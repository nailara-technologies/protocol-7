#!/usr/bin/perl
use v5.32.0;
use strict;
use English;
use warnings;

## stage 10 : additive cycles, via relays, locks, state and degraded holders.

use FindBin;
use Fcntl qw| LOCK_EX LOCK_NB |;
use JSON::PP;
BEGIN { unshift @INC, "$FindBin::Bin/../../data/lib-path/pm" }

use AMOS7::N7FS        qw| make_dirs read_file |;
use AMOS7::N7FS::Cycle qw| config_read state_read |;

require "$FindBin::Bin/fixtures/n7fs/helpers.pl";

my $box  = sandbox();
my $base = $box->{'base'};
my ( $root, $hdir, $src ) = @{$box}{qw| root host src |};
my $key  = "$base/root.key";
my $pass = "$base/pass";
write_file( $pass, "cycle pass\ncycle pass\n" );
chmod 0600, $pass or die $OS_ERROR;
make_dirs("$base/tmp");
$ENV{'TMPDIR'} = "$base/tmp";

sub cli {
    my @args = @ARG;
    my $out  = "$base/out";
    my $err  = "$base/err";
    open( my $stdin, '<:raw', -e $pass ? $pass : '/dev/null' )
        or die $OS_ERROR;
    my $pid = fork // die "fork : $OS_ERROR";
    if ( $pid == 0 ) {
        open( STDIN,  '<&',    $stdin ) or exit 98;
        open( STDOUT, '>:raw', $out )   or exit 98;
        open( STDERR, '>:raw', $err )   or exit 98;
        exec( $EXECUTABLE_NAME, "$FindBin::Bin/../n7fs", '-root', $root,
            '-host-dir', $hdir, '-pass-fd', 0, @args )
            or exit 99;
    }
    close $stdin;
    waitpid $pid, 0;
    return ( $CHILD_ERROR >> 8, read_file($out), read_file($err) );
}

my ( $rc, $out, $err ) = cli( 'keygen', "$hdir/host.key" );
( $rc, $out, $err ) = cli( 'keygen', "$hdir/parent.key" );
( $rc, $out, $err ) = cli( 'pubkey', "$hdir/parent.key" );
write_file( "$hdir/trusted-parents", $out );
( $rc, $out, $err ) = cli( 'init', '-name', 'cycle', '-intent', 'sandbox' );
my ($disk)
    = grep { !m|^\.| } do { opendir( my $d, $root ) or die; readdir $d };
( $rc, $out, $err ) = cli( 'attach', $disk );
( $rc, $out, $err )
    = cli( 'root', 'init', $key, '-argon-m', 1024, '-argon-t', 1 );
ok( $rc == 0, 'disk, host keys and service root are ready' )
    or say "$out$err";

my $hub = "$base/hub";
my $far = "$base/far";
make_dirs($ARG) for $hub, $far;
( $rc, $out, $err ) = cli(
    'holder', 'add',       'hub', $hub, '-domain', 'near',
    '-owned', '-root-key', $key
);
ok( $rc == 0, 'direct hub registered' ) or say "$out$err";
( $rc, $out, $err ) = cli(
    'holder', 'add', 'far',       $far, '-domain', 'far',
    '-via',   'hub', '-root-key', $key
);
ok( $rc == 0, 'far holder registered through the hub' ) or say "$out$err";

my $source = "$src/work";
make_dirs("$source/sub");
write_file( "$source/sub/file", "cycle contents\n" );
make_dirs("$hdir/cycle");
write_file( $pass, "cycle pass\n" );
my $config = "$hdir/cycle/work.cfg";
write_file(
    $config,
    join "\n",
    "cycle.work.disk                 = $disk",
    "cycle.work.root-key             : $key",
    "cycle.work.pass-file            = $pass",
    "cycle.work.snapshot.source      : $source",
    "cycle.work.snapshot.method      = copy-verify",
    "cycle.work.snapshot.prefix      : snap",
    "cycle.work.snapshot.staging     = $base/staging",
    "cycle.work.snapshot.shrink-limit : 30",
    "cycle.work.scrub-every          = 1Y2",
    "cycle.work.drill-every          : 1Y1",
    "cycle.work.pending-max          = 3Y3",
    "cycle.work.drill-scratch        : $base/tmp",
    ''
);
chmod 0600, $config or die $OS_ERROR;
my $parsed = config_read( $hdir, 'work' );
ok( $parsed->{'disk'} eq $disk
        && $parsed->{'source'} eq $source
        && $parsed->{'snapshot'} eq 'copy-verify'
        && $parsed->{'prefix'} eq 'snap',
    'prefixed config keys parse with both = and : separators'
);

my @before_hub = holder_blobs($hub);
my @before_far = holder_blobs($far);
( $rc, $out, $err ) = cli( 'cycle', 'work' );
ok( $rc == 1
        && $out =~ m|A1-snapshot ok|
        && $out =~ m|A2-place ok|
        && $out =~ m|A3-relay degraded|
        && $out =~ m|A4-check degraded|
        && $out =~ m|A5-refresh degraded|
        && $out =~ m|A6-drill ok|,
    'the first full additive cycle finishes every step and waits for the push'
) or say "$out$err";
ok( $out !~ m|placed [1-9]\d* nodes on far|
        && scalar( holder_blobs($hub) ) > scalar(@before_hub)
        && !scalar( holder_blobs($far) ),
    'place writes the hub, never the via holder directly'
);
ok( -f "$hdir/cycle/work.state"
        && read_file("$hdir/cycle/work.state") !~ m|^\{|m
        && read_file("$hdir/cycle/work.state")
        =~ m|step.A5-refresh.result\s+: degraded|,
    'cycle state is protocol-7 config with per-step results'
);

my ($list) = glob "$hub/relay-list.*";
ok( defined $list, 'the relay list is published on the hub' );
my $relay   = JSON::PP::decode_json( read_file($list) );
my $far_sub = holder_sub($far);
my $hub_sub = holder_sub($hub);
make_dirs($far_sub) if not defined $far_sub;
$far_sub //= $far;
foreach my $name ( $relay->{'blobs'}->@* ) {
    link "$hub_sub/$name", "$far_sub/$name" or die "push fixture : $OS_ERROR";
}
@before_hub = holder_blobs($hub);
@before_far = holder_blobs($far);
( $rc, $out, $err ) = cli( 'cycle', 'work' );
ok( $rc == 0 && $out =~ m|cycle work : clean|,
    'the next cycle adopts the pushed blobs and exits clean' )
    or say "$out$err";
my %hub_after = map { $ARG => 1 } holder_blobs($hub);
my %far_after = map { $ARG => 1 } holder_blobs($far);
ok( not( grep { not $hub_after{$ARG} } @before_hub )
        && not( grep { not $far_after{$ARG} } @before_far ),
    'cycle holder blob sets only grow'
);
my $state = state_read( $hdir, 'work' );
ok( ( $state->{'last.exit'} // '' ) eq '0'
        && ( $state->{'step.A3-relay.holder.far.result'} // '' ) eq 'ok'
        && ( $state->{'drill.next-due'}                  // 0 ) > 0,
    'state records relay success, the clean exit and next drill due'
);

rename $far, "$far.away" or die "holder outage fixture : $OS_ERROR";
( $rc, $out, $err ) = cli( 'cycle', 'work' );
ok( $rc == 1
        && $out =~ m|holder far : degraded \[ unreachable|
        && $out =~ m|A5-refresh degraded|
        && $out =~ m|A6-drill ok|,
    'an unreachable holder degrades the cycle without hiding other results'
) or say "$out$err";
$state = state_read( $hdir, 'work' );
ok( ( $state->{'step.A5-refresh.holder.hub.result'} // '' ) eq 'ok'
        && ( $state->{ 'step.A5-refresh.' . 'holder.far.result' } // '' ) eq
        'degraded',
    'per-holder state shows the reachable holder completed'
);
rename "$far.away", $far or die "holder restore fixture : $OS_ERROR";

{
    open( my $lock, '>>', "$hdir/cycle/work.lock" ) or die $OS_ERROR;
    flock( $lock, LOCK_EX | LOCK_NB )               or die $OS_ERROR;
    ( $rc, $out, $err ) = cli( 'cycle', 'work' );
    ok( $rc == 3 && $err =~ m|another cycle with this name is running|,
        'a second concurrent run exits 3 busy' )
        or say "$out$err";
    close $lock;
}

rename $key,  "$key.away"  or die $OS_ERROR;
rename $pass, "$pass.away" or die $OS_ERROR;
( $rc, $out, $err ) = cli( 'cycle', 'work', '-status' );
ok( $rc == 0
        && $out =~ m|A0-preflight|
        && $out =~ m|next drill due|
        && $out =~ m|holder drill : current|
        && $out =~ m|attended main-root drill : overdue|
        && $out =~ m|offline-copy drill : overdue|
        && $out !~ m|cycle pass|,
    'cycle -status reads state and all drill cadences without a key'
) or say "$out$err";
rename "$key.away",  $key  or die $OS_ERROR;
rename "$pass.away", $pass or die $OS_ERROR;

{
    local $ENV{'N7FS_TEST_FAULT'} = 'cycle:before-A3-relay';
    ( $rc, $out, $err ) = cli( 'cycle', 'work' );
}
ok( $rc == 2
        && $out =~ m|A3-relay failed|
        && $out =~ m|A4-check|
        && $out =~ m|A5-refresh|,
    'one failed step exits 2 while independent later steps still report'
) or say "$out$err";

write_file( "$hdir/cycle/bad.cfg", "cycle.bad.disk = $disk\n" );
chmod 0600, "$hdir/cycle/bad.cfg" or die $OS_ERROR;
( $rc, $out, $err ) = cli( 'cycle', 'bad' );
ok( $rc == 4 && $err =~ m|needs disk and root-key|,
    'invalid preflight config is refused with exit 4'
) or say "$out$err";

done();

#,,..,,.,,,.,,.,.,.,,,,,,,,..,.,,,,.,,.,.,,,,,..,,...,...,.,.,.,,,,,,,.,.,.,.,
#D2IA4IJMLZPO42I7DFBIMQIXDU2N4XDVLJAXWUYQBX7OMQ7GY2SH72TC7B4KEHBHBT2DLIEMQEUVQ
#\\\|XO5ZTCPTKEFZK7YSJLWQ5L5I5TSB5E3RIB32AIYDUJ22455CPXY \ / AMOS7 \ YOURUM ::
#\[7]MUFFZGSCXKLJI7W3KELVFWKVFTZNHCVCOBBUSKHZKALS3VKLSIDI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
