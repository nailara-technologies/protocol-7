#!/usr/bin/perl
use v5.24;
use strict;
use English;
use warnings;

###                                                             ###
## coding gpu moe planning : shared free-vram budget acceptance  ##
###                                                             ###

use File::Spec;
use File::Temp qw| tempfile |;
use Cwd        qw| abs_path |;
use FindBin    qw| $RealBin |;

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

use constant TRUE  => 5;
use constant FALSE => 0;

our %data;
our %code;
our $call;

my $fail_count = 0;
my @logs;
my $query_count   = 0;
my $partial_calls = 0;
my $shape;

sub ok {
    my ( $cond, $label ) = @ARG;
    if ($cond) { say "  ok   : $label"; return }
    $fail_count++;
    say "  FAIL : $label";
    return;
}

sub compile_module {
    my $module_name = shift;
    my $src_path
        = File::Spec->catfile( $main::root_path, 'src', $module_name );
    open( my $fh, '<', $src_path ) or die "cannot read $src_path : $!";
    my $src = join( '', <$fh> );
    close($fh);
    my $translated = p7_syntax__translate($src);
    my $cref       = eval "sub {\n# line 1 \"$module_name\"\n$translated\n}";
    die "compile failed for $module_name : $EVAL_ERROR"
        if not defined $cref;
    $code{$module_name} = $cref;
    return $cref;
}

%code = (
    'base.logs' => sub {
        my ( $level, $format, @args ) = @ARG;
        push @logs, [ $level, sprintf( $format, @args ) ];
        return TRUE;
    },
    'base.cfg_bool'                  => sub { return shift ? TRUE : FALSE },
    'coding.helper.query_gpu_memory' => sub {
        $query_count++;
        return { ok => TRUE, total_mb => 12288, free_mb => 10445 };
    },
    'models.gguf.file.extract_attention'         => sub { return $shape },
    'coding.helper.calculate_partial_gpu_layers' => sub {
        $partial_calls++;
        return {
            computed_layers => 0,
            layer_count     => 41,
            explanation     => 'test refusal',
        };
    },
);

compile_module('coding.helper.calculate_safe_context');

my $spawn_path = File::Spec->catfile( $main::root_path,
    qw| src coding.spawn_inference_server | );
open( my $spawn_fh, '<', $spawn_path ) or die "cannot read $spawn_path : $!";
my $spawn_src = join( '', <$spawn_fh> );
close($spawn_fh);

my ($planner) = $spawn_src =~ m{
    ( ^ \x20{4} my\ \$experts .*?
      ^ \x20{4} \} \n \} )
}msx;
ok( defined $planner, 'extracted real moe planner block' );
die 'cannot continue without planner' if not defined $planner;

my ($fit_check) = $spawn_src =~ m{
    ( ^ \x20{4} \#\#\ vram\ sanity\ check .*?
      ^ \} \n )
}msx;
ok( defined $fit_check, 'extracted real vram fit-check block' );
die 'cannot continue without fit check' if not defined $fit_check;

sub sparse_file_of_mb {
    my $mb = shift;
    my ( $fh, $path ) = tempfile( UNLINK => 1 );
    truncate( $fh, $mb * 1024 * 1024 ) or die "truncate failed : $!";
    close($fh);
    return $path;
}

sub run_spawn_memory_path {
    my ( $model_path, $model_shape ) = @ARG;
    $shape         = $model_shape;
    @logs          = ();
    $query_count   = 0;
    $partial_calls = 0;
    %data          = (
        coding    => { cfg   => { vram_safety_mb => 1024 } },
        inference => { model => { context_length => 42500 } },
    );

    my $backend           = 'gpu';
    my $mmproj_path       = '';
    my $kv_cache_type     = 'f16';
    my $swa_compress      = FALSE;
    my $model_layer_count = $shape->{'block_count'};
    my $gpu_layers        = $model_layer_count;
    my ( $n_cpu_moe, $moe_offload_mb ) = ( 0, 0 );
    my ( $gpu_vram, $moe_vram_budget_mb );

    my $planner_code = p7_syntax__translate("if (1) {\n$planner");
    eval $planner_code;
    die "planner eval failed : $EVAL_ERROR" if length $EVAL_ERROR;

    my $fit_code = p7_syntax__translate("if (1) {\n$fit_check");
    eval $fit_code;
    die "fit-check eval failed : $EVAL_ERROR" if length $EVAL_ERROR;

    my $safe = $code{'coding.helper.calculate_safe_context'}->(
        {   model_path      => $model_path,
            mmproj_path     => $mmproj_path,
            backend         => $backend,
            kv_cache_type   => $kv_cache_type,
            swa_compress    => $swa_compress,
            offload_mb      => $moe_offload_mb,
            vram_budget_mb  => $n_cpu_moe > 0 ? $moe_vram_budget_mb : undef,
            gpu_layers      => $gpu_layers,
            layer_count     => $model_layer_count,
            handled_offload => $n_cpu_moe > 0 || ( $model_layer_count > 0
                and $gpu_layers < $model_layer_count ),
        }
    );
    return {
        n_cpu_moe     => $n_cpu_moe,
        gpu_layers    => $gpu_layers,
        layer_count   => $model_layer_count,
        offload_mb    => $moe_offload_mb,
        safe          => $safe,
        query_count   => $query_count,
        partial_calls => $partial_calls,
        logs          => [@logs],
    };
}

sub attention_shape {
    my ( $layers, $experts ) = @ARG;
    return {
        block_count      => $layers,
        head_count       => 8,
        head_count_kv    => [ (1) x $layers ],
        embedding_length => 4096,
        key_length       => 128,
        value_length     => 128,
        expert_bytes     => $experts,
    };
}

say ': 1. moe plan, fit check, and final context share free-vram budget';

## the logged 18 x 367.56 MB leaves 9754 MB, already above free minus the   ##
## reserve and with no kv headroom. this synthetic 41-layer shape therefore ##
## has 23 expert-bearing layers so the requested successful path is         ##
## reachable                                                                ##
my $expert_mb = 6616 / 18;
my $moe_model = sparse_file_of_mb(16370);
my $moe       = run_spawn_memory_path( $moe_model,
    attention_shape( 41, [ map { $_ * 1024 * 1024 } ($expert_mb) x 23 ] ) );
ok( $moe->{'n_cpu_moe'} == 23, 'planner offloads enough expert layers' );
ok( $moe->{'partial_calls'} == 0,
    'fit check passes without partial offload' );
ok( $moe->{'gpu_layers'} == $moe->{'layer_count'},
    'all 41 layers remain on gpu' );
ok( $moe->{'safe'}{'context_length'} >= 42500,
    "final context reaches the configured "
        . "floor [ $moe->{'safe'}{'context_length'} ]"
);
ok( $moe->{'safe'}{'context_length'} != 7777,
    'final context never uses the minimum fallback'
);
ok( $moe->{'query_count'} == 1, 'planner and fit check reuse one gpu query' );

say ': 2. dense model that fits keeps full offload and a safe context';

my $dense_model = sparse_file_of_mb(4000);
my $dense
    = run_spawn_memory_path( $dense_model, attention_shape( 8, undef ) );
ok( $dense->{'n_cpu_moe'} == 0,     'dense path performs no expert offload' );
ok( $dense->{'partial_calls'} == 0, 'dense path needs no partial offload' );
ok( $dense->{'safe'}{'context_length'} >= 42500,
    'dense context still reaches the floor'
);

say ': 3. impossible fit keeps the level-0 refusal';

my $huge_model = sparse_file_of_mb(30000);
my $huge = run_spawn_memory_path( $huge_model, attention_shape( 41, undef ) );
ok( scalar( grep { $ARG->[1] =~ m|insufficient vram| } @{ $huge->{'logs'} } )
        == 1,
    'impossible model refuses the spawn'
);
ok( scalar(
        grep { $ARG->[0] == 0 and $ARG->[1] =~ m|insufficient vram| }
            @{ $huge->{'logs'} }
    ) == 1,
    'insufficient-vram refusal remains level 0'
);

say ': 4. final handled offload fit warning is level 1, real failure level 0';

@logs = ();
$code{'coding.helper.calculate_safe_context'}->(
    {   model_path      => $huge_model,
        backend         => 'gpu',
        vram_total_mb   => 12288,
        handled_offload => TRUE,
    }
);
ok( scalar(
        grep { $ARG->[0] == 1 and $ARG->[1] =~ m|does not fit GPU| } @logs
    ) == 1,
    'handled offload downgrades only the expected fit warning'
);

@logs = ();
$code{'coding.helper.calculate_safe_context'}->(
    { model_path => $huge_model, backend => 'gpu', vram_total_mb => 12288 } );
ok( scalar(
        grep { $ARG->[0] == 0 and $ARG->[1] =~ m|does not fit GPU| } @logs
    ) == 1,
    'unhandled fit failure remains level 0'
);

say '';
if ($fail_count) {
    say "FAILED : $fail_count check[s]";
    exit 1;
}
say 'all checks passed';
exit 0;

#,,,,,,..,,.,,,,.,,..,,.,,,.,,,..,,..,.,.,,,.,..,,...,...,..,,...,.,,,,.,,,..,
#QOOHWKHLF3XJ5R2EMIY4AINICVTT2MJUUCZW3IUTPXI3CZREDIJ4PNTNLDPUY4HKLE75TCS6HEI6Q
#\\\|CLVWXRTLHD2RAUSJSUOFIK25B5TIXORRP6GMTNEHLZYDKPO33KE \ / AMOS7 \ YOURUM ::
#\[7]HQA7ZZLHFPOCNSAMM5APG42VTFZRXP2EALXMWJX4QRE75SXYC2DI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
