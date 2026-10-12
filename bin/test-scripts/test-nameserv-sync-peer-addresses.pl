#!/usr/bin/env perl
use v5.24;
use strict;
use English;
use warnings;

## nameserv sync peer address fallback : one shared resolver, ordered       ##
## address lists [ ipv6 first ], a connect timeout per address, fallback to ##
## the next address, remembering the address that worked and one log line   ##
## per peer and family [ 2026-10-12, todo YJP ]. it compiles the real       ##
## src/nameserv.sync.* modules and drives them with stubs : base.logs,      ##
## base.str.os_err, event.add_io, event.add_timer, base.callback.cmd_reply, ##
## base.code.call_optional, a fake  io.socket.ip and a fake getaddrinfo. no ##
## zenka started.                                                           ##

use File::Spec;
use Cwd     qw| abs_path |;
use FindBin qw| $RealBin |;

BEGIN {
    my $root_path = abs_path(
        File::Spec->rel2abs(
            File::Spec->catdir(
                $RealBin, File::Spec->updir, File::Spec->updir
            )
        )
    );
    $main::root_path = $root_path;
}

use constant { TRUE => 5, FALSE => 0, UNKNOWN => 2 };

my $root_path = $main::root_path;

## state ##

our %data;
our %code;

$data{'nameserv'}{'sync'}{'peers'}                  = {};
$data{'nameserv'}{'sync'}{'client'}{'pending'}      = {};
$data{'nameserv'}{'cfg'}{'sync'}{'connect_timeout'} = 7;
$data{'nameserv'}{'cfg'}{'sync'}{'idle_timeout'}    = 390;

my @log_lines;         ## rendered base.logs output ##
my @io_watches;        ## event.add_io registrations ##
my @timers;            ## event.add_timer registrations ##
my $os_err = '';       ## base.str.os_err source ##
my %replies;           ## cmd_reply results by reply id ##
my @optional_calls;    ## on_done calls ##

$code{'base.logs'} = sub {
    my $level = shift;
    my $fmt   = shift;
    push @log_lines, sprintf $fmt, @ARG;
    return 1;
};
$code{'base.s_warn'}     = sub { return 1 };
$code{'base.str.os_err'} = sub { return $os_err };

$code{'event.add_io'} = sub {
    my $params = shift;
    my $w      = TestWatcher->new($params);
    push @io_watches, $w;
    return $w;
};
$code{'event.add_timer'} = sub {
    my $params = shift;
    my $w      = TestWatcher->new($params);
    push @timers, $w;
    return $w;
};
$code{'base.callback.cmd_reply'} = sub {
    my $reply_id = shift;
    my $result   = shift;
    $replies{$reply_id} = $result;
    return 1;
};
$code{'base.code.call_optional'} = sub {
    my $name   = shift;
    my $state  = shift;
    my $result = shift;
    push @optional_calls, [ $name, $result ];
    return 1;
};

package TestWatcher {

    sub new {
        my $class = shift;
        return bless { active => 1, params => shift }, $class;
    }
    sub is_active { return shift->{'active'} }
    sub cancel    { shift->{'active'} = 0; return 1 }
}

package FakeSock {
    use overload '*{}' => sub { shift->{'fh'} };

    sub new {
        my $class = shift;
        my %opt   = @_;
        open my $fh, '>', File::Spec->devnull or die $!;
        return bless {
            fh             => $fh,
            connected      => $opt{'connected'}      // 0,
            connect_result => $opt{'connect_result'} // 0,
            err            => $opt{'err'}            // 'inprogress'
        }, $class;
    }
    sub connected { return shift->{'connected'} }

    sub connect {
        my $self = shift;
        require Errno;
        if ( $self->{'err'} eq 'refused' ) {
            $! = Errno::ECONNREFUSED();
        } elsif ( $self->{'err'} eq 'inprogress' ) {
            $! = Errno::EINPROGRESS();
        }
        return $self->{'connect_result'};
    }
}

package FakeEvent {

    sub new {
        my $class = shift;
        return bless { w => FakeW->new(shift) }, $class;
    }
    sub w { return shift->{'w'} }
}

package FakeW {
    sub new  { my $class = shift; return bless { data => shift }, $class }
    sub data { return shift->{'data'} }
}

package main;

## fake io.socket.ip : the plan per peer host drives the behaviour ##
my %sock_plan;

require IO::Socket::IP;
no warnings 'redefine', 'once';
*IO::Socket::IP::new = sub {
    my $class = shift;
    my %args  = @_;
    my $plan  = $sock_plan{ $args{'PeerHost'} } // 'connect';
    return undef if $plan eq 'fail';
    return FakeSock->new(
        connected      => $plan eq 'connected' ? 1 : 0,
        connect_result => $plan eq 'connected' ? 1 : 0,
        err            => $plan
    );
};

sub fake_event {    ## event.add_* handlers receive the event ##
    my $data = shift;
    return FakeEvent->new($data);
}

## fake getaddrinfo / getnameinfo : canned, no dns ##

my $gai_results = [];
my $gai_calls   = 0;

*Socket::getaddrinfo = sub {
    $gai_calls++;
    return '', @$gai_results;
};
*Socket::getnameinfo = sub {
    my $addr = shift;
    return '', $addr->{'host'}, 7753;
};

## canned lookup : v4 answer first on purpose, ordering must be fixed ##

$gai_results = [
    {   family => Socket::AF_INET(),
        addr   => { host => '161.97.144.6' }
    },
    {   family => Socket::AF_INET6(),
        addr   => { host => '2a02:c207::1' }
    }
];

## module loader : translate p7 syntax, compile as anonymous sub ##

sub translate_code {
    my $code = shift;
    $code =~ s{<\[([A-Za-z][-\w.]*)\]>(?=->)}{chr(36).qq|code{'$1'}|}eg;
    $code =~ s{<\[([A-Za-z][-\w.]*)\]>}{chr(36).qq|code{'$1'}->()|}eg;
    $code =~ s{<([a-z][-\w.]*)>}{
        my @keys = split m|\.|, $1;
        chr(36).qq|data{'| . join( "'}{'", @keys ) . qq|'}|
    }ge;
    return $code;
}

sub load_module {
    my $name = shift;
    my $path = File::Spec->catfile( $root_path, 'src', $name );
    open my $fh, '<', $path or die "cannot read $path : $OS_ERROR";
    local $INPUT_RECORD_SEPARATOR = undef;
    my $src = <$fh>;
    close $fh;

    ## drop signature block [ last 4 lines starting with # ] ##
    $src =~ s{\n#[^\n]*\z}{\n} while $src =~ m{\n#[,\[\\|:][^\n]*\z};

    ## split out strings and comments, translate code segments only ##
    my @seg = split m{('(?:[^'\\]|\\.)*'|"(?:[^"\\]|\\.)*"|\#[^\n]*)}x,
        $src, -1;
    for ( my $i = 0; $i < @seg; $i += 2 ) {
        $seg[$i] = translate_code( $seg[$i] );
    }
    my $translated = join '', @seg;
    warn qq|===== $name =====\n$translated\n| if $ENV{'P7_DEBUG'};

    my $sub = eval "sub { $translated }";
    die "compile error in $name : $EVAL_ERROR" if $EVAL_ERROR;
    $code{$name} = $sub;
    return $sub;
}

for my $mod (
    qw|
    nameserv.sync.addresses
    nameserv.sync.peer.arm
    nameserv.sync.peer.next-addr
    nameserv.sync.peer.handler.connect
    nameserv.sync.peer.handler.timeout
    nameserv.sync.peer.connected
    nameserv.sync.peer.release
    nameserv.sync.peer.fail
    nameserv.sync.client.start
    nameserv.sync.client.next-addr
    nameserv.sync.client.handler.connect
    nameserv.sync.client.handler.connect-timeout
    nameserv.sync.client.connected
    nameserv.sync.client.finish
    |
) {
    load_module($mod);
}

## assertion helpers ##

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

sub timer_like {    ## last registered timer matching a handler name ##
    my $name = shift;
    my @hit  = grep { $ARG->{'params'}{'handler'} eq $name } @timers;
    return scalar @hit ? $hit[-1] : undef;
}

sub unreachable_lines {
    return scalar grep {m|unreachable, using|} @log_lines;
}

## --- the resolver : ordering and literals ---------------------------- ##

my $list = $code{'nameserv.sync.addresses'}->( 'pri.v7.ax', 7753 );

check 'name resolves to two addresses', scalar @$list == 2;
check 'ipv6 ordered first',
    (       $list->[0]{'family'} eq qw| ipv6 |
        and $list->[0]{'host'} eq '2a02:c207::1' );
check 'ipv4 ordered second',
    (       $list->[1]{'family'} eq qw| ipv4 |
        and $list->[1]{'host'} eq '161.97.144.6' );

my $v4 = $code{'nameserv.sync.addresses'}->( '127.0.0.1', 7753 );
$gai_calls = 0;
$v4        = $code{'nameserv.sync.addresses'}->( '127.0.0.1', 7753 );
check 'ipv4 literal is a list of one',
    (       scalar @$v4 == 1
        and $v4->[0]{'family'} eq qw| ipv4 |
        and $v4->[0]{'host'} eq '127.0.0.1' );
check 'literal does not call getaddrinfo', $gai_calls == 0;

my $v6 = $code{'nameserv.sync.addresses'}->( '2001:db8::7', 7753 );
check 'ipv6 literal is a list of one',
    (       scalar @$v6 == 1
        and $v6->[0]{'family'} eq qw| ipv6 |
        and $v6->[0]{'host'} eq '2001:db8::7' );

## --- the peer side : timeout fallback, one-time log, failure path ---- ##

my $peers = $data{'nameserv'}{'sync'}{'peers'};
my $pkey  = 'pri.v7.ax:7753';

$peers->{$pkey} = {
    host       => 'pri.v7.ax',
    port       => 7753,
    ts         => 'ts0',
    backoff    => 13,
    state      => qw| idle |,
    sock       => undef,
    watcher    => undef,
    conn_timer => undef,
    timer      => undef,
    buf        => '',
};
my $peer = $peers->{$pkey};

%sock_plan = (
    '2a02:c207::1' => 'connect',    ## stuck in syn-sent ##
    '161.97.144.6' => 'connect'
);

$code{'nameserv.sync.peer.arm'}->($pkey);

check 'peer armed on the ipv6 address first',
    (       $peer->{'addr_idx'} == 0
        and $peer->{'addrs'}[0]{'family'} eq qw| ipv6 |
        and $peer->{'state'} eq qw| connecting |
        and ref $peer->{'sock'} eq qw| FakeSock | );

my $conn_watch = $io_watches[-1];
check 'connect watcher registered',
    ( ref $conn_watch
        and $conn_watch->{'params'}{'handler'} eq
        qw| nameserv.sync.peer.handler.connect |
        and $conn_watch->{'params'}{'data'} eq $pkey );

my $conn_timer = timer_like(qw| nameserv.sync.peer.handler.timeout |);
check 'connect timeout registered',
    (       ref $conn_timer
        and $conn_timer->{'params'}{'after'} == 7
        and $conn_timer->{'params'}{'data'} eq $pkey );

## simulate the connect timeout handler : ipv6 is dead, fall back ##

$code{'nameserv.sync.peer.handler.timeout'}->( fake_event($pkey) );

check 'timeout fell back to the ipv4 address',
    (       $peer->{'addr_idx'} == 1
        and $peer->{'addrs'}[1]{'family'} eq qw| ipv4 |
        and ref $peer->{'sock'} eq qw| FakeSock | );
check 'old connect watcher cancelled', not $conn_watch->{'active'};
check 'old connect timer cancelled',   not $conn_timer->{'active'};

check 'one fallback log line naming both addresses',
    ( unreachable_lines() == 1
        and $log_lines[-1] eq ': sync peer pri.v7.ax:7753 : ipv6 '
        . '2a02:c207::1 unreachable, using ipv4 '
        . '161.97.144.6' );

## the ipv4 connect times out as well : the existing failure path ##

$code{'nameserv.sync.peer.handler.timeout'}->( fake_event($pkey) );

check 'peer entered the failure path',
    (       $peer->{'state'} eq qw| idle |
        and not defined $peer->{'sock'}
        and scalar grep {m|sync peer pri.v7.ax:7753 failed|} @log_lines );

my $retry_timer = timer_like(qw| nameserv.sync.peer.arm |);
check 'backoff retry timer registered',
    ( ref $retry_timer and $retry_timer->{'params'}{'after'} == 13 );

check 'fallback family still logged only once', unreachable_lines() == 1;

## the backoff timer delivers the event : arm takes data from it ##

@io_watches = ();
$code{'nameserv.sync.peer.arm'}->( fake_event($pkey) );

check 're-armed through the event-delivered key',
    (       $peer->{'state'} eq qw| connecting |
        and $peer->{'addr_idx'} == 0
        and $peer->{'addrs'}[0]{'family'} eq qw| ipv6 |
        and scalar @io_watches == 1 );

## the remembered address is tried first next time ##

$peers->{$pkey}{'state'}       = qw| idle |;
$peers->{$pkey}{'addr_worked'} = '161.97.144.6';
$peers->{$pkey}{'conn_timer'}  = undef;
$peers->{$pkey}{'watcher'}     = undef;
$peers->{$pkey}{'sock'}        = undef;

$code{'nameserv.sync.peer.arm'}->($pkey);

check 'remembered address tried first',
    (       $peer->{'addr_idx'} == 0
        and $peer->{'addrs'}[0]{'host'} eq '161.97.144.6' );

## --- the client side : fallback, finish with error, remembering ------ ##

%sock_plan = (
    '2a02:c207::1' => 'connect',    ## stuck in syn-sent ##
    '161.97.144.6' => 'connect'
);

my $pending = $data{'nameserv'}{'sync'}{'client'}{'pending'};
my $id      = $code{'nameserv.sync.client.start'}->(
    {   host     => 'pri.v7.ax',
        port     => 7754,
        zone     => undef,
        reply_id => 'reply-1'
    }
);

check 'client start returned an id', defined $id;

my $state = $pending->{$id};
check 'client armed on the ipv6 address first',
    (       ref $state
        and $state->{'addr_idx'} == 0
        and $state->{'addrs'}[0]{'family'} eq qw| ipv6 |
        and ref $state->{'sock'} eq qw| FakeSock | );

my $c_conn_timer
    = timer_like(qw| nameserv.sync.client.handler.connect-timeout |);
check 'client connect timeout registered',
    (       ref $c_conn_timer
        and $c_conn_timer->{'params'}{'after'} == 7
        and $c_conn_timer->{'params'}{'data'} eq $id );

## simulate the connect timeout handler ##

$code{'nameserv.sync.client.handler.connect-timeout'}->( fake_event($id) );

check 'client timeout fell back to the ipv4 address',
    (       $state->{'addr_idx'} == 1
        and $state->{'addrs'}[1]{'family'} eq qw| ipv4 |
        and ref $state->{'sock'} eq qw| FakeSock | );

check 'client fallback log names host:port',
    ( unreachable_lines() == 2
        and $log_lines[-1] eq ': sync peer pri.v7.ax:7754 : ipv6 '
        . '2a02:c207::1 unreachable, using ipv4 '
        . '161.97.144.6' );

## the ipv4 attempt errors out : finish with an error, nothing left ##

$sock_plan{'161.97.144.6'} = 'refused';
$os_err = 'Connection refused';

$code{'nameserv.sync.client.handler.connect'}->( fake_event($id) );

check 'client connect failure reached the reply route',
    (       ref $replies{'reply-1'}
        and $replies{'reply-1'}{'mode'} eq qw| false |
        and $replies{'reply-1'}{'data'} eq
        'connect failed : Connection refused' );

check 'client pending cleaned up', not exists $pending->{$id};
check 'last address failure adds no fallback line', unreachable_lines() == 2;

## a literal first address that fails resolves nothing : start refuses ##

%sock_plan = (
    '2a02:c207::1' => 'fail',        ## route dead at connect time ##
    '161.97.144.6' => 'connected'    ## immediate connect ##
);
$os_err = 'Network is unreachable';

my $id2 = $code{'nameserv.sync.client.start'}->(
    {   host     => 'pri.v7.ax',
        port     => 7754,
        zone     => undef,
        reply_id => 'reply-2'
    }
);

my $state2 = $pending->{$id2};
check 'client skipped the dead ipv6 literal',
    (       defined $id2
        and $state2->{'addr_idx'} == 1
        and $state2->{'phase'} eq qw| last-ts |
        and ref $state2->{'sock'} eq qw| FakeSock | );

check 'already-logged family stays silent', unreachable_lines() == 2;

## the working address is remembered : tried first next time ##

check 'client remembered the working address',
    ( $data{'nameserv'}{'sync'}{'client'}{'addr_worked'}{'pri.v7.ax:7754'} eq
        '161.97.144.6' );

my $id3 = $code{'nameserv.sync.client.start'}->(
    {   host     => 'pri.v7.ax',
        port     => 7754,
        zone     => undef,
        reply_id => 'reply-3'
    }
);

check 'client start tries the remembered address first',
    (       defined $id3
        and $pending->{$id3}{'addr_idx'} == 0
        and $pending->{$id3}{'addrs'}[0]{'host'} eq '161.97.144.6' );

say '';
say "passed : $pass_count  failed : $fail_count";
exit( $fail_count ? 1 : 0 );

#,,,,,,.,,.,.,.,,,,,.,.,.,..,,,.,,...,.,,,...,..,,...,...,,.,,,,,,,,.,.,,,.,,,
#WRBUCWE3HVUECGZXUXBQZ4BQUZQVWXC7QVYARSPJUGZTTASJRJOPBUU6FW4KLEINEQHIMLFFMYBGO
#\\\|FB6IN2WWPH6I6ITCPPEDD3M4SGT5T3CLGS2YY4JOIZYGFVGMHOM \ / AMOS7 \ YOURUM ::
#\[7]53I4EWD6F2M23BMQTHXWZY3RWBRTMB5FDE7UWRD4N6Q5KD4RIECQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
