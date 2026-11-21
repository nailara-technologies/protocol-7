#!/usr/bin/env perl
use v5.32;
use strict;
use warnings;
use English;

use Test::More;
use FindBin    qw| $RealBin |;
use File::Temp qw| tempdir |;
use IPC::Open3 qw| open3 |;

use lib "$RealBin/../../data/lib-path/pm";
use AMOS7::Protocol::P7Syntax qw| p7_syntax__translate |;
use AMOS7::Assert::Truth;

use constant { TRUE => 5, FALSE => 0, UNKNOWN => 2 };

our %data;
our %code;
our $call;

sub load_src {
    my $name = shift;
    my $path = "$RealBin/../../src/$name";
    open my $fh, '<', $path or die "cannot read $path : $OS_ERROR";
    my $src = join '', <$fh>;
    close $fh;
    my $translated = p7_syntax__translate($src);
    my $sub        = eval "sub {\n# line 1 \"$name\"\n$translated\n}";
    die "compile error in $name : $EVAL_ERROR" if $EVAL_ERROR;
    $code{$name} = $sub;
}

my $tmp  = tempdir( CLEANUP => 1 );
my $xpra = "$tmp/xpra-stub";
open my $xpra_fh, '>', $xpra or die $OS_ERROR;
print {$xpra_fh} "#!/bin/false\n";
close $xpra_fh;
chmod 0700, $xpra or die $OS_ERROR;

$code{'base.log'}  = sub { return TRUE };
$code{'base.logs'} = sub { return TRUE };

load_src('X-11.helper.xpra_server_argv');
my @server_argv = $code{'X-11.helper.xpra_server_argv'}
    ->( $xpra, ':101', "$tmp/xpra-101.sock" );
is_deeply \@server_argv,
    [
    $xpra,                       'start',
    ':101',                      '--daemon=no',
    "--bind=$tmp/xpra-101.sock", '--mdns=no',
    '--notifications=no',        '--dbus-control=no'
    ],
    'xpra server argv uses one explicit unix socket';
ok( !grep( m{bind-tcp|0\.0\.0\.0|\*}, @server_argv ),
    'xpra server argv contains no public listener'
);

my @generated = ( 100, 101 );
$code{'base.gen_id'} = sub {
    my $tracking  = shift;
    my $candidate = shift @generated;
    $candidate++ while $tracking->{$candidate};
    return $candidate;
};
$code{'base.vax-int.encode'} = sub { return 'FORWARD' };
{
    no warnings qw| redefine once |;
    local *AMOS7::Assert::Truth::is_true = sub { return TRUE };
    load_src('X-11.helper.alloc_xvfb_display');
    my ( $display, $label )
        = $code{'X-11.helper.alloc_xvfb_display'}->('odd');
    is $display, 101,         'xpra allocation skips an even display';
    is $label,   'x-FORWARD', 'allocation retains the reference label';
}

my $resource_ok = TRUE;
my $next_dep    = 0;
my @jobs;
$code{'dependency.add_object'} = sub { return ++$next_dep };
$code{'dependency.add'}        = sub { return TRUE };
$code{'dependency.ok'}         = sub { return $resource_ok };
$code{'jobqueue.add_job'}      = sub { push @jobs, shift; return TRUE };
$code{'X-11.helper.alloc_xvfb_display'} = sub { return ( 101, 'x-FORWARD' ) };

load_src('X-11.cmd.forward-start');
load_src('X-11.cmd.forward-list');
load_src('X-11.cmd.forward-attach');

$data{'X-11'}{'bin_path'}{'xpra'}       = $xpra;
$data{'X-11'}{'dev'}{'dimensions_xvfb'} = '1280x720';
$data{'X-11'}{'servers'}                = {};

my @app = ( '/opt/example/app', '--title', 'two words; not a shell' );
$call = { 'args' => \@app };
my $started = $code{'X-11.cmd.forward-start'}->();
is $started->{'mode'}, 'true', 'forward-start accepts an argv array';
is_deeply $data{'X-11'}{'servers'}{':101'}{'app_argv'}, \@app,
    'application argv survives without shell splitting';
is scalar @jobs, 1, 'one asynchronous xpra start job is queued';
is $jobs[0]{'callback_params'}{'mode'}, 'xpra',
    'start job selects the xpra process path';

$call = { 'args' => ['x-FORWARD'] };
my $attach = $code{'X-11.cmd.forward-attach'}->();
is $attach->{'mode'}, 'false',
    'attach refuses before the xpra process has a pid';
$data{'X-11'}{'servers'}{':101'}{'pid'} = 4242;
$attach = $code{'X-11.cmd.forward-attach'}->();
is $attach->{'data'}, 'xpra attach ssh://HOST/101',
    'attach command uses ssh as its transport boundary';

my @spawn_argv;
$code{'base.time'}                         = sub { return 1 };
$code{'base.zenki.report_child_pid'}       = sub { return TRUE };
$code{'event.add_timer'}                   = sub { return TRUE };
$data{'system'}{'kill_list'}               = [];
$data{'X-11'}{'xpra'}{'socket_dir'}        = $tmp;
$data{'X-11'}{'servers'}{':101'}{'dep_id'} = 1;
load_src('X-11.job.start_server');
{
    no warnings qw| redefine once |;
    pipe my $read_fh, my $write_fh or die $OS_ERROR;
    close $write_fh;
    local *main::open3 = sub {
        @spawn_argv = @_[ 3 .. $#ARG ];
        $_[1]       = $read_fh;
        $_[2]       = $read_fh;
        return 31337;
    };
    $code{'X-11.job.start_server'}->(
        {   'params' => {
                'display'  => ':101',
                'mode'     => 'xpra',
                'bin_name' => 'xpra',
                'primary'  => FALSE,
            }
        }
    );
    close $read_fh;
}
is_deeply \@spawn_argv,
    [
    $xpra,                       'start',
    ':101',                      '--daemon=no',
    "--bind=$tmp/xpra-101.sock", '--mdns=no',
    '--notifications=no',        '--dbus-control=no'
    ],
    'job passes xpra directly to open3 without a shell';

$resource_ok = FALSE;
$call        = { 'args' => \@app };
my $refused = $code{'X-11.cmd.forward-start'}->();
is $refused->{'mode'}, 'false', 'insufficient resources refuse start';
like $refused->{'data'}, qr|resource limit|,
    'resource refusal includes a reason';
is scalar @jobs, 2, 'resource refusal queues no process';

$data{'X-11'}{'bin_path'}{'xpra'} = undef;
my $missing = $code{'X-11.cmd.forward-start'}->();
is $missing->{'mode'}, 'false',         'missing xpra refuses forwarding';
is $missing->{'data'}, 'not-installed', 'missing xpra reports not-installed';
is $data{'X-11'}{'xpra'}{'status'}, 'not-installed',
    'mode state records that xpra is not installed';
is scalar @jobs, 2, 'not-installed path queues no process';

done_testing();

#,,,,,,,,,,.,,,,,,,..,.,.,..,,..,,...,.,.,,.,,..,,...,.,,,,.,,..,,.,,,.,.,...,
#FK2IKGVLZLCIR4UV3KMQTDFO32466YQFUN7IREHBDG6UPO6AI2QWRZSSDUATIHCNJHQ3BOIMDBKLQ
#\\\|IE3UWX73UT2CL5B7ODS5OJDPWVKTUN4YBIQOEZJCK5QBEZQAHAE \ / AMOS7 \ YOURUM ::
#\[7]ZY6KVFGBF3BOHY3KOXJUUP47L5LVGST3L743YN7QMAAHWUF74CCQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
