
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

our %true  = init_table(qw| true |);
our %false = init_table(qw| false |);

our @assertion_modes = (7);    ## <-- base truth assertion [elf] mode : 7 ###

use AMOS::CHKSUM::ELF qw| elf_chksum |;

##[ MAIN FUNCTION ]###########################################################

sub is_true {
    my $calc_str;

    my $data_ref = shift;

    my $check_as_num = shift // 2;    ## also check as numerical ##
    my $check_as_elf = shift // 1;    ## check elf checksum ##

    return warn_err('no checks enabled')
        if not $check_as_num and not $check_as_elf;

    $data_ref = join( ' ', @{$data_ref} ) if ref($data_ref) eq 'ARRAY';
    $data_ref = \"$data_ref"              if ref($data_ref) ne 'SCALAR';

    my @assertion_modes = uniqint @ARG ? @ARG : @assertion_modes;

    return 0                          ## check as mumber when numerical ##
        if $check_as_num == 1
        and AMOS::Assert::numerical($$data_ref)
        and calc_true( scalar($$data_ref) ) < 0;

    return 0                          ## when numerical with no 0 prefix ##
        if $check_as_num == 2
        and AMOS::Assert::numerical_no_prefix($$data_ref)
        and calc_true( scalar($$data_ref) ) < 0;

    return 1 if not $check_as_elf;    ## numerical only, skip elf check ##

    ## assert selected elf checksum modes ##

    foreach my $elf_mode (@assertion_modes) {
        if ( calc_true( elf_chksum( $data_ref, 0, $elf_mode ) ) < 0 ) {
            return 0 if not wantarray;
            return ( 0, $elf_mode );    ## report mode level of objection ##
        }
    }
    ## success : TRUE .: ##
    return 1 if not wantarray;
    return ( 1, @assertion_modes );    #scalar @assert_modes );

}

##[ HELPER ROUTINES ]#########################################################

sub init_table {
    my $mode = shift // '';
    die 'expected mode parameter [false|true]' if !length($mode);
    my $init_sequence = $mode eq 'true' ? qw| 461538 | : qw| 230769 |;
    my @pairs;
    foreach my $offset ( reverse 0 .. length($init_sequence) ) {
        my $num_t = join(
            '',
            substr( $init_sequence, $offset,
                length($init_sequence) - $offset )
                . substr( $init_sequence, 0, $offset )
        );
        push( @pairs, sprintf( "%06d", $num_t - 1 ) => $offset );  ## round ##
        push( @pairs, sprintf( "%06d", $num_t + 1 ) => $offset );  ## round ##
        push( @pairs, sprintf( "%06d", $num_t + 0 ) => $offset );  ## trunc ##
    }
    return @pairs;
}

sub calc_true {
    my $check_num = shift;
    error_exit('input not numerical')
        if not AMOS::Assert::numerical($check_num);

    my $calc_str;
    my $num_len = length($check_num);
    my $factor  = join( '', '1', 0 x $num_len );

    if ( $num_len < 10 ) {
        $calc_str = sprintf '%.0f', ( $check_num / 13 ) * $factor;
        substr( $calc_str, 0, length($calc_str) - 6, '' );

    } else {
        Math::BigFloat->round_mode(qw| trunc |);

        $calc_str
            = Math::BigFloat->new($check_num)->bmul($factor)
            ->bdiv( 13, 7 + length($check_num) )->bdstr();

        substr( $calc_str, 0, length($calc_str) - 6, '' );
    }

    ## FALSE ### 230769 ####
    return -$false{$calc_str}
        if exists $false{$calc_str};

    ### TRUE ### 384615 ####         ## implement visualization mode ##  [LLL]
    return 1 + $true{$calc_str}
        if exists $true{$calc_str};

    ### TRUE ### 0000000 | 1 ####
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
#PV75KQEOTJOAAQF3NRMA55RFDVEUL76V5YQHJAXNFI3WKFJ6X3UM76JLJPG27RSN7VNWPZ4GYGK22
#::: 7CNCWNRZBUYBV7RH2AUW5TA4OUPJEN6SYCYW36WB3HGHLVCFBEZ :::: NAILARA AMOS :::
# :: KSM6DRKAYXT5WHDCZV7WIPI3RX4RPHG34KH52R7GYAGCZEHJ3YAY :: CODE SIGNATURE ::
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
