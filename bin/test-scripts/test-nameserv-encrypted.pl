#!/usr/bin/env perl
use v5.32;
use strict;
use English;
use warnings;

## nameserv encrypted fallback [ dns over tls 853, dns over https 443 ] :   ##
## the pure parts [ validation, framing, doh request \ response ], the path ##
## choice per stored behaviour, and live non-blocking queries against local ##
## tls servers [ forked children, self-signed certificates generated here,  ##
## random loopback ports ] : pooled connection reuse, lazy reconnect, a     ##
## certificate failure never downgrading to plain dns, the degraded held    ##
## server with its logged reason, back-off, timeout. the event loop is a    ##
## small select loop around the real src modules. no zenka, never port 53.  ##

use File::Spec;
use File::Temp qw| tempdir |;
use Cwd        qw| abs_path |;
use FindBin    qw| $RealBin |;
use POSIX      qw| :sys_wait_h |;

use IO::Select;
use IO::Socket::INET;
use IO::Socket::SSL;
use Net::DNS;
use Net::DNS::Packet;
use Net::DNS::RR;
use Time::HiRes qw| time sleep |;

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
$SIG{'PIPE'} = 'IGNORE';    ## the zenka ignores it too [ base.sig_PIPE ] ##

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
}

{

    package FakeWatcher;
    sub new    { bless { active => 1, params => $_[1], at => $_[2] }, $_[0] }
    sub cancel { $_[0]->{'active'} = 0 }
    sub is_active { $_[0]->{'active'} }

    sub poll {
        $_[0]->{'params'}{'poll'} = $_[1] if @_ > 1;
        return $_[0]->{'params'}{'poll'};
    }
}

## module loader : translate p7 syntax, compile as anonymous sub ##

sub translate_code {
    my $code = shift;
    $code =~ s{<\[\$(\w+)\]>(?=\s*->)}{chr(36).qq|code{\$$1}|}eg;
    $code =~ s{<\[([A-Za-z][-\w.]*)\]>(?=\s*->)}{chr(36).qq|code{'$1'}|}eg;
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

    $src =~ s{\n#[^\n]*\z}{\n} while $src =~ m{\n#[,\[\\|:][^\n]*\z};

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
    base.interval.next
    base.interval.rhythm.non-linear
    nameserv.upstream_address
    nameserv.upstream_entries
    nameserv.reply.echo_question
    nameserv.cache.client_allowed
    nameserv.cache.key
    nameserv.cache.put
    nameserv.cache.own_name
    nameserv.cache.route_upstreams
    nameserv.cache.domain_route
    nameserv.cache.upstreams
    nameserv.cache.targets
    nameserv.cache.forward
    nameserv.cache.forward.try
    nameserv.cache.forward.next
    nameserv.cache.complete
    nameserv.cache.handler.answer
    nameserv.cache.handler.timeout
    nameserv.cmd.set-behaviour
    nameserv.cmd.set-encrypted-upstreams
    nameserv.cmd.encrypted-upstreams
    nameserv.cmd.set-upstreams
    nameserv.enc.normalize
    nameserv.enc.load_cfg
    nameserv.enc.list
    nameserv.enc.active
    nameserv.enc.dot_frame
    nameserv.enc.dot_unframe
    nameserv.enc.doh_request
    nameserv.enc.doh_response
    nameserv.enc.connect
    nameserv.enc.close
    nameserv.enc.note_failure
    nameserv.enc.degraded
    nameserv.enc.recovered
    nameserv.enc.detach
    nameserv.enc.fail
    nameserv.enc.start
    nameserv.enc.pump
    nameserv.enc.flush
    nameserv.enc.handler.io
    nameserv.enc.dispatch
    nameserv.enc.deliver
    nameserv.enc.handler.timeout
    |
) {
    load_module($mod);
}

## --- stubs ------------------------------------------------------------- ##

my @logs;
$code{'base.logs'}
    = sub { push @logs, sprintf $_[1] // '', @_[ 2 .. $#_ ]; return TRUE };
$code{'base.log'}        = sub { push @logs, $_[1] // ''; return TRUE };
$code{'base.prng.bytes'} = sub {
    return join '', map { chr int rand 256 } 1 .. ( $_[0] // 2 );
};

my @io_watchers;
my @timers;
$code{'event.add_io'} = sub {
    my $w = FakeWatcher->new( $_[0] );
    push @io_watchers, $w;
    return $w;
};
$code{'event.add_timer'} = sub {
    my $params = shift;
    my $w = FakeWatcher->new( $params, time + ( $params->{'after'} // 0 ) );
    push @timers, $w;
    return $w;
};

## the event loop : select over the active io watchers, fire due timers ##

sub run_loop {
    my ( $until, $max ) = @_;
    my $deadline = time + ( $max // 10 );
    while ( time < $deadline and not $until->() ) {
        @io_watchers = grep { $_->is_active } @io_watchers;
        @timers      = grep { $_->is_active } @timers;
        my ( $rs, $ws ) = ( IO::Select->new, IO::Select->new );
        my ( %r, %w );
        for my $watcher (@io_watchers) {
            my $fd   = $watcher->{'params'}{'fd'};
            my $poll = $watcher->poll;
            next if not defined fileno $fd;
            if ( $poll =~ m|r| ) {
                $rs->add($fd);
                $r{ fileno $fd } = $watcher;
            }
            if ( $poll =~ m|w| ) {
                $ws->add($fd);
                $w{ fileno $fd } = $watcher;
            }
        }
        my ( $rd, $wr ) = IO::Select->select( $rs, $ws, undef, 0.03 );
        my %fired;
        for my $fd ( @{ $rd // [] } ) {
            my $watcher = $r{ fileno $fd } // next;
            $fired{$watcher} = $watcher;
        }
        for my $fd ( @{ $wr // [] } ) {
            my $watcher = $w{ fileno $fd } // next;
            $fired{$watcher} = $watcher;
        }
        ## openssl may hold decrypted bytes the socket does not show ##
        for my $watcher (@io_watchers) {
            my $fd = $watcher->{'params'}{'fd'};
            next if not defined fileno $fd;
            $fired{$watcher} = $watcher
                if $watcher->poll =~ m|r|
                and eval { $fd->can('pending') and $fd->pending };
        }
        for my $watcher ( values %fired ) {
            next if not $watcher->is_active;
            $code{ $watcher->{'params'}{'handler'} }
                ->( FakeEvent->new( $watcher->{'params'}{'data'} ) );
        }
        for my $timer (@timers) {
            next if not $timer->is_active or time < $timer->{'at'};
            $timer->cancel;
            $code{ $timer->{'params'}{'handler'} }
                ->( FakeEvent->new( $timer->{'params'}{'data'} ) );
        }
    }
    return $until->() ? TRUE : FALSE;
}

## --- assertion helpers -------------------------------------------------- ##

my ( $pass_count, $fail_count ) = ( 0, 0 );

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

## --- certificates and servers ------------------------------------------ ##

my $tmp = tempdir( 'p7-enc-XXXXXX', 'TMPDIR' => 1, 'CLEANUP' => 1 );

sub make_cert {
    my ( $label, $name ) = @_;
    my ( $cert,  $key )  = map {"$tmp/$label.$ARG"} qw| crt key |;
    my $rc = system(
        'openssl', 'req',       '-x509',
        '-newkey', 'rsa:2048',  '-nodes',
        '-keyout', $key,        '-out',
        $cert,     '-days',     '2',
        '-subj',   "/CN=$name", '-addext',
        "subjectAltName=DNS:$name"
    );
    die "openssl failed for $label" if $rc != 0;
    return ( $cert, $key );
}

my ( $cert_a, $key_a ) = make_cert( 'a', 'dns.test.example' );
my ( $cert_b, $key_b ) = make_cert( 'b', 'other.test.example' );

my @pids;
END { kill 'TERM', @pids; waitpid $ARG, 0 for @pids }

sub answer_for {
    my ( $wire, $address ) = @_;
    my $q          = Net::DNS::Packet->new( \$wire ) or return undef;
    my $reply      = $q->reply;
    my ($question) = $q->question;
    $reply->push(
        'answer' => Net::DNS::RR->new(
            'name'    => $question->qname,
            'type'    => 'A',
            'ttl'     => 60,
            'address' => $address
        )
    );
    $reply->header->ra(1);
    return $reply->data(65535);
}

sub read_exact {
    my ( $fh, $length ) = @_;
    my $buffer = '';
    while ( length $buffer < $length ) {
        my $got = sysread $fh, $buffer, $length - length $buffer,
            length $buffer;
        return undef if not $got;
    }
    return $buffer;
}

sub tls_server_child {
    my ( $listener, $o, $count_file ) = @_;
    $SIG{'TERM'} = sub { POSIX::_exit(0) };
    my $served = 0;
    while ( my $raw = $listener->accept ) {
        open my $cf, '>>:raw', $count_file or POSIX::_exit(1);
        print {$cf} "x\n";
        close $cf;
        my $c = IO::Socket::SSL->start_SSL(
            $raw,
            'SSL_server'    => 1,
            'SSL_cert_file' => $o->{'cert'},
            'SSL_key_file'  => $o->{'key'},
        ) or next;
        if ( $o->{'mode'} eq 'silent' ) {
            1 while sysread $c, my $junk, 4096;
            next;
        }
        while (1) {
            my ( $wire, $reply );
            if ( $o->{'mode'} eq 'dot' ) {
                my $head = read_exact( $c, 2 ) // last;
                $wire  = read_exact( $c, unpack 'n', $head ) // last;
                $reply = answer_for( $wire, $o->{'address'} ) // last;
                syswrite $c, pack( 'n', length $reply ) . $reply;
            } else {
                my $head = '';
                while ( $head !~ m|\r\n\r\n| ) {
                    my $got = sysread $c, my $chunk, 1;
                    last if not $got;
                    $head .= $chunk;
                }
                last if $head !~ m|\r\n\r\n|;
                $head =~ m|^POST (\S+) HTTP/1\.1\r\n| or last;
                last if $1 ne $o->{'path'};
                $head =~ m|^Content-Type: application/dns-message\r$|mi
                    or last;
                $head =~ m|^Content-Length: (\d+)\r$|mi or last;
                $wire  = read_exact( $c, $1 )                 // last;
                $reply = answer_for( $wire, $o->{'address'} ) // last;
                my $extra
                    = $o->{'variant'} eq 'close'
                    ? "Connection: close\r\n"
                    : '';

                if ( $o->{'variant'} eq 'chunked' ) {
                    my $cut = 20;
                    syswrite $c,
                          "HTTP/1.1 200 OK\r\n"
                        . "Content-Type: application/dns-message\r\n"
                        . "Transfer-Encoding: chunked\r\n\r\n"
                        . sprintf( "%x\r\n", $cut )
                        . substr( $reply, 0, $cut ) . "\r\n"
                        . sprintf( "%x\r\n", length($reply) - $cut )
                        . substr( $reply, $cut )
                        . "\r\n0\r\n\r\n";
                } else {
                    syswrite $c,
                          "HTTP/1.1 200 OK\r\nContent-Type: "
                        . "application/dns-message\r\n"
                        . $extra
                        . 'Content-Length: '
                        . length($reply)
                        . "\r\n\r\n"
                        . $reply;
                }
                last if $o->{'variant'} eq 'close';
            }
            $served++;
            last
                if $o->{'close_after'} and $served % $o->{'close_after'} == 0;
        }
        close $c;
    }
    POSIX::_exit(0);
}

sub start_tls_server {
    my (%o) = @_;
    $o{'variant'} //= 'normal';
    $o{'address'} //= '192.0.2.99';
    $o{'path'}    //= '/dns-query';
    my $listener = IO::Socket::INET->new(
        'Listen'    => 5,
        'LocalAddr' => '127.0.0.1',
        'LocalPort' => 0,
        'ReuseAddr' => 1
    ) or die "listen failed : $OS_ERROR";
    my $port       = $listener->sockport;
    my $count_file = "$tmp/accepts.$port";
    my $pid        = fork;
    die 'fork failed'                               if not defined $pid;
    tls_server_child( $listener, \%o, $count_file ) if not $pid;
    close $listener;
    push @pids, $pid;
    return { 'port' => $port, 'count_file' => $count_file };
}

sub start_udp_server {
    my ($address) = @_;
    my $sock = IO::Socket::INET->new(
        'Proto'     => 'udp',
        'LocalAddr' => '127.0.0.1',
        'LocalPort' => 0
    ) or die "udp bind failed : $OS_ERROR";
    my $port       = $sock->sockport;
    my $count_file = "$tmp/udp.$port";
    my $pid        = fork;
    die 'fork failed' if not defined $pid;
    if ( not $pid ) {
        $SIG{'TERM'} = sub { POSIX::_exit(0) };
        while ( my $from = $sock->recv( my $wire, 65535 ) ) {
            open my $cf, '>>:raw', $count_file or POSIX::_exit(1);
            print {$cf} "x\n";
            close $cf;
            my $reply = answer_for( $wire, $address ) // next;
            $sock->send( $reply, 0, $from );
        }
        POSIX::_exit(0);
    }
    close $sock;
    push @pids, $pid;
    return { 'port' => $port, 'count_file' => $count_file };
}

sub accepts {
    my $server = shift;
    open my $fh, '<:raw', $server->{'count_file'} or return 0;
    my @lines = <$fh>;
    return scalar @lines;
}

## --- state -------------------------------------------------------------- ##

sub reset_state {
    $data{'nameserv'} = {
        'cfg' => {
            'cache' => {
                'enabled'          => 'yes',
                'max_ttl'          => 86400,
                'max_negative_ttl' => 900,
                'max_entries'      => 7777,
                'upstream'         => '',
                'upstream_timeout' => 3,
            },
            'encrypted' => { 'ca_file' => $cert_a },
        },
        'zones' => {},
        'stats' => {
            'cache_misses'    => 0,
            'cache_forwarded' => 0,
            'cache_servfail'  => 0
        },
        'cache'     => { 'entries' => {}, 'in_flight' => {} },
        'upstreams' => {
            'by_source'           => {},
            'held_by_source'      => {},
            'domain_by_source'    => {},
            'behaviour_by_source' => {},
        },
        'encrypted' => { 'upstreams' => {} },
        'enc'       => { 'pool'      => {}, 'health' => {} },
    };
    $data{'base'}{'interval'}{'cfg'}{'type'}{'dns-enc-reconnect'}
        = { start => 3.4, factor => 1.6, cap => 377, cap_jitter => 55 };
    $data{'base'}{'interval'}{'cfg'}{'type'}{'dns-enc-wait'}
        = { start => 4.7, factor => 1.2, cap => 8.1, cap_jitter => 1.3 };
    @io_watchers = ();
    @timers      = ();
    @logs        = ();
    return;
}

sub add_upstream {
    my (%o) = @_;
    $data{'nameserv'}{'encrypted'}{'upstreams'}{ $o{'name'} } = {
        'tls_name' => 'dns.test.example',
        'address'  => '127.0.0.1',
        'path'     => $o{'protocol'} eq 'doh' ? '/dns-query' : undef,
        'source'   => 'cmd',
        %o
    };
    return;
}

sub set_behaviour {
    my ( $source, $behaviour, @dhcp ) = @_;
    $data{'nameserv'}{'upstreams'}{'behaviour_by_source'}{$source}
        = { 'behaviour' => $behaviour, 'dhcp' => \@dhcp, 'at' => time };
    return;
}

sub set_static {
    $data{'nameserv'}{'cfg'}{'cache'}{'upstream'} = join ' ', @_;
    delete $data{'nameserv'}{'cache'}{'upstream_list'};
    return;
}

sub ask {
    my ( $qname, $qtype ) = @_;
    my $q = Net::DNS::Packet->new( $qname, $qtype // 'A' );
    $q->header->id(4242);
    $q->header->rd(1);
    my @got;
    $code{'nameserv.cache.forward'}->( $q, sub { push @got, shift } );
    return \@got;
}

sub answer_address {
    my $reply = shift // return undef;
    my ($rr) = grep { $_->type eq 'A' } $reply->answer;
    return defined $rr ? $rr->address : undef;
}

sub ask_wait {
    my ( $qname, $max ) = @_;
    my $got              = ask($qname);
    my $returned_at_once = scalar @{$got} ? 0 : 1;
    run_loop( sub { scalar @{$got} }, $max // 10 );
    return ( $got->[0], $returned_at_once );
}

sub logged {
    my $re = shift;
    return scalar grep { $_ =~ $re } @logs;
}

## =========================================================================== ##
## pure parts                                                                  ##
## =========================================================================== ##

{
    my ( $e, $err ) = $code{'nameserv.enc.normalize'}->(
        {   name     => 'Quad9-dot',
            protocol => 'DoT',
            address  => '9.9.9.9',
            tls_name => 'DNS.Quad9.net'
        }
    );
    check(
        'normalize : dot defaults [ port 853, lowercase, no path ]',
        $e
            && $e->{'name'} eq 'quad9-dot'
            && $e->{'protocol'} eq 'dot'
            && $e->{'port'} == 853
            && $e->{'tls_name'} eq 'dns.quad9.net'
            && not defined $e->{'path'}
    );
    ($e) = $code{'nameserv.enc.normalize'}->(
        {   name     => 'q',
            protocol => 'doh',
            address  => '2620:fe::fe',
            tls_name => 'dns.quad9.net'
        }
    );
    check(
        'normalize : doh defaults [ port 443, /dns-query ], ipv6 canonical',
        $e
            && $e->{'port'} == 443
            && $e->{'path'} eq '/dns-query'
            && $e->{'address'} eq '2620:fe::fe'
    );
    my %base = (
        name     => 'x',
        protocol => 'dot',
        address  => '192.0.2.1',
        tls_name => 'dns.example'
    );
    for my $case (
        [ 'protocol udp refused',     { protocol => 'udp' } ],
        [ 'tls hostname required',    { tls_name => '' } ],
        [ 'tls hostname with space',  { tls_name => 'a b' } ],
        [ 'hostname address refused', { address  => 'resolver.example' } ],
        [ 'port 0 refused',           { port     => 0 } ],
        [ 'port 70000 refused',       { port     => 70000 } ],
        [ 'bad name refused',         { name     => '9x' } ],
        [   'doh path with a line break refused',
            { protocol => 'doh', path => "/a\r\nHost: evil" }
        ],
        [ 'doh path must start with /', { protocol => 'doh', path => 'x' } ],
    ) {
        my ( $entry, $reason )
            = $code{'nameserv.enc.normalize'}->( { %base, %{ $case->[1] } } );
        check( "normalize : $case->[0]",
            ( !defined $entry && length $reason ) );
    }
}

{
    my $wire  = Net::DNS::Packet->new( 'a.example', 'A' )->data;
    my $frame = $code{'nameserv.enc.dot_frame'}->($wire);
    check(
        'dot frame : 2 byte length prefix',
        length $frame == 2 + length $wire
            && unpack( 'n', $frame ) == length $wire
            && substr( $frame, 2 ) eq $wire
    );
    my $buffer = $frame . $frame;
    my @m      = $code{'nameserv.enc.dot_unframe'}->( \$buffer );
    check( 'dot unframe : two messages out of one read',
        @m == 2 && $m[0] eq $wire && $m[1] eq $wire && $buffer eq '' );
    $buffer = $frame . substr( $frame, 0, 5 );
    @m      = $code{'nameserv.enc.dot_unframe'}->( \$buffer );
    check( 'dot unframe : a partial message stays buffered',
        @m == 1 && length $buffer == 5 );
    $buffer = pack( 'n', 3 ) . 'abc';
    @m      = $code{'nameserv.enc.dot_unframe'}->( \$buffer );
    check( 'dot unframe : shorter than a dns header is an error',
        @m == 1 && not defined $m[0] );
    $buffer = substr( $frame, 0, 1 );
    @m      = $code{'nameserv.enc.dot_unframe'}->( \$buffer );
    check( 'dot unframe : a lone length byte waits', not @m );
}

{
    my $up = {
        name     => 'q',
        protocol => 'doh',
        address  => '192.0.2.1',
        port     => 443,
        tls_name => 'dns.example',
        path     => '/dns-query?x=1'
    };
    my $wire = Net::DNS::Packet->new( 'a.example', 'A' )->data;
    my $req  = $code{'nameserv.enc.doh_request'}->( $up, $wire );
    my ( $head, $body ) = split m|\r\n\r\n|, $req, 2;
    my @h = split m|\r\n|, $head;
    check(
        'doh request : post with path and query',
        $h[0] eq 'POST /dns-query?x=1 HTTP/1.1'
    );
    check(
        'doh request : host is the tls name, no port 443',
        ( grep { $_ eq 'Host: dns.example' } @h ) == 1
    );
    check(
        'doh request : dns-message content type, accept, length',
        ( grep { $_ eq 'Content-Type: application/dns-message' } @h )
            && ( grep { $_ eq 'Accept: application/dns-message' } @h )
            && ( grep { $_ eq 'Content-Length: ' . length $wire } @h )
    );
    check( 'doh request : body is the dns wire, byte for byte',
        $body eq $wire );
    my $other = { %{$up}, port => 8443, tls_name => '2001:db8::1' };
    ( $head = $code{'nameserv.enc.doh_request'}->( $other, $wire ) )
        =~ m|^Host: (.+?)\r$|m;
    ## octets : flagged header strings must not upgrade the binary wire ##
    my $binary  = join '', map {chr} 0 .. 255;
    my $flagged = { %{$up} };
    utf8::upgrade( $flagged->{$_} ) for qw| path tls_name |;
    my $octets = $code{'nameserv.enc.doh_request'}->( $flagged, $binary );
    my ($octet_head) = split m|\r\n\r\n|, $octets, 2;
    check(
        'doh request : octets with flagged strings and a 0..255 wire',
        !utf8::is_utf8($octets)
            && length($octets) == length($octet_head) + 4 + 256
            && substr( $octets, -256 ) eq $binary
    );
    check(
        'doh request : a wide character in the path is refused',
        !defined $code{'nameserv.enc.doh_request'}
            ->( { %{$up}, path => "/\x{263a}" }, $wire )
    );
    check(
        'doh request : a trailing newline '
            . 'in the path is refused by normalize',
        !defined(
            (   $code{'nameserv.enc.normalize'}->(
                    {   name     => 'x',
                        protocol => 'doh',
                        address  => '192.0.2.1',
                        tls_name => 'dns.example',
                        path     => "/q\n"
                    }
                )
            )[0]
        )
    );
    check(
        'doh request : a non ascii letter in the path is refused',
        !defined(
            (   $code{'nameserv.enc.normalize'}->(
                    {   name     => 'x',
                        protocol => 'doh',
                        address  => '192.0.2.1',
                        tls_name => 'dns.example',
                        path     => "/\x{e9}"
                    }
                )
            )[0]
        )
    );
    check( 'doh request : host with port and bracketed ipv6',
        $1 eq '[2001:db8::1]:8443' );
}

{
    my $reply = Net::DNS::Packet->new( 'a.example', 'A' )->data;
    my $ok    = sub {
        my ( $extra, $body ) = @_;
        return
              "HTTP/1.1 200 OK\r\nContent-Type: application/dns-message\r\n"
            . $extra . "\r\n"
            . $body;
    };
    my $buffer
        = $ok->( 'Content-Length: ' . length($reply) . "\r\n", $reply );
    my @r = $code{'nameserv.enc.doh_response'}->( \$buffer );
    check( 'doh response : content-length body',
        $r[0] eq 'ok' && $r[1] eq $reply && !$r[2] && $buffer eq '' );

    my $full = $ok->( 'Content-Length: ' . length($reply) . "\r\n", $reply );
    my $part = substr $full, 0, length($full) - 3;
    @r = $code{'nameserv.enc.doh_response'}->( \$part );
    check( 'doh response : an incomplete body waits', $r[0] eq 'need' );
    $part = substr $full, 0, 20;
    @r    = $code{'nameserv.enc.doh_response'}->( \$part );
    check( 'doh response : an incomplete header waits', $r[0] eq 'need' );

    my $chunked = $ok->(
        "Transfer-Encoding: chunked\r\n",
        sprintf( "%x\r\n", 20 )
            . substr( $reply, 0, 20 ) . "\r\n"
            . sprintf( "%x\r\n", length($reply) - 20 )
            . substr( $reply, 20 )
            . "\r\n0\r\n\r\n"
    );
    my $growing = '';
    my @states;

    for my $piece ( unpack '(a7)*', $chunked ) {
        $growing .= $piece;
        my @x = $code{'nameserv.enc.doh_response'}->( \$growing );
        push @states, $x[0];
        @r = @x;
    }
    check(
        'doh response : chunked body, fed in small pieces',
        $r[0] eq 'ok'
            && $r[1] eq $reply
            && ( grep { $_ eq 'need' } @states ) > 3
    );

    $buffer = $ok->(
        "Connection: close\r\nContent-Length: " . length($reply) . "\r\n",
        $reply
    );
    @r = $code{'nameserv.enc.doh_response'}->( \$buffer );
    check( 'doh response : connection close is reported',
        $r[0] eq 'ok' && $r[2] );

    $buffer = "HTTP/1.1 503 Service Unavailable\r\nContent-Length: 0\r\n\r\n";
    @r      = $code{'nameserv.enc.doh_response'}->( \$buffer );
    check(
        'doh response : a non 200 status is an error',
        $r[0] eq 'error' && $r[1] =~ m|503|
    );
    $buffer
        = "HTTP/1.1 200 OK\r\nContent-Type: text/html\r\n"
        . "Content-Length: 20\r\n\r\n"
        . 'x' x 20;
    @r = $code{'nameserv.enc.doh_response'}->( \$buffer );
    check( 'doh response : a wrong content type is an error',
        $r[0] eq 'error' );
    $buffer
        = "HTTP/1.1 200 OK\r\nContent-Type: "
        . "application/dns-message\r\nContent-Length: 999999\r\n\r\n";
    @r = $code{'nameserv.enc.doh_response'}->( \$buffer );
    check( 'doh response : an oversize length is an error',
        $r[0] eq 'error' );
}

## =========================================================================== ##
## config, commands                                                            ##
## =========================================================================== ##

{
    reset_state();
    $data{'nameserv'}{'cfg'}{'encrypted'}{'upstream'} = {
        'good' => {
            'protocol' => 'dot',
            'address'  => '192.0.2.8',
            'tls_name' => 'dns.example'
        },
        'bad' => { 'protocol' => 'dot', 'address' => '192.0.2.9' },
    };
    $code{'nameserv.enc.load_cfg'}->();
    my @list = $code{'nameserv.enc.list'}->();
    check( 'config : valid entry loaded with its defaults',
        @list == 1 && $list[0]{'name'} eq 'good' && $list[0]{'port'} == 853 );
    check(
        'config : an invalid entry is skipped and logged',
        logged(qr|bad from config ignored : tls hostname missing|)
    );

    local $call = { 'args' => 'mine doh 192.0.2.7 dns.example 8443 /q' };
    my $r = $code{'nameserv.cmd.set-encrypted-upstreams'}->();
    check( 'set-encrypted-upstreams : accepted', $r->{'mode'} eq 'size' );
    $code{'nameserv.enc.load_cfg'}->();
    check(
        'reload : command entries stay, config entries are re-read',
        scalar( () = $code{'nameserv.enc.list'}->() ) == 2
    );
    my $text = $code{'nameserv.cmd.encrypted-upstreams'}->()->{'data'};
    check(
        'encrypted-upstreams : lists both with tls name and path',
        $text
            =~ m|mine\s+doh 192\.0\.2\.7:8443\s+tls name dns\.example\s+path /q|
            && $text =~ m|good\s+dot 192\.0\.2\.8:853|
            && $text =~ m|path : plain port 53|
    );
    $call = { 'args' => 'mine dot 192.0.2.7' };
    check(
        'set-encrypted-upstreams : tls name is required',
        $code{ 'nameserv.cmd.set-e' . 'ncrypted-upstreams' }->()->{'mode'} eq
            'false'
    );
    $call = { 'args' => 'mine off' };
    $code{'nameserv.cmd.set-encrypted-upstreams'}->();
    check(
        'set-encrypted-upstreams : off removes',
        scalar( () = $code{'nameserv.enc.list'}->() ) == 1
    );

    $call = { 'args' => 'dhcp:eth0 intercepting 192.0.2.1 192.0.2.53' };
    check( 'set-behaviour : accepted',
        $code{'nameserv.cmd.set-behaviour'}->()->{'mode'} eq 'size' );
    check( 'set-behaviour : change logged with the path',
        logged(qr|unmeasured -> intercepting \[ encrypted path \]|) );
    $call = { 'args' => 'dhcp:eth0 trusted 192.0.2.1' };
    check(
        'set-behaviour : an unknown behaviour is refused',
        $code{'nameserv.cmd.set-behaviour'}->()->{'mode'} eq 'false'
    );
    $call = { 'args' => 'dhcp:eth0 open 999.1.1.1' };
    check(
        'set-behaviour : an invalid address is refused',
        $code{'nameserv.cmd.set-behaviour'}->()->{'mode'} eq 'false'
    );
    $text = do {
        $call = { 'args' => 'dhcp:eth0 intercepting 192.0.2.1' };
        $code{'nameserv.cmd.set-behaviour'}->();
        $code{'nameserv.cmd.encrypted-upstreams'}->()->{'data'};
    };
    check(
        'encrypted-upstreams : shows the encrypted path and the fallback',
        $text
            =~ m|path : encrypted \[ dhcp:eth0 \] ; degraded fallback : 192\.0\.2\.1|
    );
}

## =========================================================================== ##
## the path choice per behaviour                                               ##
## =========================================================================== ##

sub target_text {
    return join ' ', map {
        $_->{'kind'} eq 'plain'
            ? (
            $_->{'degraded'}
            ? "held:$_->{'server'}"
            : "plain:$_->{'server'}"
            )
            : "$_->{'kind'}:$_->{'upstream'}{'name'}"
    } $code{'nameserv.cache.targets'}->(shift);
}

{
    reset_state();
    set_static( '192.0.2.200', '192.0.2.201' );
    add_upstream( name => 'dot-1', protocol => 'dot', port => 853 );
    add_upstream( name => 'doh-1', protocol => 'doh', port => 443 );
    $data{'nameserv'}{'upstreams'}{'by_source'}{'dhcp:eth0'} = ['192.0.2.1'];

    my $plain = 'plain:192.0.2.200 plain:192.0.2.201 plain:192.0.2.1';
    for my $b (qw| open filtering unknown unmeasured |) {
        set_behaviour( 'dhcp:eth0', $b, '192.0.2.1' );
        check(
            "path : $b keeps the plain port 53 path unchanged",
            target_text('www.example.org') eq $plain
        );
    }
    for my $b (qw| intercepting blocking-outside |) {
        set_behaviour( 'dhcp:eth0', $b, '192.0.2.1' );
        check(
            "path : $b goes encrypted, then the held server [ degraded ]",
            target_text('www.example.org') eq
                'doh:doh-1 dot:dot-1 held:192.0.2.1'
        );
    }
    check(
        'path : the plain static upstreams are never in the encrypted list',
        target_text('www.example.org') !~ m|192\.0\.2\.20| );
    check(
        'path : own names go to the owner\'s encrypted '
            . 'upstreams only, no held server, no plain port 53',
        target_text('host.lan') eq 'doh:doh-1 dot:dot-1'
    );
    set_behaviour( 'dhcp:eth0', 'open', '192.0.2.1' );
    check(
        'path : own names on a plain network stay on the static upstreams',
        target_text('host.lan') eq 'plain:192.0.2.200 plain:192.0.2.201'
    );
    set_behaviour( 'dhcp:eth0', 'intercepting', '192.0.2.1' );
    $data{'nameserv'}{'upstreams'}{'domain_by_source'}{'dhcp:eth0'} = {
        'domains'   => ['corp.example'],
        'addresses' => ['192.0.2.1']
    };
    check(
        'path : a split domain route stays on its own dns',
        target_text('a.corp.example') eq 'plain:192.0.2.1'
    );
    check( 'path : other names still go encrypted',
        target_text('www.example.org') =~ m|^doh:doh-1 dot:dot-1| );
    delete $data{'nameserv'}{'upstreams'}{'domain_by_source'}{'dhcp:eth0'};

    $data{'nameserv'}{'encrypted'}{'upstreams'} = {};
    check(
        'path : no encrypted upstream configured -> the held server',
        target_text('www.example.org') eq 'held:192.0.2.1'
    );
    set_behaviour( 'dhcp:eth0', 'intercepting' );
    check(
        'path : nothing encrypted and no held server -> plain, never no dns',
        target_text('www.example.org') eq
            'held:192.0.2.200 held:192.0.2.201 held:192.0.2.1'
    );
    check(
        'path : own names with nothing '
            . 'encrypted stay on the static upstreams',
        target_text('host.lan') eq 'plain:192.0.2.200 plain:192.0.2.201'
    );
    check(
        'path : that case names its reason',
        ( $code{'nameserv.cache.targets'}->('www.example.org') )[0]{'reason'}
            =~ m|no encrypted upstream configured|
    );
}

## =========================================================================== ##
## live : non-blocking queries                                                 ##
## =========================================================================== ##

{    ## dns over tls : pooled connection, reuse, no plain traffic ##
    reset_state();
    ## the intercepted path ##
    my $plain = start_udp_server('198.51.100.1');
    set_static("127.0.0.1:$plain->{'port'}");
    my $dot = start_tls_server(
        'mode' => 'dot',
        'cert' => $cert_a,
        'key'  => $key_a
    );
    add_upstream(
        name     => 'dot-1',
        protocol => 'dot',
        port     => $dot->{'port'}
    );
    set_behaviour( 'dhcp:eth0', 'intercepting' );

    my ( $reply, $at_once ) = ask_wait('one.example.org');
    check( 'dot : the query returns at once, the answer comes by the loop',
        $at_once );
    check( 'dot : answered through tls',
        answer_address($reply) && answer_address($reply) eq '192.0.2.99' );
    check( 'dot : certificate verified, upstream connected',
        logged(qr|dot-1 connected|) );
    ( $reply, undef ) = ask_wait('two.example.org');
    check( 'dot : second query answered',
        answer_address($reply) && answer_address($reply) eq '192.0.2.99' );
    check( 'dot : the tls connection is reused, one accept for two queries',
        accepts($dot) == 1 );

    my @got = map { ask("par$ARG.example.org") } 1 .. 3;
    run_loop(
        sub {
            ( grep { @{$ARG} } @got ) == 3;
        },
        10
    );
    check(
        'dot : three concurrent queries answered on one connection',
        (   grep { @{$ARG} && answer_address( $ARG->[0] ) eq '192.0.2.99' }
                @got
            ) == 3
            && accepts($dot) == 1
    );
    check( 'dot : plain port 53 never used', accepts($plain) == 0 );
    check( 'dot : nothing left in flight',
        not %{ $data{'nameserv'}{'cache'}{'in_flight'} } );
}

{    ## dns over https ##
    reset_state();
    my $doh = start_tls_server(
        'mode' => 'doh',
        'cert' => $cert_a,
        'key'  => $key_a,
        'path' => '/dns-query'
    );
    add_upstream(
        name     => 'doh-1',
        protocol => 'doh',
        port     => $doh->{'port'},
        path     => '/dns-query'
    );
    set_behaviour( 'dhcp:eth0', 'blocking-outside', '192.0.2.1' );
    my ($reply) = ask_wait('one.example.org');
    check( 'doh : answered through https',
        answer_address($reply) && answer_address($reply) eq '192.0.2.99' );
    my @got = map { ask("q$ARG.example.org") } 1 .. 3;
    run_loop(
        sub {
            ( grep { @{$ARG} } @got ) == 3;
        },
        10
    );
    check(
        'doh : queued queries go one at a time on the kept-alive connection',
        (   grep { @{$ARG} && answer_address( $ARG->[0] ) eq '192.0.2.99' }
                @got
            ) == 3
            && accepts($doh) == 1
    );
}

{    ## doh variants : chunked, connection close ##
    for my $variant (qw| chunked close |) {
        reset_state();
        my $doh = start_tls_server(
            'mode'    => 'doh',
            'cert'    => $cert_a,
            'key'     => $key_a,
            'variant' => $variant
        );
        add_upstream(
            name     => 'doh-1',
            protocol => 'doh',
            port     => $doh->{'port'}
        );
        set_behaviour( 'dhcp:eth0', 'intercepting', '192.0.2.1' );
        my @got = map { ask("v$ARG.example.org") } 1 .. 2;
        run_loop(
            sub {
                ( grep { @{$ARG} } @got ) == 2;
            },
            10
        );
        check(
            "doh : server answers $variant",
            (   grep {
                    @{$ARG}
                        && answer_address( $ARG->[0] ) eq '192.0.2.99'
                } @got
            ) == 2
        );
        check(
            'doh : a closing server costs a new connection, no failure',
            $variant ne 'close'
                || ( accepts($doh) == 2 && !logged(qr|DEGRADED|) )
        );
    }
}

{    ## lazy reconnect : the server closes after every answer ##
    reset_state();
    my $dot = start_tls_server(
        'mode'        => 'dot',
        'cert'        => $cert_a,
        'key'         => $key_a,
        'close_after' => 1
    );
    add_upstream(
        name     => 'dot-1',
        protocol => 'dot',
        port     => $dot->{'port'}
    );
    set_behaviour( 'dhcp:eth0', 'intercepting' );
    my ($r1) = ask_wait('a.example.org');
    my ($r2) = ask_wait('b.example.org');
    my ($r3) = ask_wait('c.example.org');
    check(
        'reconnect : stale pooled connections are replaced lazily',
        (   grep { $ARG && answer_address($ARG) eq '192.0.2.99' } $r1,
            $r2, $r3
            ) == 3
            && accepts($dot) >= 3
    );
    check( 'reconnect : no degraded mode, no back-off',
        !logged(qr|DEGRADED|) && !%{ $data{'nameserv'}{'enc'}{'health'} } );
}

{    ## certificate failures : never plain ##
    reset_state();
    my $plain = start_udp_server('198.51.100.1');
    set_static("127.0.0.1:$plain->{'port'}");
    my $untrusted = start_tls_server(
        'mode' => 'dot',
        'cert' => $cert_b,
        'key'  => $key_b
    );
    add_upstream(
        name     => 'dot-bad',
        protocol => 'dot',
        port     => $untrusted->{'port'}
    );
    set_behaviour( 'dhcp:eth0', 'intercepting' );
    my ( $reply, undef ) = ask_wait('x.example.org');
    check(
        'verify : an untrusted certificate fails the upstream',
        logged(
            qr|dot-bad .* failed : tls handshake failed : certificate verification failed|
        )
    );
    check(
        'verify : no fallback -> servfail, not an answer',
        $reply && $reply->header->rcode eq 'SERVFAIL'
    );
    check( 'verify : never silently downgraded to plain dns',
        accepts($plain) == 0 );
    my $h = $data{'nameserv'}{'enc'}{'health'}{'dot-bad'};
    check(
        'verify : the failure sets a back-off from base.interval.next',
        $h
            && $h->{'until'} > time
            && $h->{'until'} < time + 10
            && $h->{'state'}{'last'}
    );
    my $before = accepts($untrusted);
    ( $reply, undef ) = ask_wait('y.example.org');
    check(
        'verify : within the back-off the upstream is not contacted',
        accepts($untrusted) == $before && $reply->header->rcode eq 'SERVFAIL'
    );
}

{    ## hostname mismatch : trusted certificate, wrong name ##
    reset_state();
    $data{'nameserv'}{'cfg'}{'encrypted'}{'ca_file'} = $cert_b;
    my $srv = start_tls_server(
        'mode' => 'dot',
        'cert' => $cert_b,
        'key'  => $key_b
    );
    add_upstream(
        name     => 'dot-name',
        protocol => 'dot',
        port     => $srv->{'port'}
    );
    set_behaviour( 'dhcp:eth0', 'blocking-outside' );
    my ($reply) = ask_wait('x.example.org');
    check(
        'verify : a certificate for another name fails',
        logged(qr|dot-name .* failed : tls handshake failed|)
            && $reply->header->rcode eq 'SERVFAIL'
    );
    ## the same server, the matching tls name : accepted ##
    reset_state();
    $data{'nameserv'}{'cfg'}{'encrypted'}{'ca_file'} = $cert_b;
    add_upstream(
        name     => 'dot-name',
        protocol => 'dot',
        port     => $srv->{'port'},
        tls_name => 'other.test.example'
    );
    set_behaviour( 'dhcp:eth0', 'blocking-outside' );
    ($reply) = ask_wait('x.example.org');
    check(
        'verify : the same server with its own name is accepted',
        answer_address($reply) && answer_address($reply) eq '192.0.2.99'
    );
}

{    ## degraded : the held server, with the logged reason, then recovery ##
    reset_state();
    my $held      = start_udp_server('192.0.2.53');
    my $untrusted = start_tls_server(
        'mode' => 'dot',
        'cert' => $cert_b,
        'key'  => $key_b
    );
    add_upstream(
        name     => 'dot-bad',
        protocol => 'dot',
        port     => $untrusted->{'port'}
    );
    set_behaviour( 'dhcp:eth0', 'intercepting', "127.0.0.1:$held->{'port'}" );
    my ($reply) = ask_wait('d1.example.org');
    check(
        'degraded : the held server answers',
        $reply
            && answer_address($reply) eq '192.0.2.53'
            && accepts($held) == 1
    );
    check(
        'degraded : one clear log line with the reason and the server',
        logged(
            qr|dns DEGRADED : dot-bad : tls handshake failed : certificate verification failed.* -- using the held server 127\.0\.0\.1:\d+ \[ dhcp:eth0 \]|
        )
    );
    ask_wait('d2.example.org');
    check(
        'degraded : logged once on entering, not per query',
        scalar( () = grep {m|dns DEGRADED|} @logs ) == 1
    );
    check( 'degraded : the back-off skips the broken upstream',
        accepts($untrusted) == 1 );

    ## a good encrypted upstream appears : back on it, logged ##
    my $good = start_tls_server(
        'mode' => 'dot',
        'cert' => $cert_a,
        'key'  => $key_a
    );
    add_upstream(
        name     => 'dot-ok',
        protocol => 'dot',
        port     => $good->{'port'}
    );
    ($reply) = ask_wait('d3.example.org');
    check( 'recovery : the working encrypted upstream answers again',
        answer_address($reply) eq '192.0.2.99' );
    check(
        'recovery : leaving the degraded mode is logged',
        logged(qr|dns back on encrypted upstream dot-ok|)
            && not ref $data{'nameserv'}{'enc'}{'degraded_since'}
    );
}

{    ## timeout : connected, never answered ##
    reset_state();
    $data{'base'}{'interval'}{'cfg'}{'type'}{'dns-enc-wait'}
        = { start => 1, factor => 1.01, cap => 1, cap_jitter => 0.1 };
    my $held   = start_udp_server('192.0.2.53');
    my $silent = start_tls_server(
        'mode' => 'silent',
        'cert' => $cert_a,
        'key'  => $key_a
    );
    add_upstream(
        name     => 'dot-quiet',
        protocol => 'dot',
        port     => $silent->{'port'}
    );
    set_behaviour( 'dhcp:eth0', 'blocking-outside',
        "127.0.0.1:$held->{'port'}" );
    my $t0 = time;
    my ($reply) = ask_wait( 't.example.org', 15 );
    check(
        'timeout : a silent encrypted upstream falls back to the held server',
        $reply && answer_address($reply) eq '192.0.2.53'
    );
    check(
        'timeout : within about two timeouts, reason logged',
        time - $t0 < 8
            && logged(qr|DEGRADED : dot-quiet : no answer within 1\.\d s|)
    );
}

{    ## a refused tcp connect is a failed upstream too ##
    reset_state();
    my $held   = start_udp_server('192.0.2.53');
    my $closed = IO::Socket::INET->new(
        'Listen'    => 1,
        'LocalAddr' => '127.0.0.1',
        'LocalPort' => 0
    );
    my $dead_port = $closed->sockport;
    close $closed;
    add_upstream( name => 'dot-gone', protocol => 'dot', port => $dead_port );
    set_behaviour( 'dhcp:eth0', 'intercepting', "127.0.0.1:$held->{'port'}" );
    my ($reply) = ask_wait('r.example.org');
    check(
        'connect refused : the held server answers, reason logged',
        $reply
            && answer_address($reply) eq '192.0.2.53'
            && logged(qr|dot-gone .* failed : tcp connect failed|)
    );
}

{    ## plain behaviours : the encrypted code is never touched ##
    reset_state();
    my $plain = start_udp_server('198.51.100.1');
    set_static("127.0.0.1:$plain->{'port'}");
    add_upstream( name => 'dot-1', protocol => 'dot', port => 1 );
    set_behaviour( 'dhcp:eth0', 'filtering', '192.0.2.1' );
    my ($reply) = ask_wait('p.example.org');
    check(
        'filtering : plain path, plain answer, no tls attempted',
        $reply
            && answer_address($reply) eq '198.51.100.1'
            && not %{ $data{'nameserv'}{'enc'}{'pool'} }
    );
}

printf "\npassed : %d  failed : %d\n", $pass_count, $fail_count;
exit( $fail_count ? 1 : 0 );

#,,,,,,,,,,.,,..,,..,,.,,,.,.,,,.,,.,,...,,..,..,,...,...,.,,,,..,.,,,.,,,,,,,
#3IUE4IFZQTCERXCWJ7K4OBBMDG37337O64OR2J2PKGZDZZAIGE37VRRPBMJX4U255T67EACMZNL4U
#\\\|LZ6C5LXGSEANST2WXQIT4CV2SBI3CVCSTEDKUYVO2G57W3HSYGU \ / AMOS7 \ YOURUM ::
#\[7]P6SXMQSCDNMFXNREAPTQ5LJOFDD67PONTVKNJSVJBHORUIUVFUDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
