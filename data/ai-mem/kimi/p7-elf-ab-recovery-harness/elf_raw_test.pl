#!/usr/bin/perl
##  raw DynaLoader test of a specific inline_elf .so build  ##
##  usage : <perl> elf_raw_test.pl <path-to-inline_elf.so>  ##

use v5.24;
use strict;
use warnings;
use DynaLoader;

my $so_path = shift @ARGV or die "usage: $0 <inline_elf.so>\n";
die "not found : $so_path\n" if not -f $so_path;

printf "perl version : %s\n", $];
printf "so file      : %s\n", $so_path;

my $libref = DynaLoader::dl_load_file( $so_path, 0 )
    or die "cannot load $so_path : " . DynaLoader::dl_error();

my $symref;
for my $n ( '000', '001', '002', '003', '004' ) {
    $symref = DynaLoader::dl_find_symbol( $libref,
        "boot_COMPILE__${n}__AMOS7__CHKSUM__ELF__inline_elf" );
    last if $symref;
}
die "boot symbol not found\n" if not $symref;

##  install boot under temp name and call it once : it self-installs  ##
##  the real xsub into its compiled-in package                        ##
DynaLoader::dl_install_xsub( 'P7TEST::boot_it', $symref, $so_path );
P7TEST::boot_it();

my $impl;
for my $pkg ( 'AMOS7::INLINE', 'AMOS7::CHKSUM::ELF', 'COMPILE::000::AMOS7::CHKSUM::ELF' ) {
    no strict 'refs';
    if ( defined &{"${pkg}::inline_elf"} ) {
        $impl = \&{"${pkg}::inline_elf"};
        printf "implementation : %s::inline_elf\n", $pkg;
        last;
    }
}
die "inline_elf not registered\n" if not $impl;

my @bin_vectors = (
    join( '', map { chr($_) } 0 .. 31 ),
    join( '', map { chr( 200 + $_ % 56 ) } 0 .. 31 ),
    pack( 'Q*', 1234567890123456789, 987654321098765,
        5555555555555555, 1111111111111111 ),
    "\xC3\xA9\xFF\xFE\x80\xED\xA0\x80\xF4\x90\x80\x80\x00\x41\xC2\x7F",
);

my $i = 0;
foreach my $vec (@bin_vectors) {
    my $sum_7 = $impl->( $vec, 0, 7, 13 );
    my $sum_4 = $impl->( $vec, 0, 4, 13 );
    printf "vec %d : elf7=%09d elf4=%09d\n", $i++, $sum_7, $sum_4;
}
print "== done ==\n";

#,,,,,..,,,,,,,,.,.,,,.,.,,,,,,.,,..,,...,,,,,..,,...,...,..,,.,,,,,,,,.,,...,
#LBNNNL5UJGXJVASTJYMKAQ7S66RNUFNWVJZIBP4NSTLTA4LNISJKTM4JTGBPSHLMU6FBB5KVEZYOW
#\\\|P534CYCVMKS7YE6QYNLBCCXSBKGYWTHNYULN24E7TFWXS44Z4PE \ / AMOS7 \ YOURUM ::
#\[7]YIMKSHW5E6WKM46TAKNHGB5RSF2QY3CWCW7HKGI55NGBOTFZOKDQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
