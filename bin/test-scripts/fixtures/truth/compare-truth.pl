use strict; use warnings; no warnings;
use lib 'data/lib-path/pm';
use AMOS7::Assert::Truth;
srand(5);
my @v = (0, 1, 7, 13, 2**31-1, 2**32-1, 2**32, 2**40+3, 2**53, 999999999, 4294967296*13);
push @v, int rand 2**32 for 1..200; push @v, int rand 2**52 for 1..100;
for my $n (@v) { print "$n i=", (AMOS7::Assert::Truth::true_int($n) // 'u'), " f=", (AMOS7::Assert::Truth::true_float($n/7) // 'u'), "\n" }

#,,..,,.,,,,,,,,.,,,.,,..,...,..,,.,,,,,,,..,,..,,...,...,...,...,.,.,,,,,...,
#L335H5I7X5OCUEPZELAFACX2XZBHK6UHFOBBJCSOKYBCF2N6DMRXPSRCMZTYXX74HZP2UXPK5WNXI
#\\\|LKBECL7CSYYUIMTZAPFRPDWQG3DFEQBQ35LJT2YW2XD3ESC6LPH \ / AMOS7 \ YOURUM ::
#\[7]NIBPWKEDU3CNYGTQ4MSIYLHRBARB66TAUETWE3I3SDTKORIPSKAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
