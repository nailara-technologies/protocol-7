#!/usr/bin/perl
use v5.24;
use strict;
use English;
use warnings;

###                                                           ###
##  https POST body accumulation over multi-frame TLS reads    ##
###                                                           ###

## exercises the real translated sources of the input chain [             ##
## base.handler.read, net.read_binary, net.read_linewise_estimated,       ##
## base.handler.input, httpsd.request_handler, httpd.request_handler,     ##
## httpd.http_post, httpd.handler.input.body_remainder,                   ##
## base.event.callback.io-idle-restart ] against an in-process %data /    ##
## %code stub environment with a real socketpair standing in for the      ##
## IO::Socket::SSL session handle [ one 16384 byte read per sysread,      ##
## mirroring the single-TLS-record behaviour of IO::Socket::SSL ].        ##
##                                                                        ##
## scenario A : read-mode binary [ https ] body split over 16 KB frames   ##
## scenario B : read-mode linewise [ http  ] body fed in small chunks     ##
## scenario C : read-mode binary single frame [ small body, direct path ] ##
##                                                                        ##
## success means the route handler receives the exact content-length body ##
## and no error page [ 413 / 414 / 400 ] is generated.                    ##

use File::Spec;
use Cwd           qw| abs_path |;
use FindBin       qw| $RealBin |;
use Socket        qw| AF_UNIX SOCK_STREAM |;
use Fcntl         qw| F_GETFL F_SETFL O_NONBLOCK |;
use HTTP::Request ();
use Scalar::Util  ();
use bytes         ();    ##  bytes::length resolves as function in eval'd code

BEGIN {
    if ( $ENV{P7_TEST_ALARM} ) {
        require Carp;
        $SIG{ALRM}
            = sub { Carp::confess('harness alarm timeout <{C1}>') };
        alarm $ENV{P7_TEST_ALARM};
    }
}

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

##[ https stand-in : real socketpair fd, SSL package name, pending() ]########

package IO::Socket::SSL {
    sub pending        { return 0 }   ##  harness drains per frame instead  ##
    sub get_sslversion { return '' }
    sub get_cipher     { return '' }
}

##[ tied scalar emulating Event var watcher poll 'w' semantics ]##############

my %var_watchers;    ##  refaddr [var ref] => [ watcher, ... ]  ##

package P7Var::Store {

    sub TIESCALAR {
        my ( $class, $var_id ) = @_;
        return bless { value => '', var_id => $var_id }, $class;
    }
    sub FETCH { return shift->{value} }

    sub STORE {
        my ( $self, $new_value ) = @_;
        $self->{value} = $new_value;
        main::trigger_var_watchers( $self->{var_id} );
        return $new_value;
    }
}

package Event::Sim::Watcher {

    sub new {
        my ( $class, %params ) = @_;
        $params{active}    //= 1;
        $params{cancelled} //= 0;
        $params{queued}    //= 0;
        return bless \%params, $class;
    }
    sub w         { return shift }                  ##  event object emulation
    sub data      { return shift->{data} }
    sub desc      { return shift->{desc} // '' }
    sub fd        { return shift->{fd} }
    sub is_active { return shift->{active} ? 1 : 0 }

    sub start {
        my $w = shift;
        $w->{active} = 1 if not $w->{cancelled};
        return;
    }
    sub stop { shift->{active} = 0; return }

    sub cancel {
        my $w = shift;
        $w->{cancelled} = 1;
        $w->{active}    = 0;
        $w->{queued}    = 0;
        return;
    }

    sub again {    ##  explicit schedule : fires even when stopped       ##
        my $w = shift;
        return if $w->{cancelled} or $w->{queued};
        $w->{queued} = 1;
        push main::event_queue()->@*, { w => $w, need_active => 0 };
        return;
    }

    sub fire_on_write {    ##  var write trigger : only while active     ##
        my $w = shift;
        return if $w->{cancelled} or $w->{queued} or not $w->{active};
        $w->{queued} = 1;
        push main::event_queue()->@*, { w => $w, need_active => 1 };
        return;
    }

    sub now {    ##  invoke immediately [ reentrant, like Event ]   ##
        my $w = shift;
        return if $w->{cancelled};
        $w->{queued} = 0;
        main::invoke_watcher($w);
        return;
    }
}

package main;

sub trigger_var_watchers {
    my $var_id = shift;
    foreach my $w ( $var_watchers{$var_id}->@* ) {
        $w->fire_on_write;    ##  write fires active var watchers only  ##
    }
    return;
}

sub register_var_watcher {
    my ( $var_ref, $watcher ) = @_;
    my $var_id = Scalar::Util::refaddr($var_ref);
    $var_watchers{$var_id} //= [];
    push $var_watchers{$var_id}->@*, $watcher;
    return;
}

##[ p7 runtime environment stubs ]############################################

our %data;
our %code;
our $call;

my @event_queue;
sub event_queue { return \@event_queue }

my $invoke_guard = 0;

sub invoke_watcher {
    my $w       = shift;
    my $handler = $w->{handler} // return;
    die "event loop spin [ $handler ] <{C1}>"
        if ++$invoke_guard > 100000;
    $code{$handler}->($w) if exists $code{$handler};
    return;
}

sub drain_events {
    while ( my $entry = shift @event_queue ) {
        my $w = $entry->{w};
        $w->{queued} = 0;
        next if $w->{cancelled};
        next if $entry->{need_active} and not $w->{active};
        invoke_watcher($w);
    }
    return;
}

%code = (
    'base.logs'                 => sub { return TRUE },
    'base.log'                  => sub { return TRUE },
    'base.s_warn'               => sub { return TRUE },
    'base.erase_buffer_content' => sub {
        my $buffer_ref = shift;
        $$buffer_ref = '' if ref $buffer_ref eq qw| SCALAR |;
        return;
    },
    'base.session.calc_cmd_stats' => sub { return 0 },
    'base.str.os_err'             => sub { return '' },

    ##  models IO::Socket::SSL sysread : single TLS record per read  ##
    'base.s_read' => sub {
        my $read_fh    = $ARG[0];
        my $buffer_ref = $ARG[1];
        my $read_len   = $ARG[2];
        binmode( $read_fh, ':raw' );
        my $r_buff;
        my $b_read = sysread( $read_fh, $r_buff,
            $read_len > 16384 ? 16384 : $read_len );
        return 0
            if not defined $b_read
            and ( $OS_ERROR{EAGAIN} or $OS_ERROR{EWOULDBLOCK} );
        return -1 if not defined $b_read;
        if ( $b_read > 0 ) { $$buffer_ref .= $r_buff }
        return $b_read;
    },

    ##  records idle-restart pushes : the resurrection mechanism       ##
    'event.io_idle_restart' => sub {
        my $event = shift;
        push $data{'watcher_list'}{'paused'}->@*, $event;
        $data{'test'}{'idle_restart_pushes'}++;
        return;
    },

    'event.add_var' => sub {
        my $params  = shift;
        my $watcher = Event::Sim::Watcher->new(
            handler => $params->{'handler'},
            data    => $params->{'data'},
            desc    => $params->{'desc'} // '',
            fd      => undef,
        );
        register_var_watcher( $params->{'var'}, $watcher );
        return $watcher;
    },

    ##  error pages are the failure signal : record, do not reply      ##
    'httpd.send_error_page' => sub {
        my ( $id, $error_code ) = @ARG;
        push $data{'test'}{'error_pages'}->@*, $error_code;
        $data{'session'}{$id}{'flush_shutdown'} = TRUE;
        return 2;
    },
);

$data{'size'}{'buffer'}{'input'}        = 242707;
$data{'watcher_list'}{'paused'}         = [];
$data{'system'}{'process_start'}{'pid'} = $$;
$data{'watcher'}{'io'}{'transfer'}
    = Event::Sim::Watcher->new( handler => undef, desc => 'io transfer' );
$data{'http'}{'handler'} = { qw| post | => qw| httpd.http_post | };

##[ module compilation [ same sub-wrapper shape as bin/Protocol-7 ] ]#########

my $fail_count = 0;

sub compile_module {
    my $module_name = shift;
    my $src_path
        = File::Spec->catfile( $main::root_path, 'src', $module_name );
    open( my $fh, '<', $src_path ) or die "cannot read $src_path : $!";
    my $src = join( '', <$fh> );
    close($fh);
    my $translated = p7_syntax__translate($src);
    my $cref       = eval "sub {\n# line 1 \"$module_name\"\n$translated\n}";
    die "compile failed for $module_name : $EVAL_ERROR"
        if not defined $cref;
    $code{$module_name} = $cref;
    return $cref;
}

compile_module($_) foreach qw|
    net.read_binary
    net.read_linewise_estimated
    base.handler.read
    base.handler.input
    httpd.request_handler
    httpd.http_post
    httpd.handler.input.body_remainder
    httpsd.request_handler
    base.event.callback.io-idle-restart
    |;

##[ tiny assertion framework ]################################################

sub ok ($;$) {
    my ( $cond, $label ) = @ARG;
    if ($cond) { say "  ok   : $label"; return }
    $fail_count++;
    say "  FAIL : $label";
    return;
}

sub diag {
    my $label  = shift;
    my $errors = join ',', $data{'test'}{'error_pages'}->@*;
    $errors = 'none' if not length $errors;
    say "  diag : $label : error_pages=[ $errors ] "
        . "route_hits=[ $data{'test'}{'route_hits'} ]";
    return;
}

##[ session + request scaffolding ]###########################################

my $session_counter = 0;
my $body_size       = 30000;
my $request_body    = sprintf '{"jobs":%s}', 'x' x ( $body_size - 9 );
my $request_headers = join( "\r\n",
    'POST /jobs-sync HTTP/1.1',
    'Host: localhost',
    'Authorization: Bearer test-token',
    "Content-Length: $body_size",
    'Connection: close',
    '', '' );

sub new_https_session {
    my ( $read_mode, $ssl_ref ) = @ARG;
    $session_counter++;
    my $id = $session_counter;

    socketpair( my $srv_fh, my $peer_fh, AF_UNIX, SOCK_STREAM, 0 )
        or die "socketpair failed : $OS_ERROR";
    binmode($srv_fh);
    binmode($peer_fh);
    my $srv_flags = fcntl( $srv_fh, F_GETFL, 0 );
    fcntl( $srv_fh, F_SETFL, $srv_flags | O_NONBLOCK );
    bless $srv_fh, qw| IO::Socket::SSL | if $ssl_ref;

    $data{'session'}{$id} = {
        'protocol'       => $ssl_ref ? qw| https | : qw| http |,
        'handle'         => $srv_fh,
        'link'           => $ssl_ref ? qw| ip.ssl | : qw| ip |,
        'mode'           => qw| input |,
        'state'          => 0,
        'complete'       => TRUE,
        'shutdown'       => FALSE,
        'read-mode'      => $read_mode,
        'bytes-to-read'  => 16384,
        'flush_shutdown' => FALSE,
        'start_time'     => time,
        'buffer'         => { qw| input | => '', qw| output | => '' },
        'input'          => { 'handler'   => qw| httpsd.request_handler | },
        'watcher'        => {},
    };

    ##  tie input buffer : writes fire active var watchers [ Event 'w' ]  ##
    my $input_ref = \$data{'session'}{$id}{'buffer'}{'input'};
    tie $data{'session'}{$id}{'buffer'}{'input'}, qw| P7Var::Store |,
        Scalar::Util::refaddr($input_ref);
    $data{'session'}{$id}{'watcher'}{'input_buffer'}
        = Event::Sim::Watcher->new(
        handler => qw| base.handler.input |,
        data    => $id,
        desc    => "[$id] input buffer"
        );
    register_var_watcher( $input_ref,
        $data{'session'}{$id}{'watcher'}{'input_buffer'} );
    $data{'handle'}{$srv_fh} = {
        'link'     => $data{'session'}{$id}{'link'},
        'mode'     => qw| input |,
        'paused'   => FALSE,
        'bytes'    => { qw| in | => 0 },
        'peerhost' => qw| 127.0.0.1 |,
        'peerport' => 4200 + $id,
    };

    $data{'test'}{$id} = {
        peer_fh  => $peer_fh,
        io_event => Event::Sim::Watcher->new(
            handler => qw| base.handler.read |,
            data    => $id,
            fd      => $srv_fh,
            desc    => "[$id] input handler"
        ),
    };

    return $id;
}

sub feed_frame {
    my ( $id, $chunk ) = @ARG;
    my $test = $data{'test'}{$id};
    syswrite( $test->{peer_fh}, $chunk )
        or die "feed write " . "failed : $OS_ERROR";
    $code{'base.handler.read'}->( $test->{io_event} );
    drain_events();
    return;
}

sub loop_idle {
    ##  event loop went idle : fire the real idle-restart callback  ##
    my $idle_w = Event::Sim::Watcher->new(
        handler => qw| base.event.callback.io-idle-restart |,
        desc    => 'idle restart'
    );
    $code{'base.event.callback.io-idle-restart'}->($idle_w);
    drain_events();
    return;
}

sub run_scenario {
    my (%params) = @ARG;
    my $id = new_https_session( $params{read_mode}, $params{ssl_ref} );

    $data{'httpd'}{'route'} = {
        'exact' => { 'POST' => { '/jobs-sync' => 'test.route.jobs-sync' } } };
    $data{'httpd'}{'route_args'}
        = { 'exact' => { 'POST' => { '/jobs-sync' => {} } } };

    $code{'test.route.jobs-sync'} = sub {
        my ( $rid, $rargs ) = @ARG;
        my $session = $data{'session'}{$rid};
        my $body    = $session->{'http'}->{'body'}
            // $session->{'buffer'}->{'input'} // '';
        $data{'test'}{'route_hits'}++;
        $data{'test'}{'route_body'} = $body;
        return 0;
    };

    my $payload = $request_headers . $request_body;
    foreach my $frame ( $payload =~ m|(.{1,$params{frame_size}})|gs ) {
        feed_frame( $id, $frame );
        loop_idle();
        last if $data{'session'}{$id}{'flush_shutdown'};
    }

    return $id;
}

sub reset_test_state {
    delete $data{'test'};
    $data{'test'} = { 'error_pages' => [], 'route_hits' => 0 };
    return;
}

##[ scenario A : https binary, body split over 16 KB frames ]#################

say ': scenario A [ https read-mode binary, 16 KB frames ]';

reset_test_state();
my $id_a = run_scenario(
    read_mode  => qw| binary |,
    ssl_ref    => TRUE,
    frame_size => 16384,
);

ok( ( $data{'test'}{'route_hits'} // 0 ) == 1,
    'route handler dispatched exactly once'
);
ok( ( $data{'test'}{'route_body'} // '' ) eq $request_body,
    'route handler received the full 30000 byte body'
);
ok( ( scalar $data{'test'}{'error_pages'}->@* ) == 0,
    'no error page generated' );
ok( ( not $data{'session'}{$id_a}{'flush_shutdown'} ),
    'session not shut down mid-body' );
diag( 'scenario A', $id_a );

##[ scenario B : http linewise, body fed in small chunks ]####################

say ': scenario B [ http read-mode linewise, 1 KB chunks ]';

reset_test_state();
my $id_b = run_scenario(
    read_mode  => qw| linewise |,
    ssl_ref    => FALSE,
    frame_size => 1024,
);

ok( ( $data{'test'}{'route_hits'} // 0 ) == 1,
    'route handler dispatched exactly once'
);
ok( ( $data{'test'}{'route_body'} // '' ) eq $request_body,
    'route handler received the full 30000 byte body'
);
ok( ( scalar $data{'test'}{'error_pages'}->@* ) == 0,
    'no error page generated' );
diag( 'scenario B', $id_b );

##[ scenario C : small body in a single frame [ direct path ] ]###############

say ': scenario C [ single frame, body complete with headers ]';

reset_test_state();
my $small_body    = '{"jobs":"ok"}';
my $small_headers = join( "\r\n",
    'POST /jobs-sync HTTP/1.1',
    'Host: localhost',
    'Content-Length: ' . length($small_body),
    'Connection: close',
    '', '' );
{
    my $payload = $request_headers;    ##  placate perlcritic-style tools  ##
    $payload = $small_headers . $small_body;
    my $id_c = new_https_session( qw| binary |, TRUE );
    $data{'httpd'}{'route'} = {
        'exact' => { 'POST' => { '/jobs-sync' => 'test.route.jobs-sync' } } };
    $data{'httpd'}{'route_args'}
        = { 'exact' => { 'POST' => { '/jobs-sync' => {} } } };
    $code{'test.route.jobs-sync'} = sub {
        my ( $rid, $rargs ) = @ARG;
        my $session = $data{'session'}{$rid};
        my $body    = $session->{'http'}->{'body'}
            // $session->{'buffer'}->{'input'} // '';
        $data{'test'}{'route_hits'}++;
        $data{'test'}{'route_body'} = $body;
        return 0;
    };
    feed_frame( $id_c, $payload );
    loop_idle();
}

ok( ( $data{'test'}{'route_hits'} // 0 ) == 1,
    'route handler dispatched exactly once'
);
ok( ( $data{'test'}{'route_body'} // '' ) eq $small_body,
    'route handler received the complete small body'
);
ok( ( scalar $data{'test'}{'error_pages'}->@* ) == 0,
    'no error page generated' );

##[ summary ]#################################################################

say '';
if ($fail_count) {
    say "FAILED : $fail_count check[s]";
    exit 1;
}
say 'all checks passed';
exit 0;

#,,.,,..,,,,.,,,,,..,,,.,,,,.,...,..,,.,.,,..,..,,...,...,,..,...,,.,,,,,,,.,,
#GKEPPDQE7VEOVOETRJV5EM7ESELWKLPXLNOFTD4VIIJISDHF7MMJ2IU26DUAHAXJFRKUN4AOD5SQU
#\\\|3IYLK65F375RDSJK3QTKYZILUHUU52A4S6FMKCHKP2WTXST7SCG \ / AMOS7 \ YOURUM ::
#\[7]2XM7LPSLU46TP4BVR54BD2VDEJX52RGUDYLXGAHLJBASS6ASJUDQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
