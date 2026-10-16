package AMOS7::deps::os_package;

use strict;
use warnings;
use English;

use Exporter;
use base qw| Exporter |;

our @EXPORT_OK = qw|
    detect_os
    read_os_release
    backend_available
    scan_zenki_os_deps
    probe_os_pkg
    probe_binary
    install_os_pkgs
    dep_type_to_dir
    dep_dir_to_type
    |;

## short on-disk deps/os/* dir name <-> canonical internal type string [ ##
## keeps 'debian'/'binary' as the type string used everywhere else, only ##
## the leaf directory name is shortened ]                                ##
my %TYPE_TO_DIR = ( debian => 'deb', binary => 'bin' );
my %DIR_TO_TYPE = reverse %TYPE_TO_DIR;

sub dep_type_to_dir { my ($type) = @_; return $TYPE_TO_DIR{$type} // $type; }
sub dep_dir_to_type { my ($dir)  = @_; return $DIR_TO_TYPE{$dir}  // $dir; }

## OS-family backends live in AMOS7/deps/backend/<family>.pm and are loaded ##
## BY FAMILY NAME at runtime -- never a compile-time import of the dispatch ##
## targets : Module::Refresh wipes the shared CV during a live v7 reload    ##
## [ %DB::sub active ] and a coderef imported at compile time would keep    ##
## pointing at the old sub, while a runtime stash lookup [ ->can ] always   ##
## resolves to the current coderef. debp stays loaded the same way for its  ##
## direct users [ bin/p7-deps, bin/os-pkg ]                                 ##
use AMOS7::deps::debp;

## family names map to AMOS7/deps/backend/<family>.pm -- validated before ##
## anything touches require [ no path traversal, no surprises ]           ##
my $FAMILY_NAME_RE = qr|\A[a-z0-9_]+\z|;    ## \z : no trailing newline ##

## the backend method for a family, or undef                              ##
## [ unknown \ missing family, failed require, or no such method ]. the   ##
## require result is memoized in %INC by perl itself ; Module::Refresh    ##
## drops the %INC entry on reload so the next lookup loads the file again ##
sub _backend_method {
    my ( $family, $method ) = @_;

    return undef unless defined $family and $family =~ $FAMILY_NAME_RE;

    my $mod  = "AMOS7::deps::backend::$family";
    my $file = "AMOS7/deps/backend/$family.pm";

    eval { require $file } or return undef;

    return $mod->can($method);
}

sub backend_available {
    my ($family) = @_;
    return 0 unless defined $family and $family =~ $FAMILY_NAME_RE;
    return eval { require "AMOS7/deps/backend/$family.pm" } ? 1 : 0;
}

##[ detect_os ]###############################################################

sub detect_os {
    my ($alt_release_path) = @_;

    ## optional os-release path [ tests feed fixture files ] -- the default ##
    ## stays the real /etc/os-release                                       ##
    my $release_path
        = defined $alt_release_path
        ? $alt_release_path
        : qw| /etc/os-release |;

    if ( -f $release_path ) {
        open my $fh, '<', $release_path or return 'unknown';
        my $content = do { local $/; <$fh> };
        close $fh;

        if ( $content =~ m|^ID=debian$|m ) {
            return 'debian';
        } elsif ( $content =~ m|^ID_LIKE=.*debian|m ) {
            return 'debian';
        } elsif ( $content =~ m|^ID=nixos$|m ) {
            return 'nixos';
        } elsif ( $content =~ m|^ID=arch$|m ) {
            return 'arch';
        } elsif ( $content =~ m|^ID=fedora$|m ) {
            return 'fedora';
        }

        ## an explicit fixture path stands for the whole os-release state : ##
        ## no host fallback below                                           ##
        return 'unknown' if defined $alt_release_path;
    }

    if ( -f '/etc/debian_version' ) {
        return 'debian';
    }

    return 'unknown';
}

##[ read_os_release ]#########################################################

## the KEY=value pairs of os-release [ quotes stripped ] for display -- the ##
## family itself comes from detect_os only, so every zenka and the root     ##
## runner agree on it. optional path as for detect_os ; {} when unreadable  ##
sub read_os_release {
    my ($alt_release_path) = @_;

    my $release_path
        = defined $alt_release_path
        ? $alt_release_path
        : qw| /etc/os-release |;

    my %os_release;
    open my $fh, '<', $release_path or return \%os_release;
    while ( my $line = <$fh> ) {
        chomp $line;
        next unless $line =~ m{^([A-Z_]+)=(.*)$};
        my ( $key, $value ) = ( $1, $2 );
        $value =~ s{^"|"$}{}g;
        $os_release{$key} = $value;
    }
    close $fh;

    return \%os_release;
}

##[ scan_zenki_os_deps ]######################################################

sub scan_zenki_os_deps {
    my ($zenki_base) = @_;

    my %os_deps = ( binary => {} );
    return \%os_deps unless -d $zenki_base;

    opendir my $dh, $zenki_base or return \%os_deps;
    while ( my $zenka = readdir $dh ) {
        next if $zenka =~ m|^\.|;

        my $os_dep_base = "$zenki_base/$zenka/deps/os";
        next unless -d $os_dep_base;

        opendir my $odh, $os_dep_base or next;
        while ( my $dir_name = readdir $odh ) {
            next if $dir_name =~ m|^\.|;
            next if $dir_name eq '.placeholder';

            my $type_dir = "$os_dep_base/$dir_name";
            next unless -d $type_dir;

            my $type = dep_dir_to_type($dir_name);

            if ( $type eq 'binary' ) {
                opendir my $bdh, $type_dir or next;
                while ( my $bin = readdir $bdh ) {
                    next if $bin =~ m|^\.|;
                    push @{ $os_deps{binary}{$bin} }, $zenka;
                }
                closedir $bdh;
            } else {
                opendir my $tdh, $type_dir or next;
                while ( my $pkg = readdir $tdh ) {
                    next if $pkg =~ m|^\.|;
                    push @{ $os_deps{$type}{$pkg} }, $zenka;
                }
                closedir $tdh;
            }
        }
        closedir $odh;
    }
    closedir $dh;

    return \%os_deps;
}

##[ probe_os_pkg ]############################################################

## $fresh : the current dpkg state per call, no in-process apt cache  ##
## [ long-lived processes -- see AMOS7::deps::debp::probe_apt_fresh ] ##
sub probe_os_pkg {
    my ( $pkg, $os_type, $fresh ) = @_;

    return 0 unless defined $pkg && length $pkg;

    return probe_binary($pkg) if $os_type eq 'binary';

    ## dispatch by FAMILY NAME through the backend module -- os names never ##
    ## appear here : a new family is one backend file, no change to this    ##
    ## code                                                                 ##
    if ( my $probe = _backend_method( $os_type, 'probe' ) ) {
        return $probe->( $pkg, $fresh );
    }

    ## unknown family or no backend module : nothing to probe with ##
    return 0;
}

##[ probe_binary ]############################################################

## core-only replacement for File::Which::which : a name with a path       ##
## separator is checked directly, otherwise the first -f && -x hit in      ##
## $ENV{PATH} wins [ empty entries skipped ] -- keeps bin/p7-deps loadable ##
## on a bare host without File::Which                                      ##

sub _which_path {
    my ($binary) = @_;

    return undef unless defined $binary and length $binary;

    if ( index( $binary, '/' ) >= 0 ) {
        return ( -f $binary and -x $binary ) ? $binary : undef;
    }

    foreach my $dir ( split m|:|, $ENV{'PATH'} // '' ) {
        next unless length $dir;
        my $path = "$dir/$binary";
        return $path if -f $path and -x $path;
    }

    return undef;
}

sub probe_binary {
    my ($binary) = @_;

    return 0 unless defined $binary && length $binary;

    my $path = _which_path($binary);

    return ( defined $path && length $path ) ? 1 : 0;
}

##[ install_os_pkgs ]#########################################################

sub install_os_pkgs {
    my ( $os_type, @pkgs ) = @_;

    return { ok => [], failed => [] } unless @pkgs;

    ## dispatch by FAMILY NAME through the backend module                   ##
    ## [ see probe_os_pkg ] : the debian contract passes through unchanged, ##
    ## straight from debp::install_apt                                      ##
    if ( my $install = _backend_method( $os_type, 'install' ) ) {
        return $install->(@pkgs);
    }

    ## unknown family or no backend module : everything needs the admin by ##
    ## hand [ 'manual' -- e.g. nixos is declarative and will report        ##
    ## configuration.nix lines here later ]                                ##
    return { ok => [], failed => [], manual => [@pkgs] };
}

1;

#,,,.,.,.,.,,,.,.,...,,.,,.,.,,,,,.,,,.,.,...,..,,...,...,.,.,,,,,,,,,...,.,,,
#QQC6CLNA2PQLFKAZLFXXTOJRURNQSUCB7P5F3DRR2S76XMUK76264JYRPJ4VHJ6PFL7WBIKLQFRSS
#\\\|YZEIXDUDVLMCVBRMZSDXDFMILSIRJWZGF7UFHQ7BKTBX3SMBCYR \ / AMOS7 \ YOURUM ::
#\[7]4QSRZLHU4XEOUIYWEXQU6WHUSNPRXULI5VSSQKMYIGSUO4CAPKCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
