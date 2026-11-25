#!/usr/bin/env perl
use v5.32;
use strict;
use English;
use warnings;

## AMOS7::Switch : span parsing, the state file, the until check ##

use File::Spec;
use File::Temp qw| tempdir |;
use FindBin    qw| $RealBin |;
use lib File::Spec->catdir( $RealBin, qw| .. .. data lib-path pm | );
use AMOS7::Switch;

my ( $pass, $fail ) = ( 0, 0 );

sub ok {
    my ( $cond, $name ) = @ARG;
    if   ($cond) { $pass++; say "ok   - $name" }
    else         { $fail++; say "FAIL - $name" }
}

my %span = (
    '90s'   => 90,
    '90'    => 90,
    '13m'   => 780,
    '1h30m' => 5400,
    '2d'    => 172800,
    '1w'    => 604800
);
foreach my $text ( sort keys %span ) {
    ok( AMOS7::Switch::parse_span($text) == $span{$text}, "span : $text" );
}
foreach my $text ( '', '0', '0m', 'soon', '1h x', 'm', '-5s', '1.5h' ) {
    ok( !defined AMOS7::Switch::parse_span($text), "span : '$text' no span" );
}
ok( !defined AMOS7::Switch::parse_span(undef), 'span : undef no span' );

ok( !AMOS7::Switch::expired( 0,     100 ), 'until : 0 is no limit' );
ok( !AMOS7::Switch::expired( undef, 100 ), 'until : undef is no limit' );
ok( !AMOS7::Switch::expired( 101,   100 ), 'until : still running' );
ok( AMOS7::Switch::expired( 100,    100 ), 'until : over at its time' );
ok( AMOS7::Switch::expired(1), 'until : now by default' );

my $tmp  = tempdir( CLEANUP => 1 );
my $path = "$tmp/state";
ok( !AMOS7::Switch::read_file($path), 'file : none is empty' );

## an escaped value ending in a backslash must not eat the next line ##
my $text = "two\nlines\ttab \\n literal, ü, ends \\";
ok( AMOS7::Switch::write_file(
        $path, 'a header',
        [ 'a.one', AMOS7::Switch::escape_value($text) ],
        [ 'a.two', 'x = y : z' ]
    ),
    'file : written'
);
my @pairs = AMOS7::Switch::read_file($path);
ok( @pairs == 2
        && AMOS7::Switch::unescape_value( $pairs[0][1] ) eq $text
        && $pairs[1][1] eq 'x = y : z',
    'file : round trip, escapes and utf-8 kept'
);
@pairs = AMOS7::Switch::parse_state("# c\n\n  b : yes \nplain\nc=1\n");
ok( @pairs == 2 && "@{$pairs[0]} @{$pairs[1]}" eq 'b yes c 1',
    'state : `=` and `:`, comments and other lines skipped'
);
ok( !AMOS7::Switch::write_file( "$tmp/no/such", 'h' ),
    'file : an unwritable path returns false'
);

say "\n# $pass passed, $fail failed";
exit( $fail ? 1 : 0 );

#,,..,.,,,..,,,,,,,..,.,.,.,,,,..,.,.,.,.,.,,,..,,...,...,..,,..,,.,.,,,,,...,
#IVUS6B6V6YZPP34L4RNS5P7FBWLIMUZ7ABA5LL7PPAAHZTXII6TCHPVH6NWQXUJ6OCDMCG2S3D57A
#\\\|YTJIFWAVTGQ7ISYKRF3SGCC5WD5WGLPWRX74GBGJJSQHV2DA6TC \ / AMOS7 \ YOURUM ::
#\[7]JTMTM2W5KY65BCI3UPI4FP3LH5WGYOPHYXWQCENOZ2Z6OWEGZWBA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
