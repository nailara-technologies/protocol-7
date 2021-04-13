
package AMOS::Assert::Truth;  ################################################

use vars qw| $VERSION @EXPORT |;
use Exporter;
use base qw| Exporter |;

use v5.24;
use strict;
use English;
use warnings;
use Digest::Elf;    ## max len 47 characters ## req. different implementation
use Math::BigFloat;

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

    return 0                          ## check as mumber first ##
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

sub elf_checksum {    ## max-len 47 [ overflow ] ##
    my $check_sref = shift;
    error_exit('expected scalar reference') if ref($check_sref) ne 'SCALAR';
    warn_err( 'maximum input length <= 47', 2 ) if length($$check_sref) > 47;
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
#HT6JAWVBPKGTPUZJKMBGTVQJFTW47DVQOMUMNMOIIVVEHGHJWGNZ5Q32J7W6Q6HTR4R76RGHXIZXI
#::: S5VQR4N6OMVLVTU4VHZ7PIXCFGP4VI7PHEWIW7DTJFMFGTJKBQ5 :::: NAILARA AMOS :::
# :: D5C6T7A53KCRBN7ZVJXGGOSMK4CJDREPAR3VX4QLDTTZ74BETQDI :: CODE SIGNATURE ::
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
