#!/usr/bin/perl
use v5.24;
use strict;
use English;
use warnings;

###                                                                  ###
## coding model-path resolve consolidation : standalone acceptance harness ##
###                                                                  ###

## exercises the real translated module sources against an in-process %data ##
## / %code stub environment -- no live coding zenka required.  covers the   ##
## exact regression this change was built to prevent: the deferred spawn    ##
## timer's dependency.ok check firing the resolve hook [                    ##
## coding.resolve.object.model_path ] must NOT send a genuinely redundant   ##
## second cube.models.get_path_by_amos request while the original init-time ##
## request is still outstanding -- confirmed live 2026-08-26 this was a     ##
## real risk of the consolidation, not a hypothetical                       ##

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

my @send_calls;    ## records every cube.models.get_path_by_amos attempt ##
my $NEXT_ID = 1;

%code = (
    'base.log'    => sub { return TRUE },
    'base.logs'   => sub { return TRUE },
    'base.gen_id' => sub {
        my $href = shift;
        my $id;
        do { $id = $NEXT_ID++ } while exists $href->{$id};
        return $id;
    },
    'base.ntime' => sub { return 1000 },    ## constant : no time passes ##
    'base.ntime.delta_seconds' => sub { return 0 }
    ,    ## debounce timing tested elsewhere ##
    'base.str.eval_error'           => sub { return "$EVAL_ERROR" },
    'protocol-7.command.send.local' => sub {
        my $args = shift;
        push @send_calls, $args;
        return 1;    ## 1 client reached, matches the real success case ##
    },
);

$data{'inference'}{'model'}{'amos_id'} = 'TESTID7:ABCDEFG';

my $fail_count = 0;

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

compile_module($_) foreach qw|
    base.dependency.setup
    base.dependency.add_object
    base.dependency.add
    base.dependency.ok
    base.dependency.install_callbacks
    coding.callback.object.model_path
    coding.resolve.object.model_path
    coding.resolve_model_path
    |;

## real runtime alias : install_callbacks calls the short form internally ##
$code{'dependency.setup'} = $code{'base.dependency.setup'};

## resolve.object.model_path calls <[coding.resolve_model_path]> as a bare ##
## macro [ no ->() ] -- in real P7 that's sugar for ->(); our compiled sub ##
## already handles being called with no args the same way                  ##
$code{'coding.resolve_model_path'} = $code{'coding.resolve_model_path'};

sub ok {
    my ( $cond, $label ) = @ARG;
    if ($cond) { say "  ok   : $label"; return }
    $fail_count++;
    say "  FAIL : $label";
    return;
}

say ': setup';

## dependency.ok(X) only checks X's OWN chain members' callbacks -- it    ##
## never invokes X's own type callback. model_path_gpu needs a small root ##
## object that DEPENDS ON it, mirroring coding.init_dependencies'         ##
## spawn_ready_gpu / model_path_gpu pair exactly                          ##
my $obj_id = $code{'base.dependency.add_object'}
    ->( { 'type' => 'model_path', 'backend' => 'gpu' } );
$code{'base.dependency.setup'}->(
    'model_path',
    {   'callback' => $code{'coding.callback.object.model_path'},
        'resolve'  => $code{'coding.resolve.object.model_path'},
    }
);
my $root_id = $code{'base.dependency.add_object'}
    ->( { 'type' => 'spawn_precondition', 'backend' => 'gpu' } );
$code{'base.dependency.add'}->( $root_id, $obj_id );

say ': coding.callback.object.model_path';

ok( ( not $code{'coding.callback.object.model_path'}->($obj_id) ),
    'callback FALSE when <inference.model.path> is unset'
);

say ': the actual regression -- no double-send';

## step 1 : the original, unconditional init-time call [ zenka.v7's own   ##
## [coding.resolve_model_path] line ] -- this always fires first, exactly ##
## once, well before any deferred timer                                   ##
my $r1 = $code{'coding.resolve_model_path'}->();
ok( $r1,                      'initial resolve_model_path call succeeds' );
ok( scalar(@send_calls) == 1, 'exactly one send after the initial call' );
ok( ( $data{'coding'}{'model_path_request_in_flight'}{'gpu'} ? 1 : 0 ) == 1,
    'in-flight flag set after a successful send' );

## step 2 : the deferred spawn timer fires [ 0.5s later, per coding.       ##
## init_code ], finds the path still unresolved [ reply hasn't arrived yet ##
## -- this is the COMMON case, not a rare one ], and checks dependency.ok  ##
## -- which fires the resolve hook since the callback still returns FALSE. ##
## THIS must not send a second request.                                    ##
my $ok_result = $code{'base.dependency.ok'}->($root_id);
ok( ( not $ok_result ), 'dependency.ok still reports FALSE [ unresolved ]' );
ok( scalar(@send_calls) == 1,
    'resolve hook fired but did NOT send a second request [ '
        . scalar(@send_calls)
        . ' total sends -- this is the actual regression guard ]'
);

## step 3 : a second, independent dependency.ok check [ eg model_path_reply
## itself re-checking, or another caller ] while still unresolved : same
## guard, still only one send total
$code{'base.dependency.ok'}->($root_id);
ok( scalar(@send_calls) == 1,
    'still only one send after a third unresolved check' );

say ': reply arrives -- guard clears, path resolves';

## simulate what coding.handler.model_path_reply does on a successful   ##
## reply, without needing YAML::XS / a real reply payload for this test ##
$data{'coding'}{'model_path_request_in_flight'}{'gpu'} = FALSE;
$data{'inference'}{'model'}{'path'} = '/mnt/models/test-model.gguf';

ok( $code{'coding.callback.object.model_path'}->($obj_id),
    'callback TRUE once <inference.model.path> is set'
);
ok( $code{'base.dependency.ok'}->($root_id),
    'dependency.ok now TRUE [ resolve hook no longer needed ]' );
ok( scalar(@send_calls) == 1,
    'no further sends once the dependency is actually satisfied' );

say ': after clearing, a genuinely NEW resolution can send again';

## sanity : the guard isn't stuck forever -- a fresh cycle [ eg a model ##
## switch clearing inference.model.path again ] can still resolve       ##
delete $data{'inference'}{'model'}{'path'};
my $r2 = $code{'coding.resolve_model_path'}->();
ok( $r2,                      'a fresh resolve call succeeds' );
ok( scalar(@send_calls) == 2, 'exactly one NEW send [ total 2 ]' );

say '';
if ($fail_count) {
    say "FAILED : $fail_count check[s]";
    exit 1;
}
say 'all checks passed';
exit 0;

#,,..,,.,,..,,,,,,.,.,,.,,.,.,,,.,,,,,.,.,..,,..,,...,...,.,,,,.,,,..,..,,,,,,
#NPIXAXBCMSLQN6X3RFSSCZ3MA42HY4HSVH34GT7ATKYET25P2XEXEF4OVQII7C362NZOMPUKSL2WS
#\\\|AQKKTFWUUOV4OU7GU5HPEEORRV4NTWB4GGBIBW3A6N36BKUQG4L \ / AMOS7 \ YOURUM ::
#\[7]4VQOHSQ7ZYTTEFVXMK2CQDU25OEGSUVHI24MLQKY2N7KQFDH4WAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
