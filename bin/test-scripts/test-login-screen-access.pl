#!/usr/bin/env perl
use v5.32;
use strict;
use English;
use warnings;
use File::Spec;
use File::stat;
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

our %data;
our %code;
our $ARG;
our @ARG;
our $call;

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

sub compile_module {
    my ($name) = @ARG;
    my $path = File::Spec->catfile( $main::root_path, 'src', $name );
    open( my $fh, '<:raw', $path ) or die "cannot read $name";
    my $source = join( '', <$fh> );
    close($fh);
    my $compiled = eval 'sub { ' . p7_syntax__translate($source) . ' }';
    die "$name compile : $EVAL_ERROR" if not $compiled;
    return $compiled;
}

my $write_xauth  = compile_module('base.X-11.write_xauth_file');
my $prepare      = compile_module('X-11.xauth.prepare_server');
my $get_xauth    = compile_module('X-11.cmd.get_xauth_data');
my $get_display  = compile_module('X-11.cmd.get_display');
my $change_user  = compile_module('X-11.access.change_session_user');
my $xauth_reply  = compile_module('v7-zenki.login-session.xauth_reply');
my $access_reply = compile_module('v7-zenki.login-session.access_reply');
my $end_handler
    = compile_module('v7-zenki.zenka.end-handler.login-screen-session');
$code{'v7-zenki.login-session.zenki'}
    = compile_module('v7-zenki.login-session.zenki');
$data{'v7-zenki'}{'cfg'}{'login_session_zenki'}
    = 'compton protocol-7-menu bad;name';

my @pw = getpwuid($UID);
@pw = getpwnam('nobody') if not @pw or $pw[2] < 1000;
die 'no unprivileged fixture account' if not @pw;
my $session_user = $pw[0];

my $tmp         = tempdir( CLEANUP => 1 );
my $runtime_dir = File::Spec->catdir( $tmp, 'X-11' );
mkdir( $runtime_dir, 0750 ) or die 'cannot create fixture runtime dir';
$data{'system'}{'zenka-user'}{'current'}        = $session_user;
$data{'system'}{'zenka'}{'name'}                = 'X-11';
$data{'system'}{'path'}{'zenka-dirs'}{'var_P7'} = $tmp;
$code{'base.prng.bytes'}                        = sub { "\x42" x 16 };
$code{'base.X-11.write_xauth_file'}             = $write_xauth;

ok( $UID != 0 && ( ( CORE::stat($runtime_dir) )[2] & 0777 ) == 0750,
    'fixture runs non-root with the live 0750 directory layout'
);
my $server = { 'display' => ':13', 'mode' => 'xorg' };
ok( $prepare->($server), 'xorg authority preparation succeeds' );
ok( defined $server->{'xauth'}
        && length( $server->{'xauth'}->{'data'} ) == 16,
    'server retains a 128-bit cookie'
);
my $xauth_path = $server->{'xauth'}->{'path'} // '';
ok( -f $xauth_path && ( ( CORE::stat($xauth_path) )[2] & 0777 ) == 0600,
    'xorg authority file is private' );
ok( -f $xauth_path && ( CORE::stat($xauth_path) )[4] == $pw[2],
    'authority file belongs to the X-11 user' );
ok( $prepare->($server),
    'existing authority replacement works with File::stat loaded' );

$data{'X-11'}{'obj'} = {
    'authorization_protocol_name' => 'MIT-MAGIC-COOKIE-1',
    'authorization_protocol_data' => $server->{'xauth'}->{'data'},
};
my $xauth_result = $get_xauth->();
ok( $xauth_result->{'mode'} eq 'true'
        && $xauth_result->{'data'} eq 'MIT-MAGIC-COOKIE-1 = '
        . unpack( 'H*', $server->{'xauth'}->{'data'} ),
    'get_xauth_data returns the xorg cookie'
);
ok( !$prepare->( { 'display' => ':7', 'mode' => 'xvfb' } ),
    'non-xorg modes do not get authority setup'
);

{

    package LoginScreenAccessTest::X;
    sub new { return bless { 'calls' => [], 'hosts' => {} }, shift }

    sub ChangeHosts {
        my ( $self, $operation, $family, $address ) = @ARG;
        push $self->{'calls'}->@*,
            [ 'ChangeHosts', $operation, $family, $address ];
        $self->{'hosts'}->{$address} = 1    if $operation eq 'Insert';
        delete $self->{'hosts'}->{$address} if $operation eq 'Delete';
        return 5;
    }

    sub ListHosts {
        my ($self) = @ARG;
        push $self->{'calls'}->@*, ['ListHosts'];
        return ( 'Enabled',
            map { [ 'ServerInterpreted', $ARG ] }
            sort keys $self->{'hosts'}->%* );
    }
}

my $x = LoginScreenAccessTest::X->new;
$data{'X-11'}{'mode'}                           = 'xorg';
$data{'X-11'}{'primary_display'}                = ':13';
$data{'X-11'}{'display'}{'xorg'}                = ':13';
$data{'X-11'}{'servers'}{':13'}{'access_ready'} = FALSE;
$data{'X-11'}{'obj'}                            = $x;
$data{'session'}{9}                             = { 'mode' => 'client' };
my $caller = 'v7-zenki';    ## cube prepends the source zenka [ alias ] ##
$code{'base.session.user'} = sub { return $caller };

my $result = $get_display->();
ok( $result->{'mode'} eq 'false',
    'xorg display is withheld until access setup completes' );
$data{'X-11'}{'servers'}{':13'}{'access_ready'} = TRUE;
$result = $get_display->();
ok( $result->{'mode'} eq 'true' && $result->{'data'} eq ':13',
    'ready xorg display is returned normally' );

$result = $change_user->( 'Insert', { 'args' => "$caller $session_user" } );
ok( $result->{'mode'} eq 'true', 'v7 can grant a session user' );
ok( $x->{'calls'}->[0]->[1] eq 'Insert'
        && $x->{'calls'}->[0]->[2] eq 'ServerInterpreted'
        && $x->{'calls'}->[0]->[3] eq "localuser\0$session_user",
    'grant inserts the exact SI localuser entry'
);
$result = $change_user->( 'Delete', { 'args' => "$caller $session_user" } );
ok( $result->{'mode'} eq 'true' && $x->{'calls'}->[2]->[1] eq 'Delete',
    'v7 can revoke the same user' );
{
    my $calls = scalar $x->{'calls'}->@*;
    local $data{'X-11'}{'servers'}{':13'}{'xauth'}{'user'} = 'x11own';
    my $kept = $change_user->( 'Delete', { 'args' => 'v7-zenki x11own' } );
    ok( $kept->{'mode'} eq 'true' && scalar( $x->{'calls'}->@* ) == $calls,
        'a session revoke never removes the X-11 user itself'
    );
}

my $before = scalar $x->{'calls'}->@*;
$caller = 'login-screen';
$result = $change_user->( 'Insert', { 'args' => "$caller $session_user" } );
ok( $result->{'mode'} eq 'false' && scalar( $x->{'calls'}->@* ) == $before,
    'login-screen cannot grant itself SI access' );
$result = $change_user->(
    'Insert', { 'args' => "unix-taeki v7-zenki $session_user" }
);
ok( $result->{'mode'} eq 'false' && scalar( $x->{'calls'}->@* ) == $before,
    'a direct caller cannot pose as v7-zenki behind the cube prefix'
);
$caller               = 'v7-zenki';
$data{'X-11'}{'mode'} = 'xvfb';
$result = $change_user->( 'Insert', { 'args' => "$caller $session_user" } );
ok( $result->{'mode'} eq 'false' && scalar( $x->{'calls'}->@* ) == $before,
    'session grants are refused outside xorg mode' );
$data{'X-11'}{'mode'} = 'xorg';

my @sent;
my @replies;
my $starts = 0;
$code{'base.X-11.write_xauth_file'} = sub { return TRUE };
$code{'base.callback.cmd_reply'} = sub { push @replies, [@ARG]; return TRUE };
$code{'base.reply.mode_text'}    = sub { return ( 'false', 'stub refusal' ) };
$code{'base.logs'} //= sub { return TRUE };
$code{'protocol-7.route-send'} = sub { push @sent, $ARG[0]; return TRUE };
my @desktop_starts;
my @terminated;
$code{'zenka.cmd.start_once'} = sub {
    my $args = $ARG[0]->{'args'} // '';
    ## the session start waits, desktop zenki do not ##
    if ( $args !~ m|^:wait-up: | ) {
        push @desktop_starts, $args;
        return TRUE;
    }
    $starts++;
    return { 'mode' => 'deferred' };
};
$code{'zenka.cmd.terminate'} = sub {
    push @terminated, $ARG[0]->{'args'} // '';
    return TRUE;
};

sub pending_session {
    $data{'v7-zenki'}{'login-session'}{'pending'}{77} = {
        'request' => { 'reply_id' => 5 },
        'user'    => $session_user,
        'uid'     => $pw[2],
        'gid'     => $pw[3],
        'display' => ':13',
    };
}

pending_session();
$xauth_reply->(
    {   'params'    => { 'cube_sid' => 77 },
        'cmd'       => 'TRUE',
        'call_args' => { 'args' => 'MIT-MAGIC-COOKIE-1 = aabb' },
    }
);
ok( $sent[-1]->{'command'} eq 'X-11.grant_session_user' && $starts == 0,
    'xauth handoff requests SI grant before any session start'
);
$access_reply->( { 'params' => { 'cube_sid' => 77 }, 'cmd' => 'TRUE' } );
ok( $starts == 1, 'successful grant starts the session' );
ok( "@desktop_starts" eq 'compton protocol-7-menu',
    'admission starts the configured zenki in order [ bad name dropped ]' );
ok( !grep( { $_->{'command'} eq 'X-11.revoke_session_user' } @sent ),
    'deferred running session keeps its grant' );

pending_session();
@sent = ();
$access_reply->( { 'params' => { 'cube_sid' => 77 }, 'cmd' => 'FALSE' } );
ok( $starts == 1
        && $sent[0]->{'command'} eq 'X-11.revoke_session_user'
        && $replies[-1]->[1]->{'mode'} eq 'false',
    'failed grant revokes and fails admission without a start'
);

pending_session();
@sent = ();
$code{'zenka.cmd.start_once'}
    = sub { $starts++; return { 'mode' => 'false', 'data' => 'no' } };
$access_reply->( { 'params' => { 'cube_sid' => 77 }, 'cmd' => 'TRUE' } );
ok( $sent[0]->{'command'} eq 'X-11.revoke_session_user'
        && $replies[-1]->[1]->{'mode'} eq 'false',
    'immediate session start failure revokes the grant'
);

@sent = ();
$data{'v7-zenki'}{'zenka'}{'instance'}{4} = {
    'zenka_name' => 'login-screen-session',
    'status'     => 'running',
    'subname'    => $session_user,
};
$code{'v7-zenki.instance_ids'}
    = sub { return keys $data{'v7-zenki'}{'zenka'}{'instance'}->%* };
my $set_locked = compile_module('v7-zenki.zenka.cmd.login-session-locked');
my $get_state  = compile_module('v7-zenki.zenka.cmd.login-session-state');
$call = { 'args' => 'login-screen yes' };
my $lock_result = $set_locked->();
ok( $lock_result->{'mode'} eq 'true'
        && $data{'v7-zenki'}{'login-session'}{'locked'} eq $session_user,
    'login-screen records a held lock for the active session user'
);
$call = { 'args' => 'login-screen' };
my $state_result = $get_state->();
ok( $state_result->{'data'} eq "locked $session_user",
    'startup state query reports the locked session user'
);
$call        = { 'args' => 'unix-taeki yes' };
$lock_result = $set_locked->();
ok( $lock_result->{'mode'} eq 'false'
        && $data{'v7-zenki'}{'login-session'}{'locked'} eq $session_user,
    'another cube caller cannot change the lock state'
);
$call         = { 'args' => 'login-screen no' };
$lock_result  = $set_locked->();
$call         = { 'args' => 'login-screen' };
$state_result = $get_state->();
ok( $lock_result->{'mode'} eq 'true'
        && !defined $data{'v7-zenki'}{'login-session'}{'locked'}
        && $state_result->{'data'} eq "active $session_user",
    'unlock clears the recorded state and restores active'
);
$call = { 'args' => 'login-screen yes' };
$set_locked->();
$end_handler->(4);
ok( !defined $data{'v7-zenki'}{'login-session'}{'locked'},
    'session end clears a stale lock record' );
ok( $sent[0]->{'command'} eq 'X-11.revoke_session_user'
        && $sent[1]->{'command'} eq 'login-screen.session-ended',
    'session end revokes access before restoring the greeter'
);
ok( "@terminated" eq 'protocol-7-menu compton',
    'session end terminates them in reverse'
);

say '';
say sprintf ':: %d checks, %d failed', $checks, $failed;
exit( $failed ? 1 : 0 );

#,,,,,..,,.,,,.,,,.,.,.,,,.,,,...,.,.,...,.,,,..,,...,...,.,.,,,,,.,.,,,,,...,
#GE6DGZPJ7I7T7NIFACGG76Z32THOGOLPT3MB2GLC53ITZYOYIX3UAWL7UE7JOMULZEZXNOGLOOEUC
#\\\|GO527PBDZCIWOBTTJLRIF7YOEOYXXDP547YNMXNNVNNPR4QNSGK \ / AMOS7 \ YOURUM ::
#\[7]VCDRAUELJ2AIVN36AQGLG55JYTFIUCDIVM5Z756MOYY26H3JHABA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
