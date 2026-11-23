#!/usr/bin/perl
## test-p7-sign-agent-queue.pl : request queuing in bin/p7-sign-agent
##
## own agent instances only [ temp socket + run dir, new session, the
## --test-stdin-approval answer path ] -- never the owner's live agent.  1 :
## two requests -- the second answers 'QUEUED 1', a HELLO is served while the
## prompt is open, the first is approved, the second gets its OWN prompt and
## its own answer [ denied here ]  2 : a queued client that disconnects is
## dropped as 'withdrawn', never prompted, never 'denied'  3 : --queue-limit 1
## : the third request answers 'NO busy' ; a file changed while queued is
## refused at its own turn, not prompted

use v5.24;
use strict;
use warnings;
use English;
use File::Spec;
use File::Temp ();
use Cwd        qw| abs_path |;
use FindBin    qw| $RealBin |;
use POSIX      qw| setsid |;
use Fcntl      qw| F_GETFD F_SETFD FD_CLOEXEC |;
use IO::Select;

use constant TRUE  => 5;
use constant FALSE => 0;

BEGIN {
    my $up_dir    = File::Spec->updir;
    my $root_path = abs_path(
        File::Spec->rel2abs(
            File::Spec->catdir( $RealBin, $up_dir, $up_dir )
        )
    );
    $main::root_path = $root_path;
}

use lib File::Spec->catdir( $main::root_path, qw| data lib-path pm | );

use Crypt::Ed25519 ();
use Crypt::Misc    qw| encode_b32r decode_b32r |;
use Digest::BMW    ();
use IO::Socket::UNIX;

my $agent_bin
    = File::Spec->catfile( $main::root_path, qw| bin p7-sign-agent | );

my $fail_count = 0;
my @spawned_pid;
END { kill qw| TERM |, $ARG foreach @spawned_pid }

STDOUT->autoflush(1);    ## live progress under harness pipes too ##

sub ok ($;$) {
    my ( $cond, $label ) = @ARG;
    if ($cond) { say "  ok   : $label"; return TRUE }
    $fail_count++;
    say "  FAIL : $label";
    return FALSE;
}

## same value both sides of the wire : BMW-512 over the stripped body, base32
## [ the agent's bmw_b32 + the client's chk-sum.bmw.strsum ]
sub body_chksum {
    my $data = shift;
    my $ctx  = Digest::BMW->new(512);
    $ctx->add($data);
    return encode_b32r( $ctx->digest );
}

## the signed buffer the agent's regex constrains : header line + '#' +
## BMW-384 [ body + header . '#' ] + newline + the template's constant 5-byte
## tail [ fill_source_template's sig_template_prefix ]
sub sign_buffer {
    my $body        = shift;
    my $header_line = shift;    ## includes its trailing newline ##
    my $ctx         = Digest::BMW->new(384);
    $ctx->add($body);
    $ctx->add( sprintf '%s#', $header_line );
    return sprintf '%s#%s%s', $header_line,
        encode_b32r( $ctx->digest ), "\n#\\\\\\|";
}

## one op per connection, one reply line back
sub agent_request {
    my ( $socket_path, @lines ) = @ARG;
    my $handle = connect_handle($socket_path) or return undef;
    print {$handle} join '', map { $ARG =~ m|\n$| ? $ARG : "$ARG\n" } @lines;
    my $reply = read_reply($handle);
    close $handle;
    return $reply;
}

## RUN is special : the agent answers only after the user-paced approval, so
## the caller injects the approval answer on the agent's stdin between sending
## the request and reading the reply
sub run_request {
    my ( $socket_path, $stdin_write, $approval, @lines ) = @ARG;
    my $handle = connect_handle($socket_path) or return undef;
    print {$handle} join '', map { $ARG =~ m|\n$| ? $ARG : "$ARG\n" } @lines;
    print {$stdin_write} $approval;
    my $reply = read_reply($handle);
    close $handle;
    return $reply;
}

sub read_reply {
    my $handle = shift;
    my $reply  = eval {
        local $SIG{'ALRM'} = sub { die "reply timed out\n" };
        ## an agent that never answers is a failure, not a wait ##
        alarm 20;
        my $line = <$handle>;
        alarm 0;
        $line;
    };
    alarm 0;
    return $reply;
}

sub connect_handle {
    my $socket_path = shift;
    return IO::Socket::UNIX->new(
        qw| Type | => SOCK_STREAM,
        qw| Peer | => $socket_path,
    );
}

sub wait_for_socket {
    my $socket_path = shift;
    foreach my $try ( 1 .. 100 ) {
        return TRUE if -S $socket_path;
        select( undef, undef, undef, 0.1 );
    }
    return FALSE;
}

## todo RCM : the agent must never map an Inline object -- the compiled cache
## under ~/.7/inline-code is user-writable and unsigned, and this process
## holds the unlocked signing key. /proc/<pid>/maps is the strongest evidence
## : it needs no cooperation from the agent [ no hidden report channel ] and
## lists every mapped file. undef when unreadable.
sub spawn_agent {
    my %opt      = @ARG;
    my $temp_dir = $opt{'temp_dir'};
    my $socket   = File::Spec->catfile( $temp_dir, qw| agent.sock | );
    my $err_log  = File::Spec->catfile( $temp_dir, qw| agent.stderr | );

    open( my $err_fh, qw| > |, $err_log )   or die "stderr log : $OS_ERROR\n";
    pipe( my $stdin_read, my $stdin_write ) or die "pipe : $OS_ERROR\n";

    my $pid = fork();
    die "fork : $OS_ERROR\n" if not defined $pid;

    if ( $pid == 0 ) {    ## child : new session, agent's stdio rewired ##
        setsid();
        open( STDIN,  '<&', $stdin_read ) or die "stdin dup : $OS_ERROR\n";
        open( STDOUT, '>',  File::Spec->devnull )
            or die "stdout : $OS_ERROR\n";
        open( STDERR, '>&', $err_fh ) or die "stderr dup : $OS_ERROR\n";
        my @cmd = (
            $^X,         $agent_bin, '--socket',  $socket,
            '--key',     qw| test |, '--key-dir', $opt{'key_dir'},
            '--run-dir', $temp_dir
        );
        push @cmd, qw| --test-stdin-approval | if $opt{'test_stdin'};
        push @cmd, qw| --queue-limit |, $opt{'queue_limit'}
            if defined $opt{'queue_limit'};

        ## the restart handover [ ctrl-r ] : the key through an inherited ##
        ## pipe                                                           ##
        my $key_read;    ## open until the exec : out of scope = closed ##
        if ( defined $opt{'key_fd_data'} ) {
            pipe( $key_read, my $key_write ) or die "pipe : $OS_ERROR\n";
            my $fd_flags = fcntl( $key_read, F_GETFD, 0 ) // 0;
            fcntl( $key_read, F_SETFD, $fd_flags & ~FD_CLOEXEC );
            binmode $key_write;
            print {$key_write} $opt{'key_fd_data'};
            close $key_write;
            push @cmd, qw| -key-fd |, fileno $key_read;
        }
        exec @cmd or die "exec p7-sign-agent : $OS_ERROR\n";
    }

    close $stdin_read;
    close $err_fh;
    $stdin_write->autoflush(1);    ## the approval must reach the agent NOW ##
    push @spawned_pid, $pid;
    return ( $socket, $err_log, $stdin_write, $pid );
}

sub stop_agent {
    my $pid = shift;
    kill qw| TERM |, $pid;
    waitpid $pid, 0;
    @spawned_pid = grep { $ARG != $pid } @spawned_pid;
    return;
}

##[ queue helpers ]###########################################################

## the agent's stderr : how many approval prompts it has shown ##
sub prompt_count {
    my $err_log = shift;
    open( my $fh, '<', $err_log ) or return 0;
    local $/;
    my $text = <$fh> // '';
    close $fh;
    my $n = () = $text =~ m|: sign \? \[y/n\] : |g;
    return $n;
}

sub wait_until {
    my ( $code, $seconds ) = @ARG;
    my $end = time() + ( $seconds // 13 );
    while ( time() < $end ) {
        return TRUE if $code->();
        select( undef, undef, undef, 0.05 );
    }
    return FALSE;
}

sub run_log_has {
    my ( $temp_dir, $pattern ) = @ARG;
    my $log = File::Spec->catfile( $temp_dir, qw| p7-sign-agent runs.log | );
    open( my $fh, '<', $log ) or return FALSE;
    local $/;
    my $text = <$fh> // '';
    close $fh;
    return $text =~ $pattern ? TRUE : FALSE;
}

## a RUN sent, the handle kept : the reply is read later ##
sub run_open {
    my ( $socket_path, $run_id, $tree, $rel, $body ) = @ARG;
    my $handle = connect_handle($socket_path) or return undef;
    $handle->autoflush(1);
    printf {$handle} "RUN %s %s 1\nF %s %s %d\nGO\n", $run_id,
        encode_b32r($tree), encode_b32r($rel), body_chksum($body),
        length $body;
    return $handle;
}

## one reply line, or undef when none comes in time [ no die ] ##
sub reply_within {
    my ( $handle, $seconds ) = @ARG;
    return undef if not IO::Select->new($handle)->can_read($seconds);
    return scalar <$handle>;
}

sub tree_set_up {
    my ( $temp_dir, %files ) = @ARG;
    my $key_dir = File::Spec->catdir( $temp_dir, qw| keys | );
    mkdir $key_dir or die "mkdir keys : $OS_ERROR\n";
    my ( $pub, $priv )
        = Crypt::Ed25519::generate_keypair( Crypt::Misc::random_bytes(32) );
    foreach my $pair ( [ qw| public |, $pub ], [ qw| private |, $priv ] ) {
        open( my $fh, qw| > |,
            File::Spec->catfile( $key_dir, "test.$pair->[0]" ) )
            or die "key : $OS_ERROR\n";
        say {$fh} encode_b32r( $pair->[1] );
        close $fh;
    }
    my $tree = File::Spec->catdir( $temp_dir, qw| tree | );
    mkdir $tree or die "mkdir tree : $OS_ERROR\n";
    foreach my $rel ( keys %files ) {
        open( my $fh, qw| > |, File::Spec->catfile( $tree, $rel ) )
            or die "work file : $OS_ERROR\n";
        print {$fh} $files{$rel};
        close $fh;
    }
    return ( $key_dir, $tree );
}

my %files = (
    qw| a.txt | => "first request\n",
    qw| b.txt | => "second request\n",
    qw| c.txt | => "third request\n",
);

##[ part 1 : queued, prompted next, own answer ]##############################

say 'part 1 : a second request is queued and prompted after the first';
{
    my $temp = File::Temp::tempdir(
        'p7-sign-agent-queue-1-XXXX',
        TMPDIR  => 1,
        CLEANUP => 1
    );
    my ( $key_dir, $tree ) = tree_set_up( $temp, %files );
    my ( $socket, $err_log, $stdin, $pid ) = spawn_agent(
        'temp_dir'   => $temp,
        'key_dir'    => $key_dir,
        'test_stdin' => TRUE
    );
    ok( wait_for_socket($socket), 'agent serves its socket' );

    my $run_a = run_open( $socket, 'q1-a', $tree, 'a.txt', $files{'a.txt'} );
    ok( wait_until( sub { prompt_count($err_log) == 1 } ),
        'first request prompted' );
    my $run_b  = run_open( $socket, 'q1-b', $tree, 'b.txt', $files{'b.txt'} );
    my $queued = reply_within( $run_b, 7 ) // '';
    ok( $queued eq "QUEUED 1\n", 'second request answers QUEUED 1' )
        or say "       got : $queued";

    my $hello = agent_request( $socket, 'HELLO' ) // '';
    ok( $hello =~ m|^OK p7-sign-agent:003 |,
        'HELLO answered while a prompt is open'
    ) or say "       got : $hello";

    print {$stdin} "y\n";
    my $reply_a = reply_within( $run_a, 7 ) // '';
    ok( $reply_a eq "OK\n", 'first request approved' )
        or say "       got : $reply_a";
    ok( wait_until( sub { prompt_count($err_log) == 2 } ),
        'second request gets its own prompt' );
    ok( not( defined reply_within( $run_b, 0.5 ) ),
        'no answer carried over to the second request'
    );

    print {$stdin} "n\n";
    my $reply_b = reply_within( $run_b, 7 ) // '';
    ok( $reply_b eq "NO denied\n",
        'second request answered by its own prompt [ denied ]' )
        or say "       got : $reply_b";

    my $end_a = agent_request( $socket, 'END q1-a' ) // '';
    ok( $end_a =~ m|^OK |,                         'first run ends' );
    ok( run_log_has( $temp, qr|queued q1-b 1 1| ), 'run log : queued line' );
    close $run_a;
    close $run_b;
    stop_agent($pid);
}

##[ part 2 : a queued client goes away ]######################################

say 'part 2 : a queued client that disconnects is withdrawn, not denied';
{
    my $temp = File::Temp::tempdir(
        'p7-sign-agent-queue-2-XXXX',
        TMPDIR  => 1,
        CLEANUP => 1
    );
    my ( $key_dir, $tree ) = tree_set_up( $temp, %files );
    my ( $socket, $err_log, $stdin, $pid ) = spawn_agent(
        'temp_dir'   => $temp,
        'key_dir'    => $key_dir,
        'test_stdin' => TRUE
    );
    ok( wait_for_socket($socket), 'agent serves its socket' );

    my $run_a = run_open( $socket, 'q2-a', $tree, 'a.txt', $files{'a.txt'} );
    ok( wait_until( sub { prompt_count($err_log) == 1 } ),
        'first request prompted' );
    my $run_b  = run_open( $socket, 'q2-b', $tree, 'b.txt', $files{'b.txt'} );
    my $queued = reply_within( $run_b, 7 ) // '';
    ok( $queued eq "QUEUED 1\n", 'second request queued' );
    close $run_b;
    ok( wait_until(
            sub { run_log_has( $temp, qr|withdrawn q2-b 1 queued| ) }
        ),
        'run log : the queued request withdrawn'
    );

    print {$stdin} "y\n";
    my $reply_a = reply_within( $run_a, 7 ) // '';
    ok( $reply_a eq "OK\n", 'first request approved' );
    select( undef, undef, undef, 0.7 );
    ok( prompt_count($err_log) == 1,
        'the withdrawn request is never prompted' );
    ok( not( run_log_has( $temp, qr|denied q2-b| ) ),
        'the withdrawn request is not logged denied'
    );
    agent_request( $socket, 'END q2-a' );
    close $run_a;
    stop_agent($pid);
}

##[ part 3 : over the limit, content changed while queued ]###################

say 'part 3 : queue limit -> busy ; content changed while queued is refused';
{
    my $temp = File::Temp::tempdir(
        'p7-sign-agent-queue-3-XXXX',
        TMPDIR  => 1,
        CLEANUP => 1
    );
    my ( $key_dir, $tree ) = tree_set_up( $temp, %files );
    my ( $socket, $err_log, $stdin, $pid ) = spawn_agent(
        'temp_dir'    => $temp,
        'key_dir'     => $key_dir,
        'test_stdin'  => TRUE,
        'queue_limit' => 1
    );
    ok( wait_for_socket($socket), 'agent serves its socket' );

    my $run_a = run_open( $socket, 'q3-a', $tree, 'a.txt', $files{'a.txt'} );
    ok( wait_until( sub { prompt_count($err_log) == 1 } ),
        'first request prompted' );
    my $run_b = run_open( $socket, 'q3-b', $tree, 'b.txt', $files{'b.txt'} );
    ok( ( reply_within( $run_b, 7 ) // '' ) eq "QUEUED 1\n",
        'second request queued' );
    my $run_c = run_open( $socket, 'q3-c', $tree, 'c.txt', $files{'c.txt'} );
    my $busy  = reply_within( $run_c, 7 ) // '';
    ok( $busy eq "NO busy\n", 'over the limit : NO busy, not denied' )
        or say "       got : $busy";
    close $run_c;

    ## the queued request's file changes while it waits ##
    {
        open( my $fh, qw| > |, File::Spec->catfile( $tree, 'b.txt' ) )
            or die "rewrite : $OS_ERROR\n";
        print {$fh} "changed while queued\n";
        close $fh;
    }
    print {$stdin} "y\n";
    ok( ( reply_within( $run_a, 7 ) // '' ) eq "OK\n",
        'first request approved' );
    my $reply_b = reply_within( $run_b, 7 ) // '';
    ok( $reply_b eq "NO content_changed_1\n",
        'changed while queued : refused at its turn'
    ) or say "       got : $reply_b";
    ok( prompt_count($err_log) == 1,
        'the changed request is never prompted' );
    ok( run_log_has( $temp, qr|busy q3-c 1| ), 'run log : busy line' );
    agent_request( $socket, 'END q3-a' );
    close $run_a;
    close $run_b;
    stop_agent($pid);
}

##[ part 4 : SIGN + END served while another prompt is open ]#################

say 'part 4 : an approved run signs and ends while a new prompt waits';
{
    my $temp = File::Temp::tempdir(
        'p7-sign-agent-queue-4-XXXX',
        TMPDIR  => 1,
        CLEANUP => 1
    );
    my ( $key_dir, $tree ) = tree_set_up( $temp, %files );
    my ( $socket, $err_log, $stdin, $pid ) = spawn_agent(
        'temp_dir'   => $temp,
        'key_dir'    => $key_dir,
        'test_stdin' => TRUE
    );
    ok( wait_for_socket($socket), 'agent serves its socket' );

    my $run_a = run_open( $socket, 'q4-a', $tree, 'a.txt', $files{'a.txt'} );
    ok( wait_until( sub { prompt_count($err_log) == 1 } ),
        'first request prompted' );
    print {$stdin} "y\n";
    ok( ( reply_within( $run_a, 7 ) // '' ) eq "OK\n",
        'first request approved' );
    close $run_a;

    my $run_b = run_open( $socket, 'q4-b', $tree, 'b.txt', $files{'b.txt'} );
    ok( wait_until( sub { prompt_count($err_log) == 2 } ),
        'second request prompted' );

    my $buffer = sign_buffer( $files{'a.txt'}, "#,.,.,\n" );
    my $sign   = agent_request(
        $socket,                sprintf 'SIGN q4-a %s %s %d %s',
        encode_b32r('a.txt'),   body_chksum( $files{'a.txt'} ),
        length $files{'a.txt'}, encode_b32r($buffer)
    ) // '';
    ok( $sign =~ m|^OK [0-9A-Z]+$|, 'SIGN served while a prompt is open' )
        or say "       got : $sign";
    my $end = agent_request( $socket, 'END q4-a' ) // '';
    ok( $end =~ m|^OK |, 'END served while a prompt is open' )
        or say "       got : $end";

    print {$stdin} "n\n";
    ok( ( reply_within( $run_b, 7 ) // '' ) eq "NO denied\n",
        'second request answered by its own prompt'
    );
    close $run_b;
    stop_agent($pid);
}

##[ part 5 : the terminal prompt [ a pty, confirm_key ] ]#####################

say 'part 5 : the terminal prompt -- queue, redraw, carry-over guard';
if ( not eval { require IO::Pty; 1 } ) {
    say '  skip : IO::Pty not installed';
} else {
    my $temp = File::Temp::tempdir(
        'p7-sign-agent-queue-5-XXXX',
        TMPDIR  => 1,
        CLEANUP => 1
    );
    my ( $key_dir, $tree ) = tree_set_up( $temp, %files );
    my $socket = File::Spec->catfile( $temp, qw| agent.sock | );
    my $pty    = IO::Pty->new;
    my $pid    = fork();
    die "fork : $OS_ERROR\n" if not defined $pid;
    if ( $pid == 0 ) {    ## child : the pty is its controlling terminal ##
        $pty->make_slave_controlling_terminal;
        my $slave = $pty->slave;
        open( STDIN,  '<&', $slave ) or die "stdin : $OS_ERROR\n";
        open( STDERR, '>&', $slave ) or die "stderr : $OS_ERROR\n";
        open( STDOUT, '>',  File::Spec->devnull ) or die "stdout\n";
        @ENV{qw| P7_NO_MOUSE NO_COLOR |} = ( 1, 1 );
        exec $^X, $agent_bin, '--socket', $socket, '--key', qw| test |,
            '--key-dir', $key_dir, '--run-dir', $temp
            or die "exec : $OS_ERROR\n";
    }
    $pty->close_slave;
    push @spawned_pid, $pid;
    my $screen   = '';
    my $pty_wait = sub {    ## until the screen matches, the pty drained ##
        my ( $pattern, $seconds ) = @ARG;
        my $end = time() + ( $seconds // 13 );
        while ( time() < $end ) {
            return TRUE if $screen =~ $pattern;
            next        if not IO::Select->new($pty)->can_read(0.1);
            sysread( $pty, my $chunk, 65536 ) or last;
            $screen .= $chunk;
        }
        return $screen =~ $pattern ? TRUE : FALSE;
    };
    ## unsigned code on disk : the start gate asks first ##
    $pty_wait->( qr{start into|waiting for requests}, 20 );
    ## after the flush : the label shown ##
    if ( $screen =~ m|start into| ) {
        $pty_wait->( qr|\[a\]pprove|, 20 );
        select( undef, undef, undef, 0.3 );
        syswrite( $pty, qw| a | );
    }
    ok( wait_for_socket($socket), 'pty agent serves its socket' );
    say "       screen : ",
        substr( $screen =~ s|\e\[[0-9;?]*[A-Za-z]||gr, -600 )
        if not -S $socket;

    my $run_a = run_open( $socket, 'q5-a', $tree, 'a.txt', $files{'a.txt'} );
    ok( $pty_wait->(qr|sign these 1 files|),
        'first request prompted on the tty'
    );
    my $run_b = run_open( $socket, 'q5-b', $tree, 'b.txt', $files{'b.txt'} );
    ok( ( reply_within( $run_b, 7 ) // '' ) eq "QUEUED 1\n",
        'second request queued' );
    ok( $pty_wait->(qr|queued\s*:\s*1|), 'the prompt redraws with queued 1' );

    syswrite( $pty, 'a' );
    ok( ( reply_within( $run_a, 7 ) // '' ) eq "OK\n",
        'first request approved' );
    syswrite( $pty, 'a' );    ## a second key at once : must answer nothing ##
    ok( $pty_wait->(qr|next signing request|),
        'second request prompted as the next one'
    );
    ok( not( defined reply_within( $run_b, 1.5 ) ),
        'the extra key did not approve the queued request'
    );

    syswrite( $pty, 'r' );
    $pty_wait->(qr|reason|);
    syswrite( $pty, "\r" );
    ok( ( reply_within( $run_b, 7 ) // '' ) eq "NO denied\n",
        'second request answered by its own key' );
    agent_request( $socket, 'END q5-a' );
    close $run_a;
    close $run_b;
    stop_agent($pid);
}

##[ part 6 : how an approved run ENDS, on the agent screen ]##################

say 'part 6 : the agent screen shows how an approved run ends';
foreach my $plain ( FALSE, TRUE ) {
    my $temp = File::Temp::tempdir(
        'p7-sign-agent-queue-6-XXXX',
        TMPDIR  => 1,
        CLEANUP => 1
    );
    my ( $key_dir, $tree ) = tree_set_up( $temp, %files );
    local $ENV{'NO_COLOR'} = $plain ? 1 : undef;
    delete $ENV{'NO_COLOR'} if not $plain;
    my ( $socket, $err_log, $stdin, $pid ) = spawn_agent(
        'temp_dir'   => $temp,
        'key_dir'    => $key_dir,
        'test_stdin' => TRUE
    );
    ok( wait_for_socket($socket), 'agent serves its socket' );
    my $tag = $plain ? 'no colour' : 'colour';

    ## run 1 : approved, nothing signed, the client reports an abort ##
    my $run_a = run_open( $socket, 'q6-a', $tree, 'a.txt', $files{'a.txt'} );
    wait_until( sub { prompt_count($err_log) == 1 } );
    print {$stdin} "y\n";
    ok( ( reply_within( $run_a, 7 ) // '' ) eq "OK\n",
        "[$tag] run approved" );
    close $run_a;
    my $end = agent_request( $socket, sprintf 'END q6-a aborted %s',
        encode_b32r('exit 3') ) // '';
    ok( $end =~ m|^OK |, "[$tag] END aborted answered" );

    ## run 2 : approved, signed, a regular end ##
    my $run_b = run_open( $socket, 'q6-b', $tree, 'b.txt', $files{'b.txt'} );
    wait_until( sub { prompt_count($err_log) == 2 } );
    print {$stdin} "y\n";
    ok( ( reply_within( $run_b, 7 ) // '' ) eq "OK\n",
        "[$tag] second run approved" );
    close $run_b;
    agent_request(
        $socket,
        sprintf 'SIGN q6-b %s %s %d %s',
        encode_b32r('b.txt'),
        body_chksum( $files{'b.txt'} ),
        length $files{'b.txt'},
        encode_b32r( sign_buffer( $files{'b.txt'}, "#,.,.,\n" ) )
    );
    agent_request( $socket, 'END q6-b ok' );
    select( undef, undef, undef, 1.2 );    ## the idle screen after 0.7 s ##

    open( my $fh, '<', $err_log ) or die "err log : $OS_ERROR\n";
    my $screen = do { local $/; <$fh> };
    close $fh;
    my $red = "\e[38;2;150;52;78m";
    if ($plain) {
        ok( index( $screen, '[ x ABORTED : exit 3, signed 0 of 1 ]' ) >= 0,
            "[$tag] the error end reads as an error without colour"
        );
        ok( index( $screen, $red ) < 0,
            "[$tag] the end element carries no colour" );
    } else {
        ok( index( $screen,
                      $red
                    . '[ x ABORTED : exit '
                    . '3, signed 0 of 1 ]'
                    . "\e[0m" ) >= 0,
            "[$tag] the error end : muted red on the element only"
        );
    }
    ok( $screen =~ m|\[ \+ signed 1 of 1 \]|,
        "[$tag] the regular end : signed 1 of 1"
    );
    ok( $screen =~ m|last run.*\[ \+ signed 1 of 1 \]|,
        "[$tag] the idle screen keeps the last end"
    );
    ok( run_log_has( $temp, qr|run-end q6-a aborted| ),
        "[$tag] run log : run-end aborted" );
    stop_agent($pid);
}

say $fail_count ? "FAILED : $fail_count" : 'all ok';
exit( $fail_count ? 1 : 0 );

#,,.,,...,,,.,,.,,..,,...,,..,,..,.,.,,.,,.,.,..,,...,...,,..,,..,...,...,,..,
#5YEWLCEZP7BPEPUAINIMFOEYQWPFWS7KAQ6TJEP6DAXFMVI6LLQVMTXDPUFMDRMHMK6EO7QWQEWQE
#\\\|QCJTBSXZURMGNDCNGGSFGDND6P2QPSHRJ6MZEG5VIADLHCRNIYD \ / AMOS7 \ YOURUM ::
#\[7]TDDMOUPB5BF4HHKRZEJWHWDEOXQKC4BLO5DB7FL5CR2YTB653QDA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
