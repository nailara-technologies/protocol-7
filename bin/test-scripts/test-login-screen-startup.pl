#!/usr/bin/env perl
use v5.32;
use strict;
use English;
use warnings;
use File::Spec;
use FindBin     qw| $RealBin |;
use Cwd         qw| abs_path |;
use POSIX       qw| WNOHANG |;
use Time::HiRes qw| sleep |;
use Socket;

use constant { TRUE => 5, FALSE => 0 };

BEGIN {
    my $up   = File::Spec->updir;
    my $root = abs_path( File::Spec->catdir( $RealBin, $up, $up ) );
    $main::root_path = $root;
    unshift @INC, File::Spec->catdir( $root, qw| data lib-path pm | );
}
use AMOS7::Protocol::P7Syntax qw| p7_syntax__translate |;

our %data;
our %code;
our @ARG;

my $checks = 0;
my $failed = 0;

sub ok {
    my ( $cond, $label ) = @ARG;
    $checks++;
    if ($cond) { say "ok   : $label"; return TRUE }
    $failed++;
    say "FAIL : $label";
    return FALSE;
}

sub compile_module {
    my ($name) = @ARG;
    my $path = File::Spec->catfile( $main::root_path, 'src', $name );
    open( my $fh, '<:raw', $path ) or die "cannot read $name";
    my $source = join( '', <$fh> );
    close($fh);
    my $compiled = eval 'sub { ' . p7_syntax__translate($source) . ' }';
    die "$name compile : $EVAL_ERROR" if not $compiled;
    return $compiled;
}

my $execute = compile_module('base.execute_zenka_code');
my $watch   = compile_module('login-screen.handler.helper_watch');

$code{'base.list_matches'}        = sub { return FALSE };
$code{'base.check_cfg_cmd_alias'} = sub { return $ARG[0] };
$code{'base.sort'}                = sub {
    my ($arg) = @ARG;
    return ref($arg) eq 'HASH' ? sort keys %{$arg} : ();
};
$code{'base.logs'}         = sub { return TRUE };
$code{'base.log'}          = sub { return TRUE };
$code{'base.s_warn'}       = sub { return TRUE };
$code{'base.cnt_s'}        = sub { return 'lines' };
$code{'base.format_error'} = sub { return ( $ARG[0] // 'error' ) };
$code{'base.agent_code.handler.sig_warn.end_proc'} = sub { return TRUE };

my $exited = 0;
my $after  = 0;
$code{'base.exit'}     = sub { $exited++; die "fixture exit\n" };
$code{'fixture.fail'}  = sub { die "fixture failure\n" };
$code{'fixture.after'} = sub { $after++; return TRUE };

my $status = eval {
    $execute->(
        '$code{\'fixture.fail\'}->();',
        '$code{\'fixture.after\'}->();'
    );
};
ok( $after == 1 && $exited == 0,
    'ordinary config exceptions retain existing nonfatal behavior' );
ok( !$status, 'ordinary exception still marks config execution failed' );

$after = 0;
eval {
    $execute->(
        '$code{\'fixture.fail\'}->() or $code{\'base.exit\'}->(1);',
        '$code{\'fixture.after\'}->();'
    );
};
ok( $exited == 1 && $after == 0,
    'explicit base.exit makes a setup exception fatal' );

$code{'fixture.false'} = sub { return FALSE };
eval {
    $execute->(
        '$code{\'fixture.false\'}->() or $code{\'base.exit\'}->(1);',
        '$code{\'fixture.after\'}->();'
    );
};
ok( $exited >= 2 && $after == 0,
    'explicit base.exit also handles a false setup return' );

{

    package Gtk3;
    sub main_quit { $main::gtk_quit++; return 5 }
}
$code{'base.logs'}                          = sub { return TRUE };
$data{'login-screen'}{'auth_helper'}{'pid'} = $PID;
$main::gtk_quit                             = 0;
my $alive = $watch->();
ok( $alive && !$main::gtk_quit,
    'negative waitpid on a live non-child is not helper death' );

my $child = fork();
die 'cannot fork helper fixture' if not defined $child;
POSIX::_exit(0)                  if $child == 0;
$data{'login-screen'}{'auth_helper'}{'pid'} = $child;
my $rounds = 0;
while ( !$main::gtk_quit && $rounds++ < 100 ) {
    $watch->();
    sleep(0.02) if !$main::gtk_quit;
}
ok( $main::gtk_quit == 1, 'actual helper exit still stops the greeter' );
ok( !defined $data{'login-screen'}{'auth_helper'}{'pid'},
    'actual helper exit clears the watched pid'
);

my $lock_command = compile_module('login-screen.cmd.lock');
my $state_reply  = compile_module('login-screen.handler.session_state_reply');
my @locked_users;
$code{'login-screen.show_lock'} = sub {
    push @locked_users, $ARG[0];
    $data{'login-screen'}{'state'} = 'locked';
    return TRUE;
};
$code{'login-screen.show_greeter'} = sub {
    $data{'login-screen'}{'state'} = 'greeter';
    return TRUE;
};
$code{'base.reply.mode_text'} = sub { return ( 'true', $ARG[0]->{'text'} ) };

$data{'login-screen'}{'state'} = 'greeter';
my $lock_reply = $lock_command->();
ok( $lock_reply->{'mode'} eq 'false' && !@locked_users,
    'manual lock is refused without an active session'
);
$data{'login-screen'}{'state'}        = 'session';
$data{'login-screen'}{'session_user'} = 'testuser';
$lock_reply                           = $lock_command->();
ok( $lock_reply->{'mode'} eq 'true'
        && "@locked_users" eq 'testuser'
        && $data{'login-screen'}{'state'} eq 'locked',
    'manual lock enters lock state for the session user'
);
$data{'login-screen'}{'state'} = 'init';
$state_reply->( { 'cmd' => 'TRUE', 'text' => 'locked testuser' } );
ok( $data{'login-screen'}{'state'} eq 'locked'
        && $locked_users[-1] eq 'testuser',
    'greeter restart restores a locked session directly'
);
$data{'login-screen'}{'state'} = 'init';
$state_reply->( { 'cmd' => 'TRUE', 'text' => 'active testuser' } );
ok( $data{'login-screen'}{'state'} eq 'session'
        && $data{'login-screen'}{'session_user'} eq 'testuser',
    'active startup reply stays hidden and retains the session user'
);

{

    package Glib::Timeout;

    sub add {
        my ( $class, $milliseconds, $callback ) = @ARG;
        return $callback->() if not $main::queue_lock_timers;
        my $id = scalar(@main::lock_timers) + 1;
        push @main::lock_timers,
            { 'id' => $id, 'ms' => $milliseconds, 'callback' => $callback };
        return $id;
    }

    package LoginScreenStartupTest::Widget;
    sub new           { return bless { 'text' => '' }, shift }
    sub get_text      { return $ARG[0]->{'text'} }
    sub set_text      { $ARG[0]->{'text'} = $ARG[1]; return 5 }
    sub set_sensitive { return 5 }
    sub set_label     { return 5 }

    package LoginScreenStartupTest::Window;
    sub new  { return bless { 'hidden' => 0 }, shift }
    sub hide { $ARG[0]->{'hidden'}++; return 5 }
}
require File::Temp;
my $unlock_tmp = File::Temp::tempdir( CLEANUP => 1 );
my $mode_path  = File::Spec->catfile( $unlock_tmp, 'mode' );
socketpair( my $client, my $server, AF_UNIX(), SOCK_STREAM(), PF_UNSPEC() )
    or die 'cannot create unlock fixture socket';
binmode( $client, ':raw' );
binmode( $server, ':raw' );
my $helper = fork();
die 'cannot fork unlock fixture' if not defined $helper;

if ( $helper == 0 ) {
    close($client);
    sysread( $server, my $header, 4 ) == 4 or POSIX::_exit(120);
    my $length = unpack( 'N', $header );
    sysread( $server, my $frame, $length ) == $length or POSIX::_exit(121);
    my ( undef, undef, $mode ) = unpack( 'n/a* n/a* C', $frame );
    open( my $mode_fh, '>:raw', $mode_path ) or POSIX::_exit(122);
    print {$mode_fh} $mode;
    close($mode_fh);
    syswrite( $server, "OK\n" );
    close($server);
    POSIX::_exit(0);
}
close($server);
$data{'login-screen'}{'state'}             = 'locked';
$data{'login-screen'}{'session_user'}      = 'testuser';
$data{'login-screen'}{'auth_in_flight'}    = FALSE;
$data{'login-screen'}{'lock'}{'grabbed'}   = TRUE;
$data{'login-screen'}{'auth_helper'}{'fh'} = $client;
$data{'login-screen'}{'widget'}{'user'} = LoginScreenStartupTest::Widget->new;
$data{'login-screen'}{'widget'}{'password'}
    = LoginScreenStartupTest::Widget->new;
$data{'login-screen'}{'widget'}{'password'}->set_text('secret');
$data{'login-screen'}{'widget'}{'button'}
    = LoginScreenStartupTest::Widget->new;
$data{'login-screen'}{'widget'}{'status'}
    = LoginScreenStartupTest::Widget->new;
$data{'login-screen'}{'window'} = LoginScreenStartupTest::Window->new;
my $released = 0;
my @unlock_sent;
$code{'login-screen.release_lock'} = sub { $released++; return TRUE };
$code{'protocol-7.route-send'}
    = sub { push @unlock_sent, $ARG[0]; return TRUE };
my $authenticate = compile_module('login-screen.authenticate');
$authenticate->();
close($client);
waitpid( $helper, 0 );
open( my $mode_fh, '<:raw', $mode_path ) or die 'missing unlock mode';
my $unlock_mode = <$mode_fh>;
close($mode_fh);
ok( $unlock_mode eq '1', 'unlock uses the helper verify-only request mode' );
ok( $released == 1
        && $data{'login-screen'}{'state'} eq 'session'
        && $data{'login-screen'}{'window'}->{'hidden'} == 1,
    'successful unlock releases the lock and hides the window'
);
ok( @unlock_sent == 1
        && $unlock_sent[0]->{'command'} eq 'v7-zenki.login-session-locked no',
    'successful unlock clears v7 state without starting a session'
);

our @lock_timers;
our @removed_timers;
our @lock_curves;
our @cancelled_curves;
$main::queue_lock_timers = TRUE;
{

    package Glib::Source;

    sub remove {
        push @main::removed_timers, $ARG[0];
        return 5;
    }

    package LoginScreenStartupTest::Widget;
    sub set_opacity  { $ARG[0]->{'opacity'} = $ARG[1]; return 5 }
    sub get_opacity  { return $ARG[0]->{'opacity'} // 1 }
    sub set_visible  { return 5 }
    sub set_editable { return 5 }
    sub show         { return 5 }
    sub hide         { return 5 }

    package LoginScreenStartupTest::Window;
    sub set_keep_above { return 5 }
    sub fullscreen     { return 5 }
    sub set_opacity    { $ARG[0]->{'opacity'} = $ARG[1]; return 5 }
    sub get_opacity    { return $ARG[0]->{'opacity'} // 1 }
    sub show_all       { return 5 }
    sub present        { return 5 }
    sub get_window     { return undef }
}
my $show_lock     = compile_module('login-screen.show_lock');
my $lock_activity = compile_module('login-screen.handler.lock_activity');
my $release_lock  = compile_module('login-screen.release_lock');
$code{'login-screen.handler.lock_grab'} = sub { return FALSE };
$code{'login-screen.release_lock'}      = $release_lock;
$code{'base.curve.register'}
    = sub { push @lock_curves, $ARG[0]; return TRUE };
$code{'base.curve.cancel'}
    = sub { push @cancelled_curves, $ARG[0]; return TRUE };
$data{'login-screen'}{'widget'}{'panel'}
    = LoginScreenStartupTest::Widget->new;
$data{'login-screen'}{'widget'}{'user_label'}
    = LoginScreenStartupTest::Widget->new;
$data{'login-screen'}{'widget'}{'time'}
    = LoginScreenStartupTest::Widget->new;
$data{'login-screen'}{'window'} = LoginScreenStartupTest::Window->new;

sub reset_lock_fixtures {
    @lock_timers                  = ();
    @removed_timers               = ();
    @lock_curves                  = ();
    @cancelled_curves             = ();
    @unlock_sent                  = ();
    $data{'login-screen'}{'lock'} = {};
}

reset_lock_fixtures();
$show_lock->('testuser');
ok( $lock_curves[0]->{'duration'} == 1.7,
    'lock window fade defaults to 1.7 seconds'
);
$lock_curves[0]->{'on_done'}->();
my ($blank_timer) = grep { $ARG->{'ms'} == 1200 } @lock_timers;
ok( defined $blank_timer && !@unlock_sent,
    'fade-in schedules the default blank delay without immediate dpms' );
$blank_timer->{'callback'}->();
my $panel_fade = $lock_curves[-1];
ok( $panel_fade->{'id'} eq 'login_screen_lock_panel_fade'
        && $panel_fade->{'to'} == 0
        && $panel_fade->{'duration'} == 3.6,
    'blank delay starts the slow panel-only fade-out'
);
$panel_fade->{'callback'}->(0.4);
ok( $data{'login-screen'}{'widget'}{'panel'}->get_opacity() == 0.4
        && $data{'login-screen'}{'window'}->get_opacity() == 0.995
        && !@unlock_sent,
    'panel fade never lowers the covering window or blanks early'
);
$lock_activity->();
ok( $lock_curves[-1]->{'from'} == 0.4
        && $lock_curves[-1]->{'to'} == 1
        && $lock_curves[-1]->{'duration'} == 0.5
        && scalar(
        grep { $ARG eq 'login_screen_lock_panel_fade' } @cancelled_curves
        ),
    'lock activity restores the panel from its current opacity over 0.5 s'
);
ok( scalar( grep { $ARG->{'ms'} == 1200 } @lock_timers ) == 1
        && scalar( grep { $ARG->{'ms'} == 24000 } @lock_timers ) == 1,
    'lock activity restarts the delay with the longer input delay'
);
$lock_curves[-1]->{'on_done'}->();
($blank_timer) = grep { $ARG->{'ms'} == 24000 } @lock_timers;
$blank_timer->{'callback'}->();
$lock_curves[-1]->{'on_done'}->();
ok( @unlock_sent == 1
        && $unlock_sent[0]->{'command'} eq 'X-11.dpms-force-off',
    'dpms follows only the completed panel fade-out'
);

reset_lock_fixtures();
$data{'login-screen'}{'lock'}{'blank'} = 'no';
$show_lock->('testuser');
$lock_curves[0]->{'on_done'}->();
ok( !grep( { $ARG->{'ms'} == 1200 } @lock_timers ) && !@unlock_sent,
    'blank = no disables both panel fade-out and dpms'
);

reset_lock_fixtures();
$data{'login-screen'}{'lock'}{'fade_duration'}     = 'bad';
$data{'login-screen'}{'lock'}{'blank_delay'}       = 61;
$data{'login-screen'}{'lock'}{'fade_out_duration'} = 0.1;
$show_lock->('testuser');
$lock_curves[0]->{'on_done'}->();
($blank_timer) = grep { $ARG->{'ms'} == 1200 } @lock_timers;
$blank_timer->{'callback'}->();
ok( $lock_curves[0]->{'duration'} == 1.7
        && $lock_curves[-1]->{'duration'} == 3.6
        && defined $blank_timer,
    'invalid lock fade values fall back to their defaults'
);

$lock_curves[-1]->{'callback'}->(0.3);
$release_lock->();
ok( $data{'login-screen'}{'widget'}{'panel'}->get_opacity() == 1
        && scalar(
        grep { $ARG eq 'login_screen_lock_panel_fade' } @cancelled_curves
        )
        && scalar(@removed_timers) == 2,
    'release cancels every lock timer and curve and restores panel opacity'
);

say '';
say sprintf ':: %d checks, %d failed', $checks, $failed;
exit( $failed ? 1 : 0 );

#,,,.,,..,,..,.,,,,,,,...,,.,,,.,,,..,..,,.,.,..,,...,...,.,.,,..,,.,,,,,,..,,
#UBIFAZQOPWL5I4Q7ZBDX7ENNLB7ZMFIHVUPTK3S54QEXWNSQIZ66DDEWXTLKBGNNW7JMPBUTHSXC6
#\\\|AMIRY476A3UWJHJ4WCRJNHCK5PNKKIQKQFCKLFFJVMAI4RSWK4F \ / AMOS7 \ YOURUM ::
#\[7]ANWFPMIESZYQ7RGZBA2SWC2JYWAQBMMMACG5GFS63MCBO6TW5EDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
