#!/usr/bin/perl
## [:< ##
## format.kv_block encode/decode unit tests [ standalone, no zenka network ] ##

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

my $encode = load_module('format.kv_block.encode');
my $decode = load_module('format.kv_block.decode');

my ( $pass, $fail ) = ( 0, 0 );

sub ok {
    my ( $cond, $label ) = @_;
    if   ($cond) { $pass++; print "ok     - $label\n"; }
    else         { $fail++; print "NOT OK - $label\n"; }
}

## (a) one long single-line string : wraps, round-trips to same string ##
my $long_val = join ' ', map {"word$_"} 1 .. 30;
my $enc_a    = $encode->( [ [ 'alpha.key', $long_val ] ] );
my @lines_a  = split /\n/, $enc_a;
ok( scalar(@lines_a) > 1, '(a) long value wrapped to multiple lines' );
ok( scalar( grep { length($_) > 78 } @lines_a ) == 0,
    '(a) all encoded lines within 78 columns'
);
my $dec_a = $decode->($enc_a);
ok( @$dec_a == 1 && $dec_a->[0][0] eq 'alpha.key', '(a) key round-trips' );
ok( $dec_a->[0][1] eq $long_val,
    '(a) wrapped paragraph rejoined to original single string' );

## (b) two paragraphs [ blank-line separated ], first long enough to wrap ##
my $p1    = join ' ', map {"para$_"} 1 .. 25;
my $p2    = 'short second paragraph';
my $val_b = "$p1\n\n$p2";
my $enc_b = $encode->( [ [ 'beta.key', $val_b ] ] );
ok( scalar( grep { $_ eq ':' } split /\n/, $enc_b ) == 1,
    '(b) framed blank line [ paragraph separator ] present'
);
my $dec_b = $decode->($enc_b);
ok( $dec_b->[0][1] eq $val_b,
    '(b) two-paragraph value round-trips exactly [ \\n\\n separator ]' );

## (c) free-format value : deliberate short breaks Text::Wrap never made ##
my $val_c = "first deliberate line\nsecond\nx";
my $enc_c = $encode->( [ [ 'gamma.key', $val_c ] ] );
my $dec_c = $decode->($enc_c);
ok( $dec_c->[0][1] eq $val_c,
    '(c) free-format line breaks preserved [ not rejoined ]' );

## (d) dot-notation keys of varying length : column alignment [ max_len ] ##
my @pairs_d = (
    [ 'a',                 'one' ],
    [ 'mid.key',           'two' ],
    [ 'longer.key.path-x', 'three' ],
);
my $enc_d     = $encode->( \@pairs_d );
my @key_lines = grep {m|^: +[\w\-\.]+ +:|} split /\n/, $enc_d;
my @cols      = map  { index( $_, ':', 1 ) } @key_lines;
ok( @key_lines == 3 && scalar( grep { $_ != $cols[0] } @cols ) == 0,
    '(d) key separator columns aligned across varying key lengths'
);
my $dec_d = $decode->($enc_d);
ok( join( ',', map { $_->[0] } @$dec_d ) eq 'a,mid.key,longer.key.path-x',
    '(d) key order preserved' );
ok( join( ',', map { $_->[1] } @$dec_d ) eq 'one,two,three',
    '(d) values round-trip' );

## (e) empty-value key ##
my $enc_e = $encode->( [ [ 'empty.key', '' ] ] );
my $dec_e = $decode->($enc_e);
ok( @$dec_e == 1 && $dec_e->[0][0] eq 'empty.key' && $dec_e->[0][1] eq '',
    '(e) empty-value key round-trips' );

## (f) hashref input [ documented : sorted keys ] ##
my $dec_f = $decode->( $encode->( { 'b.key' => '2', 'a.key' => '1' } ) );
ok( join( ',', map { $_->[0] } @$dec_f ) eq 'a.key,b.key',
    '(f) hashref input emitted with sorted keys'
);

print "\n----\npassed : $pass\nfailed : $fail\n";
exit( $fail ? 1 : 0 );

#,,..,,..,.,.,,,.,...,.,,,..,,,.,,.,.,,,.,,..,..,,...,..,,.,,,.,.,,,.,.,.,,,.,
#SBKHXOJ5ERH45BEFYTWZ7PCPWWTDBHPF5I4W4KPSSRHKARTH5SALJEJX7BAIXN4QDCNWN76LLWVLY
#\\\|5RG63YOBJGKOSIRK6GTZUQLEP3UPY2YM4YX4JLM6O6IA5SOHG3T \ / AMOS7 \ YOURUM ::
#\[7]LCD7NJ7GVSDVMP6AA3EUWKT2YG76YXBRVNRT5OJI6OTFAJ72BWDI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
