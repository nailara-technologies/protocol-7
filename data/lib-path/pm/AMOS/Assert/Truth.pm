
package AMOS::Assert::Truth;  ################################################

use vars qw| $VERSION @EXPORT |;
use Exporter;
use base qw| Exporter |;

use v5.24;
use strict;
use English;
use warnings;
use Digest::Elf;              ## <-- worx for ascii values below 128 ##
use Math::BigFloat;

our @deep_assertion_modes = qw| 4 7 |;

@EXPORT = qw| is_true TRUE |;

if ( caller_str() =~ m|check-truth| ) {    ## use 'deep_truth' [ mode ] ##
    eval { require qw| AMOS/CHKSUM/ELF.pm | };
    *inline_elf = $AMOS::CHKSUM::ELF::inline_elf_ref if not $EVAL_ERROR;
}

##[ MAIN FUNCTION ]###########################################################

sub is_true {
    my $calc_str;
    my $data_ref     = shift;
    my $check_as_num = shift // 1;    ## also check as numerical ##
    my $check_as_elf = shift // 1;    ## check elf checksum ##

    return warn_err('no checks enabled')
        if not $check_as_num and not $check_as_elf;

    $data_ref = join( ' ', @{$data_ref} ) if ref($data_ref) eq 'ARRAY';
    $data_ref = \"$data_ref"              if ref($data_ref) eq '';

    ## used by 'check-truth' and 'question' ##
    my ( $deep_truth, @modes ) = TRUE($data_ref);
    if ( defined $deep_truth ) {
        if ( not wantarray ) {
            return $deep_truth;
        } else {
            return ( $deep_truth, @modes );
        }
    }

    return 0    ## check as mumber first ##
        if $check_as_num
        and is_numerical($$data_ref)
        and not calc_true( scalar($$data_ref) );

    return 1 if not $check_as_elf;

    ## check as string [ elf checksum ] ##
    return calc_true( elf_checksum($data_ref) );    ## pass by reference ##

}

##[ HELPER ROUTINES ]#########################################################

sub calc_true {
    my $check_num = shift;
    error_exit('input not numerical') if not is_numerical($check_num);

    Math::BigFloat->round_mode(qw| trunc |);

    my $calc_str = Math::BigFloat->new($check_num)
        ->bdiv( 13, 13 + length($check_num) );

    ## FALSE ### 230769 ####
    return 0 if index( scalar $calc_str, qw| 230769 | ) >= 0;

    ### TRUE ### 384615 | 00000000 ####
    return 1;
}

sub is_numerical {    ## export from parent ##
    return ( not defined $ARG[0] or $ARG[0] !~ m{^(0|[1-9]\d*)(\.\d+)?$} )
        ? 0
        : 1;
}

##[ ERROR HANDLING ]##########################################################

sub TRUE {
    my $check_sref = shift;
    error_exit('expected scalar reference') if ref($check_sref) ne 'SCALAR';
    return undef                            if not defined &inline_elf;

    my @assertion_modes = @ARG ? @ARG : @deep_assertion_modes;

    foreach my $elf_mode (@assertion_modes) {
        if ( not calc_true( inline_elf( $elf_mode, 0, $$check_sref ) ) ) {
            return 0 if not wantarray;
            return ( 0, $elf_mode );    ## report mode level of objection ##
        }

    }
    ## success : TRUE .: ##
    return 1 if not wantarray;
    return ( 1, @assertion_modes );    #scalar @assert_modes );
}

sub elf_checksum {    ## use alternative in overflow case ##
    my $check_sref = shift;
    error_exit('expected scalar reference') if ref($check_sref) ne 'SCALAR';

    return inline_elf( 4, 0, $$check_sref ) if defined &inline_elf;

    my $elf_chksum = Digest::Elf::elf($$check_sref);
    warn_err( 'elf checksum overflow', 2 )
        if $elf_chksum < 0
        or length($elf_chksum) > 9
        or length($$check_sref) > 0 and $elf_chksum == 0;
    return Digest::Elf::elf($$check_sref);
}

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
#UXAXCCAIHW35COAME4N3EY75WBE4BODIVURQ2BQUZTHM2EOOLITAQRZFVA7TH5YUGSVVHB5VFACFQ
#::: 3SUARSMLS577ZRJERBIFVI7I4IVDGMXL2WJGGZ3L5LWO6NTR34Y :::: NAILARA AMOS :::
# :: QXXO55TL2YDI5VB7QTST56S4UC5CNXK4SRMWPYEA5KKQTKY6JCDY :: CODE SIGNATURE ::
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
