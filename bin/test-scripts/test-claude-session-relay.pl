#!/usr/bin/env perl
use v5.32;
use strict;
use English;
use warnings;

## chat relay stage 2 : the live claude code session through its inbox     ##
## socket. a FAKE inbox socket                                             ##
## [ a unix socket server in this test that records what it receives ] and ##
## a FAKE cube : the real src/claude.live.* \ claude.cmd.session* modules, ##
## the real bin/mcp-server-p7 registration and the real bin/chat choosing  ##
## live vs zenka. never the real session socket : the inbox env of this    ##
## process is cleared first                                                ##

use File::Spec;
use File::Temp qw| tempdir |;
use File::Path qw| make_path |;
use File::Copy qw| copy |;
use File::Find ();
use Cwd        qw| abs_path |;
use FindBin    qw| $RealBin |;
use IO::Socket::UNIX;
use IO::Select;
use IPC::Open3 ();
use Symbol     qw| gensym |;
use Socket     qw| SOCK_STREAM |;

my $root;

BEGIN {
    $root
        = abs_path(
        File::Spec->catdir( $RealBin, File::Spec->updir, File::Spec->updir )
        );
    unshift @INC, "$root/data/lib-path/pm";
}
use JSON::XS ();

use constant TRUE  => 5;
use constant FALSE => 0;

delete @ENV{qw| CLAUDE_CODE_MESSAGING_SOCKET CLAUDE_CODE_MESSAGING_TOKEN |};

our %data;
our %code;
our $call;

my ( $pass, $fail ) = ( 0, 0 );

sub ok ($$) {
    my ( $cond, $name ) = @ARG;
    if   ($cond) { $pass++; say "ok   - $name" }
    else         { $fail++; say "FAIL - $name" }
    return $cond;
}

sub slurp {
    my $path = shift;
    return '' if not -f $path;
    open my $fh, '<:raw', $path or die "$path : $OS_ERROR";
    local $INPUT_RECORD_SEPARATOR = undef;
    my $text = <$fh> // '';
    close $fh;
    return $text;
}

## module loading : the same <..> translation the zenka loader does ##

sub translate_code {
    my $code = shift;
    $code =~ s|<\[(\$[A-Za-z]\w*)\]>(?=\s*->)|"\$code{$1}"|eg;
    $code =~ s|<\[(\$[A-Za-z]\w*)\]>|"\$code{$1}->()"|eg;
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
    my $src  = slurp("$root/src/$name");
    utf8::decode($src);
    my @seg = split m{('(?:[^'\\]|\\.)*'|"(?:[^"\\]|\\.)*"|\#[^\n]*)}x,
        $src, -1;
    for ( my $i = 0; $i < @seg; $i += 2 ) {
        $seg[$i] = translate_code( $seg[$i] );
    }
    my $sub = eval 'sub { ' . join( '', @seg ) . ' }';
    die "compile error $name : $EVAL_ERROR" if $EVAL_ERROR;
    $code{$name} = $sub;
}

my $tmp = tempdir(
    'claude-session-relay-XXXXXX',
    'TMPDIR'  => 1,
    'CLEANUP' => 1
);
my $var_dir = "$tmp/var";
make_path($var_dir);

my @log;
$code{'base.log'}                 = sub { shift; push @log, join ' ', @ARG };
$code{'file.zenka_dir.data_path'} = sub {$var_dir};
my @raised;    ## what goes to the cube : the registration signal ##
$code{'protocol-7.command.send.local'} = sub {
    push @raised, "$_[0]{'command'} $_[0]{'call_args'}{'args'}";
    return TRUE;
};
$code{'claude.event.add'} = sub {TRUE};
load_module($ARG) foreach qw|
    claude.signal.raise
    claude.wire.encode claude.live.sessions claude.live.wire claude.live.post
    claude.cmd.session-register claude.cmd.session-unregister
    claude.cmd.session-post claude.cmd.sessions
    |;
## the events buffer of the zenka : readable lines [ claude.status \ tail ] ##
$data{'claude'}{'events'} = [];

my $cmd = sub {
    my ( $name, $args, $param, $body ) = @ARG;
    local $call = { 'args' => $args, 'param' => $param, 'data' => $body };
    return $code{"claude.cmd.$name"}->();
};

## the fake inbox socket : listens, records every connection's bytes ##
sub fake_inbox {
    my $path = shift;
    unlink $path;
    return IO::Socket::UNIX->new(
        'Type'   => SOCK_STREAM,
        'Local'  => $path,
        'Listen' => 5
    ) // die "fake inbox $path : $OS_ERROR";
}

sub inbox_read {
    my $server = shift;
    return undef if not IO::Select->new($server)->can_read(2);
    my $conn = $server->accept // return undef;
    my $got  = '';
    while ( IO::Select->new($conn)->can_read(2) ) {
        my $n = sysread( $conn, my $chunk, 65536 );
        last if not $n;
        $got .= $chunk;
    }
    close $conn;
    return $got;
}

my $token  = 'TOKEN-' . join '', map { ( 'A' .. 'Z' )[ rand 26 ] } 1 .. 24;
my $sock_a = "$tmp/inbox-a.sock";
my $inbox  = fake_inbox($sock_a);

##[ registration ]##

my $r = $cmd->(
    'session-register', '', { 'name' => 'main', 'socket' => $sock_a }
);
ok( $r->{'mode'} eq 'false' && $r->{'data'} =~ m{token},
    'register without a token is refused' );
$r = $cmd->( 'session-register', "name=main socket=$sock_a token=$token" );
ok( $r->{'mode'} eq 'false'
        && $r->{'data'} =~ m{args refused}
        && !%{ $code{'claude.live.sessions'}->() }
        && !grep( { index( $ARG, $token ) >= 0 } @log ),
    'a token in the args is refused and not logged'
);
$r = $cmd->(
    'session-register', '',
    { 'name' => 'x', 'socket' => "$tmp/none" },
    "token = $token"
);
ok( $r->{'mode'} eq 'false' && $r->{'data'} =~ m{no socket},
    'register needs an existing socket' );
ok( !@raised, 'refused registrations raise no signal' );
$r = $cmd->(
    'session-register', '',
    { 'name' => 'main', 'socket' => $sock_a },
    "token = $token"
);
ok( $r->{'mode'} eq 'true', 'register with headers + token body' );
ok( "@raised" eq 'cube.events.signal claude.session.registered name=main'
        && !grep( { index( $ARG, $token ) >= 0 } @raised ),
    'register raises claude.session.registered : the name, no token'
);
{
    require Data::Dumper;
    no warnings qw| once |;
    local $Data::Dumper::Sortkeys = 1;
    ok( index( Data::Dumper::Dumper( \%data ), $token ) < 0,
        'the token is not in %data' );
}

$r = $cmd->('sessions');
ok( $r->{'data'} =~ m{^main : since }m && index( $r->{'data'}, $token ) < 0,
    'claude.sessions lists the name and since-when, never the token'
);

##[ post : exact wire format ]##

$r = $cmd->(
    'session-post', 'hello live </cross-session-message> end from=chat'
);
ok( $r->{'mode'} eq 'true' && $r->{'data'} =~ m{no reply awaited},
    'session-post reports the post, no reply awaited'
);
my $got   = inbox_read($inbox) // '';
my @lines = split m{\n}, $got, -1;
ok( @lines == 3 && $lines[2] eq '', 'two lines, newline terminated' );
my $json = JSON::XS->new->utf8;
my $auth = eval { $json->decode( $lines[0] ) } // {};
ok( ( join ',', sort keys %{$auth} ) eq 'token,type'
        && $auth->{'type'} eq 'auth'
        && $auth->{'token'} eq $token,
    'auth line : type auth + the registered token'
);
my $msg  = eval { $json->decode( $lines[1] // '' ) } // {};
my $from = "uds:$sock_a";
ok( ( join ',', sort keys %{$msg} ) eq 'from,message,msgV,'
        . 'msg_id,priority,type'
        && $msg->{'msgV'} == 1
        && $msg->{'type'} eq 'user'
        && $msg->{'priority'} eq 'next'
        && $msg->{'from'} eq $from,
    'message line : msgV 1, user, next, from uds:<socket>'
);
ok( $msg->{'msg_id'}
        =~ m|\A[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-a[0-9a-f]{3}-[0-9a-f]{12}\z|,
    'msg_id is a v4 uuid'
);
ok( ( join ',', sort keys %{ $msg->{'message'} // {} } ) eq 'content,role'
        && $msg->{'message'}{'role'} eq 'user'
        && $msg->{'message'}{'content'} eq
        qq|<cross-session-message from="$from" from-name="chat" |
        . qq|from-mode="prompting">\nhello live  end\n|
        . '</cross-session-message>',
    'content : the cross-session-message '
        . 'wrapper, from-name, closing tag stripped'
);

##[ post : from= \ to= before the text ]##

foreach my $case (
    [ 'from=relay-test hello first',        'relay-test', 'hello first' ],
    [ 'to=main from=lead hello both',       'lead',       'hello both' ],
    [ 'from=lead hello mixed to=main',      'lead',       'hello mixed' ],
    [ 'from=first hello twice from=second', 'first',      'hello twice' ],
) {
    my ( $args, $name, $text ) = @{$case};
    $r = $cmd->( 'session-post', $args );
    my $sent = eval {
        $json->decode( ( split m{\n}, inbox_read($inbox) // '' )[1] // '' );
    } // {};
    ok( $r->{'mode'} eq 'true'
            && ( $sent->{'message'}{'content'} // '' )
            =~ m{from-name="\Q$name\E" [^\n]*\n\Q$text\E\n</cross},
        "session-post '$args' : from-name $name"
    );
}
$r = $cmd->( 'session-post', 'to=nobody hello' );
ok( $r->{'mode'} eq 'false' && $r->{'data'} =~ m{no live session 'nobody'},
    'a leading to= selects the session' );
$r = $cmd->( 'session-post', 'from=lead' );
ok( $r->{'mode'} eq 'false' && $r->{'data'} eq 'text expected',
    'from= without a text : text expected' );

##[ token never in output or files ]##

my @files;
File::Find::find( sub { push @files, $File::Find::name if -f }, $var_dir );
ok( !grep( { index( slurp($ARG), $token ) >= 0 } @files ),
    'the token is in no file of the zenka var dir'
);
ok( !grep( { index( $ARG, $token ) >= 0 } @log,
        @{ $data{'claude'}{'events'} } ),
    'the token is in no log line and no event line'
);

##[ unregister, vanished socket, failed connect ]##

$r = $cmd->( 'session-unregister', 'name=main' );
ok( $r->{'mode'} eq 'true' && !%{ $code{'claude.live.sessions'}->() },
    'unregister drops the session' );
$r = $cmd->( 'session-post', 'nobody there' );
ok( $r->{'mode'} eq 'false' && $r->{'data'} =~ m{no live session},
    'post without a session fails' );

$cmd->(
    'session-register', '',
    { 'name' => 'main', 'socket' => $sock_a },
    "token = $token"
);
close $inbox;
unlink $sock_a;
$r = $cmd->('sessions');
ok( $r->{'data'} =~ m{no live session}
        && !%{ $code{'claude.live.sessions'}->() },
    'claude.sessions drops a session whose socket path is gone'
);
$code{'claude.live.sessions'}->()->{'main'}
    = { 'socket' => $sock_a, 'token' => $token, 'since' => time };
$r = $cmd->( 'session-post', 'into the void' );
ok( $r->{'mode'} eq 'false'
        && $r->{'data'} =~ m{socket gone}
        && !%{ $code{'claude.live.sessions'}->() },
    'a vanished socket path drops the session and its token'
);

my $sock_b = "$tmp/inbox-b.sock";
my $dead   = fake_inbox($sock_b);
$cmd->(
    'session-register', '',
    { 'name' => 'b', 'socket' => $sock_b },
    "token = $token"
);
close $dead;    ## the path stays, nobody listens ##
$r = $cmd->( 'session-post', 'refused' );
ok( $r->{'mode'} eq 'false'
        && $r->{'data'} =~ m{connect failed}
        && !%{ $code{'claude.live.sessions'}->() },
    'a failed connect drops the session'
);
unlink $sock_b;

##[ several sessions : never picked by age ; the signal on news only ]##
my ( $sock_1, $sock_2 ) = ( "$tmp/inbox-1.sock", "$tmp/inbox-2.sock" );
my ( $in_1, $in_2 ) = ( fake_inbox($sock_1), fake_inbox($sock_2) );
my $register = sub {
    my ( $name, $socket ) = @ARG;
    return $cmd->(
        'session-register', '',
        { 'name' => $name, 'socket' => $socket },
        "token = $token"
    );
};
@raised = ();
$register->( 'owner', $sock_1 );
$register->( 'owner', $sock_1 );
ok( @raised == 1, 're-register of the same socket raises no signal' );
$register->( 'owner', $sock_2 );
$register->( 'owner', $sock_1 );
ok( @raised == 3, 'a changed socket raises it again' );
$register->( 'run', $sock_2 );
$code{'claude.live.sessions'}->()->{'run'}{'since'} = time + 13;
$r = $cmd->( 'session-post', 'which one' );
ok( $r->{'mode'} eq 'false'
        && $r->{'data'} =~ m{several live sessions \[ owner, run \]}
        && !IO::Select->new( $in_1, $in_2 )->can_read(0),
    'several sessions without to= : refused with the names, nothing sent'
);
$r = $cmd->( 'session-post', 'to=owner for the owner' );
ok( $r->{'mode'} eq 'true' && ( inbox_read($in_1) // '' ) =~ m{for the owner},
    'to= selects among several'
);
close $in_2;
unlink $sock_2;
$r = $cmd->( 'session-post', 'only one left' );
ok( $r->{'mode'} eq 'true'
        && ( inbox_read($in_1) // '' ) =~ m{only one left}
        && !exists $code{'claude.live.sessions'}->()->{'run'},
    'a session with a gone socket does not count : the one left is used'
);
close $in_1;
unlink $sock_1;
%{ $code{'claude.live.sessions'}->() } = ();

##[ mcp server : registers with a fake cube, unregisters on exit ]##

sub fake_cube_run {
    my ( $cube_path, $record, %env ) = @ARG;
    unlink $cube_path;
    my $cube = IO::Socket::UNIX->new(
        'Type'   => SOCK_STREAM,
        'Local'  => $cube_path,
        'Listen' => 5
    ) // die "fake cube : $OS_ERROR";
    my $pid = fork // die "fork : $OS_ERROR";
    if ( not $pid ) {
        my $dropped = 0;
        open my $rec, '>>:raw', $record or die $OS_ERROR;
        $rec->autoflush(1);
        while ( IO::Select->new($cube)->can_read(13) ) {
            my $c = $cube->accept // next;
            $c->autoflush(1);
            print {$c} "\\\\PROTOCOL-7-VERSION\\\\ fake\n";
            while ( defined( my $line = <$c> ) ) {
                print {$rec} $line;
                if    ( $line =~ m{\Aselect unix} ) { print {$c} "TRUE ok\n" }
                elsif ( $line =~ m{\Aauth } ) { print {$c} "AUTH_TRUE ok\n" }
                elsif ( $line =~ m{\Aclose} ) {last}
                elsif ( $line =~ m{\+\n\z} ) {
                    while ( defined( my $more = <$c> ) ) {
                        print {$rec} $more;
                        last if $more eq ".\n";
                    }
                    print {$c} "TRUE registered\n";
                    ## a cube restart : the link drops once ##
                    if ( $env{'FAKE_CUBE_DROP'} and not $dropped++ ) {
                        select( undef, undef, undef, 0.3 );
                        last if not $env{'FAKE_CUBE_DOWN'};
                        ## gone for a while : connects fail ##
                        close $c;
                        close $cube;
                        unlink $cube_path;
                        sleep $env{'FAKE_CUBE_DOWN'};
                        $cube = IO::Socket::UNIX->new(
                            'Type'   => SOCK_STREAM,
                            'Local'  => $cube_path,
                            'Listen' => 5
                        ) // die "fake cube : $OS_ERROR";
                        last;
                    }
                } else {
                    print {$c} "TRUE done\n";
                }
            }
            close $c;
        }
        exit 0;
    }
    close $cube;

    local %ENV = (
        %ENV, %env,
        'PROTOCOL_7_UNIX_PATH' => $cube_path,
        'HOME'                 => "$tmp/home"
    );
    make_path("$tmp/home");
    my $err = gensym;
    my $mcp = IPC::Open3::open3( my $in, my $out, $err, $EXECUTABLE_NAME,
        qw| -C31 |, "$root/bin/mcp-server-p7" );
    sleep 2 + ( $env{'FAKE_RUN_EXTRA'} // 0 );
    if ( $env{'FAKE_STDIN'} ) {
        syswrite( $in, "$env{'FAKE_STDIN'}\n" );
        sleep 2;
    }
    close $in;    ## stdin eof : the server ends ##
    my $stderr = do { local $INPUT_RECORD_SEPARATOR = undef; <$err> // '' };
    waitpid $mcp, 0;
    kill 'TERM', $pid;
    waitpid $pid, 0;
    return $stderr;
}

my $sock_c  = "$tmp/inbox-c.sock";
my $inbox_c = fake_inbox($sock_c);
my $record  = "$tmp/cube-record";
my $stderr  = fake_cube_run(
    "$tmp/cube.sock", $record,
    'CLAUDE_CODE_MESSAGING_SOCKET' => $sock_c,
    'CLAUDE_CODE_MESSAGING_TOKEN'  => $token,
    'P7_SESSION_NAME'              => 'test-session',
);
my $seen = slurp($record);
ok( $seen        =~ m{^claude\.session-register\+\n}m
        && $seen =~ m{^\s*name : test-session$}m
        && $seen =~ m{^\s*socket : \Q$sock_c\E$}m
        && $seen =~ m{^token = \Q$token\E$}m,
    'mcp server registers name + socket headers, the token in the body'
);
ok( $seen =~ m{^claude\.session-unregister name=test-session$}m,
    'mcp server unregisters on exit' );
ok( index( $stderr, $token ) < 0, 'the token is not in the mcp server log' );
close $inbox_c;
unlink $sock_c;

## the cube link drops after the registration : the next call reconnects ##
## and the session registers again                                       ##
my $record_r = "$tmp/cube-record-reconnect";
$inbox_c = fake_inbox($sock_c);
fake_cube_run(
    "$tmp/cube-r.sock", $record_r,
    'CLAUDE_CODE_MESSAGING_SOCKET' => $sock_c,
    'CLAUDE_CODE_MESSAGING_TOKEN'  => $token,
    'P7_SESSION_NAME'              => 'test-session',
    'FAKE_CUBE_DROP'               => 1,
    'FAKE_STDIN' => '{"jsonrpc":"2.0","id":1,"method":"tools/call",'
        . '"params":{"name":"p7_command","arguments":{"command":"list '
        . 'users"}}}',
);
my $registers = () = slurp($record_r) =~ m{^claude\.session-register\+$}mg;
ok( $registers == 2 && slurp($record_r) =~ m{^list users$}m,
    'mcp server registers again after a cube reconnect'
);
close $inbox_c;
unlink $sock_c;

## no tool call : the dropped link is seen at once, no 13 min wait ##
sub idle_drop_run {
    my ( $label, %env ) = @ARG;
    my $rec    = "$tmp/cube-record-$label";
    my $server = fake_inbox($sock_c);
    my $log    = fake_cube_run(
        "$tmp/cube-$label.sock", $rec,
        'CLAUDE_CODE_MESSAGING_SOCKET' => $sock_c,
        'CLAUDE_CODE_MESSAGING_TOKEN'  => $token,
        'P7_SESSION_NAME'              => 'test-session',
        'FAKE_CUBE_DROP'               => 1,
        %env
    );
    close $server;
    unlink $sock_c;
    my $count = () = slurp($rec) =~ m{^claude\.session-register\+$}mg;
    return ( $count, $log );
}
my ( $idle_count, $idle_log ) = idle_drop_run('idle');
ok( $idle_count == 2 && $idle_log =~ m{cube link broken},
    'mcp server registers again at once when the cube link breaks [ idle ]' );
( $idle_count, $idle_log )
    = idle_drop_run( 'down', 'FAKE_CUBE_DOWN' => 4, 'FAKE_RUN_EXTRA' => 13 );
ok( $idle_count == 2 && $idle_log =~ m{register : not connected},
    'cube still down at the first try : short retries until it is back'
);

## coding.remind through p7_command : this server's session is named ##
sub remind_run {
    my ( $label, $command, %env ) = @ARG;
    my $rec    = "$tmp/cube-record-$label";
    my $server = fake_inbox($sock_c);
    fake_cube_run( "$tmp/cube-$label.sock", $rec, %env,
              'FAKE_STDIN' => '{"jsonrpc":"2.0","id":1,"method":"tools/call",'
            . '"params":{"name":"p7_command",'
            . '"arguments":{"command":"'
            . $command
            . '"}}}' );
    close $server;
    unlink $sock_c;
    return slurp($rec);
}
my %live_env = (
    'CLAUDE_CODE_MESSAGING_SOCKET' => $sock_c,
    'CLAUDE_CODE_MESSAGING_TOKEN'  => $token,
    'P7_SESSION_NAME'              => 'test-session',
);
ok( remind_run( 'rm1', 'coding.remind after=x look', %live_env )
        =~ m{^coding\.remind to=session:test-session after=x look$}m,
    'mcp server : coding.remind without to= names its own session'
);
ok( remind_run( 'rm2', 'coding.remind after=x to=session look', %live_env )
        =~ m{^coding\.remind after=x to=session:test-session look$}m,
    'mcp server : to=session becomes its own session'
);
ok( remind_run( 'rm3', 'coding.remind after=x to=panel look', %live_env )
        =~ m{^coding\.remind after=x to=panel look$}m,
    'mcp server : another target stays'
);
ok( remind_run( 'rm4', 'coding.remind after=x look' )
        =~ m{^coding\.remind after=x look$}m,
    'mcp server unregistered : the reminder goes as it is'
);

my $record_k = "$tmp/cube-record-kimi";
fake_cube_run( "$tmp/cube-k.sock", $record_k );
ok( slurp($record_k) !~ m{claude\.session-},
    'no env [ kimi ] : no registration'
);

##[ bin/chat -m claude : live vs zenka ]##

my $fake_root = "$tmp/root";
make_path( "$fake_root/bin", "$fake_root/data", "$tmp/bin" );
copy( "$root/bin/chat", "$fake_root/bin/chat" ) or die $OS_ERROR;
chmod 0700, "$fake_root/bin/chat";
symlink( "$root/data/lib-path", "$fake_root/data/lib-path" ) or die $OS_ERROR;
open my $fake_fh, '>', "$tmp/bin/p7c" or die $OS_ERROR;
print {$fake_fh} <<'FAKE';
#!/usr/bin/env perl
use strict;
use warnings;
my $dir     = $ENV{'FAKE_P7C_DIR'};
my $command = shift @ARGV // '';
open my $log, '>>', "$dir/calls" or die $!;
print {$log} "$command\t@ARGV\n";
close $log;
if ( $command eq 'claude.sessions' ) {
    print -f "$dir/live" ? "main : since Tue Nov 24 12:00:00 2026\n"
        : "no live session registered\n";
    print "run : since Tue Nov 24 12:13:00 2026\n" if -f "$dir/live2";
} elsif ( $command eq 'claude.session-post' ) {
    print "posted into live session main [ no reply awaited ]\n";
} elsif ( $command eq 'claude.send' ) {
    print "turn sent\n";
} elsif ( $command eq 'claude.tail' ) {
    if ( -f "$dir/sent" ) {
        print "12:00:00 text : zenka reply\n12:00:00 final : success : done\n";
    }
    open my $m, '>', "$dir/sent" or die $!;
    close $m;
} else {
    print ": error : unexpected $command\n";
    exit 2;
}
FAKE
close $fake_fh;
chmod 0700, "$tmp/bin/p7c";

sub run_chat {
    local %ENV = %ENV;
    $ENV{'PATH'}           = "$tmp/bin:$ENV{'PATH'}";
    $ENV{'HOME'}           = "$tmp/home";
    $ENV{'P7_CHAT_CALLER'} = 'user';
    $ENV{'FAKE_P7C_DIR'}   = $tmp;
    my $err = gensym;
    my $pid = IPC::Open3::open3( undef, my $out, $err, $EXECUTABLE_NAME,
        "$fake_root/bin/chat", @ARG );
    my $text = do { local $INPUT_RECORD_SEPARATOR = undef; <$out> // '' };
    waitpid $pid, 0;
    return $text;
}
my $history = "$fake_root/data/development/chat/channel/main/history";

open my $live, '>', "$tmp/live" or die $OS_ERROR;
close $live;
run_chat( '-q', '-m', 'claude', 'hello live session' );
my $calls = slurp("$tmp/calls");
ok( $calls =~ m{^claude\.session-post\thello live session from=chat$}m
        && $calls !~ m{^claude\.send\t}m,
    'chat -m claude posts into the registered live session'
);
ok( slurp($history) =~ m{<claude>\s+\[live\] [^\n]*no reply awaited},
    'the history line names the live path, no reply awaited'
);

unlink "$tmp/live";
run_chat( '-q', '-m', 'claude', 'hello zenka' );
$calls = slurp("$tmp/calls");
ok( $calls =~ m{^claude\.send\thello zenka}m,
    'no live session : the claude zenka path'
);
ok( slurp($history) =~ m{<claude>\s+\[zenka\] zenka reply},
    'the history line names the zenka path' );

open $live, '>', "$tmp/live" or die $OS_ERROR;
close $live;
open my $live2, '>', "$tmp/live2" or die $OS_ERROR;
close $live2;
unlink "$tmp/calls", "$tmp/sent";
run_chat( '-q', '-m', 'claude', 'which of the two' );
$calls = slurp("$tmp/calls");
ok( $calls =~ m{^claude\.send\twhich of the two}m
        && $calls !~ m{^claude\.session-post\t}m,
    'chat -m claude, several sessions : the zenka path, no post'
);
ok( slurp($history)
        =~ m{<claude>\s+\[zenka : several live sessions \[ main, run \]},
    'the history line says why'
);
run_chat( '-q', '-to-session', 'main', '-m', 'claude', 'for main' );
ok( slurp("$tmp/calls")
        =~ m{^claude\.session-post\tto=main for main from=chat$}m,
    'chat -to-session names the live session'
);
unlink "$tmp/live2";
run_chat( '-q', '-relay', 'off', 'claude' );
my $posts = () = slurp("$tmp/calls") =~ m{^claude\.session-post\t}mg;
run_chat( '-q', '-m', 'claude', 'held while off' );
my $after = () = slurp("$tmp/calls") =~ m{^claude\.session-post\t}mg;
ok( $after == $posts && slurp($history) =~ m{held while off},
    'relay off : no live post, the message stays in the history'
);

say "\n$pass passed, $fail failed";
exit( $fail ? 1 : 0 );

#,,.,,.,.,.,.,.,.,,..,.,.,,.,,,..,,.,,,,,,.,,,..,,...,...,,.,,,.,,,..,,.,,.,,,
#YWGIREACDBISATJSLA44AD3S6NCUHSRVLM5BJYWNM5XV32AIMB4N7I5KHYZZ7FUCHFUV7MABGTOIO
#\\\|YC5IQI5VCNASX45FBZEFOCY5THSIHCFPBKGICHZ72UPZTQDBRDJ \ / AMOS7 \ YOURUM ::
#\[7]5ER6YYSWS7A7YWHUY6SDN5RZBLAIXVBKIP4BSYEZYYRA6E2RLWDI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
