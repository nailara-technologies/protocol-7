## [:< ##

package AMOS7::Twofish; ######################################################

use v5.24;
use utf8;
use strict;
use English;
use warnings;

##[ global constants ]##
use constant TRUE  => 5;    ##  TRUE.  ##
use constant FALSE => 0;    ##  false  ##

use AMOS7;

use Crypt::Twofish2;

use vars qw| $VERSION @EXPORT @EXPORT_OK |;

use Exporter;
use base qw| Exporter |;

@EXPORT = qw[ ];            ##  none  ##

@EXPORT_OK = qw| key_init object_table delete_table_entry encrypt decrypt |;

my $VERSION = qw| AMOS7::Twofish-VERSION.2EXJJ7Q |;

error_exit("perl module 'Crypt::Twofish2' not loaded")
    if not defined &Crypt::Twofish2::MODE_CBC;

##[ INIT ]####################################################################

our %encryption_table;
our %decryption_table;

our $key_length     = 32;
our $min_block_size = 16;

##[ INIT OBJECT ]#############################################################

sub key_init {
    my $crypt_key = shift;
    my $o_type    = shift;
    my $o_name    = shift;

    if ( length( $crypt_key // '' ) != $key_length ) {
        warn_err( 'expected twofish key [ length %03d octets ]',
            1, $key_length );
        return undef;
    } elsif ( not length( $o_type // '' ) ) {
        warn_err('expected twofish object type <{C1}>');
        return undef;
    } elsif ( not length( $o_name // '' ) ) {
        warn_err('expected twofish object name <{C1}>');
        return undef;
    } elsif ( $o_type eq qw| encryption | ) {
        $encryption_table{$o_name}    ##  encryption table  ##
            = Crypt::Twofish2->new( $crypt_key, Crypt::Twofish2::MODE_CBC() );
    } else {
        $decryption_table{$o_name}    ##  decryption table  ##
            = Crypt::Twofish2->new( $crypt_key, Crypt::Twofish2::MODE_CBC() );
    }
    ## true ##
    return TRUE;
}

##[ LIST OBJECTS ]############################################################

sub object_table {
    return {
        qw| encryption | => [
            sort { length $a <=> length $b }
                reverse sort keys %encryption_table
        ],
        qw| decryption | => [
            sort { length $a <=> length $b }
                reverse sort keys %decryption_table
        ]
    };
}

##[ DELETE OBJECT ]###########################################################

sub delete_table_entry {
    my $o_type = shift;
    my $o_name = shift;

    if ( not length( $o_type // '' ) ) {
        warn_err('expected twofish object type <{C1}>');
        return undef;
    } elsif ( not length( $o_name // '' ) ) {
        warn_err('expected twofish object name <{C1}>');
        return undef;
    } elsif ( $o_type eq qw| encryption | ) {
        if ( not defined $encryption_table{$o_name} ) {
            warn_err( 'twofish encryption object %s not defined <{C1}>',
                1, $o_name );
            return undef;
        } else {    ##  encryption table  ##
            $encryption_table{$o_name} = undef;
            delete $encryption_table{$o_name};
        }
    } else {    ##  decryption table  ##
        if ( not defined $decryption_table{$o_name} ) {
            warn_err( 'no twofish decryption object %s defined <{C1}>',
                1, $o_name );
            return undef;
        } else {
            $decryption_table{$o_name} = undef;
            delete $decryption_table{$o_name};
        }
    }
    return TRUE;    ## true ##
}

##[ ENCRYPT ]#################################################################

sub encrypt {
    my $o_name           = shift // '';
    my $payload_data_ref = shift;

    if ( not length( $o_name // '' ) ) {
        warn_err('expected twofish object name <{C1}>');
        return undef;
    } elsif ( not defined $encryption_table{$o_name} ) {
        warn_err( "no such object defined [ '%s' ] <{C1}>", 1, $o_name );
        return undef;
    } elsif ( ref $payload_data_ref ne qw| SCALAR | ) {
        warn_err('expected scalar reference parameter to payload data');
        return undef;
    } elsif ( not length( $payload_data_ref->$* )
        or length( $payload_data_ref->$* ) % 16 != 0 ) {
        warn_err('payload data needs to be multiple of 16 bytes');
        return undef;
    }

    my $encrypted_data
        = $encryption_table{$o_name}->encrypt( $payload_data_ref->$* );

    return \$encrypted_data;
}

##[ DECRYPT ]#################################################################

sub decrypt {
    my $o_name           = shift // '';
    my $payload_data_ref = shift;

    if ( not length( $o_name // '' ) ) {
        warn_err('expected twofish object name <{C1}>');
        return undef;
    } elsif ( not defined $decryption_table{$o_name} ) {
        warn_err( "no such object defined [ '%s' ] <{C1}>", 1, $o_name );
        return undef;
    } elsif ( ref $payload_data_ref ne qw| SCALAR | ) {
        warn_err('expected scalar referdece parameter to payload data');
        return undef;
    } elsif ( not length( $payload_data_ref->$* )
        or length( $payload_data_ref->$* ) % 16 != 0 ) {
        warn_err('payload data needs to be multiple of 16 bytes');
        return undef;
    }

    my $decrypted_data
        = $decryption_table{$o_name}->decrypt( $payload_data_ref->$* );

    return \$decrypted_data;
}

return TRUE ##################################################################

#,,.,,.,.,,..,,,,,,..,.,.,,,,,.,.,,.,,..,,.,.,..,,...,...,...,.,.,,..,.,.,.,.,
#JU2XLXRREONKGRQEK4C33EOXVSEYYAE4UBZTXYOWM7GGBJVFHLC4NZGYBYOFP6ARYL7E4ALZYNFD6
#\\\|4UISYZPMGWN7PFTZDKSV72DT3IZIETIZ5XYWFJ5HI54SH6XKQGO \ / AMOS7 \ YOURUM ::
#\[7]R6GRSGTWPHOGE66YI6W4MELZW6QXDVFX32GYD6PZSR3PJM6BROBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
