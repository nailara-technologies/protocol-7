#!/usr/bin/env perl
use v5.24;
use strict;
use English;
use warnings;

## the production runtime loads the bytes pragma transitively ##
use bytes;

## async acme building blocks : repeated response headers [ headers_multi ],
## letsencr.child.acme.request [ nonce store + prefetch, badNonce retry-once,
## jws post ], schedule_poll \ cancel_poll [ real event timers ], and
## query_txt_async against real udp stub servers on 127.0.0.1 high ports [ one
## answers, one nodata, one dead port -> timeout ]. clients.https is stubbed
## at clients.https.request, replies are delivered explicitly from the event
## loop.

use File::Spec;
use Cwd     qw| abs_path |;
use FindBin qw| $RealBin |;
use IO::Socket::INET;
use IO::Socket::SSL;    ## clients.https.handler.io checks SSL_ERROR ##
use JSON::XS;
use Net::DNS;
use Net::DNS::Packet;
use Net::DNS::RR;
use Event;

BEGIN {
    my $up = File::Spec->updir;
    my $root
        = abs_path(
        File::Spec->rel2abs( File::Spec->catdir( $RealBin, $up, $up ) ) );
    unshift( @INC, File::Spec->catdir( $root, qw| data lib-path pm | ) );
    $main::root_path = $root;
}

use AMOS7::Protocol::P7Syntax qw| p7_syntax__translate |;

use constant TRUE    => 5;
use constant FALSE   => 0;
use constant UNKNOWN => 2;

our %code;
our %data;
our %keys;
our $call;

my ( $test_count, $fail_count ) = ( 0, 0 );

sub ok ($;$) {
    my ( $cond, $label ) = @ARG;
    $test_count++;
    if ($cond) { say "  ok   : $label"; return 1 }
    $fail_count++;
    say "  FAIL : $label";
    return 0;
}

my $runtime_pragmas
    = q{no bytes; use File::stat; use open qw| :encoding(UTF-8) |;};

sub compile_module {
    my ($module_name) = @ARG;
    my $src_path
        = File::Spec->catfile( $main::root_path, 'src', $module_name );
    open( my $fh, '<', $src_path ) or die "cannot read $src_path : $!";
    my $src = join( '', <$fh> );
    close($fh);
    my $cref = eval "$runtime_pragmas sub {\n# line 1 \"$module_name\"\n"
        . p7_syntax__translate($src) . "\n}";
    die "compile failed for $module_name : $EVAL_ERROR" if not defined $cref;
    $code{$module_name} = $cref;
    return $cref;
}

compile_module($ARG)
    for qw| clients.http.parse_response clients.https.handler.io
    letsencr.child.acme.request letsencr.child.acme.handler.nonce
    letsencr.child.acme.handler.response letsencr.child.acme.schedule_poll
    letsencr.child.acme.cancel_poll letsencr.child.dns.query_txt_async
    letsencr.child.dns.handler.txt_reply
    letsencr.child.dns.handler.txt_timeout |;

## --- shared stubs ------------------------------------------------------ ##

my @logs;
$code{'base.log'}
    = sub { push @logs, sprintf( $_[1] // '', @_[ 2 .. $#ARG ] ); return 1 };
$code{'base.logs'}           = $code{'base.log'};
$code{'base.str.eval_error'} = sub { return $EVAL_ERROR // '' };

## real event loop : handlers get the actual Event object, data at ->w->data
$code{'event.add_timer'} = sub {
    my $p = shift;
    return Event->timer(
        'after' => $p->{'after'} // 0,
        'data'  => $p->{'data'},
        'cb'    => sub { $code{ $p->{'handler'} }->(@ARG) },
    );
};
$code{'event.add_io'} = sub {
    my $p = shift;
    return Event->io(
        'fd'   => $p->{'fd'},
        'poll' => $p->{'poll'} // 'r',
        'data' => $p->{'data'},
        'cb'   => sub { $code{ $p->{'handler'} }->(@ARG) },
    );
};
$code{'event.add_idle'} = sub {
    my $p = shift;
    return Event->timer(
        'after' => 0,
        'cb'    => sub { $code{ $p->{'handler'} }->( $p->{'params'} ) },
    );
};

sub run_loop {    ## until Event::unloop or the watchdog fires ##
    my ($max_seconds) = @ARG;
    my $watchdog = Event->timer(
        'after' => $max_seconds // 10,
        'cb'    => sub { Event::unloop() },
    );
    Event::loop();
    $watchdog->cancel;
    return;
}

## clients.https.request stub : record, deliver on_done explicitly later ##
my @https_requests;
$code{'clients.https.request'} = sub {
    my $p = shift;
    push @https_requests, $p;
    return { 'recorded' => TRUE };
};

sub deliver_response {    ## fire the recorded request's on_done in the loop
    my ( $req, $result ) = @ARG;
    die 'no request recorded' if not defined $req;
    $result->{'params'} = $req->{'params'};
    Event->timer(
        'after' => 0,
        'cb'    => sub {
            $code{ $req->{'on_done'} }->($result);
            Event::unloop();
        },
    );
    run_loop(5);
    return;
}

## jws signing stub : records the args, returns a fixed jws ##
my @jws_calls;
$code{'letsencr.child.create_jws'} = sub {
    push @jws_calls, [@ARG];
    return { 'protected' => 'p', 'payload' => 'y', 'signature' => 's' };
};

## on_done collectors ##
my @acme_done;
$code{'test.acme_done'} = sub { push @acme_done, $_[0]; return 1 };
my @txt_done;
$code{'test.txt_done'} = sub { push @txt_done, $_[0]; Event::unloop(); };
my @poll_fires;
$code{'test.poll'} = sub { push @poll_fires, $_[0]->w->data; return 1 };

## https io-handler stubs [ eof path runs the real parse_response ] ##
$code{'base.s_read'}               = sub { return 0 };
$code{'clients.https.cleanup'}     = sub { return 1 };
$code{'clients.https.decode_body'} = sub { return $_[0] };

## --- shared acme state -------------------------------------------------- ##

sub reset_acme_state {
    @https_requests = ();
    @jws_calls      = ();
    @acme_done      = ();
    $data{'letsencr'}{'child'}{'orders'}{'ord-1'}
        = { 'nonce' => qw| order-nonce | };
    $data{'letsencr'}{'child'}{'acme_client'} = {
        'nonce'       => qw| acct-nonce |,
        'account_url' => qw| https://acme.test/acct/1 |,
        'directory'   => { 'newNonce' => qw| https://acme.test/new-nonce | },
    };
    return;
}

######################################################################
say ': parse_response [ repeated headers kept, single unchanged ]';
{
    my $raw
        = "HTTP/1.1 200 OK\r\n"
        . "Server: stub\r\n"
        . "Link: <https://acme.test/up>;rel=\"up\"\r\n"
        . "Link: <https://acme.test/alt>;rel=\"alternate\"\r\n"
        . "Replay-Nonce: n-1\r\n" . "\r\n"
        . '{"status":"ok"}';
    my $r = $code{'clients.http.parse_response'}->($raw);

    ok( $r->{'status'} == 200 && $r->{'body'} eq '{"status":"ok"}',
        'status + body as before' );
    ok( $r->{'headers'}->{'link'} eq '<https://acme.test/alt>;'
            . 'rel="alternate"',
        'headers->{link} : last value wins [ unchanged behaviour ]'
    );
    ok( ref $r->{'headers_multi'}->{'link'} eq qw| ARRAY |
            && @{ $r->{'headers_multi'}->{'link'} } == 2
            && $r->{'headers_multi'}->{'link'}[0] eq
            '<https://acme.test/up>;rel="up"',
        'headers_multi->{link} : both values, in order'
    );
    ok( $r->{'headers'}->{'server'} eq qw| stub |
            && $r->{'headers'}->{'replay-nonce'} eq qw| n-1 |,
        'single-valued headers unchanged'
    );
    ok( join( ' ', @{ $r->{'headers_multi'}->{'server'} } ) eq qw| stub |,
        'headers_multi of a single header : one element' );

    my $empty = $code{'clients.http.parse_response'}->(qw| not-a-response |);
    ok( $empty->{'status'} == 0
            && ref $empty->{'headers_multi'} eq qw| HASH |,
        'unparseable input : status 0, empty headers_multi'
    );
}

######################################################################
say ': clients.https.handler.io [ on_done receives headers_multi ]';
{
    my $raw
        = "HTTP/1.1 200 OK\r\n"
        . "Link: <one>;rel=\"up\"\r\n"
        . "Link: <two>;rel=\"alternate\"\r\n" . "\r\n" . 'body';
    my $state = {
        'sock'    => undef,
        'buffer'  => $raw,
        'on_done' => qw| test.https_done |,
        'params'  => { 't' => 1 },
    };
    my @done;
    $code{'test.https_done'}    = sub { push @done, $_[0]; return 1 };
    $IO::Socket::SSL::SSL_ERROR = 0;    ## no pending ssl error state ##
    my $fake_event = bless( { 'data' => $state }, qw| Test::FakeIoEvent | );
    $code{'clients.https.handler.io'}->($fake_event);
    ok( @done == 1 && $done[0]->{'ok'} == TRUE,
        'eof : on_done fired with ok'
    );
    ok( ref $done[0]->{'headers_multi'}->{'link'} eq qw| ARRAY |
            && @{ $done[0]->{'headers_multi'}->{'link'} } == 2,
        '  :.. headers_multi carries both Link values'
    );
    ok( $done[0]->{'headers'}->{'link'} eq '<two>;rel="alternate"',
        '  :.. headers->{link} still the last value' );
}

######################################################################
say ': acme.request [ jws post, nonce from order record ]';
{
    reset_acme_state();
    $code{'letsencr.child.acme.request'}->(
        {   'method'   => qw| POST |,
            'url'      => qw| https://acme.test/new-order |,
            'payload'  => { 'identifiers' => [] },
            'order_id' => qw| ord-1 |,
            'on_done'  => qw| test.acme_done |,
            'params'   => { 'step' => qw| new | },
        }
    );
    ok( @https_requests == 1, 'one https request issued' );
    my $req = $https_requests[0];
    ok( $req->{'method'} eq qw| POST |
            && $req->{'headers'}->{'Content-Type'} eq
            qw| application/jose+json |,
        '  :.. POST with application/jose+json'
    );
    ok( @jws_calls == 1
            && $jws_calls[0][1] eq qw| order-nonce |
            && $jws_calls[0][2] eq qw| https://acme.test/acct/1 |
            && $jws_calls[0][3] eq qw| https://acme.test/new-order |,
        '  :.. jws signed with order nonce, account-url kid, url'
    );
    ok( !@acme_done, '  :.. on_done not fired before the reply' );

    deliver_response(
        $req,
        {   'ok'      => TRUE,
            'status'  => 201,
            'body'    => '{"status":"pending"}',
            'headers' => {
                'replay-nonce' => qw| n-2 |,
                'content-type' => qw| application/json |,
                'location'     => qw| https://acme.test/order/1 |,
            },
            'headers_multi' => { 'link' => [qw| one two |] },
        }
    );
    ok( @acme_done == 1
            && $acme_done[0]->{'ok'} == TRUE
            && $acme_done[0]->{'status'} == 201,
        'reply : on_done fired once, ok'
    );
    ok( ref $acme_done[0]->{'body'} eq qw| HASH |
            && $acme_done[0]->{'body'}->{'status'} eq qw| pending |,
        '  :.. json body decoded'
    );
    ok( $acme_done[0]->{'location'} eq qw| https://acme.test/order/1 |
            && @{ $acme_done[0]->{'headers_multi'}->{'link'} } == 2
            && $acme_done[0]->{'params'}->{'step'} eq qw| new |,
        '  :.. location, headers_multi and caller params passed on'
    );
    ok( $data{'letsencr'}{'child'}{'orders'}{'ord-1'}{'nonce'} eq qw| n-2 |
            && $data{'letsencr'}{'child'}{'acme_client'}{'nonce'} eq
            qw| n-2 |,
        '  :.. replay-nonce stored to order record + account cache'
    );
}

######################################################################
say ': acme.request [ GET + POST-as-GET ]';
{
    reset_acme_state();
    $code{'letsencr.child.acme.request'}->(
        {   'method'   => qw| GET |,
            'url'      => qw| https://acme.test/directory |,
            'order_id' => qw| ord-1 |,
            'on_done'  => qw| test.acme_done |,
        }
    );
    ok( @https_requests == 1
            && $https_requests[0]->{'method'} eq qw| GET |
            && $https_requests[0]->{'headers'}->{'Accept'} eq
            qw| application/json |
            && !@jws_calls,
        'GET : no jws, accept json'
    );

    reset_acme_state();
    $code{'letsencr.child.acme.request'}->(
        {   'method'   => qw| POST-as-GET |,
            'url'      => qw| https://acme.test/authz/1 |,
            'order_id' => qw| ord-1 |,
            'on_done'  => qw| test.acme_done |,
        }
    );
    ok( @https_requests == 1
            && $https_requests[0]->{'method'} eq qw| POST |
            && @jws_calls == 1
            && defined $jws_calls[0][0]
            && $jws_calls[0][0] eq '',
        'POST-as-GET : wire POST, empty jws payload [ rfc 8555 6.3 ]'
    );
}

######################################################################
say ': acme.request [ nonce prefetch when none cached ]';
{
    reset_acme_state();
    delete $data{'letsencr'}{'child'}{'orders'}{'ord-1'}{'nonce'};
    delete $data{'letsencr'}{'child'}{'acme_client'}{'nonce'};

    $code{'letsencr.child.acme.request'}->(
        {   'method'   => qw| POST |,
            'url'      => qw| https://acme.test/new-order |,
            'payload'  => {},
            'order_id' => qw| ord-1 |,
            'on_done'  => qw| test.acme_done |,
        }
    );
    ok( @https_requests == 1
            && $https_requests[0]->{'url'} eq
            qw| https://acme.test/new-nonce |
            && !@jws_calls,
        'no nonce anywhere : newNonce fetched first, nothing signed yet'
    );

    deliver_response(
        $https_requests[0],
        {   'ok'      => TRUE,
            'status'  => 200,
            'body'    => '',
            'headers' => { 'replay-nonce' => qw| fresh-9 | },
        }
    );
    ok( @https_requests == 2
            && $https_requests[1]->{'url'} eq
            qw| https://acme.test/new-order |
            && @jws_calls == 1
            && $jws_calls[0][1] eq qw| fresh-9 |,
        '  :.. original request continues with the fresh nonce'
    );
    ## single use : the nonce went into the jws above and is gone now -- the
    ## next request takes the replay-nonce of this one's reply
    ok( !defined $data{'letsencr'}{'child'}{'orders'}{'ord-1'}{'nonce'}
            && !defined $data{'letsencr'}{'child'}{'acme_client'}{'nonce'},
        '  :.. fresh nonce consumed once signed [ single use ]'
    );
}

######################################################################
say ': acme.request [ badNonce retried exactly once ]';
{
    reset_acme_state();
    $code{'letsencr.child.acme.request'}->(
        {   'method'   => qw| POST |,
            'url'      => qw| https://acme.test/new-order |,
            'payload'  => {},
            'order_id' => qw| ord-1 |,
            'on_done'  => qw| test.acme_done |,
        }
    );
    my $bad = {
        'ok'     => FALSE,
        'status' => 400,
        'body'   =>
            '{"type":"urn:ietf:params:acme:error:badNonce","detail":"x"}',
        'headers' => {
            'replay-nonce' => qw| n-3 |,
            'content-type' => qw| application/problem+json |,
        },
    };
    deliver_response( $https_requests[0], $bad );
    ok( @https_requests == 2 && @jws_calls == 2 && !@acme_done,
        'badNonce : one retry issued, on_done not fired yet'
    );
    ok( $jws_calls[1][1] eq qw| n-3 |,
        '  :.. retry signed with the fresh nonce from the error reply' );

    deliver_response(
        $https_requests[1],
        {   'ok'      => TRUE,
            'status'  => 201,
            'body'    => '{"status":"pending"}',
            'headers' => {
                'replay-nonce' => qw| n-4 |,
                'content-type' => qw| application/json |,
            },
        }
    );
    ok( @acme_done == 1 && $acme_done[0]->{'status'} == 201,
        '  :.. retry succeeds : on_done fired once'
    );

    ## a second badNonce must not retry again ##
    reset_acme_state();
    $code{'letsencr.child.acme.request'}->(
        {   'method'   => qw| POST |,
            'url'      => qw| https://acme.test/new-order |,
            'payload'  => {},
            'order_id' => qw| ord-1 |,
            'on_done'  => qw| test.acme_done |,
        }
    );
    deliver_response( $https_requests[0], $bad );
    deliver_response( $https_requests[1], $bad );
    ok( @https_requests == 2 && @acme_done == 1,
        'badNonce twice : no second retry, error handed to on_done' );
    ok( ref $acme_done[0]->{'body'} eq qw| HASH |
            && $acme_done[0]->{'body'}->{'type'} =~ m{badNonce$},
        '  :.. caller sees the decoded badNonce problem document'
    );
}

######################################################################
say ': schedule_poll [ fires once, event-shaped arg, replace + cancel ]';
{
    @poll_fires = ();
    $data{'letsencr'}{'child'}{'orders'}{'ord-p'}
        = { 'step' => qw| poll_authz | };

    my $timer = $code{'letsencr.child.acme.schedule_poll'}->(
        {   'order_id' => qw| ord-p |,
            'delay'    => 0.05,
            'handler'  => qw| test.poll |,
            'data'     => { 'poll' => 1 },
        }
    );
    ok( defined $timer, 'timer armed' );
    ok( defined $data{'letsencr'}{'child'}{'orders'}{'ord-p'}{'timer'},
        '  :.. stored in the order record' );
    Event->timer( 'after' => 0.3, 'cb' => sub { Event::unloop() } );
    Event::loop();
    ok( @poll_fires == 1 && $poll_fires[0]->{'poll'} == 1,
        'fired once with the data hash [ handler got the event ]'
    );

    ## replace : the previous timer is canceled, only the new one fires ##
    @poll_fires = ();
    $code{'letsencr.child.acme.schedule_poll'}->(
        {   'order_id' => qw| ord-p |,
            'delay'    => 0.05,
            'handler'  => qw| test.poll |,
            'data'     => { 'poll' => qw| first | },
        }
    );
    $code{'letsencr.child.acme.schedule_poll'}->(
        {   'order_id' => qw| ord-p |,
            'delay'    => 0.1,
            'handler'  => qw| test.poll |,
            'data'     => { 'poll' => qw| second | },
        }
    );
    Event->timer( 'after' => 0.4, 'cb' => sub { Event::unloop() } );
    Event::loop();
    ok( @poll_fires == 1 && $poll_fires[0]->{'poll'} eq qw| second |,
        're-schedule : the previous timer canceled, new one fires'
    );

    ## cancel ##
    @poll_fires = ();
    $code{'letsencr.child.acme.schedule_poll'}->(
        {   'order_id' => qw| ord-p |,
            'delay'    => 0.05,
            'handler'  => qw| test.poll |,
            'data'     => { 'poll' => qw| never | },
        }
    );
    ok( $code{'letsencr.child.acme.cancel_poll'}
            ->( { 'order_id' => qw| ord-p | } ) == TRUE,
        'cancel_poll : true with a pending timer'
    );
    ok( !defined $data{'letsencr'}{'child'}{'orders'}{'ord-p'}{'timer'},
        '  :.. record cleared' );
    Event->timer( 'after' => 0.2, 'cb' => sub { Event::unloop() } );
    Event::loop();
    ok( !@poll_fires, '  :.. canceled timer never fires' );
    ok( $code{'letsencr.child.acme.cancel_poll'}
            ->( { 'order_id' => qw| ord-p | } ) == FALSE,
        'cancel_poll without a pending timer : false'
    );

    ## missing order record : dropped, not fatal ##
    @logs = ();
    my $r = $code{'letsencr.child.acme.schedule_poll'}->(
        {   'order_id' => qw| nope |,
            'delay'    => 0.01,
            'handler'  => qw| test.poll |,
        }
    );
    ok( !defined $r && grep( {m|no order record|} @logs ),
        'unknown order : dropped with a level-2 log'
    );
}

######################################################################
say ': query_txt_async [ real udp : answer, nodata, dead port ]';
{
    ## stub authoritative servers on 127.0.0.1 high ports ##
    my $mk_server = sub {
        my ($value) = @ARG;                    ## undef : nodata answer ##
        my $sock = IO::Socket::INET->new(
            'LocalAddr' => qw| 127.0.0.1 |,
            'LocalPort' => 0,
            'Proto'     => qw| udp |,
        ) or die "cannot bind udp stub : $OS_ERROR";
        Event->io(
            'fd'   => $sock,
            'poll' => 'r',
            'cb'   => sub {
                my $buf  = '';
                my $from = $sock->recv( $buf, 4096 );
                return if not length $buf;
                my $query = eval { Net::DNS::Packet->new( \$buf ) };
                return if not $query;
                my ($q) = $query->question;
                my $reply = Net::DNS::Packet->new( $q->qname, 'TXT' );
                $reply->header->id( $query->header->id );
                $reply->header->qr(1);
                $reply->header->aa(1);
                $reply->header->rcode('NOERROR');

                if ( defined $value ) {
                    $reply->push(
                        'answer',
                        Net::DNS::RR->new(
                            sprintf '%s 60 IN TXT "%s"', $q->qname,
                            $value
                        )
                    );
                }
                $sock->send( $reply->data, 0, $from );
                return;
            },
        );
        return $sock;
    };

    my $s1 = $mk_server->(qw| tok-one |);    ## answers the value ##
    my $s2 = $mk_server->(undef);            ## nodata ##

    ## a dead port : bound and closed, nobody answers ##
    my $dead = IO::Socket::INET->new(
        'LocalAddr' => qw| 127.0.0.1 |,
        'LocalPort' => 0,
        'Proto'     => qw| udp |,
    ) or die "cannot bind dead-port probe : $OS_ERROR";
    my $dead_addr = sprintf '127.0.0.1:%d', $dead->sockport;
    $dead->close;

    my @servers = map { sprintf '127.0.0.1:%d', $ARG->sockport } ( $s1, $s2 );
    push @servers, $dead_addr;

    @txt_done = ();
    my $ok_start = $code{'letsencr.child.dns.query_txt_async'}->(
        {   'name'    => qw| _acme-challenge.example.com |,
            'servers' => [@servers],
            'on_done' => qw| test.txt_done |,
            'params'  => { 'order_id' => qw| ord-1 | },
            'timeout' => 1.5,
        }
    );
    ok( $ok_start,  'query_txt_async started' );
    ok( !@txt_done, '  :.. on_done not fired before all replies' );
    run_loop(8);

    ok( @txt_done == 1, 'on_done fired once' );
    my $res = @txt_done ? $txt_done[0] : {};
    ok( $res->{'name'} eq qw| _acme-challenge.example.com |
            && $res->{'params'}->{'order_id'} eq qw| ord-1 |,
        '  :.. name + caller params carried through'
    );
    my $r1 = $res->{'results'}->{ $servers[0] } // {};
    ok( $r1->{'ok'} == TRUE
            && $r1->{'rcode'} eq qw| NOERROR |
            && join( ' ', @{ $r1->{'values'} // [] } ) eq qw| tok-one |,
        '  :.. server 1 : ok, txt value present'
    );
    my $r2 = $res->{'results'}->{ $servers[1] } // {};
    ok( $r2->{'ok'} == TRUE
            && $r2->{'rcode'} eq qw| NOERROR |
            && !@{ $r2->{'values'} // [] },
        '  :.. server 2 : ok, nodata [ no values ]'
    );
    my $r3 = $res->{'results'}->{ $servers[2] } // {};
    ok( $r3->{'ok'} == FALSE && $r3->{'rcode'} eq qw| TIMEOUT |,
        '  :.. dead port : timeout result' );
}

say '';
say "passed : " . ( $test_count - $fail_count ) . "  failed : $fail_count";
exit( $fail_count ? 1 : 0 );

## stands in for an Event io watcher : the handler reads ->w->data ##
package Test::FakeIoEvent;
sub w    { return $_[0] }
sub data { return $_[0]->{'data'} }

#,,,.,,..,,,.,,,,,...,.,.,...,,.,,,..,..,,..,,..,,...,...,.,.,.,.,,.,,.,.,,,.,
#4LCL6AUJFM5DKZUKXGC3OWCNCFH6ANHHYXX47JAD3ODL4SY6JTJOQNOA7IBW6LENUZIPSDDHGVJSW
#\\\|TWDISEGSPYGDKS2HHUW4QWG7RXDAFD4KCF3YJJOFVTUR24RQEPX \ / AMOS7 \ YOURUM ::
#\[7]AC4KY5JW5AJHQHJB7FJYUKTUA6JVDYQ2QCQ7H4LKYVQY22PYAYCQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
