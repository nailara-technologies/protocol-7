#!/usr/bin/env perl
use v5.24;
use strict;
use English;
use warnings;

## nameserv dns over tcp [ rfc 7766 ] : the framed connection handlers, the ##
## udp truncation path and the nameserv.answer split. compiles the real src ##
## modules and drives them with stubs : base.logs, base.s_read,             ##
## base.s_write, base.str.os_err, event.add_io, event.add_timer and         ##
## nameserv.zone.lookup \ nameserv.handler.p7ref_lookup use real sockets on ##
## 127.0.0.1 only, never port 53. no zenka started.                         ##

use bytes;
use Errno qw| EAGAIN EWOULDBLOCK |;

use File::Spec;
use Cwd     qw| abs_path |;
use FindBin qw| $RealBin |;

use IO::Socket::INET;
use Net::DNS;
use Net::DNS::Packet;
use Net::DNS::RR;

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

use constant TRUE  => 5;
use constant FALSE => 0;

my $root_path = $main::root_path;

STDOUT->autoflush(1);

## state ##

our %data;
our %code;
our %keys;
our $call;

## fake event \ watcher objects [ the zenka uses Event objects ] ##

{

    package FakeEvent;
    sub new  { bless { data => $_[1] }, $_[0] }
    sub w    { $_[0] }
    sub data { $_[0]->{'data'} }
    sub fd   { $_[0]->{'fd'} }
}

{

    package FakeWatcher;
    sub new       { bless { active => 1, params => $_[1] }, $_[0] }
    sub cancel    { $_[0]->{'active'} = 0 }
    sub is_active { $_[0]->{'active'} }
}

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
    nameserv.zone.lookup
    nameserv.handler.p7ref_lookup
    nameserv.answer
    nameserv.handler.query
    nameserv.dns_tcp.close
    nameserv.dns_tcp.handler.timeout
    nameserv.dns_tcp.handler.write
    nameserv.dns_tcp.handler.read
    nameserv.dns_tcp.handler.accept
    |
) {
    load_module($mod);
}

## --- stubs ------------------------------------------------------------- ##

my @logs;
$code{'base.logs'}
    = sub { push @logs, sprintf $_[1] // '', @_[ 2 .. $#_ ]; return TRUE };
$code{'base.str.os_err'} = sub { return "$OS_ERROR" };

## the real base.s_read \ base.s_write, minus the utf8 handling ##
$code{'base.s_read'} = sub {
    my ( $fh, $buffer_ref, $read_len ) = @_;
    my $buff   = '';
    my $b_read = sysread( $fh, $buff, $read_len );
    return 0
        if not defined $b_read
        and ( $OS_ERROR{EAGAIN} or $OS_ERROR{EWOULDBLOCK} );
    return -1             if not defined $b_read;
    $$buffer_ref .= $buff if $b_read > 0;
    return $b_read;
};
$code{'base.s_write'} = sub {
    my ( $fh, $buffer_ref, $write_len ) = @_;
    my $b_written = syswrite( $fh, $$buffer_ref, $write_len );
    return 0
        if not defined $b_written
        and ( $OS_ERROR{EAGAIN} or $OS_ERROR{EWOULDBLOCK} );
    return -1 if not defined $b_written;
    return $b_written;
};

my @io_watchers;
my @timers;
$code{'event.add_io'} = sub {
    my $params = shift;
    push @io_watchers, $params;
    return FakeWatcher->new($params);
};
$code{'event.add_timer'} = sub {
    my $params = shift;
    my $w      = FakeWatcher->new($params);
    push @timers, $w;
    return $w;
    return FakeWatcher->new($params);
};

## --- assertion helpers -------------------------------------------------- ##

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

## --- shared zone state -------------------------------------------------- ##

sub reset_state {

    # example.com : a plain a record + a name with 30 txt values, its
    # untruncated answer larger than 1232 bytes
    my @txt_records = map {
        {   name  => 'big.example.com',
            type  => 'TXT',
            value => sprintf '"txt-value-%02d-abcdefghijklmnopqrstuvwxyz"',
            $_
        }
    } 1 .. 30;

    $data{'nameserv'} = {
        'cfg' => {
            'tcp' => {
                'max_connections' => 77,
                'idle_timeout'    => 13
            }
        },
        'zones' => {
            'example.com' => {
                'serial'  => 100,
                'ttl'     => 3600,
                'records' => [
                    {   name  => 'www.example.com',
                        type  => 'A',
                        value => '203.0.113.7'
                    },
                    @txt_records
                ],
            },
        },
        'stats' => { queries => 0, errors => 0, tcp_queries => 0 },
    };
    $data{'nameserv'}{'dns_tcp'}{'conns'} = {};
    @io_watchers                          = ();
    @timers                               = ();
    @logs                                 = ();
    return;
}

reset_state();
my $conns = $data{'nameserv'}{'dns_tcp'}{'conns'};

sub make_query {
    my ( $qname, $qtype ) = @_;
    return Net::DNS::Packet->new( $qname, $qtype )->data;
}

## --- nameserv.answer : zone answers ------------------------------------- ##

my $reply
    = $code{'nameserv.answer'}->( make_query( 'www.example.com', 'A' ) );
check 'answer : existing a record -> reply',
    ref $reply eq qw| Net::DNS::Packet |;
check 'answer : a record noerror with the value',
    (       $reply->header->rcode eq qw| NOERROR |
        and scalar $reply->answer == 1
        and ( $reply->answer )[0]->type eq qw| A |
        and ( $reply->answer )[0]->address eq '203.0.113.7' );

$reply
    = $code{'nameserv.answer'}->( make_query( 'missing.example.com', 'A' ) );
check 'answer : missing name -> nxdomain',
    ( $reply->header->rcode eq qw| NXDOMAIN |
        and scalar $reply->answer == 0 );

$reply = $code{'nameserv.answer'}->( make_query( 'elsewhere.org', 'A' ) );
check 'answer : foreign zone -> refused',
    ( $reply->header->rcode eq qw| REFUSED | and $reply->header->aa == 0 );

check 'answer : garbage -> undef',
    not defined $code{'nameserv.answer'}->("not a dns packet at all");
check 'answer : short garbage bumps the error stat',
    ( not defined $code{'nameserv.answer'}->('short')
        and $data{'nameserv'}{'stats'}{'errors'} == 1 );

my $no_question = pack qw| n6 |, 4242, 0, 0, 0, 0, 0;
check 'answer : question-less packet -> undef',
    not defined $code{'nameserv.answer'}->($no_question);

## --- udp truncation through nameserv.handler.query ---------------------- ##
## a listener socket stands in for the zenka's udp socket                   ##

my $udp_sock = IO::Socket::INET->new(
    LocalAddr => '127.0.0.1',
    LocalPort => 0,
    Proto     => 'udp',
) or die "cannot bind udp socket : $OS_ERROR";
my $udp_port = $udp_sock->sockport;

my $udp_client = IO::Socket::INET->new(
    PeerAddr => "127.0.0.1:$udp_port",
    Proto    => 'udp',
) or die "cannot open udp client : $OS_ERROR";

my $udp_ask = sub {
    my ($query) = @_;
    $udp_client->send( $query->data );
    $data{'nameserv'}{'socket'} = $udp_sock;
    $code{'nameserv.handler.query'}->();
    my $buf = '';
    $udp_client->recv( $buf, 4096, 0 );
    return \$buf;
};

## the untruncated answer is bigger than 1232 bytes ##
my $big_reply
    = $code{'nameserv.answer'}->( make_query( 'big.example.com', 'TXT' ) );
my $big_size = length $big_reply->data;
check 'truncation : untruncated txt answer exceeds 1232 bytes',
    $big_size > 1232;

my $buf     = $udp_ask->( Net::DNS::Packet->new( 'big.example.com', 'TXT' ) );
my $u_reply = Net::DNS::Packet->new($buf);
check 'truncation : plain udp reply fits 512 bytes', length $$buf <= 512;
check 'truncation : plain udp reply has the tc bit set',
    $u_reply->header->tc == 1;
check 'truncation : plain udp reply kept the question',
    ( scalar $u_reply->question == 1
        and lc( ( $u_reply->question )[0]->qname ) eq 'big.example.com' );

my $edns_query = Net::DNS::Packet->new( 'big.example.com', 'TXT' );
$edns_query->edns->udpsize(1232);
$buf     = $udp_ask->($edns_query);
$u_reply = Net::DNS::Packet->new($buf);
check 'truncation : edns 1232 reply fits 1232 bytes', length $$buf <= 1232;
check 'truncation : edns 1232 reply is larger than the 512 one',
    length $$buf > 512;
check 'truncation : edns 1232 reply still truncated [ answer > 1232 ]',
    $u_reply->header->tc == 1;

## a small answer stays untouched : no tc bit ##
$buf     = $udp_ask->( Net::DNS::Packet->new( 'www.example.com', 'A' ) );
$u_reply = Net::DNS::Packet->new($buf);
check 'truncation : small reply not truncated',
    (       $u_reply->header->tc == 0
        and $u_reply->header->rcode eq qw| NOERROR | );

## --- tcp framing                                           ##
## --------------------------------------------------------- ##

## listener + one accepted connection ##

my $listen = IO::Socket::INET->new(
    LocalAddr => '127.0.0.1',
    LocalPort => 0,
    Proto     => 'tcp',
    Listen    => 77,
    ReuseAddr => 1,
) or die "cannot bind tcp listener : $OS_ERROR";
my $tcp_port = $listen->sockport;

my $client = IO::Socket::INET->new(
    PeerAddr => "127.0.0.1:$tcp_port",
    Proto    => 'tcp',
) or die "cannot connect tcp client : $OS_ERROR";

$code{'nameserv.dns_tcp.handler.accept'}->( FakeEvent->new($listen) );

check 'accept : one connection registered', scalar keys %$conns == 1;
my ($conn_id) = keys %$conns;
my $conn = $conns->{$conn_id};
check 'accept : connection state complete',
    (       ref $conn eq qw| HASH |
        and ref $conn->{'sock'}
        and $conn->{'peer'} eq '127.0.0.1'
        and length $conn->{'in'} == 0
        and length $conn->{'out'} == 0 );
check 'accept : idle timeout timer armed',
    ( scalar @timers == 1
        and $timers[0]{'params'}{'handler'} eq
        qw| nameserv.dns_tcp.handler.timeout | );
check 'accept : read watcher armed',
    ( scalar @io_watchers == 1
        and $io_watchers[0]{'handler'} eq qw| nameserv.dns_tcp.handler.read |
    );

my $tcp_ask = sub {    ## framed read of one reply from the client side ##
    my $len_buf = '';
    while ( length $len_buf < 2 ) {
        my $b = sysread( $client, $len_buf, 2 - length $len_buf,
            length $len_buf );
        die "tcp reply length read " . "failed : $OS_ERROR"
            if not defined $b or $b == 0;
    }
    my $msg_len = unpack qw| n |, $len_buf;
    my $msg     = '';
    while ( length $msg < $msg_len ) {
        my $b = sysread( $client, $msg, $msg_len - length $msg, length $msg );
        die "tcp reply read failed : $OS_ERROR" if not defined $b or $b == 0;
    }
    return Net::DNS::Packet->new( \$msg );
};

sub pump {    ## wait for readability [ the event loop does this ], read ##
    ## every pending chunk : tcp may deliver a write in several parts  ##
    my ($id) = @_;
    for my $round ( 1 .. 25 ) {
        last unless exists $conns->{$id};
        my $sock = $conns->{$id}{'sock'};
        my $rin  = q{};
        vec( $rin, fileno($sock), 1 ) = 1;
        my $timeout = $round == 1 ? 2 : 0.1;
        last unless select $rin, undef, undef, $timeout;
        $code{'nameserv.dns_tcp.handler.read'}->( FakeEvent->new($id) );
    }
}

## two pipelined queries in a single read chunk ##

my $q1 = Net::DNS::Packet->new( 'www.example.com',     'A' );
my $q2 = Net::DNS::Packet->new( 'missing.example.com', 'A' );
$client->send(
          pack( qw| n |, length $q1->data )
        . $q1->data
        . pack( qw| n |, length $q2->data )
        . $q2->data );

pump($conn_id);

my $r1 = $tcp_ask->();
my $r2 = $tcp_ask->();
check 'tcp : first pipelined reply is the a record',
    (       $r1->header->id == $q1->header->id
        and $r1->header->rcode eq qw| NOERROR |
        and scalar $r1->answer == 1 );
check 'tcp : second pipelined reply is nxdomain, in order',
    (       $r2->header->id == $q2->header->id
        and $r2->header->rcode eq qw| NXDOMAIN | );
check 'tcp : tcp replies are never truncated',
    ( $r1->header->tc == 0 and $r2->header->tc == 0 );
check 'tcp : both queries counted',
    $data{'nameserv'}{'stats'}{'tcp_queries'} == 2;
check 'tcp : input buffer drained', length $conn->{'in'} == 0;
check 'tcp : no write watcher left after a full flush',
    not ref $conn->{'wwatcher'};
check 'tcp : idle timeout re-armed after activity',
    ( scalar @timers == 2
        and $timers[1]{'params'}{'handler'} eq
        qw| nameserv.dns_tcp.handler.timeout | );

## one query split over two reads ##

my $q3     = Net::DNS::Packet->new( 'www.example.com', 'A' );
my $framed = pack( qw| n |, length $q3->data ) . $q3->data;
my $half   = substr $framed, 0, 5, '';

$client->send($half);
pump($conn_id);
check 'tcp : split query -> no reply yet', length $conn->{'out'} == 0;

$client->send($framed);
pump($conn_id);
my $r3 = $tcp_ask->();
check 'tcp : completed split query answered',
    (       $r3->header->id == $q3->header->id
        and $r3->header->rcode eq qw| NOERROR |
        and scalar $r3->answer == 1 );
check 'tcp : three queries counted',
    $data{'nameserv'}{'stats'}{'tcp_queries'} == 3;

## a zero length field closes the connection ##

$client->send( pack qw| n |, 0 );
pump($conn_id);
check 'tcp : zero length closes the connection',
    not exists $conns->{$conn_id};
check 'tcp : close cancelled the timer', $timers[1]->is_active == 0;

## --- fresh connection : short length, overflow, idle timeout ------------ ##

$client = IO::Socket::INET->new(
    PeerAddr => "127.0.0.1:$tcp_port",
    Proto    => 'tcp',
) or die "cannot connect tcp client : $OS_ERROR";
$code{'nameserv.dns_tcp.handler.accept'}->( FakeEvent->new($listen) );
($conn_id) = keys %$conns;
$conn = $conns->{$conn_id};

## a length below the dns header minimum closes ##

$client->send( pack( qw| n |, 5 ) . '12345' );
pump($conn_id);
check 'tcp : length below 12 closes the connection',
    not exists $conns->{$conn_id};

## more than 65537 buffered input bytes close ##

$client = IO::Socket::INET->new(
    PeerAddr => "127.0.0.1:$tcp_port",
    Proto    => 'tcp',
) or die "cannot connect tcp client : $OS_ERROR";
$code{'nameserv.dns_tcp.handler.accept'}->( FakeEvent->new($listen) );
($conn_id) = keys %$conns;
$conn = $conns->{$conn_id};

## an incomplete frame [ declared 65535, 65536 sent ] : the buffer grows ##
## past 2 + 65535 with no message to drain it                            ##
my $junk = pack( qw| n |, 65535 ) . ( 'x' x 65536 );
$client->send($junk);
pump($conn_id);
check 'tcp : buffered input beyond 65537 bytes closes the connection',
    not exists $conns->{$conn_id};

## replies the client never reads : the output buffer cap closes ##

$client = IO::Socket::INET->new(
    PeerAddr => "127.0.0.1:$tcp_port",
    Proto    => 'tcp',
) or die "cannot connect tcp client : $OS_ERROR";
$code{'nameserv.dns_tcp.handler.accept'}->( FakeEvent->new($listen) );
($conn_id) = keys %$conns;
$conns->{$conn_id}{'out'} = 'y' x ( 4 * 65537 );    ## unread replies ##
$client->send($framed);
pump($conn_id);
check 'tcp : output beyond four full replies closes the connection',
    not exists $conns->{$conn_id};

## the idle timeout handler closes the connection ##

$client = IO::Socket::INET->new(
    PeerAddr => "127.0.0.1:$tcp_port",
    Proto    => 'tcp',
) or die "cannot connect tcp client : $OS_ERROR";
$code{'nameserv.dns_tcp.handler.accept'}->( FakeEvent->new($listen) );
($conn_id) = keys %$conns;
check 'timeout : connection registered', exists $conns->{$conn_id};

$code{'nameserv.dns_tcp.handler.timeout'}->( FakeEvent->new($conn_id) );
check 'timeout : idle connection closed', not exists $conns->{$conn_id};

## --- max connections                                   ##
## ----------------------------------------------------- ##

$data{'nameserv'}{'cfg'}{'tcp'}{'max_connections'} = 1;

$client = IO::Socket::INET->new(
    PeerAddr => "127.0.0.1:$tcp_port",
    Proto    => 'tcp',
) or die "cannot connect tcp client : $OS_ERROR";
$code{'nameserv.dns_tcp.handler.accept'}->( FakeEvent->new($listen) );
check 'limit : first connection accepted at limit 1',
    scalar keys %$conns == 1;

$client = IO::Socket::INET->new(
    PeerAddr => "127.0.0.1:$tcp_port",
    Proto    => 'tcp',
) or die "cannot connect tcp client : $OS_ERROR";
my $refused_ok = 0;
{
    local $SIG{'ALRM'} = sub { die "timed out waiting for close" };
    alarm 5;
    $code{'nameserv.dns_tcp.handler.accept'}->( FakeEvent->new($listen) );
    my $b = sysread( $client, my $tmp, 1 );
    $refused_ok = 1 if defined $b and $b == 0;    ## peer closed ##
    alarm 0;
}
check 'limit : connection beyond the limit refused + closed', $refused_ok;
check 'limit : still one connection registered', scalar keys %$conns == 1;
check 'limit : refusal logged at level 1',
    ( scalar grep {m|refused|} @logs ) == 1;

## a second immediate refusal is not logged again [ once per minute ] ##

$client = IO::Socket::INET->new(
    PeerAddr => "127.0.0.1:$tcp_port",
    Proto    => 'tcp',
) or die "cannot connect tcp client : $OS_ERROR";
$code{'nameserv.dns_tcp.handler.accept'}->( FakeEvent->new($listen) );
check 'limit : second refusal not logged within a minute',
    ( scalar grep {m|refused|} @logs ) == 1;

## --- close cleans every watcher, timer and data entry ##
## --------------------                                 ##

my $held_conn  = ( values %$conns )[0];
my $held_id    = $held_conn->{'id'};
my $held_watch = $held_conn->{'watcher'};
my $held_timer = $held_conn->{'timer'};
$code{'nameserv.dns_tcp.close'}->($held_conn);
check 'close : data entry removed',     not exists $conns->{$held_id};
check 'close : read watcher cancelled', $held_watch->is_active == 0;
check 'close : idle timer cancelled',   $held_timer->is_active == 0;
check 'close : socket closed',
    ( not defined $held_conn->{'sock'} or not fileno $held_conn->{'sock'} );

say '';
say "passed : $pass_count  failed : $fail_count";
exit( $fail_count ? 1 : 0 );

#,,..,.,,,,,,,..,,.,.,.,,,,.,,.,,,,,.,,,,,.,,,..,,...,...,..,,.,.,.,,,,,.,,.,,
#NAQLFG3Z5DRJZLEG4RPP7CIBDAVUWQCQMSXEMCHNVCAUR66RSUPSWX76RHGRS5AIMQCBNHXPFO2XM
#\\\|5XTC3A3Z6R7Y3KW4ZVP5DFJBD5MP2NMBGSAFBXZH2ZIHTQGE2A2 \ / AMOS7 \ YOURUM ::
#\[7]WR3VKGKIXOMGHCESYZ5U4PRO3CCG2PTMTTN33TX2UMQPWNL3B4CQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
