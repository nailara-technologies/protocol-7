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
    sub set_opacity     { $ARG[0]->{'opacity'} = $ARG[1]; return 5 }
    sub get_opacity     { return $ARG[0]->{'opacity'} // 1 }
    sub set_visible     { $ARG[0]->{'visible'} = $ARG[1]; return 5 }
    sub set_editable    { return 5 }
    sub set_from_pixbuf { $ARG[0]->{'pixbuf'} = $ARG[1]; return 5 }
    sub clear           { delete $ARG[0]->{'pixbuf'};    return 5 }
    sub show            { return 5 }
    sub hide            { return 5 }

    package LoginScreenStartupTest::Screen;
    sub new        { return bless {}, shift }
    sub get_width  { return 1920 }
    sub get_height { return 1080 }

    package LoginScreenStartupTest::Window;
    sub set_keep_above { return 5 }
    sub fullscreen     { return 5 }
    sub set_opacity    { $ARG[0]->{'opacity'} = $ARG[1]; return 5 }
    sub get_opacity    { return $ARG[0]->{'opacity'} // 1 }
    sub show_all       { return 5 }
    sub present        { return 5 }
    sub get_window     { return undef }
    sub get_screen     { return $main::lock_screen }

    package Gtk3::Gdk::Pixbuf;

    sub new_from_file_at_scale {
        push @main::image_loads, $ARG[1];
        return undef if $main::image_load_fails;
        return 'session-pixbuf';
    }
}
my $show_lock     = compile_module('login-screen.show_lock');
my $lock_activity = compile_module('login-screen.handler.lock_activity');
my $release_lock  = compile_module('login-screen.release_lock');
my $idle_policy   = compile_module('login-screen.idle_policy');
my $idle_lock_cmd = compile_module('login-screen.cmd.idle-lock');
our $lock_screen = LoginScreenStartupTest::Screen->new;
our @image_loads;
our @lock_logs;
my $snapshot_captures = 0;
$code{'login-screen.handler.lock_grab'} = sub { return FALSE };
$code{'login-screen.release_lock'}      = $release_lock;
$code{'login-screen.idle_policy'}       = $idle_policy;
$code{'login-screen.capture_snapshot'}
    = sub { $snapshot_captures++; return 'pixbuf' };
$code{'login-screen.watch_root'}   = sub { return TRUE };
$code{'login-screen.unwatch_root'} = sub { return TRUE };
$code{'base.log'} = sub { push @lock_logs, $ARG[1]; return TRUE };
$code{'base.curve.register'}
    = sub { push @lock_curves, $ARG[0]; return TRUE };
$code{'base.curve.cancel'}
    = sub { push @cancelled_curves, $ARG[0]; return TRUE };
$data{'login-screen'}{'widget'}{'background'}
    = LoginScreenStartupTest::Widget->new;
$data{'login-screen'}{'widget'}{'snapshot'}
    = LoginScreenStartupTest::Widget->new;
$data{'login-screen'}{'widget'}{'session_image'}
    = LoginScreenStartupTest::Widget->new;
$data{'login-screen'}{'widget'}{'panel'}
    = LoginScreenStartupTest::Widget->new;
$data{'login-screen'}{'widget'}{'user_label'}
    = LoginScreenStartupTest::Widget->new;
$data{'login-screen'}{'widget'}{'time'}
    = LoginScreenStartupTest::Widget->new;
$data{'login-screen'}{'window'} = LoginScreenStartupTest::Window->new;

{

    package LoginScreenStartupTest::IdleX;
    sub new            { return bless { 'idle_ms' => 0 }, shift }
    sub root           { return 1 }
    sub init_extension { return 5 }

    sub MitScreenSaverQueryInfo {
        return ( 'Off', 0, 0, $ARG[0]->{'idle_ms'} );
    }

    package X11::Protocol;
    sub new { return $main::idle_x }
}
our $idle_x = LoginScreenStartupTest::IdleX->new;

sub reset_lock_fixtures {
    @lock_timers                  = ();
    @removed_timers               = ();
    @lock_curves                  = ();
    @cancelled_curves             = ();
    @image_loads                  = ();
    @lock_logs                    = ();
    $snapshot_captures            = 0;
    $main::image_load_fails       = FALSE;
    $data{'login-screen'}{'lock'} = {};
    $idle_x->{'idle_ms'}          = 0;
    $idle_policy->();
    @unlock_sent = ();
}

reset_lock_fixtures();
$show_lock->('testuser');
ok( $lock_curves[0]->{'duration'} == 1.7
        && !grep( { $ARG->{'ms'} == 500 } @lock_timers ),
    'layer fade defaults to 1.7 seconds without the old raise poll'
);
$lock_curves[1]->{'on_done'}->();
ok( !defined $data{'login-screen'}{'lock'}{'snapshot'},
    'snapshot is discarded when its dissolve completes'
);
$lock_curves[0]->{'on_done'}->();
$lock_curves[-1]->{'on_done'}->();
my ($blank_timer) = grep { $ARG->{'ms'} == 1200 } @lock_timers;
ok( defined $blank_timer
        && !
        grep( { $ARG->{'command'} eq 'X-11.dpms-force-off' } @unlock_sent ),
    'controls appear before the default blank delay is scheduled'
);
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
        && !
        grep( { $ARG->{'command'} eq 'X-11.dpms-force-off' } @unlock_sent ),
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
ok( $unlock_sent[-1]->{'command'} eq 'X-11.dpms-force-off',
    'dpms follows only the completed panel fade-out'
);

reset_lock_fixtures();
$data{'login-screen'}{'lock'}{'transition'} = 'fade';
$show_lock->('testuser');
ok( $snapshot_captures == 0
        && !defined $data{'login-screen'}{'lock'}{'snapshot'}
        && !$data{'login-screen'}{'widget'}{'session_image'}{'visible'},
    'fade skips capture and hides the session image'
);

reset_lock_fixtures();
$data{'login-screen'}{'lock'}{'transition'}           = 'image';
$data{'login-screen'}{'lock'}{'image'}                = $0;
$data{'login-screen'}{'lock'}{'snapshot'}             = 'stale-pixbuf';
$data{'login-screen'}{'widget'}{'snapshot'}{'pixbuf'} = 'stale-pixbuf';
$show_lock->('testuser');
ok( $snapshot_captures == 0
        && @image_loads == 1
        && !defined $data{'login-screen'}{'lock'}{'snapshot'}
        && !defined $data{'login-screen'}{'widget'}{'snapshot'}{'pixbuf'}
        && $data{'login-screen'}{'widget'}{'session_image'}{'pixbuf'} eq
        'session-pixbuf'
        && $data{'login-screen'}{'widget'}{'session_image'}{'visible'},
    'image uses the configured file without retaining a screen snapshot'
);
$release_lock->();
ok( !defined $data{'login-screen'}{'widget'}{'session_image'}{'pixbuf'},
    'unlock discards the configured lock image' );

reset_lock_fixtures();
$data{'login-screen'}{'lock'}{'transition'} = 'image';
$data{'login-screen'}{'lock'}{'image'}
    = '/nonexistent/lo' . 'gin-screen-image';
$show_lock->('testuser');
ok( $snapshot_captures == 0
        && @image_loads == 0
        && @lock_logs == 1
        && $lock_logs[0] eq 'lock image unavailable; using dark background'
        && !$data{'login-screen'}{'widget'}{'session_image'}{'visible'},
    'unreadable image falls back to fade with one generic log line'
);

reset_lock_fixtures();
$data{'login-screen'}{'lock'}{'transition'} = 'invalid';
$show_lock->('testuser');
ok( $snapshot_captures == 1
        && @lock_logs == 1
        && $lock_logs[0] eq 'invalid lock transition; using snapshot-fade'
        && $data{'login-screen'}{'lock'}{'snapshot'} eq 'pixbuf',
    'invalid transition logs once and retains snapshot-fade behavior'
);

reset_lock_fixtures();
$data{'login-screen'}{'lock'}{'blank'} = 'no';
$idle_policy->();
@unlock_sent = ();
$show_lock->('testuser');
$lock_curves[0]->{'on_done'}->();
$lock_curves[-1]->{'on_done'}->();
ok( !grep( { $ARG->{'ms'} == 1200 } @lock_timers )
        && !
        grep( { $ARG->{'command'} eq 'X-11.dpms-force-off' } @unlock_sent ),
    'blank = no disables both panel fade-out and dpms'
);

reset_lock_fixtures();
$data{'login-screen'}{'lock'}{'fade_duration'}     = 'bad';
$data{'login-screen'}{'lock'}{'blank_delay'}       = 61;
$data{'login-screen'}{'lock'}{'fade_out_duration'} = 0.1;
$idle_policy->();
@unlock_sent = ();
$show_lock->('testuser');
$lock_curves[0]->{'on_done'}->();
$lock_curves[-1]->{'on_done'}->();
($blank_timer) = grep { $ARG->{'ms'} == 1200 } @lock_timers;
$blank_timer->{'callback'}->();
ok( $lock_curves[0]->{'duration'} == 1.7
        && $lock_curves[-1]->{'duration'} == 3.6
        && defined $blank_timer,
    'invalid lock fade values fall back to their defaults'
);

$lock_curves[-1]->{'callback'}->(0.3);
$data{'login-screen'}{'state'} = 'greeter';
$release_lock->();
ok( $data{'login-screen'}{'widget'}{'panel'}->get_opacity() == 1
        && scalar(
        grep { $ARG eq 'login_screen_lock_panel_fade' } @cancelled_curves
        )
        && scalar(@removed_timers) >= 1,
    'release cancels each pending lock timer and curve and restores the panel'
);

reset_lock_fixtures();
$show_lock->('testuser');
$release_lock->();
ok( $lock_curves[-1]->{'id'} eq 'login_screen_unlock_controls_fade'
        && $data{'login-screen'}{'lock'}{'unlock_fading'}
        && !defined $data{'login-screen'}{'lock'}{'snapshot'},
    'unlock removes controls first without retaining the lock snapshot'
);
$lock_curves[-1]->{'on_done'}->();
ok( $lock_curves[-1]->{'id'} eq 'login_screen_unlock_background_fade',
    'unlock reveals the live desktop only after controls leave'
);
$lock_curves[-1]->{'on_done'}->();
ok( !$data{'login-screen'}{'lock'}{'unlock_fading'}
        && $data{'login-screen'}{'window'}->get_opacity() == 0,
    'completed unlock fade hides the transparent lock window'
);

reset_lock_fixtures();
$data{'login-screen'}{'state'} = 'greeter';
$idle_x->{'idle_ms'} = 770000;
my ($policy_timer) = grep { $ARG->{'ms'} == 1000 } @lock_timers;
$policy_timer->{'callback'}->();
($blank_timer) = grep { $ARG->{'ms'} == 6400 } @lock_timers;
ok( defined $blank_timer,
    'greeter fade starts at blank timeout minus fade duration' );
$blank_timer->{'callback'}->();
$lock_curves[-1]->{'on_done'}->();
ok( !grep( { $ARG->{'command'} eq 'X-11.dpms-force-off' } @unlock_sent ),
    'greeter leaves the exact blank endpoint to the x11 policy'
);

reset_lock_fixtures();
$data{'login-screen'}{'state'}        = 'session';
$data{'login-screen'}{'session_user'} = 'testuser';
$data{'login-screen'}{'idle_lock'}    = 'on';
$idle_policy->();
($policy_timer) = reverse grep { $ARG->{'ms'} == 1000 } @lock_timers;
$idle_x->{'idle_ms'} = 780000;
$policy_timer->{'callback'}->();
ok( $data{'login-screen'}{'state'} eq 'locked'
        && $data{'login-screen'}{'lock'}{'idle_pending'},
    'enabled idle policy locks an idle session at 780 seconds'
);
$data{'login-screen'}{'policy'}{'activity'}->('x11-activity');
ok( $data{'login-screen'}{'state'} eq 'session'
        && !$data{'login-screen'}{'lock'}{'idle_pending'}
        && $unlock_sent[-1]->{'command'} eq 'v7-zenki.login-session-locked '
        . 'no',
    'activity aborts an idle lock before its fade completes'
);
my $idle_reply = $idle_lock_cmd->( { 'args' => '42' } );
ok( $idle_reply->{'mode'} eq 'true'
        && $data{'login-screen'}{'policy'}{'idle_lock'} == 42,
    'idle-lock accepts a runtime timeout in seconds'
);
$idle_reply = $idle_lock_cmd->( { 'args' => '0' } );
ok( $idle_reply->{'mode'} eq 'false'
        && $data{'login-screen'}{'policy'}{'idle_lock'} == 42,
    'idle-lock rejects an invalid timeout without changing policy'
);
$idle_reply = $idle_lock_cmd->( { 'args' => 'off' } );
ok( $idle_reply->{'mode'} eq 'true'
        && $data{'login-screen'}{'policy'}{'idle_lock'} == 0,
    'idle-lock off disables future idle locking'
);

{

    package LoginScreenStartupTest::RootX;
    sub new { return bless { 'events' => [], 'children' => [] }, shift }
    sub handle_input { return 5 }
    sub root         { return 1 }

    sub dequeue_event {
        my $event = shift $ARG[0]->{'events'}->@*;
        return defined $event ? $event->@* : ();
    }

    sub QueryTree {
        $ARG[0]->{'queries'}++;
        return ( 1, 0, $ARG[0]->{'children'}->@* );
    }

    sub GetWindowAttributes {
        $ARG[0]->{'attributes'}++;
        return (
            'map_state' => $ARG[0]->{'mapped'} ? 'Viewable' : 'Unmapped' );
    }

    package LoginScreenStartupTest::RootGdk;
    sub new   { return bless { 'raises' => 0 }, shift }
    sub raise { $ARG[0]->{'raises'}++; return 5 }

    package LoginScreenStartupTest::RootWindow;

    sub new {
        return bless { 'gdk' => LoginScreenStartupTest::RootGdk->new }, shift;
    }
    sub get_window { return $ARG[0]->{'gdk'} }
}
my $lock_root   = compile_module('login-screen.handler.lock_root');
my $root_x      = LoginScreenStartupTest::RootX->new;
my $root_window = LoginScreenStartupTest::RootWindow->new;
$data{'login-screen'}{'state'}                     = 'locked';
$data{'login-screen'}{'window'}                    = $root_window;
$data{'login-screen'}{'lock'}{'root_watch'}{'x'}   = $root_x;
$data{'login-screen'}{'lock'}{'root_watch'}{'xid'} = 42;
$root_x->{'events'}   = [ [ 'name' => 'MapNotify', 'window' => 43 ] ];
$root_x->{'children'} = [ 42, 43 ];
$root_x->{'mapped'}   = 1;
$lock_root->();
ok( $root_window->get_window()->{'raises'} == 1,
    'root watch raises over a mapped window above the lock'
);
$root_x->{'events'}   = [ [ 'name' => 'MapNotify', 'window' => 43 ] ];
$root_x->{'children'} = [ 43, 42 ];
$lock_root->();
ok( $root_window->get_window()->{'raises'} == 1,
    'root watch ignores a mapped window below the lock'
);
$root_x->{'events'}   = [ [ 'name' => 'ConfigureNotify', 'window' => 43 ] ];
$root_x->{'children'} = [ 42, 43 ];
$root_x->{'mapped'}   = 0;
$lock_root->();
ok( $root_window->get_window()->{'raises'} == 1,
    'root watch ignores an unmapped window above the lock'
);

say '';
say sprintf ':: %d checks, %d failed', $checks, $failed;
exit( $failed ? 1 : 0 );

#,,.,,,..,,..,..,,,..,.,.,,,.,,..,..,,.,,,,.,,..,,...,...,.,,,,,,,..,,,,.,...,
#6CXLEQRLE7YV7YSHRZ76AOHHBFV34QUAL5LDYNIBUAYPRNEQI7YRSHVZB5UMMDZBB4ZBQFGIAHP26
#\\\|4ZQTLQS27FOLOWJLN474LIKKD6X7NTSZZAL3ZEEQMRSNLHJBGAL \ / AMOS7 \ YOURUM ::
#\[7]FQB55OBZ7P7DYWATU7ALPLKPIQWTRV3MA227F6TH7CCL6FW36QBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
