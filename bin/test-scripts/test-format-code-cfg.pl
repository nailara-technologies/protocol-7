#!/usr/bin/env perl
use v5.24;
use strict;
use English;
use warnings;
use utf8;

##      test bin/format-code cfg mode [ files under cfg/ ]                 ##
##                                                                         ##
##      fixtures are written inline into a temp dir , its 'cfg/' path      ##
##      component selects the cfg mode :                                   ##
##                                                                         ##
##      1. a ragged prose block gets aligned closers                       ##
##      2. an over-long block is rewrapped within LINE_MAX                 ##
##      3. a column table keeps its text , its closers get aligned         ##
##      4. key = value , continuation , inline trailing comment ,          ##
##      single '#' lines and the signature footer stay unchanged           ##
##      5. reruns converge , -r and -n give the plain run result           ##
##      6. -c reports without writing , binary files are skipped , a       ##
##      missing final newline stays missing                                ##
##      7. src mode : column block closers aligned , a fixed point         ##
##                                                                         ##
##      all fixture texts below are manufactured test data                 ##

use File::Spec;
use Cwd        qw| abs_path |;
use FindBin    qw| $RealBin |;
use File::Temp qw| tempdir |;
use File::Path qw| make_path |;
use Encode     qw| decode_utf8 encode_utf8 |;

my $up_dir    = File::Spec->updir;
my $root_path = abs_path(
    File::Spec->rel2abs( File::Spec->catdir( $RealBin, $up_dir, $up_dir ) ) );
my $tool_path
    = abs_path( File::Spec->catfile( $root_path, qw| bin format-code | ) );

my $tests_run    = 0;
my $tests_passed = 0;
my @failures;

sub check {
    my ( $label, $condition ) = @ARG;
    $tests_run++;
    if ($condition) {
        $tests_passed++;
    } else {
        push( @failures, $label );
        say sprintf( '[ FAIL ] %s', $label );
    }
    return $condition;
}

sub run_tool {
    my @args   = @ARG;
    my $output = qx| perl $tool_path @args 2>&1 |;
    $output =~ s{\e\[[\d;]*m}{}g;    ## no colors ##
    return ( $output, $CHILD_ERROR >> 8 );
}

sub slurp_raw {
    my $path = shift;
    open( my $fh, qw| <:raw |, $path ) or return undef;
    local $/;
    my $content = <$fh>;
    close($fh);
    return $content;
}

sub spew_raw {
    my ( $path, $content ) = @ARG;
    open( my $fh, qw| >:raw |, $path ) or die "$path : $OS_ERROR\n";
    print {$fh} $content;
    close($fh);
}

## LINE_MAX as the tool itself defines it ##
my ($line_max) = slurp_raw($tool_path) =~ m{use constant LINE_MAX => (\d+);};
die ":\n:: LINE_MAX not found in $tool_path\n:\n" if not defined $line_max;

## the words of a '##' block, markers stripped ##
sub block_words {
    my @words;
    for my $line (@ARG) {
        ( my $text = $line ) =~ s{^\s*\#\#\ ?}{};
        $text =~ s|\s*#{2,}\s*$||;
        push @words, split ' ', $text;
    }
    return join ' ', @words;
}

## column of each line's closing '##' [ undef without one ] ##
sub closer_columns {
    return
        map { m|^(.*?\S)([ ]*)#{2,}[ ]*\z| ? length($1) + length($2) : undef }
        @ARG;
}

sub lines_of { return split m{\n}, decode_utf8( shift // '' ) }

##[ FIXTURES ]################################################################

my $temp_root = tempdir(
    qw| format-code-cfg-XXXXXX |,
    TMPDIR  => 1,
    CLEANUP => 1
);
my $cfg_dir = File::Spec->catdir( $temp_root, qw| cfg zenki fixture | );
make_path($cfg_dir);

## [ manufactured test data ] a signature-shaped footer , not a real one ##
my $footer = join "\n",
    '#' . ( ',.' x 38 ) . ',',
    '#' . ( 'Q' x 77 ),
    '#\\\\\\|' . ( 'R' x 51 ) . ' \\ / AMOS7 \\ YOURUM ::',
    '#\\[7]' . ( 'S' x 52 ) . ' 7  DATA SIGNATURE ::',
    '#' . ( ':' x 77 ), '';

## [ manufactured test data ] one start file with every line kind ##
my $start_file = <<'FIXTURE' . $footer;

.:[ fixture zenka start-up ]:.

[load_config_file:'shared-params']

## the fixture zenka reads its own queue every few seconds and    ##
## reports the depth to cube when asked ##
## nothing else here depends on that value     ##
fixture.cfg.poll_interval = 7

## an over-long comment block that runs well past the line budget of this tool so it has to be rewrapped ##
## into lines that fit , keeping every word in the same order ##
fixture.cfg.limit = 13

## mode        effect                       ##
## off         nothing at all ##
## scan        record only , change nothing      ##
fixture.cfg.mode = off

fixture.cfg.inline = yes    ## an inline trailing comment that stays exactly where it is although it is long ##
#  a single hash comment line that is far longer than the line budget and must never be touched by this
# fixture.cfg.disabled = 1
modules.load = auth.client net protocol io.unix \
               ui fixture   ## trailing note ##
access.cmd.usr.cube = commands heart \
    ## a continuation line shaped like a comment block that is far over the line budget too ##
###  BANNER LINE  ###
##==========================================================================##

FIXTURE

## [ manufactured test data ] loose lines : one note per line ##
my $loose_file = <<'FIXTURE';
dependencies = cube
## first loose note line
## second loose note line
max_concurrency = 1
FIXTURE

## [ manufactured test data ] a block without final newline ##
my $no_newline_file = <<'FIXTURE';
## a block without a final newline at the end of the file    ##
## gets its ragged closers aligned all the same ##
FIXTURE
chomp $no_newline_file;

## [ manufactured test data ] utf8 : widths count characters ##
my $utf8_file = <<'FIXTURE';
## a dash — and an arrow → inside a long comment line that runs past the budget and wraps ##
zenki.enabled = cube p7-log
FIXTURE

## [ manufactured test data ] commented-out entries : closers only ##
my $entries_file = <<'FIXTURE';
## fixture.cfg.a = 1 ##
## fixture.cfg.bb = 22   ##
GET /x  handler.x
FIXTURE

my %fixture = (
    'zenka.v7'          => $start_file,
    'start.cfg'         => $loose_file,
    'access.users'      => $no_newline_file,
    'start-set-up.base' => $utf8_file,
    'routes'            => $entries_file,
);

for my $name ( sort keys %fixture ) {
    spew_raw(
        File::Spec->catfile( $cfg_dir, $name ),
        encode_utf8( $fixture{$name} )
    );
}

## [ manufactured test data ] binary + invalid utf8 : skipped untouched ##
my $binary_path  = File::Spec->catfile( $cfg_dir, 'image.png' );
my $binary_bytes = "\x89PNG\0\0## a ragged     ##\n## block ##\n";
spew_raw( $binary_path, $binary_bytes );
my $latin1_path  = File::Spec->catfile( $cfg_dir, 'latin1.cfg' );
my $latin1_bytes = "## caf\xE9 is not utf8 here     ##\n## second line ##\n";
spew_raw( $latin1_path, $latin1_bytes );

sub cfg_path { return File::Spec->catfile( $cfg_dir, shift ) }

##[ -c : report only , no write ]#############################################

my ( $check_out, $check_rc ) = run_tool( qw| -c |, cfg_path('zenka.v7') );
check(
    '-c names the start file as would reflow',
    $check_out =~ m{would reflow \] \.: \S*zenka\.v7 ::}
);
check(
    '-c runs no perl syntax check on a cfg file',
    $check_out !~ m{syntax valid|syntax error}
);
check(
    '-c leaves the file unchanged',
    slurp_raw( cfg_path('zenka.v7') ) eq encode_utf8( $fixture{'zenka.v7'} )
);
( $check_out, undef ) = run_tool( qw| -c |, cfg_path('start.cfg') );
check(
    '-c reports ok for a file without a block to change',
    $check_out =~ m{cfg ok \] \.: \S*start\.cfg ::}
);

##[ rewrite : plain run ]#####################################################

my @names = sort keys %fixture;
my ( $run_out, $run_rc )
    = run_tool( ( map { cfg_path($ARG) } @names ),
    $binary_path, $latin1_path );
check( 'rewrite run exits clean', $run_rc == 0 ) or print $run_out;
check( 'rewrite run prints no skipping-config notice',
    $run_out !~ m{skipping config} );

my %pass1 = map { $ARG => slurp_raw( cfg_path($ARG) ) } @names;
my @out   = lines_of( $pass1{'zenka.v7'} );
my @orig  = lines_of( encode_utf8( $fixture{'zenka.v7'} ) );

## 1. ragged prose block ##
my ($prose_at) = grep { $out[$ARG] =~ m{reads its own queue} } 0 .. $#out;
my @prose = @out[ $prose_at .. $prose_at + 1 ];
check(
    'ragged prose block is rewrapped to two lines',
    $out[ $prose_at + 2 ] eq 'fixture.cfg.poll_interval = 7'
);
my @prose_cols = closer_columns(@prose);
check( 'ragged prose block closers are aligned',
    defined $prose_cols[0] && $prose_cols[0] == $prose_cols[1] );
check(
    'ragged prose block keeps every word',
    block_words(@prose) eq
        block_words( grep {m{queue|reports the depth|nothing else}} @orig )
);

## 2. over-long block ##
my ($long_at) = grep { $out[$ARG] =~ m{over-long comment block} } 0 .. $#out;
my ($limit_at)
    = grep { $out[$ARG] eq 'fixture.cfg.limit = 13' } 0 .. $#out;
my @long = @out[ $long_at .. $limit_at - 1 ];
check(
    'over-long block wraps within LINE_MAX',
    not grep { length($ARG) > $line_max } @long
);
check(
    'over-long block keeps every word',
    block_words(@long) eq block_words(
        grep {m{over-long comment block|into lines that fit}} @orig
    )
);
my %long_cols = map { $ARG => 1 } closer_columns(@long);
check( 'over-long block closers are aligned', keys %long_cols == 1 );

## 3. column-aligned table ##
my ($table_at)      = grep { $out[$ARG] =~ m{^\#\# mode\s} } 0 .. $#out;
my @table           = @out[ $table_at .. $table_at + 2 ];
my ($orig_table_at) = grep { $orig[$ARG] =~ m{^\#\# mode\s} } 0 .. $#orig;
my @orig_table      = @orig[ $orig_table_at .. $orig_table_at + 2 ];
my $strip_closer    = sub { ( my $l = shift ) =~ s{\s*\#\#\s*$}{}; $l };
check(
    'column table keeps its text and inner spacing',
    join( "\n", map { $strip_closer->($ARG) } @table ) eq
        join( "\n", map { $strip_closer->($ARG) } @orig_table )
);
my %table_cols = map { $ARG => 1 } closer_columns(@table);
check( 'column table closers are aligned', keys %table_cols == 1 );

## 4. lines that are never touched ##
for my $kept (
      'fixture.cfg.inline = yes    ## an inline trailing comment '
    . 'that stays exactly where it is although it is long ##',
    '#  a single hash comment line that is far longer '
    . 'than the line budget and must never be touched by this',
    '# fixture.cfg.disabled = 1',
    'modules.load = auth.client net protocol io.unix \\',
    '               ui fixture   ## trailing note ##',
    '    ## a continuation line shaped like a comment '
    . 'block that is far over the line budget too ##',
    '###  BANNER LINE  ###',
    '##' . ( '=' x 74 ) . '##',
    '.:[ fixture zenka start-up ]:.',
    "[load_config_file:'shared-params']",
) {
    my $label = substr( $kept, 0, 36 );
    check( "unchanged line : $label", scalar grep { $ARG eq $kept } @out );
}
check( 'signature footer is byte-identical',
    substr( $pass1{'zenka.v7'}, -length($footer) ) eq $footer );

## everything outside the three blocks is byte-identical ##
my ($orig_prose_at)
    = grep { $orig[$ARG] =~ m{reads its own queue} } 0 .. $#orig;
my ($orig_long_at)
    = grep { $orig[$ARG] =~ m{over-long comment block} } 0 .. $#orig;
my %orig_block = map { $ARG => 1 } $orig_prose_at .. $orig_prose_at + 2,
    $orig_long_at .. $orig_long_at + 1, $orig_table_at .. $orig_table_at + 2;
my %out_block = map { $ARG => 1 } $prose_at .. $prose_at + 1,
    $long_at .. $limit_at - 1, $table_at .. $table_at + 2;
check(
    'all other lines of the start file are byte-identical',
    join( "\n", map { $out[$ARG] } grep { not $out_block{$ARG} } 0 .. $#out )
        eq join( "\n",
        map { $orig[$ARG] } grep { not $orig_block{$ARG} } 0 .. $#orig )
);

check( 'loose note lines stay as written',
    $pass1{'start.cfg'} eq encode_utf8( $fixture{'start.cfg'} ) );

my @no_nl = lines_of( $pass1{'access.users'} );
check(
    'missing final newline stays missing',
    $pass1{'access.users'} !~ m{\n\z}
);
my @no_nl_cols = closer_columns(@no_nl);
check(
    'block without final newline gets aligned closers',
    @no_nl == 2 && defined $no_nl_cols[0] && $no_nl_cols[0] == $no_nl_cols[1]
);

my @utf8_out = lines_of( $pass1{'start-set-up.base'} );
check( 'utf8 block wraps by characters within LINE_MAX',
    @utf8_out == 3 && not grep { length($ARG) > $line_max } @utf8_out );
check(
    'utf8 block keeps its multi-byte characters',
    $pass1{'start-set-up.base'} =~ m|\Q@{[ encode_utf8('—') ]}\E|
        && $pass1{'start-set-up.base'} =~ m|\Q@{[ encode_utf8('→') ]}\E|
);

my @routes      = lines_of( $pass1{'routes'} );
my @routes_cols = closer_columns( @routes[ 0, 1 ] );
check(
    'commented-out entries keep their text , closers aligned',
    $routes[0] =~ m{^\#\# fixture\.cfg\.a = 1\s+\#\#$}
        && $routes[1] eq '## fixture.cfg.bb = 22   ##'
        && $routes_cols[0] == $routes_cols[1]
);

check( 'binary file is untouched', slurp_raw($binary_path) eq $binary_bytes );
check(
    'invalid utf8 file is untouched',
    slurp_raw($latin1_path) eq $latin1_bytes
);

##[ 5. convergence : a second run , and -r \ -n give the same result ]########

run_tool( map { cfg_path($ARG) } @names );
check(
    "second run changes nothing : $ARG",
    slurp_raw( cfg_path($ARG) ) eq $pass1{$ARG}
) for @names;

my ( $second_check, undef ) = run_tool( qw| -c |, cfg_path('zenka.v7') );
check( '-c after the rewrite reports ok',
    $second_check =~ m{cfg ok} && $second_check !~ m{would reflow} );

for my $flag (qw| -r -n |) {
    for my $name (@names) {
        spew_raw( cfg_path($name), encode_utf8( $fixture{$name} ) );
    }
    run_tool( $flag, map { cfg_path($ARG) } @names );
    check(
        "'$flag' run gives the plain run result : $ARG",
        slurp_raw( cfg_path($ARG) ) eq $pass1{$ARG}
    ) for @names;
}

##[ 7. src mode : align-only column block , fixed point ]#####################

my $src_dir = File::Spec->catdir( $temp_root, qw| src | );
make_path($src_dir);
my $src_path = File::Spec->catfile( $src_dir, 'fixture.column_block' );

## [ manufactured test data ] a p7 module with a ragged column block ##
spew_raw( $src_path, <<'FIXTURE' );
## [:< ##

# name  = fixture.column_block
# descr = test fixture , a column block with ragged closers

## prefix    type ##
## '00'      routing ##
## '0111'    color document ##
my $prefix = shift;
return $prefix;
FIXTURE

run_tool( qw| -n |, $src_path );
my $src_pass1 = slurp_raw($src_path);
my @src_out   = grep {m{^\#\# (?:prefix|'0)}} lines_of($src_pass1);
my %src_cols  = map  { $ARG => 1 } closer_columns(@src_out);
check(
    'src column block gets aligned closers',
    @src_out == 3 && keys %src_cols == 1
);
check( 'src column block keeps its text',
    $src_pass1 =~ m{^\#\# '0111'    color document\s+\#\#$}m );
run_tool( qw| -n |, $src_path );
check( 'src second run changes nothing', slurp_raw($src_path) eq $src_pass1 );

##[ SUMMARY ]#################################################################

say '';
if ( @failures == 0 ) {
    say sprintf '[ PASS ] %d of %d checks', $tests_passed, $tests_run;
    exit 0;
} else {
    say sprintf '[ FAIL ] %d of %d checks failed',
        scalar @failures, $tests_run;
    exit 1;
}

#,,,,,.,,,,..,,..,,..,.,.,...,.,.,,,,,,..,,.,,..,,...,...,...,..,,.,.,,,,,..,,
#OEPW2CJ3HEVVB5NPEOA6ROX5ITCOBBXGL5NNTDH72F5AN6WZNQZDID5WNHFTZRW54KB4MBSO3Q6HY
#\\\|JIJICBJJEAPXXVGD6HB6V2MFZNYKUG34HDMNZTOLHZ6HHQZE5ET \ / AMOS7 \ YOURUM ::
#\[7]E3S4YXDDOEURL2MUZIUB76CRANZKZJYSDVUJ7AHPQDC53IB5LYBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
