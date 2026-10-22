#!/usr/bin/env perl
use v5.24;
use strict;
use English;
use warnings;

## the production runtime [ bin/Protocol-7 : use utf8 + Encode ] loads the ##
## bytes pragma transitively ; keep it so compiled modules resolve it.     ##
use bytes;

##     models discovery : scan-path-add vs models.discover :re-scan:        ##
##     disagreed [ host symptom after 7fd8ca329 : configured                ##
##     /data/models entry is non-recursive, scan-path-add registers the     ##
##     same path recursively, and the merge in                              ##
##     models.discover.scan_all_paths deduplicated by path string --        ##
##     keeping the configured entry and dropping the recursive one ]        ##
##                                                                          ##
##     drives the REAL scanner modules against a tempdir laid out           ##
##     <publisher>/<repo>/<file>.gguf :                                     ##
##     - scan_directory recursive vs non-recursive on that layout           ##
##     - configured search path that does not exist + added path ->         ##
##     discover finds the files                                             ##
##     [ legacy-added and canonical-added shapes ]                          ##
##     - duplicates across models.scan_paths and                            ##
##     models.storage.search_paths are not double-counted                   ##
##     - composite registry ids are stable between scan-path-add and        ##
##     models.registry.populate_from_discovery                              ##
##     - scan-path-del removes the canonical entry as well empty            ##
##     placeholder .gguf files are accepted : extract_metadata fails        ##
##     its 24-byte header read and falls back to filename-based naming.     ##

use File::Spec;
use Cwd        qw| abs_path |;
use FindBin    qw| $RealBin |;
use File::Temp qw| tempdir |;

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

our %code;
our %data;

$OUTPUT_AUTOFLUSH = 1;

my $fail_count = 0;
my $pass_count = 0;

sub ok ($;$) {
    my ( $cond, $label ) = @ARG;
    if ($cond) { $pass_count++; say "  ok   : $label"; return }
    $fail_count++;
    say "  FAIL : $label";
    return;
}

## $prefix : source prepended inside the compiled sub [ constants ]        ##
my $runtime_pragmas = q{no bytes; use File::stat; use File::Spec;
    use File::Spec::Functions qw| catfile |;
    use open qw| :encoding(UTF-8) |;};
my $module_prefix = q{use constant TRUE => 5; use constant FALSE => 0;};

sub compile_module {
    my ( $module_name, $prefix ) = @ARG;
    $prefix //= $module_prefix;
    my $src_path
        = File::Spec->catfile( $main::root_path, 'src', $module_name );
    open( my $fh, '<', $src_path ) or die "cannot read $src_path : $!";
    my $src = join( '', <$fh> );
    close($fh);
    my $translated = p7_syntax__translate($src);
    my $cref
        = eval "$runtime_pragmas sub {\n$prefix\n# "
        . "line 1 \"$module_name\"\n$translated\n}";
    die "compile failed for $module_name : $EVAL_ERROR"
        if not defined $cref;
    $code{$module_name} = $cref;
    return $cref;
}

my $cmd_header = 'my $call = {}; if ( ref( $ARG[0] ) eq q|HASH| ) { $call '
    . '= $ARG[0] } else { $call->{q|args|} = $ARG[0] }';

## ---------------------------------------------------------------------- ##
## stubs                                                                  ##

my @logged;
my @complaints;
my @action_buffer;
my $saved_registry;

$code{'base.logs'} = sub { push @logged, [@ARG]; return };
$code{'base.log'}  = sub { push @logged, [@ARG]; return };
$code{'base.s_warn'}
    = sub { push @complaints, sprintf( shift, @ARG ); return };
$code{'base.ntime'}         = sub { return 0 };
$code{'base.anum_log_time'} = sub { return 'TS' };
$code{'base.buffer.add_line'}
    = sub { push @action_buffer, $ARG[1]; return };
$code{'models.storage.yaml_load'} = sub { return {} };
$code{'models.storage.yaml_save'} = sub {
    $saved_registry = $ARG[0];
    return length join '', keys $ARG[0]->%*;
};
## deterministic stand-in for the AMOS checksum : distinct inputs give      ##
## distinct 7-digit ids, and both checksum modules share it -- which is all ##
## the id-stability contract needs here                                     ##
$code{'chk-sum.amos'} = sub {
    my $in = join '', map { defined $ARG ? $ARG : '' } @ARG;
    return sprintf( '%07d', unpack( '%32C*', $in ) % 10000000 );
};
$code{'models.gguf.file.file_type_to_quant'} = sub { return 'unknown' };
$code{'models.storage.adapter.discover_all'} = sub { return [] };

my @perl_warnings;
local $SIG{__WARN__} = sub { push @perl_warnings, @ARG };

## ---------------------------------------------------------------------- ##
## the real modules under test                                            ##

compile_module($_) for qw|
    models.gguf.file.extract_metadata
    models.gguf.file.is_garbage_name
    models.gguf.file.name_diverges
    models.gguf.file.extract_name
    models.discover.scan_directory
    models.storage.discover_directory
    models.discover.scan_all_paths
    models.checksum.from_path
    models.checksum.from_metadata
    models.registry.populate_from_discovery
    |;

compile_module( 'models.cmd.scan-path-add',
    $module_prefix . "\n" . $cmd_header );
compile_module( 'models.cmd.scan-path-del',
    $module_prefix . "\n" . $cmd_header );

## ---------------------------------------------------------------------- ##
## temp dir with the publisher/repo/file layout                           ##

my $tmp = tempdir( 'p7-models-disc-XXXXXXXX', TMPDIR => 1, CLEANUP => 1 );

my $models_root = "$tmp/data/models";

my @model_files = (
    "$models_root/mradermacher/Qwen3.8-9B-heretic-uncensore"
        . "d-i1-GGUF/Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf",
    "$models_root/bartowski/TestModel-7B-GGUF/TestModel-7B-Q6_K.gguf"
);

foreach my $file_path (@model_files) {
    my $parent_dir = ( $file_path =~ m|^(.*)/[^/]+$| )[0];
    system( 'mkdir', '-p', $parent_dir ) == 0 or die 'mkdir model dir';
    open( my $fh, '>', $file_path ) or die "placeholder gguf : $OS_ERROR";
    close($fh);
}

sub reset_models_state {
    $data{'models'} = {};
    return;
}

sub call_cmd {
    my ( $module_name, $arg ) = @ARG;
    return $code{$module_name}->( { 'args' => $arg } );
}

sub discovered_paths {
    my $found = $code{'models.discover.scan_all_paths'}->();
    return [ sort map { $ARG->{'path'} } @$found ];
}

## ---------------------------------------------------------------------- 1 ##
## : the scanner itself on this layout                                      ##

say "\n :. scan_directory on publisher/repo/file layout";

my $deep_scan
    = $code{'models.discover.scan_directory'}->( $models_root, TRUE );
ok( ref $deep_scan eq qw| ARRAY |, 'recursive scan returns arrayref' );
ok( scalar @$deep_scan == 2,       'recursive scan finds both models' );

my $flat_scan
    = $code{'models.discover.scan_directory'}->( $models_root, FALSE );
ok( scalar @$flat_scan == 0,
    'non-recursive scan finds nothing at depth 3 [ root cause ]' );

my $missing_scan
    = $code{'models.discover.scan_directory'}->("$tmp/no-such-dir");
ok( ref $missing_scan eq qw| ARRAY | && scalar @$missing_scan == 0,
    'missing directory scans to empty result' );

## ---------------------------------------------------------------------- 2 ##
## : host shape -- configured paths only would find nothing ; the legacy    ##
## added-path entry must upgrade the configured duplicate                   ##

say "\n :. legacy host shape [ configured non-recursive + scan-path-add ]";

reset_models_state();
$data{'models'}{'storage'}{'search_paths'} = [
    {   'path'      => "$tmp/does-not-exist",
        'enabled'   => TRUE,
        'recursive' => TRUE,
        'tier'      => 3
    },
    {   'path'    => $models_root,
        'enabled' => TRUE,
        ## the configured /data/models shape ##
        'recursive' => FALSE,
        'tier'      => 5
    }
];
$data{'models'}{'scan_paths'} = {
    'models' => {
        'path'      => $models_root,
        'enabled'   => TRUE,
        'recursive' => TRUE,
        'tier'      => 3
    }
};

my $found = discovered_paths();
ok( scalar @$found == 2,
    'discover finds the files although the configured entry is non-recursive'
);
ok( join( "\n", @$found ) eq join( "\n", sort @model_files ),
    'exactly the two placeholder files are found'
);
ok( $data{'models'}{'storage'}{'search_paths'}[1]{'recursive'} == FALSE,
    'canonical store entry left untouched [ scan list is a copy ]'
);

## ---------------------------------------------------------------------- 3 ##
## : scan-path-add writes the canonical store ; no double counting          ##

say "\n :. scan-path-add registers into canonical search paths";

reset_models_state();
$data{'models'}{'storage'}{'search_paths'} = [
    {   'path'      => "$tmp/does-not-exist",
        'enabled'   => TRUE,
        'recursive' => TRUE,
        'tier'      => 3
    }
];

my $result = call_cmd( 'models.cmd.scan-path-add', $models_root );
ok( ref $result eq qw| HASH | && $result->{'mode'} eq qw| true |,
    'scan-path-add succeeds' );
ok( $result->{'data'} =~ m|2 models|, 'scan-path-add reports 2 models' );

ok( ( $data{'models'}{'scan_paths'}{'models'}{'path'} // '' ) eq $models_root,
    'legacy scan_paths record kept [ path-id : models ]'
);

my $canonical = $data{'models'}{'storage'}{'search_paths'} // [];
my @canonical_match
    = grep { ( $ARG->{'path'} // '' ) eq $models_root } @$canonical;
ok( scalar @canonical_match == 1 && $canonical_match[0]{'recursive'} == TRUE,
    'canonical search_paths holds exactly one enabled recursive entry'
);

ok( ref $saved_registry eq qw| HASH | && scalar keys $saved_registry->%* == 2,
    'scan-path-add saved a 2-entry registry'
);

$found = discovered_paths();
ok( scalar @$found == 2,
    'discover does not double-count the path registered in both stores' );

my $again = call_cmd( 'models.cmd.scan-path-add', $models_root );
ok( ref $again eq qw| HASH | && $again->{'mode'} eq qw| false |,
    're-adding the same path is rejected as already registered'
);

## ---------------------------------------------------------------------- 4 ##
## : ids stable between scan-path-add and discover                          ##

say "\n :. composite id stability";

my @add_ids = sort keys $saved_registry->%*;

$data{'models'}{'registry'} = {};
my $populate_result
    = $code{'models.registry.populate_from_discovery'}
    ->( $code{'models.discover.scan_all_paths'}->() );

my @discover_ids = sort keys $data{'models'}{'registry'}->%*;

ok( $populate_result->{'added'} == 2,
    'populate_from_discovery adds both models to an empty registry' );
ok( join( "\n", @add_ids ) eq join( "\n", @discover_ids ),
    'composite checksum ids identical between scan-path-add and discover' );

## ---------------------------------------------------------------------- 5 ##
## : scan-path-add upgrades a configured entry in place                     ##

say "\n :. scan-path-add on an already-configured path";

reset_models_state();
$data{'models'}{'storage'}{'search_paths'} = [
    {   'path'      => $models_root,
        'enabled'   => TRUE,
        'recursive' => FALSE,
        'tier'      => 5
    }
];

$result = call_cmd( 'models.cmd.scan-path-add', $models_root );
ok( ref $result eq qw| HASH | && $result->{'mode'} eq qw| true |,
    'scan-path-add succeeds on a configured path' );

$canonical = $data{'models'}{'storage'}{'search_paths'} // [];
@canonical_match
    = grep { ( $ARG->{'path'} // '' ) eq $models_root } @$canonical;
ok( scalar @canonical_match == 1 && $canonical_match[0]{'recursive'} == TRUE,
    'configured entry upgraded in place, not duplicated'
);

$found = discovered_paths();
ok( scalar @$found == 2, 'discover finds both models after the upgrade' );

## ---------------------------------------------------------------------- 6 ##
## : scan-path-del removes both records                                     ##

say "\n :. scan-path-del";

$result = call_cmd( 'models.cmd.scan-path-del', 'models' );
ok( ref $result eq qw| HASH | && $result->{'mode'} eq qw| true |,
    'scan-path-del succeeds' );
ok( scalar keys $data{'models'}{'scan_paths'}->%* == 0,
    'legacy scan_paths record removed' );

$canonical = $data{'models'}{'storage'}{'search_paths'} // [];
@canonical_match
    = grep { ( $ARG->{'path'} // '' ) eq $models_root } @$canonical;
ok( scalar @canonical_match == 0,
    'canonical search_paths entry removed as well' );

$found = discovered_paths();
ok( scalar @$found == 0, 'discover no longer scans the removed path' );

## ---------------------------------------------------------------------- ##
## summary                                                                ##

my @struct_warnings
    = grep {m{uninitialized|Use of|ref\(\) on|Not an? \w+ ref}i}
    @perl_warnings;
ok( scalar @struct_warnings == 0,
    'no perl warnings from ' . 'the compiled modules' );

say '';
say "passed : $pass_count  failed : $fail_count";
exit( $fail_count ? 1 : 0 );

#,,,,,,..,...,,.,,...,,,.,...,.,.,..,,,,.,...,..,,...,...,.,,,,.,,,,,,,.,,.,,,
#DRFJPS6OA7XL2H7XFIHH6VZ7WN4CEZASAED5DTPGUMFXJ2B2EGLOJJ5JFVVWWX74CDQONYLBX4PIG
#\\\|EXA6EWBVS6Q5DJ5EUZTYFGQJZNXI7BXBEYVEOQJTBNIJUWQZDD5 \ / AMOS7 \ YOURUM ::
#\[7]JH3RH63FL2HH46E77SBUUQ6X4PSUOIJYM3P7Y3ZMNLPDOLVOKKAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
