#!/usr/bin/env perl
use v5.32;
use strict;
use English;
use warnings;
use bytes;
use Socket;
use Fcntl;
use File::Spec;
use File::Temp qw| tempdir |;
use FindBin    qw| $RealBin |;
use Cwd        qw| abs_path |;

use constant { TRUE => 5, FALSE => 0 };

BEGIN {
    my $up   = File::Spec->updir;
    my $root = abs_path( File::Spec->catdir( $RealBin, $up, $up ) );
    $main::root_path = $root;
    unshift @INC, File::Spec->catdir( $root, qw| data lib-path pm | );
}
use AMOS7::Protocol::P7Syntax qw| p7_syntax__translate |;

my $checks = 0;
my $failed = 0;

sub ok {
    my ( $cond, $label ) = @ARG;
    $checks++;
    if ($cond) { say "ok   : $label"; return TRUE }
    $failed++;
    say "FAIL : $label";
    return FALSE;
}

sub write_file {
    my ( $path, $content, $mode ) = @ARG;
    open( my $fh, '>:raw', $path ) or die "write $path : $OS_ERROR";
    print {$fh} $content;
    close($fh)                    or die;
    chmod( $mode // 0600, $path ) or die;
}

my $tmp    = tempdir( CLEANUP => 1 );
my $passwd = File::Spec->catfile( $tmp, 'passwd' );
my $shadow = File::Spec->catfile( $tmp, 'shadow' );
my $shells = File::Spec->catfile( $tmp, 'shells' );
my $grants = File::Spec->catfile( $tmp, 'grants' );
mkdir($grants)         or die;
chmod( 0700, $grants ) or die;

my @users = qw|
    testuser lowuid notallow locked expired nologin badshell forced
    oldpassword ratelimit global-a global-b
    |;
my %uid;
my $next_uid = 1001;
$uid{$ARG} = $next_uid++ for @users;
my %shell = map { $ARG => '/bin/bash' } @users;
$shell{'nologin'}  = '/usr/sbin/nologin';
$shell{'badshell'} = '/bin/not-a-login-shell';
$uid{'lowuid'}     = 999;

my $secret       = "fixture pass\nwith octets \xc3\xbf";
my $hash         = crypt( $secret, '$6$fixture$' );
my @passwd_lines = map {
    join( ':', $ARG, 'x', $uid{$ARG}, $uid{$ARG}, '', '/tmp', $shell{$ARG} )
} @users;
write_file( $passwd, join( "\n", @passwd_lines, '' ) );
write_file( $shells, "/bin/bash\n" );

my @shadow_lines;
foreach my $user (@users) {
    my $user_hash = $hash;
    $user_hash = "!$hash" if $user eq 'locked';
    my $line = "${user}:${user_hash}::0:99999:7:::";
    $line = "${user}:${user_hash}:1:0:1:0:1:1:"   if $user eq 'expired';
    $line = "${user}:${user_hash}:0:0:99999:7:::" if $user eq 'forced';
    $line = "${user}:${user_hash}:1:0:1:0:1::"    if $user eq 'oldpassword';
    push @shadow_lines, $line;
}
write_file( $shadow, join( "\n", @shadow_lines, '' ) );

my $config = File::Spec->catfile( $tmp, 'auth.cfg' );
my $allow  = join( ' ', grep { $ARG ne 'notallow' } @users );
write_file( $config,
          "login-screen.auth.allow = $allow\nlogin-screen.auth.user_free "
        . "= 2\nlogin-screen.auth.global_free = 50\n" );

sub spawn_helper {
    my ($config_path) = @ARG;
    socketpair( my $client, my $server, AF_UNIX, SOCK_STREAM, PF_UNSPEC )
        or die;
    binmode( $client, ':raw' );
    binmode( $server, ':raw' );
    my $pid = fork() // die;
    if ( $pid == 0 ) {
        close($client);
        fcntl( $server, F_SETFD, 0 ) or POSIX::_exit(126);
        exec {$EXECUTABLE_NAME} $EXECUTABLE_NAME,
            "$main::root_path/bin/login-screen-auth",
            '--fd',          fileno($server),
            '--config',      $config_path,
            '--test-passwd', $passwd,
            '--test-shadow', $shadow,
            '--test-shells', $shells, '--test-grant-dir', $grants
            or POSIX::_exit(127);
    }
    close($server);
    return ( $pid, $client );
}

sub request {
    my ( $fh, $username, $password ) = @ARG;
    my $frame  = pack( 'n/a* n/a*', $username, $password );
    my $wire   = pack( 'N', length($frame) ) . $frame;
    my $offset = 0;
    while ( $offset < length($wire) ) {
        my $written
            = syswrite( $fh, $wire, length($wire) - $offset, $offset );
        return 'IO' if not defined $written or $written == 0;
        $offset += $written;
    }
    my $reply = '';
    while ( $reply !~ m|\n$| and length($reply) < 128 ) {
        my $read = sysread( $fh, my $part, 128 - length($reply) );
        last if not defined $read or $read == 0;
        $reply .= $part;
    }
    $frame = $wire = $password = "\0" x length($password);
    return $reply;
}

my ( $helper_pid, $io ) = spawn_helper($config);
my $ticket;
my $reply = request( $io, 'testuser', $secret );
ok( $reply =~ m|^OK ([0-9a-f]{64})\n$|, 'valid fixture password accepted' );
$ticket = $1 if $reply =~ m|^OK ([0-9a-f]{64})\n$|;
ok( defined $ticket && -f File::Spec->catfile( $grants, $ticket ),
    'success writes a root-grant ticket file' );
if ( defined $ticket ) {
    my $path = File::Spec->catfile( $grants, $ticket );
    ok( ( ( stat($path) )[2] & 0777 ) == 0600, 'grant file mode is 0600' );
}
ok( request( $io, 'testuser', 'wrong' ) eq "FAIL\n",
    'wrong password gets generic failure'
);
ok( request( $io, 'unknown', $secret ) eq "FAIL\n",
    'unknown user gets the same failure'
);
ok( request( $io, 'notallow', $secret ) eq "FAIL\n",
    'user outside allow-list is refused' );
ok( request( $io, 'lowuid', $secret ) eq "FAIL\n",
    'uid below 1000 is refused' );
## the dummy hash password is public : an existing but inadmissible account ##
## must not pass with it [ was : OK + grant for lowuid ]                    ##
ok( request( $io, 'lowuid', 'fixture-only-dummy-password' ) eq "FAIL\n",
    'dummy hash password never grants an inadmissible account'
);
ok( request( $io, 'locked', $secret ) eq "FAIL\n",
    'locked shadow hash is refused' );
ok( request( $io, 'expired', $secret ) eq "FAIL\n",
    'expired account is refused' );
ok( request( $io, 'nologin', $secret ) eq "FAIL\n",
    'nologin shell is refused' );
ok( request( $io, 'badshell', $secret ) eq "FAIL\n",
    'shell outside shells list is refused'
);
ok( request( $io, 'forced', $secret ) eq "FAIL\n",
    'forced-change shadow account is refused'
);
ok( request( $io, 'oldpassword', $secret ) eq "FAIL\n",
    'expired password and grace are refused'
);
ok( request( $io, "bad\nuser", $secret ) eq "ERROR\n",
    'malformed username cannot reach account policy'
);

ok( request( $io, 'ratelimit', 'one' ) eq "FAIL\n",
    'rate fixture failure one' );
ok( request( $io, 'ratelimit', 'two' ) eq "FAIL\n",
    'rate fixture failure two' );
ok( request( $io, 'ratelimit', 'three' ) eq "FAIL\n",
    'third failure completes and schedules delay'
);
ok( request( $io, 'ratelimit', $secret ) =~ m|^WAIT \d+\n$|,
    'next request is delayed before crypt' );

our %data;
our %code;
my $module      = 'v7-zenki.login-session.consume_grant';
my $module_path = File::Spec->catfile( $main::root_path, 'src', $module );
open( my $module_fh, '<:raw', $module_path ) or die;
my $source = join( '', <$module_fh> );
close($module_fh);
my $compiled = eval 'sub { ' . p7_syntax__translate($source) . ' }';
die "consume_grant compile : $EVAL_ERROR" if not $compiled;
$code{$module} = $compiled;
$data{'v7-zenki'}{'login-session'}{'grant_dir'} = $grants;

if ( $EUID == 0 and defined $ticket ) {
    my $grant = $code{$module}->( 'testuser', $ticket );
    ok( defined $grant && $grant->{'uid'} == $uid{'testuser'},
        'v7 consumes a valid grant exactly once' );
    ok( !defined $code{$module}->( 'testuser', $ticket ),
        'grant replay is refused' );
} else {
    ok( TRUE, 'skip valid grant consume [ requires root-owned fixture ]' );
    ok( TRUE, 'skip grant replay [ requires root-owned fixture ]' );
}

$reply = request( $io, 'testuser', $secret );
my $second_ticket = $1 if $reply =~ m|^OK ([0-9a-f]{64})\n$|;
ok( defined $second_ticket, 'second valid grant issued for wrong-user test' );
if ( $EUID == 0 and defined $second_ticket ) {
    ok( !defined $code{$module}->( 'lowuid', $second_ticket ),
        'grant cannot be claimed by another user'
    );
    ok( not -f File::Spec->catfile( $grants, $second_ticket ),
        'wrong-user claim still consumes the grant'
    );
} else {
    ok( TRUE, 'skip wrong-user grant [ requires root-owned fixture ]' );
    ok( TRUE, 'skip wrong-user consumption [ requires root-owned fixture ]' );
}

close($io);
waitpid( $helper_pid, 0 );

my $global_config = File::Spec->catfile( $tmp, 'global.cfg' );
write_file( $global_config,
          "login-screen.auth.allow = $allow\nlogin-screen.auth.user_free "
        . "= 50\nlogin-screen.auth.global_free = 1\n" );
( $helper_pid, $io ) = spawn_helper($global_config);
ok( request( $io, 'global-a', 'wrong' ) eq "FAIL\n",
    'global rate first failure' );
ok( request( $io, 'global-b', 'wrong' ) eq "FAIL\n",
    'global rate second failure across another user'
);
ok( request( $io, 'global-a', $secret ) =~ m|^WAIT \d+\n$|,
    'global growing delay applies across users'
);
close($io);
waitpid( $helper_pid, 0 );

sub refusal_status {
    my (@args) = @ARG;
    my $pid = open( my $pipe, '-|' ) // die;
    if ( $pid == 0 ) {
        open( STDERR, '>&', STDOUT ) or die;
        exec {$EXECUTABLE_NAME} $EXECUTABLE_NAME,
            "$main::root_path/bin/login-screen-auth", @args
            or POSIX::_exit(127);
    }
    my $output = join( '', <$pipe> );
    close($pipe);
    return ( $CHILD_ERROR >> 8, $output );
}
my ( $status, $output ) = refusal_status( '--fd', 0, '--shadow', $shadow );
ok( $status != 0 && $output =~ m|refused option|,
    'production mode refuses a shadow-path override'
);
( $status, $output ) = refusal_status( '--fd', 0, '--test-shadow', $shadow );
ok( $status != 0 && $output =~ m|incomplete fixture mode|,
    'fixture mode requires every policy path and grant dir'
);

say '';
say sprintf ':: %d checks, %d failed', $checks, $failed;
exit( $failed ? 1 : 0 );

#,,,,,,.,,,,,,,..,.,,,,..,,..,.,,,...,,,,,..,,..,,...,...,...,..,,,,.,..,,..,,
#4R74POW2EO6CP7DVMO6UFMFDHZHUIZHWBPKGUTK7DXDZ73FQ6FOBEJ6T6XGA2KZS24TLPATF45VSW
#\\\|TQMQMHOEY6VDIQWPMNZVQ7QVOQPUTDDB2CZSA36YH747TKESH4R \ / AMOS7 \ YOURUM ::
#\[7]CH5MZ2WUX6YHI6CRQM6FYY7R5NVUI7EI4EDTNQFGZTF32SMPKYBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
