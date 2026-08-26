use v5.24; use strict; use warnings; use English; use DynaLoader;
BEGIN { unshift @INC, "/data/projects/protocol-7/data/ai-mem/kimi/p7-elf-ab-recovery-harness/lib540";
        unshift @INC, "/data/projects/protocol-7/data/lib-path/pm" }
use AMOS7;
use AMOS7::CHKSUM::ELF;

sub boot_old_so {
    my ( $so_path, $pkg_us ) = @ARG;
    my $libref = DynaLoader::dl_load_file( $so_path, 0 ) or die DynaLoader::dl_error();
    my $symref;
    for my $n ( '000' .. '010' ) {
        $symref = DynaLoader::dl_find_symbol( $libref, "boot_COMPILE__${n}__${pkg_us}" );
        last if $symref;
    }
    die "no boot sym" if not $symref;
    DynaLoader::dl_install_xsub( 'P7TEST::boot_it', $symref, $so_path );
    P7TEST::boot_it();
    no strict 'refs';
    ( my $short = $pkg_us ) =~ s|^AMOS7__||; $short =~ s|__|::|g;
    $short = ( $short =~ m|([^:]+)$| )[0];
    for my $pkg ( 'AMOS7::INLINE', 'AMOS7::CHKSUM::ELF' ) {
        my $code = *{"${pkg}::${short}"}{CODE};
        return ( $code, "${pkg}::${short}" ) if defined $code;
    }
    die "not registered";
}

my ( $impl, $where ) = boot_old_so(
    "$ENV{HOME}/.7/inline-code/inline_elf.IJGVOPO3EXIKZZY/lib/auto/"
      . 'COMPILE/000/AMOS7/CHKSUM/ELF/inline_elf/inline_elf.so',
    'AMOS7__CHKSUM__ELF__inline_elf' );
print "boot installed at $where\n";
{ no strict 'refs'; no warnings 'redefine';
  *{'AMOS7::CHKSUM::ELF::inline_elf'} = $impl; }

printf "dispatch is old C impl : %s\n",
    ( \&AMOS7::CHKSUM::ELF::inline_elf == $impl ) ? 'YES' : 'NO';

my $vec = pack( 'Q*', 1234567890123456789, 987654321098765,
    5555555555555555, 1111111111111111 );

##  direct C call, fresh copies, 4 args [ as raw test ]  ##
my $v1 = $vec; my $v2 = $vec;
printf "direct 4-arg : elf7=%09d elf4=%09d\n",
    $impl->( $v1, 0, 7, 13 ), $impl->( $v2, 0, 4, 13 );

##  via wrapper [ 5 args, separate copies ]  ##
my $v3 = $vec; my $v4 = $vec;
printf "wrapper      : elf7=%s elf4=%s\n",
    AMOS7::CHKSUM::ELF::elf_chksum( \$v3, 0, 7, 13 ),
    AMOS7::CHKSUM::ELF::elf_chksum( \$v4, 0, 4, 13 );

##  via wrapper, SAME scalar for both calls [ mutation effect ]  ##
my $v5 = $vec;
printf "wrapper same scalar : elf7=%s elf4=%s\n",
    AMOS7::CHKSUM::ELF::elf_chksum( \$v5, 0, 7, 13 ),
    AMOS7::CHKSUM::ELF::elf_chksum( \$v5, 0, 4, 13 );

#,,.,,,.,,,,.,..,,,,,,,.,,,..,,..,...,,..,,,,,..,,...,...,.,.,.,,,...,...,,,,,
#GGLEKBMWNX3ESM4GRPEQY5OHQGFW2VRDXWC2T6OJCBCVSPK5AQ5B2ADUM7TMAFQIIV3FYIV5JRSYS
#\\\|QKOW4XCTZJUBRWOA6C3Y7QPCZHTPV23YNH3BYM26SXK5OBRSDG2 \ / AMOS7 \ YOURUM ::
#\[7]J6F7Q2KTTA4DM3FRSNSHQBOCEXHAUC5TMXKLUC2T5MBB2V2GTKBA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
