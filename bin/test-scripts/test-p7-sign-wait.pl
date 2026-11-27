#!/usr/bin/perl
use v5.32.0;
use strict;
use warnings;
use English;
use File::Temp ();
use FindBin;
use Cwd ();

## p7-sign-wait against fake state files : it ends only on a final state ##

my $root = Cwd::abs_path("$FindBin::RealBin/../..");
my $dir  = File::Temp::tempdir( CLEANUP => 1 );
$ENV{'P7_STATE_DIR'}      = $dir;
$ENV{'P7_SIGN_WAIT_FAST'} = 1;
my ( $ok, $n ) = ( 0, 0 );

sub check {
    my ( $label, $cond ) = @ARG;
    $n++;
    $ok++ if $cond;
    say( ( $cond ? 'ok' : 'NOT ok' ) . " $n : $label" );
}

sub put {
    my ( $job, $body ) = @ARG;
    open( my $fh, '>:raw', "$dir/$job.json.tmp" ) or die $OS_ERROR;
    print {$fh} $body;
    close $fh;
    rename "$dir/$job.json.tmp", "$dir/$job.json";
}

sub run_wait {
    my @args = @ARG;
    my $out  = qx| $root/bin/dev/p7-sign-wait @args 2>&1 |;
    return ( $CHILD_ERROR >> 8, $out );
}

my $j = 'p7-sign-1-1';

## every final state ends the wait : approved 0, the rest 1 ##
foreach my $pair (
    [qw| approved 0 |], [qw| denied 1 |],
    [qw| aborted 1 |],  [qw| failed 1 |]
) {
    put( $j, qq|{"status":"$pair->[0]","paths":["a"],"signed":1}| );
    my ( $rc, $out ) = run_wait( $j, 5 );
    check( "$pair->[0] -> rc $pair->[1]", $rc == $pair->[1] );
}
foreach my $pair ( [qw| committed 0 |], [qw| refused 1 |], [qw| stale 1 |] ) {
    my $c = 'p7-commit-1-1';
    put( $c, qq|{"status":"$pair->[0]"}| );
    my ( $rc, undef ) = run_wait( $c, 5 );
    check( "commit $pair->[0] -> rc $pair->[1]", $rc == $pair->[1] );
}

## non-final phases never end it : the timeout is loud and non-zero ##
foreach my $phase (
    qw| starting versioning preparing queued awaiting-approval signing |) {
    put( $j, qq|{"status":"$phase","pid":$PID}| );
    my ( $rc, $out ) = run_wait( $j, 1 );
    check(
        "$phase : timeout rc 3 and says NOT final",
        $rc == 3 && $out =~ m|TIMEOUT.*NOT final.*\Q$phase\E|
    );
}

## a job that turns approved after a while : waits, then 0 ##
put( $j, qq|{"status":"awaiting-approval","pid":$PID}| );
my $pid = fork();
if ( $pid == 0 ) {
    select( undef, undef, undef, 1.5 );
    put( $j, '{"status":"approved","signed":1,"paths":["a"]}' );
    exit 0;
}
my ( $rc, $out ) = run_wait( $j, 10 );
waitpid $pid, 0;
check( 'waited through awaiting-approval, then approved -> 0',
    $rc == 0 && $out =~ m|approved| );

## the runner exits right after writing its final state : never a crash ##
put( $j, '{"status":"signing","pid":999999999}' );
$pid = fork();
if ( $pid == 0 ) {
    select( undef, undef, undef, 0.03 );
    put( $j, '{"status":"approved","signed":1,"paths":["a"]}' );
    exit 0;
}
( $rc, $out ) = run_wait( $j, 10 );
waitpid $pid, 0;
check( 'dead pid, final state lands in the grace -> approved 0',
    $rc == 0 && $out !~ m|process gone| );

## a dead pid without a final state is a crash : rc 1 ##
put( $j, '{"status":"awaiting-approval","pid":999999999}' );
( $rc, $out ) = run_wait( $j, 5 );
check(
    'dead pid, no final state -> failed rc 1',
    $rc == 1 && $out =~ m|process gone|
);

## base32 ntime ids reach the same state files ##
put( 'p7-sign-AAAAAAA-1', '{"status":"approved"}' );
( $rc, $out ) = run_wait( 'p7-sign-AAAAAAA-1', 5 );
check( 'base32 ntime sign id -> approved rc 0', $rc == 0 );
put( 'p7-commit-AAAAAAA-1', '{"status":"committed"}' );
( $rc, $out ) = run_wait( 'p7-commit-AAAAAAA-1', 5 );
check( 'base32 ntime commit id -> committed rc 0', $rc == 0 );

## a live session registers the wait and its exit guard clears it ##
mkdir "$dir/bin";
my $p7c = "$dir/bin/p7c";
open( my $mock, '>:raw', $p7c ) or die $OS_ERROR;
print {$mock} "#!/bin/sh\nprintf '%s\\n' \"\$*\" >> \"\$P7_OPEN_LOG\"\n";
close $mock;
chmod 0700, $p7c;
$ENV{'P7_OPEN_LOG'} = "$dir/open.log";
local $ENV{'PATH'}                   = "$dir/bin:$ENV{'PATH'}";
local $ENV{'P7_SESSION_NAME'}        = 'sign-live';
local $ENV{'P7_SESSION_REPORT'}      = 'yes';
local $ENV{'CLAUDE_CODE_SESSION_ID'} = '12345678-1234-4234-8234-123456789abc';
put( $j, '{"status":"approved"}' );
( $rc, $out ) = run_wait( $j, 5 );
open( my $open_log, '<:raw', "$dir/open.log" ) or die $OS_ERROR;
my @open_calls = <$open_log>;
close $open_log;
check(
    'sign wait : start registers and exit clears the same sid and id',
    @open_calls == 2
        && $open_calls[0] =~ m{kind=wait id=p7-sign-1-1 clear=0 what=sign_job}
        && $open_calls[1] =~ m{kind=wait id=p7-sign-1-1 clear=1}
        && !grep { !m{sid=12345678-1234-4234-8234-123456789abc} } @open_calls
);
put( 'p7-commit-1-1', '{"status":"committed"}' );
( $rc, $out ) = run_wait( 'p7-commit-1-1', 5 );
open( $open_log, '<:raw', "$dir/open.log" ) or die $OS_ERROR;
my @after_commit = <$open_log>;
close $open_log;
check( 'commit wait : outside the narrow sign-work registration',
    @after_commit == 2 );

## unknown job : rc 2 ##
( $rc, $out ) = run_wait( 'p7-sign-9-9', 10 );
check( 'unknown job -> rc 2', $rc == 2 && $out =~ m|unknown job| );

say "$ok of $n";
exit( $ok == $n ? 0 : 1 );

#,,.,,..,,.,,,.,,,,,.,..,,.,,,,,.,.,.,.,,,,,.,..,,...,...,.,,,...,.,,,,,,,.,.,
#3LHHBQUHU2RG3K6WFMXO2CMHDX6G5A4EGVCFOD3WIB2CIGJZ4IIX32VN5S3SC2NRQY6SKOFNF7OZS
#\\\|LFNUJ4H6XWNBGMLLPNZO53DFUETC7MYGCW4PGU6JWDAQPFJKWNC \ / AMOS7 \ YOURUM ::
#\[7]AUCZ7C27NDXD5MBA4AG6FQZ6BMFBS3D6THVKW6RRKYYEQKUUPECY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
