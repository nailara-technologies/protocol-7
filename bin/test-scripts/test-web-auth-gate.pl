#!/usr/bin/env perl
use v5.24;
use strict;
use English;
use warnings;

## the production runtime [ bin/Protocol-7 : use utf8 + Encode ] loads the ##
## bytes pragma transitively ; keep it so compiled modules resolve it.     ##
use bytes;

##     web auth gate on the /jobs* routes : drives the REAL gate module    ##
##     [ httpd.route.handler.web-relay ] against the REAL auth plugin      ##
##     modules on a tempdir session store :                                ##
##     - no token                                    -> 401                ##
##     - valid bearer token                          -> relayed            ##
##     - expired token                               -> 401                ##
##     - token minted under a different secret       -> 401                ##
##     - loopback exemption only where the route enables it                ##
##     - host-configured exempt peers [ web.auth.exempt_peers ] only       ##
##       where the route enables the exemption                             ##
##     - missing secret fails closed [ one log line ]                      ##
##     - web.auth-issue refuses non-admin callers, mints for cube /        ##
##       explicitly granted users, honors -ttl                             ##
##     - jobsite.sync.token_for_url : per-url map + single-token fallback  ##

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
    unshift( @INC, $local_lib_path );
    $main::root_path = $root_path;
}

use AMOS7::Protocol::P7Syntax qw| p7_syntax__translate |;

use constant TRUE    => 5;
use constant FALSE   => 0;
use constant UNKNOWN => 2;

our %code;
our %data;

$OUTPUT_AUTOFLUSH = 1;

my $fail_count = 0;
my $pass_count = 0;

sub ok ($;$) {
    my ( $cond, $label ) = @ARG;
    if ($cond) { $pass_count++; say "  ok   : $label"; return }
    $fail_count++;
    say "  FAIL : $label";
    return;
}

## $prefix : source prepended inside the compiled sub [ constants ]        ##
my $runtime_pragmas = q{no bytes; use English; use File::stat; use File::Spec;
    use File::Spec::Functions qw| catfile |; use YAML::XS ();
    use open qw| :encoding(UTF-8) |;};
my $module_prefix = q{use constant TRUE => 5; use constant FALSE => 0;};

sub compile_module {
    my ( $module_name, $prefix ) = @ARG;
    $prefix //= $module_prefix;
    my $src_path
        = File::Spec->catfile( $main::root_path, 'src', $module_name );
    open( my $fh, '<', $src_path ) or die "cannot read $src_path : $!";
    my $src = join( '', <$fh> );
    close($fh);
    my $translated = p7_syntax__translate($src);
    my $cref
        = eval "$runtime_pragmas sub {\n$prefix\n# "
        . "line 1 \"$module_name\"\n$translated\n}";
    die "compile failed for $module_name : $EVAL_ERROR"
        if not defined $cref;
    $code{$module_name} = $cref;
    return $cref;
}

my $cmd_header = 'my $call = {}; if ( ref( $ARG[0] ) eq q|HASH| ) { $call '
    . '= $ARG[0] } else { $call->{q|args|} = $ARG[0] }';

## ---------------------------------------------------------------------- ##
## stubs                                                                  ##

my @logged;
my @sent_error;
my @relayed;
my $ntime_counter = 1000;

$code{'base.logs'} = sub { push @logged, [@ARG]; return };
$code{'base.log'}  = sub { push @logged, [@ARG]; return };
$code{'base.s_warn'}
    = sub { push @logged, [ 'warn', sprintf( shift, @ARG ) ]; return };
$code{'base.ntime.b32'} = sub { $ntime_counter++; return "N$ntime_counter" };
$code{'base.ntime.epoch_timestamp'} = sub { return time };
$code{'base.str.os_err'}            = sub { return $OS_ERROR };
$code{'format.yaml.load_file'}      = sub {
    my $path = shift;
    return eval { YAML::XS::LoadFile($path) };
};
$code{'file.make_path'} = sub {
    my ( $dir, $mode ) = @ARG;
    require File::Path;
    File::Path::make_path($dir);
    return -d $dir ? TRUE : FALSE;
};
$code{'file.open'} = sub {
    my ( $file, $layer, $mode, $lock, $perm ) = @ARG;
    open( my $fh, '>', $file ) or return undef;
    return $fh;
};

## deterministic stand-ins for the checksums : distinct inputs give     ##
## distinct outputs, and every consumer here goes through the same stub ##
$code{'chk-sum.amos'} = sub {
    my $in = join '', map { defined $ARG ? $ARG : '' } @ARG;
    return sprintf( 'AMOS-%08d', unpack( '%32C*', $in ) );
};
$code{'chk-sum.bmw.L13-str'} = sub {
    my $in = join '', map { defined $ARG ? $ARG : '' } @ARG;
    return sprintf( '%013d', unpack( '%32C*', $in ) % 10000000000000 );
};

$code{'httpd.send_error_page'} = sub {
    my ( $sid, $error_code ) = @ARG;
    push @sent_error, [ $sid, $error_code ];
    return 2;
};
$code{'protocol-7.route-send'} = sub {
    my $call = shift;
    push @relayed, $call;
    return 0;
};

## ---------------------------------------------------------------------- ##
## the real modules under test                                            ##

compile_module($_) for qw|
    plugin.web.auth.session.path
    plugin.web.auth.session.read
    plugin.web.auth.session.write
    plugin.web.auth.store.group
    plugin.web.auth.destroy_session
    plugin.web.auth.create_session
    plugin.web.auth.verify_session
    base.session.user
    base.has_access
    jobsite.sync.token_for_url
    httpd.route.handler.web-relay
    |;

compile_module( 'web.cmd.auth-issue', $module_prefix . "\n" . $cmd_header );

## ---------------------------------------------------------------------- ##
## temp session store + zenka identity                                    ##

my $tmp = tempdir( 'p7-web-auth-gate-XXXXXXXX', TMPDIR => 1, CLEANUP => 1 );

$data{'system'}{'path'}{'zenka-dirs'} = { 'var_P7' => $tmp };
$data{'system'}{'zenka'}{'name'}      = qw| httpd |;
$data{'system'}{'node'}{'name'}       = qw| test-node |;
$data{'system'}{'amos-zenka-user'}    = qw| tester |;

$data{'plugin.web.auth'}{'cfg'} = {
    'secret'  => qw| test-secret-A |,
    'session' => { 'ttl_seconds' => 86400 },
};

$data{'access'}{'cmd'}{'regex'}{'usr'} = {};

my @perl_warnings;
local $SIG{__WARN__} = sub { push @perl_warnings, @ARG };

## ---------------------------------------------------------------------- ##
## helpers                                                                ##

## run the real gate for one request : returns ( error_code, relayed )    ##
sub gate_call {
    my ( $peer, $headers, %route_extra ) = @ARG;
    $data{'session'} = {
        1 => {
            'http' => {
                'request' => {
                    'headers' => $headers // {},
                    'client'  => { 'addr' => $peer // qw| 203.0.113.10 | },
                },
                'body' => '',
            },
            'buffer' => { 'input' => '' },
        }
    };
    @sent_error = ();
    @relayed    = ();
    $code{'httpd.route.handler.web-relay'}->(
        1,
        {   'command'       => qw| web.jobs-data |,
            'auth.required' => 1,
            %route_extra,
        }
    );
    my $error_code = @sent_error ? $sent_error[0][1] : 0;
    return ( $error_code, scalar @relayed );
}

sub mint_token {
    my %params = @ARG;
    return $code{'plugin.web.auth.create_session'}->( \%params );
}

sub bearer { return { 'authorization' => "Bearer $ARG[0]" } }

## ---------------------------------------------------------------------- 1 ##
## : the gate itself                                                        ##

say "\n :. gate [ httpd.route.handler.web-relay + plugin.web.auth.* ]";

my ( $err, $relayed_count ) = gate_call();
ok( $err == 401 && $relayed_count == 0, 'no token -> 401, no relay' );

my $session = mint_token( 'user_id' => qw| jobsite-push | );
ok( defined $session && length( $session->{'token'} // '' ), 'token minted' );

( $err, $relayed_count )
    = gate_call( undef, bearer( $session->{'token'} ) );
ok( $err == 0 && $relayed_count == 1, 'valid bearer token -> relayed' );

my $expired = mint_token( 'user_id' => qw| old |, 'ttl' => -3600 );
( $err, $relayed_count )
    = gate_call( undef, bearer( $expired->{'token'} ) );
ok( $err == 401 && $relayed_count == 0, 'expired token -> 401' );

my $cookie_session = mint_token( 'user_id' => qw| ui-user | );
( $err, $relayed_count )
    = gate_call( undef,
    { 'cookie' => 'other=1; p7_session=' . $cookie_session->{'token'} } );
ok( $err == 0 && $relayed_count == 1,
    'p7_session cookie accepted as fallback'
);

## ---------------------------------------------------------------------- 2 ##
## : wrong secret revokes outstanding tokens                                ##

say "\n :. secret binding";

$data{'plugin.web.auth'}{'cfg'}{'secret'} = qw| test-secret-B |;
( $err, $relayed_count )
    = gate_call( undef, bearer( $session->{'token'} ) );
ok( $err == 401 && $relayed_count == 0,
    'token minted under another secret -> 401'
);
$data{'plugin.web.auth'}{'cfg'}{'secret'} = qw| test-secret-A |;
( $err, $relayed_count )
    = gate_call( undef, bearer( $session->{'token'} ) );
ok( $err == 0 && $relayed_count == 1,
    'token verifies again once the secret is back' );

## ---------------------------------------------------------------------- 3 ##
## : loopback exemption only where enabled                                  ##

say "\n :. loopback + host-configured peer exemption";

( $err, $relayed_count ) = gate_call(qw| 127.0.0.1 |);
ok( $err == 401 && $relayed_count == 0,
    'loopback peer still 401 without auth.exempt-loopback' );

( $err, $relayed_count )
    = gate_call( qw| 127.0.0.1 |, undef, 'auth.exempt-loopback' => 1 );
ok( $err == 0 && $relayed_count == 1,
    'loopback peer exempt where the route enables it' );

( $err, $relayed_count )
    = gate_call( qw| ::1 |, undef, 'auth.exempt-loopback' => 1 );
ok( $err == 0 && $relayed_count == 1, '::1 exempt as well' );

( $err, $relayed_count )
    = gate_call( qw| ::ffff:127.0.0.1 |, undef, 'auth.exempt-loopback' => 1 );
ok( $err == 0 && $relayed_count == 1, 'ipv4-mapped ::ffff:127.0.0.1 exempt' );

( $err, $relayed_count )
    = gate_call( undef, undef, 'auth.exempt-loopback' => 1 );
ok( $err == 401 && $relayed_count == 0,
    'non-loopback peer stays gated even with the exemption enabled' );

( $err, $relayed_count ) = gate_call(
    undef,
    { 'x-forwarded-for' => qw| 127.0.0.1 | },
    'auth.exempt-loopback' => 1
);
ok( $err == 401 && $relayed_count == 0,
    'X-Forwarded-For never counts as the peer'
);

## ---------------------------------------------------------------------- 4 ##
## : host-configured exempt peers [ web.auth.exempt_peers ]                 ##

say "\n :. host config exempt peers [ WSL private-lan set-up ]";

$data{'web'}{'auth'}{'exempt_peers'} = qw| 198.51.100.7 |;

( $err, $relayed_count ) = gate_call(qw| 198.51.100.7 |);
ok( $err == 401 && $relayed_count == 0,
    'host-configured peer NOT exempt without the route flag' );

( $err, $relayed_count )
    = gate_call( qw| 198.51.100.7 |, undef, 'auth.exempt-loopback' => 1 );
ok( $err == 0 && $relayed_count == 1,
    'host-configured peer exempt where the route enables it' );

( $err, $relayed_count )
    = gate_call( qw| 198.51.100.8 |, undef, 'auth.exempt-loopback' => 1 );
ok( $err == 401 && $relayed_count == 0,
    'peer not listed in exempt_peers stays gated' );

delete $data{'web'}{'auth'}{'exempt_peers'};

## ---------------------------------------------------------------------- 5 ##
## : missing secret fails closed                                            ##

say "\n :. missing secret [ fail closed ]";

$data{'plugin.web.auth'}{'cfg'}{'secret'} = '';
( $err, $relayed_count )
    = gate_call( undef, bearer( $session->{'token'} ) );
my ( $err2, $relayed_count2 )
    = gate_call( undef, bearer( $session->{'token'} ) );
ok( $err == 401
        && $relayed_count == 0
        && $err2 == 401
        && $relayed_count2 == 0,
    'valid token refused while no secret is configured'
);
my $no_secret_lines = scalar grep {m|no web\.auth\.secret|sm}
    map {
    join ' ',
        map { $_ // '' }
        $ARG->@*
    } @logged;
ok( $no_secret_lines == 1,
    'exactly one clear log line for the missing secret' );

$data{'plugin.web.auth'}{'cfg'}{'secret'} = qw| test-secret-A |;
( $err, $relayed_count )
    = gate_call( undef, bearer( $session->{'token'} ) );
ok( $err == 0 && $relayed_count == 1,
    'gate passes again once the secret is configured' );

## ---------------------------------------------------------------------- 6 ##
## : web.auth-issue caller gating                                           ##

say "\n :. web.auth-issue [ admin only ]";

sub issue_as {
    my ($user) = @ARG;
    $data{'session'}
        = defined $user
        ? { 9 => { 'mode' => qw| client |, 'user' => $user } }
        : {};
    return $code{'web.cmd.auth-issue'}->( { 'args' => 'jobsite-push' } );
}

my $reply = issue_as(qw| mallory |);
ok( ref $reply eq qw| HASH | && $reply->{'mode'} eq qw| false |,
    'non-admin caller refused' );

$reply = issue_as(undef);
ok( ref $reply eq qw| HASH | && $reply->{'mode'} eq qw| false |,
    'unresolvable caller refused' );

$reply = issue_as(qw| cube |);
ok( ref $reply eq qw| HASH |
        && $reply->{'mode'} eq qw| true |
        && $reply->{'data'} =~ m|token \[ shown once \] : \S+|,
    'cube [ access-table-enforced ] caller can mint'
);

$data{'access'}{'cmd'}{'regex'}{'usr'}{qw| ops |} = qr|^web\.auth-issue$|;
$reply = issue_as(qw| ops |);
ok( ref $reply eq qw| HASH | && $reply->{'mode'} eq qw| true |,
    'local user explicitly granted web.auth-issue can mint'
);
delete $data{'access'}{'cmd'}{'regex'}{'usr'}{qw| ops |};

$data{'session'} = { 9 => { 'mode' => qw| client |, 'user' => qw| cube | } };
$reply
    = $code{'web.cmd.auth-issue'}->( { 'args' => 'jobsite-push -ttl 3600' } );
my ($issued_ttl) = $reply->{'data'} =~ m|expires_at_epoch=(\d+)|;
ok( $reply->{'mode'} eq qw| true |
        && abs( $issued_ttl - ( time + 3600 ) ) <= 1,
    '-ttl honored [ ~1h expiry ]'
);

$reply = $code{'web.cmd.auth-issue'}->( { 'args' => '' } );
ok( $reply->{'mode'} eq qw| false |, 'usage error without user_id' );

## a minted issue-command token passes the gate end to end
$reply = issue_as(qw| cube |);
my ($new_token) = $reply->{'data'} =~ m|shown once \] : (\S+)|;
( $err, $relayed_count ) = gate_call( undef, bearer($new_token) );
ok( $err == 0 && $relayed_count == 1,
    'token from web.auth-issue passes the gate' );

## ---------------------------------------------------------------------- 7 ##
## : jobsite.sync.token_for_url                                             ##

say "\n :. jobsite.sync.token_for_url";

$data{'jobsite'}{'cfg'} = {
    'sync_token'  => qw| single-token |,
    'sync_tokens' => 'https://example.invalid/a=token-a '
        . 'https://example.invalid/b=token-b',
};

my $tok = $code{'jobsite.sync.token_for_url'}->('https://example.invalid/a');
ok( $tok eq qw| token-a |, 'per-url token mapping hit' );

$tok = $code{'jobsite.sync.token_for_url'}->('https://example.invalid/c');
ok( $tok eq qw| single-token |, 'unmapped url falls back to sync_token' );

delete $data{'jobsite'}{'cfg'}{'sync_token'};
$tok = $code{'jobsite.sync.token_for_url'}->('https://example.invalid/c');
ok( $tok eq '', 'no token configured resolves to empty [ push as today ]' );

delete $data{'jobsite'}{'cfg'};

## ---------------------------------------------------------------------- ##
## summary                                                                ##

my @struct_warnings
    = grep {m{uninitialized|Use of|ref\(\) on|Not an? \w+ ref}i}
    @perl_warnings;
ok( scalar @struct_warnings == 0,
    'no perl warnings from the compiled modules' );

say '';
say "passed : $pass_count  failed : $fail_count";
exit( $fail_count ? 1 : 0 );

#,,,.,.,.,,..,,.,,.,,,.,,,...,,,,,,,.,.,,,.,.,..,,...,...,,,,,,.,,,,.,,..,,.,,
#EZRCPZ2OR4JOJ26SBLHITCUXFQ5JZCZGQR6X6GSSDMEFVFYNEIKACUPBCJGZF2SJXKJ74OVQYEYUW
#\\\|3734WAN33P72HD6UWB7TA35DTDHIDBACPSOHEMQZXYG2KZCK4KK \ / AMOS7 \ YOURUM ::
#\[7]UJED7VIXHT2OIAWY6TPGX6JLAUZF4GFHQF7DKUX7RIDDOAAQVABY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
