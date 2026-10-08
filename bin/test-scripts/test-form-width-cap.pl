#!/usr/bin/perl
## test : terminal-width cap for the interactive form frame [ stubs only ]
##
## covers the engine guarantee added with the <form.term_cols> frame cap : in
## interactive mode an over-long field VALUE must be cut [ trailing '..' ] so
## no rendered frame line exceeds the terminal's columns, a short form renders
## unchanged, the ACTIVE field keeps its cursor visible even when the cursor
## sits inside the part a right-cut would drop [ left-cut ], and a caller that
## passes no cap [ one-shot / -no-tty ] renders byte-identical

use v5.28;
use strict;
use warnings;
use English qw| -no_match_vars |;
use FindBin qw| $RealBin |;
use IO::Handle;

BEGIN { unshift( @INC, "$RealBin/../../data/lib-path/pm" ) }

use AMOS7::Protocol::P7Syntax qw| p7_syntax__translate |;

use constant TRUE    => 5;
use constant FALSE   => 0;
use constant UNKNOWN => 2;

our ( %data, %code, %colors, %keys );
%colors = (
    qw| p7_fg_0000 | => '',
    qw| p7_fg_0001 | => '',
    qw| reset |      => ''
);

my $module_dir = "$RealBin/../../src";

my @module_files = qw|
    editor.ui.ascii_frame.render_form
    ascii.frame.render
    |;

for my $file (@module_files) {
    open( my $fh, '<', "$module_dir/$file" ) or die "open $file : $!";
    my $src = do { local $/; <$fh> };
    close($fh);
    $src =~ s{\n#,[^\n]*\n#[A-Z2-7]{40,}[^\n]*\n#\\\\\\\|.*\z}{}s;
    my $translated = p7_syntax__translate($src);
    my $cref = eval( "sub {\n# line 1 \"$file\"\n" . $translated . "\n}" );
    die "compile $file : $@" if ref $cref ne 'CODE';
    $code{$file} = $cref;
}

##[ stubs ]###################################################################

## hand-built single-mode frame descriptor [ same shape ascii.frame.parse
## produces for a mockup ] : one ':' border, one-space outer margin, two plain
## scalar field slots with a shared 10-column label prefix
my $frame_prefix = sprintf( '  %-5s:  ', qw| alpha | );    ## 10 columns ##

my $test_descriptor = {
    qw| border_style | => qw| single |,
    qw| border |       => {
        qw| left |   => q{:},
        qw| right |  => q{:},
        qw| top |    => [],
        qw| bottom | => [],
    },
    qw| corners |   => {},
    qw| padding |   => { qw| left | => 0, qw| right | => 0 },
    qw| margin |    => { qw| left | => 1 },
    qw| min_width | => 30,
    qw| slots |     => {
        qw| f0 | => {
            qw| type |   => qw| field |,
            qw| prefix | => $frame_prefix,
            qw| suffix | => '',
            qw| row |    => 1,
        },
        qw| f1 | => {
            qw| type |   => qw| field |,
            qw| prefix | => $frame_prefix,
            qw| suffix | => '',
            qw| row |    => 2,
        },
    },
};

$code{'ascii.frame.load'}
    = sub { return { qw| descriptor | => $test_descriptor } };

$code{'ascii.frame.render.border_line'} = sub { return '' };

my %display_value = ( qw| f0 | => '', qw| f1 | => '' );
my %cursor_offset = ( qw| f0 | => 0,  qw| f1 | => 0 );

$code{'editor.control.get_display_value'} = sub {
    my ( $state, $name ) = @ARG;
    return $display_value{$name} // '';
};

$code{'editor.control.get_display_cursor'} = sub {
    my ( $state, $name ) = @ARG;
    return $cursor_offset{$name} // 0;
};

sub reset_state {
    %display_value = ( qw| f0 | => '', qw| f1 | => '' );
    %cursor_offset = ( qw| f0 | => 0,  qw| f1 | => 0 );
    return;
}

sub render_form {
    my ( $active_index, $max_width ) = @ARG;
    my $state = {
        qw| active_field | => $active_index,
        qw| schema |       => {
            qw| fields | =>
                [ { qw| name | => qw| f0 | }, { qw| name | => qw| f1 | } ]
        },
    };
    return $code{'editor.ui.ascii_frame.render_form'}
        ->( $state, qw| test-frame |, undef, undef, $max_width );
}

##[ assertions ]##############################################################

my ( $pass, $fail ) = ( 0, 0 );

sub ok {
    my ( $cond, $label ) = @ARG;    ## local ok(), prototype-free ($;$)
    if ($cond) { $pass++; return }
    $fail++;
    print "FAIL : $label\n";
    return;
}

sub max_line_length {
    my ($rendered) = @_;
    my $max = 0;
    foreach my $line ( split m{\n}, $rendered ) {
        $max = length $line if length $line > $max;
    }
    return $max;
}

my $term_cols = 40;
## value budget mirror of render_form's own computation, checked below ##
my $value_budget = $term_cols - ( 1 + 2 + 0 + 0 ) - ( 10 + 0 ) - 4;   ## 23 ##

##[ over-long unfocused value is cut ]########################################

reset_state();
$display_value{'f0'} = qw| a | x 100;
$display_value{'f1'} = qw| ok |;
$cursor_offset{'f1'} = 2;    ## cursor past the value : 'ok' unobscured ##

## uncapped render demonstrates the bug class : the frame blows past 40 ##
my $uncapped = render_form( 1, undef );
ok( max_line_length($uncapped) > $term_cols,
    'uncapped long value overflows the terminal [ bug reproduced ]' );

my $capped = render_form( 1, $term_cols );
ok( defined $capped, 'capped render succeeds' );
ok( max_line_length($capped) <= $term_cols,
    'no rendered line exceeds the terminal width'
);
ok( index( $capped, ( qw| a | x ( $value_budget - 2 ) ) . q{..} ) >= 0,
    'over-long value cut with a trailing .. [ head kept at budget ]'
);
ok( index( $capped, qw| ok | ) >= 0,
    'the short active field renders intact' );

##[ focused cursor inside the cut part flips to a left-cut ]##################

reset_state();
my $marker_char = qw| Z |;
$display_value{'f0'} = ( qw| a | x 95 ) . $marker_char . ( qw| b | x 4 );
$cursor_offset{'f0'} = 95;    ## cursor sits on 'Z', deep in the tail ##

$capped = render_form( 0, $term_cols );
ok( defined $capped, 'focused long-value render succeeds' );
ok( max_line_length($capped) <= $term_cols,
    'focused row stays within the terminal width'
);
ok( index( $capped, q{..} ) >= 0, 'left-cut carries the leading .. marker' );

my $cursor_at = index( $capped, q{|} );
ok( $cursor_at >= 0, 'cursor marker still visible on the cut row' );
ok( $cursor_at > index( $capped, q{..} ),
    'cursor sits right of the left-cut marker [ tail, not head ]' );

## EXACT position : the marker replaces the character it sits on, so with the
## cursor on 'Z' [ index 95 ] its neighbours are 'a' [ 94 ] and 'b' [ 96 ] --
## an offset that forgot the two '..' characters lands on 93 [ 'a' both ]
ok( substr( $capped, $cursor_at - 1, 1 ) eq qw| a |
        && substr( $capped, $cursor_at + 1, 1 ) eq qw| b |,
    'left-cut cursor lands exactly on the original character [ Z ]'
);

##[ short form renders unchanged ]############################################

reset_state();
$display_value{'f0'} = qw| abc |;
$display_value{'f1'} = qw| ok |;
$cursor_offset{'f0'} = 3;         ## end-of-value cursor on the short field ##

my $short_uncapped = render_form( 0, undef );
my $short_capped   = render_form( 0, $term_cols );

ok( defined $short_uncapped && defined $short_capped,
    'short form renders in both modes' );
ok( $short_capped eq $short_uncapped,
    'short form renders byte-identical with and without the cap' );
ok( index( $short_capped, q{..} ) < 0,
    'no cut markers appear when nothing exceeds the budget' );
ok( max_line_length($short_capped) <= $term_cols,
    'short frame already fits the terminal'
);

##[ one-shot mode [ no cap passed ] stays unchanged ]#########################

reset_state();
$display_value{'f0'} = qw| a | x 100;
$display_value{'f1'} = qw| ok |;

my $oneshot       = render_form( 1, undef );
my $oneshot_again = render_form( 1, undef );
ok( defined $oneshot, 'one-shot render succeeds' );
ok( $oneshot eq $oneshot_again,
    'one-shot [ no cap argument ] is deterministic and uncapped' );
ok( max_line_length($oneshot) > $term_cols,
    'one-shot frame keeps its natural width [ unchanged ]' );
ok( index( $oneshot, q{..} ) < 0, 'one-shot output shows no cut markers' );

##[ summary ]#################################################################

print "\n$pass passed, $fail failed\n";
exit( $fail ? 1 : 0 );

#,,..,,..,..,,.,.,,,,,.,.,,..,,.,,...,,,,,..,,..,,...,...,,,,,..,,,..,.,,,,..,
#K6CAVBOSJHX7NY2TPBNJZTMBUD73QJRYXKMEBVBXLRLRMFJ4UKOV2CVMA57UBFKPEIJWOZ2PG5LKU
#\\\|YHZB3NTJBXY73VZBPA5PDL4BGOMLCQS52BRQQCLN6ESBDYGCXVZ \ / AMOS7 \ YOURUM ::
#\[7]J56WRB6PMYECDIZQLLCZ4MWLTYMFHZM5MUEZ6BZG2CXZVQ2LZSBA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
