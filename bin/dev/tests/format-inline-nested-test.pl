#!/usr/bin/perl
## [:< ##
## format.inline-nested encode/decode unit tests [ standalone, no zenka ] ##

use strict;
use warnings;
use Text::Wrap;
use FindBin qw| $Bin |;
use Cwd     qw| abs_path |;

my $root = abs_path("$Bin/../../..")
    or die "could not locate protocol-7 root";

## module files are raw perl bodies -> wrap into sub for direct calls ##
sub load_module {
    my $name = shift;
    my $path = "$root/modules/$name";
    open( my $fh, '<', $path ) or die "cannot read $path : $!";
    my $src = do { local $/; <$fh> };
    close($fh);
    my $sub = eval "sub { $src }";
    die "compile error in $name : $@" if $@;
    return $sub;
}

my $encode = load_module('format.inline-nested.encode');
my $decode = load_module('format.inline-nested.decode');

my ( $pass, $fail ) = ( 0, 0 );

sub ok {
    my ( $cond, $label ) = @_;
    if   ($cond) { $pass++; print "ok     - $label\n"; }
    else         { $fail++; print "NOT OK - $label\n"; }
}

sub pairs_str {
    my $pairs = shift;
    return join '|', map { $_->[0] . '=' . $_->[1] } @{$pairs};
}

## (a) bare : one long single-line string : wraps, round-trips ##
my $long_val = join ' ', map {"word$_"} 1 .. 30;
my $enc_a    = $encode->( [ [ 'alpha.key', $long_val ] ] );
my @lines_a  = split /\n/, $enc_a;
ok( scalar( grep {m|^ +\.$|} @lines_a ) == 1,
    '(a) lone-dot entry boundary line present'
);
ok( scalar(@lines_a) > 2, '(a) long value wrapped to multiple lines' );
ok( scalar( grep { length($_) > 78 } @lines_a ) == 0,
    '(a) all encoded lines within 78 columns'
);
my $dec_a = $decode->($enc_a);
ok( ref $dec_a eq 'ARRAY' && @$dec_a == 1 && $dec_a->[0][0] eq 'alpha.key',
    '(a) bare decode returns plain arrayref, key round-trips'
);
ok( $dec_a->[0][1] eq $long_val,
    '(a) wrapped paragraph rejoined to original single string' );

## (b) bare : free-format value [ deliberate short breaks ] ##
my $val_b = "first deliberate line\nsecond\nx";
my $enc_b = $encode->( [ [ 'beta.key', $val_b ] ] );
my $dec_b = $decode->($enc_b);
ok( $dec_b->[0][1] eq $val_b,
    '(b) free-format line breaks preserved [ not rejoined ]' );

## (c) bare : multi-paragraph value [ blank-line separated ] ##
my $p1    = join ' ', map {"para$_"} 1 .. 25;
my $p2    = 'short second paragraph';
my $val_c = "$p1\n\n$p2";
my $enc_c = $encode->( [ [ 'gamma.key', $val_c ] ] );
ok( scalar( grep {m|^ +:$|} split /\n/, $enc_c ) == 1,
    '(c) framed paragraph-break line present'
);
my $dec_c = $decode->($enc_c);
ok( $dec_c->[0][1] eq $val_c,
    '(c) two-paragraph value round-trips exactly [ \\n\\n separator ]' );

## (d) core capability : inter-entry blank lines stripped -> still decodes ##
my @pairs_d = (
    [ 'a',                 $long_val ],
    [ 'mid.key',           "l1\nl2" ],
    [ 'longer.key.path-x', "$p1\n\n$p2" ],
);
my $enc_d = $encode->( \@pairs_d );
ok( scalar( grep {m|^ +\.$|} split /\n/, $enc_d ) == 3,
    '(d) one dot boundary line per entry' );
my $stripped_d = join( '', map { $_ . "\n" } grep {/\S/} split /\n/, $enc_d );
ok( $stripped_d !~ m|\n\n|, '(d) all blank lines stripped from input' );
my $dec_d_full     = $decode->($enc_d);
my $dec_d_stripped = $decode->($stripped_d);
ok( pairs_str($dec_d_full) eq pairs_str( \@pairs_d ),
    '(d) unstripped input round-trips' );
ok( pairs_str($dec_d_stripped) eq pairs_str( \@pairs_d ),
    '(d) blank-stripped input still decodes correctly [ dot markers ]'
);

## (e) inline-wrapped round-trip : path name + pairs recovered ##
my $enc_e = $encode->( \@pairs_d, { inline_path => 'parent.inline.path' } );
ok( $enc_e =~ m|^ \.:\[ parent\.inline\.path \]:\.$|m,
    '(e) inline header present' );
ok( $enc_e =~ m|^ :\.$|m,    '(e) inline footer present' );
ok( $enc_e =~ m|^ :  +\.$|m, '(e) framed dot boundary line present' );
my $dec_e = $decode->($enc_e);
ok( ref $dec_e eq 'HASH' && $dec_e->{inline_path} eq 'parent.inline.path',
    '(e) inline_path recovered' );
ok( ref $dec_e->{pairs} eq 'ARRAY'
        && pairs_str( $dec_e->{pairs} ) eq pairs_str( \@pairs_d ),
    '(e) inline pairs round-trip'
);

## (f) nested inline-within-inline round-trip ##
my $inner_f = $encode->(
    [ [ 'inner.key', 'inner value' ], [ 'inner.two', 'second' ] ],
    { inline_path => 'inner.block' }
);
chomp $inner_f;
my $enc_f = $encode->(
    [ [ 'outer.key', $inner_f ], [ 'after.key', 'tail' ], ],
    { inline_path => 'outer.block' }
);
my $dec_f = $decode->($enc_f);
ok( ref $dec_f eq 'HASH'
        && $dec_f->{inline_path} eq 'outer.block'
        && @{ $dec_f->{pairs} } == 2,
    '(f) outer block decoded [ path + 2 pairs ]'
);
ok( $dec_f->{pairs}[1][0] eq 'after.key' && $dec_f->{pairs}[1][1] eq 'tail',
    '(f) sibling pair after nested value intact' );
my $dec_f_inner = $decode->( $dec_f->{pairs}[0][1] );
ok( ref $dec_f_inner eq 'HASH'
        && $dec_f_inner->{inline_path} eq 'inner.block'
        && pairs_str( $dec_f_inner->{pairs} ) eq
        'inner.key=inner value|inner.two=second',
    '(f) nested inner block recovered from entry value'
);

## (g) empty-value key in both modes ##
my $enc_g_bare = $encode->( [ [ 'empty.key', '' ] ] );
my $dec_g_bare = $decode->($enc_g_bare);
ok( @$dec_g_bare == 1
        && $dec_g_bare->[0][0] eq 'empty.key'
        && $dec_g_bare->[0][1] eq '',
    '(g) empty-value key round-trips [ bare ]'
);
my $enc_g_inl = $encode->(
    [ [ 'empty.key', '' ], [ 'full.key', 'x' ] ],
    { inline_path => 'empty.test' }
);
my $dec_g_inl = $decode->($enc_g_inl);
ok( ref $dec_g_inl eq 'HASH'
        && pairs_str( $dec_g_inl->{pairs} ) eq 'empty.key=|full.key=x',
    '(g) empty-value key round-trips [ inline ]'
);

## (h) varying key lengths : column alignment ##
my @pairs_h = (
    [ 'a',                 'one' ],
    [ 'mid.key',           'two' ],
    [ 'longer.key.path-x', 'three' ],
);
my $enc_h       = $encode->( \@pairs_h );
my @key_lines_h = grep {m|^ *[\w\-\.]+  :|} split /\n/, $enc_h;
my @cols_h      = map  { index( $_, ':' ) } @key_lines_h;
ok( @key_lines_h == 3 && scalar( grep { $_ != $cols_h[0] } @cols_h ) == 0,
    '(h) key separator columns aligned across varying key lengths'
);
my @dot_lines_h = grep {m|^ +\.$|} split /\n/, $enc_h;
ok( @dot_lines_h == 3
        && scalar( grep { index( $_, '.' ) != $cols_h[0] } @dot_lines_h )
        == 0,
    '(h) dot markers aligned with key separator column'
);
my $dec_h = $decode->($enc_h);
ok( join( ',', map { $_->[0] } @$dec_h ) eq 'a,mid.key,longer.key.path-x'
        && join( ',', map { $_->[1] } @$dec_h ) eq 'one,two,three',
    '(h) key order and values round-trip'
);

## (i) hashref input [ documented : sorted keys ] ##
my $dec_i = $decode->( $encode->( { 'b.key' => '2', 'a.key' => '1' } ) );
ok( join( ',', map { $_->[0] } @$dec_i ) eq 'a.key,b.key',
    '(i) hashref input emitted with sorted keys'
);

print "\n----\npassed : $pass\nfailed : $fail\n";
exit( $fail ? 1 : 0 );

#,,.,,,.,,...,,.,,.,.,,.,,.,.,..,,...,,,,,,..,..,,...,...,.,,,,..,,.,,...,,.,,
#RKRLVKV7OJZARGTF73BHTM2XBWSAKKEFNNQWSIKTPQJVQCWDL5ZSSZDSYFUR3BFC3JZ3TX6YVIH4C
#\\\|UUEJ5BIXOPO247FDLAEO4VQTVJBWLD24ANO5T3V6K6A5YK6IKEX \ / AMOS7 \ YOURUM ::
#\[7]YGWIWIXQ4RDXEYEB5T3LI6ZSHT436IRWNJQHB2S4XNU3S3HMIQCI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
