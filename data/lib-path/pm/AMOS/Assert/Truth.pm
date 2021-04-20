
package AMOS::Assert::Truth;  ################################################

use vars qw| $VERSION @EXPORT |;
use Exporter;
use base qw| Exporter |;

@EXPORT = qw| is_true |;

use v5.24;
use strict;
use English;
use warnings;
use Math::BigFloat;
use List::Util 'uniqint';

use AMOS::Assert;

our @assertion_modes = qw[ 4 7 ];

use AMOS::CHKSUM::ELF qw| elf_chksum |;

##[ MAIN FUNCTION ]###########################################################

sub is_true {
    my $calc_str;
    my $data_ref     = shift;
    my $check_as_num = shift // 2;    ## also check as numerical ##
    my $check_as_elf = shift // 1;    ## check elf checksum ##

    return warn_err('no checks enabled')
        if not $check_as_num and not $check_as_elf;

    $data_ref = join( ' ', @{$data_ref} ) if ref($data_ref) eq 'ARRAY';
    $data_ref = \"$data_ref"              if ref($data_ref) eq '';

    my @assertion_modes = uniqint @ARG ? @ARG : @assertion_modes;

    return 0                          ## check as mumber when numerical ##
        if $check_as_num == 1
        and AMOS::Assert::numerical($$data_ref)
        and not calc_true( scalar($$data_ref) );

    return 0                          ## when numerical with no 0 prefix ##
        if $check_as_num == 2
        and AMOS::Assert::numerical_no_prefix($$data_ref)
        and not calc_true( scalar($$data_ref) );

    return 1 if not $check_as_elf;    ## numerical only, skip elf check ##

    ## assert selected elf checksum modes ##

    foreach my $elf_mode (@assertion_modes) {
        if ( not calc_true( elf_chksum( $data_ref, 0, $elf_mode ) ) ) {
            return 0 if not wantarray;
            return ( 0, $elf_mode );    ## report mode level of objection ##
        }

    }
    ## success : TRUE .: ##
    return 1 if not wantarray;
    return ( 1, @assertion_modes );    #scalar @assert_modes );

}

##[ HELPER ROUTINES ]#########################################################

sub calc_true {
    my $check_num = shift;
    error_exit('input not numerical')
        if not AMOS::Assert::numerical($check_num);

    Math::BigFloat->round_mode(qw| trunc |);

    ## implement alternative mode for short lengths ## [LLL]
    my $calc_str = Math::BigFloat->new($check_num)
        ->bdiv( 13, 13 + length($check_num) );

    ## FALSE ### 230769 ####
    return 0 if index( scalar $calc_str, qw| 230769 | ) >= 0;

    ### TRUE ### 384615 | 00000000 ####
    return 1;
}

##[ ERROR HANDLING ]##########################################################

## add these to AMOS.pm ##

sub warn_err {
    my $err_str = shift;
    my $c_lvl   = shift // 1;
    warn "$err_str " . caller_str($c_lvl) . "\n";
    return undef;
}

sub error_exit {
    my $err_str = shift;
    my $c_lvl   = shift // 1;
    die "$err_str " . caller_str($c_lvl) . "\n";
}

sub caller_str {
    my $c_lvl = shift // 0;    ## 0 means caller parent [ from here ] ##
    $c_lvl++;                  ## <-- accounting for this subroutine ##
    my ( $package, $filename, $line, $subroutine ) = caller($c_lvl);

    return "[$filename:$line]";
}

return 1;  ###################################################################

#.............................................................................
#BTRIMMON3FM6OJQK327EHIDWE5NXV7XE6BSE5ABXBDLQPLD6KY26TR75ZKTVTHTFDEMXUZIC765WY
#::: MV3F3AZ7MREHMTZXT74DGKJPRKGYZXPRBHUTVKATY5CKFWOPAD5 :::: NAILARA AMOS :::
# :: ONJB74JPYKQ6YGWBHEZPGJ3CSZHRUSY4ENYMBKJYZ526AOZSKWAY :: CODE SIGNATURE ::
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
