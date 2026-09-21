#!/usr/bin/perl
use v5.24;
use strict;
use English;
use warnings;

###                                                            ###
## model_batch harness smoke test                               ##
###                                                            ###

##        compiles the REAL translated source of the model_batch            ##
##        blob store, manifest, gate, capture/revert/verify, record         ##
##        store and the poll_batch runner against an in-process             ##
##        %data / %code stub environment -- no live coding zenka            ##
##        required. covers the option-D decision tree [ 2026-09-21 ]        ##
##        :                                                                 ##
##                                                                          ##
##        1. blob store round-trip + CAS dedup [ xz+base32 pack             ##
##        format ]                                                          ##
##        2. manifest build/diff/checksum + .git/state/dotfile              ##
##        excludes                                                          ##
##        3. gate : dirty refuses, :force: captures and proceeds            ##
##        4. full per-(model,task) cycle : task edits tree ->               ##
##        capture -> revert -> reverify clean -> tree identical to          ##
##        baseline                                                          ##
##        5. record persistence via stubbed zenka_dir                       ##
##        6. runner end-to-end : gate -> switch -> submit [ task            ##
##        edits tree ] -> settle -> restore -> advance -> finish            ##

use File::Spec;
use File::Temp qw| tempdir |;
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
use YAML::XS                  ();
use IO::Compress::Xz          ();
use IO::Uncompress::UnXz      ();
use Digest::SHA               ();

use constant TRUE    => 5;
use constant FALSE   => 0;
use constant UNKNOWN => 2;

use File::Spec::Functions qw| canonpath catfile catdir |;
use File::Path            qw| make_path |;

our %data;
our %code;
our $call;

my $fail_count = 0;

sub ok {
    my ( $cond, $label ) = @ARG;
    if ($cond) {
        print "ok   : $label\n";
    } else {
        $fail_count++;
        print "FAIL : $label\n";
    }
    return $cond;
}

##[ stub environment ]########################################################

my $tmp_root = tempdir( CLEANUP => 1 );
my $var_dir  = catdir( $tmp_root, 'var' );
my $tree_dir = catdir( $tmp_root, 'tree' );
make_path($var_dir);
make_path($tree_dir);

## deterministic BASE32 [ RFC4648, uppercase, padded ] for stub checksums ##
my @B32 = ( 'A' .. 'Z', 2 .. 7 );

sub b32_encode {
    my $bytes = shift;
    my $bits  = unpack qw| B* |, $bytes;
    $bits .= '0' x ( ( 5 - length($bits) % 5 ) % 5 );
    return join '', map { $B32[ oct "0b$ARG" ] } $bits =~ m{(.{5})}g;
}

sub stub_checksum {
    return b32_encode( Digest::SHA::sha256( $_[0] ) );
}

%data = (
    'system' => {
        'root_path'       => $tree_dir,
        'conf_path'       => $tmp_root,
        'zenka'           => { 'name'       => 'coding' },
        'path'            => { 'zenka-dirs' => { 'var_P7' => $var_dir } },
        'inference'       => {},
        'amos-zenka-user' => 'nobody',
    },
    'coding' => {
        'inference_servers' => {
            'gpu' => {
                'status' => 'ready',
                'pid'    => 1000,
                'model'  => 'ORIGINALMODEL000000000000000000000000000'
                    . '00000000000000000000000000000000000000000',
            },
        },
        'state' =>
            { 'backend' => { 'gpu' => { 'lock' => '', 'queue' => [] } } },
        'task' => { 'queue' => {}, 'active' => [] },
    },
    'inference' => {
        'backend' =>
            { 'gpu' => { 'model_id' => '' }, 'cpu' => { 'model_id' => '' } },
        'model' => {
                  'amos_id' => 'ORIGINALMODEL00000000000000000000000000000'
                . '000000000000000000000000000000000000000'
        },
    },
    'coding.cfg' => { 'switch_model_max_wait' => 300 },
);

my @logs;
my @timers;

%code = (
    'base.logs' => sub {
        my ( $level, $fmt, @args ) = @ARG;
        push @logs, sprintf( $fmt, @args );
        return TRUE;
    },
    'base.s_warn' => sub { return TRUE },
    'base.time'   => sub { return 10_000 },
    'base.ntime'  => sub { return 3211206825624 },
    'base.gen_id' => sub {
        my $href = shift // {};
        my $id   = 1;
        $id++ while exists $href->{$id};
        return "$id";
    },
    'base.cnt_s'      => sub { return $_[0] == 1 ? '' : 's' },
    'event.add_timer' => sub {
        my $params = shift;
        push @timers, $params;
        return bless { 'params' => $params, 'active' => 1 }, 'FakeTimer';
    },

    ## filesystem ##
    'file.read' => sub {
        my $path = shift;
        open( my $fh, '<:encoding(UTF-8)', $path ) or return undef;
        my $content = do { local $INPUT_RECORD_SEPARATOR = undef; <$fh> };
        close($fh);
        return $content;
    },
    'file.write' => sub {
        my ( $path, $content ) = @ARG;
        if ( my $parent = $path =~ m{^(.*)/[^/]+$} ? $1 : '' ) {
            make_path($parent) if length $parent and !-d $parent;
        }
        open( my $fh, '>:encoding(UTF-8)', $path ) or return FALSE;
        print {$fh} $content;
        close($fh);
        return TRUE;
    },
    'file.slurp' => sub {
        my $path = shift;
        open( my $fh, '<:raw', $path ) or return undef;
        my $content = do { local $INPUT_RECORD_SEPARATOR = undef; <$fh> };
        close($fh);
        return \$content;
    },
    'file.path.make_dir' => sub {
        make_path(shift);
        return TRUE;
    },
    'file.all_files' => sub {
        my ( $path, $arg ) = @ARG;
        my $recursive = ( defined $arg and $arg eq qw| recursive | );
        my @out;
        my @dirs = ($path);
        while (@dirs) {
            my $dir = shift @dirs;
            opendir( my $dh, $dir ) or next;
            my @entries = sort readdir($dh);
            closedir($dh);
            for my $entry (@entries) {
                next if $entry =~ m|^\.{1,2}$|;
                my $full = catfile( $dir, $entry );
                push @out,  canonpath($full) if -f $full;
                push @dirs, $full            if -d $full and $recursive;
            }
        }
        return \@out;
    },
    'file.zenka_dir.data_path' => sub { return catdir( $var_dir, 'coding' ) },
    'file.zenka_dir.load'      => sub {
        my $rel = shift;
        my $abs = catfile( $var_dir, 'coding', $rel );
        return undef unless -f $abs;
        open( my $fh, '<:raw', $abs ) or return undef;
        my $c = do { local $INPUT_RECORD_SEPARATOR = undef; <$fh> };
        close($fh);
        return \$c;
    },
    'file.zenka_dir.write' => sub {
        my ( $rel, $sref ) = @ARG;
        my $abs = catfile( $var_dir, 'coding', $rel );
        if ( my $parent = $abs =~ m{^(.*)/[^/]+$} ? $1 : '' ) {
            make_path($parent) if length $parent;
        }
        open( my $fh, '>:raw', $abs ) or return undef;
        print {$fh} ref $sref eq qw| SCALAR | ? $sref->$* : $sref;
        close($fh);
        chmod 0640, $abs;
        return length( ref $sref eq qw| SCALAR | ? $sref->$* : $sref );
    },

    ## checksum family [ deterministic stub, BASE32-shaped ] ##
    'base.chk-sum.bmw.filesum' => sub {
        my ( $bits, $path ) = @ARG;
        return undef unless -f $path;
        open( my $fh, '<:raw', $path ) or return undef;
        my $c = do { local $INPUT_RECORD_SEPARATOR = undef; <$fh> };
        close($fh);
        return stub_checksum($c);
    },
    'base.chk-sum.bmw.strsum' => sub {
        my ( $input, $bits ) = @ARG;
        return stub_checksum(
            ref $input eq qw| SCALAR | ? $input->$* : $input );
    },

    ## base32 ##
    'base32.encode' => sub { return b32_encode( $_[0] ) },
    'base32.decode' => sub {
        my $b32  = shift;
        my $bits = join '', map {
            my $v = index( join( '', @B32 ), $_ );
            sprintf qw| %05b |, $v
        } split //, $b32;
        return pack qw| B* |, $bits;
    },
    'base.perlmod.autoload' => sub { return TRUE },

    ## yaml ##
    'format.yaml.dump_str'  => sub { return YAML::XS::Dump( $_[0] ) },
    'format.yaml.load_str'  => sub { return YAML::XS::Load( $_[0] ) },
    'format.yaml.load_file' => sub {
        my $path = shift;
        return eval { YAML::XS::LoadFile($path) };
    },

    ## inference + queue machinery stubs ##
    'coding.helper.backend_idle' => sub {
        return { idle => 1, active => 0, in_flight => 0 };
    },
    'coding.async.backend_acquire' => sub {
        my ( $lock_id, $backend ) = @ARG;
        $data{'coding'}{'state'}{'backend'}{$backend}{'lock'} = $lock_id;
        return { acquired => 1 };
    },
    'coding.async.backend_release' => sub {
        my ( $lock_id, $backend ) = @ARG;
        my $bs = $data{'coding'}{'state'}{'backend'}{$backend};
        $bs->{'lock'} = '' if defined $bs and $bs->{'lock'} eq $lock_id;
        return TRUE;
    },
    'coding.async.state_machine' => sub { return {} },
    'coding.async.stream_tps'    => sub {
        my $mode = shift;
        return
              $mode eq qw| get_tps |  ? 20
            : $mode eq qw| is_alive | ? FALSE
            :                           undef;
    },
    'coding.cmd.inference-status' => sub {
        return {
            qw| mode | => qw| true |,
            qw| data | => YAML::XS::Dump(
                {   'gpu' => {
                        'status' =>
                            $data{'coding'}{'inference_servers'}{'gpu'}
                            {'status'},
                        'pid' => $data{'coding'}{'inference_servers'}{'gpu'}
                            {'pid'},
                        'model_id' =>
                            $data{'coding'}{'inference_servers'}{'gpu'}
                            {'model'},
                    }
                }
            )
        };
    },
    'coding.cmd.switch-model' => sub {
        my $params = shift             // {};
        my $args   = $params->{'args'} // '';
        my ( $model, $backend_arg ) = split m{ +}, $args;
        my $backend
            = ( $backend_arg // '' ) =~ m{backend=(\w+)} ? $1 : qw| gpu |;
        ## simulate kill+respawn : pid changes, new model reports ready ##
        $data{'coding'}{'inference_servers'}{$backend}{'pid'}++;
        $data{'coding'}{'inference_servers'}{$backend}{'model'} = $model;
        $data{'coding'}{'inference_servers'}{$backend}{'status'}
            = qw| ready |;
        $data{'inference'}{'backend'}{$backend}{'model_id'} = $model;
        $data{'inference'}{'model'}{'amos_id'} = $model;
        return { qw| mode | => qw| true | };
    },
    'coding.cmd.submit' => sub {
        my $params = shift                         // {};
        my $prompt = $params->{'param'}{'request'} // '';
        state $seq = 0;
        $seq++;
        my $task_id = sprintf qw| task-%04d |, $seq;

        ## simulate the model's work : edit one file, create one file ##
        open( my $fh, '>>:encoding(UTF-8)',
            catfile( $tree_dir, qw| lib module.pm | ) )
            or die $OS_ERROR;
        print {$fh} "# task $task_id was here\n";
        close($fh);
        $code{'file.write'}->( catfile( $tree_dir, qw| scratch | ),
            "created by $task_id\n" );

        $data{'coding'}{'task'}{'queue'}{$task_id} = {
            'execution' => {
                'status' => qw| completed |,
                'result' => "done : $prompt",
            }
        };
        return {
            qw| mode | => qw| size |,
            qw| data | => sprintf 'task:%s|type:code|routed:gpu',
            $task_id
        };
    },
    'coding.cmd.abort-inference' => sub {
        return { qw| mode | => qw| false | };
    },
    'iteration.score_result' => sub {
        return {
            qw| score |   => 1.0,
            qw| passed |  => 1,
            qw| total |   => 1,
            qw| verdict | => qw| advance |,
        };
    },
);

sub compile_module {
    my $module_name = shift;
    my $src_path
        = File::Spec->catfile( $main::root_path, 'src', $module_name );
    open( my $fh, '<', $src_path ) or die "cannot read $src_path : $!";
    my $src = join( '', <$fh> );
    close($fh);
    $src =~ s{\n#,[^\n]*\n#[A-Z2-7]{40,}[^\n]*\n#\\\\\\\|.*\z}{}s;
    my $translated = p7_syntax__translate($src);
    my $cref       = eval "sub {\n# line 1 \"$module_name\"\n$translated\n}";
    die "compile failed for $module_name : $EVAL_ERROR"
        if not defined $cref;
    $code{$module_name} = $cref;
    return $cref;
}

for my $module (
    qw| model_batch.blob.path        model_batch.blob.store
    model_batch.blob.read        model_batch.blob.restore
    model_batch.manifest.build   model_batch.manifest.diff
    model_batch.manifest.checksum model_batch.manifest.persist
    model_batch.baseline.pack    model_batch.gate.check
    model_batch.capture.task     model_batch.revert.to_baseline
    model_batch.verify.clean     model_batch.diff.text
    model_batch.spec.load        coding.model_batch.record
    coding.model_batch.handler.poll_batch base.diff_array |
) {
    compile_module($module);
}

sub call_m {
    my ( $name, @args ) = @ARG;
    return $code{$name}->(@args);
}

##[ 1. blob store round-trip + CAS dedup ]####################################

my $blob_src = catfile( $tmp_root, qw| blob-src.txt | );
$code{'file.write'}->( $blob_src, "hello blob store \x{263A}\n" );

my $cs_one = call_m( 'model_batch.blob.store', $blob_src );
ok( defined $cs_one,                  'blob.store returns a checksum' );
ok( $cs_one =~ m{^[A-Z2-7]{20,128}$}, 'checksum is BASE32-shaped' );

my $blob_dir = call_m('model_batch.blob.path');
ok( -f catfile( $blob_dir, "$cs_one.mxz.B32" ),
    'packed blob landed as <checksum>.mxz.B32'
);

my $cs_two = call_m( 'model_batch.blob.store', $blob_src );
ok( $cs_one eq $cs_two, 'identical content -> identical checksum [ CAS ]' );
my @blob_files = grep { !/^\./ } do {
    opendir( my $dh, $blob_dir );
    my @e = readdir($dh);
    closedir($dh);
    @e;
};
ok( scalar(@blob_files) == 1, 'identical content packed exactly once' );

my $roundtrip = call_m( 'model_batch.blob.read', $cs_one );
ok( defined $roundtrip and $roundtrip eq "hello blob store \x{263A}\n",
    'blob.read round-trips content through xz+base32' );

my $restore_dest = catfile( $tmp_root, qw| deep dir restored.txt | );
ok( call_m( 'model_batch.blob.restore', $cs_one, $restore_dest ),
    'blob.restore reports success' );
ok( $code{'file.read'}->($restore_dest) eq "hello blob store \x{263A}\n",
    'restored content matches original' );

##[ 2. manifest build / diff / checksum + excludes ]##########################

make_path( catdir( $tree_dir, qw| .git objects | ) );
make_path( catdir( $tree_dir, qw| state | ) );
make_path( catdir( $tree_dir, qw| lib | ) );
$code{'file.write'}->( catfile( $tree_dir, qw| .git objects x | ), 'git' );
$code{'file.write'}->( catfile( $tree_dir, qw| .hidden | ),        'dot' );
$code{'file.write'}->( catfile( $tree_dir, qw| state runtime.yaml | ), 'st' );
$code{'file.write'}
    ->( catfile( $tree_dir, qw| lib module.pm | ), "package m;\n1;\n" );
$code{'file.write'}->( catfile( $tree_dir, qw| README | ), "readme\n" );

my $manifest_one = call_m('model_batch.manifest.build');
ok( ref $manifest_one eq qw| HASH |, 'manifest.build returns a hashref' );
ok( !grep( m{^\.git/}, keys $manifest_one->%* ),
    '.git/ excluded from manifest' );
ok( !grep( m{^state/}, keys $manifest_one->%* ),
    'state/ excluded from manifest' );
ok( !grep( m{(?:^|/)\.}, keys $manifest_one->%* ),
    'dotfiles excluded from manifest' );
ok( exists $manifest_one->{'lib/module.pm'}
        and exists $manifest_one->{'README'},
    'regular files present in manifest'
);

## mutate : change one, add one, remove one ##
$code{'file.write'}->( catfile( $tree_dir, qw| README | ), "readme v2\n" );
$code{'file.write'}->( catfile( $tree_dir, 'new file' ), "new\n" );
unlink catfile( $tree_dir, qw| lib module.pm | );

my $manifest_two = call_m('model_batch.manifest.build');
my $mdiff
    = call_m( 'model_batch.manifest.diff', $manifest_one, $manifest_two );
ok( $mdiff->{'changed'}->[0] eq qw| README |, 'diff reports changed path' );
ok( $mdiff->{'added'}->[0] eq 'new file',     'diff reports added path' );
ok( $mdiff->{'removed'}->[0] eq qw| lib/module.pm |,
    'diff reports removed path' );

ok( call_m( 'model_batch.manifest.checksum', $manifest_one ) eq
        call_m( 'model_batch.manifest.checksum', $manifest_one ),
    'manifest checksum is deterministic'
);
ok( call_m( 'model_batch.manifest.checksum', $manifest_one ) ne
        call_m( 'model_batch.manifest.checksum', $manifest_two ),
    'manifest checksum differs across manifests'
);

##[ 3. gate : refuse / force-capture ]########################################

my $batch_id = qw| smoke-test |;

## tree currently DIRTY vs a fresh baseline : restore the mutations first ##
$code{'file.write'}
    ->( catfile( $tree_dir, qw| lib module.pm | ), "package m;\n1;\n" );
unlink catfile( $tree_dir, 'new file' );
$code{'file.write'}->( catfile( $tree_dir, qw| README | ), "readme\n" );

my $gate_clean = call_m( 'model_batch.gate.check',
    { qw| batch_id | => $batch_id, qw| force | => FALSE } );
ok( ref $gate_clean eq qw| HASH | and $gate_clean->{'clean'},
    'first gate captures baseline and passes clean'
);
ok( $gate_clean->{'baseline_new'}, 'first gate marks baseline as new' );

## dirty the tree again, gate must refuse without :force: ##
$code{'file.write'}->( catfile( $tree_dir, qw| README | ), "owner edit\n" );
my $gate_refuse = call_m( 'model_batch.gate.check',
    { qw| batch_id | => $batch_id, qw| force | => FALSE } );
ok( !$gate_refuse->{'clean'}, 'dirty tree refuses the gate' );
ok( $gate_refuse->{'diff'}{'changed'}->[0] eq qw| README |,
    'refusal carries the diff list' );

my $blobs_before = scalar @blob_files;
my $gate_forced  = call_m( 'model_batch.gate.check',
    { qw| batch_id | => $batch_id, qw| force | => TRUE } );
ok( $gate_forced->{'clean'} and $gate_forced->{'forced'},
    ':force: gate proceeds and is marked forced'
);
my $forced_cs
    = call_m( 'model_batch.blob.store', catfile( $tree_dir, qw| README | ) );
ok( -f catfile( $blob_dir, "$forced_cs.mxz.B32" ),
    ':force: gate blob-stores the dirty path immediately'
);

## restore pre-existing drift so the runner starts clean ##
$code{'file.write'}->( catfile( $tree_dir, qw| README | ), "readme\n" );

##[ 4. full capture -> revert -> reverify cycle ]#############################

my $pack_result = call_m( 'model_batch.baseline.pack', $batch_id );
ok( ref $pack_result eq qw| HASH | and $pack_result->{'present'} > 0,
    'baseline pack stores every baseline path' );

my $baseline_href
    = call_m( 'model_batch.manifest.persist', qw| load |, $batch_id );

## simulate a task run : change + add + remove ##
$code{'file.write'}->( catfile( $tree_dir, qw| README | ), "model edit\n" );
$code{'file.write'}->( catfile( $tree_dir, qw| model-new | ), "mn\n" );
unlink catfile( $tree_dir, qw| .hidden | );    ## no-op : not in manifest ##

my $capture = call_m( 'model_batch.capture.task',
    { qw| baseline | => $baseline_href } );
ok( ref $capture eq qw| HASH |, 'capture.task returns a result' );
ok( ( grep { $_ eq qw| README | } $capture->{'files_touched'}->@* )
        and
        ( grep { $_ eq qw| model-new | } $capture->{'files_touched'}->@* ),
    'capture lists touched files'
);
ok( $capture->{'paths'}{'README'}{'before'} ne
        $capture->{'paths'}{'README'}{'after'},
    'capture records before/after checksum pairs'
);

my $revert_ok = call_m( 'model_batch.revert.to_baseline',
    { qw| baseline | => $baseline_href, qw| capture | => $capture } );
ok( $revert_ok, 'revert.to_baseline reports success' );
ok( !-f catfile( $tree_dir, qw| model-new | ),
    'baseline-absent path deleted' );

my $verify = call_m( 'model_batch.verify.clean', $batch_id );
ok( ref $verify eq qw| HASH | and $verify->{'clean'},
    'reverify confirms tree matches baseline exactly'
);
ok( $code{'file.read'}->( catfile( $tree_dir, qw| README | ) ) eq "readme\n",
    'changed path restored to baseline content'
);

## lazy diff at review time ##
my $diff_str = call_m(
    'model_batch.diff.text',
    $capture->{'paths'}{'README'}{'before'},
    $capture->{'paths'}{'README'}{'after'}
);
ok( defined $diff_str
        and $diff_str =~ m{^\-readme$}m
        and $diff_str =~ m{^\+model\ edit$}m,
    'lazy diff recomputed from two checksum blobs'
);

##[ 5. record persistence ]###################################################

my $record_reply = call_m(
    'coding.model_batch.record',
    {   qw| batch_id | => $batch_id,
        qw| model |    => 'CANDIDATE0000000000000000000000000000000'
            . '0000000000000000000000000000000000000000',
        qw| entry | => {
            qw| task_id | => qw| task-1 |,
            qw| verdict | => qw| completed |,
        },
    }
);
ok( $record_reply->{'mode'} eq qw| true |, 'record write reports success' );
my $record_yaml = call_m( 'file.zenka_dir.load',
    qw| state/model_batch/smoke-test/CANDIDATE00000000000000000000000000000000000000000000000000000000000000000000000.yaml |
);
ok( defined $record_yaml and $$record_yaml =~ m{verdict:\ completed},
    'record persisted under state/model_batch/<batch>/<model>.yaml'
);

##[ 6. runner end-to-end ]####################################################

@timers = ();
@logs   = ();

my $candidate
    = 'CANDIDATE0000000000000000000000000000000'
    . '0000000000000000000000000000000000000000';

$data{'coding'}{'model_batch_state'} = {
    qw| batch_id | => $batch_id,
    qw| backend |  => qw| gpu |,
    qw| spec |     => {
        qw| batch_spec_version | => 1,
        qw| reference_tps |      => 20,
        qw| tasks |              => [
            {   qw| id |          => qw| task-A |,
                qw| prompt |      => 'do the thing',
                qw| budget_hint | => 300,
                qw| criteria |    => ['readme'],
            },
        ],
    },
    qw| candidates |  => [$candidate],
    qw| idx |         => 0,
    qw| task_idx |    => 0,
    qw| phase |       => qw| gate |,
    qw| state |       => qw| running |,
    qw| force |       => FALSE,
    qw| no_yield |    => TRUE,
    qw| started |     => 0,
    qw| switch_id |   => '',
    qw| baseline |    => $baseline_href,
    qw| baseline_cs | =>
        call_m( 'model_batch.manifest.checksum', $baseline_href ),
    qw| last_observed_tps | => 0,
    qw| tps_scale |         => 1,
    qw| breaker |           => { qw| signature | => '', qw| count | => 0 },
};

my $event = bless {
    'data'   => {},
    'active' => 1,
    },
    'FakeEvent';

sub tick { $code{'coding.model_batch.handler.poll_batch'}->($event) }

tick();    ## gate -> switch ##
my $state = $data{'coding'}{'model_batch_state'};
ok( $state->{'phase'} eq qw| switch |,
    'runner: gate phase ' . 'advanced to switch' );

tick();    ## switch -> waiting_ready ##
$state = $data{'coding'}{'model_batch_state'};
ok( $state->{'phase'} eq qw| waiting_ready |,
    'runner: lock acquired, switch issued'
);
ok( $data{'coding'}{'self_test_switch_in_progress'},
    'runner: self_test_switch_in_progress set for the candidate cycle' );
ok( ( $data{'coding'}{'state'}{'backend'}{'gpu'}{'lock'} // '' )
        =~ m{^batch:},
    'runner: batch backend lock held'
);

tick();    ## waiting_ready -> task_start [ pid changed ] ##
$state = $data{'coding'}{'model_batch_state'};
ok( $state->{'phase'} eq qw| task_start |,
    'runner: switch confirmed by pid change'
);

tick();    ## task_start -> task_wait [ submit ] ##
$state = $data{'coding'}{'model_batch_state'};
ok( $state->{'phase'} eq qw| task_wait |,
    'runner: task submitted through queue machinery' );

tick();    ## task_wait -> settle -> task_start/restore ##
$state = $data{'coding'}{'model_batch_state'};
ok( $state->{'phase'} eq qw| restore |,
    'runner: task settled [ capture/revert/reverify ] -> restore' );

## the stubbed task edited README and created scratch/ -- both reverted ##
ok( $code{'file.read'}->( catfile( $tree_dir, qw| README | ) ) eq "readme\n",
    'runner: task tree edits reverted to baseline content'
);
ok( !-e catfile( $tree_dir, qw| scratch | ),
    'runner: task-created file deleted after revert'
);

tick();    ## restore -> restoring ##
tick();    ## restoring -> gate [ idx 1 == total ] ##
tick();    ## gate sees idx >= total -> finish ##
$state = $data{'coding'}{'model_batch_state'};
ok( !defined $state, 'runner: batch finished and state cleared' );
ok( !$data{'coding'}{'self_test_switch_in_progress'},
    'runner: self_test_switch_in_progress cleared at finish'
);
ok( $data{'coding'}{'state'}{'backend'}{'gpu'}{'lock'} eq '',
    'runner: backend lock released at finish' );

my $cursor_yaml
    = call_m( 'file.zenka_dir.load', qw| state/model_batch_cursor.yaml | );
ok( defined $cursor_yaml and $$cursor_yaml !~ m{batch:},
    'runner: cursor cleared from disk at finish'
);

my $model_record = call_m( 'file.zenka_dir.load',
    "state/model_batch/$batch_id/$candidate.yaml" );
ok( defined $model_record
        and $$model_record =~ m{task-A}
        and $$model_record =~ m{verdict:\ completed}
        and $$model_record =~ m{fingerprint},
    'runner: per-task record written with verdict + fingerprint'
);

print "\n",
    ( $fail_count ? "$fail_count " . "FAILURE(S)\n" : "all checks passed\n" );
exit( $fail_count ? 1 : 0 );

##[ fake event wrapper ]######################################################

package FakeEvent {
    use strict;
    use English;

    sub w         {shift}
    sub data      { shift->{'data'} }
    sub is_active { shift->{'active'} }
    sub cancel    { shift->{'active'} = 0; return }
}

package FakeTimer {
    use strict;
    use English;

    sub is_active { shift->{'active'} }
    sub cancel    { shift->{'active'} = 0; return }
    sub data      { shift->{'params'}{'data'} }
}

#,,.,,,,.,,.,,..,,.,.,,.,,...,.,,,..,,,,.,,,,,..,,...,...,...,...,,.,,,..,,,,,
#7R2JXP5U7FCYJ3HLZEZU5P2CR5BYH2JHWXWB77VW3YUKMYTNIUNPISUQKRDT5XJ2NWHF7GTM5X4VU
#\\\|Q25JOOCU5BCBIDKHEFUFFB7AEBRC5CFQDS72M2XY7HIFMIT2IPE \ / AMOS7 \ YOURUM ::
#\[7]SRXOU7UIX5QQUO5GQXLR4DV7PISSQQS6EESD3HEQ7IEEIYU5TIDQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
