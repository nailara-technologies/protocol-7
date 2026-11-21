#!/usr/bin/env perl
use v5.32;
use strict;
use English;
use warnings;
use bytes;

use File::Spec;
use Cwd        qw| abs_path |;
use FindBin    qw| $RealBin |;
use File::Temp qw| tempdir |;

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
    unshift @INC, $local_lib_path;
    $main::root_path = $root_path;
}

use AMOS7::Protocol::P7Syntax qw| p7_syntax__translate |;

use constant TRUE  => 5;
use constant FALSE => 0;

our %code;
our %data;

$OUTPUT_AUTOFLUSH = 1;
my $fail_count = 0;
my $pass_count = 0;

sub ok {
    my ( $cond, $label ) = @ARG;
    if ($cond) { $pass_count++; say "  ok   : $label"; return }
    $fail_count++;
    say "  FAIL : $label";
    return;
}

my $runtime_pragmas = q{no bytes; use English; use File::stat; use File::Spec;
    use File::Spec::Functions qw| catfile |; use YAML::XS ();
    use open qw| :encoding(UTF-8) |;};
my $module_prefix = q{use constant TRUE => 5; use constant FALSE => 0;};

sub compile_module {
    my ( $module_name, $prefix ) = @ARG;
    $prefix //= $module_prefix;
    my $src_path
        = File::Spec->catfile( $main::root_path, 'src', $module_name );
    open my $fh, '<', $src_path or die "cannot read $src_path : $!";
    my $src = join '', <$fh>;
    close $fh;
    my $translated = p7_syntax__translate($src);
    my $cref
        = eval "$runtime_pragmas sub {\n$prefix\n# "
        . "line 1 \"$module_name\"\n$translated\n}";
    die "compile failed for $module_name : $EVAL_ERROR" if not defined $cref;
    $code{$module_name} = $cref;
    return $cref;
}

my $cmd_header = 'my $call = {}; if ( ref( $ARG[0] ) eq q|HASH| ) { $call '
    . '= $ARG[0] } else { $call->{q|args|} = $ARG[0] }';

my @logged;
my @timers;
my @sent;
my @interval_calls;
my $ntime_counter = 1000;
my $prng_counter  = 0;

$code{'base.logs'} = sub { push @logged, [@ARG]; return };
$code{'base.log'}  = sub { push @logged, [@ARG]; return };
$code{'base.s_warn'}
    = sub { push @logged, [ 'warn', sprintf shift, @ARG ]; return };
$code{'base.ntime.b32'}  = sub { return 'N' . ++$ntime_counter };
$code{'base.prng.bytes'} = sub {
    my $amount = shift // 32;
    $prng_counter++;
    return join '',
        map { chr( ( $prng_counter + $ARG ) % 256 ) } 0 .. $amount - 1;
};
$code{'base.ntime.epoch_timestamp'} = sub { return time };
$code{'base.str.os_err'}            = sub { return $OS_ERROR };
$code{'format.yaml.load_file'}      = sub {
    my $path = shift;
    return eval { YAML::XS::LoadFile($path) };
};
$code{'file.make_path'} = sub {
    my $dir = shift;
    require File::Path;
    File::Path::make_path($dir);
    return -d $dir ? TRUE : FALSE;
};
$code{'file.open'} = sub {
    my $file = shift;
    open my $fh, '>', $file or return undef;
    return $fh;
};
$code{'chk-sum.bmw.L13-str'} = sub {
    my $in   = join '', map { defined $ARG ? $ARG : '' } @ARG;
    my $hash = 0;
    $hash = ( $hash * 33 + $ARG ) % 10000000000000 for unpack 'C*', $in;
    return sprintf '%013d', $hash;
};
$code{'base.cfg_bool'} = sub {
    my $value = shift // 0;
    return $value =~ m{^(?:1|yes|true|on)$}i ? TRUE : FALSE;
};
$code{'event.add_timer'} = sub {
    my $timer = shift;
    push @timers, $timer;
    return TRUE;
};
$code{'protocol-7.route-send'} = sub {
    my $call = shift;
    push @sent, $call;
    return 1;
};

compile_module($_) for qw|
    plugin.web.auth.session.path
    plugin.web.auth.session.read
    plugin.web.auth.session.write
    plugin.web.auth.store.group
    plugin.web.auth.destroy_session
    plugin.web.auth.create_session
    plugin.web.auth.verify_session
    plugin.web.auth.lease_caller
    base.session.user
    base.reply.mode_text
    base.interval.next
    base.interval.rhythm.lifetime
    base.interval.rhythm.non-linear
    jobsite.sync.token_for_url
    jobsite.lease.schedule
    jobsite.lease.start
    jobsite.lease.failed
    jobsite.lease.renew
    jobsite.handler.lease-renewed
    |;
compile_module( 'web.cmd.lease-renew', "$module_prefix\n$cmd_header" );

my $real_destroy = $code{'plugin.web.auth.destroy_session'};
my @revocation_new_active;
my $watch_rotation = FALSE;
$code{'plugin.web.auth.destroy_session'} = sub {
    my ( $hash, @rest ) = @ARG;
    if ($watch_rotation) {
        my $active_dir = "$data{'system'}{'path'}{'zenka-dirs'}{'var_P7'}"
            . '/shared/web-auth/active';
        opendir my $dh, $active_dir or die "cannot read $active_dir : $!";
        my @other_sessions
            = grep { $ARG ne $hash and $ARG !~ m{^\.} } readdir $dh;
        closedir $dh;
        push @revocation_new_active, scalar @other_sessions;
        $watch_rotation = FALSE;
    }
    return $real_destroy->( $hash, @rest );
};

my $real_interval = $code{'base.interval.next'};
$code{'base.interval.next'} = sub {
    my $args = shift;
    push @interval_calls, $args->{'type'};
    return $real_interval->($args);
};

my $tmp = tempdir( 'p7-token-lease-XXXXXXXX', TMPDIR => 1, CLEANUP => 1 );
$data{'system'}{'path'}{'zenka-dirs'} = { 'var_P7' => $tmp };
$data{'system'}{'node'}{'name'}       = qw| test-node |;
$data{'system'}{'amos-zenka-user'}    = qw| test-user |;
$data{'plugin.web.auth'}{'cfg'}       = {
    'secret'  => qw| test-secret |,
    'session' => { 'ttl_seconds' => 300 },
};
$data{'web'}{'cfg'}{'lease'} = {};

sub set_caller {
    my $user = shift;
    $data{'session'} = {
        7 => {
            'mode' => qw| client |,
            'user' => $user,
        },
    };
}

sub lease_call {
    my ( $user, $token, $ttl ) = @ARG;
    my $param = { 'user' => $user };
    $param->{'ttl'} = $ttl if defined $ttl;
    return $code{'web.cmd.lease-renew'}
        ->( { 'param' => $param, 'data' => $token // '' } );
}

sub refused {
    my $reply = shift;
    return (    $reply->{'mode'} eq qw| false |
            and $reply->{'data'} eq 'denied : lease renewal refused' );
}

say "\n :. issuer proof, grants and rotation";
my $initial = $code{'plugin.web.auth.create_session'}
    ->( { 'user_id' => qw| lease-user |, 'ttl' => 90 } );
my $initial_token = $initial->{'token'};
my $initial_hash  = $initial->{'token_hash'};

set_caller(qw| caller-user |);
my $reply = lease_call( qw| lease-user |, $initial_token, 30 );
ok( refused($reply), 'missing grant is refused' );

$data{'web'}{'cfg'}{'lease'}{'lease-user'} = {
    'callers' => qw| another-user |,
    'ttl_max' => 90,
    'scope'   => qw| jobs-sync |,
};
$reply = lease_call( qw| lease-user |, $initial_token, 30 );
ok( refused($reply), 'direct unlisted caller is refused' );

set_caller(qw| cube |);
$reply = lease_call( qw| lease-user |, qw| wrong-token-value |, 30 );
ok( refused($reply), 'wrong token for the lease user is refused' );

my $other = $code{'plugin.web.auth.create_session'}
    ->( { 'user_id' => qw| other-lease-user |, 'ttl' => 90 } );
$reply = lease_call( qw| lease-user |, $other->{'token'}, 30 );
ok( refused($reply), 'token of another lease user is refused' );
$code{ 'plugin.web.auth' . '.destroy_session' }
    ->( $other->{'token_hash'}, qw| hash | );

my $expired = $code{'plugin.web.auth.create_session'}
    ->( { 'user_id' => qw| lease-user |, 'ttl' => 90 } );
my $expired_session
    = $code{'plugin.web.auth.session.read'}->( $expired->{'token_hash'} );
$expired_session->{'expires_at_epoch'} = time - 1;
$code{'plugin.web.auth.session.write'}
    ->( $expired->{'token_hash'}, $expired_session );
$reply = lease_call( qw| lease-user |, $expired->{'token'}, 30 );
ok( refused($reply), 'expired token is refused' );

$reply = $code{'web.cmd.lease-renew'}
    ->( { 'args' => "lease-user -previous-hash $initial_hash" } );
ok( refused($reply), 'hash-only request is refused' );

my $verified_initial
    = $code{'plugin.web.auth.verify_session'}->($initial_token);
ok( ( $verified_initial->{'user_id'} // '' ) eq qw| lease-user |,
    'initial proof verifies directly' );
my $before = time;
$reply = lease_call( qw| lease-user |, $initial_token, 900 );
ok( $reply->{'mode'} eq qw| true |,
    'routed cube caller with a valid token is accepted' );
my ($first_token)  = $reply->{'data'} =~ m{^token \[ shown once \] : (\S+)};
my ($first_expiry) = $reply->{'data'} =~ m{expires_at_epoch=(\d+)$};
ok( defined $first_expiry
        and $first_expiry <= $before + 90
        and $first_expiry > $before,
    'requested ttl is clamped to ttl_max'
);
my $first_hash    = $code{'chk-sum.bmw.L13-str'}->($first_token);
my $first_session = $code{'plugin.web.auth.session.read'}->($first_hash);
ok( ( $first_session->{'data'}{'scope'} // '' ) eq qw| jobs-sync |,
    'lease scope is stored with the session' );
ok( ( $first_session->{'token'} // '' ) eq '',
    'session record contains no clear token'
);

set_caller(qw| caller-user |);
$data{'web'}{'cfg'}{'lease'}{'lease-user'}{'callers'} = qw| caller-user |;
$watch_rotation = TRUE;
$reply = lease_call( qw| lease-user |, $first_token, 30 );
my ($second_token) = $reply->{'data'} =~ m{^token \[ shown once \] : (\S+)};
my $second_hash = $code{'chk-sum.bmw.L13-str'}->( $second_token // '' );
ok( $reply->{'mode'} eq qw| true |
        and not -f "$tmp/shared/web-auth/active/$first_hash/session.yaml"
        and -f "$tmp/shared/web-auth/active/$second_hash/session.yaml",
    'direct listed caller rotates and revokes the old token'
);
ok( @revocation_new_active and $revocation_new_active[-1],
    'replacement is stored before old-token revocation'
);

## a '+' body carries a trailing newline [ base.handler.command ] ##
$reply = lease_call( qw| lease-user |, ( $second_token // '' ) . "\n", 30 );
my ($third_token) = $reply->{'data'} =~ m{^token \[ shown once \] : (\S+)};
ok( $reply->{'mode'} eq qw| true | and defined $third_token,
    'a token body with a trailing newline is accepted as proof'
);
$second_token = $third_token;

say "\n :. consumer scheduling and failure retention";
$data{'jobsite'}{'cfg'}{'sync_url'}    = qw| test-sync-url |;
$data{'jobsite'}{'cfg'}{'sync_token'}  = qw| bootstrap-token-value |;
$data{'jobsite'}{'cfg'}{'sync_tokens'} = '';
$data{'jobsite'}{'cfg'}{'lease'}       = {
    'issuer' => qw| issuer-route |,
    'user'   => qw| lease-user |,
};
$data{'base'}{'interval'}{'cfg'}{'type'} = {
    'jobsite-lease-renew' => {
        'rhythm'            => qw| lifetime |,
        'lifetime_fraction' => 0.667,
        'jitter'            => 0,
        'harmonic'          => 0,
    },
    'jobsite-lease-retry' => {
        'start'      => 2,
        'factor'     => 1.618,
        'cap'        => 377,
        'cap_jitter' => 0,
        'harmonic'   => 0,
    },
};
ok( $code{'jobsite.lease.start'}->(), 'configured consumer starts' );
ok( @timers == 1 and $interval_calls[-1] eq qw| jobsite-lease-retry |,
    'initial renewal uses the interval helper' );
@timers = ();
ok( $code{'jobsite.lease.renew'}->(), 'renewal request is routed' );
my $request = $sent[-1];
ok( $request->{'command'} eq qw| issuer-route.lease-renew |,
    'request targets the configured issuer' );
ok( ( $request->{'call_args'}{'args'} // '' ) eq ''
        and $request->{'call_args'}{'param'}{'user'} eq qw| lease-user |
        and $request->{'call_args'}{'data'} eq qw| bootstrap-token-value |,
    'request carries the current token only in body data'
);

my $renewed_token  = qw| renewed-token-value |;
my $renewed_expiry = time + 300;
my $renew_reply    = {
    'cmd'       => qw| TRUE |,
    'call_args' => {
              'args' => "token [ shown once ] : $renewed_token  "
            . "user=lease-user "
            . "expires_at_epoch=$renewed_expiry",
    },
    'params' => $request->{'reply'}{'params'},
};
ok( $code{'jobsite.handler.lease-renewed'}->($renew_reply),
    'valid renewal reply is accepted' );
ok( $code{'jobsite.sync.token_for_url'}->('test-sync-url') eq $renewed_token,
    'consumer uses the in-memory replacement for sync'
);
ok( @timers == 1
        and $interval_calls[-1] eq qw| jobsite-lease-renew |
        and abs( $timers[0]{'after'} - 200.1 ) < 1,
    sprintf 'next renewal uses lifetime [ timers=%d type=%s delay=%s ]',
    scalar @timers,
    $interval_calls[-1] // '',
    $timers[0]{'after'} // ''
);

@timers = ();
ok( $code{'jobsite.lease.renew'}->(), 'second renewal request is routed' );
$code{'jobsite.handler.lease-renewed'}->(
    { 'cmd' => qw| FALSE |, 'call_args' => { 'args' => 'unavailable' } } );
ok( $code{'jobsite.sync.token_for_url'}->('test-sync-url') eq $renewed_token,
    'issuer failure keeps the current token'
);
ok( @timers == 1 and $interval_calls[-1] eq qw| jobsite-lease-retry |,
    'issuer failure schedules interval backoff' );

$data{'jobsite'}{'lease'}{'lifetime'}         = 100;
$data{'jobsite'}{'lease'}{'expires_at_epoch'} = time + 5;
$data{'jobsite'}{'lease'}{'warned'}           = FALSE;
$code{'jobsite.lease.failed'}->('test-failure');
$code{'jobsite.lease.failed'}->('test-failure');
my $expiry_warnings = grep {
            ( $ARG->[0] // '' ) == 0
        and ( $ARG->[1] // '' )
        =~ m{issuer unavailable}
} @logged;
ok( $expiry_warnings == 1, 'near-expiry warning is logged exactly once' );

my $logged_text = join "\n", map { join ' ', @{$ARG} } @logged;
ok( $logged_text !~ m{bootstrap-token-value|renewed-token-value},
    'tokens never appear in log lines' );

delete $data{'jobsite'}{'cfg'}{'lease'};
$data{'jobsite'}{'cfg'}{'sync_tokens'} = 'other-url=mapped-token-value';
ok( $code{'jobsite.sync.token_for_url'}->('other-url') eq
        qw| mapped-token-value |
        and $code{'jobsite.sync.token_for_url'}->('test-sync-url') eq
        qw| bootstrap-token-value |,
    'without lease config static token behavior is unchanged'
);

say sprintf "\n :. %d passed, %d failed\n", $pass_count, $fail_count;
exit( $fail_count ? 1 : 0 );

#,,.,,,,.,,,,,..,,,,,,.,,,..,,,,,,,,,,,,,,.,,,..,,...,...,...,..,,.,.,...,,,.,
#CVJ3TYTAZLB4RBXCMYHXWOFFXZBAYC3ZCL3IPX7O54FRL7HU7J5WARQJZMBF6DXWLAYSFVL4PH6KC
#\\\|QMTTQ63YZSJNXR5VKFHQWGQ66AXAUMBSAZPD7I7G6KG72WZLA6A \ / AMOS7 \ YOURUM ::
#\[7]D4ZMGJAFE6IBGXOBEGKUPSGXZD7HXCPO5I3NWLWSJ4P22WDCGAAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
