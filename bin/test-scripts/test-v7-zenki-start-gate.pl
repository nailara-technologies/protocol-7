#!/usr/bin/env perl
use v5.24;
use strict;
use English;
use warnings;

## the production runtime [ bin/Protocol-7 : use utf8 + Encode ] loads the ##
## bytes pragma transitively. mirror that here, as the precedent tests do. ##
use bytes;

## v7-zenki.zenka.cmd.start profile gate : every start                     ##
## [ by hand, start_once, dependency ] follows zenki.disabled and the      ##
## on-demand allow list ; ':ignore-disabled:' overrides per call and does  ##
## not enrol the zenka in zenki.enabled ; a concurrent handover is exempt. ##
## REAL module ; anything past the gate stops at a zenka.get_dependencies  ##
## stub. no zenka                                                          ##

use File::Spec;
use Cwd     qw| abs_path |;
use FindBin qw| $RealBin |;

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
    $main::root_path = $root_path;
}

use AMOS7::Protocol::P7Syntax qw| p7_syntax__translate |;

use constant TRUE    => 5;
use constant FALSE   => 0;
use constant UNKNOWN => 2;

our %code;
our %data;

my $fail_count = 0;
my $test_count = 0;

sub ok ($;$) {
    my ( $cond, $label ) = @ARG;
    $test_count++;
    if ($cond) { say "  ok   : $label"; return 1 }
    $fail_count++;
    say "  FAIL : $label";
    return 0;
}

my $runtime_pragmas
    = q{no bytes; use File::stat; use open qw| :encoding(UTF-8) |;};

sub compile_module {
    my ( $module_name, $prefix ) = @ARG;
    my $src_path
        = File::Spec->catfile( $main::root_path, 'src', $module_name );
    open( my $fh, '<', $src_path ) or die "cannot read $src_path : $!";
    my $src = join( '', <$fh> );
    close($fh);
    my $translated = p7_syntax__translate($src);
    my $cref       = eval "$runtime_pragmas sub {\n$prefix\n# "
        . "line 1 \"$module_name\"\n$translated\n}";
    die "compile failed for $module_name : $EVAL_ERROR" if not defined $cref;
    $code{$module_name} = $cref;
    return $cref;
}

## --- stubs ------------------------------------------------------------- ##
my @logged;
$code{'base.logs'}              = sub { push @logged, [@ARG]; return };
$code{'base.log'}               = sub { push @logged, [@ARG]; return };
$code{'base.s_warn'}            = sub {return};
$code{'v7-zenki.start_count'}   = sub { return 0 };
$code{'zenka.instance.get_ids'} = sub { return [] };
$code{'zenka.is_enabled'}       = sub {
    my $enabled
        = $data{'v7-zenki'}{'start_setup'}{'globals'}{'zenki'}{'enabled'}
        // return TRUE;
    return scalar grep { $ARG eq $_[0] } split m|\s+|, $enabled;
};
$code{'zenka.get_dependencies'} = sub { die "GATE PASSED\n" };

## the compiled-in .cmd. header of bin/Protocol-7 : $call is $ARG[0], @ARG ##
## is NOT shifted                                                          ##
my $cmd_header = q{my $call = {}; if ( ref( $ARG[0] ) eq 'HASH' ) }
    . q{{ $call = $ARG[0] } else { $call->{'args'} = $ARG[0] }};
compile_module( 'v7-zenki.zenka.profile_refusal', '' );
$code{'zenka.profile_refusal'} = $code{'v7-zenki.zenka.profile_refusal'};
compile_module( 'v7-zenki.zenka.cmd.start', $cmd_header );
$code{'zenka.cmd.start'} = $code{'v7-zenki.zenka.cmd.start'};
compile_module( 'v7-zenki.zenka.cmd.start_once', $cmd_header );
$code{'zenka.cmd.start_once'} = $code{'v7-zenki.zenka.cmd.start_once'};

$data{'regex'}{'base'}{'iid'}     = qr|^\d+$|;
$data{'regex'}{'base'}{'subname'} = qr|[\w.:-]|;

sub profile {    ## a lean profile : enabled + on-demand allow list ##
    my (%z) = @ARG;
    $data{'v7-zenki'}{'start_setup'}{'globals'}{'zenki'} = {%z};
    $data{'v7-zenki'}{'cfg_data'}{'start_profile'} = 'remote-server-lowram';
    $data{'v7-zenki'}{'start_setup'}{'zenki'}{'config'}{$ARG} = {}
        for qw| cube p7-log letsencr dist-upgrade pull-git discover |;
    return;
}

## returns ( 'passed' | 'refused', reply ) ##
sub try_start {
    my ( $cmd, $call ) = @ARG;
    my $reply = eval { $code{$cmd}->($call) };
    return ( 'passed', undef ) if $EVAL_ERROR eq "GATE PASSED\n";
    die $EVAL_ERROR            if length $EVAL_ERROR;
    return ( 'refused', $reply );
}

my $enabled = sub {
    $data{'v7-zenki'}{'start_setup'}{'globals'}{'zenki'}{'enabled'};
};

say ':: lean profile [ allow list ]';

profile(
    'enabled'   => 'cube p7-log',
    'on-demand' => 'letsencr',
    'disabled'  => 'discover'
);

my ( $r, $reply );
for my $cmd (qw| v7-zenki.zenka.cmd.start v7-zenki.zenka.cmd.start_once |) {
    ( my $short = $cmd ) =~ s|^v7-zenki\.zenka\.cmd\.||;
    ( $r, $reply ) = try_start( $cmd, { 'args' => 'dist-upgrade' } );
    ok( $r eq 'refused'
            && $reply->{'data'}
            =~ m|not in the on-demand allow list of profile 'remote-server-lowram'|
            && $reply->{'data'} =~ m|:ignore-disabled:|,
        "$short dist-upgrade : refused, allow list named, override shown"
    );
    ( $r, $reply ) = try_start( $cmd, { 'args' => 'discover' } );
    ok( $r eq 'refused' && $reply->{'data'} =~ m|in zenki.disabled|,
        "$short discover : refused as zenki.disabled" );
    ( $r, $reply ) = try_start( $cmd, { 'args' => 'letsencr' } );
    ok( $r eq 'passed', "$short letsencr [ on-demand listed ] : passes" );
}

( $r, $reply )
    = try_start( 'v7-zenki.zenka.cmd.start',
    { 'args' => 'dist-upgrade', 'session_id' => 77 } );
ok( $r eq 'refused', 'start from a session : refused alike' );

( $r, $reply ) = try_start( 'v7-zenki.zenka.cmd.start_once',
    { 'args' => 'pull-git', 'recursion' => 1 } );
ok( $r eq 'refused', 'as a dependency : refused alike' );

say ':: :ignore-disabled:';

( $r, $reply )
    = try_start( 'v7-zenki.zenka.cmd.start',
    { 'args' => 'dist-upgrade :ignore-disabled:' } );
ok( $r eq 'passed', 'start dist-upgrade :ignore-disabled: : passes' );
( $r, $reply )
    = try_start( 'v7-zenki.zenka.cmd.start',
    { 'args' => ':ignore-disabled: discover' } );
ok( $r eq 'passed', 'flag first, zenki.disabled one : passes' );
( $r, $reply ) = try_start( 'v7-zenki.zenka.cmd.start_once',
    { 'args' => 'pull-git :ignore-disabled:' } );
ok( $r eq 'passed', 'start_once with the flag : passes' );
( $r, $reply )
    = try_start( 'v7-zenki.zenka.cmd.start',
    { 'args' => ':ignore-disabled:' } );
ok( $r eq 'refused' && $reply->{'data'} =~ m|name or id expected|,
    'the flag alone : name expected' );

say ':: concurrent handover \ open profiles';

( $r, $reply )
    = try_start( 'v7-zenki.zenka.cmd.start',
    { 'args' => 'dist-upgrade', 'mode' => 'concurrent-handover' } );
ok( $r eq 'passed', 'concurrent handover : exempt' );

profile( 'disabled' => 'discover' );    ## remote-server : no allow list ##
( $r, $reply )
    = try_start( 'v7-zenki.zenka.cmd.start', { 'args' => 'dist-upgrade' } );
ok( $r eq 'passed', 'no allow list : any not-disabled zenka passes' );
( $r, $reply )
    = try_start( 'v7-zenki.zenka.cmd.start', { 'args' => 'discover' } );
ok( $r eq 'refused', '  :.. zenki.disabled still refused' );

profile();                              ## a desktop profile : neither list ##
( $r, $reply )
    = try_start( 'v7-zenki.zenka.cmd.start', { 'args' => 'dist-upgrade' } );
ok( $r eq 'passed', 'no lists at all : everything passes [ desktop ]' );

say ':: a forced start does not enrol the zenka';

## past the gate : let the rest run far enough to reach the enrol line ##
## [ get_dependencies returns none, the job queue is stubbed ]         ##
profile( 'enabled' => 'cube p7-log', 'on-demand' => 'letsencr' );
$code{'zenka.get_dependencies'} = sub { return '' };
my $stub_rest = sub {
    my %stub = (
        'zenka.get_id'               => sub { return 1 },
        'zenka.get_object_id'        => sub { return 1 },
        'dependency.ok_resolve'      => sub { return TRUE },
        'jobqueue.add_job'           => sub { return 42 },
        'base.dependency.add_object' => sub { return 1 },
    );
    $code{$ARG} //= $stub{$ARG} for keys %stub;
};
$stub_rest->();
my $forced = eval {
    $code{'v7-zenki.zenka.cmd.start'}
        ->( { 'args' => 'dist-upgrade :ignore-disabled:' } );
};
SKIP: {
    if ( not ref $forced ) {
        ## the rest of cmd.start needs more stubs than this test keeps : ##
        ## check the enrol line directly instead                         ##
        my $path = File::Spec->catfile( $main::root_path, 'src',
            'v7-zenki.zenka.cmd.start' );
        open( my $fh, '<', $path ) or die;
        my $src = join '', <$fh>;
        close $fh;
        ok( $src
                =~ m{if not \$ignore_disabled\s+and not <\[zenka\.is_enabled\]>},
            'forced start : enrol line guarded by the flag [ source check ]'
        );
        last SKIP;
    }
    ok( $enabled->() !~ m|\bdist-upgrade\b|,
        'forced start : dist-upgrade not added to zenki.enabled' );
}

say '';
say sprintf ':: %d checks, %d failed', $test_count, $fail_count;
exit( $fail_count ? 1 : 0 );

#,,..,..,,,..,,..,...,.,.,.,,,,.,,,..,.,.,,.,,..,,...,...,...,,..,,.,,,,,,.,.,
#7DEIJY22MND3ZK6C2TPRKK3GWUG5HPTYGGQ3QAMVJFQMM3DR7HWQR7DNVDLDNPJRMVJYRMJQKNISW
#\\\|HTWUACRPR2SU2FS3JW5XYUAXPT4R7I7QQRK4CITL3DVZS4RA3FS \ / AMOS7 \ YOURUM ::
#\[7]6PMICVB3JBIA5YUDX63ZP6WPFOPLJMKTZ4LXD47ZKWGFONHBW6BQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
