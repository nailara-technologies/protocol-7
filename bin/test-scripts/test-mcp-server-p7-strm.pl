#!/usr/bin/perl
## test-mcp-server-p7-strm.pl -- fake-cube harness for the STRM drain support
## in bin/mcp-server-p7 [ task : mcp-server-p7-strm-support ]
##
## spins up a scripted fake cube on a temp unix socket, runs the real
## mcp-server-p7 over stdio json-rpc against it, and checks every STRM path :
## bounded + unbounded clean close, (N) prefix in both spacings, STRM-SIZE
## type token, !TRM!, bounded-total mismatch, idle valve, byte-cap valve,
## hardened unknown-reply fall-through, and the multiline call site -- with a
## sentinel command after every teardown to prove the reconnect actually works
## [ the hard invariant ]
##
## usage : perl bin/test-scripts/test-mcp-server-p7-strm.pl

use strict;
use warnings;
use JSON::PP;
use IO::Socket::UNIX;
use IO::Select;
use IPC::Open3;
use File::Temp qw| tempdir |;
use Symbol     qw| gensym |;
use Time::HiRes;

my $json = JSON::PP->new->utf8->canonical;

my $root_path = $ENV{'PROTOCOL_7_ROOT'} // '/data/projects/protocol-7';
my $server_pl = "$root_path/bin/mcp-server-p7";
die "server not found : $server_pl" if not -f $server_pl;

##[ scripted fake-cube replies [ keyed by exact command string ] ]##

my %SCRIPTS = (
    'cmd.true' => ["TRUE works\n"],

    ## bounded : declared total must match summed chunk lens ##
    'cmd.bounded' => [
        "STRM open 11\n",
        "STRM 5\nhello",
        "STRM 6\n world",
        "STRM close\n",
    ],

    ## unbounded clean close ##
    'cmd.unbounded-close' =>
        [ "STRM open\n", "STRM 3\nabc", "STRM close\n", ],

    ## (N) prefix, no trailing space ##
    'cmd.prefixed-a' =>
        [ "(5)STRM open 5\n", "(5)STRM 5\nworld", "(5)STRM close\n", ],

    ## '(NNN) ' override form, WITH trailing space ##
    'cmd.prefixed-b' =>
        [ "(5) STRM open\n", "(5) STRM 2\nhi", "(5) STRM close\n", ],

    ## STRM-SIZE type token ##
    'cmd.strm-size' =>
        [ "STRM-SIZE open 3\n", "STRM-SIZE 3\nxyz", "STRM-SIZE close\n", ],

    ## abnormal termination from a gated upstream relay ##
    'cmd.trm' => [ "STRM open\n", "STRM 4\npart", "(7)!TRM!\n", ],

    ## bounded total mismatch : real failure, not silent return ##
    'cmd.mismatch' => [ "STRM open 10\n", "STRM 5\nshort", "STRM close\n", ],

    ## opens, pushes once, then parks forever [ idle valve target ] ##
    'cmd.never-closes' => [ "STRM open\n", "STRM 5\nhello", '__PARK__', ],

    ## fast runaway producer [ byte-cap valve target, cap = 64 ] ##
    'cmd.bytecap' => [
        "STRM open\n", map { sprintf( "STRM 10\n%s", 'x' x 10 ) } 1 .. 20,
    ],

    ## reply type with trailing frames this client does not handle ##
    'cmd.chrsize' => ["CHRSIZE 5\nabcde"],

    ## multiline call site : clean STRM close ##
    'task.create' => [ "STRM open\n", "STRM 4\nmlrn", "STRM close\n", ],

    ## multiline call site : unknown-reply fall-through ##
    'task.complete' => ["WUNKNOWN huh\n"],
);

##[ fake cube server [ child process ] ]##

sub fake_read_line {
    my $conn = shift;
    my $sel  = IO::Select->new($conn);
    my $line = '';
    while (1) {
        return undef if not $sel->can_read(30);
        my $n = sysread( $conn, my $byte, 1 );
        return undef if not defined $n or $n == 0;
        $line .= $byte;
        last if $byte eq "\n";
    }
    chomp $line;
    return $line;
}

sub fake_write {
    my ( $conn, $data ) = @_;
    my $n = syswrite( $conn, $data, length $data );
    return defined $n && $n == length $data;
}

sub fake_cube_server {
    my $sock_path = shift;
    $SIG{PIPE} = 'IGNORE';
    my $srv = IO::Socket::UNIX->new(
        Type   => SOCK_STREAM,
        Local  => $sock_path,
        Listen => 5,
    ) or die "fake cube listen failed : $!";
    while ( my $conn = $srv->accept ) {
        fake_write( $conn, "\\\\PROTOCOL-7-VERSION\\\\ fake-cube 0.1\n" )
            or next;
        my $sel = fake_read_line($conn);     ## select unix
        fake_write( $conn, "TRUE\n" ) or next;
        my $auth = fake_read_line($conn);    ## auth <user>
        fake_write( $conn, "AUTH_TRUE\n" ) or next;
        while ( defined( my $cmd = fake_read_line($conn) ) ) {
            last if $cmd eq 'close';
            my $is_multiline = $cmd =~ s{\+\z}{};
            if ($is_multiline) {
                ## drain header block then body up to '.' terminator ##
                while ( defined( my $hl = fake_read_line($conn) ) ) {
                    last if $hl eq '';
                }
                while ( defined( my $bl = fake_read_line($conn) ) ) {
                    last if $bl eq '.';
                }
            }
            my $script = $SCRIPTS{$cmd};
            if ( not defined $script ) {
                fake_write( $conn, "FALSE unknown fake command : $cmd\n" )
                    or last;
                next;
            }
            my $ok = 1;
            for my $frame ( @{$script} ) {
                last if $frame eq '__PARK__';    ## silence until teardown
                $ok = fake_write( $conn, $frame ) or last;
            }
            last if not $ok;
        }
        close $conn;
    }
    exit 0;
}

##[ mcp client driver [ stdio json-rpc ] ]##

my ( $tmp_dir, $srv_pid, $srv_wtr, $srv_rdr, $srv_err );
my $req_id = 0;

sub mcp_request {
    my ( $method, $params ) = @_;
    my $id = ++$req_id;
    print {$srv_wtr} $json->encode(
        {   'jsonrpc' => '2.0',
            'id'      => $id,
            'method'  => $method,
            'params'  => $params,
        }
    ) . "\n";
    my $sel = IO::Select->new($srv_rdr);
    while (1) {
        die "timeout waiting for response id=$id [$method]\n"
            if not $sel->can_read(60);
        my $line = <$srv_rdr>;
        die "server closed stdout waiting for id=$id [$method]\n"
            if not defined $line;
        my $msg = eval { $json->decode($line) };
        next if $@ or not defined $msg->{'id'} or $msg->{'id'} != $id;
        return $msg;
    }
}

sub tool_call {
    my ( $name, $args ) = @_;
    my $msg
        = mcp_request( 'tools/call',
        { 'name' => $name, 'arguments' => $args } );
    my $result = $msg->{'result'}                // {};
    my $text   = $result->{'content'}[0]{'text'} // '';
    my $is_err = $result->{'isError'} ? 1 : 0;
    return ( $text, $is_err );
}

##[ tiny tap-style check helpers ]##

my ( $pass, $fail ) = ( 0, 0 );

sub check {
    my ( $name, $ok, $detail ) = @_;
    if ($ok) {
        $pass++;
        printf "ok   %s\n", $name;
    } else {
        $fail++;
        printf "FAIL %s\n     got : %s\n", $name, $detail // '<none>';
    }
    return $ok;
}

##[ main ]##

$tmp_dir = tempdir( 'p7-strm-test-XXXX', TMPDIR => 1, CLEANUP => 1 );
my $sock_path = "$tmp_dir/cube.sock";

$srv_pid = fork();
die "fork failed" if not defined $srv_pid;
if ( $srv_pid == 0 ) {
    fake_cube_server($sock_path);
}

## wait for the fake cube socket to appear ##
for ( 1 .. 50 ) {
    last if -S $sock_path;
    Time::HiRes::sleep(0.1);
}
die "fake cube socket never appeared" if not -S $sock_path;

## spawn the real mcp-server-p7 against the fake cube, with tight valve ##
## bounds so the valve paths are exercisable in test time               ##
local %ENV = %ENV;
$ENV{'PROTOCOL_7_UNIX_PATH'}             = $sock_path;
$ENV{'PROTOCOL_7_MCP_STRM_IDLE_TIMEOUT'} = 3;
$ENV{'PROTOCOL_7_MCP_STRM_MAX_BYTES'}    = 64;

## spawn via the shebang [ #!/usr/bin/env -S perl -C31 ] -- plain 'perl ##
## script' dies with 'Too late for -C31 option'                         ##
my $mcp_pid = open3( $srv_wtr, $srv_rdr, '>&STDERR', $server_pl );
binmode( $srv_wtr, ':raw' );
binmode( $srv_rdr, ':raw' );

eval {
    mcp_request( 'initialize',
        { 'clientInfo' => { 'name' => 'strm-test' } } );

    ## 1 : bounded stream, clean close ##
    my ( $t, $e ) = tool_call( 'p7_command', { 'command' => 'cmd.bounded' } );
    check(
        'bounded strm : full payload, clean close',
        !$e && $t eq 'hello world',
        "err=$e text=$t"
    );

    ## 2 : sentinel on the SAME cached socket proves byte-clean close ##
    ( $t, $e ) = tool_call( 'p7_command', { 'command' => 'cmd.true' } );
    check(
        'sentinel after clean close [ no reconnect needed ]',
        !$e && $t eq 'works',
        "err=$e text=$t"
    );

    ## 3 : unbounded stream, clean close ##
    ( $t, $e )
        = tool_call( 'p7_command', { 'command' => 'cmd.unbounded-close' } );
    check(
        'unbounded strm : clean close',
        !$e && $t eq 'abc',
        "err=$e text=$t"
    );

    ## 4+5 : (N) prefix, both spacings ##
    ( $t, $e ) = tool_call( 'p7_command', { 'command' => 'cmd.prefixed-a' } );
    check(
        'prefixed frames [ (5)STRM ]',
        !$e && $t eq 'world',
        "err=$e text=$t"
    );
    ( $t, $e ) = tool_call( 'p7_command', { 'command' => 'cmd.prefixed-b' } );
    check(
        'prefixed frames [ (5) STRM ]',
        !$e && $t eq 'hi',
        "err=$e text=$t"
    );

    ## 6 : STRM-SIZE type token ##
    ( $t, $e ) = tool_call( 'p7_command', { 'command' => 'cmd.strm-size' } );
    check( 'strm-size type token', !$e && $t eq 'xyz', "err=$e text=$t" );

    ## 7 : !TRM! abnormal termination ##
    ( $t, $e ) = tool_call( 'p7_command', { 'command' => 'cmd.trm' } );
    check(
        '!TRM! : partial payload + marker',
        !$e
            && $t
            =~ m{\Apart\n\[stream terminated abnormally by !TRM!, 4 bytes collected\]\z},
        "err=$e text=$t"
    );

    ## 8 : sentinel proves reconnect after !TRM! teardown ##
    ( $t, $e ) = tool_call( 'p7_command', { 'command' => 'cmd.true' } );
    check(
        'sentinel after !TRM! teardown',
        !$e && $t eq 'works',
        "err=$e text=$t"
    );

    ## 9 : bounded-total mismatch is a real failure ##
    ( $t, $e ) = tool_call( 'p7_command', { 'command' => 'cmd.mismatch' } );
    check(
        'bounded-total mismatch : error',
        $e && $t =~ m{incomplete STRM stream : 5 of 10},
        "err=$e text=$t"
    );

    ## 10 : sentinel proves reconnect after mismatch teardown ##
    ( $t, $e ) = tool_call( 'p7_command', { 'command' => 'cmd.true' } );
    check(
        'sentinel after mismatch teardown',
        !$e && $t eq 'works',
        "err=$e text=$t"
    );

    ## 11 : idle valve on a parked-open stream ##
    my $vstart = Time::HiRes::time();
    ( $t, $e )
        = tool_call( 'p7_command', { 'command' => 'cmd.never-closes' } );
    my $velapsed = Time::HiRes::time() - $vstart;
    check(
        'idle valve : partial payload + marker',
        !$e
            && $t
            =~ m{\Ahello\n\[stream still open, 5 bytes collected, \d+ seconds idle\]\z},
        "err=$e text=$t"
    );
    check(
        'idle valve : tripped near the 3 s bound',
        $velapsed >= 2.5 && $velapsed < 20,
        sprintf '%.1f s', $velapsed
    );

    ## 12 : THE invariant check -- next unrelated call still succeeds ##
    ( $t, $e ) = tool_call( 'p7_command', { 'command' => 'cmd.true' } );
    check(
        'sentinel after idle-valve teardown [ hard invariant ]',
        !$e && $t eq 'works',
        "err=$e text=$t"
    );

    ## 13 : byte-cap valve on a fast runaway producer ##
    ( $t, $e ) = tool_call( 'p7_command', { 'command' => 'cmd.bytecap' } );
    check(
        'byte-cap valve : payload + marker',
        !$e
            && $t
            =~ m{\Ax{70}\n\[stream still open, 70 bytes collected, byte cap 64 reached\]\z},
        "err=$e len=" . length($t)
    );

    ## 14 : sentinel proves reconnect after byte-cap teardown ##
    ( $t, $e ) = tool_call( 'p7_command', { 'command' => 'cmd.true' } );
    check(
        'sentinel after byte-cap teardown',
        !$e && $t eq 'works',
        "err=$e text=$t"
    );

    ## 15 : hardened fall-through -- unhandled type returns raw... ##
    ( $t, $e ) = tool_call( 'p7_command', { 'command' => 'cmd.chrsize' } );
    check(
        'unknown reply type [ CHRSIZE ] returns raw line',
        !$e && $t eq 'CHRSIZE 5',
        "err=$e text=$t"
    );

    ## 16 : ...and its leftover frames cannot corrupt the next call ##
    ( $t, $e ) = tool_call( 'p7_command', { 'command' => 'cmd.true' } );
    check(
        'sentinel after unknown-reply teardown [ fall-through fix ]',
        !$e && $t eq 'works',
        "err=$e text=$t"
    );

    ## 17 : multiline call site -- STRM clean close ##
    my $long_desc = join ' ', ('multiline strm drain test') x 30;
    ( $t, $e )
        = tool_call( 'p7_task_create', { 'description' => $long_desc } );
    check(
        'multiline path : strm clean close',
        !$e && $t eq 'mlrn',
        "err=$e text=$t"
    );

    ## 18 : multiline call site -- hardened fall-through [ result over 200 ##
    ## chars forces the cube_command_multiline path ]                      ##
    my $long_result = join ' ', ('multiline fall-through test') x 20;
    ( $t, $e )
        = tool_call( 'p7_task_complete',
        { 'task_id' => 'FAKEID', 'result' => $long_result } );
    check(
        'multiline path : unknown reply returns raw line',
        !$e && $t eq 'WUNKNOWN huh',
        "err=$e text=$t"
    );

    ## 19 : sentinel proves multiline fall-through tore down ##
    ( $t, $e ) = tool_call( 'p7_command', { 'command' => 'cmd.true' } );
    check(
        'sentinel after multiline fall-through',
        !$e && $t eq 'works',
        "err=$e text=$t"
    );
};
my $eval_err = $@;

close $srv_wtr;
kill 'TERM', $mcp_pid if $mcp_pid;
kill 'TERM', $srv_pid;
waitpid $mcp_pid, 0;
waitpid $srv_pid, 0;

die "harness error : $eval_err" if $eval_err;

printf "\n%d passed, %d failed\n", $pass, $fail;
exit( $fail ? 1 : 0 );

#,,..,..,,...,.,,,,,.,,,.,..,,,,.,,,.,,.,,.,,,..,,...,...,...,,.,,...,,.,,,.,,
#VJBA542YSKRCW4CLJWCIZY76VQDLI66IWP5KJXIWDF5C2B4IC5Z3BFY4HTCAS622XUUGYJJP7I2LW
#\\\|TYGRCHVH47AV4OFXSWVPKVZZ2PXA6HI5ZSXY6HJPE7ASFYVGUHU \ / AMOS7 \ YOURUM ::
#\[7]4F2MW5GIAIKKMYTQO4PIF76Y3Y2KFGVPZFAPNA3GK27FXDK3GKBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
