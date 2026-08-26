#!/usr/bin/perl
use v5.24;
use strict;
use English;
use warnings;

###                                                                  ###
## coding.init_code : model_path dependency objects actually get created ##
###                                                                  ###

## found 2026-08-26 live-testing the CPU spawn path: coding.init_dependencies
## -- where <coding.dep.spawn_ready_gpu>/<coding.dep.spawn_ready_cpu> used to
## be created -- is NEVER INVOKED anywhere [ confirmed by exhaustive grep ].
## every dependency.ok() call on those ids was therefore always
## dependency.ok(undef), which fails open [ returns TRUE unconditionally,
## logging a warning ] -- the model-path dependency gate landed earlier the
## same day had never actually been live for either backend. fixed by moving
## the object-creation into coding.init_code, which genuinely runs at startup.
## coding.init_code as a whole is too heavy [ event/signal setup, privilege
## drop, network ] to compile and invoke standalone, so this harness extracts
## just the new block, same technique as  test-coding-cpu-ld-library-path.pl

use File::Spec;
use Cwd     qw| abs_path |;
use FindBin qw| $RealBin |;

BEGIN {
    my $up_dir    = File::Spec->updir;
    my $root_path = abs_path(
        File::Spec->rel2abs(
            File::Spec->catdir( $RealBin, $up_dir, $up_dir )
        )
    );
    my $local_lib_path
        = File::Spec->catdir( $root_path, qw| data lib-path pm | );
    die "not found : $local_lib_path" if !-d $local_lib_path;
    unshift( @INC, $local_lib_path );
    $main::root_path = $root_path;
}

use AMOS7::Protocol::P7Syntax qw| p7_syntax__translate |;

use constant TRUE    => 5;
use constant FALSE   => 0;
use constant UNKNOWN => 2;

our %data;
our %code;
our $call;
my $fail_count = 0;
my $NEXT_ID    = 1;

%code = (
    'base.log'    => sub { return TRUE },
    'base.logs'   => sub { return TRUE },
    'base.gen_id' => sub {
        my $href = shift;
        my $id;
        do { $id = $NEXT_ID++ } while exists $href->{$id};
        return $id;
    },
    'coding.callback.object.model_path' => sub { return TRUE },
    'coding.resolve.object.model_path'  => sub { return TRUE },
);

sub ok {
    my ( $cond, $label ) = @ARG;
    if ($cond) { say "  ok   : $label"; return }
    $fail_count++;
    say "  FAIL : $label";
    return;
}

sub read_file {
    my $path = shift;
    open( my $fh, '<', $path ) or die "cannot read $path : $!";
    my $content = join( '', <$fh> );
    close($fh);
    return $content;
}

sub compile_module {
    my $module_name = shift;
    my $src_path
        = File::Spec->catfile( $main::root_path, 'src', $module_name );
    my $translated = p7_syntax__translate( read_file($src_path) );
    my $cref       = eval "sub {\n# line 1 \"$module_name\"\n$translated\n}";
    die "compile failed for $module_name : $EVAL_ERROR"
        if not defined $cref;
    $code{$module_name} = $cref;
    return $cref;
}

compile_module($_) foreach qw|
    base.dependency.add_object
    base.dependency.add
    |;

say ': coding.init_dependencies is still dead code '
    . '[ documented, not a silent regression risk ]';

my $found_caller = 0;
for my $dir (
    File::Spec->catdir( $main::root_path, 'src' ),
    File::Spec->catdir( $main::root_path, 'cfg' )
) {
    open( my $grep_fh, '-|', 'grep', '-rl', 'init_dependencies', $dir )
        or next;
    while (<$grep_fh>) {
        chomp;
        next if m|/coding\.init_dependencies$|;    ## the file itself ##
        next if m|/base\.list\.subroutines$|;      ## registry listing only ##
        next if m|/subroutines\.load-early$|;      ## load list, not a call ##
        my $content = read_file($_);
        $found_caller = 1
            if $content
            =~ m{<\[coding\.init_dependencies\]>|\$code\{'coding\.init_dependencies'\}\s*->};
    }
    close $grep_fh;
}
ok( ( not $found_caller ),
    'no real invocation of coding.init_dependencies found anywhere [ if this '
        . 'now fails, someone wired it up -- update the file\'s header note '
        . 'and re-check for the old-graph activation this harness was '
        . 'written to avoid ]'
);

say ': coding.init_dependencies no longer duplicates the model_path block';

my $dead_src = read_file(
    File::Spec->catfile(
        $main::root_path, qw| src coding.init_dependencies |
    )
);
ok( $dead_src !~ m{coding\.dep\.spawn_ready_cpu},
    'the model_path/spawn_ready object-creation block is gone from the '
        . 'dead file [ single source of truth now lives in coding.init_code ]'
);

say ': coding.init_code actually creates the model_path dependency objects';

my $init_code_src
    = read_file(
    File::Spec->catfile( $main::root_path, qw| src coding.init_code | ) );

## the block is nested one level in [ inside the surrounding "if (not      ##
## $already_initialized)" ], so its own closing brace is indented 4 spaces ##
## -- anchor on that exact indent, not column 0, to avoid swallowing the   ##
## OUTER block's closing brace too                                         ##
my ($block) = $init_code_src =~ m{
    ( if \s* \( \s* exists \s* \$code\{'coding\.callback\.object\.model_path'\} \s* \) \s* \{
      .*?
      \n \x20{4} \} )
}xms;

ok( defined $block,
    'extracted the model_path object-creation block from coding.init_code [ '
        . 'if this fails, the block was moved/renamed -- update this harness '
        . 'to match ]'
);
die 'cannot continue without the extracted block' if not defined $block;

for my $marker (
    qw| coding.dep.model_path_gpu coding.dep.spawn_ready_gpu
    coding.dep.model_path_cpu coding.dep.spawn_ready_cpu |
) {
    ok( index( $block, $marker ) >= 0, "extracted block references $marker" );
}

## run it for real against a minimal stub environment ##
my $plain_block = $block;
$plain_block =~ s{<coding\.dep\.(\w+)>}{\$data{'coding'}{'dep'}{'$1'}}g;
$plain_block
    =~ s{<\[dependency\.add_object\]>}{\$code{'base.dependency.add_object'}}g;
$plain_block =~ s{<\[dependency\.add\]>}{\$code{'base.dependency.add'}}g;

eval $plain_block;
die "eval failed : $EVAL_ERROR" if length $EVAL_ERROR;

my $gpu_model = $data{'coding'}{'dep'}{'model_path_gpu'};
my $gpu_root  = $data{'coding'}{'dep'}{'spawn_ready_gpu'};
my $cpu_model = $data{'coding'}{'dep'}{'model_path_cpu'};
my $cpu_root  = $data{'coding'}{'dep'}{'spawn_ready_cpu'};

ok( defined $gpu_model
        && defined $gpu_root
        && defined $cpu_model
        && defined $cpu_root,
    'all four object ids were actually assigned [ not undef -- this '
        . 'is the exact bug : dependency.ok(undef) always failed open ]'
);
ok(
    (   ( grep {defined} $gpu_model, $gpu_root, $cpu_model, $cpu_root ) == 4
            and scalar( grep { $_ eq $gpu_model } $gpu_root,
            $cpu_model, $cpu_root ) == 0
    ),
    'all four ids are distinct [ no accidental collision ]'
);
ok( grep( { $_ == $gpu_model } @{ $data{'dependency'}{'chain'}{$gpu_root} } ),
    'spawn_ready_gpu\'s chain includes model_path_gpu'
);
ok( grep( { $_ == $cpu_model } @{ $data{'dependency'}{'chain'}{$cpu_root} } ),
    'spawn_ready_cpu\'s chain includes '
        . 'model_path_cpu [ independently of gpu\'s chain ]'
);

say '';
if ($fail_count) {
    say "FAILED : $fail_count check[s]";
    exit 1;
}
say 'all checks passed';
exit 0;

#,,,.,,,,,.,,,..,,.,,,.,.,...,,.,,,,.,,,.,.,.,.,.,...,..,,..,,...,,,.,...,.,.,
#QOU4XRUD7ON6PAXO53HTMWFA4CGJCWB4QBSLZJ3CZTEFFUXWEKFM3O6O3NPTDE6BGVJ4UXBCUJIVM
#\\\|GPYR5DI3DDAZ2EB2A7TWZYCYMT23EZLHGQSRBH6WATCAFLOZTII \ / AMOS7 \ YOURUM ::
#\[7]MVZ2GLMOWSPBLJJYFVDAQ4T43LB5IMA4TH7SGEGYTYFILTXLUAAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
