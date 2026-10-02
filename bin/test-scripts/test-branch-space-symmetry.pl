#!/usr/bin/perl
use v5.24;
use strict;
use English;
use warnings;

###                                                                 ###
##  branch.space cube symmetry group : standalone harness            ##
###                                                                 ###

## exercises the real translated module sources [ symmetry.list,           ##
## symmetry.apply, symmetry.invariants, symmetry.random_baseline ] against ##
## an in-process stub environment -- no live zenka required :              ##
## - symmetry.list yields 48 unique entries, 24 with det +1                ##
## - full 3x3x3 block, 3D plus sign and 8 corners are fully invariant      ##
## - a single off-axis cell pinned at the origin gives exactly 1           ##
## - an L-shape keeps only a small symmetry count                          ##
## - applying a symmetry then its inverse returns the original             ##
## - random baseline mean sits far below the symmetric cases               ##

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

##[ p7 runtime environment stubs ]############################################

use constant TRUE  => 5;
use constant FALSE => 0;

our %data;
our %code;
our $call;

##[ module compilation [ same sub-wrapper shape as bin/Protocol-7 ] ]#########

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
    branch.space.symmetry.list
    branch.space.symmetry.apply
    branch.space.symmetry.invariants
    branch.space.symmetry.random_baseline
    |;

sub call_module {
    my ( $module_name, $params ) = @ARG;
    return $code{$module_name}->($params);
}

##[ tiny assertion framework ]################################################

sub ok {
    my ( $cond, $label ) = @ARG;
    if ($cond) { say "  ok   : $label"; return }
    $fail_count++;
    say "  FAIL : $label";
    return;
}

##[ 1 : the 48 symmetries ]###################################################

say ': symmetry.list';

my $list_res = call_module('branch.space.symmetry.list');
ok( ref $list_res eq qw| HASH | and $list_res->{'mode'} eq qw| true |,
    'list returns true' );

my $symmetries = $list_res->{'data'}->{'symmetries'};

ok( ref $symmetries eq qw| ARRAY | and scalar $symmetries->@* == 48,
    '48 entries listed' );

my %unique;
my $det_plus       = 0;
my $entry_shape_ok = 1;

foreach my $entry ( $symmetries->@* ) {
    $entry_shape_ok = 0
        unless ref $entry eq qw| HASH |
        and ref $entry->{'perm'} eq qw| ARRAY |
        and ref $entry->{'signs'} eq qw| ARRAY |
        and $entry->{'perm'}->@* == 3
        and $entry->{'signs'}->@* == 3
        and $entry->{'det'} =~ m{^[+-]?1$};
    $unique{  join( ',', $entry->{'perm'}->@* ) . qw| / |
            . join( ',', $entry->{'signs'}->@* ) }++;
    $det_plus++ if $entry->{'det'} == 1;
}

ok( $entry_shape_ok,           'every entry has perm, signs and det' );
ok( scalar keys %unique == 48, 'all 48 entries unique' );
ok( $det_plus == 24,           '24 proper rotations with det +1' );

my $identity = $symmetries->[0];
ok( ( join( ',', $identity->{'perm'}->@* ) eq '0,1,2' )
        and ( join( ',', $identity->{'signs'}->@* ) eq '1,1,1' )
        and $identity->{'det'} == 1,
    'first entry is the identity rotation'
);

##[ 2 : fully symmetric cell sets ]###########################################

say ': symmetry.invariants [ symmetric sets ]';

my @block_3 = map {
    my $z = $ARG;
    map {
        my $y = $ARG;
        map { [ $z, $y, $ARG ] } -1 .. 1
    } -1 .. 1
} -1 .. 1;

my $inv_block = call_module( 'branch.space.symmetry.invariants',
    { 'cells' => \@block_3 } );
ok( ( $inv_block->{'data'}{'count'} // 0 ) == 48, 'full 3x3x3 block -> 48' );

my @plus_3d = (
    [  0,  0, 0 ],
    [  1,  0, 0 ],
    [ -1,  0, 0 ],
    [  0,  1, 0 ],
    [  0, -1, 0 ],
    [  0,  0, 1 ],
    [  0,  0, -1 ]
);

my $inv_plus = call_module( 'branch.space.symmetry.invariants',
    { 'cells' => \@plus_3d } );
ok( ( $inv_plus->{'data'}{'count'} // 0 ) == 48,
    '3D plus sign [ center + 6 faces ] -> 48'
);

my @corners = map {
    my $z = $ARG;
    map {
        my $y = $ARG;
        map { [ $z, $y, $ARG ] } -1, 1
    } -1, 1
} -1, 1;

my $inv_corners = call_module( 'branch.space.symmetry.invariants',
    { 'cells' => \@corners } );
ok( ( $inv_corners->{'data'}{'count'} // 0 ) == 48, '8 corners -> 48' );

##[ 3 : asymmetric sets ]#####################################################

say ': symmetry.invariants [ asymmetric sets ]';

my $inv_single = call_module( 'branch.space.symmetry.invariants',
    { 'cells' => [ [ 1, 2, 3 ] ], 'center' => 0 } );
ok( ( $inv_single->{'data'}{'count'}             // 0 ) == 1
        and ( $inv_single->{'data'}{'rotations'} // 0 ) == 1
        and ( $inv_single->{'data'}{'mirrors'}   // 0 ) == 0,
    'single off-axis cell [1,2,3] with center 0 -> 1 [ identity only ]'
);

my $inv_single_auto = call_module( 'branch.space.symmetry.invariants',
    { 'cells' => [ [ 1, 2, 3 ] ] } );
ok( ( $inv_single_auto->{'data'}{'count'} // 0 ) == 1,
    'single cell with computed center also -> 1'
);

my @l_shape = ( [ 0, 0, 0 ], [ 0, 0, 1 ], [ 0, 1, 0 ] );

my $inv_l = call_module( 'branch.space.symmetry.invariants',
    { 'cells' => \@l_shape } );
ok( ( $inv_l->{'data'}{'count'} // 0 ) == 4,
    'L-shape -> 4 [ z-swap diagonal and z mirror only ]' );

my $inv_empty
    = call_module( 'branch.space.symmetry.invariants', { 'cells' => [] } );
ok( ref $inv_empty eq qw| HASH | and $inv_empty->{'mode'} eq qw| false |,
    'empty cells rejected' );

##[ 4 : apply and inverse round-trip ]########################################

say ': symmetry.apply';

my $probe = [ 3, -2, 5 ];

my $apply_id = call_module( 'branch.space.symmetry.apply',
    { 'symmetry' => $identity, 'position' => $probe } );
ok( ( join( ',', $apply_id->{'data'}{'position'}->@* ) eq '3,-2,5' ),
    'identity leaves position unchanged' );

my $roundtrip_ok   = 1;
my $inverse_det_ok = 1;

foreach my $entry ( $symmetries->@* ) {
    ## inverse of out[i] = signs[i] * in[ perm[i] ] ##
    my @inv_perm;
    $inv_perm[ $entry->{'perm'}->[$ARG] ] = $ARG foreach 0 .. 2;
    my @inv_signs;
    $inv_signs[$ARG] = $entry->{'signs'}->[ $inv_perm[$ARG] ]
        foreach 0 .. 2;
    my $inverse = { 'perm' => \@inv_perm, 'signs' => \@inv_signs };

    my $fwd = call_module( 'branch.space.symmetry.apply',
        { 'symmetry' => $entry, 'position' => $probe } );
    my $rev = call_module( 'branch.space.symmetry.apply',
        { 'symmetry' => $inverse, 'position' => $fwd->{'data'}{'position'} }
    );
    $roundtrip_ok = 0
        unless join( ',', $rev->{'data'}{'position'}->@* ) eq
        join( ',', $probe->@* );

    ## det of inverse must flip the determinant class back ##
    my $inv_det = 1;
    $inv_det *= $ARG foreach @inv_signs;
    my $inversions = 0;
    foreach my $i ( 0 .. 2 ) {
        foreach my $j ( $i + 1 .. 2 ) {
            $inversions++ if $inv_perm[$i] > $inv_perm[$j];
        }
    }
    $inv_det *= $inversions % 2 ? -1 : 1;
    $inverse_det_ok = 0 unless $inv_det == $entry->{'det'};
}

ok( $roundtrip_ok, 'applying a symmetry then its inverse returns original' );
ok( $inverse_det_ok, 'inverse keeps the determinant class' );

my $apply_bad = call_module( 'branch.space.symmetry.apply',
    { 'symmetry' => $identity, 'position' => [ 1, 2 ] } );
ok( ref $apply_bad eq qw| HASH | and $apply_bad->{'mode'} eq qw| false |,
    'malformed position rejected' );

##[ 5 : random baseline ]#####################################################

say ': symmetry.random_baseline';

my $baseline = call_module( 'branch.space.symmetry.random_baseline',
    { 'cells' => 7, 'size' => 5, 'trials' => 200, 'seed' => 7 } );

my $mean = $baseline->{'data'}{'mean'} // 99;
ok( $mean < 10, "random baseline 7 cells in 5^3 : mean $mean well below 48" );
ok( ( $baseline->{'data'}{'max'} // 99 ) < 48,
    'random baseline max stays below 48'
);
ok( ref $baseline->{'data'}{'histogram'} eq qw| HASH |
        and scalar keys %{ $baseline->{'data'}{'histogram'} } > 0,
    'histogram populated'
);

my $baseline_repeat = call_module( 'branch.space.symmetry.random_baseline',
    { 'cells' => 7, 'size' => 5, 'trials' => 200, 'seed' => 7 } );
ok( ( $baseline_repeat->{'data'}{'mean'} // -1 ) == $mean,
    'fixed seed reproduces the baseline' );

my $baseline_bad = call_module(
    'branch.space.symmetry.random_baseline',
    { 'cells' => 200, 'size' => 5 }
);
ok( ref $baseline_bad eq qw| HASH |
        and $baseline_bad->{'mode'} eq qw| false |,
    'cells exceeding cube volume rejected'
);

##[ summary ]#################################################################

say '';
if ($fail_count) {
    say "FAILED : $fail_count check[s]";
    exit 1;
}
say 'all checks passed';
exit 0;

#,,.,,.,,,,,,,..,,..,,,,.,..,,,.,,...,.,,,,..,..,,...,...,...,,..,,..,.,,,...,
#CRMUUJD63BOGJQSMVJFELWLL7OD3JCJEPL5EFTDGZXNE3AF6AWNBUALDCA4JQB7627CDLTPYAUYOQ
#\\\|OAD52S3OOBP43OOODYR3UODNTSCACMXL7WKUSSIMNCSOM2KSCH6 \ / AMOS7 \ YOURUM ::
#\[7]ITKREXCFA5TSXFK2UHVCQ4ZQ5YCHRXQBIVUVADAZZRRLJKBF7QAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
