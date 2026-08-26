use v5.24; use strict; use warnings; use English; use DynaLoader;
my $so = "$ENV{HOME}/.7/inline-code/inline_elf.IJGVOPO3EXIKZZY/lib/auto/"
  . 'COMPILE/000/AMOS7/CHKSUM/ELF/inline_elf/inline_elf.so';
my $libref = DynaLoader::dl_load_file( $so, 0 ) or die DynaLoader::dl_error();
my $symref = DynaLoader::dl_find_symbol( $libref,
    'boot_COMPILE__000__AMOS7__CHKSUM__ELF__inline_elf' ) or die;
DynaLoader::dl_install_xsub( 'P7TEST::boot_it', $symref, $so );
P7TEST::boot_it();
no strict 'refs';
my $impl = *{'AMOS7::INLINE::inline_elf'}{CODE} // die;
my $base = pack( 'Q*', 1234567890123456789, 987654321098765,
    5555555555555555, 1111111111111111 );
my $v1 = $base; printf "4-arg           : %09d\n", $impl->( $v1, 0, 7, 13 );
my $v2 = $base; printf "5-arg 0xFE000000: %09d\n", $impl->( $v2, 0, 7, 13, 0xFE000000 );
my $v3 = $base; printf "5-arg numeric str : %09d\n", $impl->( $v3, 0, 7, 13, '4261412864' );
my $v4 = $base; printf "3-arg            : %09d\n", $impl->( $v4, 0, 7 );
my $v5 = $base; printf "utf8-flagged 4-arg: %09d\n", do { utf8::upgrade($v5); $impl->( $v5, 0, 7, 13 ) };
my $v6 = $base; printf "no-warnings-utf8 block : %09d\n", do {
    no warnings 'utf8';
    $impl->( $v6, 0, 7, 13 );
};
my $v7 = $base;
my $ref = \$v7;
printf "via scalar-ref deref : %09d\n", $impl->( $$ref, 0, 7, 13 );

#,,..,..,,.,.,..,,,..,...,,,,,...,.,.,,..,,,.,..,,...,...,,..,.,,,,..,...,.,,,
#FSFMUD72XSIP77CJ3BLEQHR4IODJZPWKEW7TOLRXQBCWD2CQVJ7Y3G7KHGYFVUQIWRWYE54NYPGPQ
#\\\|PDGW5FGNNLXJEVWSEJFNM5HMPIWMRBXHJZKDCL6USSZ7YWLEM3N \ / AMOS7 \ YOURUM ::
#\[7]5VPTVI7TTVKYLCPZQ32NTENXDRQOOVPQSEYNEJV5M7CCYPFRUQBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
