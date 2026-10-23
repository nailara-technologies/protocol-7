#!/usr/bin/env perl
use v5.24;
use strict;
use English;
use warnings;

## managed links                                                            ##
## [ 2026-10-23, stage 1 of  data/md/design/LINK-ZENKI-AND-TRANSPORTS.md ]  ##
## compiles the real link.* modules and drives them with stubs :            ##
## link.session.open's auth \ handshake \ session collaborators are         ##
## scripted recorders, link.transport.ssh-w.open runs a FAKE ssh [ a script ##
## on PATH that records its argv, then pumps stdin -> stdout like ssh -W ], ##
## link.pin.migrate runs against a throwaway ~/.n in a tempdir, and the     ##
## supervisor's event.add_timer / send.local are captured and fired by      ##
## hand. no zenka started, restarted or reloaded, no network, no real ssh,  ##
## no real pin dirs touched.                                                ##

use bytes;

use File::Spec;
use File::Temp qw| tempdir |;
use Cwd        qw| abs_path |;
use FindBin    qw| $RealBin |;
use Socket     qw| AF_UNIX SOCK_STREAM PF_UNSPEC |;

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

use constant TRUE  => 5;
use constant FALSE => 0;

our %code;
our %data;

my $fail_count = 0;
my $pass_count = 0;

sub ok ($;$) {
    my ( $cond, $label ) = @ARG;
    if ($cond) { $pass_count++; say "  ok   : $label"; return }
    $fail_count++;
    say "  FAIL : $label";
    return;
}

sub compile_module {
    my ( $module_name, $prefix ) = @ARG;
    $prefix //= '';
    my $src_path
        = File::Spec->catfile( $main::root_path, 'src', $module_name );
    open( my $fh, '<', $src_path ) or die "cannot read $src_path : $!";
    my $src = join( '', <$fh> );
    close($fh);
    my $translated = p7_syntax__translate($src);
    my $cref
        = eval "sub {\n$prefix\n# line 1 \"$module_name\"\n$translated\n}";
    die "compile failed for $module_name : $EVAL_ERROR"
        if not defined $cref;
    $code{$module_name} = $cref;
    return $cref;
}

## generic stubs ##
my @logged;
$code{'base.logs'} = sub { push @logged, [@ARG]; return };
$code{'base.log'}  = sub {return};
$code{'base.s_warn'}
    = sub { push @logged, [ 0, sprintf( shift, @ARG ) ]; return };

sub logs_containing {
    my $pattern = shift;
    return grep { $ARG->[1] =~ $pattern } @logged;
}

## fake event + watcher [ the shapes base.session.check.close and ##
## base.event.add_timer hand to handlers : w->data ]              ##
package FakeW {
    sub new       { bless { data => $_[1], active => 1 }, $_[0] }
    sub data      { $_[0]->{'data'} }
    sub is_active { $_[0]->{'active'} }
    sub cancel    { $_[0]->{'active'} = 0 }
}

package FakeEvent {
    sub new { bless { w => FakeW->new( $_[1] ) }, $_[0] }
    sub w   { $_[0]->{'w'} }
}

package main;

## ---- link.session.open ---- ##
say 'link.session.open';
my %script;
my @calls;
my @socks;
my $next_sid = 8000;

sub reset_script {
    %script = (
        'auth'      => 'ok',
        'handshake' => 'ok',
        'init'      => 'ok',
        'activate'  => 'ok',
    );
    @calls = ();
    @socks = ();
    %{ $data{'session'} } = ();
    return;
}

$code{'auth.client.auth-keypair.authenticate'} = sub {
    push @calls, [ 'auth', @ARG ];
    if ( $script{'auth'} ne 'ok' ) {
        my $result_out = $ARG[5];
        $result_out->{'class'} = $script{'auth'}
            if ref $result_out eq qw| HASH |;
        return undef;
    }
    return { 'server_pub' => 'stub-binding' };
};
$code{'protocol.protocol-7.link-upgrade.handshake'} = sub {
    push @calls, [ 'handshake', @ARG ];
    return ( 0, { 'error' => $script{'handshake_error'} // 'bad' } )
        if $script{'handshake'} eq 'fail';
    return ( 1, { 'key' => 'stub-link' } );
};
$code{'base.session.init'} = sub {
    push @calls, [ 'session.init', @ARG ];
    return if $script{'init'} eq 'undef';
    my $id = $next_sid++;
    $data{'session'}{$id} = { 'name' => $ARG[3] };
    return $id;
};
$code{'base.session.init_state'} = sub {
    push @calls, [ 'init_state', @ARG ];
    return;
};
$code{'protocol.protocol-7.link-upgrade.client_activate'} = sub {
    push @calls, [ 'activate', @ARG ];
    return $script{'activate'} eq 'ok' ? TRUE : FALSE;
};
$code{'base.session.shutdown'} = sub {
    push @calls, [ 'shutdown', @ARG ];
    delete $data{'session'}{ $ARG[0] };
    return;
};

compile_module('link.session.open');
compile_module('link.session.handshake_class');
my $session_open = $code{'link.session.open'};

sub sock_closed { my $s = shift; return not defined fileno($s) }

sub is_false {
    my ($res) = @ARG;
    return ref $res eq 'HASH' && $res->{'mode'} eq 'false';
}

reset_script();
{
    my $res = $session_open->(
        {   'fd'       => 'x',
            'pin_host' => 'delta',
            'pin_port' => 42,
            'as_user'  => 'remote-fetch'
        }
    );
    ok( $res->{'mode'} eq qw| true | && $res->{'data'} =~ m{^\d+$},
        'success -> ( true, sid )' );
    my @a = grep { $ARG->[0] eq 'auth' } @calls;
    ok( $a[0][5]{'host'} eq 'delta' && $a[0][5]{'port'} == 42,
        'the pin is checked under the record name + cube port'
    );
    my $sid = $res->{'data'};
    ok( $data{'session'}{$sid}{'authenticated'} eq 'yes',
        'session marked authenticated = yes' );
    my @s = grep { $ARG->[0] eq 'session.init' } @calls;
    ok( $s[0][4] eq 'delta', 'the session is named after the record' );
}

reset_script();
$script{'auth'} = 'transport';
{
    my $res = $session_open->(
        {   'fd'       => 'x',
            'pin_host' => 'delta',
            'pin_port' => 42,
            'as_user'  => 'remote-fetch'
        }
    );
    ok( is_false($res) && $res->{'class'} eq qw| transport |,
        'auth failure class transport -> passed through'
    );
}

reset_script();
$script{'auth'} = 'trust';
{
    my $res = $session_open->(
        {   'fd'       => 'x',
            'pin_host' => 'delta',
            'pin_port' => 42,
            'as_user'  => 'remote-fetch'
        }
    );
    ok( is_false($res) && $res->{'class'} eq qw| trust |,
        'auth failure class trust -> passed through'
    );
}

for my $case (
    [ 'no link-upgrade answer',                          qw| transport | ],
    [ 'no link-complete answer',                         qw| transport | ],
    [ 'send failed : broken pipe',                       qw| transport | ],
    [ 'link-upgrade refused : x',                        qw| trust | ],
    [ 'link-complete refused : x',                       qw| trust | ],
    [ 'server_bind_sig NOT valid [ server not proven ]', qw| trust | ],
    [ 'dh failed',                                       qw| trust | ],
) {
    reset_script();
    $script{'handshake'}       = 'fail';
    $script{'handshake_error'} = $case->[0];
    my $res = $session_open->(
        {   'fd'       => 'x',
            'pin_host' => 'delta',
            'pin_port' => 42,
            'as_user'  => 'remote-fetch'
        }
    );
    ok( is_false($res) && $res->{'class'} eq $case->[1],
        "handshake '$case->[0]' -> class $case->[1]"
    );
}

reset_script();
{
    my $res = $session_open->(
        {   'pin_host' => 'delta',
            'pin_port' => 42,
            'as_user'  => 'u'
        }
    );
    ok( is_false($res) && $res->{'class'} eq qw| trust |,
        'missing fd -> false, class trust [ never retry a caller bug ]' );
}

## ---- link.transport.ssh-w.open ---- ##
say 'link.transport.ssh-w.open';

my $tmp_dir  = tempdir( CLEANUP => 1 );
my $log_file = "$tmp_dir/ssh-argv.log";

## the fake ssh : records argv, then pumps stdin -> stdout [ ssh -W shape ] ##
## so an eof on the socketpair end ends it -- the no-orphan rule            ##
{
    open( my $fh, '>', "$tmp_dir/ssh" ) or die $ERRNO;
    print {$fh} <<'FAKE_SSH';
#!/bin/sh
printf '%s\n' "$@" > "$P7_FAKE_SSH_LOG"
exec cat
FAKE_SSH
    close($fh);
    chmod 0755, "$tmp_dir/ssh";
}
$ENV{'PATH'}            = "$tmp_dir:$ENV{'PATH'}";
$ENV{'P7_FAKE_SSH_LOG'} = $log_file;

compile_module('link.record.cube_port');
compile_module('link.transport.ssh-w.open');
my $ssh_w_open = $code{'link.transport.ssh-w.open'};

sub read_argv_log {
    return () if not -f $log_file;
    open( my $fh, '<', $log_file ) or return ();
    my @lines = map { chomp; $_ } <$fh>;
    close($fh);
    return @lines;
}

sub wait_for_argv_log {    ## the child records its argv right after fork ##
    foreach my $try ( 1 .. 40 ) {
        my @lines = read_argv_log();
        return @lines if @lines >= 4;
        select( undef, undef, undef, 0.05 );
    }
    return read_argv_log();
}

sub fake_record {
    my (%over) = @ARG;
    my %fields = (
        'addresses'  => ['delta.example:42'],
        'ssh'        => 'p7user@delta.example',
        'ssh_port'   => 2222,
        'transports' => ['ssh-w'],
        'af'         => '4',
        'link_user'  => 'remote-fetch',
        'roles'      => ['link'],
        %over,
    );
    return { 'name' => 'delta', 'fields' => \%fields };
}

unlink $log_file if -e $log_file;
my ( $w_fd, $w_info ) = $ssh_w_open->( fake_record() );
ok( defined $w_fd, 'ssh-w : stream fd returned' );
ok( ref $w_info eq 'HASH' && $w_info->{'pid'} > 0,
    'ssh-w : child pid tracked' );
my @argv_lines = wait_for_argv_log();
ok( ( grep { $_ eq '-W' } @argv_lines ) && $argv_lines[1] eq '127.0.0.1:42',
    'ssh-w : -W 127.0.0.1:<cube port> first' );
ok( ( grep { $_ eq 'BatchMode=yes' } @argv_lines ), 'ssh-w : BatchMode=yes' );
ok( ( grep { $_ =~ m{^ConnectTimeout=\d+$} } @argv_lines ),
    'ssh-w : ConnectTimeout set' );
ok( ( grep { $_ =~ m{^ServerAliveInterval=\d+$} } @argv_lines ),
    'ssh-w : ServerAliveInterval set' );
ok( ( grep { $_ =~ m{^ServerAliveCountMax=\d+$} } @argv_lines ),
    'ssh-w : ServerAliveCountMax set' );
ok( ( grep { $_ eq '-4' } @argv_lines ), 'ssh-w : af 4 adds -4' );
ok( ( grep { $_ eq '-p' } @argv_lines )
        && $argv_lines[-1] eq 'p7user@delta.example',
    'ssh-w : -p <ssh port> then the target LAST [ no option injection ]'
);

{
    my $bad = fake_record( 'ssh' => '-evil' );
    my ( $fd, $why ) = $ssh_w_open->($bad);
    ok( !defined $fd && length $why,
        'ssh-w : target ' . 'starting with - refused' );
    my $bad_port = fake_record( 'ssh_port' => 99999 );
    ( $fd, $why ) = $ssh_w_open->($bad_port);
    ok( !defined $fd && length $why,
        'ssh-w : out-of-range ' . 'ssh port refused' );
}

{
    unlink $log_file if -e $log_file;
    my ( $fd, $info ) = $ssh_w_open->( fake_record( 'af' => '6' ) );
    my @lines = wait_for_argv_log();
    ok( defined $fd
            && ( grep { $_ eq '-6' } @lines )
            && !( grep { $_ eq '-4' } @lines ),
        'ssh-w : af 6 adds -6, not -4'
    );
    kill qw| TERM |, $info->{'pid'};    ## cleanup : not under test ##

    unlink $log_file if -e $log_file;
    ( $fd, $info ) = $ssh_w_open->( fake_record( 'af' => 'auto' ) );
    @lines = wait_for_argv_log();
    ok( defined $fd && !( grep { $_ eq '-4' || $_ eq '-6' } @lines ),
        'ssh-w : af auto adds neither -4 nor -6' );
    kill qw| TERM |, $info->{'pid'};

    unlink $log_file if -e $log_file;
    $data{'protocol-7'}{'remote'}{'default-port'} = 4242;
    ( $fd, $info )
        = $ssh_w_open->( fake_record( 'addresses' => ['delta.example'] ) );
    @lines = wait_for_argv_log();
    ok( defined $fd && $lines[1] eq '127.0.0.1:4242',
        'ssh-w : port //= protocol-7.remote.default-port'
    );
    kill qw| TERM |, $info->{'pid'};
    delete $data{'protocol-7'};
}

## no orphans : closing the stream end gives the child eof and it exits ##
{
    unlink $log_file if -e $log_file;
    my ( $fd, $info ) = $ssh_w_open->( fake_record() );
    my $pid = $info->{'pid'};
    close($fd);
    my $gone = 0;
    foreach my $try ( 1 .. 40 ) {
        my $reaped = waitpid( $pid, 1 );
        if ( $reaped == $pid ) { $gone = 1; last }
        select( undef, undef, undef, 0.05 );
    }
    ok( $gone,
              'ssh-w : eof on the socketpair end '
            . '-> the child exits [ no orphan ]' );
}

## ---- link.pin.migrate ---- ##
say 'link.pin.migrate';

my $home_dir = "$tmp_dir/home";
my $pin_dir  = "$home_dir/.n/remote-keys/servers";
$code{'base.get_homedir'} = sub { return $home_dir };

sub write_pin {
    my ( $name, $id ) = @ARG;
    File::Path::make_path($pin_dir) if not -d $pin_dir;
    open( my $fh, '>', "$pin_dir/$name" ) or die $ERRNO;
    print {$fh} "$id\n";
    close($fh);
    return;
}

compile_module('link.pin.migrate');
my $pin_migrate = $code{'link.pin.migrate'};

sub reset_pins {
    if ( -d $pin_dir ) {
        unlink glob "$pin_dir/*";
    }
    return;
}

reset_pins();
write_pin( '127.0.0.1_4243.public', 'KEY-ID-ALPHA' );
{
    my ( $ok, $why ) = $pin_migrate->( 'delta', 42 );
    ok( $ok, 'pin.migrate : no pin_from -> true' );
    ok( -f "$pin_dir/127.0.0.1_4243.public" && !-e "$pin_dir/delta_42.public",
        'pin.migrate : no pin_from -> nothing moves [ never guessed ]'
    );
}

{
    my ( $ok, $why ) = $pin_migrate->( 'delta', 42, '127.0.0.1_4243' );
    ok( $ok, 'pin.migrate : pin_from named -> moved' );
    ok( !-e "$pin_dir/127.0.0.1_4243.public" && -f "$pin_dir/delta_42.public",
        'pin.migrate : renamed onto the record name'
    );
    open( my $fh, '<', "$pin_dir/delta_42.public" );
    my $first = <$fh>;
    close($fh);
    ok( $first eq "KEY-ID-ALPHA\n",
        'pin.migrate : the key id ' . 'is kept [ no new TOFU ]' );
    ok( logs_containing(qr{moved}), 'pin.migrate : the move is logged' );
    ( $ok, $why ) = $pin_migrate->( 'delta', 42, '127.0.0.1_4243' );
    ok( $ok, 'pin.migrate : pin_from gone [ moved already ] -> true' );
}

reset_pins();
write_pin( 'delta_42.public',       'KEY-ID-ALPHA' );
write_pin( '127.0.0.1_4243.public', 'KEY-ID-ALPHA' );
write_pin( '127.0.0.1_5151.public', 'KEY-ID-BRAVO' );
{
    my ( $ok, $why ) = $pin_migrate->( 'delta', 42, '127.0.0.1_4243' );
    ok( $ok, 'pin.migrate : both pins, equal ids -> true, left alone' );
    ok( -f "$pin_dir/127.0.0.1_4243.public",
        'pin.migrate : the by-hand pin stays'
    );
    ( $ok, $why ) = $pin_migrate->( 'delta', 42 );
    ok( $ok, 'pin.migrate : an unrelated by-hand pin never blocks a record' );
}

reset_pins();
write_pin( 'delta_42.public',       'KEY-ID-ALPHA' );
write_pin( '127.0.0.1_4243.public', 'KEY-ID-BRAVO' );
{
    my ( $ok, $why ) = $pin_migrate->( 'delta', 42, '127.0.0.1_4243' );
    ok( !$ok && length $why, 'pin.migrate : differing ids -> refused' );
    ok( -f "$pin_dir/delta_42.public" && -f "$pin_dir/127.0.0.1_4243.public",
        'pin.migrate : refusal changes nothing on disk'
    );
    ok( logs_containing(qr{contradicts}),
        'pin.migrate : ' . 'the stop is logged'
    );
}

{
    my ( $ok, $why ) = $pin_migrate->( 'delta', 42, '../etc_42' );
    ok( !$ok, 'pin.migrate : pin_from with a path refused' );
}

{
    my ( $ok, $why ) = $pin_migrate->( 'bad/name', 42 );
    ok( !$ok, 'pin.migrate : bad record name refused' );
    ( $ok, $why ) = $pin_migrate->( 'delta', 70000 );
    ok( !$ok, 'pin.migrate : bad port refused' );
}

## ---- the supervisor ---- ##
say 'link supervisor : failure classes and backoff';

my @records;
$code{'link.records.list'} = sub { return \@records };

my $pin_migrate_script = TRUE;
$code{'link.pin.migrate'} = sub {
    return $pin_migrate_script ? TRUE : ( FALSE, 'pin contradiction' );
};
my $ssh_w_script = 'ok';
$code{'link.transport.ssh-w.open'} = sub {
    return ( undef, { 'why' => 'ssh failed' } ) if $ssh_w_script eq 'fail';
    socketpair( my $a, my $b, AF_UNIX, SOCK_STREAM, PF_UNSPEC )
        or die $ERRNO;
    return ( $a, { 'pid' => 424242 } );
};
my $session_script = { 'mode' => 'true', 'data' => 8001 };
$code{'link.session.open'} = sub {
    push @calls, [ 'session.open', @ARG ];
    return $session_script;
};
$code{'base.open'} = sub {
    return if $ssh_w_script eq 'fail';
    socketpair( my $a, my $b, AF_UNIX, SOCK_STREAM, PF_UNSPEC )
        or die $ERRNO;
    return $a;
};

my @timers;
my @sends;
$code{'event.add_timer'} = sub {
    push @timers, $ARG[0];
    return FakeW->new( $ARG[0]{'data'} );
};
$code{'protocol-7.command.send.local'} = sub {
    push @sends, $ARG[0];
    return 1;
};

compile_module('link.supervisor.teardown');
compile_module('link.supervisor.kill_transport');
compile_module('link.supervisor.retry');
compile_module('link.supervisor.link_down');
compile_module('link.supervisor.connect');
compile_module('link.supervisor.heartbeat_send');
compile_module('link.handler.heartbeat_reply');
compile_module('link.handler.heartbeat_timeout');
compile_module('link.handler.session_rip');
compile_module('link.supervisor.start');

my $connect = $code{'link.supervisor.connect'};

sub reset_supervisor {
    @records            = ();
    @timers             = ();
    @sends              = ();
    @calls              = ();
    @logged             = ();
    $pin_migrate_script = TRUE;
    $ssh_w_script       = 'ok';
    $session_script     = { 'mode'  => 'true', 'data' => 8001 };
    $data{'external'}   = { 'links' => {}, 'cfg'  => {} };
    $data{'link'}       = { 'cfg'   => {}, 'sids' => {}, 'supervisor' => {} };
    $data{'session'}    = {};
    return;
}

sub link_entry { return $data{'external'}{'links'}{'delta'} }

sub timer_named {
    my $desc = shift;
    return grep { ( $ARG->{'desc'} // '' ) =~ $desc } @timers;
}

reset_supervisor();
push( @records,
    fake_record( 'link_user' => 'task-worker', 'transports' => ['ssh-w'] ) );
{
    my $ok = $connect->('delta');
    ok( $ok, 'supervisor : connect succeeds' );
    my $e = link_entry();
    ok( $e->{'state'} eq qw| up | && $e->{'sid'} == 8001,
        'supervisor : state up with the session id'
    );
    my @so = grep { $ARG->[0] eq 'session.open' } @calls;
    ok( $so[0][1]{'pin_host'} eq 'delta' && $so[0][1]{'pin_port'} == 42,
        'supervisor : the pin is the record name + cube port'
    );
    ok( $so[0][1]{'as_user'} eq 'task-worker',
        'supervisor : link_user from the record'
    );
    ok( $data{'session'}{8001}{'rip_handler'} eq 'link.handler.session_rip',
        'supervisor : rip_handler armed for fast death detection'
    );
    ok( $data{'link'}{'sids'}{8001} eq 'delta', 'supervisor : sid mapped' );
    ok( scalar timer_named(qr{heartbeat}), 'supervisor : heartbeat armed' );
    ok( scalar @sends == 1 && $sends[0]{'command'} eq '8001.heart',
        'supervisor : the first heartbeat goes out with the connect'
    );
}

reset_supervisor();
push( @records, fake_record() );
$session_script = {
    'mode'  => 'false',
    'data'  => 'pin mismatch',
    'class' => 'trust'
};
{
    my $ok = $connect->('delta');
    ok( !$ok, 'supervisor : trust failure -> connect false' );
    my $e = link_entry();
    ok( $e->{'state'} eq qw| refused |,
        'supervisor : trust failure -> state refused' );
    my ($retry) = timer_named(qr{retry});
    ok( $retry && $retry->{'after'} >= 30,
        'supervisor : trust failure retries only at the 30 s cap' );
}

reset_supervisor();
push( @records, fake_record() );
$session_script = {
    'mode'  => 'false',
    'data'  => 'no answer',
    'class' => 'transport'
};
{
    $connect->('delta');
    my ($retry) = timer_named(qr{retry});
    ok( link_entry()->{'state'} eq qw| down |
            && $retry
            && $retry->{'after'} >= 0.5
            && $retry->{'after'} < 3,
        'supervisor : transport failure -> backoff from 0.5 s'
    );
    $connect->('delta');    ## second cycle doubles ##
    my ($retry2) = ( timer_named(qr{retry}) )[-1];
    ok( link_entry()->{'attempts'} == 2
            && $retry2->{'after'} >= 1
            && $retry2->{'after'} < 4,
        'supervisor : backoff doubles per attempt'
    );
}

reset_supervisor();
push( @records, fake_record() );
{
    $connect->('delta');
    link_entry()->{'attempts'} = 2;
    $code{'link.handler.heartbeat_reply'}
        ->( { 'params' => { 'name' => 'delta' } } );
    ok( link_entry()->{'attempts'} == 0,
        'supervisor : a heartbeat reply resets the backoff' );
}

reset_supervisor();
push( @records, fake_record() );
{
    $connect->('delta');
    my $pid = fork;
    if ( $pid == 0 ) { sleep 30; CORE::exit 0 }
    link_entry()->{'transport_pid'} = $pid;
    my @shuts0 = grep { $ARG->[0] eq 'shutdown' } @calls;
    $code{'link.handler.heartbeat_timeout'}
        ->( FakeEvent->new( { 'name' => 'delta' } ) );
    my $e = link_entry();
    ok( $e->{'state'} eq qw| down |,
        'supervisor : heartbeat timeout -> link down' );
    my @shuts = grep { $ARG->[0] eq 'shutdown' } @calls;
    ok( @shuts == @shuts0 + 1 && $shuts[-1][1] == 8001,
        'supervisor : the session is shut down with the link'
    );
    my $reaped = waitpid( $pid, 1 );
    ok( $reaped == $pid || ( kill 0, $pid ) == 0,
        'supervisor : the transport child is gone [ no orphan ]' );
    ok( scalar timer_named(qr{retry}),
        'supervisor : the reconnect is scheduled' );
}

reset_supervisor();
push( @records, fake_record() );
{
    $connect->('delta');
    $code{'link.handler.session_rip'}->( FakeEvent->new(8001) )
        ;    ## base.session.check.close shape ##
    ok( link_entry()->{'state'} eq qw| down |,
        'supervisor : session rip -> link down + reconnect' );
    ok( !exists $data{'link'}{'sids'}{8001},
        'supervisor : the rip detaches the sid map'
    );
}

reset_supervisor();
push( @records, fake_record( 'link_user' => '' ) );
{
    $connect->('delta');
    ok( link_entry()->{'state'} eq qw| refused |,
        'supervisor : no link identity -> refused, not a retry spin' );
}

reset_supervisor();
push( @records, fake_record( 'transports' => ['carrier-pigeon'] ) );
{
    $connect->('delta');
    ok( link_entry()->{'state'} eq qw| refused |,
        'supervisor : unknown transport -> refused'
    );
}

reset_supervisor();
{
    $connect->('delta');
    ok( link_entry()->{'state'} eq qw| refused |,
        'supervisor : record gone -> supervision stops'
    );
    ok( !timer_named(qr{retry}), 'supervisor : record gone -> no retry' );
}

reset_supervisor();
$pin_migrate_script = FALSE;
push( @records, fake_record() );
{
    $connect->('delta');
    ok( link_entry()->{'state'} eq qw| refused |,
        'supervisor : pin contradiction -> refused, never a new TOFU' );
    ok( logs_containing(qr{pin continuity refused}),
        'supervisor : the pin stop is logged'
    );
}

reset_supervisor();
push( @records, fake_record() );
$records[0]{'name'} = 'pri.v7.ax';
{
    $connect->('pri.v7.ax');
    ok( $data{'external'}{'links'}{'pri.v7.ax'}{'state'} eq qw| refused |
            && !timer_named(qr{retry}),
        'supervisor : a dotted record name is refused, no retry'
    );
    ok( !grep( { $ARG->[0] eq 'session.open' } @calls ),
        'supervisor : a dotted name opens no session'
    );
}

reset_supervisor();
push( @records, fake_record(), fake_record( 'name' => 'us-east-1' ) );
$records[1]{'name'} = 'us-east-1';
{
    my $n = $code{'link.supervisor.start'}->();
    ok( $n == 2, 'supervisor.start : one cycle per link record' );
    ok( $data{'external'}{'links'}{'delta'}{'state'} eq qw| up |
            && $data{'external'}{'links'}{'us-east-1'}{'state'} eq qw| up |,
        'supervisor.start : both links up'
    );
}

say '';
say "passed : $pass_count  failed : $fail_count";
exit( $fail_count ? 1 : 0 );

#,,,,,,,.,,.,,.,.,..,,,..,,.,,,..,,,,,.,.,...,..,,...,...,,,,,,..,...,.,,,,.,,
#AG53M7MDILJQINOGDONPZLSZEUUHE36D2X2VHGFMREREETCKMSYM2IOTSAGUBDUX3GIBMCVCDUYV4
#\\\|7ORZSCEW23CFEZBCTN7MPPADTD3DWKFZPTM7K7ONAQIQN7IG475 \ / AMOS7 \ YOURUM ::
#\[7]TJL2HMJYGRGKMPEVAJYFZ52CMCW5DEL2JXORIC6DCUCHYOPCVOBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
