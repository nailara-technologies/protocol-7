package AMOS7::deps::tracked;
our $VERSION = qw| AMOS7::deps::tracked-VERSION.DYLAKQA |;

use strict;
use warnings;
use English;

use File::Spec;
use File::Path qw| make_path |;
use Fcntl      qw| O_RDONLY O_DIRECTORY LOCK_EX |;

use Exporter;
use base qw| Exporter |;

our @EXPORT_OK = qw| track_file read_tracked record undeclared promote
    chown_to_user recorded_profiles |;

## fully-qualified calls into os_package [ compile-time imports break when ##
## Module::Refresh wipes the shared CV during a live v7 reload ]           ##
use AMOS7::deps::os_package;

##[ shared tracked-package list ]#############################################
##
## single implementation for var/sys-deps/tracked.yaml [ OS packages and    ##
## CPAN modules installed while a system runs, later declared as empty      ##
## marker files under cfg/zenki/<zenka>/deps/os/<dir>/<pkg> for replication ##
## to other hosts ]. a 'profile' entry [ type 'profile' ] records the       ##
## p7-deps profile installed on a host -- read back by bin/p7-install on    ##
## re-runs. previously three separate copies                                ##
## [ bin/os-pkg, sys-deps.handler.install_reply, v7-zenki.sys_deps.track ]  ##
## -- this one dedups, writes atomically and adds the 'family' and optional ##
## 'user' fields                                                            ##

## YAML::Tiny is always required lazily inside the functions : the stripped ##
## core-perl load check forbids pulling it in at module-load time           ##

##[ track_file ]##############################################################

sub track_file {
    my ($p7_root) = @_;
    return File::Spec->catfile( $p7_root, qw| var sys-deps tracked.yaml | );
}

##[ read_tracked ]############################################################

## arrayref of entries [ missing or unreadable file = [] ] ##

sub read_tracked {
    my ($p7_root) = @_;

    my $path = track_file($p7_root);
    return [] unless -f $path;

    my $entries = [];
    eval {
        require YAML::Tiny;
        my $yaml = YAML::Tiny->read($path);
        if (    defined $yaml
            and defined $yaml->[0]
            and ref $yaml->[0] eq 'HASH' ) {
            my $tracked = $yaml->[0]->{'tracked'} // [];
            $entries = $tracked if ref $tracked eq 'ARRAY';
        }
    };
    return $entries;
}

##[ recorded_profiles ]#######################################################

## profile entries [ type 'profile', written by bin/p7-deps install ], most ##
## recently installed first -- bin/p7-install picks the first one on a      ##
## re-run without --profile                                                 ##

sub recorded_profiles {
    my ($p7_root) = @_;

    my @profiles = grep {
                ref $ARG eq 'HASH'
            and ( $ARG->{'type'} // '' ) eq qw| profile |
            and defined $ARG->{'pkg'}
    } @{ read_tracked($p7_root) };

    return [
        sort {
            ( $b->{'installed_at'} // '' ) cmp( $a->{'installed_at'} // '' )
        } @profiles
    ];
}

##[ record ]##################################################################

## merge new entries into the tracked list and write it back atomically     ##
## [ temp file + rename ]. dedup on type + name : a re-install updates      ##
## installed_at, keeps the first zenka unless the stored entry has none and ##
## the caller supplies one. 'family' is set at record time                  ##
## [ the OS family via detect_os, or 'cpan' for cpan entries ] ; 'user' is  ##
## kept when given [ unset when unknown ]. returns the merged list, undef   ##
## on write failure                                                         ##

sub record {
    my ( $p7_root, $new_entries ) = @_;

    return undef
        unless defined $p7_root
        and ref $new_entries eq 'ARRAY';

    ## one writer at a time across v7-zenki, sys-deps and os-pkg : the lock ##
    ## is held until this sub returns [ released with the handle ]          ##
    my $lock    = _lock($p7_root);
    my $entries = read_tracked($p7_root);

    my %index;
    for my $entry (@$entries) {
        next unless ref $entry eq 'HASH';
        $index{ _key( $entry->{'type'}, $entry->{'pkg'} ) } = $entry;
    }

    for my $new (@$new_entries) {
        next unless ref $new eq 'HASH';
        my $pkg = $new->{'pkg'};
        next unless defined $pkg and length $pkg;

        my $type   = $new->{'type'} // qw| debian |;
        my $family = _family($type);

        if ( my $existing = $index{ _key( $type, $pkg ) } ) {
            ## re-install : refresh the timestamp, keep the first values ##
            $existing->{'installed_at'} = $new->{'installed_at'}
                // _timestamp();
            $existing->{'zenka'} //= $new->{'zenka'}
                if defined $new->{'zenka'};
            $existing->{'source'} //= $new->{'source'};
            $existing->{'user'}   //= $new->{'user'}
                if defined $new->{'user'};
            $existing->{'family'} //= $family;
            $existing->{'declared'} = 1
                if $new->{'declared'};
        } else {
            my %entry = (
                'pkg'          => $pkg,
                'type'         => $type,
                'installed_at' => $new->{'installed_at'} // _timestamp(),
                'source'       => $new->{'source'}       // 'unknown',
                'zenka'        => $new->{'zenka'},
                'declared'     => $new->{'declared'} // 0,
                'family'       => $family,
            );
            $entry{'user'} = $new->{'user'} if defined $new->{'user'};
            push @$entries, \%entry;
            $index{ _key( $type, $pkg ) } = $entries->[-1];
        }
    }

    return undef unless _save( $p7_root, $entries );
    return $entries;
}

##[ chown_to_user ]###########################################################

## hand the tracked file + its directory over to the zenka user after a     ##
## ROOT install [ v7-zenki prestart \ perlmod auto-install stage 2 ] so the ##
## unprivileged sys-deps \ os-pkg zenki keep read-write access. no-op when  ##
## not root, when the user is unknown or the file does not exist            ##

sub chown_to_user {
    my ( $p7_root, $user ) = @_;

    return unless defined $p7_root and defined $user and length $user;
    return if $UID != 0;

    my $path = track_file($p7_root);
    return unless -f $path;

    my $dir = File::Spec->catdir( $p7_root, qw| var sys-deps | );
    my ( $uid, $gid ) = ( getpwnam($user) )[ 2, 3 ];
    return unless defined $uid;

    chown( $uid, $gid, $dir, $path );
    chmod 0775, $dir;
    chmod 0664, $path;
    return 1;
}

##[ undeclared ]##############################################################

## entries whose package is not declared in any zenka's               ##
## deps/os/<dir>/<pkg>                                                ##
## [ the <dir> name via dep_type_to_dir, never hard-coded ]. an entry ##
## already flagged 'declared' in the file is never reported again     ##

sub undeclared {
    my ($p7_root) = @_;

    my $entries = read_tracked($p7_root);

    my $zenki_base = File::Spec->catdir( $p7_root, qw| cfg zenki | );
    my $os_deps    = AMOS7::deps::os_package::scan_zenki_os_deps($zenki_base);

    my @undeclared;
    for my $entry (@$entries) {
        next if $entry->{'declared'};
        my $type = $entry->{'type'} // '';
        my $pkg  = $entry->{'pkg'}  // '';
        ## an install record, not a package ##
        next if $type eq qw| profile |;
        next
            if length $pkg
            and defined $os_deps->{$type}
            and defined $os_deps->{$type}{$pkg};
        push @undeclared, $entry;
    }

    return \@undeclared;
}

##[ promote ]#################################################################

## write the declaration marker for a tracked entry into                    ##
## cfg/zenki/<zenka>/deps/os/<dir-for-its-type>/<name> and flag the entry   ##
## 'declared' in the tracked file. refuses : invalid names [ '/' or '..' ], ##
## an unknown zenka [ no such cfg/zenki/<zenka> directory ] or an entry not ##
## present in the tracked list. returns a hashref :  { ok => 1, status =>   ##
## created | exists, path => .. } or  { ok => 0, error => .. }              ##

sub promote {
    my ( $p7_root, $zenka, $name ) = @_;

    for my $value ( $zenka, $name ) {
        return { 'ok' => 0, 'error' => 'invalid zenka or package name' }
            if not defined $value
            or not length $value
            or index( $value, '/' ) >= 0
            or index( $value, '..' ) >= 0;
    }

    my $zenka_dir = File::Spec->catdir( $p7_root, qw| cfg zenki |, $zenka );
    return { 'ok' => 0, 'error' => "unknown zenka '$zenka'" }
        unless -d $zenka_dir;

    ## one writer at a time across v7-zenki, sys-deps and os-pkg : the lock ##
    ## is held until this sub returns [ released with the handle ]          ##
    my $lock    = _lock($p7_root);
    my $entries = read_tracked($p7_root);
    my ($entry) = grep {
        ref $_ eq 'HASH' and defined $_->{'pkg'} and $_->{'pkg'} eq $name
    } @$entries;
    return { 'ok' => 0, 'error' => "no tracked entry for '$name'" }
        unless defined $entry;

    my $type     = $entry->{'type'} // qw| debian |;
    my $dir_name = AMOS7::deps::os_package::dep_type_to_dir($type);
    my $dep_dir  = File::Spec->catdir( $zenka_dir, qw| deps os |, $dir_name );
    make_path($dep_dir) unless -d $dep_dir;

    my $marker = File::Spec->catfile( $dep_dir, $name );
    my $status = qw| exists |;
    if ( !-f $marker ) {
        open my $fh, '>',
            $marker
            or return {
            'ok'    => 0,
            'error' => "failed to create $marker: $OS_ERROR"
            };
        close $fh;
        $status = qw| created |;
    }

    $entry->{'declared'} = 1;
    $entry->{'family'} //= _family($type);
    return { 'ok' => 0, 'error' => "failed to update tracked state" }
        unless _save( $p7_root, $entries );

    return { 'ok' => 1, 'status' => $status, 'path' => $marker };
}

##[ internals ]###############################################################

sub _key {
    return join chr(0), map { $_ // '' } @ARG;
}

sub _family {
    my ($type) = @_;
    return qw| cpan | if ( $type // '' ) eq qw| cpan |;
    return AMOS7::deps::os_package::detect_os();
}

sub _timestamp {
    my @gm = gmtime();
    return sprintf(
        '%04d-%02d-%02dT%02d:%02d:%02dZ',
        $gm[5] + 1900,
        $gm[4] + 1,
        $gm[3], $gm[2], $gm[1], $gm[0]
    );
}

## exclusive lock on the var/sys-deps directory itself -- no lock file ##
## [ root and the zenka user both open a directory read-only ] ; best  ##
## effort : without it the write still happens [ atomic, unlocked ]    ##
sub _lock {
    my ($p7_root) = @_;

    my $dir = File::Spec->catdir( $p7_root, qw| var sys-deps | );
    make_path($dir) unless -d $dir;
    sysopen( my $lock_fh, $dir, O_RDONLY | O_DIRECTORY ) or return undef;
    flock( $lock_fh, LOCK_EX )                           or return undef;
    return $lock_fh;
}

sub _save {
    my ( $p7_root, $entries ) = @_;

    my $path = track_file($p7_root);
    my $dir  = File::Spec->catdir( $p7_root, qw| var sys-deps | );
    make_path($dir) unless -d $dir;

    my $content = eval {
        require YAML::Tiny;
        YAML::Tiny->new( { 'tracked' => $entries } )->write_string;
    };
    return undef
        if not defined $content or length $EVAL_ERROR;

    ## atomic : temp file in the same directory, then rename ##
    my $tmp = sprintf '%s.tmp.%d', $path, $PID;
    if ( open my $fh, '>', $tmp ) {
        print {$fh} $content;
        if ( close $fh and rename $tmp, $path ) {
            chmod 0664, $path if -o $path;
            return 1;
        }
    }
    unlink $tmp if -f $tmp;
    return undef;
}

1;

#,,..,,,.,...,.,.,.,,,,,,,,,.,,.,,,.,,,,,,,.,,..,,...,...,.,.,,..,..,,,,.,,,.,
#447Z22Y6H5G72GEIP6Y7VWYV2U464LDFDO4H7GOUMK3KLLYIEKJOT3YS5DMV7EB2RGKT3VOPLKTPS
#\\\|OYQVFHPLFI6QXOV6AZH3YE7JLNTMWCH7L54GR7B5XCHFKGCEIO3 \ / AMOS7 \ YOURUM ::
#\[7]A54NGCDOD3FEANQEKMDV53S4CYDWOZ3WW23YUZGV4F5KJHBCJIDQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
