#!/usr/bin/perl

# [ helper: seed the credential fabric with deterministic test slots ]

use v5.24;
use strict;
use warnings;
use English;

use File::Spec;
use FindBin qw| $RealBin |;
use lib File::Spec->catdir( $RealBin, 'lib' );
use CredFabTest qw| p7c_eval |;

my $domain = $ARGV[0] // '';

sub register_slot {
    my ($slot, $type, $sens) = @ARG;
    my $code = sprintf(
        'my $r=$code{"credential_fabric.register"}->({slot=>"%s",owner=>"credential_fabric",type=>"%s",sensitivity=>"%s",storage=>"local"}); return $r->{data};',
        $slot, $type, $sens
    );
    my $out = p7c_eval( 'credential_fabric', $code );
    return ( $out // '' ) eq 'registered' ? 1 : 0;
}

sub rotate_slot {
    my ($slot, $value) = @ARG;
    my $code = sprintf(
        'my $r=$code{"credential_fabric.rotate"}->({slot=>"%s",new_value=>"%s",reason=>"test-harness"}); return $r->{data};',
        $slot, $value
    );
    my $out = p7c_eval( 'credential_fabric', $code );
    return $out // '';
}

my @slots = (
    { slot => 'openweathermap.api-key', type => 'api-key',     sens => 'low' },
    { slot => 'api.atom-host.bearer',   type => 'bearer-token', sens => 'medium' },
    { slot => 'rotation-test.api-key',  type => 'api-key',     sens => 'low' },
);

# [ session slot matching the test echo domain ]
push @slots, { slot => "session.$domain", type => 'api-key', sens => 'low' }
    if length $domain;

my $ok = 1;
for my $s (@slots) {
    if ( not register_slot( $s->{slot}, $s->{type}, $s->{sens} ) ) {
        warn "[ warn ] could not register $s->{slot}\n";
        $ok = 0;
        next;
    }
    my $rot = rotate_slot( $s->{slot}, "test-value-$s->{slot}" );
    if ( $rot ne 'rotated' ) {
        warn "[ warn ] could not rotate $s->{slot}: $rot\n";
        $ok = 0;
    }
}

print $ok ? "seeded\n" : "seeded-with-errors\n";
exit( $ok ? 0 : 1 );

# [ end ]

#,,,,,,..,.,.,,,,,.,.,,.,,,,,,,,.,,,.,,..,,..,..,,...,...,..,,,,,,,,,,.,,,.,,,
#UQYW673QAIBLVKXF4UQYOVXNHZORIZRDV7NFCACEGS4XVNH5OTOVWAP74FTSRCDGYNSI4JN5LK3TQ
#\\\|EMDJDCC3DL35AETW4LJ7Q72PYUWCFORX7HIHWYN2372Z4DGXDNC \ / AMOS7 \ YOURUM ::
#\[7]IE5BVZTLJH426K2QRXLOB3HR5VTRVBBGWVX26XKZT73FX2FD6OAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
