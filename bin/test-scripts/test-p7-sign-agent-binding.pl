#!/usr/bin/perl
## p7-sign-agent content binding : RUN approves CONTENTS, not paths --------
###                                                                         ###

## drives the REAL bin/p7-sign-agent over its unix socket with a THROWAWAY  ##
## Ed25519 key in a File::Temp dir [ never ~/.n or user-keys ]. two agents: ##
##                                                                          ##
## 1 : --test-stdin-approval, started in its own session                    ##
## [ setsid, so /dev/tty cannot open and the stdin fallback engages ].      ##
## asserts the whole happy path -- HELLO identity, RUN approved with 'y' on ##
## stdin, SIGN OK with a verifiable signature -- then MODIFIES the approved ##
## file and asserts SIGN refuses [ content changed ] even though the        ##
## request repeats the approved values verbatim : the binding is to what    ##
## RUN read, not to what the request claims. END closes the run.            ##
##                                                                          ##
## 2 : NO test flag. a stray 'y' sits on its stdin before RUN -- asserts    ##
## the approval is still refused and the run never opens                    ##
## [ the stdin fallback must not exist in production ].                     ##

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

STDOUT->autoflush(1);    ## live progress under harness pipes too ##

sub ok ($;$) {
    my ( $cond, $label ) = @ARG;
    if ($cond) { say "  ok   : $label"; return }
    $fail_count++;
    say "  FAIL : $label";
    return;
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

## spawn an agent in its own session [ no controlling tty ] with a pipe to its
## stdin and its stderr captured to a log file
my @spawned_pid;

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

##[ part 1 : content-bound run through --test-stdin-approval ]################

say 'part 1 : RUN approves contents, SIGN refuses a modified file';

my $temp_one = File::Temp::tempdir(
    'p7-sign-agent-binding-1-XXXX',
    TMPDIR  => 1,
    CLEANUP => 1
);

my $key_dir_one = File::Spec->catdir( $temp_one, qw| keys | );
mkdir $key_dir_one or die "mkdir keys : $OS_ERROR\n";

my $secret = Crypt::Misc::random_bytes(32);
my ( $pub_one, $priv_one ) = Crypt::Ed25519::generate_keypair($secret);
{
    open( my $fh, qw| > |,
        File::Spec->catfile( $key_dir_one, 'test.public' ) )
        or die "public key : $OS_ERROR\n";
    say {$fh} encode_b32r($pub_one);
    close $fh;
    open( $fh, qw| > |, File::Spec->catfile( $key_dir_one, 'test.private' ) )
        or die "private key : $OS_ERROR\n";
    say {$fh} encode_b32r($priv_one);
    close $fh;
}

## unsigned file : the strip is the identity, content == body
my $tree_one = File::Spec->catdir( $temp_one, qw| tree | );
mkdir $tree_one or die "mkdir tree : $OS_ERROR\n";
my $file_rel  = qw| alpha.txt |;
my $file_body = "hello protocol-7\n";
{
    open( my $fh, qw| > |, File::Spec->catfile( $tree_one, $file_rel ) )
        or die "work file : $OS_ERROR\n";
    print {$fh} $file_body;
    close $fh;
}

my ( $socket_one, $log_one, $stdin_one, $pid_one ) = spawn_agent(
    'temp_dir'   => $temp_one,
    'key_dir'    => $key_dir_one,
    'test_stdin' => TRUE
);

ok( wait_for_socket($socket_one), 'agent 1 serves its socket' );

my $hello = agent_request( $socket_one, qw| HELLO | );
ok( defined $hello && $hello =~ m|^OK p7-sign-agent/1 |,
    'HELLO answers with the protocol + public key'
);

my $chk_one = body_chksum($file_body);
my $len_one = length $file_body;
my $run_id  = qw| binding-test-run |;

my $run_reply = run_request(
    $socket_one,
    $stdin_one,
    "y\n",
    sprintf( 'RUN %s %s 1', $run_id, encode_b32r($tree_one) ),
    sprintf( 'F %s %s %d',  encode_b32r($file_rel), $chk_one, $len_one ),
    qw| GO |
);
ok( defined $run_reply && $run_reply =~ m|^OK|,
    'RUN approved with y on stdin' )
    or say "       run reply : " . ( $run_reply // '<none>' );

my $header_line = "#........,\n";
my $buffer      = sign_buffer( $file_body, $header_line );

my $sign_reply = agent_request( $socket_one, sprintf 'SIGN %s %s %s %d %s',
    $run_id, encode_b32r($file_rel), $chk_one, $len_one,
    encode_b32r($buffer) );
my ( $sig_status, $sig_b32 ) = split m| |, $sign_reply // '';
chomp $sig_b32 if defined $sig_b32;
my $signature = defined $sig_b32 ? decode_b32r($sig_b32) : undef;
ok( defined $signature
        && $sig_status eq qw| OK |
        && Crypt::Ed25519::verify( $buffer, $pub_one, $signature ),
    'SIGN returns a signature that verifies against the throwaway public key'
);

## the attack this binding exists for : change the file AFTER approval, replay
## the exact approved request values -- must refuse
open( my $mod_fh, qw| >> |, File::Spec->catfile( $tree_one, $file_rel ) )
    or die "modify work file : $OS_ERROR\n";
print {$mod_fh} "same-uid process slipped this in\n";
close $mod_fh;

my $replay_reply = agent_request( $socket_one, sprintf 'SIGN %s %s %s %d %s',
    $run_id, encode_b32r($file_rel), $chk_one, $len_one,
    encode_b32r($buffer) );
ok( defined $replay_reply && $replay_reply =~ m|^NO content_changed\n?\z|,
    'SIGN refuses the approved values once '
        . 'the file changed [ content changed ]'
) or say "       replay reply : " . ( $replay_reply // '<none>' );

my $end_reply = agent_request( $socket_one, "END $run_id" );
ok( defined $end_reply && $end_reply =~ m|^OK |,
    'END closes the run with its signed end record'
);

stop_agent($pid_one);

##[ part 2 : stray stdin approval without the test flag ]#####################

say 'part 2 : no test flag -- a stray stdin y must not approve';

my $temp_two = File::Temp::tempdir(
    'p7-sign-agent-binding-2-XXXX',
    TMPDIR  => 1,
    CLEANUP => 1
);

my $key_dir_two = File::Spec->catdir( $temp_two, qw| keys | );
mkdir $key_dir_two or die "mkdir keys : $OS_ERROR\n";

my ( $pub_two, $priv_two ) = Crypt::Ed25519::generate_keypair($secret);
{
    open( my $fh, qw| > |,
        File::Spec->catfile( $key_dir_two, 'test.public' ) )
        or die "public key : $OS_ERROR\n";
    say {$fh} encode_b32r($pub_two);
    close $fh;
    open( $fh, qw| > |, File::Spec->catfile( $key_dir_two, 'test.private' ) )
        or die "private key : $OS_ERROR\n";
    say {$fh} encode_b32r($priv_two);
    close $fh;
}

my $tree_two = File::Spec->catdir( $temp_two, qw| tree | );
mkdir $tree_two or die "mkdir tree : $OS_ERROR\n";
open( my $two_fh, qw| > |, File::Spec->catfile( $tree_two, $file_rel ) )
    or die "work file : $OS_ERROR\n";
print {$two_fh} $file_body;
close $two_fh;

my ( $socket_two, $log_two, $stdin_two, $pid_two ) = spawn_agent(
    'temp_dir'   => $temp_two,
    'key_dir'    => $key_dir_two,
    'test_stdin' => FALSE
);

ok( wait_for_socket($socket_two), 'agent 2 serves its socket' );

print {$stdin_two} "y\n";    ## the stray approval, must be ignored ##

my $denied_reply = run_request(
    $socket_two,
    $stdin_two,
    '',
    sprintf( 'RUN %s %s 1', $run_id, encode_b32r($tree_two) ),
    sprintf( 'F %s %s %d',
        encode_b32r($file_rel), body_chksum($file_body),
        length $file_body ),
    qw| GO |
);
ok( defined $denied_reply && $denied_reply =~ m|^NO denied|,
    'RUN refused with no controlling terminal and no test flag'
) or say "       run reply : " . ( $denied_reply // '<none>' );

stop_agent($pid_two);    ## exits flush the agent's buffered stderr ##

my $log_text = do {
    my $content;
    if ( open( my $fh, qw| < |, $log_two ) ) {
        local $INPUT_RECORD_SEPARATOR = undef;
        $content = <$fh>;
        close $fh;
    }
    $content;
};
ok( ( defined $log_text and index( $log_text, 'approval refused', 0 ) != -1 ),
    'agent 2 logged the refusal'
);

##[ part 3 : the restart handover -key-fd ]###################################

say q|part 3 : -key-fd hands the unlocked key over [ ctrl-r restart ]|;

my $temp_three = File::Temp::tempdir(
    q|p7-sign-agent-binding-3-XXXX|,
    TMPDIR  => 1,
    CLEANUP => 1
);
my $key_dir_three = File::Spec->catdir( $temp_three, qw| keys | );
mkdir $key_dir_three or die "mkdir keys : $OS_ERROR\n";
my ( $pub_three, $priv_three )
    = Crypt::Ed25519::generate_keypair( Crypt::Misc::random_bytes(32) );
{
    open( my $fh, qw| > |,
        File::Spec->catfile( $key_dir_three, q|test.public| ) )
        or die "public key : $OS_ERROR\n";
    say {$fh} encode_b32r($pub_three);
    close $fh;
    open( $fh, qw| > |,
        File::Spec->catfile( $key_dir_three, q|test.private| ) )
        or die "private key : $OS_ERROR\n";
    say {$fh} encode_b32r($priv_three);
    close $fh;
}

my ( $socket_three, $log_three, undef, $pid_three ) = spawn_agent(
    'temp_dir'    => $temp_three,
    'key_dir'     => $key_dir_three,
    'key_fd_data' => $priv_three
);
ok( wait_for_socket($socket_three), q|agent 3 starts with the handed key| );
my $hello_three = agent_request( $socket_three, qw| HELLO | );
ok( defined $hello_three
        && index( $hello_three, encode_b32r($pub_three), 0 ) != -1,
    q|HELLO answers with the handed key's public half|
);
stop_agent($pid_three);
unlink $socket_three;

## a WRONG key through the pipe while the key dir holds the right one : the
## agent must refuse -- proves the fd, not the file, is used
my ( undef, $wrong_priv )
    = Crypt::Ed25519::generate_keypair( Crypt::Misc::random_bytes(32) );
my ( $socket_four, $log_four, undef, $pid_four ) = spawn_agent(
    'temp_dir'    => $temp_three,
    'key_dir'     => $key_dir_three,
    'key_fd_data' => $wrong_priv
);
waitpid $pid_four, 0;
@spawned_pid = grep { $ARG != $pid_four } @spawned_pid;
my $log_four_text = do {
    local $INPUT_RECORD_SEPARATOR = undef;
    my $text = '';
    if ( open( my $fh, qw| < |, $log_four ) ) { $text = <$fh>; close $fh }
    $text;
};
ok( not( -S $socket_four )
        && index( $log_four_text, q|does not match|, 0 ) != -1,
    q|a wrong handed key is refused [ the fd is used, not the file ]|
);

##[ summary ]#################################################################

if ( $fail_count == 0 ) {
    say 'all checks passed =)';
    exit 0;
}
say "$fail_count check(s) FAILED";
exit 1;

#,,,.,,,,,.,.,,..,.,.,,,.,,..,,,.,,.,,.,.,.,.,..,,...,..,,..,,.,.,,..,,,,,,,.,
#O5P4MBHBISGTW7CVFYED6NP34L3R4YDDLN2FMGAJ4RAMYX464WPH2M3BZXOUTMCJDGUWAS5XGRF6Q
#\\\|O75OYGUQAMIKMKZZDG75EJ6DWPZFZW562PIZD3EPQ6EYFVYAES4 \ / AMOS7 \ YOURUM ::
#\[7]7QWUJSMYKU7HIX77QN45VISGFUKDBSRWEWIAE7GGMK37XK76KODA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
