#!/usr/bin/perl
## ground-truth harness : runs the ACTUAL modules/amos7.decode_octal_bit_header
## code against footer lines and prints decoded values for comparison with
## the standalone python extractor.
use v5.24;
use strict;
use warnings;
use FindBin qw| $RealBin |;
use lib "$RealBin/../../lib-path/pm";



## pure-perl equivalents [ inline-src providers return descriptor hashrefs ;
## the compiled versions are functionally identical to these ] ##
*AMOS7::BitConv::bit_string_to_num = sub { oct( '0b' . $_[0] ) };
sub encode_b32r { 'STUB' }

## load the real module body [ strip header + signature footer ] ##
my $mod_path = "$RealBin/../../../modules/amos7.decode_octal_bit_header";
open my $fh, '<', $mod_path or die "cannot open $mod_path : $!";
my @body;
while ( my $line = <$fh> ) {
    last if $line =~ m|^#([,\.]\s*)+$|;    ## signature footer start ##
    push @body, $line;
}
close $fh;
my $src = join '', @body;
$src =~ s|^## \[:< ##.*?\n\n||s;           ## [:< header
$src =~ s|^# name.*\n||m;
$src =~ s|^# descr.*\n||m;

my $decoder = eval "sub { use English;\n$src\n}";
die "compile error : $@" if $@;

## read footer lines from files listed on STDIN [ or args ] ##
while (<>) {
    chomp;
    my $file = $_;
    my $path = "$RealBin/../../../modules/$file";
    open my $ff, '<', $path or do { warn "skip $file : $!"; next };
    my @lines = <$ff>;
    close $ff;
    my ($footer_line)
        = reverse grep { m|^#([,\.]+)$| } map { my $l = $_; $l =~ s|\s+$||; $l } @lines;
    chomp $footer_line;
    my $r = $decoder->($footer_line);
    printf "%s\tremaining=%s\tendline=%s\terr=%s\n",
        $file,
        $r->{'amos-iterations-remaining'} // 'undef',
        $r->{'endline-state-encoded'}     // 'undef',
        $r->{'encountered-error'}         // 'none';
}

#,,.,,,..,..,,...,,,,,..,,.,,,...,...,...,.,,,..,,...,...,...,.,.,.,.,,.,,,.,,
#HCSGSXAIJB7A73AWO572K4Q33WFDUR4YJO6Q7BR3XDCC3YZ6JTLYRF53A6MLVRVIPCNUQIVVHADWW
#\\\|W7YPRNPMFBP74HHUC3LOTY64WWBC4ILBVOYEE4UUAPTAUZBCHIL \ / AMOS7 \ YOURUM ::
#\[7]TJZ6WVN4EBCSITQVMATQGEUPCGCTZ7YE7DT3KBHVUSZDRLOOSKBA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
