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

our $VERSION = qw| AMOS7::N7FS::Keys-VERSION.U2AMVPI |;

@EXPORT_OK = qw| root_init root_open root_convert root_passphrase |;

use JSON::PP;
use Crypt::KeyDerivation qw| argon2_pbkdf |;
use AMOS7::N7FS          qw| b32 unb32 random_bytes read_file write_new_file
    make_dirs refuse |;
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
    print {*STDERR} ( $opt{'prompt'} // 'root passphrase' ), ' : ';
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

## a key reference is a passphrase file, or vault:<name> for a p7-vault note
sub _is_vault { return ( shift // '' ) =~ m|\Avault:| ? 1 : 0 }

sub _vault_name {
    my $ref = shift // '';
    my ($name) = $ref =~ m|\Avault:([A-Za-z0-9_.-]{1,64})\z|;
    refuse( 'vault key reference is invalid [ %s ]', $ref )
        if not defined $name;
    return $name;
}

sub _vault_open {
    my %opt = @_;
    require AMOS7::Vault;
    my $dir = $opt{'vault_dir'} // $ENV{'P7_VAULT_DIR'}
        // sprintf( '%s/.n/vault', $ENV{'HOME'} // '' );
    my ( $vault, $err ) = AMOS7::Vault::vault_open($dir);
    refuse( 'vault : %s', $err // 'cannot open' ) if not $vault;
    my $pass = root_passphrase( %opt, qw| prompt | => 'vault passphrase' );
    my $open = AMOS7::Vault::vault_unlock( $vault, $pass );
    AMOS7::Vault::secret_wipe( \$pass );
    refuse('vault passphrase does not unlock the vault') if not $open;
    return $vault;
}

sub _vault_title { return 'n7fs root ' . _vault_name(shift) }

## the entry id and record of a root stored in an unlocked vault
sub _vault_find {
    my ( $vault, $ref ) = @_;
    my $title    = _vault_title($ref);
    my $versions = AMOS7::Vault::entry_versions($vault);
    foreach my $id ( sort keys %{$versions} ) {
        my ($record) = AMOS7::Vault::entry_load( $vault, $id );
        next                    if ref $record ne qw| HASH |;
        return ( $id, $record ) if ( $record->{'title'} // '' ) eq $title;
    }
    return;
}

sub _vault_store {
    my ( $ref, $secret, %opt ) = @_;
    my $vault = _vault_open(%opt);
    refuse( 'vault already holds a root named %s', _vault_name($ref) )
        if _vault_find( $vault, $ref );
    AMOS7::Vault::entry_save(
        $vault, undef,
        {   qw| type |  => qw| note |,
            qw| title | => _vault_title($ref),
            qw| body |  => b32($secret),
        }
    );
    AMOS7::Vault::vault_lock($vault);
    return;
}

sub _vault_load {
    my ( $ref, %opt ) = @_;
    my $vault = _vault_open(%opt);
    my ( undef, $record ) = _vault_find( $vault, $ref );
    AMOS7::Vault::vault_lock($vault);
    refuse( 'vault holds no root named %s', _vault_name($ref) )
        if not $record;
    my $secret = unb32( $record->{'body'} // '' );
    refuse('vault root entry is invalid')
        if not defined $secret
        or length $secret != 96;
    return $secret;
}

sub _file_store {
    my ( $path, $secret, %opt ) = @_;
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
    my $salt    = random_bytes(16);
    my $id      = random_bytes(16);
    my $derived = argon2_pbkdf( qw| argon2id |, $pass, $salt, $params{'t'},
        $params{'m'}, $params{'p'}, 64 );
    my $wrapped = AMOS7::N7FS::Seal::wrap_bytes( $derived, $secret, $id, 0,
        qw| root-file | );
    write_new_file( $path, _pack( $wrapped, $salt, \%params ) );
    chmod 0600, $path or refuse( 'cannot protect root file %s', $path );
    return;
}

sub _file_load {
    my ( $path, %opt ) = @_;
    require AMOS7::N7FS::Seal;
    my @st = stat $path or refuse( 'no root key file %s', $path );
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
    return $secret;
}

sub _store {
    my ( $ref, $secret, %opt ) = @_;
    return _vault_store( $ref, $secret, %opt ) if _is_vault($ref);
    return _file_store( $ref, $secret, %opt );
}

sub _load {
    my ( $ref, %opt ) = @_;
    return _vault_load( $ref, %opt ) if _is_vault($ref);
    return _file_load( $ref, %opt );
}

sub _root_id {
    my $signer = shift;
    return b32( bmw384_bytes( 'p7 n7fs seal root id v1' . $signer->public ) );
}

## the base of `<base>.state` : a file keeps its state beside it, a vault root
## has no path of its own so it lives under the host directory by root id
sub _state_base {
    my ( $ref, $root_id, %opt ) = @_;
    return $ref if not _is_vault($ref);
    my $dir = $ENV{'N7FS_HOST_DIR'}
        // sprintf( '%s/.n/n7fs', $ENV{'HOME'} // '' );
    make_dirs( "$dir/seal-roots", 0700 );
    return "$dir/seal-roots/$root_id";
}

sub root_init {
    my %opt = @_;
    my $ref = $opt{'path'}
        // refuse('root init needs a file or vault:<name>');
    _vault_name($ref) if _is_vault($ref);
    refuse( 'root file %s exists', $ref )
        if not _is_vault($ref)
        and ( -e $ref or -l $ref );
    require AMOS7::N7FS::Seal;
    my $secret
        = AMOS7::N7FS::Seal::new_keypair() . AMOS7::N7FS::Sign::new_seed();
    _store( $ref, $secret, %opt );
    return { qw| path | => $ref };
}

sub root_open {
    my %opt    = @_;
    my $ref    = $opt{'path'} // refuse('root key file needed');
    my $secret = _load( $ref, %opt );
    my $keys   = substr( $secret, 0, 64 );
    my $signer = seed_signer( substr( $secret, 64, 32 ) );
    my $id     = _root_id($signer);
    return {
        qw| keys |    => $keys,
        qw| signer |  => $signer,
        qw| root_id | => $id,
        qw| path |    => _state_base( $ref, $id, %opt ),
    };
}

## only the wrapping of the root changes : every blob, map and holder stays
## valid. the counter and pins carry over, the writer id deliberately does not
sub root_convert {
    my %opt = @_;
    my ( $from, $to ) = @opt{qw| from to |};
    refuse('root convert : source and target are the same') if $from eq $to;
    _vault_name($to)                                        if _is_vault($to);
    refuse( 'root file %s exists', $to )
        if not _is_vault($to)
        and ( -e $to or -l $to );
    my $secret = _load( $from, %opt );
    my $id     = _root_id( seed_signer( substr( $secret, 64, 32 ) ) );
    _store( $to, $secret, %opt );
    my $old = _state_base( $from, $id, %opt ) . '.state/state';
    my $new = _state_base( $to,   $id, %opt ) . '.state';

    if ( -f $old and not -e "$new/state" ) {
        my $state = $JSON->decode( read_file($old) );
        delete $state->{'writer'};
        make_dirs( $new, 0700 );
        write_new_file( "$new/state", $JSON->encode($state) );
    }
    return { qw| root_id | => $id };
}

1;

#,,,,,,,,,...,..,,.,.,,..,,,,,.,.,.,.,,.,,,,.,..,,...,...,.,,,,..,.,,,,..,...,
#UMM3YHKG3BCRJX5IPSYS4CJHATUSEEGV6S5ZX5WPNSIQMU5SLOD3TSCANRNNGFHXXJYB3KA3I433Y
#\\\|UTBTHNMEXGQSRY52BM4RAMQIDLR76ZTCLGS47OHYQ7FFPWSG2UF \ / AMOS7 \ YOURUM ::
#\[7]FZIX6744CR3TFY7ZXREYK2UVXBZIQX6VT6YPWAHBJBWC2RUNYOAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
