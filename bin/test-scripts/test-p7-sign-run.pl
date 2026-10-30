#!/usr/bin/perl
## p7-sign-run pending bump reuse and valid-file staging : regression ------
###                                                                         ###

use v5.24;
use strict;
use warnings;
use English;
use File::Copy ();
use File::Path ();
use File::Spec;
use File::Spec::Functions qw| catfile |;
use File::Temp            ();
use Cwd                   qw| abs_path |;
use FindBin               qw| $RealBin |;
use JSON::PP              ();

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
use AMOS7::Protocol::P7Syntax qw| p7_syntax__translate |;

my $fail_count = 0;

sub ok ($;$) {
    my ( $cond, $label ) = @ARG;
    if ($cond) { say "  ok   : $label"; return }
    $fail_count++;
    say "  FAIL : $label";
    return;
}

sub put_file {
    my ( $path, $text ) = @ARG;
    File::Path::make_path(
        File::Spec->catdir( ( File::Spec->splitpath($path) )[1] ) );
    open( my $fh, '>:raw', $path ) or die "$path : $OS_ERROR";
    print {$fh} $text;
    close $fh;
    return;
}

sub slurp_file {
    my $path = shift;
    open( my $fh, '<:raw', $path ) or die "$path : $OS_ERROR";
    local $INPUT_RECORD_SEPARATOR;
    my $text = <$fh>;
    close $fh;
    return $text;
}

my $old_ver = qw| AAAAAAAAAA-10407.0 |;
my $new_ver = qw| BBBBBBBBBB-10408.0 |;
my $footer  = <<'FOOTER';
#,,,,,,,.,,,
#AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
#\\\|AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA \ / AMOS7 \ YOURUM ::
#\[7]AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
FOOTER

sub version_file_text {
    my $version = shift;
    my ( $base, $count, $minor )
        = $version =~ m|^([A-Z2-7]{10})-(\d+)\.(\d+)$|;
    return (
        "$version\n$footer",
        "::: SOURCE-CODE VERSION :: $version :::\n\nbody\n",
        "# versions\n\n- **Version Identifier**: `$version`\n- **Network "
            . "Timestamp**: `$base`\n- **Commit Count**: `$count`\n- "
            . "**Revision**: `.$minor`\n\n$footer"
    );
}

my @bump_files = (
    qw| cfg/protocol-7.src-ver |,
    qw| read-me/md/README.md |,
    qw| read-me/project-identity/source-code-versions.md |
);

sub make_repo {
    my $root = File::Temp::tempdir(
        'p7-sign-run-test-XXXX',
        TMPDIR  => 1,
        CLEANUP => 1
    );
    File::Path::make_path( File::Spec->catdir( $root, qw| bin dev | ) );
    File::Copy::copy(
        File::Spec->catfile( $main::root_path, qw| bin dev p7-sign-run | ),
        File::Spec->catfile( $root,            qw| bin dev p7-sign-run | )
    ) or die "copy p7-sign-run : $OS_ERROR";
    my @old_text = version_file_text($old_ver);
    put_file( File::Spec->catfile( $root, $bump_files[$ARG] ),
        $old_text[$ARG] )
        foreach 0 .. $#bump_files;
    put_file( File::Spec->catfile( $root, qw| src example | ), "example\n" );
    put_file( File::Spec->catfile( $root, qw| bin dev update-version | ),
        <<'STUB' );
#!/usr/bin/perl
use strict;
use warnings;
open my $marker, '>', 'update-version.called' or die $!;
close $marker;
my $version = 'CCCCCCCCCC-00000.0';
my @paths = (
    'cfg/protocol-7.src-ver',
    'read-me/md/README.md',
    'read-me/project-identity/source-code-versions.md'
);
open my $ver, '<', $paths[0] or die $!;
my $old = <$ver>;
close $ver;
my ($count) = $old =~ m/-(\d+)\./;
$version = sprintf 'CCCCCCCCCC-%05d.0', $count + 1;
my ($base) = $version =~ m/^([^-]+)/;
open $ver, '>', $paths[0] or die $!;
print {$ver} "$version\n";
close $ver;
open my $readme, '<', $paths[1] or die $!;
my $text = do { local $/; <$readme> };
close $readme;
$text =~ s/::: SOURCE-CODE VERSION :: \S+ :::/::: SOURCE-CODE VERSION :: $version :::/;
open $readme, '>', $paths[1] or die $!;
print {$readme} $text;
close $readme;
open my $versions, '<', $paths[2] or die $!;
$text = do { local $/; <$versions> };
close $versions;
$text =~ s/(Version Identifier\*\*: `)[^`]+/$1$version/;
$text =~ s/(Network Timestamp\*\*: `)[^`]+/$1$base/;
$text =~ s/(Commit Count\*\*: `)[^`]+/$1$count/;
$text =~ s/(Revision\*\*: `\.)[^`]+/${1}0/;
open $versions, '>', $paths[2] or die $!;
print {$versions} $text;
close $versions;
print "source version :: $version\n";
STUB
    put_file( File::Spec->catfile( $root, qw| bin Protocol-7 | ), <<'STUB' );
#!/usr/bin/perl
use strict;
use warnings;
my @paths = @ARGV[ 3 .. $#ARGV ];
my $run = 'test-run';
my $log = $ENV{'XDG_RUNTIME_DIR'} . '/runs.log';
open my $fh, '>>', $log or die $!;
print {$fh} "0 request $run\n0 begin $run\n";
print {$fh} "0 sign $run $_\n" foreach @paths;
print {$fh} "0 end $run\n";
close $fh;
system qw| git add -- |, @paths;
print "stub signing complete\n";
STUB
    chmod 0755,
        File::Spec->catfile( $root, qw| bin dev p7-sign-run | ),
        File::Spec->catfile( $root, qw| bin dev update-version | ),
        File::Spec->catfile( $root, qw| bin Protocol-7 | );
    system( qw| git -C |, $root, qw| init -q | ) == 0 or die 'git init';
    system( qw| git -C |, $root,
        qw| config user.email test@example.invalid | );
    system( qw| git -C |, $root, qw| config user.name test | );
    system( qw| git -C |, $root, qw| add . | ) == 0 or die 'git add';
    system( qw| git -C |, $root, qw| commit -qm initial | ) == 0
        or die 'git commit';
    return $root;
}

sub pending_bump {
    my $root     = shift;
    my @new_text = version_file_text($new_ver);
    put_file( File::Spec->catfile( $root, $bump_files[$ARG] ),
        $new_text[$ARG] )
        foreach 0 .. $#bump_files;
    return;
}

sub run_sign {
    my ( $root, @args ) = @ARG;
    my $state = File::Spec->catfile( $root, qw| state.json | );
    my $pid   = open( my $fh, '-|' );
    die 'fork' if not defined $pid;
    if ( $pid == 0 ) {
        chdir $root or die $OS_ERROR;
        $ENV{'XDG_RUNTIME_DIR'} = $root;
        open( STDERR, '>&', \*STDOUT );
        exec $^X, File::Spec->catfile( $root, qw| bin dev p7-sign-run | ),
            qw| -state |, $state, @args;
    }
    local $INPUT_RECORD_SEPARATOR;
    my $out = <$fh> // '';
    close $fh;
    my $status = $CHILD_ERROR;
    my $data   = -f $state ? JSON::PP::decode_json( slurp_file($state) ) : {};
    return ( $status, $out, $data );
}

sub update_called {
    return -f File::Spec->catfile( shift, qw| update-version.called | );
}

say ': 1. sane pending bump reused';
{
    my $root = make_repo();
    pending_bump($root);
    my ( $status, $out, $state )
        = run_sign( $root, qw| -op new src/example | );
    ok( $status == 0 && !update_called($root),
        'sane bump skips update-version'
    );
    ok( $out =~ m|version : reusing pending bump \Q$new_ver\E|,
        'reuse is reported' );
    my %paths = map { $ARG => TRUE } $state->{'paths'}->@*;
    ok( ( scalar grep { $paths{$ARG} } @bump_files ) == 3,
        'all three reused files join the sign request'
    );
}

my @insane_cases = (
    [   'partial file set',
        sub {
            my $root = shift;
            my @text = version_file_text($new_ver);
            put_file( File::Spec->catfile( $root, $bump_files[0] ),
                $text[0] );
        }
    ],
    [   'counter not HEAD plus one',
        sub {
            my $root = shift;
            pending_bump($root);
            my @text = version_file_text(qw| BBBBBBBBBB-10409.0 |);
            put_file( File::Spec->catfile( $root, $bump_files[0] ),
                $text[0] );
            put_file( File::Spec->catfile( $root, $bump_files[1] ),
                $text[1] );
            put_file( File::Spec->catfile( $root, $bump_files[2] ),
                $text[2] );
        }
    ],
    [   'version absent from README',
        sub {
            my $root = shift;
            pending_bump($root);
            my @text = version_file_text($new_ver);
            $text[1] =~ s|\Q$new_ver\E|$old_ver|;
            put_file( File::Spec->catfile( $root, $bump_files[1] ),
                $text[1] );
        }
    ],
    [   'unrelated README change',
        sub {
            my $root = shift;
            pending_bump($root);
            my $path = File::Spec->catfile( $root, $bump_files[1] );
            my $text = slurp_file($path);
            $text =~ s|body|other body|;
            put_file( $path, $text );
        }
    ],
    [   'unrelated source-version change',
        sub {
            my $root = shift;
            pending_bump($root);
            put_file( File::Spec->catfile( $root, $bump_files[0] ),
                "$new_ver\nextra\n$footer" );
        }
    ],
    [   'unrelated versions-document change',
        sub {
            my $root = shift;
            pending_bump($root);
            my $path = File::Spec->catfile( $root, $bump_files[2] );
            my $text = slurp_file($path);
            $text =~ s|# versions|# changed|;
            put_file( $path, $text );
        }
    ],
);

foreach my $case (@insane_cases) {
    say ": 2. insane pending bump : $case->[0]";
    my $root = make_repo();
    $case->[1]->($root);
    my ( $status, $out, $state )
        = run_sign( $root, qw| -op new src/example | );
    ok( $status == 0 && update_called($root),
        "$case->[0] falls back to a fresh bump"
    );
    ok( $out =~ m|version : pending bump not reused : \S|,
        "$case->[0] reports why reuse was refused"
    );
    my %paths = map { $ARG => TRUE } $state->{'paths'}->@*;
    ok( ( scalar grep { $paths{$ARG} } @bump_files ) == 3,
        "$case->[0] fresh bump joins all three version files"
    );
}

say ': 3. amend-message keeps no-bump behaviour';
{
    my $root = make_repo();
    pending_bump($root);
    my ( $status, $out, $state )
        = run_sign( $root, qw| -op amend-message src/example | );
    ok( $status == 0 && !update_called($root) && !defined $state->{'version'},
        'amend-message neither reuses nor bumps'
    );
}

say ': 4. slash-less unsigned path refused before work';
{
    my $root = make_repo();
    my ( $status, $out, $state )
        = run_sign( $root, qw| -op new AI-COLLABORATION-GUIDE.md | );
    ok( $status != 0
            && !update_called($root)
            && $out
            =~ m|'AI-COLLABORATION-GUIDE\.md' has no slash.*staged by hand|s,
        'the refusal names the path and manual staging'
    );
}

say ': 5. already-valid requested paths join the staging list';

our %code;
our %data;
our %colors;

$code{'base.log'}                   = sub { return TRUE };
$code{'base.logs'}                  = sub { return TRUE };
$code{'base.s_warn'}                = sub { return TRUE };
$code{'base.str.eval_error'}        = sub { return '' };
$code{'base.exit'}                  = sub { die 'unexpected base.exit' };
$code{'event.once'}                 = sub { return TRUE };
$code{'source.cmd.get-code-signed'} = sub {
    return { 'mode' => qw| true |, 'data' => 'still valid. =)' };
};
$data{'system'}{'zenka'}{'verbosity'}{'console'} = 0;

my $module_path
    = File::Spec->catfile( $main::root_path,
    qw| src sourcecode.sign_file_list | );
my $module_source = slurp_file($module_path);
my $translated    = p7_syntax__translate($module_source);
my $sign_list     = eval "sub {\n# line 1 \"$module_path\"\n$translated\n}";
die "compile $module_path : $EVAL_ERROR" if not defined $sign_list;

my $result = $sign_list->(
    [qw| src/already-valid src/also-valid |],
    $main::root_path, 0
);
ok( join( ' ', $result->{'staged'}->@* ) eq
        'src/already-valid src/also-valid',
    'both valid requested paths are staged'
);
ok( $result->{'written_count'} == 0, 'valid files are not rewritten' );

say $fail_count ? "FAILED : $fail_count checks" : 'all checks passed';
exit( $fail_count ? 1 : 0 );

#,,,.,,,.,,..,...,,,.,,..,...,,.,,..,,,.,,.,,,..,,...,..,,...,.,.,.,.,...,,,,,
#4R76OOM3MAIT7GAPONVAX5G6NTS5UDTBXF7KL2X7IPYVAPDSYGZHAEQN2NNMRKQI7IF4QFSPLNBKE
#\\\|KEK7PV6HSYZWADYIONU5RRPDNLD7P5FJJAKJQEAPGYAPU7P33AU \ / AMOS7 \ YOURUM ::
#\[7]URGF24C4U346YVU4KUJTVZVSLAHDUARN2DA4NB5YODKPKADWKWCI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
