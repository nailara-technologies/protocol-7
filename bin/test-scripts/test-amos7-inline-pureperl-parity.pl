#!/usr/bin/perl
## AMOS7 Inline <-> pure-perl parity : todo RCM --------------------------
###                                                                     ###

## bin/p7-sign-agent forces the pure-perl AMOS7 alternatives                ##
## [ $AMOS7::INLINE::force_pure_perl in its BEGIN block ] because the       ##
## compiled Inline C cache under ~/.7/inline-code is user-writable and      ##
## unsigned. that is only acceptable if both paths agree EXACTLY on every   ##
## function the agent's unlock path uses. this test proves it.              ##
##                                                                          ##
## one perl process cannot hold both paths                                  ##
## [ the decision is process-wide at AMOS7::INLINE load ], so the parent    ##
## generates a deterministic vector set, writes a small worker script, and  ##
## runs it TWICE : once with the switch unset [ Inline C when available ]   ##
## and once forced pure-perl.  the two result streams must be               ##
## byte-identical. any divergence is a STOP : the crypto is not to be       ##
## 'fixed' to match [ report instead ].                                     ##
##                                                                          ##
## vector surface, matching what key_32 + its is_true \ elf_chksum calls    ##
## exercise : bit_string_to_num, elf_chksum \ elf_chksum-with-defaults,     ##
## is_true + calc_true [ the dispatcher entries key_32 reaches, over random ##
## binary, ascii and wide numerical input ], key_32 end-to-end over random  ##
## passphrases with all three seed forms                                    ##
## [ none, numeric, scalar reference ] -- and, inside their documented      ##
## input contracts only, the raw true_int \ true_float oracles calc_true    ##
## dispatches to [ wider raw-oracle input clamps differently in C than the  ##
## pure-perl long-number path -- calc_true's guard exists precisely to      ##
## route such input away from the compiled sub, so the agent never sees     ##
## that ]                                                                   ##

use v5.32.0;
use strict;
use warnings;
use English;
use File::Spec;
use File::Temp ();
use Cwd        qw| abs_path |;
use FindBin    qw| $RealBin |;

use constant TRUE  => 5;
use constant FALSE => 0;

BEGIN {
    my $up_dir    = File::Spec->updir;
    my $root_path = abs_path(
        File::Spec->rel2abs(
            File::Spec->catdir( $RealBin, $up_dir, $up_dir )
        )
    );
    $main::root_path = $root_path;
}

my $fail_count = 0;
STDOUT->autoflush(1);

sub ok ($;$) {
    my ( $cond, $label ) = @ARG;
    if ($cond) { say "  ok   : $label"; return }
    $fail_count++;
    say "  FAIL : $label";
    return;
}

##[ deterministic vector generation ]#########################################

my $rand_state = 0x5DEECE66;    ## fixed seed : same vectors every run ##

sub next_rand {    ## LCG : deterministic, parent-side only ##
    $rand_state = ( $rand_state * 0x41C64E6D + 0x3039 ) & 0x7FFFFFFF;
    return $rand_state;
}

sub next_bytes {    ## random binary string of $len bytes ##
    my $len = shift;
    return join '', map { chr( next_rand() & 0xFF ) } 1 .. $len;
}

my @pass_alphabet = split m||,
    q|abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.,+-|;

sub next_passphrase {    ## key_32 needs >= 13 chars, >= 5 non-whitespace ##
    my $len = 13 + next_rand() % 68;
    return join '',
        map { $pass_alphabet[ next_rand() % @pass_alphabet ] } 1 .. $len;
}

sub hexify { return unpack qw| H* |, shift }

my @vectors;             ## one line each : <type> <hex-payload> [ args ] ##

sub add_vector { push @vectors, join ' ', @ARG; return }

## bit_string_to_num : random bitstrings, lengths 1 .. 64 [ the 64 cap is ##
## the compiled version's croak boundary -- stay inside it ]              ##
foreach my $n ( 1 .. 320 ) {
    my $bit_len = 1 + next_rand() % 64;
    my $bits    = join '', map { next_rand() & 1 } 1 .. $bit_len;
    add_vector( qw| bs2n |, hexify($bits) );
}

## true_int [ raw oracle, its documented contract only : no dot, value      ##
## numerically <= 2**64-1 -- calc_true's dispatch guard is what keeps wider ##
## input away from the compiled sub ; wider values are tested through the   ##
## ctrue \ istrue vectors below, the way the agent reaches them ] : plain   ##
## and negative digit strings, plus fixed edges                             ##
my @tint_values = qw|
    0 1 12 13 26 169 18446744073709551615 9223372036854775808
    -1 -12 -13 -169 -9223372036854775808 -9223372036854775809
    230769 307692076923
    |;
foreach my $n ( 1 .. 380 ) {
    if ( next_rand() & 1 ) {    ## negative : numerically <= 2**64-1 always ##
        my $digit_len = 1 + next_rand() % 21;
        my $digits    = join '', map { next_rand() % 10 } 1 .. $digit_len;
        push @tint_values, '-' . $digits;
    } else {    ## positive : 1..19 digits stays inside the 64 bit contract ##
        my $digit_len = 1 + next_rand() % 19;
        push @tint_values, join '', map { next_rand() % 10 } 1 .. $digit_len;
    }
}
add_vector( qw| tint |, hexify($ARG) ) foreach @tint_values;

## true_float [ raw oracle, contract only : calc_true routes an input here
## when it has a '.' OR is numerically past 2**64 with length < 17 -- bare
## in-range values belong to true_int's domain even when exponent-typed ;
## those boundary shapes are covered by the ctrue vectors below ]
my @tfloat_values = qw|
    0.5 .5 -0.5 -.5 0.0001 -0.0001 3.141592653589 -2.7182818284
    12.999999 13.000001 230769.230769 -30769.2307692 9e19 1e20
    |;
my $tfloat_wanted = 320;
while ( scalar @tfloat_values < $tfloat_wanted ) {
    my $double = unpack qw| d |, next_bytes(8);
    next if $double != $double or abs($double) == 9**9**9;    ## nan \ inf ##
    my $numstr = sprintf qw| %.10g |, $double;
    next if length $numstr > 16;    ## compiled input length < 17 ##
    ## no-dot values route to true_float only past the 64 bit boundary on ##
    ## the positive side -- calc_true's guard lets EVERY no-dot negative  ##
    ## through to true_int [ negative <= 2**64-1 numerically ]            ##
    next
        if index( $numstr, qw| . |, 0 ) == -1
        and not 0 + $numstr > 18446744073709551615;
    push @tfloat_values, $numstr;
}
add_vector( qw| tfloat |, hexify($ARG) ) foreach @tfloat_values;

## calc_true : the dispatch entry is_true calls -- THIS is the surface the ##
## agent's key_32 actually reaches, and it must be mode-independent for    ##
## EVERY valid numerical input : the wide values [ past 2**64, past 17     ##
## chars, 2**53 double-rounding boundary, the exact input the raw-oracle   ##
## comparison above must exclude ], exponent shapes, long digit strings    ##
my @ctrue_values = qw|
    0 1 13 18446744073709551615 18446744073709551616 18446744073709551617
    9999999999999999 99999999999999999999 141038581638587812163
    -141038581638587812163 12345678901234567890123456789
    1e-20 1e-5 -1e-5 -1e20 9e19 -9e19 0.00000000000000000001
    13.13 -13.13 9007199254740992 9007199254740993 9007199254740994
    |;

foreach my $n ( 1 .. 300 ) {
    my $digit_len = 17 + next_rand() % 9;    ## 17..25 digits ##
    my $digits    = join '', map { next_rand() % 10 } 1 .. $digit_len;
    push @ctrue_values, ( next_rand() & 1 ? '-' : '' ) . $digits;
}
foreach my $n ( 1 .. 60 ) {    ## exponent shapes, mantissa <= 16 chars ##
    my $mant_len = 1 + next_rand() % 16;
    my $mantissa = join '', map { next_rand() % 10 } 1 .. $mant_len;
    $mantissa = ( next_rand() & 1 ? '-' : '' ) . $mantissa;
    push @ctrue_values,
        sprintf qw| %se%d |, $mantissa, -20 + next_rand() % 41;
}
add_vector( qw| ctrue |, hexify($ARG) ) foreach @ctrue_values;

## elf_chksum : random binary 1 .. 512 bytes [ high bytes included -- the ##
## utf8 upgrade \ codepoint paths are the historic divergence ], explicit ##
## argument sets around the AMOS-13-ELF-7 and elf-hash configurations and ##
## the defaults the agent's is_true calls use                             ##
foreach my $n ( 1 .. 320 ) {
    my $data  = next_bytes( 1 + next_rand() % 512 );
    my $start = next_rand();    ## full 31 bit range, within \d{1,9} ##
    add_vector( qw| elf |, hexify($data), $start, qw| 7 13 4261412864 | )
        ;                       ## 0xFE000000 ##
    add_vector( qw| elf |, hexify($data), 0, qw| 4 24 4026531840 | )
        ;                       ## 0xF0000000 ##
    add_vector( qw| elf |, hexify($data), $start, qw| 3 13 4261412864 | );
    add_vector( qw| elfd |, hexify($data) );    ## bare defaults ##
}

## is_true : the dispatcher entry key_32 calls, over random binary and
## ascii-ish data, in the mode combinations the unlock path uses -- plus wide
## numerical strings, which route through calc_true's is_number path
foreach my $n ( 1 .. 240 ) {
    my $data = next_bytes( 1 + next_rand() % 64 );
    add_vector( qw| istrue |, hexify($data), qw| 2 1 | );
    add_vector( qw| istrue |, hexify($data), qw| 0 1 | );
}
foreach my $n ( 1 .. 80 ) {
    my $data = next_passphrase();
    add_vector( qw| istrue |, hexify($data), qw| 2 1 | );
}
foreach my $ctrue_value (@ctrue_values) {
    add_vector( qw| istrue |, hexify($ctrue_value), qw| 2 1 | );
}

## key_32 end-to-end : random passphrases, all three seed forms the signature
## supports [ none, numeric, scalar reference ]
foreach my $n ( 1 .. 24 ) {
    my $pass = next_passphrase();
    add_vector( qw| key32 |, hexify($pass), qw| - | );
    add_vector( qw| key32 |, hexify($pass), qw| n 7 | );
    add_vector( qw| key32 |, hexify($pass), qw| s |, hexify('vault seed') );
}

##[ the worker : spawned twice, once per path ]###############################

my $worker_source = <<~'WORKER';
    #!/usr/bin/perl
    ## parity worker -- internal to test-amos7-inline-pureperl-parity.pl ##
    use v5.32.0;
    use strict;
    use warnings;
    use English;

    BEGIN {
        unshift @INC, $ENV{'P7_PARITY_LIB'};
        $AMOS7::INLINE::force_pure_perl = 1
            if $ENV{'P7_PARITY_FORCE_PUREPERL'};
    }

    use AMOS7::13 qw| key_32 |;
    use AMOS7::Assert::Truth qw| is_true |;
    use AMOS7::CHKSUM::ELF qw| elf_chksum |;
    use DynaLoader ();

    foreach my $required_sub (
        \&AMOS7::BitConv::bit_string_to_num,
        \&AMOS7::Assert::Truth::true_int,
        \&AMOS7::Assert::Truth::true_float,
        \&AMOS7::CHKSUM::ELF::inline_elf
        )
    {
        die "expected AMOS7 subroutine not installed\n"
            if ref $required_sub ne qw| CODE |;
    }

    ## the process-side evidence which path ran : forced must be 0 ##
    print STDERR sprintf "DYNLOAD %d\n",
        scalar grep { m|inline-code| } @DynaLoader::dl_shared_objects;

    my $vector_path = shift @ARGV or die "vector path expected\n";
    open( my $vector_fh, qw| < |, $vector_path )
        or die "vectors : $OS_ERROR\n";

    while ( my $line = <$vector_fh> ) {
        chomp $line;
        next unless length $line;
        my ( $type, $payload_hex, @args ) = split m| |, $line;
        my $payload = pack qw| H* |, $payload_hex // '';

        if ( $type eq qw| bs2n | ) {
            say AMOS7::BitConv::bit_string_to_num($payload);
        } elsif ( $type eq qw| tint | ) {
            say AMOS7::Assert::Truth::true_int($payload);
        } elsif ( $type eq qw| tfloat | ) {
            say AMOS7::Assert::Truth::true_float($payload);
        } elsif ( $type eq qw| ctrue | ) {
            say AMOS7::Assert::Truth::calc_true($payload);
        } elsif ( $type eq qw| elf | ) {
            say elf_chksum( \$payload, @args );
        } elsif ( $type eq qw| elfd | ) {
            say elf_chksum( \$payload );
        } elsif ( $type eq qw| istrue | ) {
            say is_true( \$payload, @args );
        } elsif ( $type eq qw| key32 | ) {
            my ( $seed_kind, $seed_val ) = @args;
            my $key;
            if    ( $seed_kind eq qw| - | ) { $key = key_32( \$payload ) }
            elsif ( $seed_kind eq qw| n | ) { $key = key_32( \$payload, 0 + $seed_val ) }
            else {
                my $seed = pack qw| H* |, $seed_val;
                $key = key_32( \$payload, \$seed );
            }
            die "key_32 returned undef\n" if not defined $key;
            say unpack qw| H* |, $key;
        } else {
            die "unknown vector type '$type'\n";
        }
    }
    close $vector_fh;
    WORKER

sub slurp_file {
    my $path = shift;
    open( my $fh, qw| < |, $path ) or return undef;
    local $INPUT_RECORD_SEPARATOR = undef;
    my $data = <$fh>;
    close $fh;
    return $data;
}

## spawn one worker run : stdout \ stderr captured to temp files, exit status
## + both streams back
sub run_worker {
    my ( $force_pure_perl, $worker_path, $vector_path, $temp_dir ) = @ARG;

    my $out_path = File::Spec->catfile( $temp_dir,
        $force_pure_perl ? qw| worker-pure.out | : qw| worker-c.out | );
    my $err_path = File::Spec->catfile( $temp_dir,
        $force_pure_perl ? qw| worker-pure.err | : qw| worker-c.err | );

    my $pid = fork();
    die "fork : $OS_ERROR\n" if not defined $pid;

    if ( $pid == 0 ) {
        local $ENV{'P7_PARITY_LIB'}
            = File::Spec->catdir( $main::root_path, qw| data lib-path pm | );
        local $ENV{'P7_PARITY_FORCE_PUREPERL'} = $force_pure_perl ? 1 : '';
        open( STDOUT, qw| > |, $out_path ) or die "stdout : $OS_ERROR\n";
        open( STDERR, qw| > |, $err_path ) or die "stderr : $OS_ERROR\n";
        exec( $^X, $worker_path, $vector_path )
            or die "exec worker : $OS_ERROR\n";
    }

    waitpid $pid, 0;
    my $exit_status = $CHILD_ERROR >> 8;
    my $out         = slurp_file($out_path) // '';
    my $err         = slurp_file($err_path) // '';
    return ( $exit_status, $out, $err );
}

sub dynload_count {
    my $stderr_text = shift;
    my ($count) = $stderr_text =~ m|^DYNLOAD (\d+)$|m;
    return defined $count ? 0 + $count : undef;
}

##[ run ]#####################################################################

say 'AMOS7 Inline <-> pure-perl parity : todo RCM';

my $temp_dir = File::Temp::tempdir(
    'amos7-inline-parity-XXXX',
    TMPDIR  => 1,
    CLEANUP => 1
);

my $vector_path = File::Spec->catfile( $temp_dir, qw| vectors.txt | );
{
    open( my $vector_fh, qw| > |, $vector_path )
        or die "vectors : $OS_ERROR\n";
    say {$vector_fh} $ARG foreach @vectors;
    close $vector_fh;
}

my $worker_path = File::Spec->catfile( $temp_dir, qw| parity-worker.pl | );
{
    open( my $worker_fh, qw| > |, $worker_path )
        or die "worker : $OS_ERROR\n";
    print {$worker_fh} $worker_source;
    close $worker_fh;
}

say sprintf '  vectors : %d [ bs2n %d, tint %d, tfloat '
    . '%d, ctrue %d, elf %d, istrue %d, key32 %d ]',
    scalar @vectors,
    scalar( grep {m|^bs2n |} @vectors ),
    scalar( grep {m|^tint |} @vectors ),
    scalar( grep {m|^tfloat |} @vectors ),
    scalar( grep {m|^ctrue |} @vectors ),
    scalar( grep {m|^elf |} @vectors ),
    scalar( grep {m|^istrue |} @vectors ),
    scalar( grep {m|^key32 |} @vectors );

my ( $exit_c, $out_c, $err_c )
    = run_worker( FALSE, $worker_path, $vector_path, $temp_dir );
my ( $exit_pure, $out_pure, $err_pure )
    = run_worker( TRUE, $worker_path, $vector_path, $temp_dir );

my $dyn_c    = dynload_count($err_c);
my $dyn_pure = dynload_count($err_pure);

ok( $exit_c == 0, 'inline-path worker completed' )
    or say "       exit $exit_c, stderr : $err_c";
ok( $exit_pure == 0, 'pure-perl worker completed' )
    or say "       exit $exit_pure, stderr : $err_pure";

ok( defined $dyn_pure && $dyn_pure == 0,
    'pure-perl worker loaded no inline-code object [ DynaLoader ]' )
    or say "       dynload count : " . ( $dyn_pure // '<unreported>' );

if ( defined $dyn_c and $dyn_c > 0 ) {
    ok( TRUE,
              "inline-path worker loaded $dyn_c inline-code "
            . "object(s) -- the comparison is compiled vs pure-perl" );
} else {
    say '  note : Inline::C unavailable or nothing compiled -- '
        . 'this host compares the pure-perl path against itself';
    ok( TRUE, 'inline-path side reported no compiled objects [ noted ]' );
}

if ( $exit_c == 0 and $exit_pure == 0 ) {
    ok( $out_c eq $out_pure,
        sprintf '%d result lines byte-identical across both paths',
        scalar @vectors
        )
        or do {
        my @lines_c    = split m|\n|, $out_c;
        my @lines_pure = split m|\n|, $out_pure;
        foreach my $idx ( 0 .. $#vectors ) {
            next
                if defined $lines_c[$idx]
                and defined $lines_pure[$idx]
                and $lines_c[$idx] eq $lines_pure[$idx];
            say "       first divergence : vector $idx [ $vectors[$idx] ]";
            say "         inline   : " . ( $lines_c[$idx]    // '<missing>' );
            say "         pure-perl: " . ( $lines_pure[$idx] // '<missing>' );
            last;
        }
        };
}

##[ summary ]#################################################################

if ( $fail_count == 0 ) {
    say 'all checks passed =)';
    exit 0;
}
say "$fail_count check(s) FAILED";
exit 1;

#,,..,.,,,.,.,,..,.,.,,.,,.,.,,,,,.,.,,.,,...,..,,...,...,...,,,,,.,.,,..,...,
#MZ5L6PKXVL6WTCVWH6XX2UJAY5SS5XNVK3DX7TH67CEXTK5GV6T4F43ZVVJ2IVNTMG2C4AMFIOWE2
#\\\|EMQ7VRFJTQAMWACUFGEUTGR3F5HP7VEQHSSFKWDCRVHPWPYJUH6 \ / AMOS7 \ YOURUM ::
#\[7]EZMAHT26EVMQQ224L3FBEJNH3A36ZPSXCCOCEEJRDPAI2XUOMWDI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
