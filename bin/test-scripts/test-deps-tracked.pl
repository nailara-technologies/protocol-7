#!/usr/bin/perl
use v5.24;
use strict;
use English;
use warnings;

###                                                              ###
##  AMOS7::deps::tracked : shared tracked-package list contract   ###
###                                                              ###

## exercises data/lib-path/pm/AMOS7/deps/tracked.pm against temporary roots ##
## only [ File::Temp ] -- never the real var/. covers : reading a fixture   ##
## in the CURRENT on-disk format, recording into empty and existing files,  ##
## dedup on type + name with re-install updating installed_at, atomic write ##
## [ no temp file left ], undeclared before and after a declaration marker  ##
## exists, promote writing the marker into the right deps/os/<dir>/ for the ##
## entry's type and refusing bad names \ unknown zenki \ unknown entries,   ##
## family + user round-trip and absence-safety. every assertion reads the   ##
## state back from disk                                                     ##
## [ tracked.yaml re-parsed with YAML::Tiny or the marker file tree ] --    ##
## never from printed text                                                  ##

use File::Spec;
use Cwd        qw| abs_path |;
use FindBin    qw| $RealBin |;
use File::Temp qw| tempdir |;
use File::Path qw| make_path |;

BEGIN {
    my $up_dir    = File::Spec->updir;
    my $root_path = abs_path(
        File::Spec->rel2abs(
            File::Spec->catdir( $RealBin, $up_dir, $up_dir )
        )
    );
    my $local_lib_path
        = File::Spec->catdir( $root_path, qw| data lib-path pm | );
    die "not found : $local_lib_path" if !-d $local_lib_path;
    unshift( @INC, $local_lib_path );
}

use YAML::Tiny;
use AMOS7::deps::tracked;
use AMOS7::deps::os_package qw| detect_os dep_type_to_dir |;

use constant TRUE  => 5;
use constant FALSE => 0;

my $pass_count = 0;
my $fail_count = 0;

sub check {
    my ( $label, $cond ) = @_;
    if ($cond) {
        $pass_count++;
        printf "ok   : %s\n", $label;
    } else {
        $fail_count++;
        printf "FAIL : %s\n", $label;
    }
    return $cond;
}

sub write_file {
    my ( $path, $content ) = @_;
    open my $fh, '>', $path or die "cannot write $path : $OS_ERROR";
    print {$fh} $content;
    close $fh;
    return TRUE;
}

## fresh temp root with the tracked file optionally pre-populated ##

my $sandbox = tempdir( CLEANUP => 1 );

sub fresh_root {
    my ($tracked_yaml) = @_;
    my $root = File::Spec->catdir( $sandbox,
              'root-'
            . $PID . '-'
            . $pass_count . '-'
            . $fail_count . '-'
            . int( rand 1_000_000 ) );
    make_path( File::Spec->catdir( $root, qw| var sys-deps | ) );
    if ( defined $tracked_yaml ) {
        write_file( AMOS7::deps::tracked::track_file($root), $tracked_yaml );
    }
    return $root;
}

## entries exactly as they sit on disk [ re-parse, never trust returns ] ##

sub entries_on_disk {
    my ($root) = @_;
    my $yaml = eval {
        YAML::Tiny->read( AMOS7::deps::tracked::track_file($root) );
    };
    return undef unless defined $yaml && ref $yaml->[0] eq 'HASH';
    return $yaml->[0]->{'tracked'} // [];
}

## marker files present under a root, as relative paths ##

sub marker_files {
    my ($root) = @_;
    my $base = File::Spec->catdir( $root, qw| cfg zenki | );
    return [] unless -d $base;
    my @found;
    opendir my $dh, $base or die "cannot open $base : $OS_ERROR";
    while ( my $zenka = readdir $dh ) {
        next if $zenka =~ m|^\.|;
        my $os_base = File::Spec->catdir( $base, $zenka, qw| deps os | );
        next unless -d $os_base;
        opendir my $oh, $os_base or next;
        while ( my $dir = readdir $oh ) {
            next if $dir =~ m|^\.|;
            my $type_dir = File::Spec->catdir( $os_base, $dir );
            next unless -d $type_dir;
            opendir my $th, $type_dir or next;
            while ( my $pkg = readdir $th ) {
                next if $pkg =~ m|^\.|;
                push @found, "$zenka/deps/os/$dir/$pkg";
            }
            closedir $th;
        }
        closedir $oh;
    }
    closedir $dh;
    return [ sort @found ];
}

## temp files left next to the tracked file ##

sub leftover_temp_files {
    my ($root) = @_;
    my $dir = File::Spec->catdir( $root, qw| var sys-deps | );
    opendir my $dh, $dir or return [];
    my @leftover = sort grep {m|\.tmp\.|} readdir $dh;
    closedir $dh;
    return \@leftover;
}

##[ fixture : the CURRENT on-disk shape, copied from var/sys-deps/     ##
##  tracked.yaml [ quoted + unquoted declared forms, no family, no user ] ##

my $fixture = <<'EOF';
---
tracked:
  -
    declared: '0'
    installed_at: 3XB2V4EWEGCOADI
    pkg: make
    source: sys-deps
    type: debian
    zenka: ~
  -
    declared: 0
    installed_at: 3XB2X3EUFOCLC2Q
    pkg: libimager-perl
    source: sys-deps
    type: debian
    zenka: ~
EOF

my $host_family = detect_os();

##[ track_file + read_tracked ]###############################################

{
    my $root = fresh_root(undef);

    check 'track_file points at var/sys-deps/tracked.yaml under the root',
        ( AMOS7::deps::tracked::track_file($root) eq
            File::Spec->catfile( $root, qw| var sys-deps tracked.yaml | ) );

    check 'read_tracked on a missing file returns an empty list',
        ( @{ AMOS7::deps::tracked::read_tracked($root) } == 0 );
}

{
    my $root    = fresh_root($fixture);
    my $entries = AMOS7::deps::tracked::read_tracked($root);

    check 'fixture in the current format reads two entries',
        ( ref $entries eq 'ARRAY' and @$entries == 2 );

    check 'fixture entry fields survive a round trip',
        (       $entries->[0]{'pkg'} eq 'make'
            and $entries->[0]{'installed_at'} eq '3XB2V4EWEGCOADI'
            and $entries->[0]{'source'} eq 'sys-deps'
            and $entries->[0]{'type'} eq 'debian'
            and not defined $entries->[0]{'zenka'} );

    check 'fixture entries carry no family key [ absent-safe ]',
        (       @$entries == 2
            and not exists $entries->[0]{'family'}
            and not exists $entries->[1]{'family'} );

    check 'fixture entries carry no user key [ absent-safe ]',
        (       not exists $entries->[0]{'user'}
            and not exists $entries->[1]{'user'} );

    check 'both quoted and unquoted declared forms read as false',
        ( not $entries->[0]{'declared'} and not $entries->[1]{'declared'} );
}

##[ record : empty file, append, defaults ]###################################

{
    my $root = fresh_root(undef);

    my $returned = AMOS7::deps::tracked::record(
        $root,
        [
            {   'pkg'          => 'make',
                'type'         => 'debian',
                'installed_at' => '3XB2V4EWEGCOADI',
                'source'       => 'sys-deps',
                'zenka'        => undef,
                'declared'     => 0,
            }
        ]
    );

    check 'record creates the directory and file',
        ( -f AMOS7::deps::tracked::track_file($root) );

    my $entries = entries_on_disk($root);
    check 'record into an empty root writes one entry on disk',
        ( ref $entries eq 'ARRAY' and @$entries == 1 );

    check 'recorded entry keeps the caller-supplied fields on disk',
        (       $entries->[0]{'pkg'} eq 'make'
            and $entries->[0]{'type'} eq 'debian'
            and $entries->[0]{'installed_at'} eq '3XB2V4EWEGCOADI'
            and $entries->[0]{'source'} eq 'sys-deps' );

    check 'record sets family to the detected OS family on disk',
        ( $entries->[0]{'family'} eq $host_family );

    check 'record leaves user unset when unknown [ absent on disk ]',
        ( not exists $entries->[0]{'user'} );

    check 'record returns the merged list',
        ( ref $returned eq 'ARRAY' and @$returned == 1 );
}

{
    my $root = fresh_root(undef);

    AMOS7::deps::tracked::record( $root,
        [ { 'pkg' => 'libfoo-perl', 'type' => 'debian' } ] );

    my $entries = entries_on_disk($root);
    check 'record defaults type to debian on disk',
        ( @$entries == 1 and $entries->[0]{'type'} eq 'debian' );

    check 'record generates an ISO installed_at when none is given',
        ( $entries->[0]{'installed_at'}
            =~ m|^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$| );

    check 'record defaults source to unknown on disk',
        ( $entries->[0]{'source'} eq 'unknown' );
}

{
    my $root = fresh_root($fixture);

    AMOS7::deps::tracked::record(
        $root,
        [
            {   'pkg'          => 'libnew-perl',
                'type'         => 'debian',
                'installed_at' => '3XB2ZNEW000000A',
                'source'       => 'sys-deps',
                'zenka'        => 'cube',
                'declared'     => 0,
            }
        ]
    );

    my $entries = entries_on_disk($root);
    check 'record into an existing file appends on disk',
        ( @$entries == 3 and $entries->[2]{'pkg'} eq 'libnew-perl' );

    check 'pre-existing fixture entries stay untouched on disk',
        (       $entries->[0]{'pkg'} eq 'make'
            and $entries->[0]{'installed_at'} eq '3XB2V4EWEGCOADI'
            and not exists $entries->[0]{'family'} );
}

##[ dedup + re-install semantics ]############################################

{
    my $root = fresh_root($fixture);

    ## re-install of an existing type + name ##
    AMOS7::deps::tracked::record(
        $root,
        [
            {   'pkg'          => 'make',
                'type'         => 'debian',
                'installed_at' => '3XB2ZZZZREINSTA',
                'source'       => 'v7-prestart',
                'zenka'        => 'cube',
                'declared'     => 0,
            }
        ]
    );

    my $entries = entries_on_disk($root);
    my @make    = grep { $ARG->{'pkg'} eq 'make' } @$entries;
    check 're-record dedups on type + name [ single entry on disk ]',
        ( @$entries == 2 and @make == 1 );

    check 're-install updates installed_at on disk',
        ( @make == 1 and $make[0]{'installed_at'} eq '3XB2ZZZZREINSTA' );

    check 're-install fills a missing zenka but keeps it first',
        ( @make == 1 and $make[0]{'zenka'} eq 'cube' );

    ## a second re-install must not overwrite the first zenka ##
    AMOS7::deps::tracked::record(
        $root,
        [
            {   'pkg'          => 'make',
                'type'         => 'debian',
                'installed_at' => '3XB2YYYYSECOND',
                'source'       => 'manual',
                'zenka'        => 'task',
                'declared'     => 0,
            }
        ]
    );

    $entries = entries_on_disk($root);
    @make    = grep { $ARG->{'pkg'} eq 'make' } @$entries;
    check 'second re-install still updates installed_at on disk',
        ( @make == 1 and $make[0]{'installed_at'} eq '3XB2YYYYSECOND' );

    check 'the first zenka wins over a later re-install',
        ( @make == 1 and $make[0]{'zenka'} eq 'cube' );

    AMOS7::deps::tracked::record(
        $root,
        [
            {   'pkg'          => 'make',
                'type'         => 'cpan',
                'installed_at' => '3XB2XXXXCPAN000',
                'source'       => 'v7-prestart',
                'declared'     => 0,
            }
        ]
    );
    my $after = entries_on_disk($root);
    my @cpan_make
        = grep { $ARG->{'type'} eq 'cpan' and $ARG->{'pkg'} eq 'make' }
        @$after;

    check 'dedup is keyed on type + name, not name alone',
        ( @$after == 3 and @cpan_make == 1 );
}

##[ atomic write ]############################################################

{
    my $root = fresh_root($fixture);

    AMOS7::deps::tracked::record(
        $root,
        [
            {   'pkg'          => 'libatomic-perl',
                'type'         => 'debian',
                'installed_at' => '3XB2ATOMIC00000',
                'source'       => 'sys-deps',
                'declared'     => 0,
            }
        ]
    );

    check 'record leaves no temp file behind',
        ( @{ leftover_temp_files($root) } == 0 );

    check 'the tracked file itself is intact after the atomic rename',
        ( @{ entries_on_disk($root) } == 3 );
}

##[ family + user round-trip ]################################################

{
    my $root = fresh_root(undef);

    AMOS7::deps::tracked::record(
        $root,
        [
            {   'pkg'          => 'Imager',
                'type'         => 'cpan',
                'installed_at' => '3XB2CPAN0000000',
                'source'       => 'v7-prestart',
                'zenka'        => 'vision-batch',
                'declared'     => 0,
                'user'         => 'taeki',
            }
        ]
    );

    my $entries = entries_on_disk($root);
    check 'cpan entries get family cpan on disk',
        ( @$entries == 1 and $entries->[0]{'family'} eq 'cpan' );

    check 'user round-trips through the file',
        ( @$entries == 1 and $entries->[0]{'user'} eq 'taeki' );

    ## a re-install without a user must keep the recorded one ##
    AMOS7::deps::tracked::record(
        $root,
        [
            {   'pkg'          => 'Imager',
                'type'         => 'cpan',
                'installed_at' => '3XB2CPANREINSTA',
                'source'       => 'v7-prestart',
                'declared'     => 0,
            }
        ]
    );

    $entries = entries_on_disk($root);
    check 're-install keeps the first user on disk',
        (       @$entries == 1
            and $entries->[0]{'user'} eq 'taeki'
            and $entries->[0]{'installed_at'} eq '3XB2CPANREINSTA' );
}

##[ undeclared ]##############################################################

{
    my $root = fresh_root($fixture);

    my $undeclared = AMOS7::deps::tracked::undeclared($root);
    check 'both fixture packages start undeclared', ( @$undeclared == 2 );

    ## declare 'make' for the cube zenka with a real marker file ##
    my $marker_dir = File::Spec->catdir(
        $root,
        qw| cfg zenki cube deps os |,
        dep_type_to_dir('debian')
    );
    make_path($marker_dir);
    write_file( File::Spec->catfile( $marker_dir, 'make' ), '' );

    $undeclared = AMOS7::deps::tracked::undeclared($root);
    check 'undeclared shrinks after a declaration marker appears on disk',
        ( @$undeclared == 1 and $undeclared->[0]{'pkg'} eq 'libimager-perl' );
}

{
    ## the declared flag in the file is respected without any marker ##
    my $root    = fresh_root($fixture);
    my $entries = entries_on_disk($root);
    $entries->[0]{'declared'} = 1;
    YAML::Tiny->new( { 'tracked' => $entries } )
        ->write( AMOS7::deps::tracked::track_file($root) );

    my $undeclared = AMOS7::deps::tracked::undeclared($root);
    check 'an entry flagged declared is not reported again',
        ( @$undeclared == 1 and $undeclared->[0]{'pkg'} eq 'libimager-perl' );
}

{
    ## type-aware : a deb marker must not declare a binary entry and vice ##
    ## versa [ guards against a hard-coded deb scan ]                     ##
    my $root = fresh_root(undef);
    AMOS7::deps::tracked::record(
        $root,
        [
            {   'pkg'          => 'ffprobe',
                'type'         => 'binary',
                'installed_at' => '3XB2BIN00000000',
                'source'       => 'v7-prestart',
                'declared'     => 0,
            }
        ]
    );

    my $deb_dir = File::Spec->catdir(
        $root,
        qw| cfg zenki cube deps os |,
        dep_type_to_dir('debian')
    );
    my $bin_dir = File::Spec->catdir(
        $root,
        qw| cfg zenki cube deps os |,
        dep_type_to_dir('binary')
    );
    make_path($deb_dir);
    write_file( File::Spec->catfile( $deb_dir, 'ffprobe' ), '' );

    my $undeclared = AMOS7::deps::tracked::undeclared($root);
    check 'a deb marker does not declare a binary entry [ type-aware ]',
        ( @$undeclared == 1 and $undeclared->[0]{'pkg'} eq 'ffprobe' );

    make_path($bin_dir);
    write_file( File::Spec->catfile( $bin_dir, 'ffprobe' ), '' );

    $undeclared = AMOS7::deps::tracked::undeclared($root);
    check 'a bin marker declares the binary entry', ( @$undeclared == 0 );
}

##[ promote ]#################################################################

{
    my $root = fresh_root($fixture);
    make_path( File::Spec->catdir( $root, qw| cfg zenki cube | ) );

    my $result = AMOS7::deps::tracked::promote( $root, 'cube', 'make' );

    check 'promote reports the marker as created',
        (       ref $result eq 'HASH'
            and $result->{'ok'}
            and $result->{'status'} eq 'created' );

    check 'promote writes the marker into deps/os/<dir> for a debian entry',
        (
              join( '|', @{ marker_files($root) } ) eq 'cube/deps/os/'
            . dep_type_to_dir('debian')
            . '/make' );

    my $entries = entries_on_disk($root);
    my @make    = grep { $ARG->{'pkg'} eq 'make' } @$entries;
    check 'promote flags the entry declared in the tracked file',
        ( @make == 1 and $make[0]{'declared'} );

    ## family is filled in as a side effect of the promote save ##
    check 'promote back-fills family on the touched entry',
        ( @make == 1 and $make[0]{'family'} eq $host_family );

    $result = AMOS7::deps::tracked::promote( $root, 'cube', 'make' );
    check 'a second promote reports the marker as existing',
        ( $result->{'ok'} and $result->{'status'} eq 'exists' );

    check 'promote never duplicates the marker on disk',
        ( @{ marker_files($root) } == 1 );
}

{
    ## the marker directory follows the entry's own type ##
    my $root = fresh_root(undef);
    AMOS7::deps::tracked::record(
        $root,
        [
            {   'pkg'          => 'ffmpeg',
                'type'         => 'rpm',
                'installed_at' => '3XB2RPM00000000',
                'source'       => 'v7-prestart',
                'declared'     => 0,
            }
        ]
    );
    make_path( File::Spec->catdir( $root, qw| cfg zenki cube | ) );

    my $result = AMOS7::deps::tracked::promote( $root, 'cube', 'ffmpeg' );

    check 'promote uses the entry type, never a hard-coded deb dir',
        (
        $result->{'ok'}
            and join( '|', @{ marker_files($root) } ) eq
            'cube/deps/os/rpm/ffmpeg' and not -f File::Spec->catfile(
            $root, qw| cfg zenki cube deps os deb ffmpeg |
            )
        );
}

{
    ## refusals : nothing may appear on disk ##
    my $root = fresh_root($fixture);
    make_path( File::Spec->catdir( $root, qw| cfg zenki cube | ) );

    my $bad = AMOS7::deps::tracked::promote( $root, 'cube', 'evil/pkg' );
    check 'promote refuses a name containing a slash',
        ( ref $bad eq 'HASH' and not $bad->{'ok'} );

    $bad = AMOS7::deps::tracked::promote( $root, 'cube', '..' );
    check 'promote refuses a dot-dot name',
        ( ref $bad eq 'HASH' and not $bad->{'ok'} );

    $bad = AMOS7::deps::tracked::promote( $root, 'no-such-zenka', 'make' );
    check 'promote refuses an unknown zenka',
        ( ref $bad eq 'HASH' and not $bad->{'ok'} );

    $bad = AMOS7::deps::tracked::promote( $root, 'cube', 'never-tracked' );
    check 'promote refuses an untracked package',
        ( ref $bad eq 'HASH' and not $bad->{'ok'} );

    check 'a refused promote writes nothing at all',
        (       @{ marker_files($root) } == 0
            and @{ entries_on_disk($root) } == 2
            and not grep { $ARG->{'declared'} } @{ entries_on_disk($root) } );
}

## concurrent writers : no lost update                                     ##
## [ v7-zenki, sys-deps and os-pkg record at the same time ] -- 8          ##
## processes, 5 packages each, started together ; every package must be on ##
## disk afterwards                                                         ##
{
    my $root     = fresh_root();
    my $go       = File::Spec->catfile( $root, 'go' );
    my $writers  = 8;
    my $per_proc = 5;
    my @pids;
    for my $w ( 1 .. $writers ) {
        my $pid = fork() // die "fork : $OS_ERROR";
        if ( $pid == 0 ) {
            select( undef, undef, undef, 0.01 ) until -e $go;
            AMOS7::deps::tracked::record( $root,
                [ { 'pkg' => "w$w-p$ARG", 'type' => 'debian' } ] )
                for 1 .. $per_proc;
            exit 0;
        }
        push @pids, $pid;
    }
    write_file( $go, "go\n" );
    waitpid( $ARG, 0 ) for @pids;
    my %on_disk = map  { $ARG->{'pkg'} => 1 } @{ entries_on_disk($root) };
    my @missing = grep { not $on_disk{$ARG} }
        map {
        my $w = $ARG;
        map {"w$w-p$ARG"} 1 .. $per_proc
        } 1 .. $writers;
    check 'concurrent writers : no lost update [ '
        . ( $writers * $per_proc )
        . ' records, '
        . scalar(@missing)
        . ' missing ]', not @missing;
    check '  :.. no temp file left behind',
        not @{ leftover_temp_files($root) };
}

## summary ##

printf "\n: %d checks passed, %d failed\n", $pass_count, $fail_count;
exit( $fail_count ? 1 : 0 );

#,,.,,...,,..,,,.,..,,...,,.,,..,,.,.,,,.,.,,,.,.,...,...,,,.,,,,,.,.,,..,...,
#WOZXOPUJLXMQPGW727IGYTTF7F4UHZUZTQ4AHULZQPKTGTB75VG4BFYUEPKF26TQQUJKXCCBSPWYS
#\\\|YF6LJFIU3ICLSRTCVXD6OOL4YBXTRBXU52OAWI53FRNLPMI6JSD \ / AMOS7 \ YOURUM ::
#\[7]RSDDAEMWX2RZFDCC4DMHCRZA33K2PVU35DY3ESGG6XQTV7LMQQDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
