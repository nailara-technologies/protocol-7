#!/usr/bin/perl
## test-mcp-claude-cloud.pl -- fake-cube + stub harness for the
## claude_cloud_dispatch / claude_cloud_status tools in bin/mcp-server-p7
## [ task : mcp-server-p7-claude-cloud-dispatch ]
##
## stubs `claude` [ first on PATH : records its argv as one JSON array per
## line, prints a canned reply containing a session id + a
## https://claude.ai/code/... url ] and `git` [ records argv, answers the
## three read-only identity queries from env, delegates everything else to the
## real git ]. drives the REAL mcp-server-p7 over stdio json-rpc against a
## scripted fake cube and asserts :
##
## - the claude argv is LIST-FORM with the prompt as ONE argument even with
## quotes / $( ) / newlines in it [ injection sentinel file must NOT appear ]
## - the fixed preamble + branch + sha are present in that argument
## - session id + url are parsed from known-format output
## - unparseable output still returns the raw text, isError=0
## - 'push first' refusal when @{u}..HEAD is non-empty, both with the stubbed
## git and against a REAL throwaway git repo with an unpushed commit on top of
## a pushed one
## - claude_cloud_status wraps `claude agents --json` + `claude logs`
##
## env knobs [ also used by the mutation runs ] :  P7_MCP_SERVER_PL  -- run a
## different server copy [ mutated or not ] PERL5LIB          -- needed when
## the server copy lives outside the repo
## [ compile-time AMOS7/Digest::BMW requires ]
##
## usage : perl bin/test-scripts/test-mcp-claude-cloud.pl

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

my $root_path = $ENV{'PROTOCOL_7_ROOT'}  // '/data/projects/protocol-7';
my $server_pl = $ENV{'P7_MCP_SERVER_PL'} // "$root_path/bin/mcp-server-p7";

## capture files present before this run : never touched at cleanup ##
my %captures_before
    = map { $_ => 1 } glob("$root_path/data/state/claude-cloud-*.out");
die "server not found : $server_pl" if not -f $server_pl;

## real git binary [ looked up BEFORE the stub dir enters any PATH ] ##
my $real_git = $ENV{'P7_REAL_GIT'} // '';
if ( not length $real_git ) {
    $real_git
        = -x '/usr/bin/git'       ? '/usr/bin/git'
        : -x '/usr/local/bin/git' ? '/usr/local/bin/git'
        :                           '';
    die 'cannot locate the real git binary' if not length $real_git;
}

my $fake_sha = '0123456789abcdef0123456789abcdef01234567';

##[ scripted fake-cube replies [ keyed by exact command string ] ]##

my %SCRIPTS = ( 'cmd.true' => ["TRUE works\n"], );

##[ fake cube server [ child process — same protocol dialect as the    ]##
##[ strm test harness                                                  ]##

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
                $ok = fake_write( $conn, $frame ) or last;
            }
            last if not $ok;
        }
        close $conn;
    }
    exit 0;
}

##[ stub binaries [ claude + git, first on the server PATH ] ]##

sub write_stub {
    my ( $dir, $name, $content ) = @_;
    my $path = "$dir/$name";
    open( my $fh, '>', $path ) or die "cannot write $path : $!";
    print {$fh} $content;
    close $fh;
    chmod 0755, $path;
    return $path;
}

## stub claude : records argv [ one JSON array per line ], then prints a ##
## canned reply. modes : cloud [ id + url, exits ], garbage [ nothing  ]##
## to parse, exits ], slowurl [ id + url after ~1 s, then lingers       ]##
## STUB_LINGER s — exercises the detached early-return poll ], nourl     ]##
## [ never prints a url, lingers ], status [ agents --json -> fake       ]##
## listing, logs -> fake terminal output ]                               ]##
my $STUB_CLAUDE = <<'EOT';
#!/usr/bin/perl
use strict;
use warnings;
use JSON::PP;
$| = 1;    ## model a well-behaved streaming cli : no stdio block-buffering on the capture file ##
my $log = $ENV{'CLAUDE_STUB_LOG'} or die "CLAUDE_STUB_LOG not set\n";
open my $fh, '>>', $log or die "stub log : $!\n";
print {$fh} JSON::PP->new->canonical->encode( \@ARGV ), "\n";
close $fh;
my $mode   = $ENV{'CLAUDE_STUB_MODE'} // 'cloud';
my $linger = $ENV{'STUB_LINGER'}      // 30;
if ( $mode eq 'garbage' ) {
    print "cloud say what? no id here, no url either\n";
    exit 0;
} elsif ( $mode eq 'slowurl' ) {
    ## the url appears ~1 s in, then the session keeps running ##
    sleep 1;
    print "created claude cloud session\n";
    print "session id : 3fa85f64-5717-4562-b3fc-2c963f66afa6\n";
    print "open https://claude.ai/code/3fa85f64-5717-4562-b3fc-2c963f66afa6"
        . " to watch live\n";
    sleep $linger;
    exit 0;
} elsif ( $mode eq 'nourl' ) {
    print "working on it, no link yet\n";
    sleep $linger;
    exit 0;
} elsif ( $mode eq 'status' or $ARGV[0] eq 'agents' or $ARGV[0] eq 'logs' ) {
    ## status replies are also given in 'cloud' mode so a single server  ##
    ## phase can cover dispatch + status without an env change          ##
    if ( @ARGV >= 2 and $ARGV[0] eq 'agents' ) {
        print JSON::PP->new->canonical->encode(
            [   {   'id'     => '3fa85f64-5717-4562-b3fc-2c963f66afa6',
                    'status' => 'running'
                }
            ]
        ), "\n";
    } else {
        print "fake cloud terminal output line 1\n";
        print "fake cloud terminal output line 2\n";
    }
    exit 0;
}
if ( @ARGV and $ARGV[0] eq '-p' ) {
    ## tuning follow-up reply : the documented json shapes            ##
    ## {ok, session_id, url} / {ok:false, session_id, error}          ##
    if ( ( $ENV{'CLAUDE_STUB_MODE'} // '' ) eq 'followuperr' ) {
        print JSON::PP->new->canonical->encode(
            {   'ok'         => JSON::PP::false,
                'session_id' => '3fa85f64-5717-4562-b3fc-2c963f66afa6',
                'error'      => 'simulated follow-up failure'
            }
        ), "\n";
    } else {
        print JSON::PP->new->canonical->encode(
            {   'ok'         => JSON::PP::true,
                'session_id' => '3fa85f64-5717-4562-b3fc-2c963f66afa6',
                'url' =>
                    'https://claude.ai/code/3fa85f64-5717-4562-b3fc-2c963f66afa6'
            }
        ), "\n";
    }
    exit 0;
}
print "created claude cloud session\n";
print "session id : 3fa85f64-5717-4562-b3fc-2c963f66afa6\n";
print "open https://claude.ai/code/3fa85f64-5717-4562-b3fc-2c963f66afa6"
    . " to watch live\n";
print "all done\n";
exit 0;
EOT

## stub git : records argv, answers the identity queries from env,   ##
## delegates everything else to the REAL git [ so the throwaway-repo ##
## push-first test exercises real @{u}..HEAD semantics ]             ##
my $STUB_GIT = <<'EOT';
#!/usr/bin/perl
use strict;
use warnings;
if ( my $log = $ENV{'GIT_STUB_LOG'} ) {
    if ( open my $fh, '>>', $log ) {
        print {$fh} join( "\t", @ARGV ), "\n";
        close $fh;
    }
}
my $key = join ' ', @ARGV;
if ( $key eq 'branch --show-current'
    and defined $ENV{'GIT_STUB_BRANCH'} ) {
    print $ENV{'GIT_STUB_BRANCH'}, "\n";
    exit 0;
}
if ( $key =~ m{\Arev-parse --verify --quiet \S+\z}
    and defined $ENV{'GIT_STUB_SHA'} ) {
    print $ENV{'GIT_STUB_SHA'}, "\n";
    exit 0;
}
if ( $key =~ m{\A-c color\.ui=false log --oneline --no-color \S+\z} ) {
    if ( defined $ENV{'GIT_STUB_UNPUSHED'} ) {
        print "deadbeef stub unpushed commit\n" if $ENV{'GIT_STUB_UNPUSHED'};
        exit 0;    ## empty : everything is on the remote ##
    }
    exec $ENV{'P7_REAL_GIT'}, @ARGV;    ## real @{u}..HEAD check ##
}
if ( $key eq '-c color.ui=false status --porcelain --untracked-files=no' ) {
    if ( defined $ENV{'GIT_STUB_DIRTY'} ) {
        print $ENV{'GIT_STUB_DIRTY'};    ## empty : clean tree ##
        exit 0;
    }
    exec $ENV{'P7_REAL_GIT'}, @ARGV;    ## real dirty-tree check ##
}
exec $ENV{'P7_REAL_GIT'}, @ARGV;
EOT

##[ mcp client driver [ stdio json-rpc ] ]##

my ( $tmp_dir, $srv_pid, $srv_wtr, $srv_rdr );
my $req_id = 0;
my @stub_pids;        ## detached stub claude processes to kill at cleanup ##
my @capture_files;    ## their capture files to unlink at cleanup          ##

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
            if not $sel->can_read(90);
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

##[ server lifecycle ]##

sub spawn_server {
    my $stub_dir = "$tmp_dir/stubbin";
    local %ENV = %ENV;
    $ENV{'PATH'}                 = "$stub_dir:$ENV{'PATH'}";
    $ENV{'PROTOCOL_7_UNIX_PATH'} = "$tmp_dir/cube.sock";
    $ENV{'P7_REAL_GIT'}          = $real_git;
    $ENV{'CLAUDE_STUB_LOG'}      = "$tmp_dir/claude-argv.log";
    $ENV{'GIT_STUB_LOG'}         = "$tmp_dir/git-argv.log";

    my $pid = open3( $srv_wtr, $srv_rdr, '>&STDERR', $server_pl );
    binmode( $srv_wtr, ':raw' );
    binmode( $srv_rdr, ':raw' );
    mcp_request( 'initialize',
        { 'clientInfo' => { 'name' => 'claude-cloud-test' } } );
    return $pid;
}

sub kill_server {
    close $srv_wtr;
    kill 'TERM', $_[0] if $_[0];
    waitpid( $_[0], 0 ) if $_[0];
}

## read the claude stub argv log : one JSON array per line ##
sub stub_calls {
    my ($file) = @_;
    my @calls;
    if ( open( my $fh, '<', $file ) ) {
        while ( my $line = <$fh> ) {
            my $argv = eval { JSON::PP->new->decode($line) };
            push @calls, $argv if ref $argv eq 'ARRAY';
        }
        close $fh;
    }
    return @calls;
}

## read the git stub argv log : one tab-joined argv per line ##
sub git_calls {
    my ($file) = @_;
    my @calls;
    if ( open( my $fh, '<', $file ) ) {
        while ( my $line = <$fh> ) {
            chomp $line;
            push @calls, [ split m{\t}, $line ];
        }
        close $fh;
    }
    return @calls;
}

##[ main ]##

$tmp_dir = tempdir( 'p7-cld-test-XXXX', TMPDIR => 1, CLEANUP => 1 );
mkdir "$tmp_dir/stubbin" or die "cannot make stub dir : $!";

write_stub( "$tmp_dir/stubbin", 'claude', $STUB_CLAUDE );
write_stub( "$tmp_dir/stubbin", 'git',    $STUB_GIT );

## throwaway git repo with one PUSHED commit and one LOCAL-ONLY commit on ##
## branch 'cloud-test' [ upstream set via a bare remote ]                 ##
my $bare_remote = tempdir( 'p7-cld-remote-XXXX', TMPDIR => 1, CLEANUP => 1 );
my $temp_repo   = tempdir( 'p7-cld-repo-XXXX',   TMPDIR => 1, CLEANUP => 1 );
system( $real_git, 'init', '-q', '--bare', "$bare_remote/remote.git" ) == 0
    or die "bare init failed";
system( $real_git, '-C', $temp_repo, 'init', '-q' ) == 0
    or die "repo init failed";
system( $real_git, '-C', $temp_repo, 'config', 'user.email', 't@example' );
system( $real_git, '-C', $temp_repo, 'config', 'user.name',  't' );
{
    open( my $fh, '>', "$temp_repo/f" ) or die $!;
    print {$fh} "x\n";
    close $fh;
}
system( $real_git, '-C', $temp_repo, 'add', 'f' ) == 0 or die $!;
system( $real_git, '-C', $temp_repo, 'commit', '-qm', 'init' ) == 0
    or die $!;
system( $real_git, '-C', $temp_repo, 'branch', '-M', 'cloud-test' ) == 0
    or die $!;
system( $real_git, '-C', $temp_repo, 'remote', 'add', 'origin',
    "$bare_remote/remote.git" ) == 0
    or die $!;
system( $real_git, '-C', $temp_repo, 'push', '-qu', 'origin', 'cloud-test' )
    == 0
    or die $!;
{
    open( my $fh, '>>', "$temp_repo/f" ) or die $!;
    print {$fh} "y\n";
    close $fh;
}
system( $real_git, '-C', $temp_repo, 'commit', '-qam', 'local only' ) == 0
    or die $!;

## second throwaway repo, fully pushed AND clean [ for the dirty-tree  ]  ##
## refusal : an uncommitted tracked-file change is added before phase 9 ] ##
my $temp_repo2 = tempdir( 'p7-cld-repo2-XXXX', TMPDIR => 1, CLEANUP => 1 );
system( $real_git, '-C', $temp_repo2, 'init',   '-q' ) == 0 or die $!;
system( $real_git, '-C', $temp_repo2, 'config', 'user.email', 't@example' );
system( $real_git, '-C', $temp_repo2, 'config', 'user.name',  't' );
{
    open( my $fh, '>', "$temp_repo2/f" ) or die $!;
    print {$fh} "x\n";
    close $fh;
}
system( $real_git, '-C', $temp_repo2, 'add', 'f' ) == 0 or die $!;
system( $real_git, '-C', $temp_repo2, 'commit', '-qm', 'init' ) == 0
    or die $!;
system( $real_git, '-C', $temp_repo2, 'branch', '-M', 'cloud-test2' ) == 0
    or die $!;
system( $real_git, '-C', $temp_repo2, 'remote', 'add', 'origin',
    "$bare_remote/remote.git" ) == 0
    or die $!;
system( $real_git, '-C', $temp_repo2, 'push', '-qu', 'origin', 'cloud-test2' )
    == 0
    or die $!;

## start the scripted fake cube + wait for its socket ##
$srv_pid = fork();
die "fork failed" if not defined $srv_pid;
if ( $srv_pid == 0 ) {
    fake_cube_server("$tmp_dir/cube.sock");
}
for ( 1 .. 50 ) {
    last if -S "$tmp_dir/cube.sock";
    Time::HiRes::sleep(0.1);
}
die "fake cube socket never appeared" if not -S "$tmp_dir/cube.sock";

my $mcp_pid;

eval {
    ##================================================================##
    ## phase 1 : tools/list + happy-path dispatch + env param + status ##
    ##================================================================##
    {
        local %ENV = %ENV;
        $ENV{'CLAUDE_STUB_MODE'}          = 'cloud';
        $ENV{'GIT_STUB_BRANCH'}           = 'cloud-base';
        $ENV{'GIT_STUB_SHA'}              = $fake_sha;
        $ENV{'GIT_STUB_UNPUSHED'}         = '0';
        $ENV{'GIT_STUB_DIRTY'}            = '';
        $ENV{'PROTOCOL_7_MCP_CLOUD_REPO'} = $root_path;
        $mcp_pid                          = spawn_server();
    }

    my $list = mcp_request( 'tools/list', {} );
    my @tool_names
        = map { $_->{'name'} } @{ $list->{'result'}{'tools'} // [] };
    check(
        'tools/list exposes claude_cloud_dispatch',
        ( grep { $_ eq 'claude_cloud_dispatch' } @tool_names ),
        join ' ', @tool_names
    );
    check(
        'tools/list exposes claude_cloud_status',
        ( grep { $_ eq 'claude_cloud_status' } @tool_names ),
        join ' ', @tool_names
    );

    my $pwned  = "$tmp_dir/pwned-by-injection";
    my $pwned2 = "$tmp_dir/pwned-by-injection-2";
    my $nasty
        = "fix the \"quoted\" bits and run \$(touch $pwned) now\nsecond "
        . "line with \$(touch $pwned2) and `echo boom` never";
    my ( $t, $e )
        = tool_call( 'claude_cloud_dispatch', { 'prompt' => $nasty } );

    ## -- injection assertion : the $(touch ...) must NOT have run --      ##
    ## [ a 2 s grace period : under a broken shell-string exec the stub  ] ##
    ## [ prints the id on the FIRST shell line and the tool returns at  ]  ##
    ## [ once — the injected $(touch ...) on a LATER line would land a   ] ##
    ## [ moment afterwards ; correct list-form exec runs nothing at all ]  ##
    Time::HiRes::sleep(2);
    check(
        'injection sentinel files absent [ list-form exec ]',
        !-e $pwned && !-e $pwned2,
        "pwned files exist : $pwned $pwned2"
    );

    my @claude_argv = stub_calls("$tmp_dir/claude-argv.log");
    check(
        'claude was invoked exactly once',
        @claude_argv == 1,
        scalar @claude_argv . ' invocations'
    );

    my $argv = $claude_argv[0] // [];
    check(
        'exactly one argv element : the '
            . '--cloud=<task> pair [ no -p, no shell words ]',
        @$argv == 1,
        join ' ',
        map { length > 24 ? substr( $_, 0, 21 ) . '...' : $_ } @$argv
    );
    my $sent_prompt
        = ( @$argv and $argv->[0] =~ m{\A--cloud=(.*)\z}s ) ? $1 : undef;
    check(
        'the whole task travels as ONE argv element [ no shell splitting ]',
        (   defined $sent_prompt and $sent_prompt eq join( "\n",
                '[ protocol-7 cloud dispatch ]',
                'you are working in a cloud clone of the protocol-7 '
                    . 'repository [ github nailara-technologies/protocol-7 '
                    . '].',
                "start from branch 'cloud-base' at commit '$fake_sha'.",
                'read CLAUDE.md first and follow its conventions.',
                'note: do not merge to the default branch.',
                'finish with a pushed branch plus a summary of what changed.',
                '',
                'task :',
                $nasty )
        ),
        defined $sent_prompt ? $sent_prompt : '<--cloud value missing>'
    );
    check(
        'preamble carries branch + sha + no-merge rule',
        (           defined $sent_prompt
                and $sent_prompt =~ m{start from branch 'cloud-base'}
                and $sent_prompt =~ m{at commit '$fake_sha'}
                and $sent_prompt =~ m{do not merge to the default branch}
        ),
        defined $sent_prompt ? $sent_prompt : '<--cloud value missing>'
    );
    check(
        'nasty payload survived verbatim inside the single argument',
        ( defined $sent_prompt and index( $sent_prompt, $nasty ) >= 0 ),
        defined $sent_prompt ? $sent_prompt : '<--cloud value missing>'
    );

    check(
        'result parses session id + url and includes raw output',
        !$e
            && $t =~ m{session_id: 3fa85f64-5717-4562-b3fc-2c963f66afa6}
            && $t
            =~ m{url: https://claude\.ai/code/3fa85f64-5717-4562-b3fc-2c963f66afa6}
            && $t =~ m{raw output}
            && index( $t, 'all done' ) >= 0,
        "err=$e text=$t"
    );
    check( 'result names the billed-session fact',
        index( $t, 'BILLED' ) >= 0, $t );

    ## environment param [ 3 elements : --cloud=<task>, --environment, id ] ##
    ( $t, $e )
        = tool_call( 'claude_cloud_dispatch',
        { 'prompt' => 'second task', 'environment' => 'ccpool_test123' } );
    my @claude_argv2 = stub_calls("$tmp_dir/claude-argv.log");
    my $argv2        = $claude_argv2[-1] // [];
    check(
        '--environment passed as its own argv pair',
        (          !$e
                and @$argv2 == 3
                and $argv2->[1] eq '--environment'
                and $argv2->[2] eq 'ccpool_test123'
        ),
        join ' ',
        @$argv2
    );

    ## claude_cloud_status ##
    ( $t, $e )
        = tool_call( 'claude_cloud_status',
        { 'session_id' => '3fa85f64-5717-4562-b3fc-2c963f66afa6' } );
    check(
        'claude_cloud_status returns state + recent output',
        !$e
            && $t =~ m{state: active}
            && index( $t, 'fake cloud terminal output line 1' ) >= 0,
        "err=$e text=$t"
    );
    my @status_argv
        = grep { $_->[0] eq 'logs' } stub_calls("$tmp_dir/claude-argv.log");
    check(
        'status wrapped `claude logs <session_id>`',
        (           @status_argv == 1
                and $status_argv[0][1] eq
                '3fa85f64-5717-4562-b3fc-2c963f66afa6'
        ),
        join ' ',
        @{ $status_argv[0] // [] }
    );
    my @agents_argv
        = grep { $_->[0] eq 'agents' } stub_calls("$tmp_dir/claude-argv.log");
    check(
        'status wrapped `claude agents --json`',
        ( @agents_argv == 1 and $agents_argv[0][1] eq '--json' ),
        join ' ',
        @{ $agents_argv[0] // [] }
    );

    ## status with neither reader named is refused ##
    ( $t, $e ) = tool_call( 'claude_cloud_status', {} );
    check(
        'status without session_id or capture_file is refused',
        $e && index( $t, 'session_id or capture_file is required' ) >= 0,
        "err=$e text=$t"
    );

    ## sentinel : the server is still healthy after all cloud calls ##
    ( $t, $e ) = tool_call( 'p7_command', { 'command' => 'cmd.true' } );
    check(
        'sentinel : server healthy after cloud tools',
        !$e && $t eq 'works',
        "err=$e text=$t"
    );

    kill_server($mcp_pid);
    $mcp_pid = undef;

    ##=============================================================##
    ## phase 2 : unparseable output still returns raw text, no fail  ##
    ##=============================================================##
    {
        local %ENV = %ENV;
        $ENV{'CLAUDE_STUB_MODE'}          = 'garbage';
        $ENV{'GIT_STUB_BRANCH'}           = 'cloud-base';
        $ENV{'GIT_STUB_SHA'}              = $fake_sha;
        $ENV{'GIT_STUB_UNPUSHED'}         = '0';
        $ENV{'GIT_STUB_DIRTY'}            = '';
        $ENV{'PROTOCOL_7_MCP_CLOUD_REPO'} = $root_path;
        $mcp_pid                          = spawn_server();
    }
    unlink "$tmp_dir/claude-argv.log", "$tmp_dir/git-argv.log";

    ( $t, $e )
        = tool_call( 'claude_cloud_dispatch', { 'prompt' => 'anything' } );
    check(
        'unparseable output : isError=0 with explicit not-parsed notes',
        !$e && $t =~ m{session_id: NOT parsed} && $t =~ m{url: NOT parsed},
        "err=$e text=$t"
    );
    check( 'unparseable output : raw text returned',
        index( $t, 'cloud say what? no id here, no url either' ) >= 0, $t );
    my @phase2_git = git_calls("$tmp_dir/git-argv.log");
    check(
        'git identity + push + dirty checks still ran [ 4 git calls ]',
        @phase2_git == 4,
        join ' | ', map { join ' ', @$_ } @phase2_git
    );

    kill_server($mcp_pid);
    $mcp_pid = undef;

    ##=============================================================##
    ## phase 3 : push-first refusal [ stubbed git, deterministic ]   ##
    ##=============================================================##
    {
        local %ENV = %ENV;
        $ENV{'CLAUDE_STUB_MODE'}          = 'cloud';
        $ENV{'GIT_STUB_BRANCH'}           = 'cloud-base';
        $ENV{'GIT_STUB_SHA'}              = $fake_sha;
        $ENV{'GIT_STUB_UNPUSHED'}         = '1';
        $ENV{'PROTOCOL_7_MCP_CLOUD_REPO'} = $root_path;
        $mcp_pid                          = spawn_server();
    }
    unlink "$tmp_dir/claude-argv.log", "$tmp_dir/git-argv.log";

    my $claude_calls_before = scalar stub_calls("$tmp_dir/claude-argv.log");
    ( $t, $e )
        = tool_call( 'claude_cloud_dispatch',
        { 'prompt' => 'should never reach claude' } );
    check(
        'push-first refusal : isError=1 with push first message',
        $e && index( $t, 'push first' ) >= 0,
        "err=$e text=$t"
    );
    check(
        'push-first refusal : claude was never invoked',
        scalar stub_calls("$tmp_dir/claude-argv.log") == $claude_calls_before,
        scalar stub_calls("$tmp_dir/claude-argv.log") . ' claude calls'
    );
    my @phase3_git = git_calls("$tmp_dir/git-argv.log");
    check(
        'push-first refusal : @{u}..HEAD check ran before refusing',
        (   @phase3_git
                and grep {
                join( ' ', @$_ )
                    =~ m{-c color\.ui=false log --oneline --no-color}
                } @phase3_git
        ),
        join ' | ',
        map { join ' ', @$_ } @phase3_git
    );

    kill_server($mcp_pid);
    $mcp_pid = undef;

    ##=============================================================##
    ## phase 4 : push-first against a REAL git repo with unpushed commits ##
    ## [ no stub env answers : delegation all the way down ]              ##
    ##=============================================================##
    {
        local %ENV = %ENV;
        $ENV{'CLAUDE_STUB_MODE'} = 'cloud';
        delete $ENV{'GIT_STUB_BRANCH'};
        delete $ENV{'GIT_STUB_SHA'};
        delete $ENV{'GIT_STUB_UNPUSHED'};
        $ENV{'PROTOCOL_7_MCP_CLOUD_REPO'} = $temp_repo;
        $mcp_pid = spawn_server();
    }
    unlink "$tmp_dir/claude-argv.log", "$tmp_dir/git-argv.log";

    ( $t, $e )
        = tool_call( 'claude_cloud_dispatch',
        { 'prompt' => 'should never reach claude either' } );
    check(
        'push-first refusal : real temp repo, real @{u}..HEAD',
        $e && index( $t, 'push first' ) >= 0 && $t =~ m{local only},
        "err=$e text=$t"
    );
    check(
        'push-first refusal [ temp repo ] : claude was never invoked',
        scalar stub_calls("$tmp_dir/claude-argv.log") == 0,
        scalar stub_calls("$tmp_dir/claude-argv.log") . ' claude calls'
    );

    ## same repo, explicit branch param that has no upstream at all ##
    ( $t, $e )
        = tool_call( 'claude_cloud_dispatch',
        { 'prompt' => 'x', 'branch' => 'no-such-branch' } );
    check(
        'unresolvable branch refused before dispatch',
        $e && index( $t, 'cannot resolve a commit' ) >= 0,
        "err=$e text=$t"
    );

    kill_server($mcp_pid);
    $mcp_pid = undef;

    ##=========================================================##
    ## phase 5 : url after ~1 s, session lingers 30 s DETACHED   ##
    ##=========================================================##
    {
        local %ENV = %ENV;
        $ENV{'CLAUDE_STUB_MODE'}          = 'slowurl';
        $ENV{'GIT_STUB_BRANCH'}           = 'cloud-base';
        $ENV{'GIT_STUB_SHA'}              = $fake_sha;
        $ENV{'GIT_STUB_UNPUSHED'}         = '0';
        $ENV{'GIT_STUB_DIRTY'}            = '';
        $ENV{'PROTOCOL_7_MCP_CLOUD_REPO'} = $root_path;
        $mcp_pid                          = spawn_server();
    }
    unlink "$tmp_dir/claude-argv.log", "$tmp_dir/git-argv.log";

    my $t5start = Time::HiRes::time();
    ( $t, $e )
        = tool_call( 'claude_cloud_dispatch',
        { 'prompt' => 'long cloud task' } );
    my $t5elapsed = Time::HiRes::time() - $t5start;

    my ($pid5) = $t =~ m{pid=(\d+)};
    push @stub_pids, $pid5 if defined $pid5 and $pid5 > 1;
    my ($cap5) = $t =~ m{capture_file: (\S+)};
    push @capture_files, $cap5 if defined $cap5;

    check(
        'slow url : tool returns within a few '
            . 'seconds [ long before the 30 s stub run ]',
        !$e && $t5elapsed < 10,
        sprintf 'err=%s elapsed=%.1fs',
        $e,
        $t5elapsed
    );
    check(
        'slow url : parsed session id + url + status=started',
        !$e
            && $t =~ m{status=started}
            && $t =~ m{session_id: 3fa85f64-5717-4562-b3fc-2c963f66afa6}
            && $t
            =~ m{url: https://claude\.ai/code/3fa85f64-5717-4562-b3fc-2c963f66afa6},
        "err=$e text=$t"
    );
    check( 'slow url : capture file under data/state, kimi-style name',
        $t =~ m{capture_file: \S*/data/state/claude-cloud-\d+-[\d.]+\.out},
        $t );
    check(
        'slow url : detached claude process '
            . 'STILL ALIVE after the tool returned',
        ( defined $pid5 and $pid5 > 1 and kill( 0, $pid5 ) ),
        defined $pid5 ? "pid=$pid5" : 'no pid in reply'
    );

    ## the server must answer an unrelated call immediately afterwards ##
    my $tlstart   = Time::HiRes::time();
    my $tl        = mcp_request( 'tools/list', {} );
    my $tlelapsed = Time::HiRes::time() - $tlstart;
    check(
        'server answers a second tool call '
            . 'immediately [ not blocked on the cloud run ]',
        $tlelapsed < 5,
        sprintf '%.1fs',
        $tlelapsed
    );

    ## the capture-file reader sees the tail, including the late url ##
    ( $t, $e )
        = tool_call( 'claude_cloud_status',
        { 'capture_file' => $cap5 // '/nonexistent' } );
    check(
        'claude_cloud_status(capture_file) : size + parsed url + tail',
        !$e
            && $t =~ m{capture_file: \S+ \[ \d+ bytes \]}
            && $t =~ m{url: https://claude\.ai/code/}
            && index( $t, 'to watch live' ) >= 0,
        "err=$e text=$t"
    );

    kill_server($mcp_pid);
    $mcp_pid = undef;

    ##=========================================================##
    ## phase 6 : never prints a url -> status=starting, no error ##
    ##=========================================================##
    {
        local %ENV = %ENV;
        $ENV{'CLAUDE_STUB_MODE'}          = 'nourl';
        $ENV{'GIT_STUB_BRANCH'}           = 'cloud-base';
        $ENV{'GIT_STUB_SHA'}              = $fake_sha;
        $ENV{'GIT_STUB_UNPUSHED'}         = '0';
        $ENV{'GIT_STUB_DIRTY'}            = '';
        $ENV{'PROTOCOL_7_MCP_CLOUD_REPO'} = $root_path;
        $ENV{'PROTOCOL_7_MCP_CLOUD_POLL'} = '8';
        $mcp_pid                          = spawn_server();
    }
    unlink "$tmp_dir/claude-argv.log", "$tmp_dir/git-argv.log";

    my $t6start = Time::HiRes::time();
    ( $t, $e )
        = tool_call( 'claude_cloud_dispatch',
        { 'prompt' => 'silent cloud task' } );
    my $t6elapsed = Time::HiRes::time() - $t6start;

    my ($pid6) = $t =~ m{pid=(\d+)};
    push @stub_pids, $pid6 if defined $pid6 and $pid6 > 1;
    my ($cap6) = $t =~ m{capture_file: (\S+)};
    push @capture_files, $cap6 if defined $cap6;

    check(
        'no url : returns within the poll cap, not an error',
        !$e && $t6elapsed >= 5 && $t6elapsed < 20,
        sprintf 'err=%s elapsed=%.1fs',
        $e,
        $t6elapsed
    );
    check(
        'no url : status=starting with capture file + pid + recovery hint',
        $t        =~ m{status=starting}
            && $t =~ m{capture_file: \S+}
            && $t =~ m{pid=\d+}
            && index( $t, 'claude_cloud_status(capture_file=' ) >= 0,
        $t
    );
    check(
        'no url : detached process still alive [ url may appear later ]',
        ( defined $pid6 and kill( 0, $pid6 ) ),
        defined $pid6 ? "pid=$pid6" : 'no pid in reply'
    );

    ## the capture-file reader shows the tail even without an id ##
    ( $t, $e )
        = tool_call( 'claude_cloud_status',
        { 'capture_file' => $cap6 // '/nonexistent' } );
    check(
        'claude_cloud_status(capture_file) : tail visible, id not parsed yet',
        !$e
            && index( $t, 'working on it, no link yet' ) >= 0
            && $t =~ m{session_id: NOT parsed from capture file yet},
        "err=$e text=$t"
    );

    ## tuning requested but no id parsed -> skipped + exact send-later cmd ##
    my $calls_before_skip = scalar stub_calls("$tmp_dir/claude-argv.log");
    ( $t, $e ) = tool_call(
        'claude_cloud_dispatch',
        {   'prompt' => 'tuned silent task',
            'effort' => 'low',
            'model'  => 'sonnet',
            'fast'   => 'true'
        }
    );
    my ($cap6b) = $t =~ m{capture_file: (\S+)};
    push @capture_files, $cap6b if defined $cap6b;
    my ($pid6b) = $t =~ m{pid=(\d+)};
    push @stub_pids, $pid6b if defined $pid6b and $pid6b > 1;
    check(
        'no id : tuning SKIPPED with the exact commands to send later',
        !$e
            && $t =~ m{status=starting}
            && index( $t, 'session tuning SKIPPED' ) >= 0
            && index(
            $t,
            'claude -p "/effort low" --cloud '
                . '<session-id> --output-format json'
            ) >= 0
            && index(
            $t,
            'claude -p "/model sonnet" --cloud '
                . '<session-id> --output-format json'
            ) >= 0
            && index( $t,
            'claude -p "/fast" --cloud <session-id> --output-format json' )
            >= 0,
        "err=$e text=$t"
    );
    check(
        'no id : no follow-up was sent [ only the dispatch ran ]',
        scalar stub_calls("$tmp_dir/claude-argv.log")
            == $calls_before_skip + 1,
        scalar stub_calls("$tmp_dir/claude-argv.log") . ' claude calls'
    );

    kill_server($mcp_pid);
    $mcp_pid = undef;

    ##=========================================================##
    ## phase 7 : tuning follow-ups [ effort, model, fast ]       ##
    ##=========================================================##
    {
        local %ENV = %ENV;
        $ENV{'CLAUDE_STUB_MODE'}          = 'cloud';
        $ENV{'GIT_STUB_BRANCH'}           = 'cloud-base';
        $ENV{'GIT_STUB_SHA'}              = $fake_sha;
        $ENV{'GIT_STUB_UNPUSHED'}         = '0';
        $ENV{'GIT_STUB_DIRTY'}            = '';
        $ENV{'PROTOCOL_7_MCP_CLOUD_REPO'} = $root_path;
        $mcp_pid                          = spawn_server();
    }
    unlink "$tmp_dir/claude-argv.log", "$tmp_dir/git-argv.log";

    my $expected_id = '3fa85f64-5717-4562-b3fc-2c963f66afa6';

    ( $t, $e ) = tool_call(
        'claude_cloud_dispatch',
        {   'prompt' => 'tuned task',
            'effort' => 'high',
            'model'  => 'sonnet',
            'fast'   => 'true'
        }
    );
    my @fargv       = stub_calls("$tmp_dir/claude-argv.log");
    my @expected_fu = (
        [   '-p',              '/effort high',
            '--cloud',         $expected_id,
            '--output-format', 'json'
        ],
        [   '-p',              '/model sonnet',
            '--cloud',         $expected_id,
            '--output-format', 'json'
        ],
        [ '-p', '/fast', '--cloud', $expected_id, '--output-format', 'json' ],
    );
    check(
        'tuning : dispatch + 3 follow-ups = 4 claude calls',
        !$e && @fargv == 4,
        scalar @fargv . ' calls'
    );
    check(
        'tuning : follow-up argv exact list, order effort, model, fast',
        (   @fargv == 4
                and join( '|', @{ $fargv[1] } ) eq
                join( '|', @{ $expected_fu[0] } )
                and join( '|', @{ $fargv[2] } ) eq
                join( '|', @{ $expected_fu[1] } )
                and join( '|', @{ $fargv[3] } ) eq
                join( '|', @{ $expected_fu[2] } )
        ),
        join ' ;; ',
        map { join ' ', @$_ } @fargv
    );
    check(
        'tuning : reply reports each follow-up ok',
        !$e
            && index( $t, 'follow-up /effort high : ok' ) >= 0
            && index( $t, 'follow-up /model sonnet : ok' ) >= 0
            && index( $t, 'follow-up /fast : ok' ) >= 0,
        $t
    );

    ## fast only when true : effort alone sends exactly one follow-up ##
    ( $t, $e )
        = tool_call( 'claude_cloud_dispatch',
        { 'prompt' => 'effort only', 'effort' => 'low' } );
    my @fargv2    = stub_calls("$tmp_dir/claude-argv.log");
    my @new_calls = @fargv2[ 4 .. $#fargv2 ];    ## added by this dispatch ##
    my $fast_new
        = grep { $_->[0] eq '-p' and $_->[1] eq '/fast' } @new_calls;
    check(
        'fast only when true : no /fast follow-up without fast=true',
        !$e
            && @fargv2 == 6
            && @new_calls == 2
            && $new_calls[1][1] eq '/effort low'
            && $fast_new == 0,
        join ' ;; ',
        map { join ' ', @$_ } @new_calls
    );

    ## fast="false" must not toggle fast mode [ a '//' vs 'eq' precedence ##
    ## slip once read any defined value as true ]                         ##
    my $fast_before = grep { $_->[0] eq '-p' and $_->[1] eq '/fast' }
        stub_calls("$tmp_dir/claude-argv.log");
    ( $t, $e )
        = tool_call( 'claude_cloud_dispatch',
        { 'prompt' => 'fast false', 'effort' => 'low', 'fast' => 'false' } );
    my $fast_after = grep { $_->[0] eq '-p' and $_->[1] eq '/fast' }
        stub_calls("$tmp_dir/claude-argv.log");
    check(
        'fast="false" : no /fast follow-up',
        !$e && $fast_after == $fast_before,
        "before $fast_before after $fast_after"
    );

    ## nothing sent when no tuning param is given ##
    my $calls_before_plain = scalar stub_calls("$tmp_dir/claude-argv.log");
    ( $t, $e )
        = tool_call( 'claude_cloud_dispatch', { 'prompt' => 'plain' } );
    my @fargv3 = stub_calls("$tmp_dir/claude-argv.log");
    check(
        'no tuning params : no follow-up sent, account default stays',
        !$e
            && @fargv3 == $calls_before_plain + 1    ## the creation only ##
            && index( $t, 'follow-up' ) < 0,
        scalar @fargv3 . ' calls'
    );

    ## invalid effort / model refused before anything runs ##
    my $claude_before_invalid = scalar stub_calls("$tmp_dir/claude-argv.log");
    my $git_before_invalid    = scalar git_calls("$tmp_dir/git-argv.log");
    ( $t, $e )
        = tool_call( 'claude_cloud_dispatch',
        { 'prompt' => 'x', 'effort' => 'sideways' } );
    check(
        'invalid effort refused before anything runs',
        $e
            && index( $t, "invalid effort 'sideways'" ) >= 0
            && scalar stub_calls("$tmp_dir/claude-argv.log")
            == $claude_before_invalid
            && scalar git_calls("$tmp_dir/git-argv.log")
            == $git_before_invalid,
        "err=$e text=$t"
    );
    ( $t, $e )
        = tool_call( 'claude_cloud_dispatch',
        { 'prompt' => 'x', 'model' => 'x; rm -rf' } );
    check(
        'invalid model refused [ shell-shaped name never dispatched ]',
        $e
            && index( $t, 'invalid model' ) >= 0
            && scalar stub_calls("$tmp_dir/claude-argv.log")
            == $claude_before_invalid
            && scalar git_calls("$tmp_dir/git-argv.log")
            == $git_before_invalid,
        "err=$e text=$t"
    );

    kill_server($mcp_pid);
    $mcp_pid = undef;

    ##=========================================================##
    ## phase 7b : follow-up json error reported                  ##
    ##=========================================================##
    {
        local %ENV = %ENV;
        $ENV{'CLAUDE_STUB_MODE'}          = 'followuperr';
        $ENV{'GIT_STUB_BRANCH'}           = 'cloud-base';
        $ENV{'GIT_STUB_SHA'}              = $fake_sha;
        $ENV{'GIT_STUB_UNPUSHED'}         = '0';
        $ENV{'GIT_STUB_DIRTY'}            = '';
        $ENV{'PROTOCOL_7_MCP_CLOUD_REPO'} = $root_path;
        $mcp_pid                          = spawn_server();
    }
    unlink "$tmp_dir/claude-argv.log", "$tmp_dir/git-argv.log";

    ( $t, $e )
        = tool_call( 'claude_cloud_dispatch',
        { 'prompt' => 'x', 'effort' => 'low' } );
    check(
        'follow-up json error reported [ session itself still fine ]',
        !$e && $t =~ m{status=started} && index(
            $t,
            'follow-up /effort low : error '
                . '[ simulated follow-up failure ]'
        ) >= 0,
        "err=$e text=$t"
    );

    kill_server($mcp_pid);
    $mcp_pid = undef;

    ##=========================================================##
    ## phase 8 : dirty-tree refusal [ real repo, delegation ]    ##
    ##=========================================================##
    {
        open( my $fh, '>>', "$temp_repo2/f" ) or die $!;
        print {$fh} "uncommitted change\n";
        close $fh;
    }
    {
        local %ENV = %ENV;
        $ENV{'CLAUDE_STUB_MODE'} = 'cloud';
        delete $ENV{'GIT_STUB_BRANCH'};
        delete $ENV{'GIT_STUB_SHA'};
        delete $ENV{'GIT_STUB_UNPUSHED'};
        delete $ENV{'GIT_STUB_DIRTY'};
        $ENV{'PROTOCOL_7_MCP_CLOUD_REPO'} = $temp_repo2;
        $mcp_pid = spawn_server();
    }
    unlink "$tmp_dir/claude-argv.log", "$tmp_dir/git-argv.log";

    ( $t, $e )
        = tool_call( 'claude_cloud_dispatch', { 'prompt' => 'dirty work' } );
    check(
        'dirty tree : refused with uncommitted-changes error',
        $e
            && index( $t, 'uncommitted changes in tracked files' ) >= 0
            && index( $t, 'commit or stash them first' ) >= 0,
        "err=$e text=$t"
    );
    check(
        'dirty tree : claude was never invoked',
        scalar stub_calls("$tmp_dir/claude-argv.log") == 0,
        scalar stub_calls("$tmp_dir/claude-argv.log") . ' claude calls'
    );

    ## the string "false" is no permission [ a '//' vs 'eq' precedence slip ##
    ## once read any defined value as true ]                                ##
    ( $t, $e )
        = tool_call( 'claude_cloud_dispatch',
        { 'prompt' => 'dirty work', 'allow_dirty' => 'false' } );
    check(
        'allow_dirty="false" : still refused',
        $e && index( $t, 'uncommitted changes in tracked files' ) >= 0,
        "err=$e text=$t"
    );

    ( $t, $e )
        = tool_call( 'claude_cloud_dispatch',
        { 'prompt' => 'dirty work', 'allow_dirty' => 'true' } );
    check(
        'allow_dirty=true : passes with a warning',
        !$e
            && $t =~ m{status=started}
            && index( $t, 'warning: allow_dirty=true' ) >= 0,
        "err=$e text=$t"
    );

    kill_server($mcp_pid);
    $mcp_pid = undef;
};
my $eval_err = $@;

kill_server($mcp_pid) if $mcp_pid;
kill 'TERM', $srv_pid if $srv_pid;

## kill the DETACHED stub claude processes                            ##
## [ the whole point of the async  ] model is that they outlive their ##
## servers — cleanup is explicitly on us ]                            ##
my $stubs_dead = 1;
kill 'TERM', $_ for @stub_pids;
for my $spid (@stub_pids) {
    my $gone = 0;
    for ( 1 .. 50 ) {
        if ( not kill( 0, $spid ) ) { $gone = 1; last; }
        Time::HiRes::sleep(0.1);
    }
    $stubs_dead = 0 if not $gone;
}
check( 'detached stub claude processes killed at cleanup',
    $stubs_dead, join ' ', map { $_ // '?' } @stub_pids );

## unlink the capture files the dispatches created [ under the real      ]##
## repo's data/state when running unmutated — leave no litter behind     ]##
unlink @capture_files, map {"$_.pid"} @capture_files;

## and every other capture this run created [ the plain dispatch cases ] : new
## since the start AND stub output -- a real cloud run started meanwhile is
## never removed
for my $capture ( glob("$root_path/data/state/claude-cloud-*.out") ) {
    next if $captures_before{$capture};
    open my $fh, q{<}, $capture or next;
    my $first = <$fh> // q{};
    close $fh;
    next if $first !~ m{^(?:created claude cloud session|cloud say what)};
    unlink $capture, "$capture.pid";
}

die "harness error : $eval_err" if $eval_err;

printf "\n%d passed, %d failed\n", $pass, $fail;
exit( $fail ? 1 : 0 );

## the mutation runs [ see task ] drive this same file with P7_MCP_SERVER_PL
## pointing at a mutated server copy and expect the targeted checks to FAIL :
## 1. command built as a shell string  -> 'injection sentinel' FAILs
## 2. push-first check dropped         -> 'push first' checks FAIL
## 3. poll cap replaced by wait-exit   -> 'returns early / still alive' FAIL
## 4. /fast always sent                -> 'fast only when true' FAILs
## 5. dirty-tree check dropped         -> 'dirty tree' checks FAIL

#,,.,,,..,..,,,,,,...,..,,,,.,..,,,,,,...,,.,,..,,...,...,...,..,,,,.,..,,..,,
#IACE5CDTW7HC2MIL7WQJK2DBFD245JBPZIQE6VUOSFIQPE2H7XGQAPEFTLPK4OOAVK5IJ3FJLQ6ZG
#\\\|6B4JQWOT3WT2WHXD3IBRMAF7F62RCTNOZY3WZFJDZZADKKDM43O \ / AMOS7 \ YOURUM ::
#\[7]USJXEPQIKO4ALW2ZBBRRN2WU5IJKPAUSRNMP3XUZD3PS5CS4DQAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
