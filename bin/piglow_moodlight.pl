#!/usr/bin/perl -T

$0 = 'pglow-moodlight';

use strict;
use warnings;
use Device::PiGlow;
use Math::Trig ':pi';
use Time::HiRes qw(sleep);
use Convert::Color::HSV qw(as_rgb8);

my $glow    = Device::PiGlow->new();
my @colours = $glow->colours();

$glow->enable_output();
$glow->enable_all_leds();

$SIG{TERM} = $SIG{INT} = sub {
    $glow->reset();
    exit;
};

my $deg       = 0;
my $val       = 0;
my $step_size = 0.11;
my $old_color = '';

my $yellow_full = Convert::Color::HSV->new( 60, 1, 1 );
my $orange_full = Convert::Color::HSV->new( 30, 1, 1 );

while ( $deg = sprintf( "%.5f", $deg + $step_size ) or 1 ) {
    $deg = 0 if $deg >= 360;
    $val = sprintf( "%.3f", $val + 0.001 ) if $val < 1;

    my $color = Convert::Color::HSV->new( 360 - $deg, 1, $val );

    my @RGB = map { sprintf( "%.0f", 255 * $_ ) } $color->as_rgb8->rgb;

    my $orange_dist = $color->dst_hsv($orange_full);
    my $yellow_dist = $color->dst_hsv($yellow_full);

    my $white  = sprintf( "%.0f", 255 * $val * ( 1 - $color->chroma ) );
    my $orange = sprintf( "%.0f", 255 * $val * ( 1 - $orange_dist ) );
    my $yellow = sprintf( "%.0f", 255 * $val * ( 1 - $yellow_dist ) );

    $glow->set_colour( 'red',    $RGB[0] );
    $glow->set_colour( 'green',  $RGB[1] );
    $glow->set_colour( 'blue',   $RGB[2] );
    $glow->set_colour( 'orange', $orange );
    $glow->set_colour( 'yellow', $yellow );
    $glow->set_colour( 'white',  $white );
    $glow->update();

    sleep 0.013;
}
