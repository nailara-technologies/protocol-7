#!/usr/bin/env perl
use v5.32;
use strict;
use warnings;
use English;

use Test::More;
use File::Temp qw| tempdir |;
use File::Path qw| make_path |;
use FindBin    qw| $RealBin |;
use Cwd        qw| abs_path |;

use lib "$RealBin/../../data/lib-path/pm";
use AMOS7::Desktop::Theme;

use constant { TRUE => 5, FALSE => 0, UNKNOWN => 2 };

my $root = abs_path("$RealBin/../..");
my $tmp  = tempdir( CLEANUP => 1 );

our %data;
our %code;
our $call;

sub translate_code {
    my $code = shift;
    $code =~ s{<\[([A-Za-z][-\w.]*)\]>(?=->)}{chr(36).qq|code{'$1'}|}eg;
    $code =~ s{<\[([A-Za-z][-\w.]*)\]>}{chr(36).qq|code{'$1'}->()|}eg;
    $code =~ s{<([a-z][-\w.]*)>}{
        my @keys = split m|[.]|, ${^CAPTURE}[0];
        chr(36).qq|data{'| . join( "'}{'", @keys ) . qq|'}|
    }ge;
    return $code;
}

sub load_src {
    my $name = shift;
    my $path = "$root/src/$name";
    open my $fh, '<', $path or die "cannot read $path : $OS_ERROR";
    local $INPUT_RECORD_SEPARATOR = undef;
    my $src = <$fh>;
    close $fh;
    my @seg = split m{('(?:[^'\\]|\\.)*'|"(?:[^"\\]|\\.)*"|\#[^\n]*)}x,
        $src, -1;
    for ( my $i = 0; $i < @seg; $i += 2 ) {
        $seg[$i] = translate_code( $seg[$i] );
    }
    my $sub = eval 'sub { ' . join( '', @seg ) . ' }';
    die "compile error in $name : $EVAL_ERROR" if $EVAL_ERROR;
    $code{$name} = $sub;
}

$code{'file.make_path'} = sub { make_path(shift); return TRUE };
$code{'file.slurp'}     = sub {
    my $path = shift;
    open my $fh, '<', $path or return undef;
    local $INPUT_RECORD_SEPARATOR = undef;
    my $text = <$fh>;
    close $fh;
    return \$text;
};
$code{'file.write'} = sub {
    my ( $path, $text ) = @ARG;
    open my $fh, '>', $path or return FALSE;
    print {$fh} $text;
    close $fh;
    return TRUE;
};
$code{'base.perlmod.autoload'} = sub { return TRUE };
my $serial = 0;
$code{'base.prng.chars-anum'} = sub { return sprintf 'stub%04d', ++$serial };

my @spawn;
$code{'povray.spawn_render'} = sub {
    push @spawn, [@ARG];
    $data{'povray'}{'render'}{ $_[0] } = { 'out_png' => $_[2] };
    return undef;
};
my @reply;
$code{'base.callback.cmd_reply'} = sub { push @reply, [@ARG] };

$data{'system'}{'root_path'}           = $root;
$data{'system'}{'zenka'}{'name'}       = 'povray-test';
$data{'system'}{'path'}{'zenka-dirs'}  = {};
$data{'povray'}{'cfg'}{'output_dir'}   = "$tmp/povray";
$data{'povray'}{'cfg'}{'template_dir'} = "$root/data/povray-templates";
$data{'povray'}{'cfg'}{'icon_symbols'}
    = 'terminal browser files settings power media';
$data{'povray'}{'cfg'}{'icon_sizes'} = '13 24';
$data{'povray'}{'render'} = {};

load_src('povray.template.resolve');
load_src('povray.icon-set.jobs');
load_src('povray.icon-set.next');
load_src('povray.cmd.render-icon-set');

$call = { 'args' => '', 'reply_id' => 'reply-stub' };
my $result = $code{'povray.cmd.render-icon-set'}->();
is_deeply $result, { 'mode' => 'deferred' }, 'command defers the set reply';
is scalar @spawn,          1,  'only the first povray job is spawned';
is $spawn[0][4]{'width'},  13, 'stub receives task-bar width';
is $spawn[0][4]{'height'}, 13, 'stub receives task-bar height';
ok $spawn[0][4]{'alpha'},    'stub receives alpha output option';
ok $spawn[0][4]{'icon_set'}, 'stub marks the job as part of the set';

my $set   = $data{'povray'}{'icon_set'};
my @built = ( $set->{'current'}, @{ $set->{'jobs'} } );
is scalar @built, 24, 'six symbols at four sizes produce 24 jobs';
is_deeply [ map { $ARG->{'size'} } @built[ 0 .. 3 ] ], [ 13, 24, 26, 48 ],
    'base sizes and unique 2x sizes are sorted';
is_deeply [ map { $ARG->{'symbol'} } @built[ 0, 4, 8, 12, 16, 20 ] ],
    [qw| terminal browser files settings power media |],
    'all configured symbols are present';

my @expected;
foreach my $symbol (qw| terminal browser files settings power media |) {
    push @expected,
        map {"$tmp/povray/icon-set/$symbol-$ARG.png"} ( 13, 24, 26, 48 );
}
is_deeply [ map { $ARG->{'out_png'} } @built ], \@expected,
    'stable output names all share the zenka data directory';

foreach my $job (@built) {
    my ( $ok, $scene )
        = $code{'povray.template.resolve'}
        ->( 'desktop-icon', $job->{'context'} );
    ok $ok, "template resolves $job->{'symbol'} at $job->{'size'}";
    unlike $scene, qr|\{\{|, 'no unresolved template placeholders';
    last if not $ok;
}
my $first_scene = ${ $code{'file.slurp'}->( $built[0]{'pov_path'} ) };
like $first_scene,
    qr|color rgbt < 0[.]000000, 0[.]333333, 0[.]800000, 0[.]5500 >|,
    'foreground and translucency tokens reach the material';
like $first_scene, qr|color rgb < 0[.]266667, 0[.]152941, 0[.]674510 >|,
    'accent token reaches the shared fill light';
like $first_scene,
    qr|#include "\Q$root\E/data/povray-templates/symbols/terminal[.]pov"|,
    'the selected symbol input is included';

$call = { 'args' => '', 'reply_id' => 'other-reply' };
my $busy = $code{'povray.cmd.render-icon-set'}->();
is $busy->{'mode'}, 'false', 'a concurrent set render is refused';

$set->{'jobs'}    = [];
$set->{'results'} = \@expected;
ok $code{'povray.icon-set.next'}->(), 'empty queue completes the set';
is $reply[0][0], 'reply-stub',   'completion uses the original reply id';
is $reply[0][1]{'mode'}, 'true', 'stubbed set completes successfully';
is $reply[0][1]{'data'}, "$tmp/povray/icon-set [ 24 icons ]",
    'completion returns the output directory and count';
ok !defined $data{'povray'}{'icon_set'}, 'set state is cleared';

done_testing;

#,,,.,.,.,.,,,.,,,,.,,,,.,,,.,,,,,,..,...,,,,,..,,...,...,...,,,,,,,,,,..,,,.,
#TYA3XVOWCIKGON3JD4MDRE4JS7YFZ3S7WWYFX7ZAJXFOXABRJETTZK3BMQOET2YBFRHBSOWHYPZS4
#\\\|XMZUQTZT75LTQPM3LOWBCULEQV3DQSEZUWRDTTCIJBNGNLDHLGR \ / AMOS7 \ YOURUM ::
#\[7]I6ZPZL4YMFZ6UTCDF5KPUR4IY2GOXAYANUEMJG5CZAV3WA3GLGCQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
