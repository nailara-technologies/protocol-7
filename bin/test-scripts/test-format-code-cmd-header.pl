#!/usr/bin/env perl
use v5.24;
use strict;
use English;
use warnings;

## bin/format-code -c : 'my' \ 'our' of $reply \ $call in src/*.cmd.* files ##
## is refused, with the zenka loader's hint. fixtures in a temp dir         ##

use File::Spec;
use Cwd        qw| abs_path |;
use FindBin    qw| $RealBin |;
use File::Temp qw| tempdir |;

my $root = abs_path(
    File::Spec->catdir( $RealBin, File::Spec->updir, File::Spec->updir ) );
my $tool = "$root/bin/format-code";
my $tmp  = tempdir( 'format-code-cmd-XXXXXX', 'TMPDIR' => 1, 'CLEANUP' => 1 );
mkdir "$tmp/src" or die "mkdir : $OS_ERROR";

my ( $pass, $fail ) = ( 0, 0 );

sub ok {
    die "ok() without a name [ a list-context match ? ]\n" if @ARG != 2;
    my ( $cond, $name ) = @ARG;
    if   ($cond) { $pass++; say "ok   - $name" }
    else         { $fail++; say "FAIL - $name" }
    return $cond;
}

## -c exits 0 either way : the report text decides. colours and the ##
## wrapping of long messages are removed                            ##
sub check {
    my ( $name, $body ) = @ARG;
    my $path = "$tmp/src/$name";
    open my $fh, '>', $path or die "$path : $OS_ERROR";
    print {$fh} "## [:< ##\n\n# name  = $name\n# descr = fixture\n\n$body";
    close $fh;
    my $out = qx|$EXECUTABLE_NAME $tool -c $path 2>&1|;
    $out =~ s{\e\[[\d;]*m}{}g;
    $out =~ s{\s+}{ }g;
    return $out;
}

my $out = check( 'x.cmd.top', "my \$reply = 1;\nreturn \$reply;\n" );
ok( $out =~ m{my \$reply line 6 \[ hint} && $out !~ m{syntax valid},
    'my $reply is refused, with its line' );

## the loader's own hint text [ bin/Protocol-7 ] : the two never drift ##
open my $lfh, '<', "$root/bin/Protocol-7" or die "loader : $OS_ERROR";
my $loader = do { local $INPUT_RECORD_SEPARATOR = undef; <$lfh> };
close $lfh;
my ($block) = $loader =~ m{my \@hint = \((.*?)\n\s*\);}s;
my @parts;
foreach my $item ( split m{,\n}, $block // '' ) {
    push @parts, join '', $item =~ m{'((?:[^'\\]|\\.)*)'}g;
}
my $hint = join ' ', grep {length} @parts;
$hint =~ s{\$%s}{\$reply};
$hint =~ s{\x22}{'}g;        ## the report turns double quotes into single ##
my $same = @parts && index( $out, $hint ) >= 0;
ok( $same, 'the hint is the text the zenka loader prints' );

$out = check( 'x.cmd.our', "our \$call;\nreturn [ \$call, 1 ];\n" );
ok( scalar $out =~ m{our \$call line 6}, 'our $call is refused' );

$out = check( 'x.cmd.list',
    "my ( \$first, \$reply ) = \@ARG;\nreturn \$first // \$reply;\n" );
ok( scalar $out =~ m{my \$reply line 6}, 'a list declaration is refused' );

$out = check( 'x.cmd.nested',
          "my \$f = sub { my \$call = shift; "
        . "return \$call };\nreturn \$f->(1);\n" );
ok( scalar $out =~ m{syntax valid} && $out !~ m{pre-declared},
    'an inner block passes' );

$out = check( 'x.cmd.loop',
    "foreach my \$reply ( 1, 2 ) { return \$reply }\nreturn 0;\n" );
ok( scalar $out =~ m{syntax valid}, 'a loop variable has its own scope' );

$out = check( 'x.cmd.mixed',
          "if (1) { my \$reply = 1; return \$reply }\n( "
        . "my \$call = 'a' ) =~ s{a}{b};\nreturn \$call;\n" );
ok( $out =~ m{my \$call line 7} && $out !~ m{my \$reply line},
    'top level in parentheses refused, the block before it passes'
);

## no operator at all : the PPI find of it answers '' ##
$out = check( 'x.cmd.bare', "return 1;\n" );
ok( $out =~ m{syntax valid} && $out !~ m{ARRAY ref},
    'a module without operators passes' );

$out = check( 'x.cmd.clean',
    "## my \$reply in a comment ##\nmy \$text = 'my \$call';\nmy \$replies = "
        . "<[base.time]>->(2);\nmy ( \$calls, \$x ) = ( \$call->{'args'}, "
        . "\$reply );\nreturn [ \$text, \$replies, \$calls, \$x ];\n" );
ok( $out =~ m{syntax valid} && $out !~ m{pre-declared},
    'comments, strings, other names and plain use pass'
);

$out = check( 'x.handler.reply', "my \$reply = shift;\nreturn \$reply;\n" );
ok( scalar $out =~ m{syntax valid},
    'a module without .cmd. may declare them' );

say "\n$pass passed, $fail failed";
exit( $fail ? 1 : 0 );

#,,,.,...,.,.,,,,,,,.,..,,.,,,,,.,,,.,.,,,...,..,,...,...,,.,,,..,,,.,,,,,.,,,
#FZ5EWS64SGZX72OJU7S2PI5ZFSKEWSGRWTEEHL7YJCSJ3KNZGKVZPIQLAD2URMGZ7GK3FJ6TFL6BQ
#\\\|OKIK33Q3ZJZZ2JDMDZB55C7ANSHNVZDNK6S7MZMJN3VQMBOSF56 \ / AMOS7 \ YOURUM ::
#\[7]WK2NGZKMJFEBQSQG5TXLHBA7LCXLKCBL6WZY66UBYR3TWNG5Z4DY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
