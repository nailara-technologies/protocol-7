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
use JSON::XS   ();

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
my $cmd_header    = 'my $call = {}; if ( ref( $ARG[0] ) eq q|HASH| ) { $call '
    . '= $ARG[0] } else { $call->{q|args|} = $ARG[0] }';

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
    die "compile failed for $module_name : $EVAL_ERROR" if !defined $cref;
    $code{$module_name} = $cref;
    return $cref;
}

my @logged;
my $now           = time;
my $ntime_counter = 1000;
my $prng_counter  = 0;

$code{'base.logs'} = sub { push @logged, [@ARG]; return };
$code{'base.log'}  = sub { push @logged, [@ARG]; return };
$code{'base.s_warn'}
    = sub { push @logged, [ 'warn', sprintf shift, @ARG ]; return };
$code{'base.time'}                  = sub { return $now };
$code{'base.ntime.b32'}             = sub { return 'N' . ++$ntime_counter };
$code{'base.ntime.epoch_timestamp'} = sub { return time };
$code{'base.str.os_err'}            = sub { return $OS_ERROR };
$code{'base.prng.bytes'}            = sub {
    my $amount = shift // 32;
    $prng_counter++;
    return join '',
        map { chr( ( $prng_counter + $ARG ) % 256 ) } 0 .. $amount - 1;
};
$code{'format.yaml.load_file'} = sub {
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
$code{'plugin.web.auth.admit.gate'}   = sub { return ( 0, undef, [] ) };
$code{'plugin.web.auth.admit.record'} = sub { return TRUE };

compile_module($_) for qw|
    plugin.web.auth.session.path
    plugin.web.auth.session.read
    plugin.web.auth.session.write
    plugin.web.auth.session.cfg
    plugin.web.auth.store.group
    plugin.web.auth.destroy_session
    plugin.web.auth.create_session
    plugin.web.auth.verify_session
    plugin.web.auth.rotate_session
    plugin.web.auth.ui_session.begin
    plugin.web.auth.ui_session.info
    plugin.web.auth.admit.activity
    plugin.web.auth.admit.renew
    plugin.web.auth.admit.logout
    |;
compile_module( $_, "$module_prefix\n$cmd_header" )
    for qw| web.cmd.auth-activity web.cmd.auth-renew web.cmd.auth-logout |;

my $tmp = tempdir( 'p7-web-ui-session-XXXXXXXX', TMPDIR => 1, CLEANUP => 1 );
$data{'system'}{'path'}{'zenka-dirs'} = { 'var_P7' => $tmp };
$data{'system'}{'node'}{'name'}       = qw| test-node |;
$data{'system'}{'amos-zenka-user'}    = qw| test-user |;
$data{'plugin.web.auth'}{'cfg'}       = {
    'secret'  => qw| test-secret |,
    'session' => {
        'ttl_seconds'          => 300,
        'idle_timeout_seconds' => 900,
        'max_age_seconds'      => 43200,
        'overlap_seconds'      => 30,
    },
};

my @tokens;

sub mint_ui {
    my $ttl     = shift // 300;
    my $created = $code{'plugin.web.auth.create_session'}
        ->( { 'user_id' => qw| ui-user |, 'ttl' => $ttl } );
    my $session = $code{'plugin.web.auth.ui_session.begin'}->(
        $code{'plugin.web.auth.verify_session'}->( $created->{'token'} ) );
    push @tokens, $created->{'token'};
    return ( $created->{'token'}, $session );
}

sub envelope {
    my $reply = shift // {};
    return eval { JSON::XS::decode_json( $reply->{'data'} ) } // {};
}

sub reply_body {
    my $env = shift // {};
    return eval { JSON::XS::decode_json( $env->{'body'} // '' ) } // {};
}

sub renew_cookie {
    my ( $token, $tls ) = @ARG;
    my $env = envelope(
        $code{'web.cmd.auth-renew'}->(
            {   'param' => {
                    'cookie_header' => "p7_session=$token",
                    'peer_tls'      => $tls // 1,
                },
            }
        )
    );
    my $cookie = $env->{'set_cookie'} // '';
    my ($replacement) = $cookie =~ m|^p7_session=([^;]+)|;
    push @tokens, $replacement if defined $replacement;
    return ( $env, reply_body($env), $replacement );
}

sub renew_bearer {
    my $token = shift;
    my $env   = envelope( $code{'web.cmd.auth-renew'}
            ->( { 'param' => { 'auth_header' => "Bearer $token" } } ) );
    my $body = reply_body($env);
    push @tokens, $body->{'token'} if defined $body->{'token'};
    return ( $env, $body );
}

sub refused {
    my ( $env, $body ) = @ARG;
    return (    ( $env->{'status'} // 0 ) == 401
            and ( $body->{'error'} // '' ) eq qw| unauthorized |
            and !defined $body->{'token'} );
}

say "\n :. bounded renewal, concurrent tabs and overlap";
my ( $old_token, $old_session ) = mint_ui(300);
my $old_hash = $old_session->{'token_hash'};
my ( $env_a, $body_a, $new_token ) = renew_cookie($old_token);
ok( ( $env_a->{'status'} // 0 ) == 200 and defined $new_token,
    'live cookie session renews within bounds' );
ok( ( $env_a->{'set_cookie'} // '' )
        =~ m|Max-Age=\d+; HttpOnly; SameSite=Strict; Secure$|,
    'renewed cookie preserves all flags and Secure'
);
ok( !exists $body_a->{'token'},
    'cookie renewal body does not expose the token' );

my $before_replay = $prng_counter;
my ( $env_b, $body_b, $replay_token ) = renew_cookie( $old_token, 0 );
ok( ( $env_b->{'status'} // 0 ) == 200
        and defined $replay_token
        and $replay_token eq $new_token
        and $prng_counter == $before_replay,
    'two tabs with one old proof receive one rotation'
);
ok( ( $env_b->{'set_cookie'} // '' ) !~ m|Secure|,
    'non-tls renewal keeps Secure absent'
);
ok( defined $code{'plugin.web.auth.verify_session'}->($old_token),
    'previous token remains valid inside overlap' );
ok( defined $code{'plugin.web.auth.verify_session'}->($new_token),
    'replacement token is valid' );
my $old_overlap = $code{'plugin.web.auth.session.read'}->($old_hash);
ok( ( $old_overlap->{'rotation'}{'current_hash'} // '' ) eq
        $code{'chk-sum.bmw.L13-str'}->($new_token)
        and $old_overlap->{'expires_at_epoch'} <= time + 30,
    'old record points to one current hash and a short expiry'
);
$old_overlap->{'expires_at_epoch'} = time - 1;
$code{'plugin.web.auth.session.write'}->( $old_hash, $old_overlap );
ok( !defined $code{'plugin.web.auth.verify_session'}->($old_token)
        and defined $code{'plugin.web.auth.verify_session'}->($new_token),
    'old token dies after overlap while current remains valid'
);

say "\n :. bearer renewal and absolute-age cap";
my ( $bearer_old, $bearer_session ) = mint_ui(300);
$bearer_session->{'data'}{'ui'}{'max_expires_at_epoch'} = time + 40;
$code{'plugin.web.auth.session.write'}
    ->( $bearer_session->{'token_hash'}, $bearer_session );
my ( $env_bearer, $body_bearer ) = renew_bearer($bearer_old);
ok( ( $env_bearer->{'status'} // 0 ) == 200
        and defined $body_bearer->{'token'}
        and !exists $env_bearer->{'set_cookie'},
    'bearer renewal returns the replacement without a cookie'
);
ok( ( $body_bearer->{'session'}{'expires_at_epoch'} // 0 )
        <= $bearer_session->{'data'}{'ui'}{'max_expires_at_epoch'},
    'renewal never extends past maximum session age'
);

say "\n :. activity, idle and maximum-age refusal";
my ( $idle_token, $idle_session ) = mint_ui(300);
my $idle_started = $idle_session->{'data'}{'ui'}{'last_activity_epoch'};
$code{'plugin.web.auth.verify_session'}->($idle_token);
my $after_poll = $code{'plugin.web.auth.session.read'}
    ->( $idle_session->{'token_hash'} );
ok( $after_poll->{'data'}{'ui'}{'last_activity_epoch'} == $idle_started,
    'verification and polling do not count as user activity'
);
$after_poll->{'data'}{'ui'}{'last_activity_epoch'} = time - 901;
$code{'plugin.web.auth.session.write'}
    ->( $idle_session->{'token_hash'}, $after_poll );
my ( $env_idle, $body_idle ) = renew_cookie($idle_token);
ok( refused( $env_idle, $body_idle ),
    'renewal after idle timeout gets the generic refusal' );

my ( $max_token, $max_session ) = mint_ui(300);
$max_session->{'data'}{'ui'}{'max_expires_at_epoch'} = time - 1;
$code{'plugin.web.auth.session.write'}
    ->( $max_session->{'token_hash'}, $max_session );
my ( $env_max, $body_max ) = renew_bearer($max_token);
ok( refused( $env_max, $body_max ),
    'renewal past maximum age gets the same refusal' );

my ( $activity_token, $activity_session ) = mint_ui(300);
$now += 10;
my $activity_env = envelope(
    $code{'web.cmd.auth-activity'}->(
        { 'param' => { 'cookie_header' => "p7_session=$activity_token" } }
    )
);
$now -= 10;
my $activity_body = reply_body($activity_env);
ok( ( $activity_env->{'status'} // 0 ) == 200
        and ( $activity_body->{'session'}{'last_activity_epoch'} // 0 )
        > $activity_session->{'data'}{'ui'}{'last_activity_epoch'},
    'the dedicated activity action advances server-side activity'
);

my $machine = $code{'plugin.web.auth.create_session'}
    ->( { 'user_id' => qw| machine-user |, 'ttl' => 300 } );
my ( $env_machine, $body_machine ) = renew_bearer( $machine->{'token'} );
ok( refused( $env_machine, $body_machine ),
    'a token without ui login state cannot renew as ui' );

my ( $corrupt_token, $corrupt_session ) = mint_ui(300);
delete $corrupt_session->{'data'}{'ui'};
$code{'plugin.web.auth.session.write'}
    ->( $corrupt_session->{'token_hash'}, $corrupt_session );
my ( $env_corrupt, $body_corrupt ) = renew_bearer($corrupt_token);
ok( refused( $env_corrupt, $body_corrupt ),
    'missing state on a ui-scoped token fails closed'
);

say "\n :. logout revokes both overlap tokens";
my ( $logout_old, undef ) = mint_ui(300);
my ( undef, undef, $logout_current ) = renew_cookie($logout_old);
my $logout_env = envelope(
    $code{'web.cmd.auth-logout'}->(
        { 'param' => { 'cookie_header' => "p7_session=$logout_current" } }
    )
);
ok( ( $logout_env->{'status'} // 0 ) == 200,
    'logout with the current token succeeds'
);
ok( !defined $code{'plugin.web.auth.verify_session'}->($logout_old)
        and !
        defined $code{'plugin.web.auth.verify_session'}->($logout_current),
    'logout revokes current and previous overlap tokens'
);

for my $hash (
    $old_hash,
    $code{'chk-sum.bmw.L13-str'}->($new_token),
    $code{'chk-sum.bmw.L13-str'}->( $body_bearer->{'token'} // '' ),
) {
    my $record      = $code{'plugin.web.auth.session.read'}->($hash) // next;
    my $yaml        = YAML::XS::Dump($record);
    my $clear_count = grep { length and index( $yaml, $ARG ) >= 0 } @tokens;
    ok( $clear_count == 0, 'active session record contains hashes only' );
}

my $logged_text = join "\n", map { join ' ', @{$ARG} } @logged;
my $logged_tokens
    = grep { length and index( $logged_text, $ARG ) >= 0 } @tokens;
ok( $logged_tokens == 0, 'no token appears in logs' );

say sprintf "\n :. %d passed, %d failed\n", $pass_count, $fail_count;
exit( $fail_count ? 1 : 0 );

#,,,,,..,,,,,,,..,.,.,.,.,.,,,...,,.,,,..,.,,,..,,...,...,...,,,,,,.,,.,,,,..,
#WADYGLDEGAZC7ZZJSLHCA2ASWQGNWI73KNBAXLXXBK6FYPQJO3RPM7PCTR5DNSBL6TKNNCF5RLZLS
#\\\|JKAVIBM2MVWZGUCFFPJQQ3KWN4REVSU3L5WTXPDC5RG3OHYNMO2 \ / AMOS7 \ YOURUM ::
#\[7]MOIKGIQHPJXMVXN6ZUXRKYCS5Y7FMBE2Y4ZJ3TF5Y6RWD2ZMK6AI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
