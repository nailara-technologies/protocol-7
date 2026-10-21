#!/usr/bin/perl
use v5.32.0;
use strict;
use warnings;
use English;

## Test AMOS7::TERM::Editor pure functions  Tests: paste normalisation
## [ crlf, lone cr, mixed ], de-interlace transform [ doubled breaks, original
## blank line, stop at even run, stop at two text lines, block above cursor
## untouched, whitespace-only counts as empty ], bracketed-paste parser on a
## byte string fed through a fake reader
## [ paste event, crlf collapse, escape sequences, lone cr ]

##[ LOCAL PM LIB PATH ]#######################################################

BEGIN {
    use File::Spec;
    use Cwd     qw| abs_path |;
    use FindBin qw| $RealBin |;
    my $up_dir       = File::Spec->updir;
    my $data_pm_path = qw| data/lib-path/pm |;
    my $root_path    = abs_path(
        File::Spec->rel2abs(
            File::Spec->catdir( $RealBin, $up_dir, $up_dir )
        )
    );
    my $local_lib_path
        = abs_path( File::Spec->catdir( $root_path, $data_pm_path ) );
    $local_lib_path //= $data_pm_path;
    die "\n:\n:: not found : $local_lib_path\n:\n" if !-d $local_lib_path;
    unshift( @INC, $local_lib_path )               if -d $local_lib_path;
}

use AMOS7::TERM::Editor qw|
    editor_normalize_paste
    editor_deinterlace
    read_editor_event
    |;

my $tests_run    = 0;
my $tests_passed = 0;

sub check {
    my ( $label, $condition ) = @ARG;
    $tests_run++;
    if ($condition) {
        $tests_passed++;
        say sprintf( '[ ok ] %s', $label );
    } else {
        say sprintf( '[ FAIL ] %s', $label );
    }
    return $condition;
}

sub lines_str {
    return join '|', @{ $_[0] };
}

## fake reader over a byte string : read( $timeout ) -> byte or undef ##
sub fake_reader {
    my $bytes   = shift;
    my $pos     = 0;
    my $pending = '';
    return {
        read => sub {
            if ( length $pending ) {
                return substr( $pending, 0, 1, '' );
            }
            return undef if $pos >= length($bytes);
            my $b = substr( $bytes, $pos, 1 );
            $pos++;
            return $b;
        },
        ungetc => sub {
            $pending = $_[0] . $pending;
        },
    };
}

## read events from a byte string until the reader is exhausted ##
sub events_from_bytes {
    my $bytes   = shift;
    my $reader  = fake_reader($bytes);
    my $aborted = 0;
    my @events;
    while (1) {
        my $event = read_editor_event( $reader, \$aborted );
        last if !defined $event;
        push @events, $event;
        last if $tests_run > 1000;    ## runaway guard ##
    }
    return @events;
}

say '';
say '=== testing AMOS7::TERM::Editor ===';
say '';

##[ paste normalisation ]#####################################################

check( 'paste normalise : crlf -> lf',
    editor_normalize_paste("a\r\nb\r\n") eq "a\nb\n" );
check( 'paste normalise : lone cr -> lf',
    editor_normalize_paste("a\rb\rc") eq "a\nb\nc" );
check( 'paste normalise : mixed crlf + cr + lf',
    editor_normalize_paste("a\r\nb\rc\nd\r\ne") eq "a\nb\nc\nd\ne" );
check( 'paste normalise : empty string', editor_normalize_paste('') eq '' );

##[ de-interlace ]############################################################

my ( $out_ref, $changed );

( $out_ref, $changed ) = editor_deinterlace( [ 'a', '', 'b', '', 'c' ], 0 );
check(
    'de-interlace : a\\n\\nb\\n\\nc -> a\\nb\\nc',
    $changed == 1 && lines_str($out_ref) eq 'a|b|c'
);

( $out_ref, $changed )
    = editor_deinterlace( [ 'a', '', '', '', 'b' ], 0 );
check( 'de-interlace : original blank line a\\n\\n\\n\\nb -> a\\n\\nb',
    $changed == 1 && lines_str($out_ref) eq 'a||b' );

## even run [ e = 2 ] right after the first text line : nothing changes ##
( $out_ref, $changed )
    = editor_deinterlace( [ 'a', '', '', 'b', '', 'c' ], 0 );
check(
    'de-interlace : stop at first even run',
    $changed == 0 && lines_str($out_ref) eq 'a|||b||c'
);

## even run [ e = 0 ] : two text lines in a row stop the walk ##
( $out_ref, $changed ) = editor_deinterlace( [ 'a', 'b', '', 'c' ], 0 );
check(
    'de-interlace : stop at two text lines in a row',
    $changed == 0 && lines_str($out_ref) eq 'a|b||c'
);

## text above the cursor is untouched ##
( $out_ref, $changed )
    = editor_deinterlace( [ 'a', '', 'b', '', 'c', '', 'd' ], 2 );
check(
    'de-interlace : block above the cursor untouched',
    $changed == 1 && lines_str($out_ref) eq 'a||b|c|d'
);

## whitespace-only lines count as empty ##
( $out_ref, $changed )
    = editor_deinterlace( [ 'a', '  ', '', ' ', 'b', '', 'c' ], 0 );
check(
    'de-interlace : whitespace-only lines count as empty',
    $changed == 1 && lines_str($out_ref) eq 'a||b|c'
);

## cursor below an empty prefix : skip to first text line ##
( $out_ref, $changed ) = editor_deinterlace( [ '', 'a', '', 'b' ], 0 );
check(
    'de-interlace : skip empty prefix to first text line',
    $changed == 1 && lines_str($out_ref) eq '|a|b'
);

## untouched buffer reports not changed ##
( $out_ref, $changed ) = editor_deinterlace( [ 'a', 'b', 'c' ], 0 );
check(
    'de-interlace : clean buffer unchanged',
    $changed == 0 && lines_str($out_ref) eq 'a|b|c'
);

## input array is not modified ##
my @input = ( 'a', '', 'b' );
editor_deinterlace( \@input, 0 );
check( 'de-interlace : input array not modified',
    lines_str( \@input ) eq 'a||b' );

##[ bracketed paste parser ]##################################################

my @events = events_from_bytes("\e[200~line1\r\nline2\e[201~");
check(
    'paste parser : single paste event',
    scalar @events == 1
        && ref $events[0] eq 'HASH'
        && $events[0]{'paste'} eq "line1\r\nline2"
);

@events = events_from_bytes("x\e[200~a\nb\e[201~y");
check(
    'paste parser : keys around the paste stay separate',
    scalar @events == 3
        && $events[0] eq 'x'
        && ref $events[1] eq 'HASH'
        && $events[1]{'paste'} eq "a\nb"
        && $events[2] eq 'y'
);

@events = events_from_bytes("\r\n");
check( 'paste parser : crlf without bracketed paste = one enter',
    scalar @events == 1 && $events[0] eq "\n" );

@events = events_from_bytes("\rx");
check(
    'paste parser : lone cr is enter, next key preserved',
    scalar @events == 2 && $events[0] eq "\n" && $events[1] eq 'x'
);

@events = events_from_bytes("\e[A\e[3~");
check( 'paste parser : escape sequences collected whole',
    scalar @events == 2 && $events[0] eq "\e[A" && $events[1] eq "\e[3~" );

@events = events_from_bytes("ab");
check( 'paste parser : plain bytes pass through',
    scalar @events == 2 && $events[0] eq 'a' && $events[1] eq 'b' );

## paste normalisation result splits into the expected block ##
my $norm = editor_normalize_paste( $events[0] );
check( 'paste parser : bytes readable after parse', $norm eq 'a' );

@events = events_from_bytes("\xC3\xA9\xE2\x80\x94x");
check(
    'utf-8 : multibyte keys decode to single characters',
    scalar @events == 3
        && $events[0] eq "\x{e9}"
        && $events[1] eq "\x{2014}"
        && $events[2] eq 'x'
);

@events = events_from_bytes("\xE9ab");
check(
    'utf-8 : lone latin-1 lead byte keeps the following keys',
    scalar @events == 3
        && $events[0] eq "\xE9"
        && $events[1] eq 'a'
        && $events[2] eq 'b'
);

@events = events_from_bytes("\xE2\x80x");
check(
    'utf-8 : truncated sequence yields every byte as its own key',
    scalar @events == 3
        && $events[0] eq "\xE2"
        && $events[1] eq "\x80"
        && $events[2] eq 'x'
);

##[ summary ]#################################################################

say '';
say sprintf( '=== %d / %d tests passed ===', $tests_passed, $tests_run );
say '';

exit( $tests_passed == $tests_run ? 0 : 1 );

#,,,.,,,,,...,...,,,,,...,,.,,,,,,.,.,,,.,,,,,..,,...,...,.,,,...,,,,,.,.,..,,
#6SGRU7XNOB3L7X4SYYNMOHVXH5IL4IP5YKNQWUSBMIDFLHMXYNSCKROMZZFKOH5SAPMM255WN4N4S
#\\\|TYX72KKUGIJ27TXCTKAKYX2SABNOY3JWG7L4SI7U6Z3WM4IN3GL \ / AMOS7 \ YOURUM ::
#\[7]XEYVIWMJYC5OEFDQLDLIG26ICHLZVKGWW7JJW3BHODIBSGNVN2AY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
