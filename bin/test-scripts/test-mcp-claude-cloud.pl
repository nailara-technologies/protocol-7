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
## - claude_cloud_status wraps `claude agents --json` + `claude logs` for
## non-cloud ids ; a CLOUD id [ session_… / cse_… ] makes no agents / logs
## call and gets the url + teleport hint instead
## - claude_cloud_result : branch picker listing + log / diffstat / full
## newest commit message against a REAL temp repo with a bare 'hub' remote,
## HEAD + working tree asserted unchanged, bad names refused before any git
## call, and an inline MUTATION run
## [ result copy whose fetch became a checkout ] proving the unchanged-HEAD
## assertion bites
##
## env knobs [ also used by the mutation runs ] :  P7_MCP_SERVER_PL  -- run a
## different server copy [ mutated or not ] PERL5LIB          -- needed when
## the server copy lives outside the repo
## [ compile-time AMOS7/Digest::BMW requires ]  launch-clone notes : every
## dispatch now runs claude from a launch clone at
## <root>/data/state/cloud-launch/protocol-7. the github-url check is
## overridable for tests ONLY via PROTOCOL_7_MCP_CLOUD_GITHUB_HOSTS [
## comma-separated extra url prefixes — the tests substitute local bare repos
## for github ] ; PROTOCOL_7_MCP_CLOUD_REMOTE picks a non-'hub' remote name.
##
## usage : perl bin/test-scripts/test-mcp-claude-cloud.pl

use strict;
use warnings;
use JSON::PP;
use IO::Socket::UNIX;
use IO::Select;
use IPC::Open3;
use File::Temp qw| tempdir |;
use File::Path qw| remove_tree |;
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
use Cwd qw| getcwd |;
$| = 1;    ## model a well-behaved streaming cli : no stdio block-buffering on the capture file ##
my $log = $ENV{'CLAUDE_STUB_LOG'} or die "CLAUDE_STUB_LOG not set\n";
open my $fh, '>>', $log or die "stub log : $!\n";
print {$fh} JSON::PP->new->canonical->encode( \@ARGV ), "\n";
print {$fh} "CWD\t" . getcwd() . "\n";
close $fh;
my $mode   = $ENV{'CLAUDE_STUB_MODE'} // 'cloud';
my $linger = $ENV{'STUB_LINGER'}      // 30;
## like the real cli : creating a cloud session needs a terminal [ the  ##
## follow-ups via -p do not ] -- passes only through the script pty     ##
if ( $mode eq 'notty'
    or ( @ARGV and $ARGV[0] =~ m{^--cloud=} and not -t STDOUT ) )
{
    print "Error: --cloud requires an interactive terminal.\n";
    print "Non-interactive invocations (piped stdout, --init-only, "
        . "--sdk-url) run locally and would silently ignore --cloud. "
        . "Drop --cloud, or run from a TTY.\n";
    exit 1;
}
if ( $mode eq 'ansi' ) {
    ## a pty run : colour, cursor and carriage-return codes around the id ##
    print "\e[?25l\e[1m\e[38;5;141mcreated cloud session\e[0m\r\n";
    print "\e[2KSession ID: \e[36msession_01AnsiWrapped9k\e[0m\r\n";
    print "View: \e]8;;https://claude.ai/code/session_01AnsiWrapped9k\a"
        . "\e[4mhttps://claude.ai/code/session_01AnsiWrapped9k\e[24m"
        . "\e]8;;\a\r\n\e[?25h";
    exit 0;
}
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
    ## the server to run : the env override wins                            ##
    ## [ mutation runs point it  ] at a mutated copy of this file — see the ##
    ## notes at the bottom ]                                                ##
    my $srv_pl   = $ENV{'P7_MCP_SERVER_PL'} // $server_pl;
    my $stub_dir = "$tmp_dir/stubbin";
    local %ENV = %ENV;
    $ENV{'PATH'}                 = "$stub_dir:$ENV{'PATH'}";
    $ENV{'PROTOCOL_7_UNIX_PATH'} = "$tmp_dir/cube.sock";
    $ENV{'P7_REAL_GIT'}          = $real_git;
    $ENV{'CLAUDE_STUB_LOG'}      = "$tmp_dir/claude-argv.log";
    $ENV{'GIT_STUB_LOG'}         = "$tmp_dir/git-argv.log";
    ## a server COPY outside the repo cannot find data/lib-path/pm via its ##
    ## own FindBin — give it the lib path for its compile-time AMOS7 /     ##
    ## Digest::BMW requires                                                ##
    $ENV{'PERL5LIB'}
        = "$root_path/data/lib-path/pm"
        . ( length( $ENV{'PERL5LIB'} // '' ) ? ":$ENV{'PERL5LIB'}" : '' );

    my $pid = open3( $srv_wtr, $srv_rdr, '>&STDERR', $srv_pl );
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

## the CWD lines the stub recorded [ one per invocation, after its argv ] ##
sub stub_cwds {
    my ($file) = @_;
    my @cwds;
    if ( open( my $fh, '<', $file ) ) {
        while ( my $line = <$fh> ) {
            push @cwds, $1 if $line =~ m{\ACWD\t(.+?)\n?\z};
        }
        close $fh;
    }
    return @cwds;
}

## list-form git output capture [ snapshots for the unchanged-HEAD checks ]##
sub git_capture {
    my @cmd = @_;
    open( my $fh, '-|', @cmd ) or die "cannot run @cmd : $!";
    my $out = do { local $/ = undef; <$fh> }
        // '';
    close $fh;
    return $out;
}

sub head_of {
    my ($repo) = @_;
    my $out = git_capture( $real_git, '-C', $repo, 'rev-parse', 'HEAD' );
    chomp $out;
    return $out;
}

sub porcelain_of {
    my ($repo) = @_;
    return git_capture( $real_git, '-C', $repo, 'status', '--porcelain' );
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

## third throwaway repo : a bare remote named 'hub' + a PUSHED feature    ##
## branch with two commits [ the claude_cloud_result target ] — HEAD sits ##
## on 'base' so the tool's base default is exercised for real             ##
my $result_remote = tempdir( 'p7-cld-hub-XXXX',   TMPDIR => 1, CLEANUP => 1 );
my $result_repo   = tempdir( 'p7-cld-repo3-XXXX', TMPDIR => 1, CLEANUP => 1 );
system( $real_git, 'init', '-q', '--bare', "$result_remote/hub.git" ) == 0
    or die "bare init failed";
system( $real_git, '-C', $result_repo, 'init', '-q' ) == 0 or die "repo init";
system( $real_git, '-C', $result_repo, 'config', 'user.email', 't@example' );
system( $real_git, '-C', $result_repo, 'config', 'user.name',  't' );
system( $real_git, '-C', $result_repo, 'branch', '-M',         'base' ) == 0
    or die "branch rename failed";
{
    open( my $fh, '>', "$result_repo/f" ) or die $!;
    print {$fh} "base\n";
    close $fh;
}
system( $real_git, '-C', $result_repo, 'add', 'f' ) == 0 or die $!;
{
    ## distinct committer dates : the branch-picker sorts by committerdate, ##
    ## and same-second commits tie with an unspecified order otherwise      ##
    local $ENV{'GIT_COMMITTER_DATE'} = '2026-10-10T12:00:00 +0200';
    system( $real_git, '-C', $result_repo, 'commit', '-qm', 'base commit' )
        == 0
        or die $!;
}
system( $real_git, '-C', $result_repo, 'remote', 'add', 'hub',
    "$result_remote/hub.git" ) == 0
    or die $!;
system( $real_git, '-C', $result_repo, 'push', '-qu', 'hub', 'base' ) == 0
    or die $!;
system( $real_git, '-C', $result_repo, 'checkout', '-qb', 'cloud-result' )
    == 0
    or die $!;
{
    open( my $fh, '>>', "$result_repo/f" ) or die $!;
    print {$fh} "feature line\n";
    close $fh;
}
{
    local $ENV{'GIT_COMMITTER_DATE'} = '2026-10-12T12:00:00 +0200';
    system( $real_git, '-C', $result_repo, 'commit', '-qam',
        'feature work one' ) == 0
        or die $!;
}
{
    open( my $fh, '>', "$result_repo/result.feature" ) or die $!;
    print {$fh} "new feature file\n";
    close $fh;
}
system( $real_git, '-C', $result_repo, 'add', 'result.feature' ) == 0
    or die $!;
{
    local $ENV{'GIT_COMMITTER_DATE'} = '2026-10-14T12:00:00 +0200';
    system( $real_git, '-C', $result_repo, 'commit', '-qm',
              "cloud session summary\n\nimplemented "
            . "the thing\nverified the other thing" ) == 0
        or die $!;
}
system( $real_git, '-C', $result_repo, 'push', '-qu', 'hub', 'cloud-result' )
    == 0
    or die $!;
system( $real_git, '-C', $result_repo, 'checkout', '-q', 'base' ) == 0
    or die $!;

## fourth throwaway repo : the LAUNCH-CLONE source — a bare 'hub' remote   ##
## with a single fully-pushed clean branch 'cloud-base' and CLAUDE.md at   ##
## the root [ the launch clone sparse-checkouts it ]. the github-url check ##
## accepts these local urls via the TEST-ONLY override below               ##
my $launch_remote
    = tempdir( 'p7-cld-lremote-XXXX', TMPDIR => 1, CLEANUP => 1 );
my $launch_repo = tempdir( 'p7-cld-lrepo-XXXX', TMPDIR => 1, CLEANUP => 1 );
system( $real_git, 'init', '-q', '--bare', "$launch_remote/launch.git" ) == 0
    or die "bare init failed";
system( $real_git, '-C', $launch_repo, 'init',   '-q' ) == 0 or die $!;
system( $real_git, '-C', $launch_repo, 'config', 'user.email', 't@example' );
system( $real_git, '-C', $launch_repo, 'config', 'user.name',  't' );
{
    open( my $fh, '>', "$launch_repo/CLAUDE.md" ) or die $!;
    print {$fh} "# launch clone test repo\n";
    close $fh;
}
system( $real_git, '-C', $launch_repo, 'add', 'CLAUDE.md' ) == 0 or die $!;
system( $real_git, '-C', $launch_repo, 'commit', '-qm', 'init' ) == 0
    or die $!;
system( $real_git, '-C', $launch_repo, 'branch', '-M', 'cloud-base' ) == 0
    or die $!;
system( $real_git, '-C', $launch_repo, 'remote', 'add', 'hub',
    "$launch_remote/launch.git" ) == 0
    or die $!;
system( $real_git, '-C', $launch_repo, 'push', '-qu', 'hub', 'cloud-base' )
    == 0
    or die $!;

## where the server's launch clone will live                                ##
## [ server's ROOT_PATH == the    ] repo root for the unmutated runs ] +    ##
## whether it predates this run the launch clone lives in this run's temp   ##
## dir [ the server reads PROTOCOL_7_MCP_CLOUD_LAUNCH_DIR ] : a real launch ##
## clone under data/state is never reused, fetched into or removed by this  ##
## test                                                                     ##
my $launch_dir = "$tmp_dir/cloud-launch/protocol-7";
$ENV{'PROTOCOL_7_MCP_CLOUD_LAUNCH_DIR'} = $launch_dir;
my $launch_preexisting = -d $launch_dir;
my $launch_sha         = head_of($launch_repo);

## the TEST-ONLY github-url override : accept the local bare urls           ##
$ENV{'PROTOCOL_7_MCP_CLOUD_GITHUB_HOSTS'}
    = "$launch_remote/launch.git,$bare_remote/remote.git";

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
        $ENV{'PROTOCOL_7_MCP_CLOUD_REPO'} = $launch_repo;
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
        ## the preamble wording may change ; the task must arrive whole, ##
        ## after 'task :', inside the one --cloud argument               ##
        (   defined $sent_prompt
                and
                index( $sent_prompt, '[ protocol-7 ' . 'cloud dispatch ]' )
                == 0
                and substr( $sent_prompt, -length("task :\n$nasty") ) eq
                "task :\n$nasty"
        ),
        defined $sent_prompt ? $sent_prompt : '<--cloud value missing>'
    );
    check(
        'preamble carries branch + sha + no-merge rule',
        (           defined $sent_prompt
                and $sent_prompt =~ m{start from branch 'cloud-base'}
                and $sent_prompt =~ m{at commit '$launch_sha'}
                and $sent_prompt =~ m{do not\s+merge to the default branch}
        ),
        defined $sent_prompt ? $sent_prompt : '<--cloud value missing>'
    );
    check(
        'preamble : push path proven before any work '
            . '[ remote, history, empty dev branch pushed ]',
        (           defined $sent_prompt
                and $sent_prompt =~ m{BEFORE any work, prove the push path}
                and $sent_prompt =~ m{`git remote -v`}
                and $sent_prompt =~ m{attach the github repository with write}
                and $sent_prompt =~ m{single snapshot commit without history}
                and $sent_prompt
                =~ m{'dev/<topic>' from '$launch_sha' and push}
                and $sent_prompt =~ m{never to 'cloud-base'}
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

    ## launch clone [ created by this first dispatch ] ##
    my @cwds1 = stub_cwds("$tmp_dir/claude-argv.log");
    check(
        'launch clone : stub claude cwd IS the launch clone',
        ( @cwds1 == 1 and $cwds1[0] eq $launch_dir ),
        "cwds=@cwds1"
    );
    check(
        'launch clone : reply names the clone path + its HEAD',
        (           index( $t, "launch_clone: $launch_dir" ) >= 0
                and index( $t, "launch_clone_head: $launch_sha" ) >= 0
        ),
        $t
    );
    check( 'launch clone : created on first dispatch',
        -d "$launch_dir/.git", $launch_dir );
    check(
        'launch clone : origin is the hub url',
        git_capture( $real_git, '-C', $launch_dir,
            'remote', 'get-url', 'origin' ) eq "$launch_remote/launch.git\n",
        git_capture(
            $real_git, '-C', $launch_dir, 'remote', 'get-url', 'origin'
        )
    );
    check(
        'launch clone : HEAD is the dispatched sha on the branch name',
        (   head_of($launch_dir) eq $launch_sha
                and git_capture( $real_git, '-C', $launch_dir,
                'symbolic-ref', 'HEAD' ) eq "refs/heads/cloud-base\n"
        ),
        head_of($launch_dir) . ' vs ' . $launch_sha
    );
    check(
        'launch clone : sparse one-file worktree, clean status',
        (           -f "$launch_dir/CLAUDE.md"
                and not -e "$launch_dir/bin"
                and git_capture( $real_git, '-C', $launch_dir,
                'status', '--porcelain' ) eq ''
        ),
        join ' ',
        map { $_ // '?' } glob("$launch_dir/*")
    );
    check(
        'checkout grew NO origin remote',
        git_capture(
            $real_git,    '-C',
            $launch_repo, 'config',
            '--get',      'remote.origin.url'
        ) eq '',
        'origin url : '
            . git_capture(
            $real_git,    '-C',
            $launch_repo, 'config',
            '--get',      'remote.origin.url'
            )
    );

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
        $ENV{'PROTOCOL_7_MCP_CLOUD_REPO'} = $launch_repo;
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
    my @phase2_git  = git_calls("$tmp_dir/git-argv.log");
    my @phase2_join = map { join ' ', @$_ } @phase2_git;
    check(
        'git identity + push + dirty checks still ran on the checkout',
        (   ( grep { $_ eq 'branch --show-current' } @phase2_join )
                && ( grep {m{\Arev-parse --verify --quiet HEAD\z}}
                @phase2_join )
                && ( grep {m{log --oneline --no-color }} @phase2_join )
                && ( grep {m{status --porcelain }} @phase2_join )
        ),
        join ' | ',
        @phase2_join
    );
    check(
        'launch clone reused : no second clone on later dispatches',
        ( not grep { $_->[0] eq 'clone' } @phase2_git )
            && ( grep { $_->[0] eq 'fetch' } @phase2_git ),
        join ' | ',
        map { join ' ', @$_ } @phase2_git
    );

    kill_server($mcp_pid);
    $mcp_pid = undef;

    ##=============================================================##
    ## phase 2b : pty output -- escape codes around the id \ url [ the stub ##
    ## refuses creation without a terminal, so every passing dispatch in    ##
    ## this file went through the script pty ]                              ##
    ##=============================================================##
    for my $stub_mode (qw| ansi notty |) {
        {
            local %ENV = %ENV;
            $ENV{'CLAUDE_STUB_MODE'}          = $stub_mode;
            $ENV{'PROTOCOL_7_MCP_CLOUD_REPO'} = $launch_repo;
            $mcp_pid                          = spawn_server();
        }
        unlink "$tmp_dir/claude-argv.log", "$tmp_dir/git-argv.log";
        ( $t, $e )
            = tool_call( 'claude_cloud_dispatch',
            { 'prompt' => "pty $stub_mode" } );
        if ( $stub_mode eq 'ansi' ) {
            check(
                'pty output : id + url parsed through colour \ cursor codes',
                !$e
                    && $t =~ m{status=started}
                    && index( $t, 'session_01AnsiWrapped9k' ) >= 0
                    && $t
                    =~ m{url: https://claude\.ai/code/session_01AnsiWrapped9k\b},
                "err=$e text=$t"
            );
            check( 'pty output : raw text shown without escape codes',
                index( $t, "\e" ) < 0, $t );
        } else {
            check(
                'no terminal : reply says nothing started, nothing billed',
                index( $t, 'nothing started, nothing billed' ) >= 0
                    && index( $t, 'STARTED A BILLED' ) < 0,
                "err=$e text=$t"
            );
        }
        kill_server($mcp_pid);
        $mcp_pid = undef;
    }

    ##=========================================================##
    ## phase 2c : launch-clone reuse + HEAD follows the dispatch  ##
    ##=========================================================##
    {
        local %ENV = %ENV;
        $ENV{'CLAUDE_STUB_MODE'}          = 'cloud';
        $ENV{'PROTOCOL_7_MCP_CLOUD_REPO'} = $launch_repo;
        $mcp_pid                          = spawn_server();
    }
    unlink "$tmp_dir/claude-argv.log", "$tmp_dir/git-argv.log";

    ## a new commit on the branch, pushed — the dispatched sha must move ##
    {
        open( my $fh, '>>', "$launch_repo/CLAUDE.md" ) or die $!;
        print {$fh} "more\n";
        close $fh;
    }
    system( $real_git, '-C', $launch_repo, 'commit', '-qam', 'two' ) == 0
        or die $!;
    system( $real_git, '-C', $launch_repo, 'push', '-q' ) == 0 or die $!;
    $launch_sha = head_of($launch_repo);

    ( $t, $e )
        = tool_call( 'claude_cloud_dispatch',
        { 'prompt' => 'reuse the launch clone' } );

    my @phase2c_git = git_calls("$tmp_dir/git-argv.log");
    check(
        'reuse : second dispatch fetches, never re-clones',
        !$e
            && ( not grep { $_->[0] eq 'clone' } @phase2c_git )
            && ( grep { $_->[0] eq 'fetch' } @phase2c_git ),
        join ' | ',
        map { join ' ', @$_ } @phase2c_git
    );
    check(
        'reuse : launch HEAD moved to the new dispatched sha',
        (   head_of($launch_dir) eq $launch_sha
                and git_capture( $real_git, '-C', $launch_dir,
                'symbolic-ref', 'HEAD' ) eq "refs/heads/cloud-base\n"
        ),
        head_of($launch_dir) . ' vs ' . $launch_sha
    );
    check(
        'reuse : reply names the clone + its current head',
        (           index( $t, "launch_clone: $launch_dir" ) >= 0
                and index( $t, "launch_clone_head: $launch_sha" ) >= 0
        ),
        $t
    );

    kill_server($mcp_pid);
    $mcp_pid = undef;

    ##=========================================================##
    ## phase 2d : a non-github hub url is refused before anything starts [ ##
    ## the result repo's hub is a local bare repo and the TEST-ONLY        ##
    ## override is removed for this phase ]                                ##
    ##=========================================================##
    {
        local %ENV = %ENV;
        $ENV{'CLAUDE_STUB_MODE'} = 'cloud';
        delete $ENV{'PROTOCOL_7_MCP_CLOUD_GITHUB_HOSTS'};
        $ENV{'PROTOCOL_7_MCP_CLOUD_REPO'} = $result_repo;
        $mcp_pid = spawn_server();
    }
    unlink "$tmp_dir/claude-argv.log", "$tmp_dir/git-argv.log";

    ( $t, $e )
        = tool_call( 'claude_cloud_dispatch',
        { 'prompt' => 'should never reach claude' } );
    check(
        'non-github remote : refused before anything starts',
        $e && index( $t, 'not a GitHub URL' ) >= 0,
        "err=$e text=$t"
    );
    check(
        'non-github remote : claude was never invoked',
        scalar stub_calls("$tmp_dir/claude-argv.log") == 0,
        scalar stub_calls("$tmp_dir/claude-argv.log") . ' claude calls'
    );
    check(
        'non-github remote : the existing launch clone was untouched',
        git_capture( $real_git, '-C', $launch_dir,
            'remote', 'get-url', 'origin' ) eq "$launch_remote/launch.git\n",
        git_capture(
            $real_git, '-C', $launch_dir, 'remote', 'get-url', 'origin'
        )
    );

    kill_server($mcp_pid);
    $mcp_pid = undef;

    ##=========================================================##
    ## phase 2e : MUTATION-CHECK — a copy that starts claude from the ##
    ## CHECKOUT again must trip the launch-clone cwd assert           ##
    ##=========================================================##
    my $mut1_dir = "$tmp_dir/mut1";
    my $mut1     = "$mut1_dir/mcp-server-p7";
    {
        open( my $fh, '<', $server_pl ) or die "cannot read $server_pl : $!";
        my $src = do { local $/ = undef; <$fh> };
        close $fh;
        ## the mutation : the detached worker chdirs to the checkout    ##
        ## instead of the launch clone [ one substitution, one anchor ] ##
        my $hits = $src
            =~ s/_cloud_fork_run\( \\\@cmd, \$launch_dir \)/_cloud_fork_run( \\\@cmd, \$repo )/;
        die "mutation anchor not found in $server_pl" unless $hits == 1;
        mkdir $mut1_dir             or die $!;
        open( my $out, '>', $mut1 ) or die "cannot write $mut1 : $!";
        print {$out} $src;
        close $out;
        chmod 0755, $mut1;
    }
    {
        local %ENV = %ENV;
        $ENV{'P7_MCP_SERVER_PL'}          = $mut1;
        $ENV{'CLAUDE_STUB_MODE'}          = 'cloud';
        $ENV{'PROTOCOL_7_MCP_CLOUD_REPO'} = $launch_repo;
        $mcp_pid                          = spawn_server();
    }
    unlink "$tmp_dir/claude-argv.log";

    ( $t, $e )
        = tool_call( 'claude_cloud_dispatch',
        { 'prompt' => 'mutated cwd dispatch' } );
    my @mut1_cwds = stub_cwds("$tmp_dir/claude-argv.log");
    check(
        'MUTATION [ cwd -> checkout ] : claude started from the '
            . 'CHECKOUT — the launch-clone cwd assertion FAILS as designed',
        !$e && @mut1_cwds == 1 && $mut1_cwds[0] eq $launch_repo,
        "err=$e cwd=@mut1_cwds"
    );

    kill_server($mcp_pid);
    $mcp_pid = undef;

    ##=========================================================##
    ## phase 2f : MUTATION-CHECK — with the launch clone neither pointed at ##
    ## nor verified against the dispatched commit, a wrong HEAD reaches     ##
    ## claude : the HEAD == sha assertion FAILS as designed                 ##
    ##=========================================================##
    my $mut2_dir = "$tmp_dir/mut2";
    my $mut2     = "$mut2_dir/mcp-server-p7";
    {
        open( my $fh, '<', $server_pl ) or die "cannot read $server_pl : $!";
        my $src = do { local $/ = undef; <$fh> };
        close $fh;
        ## the mutation : update-ref retargeted to a canary ref      ##
        ## [ the branch never moves ] + the HEAD == sha gate removed ##
        my $anchor2 = q|) if ( $launch_head // '' ) ne $sha;|;
        my $hits    = $src
            =~ s/"refs\/heads\/\$branch", \$sha/"refs\/heads\/p7-mut-canary", \$sha/;
        die "mutation anchor 1 not found in $server_pl" unless $hits == 1;
        $hits = $src =~ s/\Q$anchor2\E/) if 0;/;
        die "mutation anchor 2 not found in $server_pl" unless $hits == 1;
        mkdir $mut2_dir             or die $!;
        open( my $out, '>', $mut2 ) or die "cannot write $mut2 : $!";
        print {$out} $src;
        close $out;
        chmod 0755, $mut2;
    }
    {
        local %ENV = %ENV;
        $ENV{'P7_MCP_SERVER_PL'}          = $mut2;
        $ENV{'CLAUDE_STUB_MODE'}          = 'cloud';
        $ENV{'PROTOCOL_7_MCP_CLOUD_REPO'} = $launch_repo;
        $mcp_pid                          = spawn_server();
    }
    unlink "$tmp_dir/claude-argv.log";

    ## the SHARED launch clone, still at the older commit of the earlier  ##
    ## phases -- a fresh clone would sit at the tip and hide the mutation ##
    my $mut2_launch = $launch_dir;

    ## the branch moves on first [ an empty commit, pushed ] : the mutated ##
    ## server fetches it but only moves its canary ref, so the launch      ##
    ## clone's HEAD provably stays behind the dispatched commit -- without ##
    ## this, a clone already at the tip would hide the mutation            ##
    system( $real_git, '-C', $launch_repo, 'commit', '-q', '--allow-empty',
        '-m', 'mut2 advance' ) == 0
        or die "mut2 advance commit : $!";
    system( $real_git, '-C', $launch_repo, 'push', '-q', 'hub', 'cloud-base' )
        == 0
        or die "mut2 advance push : $!";
    my $mut2_sha = head_of($launch_repo);
    ( $t, $e )
        = tool_call( 'claude_cloud_dispatch',
        { 'prompt' => 'mutated head dispatch' } );
    check(
        'MUTATION [ HEAD check skipped ] : claude started although the '
            . 'launch clone is NOT at the dispatched commit — the HEAD == '
            . 'sha assertion FAILS as designed',
        !$e
            && $t =~ m{status=started}
            && $t =~ m{\Q$mut2_sha\E}
            && length( head_of($mut2_launch) )
            && head_of($mut2_launch) ne $mut2_sha,
        "err=$e head='" . head_of($mut2_launch) . "' dispatched=$mut2_sha"
    );

    kill_server($mcp_pid);
    $mcp_pid = undef;

    ##=============================================================##
    ## phase 3 : push-first refusal [ stubbed git, deterministic ]   ##
    ##=============================================================##
    {
        local %ENV = %ENV;
        $ENV{'CLAUDE_STUB_MODE'}          = 'cloud';
        $ENV{'GIT_STUB_UNPUSHED'}         = '1';
        $ENV{'PROTOCOL_7_MCP_CLOUD_REPO'} = $launch_repo;
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
        $ENV{'PROTOCOL_7_MCP_CLOUD_REMOTE'} = 'origin';
        $ENV{'PROTOCOL_7_MCP_CLOUD_REPO'}   = $temp_repo;
        $mcp_pid                            = spawn_server();
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
        $ENV{'PROTOCOL_7_MCP_CLOUD_REPO'} = $launch_repo;
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
        $ENV{'PROTOCOL_7_MCP_CLOUD_REPO'} = $launch_repo;
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
        $ENV{'PROTOCOL_7_MCP_CLOUD_REPO'} = $launch_repo;
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
        $ENV{'PROTOCOL_7_MCP_CLOUD_REPO'} = $launch_repo;
        $mcp_pid                          = spawn_server();
    }
    unlink "$tmp_dir/claude-argv.log", "$tmp_dir/git-argv.log";

    ( $t, $e )
        = tool_call( 'claude_cloud_dispatch',
        { 'prompt' => 'x', 'effort' => 'low' } );
    check(
        'follow-up json error reported [ session itself still fine ]',
        !$e
            && $t =~ m{status=started}
            && index( $t,
            'follow-up /effort low : error [ simulated follow-up failure ]' )
            >= 0,
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
        $ENV{'PROTOCOL_7_MCP_CLOUD_REMOTE'} = 'origin';
        $ENV{'PROTOCOL_7_MCP_CLOUD_REPO'}   = $temp_repo2;
        $mcp_pid                            = spawn_server();
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

    ##=========================================================##
    ## phase 9 : status for a CLOUD id — no agents / logs call   ##
    ##=========================================================##
    {
        local %ENV = %ENV;
        $ENV{'CLAUDE_STUB_MODE'}          = 'status';
        $ENV{'PROTOCOL_7_MCP_CLOUD_REPO'} = $root_path;
        $mcp_pid                          = spawn_server();
    }
    unlink "$tmp_dir/claude-argv.log", "$tmp_dir/git-argv.log";

    my $cloud_id = 'session_018fjDZetZXhjdXJ6ecCrmzt';
    ( $t, $e )
        = tool_call( 'claude_cloud_status', { 'session_id' => $cloud_id } );
    check(
        'status [ cloud id ] : url + teleport hint + result pointer',
        !$e
            && index( $t, "https://claude.ai/code/$cloud_id" ) >= 0
            && index( $t, "claude --teleport $cloud_id" ) >= 0
            && index( $t, 'claude_cloud_result' ) >= 0
            && index( $t, 'NOT visible to the local readers' ) >= 0,
        "err=$e text=$t"
    );
    check(
        'status [ cloud id ] : no agents / logs call was made',
        scalar stub_calls("$tmp_dir/claude-argv.log") == 0,
        scalar stub_calls("$tmp_dir/claude-argv.log") . ' claude calls'
    );

    ## a cse_ id is treated the same way ##
    ( $t, $e )
        = tool_call( 'claude_cloud_status', { 'session_id' => 'cse_00Abc' } );
    check(
        'status [ cse_ id ] : same plain reply, still no local readers',
        !$e
            && index( $t, 'https://claude.ai/code/cse_00Abc' ) >= 0
            && scalar stub_calls("$tmp_dir/claude-argv.log") == 0,
        "err=$e text=$t"
    );

    kill_server($mcp_pid);
    $mcp_pid = undef;

    ##=========================================================##
    ## phase 10 : claude_cloud_result against the real hub repo  ##
    ##=========================================================##
    {
        local %ENV = %ENV;
        delete $ENV{'GIT_STUB_BRANCH'};
        delete $ENV{'GIT_STUB_SHA'};
        delete $ENV{'GIT_STUB_UNPUSHED'};
        delete $ENV{'GIT_STUB_DIRTY'};
        $ENV{'PROTOCOL_7_MCP_CLOUD_REPO'} = $result_repo;
        $mcp_pid = spawn_server();
    }
    unlink "$tmp_dir/claude-argv.log", "$tmp_dir/git-argv.log";

    my $head_before   = head_of($result_repo);
    my $status_before = porcelain_of($result_repo);

    ## without branch : newest remote branches of 'hub', newest first ##
    ( $t, $e ) = tool_call( 'claude_cloud_result', {} );
    check(
        'result [ no branch ] : hub branches listed with dates + subjects',
        !$e
            && index( $t, 'hub/cloud-result' ) >= 0
            && index( $t, 'cloud session summary' ) >= 0
            && index( $t, 'hub/base' ) >= 0,
        "err=$e text=$t"
    );
    check(
        'result [ no branch ] : newest first [ cloud-result above base ]',
        !$e && index( $t, 'hub/cloud-result' ) < index( $t, 'hub/base' ),
        $t
    );

    ## with branch : log + diffstat + full newest commit message ##
    ( $t, $e )
        = tool_call( 'claude_cloud_result', { 'branch' => 'cloud-result' } );
    check(
        'result [ branch ] : ahead-log + diffstat + full summary message',
        !$e
            && index( $t, 'feature work one' ) >= 0
            && $t =~ m{result\.feature}
            && index( $t, 'cloud session summary' ) >= 0
            && index( $t, 'verified the other thing' ) >= 0,
        "err=$e text=$t"
    );
    my @result_git = git_calls("$tmp_dir/git-argv.log");
    check(
        'result [ branch ] : fetch hub + base..hub/branch ranges ran',
        (   @result_git
                and
                grep { join( ' ', @$_ ) =~ m{-c color\.ui=false fetch hub} }
                @result_git
                and grep {
                join( ' ', @$_ )
                    =~ m{log --oneline --no-color base\.\.hub/cloud-result}
                } @result_git
                and grep {
                join( ' ', @$_ )
                    =~ m{diff --stat --no-color base\.\.\.hub/cloud-result}
                } @result_git
        ),
        join ' | ',
        map { join ' ', @$_ } @result_git
    );

    ## read-only : HEAD + working tree exactly as before ##
    my $head_after   = head_of($result_repo);
    my $status_after = porcelain_of($result_repo);
    check(
        'result : HEAD + working tree unchanged',
        $head_after eq $head_before && $status_after eq $status_before,
        "head $head_before -> $head_after ; "
            . "status '$status_before' -> '$status_after'"
    );

    ## bad names refused BEFORE any git call ##
    my $git_calls_before_bad = scalar git_calls("$tmp_dir/git-argv.log");
    ( $t, $e )
        = tool_call( 'claude_cloud_result', { 'branch' => 'bad..name' } );
    check(
        'result : branch with .. refused before any git call',
        $e
            && index( $t, "invalid branch 'bad..name'" ) >= 0
            && scalar git_calls("$tmp_dir/git-argv.log")
            == $git_calls_before_bad,
        "err=$e text=$t"
    );
    ( $t, $e )
        = tool_call( 'claude_cloud_result', { 'remote' => 'x;y' } );
    check(
        'result : shell-shaped remote refused before any git call',
        $e
            && index( $t, "invalid remote 'x;y'" ) >= 0
            && scalar git_calls("$tmp_dir/git-argv.log")
            == $git_calls_before_bad,
        "err=$e text=$t"
    );

    kill_server($mcp_pid);
    $mcp_pid = undef;

    ##=========================================================##
    ## phase 11 : MUTATION-CHECK — a result copy whose fetch became `git ##
    ## checkout <branch>` must trip the  unchanged-HEAD assertion ; then ##
    ## restore + report                                                  ##
    ##=========================================================##
    my $mutated = "$tmp_dir/mcp-server-p7-checkout-mutation";
    {
        open( my $fh, '<', $server_pl ) or die "cannot read $server_pl : $!";
        my $src = do { local $/ = undef; <$fh> };
        close $fh;
        ## the mutation : result's sole write turned into a tree-moving ##
        ## checkout of the very branch it was asked about               ##
        my $hits = $src
            =~ s/qw\| git -c color\.ui=false fetch \|, \$remote/qw| git -c color.ui=false checkout |, \$branch/;
        die "mutation anchor not found in $server_pl" unless $hits == 1;
        open( my $out, '>', $mutated ) or die "cannot write $mutated : $!";
        print {$out} $src;
        close $out;
        chmod 0755, $mutated;
    }
    {
        local %ENV = %ENV;
        $ENV{'P7_MCP_SERVER_PL'}          = $mutated;
        $ENV{'PROTOCOL_7_MCP_CLOUD_REPO'} = $result_repo;
        $mcp_pid                          = spawn_server();
    }
    unlink "$tmp_dir/claude-argv.log", "$tmp_dir/git-argv.log";

    my $mut_head_before = head_of($result_repo);
    ( $t, $e )
        = tool_call( 'claude_cloud_result', { 'branch' => 'cloud-result' } );
    my $mut_head_after = head_of($result_repo);
    check(
        'MUTATION [ result runs git checkout ] : HEAD moved '
            . '— the unchanged-HEAD assertion FAILS as designed',
        $mut_head_after ne $mut_head_before,
        "head $mut_head_before -> $mut_head_after [ reply err=$e ]"
    );

    kill_server($mcp_pid);
    $mcp_pid = undef;

    ## restore the temp repo : back on 'base' at the original commit ##
    system( $real_git, '-C', $result_repo, 'checkout', '-q', 'base' ) == 0
        or die "mutation restore failed";
    check(
        'MUTATION : temp repo restored to its base branch',
        head_of($result_repo) eq $mut_head_before,
        head_of($result_repo) . ' vs ' . $mut_head_before
    );
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

## remove the launch clone this run created [ a pre-existing one stays ] ##
if ( not $launch_preexisting and -d $launch_dir ) {
    remove_tree($launch_dir);
    rmdir "$tmp_dir/cloud-launch";
}

## and every other capture this run created [ the plain dispatch cases ] : new
## since the start AND stub output -- a real cloud run started meanwhile is
## never removed
for my $capture ( glob("$root_path/data/state/claude-cloud-*.out") ) {
    next if $captures_before{$capture};
    open my $fh, q{<}, $capture or next;
    my $first = <$fh> // q{};
    close $fh;
    ## pty stub codes ##
    $first =~ s{\e(?:\[[0-9;?]*[\x40-\x7e]|\][^\a]*\a)}{}g;
    next
        if $first
        !~ m{^(?:created (?:claude )?cloud session|cloud say what|Error: --cloud requires an interactive terminal)};
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
## 6. result fetch turned to checkout  -> the inline MUTATION run in phase 11
##    proves the unchanged-HEAD assertion catches it [ expected to FAIL there
##    by design — that IS the check working ]
## 7. claude started from the checkout again [ phase 2e ] -> the launch-clone
##    cwd assertion FAILs [ got : the checkout path ]
## 8. launch clone neither pointed at nor verified against the dispatched
##    commit [ phase 2f ] -> the HEAD == sha assertion FAILs

#,,..,,,.,,..,,..,.,.,,,,,,,.,,,.,,..,.,,,..,,..,,...,...,.,,,...,,,,,,,,,,,.,
#BIWNHJSL54ALULIPTBSLGTHV4FC47VBNMCIA3XPBRBYWBSL4YDPULU2JB6ULFLHYC5JFPG3EDUC7Q
#\\\|LLE4ZNR7MGN2G2QZFCC5MLTDJ7RDC6JKT3BUZEIKYJYB546DGGQ \ / AMOS7 \ YOURUM ::
#\[7]C5PU2X5IMVQM7U75LFXG4ODPDVJPUK4NGET7JDDSAMHF6IEWBYAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
