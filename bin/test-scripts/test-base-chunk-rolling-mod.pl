#!/usr/bin/perl

use v5.28;
use strict;
use warnings;

# test script for base.chunk.rolling_mod
# rolling mod-m window chunker over base-256 digit bytes :
#   (a) rolling value matches direct window value mod m at every position
#   (b) boundaries re-sync after insert \ delete \ prepend edits
#   (c) avg chunk length report for modulus 7, 13, 91
#   (d) naive running-prefix remainder loses boundaries after an insert

use File::Spec;
use Cwd     qw| abs_path |;
use FindBin qw| $RealBin |;

my $tests_run    = 0;
my $tests_passed = 0;

sub check {
    my ( $label, $condition ) = @_;
    $tests_run++;
    if ($condition) {
        $tests_passed++;
        printf "[ ok ] %s\n", $label;
    } else {
        printf "[ FAIL ] %s\n", $label;
    }
    return $condition;
}

##[ module loader ]###########################################################

my $up_dir    = File::Spec->updir;
my $root_path = abs_path(
    File::Spec->rel2abs( File::Spec->catdir( $RealBin, $up_dir, $up_dir ) ) );
my $src_dir = File::Spec->catdir( $root_path, qw| src | );

sub load_mod {
    my $name = shift;
    my $path = File::Spec->catfile( $src_dir, $name );
    open( my $fh, '<', $path ) or die "cannot read $path : $!";
    my $src = do { local $/; <$fh> };
    close($fh);
    $src =~ s|\n#,.*\z||s;    ## strip signature footer when present ##
    my $cref = eval "sub { $src }";
    die "compile error in $name : $@" if $@;
    return $cref;
}

my $chunker = load_mod('base.chunk.rolling_mod');

sub chunk_boundaries {
    my ( $data, %param ) = @_;
    my $res = $chunker->( { 'data' => $data, %param } );
    die "chunker failed : " . $res->{'data'}
        if ref $res ne qw| HASH |
        or $res->{'mode'} ne 'true';
    return $res->{'data'};
}

##[ fixed-seed random test data ]#############################################

srand(13);
my $data = join '', map { chr int rand 256 } 1 .. 20000;
my $len  = length $data;

say '';
say '=== testing base.chunk.rolling_mod ===';
say '';

##[ direct window value reference ]###########################################

sub direct_window_value {
    my ( $bytes, $pos, $window, $m ) = @_;
    my $v = 0;
    $v = ( $v * 256 + ord substr $bytes, $_, 1 ) % $m
        for $pos - $window + 1 .. $pos;
    return $v;
}

##[ (a) rolling value == direct window value mod m at every position ]########

for my $window ( 3, 4 ) {
    my $modulus = 13;
    my $res     = chunk_boundaries(
        $data,
        'window' => $window,
        'trace'  => 1
    );
    my $trace = $res->{'trace'};
    my $fail  = 0;
    for my $k ( 0 .. $#$trace ) {
        my $pos    = $window - 1 + $k;
        my $direct = direct_window_value( $data, $pos, $window, $modulus );
        if ( $trace->[$k] != $direct ) {
            $fail++;
            printf "  [ FAIL ] pos %d : rolling %d != direct %d\n",
                $pos, $trace->[$k], $direct;
            last if $fail > 3;
        }
    }
    check(
        sprintf(
            'rolling value == direct window value mod %d '
                . 'at every position [ window %d, %d positions ]',
            $modulus, $window, scalar @$trace
        ),
        $fail == 0
    );

    ## structural sanity : boundaries increasing, ending at data end ##
    my $b    = $res->{'boundaries'};
    my $sane = @$b >= 2 && $b->[-1] == $len;
    my $prev = 0;
    for my $end (@$b) {
        $sane = 0 if $end <= $prev;
        $prev = $end;
    }
    check( sprintf( 'boundaries well-formed [ window %d ]', $window ),
        $sane );
}

##[ (b) boundary re-sync after edits ]########################################

## every original boundary outside the re-sync zone must reappear shifted ##
## by the edit offset ; no unexpected boundaries outside it               ##
sub check_resync {
    my ( $label, $orig, $edited, $p, $delta, $window, $edited_len ) = @_;
    my %expect = ();
    for my $b (@$orig) {
        next if $b > $p and $b <= $p + $window;    ## re-sync zone ##
        $expect{ $b + ( $b > $p ? $delta : 0 ) } = 1;
    }
    my %have = map { $_ => 1 } @$edited;
    my $fail = 0;

    for my $expected ( sort { $a <=> $b } keys %expect ) {
        if ( not $have{$expected} ) {
            $fail++;
            printf "  [ FAIL ] %s : expected boundary %d missing\n",
                $label, $expected;
            last if $fail > 3;
        }
    }
    for my $e (@$edited) {
        next if $expect{$e};
        next if $e > $p and $e <= $p + $window + ( $delta > 0 ? $delta : 0 );
        $fail++;
        printf "  [ FAIL ] %s : unexpected boundary %d\n", $label, $e;
        last if $fail > 3;
    }
    check(
        sprintf(
            '%s : %d boundaries re-sync outside edited chunk',
            $label, scalar keys %expect
        ),
        $fail == 0
    );
}

my $orig_b = chunk_boundaries($data)->{'boundaries'};

## insert 1 byte at position 10000 ##
my $p_insert = 10000;
my $edited_insert
    = substr( $data, 0, $p_insert ) . chr(0x5A) . substr( $data, $p_insert );
check_resync(
    'insert 1 byte @10000',
    $orig_b,   chunk_boundaries($edited_insert)->{'boundaries'},
    $p_insert, 1, 3, length $edited_insert
);

## delete 1 byte at position 10000 ##
my $p_delete = 10000;
my $edited_delete
    = substr( $data, 0, $p_delete ) . substr( $data, $p_delete + 1 );
check_resync(
    'delete 1 byte @10000',
    $orig_b,   chunk_boundaries($edited_delete)->{'boundaries'},
    $p_delete, -1, 3, length $edited_delete
);

## prepend 5 bytes ##
my $edited_prepend = pack( 'C*', 0x41, 0x42, 0x43, 0x44, 0x45 ) . $data;
check_resync(
    'prepend 5 bytes',
    $orig_b, chunk_boundaries($edited_prepend)->{'boundaries'},
    0, 5, 3, length $edited_prepend
);

## also through a scalar ref data param ##
my $ref_b = chunk_boundaries( \$data, 'modulus' => 13 )->{'boundaries'};
check(
    'scalar ref data param matches plain param',
    join( ',', @$ref_b ) eq join( ',', @$orig_b )
);

##[ (c) avg chunk length by modulus ]#########################################

say '';
say 'avg chunk length on 20000 random bytes [ window 3 ] :';
for my $modulus ( 7, 13, 91 ) {
    my $res = chunk_boundaries( $data, 'modulus' => $modulus );
    printf "  modulus %-3d : chunks %5d  avg_len %.2f\n",
        $modulus, $res->{'chunks'}, $res->{'avg_len'};
}
check(
    'modulus 91 avg chunk length larger than modulus 7',
    chunk_boundaries( $data, 'modulus' => 91 )->{'avg_len'}
        > chunk_boundaries( $data, 'modulus' => 7 )->{'avg_len'}
);

##[ (d) naive running-prefix remainder contrast ]#############################

## prefix variant : boundary wherever the running full-prefix remainder ##
## hits zero ; re-sync check identical to the rolling window            ##
sub prefix_boundaries {
    my ( $bytes, $m ) = @_;
    my @b;
    my $r = 0;
    for my $i ( 0 .. length($bytes) - 1 ) {
        $r = ( $r * 256 + ord substr $bytes, $i, 1 ) % $m;
        push @b, $i + 1 if $r == 0;
    }
    push @b, length($bytes) if not @b or $b[-1] != length($bytes);
    return \@b;
}

## note : a byte value == -1 mod 13 [ e.g. 0x5A ] preserves prefix ##
## remainders by coincidence ; use a generic byte for the contrast ##
my $prefix_edited
    = substr( $data, 0, $p_insert ) . chr(0x42) . substr( $data, $p_insert );
my $prefix_b     = prefix_boundaries( $data,          13 );
my $prefix_edit  = prefix_boundaries( $prefix_edited, 13 );
my $p            = $p_insert;
my $prefix_match = 0;
my $prefix_total = 0;
my %edit_have    = map { $_ => 1 } @$prefix_edit;

for my $b (@$prefix_b) {
    next if $b > $p and $b <= $p + 3;    ## re-sync zone ##
    $prefix_total++;
    $prefix_match++ if $edit_have{ $b + 1 };
}
printf "  prefix-remainder : %d of %d boundaries survived 1-byte insert\n",
    $prefix_match, $prefix_total;
check( 'prefix-remainder loses boundaries after insert [ < 10 pct ]',
    $prefix_match < $prefix_total * 0.1 );

say '';
printf "=== %d of %d tests passed ===\n", $tests_passed, $tests_run;
say '';

exit( $tests_passed == $tests_run ? 0 : 1 );

#,,,,,...,.,.,...,..,,.,.,...,,..,.,,,,,,,,,,,..,,...,...,..,,.,.,...,..,,,,.,
#HYLQN5BUAZ42TPGMCLAMO53HYP7RRWVAZ2WBKCBCE22ZUFCZ4HXOERIEP5LBFU6HFBJ6FVLTGZ74O
#\\\|NNJW3RJFFALSRJ4TIQV6B4FJJNLDOD3HYWEODRNPGZKL6BFXNFS \ / AMOS7 \ YOURUM ::
#\[7]RQFMIVU4GJDT2VQE6AFOZHXFVSQDXR2HD4MOBEFKD6MEPEGBU4AI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
