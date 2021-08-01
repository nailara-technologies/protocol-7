
package AMOS7::Twofish; ######################################################

use v5.24;
use utf8;
use strict;
use English;
use warnings;

use AMOS7;
use Crypt::Twofish2;

use vars qw| $VERSION @EXPORT @EXPORT_OK |;

use Exporter;
use base qw| Exporter |;

@EXPORT = qw[ ];    ##  none  ##

@EXPORT_OK = qw| key_init object_table delete_table_entry encrypt decrypt |;

my $VERSION = qw| AMOS7::Twofish-VERSION.2EXJJ7Q |;

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
            = Crypt::Twofish2->new( $crypt_key, Crypt::Twofish2::MODE_CBC );
    } else {
        $decryption_table{$o_name}    ##  decryption table  ##
            = Crypt::Twofish2->new( $crypt_key, Crypt::Twofish2::MODE_CBC );
    }
    ## true ##
    return 5;
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
    return 5;    ## true ##
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

return 5;  ###################################################################

#,,..,.,,,,,.,.,.,.,.,,.,,..,,,,.,.,.,.,,,..,,..,,...,...,.,.,...,,..,..,,.,,,
#I3Q3G4LYZ4X6WXDF7AZVTJD5CSKS2POHRSF6N6CWCOOZWSBQDXA33FRWOH3Q3CWOCN7EJJRE54JHC
#\\\|CX7ZZXVMYCV2IRV3QLZON66XOPDWV4GYQILVLB45HW6D535IHXO \ / AMOS7 \ YOURUM ::
#\[7]ZCWHBDBAHMJXG2RJ3XYVLTFGBE7YW3WAYWYNT6CU4BLEKUYT6ICY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
