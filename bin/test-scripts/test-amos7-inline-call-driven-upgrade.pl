#!/usr/bin/perl
use v5.24;
use strict;
use English;
use warnings;

###                                                                  ###
## AMOS7::INLINE call-driven upgrade                                      ##
## [ data/tasks/rcm-inline-call-driven-upgrade.md, points 1 2 3 4 5 6 7 ] ##
###

## each scenario runs in its own perl                                    ##
## [ the inline namespace and the object cache are per process ] under a ##
## throwaway dir in /tmp                                                 ##
##
## - upgrade   : fallback at once, compiled swapped in after the publish,
##               double fork, checksum recorded
## - timelimit : a hung compiler is killed with its process group
## - cap       : no free build slot stays pure perl, a freed slot upgrades
## - force     : force_pure_perl never forks, never creates a dir
## - prebuild  : every registered source compiled in the foreground, no
##               fork, objects published under the throwaway HOME, a second
##               run only loads
## - prune     : 2-part dirs and stale foreign-key dirs go ; the current key,
##               young dirs, links, other-uid dirs, locked dirs stay
## - trust-*   : key holder without \ with \ not on a list, plain caller
##               with a list that does not match

use File::Spec;
use Cwd         qw| abs_path |;
use FindBin     qw| $RealBin |;
use Time::HiRes ();

my ( $scenario, $base );

BEGIN {
    my $up_dir    = File::Spec->updir;
    my $root_path = abs_path(
        File::Spec->rel2abs(
            File::Spec->catdir( $RealBin, $up_dir, $up_dir )
        )
    );
    unshift @INC, File::Spec->catdir( $root_path, 'data', 'lib-path', 'pm' );

    ( $scenario, $base ) = @ARGV[ 0, 1 ];
    if ( defined $scenario and $scenario eq 'force' ) {
        $AMOS7::INLINE::force_pure_perl = 1;
    }
    ## count forks of the whole process ##
    no warnings qw| once |;
    $AMOS7::INLINE::no_detached_build = 1
        if defined $scenario and $scenario eq 'prebuild';
    *CORE::GLOBAL::fork = sub { $main::forks++; return CORE::fork() };
}

our $forks = 0;

my $failed = 0;

sub check {
    my ( $label, $condition ) = @_;
    printf "  %s : %s\n", ( $condition ? 'ok  ' : 'FAIL' ), $label;
    $failed++ if not $condition;
    return;
}

##[ PARENT : RUN THE SCENARIOS ]##############################################

if ( not defined $scenario ) {
    my $root = sprintf '/tmp/claude-1000/inline-upgrade-test-%d', $PID;
    mkdir '/tmp/claude-1000';
    mkdir $root or die "cannot create '$root' : $OS_ERROR\n";
    my $all_failed = 0;
    ## upgrade first : the trust scenarios reuse its published object ##
    foreach my $name (
        qw| upgrade timelimit cap force prebuild prune trust-nolist
        trust-listed trust-foreign trust-plain |
    ) {
        printf "scenario %s\n", $name;
        my $dir = "$root/$name";
        $dir = "$root/upgrade" if $name =~ m|^trust|;
        mkdir $dir;
        my $out
            = qx| $EXECUTABLE_NAME $PROGRAM_NAME $name $dir 2>$root/$name.err |;
        print $out;
        $all_failed++ if $CHILD_ERROR != 0 or $out =~ m|FAIL|;
    }

    ## a cold cache with the real modules : the truth fallbacks once were  ##
    ## the dispatcher calc_true -> the bridging wrapper looped into itself ##
    ## [ deep recursion, a SEGV in v7-zenki, 2026-11-18 ]                  ##
    printf "scenario cold-dispatcher\n";
    my $home = "$root/cold-home";
    mkdir $home;
    my $lib = abs_path(
        File::Spec->catdir( $RealBin, qw| .. .. data lib-path pm | ) );
    my $probe
        = 'use AMOS7; use AMOS7::Assert::Truth; my $n = 0; for ( 1 .. 13 ) { '
        . 'AMOS7::Assert::Truth::is_true("x$_"); $n++; select undef, '
        . 'undef, undef, 0.2 } print "calls $n\n"';
    my $cold = qx| HOME=$home $EXECUTABLE_NAME -I$lib -e '$probe' 2>&1 |;
    my $cold_ok
        = (     $CHILD_ERROR == 0
            and $cold =~ m|calls 13|
            and $cold !~ m|Deep recursion\|re-enters| );
    printf "  %s : cold cache, dispatcher fallbacks : no recursion\n",
        $cold_ok ? 'ok  ' : 'FAIL';
    print $cold   if not $cold_ok;
    $all_failed++ if not $cold_ok;

    system 'rm', '-rf', '--one-file-system', '--', $root;
    printf "\n%s\n",
        $all_failed ? "$all_failed scenario(s) FAILED" : 'all passed';
    exit( $all_failed ? 1 : 0 );
}

##[ CHILD : ONE SCENARIO ]####################################################

require AMOS7::INLINE;
AMOS7::INLINE->import;
use Scalar::Util qw| refaddr |;

my $object  = "$base/obj";
my $package = 'T::S';

sub compile {
    return AMOS7::INLINE::compile_inline_source(
        {   'subroutine-name' => 'bit_string_to_num',
            'target-package'  => $package,
            'target-path'     => $object,
        }
    );
}

## call until the installed sub is no longer the one first returned ##
sub wait_upgrade {
    my ( $initial, $seconds ) = @_;
    my $deadline = Time::HiRes::time() + $seconds;
    no strict qw| refs |;
    while ( Time::HiRes::time() < $deadline ) {
        &{"${package}::bit_string_to_num"}('1');
        return 1
            if refaddr( \&{"${package}::bit_string_to_num"} ) != $initial;
        select undef, undef, undef, 0.2;
    }
    return 0;
}

sub leftovers {
    return scalar grep { !-l $ARG } glob "$object.build-*";
}

sub gone {    ## pid not alive ##
    my $pid = shift;
    return !-d "/proc/$pid" || do {
        open my $fh, '<', "/proc/$pid/stat" or return 1;
        ( my $stat = <$fh> ) =~ s|^.*\) ||;
        $stat =~ m|^Z|;
    };
}

if ( $scenario eq 'upgrade' ) {
    my $started = Time::HiRes::time();
    my $ref     = compile();
    my $elapsed = Time::HiRes::time() - $started;
    check( 'first call returns at once [ < 2 s ]', $elapsed < 2 );
    check( 'nothing published at return',
        !AMOS7::INLINE::_object_published($object) );
    check(
        'pure-perl alternative answers',
        T::S::bit_string_to_num('101') == 5
    );
    ## the parent forks once, the middle child the builder : no child of ##
    ## ours is left to reap [ no SIGCHLD handler, no later waitpid ]     ##
    check( 'builder detached by a double fork',
        ( $main::forks == 1 and waitpid( -1, 1 ) == -1 ) );
    my $initial = refaddr( \&T::S::bit_string_to_num );
    check(
        'upgrade after publish, same process',
        wait_upgrade( $initial, 150 )
    );
    check(
        'installed sub is the compiled one',
        refaddr( \&T::S::bit_string_to_num )
            == refaddr( \&AMOS7::INLINE::bit_string_to_num )
    );
    check( 'compiled sub answers', T::S::bit_string_to_num('1111') == 15 );
    check( 'an old reference still works', $ref->('11') == 3 );
    check( 'object published', AMOS7::INLINE::_object_published($object) );
    my $recorded = do {
        open my $fh, '<', "$object/chksum" or die "no chksum record\n";
        <$fh>;
    };
    chomp $recorded;
    check(
        'checksum recorded before publish',
        (   length $recorded
                and $recorded eq AMOS7::INLINE::_object_chksum($object)
        )
    );
    check( 'no build dir left',                 leftovers() == 0 );
    check( 'no second build after the upgrade', $main::forks == 1 );

} elsif ( $scenario eq 'timelimit' ) {
    my $pid_file = "$base/cc.pids";
    my $cc       = "$base/slowcc";
    open my $fh, '>', $cc or die;
    print {$fh} "#!/bin/sh\necho \$\$ >> $pid_file\nexec sleep 300\n";
    close $fh;
    chmod 0755, $cc;
    $AMOS7::INLINE::build_cc         = $cc;
    $AMOS7::INLINE::build_time_limit = 3;
    my $started = Time::HiRes::time();
    compile();
    check(
        'returns at once with a hung compiler',
        Time::HiRes::time() - $started < 2
    );
    my $seen = 0;

    foreach ( 1 .. 40 ) {    ## the compiler starts ##
        $seen = -s $pid_file ? 1 : 0;
        last if $seen;
        select undef, undef, undef, 0.25;
    }
    check( 'the hung compiler started', $seen );
    select undef, undef, undef, 6;    ## limit 3 s + cleanup ##
    my @pids = do {
        open my $p, '<', $pid_file or die;
        map { chomp; $ARG } <$p>;
    };
    check(
        'the compiler was killed by the limit',
        ( @pids and !grep { !gone($ARG) } @pids )
    );
    check( 'nothing published', !AMOS7::INLINE::_object_published($object) );
    check( 'no build dir left', leftovers() == 0 );
    check(
        'no builder holds the object lock',
        !AMOS7::INLINE::_builder_active($object)
    );
    check( 'still answers in pure perl', T::S::bit_string_to_num('11') == 3 );

} elsif ( $scenario eq 'cap' ) {
    my @held = (
        AMOS7::INLINE::_acquire_build_cap($base),
        AMOS7::INLINE::_acquire_build_cap($base)
    );
    check( 'both cap slots held by the test', 2 == grep {defined} @held );
    check( 'a third slot is refused',
        !defined AMOS7::INLINE::_acquire_build_cap($base) );
    my $forks_before = $main::forks;
    compile();
    my $initial = refaddr( \&T::S::bit_string_to_num );
    select undef, undef, undef, 2;
    T::S::bit_string_to_num('1');
    check( 'cap reached : no fork',          $main::forks == $forks_before );
    check( 'cap reached : no build started', !-e "$object.lock" );
    check(
        'cap reached : pure perl answers',
        T::S::bit_string_to_num('101') == 5
    );
    check( 'no upgrade while the cap holds', !wait_upgrade( $initial, 4 ) );
    close $held[0];    ## a slot frees up : a later call retries ##
    check( 'upgrade once a slot is free', wait_upgrade( $initial, 150 ) );
    check( 'compiled sub answers', T::S::bit_string_to_num('1111') == 15 );

} elsif ( $scenario eq 'force' ) {
    my $ref = compile();
    T::S::bit_string_to_num('101') for 1 .. 3;
    select undef, undef, undef, 1.5;
    T::S::bit_string_to_num('101') for 1 .. 3;
    check( 'force_pure_perl : never forks',           $main::forks == 0 );
    check( 'force_pure_perl : no inline dir created', !-e $object );
    check(
        'force_pure_perl : alternative answers',
        T::S::bit_string_to_num('101') == 5
    );
    check(
        'force_pure_perl : no wrapper, no upgrade',
        !defined &AMOS7::INLINE::bit_string_to_num
    );

} elsif ( $scenario eq 'prebuild' ) {
    $ENV{'HOME'} = $base;    ## the cache parent : $base/.7/inline-code ##
    my $parent = AMOS7::INLINE::inline_cache_parent();
    check(
        'cache parent under the throwaway home',
        $parent eq "$base/.7/inline-code"
    );
    my $result = AMOS7::INLINE::prebuild_all();
    check( 'no unavailable reason', !defined $result->{'unavailable'} );
    check( 'every source built',
        ( $result->{'built'} == 5 and $result->{'failed'} == 0 ) );
    ## the compiler tools may fork : a detached builder takes a cap slot ##
    check( 'foreground : no detached builder',
        !glob "$parent/.build-slot.*" );
    my @objects   = grep { -d $ARG and !-l $ARG } glob "$parent/*.*.*";
    my @published = grep { AMOS7::INLINE::_object_published($ARG) } @objects;
    check( 'five published object dirs',
        ( @published == 5 and @objects == 5 ) );
    my $key = AMOS7::INLINE::toolchain_key();
    check(
        'objects carry the toolchain key',
        5 == grep {m|\.\Q$key\E$|} @objects
    );
    check( 'no build dir left',
        0 == grep { -d $ARG } glob "$parent/*.build-*" );
    my $again = AMOS7::INLINE::prebuild_all();
    check( 'second run : all present, loaded only',
        ( $again->{'built'} == 5 and $again->{'failed'} == 0 ) );
    check( 'second run : still no detached builder',
        !glob "$parent/.build-slot.*" );
    check( 'nothing pruned from a clean cache', $again->{'pruned'} == 0 );

} elsif ( $scenario eq 'prune' ) {
    require Fcntl;
    my $parent = "$base/cache";
    mkdir $parent;
    my $key = AMOS7::INLINE::toolchain_key();
    my $old = time - 20 * 86400;
    my %want_gone;
    my %want_kept;
    my $make = sub {
        my ( $name, $age ) = @_;
        mkdir "$parent/$name";
        mkdir "$parent/$name/lib";
        utime $age, $age, "$parent/$name" if defined $age;
        return "$parent/$name";
    };
    $want_gone{ $make->('foo.AAAAAAAAAAAAAAA') } = '2-part form';
    $want_gone{ $make->( 'foo.CCCCCCCCCCCCCCC.OLDKY', $old ) }
        = 'old foreign key';
    $want_kept{ $make->('foo.DDDDDDDDDDDDDDD.NEWKY') } = 'young foreign key';
    $want_kept{ $make->( "foo.EEEEEEEEEEEEEEE.$key", $old ) }
        = 'current key, old';
    $want_kept{ $make->( 'foo.FFFFFFFFFFFF' . 'FFF.build-abc123' ) }
        = 'build dir name';
    ## a lock file next to a removed dir goes with it ##
    open my $gone_lock, '>', "$parent/foo.AAAAAAAAAAAAAAA.lock" or die;
    close $gone_lock;
    ## a link, even named like a 2-part dir, is never followed ##
    mkdir "$base/outside";
    open my $marker, '>', "$base/outside/marker" or die;
    close $marker;
    symlink "$base/outside", "$parent/foo.GGGGGGGGGGGGGGG" or die;
    ## a locked dir : somebody is building \ loading it ##
    my $locked = $make->('foo.HHHHHHHHHHHHHHH');
    open my $lock_fh, '>', "$locked.lock" or die;
    flock $lock_fh, Fcntl::LOCK_EX() | Fcntl::LOCK_NB() or die;
    ## other uid : only a root run can make one ##
    my $foreign;
    if ( $UID == 0 ) {
        $foreign = $make->('foo.IIIIIIIIIIIIIII');
        chown 65534, 65534, $foreign;
    }
    open my $slot, '>', "$parent/.build-slot.0" or die;
    close $slot;

    my $removed = AMOS7::INLINE::prune_cache( { 'parent' => $parent } );
    check( 'two dirs removed',           $removed == 2 );
    check( "removed : $want_gone{$ARG}", !-e $ARG )
        foreach sort keys %want_gone;
    check( "kept : $want_kept{$ARG}", -d $ARG ) foreach sort keys %want_kept;
    check( 'removed dir took its lock file',
        !-e "$parent/foo.AAAA" . "AAAAAAAAAAA.lock" );
    check( 'link kept',             -l "$parent/foo.GGGGGGGGGGGGGGG" );
    check( 'link target untouched', -f "$base/outside/marker" );
    check( 'locked dir kept',       -d $locked );
    check( 'other-uid dir kept',    -d $foreign ) if defined $foreign;
    print "  skip : other-uid dir [ not root ]\n" if not defined $foreign;
    check( 'slot file kept', -e "$parent/.build-slot.0" );
    close $lock_fh;
    my $second = AMOS7::INLINE::prune_cache( { 'parent' => $parent } );
    check( 'lock released : the locked 2-part dir goes',
        ( $second == 1 and !-e $locked ) );
    check( 'the current-key dir still stays after the second run',
        -d "$parent/foo.EEEEEEEEEEEEEEE.$key" );

} elsif ( $scenario =~ m|^trust-| ) {    ## object published by 'upgrade' ##
    check(
        'object from the upgrade scenario present',
        AMOS7::INLINE::_object_published($object)
    );
    my $chksum = AMOS7::INLINE::_object_chksum($object);
    my $stderr = '';
    if ( $scenario eq 'trust-nolist' ) {
        $AMOS7::INLINE::require_trusted = 1;
        compile();
        check(
            'key holder without a list : stays pure perl',
            !defined &AMOS7::INLINE::bit_string_to_num
        );
        check(
            'key holder : alternative answers',
            T::S::bit_string_to_num('101') == 5
        );
        check( 'key holder without a list : no builder', $main::forks == 0 );
    } elsif ( $scenario eq 'trust-listed' ) {
        $AMOS7::INLINE::require_trusted     = 1;
        $AMOS7::INLINE::trusted_objects_ref = { $chksum => 1 };
        compile();
        check(
            'key holder, object on the list : compiled loaded',
            defined &AMOS7::INLINE::bit_string_to_num
        );
        check( 'compiled answers', T::S::bit_string_to_num('1111') == 15 );
    } elsif ( $scenario eq 'trust-foreign' ) {
        $AMOS7::INLINE::require_trusted     = 1;
        $AMOS7::INLINE::trusted_objects_ref = { 'NOT-THIS-ONE' => 1 };
        compile();
        check(
            'key holder, object not on the list : stays pure perl',
            !defined &AMOS7::INLINE::bit_string_to_num
        );
        check( 'alternative answers', T::S::bit_string_to_num('101') == 5 );
        ## trust-plain : not a key holder, a list that does not match ##
    } else {
        $AMOS7::INLINE::trusted_objects_ref = { 'NOT-THIS-ONE' => 1 };
        my $warnings = 0;
        local $SIG{__WARN__}
            = sub { $warnings++ if $ARG[0] =~ m|unverified| };
        no warnings qw| redefine |;
        local *AMOS7::INLINE::warn_err = sub {
            $warnings++ if $ARG[0] =~ m|unverified|;
            return;
        };
        compile();
        check(
            'plain caller, unmatched list : loads anyway',
            defined &AMOS7::INLINE::bit_string_to_num
        );
        check( 'plain caller : one unverified warning', $warnings == 1 );
    }
}

exit( $failed ? 1 : 0 );

#,,,.,,,.,.,.,..,,...,...,,,,,..,,,,.,.,.,,..,..,,...,...,..,,.,,,,..,,,,,,,,,
#EXSIDVX3UY4ZB33ZDG4DZL6RZRZ4YD3LZ6KQ7IDWIX3FMFHHFYKWBRP2MZ5RD5GPXBZL2EUZ47E5Y
#\\\|2SBJXGIADGYZRSL2DDISBS3EPA4SB22OMZUFZOE3D4KQKYJD3IT \ / AMOS7 \ YOURUM ::
#\[7]QDRGYQQQJ3DNREFMQBEEAID2VOB7H6HE3AVWRPCTYT2VISI2BMDQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
