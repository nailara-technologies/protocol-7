#!/usr/bin/env perl
use v5.24;
use strict;
use English;
use warnings;

## the production runtime loads the bytes pragma transitively ##
use bytes;

## letsencr acme flow on the event loop [ letsencr.child.acme.* ] : order
## record, phase barriers, set-up confirmed BEFORE the challenge response,
## reused authorizations, one order at a time [ queue ], fail called twice,
## late replies dropped, timer handlers given event-shaped objects. the
## transport [ acme.request ], timers, dns and route-send are stubbed : every
## reply is delivered explicitly by the test, nothing leaves the process.

use File::Spec;
use Cwd     qw| abs_path |;
use FindBin qw| $RealBin |;
use JSON::XS;
use Crypt::Misc  qw| encode_b32r decode_b32r |;
use MIME::Base64 qw| encode_base64url |;
use Digest::SHA  qw| sha256 |;

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

## an Event timer watcher stand-in : handlers read $event->w->data ##
{

    package Test::FakeTimerEvent;
    sub w         { return $_[0] }
    sub data      { return $_[0]->{'data'} }
    sub cancel    { return 1 }
    sub is_active { return 0 }
}

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

compile_module("letsencr.child.acme.$ARG")
    for
    qw| begin start order_of on_deadline step_authz on_authz key_authorization
    step_setup on_setup step_propagate on_propagate step_respond on_respond
    step_poll_authz on_poll_authz step_finalize on_order step_poll_order
    on_download cleanup finish fail next_queued |;
compile_module($ARG) for qw| letsencr.child.cmd.request-certificate
    letsencr.child.cmd.renew-certificate |;

## --- stubs : every outside effect is recorded, nothing is delivered ---- ##

my ( @logs, @acme, @routes, @replies, @timers, @dns, @acme_new );

$code{'base.log'}
    = sub { push @logs, sprintf( $_[1] // '', @_[ 2 .. $#ARG ] ); return 1 };
$code{'base.logs'}            = $code{'base.log'};
$code{'base.cnt_s'}           = sub { return $_[0] == 1 ? '' : 's' };
$code{'base.cfg_bool'}        = sub { return $_[0] && $_[0] ne 'no' };
$code{'base.anum_log_time'}   = sub { return 'T' };
$code{'base.buffer.add_line'} = sub { return 1 };
my $id_seq = 100;
$code{'base.gen_id'} = sub { return ++$id_seq };

$code{'letsencr.child.substitute_admin_email'} = sub { return $_[0] };
$code{'letsencr.child.get_jwk'}
    = sub { return { 'e' => 'AQAB', 'kty' => 'RSA', 'n' => 'xyz' } };
$code{'letsencr.child.generate_csr'} = sub {
    return { 'csr_b64url' => 'CSR', 'key_pem' => 'KEYPEM', 'csr_pem' => 'C' };
};
$code{'letsencr.child.validate_chain'} = sub {
    return { 'valid' => 1, 'chain_pem' => $_[1] };
};

## acme_new : what the blocking part leaves behind [ acme_state ] ##
my %orders_by_domain;
$code{'letsencr.child.acme_new'} = sub {
    my ( $msg, $reply_id ) = @ARG;
    push @acme_new, $msg->{'domains'}->[0];
    my $o = $orders_by_domain{ $msg->{'domains'}->[0] };
    return { 'status' => 'error', 'error' => 'no stub order' } if not $o;
    $data{'letsencr'}{'child'}{'acme_state'} = {
        'domains'        => $msg->{'domains'},
        'primary_domain' => $msg->{'domains'}->[0],
        'order'          => $o,
        'reply_id'       => $reply_id,
    };
    return { 'status' => 'deferred' };
};

$code{'letsencr.child.acme.request'}
    = sub { push @acme, $_[0]; return TRUE };
$code{'letsencr.child.acme.schedule_poll'}
    = sub { push @timers, $_[0]; return TRUE };
$code{'letsencr.child.acme.cancel_poll'} = sub { return TRUE };
my @deadlines;
{

    package Test::FakeWatcher;
    sub cancel { $_[0]->{'cancelled'} = 1 }
}
$code{'event.add_timer'} = sub {
    my $w = bless { 'p' => $_[0] }, 'Test::FakeWatcher';
    push @deadlines, $w;
    return $w;
};
$code{'letsencr.child.dns.query_txt_async'}
    = sub { push @dns, $_[0]; return TRUE };
$code{'protocol-7.route-send'} = sub { push @routes, $_[0]; return TRUE };
$code{'base.callback.cmd_reply'}
    = sub { push @replies, [@ARG]; return TRUE };

sub reset_all {
    @logs = @acme = @routes = @replies = @timers = @dns = @acme_new = ();
    %orders_by_domain = ();
    delete $data{'letsencr'}{'child'}{$ARG} for qw| orders acme acme_state |;
    delete $data{'letsencr'}{'dns'};
    delete $data{'letsencr'}{'cfg'};
    $data{'letsencr'}{'admin'}{'email'} = 'admin@example.test';
}

## deliver the oldest acme request's reply ##
sub acme_reply {
    my ( $body, %o ) = @ARG;
    my $req = shift @acme or die 'no acme request pending';
    $code{ $req->{'on_done'} }->(
        {   'ok'     => $o{'ok'}     // 1,
            'status' => $o{'status'} // 200,
            'body'   => $body,
            'params' => $req->{'params'},
        }
    );
    return $req;
}

sub route_reply {
    my ( $mode, $data ) = @ARG;
    my $r = shift @routes or die 'no route-send pending';
    ## the real shape [ base.handler.command.process_reply ] : ONE hash ##
    $code{ $r->{'reply'}->{'handler'} }->(
        {   'sid'       => 1,
            'cmd'       => $mode,
            'call_args' => $data // '',
            'params'    => $r->{'reply'}->{'params'},
        }
    );
    return $r;
}

sub fire_timer {
    my $t = shift @timers or die 'no timer pending';
    $code{ $t->{'handler'} }
        ->( bless( { 'data' => $t->{'data'} }, 'Test::FakeTimerEvent' ) );
    return $t;
}

sub request_cert {
    my ( $domain, $reply_id ) = @ARG;
    local $call
        = { 'args' => $domain, 'reply_id' => $reply_id, 'param' => {} };
    return $code{'letsencr.child.cmd.request-certificate'}->();
}

sub authz_body {
    my ( $domain, %o ) = @ARG;
    return {
        'identifier' => { 'type' => 'dns', 'value' => $domain },
        'status'     => $o{'status'} // 'pending',
        ( $o{'wildcard'} ? ( 'wildcard' => JSON::XS::true ) : () ),
        'challenges' => [
            {   'type'  => 'http-01',
                'token' => "H-$domain",
                'url'   => "C-H-$domain"
            },
            {   'type'  => 'dns-01',
                'token' => "D-$domain",
                'url'   => "C-D-$domain"
            },
        ],
    };
}

my $pem
    = "-----BEGIN CERTIFICATE-----\nLEAF\n-----END "
    . "CERTIFICATE-----\n-----BEGIN CERTIFICATE-----\nINTER\n-----END "
    . "CERTIFICATE-----\n";

## --- 1 : http-01 success path, set-up before respond ------------------- ##
say ':: http-01 order';
reset_all();
$orders_by_domain{'a.test'} = {
    'order_url'      => 'O-a',
    'finalize_url'   => 'F-a',
    'authorizations' => ['Z-a'],
};

my $r = request_cert( 'a.test', 'R1' );
ok( $r->{'mode'} eq 'deferred',             'request answered deferred' );
ok( @acme == 1 && $acme[0]{'url'} eq 'Z-a', 'authorization fetched first' );

acme_reply( authz_body('a.test') );
ok( @routes == 1 && $routes[0]{'command'} eq 'httpd.setup-acme-challenge',
    'httpd set-up sent' );
ok( $routes[0]{'reply'}{'handler'} eq 'letsencr.child.acme.on_setup',
    'set-up carries a reply handler' );
ok( !@acme, 'NO acme request before the set-up reply' );
like_args(
    $routes[0]{'call_args'}{'args'},
    qr/^a\.test H-a\.test H-a\.test\.\S+$/,
    'set-up args : domain token key_auth'
);

route_reply('TRUE');
ok( @acme == 1
        && $acme[0]{'url'} eq 'C-H-a.test'
        && $acme[0]{'method'} eq 'POST',
    'challenge answered only after the set-up reply'
);

acme_reply( {} );
ok( @timers == 1
        && $timers[0]{'handler'} eq 'letsencr.child.acme.step_poll_authz',
    'authorization poll scheduled'
);

fire_timer();
ok( @acme == 1 && $acme[0]{'method'} eq 'POST-as-GET',
    'timer polls ' . 'the authz' );
acme_reply( { 'status' => 'pending' } );
ok( @timers == 1, 'still pending : next poll scheduled' );
fire_timer();
acme_reply( { 'status' => 'valid' } );
ok( @acme == 1
        && $acme[0]{'url'} eq 'F-a'
        && $acme[0]{'payload'}{'csr'} eq 'CSR',
    'finalize sent with the csr'
);

acme_reply( { 'status' => 'processing' } );
ok( @timers == 1
        && $timers[0]{'handler'} eq 'letsencr.child.acme.step_poll_order',
    'order poll scheduled while processing'
);
fire_timer();
ok( $acme[0]{'url'} eq 'O-a', 'order polled' );
acme_reply( { 'status' => 'valid', 'certificate' => 'CERT-a' } );
ok( $acme[0]{'url'} eq 'CERT-a', 'certificate download requested' );
acme_reply($pem);

ok( @replies == 1
        && $replies[0][0] eq 'R1'
        && $replies[0][1]{'mode'} eq 'size',
    'one reply : the bundle [ mode size ]'
);
my $bundle = decode_json( decode_b32r( $replies[0][1]{'data'} ) );
ok( $bundle->{'certificate'}  =~ m|LEAF|
        && $bundle->{'chain'} =~ m|INTER|
        && $bundle->{'key'} eq 'KEYPEM',
    'bundle : leaf, chain, key from the order record'
);
ok( ( grep { $_->{'command'} eq 'httpd.cleanup-acme-challenge' } @routes ),
    'httpd challenge cleaned up' );
ok( !%{ $data{'letsencr'}{'child'}{'orders'} // {} },
    'order record ' . 'removed' );

## --- 2 : domain from the response, reused authz ------------------------ ##
say ':: two authorizations, reversed + one reused';
reset_all();
$orders_by_domain{'b.test'} = {
    'order_url'      => 'O-b',
    'finalize_url'   => 'F-b',
    'authorizations' => [ 'Z-1', 'Z-2' ],
};
request_cert( 'b.test', 'R2' );
acme_reply( authz_body('www.b.test') );                       ## Z-1 ##
acme_reply( authz_body( 'b.test', 'status' => 'valid' ) );    ## Z-2 ##
my $order = ( values %{ $data{'letsencr'}{'child'}{'orders'} } )[0];
ok( $order->{'authz'}{'Z-1'}{'domain'} eq 'www.b.test',
    'Z-1 domain taken from its identifier' );
ok( $order->{'authz'}{'Z-2'}{'status'} eq 'reused',
    'valid authz ' . 'marked reused' );
ok( ( grep {m|reused|} @logs ), 'reuse logged' );
ok( @routes == 1 && $routes[0]{'call_args'}{'args'} =~ m|^www\.b\.test |,
    'set-up only for the non-reused authz' );

## --- 3 : one order at a time, fail twice, late reply dropped ----------- ##
say ':: queue + failure';
reset_all();
$orders_by_domain{$ARG} = {
    'order_url'      => "O-$ARG",
    'finalize_url'   => "F-$ARG",
    'authorizations' => [ "Z1-$ARG", "Z2-$ARG" ],
    }
    for qw| c.test d.test |;

request_cert( 'c.test', 'R3' );
my ($cid) = keys %{ $data{'letsencr'}{'child'}{'orders'} };
my $r4 = request_cert( 'd.test', 'R4' );
ok( $r4->{'mode'} eq 'deferred', 'second request deferred' );
ok( @acme_new == 1,              'acme_new NOT run for the queued request' );

acme_reply( authz_body('c.test') );
acme_reply( authz_body('www.c.test') );
route_reply('TRUE');
route_reply('TRUE');
ok( @acme == 1, 'first challenge response in flight' );
acme_reply( { 'detail' => 'nope' }, 'ok' => 0, 'status' => 403 );

ok( ( grep { $_->[0] eq 'R3' && $_->[1]{'mode'} eq 'false' } @replies ) == 1,
    'failed order answered false once'
);
ok( ( grep { $_->{'command'} eq 'httpd.cleanup-acme-challenge' } @routes )
        == 2,
    'both challenges cleaned up on failure'
);
ok( @acme_new == 2 && $acme_new[1] eq 'd.test',
    'queued request started after the failure'
);

my $before = scalar @replies;
$code{'letsencr.child.acme.fail'}->( $cid, 'again' );
$code{'letsencr.child.acme.on_respond'}->(
    { 'ok' => 1, 'params' => { 'order_id' => $cid, 'authz' => 'Z2-c.test' } }
);
ok( @replies == $before, 'second fail + late reply : no further reply' );
ok( ( grep {m|finished order $cid dropped|} @logs ),
    'late reply logged ' . 'and dropped' );

## --- 5 : dns-01 through nameserv, propagation polled ------------------- ##
say ':: dns-01 wildcard via nameserv';
reset_all();
$data{'letsencr'}{'dns'}{'provider'}              = 'nameserv';
$data{'letsencr'}{'dns'}{'nameserv'}{'targets'}   = 'nameserv';
$data{'letsencr'}{'dns'}{'nameserv'}{'addresses'} = '192.0.2.1 192.0.2.2';
$orders_by_domain{'*.e.test'}                     = {
    'order_url'      => 'O-e',
    'finalize_url'   => 'F-e',
    'authorizations' => ['Z-e'],
};
request_cert( '*.e.test', 'R5' );
acme_reply( authz_body( 'e.test', 'wildcard' => 1 ) );
ok( @routes == 1
        && $routes[0]{'command'} eq 'nameserv.add-txt'
        && $routes[0]{'call_args'}{'args'}
        =~ m|^_acme-challenge\.e\.test \S+$|,
    'wildcard : nameserv.add-txt on the base name'
);
route_reply('TRUE');
ok( @dns == 1 && "@{ $dns[0]{'servers'} }" eq '192.0.2.1 192.0.2.2' && !@acme,
    'propagation asked on both servers, no respond yet'
);

my $value = ( values %{ $data{'letsencr'}{'child'}{'orders'} } )[0]
    ->{'authz'}{'Z-e'}{'dns_value'};
my $q = shift @dns;
$code{ $q->{'on_done'} }->(
    {   'params'  => $q->{'params'},
        'results' => {
            '192.0.2.1' => { 'ok' => 1, 'values' => [$value] },
            '192.0.2.2' => { 'ok' => 1, 'values' => [] },
        }
    }
);
ok( @timers == 1 && !@acme, 'one server without the value : poll again' );
fire_timer();
$q = shift @dns;
$code{ $q->{'on_done'} }->(
    {   'params'  => $q->{'params'},
        'results' => {
            '192.0.2.1' => { 'ok' => 1, 'values' => [$value] },
            '192.0.2.2' => { 'ok' => 1, 'values' => [ 'other', $value ] },
        }
    }
);
ok( @acme == 1 && $acme[0]{'url'} eq 'C-D-e.test',
    'value on both servers : dns-01 challenge answered'
);

## a failure now removes the txt value again ##
acme_reply( { 'detail' => 'x' }, 'ok' => 0, 'status' => 400 );
ok(
    (   grep {
                   $_->{'command'} eq 'nameserv.remove-txt'
                && $_->{'call_args'}{'args'} eq "_acme-challenge.e.test "
                . "$value"
        } @routes
    ),
    'txt value removed on failure'
);

## --- 6 : a lost reply : the deadline fails the order, the queue moves -- ##
say ':: lost set-up reply';
reset_all();
@deadlines = ();
$orders_by_domain{$ARG} = {
    'order_url'      => "O-$ARG",
    'finalize_url'   => "F-$ARG",
    'authorizations' => ["Z-$ARG"],
    }
    for qw| f.test g.test |;
request_cert( 'f.test', 'R6' );
request_cert( 'g.test', 'R7' );
acme_reply( authz_body('f.test') );
shift @routes;    ## the set-up reply never comes ##
ok( @deadlines == 1, 'one deadline timer armed for the active order' );
my $dl = $deadlines[0];
$code{ $dl->{'p'}{'handler'} }
    ->( bless( { 'data' => $dl->{'p'}{'data'} }, 'Test::FakeTimerEvent' ) );
ok( ( grep { $_->[0] eq 'R6' && $_->[1]{'mode'} eq 'false' } @replies ) == 1,
    'deadline : hung order answered false'
);
ok( @acme_new == 2 && $acme_new[1] eq 'g.test',
    'deadline : queued ' . 'order started'
);
ok( @deadlines == 2, 'the next order got its own deadline' );

sub like_args { ok( defined $_[0] && $_[0] =~ $_[1], $_[2] ) }

say '';
say sprintf 'passed : %d ' . ' failed : %d', $test_count - $fail_count,
    $fail_count;
exit( $fail_count ? 1 : 0 );

#,,..,,,.,,.,,.,,,,.,,.,.,..,,,,,,,..,,,.,,.,,..,,...,..,,.,.,...,,..,.,,,...,
#YEMGRFTNJGI5B37SU6IWDCVLXNREXJ7ZHOFSXIOBHK33BI364MGHVRTXBVL3KASYHL3RPJDFCNS5I
#\\\|O5TK46NEM7XV4Y2NZSGU5KBRAOSTES64VKMTHJHB3U54S72FTRI \ / AMOS7 \ YOURUM ::
#\[7]4HXCATPFHFMQ7ITXD4TYQ35U6AT7XA6LZCA5NNO6GUFV3NIW5EBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
