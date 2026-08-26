#!/usr/bin/env perl

## standalone test for keyring phase 1 key derivation system exercises: ##
## sign+verify round-trip, tamper detection, path composability         ##

use strict;
use warnings;
use v5.10.0;

use Crypt::Mac::BLAKE2b qw();
use Crypt::Misc         qw( slow_eq encode_b32r );
use Crypt::URandom      qw( urandom );

my $PASS = 0;
my $FAIL = 0;

sub ok {
    my ( $label, $cond ) = @_;
    if ($cond) {
        printf "  ok  %s\n", $label;
        $PASS++;
    } else {
        printf "FAIL  %s\n", $label;
        $FAIL++;
    }
}

## keyed derivation step : child = blake2b_32(parent, info || 0x01) ##
sub derive_child {
    my ( $parent_key, $component ) = @_;
    return Crypt::Mac::BLAKE2b::blake2b( 32, $parent_key,
        $component . "\x01" );
}

sub derive_path {
    my ( $root_key, $dot_path ) = @_;
    my $current = $root_key;
    for my $component ( split /\./, $dot_path ) {
        $current = derive_child( $current, $component );
    }
    return $current;
}

sub keyring_sign {
    my ( $root_key, $dot_path, $datum ) = @_;
    my $key = derive_path( $root_key, $dot_path );
    return Crypt::Mac::BLAKE2b::blake2b( 32, $key, $datum );
}

sub keyring_verify {
    my ( $root_key, $dot_path, $datum, $signature ) = @_;
    my $expected = keyring_sign( $root_key, $dot_path, $datum );
    return slow_eq( $expected, $signature ) ? 1 : 0;
}

sub path_distance {
    my ( $path_a, $path_b ) = @_;
    my @a      = length($path_a) ? split( /\./, $path_a ) : ();
    my @b      = length($path_b) ? split( /\./, $path_b ) : ();
    my $common = 0;
    $common++
        while $common < scalar @a
        and $common < scalar @b
        and $a[$common] eq $b[$common];
    return ( scalar @a - $common ) + ( scalar @b - $common );
}

## -- root key ------------------------------------------------------------ ##

my $root = urandom(32);
printf "root key: %s\n\n", encode_b32r($root);

## -- section 1: sign + verify round trip --------------------------------- ##

print "[ sign + verify round trip ]\n";

my $sig = keyring_sign( $root, 'base.net.connect', 'test datum' );
ok( 'signature is 32 bytes', defined $sig && length($sig) == 32 );

ok( 'valid signature verifies',
    keyring_verify( $root, 'base.net.connect', 'test datum', $sig ) );

ok( 'tampered datum fails',
    !keyring_verify( $root, 'base.net.connect', 'wrong datum', $sig ) );

ok( 'tampered path fails',
    !keyring_verify( $root, 'base.net.listen', 'test datum', $sig ) );

ok( 'truncated signature fails',
    !keyring_verify(
        $root, 'base.net.connect', 'test datum', substr( $sig, 0, 16 )
    )
);

print "\n";

## -- section 2: path composability -------------------------------------- ##

print "[ path composability ]\n";

## derive base.net.connect from root in one shot ##
my $k_full = derive_path( $root, 'base.net.connect' );

## derive base.net from root, then connect from that ##
my $k_base_net = derive_path( $root, 'base.net' );
my $k_step     = derive_child( $k_base_net, 'connect' );

ok( 'full path == two-step derivation', $k_full eq $k_step );

## three-level: root -> base -> net -> connect == root -> base.net.connect ##
my $k_base    = derive_path( $root, 'base' );
my $k_net     = derive_child( $k_base, 'net' );
my $k_connect = derive_child( $k_net,  'connect' );

ok( 'three-step chain matches full path', $k_full eq $k_connect );

## different paths produce different keys ##
my $k_listen = derive_path( $root, 'base.net.listen' );
ok( 'sibling paths produce distinct keys', $k_full ne $k_listen );

my $k_other = derive_path( $root, 'httpd.request' );
ok( 'unrelated path produces distinct key', $k_full ne $k_other );

print "\n";

## -- section 3: distance metric ----------------------------------------- ##

print "[ distance metric ]\n";

ok( 'same path: distance 0',
    path_distance( 'base.net.connect', 'base.net.connect' ) == 0 );

ok( 'siblings under base.net: distance 2',
    path_distance( 'base.net.connect', 'base.net.listen' ) == 2 );

ok( 'no common ancestor below root: distance 5',
    path_distance( 'base.net.connect', 'httpd.request' ) == 5 );

ok( 'parent/child: distance 1',
    path_distance( 'base.net', 'base.net.connect' ) == 1 );

ok( 'root to leaf: distance equals depth',
    path_distance( '', 'base.net.connect' ) == 3
);

print "\n";

## -- section 4: intermediate caching property --------------------------- ##

print "[ intermediate caching property ]\n";

## signing base.net.connect derives the same base.net intermediate regardless
## of whether we derived base.net first
my $k_connect_direct = derive_path( $root, 'base.net.connect' );
ok( 'direct full-path derivation is deterministic',
    $k_connect_direct eq $k_full );

## different root -> different tree ##
my $root2        = urandom(32);
my $k_other_root = derive_path( $root2, 'base.net.connect' );
ok( 'different root key produces different tree', $k_full ne $k_other_root );

print "\n";

## -- summary ------------------------------------------------------------- ##

printf "result: %d passed, %d failed\n", $PASS, $FAIL;
exit( $FAIL ? 1 : 0 );

#,,..,,.,,,,,,.,.,...,.,,,,.,,.,.,...,...,,.,,..,,...,...,.,,,,..,,.,,,.,,,.,,
#WFHFPQSDHOYSLDLGUBWJG4MCT62NZIMI575X74IO7DOPIBOFXIZPHGOQ7DR6LFUB7TI2THKNAHCZ2
#\\\|NE7WHB6XFUV5GH64F4KMSIIRCVE5BZQMMWKQG5MDHNWZRSZB7EC \ / AMOS7 \ YOURUM ::
#\[7]ZQCWHUDTWDPCULJ5VMF7KHMIYQMBLIAVYOW4TWI2TB3KABXQJGDQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
