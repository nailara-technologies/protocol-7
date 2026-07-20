package AMOS7::deps::os_package;

use strict;
use warnings;
use English;

use Exporter;
use base qw| Exporter |;

our @EXPORT_OK = qw|
    detect_os
    scan_zenki_os_deps
    probe_os_pkg
    probe_binary
    install_os_pkgs
    |;

use File::Which qw| which |;

## Load debian backend for dispatch [ fully-qualified calls only :        ##
## compile-time imports break when Module::Refresh wipes the shared CV    ##
## during a live v7 reload [ %DB::sub active ] -- runtime stash lookups    ##
## always resolve to the current coderef ]                                ##
use AMOS7::deps::debp;

##[ detect_os ]###############################################################

sub detect_os {
    if ( -f '/etc/os-release' ) {
        open my $fh, '<', '/etc/os-release' or return 'unknown';
        my $content = do { local $/; <$fh> };
        close $fh;

        if ( $content =~ m|^ID=debian$|m ) {
            return 'debian';
        } elsif ( $content =~ m|^ID_LIKE=.*debian|m ) {
            return 'debian';
        } elsif ( $content =~ m|^ID=arch$|m ) {
            return 'arch';
        } elsif ( $content =~ m|^ID=fedora$|m ) {
            return 'fedora';
        }
    }

    if ( -f '/etc/debian_version' ) {
        return 'debian';
    }

    return 'unknown';
}

##[ scan_zenki_os_deps ]######################################################

sub scan_zenki_os_deps {
    my ($zenki_base) = @_;

    my %os_deps = ( binary => {} );
    return \%os_deps unless -d $zenki_base;

    opendir my $dh, $zenki_base or return \%os_deps;
    while ( my $zenka = readdir $dh ) {
        next if $zenka =~ /^\./;

        my $os_dep_base = "$zenki_base/$zenka/os-dep";
        next unless -d $os_dep_base;

        opendir my $odh, $os_dep_base or next;
        while ( my $type = readdir $odh ) {
            next if $type =~ /^\./;
            next if $type eq '.placeholder';

            my $type_dir = "$os_dep_base/$type";
            next unless -d $type_dir;

            if ( $type eq 'binary' ) {
                opendir my $bdh, $type_dir or next;
                while ( my $bin = readdir $bdh ) {
                    next if $bin =~ /^\./;
                    push @{ $os_deps{binary}{$bin} }, $zenka;
                }
                closedir $bdh;
            } else {
                opendir my $tdh, $type_dir or next;
                while ( my $pkg = readdir $tdh ) {
                    next if $pkg =~ /^\./;
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

sub probe_os_pkg {
    my ( $pkg, $os_type ) = @_;

    return 0 unless defined $pkg && length $pkg;

    return probe_binary($pkg)                 if $os_type eq 'binary';
    return AMOS7::deps::debp::probe_apt($pkg) if $os_type eq 'debian';

    ## future: arch, fedora, etc. ##
    return 0;
}

##[ probe_binary ]############################################################

sub probe_binary {
    my ($binary) = @_;

    return 0 unless defined $binary && length $binary;

    my $path = File::Which::which($binary);

    return ( defined $path && length $path ) ? 1 : 0;
}

##[ install_os_pkgs ]#########################################################

sub install_os_pkgs {
    my ( $os_type, @pkgs ) = @_;

    return { ok => [], failed => [] } unless @pkgs;

    if ( $os_type eq 'debian' ) {
        return AMOS7::deps::debp::install_apt(@pkgs);
    }

    ## Future: arch, fedora, etc. ##
    return { ok => [], failed => [@pkgs] };
}

1;

#,,,,,,.,,,..,.,,,,,,,.,,,,,,,,.,,,,,,,.,,...,..,,...,...,,,.,,.,,,,,,.,,,.,.,
#NGD57G6RQCM5MRR6IXYZ7CYAHR5XBGX2M5BVOTKI7VFWTHHSE6QRANHRLRZKTZH5IE6LOQZMTAMEQ
#\\\|MY7JDOGREXEHCB5GWSA3C33B2T34LFZDZDPG5I3GAL2QTQ2RLRI \ / AMOS7 \ YOURUM ::
#\[7]FEUOSOPUQ543KAFSVHI5XMDZZ7MXC6QXOHFXIZZ4T2P4X3EB3WDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
