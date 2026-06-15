#!/usr/bin/perl

# [ helper: seed the cred-mesh fabric with deterministic test slots ]

use v5.24;
use strict;
use warnings;
use English;

use File::Spec;
use FindBin qw| $RealBin |;
use lib File::Spec->catdir( $RealBin, 'lib' );
use CredMeshTest qw| p7c_eval |;

my $domain = $ARGV[0] // '';

sub register_slot {
    my ( $slot, $type, $sens ) = @ARG;
    my $code = sprintf(
        'my $r=$code{"cred-mesh.register"}->({slot=>"%s",owner=>"cred-mesh",type=>"%s",sensitivity=>"%s",storage=>"local"}); return $r->{data};',
        $slot, $type, $sens
    );
    my $out = p7c_eval( 'cred-mesh', $code );
    return ( $out // '' ) eq 'registered' ? 1 : 0;
}

sub rotate_slot {
    my ( $slot, $value ) = @ARG;
    my $code = sprintf(
        'my $r=$code{"cred-mesh.rotate"}->({slot=>"%s",new_value=>"%s",reason=>"test-harness"}); return $r->{data};',
        $slot, $value
    );
    my $out = p7c_eval( 'cred-mesh', $code );
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

#,,,,,..,,,..,,..,,,.,.,,,,,.,,,.,...,..,,.,,,..,,...,...,.,,,..,,.,,,..,,,,.,
#Z2WRUEJW7TWTL2TX2644UJS43LSCOSBIFLGZIAKJGHGM2JSIA3XQHFEYOO3SLYTDRJJRCZAZPPLAY
#\\\|NJU5CH4XFNOM2ZEVP6STZUL5UGDIGEJWBNMEJ6IY7NTS4A6XJNY \ / AMOS7 \ YOURUM ::
#\[7]S5WFM5ARDCPL4V5ZZQEBHH223WYVXAKIPMAIE3K4X7POH6OGBEDI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
