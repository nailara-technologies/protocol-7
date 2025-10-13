#!/usr/bin/perl -T

use strict;
use English;
use warnings;

use Device::PiGlow;
use Time::HiRes qw| sleep |;
use Convert::Color::HSV qw| as_rgb8 |;

$0 = qw| piglow-moodlight |;

my $glow    = Device::PiGlow->new();
my @colours = $glow->colours();

$glow->enable_output();
$glow->enable_all_leds();

$SIG{'INT'} = $SIG{'TERM'} = sub {
    $glow->reset();
    exit;
};

my $val       = 0;
my $deg       = 0;
my $step_size = 0.11;
my $old_color = '';

my $yellow_full = Convert::Color::HSV->new( 60, 1, 1 );
my $orange_full = Convert::Color::HSV->new( 30, 1, 1 );

while ( $deg = sprintf( qw| %.5f |, $deg + $step_size ) or 1 ) {

    $deg = 0 if $deg >= 360;

    $val = sprintf( qw| %.3f |, $val + 0.001 ) if $val < 1;

    my $color = Convert::Color::HSV->new( 360 - $deg, 1, $val );

    my @RGB = map { sprintf( qw| %.0f |, 255 * $ARG ) } $color->as_rgb8->rgb;

    my $yellow_dist = $color->dst_hsv($yellow_full);
    my $orange_dist = $color->dst_hsv($orange_full);

    my $white  = sprintf( qw| %.0f |, 255 * $val * ( 1 - $color->chroma ) );
    my $orange = sprintf( qw| %.0f |, 255 * $val * ( 1 - $orange_dist ) );
    my $yellow = sprintf( qw| %.0f |, 255 * $val * ( 1 - $yellow_dist ) );

    $glow->set_colour( qw| blue   |, $RGB[2] );
    $glow->set_colour( qw|  green |, $RGB[1] );
    $glow->set_colour( qw|    red |, $RGB[0] );
    $glow->set_colour( qw| orange |, $orange );
    $glow->set_colour( qw| yellow |, $yellow );
    $glow->set_colour( qw|  white |, $white );
    $glow->update();

    sleep 0.013;
}

#,,.,,,.,,,.,,,..,.,.,,,.,,,,,,.,,,..,,,.,.,.,.,.,...,...,.,.,...,...,,,.,,,.,
#3D7QULE2KTRQL7K26EUZRXPK43IZF2M4AJGTDB6Y2QWZSRCY2H7OEUQLFRL6JZ7LOJLWSA4QIBUSY
#\\\|AUMZ2TWM4TPLH4KD3R3QLG2DSJTEWADB3HLXGSSH2IFAVRNPWAJ \ / AMOS7 \ YOURUM ::
#\[7]SEQKGVUKOAH6BIEW6EFSHKZLILT5AUTA7IKG3LGSKRKDVHKEYEBA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
