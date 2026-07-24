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

use Crypt::Mode::CBC;

use vars qw| $VERSION @EXPORT @EXPORT_OK |;

use Exporter;
use base qw| Exporter |;

@EXPORT = qw[ ];            ##  none  ##

@EXPORT_OK = qw| key_init object_table delete_table_entry encrypt decrypt |;

my $VERSION = qw| AMOS7::Twofish-VERSION.2EXJJ7Q |;

error_exit("perl module 'Crypt::Mode::CBC' not loaded")
    if not defined &Crypt::Mode::CBC::new;

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
        ## encryption table with cipher object, key, and IV  Second    ##
        ## parameter 0 = no padding (matches Crypt::Twofish2 behavior) ##
        $encryption_table{$o_name} = {
            cipher => Crypt::Mode::CBC->new( 'Twofish', 0 ),
            key    => $crypt_key,
            iv     => "\0" x 16,    ## Initialize IV to zero vector ##
        };
    } else {
        ## decryption table with cipher object, key, and IV  Second    ##
        ## parameter 0 = no padding (matches Crypt::Twofish2 behavior) ##
        $decryption_table{$o_name} = {
            cipher => Crypt::Mode::CBC->new( 'Twofish', 0 ),
            key    => $crypt_key,
            iv     => "\0" x 16,    ## Initialize IV to zero vector ##
        };
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

    my $obj = $encryption_table{$o_name};
    my $encrypted_data
        = $obj->{cipher}
        ->encrypt( $payload_data_ref->$*, $obj->{key}, $obj->{iv} );

    ## Update IV to last ciphertext block for stateful CBC ##
    $obj->{iv} = substr( $encrypted_data, -16 );

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

    my $obj = $decryption_table{$o_name};

    ## Save last ciphertext block before decrypting for IV update ##
    my $last_ct_block = substr( $payload_data_ref->$*, -16 );

    my $decrypted_data
        = $obj->{cipher}
        ->decrypt( $payload_data_ref->$*, $obj->{key}, $obj->{iv} );

    ## Update IV to last ciphertext block for stateful CBC ##
    $obj->{iv} = $last_ct_block;

    return \$decrypted_data;
}

return TRUE ##################################################################

#,,.,,,.,,.,,,,,,,,,.,...,.,,,,.,,,,,,.,.,,..,..,,...,...,,,,,,..,..,,,,.,.,.,
#6AXMN5YW47RWZ4QGEBE6DU26V65JBTT6UVGXACTWOX3PLSVAX73KO52HZQ62VTYDLBOGEEBZLNGFW
#\\\|G7MN5QGYWYKYUJIED7A74UBD6GO2AIMPXVXFVLNLTEFKLUT3SOZ \ / AMOS7 \ YOURUM ::
#\[7]TOU6EDPWCHE7ZDM7YLIJN54BM2DJC4FJ3IRTVAHXV5OQYJYGWECY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
