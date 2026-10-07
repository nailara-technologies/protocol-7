#!/usr/bin/perl
## ground-truth harness : runs the ACTUAL src/amos7.decode_octal_bit_header
## code against footer lines and prints decoded values for comparison with the
## standalone python extractor.
use v5.24;
use strict;
use warnings;
use FindBin qw| $RealBin |;
use lib "$RealBin/../../lib-path/pm";

## pure-perl equivalents [ inline-src providers return descriptor hashrefs ##
## ; the compiled versions are functionally identical to these ]           ##
*AMOS7::BitConv::bit_string_to_num = sub { oct( '0b' . $_[0] ) };
sub encode_b32r {'STUB'}

## load the real module body [ strip header + signature footer ] ##
my $mod_path = "$RealBin/../../../../src/amos7.decode_octal_bit_header";
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
    my $path = "$RealBin/../../../../src/$file";
    open my $ff, '<', $path or do { warn "skip $file : $!"; next };
    my @lines = <$ff>;
    close $ff;
    my ($footer_line)
        = reverse grep {m|^#([,\.]+)$|}
        map { my $l = $_; $l =~ s|\s+$||; $l } @lines;
    chomp $footer_line;
    my $r = $decoder->($footer_line);
    printf "%s\tremaining=%s\tendline=%s\terr=%s\n",
        $file,
        $r->{'amos-iterations-remaining'} // 'undef',
        $r->{'endline-state-encoded'}     // 'undef',
        $r->{'encountered-error'}         // 'none';
}

#,,,,,...,,,.,.,,,,.,,,,,,...,..,,..,,.,.,.,,,..,,...,..,,.,.,.,.,,,,,...,.,.,
#QQWFTAVAPIFTAIUWN2H2PCC57JX22XK5GR6DJFGDSG2KOMNHIZQGNJ4UVSYCC5YXZP4TSEGGIV3FC
#\\\|GH654MD6BQL34CY2Z3DEJX4IAMGQFG4O24ULW3CPDS3XSXNST6D \ / AMOS7 \ YOURUM ::
#\[7]DTAAO33R7H2T32UKKGUJCN2NM2MMRESOZD5TXGUMHR5VTS57D4BY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
