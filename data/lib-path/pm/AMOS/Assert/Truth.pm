
package AMOS::Assert::Truth;  ################################################

use vars qw| $VERSION @EXPORT |;
use Exporter;
use base qw| Exporter |;

use v5.24;
use strict;
use English;
use warnings;
use Math::BigFloat;

use AMOS::CHKSUM::ELF qw| elf_chksum |;

our @deep_assertion_modes = qw| 4 7 |;

@EXPORT = qw| is_true |;

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

    my @assertion_modes = @ARG ? @ARG : @deep_assertion_modes;

    return 0                          ## check as mumber when numerical ##
        if $check_as_num
        and is_numerical($$data_ref)
        and not calc_true( scalar($$data_ref) );

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
    error_exit('input not numerical') if not is_numerical($check_num);

    Math::BigFloat->round_mode(qw| trunc |);

    ## implement alternative mode for short lengths ## [LLL]
    my $calc_str = Math::BigFloat->new($check_num)
        ->bdiv( 13, 13 + length($check_num) );

    ## FALSE ### 230769 ####
    return 0 if index( scalar $calc_str, qw| 230769 | ) >= 0;

    ### TRUE ### 384615 | 00000000 ####
    return 1;
}

sub is_numerical {    ## export from parent module ## [LLL]
    return ( not defined $ARG[0] or $ARG[0] !~ m{^\d+(\.\d+)?$} )
        ? 0
        : 1;
}

##[ ERROR HANDLING ]##########################################################

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
#IJ65RWHV5PM2Q4OMCMPOOEHQCJSIQO76MKILPHRJNFSKK7MT7YXT2WRXD2IFVG3LLLECTFHXJBINM
#::: NB7373HCT57I45RJLI2IYJJ5OLTKCKTYLVBCS7EIGYBE2X7R2OR :::: NAILARA AMOS :::
# :: ULA2CPRB5F5L4Q3MLNT44RVCRQEJLSFMFQBXAWTCJRRUSXWMTGCQ :: CODE SIGNATURE ::
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
