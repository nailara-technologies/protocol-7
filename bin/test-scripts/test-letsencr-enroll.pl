#!/usr/bin/env perl
use v5.24;
use strict;
use English;
use warnings;

## the production runtime loads the bytes pragma transitively ##
use bytes;

## letsencr automatic enrollment : allowlist, dns sanity check, http-01    ##
## self-test, max-per-check, persistent backoff, per-request acme server [ ##
## staging vs production ] and the staging no-install rule. everything is  ##
## stubbed : no dns, no http, no acme server is ever contacted.            ##

use File::Spec;
use Cwd        qw| abs_path |;
use FindBin    qw| $RealBin |;
use File::Temp qw| tempdir |;
use JSON::XS;
use Crypt::Misc qw| encode_b32r |;

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

## stands in for an Event timer watcher : a handler gets the event and reads
## event.add_timer's 'data' as $event->w->data
{

    package Test::FakeTimerEvent;
    sub w    { return $_[0] }
    sub data { return $_[0]->{'data'} }
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

compile_module($ARG)
    for
    qw| letsencr.parent.enroll_backoff_delay letsencr.parent.enroll_state_path
    letsencr.parent.enroll_state_load letsencr.parent.enroll_state_save
    letsencr.parent.enroll_record_failure
    letsencr.parent.process_new_domains
    letsencr.parent.cmd.request-certificate
    letsencr.parent.handler_enroll_verify_reply
    letsencr.parent.handler_enrollment_reply
    letsencr.child.check_domain_dns letsencr.child.verify_http_selftest
    letsencr.child.handler.selftest_setup_reply
    letsencr.child.handler.selftest_timeout
    letsencr.child.selftest_finish
    letsencr.child.cmd.verify-domain letsencr.child.acme_use_server
    letsencr.child.account_file_paths letsencr.child.acme_new |;

my $tmp = tempdir( CLEANUP => 1 );

## --- shared stubs ------------------------------------------------------ ##

my @logs;
$code{'base.log'}
    = sub { push @logs, sprintf( $_[1] // '', @_[ 2 .. $#ARG ] ); return 1 };
$code{'base.logs'}     = $code{'base.log'};
$code{'base.sort'}     = sub { return sort @ARG };
$code{'base.cnt_s'}    = sub { return '' };
$code{'base.cfg_bool'} = sub {
    my $v = shift;
    return ( $v && $v ne qw| no | && $v ne qw| 0 | ) ? TRUE : FALSE;
};
$code{'base.prng.chars-anum'} = sub { return 'T' x ( $_[0] // 8 ) };
$code{'base.time'}            = sub { return time() };
$code{'base.ntime'}           = sub { return time() };
$code{'base.str.eval_error'}  = sub { return $EVAL_ERROR // '' };

my @sent;
$code{'protocol-7.command.send.local'} = sub {
    push @sent, $_[0];
    return TRUE;
};

my $route_send_result = TRUE;
my @routed;
$code{'protocol-7.route-send'} = sub {
    push @routed, $_[0];
    return $route_send_result;
};

my @activity;
$code{'letsencr.parent.activity_logger'} = sub {
    push @activity, [@ARG];
    return TRUE;
};

my %parent_calls;
$code{'letsencr.parent.save_certificate'} = sub {
    $parent_calls{'save'}++;
    return TRUE;
};
$code{'letsencr.parent.install_certificate_to_httpsd'} = sub {
    $parent_calls{'install'}++;
    return { 'status' => qw| success | };
};
$code{'letsencr.parent.notify_httpd_certificate_update'} = sub {
    $parent_calls{'notify'}++;
    return { 'status' => qw| success | };
};

my @timers;
$code{'event.add_timer'} = sub { push @timers, $_[0]; return TRUE };

my @parent_replies;    ## deferred replies delivered to the parent ##
$code{'base.callback.cmd_reply'} = sub {
    push @parent_replies, [@ARG];
    return TRUE;
};

my @resolved;
$code{'letsencr.child.resolve_addresses'} = sub { return @resolved };

my @fetches;    ## self-test fetches [ must never precede a setup reply ] ##
my $http_get_result;
$code{'letsencr.child.http_get_url'} = sub {
    push @fetches, $_[0];
    return $http_get_result;
};

my @cleanups;
$code{'letsencr.child.util.cleanup_challenge'} = sub {
    push @cleanups, [@ARG];
    return TRUE;
};

my @fetched_dirs;
$code{'letsencr.child.fetch_acme_directory'} = sub {
    my $server = shift;
    push @fetched_dirs, $server;
    $data{'letsencr'}{'child'}{'acme_client'}{'directory'}
        = { 'newAccount' => 'na', 'newOrder' => 'no', 'newNonce' => 'nn' };
    $data{'letsencr'}{'child'}{'acme_client'}{'nonce'} = qw| test-nonce |;
    return { 'directory' => {}, 'nonce' => qw| test-nonce | };
};

my @loaded_key_servers;
$code{'letsencr.child.load_account_key'} = sub {
    push @loaded_key_servers, shift;
    $data{'letsencr'}{'child'}{'acme_client'}{'account_key_name'}
        = qw| test-key |;
    return qw| test-key |;
};

$code{'letsencr.child.acme_register_account'} = sub {
    $data{'letsencr'}{'child'}{'acme_client'}{'account_url'}
        = qw| test-account-url |;
    return { 'account_url' => qw| test-account-url | };
};

$code{'letsencr.child.acme_create_order'} = sub {
    return { 'order_url' => qw| test-order |, 'authorizations' => [] };
};

## --- shared config ------------------------------------------------------ ##

my $PROD    = qw| https://acme-v02.api.letsencrypt.org/directory |;
my $STAGING = qw| https://acme-staging-v02.api.letsencrypt.org/directory |;

$data{'letsencr'}{'cache'}{'dir'}   = $tmp;
$data{'letsencr'}{'certs'}{'dir'}   = File::Spec->catdir( $tmp, qw| certs | );
$data{'letsencr'}{'acme'}{'server'} = $PROD;
$data{'letsencr'}{'admin'}{'email'} = qw| admin@example.com |;
$data{'letsencr'}{'cfg'}{'enroll_staging_server'} = $STAGING;
$data{'letsencr'}{'cfg'}{'enroll_staging'}        = TRUE;
$data{'letsencr'}{'cfg'}{'enroll_max_per_check'}  = 10;
$data{'letsencr'}{'cfg'}{'enroll_domains'}        = '';
$data{'letsencr'}{'cfg'}{'public_addresses'}      = '';
$data{'letsencr'}{'parent'}{'certs'}              = {};
$data{'letsencr'}{'parent'}{'acme_account'} = { 'account_id' => qw| acct | };
$data{'letsencr'}{'child'}{'acme_client'}   = { 'server'     => $PROD };

sub reset_calls {
    @sent         = ();
    @routed       = ();
    @cleanups     = ();
    @timers       = ();
    %parent_calls = ();
    @activity     = ();
    return;
}

sub clear_state {    ## no leftovers from earlier sections ##
    $code{'letsencr.parent.enroll_state_save'}->( {} );
    return;
}

sub sent_commands {
    return map { $ARG->{'command'} } @sent;
}

## deliver httpd's answer to the last routed setup command explicitly -- ##
## the stub records only : in the live system the reply arrives later    ##
sub deliver_setup_reply {
    my ($mode) = @ARG;
    my $routed = $routed[-1]        or die 'no setup command routed';
    my $reply  = $routed->{'reply'} or die 'setup routed without reply';
    $code{ $reply->{'handler'} }
        ->( { 'cmd' => $mode, 'params' => $reply->{'params'} } );
    return $reply->{'params'}->{'token'};
}

######################################################################
say ': backoff [ growth + cap ]';
{
    my $f = $code{'letsencr.parent.enroll_backoff_delay'};
    ok( $f->(1) == 3600,   'attempt 1 : 1 h' );
    ok( $f->(2) == 7200,   'attempt 2 : 2 h' );
    ok( $f->(3) == 14400,  'attempt 3 : 4 h' );
    ok( $f->(5) == 57600,  'attempt 5 : 16 h' );
    ok( $f->(6) == 86400,  'attempt 6 : 24 h cap reached' );
    ok( $f->(12) == 86400, 'attempt 12 : still capped at 24 h' );
}

######################################################################
say ': state persistence [ save, reload, backoff grows ]';
{
    my $load   = $code{'letsencr.parent.enroll_state_load'};
    my $save   = $code{'letsencr.parent.enroll_state_save'};
    my $record = $code{'letsencr.parent.enroll_record_failure'};

    my $state = $load->();
    ok( ref($state) eq qw| HASH | && !keys %{$state},
        'no state file : empty hash' );

    my $e1 = $record->( $state, qw| a.example |, 'dns failed' );
    ok( $e1->{'attempts'} == 1
            && $e1->{'next_attempt_after'} - $e1->{'last_attempt'} == 3600,
        'first failure : attempt 1, backed off by 1 h'
    );

    ## reload from disk : a restart must not reset the backoff ##
    my $reloaded = $load->();
    ok( ( $reloaded->{'a.example'}->{'attempts'} // 0 ) == 1,
        'state persisted across reload' );

    my $e2 = $record->( $reloaded, qw| a.example |, 'order failed' );
    ok( $e2->{'attempts'} == 2
            && $e2->{'next_attempt_after'} - $e2->{'last_attempt'} == 7200,
        'second failure after reload : attempt 2, backed off by 2 h'
    );
    ok( ( $load->()->{'a.example'}->{'last_error'} // '' ) eq 'order failed',
        '  :.. last failure reason persisted'
    );
}

######################################################################
say ': candidate selection [ allowlist off, on ]';
{
    my $process = $code{'letsencr.parent.process_new_domains'};

    reset_calls();
    clear_state();
    $data{'letsencr'}{'cfg'}{'enroll_domains'} = '';
    $process->( [qw| b.example a.example |], {} );
    my @cmds = sent_commands();
    ok( scalar( grep { $ARG eq qw| child.verify-domain | } @cmds ) == 2,
        'allowlist unset : both candidates queued for verification'
    );
    ok( ( $sent[0]->{'call_args'}->{'args'} // '' ) eq qw| a.example |,
        '  :.. processed in sorted order' );

    reset_calls();
    clear_state();    ## the first call left its domains 'pending' ##
    $data{'letsencr'}{'cfg'}{'enroll_domains'} = 'a.example c.example';
    $process->( [qw| b.example a.example c.example |], {} );
    my @domains = map { $ARG->{'call_args'}->{'args'} } @sent;
    ok( join( ' ', @domains ) eq 'a.example c.example',
        'allowlist set : only listed domains qualify'
    );
    $data{'letsencr'}{'cfg'}{'enroll_domains'} = '';
}

######################################################################
say ': in-flight guard [ pending ]';
{
    my $process = $code{'letsencr.parent.process_new_domains'};
    my $load    = $code{'letsencr.parent.enroll_state_load'};
    my $save    = $code{'letsencr.parent.enroll_state_save'};

    reset_calls();
    clear_state();
    $process->( [qw| fly.example |], {} );
    ok( ( $load->()->{'fly.example'}{'status'} // '' ) eq qw| pending |,
        'queued domain is marked pending in the state' );

    reset_calls();
    $process->( [qw| fly.example |], {} );
    ok( !@sent && grep( {m|already in progress|} @logs ),
        'a second check while pending : skipped, not queued again'
    );

    reset_calls();
    $save->(
        {   'fly.example' => {
                'status'        => qw| pending |,
                'pending_since' => time() - 7200,
            }
        }
    );
    $process->( [qw| fly.example |], {} );
    ok( scalar(@sent) == 1,
        'a pending mark older than an hour counts as lost : queued again' );
}

######################################################################
say ': explicit request claims the domain [ no double order ]';
{
    my $process = $code{'letsencr.parent.process_new_domains'};
    my $request = $code{'letsencr.parent.cmd.request-certificate'};
    my $load    = $code{'letsencr.parent.enroll_state_load'};

    reset_calls();
    clear_state();
    local $data{'letsencr'}{'parent'}{'certs'} = {};

    ## install-vhosts 'tls: yes' -> letsencr.request-certificate ##
    local $call = { 'call_args' => { 'args' => qw| vhost.example | } };
    $request->();
    ok( ( $load->()->{'vhost.example'}{'explicit'} // 0 ) > 0,
        'request-certificate records the domain as explicitly requested'
    );
    ok( scalar(
            grep { $ARG eq qw| child.request-certificate | } sent_commands()
        ) == 1,
        '  :.. and still orders it [ production path unchanged ]'
    );

    reset_calls();
    $process->( [qw| vhost.example other.example |], {} );
    my @verified = map { $ARG->{'call_args'}->{'args'} }
        grep { $ARG->{'command'} eq qw| child.verify-domain | } @sent;
    ok( join( ' ', @verified ) eq qw| other.example |
            && grep( {m|vhost\.example : skipped \[ explicitly requested \]|}
            @logs ),
        'automatic enrollment skips the claimed domain, takes the other'
    );

    ## a domain with an active certificate is refused, claims nothing new ##
    reset_calls();
    clear_state();
    local $data{'letsencr'}{'parent'}{'certs'}
        = {
        'have.example' => { 'status' => qw| active |, 'expires_at' => 1 } };
    local $call = { 'call_args' => { 'args' => qw| have.example | } };
    my $reply = $request->();
    ok( ( $reply->{'mode'} // '' ) eq qw| true |
            && ( $reply->{'data'} // '' ) =~ m|already exists|
            && !sent_commands(),
        'existing active certificate : refused, nothing ordered'
    );
}

######################################################################
say ': max per check';
{
    my $process = $code{'letsencr.parent.process_new_domains'};
    reset_calls();
    clear_state();
    $data{'letsencr'}{'cfg'}{'enroll_max_per_check'} = 2;
    $process->( [qw| d1.example d2.example d3.example d4.example |], {} );
    ok( scalar(@sent) == 2,
        'enroll_max_per_check = 2 : 2 of 4 candidates queued' );
    ok( scalar( grep {m|enroll_max_per_check|} @logs ),
        '  :.. the rest logged as skipped [ limit reached ]'
    );
    $data{'letsencr'}{'cfg'}{'enroll_max_per_check'} = 10;
}

######################################################################
say ': backoff skip + issued-staging skip';
{
    my $process = $code{'letsencr.parent.process_new_domains'};
    my $save    = $code{'letsencr.parent.enroll_state_save'};

    reset_calls();
    $save->(
        {   'backed.example' =>
                { 'attempts' => 1, 'next_attempt_after' => time() + 3600 }
        }
    );
    $process->( [qw| backed.example |], {} );
    ok( !@sent && grep( {m|backed off until|} @logs ),
        'backed-off domain : skipped, logged, not queued'
    );

    reset_calls();
    $save->( { 'staged.example' => { 'status' => qw| issued-staging | } } );
    $process->( [qw| staged.example |], {} );
    ok( !@sent && grep( {m|issued-staging|} @logs ),
        'issued-staging domain : skipped while enroll_staging is on' );

    reset_calls();
    $data{'letsencr'}{'cfg'}{'enroll_staging'} = FALSE;
    $process->( [qw| staged.example |], {} );
    ok( scalar(@sent) == 1,
        '  :.. enroll_staging off : it is a production candidate again' );
    $data{'letsencr'}{'cfg'}{'enroll_staging'} = TRUE;
}

######################################################################
say ': dns check [ private rejected, public accepted, public_addresses ]';
{
    my $dns = $code{'letsencr.child.check_domain_dns'};

    @resolved = (qw| 10.0.0.5 |);
    ok( !$dns->( qw| x.example |, [] )->{'ok'},
        'private-only [ 10.x ] : rejected'
    );

    @resolved = (qw| 192.168.1.1 127.0.0.1 fe80::1 |);
    ok( !$dns->( qw| x.example |, [] )->{'ok'},
        'private + loopback + link-local mix : rejected'
    );

    @resolved = ();
    ok( !$dns->( qw| x.example |, [] )->{'ok'}, 'unresolvable : rejected' );

    @resolved = (qw| 93.184.216.34 |);
    ok( $dns->( qw| x.example |, [] )->{'ok'}, 'public address : accepted' );

    @resolved = (qw| 10.0.0.5 93.184.216.34 |);
    ok( $dns->( qw| x.example |, [] )->{'ok'},
        'private + public mix : accepted [ one public is enough ]' );

    @resolved = (qw| 93.184.216.34 |);
    ok( $dns->( qw| x.example |, [qw| 93.184.216.34 |] )->{'ok'},
        'public_addresses : resolved address on the list : accepted'
    );

    ok( !$dns->( qw| x.example |, [qw| 8.8.8.8 |] )->{'ok'},
        'public_addresses : resolved address not on the list : rejected'
    );

    @resolved = (qw| 2001:4860:4860::8888 |);
    ok( $dns->( qw| x.example |, [] )->{'ok'},
        'public AAAA only : accepted' );
}

######################################################################
say ': http-01 self-test [ async : no fetch before the setup reply ]';
{
    my $selftest = $code{'letsencr.child.verify_http_selftest'};
    my $expected = 'letsencr-self-test.' . ( 'T' x 48 );

    reset_calls();
    @fetches                               = ();
    @parent_replies                        = ();
    $data{'letsencr'}{'child'}{'selftest'} = {};
    $route_send_result                     = TRUE;
    $http_get_result                       = $expected;

    my $r = $selftest->( { 'domain' => qw| x.example |, 'reply_id' => 42 } );
    ok( $r->{'ok'}, 'self-test queued' );
    ok( $routed[0]->{'command'} eq qw| httpd.setup-acme-challenge |
            && $routed[0]->{'call_args'}->{'args'}
            =~ m{^x\.example \S+ \Q$expected\E$}
            && $routed[0]->{'reply'}->{'handler'} eq
            qw| letsencr.child.handler.selftest_setup_reply |,
        '  :.. token placed via httpd.setup-acme-challenge + reply handler'
    );
    ok( !@fetches && !@parent_replies,
        '  :.. no fetch and no parent reply before httpd answers' );
    ok( scalar(
            grep {
                ( $ARG->{'handler'} // '' ) eq
                    qw| letsencr.child.handler.selftest_timeout |
            } @timers
        ),
        '  :.. a timeout guard is armed'
    );

    deliver_setup_reply('TRUE');
    ok( @fetches == 1
            && $fetches[0]
            =~ m{^http://x\.example/\.well-known/acme-challenge/\S+$},
        'setup TRUE : the url is fetched'
    );
    ok( @cleanups == 1 && $cleanups[0][0] eq qw| x.example |,
        '  :.. test token cleaned up after pass' );
    ok( @parent_replies == 1
            && $parent_replies[0][0] == 42
            && $parent_replies[0][1]{'mode'} eq qw| true |,
        '  :.. deferred TRUE reply to the parent'
    );

    ## content mismatch ##
    @fetches         = ();
    @cleanups        = ();
    @parent_replies  = ();
    $http_get_result = qw| something-else |;
    $selftest->( { 'domain' => qw| x.example |, 'reply_id' => 43 } );
    deliver_setup_reply('TRUE');
    ok( @parent_replies == 1
            && $parent_replies[0][1]{'mode'} eq qw| false |
            && $parent_replies[0][1]{'data'} =~ m{mismatch},
        'content mismatch : deferred FALSE to the parent'
    );
    ok( @cleanups == 1, '  :.. test token cleaned up after mismatch' );

    ## httpd answers FALSE ##
    @fetches        = ();
    @cleanups       = ();
    @parent_replies = ();
    $selftest->( { 'domain' => qw| x.example |, 'reply_id' => 44 } );
    deliver_setup_reply('FALSE');
    ok( !@fetches
            && @parent_replies == 1
            && $parent_replies[0][1]{'mode'} eq qw| false |,
        'setup FALSE : no fetch, deferred FALSE to the parent'
    );
    ok( @cleanups == 1, '  :.. test token cleaned up after setup failure' );

    ## timeout : whichever fires first wins ##
    @fetches        = ();
    @cleanups       = ();
    @parent_replies = ();
    $selftest->( { 'domain' => qw| x.example |, 'reply_id' => 45 } );
    my $token = $routed[-1]->{'reply'}->{'params'}->{'token'};
    ## the real timer passes the EVENT : its data sits at ->w->data ##
    my $fake_event = bless { 'data' => { 'token' => $token } },
        qw| Test::FakeTimerEvent |;
    $code{'letsencr.child.handler.selftest_timeout'}->($fake_event);
    ok( @parent_replies == 1
            && $parent_replies[0][0] == 45
            && $parent_replies[0][1]{'mode'} eq qw| false |
            && $parent_replies[0][1]{'data'} =~ m{timed out},
        'timeout : deferred FALSE to the parent'
    );
    ok( @cleanups == 1, '  :.. test token cleaned up after timeout' );
    deliver_setup_reply('TRUE');    ## late reply : no-op ##
    ok( @parent_replies == 1 && @cleanups == 1 && !@fetches,
        '  :.. a late setup reply is a no-op' );

    ## setup command cannot be queued ##
    @parent_replies    = ();
    @routed            = ();
    $route_send_result = FALSE;
    $r = $selftest->( { 'domain' => qw| x.example |, 'reply_id' => 46 } );
    ok( !$r->{'ok'} && $r->{'reason'} =~ m{setup},
        'httpd unreachable : fails immediately [ not deferred ]' );
    ok( !keys %{ $data{'letsencr'}{'child'}{'selftest'} },
        '  :.. no pending self-test left behind'
    );
    $route_send_result = TRUE;
}

######################################################################
say ': verify-domain command [ dns gate, deferred self-test ]';
{
    my $verify   = $code{'letsencr.child.cmd.verify-domain'};
    my $expected = 'letsencr-self-test.' . ( 'T' x 48 );

    @resolved = (qw| 10.0.0.5 |);
    $call = { 'args' => qw| x.example |, 'param' => {}, 'reply_id' => 50 };
    my $r = $verify->();
    ok( $r->{'mode'} eq qw| false | && $r->{'data'} =~ m{^dns :},
        'dns failure : immediate false with the reason'
    );

    @resolved                              = (qw| 93.184.216.34 |);
    $http_get_result                       = $expected;
    @cleanups                              = ();
    @parent_replies                        = ();
    @fetches                               = ();
    $data{'letsencr'}{'child'}{'selftest'} = {};
    $r                                     = $verify->();
    ok( $r->{'mode'} eq qw| deferred |,
        'dns passed : self-test queued, reply deferred' );
    ok( !@fetches, '  :.. no fetch before httpd answers the setup' );
    deliver_setup_reply('TRUE');
    ok( @parent_replies == 1
            && $parent_replies[0][0] == 50
            && $parent_replies[0][1]{'mode'} eq qw| true |,
        'setup TRUE + matching fetch : deferred TRUE [ cleanup : '
            . scalar(@cleanups) . ' ]'
    );
}

######################################################################
say ': verify reply [ staging server chosen, backoff on failure ]';
{
    my $handler = $code{'letsencr.parent.handler_enroll_verify_reply'};

    reset_calls();
    $handler->(
        {   'cmd'    => qw| TRUE |,
            'params' => {
                'domain'    => qw| fresh.example |,
                'alt_names' => [],
                'staging'   => TRUE,
            }
        }
    );
    my $req = $sent[0];
    ok( $req->{'command'} eq qw| child.request-certificate |,
        'checks passed : certificate order queued'
    );
    ok( ( $req->{'call_args'}->{'param'}->{'acme_server'} // '' ) eq $STAGING,
        '  :.. staging enrollments go to the staging acme server'
    );
    ok( $req->{'reply'}->{'handler'} eq
            qw| letsencr.parent.handler_enrollment_reply |
            && $req->{'reply'}->{'params'}->{'enrollment'}
            && $req->{'reply'}->{'params'}->{'staging'},
        '  :.. enrollment + staging flags carried in the reply params'
    );

    reset_calls();
    $handler->(
        {   'cmd'    => qw| TRUE |,
            'params' => {
                'domain'    => qw| prod.example |,
                'alt_names' => [],
                'staging'   => FALSE,
            }
        }
    );
    ok( !defined $sent[0]->{'call_args'}->{'param'}->{'acme_server'},
        'staging off : no per-request server [ zenka-wide production ]'
    );

    reset_calls();
    clear_state();
    $handler->(
        {   'cmd'    => qw| FALSE |,
            'data'   => 'dns : resolves to private only',
            'params' => { 'domain' => qw| bad.example |, 'staging' => TRUE }
        }
    );
    my $state = $code{'letsencr.parent.enroll_state_load'}->();
    ok( !@sent
            && ( $state->{'bad.example'}->{'attempts'} // 0 ) == 1
            && $state->{'bad.example'}->{'next_attempt_after'} > time(),
        'checks failed : no order, backoff recorded + persisted'
    );
}

######################################################################
say ': enrollment reply [ staging not installed, production installed ]';
{
    my $handler = $code{'letsencr.parent.handler_enrollment_reply'};

    my $bundle = encode_b32r(
        JSON::XS::encode_json(
            {   'certificate' => qw| STAGING-CERT |,
                'key'         => qw| STAGING-KEY |,
                'expires_at'  => time() + 86400,
                'domains'     => [qw| stage.example |],
            }
        )
    );

    reset_calls();
    $code{'letsencr.parent.enroll_state_save'}->( {} );
    $handler->(
        {   'cmd'    => qw| SIZE |,
            'data'   => $bundle,
            'params' => {
                'domain'     => qw| stage.example |,
                'attempt'    => 1,
                'enrollment' => 1,
                'staging'    => TRUE,
            }
        }
    );
    ok( !$parent_calls{'save'} && !$parent_calls{'install'},
        'staging certificate : not saved to certs dir, not installed'
    );
    ok( !exists $data{'letsencr'}{'parent'}{'certs'}{'stage.example'},
        '  :.. not added to the production certificate registry'
    );
    my $state = $code{'letsencr.parent.enroll_state_load'}->();
    ok( ( $state->{'stage.example'}->{'status'} // '' ) eq
            qw| issued-staging |,
        '  :.. enrollment state : issued-staging'
    );

    reset_calls();
    $handler->(
        {   'cmd'    => qw| SIZE |,
            'data'   => $bundle,
            'params' => {
                'domain'     => qw| prod2.example |,
                'attempt'    => 1,
                'enrollment' => 1,
                'staging'    => FALSE,
            }
        }
    );
    ok( $parent_calls{'save'} && $parent_calls{'install'},
        'production enrollment : saved + installed to httpsd'
    );
    ok( exists $data{'letsencr'}{'parent'}{'certs'}{'prod2.example'},
        '  :.. added to the certificate registry' );
    $state = $code{'letsencr.parent.enroll_state_load'}->();
    ok( ( $state->{'prod2.example'}->{'status'} // '' ) eq qw| issued |,
        '  :.. enrollment state : issued' );

    reset_calls();
    $handler->(
        {   'cmd'    => qw| FALSE |,
            'data'   => qw| rate_limited |,
            'params' => {
                'domain'     => qw| fail.example |,
                'attempt'    => 1,
                'enrollment' => 1,
                'staging'    => TRUE,
            }
        }
    );
    $state = $code{'letsencr.parent.enroll_state_load'}->();
    ok( ( $state->{'fail.example'}->{'attempts'} // 0 ) == 1
            && $state->{'fail.example'}->{'next_attempt_after'} > time(),
        'order failure : persistent backoff recorded'
    );
    ok( !grep( { ( $ARG->{'handler'} // '' ) =~ m{enrollment_retry} }
            @timers ),
        '  :.. no short retry timers for automatic enrollments'
    );
}

######################################################################
say ': per-request server + separate accounts [ acme_new ]';
{
    my $paths = $code{'letsencr.child.account_file_paths'};

    my $prod_paths = $paths->($PROD);
    my $stag_paths = $paths->($STAGING);
    ok( $prod_paths->{'key_rsa'} eq "$tmp/account.key.rsa"
            && $prod_paths->{'account_json'} eq "$tmp/account.json",
        'production : legacy account file names [ unchanged ]'
    );
    ok( $stag_paths->{'key_rsa'} ne $prod_paths->{'key_rsa'}
            && $stag_paths->{'account_json'} =~ m{account\.acme-staging},
        'staging : separate account key + registration storage'
    );

    my $new = $code{'letsencr.child.acme_new'};

    @fetched_dirs                             = ();
    @loaded_key_servers                       = ();
    $data{'letsencr'}{'child'}{'acme_client'} = { 'server' => $PROD };
    my $r = $new->(
        { 'domains' => [qw| s.example |], 'server' => $STAGING }, undef
    );
    ok( ( $fetched_dirs[0] // '' ) eq $STAGING,
        'new enrollment : directory fetched from the staging server' );
    ok( ( $loaded_key_servers[0] // '' ) eq $STAGING,
        '  :.. account key loaded for the staging server'
    );
    ok( $data{'letsencr'}{'child'}{'acme_client'}->{'server'} eq $STAGING,
        '  :.. client state switched to staging' );

    ## renewal [ renew-certificate calls acme_new without a server ] : must ##
    ## switch back to the configured production server + account            ##
    @fetched_dirs       = ();
    @loaded_key_servers = ();
    $r                  = $new->( { 'domains' => [qw| r.example |] }, undef );
    ok( ( $fetched_dirs[0] // '' ) eq $PROD,
        'renewal : directory fetched from the production server' );
    ok( ( $loaded_key_servers[0] // '' ) eq $PROD,
        '  :.. account key loaded for the production server'
    );
}

say '';
say "passed : " . ( $test_count - $fail_count ) . "  failed : $fail_count";
exit( $fail_count ? 1 : 0 );

#,,,.,.,,,.,,,,.,,,.,,,.,,,..,,.,,,,.,,,.,.,,,..,,...,..,,,..,,.,,...,.,.,.,.,
#BFXAWHEXUFV5FOWIYIJDCEIC45DRCSDKXFVVTZ3XUNGREW73CWHOCVERJ7U252XBTSNHBVLYXWBDW
#\\\|GUJNM43MLFJMRO5ZJXECIC3HMU2MQ7BCYMNWEBY6ULGZM2Z7ZUI \ / AMOS7 \ YOURUM ::
#\[7]75N64WKZSZGAFD7EQOOQ26ELAGEPNYVBOU3FODKM2GUTUGHHHICI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
