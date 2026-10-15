#!/usr/bin/env perl
use v5.32;
use strict;
use English;
use warnings;

## nameserv forwarding dns cache [ loopback clients only ] : the cache mode ##
## of the nameserv zenka -- client_allowed, get \ put, forwarding with      ##
## in-flight coalescing, upstream fallback, tcp retry on truncation and the ##
## udp \ tcp handler integration. compiles the real src modules and drives  ##
## them with stubs : base.logs, base.s_warn, base.s_read, base.s_write,     ##
## base.str.os_err, event.add_io, event.add_timer ; base.cfg_bool is the    ##
## real module. fake upstreams are real sockets on 127.0.0.1 at random      ##
## ports, answered by the test itself ; the test drives the io \ timer      ##
## handlers. never port 53, no zenka started.                               ##

use bytes;

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
    base.cfg_bool
    nameserv.zone.lookup
    nameserv.handler.p7ref_lookup
    nameserv.answer
    nameserv.cache.client_allowed
    nameserv.cache.key
    nameserv.cache.get
    nameserv.cache.put
    nameserv.cache.upstreams
    nameserv.cache.forward
    nameserv.cache.forward.try
    nameserv.cache.forward.next
    nameserv.cache.complete
    nameserv.cache.handler.answer
    nameserv.cache.handler.timeout
    nameserv.handler.query
    nameserv.dns_tcp.close
    nameserv.dns_tcp.handler.timeout
    nameserv.dns_tcp.handler.write
    nameserv.dns_tcp.handler.read
    nameserv.dns_tcp.handler.accept
    nameserv.cmd.status
    |
) {
    load_module($mod);
}

## --- stubs ------------------------------------------------------------- ##

my @logs;
$code{'base.logs'}
    = sub { push @logs, sprintf $_[1] // '', @_[ 2 .. $#_ ]; return TRUE };
$code{'base.s_warn'}
    = sub { push @logs, sprintf $_[0], @_[ 1 .. $#_ ]; return TRUE };
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

## --- shared state ------------------------------------------------------- ##

sub reset_state {
    my %cfg_cache = (
        'enabled'          => 'yes',
        'max_ttl'          => 86400,
        'max_negative_ttl' => 900,
        'max_entries'      => 7777,
        'upstream'         => '',
        'upstream_timeout' => 3,
    );

    $data{'nameserv'} = {
        'bind' => { 'addr' => '127.0.0.1', 'port' => 53 },
        'cfg'  => {
            'tcp' => {
                'max_connections' => 77,
                'idle_timeout'    => 13
            },
            'cache' => \%cfg_cache,
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
                ],
            },
        },
        'stats' => {
            'queries'         => 0,
            'errors'          => 0,
            'tcp_queries'     => 0,
            'cache_hits'      => 0,
            'cache_misses'    => 0,
            'cache_forwarded' => 0,
            'cache_servfail'  => 0,
        },
    };
    $data{'nameserv'}{'dns_tcp'}{'conns'}   = {};
    $data{'nameserv'}{'cache'}{'entries'}   = {};
    $data{'nameserv'}{'cache'}{'in_flight'} = {};
    @io_watchers                            = ();
    @timers                                 = ();
    @logs                                   = ();
    return;
}

sub set_upstreams {
    my (@servers) = @_;
    $data{'nameserv'}{'cfg'}{'cache'}{'upstream'} = join ' ', @servers;
    delete $data{'nameserv'}{'cache'}{'upstream_list'};
    return;
}

sub cache_entries {
    return $data{'nameserv'}{'cache'}{'entries'};
}

sub in_flight_states {
    return values %{ $data{'nameserv'}{'cache'}{'in_flight'} };
}

sub make_query {
    my ( $qname, $qtype, $id, $rd ) = @_;
    my $q = Net::DNS::Packet->new( $qname, $qtype );
    $q->header->id($id);
    $q->header->rd( $rd ? 1 : 0 );
    return $q;
}

sub wait_readable {
    my ( $sock, $timeout ) = @_;
    my $rin = q{};
    vec( $rin, fileno($sock), 1 ) = 1;
    return scalar select $rin, undef, undef, $timeout // 3;
}

## --- client_allowed                                     ##
## ------------------------------------------------------ ##

check 'client_allowed : 127.0.0.1 loopback',
    $code{'nameserv.cache.client_allowed'}->('127.0.0.1') == TRUE;
check 'client_allowed : 127.5.5.5 in 127/8',
    $code{'nameserv.cache.client_allowed'}->('127.5.5.5') == TRUE;
check 'client_allowed : ::1 loopback',
    $code{'nameserv.cache.client_allowed'}->('::1') == TRUE;
check 'client_allowed : ::ffff:127.0.0.1 v4-mapped loopback',
    $code{'nameserv.cache.client_allowed'}->('::ffff:127.0.0.1') == TRUE;
check 'client_allowed : 192.168.1.1 refused',
    $code{'nameserv.cache.client_allowed'}->('192.168.1.1') == FALSE;
check 'client_allowed : ::ffff:10.0.0.1 v4-mapped private refused',
    $code{'nameserv.cache.client_allowed'}->('::ffff:10.0.0.1') == FALSE;
check 'client_allowed : 2001:db8::1 refused',
    $code{'nameserv.cache.client_allowed'}->('2001:db8::1') == FALSE;
check 'client_allowed : empty refused',
    $code{'nameserv.cache.client_allowed'}->('') == FALSE;

## --- shared zenka-side udp socket + clients ##
## ------------------------------             ##

my $zenka_sock = IO::Socket::INET->new(
    LocalAddr => '127.0.0.1',
    LocalPort => 0,
    Proto     => 'udp',
) or die "cannot bind udp socket : $OS_ERROR";
my $zenka_port = $zenka_sock->sockport;

my $udp_client = IO::Socket::INET->new(
    PeerAddr => "127.0.0.1:$zenka_port",
    Proto    => 'udp',
) or die "cannot open udp client : $OS_ERROR";

sub udp_ask {    ## send + run the handler [ sync path answers at once ] ##
    my ($query) = @_;
    $udp_client->send( $query->data );
    $data{'nameserv'}{'socket'} = $zenka_sock;
    $code{'nameserv.handler.query'}->();
    return;
}

sub client_recv {    ## wait for one reply datagram on a client socket ##
    my ($sock) = @_;
    return undef unless wait_readable( $sock // $udp_client, 3 );
    my $buf = '';
    ( $sock // $udp_client )->recv( $buf, 4096, 0 );
    return Net::DNS::Packet->new( \$buf );
}

## --- mode off : REFUSED exactly as before ##
## --------------------------------         ##

reset_state();
$data{'nameserv'}{'cfg'}{'cache'}{'enabled'} = 'no';

udp_ask( make_query( 'elsewhere.org', 'A', 7101, 1 ) );
my $reply = client_recv();
check 'mode off : foreign rd query -> REFUSED as before',
    (       ref $reply
        and $reply->header->rcode eq qw| REFUSED |
        and $reply->header->aa == 0 );
check 'mode off : nothing forwarded',
    (       $data{'nameserv'}{'stats'}{'cache_forwarded'} == 0
        and $data{'nameserv'}{'stats'}{'cache_misses'} == 0
        and scalar in_flight_states() == 0 );

## --- authoritative zones are never forwarded ##
## -----------------------------               ##

reset_state();

udp_ask( make_query( 'www.example.com', 'A', 7102, 1 ) );
$reply = client_recv();
check 'authoritative : zone answer from the zone, rd set',
    (       ref $reply
        and $reply->header->rcode eq qw| NOERROR |
        and $reply->header->aa == 1
        and scalar $reply->answer == 1
        and ( $reply->answer )[0]->address eq '203.0.113.7' );
check 'authoritative : nothing forwarded, nothing cached',
    ( $data{'nameserv'}{'stats'}{'cache_forwarded'} == 0
        and scalar keys %{ cache_entries() } == 0 );

## --- non-loopback client with rd : REFUSED, nothing forwarded ##
## ------------                                                 ##

reset_state();

my $real_client_allowed = $code{'nameserv.cache.client_allowed'};
$code{'nameserv.cache.client_allowed'} = sub { return FALSE };

udp_ask( make_query( 'elsewhere.org', 'A', 7103, 1 ) );
$reply = client_recv();
check 'client check : non-loopback rd query -> REFUSED',
    ( ref $reply and $reply->header->rcode eq qw| REFUSED | );
check 'client check : nothing forwarded, no cache lookup',
    (       $data{'nameserv'}{'stats'}{'cache_forwarded'} == 0
        and $data{'nameserv'}{'stats'}{'cache_misses'} == 0
        and $data{'nameserv'}{'stats'}{'cache_hits'} == 0 );

$code{'nameserv.cache.client_allowed'} = $real_client_allowed;

## --- fake upstream helpers                                               ##
## ------------------------------------------------- a fake upstream = a   ##
## udp socket [ + a tcp listener for the truncation case ] on 127.0.0.1 at ##
## a random port, answered by the test itself                              ##

my $upstream;        ## current udp fake upstream ##
my $upstream_tcp;    ## optional tcp fake upstream ##

sub new_upstream {
    my ($want_tcp) = @_;
    my $sock = IO::Socket::INET->new(
        LocalAddr => '127.0.0.1',
        LocalPort => 0,
        Proto     => 'udp',
    ) or die "cannot bind upstream udp : $OS_ERROR";
    $upstream = $sock;
    if ($want_tcp) {
        $upstream_tcp = IO::Socket::INET->new(
            LocalAddr => '127.0.0.1',
            LocalPort => $sock->sockport,
            Proto     => 'tcp',
            Listen    => 7,
            ReuseAddr => 1,
        ) or die "cannot bind upstream tcp : $OS_ERROR";
    } else {
        $upstream_tcp = undef;
    }
    set_upstreams( '127.0.0.1:' . $sock->sockport );
    return $sock;
}

sub upstream_recv_query {    ## wait for one udp query on $upstream ##
    die "no udp upstream query arrived" unless wait_readable( $upstream, 3 );
    my $buf = '';
    $upstream->recv( $buf, 4096, 0 );
    return Net::DNS::Packet->new( \$buf );
}

sub upstream_idle {    ## assert no udp query pending ##
    return not wait_readable( $upstream, 0.3 );
}

sub make_upstream_reply {
    my ( $req, %opts ) = @_;
    my ($question) = $req->question;
    my $reply = Net::DNS::Packet->new( $question->qname, $question->qtype,
        $question->qclass );
    $reply->header->id( $req->header->id );
    $reply->header->qr(1);
    $reply->header->aa( $opts{'aa'}       // 1 );
    $reply->header->rcode( $opts{'rcode'} // qw| NOERROR | );
    $reply->header->tc(1) if $opts{'tc'};

    for my $rr ( @{ $opts{'answer'} // [] } ) {
        $reply->push( answer => $rr );
    }
    for my $rr ( @{ $opts{'authority'} // [] } ) {
        $reply->push( authority => $rr );
    }
    return $reply->data(4096);
}

sub answer_a_rr {
    my ( $qname, $ttl, $ip ) = @_;
    return Net::DNS::RR->new("$qname $ttl IN A $ip");
}

sub soa_rr {
    my ( $zone, $ttl, $minimum ) = @_;
    return Net::DNS::RR->new( "$zone $ttl IN SOA ns1.$zone hostmaster.$zone "
            . "1 7200 3600 1209600 $minimum" );
}

sub make_negative_reply {    ## parsed packet form, for direct put tests ##
    my ( $query_packet, $soa_minimum ) = @_;
    my ($question) = $query_packet->question;
    my $reply = Net::DNS::Packet->new( $question->qname, $question->qtype,
        $question->qclass );
    $reply->header->qr(1);
    $reply->header->rcode(qw| NXDOMAIN |);
    $reply->push( authority => soa_rr( 'example.org', 3600, $soa_minimum ) );
    return $reply;
}

sub drive_upstream_answer {    ## answer the pending in-flight state ##
    my (%opts) = @_;
    my $req = upstream_recv_query();
    $upstream->send( make_upstream_reply( $req, %opts ) );
    my ($state) = in_flight_states();
    die "no in-flight state" unless ref $state;
    die "resolver socket not readable"
        unless wait_readable( $state->{'sock'}, 3 );
    $code{'nameserv.cache.handler.answer'}->( FakeEvent->new($state) );
    return ( $req, $state );
}

sub drive_timeout {    ## fire the timeout handler of the pending state ##
    my ($state) = in_flight_states();
    die "no in-flight state" unless ref $state;
    $code{'nameserv.cache.handler.timeout'}->( FakeEvent->new($state) );
    return $state;
}

## --- miss -> forwarded -> hit, ttl decrement, expiry ##
## ---------------------                               ##

reset_state();
new_upstream();

udp_ask( make_query( 'cached.example.org', 'A', 1111, 1 ) );
check 'forward : miss returns nothing synchronously',
    (       $data{'nameserv'}{'stats'}{'cache_misses'} == 1
        and $data{'nameserv'}{'stats'}{'cache_forwarded'} == 1
        and scalar in_flight_states() == 1 );

my $req = upstream_recv_query();
check 'forward : upstream got the query with rd = 1',
    ( lc( ( $req->question )[0]->qname ) eq 'cached.example.org'
        and $req->header->rd == 1 );

$upstream->send(
    make_upstream_reply(
        $req,
        'answer' => [ answer_a_rr( 'cached.example.org', 60, '192.0.2.77' ) ]
    )
);
my ($state) = in_flight_states();
die "resolver socket " . "not readable"
    unless wait_readable( $state->{'sock'}, 3 );
my $held_watcher = $state->{'watcher'};
my $held_timer   = $state->{'timer'};
$code{'nameserv.cache.handler.answer'}->( FakeEvent->new($state) );

$reply = client_recv();
check 'forward : reply delivered with the client query id',
    ( ref $reply and $reply->header->id == 1111 );
check 'forward : forwarded answer content',
    (       $reply->header->rcode eq qw| NOERROR |
        and scalar $reply->answer == 1
        and ( $reply->answer )[0]->address eq '192.0.2.77' );
check 'forward : reply cached once', scalar keys %{ cache_entries() } == 1;
check 'forward : io watcher + timer cancelled after completion',
    ( $held_watcher->is_active == 0 and $held_timer->is_active == 0 );
check 'forward : in-flight state deregistered',
    scalar in_flight_states() == 0;

sleep 2;    ## let the entry age ##

udp_ask( make_query( 'cached.example.org', 'A', 2222, 1 ) );
$reply = client_recv();
check 'hit : second query answered from the cache',
    (       ref $reply
        and $reply->header->id == 2222
        and $reply->header->rcode eq qw| NOERROR |
        and ( $reply->answer )[0]->address eq '192.0.2.77' );
check 'hit : no upstream traffic, no second forward',
    (       upstream_idle()
        and $data{'nameserv'}{'stats'}{'cache_forwarded'} == 1
        and $data{'nameserv'}{'stats'}{'cache_hits'} == 1
        and $data{'nameserv'}{'stats'}{'cache_misses'} == 1 );
check 'hit : ttl decremented by the elapsed time',
    ( ( $reply->answer )[0]->ttl <= 58 and ( $reply->answer )[0]->ttl > 0 );

## expiry : an entry past its expiry is a miss again ##

my $key = $code{'nameserv.cache.key'}
    ->( make_query( 'cached.example.org', 'A', 0, 0 ) );
cache_entries()->{$key}{'expiry'} = time - 1;

udp_ask( make_query( 'cached.example.org', 'A', 3333, 1 ) );
check 'expiry : expired entry counts as a miss, forwarded again',
    (       $data{'nameserv'}{'stats'}{'cache_misses'} == 2
        and $data{'nameserv'}{'stats'}{'cache_forwarded'} == 2
        and scalar in_flight_states() == 1 );

drive_upstream_answer(
    'answer' => [ answer_a_rr( 'cached.example.org', 60, '192.0.2.77' ) ] );
$reply = client_recv();
check 'expiry : re-fetched reply delivered',
    ( ref $reply and $reply->header->id == 3333 );

## --- negative caching                                  ##
## ----------------------------------------------------- ##

reset_state();
new_upstream();

udp_ask( make_query( 'gone.example.org', 'A', 4101, 1 ) );
my $req_nx = upstream_recv_query();
$upstream->send(
    make_upstream_reply(
        $req_nx,
        'rcode'     => qw| NXDOMAIN |,
        'authority' => [ soa_rr( 'example.org', 3600, 60 ) ]
    )
);
($state) = in_flight_states();
wait_readable( $state->{'sock'}, 3 );
$code{'nameserv.cache.handler.answer'}->( FakeEvent->new($state) );
client_recv();
check 'negative : nxdomain with soa cached',
    scalar keys %{ cache_entries() } == 1;
check 'negative : soa minimum used as the entry ttl',
    (
    cache_entries()->{
        $code{'nameserv.cache.key'}
            ->( make_query( 'gone.example.org', 'A', 0, 0 ) )
    }{'ttl'} // -1
    ) == 60;

udp_ask( make_query( 'gone.example.org', 'A', 4102, 1 ) );
$reply = client_recv();
check 'negative : second query is a cached nxdomain hit',
    (       $data{'nameserv'}{'stats'}{'cache_hits'} == 1
        and $reply->header->rcode eq qw| NXDOMAIN |
        and upstream_idle()
        and $data{'nameserv'}{'stats'}{'cache_forwarded'} == 1 );

## capped at max_negative_ttl ##

reset_state();
new_upstream();
$data{'nameserv'}{'cfg'}{'cache'}{'max_negative_ttl'} = 30;

my $nx2 = Net::DNS::Packet->new( 'capped.example.org', 'A' );
check 'negative : put capped at max_negative_ttl',
    ( $code{'nameserv.cache.put'}->( make_negative_reply( $nx2, 60 ) ) == TRUE
        and cache_entries()->{ $code{'nameserv.cache.key'}->($nx2) }{'ttl'}
        == 30 );

## without soa : not cached ##

reset_state();
new_upstream();

udp_ask( make_query( 'soaless.example.org', 'A', 4201, 1 ) );
my $req_bare = upstream_recv_query();
$upstream->send(
    make_upstream_reply( $req_bare, 'rcode' => qw| NXDOMAIN | ) );
($state) = in_flight_states();
wait_readable( $state->{'sock'}, 3 );
$code{'nameserv.cache.handler.answer'}->( FakeEvent->new($state) );
client_recv();
check 'negative : nxdomain without soa not cached',
    scalar keys %{ cache_entries() } == 0;

udp_ask( make_query( 'soaless.example.org', 'A', 4202, 1 ) );
check 'negative : second query forwarded again',
    ( $data{'nameserv'}{'stats'}{'cache_forwarded'} == 2
        and scalar in_flight_states() == 1 );

drive_upstream_answer(
    'authority' => [ soa_rr( 'example.org', 3600, 60 ) ],
    'rcode'     => qw| NXDOMAIN |
);
client_recv();

## --- servfail is not cached                     ##
## ---------------------------------------------- ##

reset_state();
new_upstream();

udp_ask( make_query( 'flaky.example.org', 'A', 5101, 1 ) );
drive_upstream_answer( 'rcode' => qw| SERVFAIL |, 'aa' => 0 );
$reply = client_recv();
check 'servfail : upstream servfail delivered with the client id',
    (       ref $reply
        and $reply->header->id == 5101
        and $reply->header->rcode eq qw| SERVFAIL | );
check 'servfail : not cached', scalar keys %{ cache_entries() } == 0;

udp_ask( make_query( 'flaky.example.org', 'A', 5102, 1 ) );
check 'servfail : second query forwarded again',
    ( $data{'nameserv'}{'stats'}{'cache_forwarded'} == 2
        and scalar in_flight_states() == 1 );

drive_upstream_answer(
    'answer' => [ answer_a_rr( 'flaky.example.org', 300, '192.0.2.88' ) ] );
client_recv();
check 'servfail : recovery cached afterwards',
    scalar keys %{ cache_entries() } == 1;

## --- truncated udp reply : retry the same upstream over tcp ##
## ---------------                                            ##

reset_state();
new_upstream(1);    ## udp + tcp on the same port ##

udp_ask( make_query( 'big.example.org', 'A', 5201, 1 ) );
my $req_tc = upstream_recv_query();
$upstream->send( make_upstream_reply( $req_tc, 'tc' => 1 ) );
($state) = in_flight_states();
wait_readable( $state->{'sock'}, 3 );
$code{'nameserv.cache.handler.answer'}->( FakeEvent->new($state) );
check 'truncated : still in flight after the tc reply, no delivery yet',
    ( scalar in_flight_states() == 1 and $state->{'usevc'} == TRUE );

## the same upstream, retried over tcp ##
die "no tcp retry arrived" unless wait_readable( $upstream_tcp, 3 );
my $tcp_peer = $upstream_tcp->accept;
my $len_buf  = '';
while ( length $len_buf < 2 ) {
    my $b = sysread( $tcp_peer, $len_buf, 2 - length $len_buf,
        length $len_buf );
    die "tcp retry length read " . "failed : $OS_ERROR"
        if not defined $b or $b == 0;
}
my $msg_len = unpack qw| n |, $len_buf;
my $msg     = '';
while ( length $msg < $msg_len ) {
    my $b = sysread( $tcp_peer, $msg, $msg_len - length $msg, length $msg );
    die "tcp retry read failed : $OS_ERROR" if not defined $b or $b == 0;
}
my $tcp_req = Net::DNS::Packet->new( \$msg );
check 'truncated : tcp retry asks the same question',
    lc( ( $tcp_req->question )[0]->qname ) eq 'big.example.org';

my $tcp_reply = make_upstream_reply( $tcp_req,
    'answer' => [ answer_a_rr( 'big.example.org', 300, '192.0.2.99' ) ] );
$tcp_peer->send( pack( qw| n |, length $tcp_reply ) . $tcp_reply );

($state) = in_flight_states();
die "resolver tcp " . "socket not readable"
    unless wait_readable( $state->{'sock'}, 3 );
$code{'nameserv.cache.handler.answer'}->( FakeEvent->new($state) );

$reply = client_recv();
check 'truncated : full reply delivered over the tcp retry, tc clear',
    (       ref $reply
        and $reply->header->id == 5201
        and $reply->header->tc == 0
        and ( $reply->answer )[0]->address eq '192.0.2.99' );
check 'truncated : retry result cached',
    scalar keys %{ cache_entries() } == 1;

## --- upstream fallback : timeout -> next upstream ##
## -------------------------                        ##

reset_state();
my $silent = IO::Socket::INET->new(
    LocalAddr => '127.0.0.1',
    LocalPort => 0,
    Proto     => 'udp',
) or die "cannot bind silent upstream : $OS_ERROR";
new_upstream();
set_upstreams( '127.0.0.1:' . $silent->sockport,
    '127.0.0.1:' . $upstream->sockport );

udp_ask( make_query( 'fallback.example.org', 'A', 6101, 1 ) );
check 'fallback : first upstream queried',
    $data{'nameserv'}{'stats'}{'cache_forwarded'} == 1;

drive_timeout();
check 'fallback : timeout moved to the second upstream',
    ( $data{'nameserv'}{'stats'}{'cache_forwarded'} == 2
        and scalar in_flight_states() == 1 );

my $req_fb = upstream_recv_query();
check 'fallback : the answering upstream is the second one',
    lc( ( $req_fb->question )[0]->qname ) eq 'fallback.example.org';
$upstream->send(
    make_upstream_reply(
        $req_fb,
        'answer' =>
            [ answer_a_rr( 'fallback.example.org', 300, '192.0.2.111' ) ]
    )
);
($state) = in_flight_states();
wait_readable( $state->{'sock'}, 3 );
$code{'nameserv.cache.handler.answer'}->( FakeEvent->new($state) );
$reply = client_recv();
check 'fallback : second upstream reply delivered with the client id',
    (       ref $reply
        and $reply->header->id == 6101
        and ( $reply->answer )[0]->address eq '192.0.2.111' );

## --- all silent : servfail to the client ##
## ----------------------------------      ##

reset_state();
my $silent_a = IO::Socket::INET->new(
    LocalAddr => '127.0.0.1',
    LocalPort => 0,
    Proto     => 'udp',
) or die "cannot bind silent upstream : $OS_ERROR";
my $silent_b = IO::Socket::INET->new(
    LocalAddr => '127.0.0.1',
    LocalPort => 0,
    Proto     => 'udp',
) or die "cannot bind silent upstream : $OS_ERROR";
set_upstreams(
    '127.0.0.1:' . $silent_a->sockport,
    '127.0.0.1:' . $silent_b->sockport
);

udp_ask( make_query( 'dark.example.org', 'A', 6201, 1 ) );
drive_timeout();
drive_timeout();
check 'all silent : both upstream tries made',
    $data{'nameserv'}{'stats'}{'cache_forwarded'} == 2;
check 'all silent : nothing left in flight', scalar in_flight_states() == 0;
$reply = client_recv();
check 'all silent : servfail to the client with its id',
    (       ref $reply
        and $reply->header->id == 6201
        and $reply->header->rcode eq qw| SERVFAIL | );
check 'all silent : servfail counter bumped, nothing cached',
    ( $data{'nameserv'}{'stats'}{'cache_servfail'} == 1
        and scalar keys %{ cache_entries() } == 0 );

## --- in-flight coalescing                           ##
## -------------------------------------------------- ##

reset_state();
new_upstream();

my $client2 = IO::Socket::INET->new(
    PeerAddr => "127.0.0.1:$zenka_port",
    Proto    => 'udp',
) or die "cannot open second udp client : $OS_ERROR";

my $q1 = make_query( 'join.example.org', 'A', 6301, 1 );
my $q2 = make_query( 'join.example.org', 'A', 6302, 1 );
$udp_client->send( $q1->data );
$data{'nameserv'}{'socket'} = $zenka_sock;
$code{'nameserv.handler.query'}->();
$client2->send( $q2->data );
$data{'nameserv'}{'socket'} = $zenka_sock;
$code{'nameserv.handler.query'}->();

check 'coalesce : one in-flight state with both waiters',
    (       scalar in_flight_states() == 1
        and scalar @{ ( in_flight_states() )[0]->{'waiters'} } == 2 );
my $req_j = upstream_recv_query();
check 'coalesce : exactly one upstream query',
    ( upstream_idle()
        and $data{'nameserv'}{'stats'}{'cache_forwarded'} == 1 );

$upstream->send(
    make_upstream_reply(
        $req_j,
        'answer' => [ answer_a_rr( 'join.example.org', 300, '192.0.2.122' ) ]
    )
);
($state) = in_flight_states();
wait_readable( $state->{'sock'}, 3 );
$code{'nameserv.cache.handler.answer'}->( FakeEvent->new($state) );

my $r1 = client_recv($udp_client);
my $r2 = client_recv($client2);
check 'coalesce : both waiters delivered, each with its own id',
    (       ref $r1
        and ref $r2
        and $r1->header->id == 6301
        and $r2->header->id == 6302
        and ( $r1->answer )[0]->address eq '192.0.2.122'
        and ( $r2->answer )[0]->address eq '192.0.2.122' );
check 'coalesce : one put, one entry', scalar keys %{ cache_entries() } == 1;

## --- max_entries : evict the entries that expire first ##
## ---------------------                                 ##

reset_state();
$data{'nameserv'}{'cfg'}{'cache'}{'max_entries'} = 2;

my $put_reply = sub {
    my ( $qname, $ttl ) = @_;
    my $pkt = Net::DNS::Packet->new( $qname, 'A' );
    $pkt->header->qr(1);
    $pkt->header->rcode(qw| NOERROR |);
    $pkt->push( answer => answer_a_rr( $qname, $ttl, '192.0.2.200' ) );
    return $code{'nameserv.cache.put'}->($pkt);
};

check 'evict : first entry stored',
    $put_reply->( 'evict-a.example.org', 300 ) == TRUE;
check 'evict : second entry stored',
    $put_reply->( 'evict-b.example.org', 200 ) == TRUE;
check 'evict : third entry stored, earliest expiry removed',
    (
            $put_reply->( 'evict-c.example.org', 100 ) == TRUE
        and scalar keys %{ cache_entries() } == 2
        and not exists cache_entries()->{
        $code{'nameserv.cache.key'}
            ->( make_query( 'evict-b.example.org', 'A', 0, 0 ) )
        }
        and exists cache_entries()->{
        $code{'nameserv.cache.key'}
            ->( make_query( 'evict-a.example.org', 'A', 0, 0 ) )
        }
        and exists cache_entries()->{
        $code{'nameserv.cache.key'}
            ->( make_query( 'evict-c.example.org', 'A', 0, 0 ) )
        }
    );

## --- tcp integration                                     ##
## ------------------------------------------------------- ##

reset_state();
new_upstream();

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

my $conns = $data{'nameserv'}{'dns_tcp'}{'conns'};
$code{'nameserv.dns_tcp.handler.accept'}->( FakeEvent->new($listen) );
my ($conn_id) = keys %$conns;

sub pump {    ## wait for readability, drain every pending chunk ##
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

my $tcp_ask = sub {    ## framed read of one reply from the client side ##
    my $len_buf = '';
    while ( length $len_buf < 2 ) {
        my $b = sysread( $client, $len_buf, 2 - length $len_buf,
            length $len_buf );
        die "tcp reply length read failed : $OS_ERROR"
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

my $tcp_query = make_query( 'tcpcached.example.org', 'A', 6401, 1 );
my $framed    = pack( qw| n |, length $tcp_query->data ) . $tcp_query->data;
$client->send($framed);
pump($conn_id);

check 'tcp : miss forwarded over the tcp path',
    ( scalar in_flight_states() == 1
        and $data{'nameserv'}{'stats'}{'cache_forwarded'} == 1 );

drive_upstream_answer( 'answer' =>
        [ answer_a_rr( 'tcpcached.example.org', 300, '192.0.2.133' ) ] );
my $tcp_reply_pkt = $tcp_ask->();
check 'tcp : forwarded reply framed + written to the connection',
    (       $tcp_reply_pkt->header->id == 6401
        and $tcp_reply_pkt->header->rcode eq qw| NOERROR |
        and ( $tcp_reply_pkt->answer )[0]->address eq '192.0.2.133' );
check 'tcp : result cached', scalar keys %{ cache_entries() } == 1;

## a second identical query on the same connection : cache hit, sync reply ##

$client->send($framed);
pump($conn_id);
my $tcp_hit = $tcp_ask->();
check 'tcp : second query is a cache hit, no second forward',
    (       $tcp_hit->header->id == 6401
        and $tcp_hit->header->rcode eq qw| NOERROR |
        and $data{'nameserv'}{'stats'}{'cache_forwarded'} == 1
        and scalar in_flight_states() == 0 );

## a tcp connection closed before the upstream reply : no error at all ##

my $client2_b = IO::Socket::INET->new(
    PeerAddr => "127.0.0.1:$tcp_port",
    Proto    => 'tcp',
) or die "cannot connect second tcp client : $OS_ERROR";
$code{'nameserv.dns_tcp.handler.accept'}->( FakeEvent->new($listen) );
my ($conn2_id) = grep { $_ ne $conn_id } keys %$conns;
my $conn2 = $conns->{$conn2_id};

my $tcp_q2 = make_query( 'late.example.org', 'A', 6402, 1 );
$client2_b->send( pack( qw| n |, length $tcp_q2->data ) . $tcp_q2->data );
pump($conn2_id);
check 'tcp closed : second connection forwarded a query',
    scalar in_flight_states() == 1;

$code{'nameserv.dns_tcp.close'}->($conn2);    ## client went away ##
check 'tcp closed : connection state removed', not exists $conns->{$conn2_id};

my $closed_ok = eval {
    drive_upstream_answer(
        'answer' => [ answer_a_rr( 'late.example.org', 300, '192.0.2.144' ) ]
    );
    1;
};
check 'tcp closed : late upstream reply -> no error, nothing appended',
    (       $closed_ok
        and not exists $conns->{$conn2_id}
        and scalar in_flight_states() == 0 );

## a closed connection's id reused by a new one [ peer + fileno ] : the ##
## late reply must not reach the new connection                         ##

my $client3 = IO::Socket::INET->new(
    PeerAddr => "127.0.0.1:$tcp_port",
    Proto    => 'tcp',
) or die "cannot connect third tcp client : $OS_ERROR";
$code{'nameserv.dns_tcp.handler.accept'}->( FakeEvent->new($listen) );
my ($conn3_id) = grep { $_ ne $conn_id } keys %$conns;
my $conn3 = $conns->{$conn3_id};

my $tcp_q3 = make_query( 'reused.example.org', 'A', 6403, 1 );
$client3->send( pack( qw| n |, length $tcp_q3->data ) . $tcp_q3->data );
pump($conn3_id);
$code{'nameserv.dns_tcp.close'}->($conn3);
$conns->{$conn3_id} = { 'id' => $conn3_id, 'out' => '', 'in' => '' };

my $reuse_ok = eval {
    drive_upstream_answer( 'answer' =>
            [ answer_a_rr( 'reused.example.org', 300, '192.0.2.155' ) ] );
    1;
};
check 'tcp id reused : the late reply does not reach the new connection',
    ( $reuse_ok and $conns->{$conn3_id}{'out'} eq '' );
delete $conns->{$conn3_id};

## --- upstream servfail \ refused : the next upstream first  ##
## ---------------------------------------------------------- ##

reset_state();
my $broken = IO::Socket::INET->new(
    LocalAddr => '127.0.0.1',
    LocalPort => 0,
    Proto     => 'udp',
) or die "cannot bind broken upstream : $OS_ERROR";
new_upstream();
set_upstreams( '127.0.0.1:' . $broken->sockport,
    '127.0.0.1:' . $upstream->sockport );

udp_ask( make_query( 'next.example.org', 'A', 6501, 1 ) );
{
    die 'no query at the broken upstream' unless wait_readable( $broken, 3 );
    my $buf  = '';
    my $from = $broken->recv( $buf, 4096, 0 );
    $broken->send(
        make_upstream_reply(
            scalar Net::DNS::Packet->new( \$buf ),
            'rcode' => qw| SERVFAIL |,
            'aa'    => 0
        ),
        0, $from
    );
}
($state) = in_flight_states();
wait_readable( $state->{'sock'}, 3 );
$code{'nameserv.cache.handler.answer'}->( FakeEvent->new($state) );
check 'servfail next : the second upstream asked, nothing delivered yet',
    ( $data{'nameserv'}{'stats'}{'cache_forwarded'} == 2
        and scalar in_flight_states() == 1 );

drive_upstream_answer(
    'answer' => [ answer_a_rr( 'next.example.org', 300, '192.0.2.166' ) ] );
$reply = client_recv();
check 'servfail next : the second upstream answer delivered and cached',
    (       ref $reply
        and $reply->header->id == 6501
        and ( $reply->answer )[0]->address eq '192.0.2.166'
        and scalar keys %{ cache_entries() } == 1 );

## --- edns : a hit keeps the opt record's flags [ its 'ttl' field ] ##
## ----------------------------------------------------------------  ##

reset_state();
{
    my $q_edns = make_query( 'edns.example.org', 'A', 6601, 1 );
    my $r_edns = Net::DNS::Packet->new( 'edns.example.org', 'A', 'IN' );
    $r_edns->header->qr(1);
    $r_edns->push(
        answer => answer_a_rr( 'edns.example.org', 300, '192.0.2.177' ) );
    $r_edns->edns->udpsize(1232);
    $r_edns->header->do(1);
    $r_edns = Net::DNS::Packet->new( \$r_edns->data(4096) );
    $code{'nameserv.cache.put'}->($r_edns);
    my ($key) = keys %{ cache_entries() };
    cache_entries()->{$key}{'stored'} -= 100;    ## aged 100 s ##
    my $hit = $code{'nameserv.cache.get'}->($q_edns);
    check 'edns : answer ttl aged, opt flags intact on a hit',
        ( ref $hit and ( $hit->answer )[0]->ttl == 200 and $hit->header->do );
}

## --- status shows the cache counters     ##
## --------------------------------------- ##

my $status = $code{'nameserv.cmd.status'}->();
check 'status : cache counters in the status output',
    ( ref $status eq qw| HASH |
        and $status->{'data'} =~ m{cache: \d+ hits, \d+ misses,} );
printf "status : %s\n", join ' ',
    grep {m{^\s+cache:}} split m{\n}, $status->{'data'};

## --- summary                                                      ##
## ---------------------------------------------------------------- ##

say '';
say "passed : $pass_count  failed : $fail_count";
exit( $fail_count ? 1 : 0 );

#,,,,,,,.,,,,,...,,,.,.,,,...,,,,,..,,..,,,,,,..,,...,...,..,,..,,..,,,..,,,,,
#EF5Q47XMY2O7JHFVNJ3B6FSMNW6VVHT6CSS4ACLWCYWQ34A4WAM5XO3DOB63SLKXZOZ5ULLR3RMFQ
#\\\|TZLGVPGELERBZNBBU25XZAQA6BDAFJJPHHPSRH72B74FEYIMM4Q \ / AMOS7 \ YOURUM ::
#\[7]ONG3YM2QE5UJ432LZINOUSI3HDNGNA6X3GBL5RPROPVVG2UDVQBA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
