## [:< ##

package AMOS7::N7FS::Keys;    ##############################################

## sealed replica root keys : argon2id file protection and os entropy.

use v5.32.0;
use utf8;
use strict;
use English;
use warnings;

use Exporter;
use base qw| Exporter |;
use vars qw| @EXPORT_OK $VERSION |;

our $VERSION = qw| AMOS7::N7FS::Keys-VERSION.AFXGODY |;

@EXPORT_OK = qw| root_init root_open root_passphrase |;

use JSON::PP;
use Crypt::KeyDerivation qw| argon2_pbkdf |;
use AMOS7::N7FS qw| b32 unb32 random_bytes read_file write_new_file refuse |;
use AMOS7::N7FS::Sign qw| seed_signer |;
use AMOS7::N7FS::Sum  qw| bmw384_bytes |;

my $JSON = JSON::PP->new->utf8->canonical;

sub root_passphrase {
    my %opt = @_;
    if ( defined $opt{'pass_fd'} ) {
        open( my $fh, '<&', $opt{'pass_fd'} )
            or refuse( 'cannot read passphrase fd : %s', $OS_ERROR );
        my $pass = <$fh> // '';
        $pass =~ s|\r?\n\z||;
        close $fh;
        return $pass;
    }
    require Term::ReadKey;
    print STDERR 'root passphrase : ';
    Term::ReadKey::ReadMode(qw| noecho |);
    my $pass = <STDIN> // '';
    Term::ReadKey::ReadMode(qw| restore |);
    print STDERR "\n";
    $pass =~ s|\r?\n\z||;
    return $pass;
}

sub _pack {
    my ( $secret, $salt, $params ) = @_;
    my $head = $JSON->encode(
        {   qw| kdf |  => qw| argon2id |,
            qw| t |    => $params->{'t'},
            qw| m |    => $params->{'m'},
            qw| p |    => $params->{'p'},
            qw| salt | => b32($salt),
        }
    );
    return "P7RK\x01" . pack( qw| N/a* |, $head ) . $secret;
}

sub _unpack {
    my $bytes = shift // '';
    refuse('root file : bad magic or suite')
        if substr( $bytes, 0, 5 ) ne "P7RK\x01";
    my $head_len = unpack qw| N |, substr( $bytes, 5, 4 );
    my $head     = eval { $JSON->decode( substr( $bytes, 9, $head_len ) ) };
    refuse('root file : bad parameters') if ref $head ne qw| HASH |;
    my $salt = unb32( $head->{'salt'} // '' );
    refuse('root file : bad salt') if not defined $salt or length $salt != 16;
    refuse('root file : unsupported kdf')
        if ( $head->{'kdf'} // '' ) ne qw| argon2id |
        or ( $head->{'t'} // '' ) !~ m|\A[1-9]\d*\z|
        or ( $head->{'m'} // '' ) !~ m|\A[1-9]\d*\z|
        or ( $head->{'p'} // '' ) !~ m|\A[1-9]\d*\z|;
    return ( $head, $salt, substr( $bytes, 9 + $head_len ) );
}

sub root_init {
    my %opt  = @_;
    my $path = $opt{'path'} // refuse('root init needs a file');
    refuse( 'root file %s exists', $path ) if -e $path or -l $path;
    my %params = (
        qw| t | => $opt{'argon_t'} // 3,
        qw| m | => $opt{'argon_m'} // 262144,
        qw| p | => $opt{'argon_p'} // 1,
    );
    refuse('argon parameters must be positive integers')
        if grep { ( $params{$ARG} // '' ) !~ m|\A[1-9]\d*\z| } keys %params;
    my $pass = root_passphrase(%opt);
    refuse('empty root passphrase') if not length $pass;
    my $confirm = root_passphrase(%opt);
    refuse('root passphrases differ') if $pass ne $confirm;

    require AMOS7::N7FS::Seal;
    my $salt = random_bytes(16);
    my $id   = random_bytes(16);
    my $secret
        = AMOS7::N7FS::Seal::new_keypair() . AMOS7::N7FS::Sign::new_seed();
    my $derived = argon2_pbkdf( qw| argon2id |, $pass, $salt, $params{'t'},
        $params{'m'}, $params{'p'}, 64 );
    my $wrapped = AMOS7::N7FS::Seal::wrap_bytes( $derived, $secret, $id, 0,
        qw| root-file | );
    write_new_file( $path, _pack( $wrapped, $salt, \%params ) );
    chmod 0600, $path or refuse( 'cannot protect root file %s', $path );
    return { qw| path | => $path };
}

sub root_open {
    require AMOS7::N7FS::Seal;
    my %opt  = @_;
    my $path = $opt{'path'} // refuse('root key file needed');
    my @st   = stat $path or refuse( 'no root key file %s', $path );
    refuse('root key file is readable by others [ chmod 600 ]')
        if $st[2] & 0077;
    my $bytes = read_file($path);
    my ( $params, $salt, $wrapped ) = _unpack($bytes);
    my $pass    = root_passphrase(%opt);
    my $derived = argon2_pbkdf( qw| argon2id |, $pass, $salt, $params->{'t'},
        $params->{'m'}, $params->{'p'}, 64 );
    my $secret = AMOS7::N7FS::Seal::unwrap_bytes( $derived, $wrapped,
        qw| root-file | );
    refuse('root secret has the wrong length') if length $secret != 96;
    my $keys   = substr( $secret, 0, 64 );
    my $signer = seed_signer( substr( $secret, 64, 32 ) );
    return {
        qw| keys |    => $keys,
        qw| signer |  => $signer,
        qw| root_id | => AMOS7::N7FS::b32(
            bmw384_bytes( 'p7 n7fs seal root id v1' . $signer->public )
        ),
        qw| path | => $path,
    };
}

1;

#,,.,,...,,.,,,.,,,..,..,,,,,,..,,..,,,..,.,,,..,,...,..,,,,,,.,.,,.,,.,.,..,,
#HIF3B43UNO4QP3K5AQBOIX2YEYATANSOAILIH4DWI6RVSJOEMB2TECO766HYLDFQ7O4KCMGUQXP3E
#\\\|4QMHVHP53RCVZCYLXKOOUGN7KVMVF7YT7CIR7F4J5EAT6NYUALI \ / AMOS7 \ YOURUM ::
#\[7]2EDBOD24RF6U4LGEYGKUY54H7LKYBLCYSWDF5MCTTXMN4N2IOMDA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
