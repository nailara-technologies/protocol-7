#!/usr/bin/env perl
use v5.32;
use strict;
use English;

## session continuity stage 1 : the real src/session_move.* modules and the ##
## claude \ kimi export \ import \ lease commands, between two FAKE homes   ##
## and work dirs [ one 'host' each ]. fake transcripts, fake credential     ##
## files that must never travel. no zenka, no cube, no claude, no kimi      ##

use File::Spec;
use File::Find qw| find |;
use File::Path qw| make_path |;
use File::Temp qw| tempdir |;
use Cwd        qw| abs_path |;
use FindBin    qw| $RealBin |;
use Fcntl      ();
use JSON::PP   ();

BEGIN {
    $main::root_path = abs_path("$RealBin/../..");
    unshift @INC, "$main::root_path/data/lib-path/pm";
}

use Digest::BMW ();
use Crypt::Misc qw| encode_b32r |;

use constant TRUE  => 5;
use constant FALSE => 0;

our %data;
our %code;
our $call;

my ( $pass, $fail ) = ( 0, 0 );

sub ok {
    my ( $cond, $name ) = @ARG;
    if   ($cond) { $pass++; say "ok   - $name" }
    else         { $fail++; say "FAIL - $name" }
    return $cond;
}

## module loading : the same <..> translation the zenka loader does ##
sub translate_code {
    my $code = shift;
    $code =~ s{<\[([A-Za-z][-\w.]*)\]>(?=\s*->)}{chr(36).qq|code{'$1'}|}eg;
    $code =~ s{<\[([A-Za-z][-\w.]*)\]>}{chr(36).qq|code{'$1'}->()|}eg;
    $code =~ s{<([a-z][-\w.]*)>}{
        my @keys = split m|\.|, $1;
        chr(36).qq|data{'| . join( "'}{'", @keys ) . qq|'}|
    }ge;
    return $code;
}

sub slurp {
    my ( $path, $layer ) = @ARG;
    open my $fh, '<' . ( $layer // ':raw' ), $path or return undef;
    local $INPUT_RECORD_SEPARATOR = undef;
    my $text = <$fh> // '';
    close $fh;
    return $text;
}

sub spew {
    my ( $path, $text ) = @ARG;
    make_path($1) if $path =~ m{\A(.*)/};
    open my $fh, '>:raw', $path or die "$path : $OS_ERROR";
    print {$fh} $text;
    close $fh or die;
    return $path;
}

sub load_module {
    my $name = shift;
    my $src  = slurp( "$main::root_path/src/$name", ':encoding(UTF-8)' )
        // die "no module $name";
    $src =~ s{\n#[^\n]*\z}{\n} while $src =~ m{\n#[,\[\\|:][^\n]*\z};
    my @seg = split m{('(?:[^'\\]|\\.)*'|"(?:[^"\\]|\\.)*"|\#[^\n]*)}x,
        $src, -1;
    for ( my $i = 0; $i < @seg; $i += 2 ) {
        $seg[$i] = translate_code( $seg[$i] );
    }
    my $translated = join '', @seg;
    $code{$name} = eval "sub { $translated }";
    die "$name : $EVAL_ERROR" if $EVAL_ERROR;
}

opendir my $dh, "$main::root_path/src" or die;
load_module($ARG) foreach grep {m{\Asession_move\.}} readdir $dh;
closedir $dh;
load_module($ARG) foreach qw|
    claude.var_dir claude.session.load claude.session.save
    claude.session.project_dir claude.session.running claude.session.hold
    claude.cmd.session-export claude.cmd.session-import
    claude.cmd.session-lease claude.cmd.stop claude.child.start
    claude.session.transcript kimi.acp.session_transcript kimi.acp.spawn
    kimi.acp.session_store kimi.acp.session_paths kimi.acp.hold
    kimi.cmd.acp-session-export kimi.cmd.acp-session-import
    kimi.cmd.acp-session-lease kimi.cmd.acp-stop
    |;

## stubs ##
my $tmp = tempdir( 'session-cont-XXXXXX', 'TMPDIR' => 1, 'CLEANUP' => 1 );
my ( $host, @events );
$code{'base.perlmod.load'}
    = sub { ( my $f = "$ARG[0].pm" ) =~ s{::}{/}g; require $f; TRUE };
$code{'base.ntime'}            = sub {time};
$code{'claude.event.add'}      = sub { push @events, "@ARG"; TRUE };
$code{'kimi.acp.event'}        = sub { push @events, "@ARG"; TRUE };
$code{'claude.child.stop'}     = sub {FALSE};
$code{'kimi.acp.stop'}         = sub {FALSE};
$code{'kimi.acp.state'}        = sub { $data{'kimi_state'} };
$code{'stream_child.user_env'} = sub { { 'HOME' => "$tmp/$host/home" } };
$code{'chk-sum.bmw.filesum'}   = sub {
    my ( $bits, $path ) = @ARG;
    return undef if $bits != 256 or not -f $path;
    return encode_b32r( Digest::BMW::bmw_256( slurp($path) ) );
};
$code{'file.zenka_dir.load'} = sub {
    my $text = slurp("$tmp/$host/zdir/$ARG[0]");
    return defined $text ? \$text : undef;
};
$code{'file.zenka_dir.write'} = sub {
    spew( "$tmp/$host/zdir/$ARG[0]", $ARG[1]->$* );
    return TRUE;
};

## two hosts : own home, own work dir, own zenka dirs ##
sub on_host {
    $host = shift;
    make_path( "$tmp/$host/work/protocol-7", "$tmp/$host/var" );
    %data = (
        'system'       => { 'root_path' => "$tmp/$host/work/protocol-7" },
        'session_move' => { 'cfg'   => { 'host'    => "host-$host" } },
        'claude'       => { 'cfg'   => { 'var_dir' => "$tmp/$host/var" } },
        'kimi_state'   => { 'phase' => 'stopped' },
    );
    delete $ENV{'CLAUDE_CONFIG_DIR'};
    $data{'claude'}{'session'} = $code{'claude.session.load'}->();
}

sub cmd {
    my ( $name, $args ) = @ARG;
    local $call = { 'args' => $args };
    return $code{$name}->();
}

sub tree {
    my $base = shift;
    my @files;
    find(
        {   'no_chdir' => 1,
            'wanted'   => sub {
                push @files, substr $File::Find::name, 1 + length $base
                    if -f $File::Find::name or -l $File::Find::name;
            }
        },
        $base
    );
    return join ' ', sort @files;
}

my $secret = 'FAKE-SECRET-must-not-travel';
my $store  = "$tmp/store";
make_path($store);

##[ naming rules ]##
on_host('a');
{
    local $data{'system'}{'root_path'} = $main::root_path;
    my $at = $code{'claude.session.project_dir'}->();
    ( my $expected = $main::root_path ) =~ s{[^a-zA-Z0-9]}{-}g;
    ok( $at->{'name'} eq $expected, 'claude : project dir name of a path' );
}
make_path("$tmp/a/dot.and_under score");
{
    local $data{'system'}{'root_path'} = "$tmp/a/dot.and_under score";
    ok( $code{'claude.session.project_dir'}->()->{'name'}
            =~ m{-dot-and-under-score\z},
        "claude : '.', '_' and blank become '-'"
    );
}
SKIP: {
    last SKIP if not -d '/data/projects/protocol-7';
    {
        local $data{'system'}{'root_path'} = '/data/projects/protocol-7';
        ok( $code{'claude.session.project_dir'}->()->{'name'} eq
                '-data-projects-protocol-7',
            'claude : the dir name claude itself made'
        );
    }
    local $data{'system'}{'root_path'} = '/data/projects/protocol-7';
    ok( $code{'kimi.acp.session_paths'}->()->{'key'} eq
            'wd_protocol-7_fd9ee37a8de1',
        'kimi : the workspace key kimi itself made'
    );
}

##[ claude : host a ]##
my $id    = '11111111-2222-3333-4444-555555555555';
my $cfg_a = "$tmp/a/home/.claude";
spew( "$cfg_a/.credentials.json", $secret );
spew( "$cfg_a/settings.json",     qq|{"token":"$secret"}| );
my $name_a  = $code{'claude.session.project_dir'}->()->{'name'};
my $line_1  = qq|{"type":"user","text":"one \xc3\xbc"}\n|;
my $jsonl_a = spew( "$cfg_a/projects/$name_a/$id.jsonl", $line_1 );
spew( "$cfg_a/projects/$name_a/$id/tool-results/x.txt", $secret );
$code{'claude.session.save'}->($id);
$data{'claude'}{'session'} = $id;
spew( "$tmp/a/var/events.log", join '', map {"$ARG event\n"} 1 .. 500 );

$data{'claude'}{'child'} = { 'out' => 1 };
ok( cmd( 'claude.cmd.session-export', $store )->{'mode'} eq 'false',
    'export : refused while claude runs' );
delete $data{'claude'}{'child'};

my $r = cmd( 'claude.cmd.session-export', $store );
ok( $r->{'mode'} eq 'true', 'export : done' ) or say "# $r->{'data'}";
my $base = "$store/claude/$id";
ok( tree($base) eq
        join( ' ', sort "$id.jsonl", qw| events.tail manifest session.cfg | ),
    'export : exactly the three session files and the manifest'
);
ok( !grep( { index( slurp("$base/$ARG"), $secret ) >= 0 }
        split m| |,
        tree($base) ),
    'export : no credential content in the store'
);
ok( ( () = slurp("$base/events.tail") =~ m{\n}g ) == 377,
    'export : the events log tail only' );
my $manifest = slurp( "$base/manifest", ':encoding(UTF-8)' );
my @listed   = $manifest =~ m{^file\s+= (\d+) (\S+) (\S+)$}mg;
my $sums_ok  = @listed == 9;

while ( my ( $size, $sum, $file ) = splice @listed, 0, 3 ) {
    $sums_ok = 0
        if -s "$base/$file" != $size
        or $code{'chk-sum.bmw.filesum'}->( 256, "$base/$file" ) ne $sum;
}
ok( $sums_ok, 'manifest : sizes and BMW checksums of the stored files' );
ok( $manifest        =~ m{^work_dir = \Q$tmp\E/a/work/protocol-7$}m
        && $manifest =~ m{^host     = host-a$}m
        && $manifest =~ m{^time     = \d+$}m,
    'manifest : work dir, host, time'
);
ok( !-e "$base/lease", 'export : the lease is released' );

## the exporting host keeps a pointer into the store ##
ok( -f "$tmp/a/var/hold.$id.cfg", 'export : this host keeps a pointer' );

##[ claude : host b ]##
on_host('b');
my $cfg_b = "$tmp/b/home/.claude";
$r = cmd( 'claude.cmd.session-import', "$store $id" );
ok( $r->{'mode'} eq 'false' && !-e "$base/lease",
    'import : no claude config dir : refused, no lease left'
);
make_path($cfg_b);

spew( "$base/session.cfg", slurp("$base/session.cfg") . "x\n" );
$r = cmd( 'claude.cmd.session-import', "$store $id" );
ok( $r->{'mode'} eq 'false'
        && $r->{'data'} =~ m{checksum}
        && !-e "$base/lease"
        && tree($cfg_b) eq '',
    'import : a changed file is refused, nothing placed'
);
{
    my $good = slurp("$base/session.cfg");
    $good =~ s{x\n\z}{};
    spew( "$base/session.cfg", $good );
}
my $good_manifest = slurp("$base/manifest");
spew( "$base/manifest",
    $good_manifest . "file     = 1 AAAA ../../.credentials.json\n" );
ok( cmd( 'claude.cmd.session-import', "$store $id" )->{'data'}
        =~ m{not a session file},
    'import : a name outside the session files is refused'
);
spew( "$base/manifest", $good_manifest );

$r = cmd( 'claude.cmd.session-import', "$store $id" );
ok( $r->{'mode'} eq 'true', 'import : done' ) or say "# $r->{'data'}";
my $name_b  = $code{'claude.session.project_dir'}->()->{'name'};
my $jsonl_b = "$cfg_b/projects/$name_b/$id.jsonl";
ok( $name_b ne $name_a && slurp($jsonl_b) eq $line_1,
    'import : transcript under the CURRENT work dir, same octets'
);
ok( tree($cfg_b) eq "projects/$name_b/$id.jsonl",
    'import : only the transcript enters the claude config dir' );
ok( $code{'claude.session.load'}->() eq $id
        && $data{'claude'}{'session'} eq $id,
    'import : the zenka resumes this session'
);
ok( -f "$tmp/b/var/events.imported.$id.log", 'import : events tail kept' );
ok( slurp("$base/lease") =~ m{^host  = host-b$}m,
    'import : this host holds the lease'
);
ok( cmd( 'claude.cmd.session-lease', '' )->{'data'}
        =~ m{host host-b .* \[ held \]},
    'lease : own holds shown'
);

##[ claude : lease refusal and release ]##
on_host('a');
$data{'claude'}{'session'} = $id;
$r = cmd( 'claude.cmd.session-import', "$store $id" );
ok( $r->{'mode'} eq 'false' && $r->{'data'} =~ m{held by host host-b},
    'lease : import refused while another host holds it'
);
$r = cmd( 'claude.cmd.session-export', $store );
ok( $r->{'mode'} eq 'false' && $r->{'data'} =~ m{held by host host-b},
    'lease : export refused too' );
$data{'claude'}{'cfg'}{'binary'} = '/nonexistent';
ok( ( $code{'claude.child.start'}->( {} )->{'error'} // '' )
        =~ m{held by host host-b},
    'start : the exporting host cannot resume while b holds it'
);
ok( cmd( 'claude.cmd.session-lease', "$store $id" )->{'data'}
        =~ m{host host-b},
    'lease : shown for a stored session'
);

on_host('b');
cmd( 'claude.cmd.stop', '' );
ok( !-e "$base/lease", 'lease : claude.stop releases it' );
ok( cmd( 'claude.cmd.session-lease', '' )->{'data'} =~ m{: free$}m,
    'lease : the pointer stays, the store says free' );

## b imports again, works, exports ; a takes the longer transcript back ##
cmd( 'claude.cmd.session-import', "$store $id" );
$data{'claude'}{'session'} = $id;
spew( $jsonl_b, "${line_1}two\n" );
$r = cmd( 'claude.cmd.session-export', $store );
ok( $r->{'mode'} eq 'true' && !-e "$base/lease",
    'round trip : b exports, lease released'
);

on_host('a');
$data{'claude'}{'session'} = $id;
$data{'claude'}{'cfg'}{'binary'} = '/nonexistent';
ok( ( $code{'claude.child.start'}->( {} )->{'error'} // '' )
        =~ m{store holds a newer} && !-e "$base/lease",
    'start : a stale copy is not resumed once b is done'
);
$r = cmd( 'claude.cmd.session-export', $store );
ok( $r->{'mode'} eq 'false'
        && $r->{'data'} =~ m{newer or has diverged}
        && slurp("$base/$id.jsonl") eq "${line_1}two\n"
        && !-e "$base/lease",
    'round trip : a stale export does not overwrite the store'
);
ok( cmd( 'claude.cmd.session-import', "$store $id" )->{'mode'} eq 'true'
        && slurp($jsonl_a) eq "${line_1}two\n",
    'round trip : a takes the longer transcript'
);
cmd( 'claude.cmd.stop', '' );
spew( $jsonl_a, "${line_1}diverged\n" );
$r = cmd( 'claude.cmd.session-import', "$store $id" );
ok( $r->{'mode'} eq 'false'
        && slurp($jsonl_a) eq "${line_1}diverged\n"
        && !-e "$base/lease",
    'import : a diverged local transcript is kept'
);
ok( !grep( {m{\.new\.\d+\z}} split m| |, tree("$tmp") ),
    'transfer : no staged files left behind'
);

## expired and unreadable leases ##
spew( "$base/lease", "host = other\npid = 1\nsince = 1\nuntil = 2\n" );
ok( $code{'session_move.lease.update'}->( $base, 'acquire' )->{'ok'},
    'lease : an expired lease can be taken' );
spew( "$base/lease", "garbage\n" );
ok( $code{'session_move.lease.update'}->( $base, 'acquire' )->{'error'},
    'lease : an unreadable lease blocks' );
unlink "$base/lease";

## a symlinked transcript is never followed ##
unlink $jsonl_a;
symlink "$cfg_a/.credentials.json", $jsonl_a or die;
mkdir "$tmp/store2";
$r = cmd( 'claude.cmd.session-export', "$tmp/store2" );
ok( $r->{'mode'} eq 'false' && $r->{'data'} =~ m{not a regular file},
    'export : a symlink to the credentials is refused'
);
ok( tree("$tmp/store2") eq '', 'export : nothing reached the store' );

##[ kimi ]##
$data{'kimi_state'} = { 'phase' => 'stopped' };
on_host('a');
my $kid  = 'session_aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee';
my $kh_a = "$tmp/a/home/.kimi-code";
my $at_a = $code{'kimi.acp.session_paths'}->();
my $sd_a = "$kh_a/sessions/$at_a->{'key'}/$kid";
spew( "$kh_a/$ARG", $secret )
    foreach qw| credentials/kimi.json oauth/token server.token config.toml
    mcp.json device_id |;
spew(
    "$sd_a/state.json",
    JSON::PP->new->encode(
        {   'id'     => $kid,
            'cwd'    => $at_a->{'work_dir'},
            'agents' => {
                'main' =>
                    { 'homedir' => "$sd_a/agents/main", 'type' => 'main' }
            }
        }
    )
);
spew( "$sd_a/agents/main/wire.jsonl",    "wire one\n" );
spew( "$sd_a/agents/agent-0/wire.jsonl", "sub wire\n" );
spew( "$sd_a/logs/kimi-code.log",        $secret );
spew(
    "$kh_a/session_index.jsonl",
    JSON::PP->new->encode(
        {   'sessionId'  => $kid,
            'sessionDir' => $sd_a,
            'workDir'    => $at_a->{'work_dir'}
        }
        )
        . "\n"
);
$code{'kimi.acp.session_store'}->( 'save', $kid );

$data{'kimi_state'}{'phase'} = 'ready';
ok( cmd( 'kimi.cmd.acp-session-export', $store )->{'mode'} eq 'false',
    'kimi export : refused while the child runs' );
$data{'kimi_state'}{'phase'} = 'stopped';
$r = cmd( 'kimi.cmd.acp-session-export', $store );
ok( $r->{'mode'} eq 'true', 'kimi export : done' ) or say "# $r->{'data'}";
my $kbase = "$store/kimi/$kid";
ok( tree($kbase) eq 'agents/agent-0/wire.jsonl '
        . 'agents/main/wire.jsonl manifest state.json',
    'kimi export : state, transcripts, manifest and nothing else'
);

on_host('b');
my $kh_b = "$tmp/b/home/.kimi-code";
make_path($kh_b);
$r = cmd( 'kimi.cmd.acp-session-import', "$store $kid" );
ok( $r->{'mode'} eq 'true', 'kimi import : done' ) or say "# $r->{'data'}";
my $at_b = $code{'kimi.acp.session_paths'}->();
my $sd_b = "$kh_b/sessions/$at_b->{'key'}/$kid";
ok( tree($kh_b) eq join( ' ',
        'session_index.jsonl',
        map {"sessions/$at_b->{'key'}/$kid/$ARG"}
            qw| agents/agent-0/wire.jsonl agents/main/wire.jsonl state.json |
    ),
    'kimi import : the files in the kimi home'
);
my $state = JSON::PP->new->utf8->decode( slurp("$sd_b/state.json") );
ok( $state->{'cwd'} eq $at_b->{'work_dir'}
        && $state->{'agents'}{'main'}{'homedir'} eq "$sd_b/agents/main",
    'kimi import : state.json paths are this host\'s'
);
my $index = JSON::PP->new->utf8->decode( slurp("$kh_b/session_index.jsonl") );
ok( $index->{'sessionDir'} eq $sd_b, 'kimi import : indexed' );
ok( $code{'kimi.acp.session_store'}->('load') eq $kid,
    'kimi import : acp-start resumes it' );

on_host('a');
ok( cmd( 'kimi.cmd.acp-session-import', "$store $kid" )->{'data'}
        =~ m{held by host host-b},
    'kimi lease : refused on the other host'
);
ok( ( $code{'kimi.acp.spawn'}->($kid)->{'error'} // '' )
        =~ m{held by host host-b},
    'kimi start : the exporting host cannot resume while b holds it'
);
ok( cmd( 'kimi.cmd.acp-session-lease', $store )->{'data'} =~ m{host-b},
    'kimi lease : shown' );
on_host('b');
cmd( 'kimi.cmd.acp-stop', '' );
ok( !-e "$kbase/lease", 'kimi lease : acp-stop releases it' );

printf "\n%d passed, %d failed\n", $pass, $fail;
exit( $fail ? 1 : 0 );

#,,,,,.,.,,..,,.,,...,.,,,.,.,,..,.,,,.,.,.,,,..,,...,...,.,,,,..,.,,,.,,,,.,,
#B6HPKQBNZHEVB4LY6POPUCFVYCZKMSAW5XJX4IDL2U7P2OZFRC25QGHCB7K3FSR77JCMJB6EYSI7E
#\\\|NELEZ4LIEKGENUEGRXVMMLBQNEQHETOZI7BQGBFL246YMGHOXVZ \ / AMOS7 \ YOURUM ::
#\[7]V3F4AEU6WGXYT5CUOHTZLMJGHP673ZAWIYGVXIEUS4NGKTMG52CQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
