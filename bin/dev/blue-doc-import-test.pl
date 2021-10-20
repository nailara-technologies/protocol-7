#!/usr/local/bin/perl

use v5.24;
use strict;
use English;
use warnings;

## adopted demo.pl from Graphics::Magick for an import parameter test ##

use Graphics::Magick;
use List::MoreUtils qw| :all |;

#
# Read model & smile image.
#
print ": read..,\n";

## $null=Graphics::Magick->new;
## $null->Set(size=>'70x70');
## $x=$null->ReadImage('NULL:black');
## warn "$x" if "$x";

my $image = Graphics::Magick->new();

# $x=$image->ReadImage('/data/png/transformation-example.png');
my $x = $image->ReadImage('/data/png/scan-example-000.png');
warn "$x" if "$x";

$image->Shave('5x13');

my @query_attr = sort { length $b <=> length $a }
    reverse sort qw|
    page
    white-point
    mattecolor
    |;

my ( undef, $p_len ) = minmax map {length} @query_attr;

say '';
map { say sprintf '  %*s : %s', $p_len, $ARG, $image->Get( ucfirst($ARG) ) }
    @query_attr;
say '';

$image->Set( matte => qw| true | );    ## transparency ##

$image->Set( fuzz => 24742 );

# print ": rotate ..,\n";
# $image->Rotate(-0.2);

print ": despeckle ..,\n";
$image->Despeckle();

print ": blue background ..,\n";

$image->Opaque( color => qw| white |, fill => '#09052A' );
## $image->Opaque( color => qw| white |, fill => '#0647C3' );

print ": blue foreground ..,\n";
$image->Set( fuzz => 10777 );

$image->Opaque( color => qw| black |, fill => '#0647C3' );
## $image->Opaque( color => qw| black |, fill => '#09052A' );

## export :: print
## export :: display
## export :: to-medium
#
##  export from blue [reverse]  ##
#
# $image->Set( fuzz => 0 );
# $image->Opaque( color => '#09052A', fill => qw| white | );
# $image->Opaque( color => '#0647C3', fill => qw| black | );
# $image->Opaque( color => '#09052A', fill => '#0647C3' );
#
####

#print ": transparent ..,\n";
#$image->Transparent( color => qw| black | );

$image->Set( qw| mattecolor | => '#09052A' );

#print ": despeckle ..,\n";
#$image->Despeckle();

#print ": reduce noise ..,\n";
#$image->ReduceNoise();

#print ": charcoal ..,\n";
#$image->Charcoal();

# print ": edge detect ..,\n";
# $image->Edge(2.42);

print ": transparent ..,\n";

# $image->Transparent( color => qw| white | );
#$image->Transparent( color => qw| black | );
#$image->Set( qw| mattecolor | => '#09052A' );

#0647C3

# $image->Colorize( qw| fill | => qq|#09052A|, qw| opacity | => 57 );

$image->Write('out.png');

print "display..,\n";

$image->Write('win:');

exit;

##  $image->Label('Magick');
##  $image->Set(bordercolor=>'black');
##  $image->Set(background=>'black');
##
##  $smile=Graphics::Magick->new;
##  $x=$smile->ReadImage('smile.gif');
##  warn "$x" if "$x";
##  $smile->Label('Smile');
##  $smile->Set(bordercolor=>'black');
##  #
##  # Create image stack.
##  #
##  print "Transform image...\n";
##  $images=Graphics::Magick->new();
##  $image=$null->Clone();
##  push(@$images,$image);
##  $image=$null->Clone();
##  push(@$images,$image);
##  $image=$null->Clone();
##  push(@$images,$image);
##  $image=$null->Clone();
##  push(@$images,$image);
##  $image=$null->Clone();
##  push(@$images,$image);
##
##  print "Add Noise...\n";
##  $image=$image->Clone();
##  $image->Label('Add Noise');
##  $image->AddNoise("LaplacianNoise");
##  push(@$images,$image);
##
##  print "Annotate...\n";
##  $image=$image->Clone();
##  $image->Label('Annotate');
##  $image->Annotate(text=>'Magick',geometry=>'+0+20',font=>'Generic.ttf',
##    fill=>'gold',gravity=>'North',pointsize=>14);
##  push(@$images,$image);
##
##  print "Blur...\n";
##  $image=$image->Clone();
##  $image->Label('Blur');
##  $image->Blur('0.0x1.0');
##  push(@$images,$image);
##
##  print "Border...\n";
##  $image=$image->Clone();
##  $image->Label('Border');
##  $image->Border(geometry=>'6x6',color=>'gold');
##  push(@$images,$image);
##
##  print "Channel...\n";
##  $image=$image->Clone();
##  $image->Label('Channel');
##  $image->Channel();
##  push(@$images,$image);
##

## print "Charcoal...\n";

## $image->Label('Charcoal');
## $image->Charcoal();

##
##  print "Composite...\n";
##  $image=$image->Clone();
##  $image->Label('Composite');
##  $image->Composite(image=>$smile,compose=>'over',geometry=>'+35+65');
##  push(@$images,$image);
##
##  print "Contrast...\n";
##  $image=$image->Clone();
##  $image->Label('Contrast');
##  $image->Contrast();
##  push(@$images,$image);
##
##  print "Convolve...\n";
##  $image=$image->Clone();
##  $image->Label('Convolve');
##  $image->Convolve([1, 1, 1, 1, 4, 1, 1, 1, 1]);
##  push(@$images,$image);
##
##  print "Crop...\n";
##  $image=$image->Clone();
##  $image->Label('Crop');
##  $image->Crop(geometry=>'80x80+25+50');
##  push(@$images,$image);
##
##  print "Despeckle...\n";
##  $image=$image->Clone();
##  $image->Label('Despeckle');
##  $image->Despeckle();
##  push(@$images,$image);
##

# print "Detect Edges...\n";

# $image=$image->Clone();
##$image->Label('Detect Edges');
## $image->Edge();

# $image->Label('Detect Edges');
# $image->Edge();

## push(@$images,$image);

##
##  print "Emboss...\n";
##  $image=$image->Clone();
##  $image->Label('Emboss');
##  $image->Emboss();
##
##  print "Equalize...\n";
##  push(@$images,$image);
##  $image=$image->Clone();
##  $image->Label('Equalize');
##  $image->Equalize();
##  push(@$images,$image);
##
##
##  print "Frame...\n";
##  $image=$image->Clone();
##  $image->Label('Frame');
##  $image->Frame('15x15+3+3');
##  push(@$images,$image);
##
##  print "Gamma...\n";
##  $image=$image->Clone();
##  $image->Label('Gamma');
##  $image->Gamma(1.6);
##  push(@$images,$image);
##
##  print "Gaussian Blur...\n";
##  $image=$image->Clone();
##  $image->Label('Gaussian Blur');
##  $image->GaussianBlur('0.0x1.5');
##  push(@$images,$image);
##
##  print "Gradient...\n";
##  $gradient=Graphics::Magick->new;
##  $gradient->Set(size=>'130x194');
##  $x=$gradient->ReadImage('gradient:#20a0ff-#ffff00');
##  warn "$x" if "$x";
##  $gradient->Label('Gradient');
##  push(@$images,$gradient);
##
##  print "Grayscale...\n";
##  $image=$image->Clone();
##  $image->Label('Grayscale');
##  $image->Quantize(colorspace=>'gray');
##  push(@$images,$image);
##
##
##  print "Median Filter...\n";
##  $image=$image->Clone();
##  $image->Label('Median Filter');
##  $image->MedianFilter();
##  push(@$images,$image);
##
##  print "Modulate...\n";
##  $image=$image->Clone();
##  $image->Label('Modulate');
##  $image->Modulate(brightness=>110,saturation=>110,hue=>110);
##  push(@$images,$image);
##  $image=$image->Clone();
##
##  print "Monochrome...\n";
##  $image->Label('Monochrome');
##  $image->Quantize(colorspace=>'gray',colors=>2,dither=>'false');
##  push(@$images,$image);
##
##  print "Negate...\n";
##  $image=$image->Clone();
##  $image->Label('Negate');
##  $image->Negate();
##  push(@$images,$image);
##
##  print "Normalize...\n";
##  $image=$image->Clone();
##  $image->Label('Normalize');
##  $image->Normalize();
##  push(@$images,$image);
##
##  print "Oil Paint...\n";
##  $image=$image->Clone();
##  $image->Label('Oil Paint');
##  $image->OilPaint();
##  push(@$images,$image);
##
##  print "Plasma...\n";
##  $plasma=Graphics::Magick->new;
##  $plasma->Set(size=>'130x194');
##  $x=$plasma->ReadImage('plasma:fractal');
##  warn "$x" if "$x";
##  $plasma->Label('Plasma');
##  push(@$images,$plasma);
##
##  print "Quantize...\n";
##  $image=$image->Clone();
##  $image->Label('Quantize');
##  $image->Quantize();
##  push(@$images,$image);
##
##  print "Raise...\n";
##  $image=$image->Clone();
##  $image->Label('Raise');
##  $image->Raise('10x10');
##  push(@$images,$image);
##

##
##  print "Resize...\n";
##  $image=$image->Clone();
##  $image->Label('Resize');
##  $image->Resize('50%');
##  push(@$images,$image);
##
##  print "Roll...\n";
##  $image=$image->Clone();
##  $image->Label('Roll');
##  $image->Roll(geometry=>'+20+10');
##  push(@$images,$image);
##
##  print "Rotate...\n";
##  $image=$image->Clone();
##  $image->Label('Rotate');
##  $image->Rotate(45);
##  $image->Transparent(color=>'black');
##  push(@$images,$image);
##
##  print "Scale...\n";
##  $image=$image->Clone();
##  $image->Label('Scale');
##  $image->Scale('60%');
##  push(@$images,$image);
##
##  print "Segment...\n";
##  $image=$image->Clone();
##  $image->Label('Segment');
##  $image->Segment(cluster=>'0.5', smooth=>'0.25');
##  push(@$images,$image);
##
##  print "Shade...\n";
##  $image=$image->Clone();
##  $image->Label('Shade');
##  $image->Shade(geometry=>'30x30',gray=>'true');
##  push(@$images,$image);
##
##  print "Sharpen...\n";
##  $image=$image->Clone();
##  $image->Label('Sharpen');
##  $image->Sharpen('0.0x1.0');
##  push(@$images,$image);
##
##  print "Shave...\n";
##  $image=$image->Clone();
##  $image->Label('Shave');
##  $image->Shave('10x10');
##  push(@$images,$image);
##
##  print "Shear...\n";
##  $image=$image->Clone();
##  $image->Label('Shear');
##  $image->Shear('45x45');
##  $image->Transparent(color=>'black');
##  push(@$images,$image);
##
##  print "Spread...\n";
##  $image=$image->Clone();
##  $image->Label('Spread');
##  $image->Spread();
##  push(@$images,$image);
##
##  print "Solarize...\n";
##  $image=$image->Clone();
##  $image->Label('Solarize');
##  $image->Solarize();
##  push(@$images,$image);
##
##  print "Swirl...\n";
##  $image=$image->Clone();
##  $image->Set(background=>'#000000FF');
##  $image->Label('Swirl');
##  $image->Swirl(90);
##  push(@$images,$image);
##
##  print "Unsharp Mask...\n";
##  $image=$image->Clone();
##  $image->Label('Unsharp Mask');
##  $image->UnsharpMask('0.0x1.0');
##  push(@$images,$image);
##
##  print "Wave...\n";
##  $image=$image->Clone();
##  $image->Label('Wave');
##  $image->Set(background=>'#000000FF');
##  $image->Wave('25x150');
##  push(@$images,$image);
##  #
##  # Create image montage.
##  #
##  print "Montage...\n";
##  $montage=$images->Montage(geometry=>'130x194+10+5>',gravity=>'Center',
##    bordercolor=>'green',borderwidth=>1,tile=>'5x1000',compose=>'over',
##    background=>'#ffffff',font=>'Generic.ttf',pointsize=>18,fill=>'#600',
##    stroke=>'none');
##
##  $logo=Graphics::Magick->new();
##  $logo->Read('logo:');
##  $logo->Zoom('40%');
##  $montage->Composite(image=>$logo,gravity=>'North');

## print "Write...\n";
#  $montage->Set(matte=>'false');
#  $montage->Write('out.png');

## $image->Set(matte=>'false');
## $image->Write('out.png');

## print "Display...\n";
## $montage->Write('win:');

## $image->Write('win:');

#,,,.,,..,,..,..,,.,.,.,.,.,,,..,,,,,,,,.,.,.,..,,...,...,,.,,...,,..,,..,,..,
#CP4Y73JFQGUJ6SEUS7TEB7R4OLLU3H32W2NL5WVMKECTEN2ETLAWPESCYWPTAKOMWHBYIX6RJW47K
#\\\|F5S5ZAMIAY422PUTFPEJ7SQOHLY6XZAADIVCZAOODCCZJHD6ERO \ / AMOS7 \ YOURUM ::
#\[7]V3KFMLWFTFYZHNXQTWPCX5RXQWHJJ3I6V6H4TWUC5WXCH3IWMYBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
