## [:< ##

package AMOS7::Vault;    ####################################################

## personal secret vault : logins, notes, contacts -- encrypted at rest, one
## file per entry version, recoverable with plain perl + CryptX
## [ or Crypt::Argon2 ] and nothing else from protocol-7.
##
## format : data/md/design/VAULT-FORMAT.md [ keep both in step ]
##
## standard primitives only [ argon2id, hkdf-sha256, twofish-gcm inside
## chacha20-poly1305, rfc 4648 base32 ] -- the blobs travel to usb keys and a
## public repo, so a recovery must never depend on a protocol-7 specific
## cipher. two ciphers so that a break of either one alone reveals nothing.
##
## NEVER pass a secret value to warn / die / a log line. errors name the file
## or the entry id, never the content.

use v5.24;
use utf8;
use strict;
use English;
use warnings;

##[ global constants ]##
use constant TRUE  => 5;    ##  TRUE.  ##
use constant FALSE => 0;    ##  false  ##

use Exporter;
use base qw| Exporter |;
use vars qw| @EXPORT_OK $VERSION |;

our $VERSION = qw| AMOS7::Vault-VERSION.0000001 |;

@EXPORT_OK = qw|
    vault_init
    vault_open
    vault_unlock
    vault_rewrap
    vault_wraps
    entry_save
    entry_load
    entry_versions
    entries_latest
    vault_verify
    gen_password
    recovery_code_new
    recovery_code_normalize
    type_fields
    secret_field
    ntime_now
    ntime_b32
    ntime_b32_to_unix
    version_to_unix
    |;

##[ DEPENDENCIES ]############################################################

use Fcntl qw| O_RDONLY O_WRONLY O_CREAT O_EXCL |;
use IO::Handle;
use JSON::PP;
use Time::HiRes qw| time |;
use AMOS7::NTIME;
use Crypt::Misc                      qw| encode_b32r decode_b32r |;
use Crypt::KeyDerivation             qw| hkdf |;
use Crypt::AuthEnc::ChaCha20Poly1305 qw|
    chacha20poly1305_encrypt_authenticate
    chacha20poly1305_decrypt_verify
    |;
use Crypt::AuthEnc::GCM qw| gcm_encrypt_authenticate gcm_decrypt_verify |;

##[ FORMAT CONSTANTS ]########################################################

our $KEY_MAGIC       = qw| p7-vault-key |;
our $ENTRY_MAGIC     = qw| p7-vault-entry |;
our $KEY_BIN_MAGIC   = qw| P7VK |;  ## first bytes of the binary files ##
our $ENTRY_BIN_MAGIC = qw| P7VE |;
our $FORMAT          = 1;           ## twofish-gcm inside chacha20-poly1305 ##
## plaintext padded to a multiple [ hides length ] ##
our $PAD_BLOCK = 512;

## default argon2id cost : 3 passes over 256 MiB -- about a second here,
## affordable on pri [ 11 GB ] and the laptops. stored in the key file, so a
## later change never breaks an existing vault
our %KDF_DEFAULT = ( t => 3, m => 262144, p => 1 );

## record types and their fields, in prompt order. secret fields are never
## shown unmasked unless asked for
our %TYPES = (
    login   => [qw| title url username password totp notes |],
    note    => [qw| title body |],
    contact => [qw| title name phone email address notes |],
);
our %SECRET = map { $ARG => TRUE } qw| password totp body |;

our $JSON = JSON::PP->new->utf8->canonical;

##[ SMALL HELPERS ]###########################################################

sub type_fields {
    my $type = shift // '';
    return exists $TYPES{$type} ? @{ $TYPES{$type} } : ();
}

sub secret_field { return $SECRET{ shift // '' } ? TRUE : FALSE }

sub _b32 {
    my $out = encode_b32r(shift);
    $out =~ s|=+$||;
    return $out;
}

sub _unb32 {
    my $in = shift // '';
    return undef if $in !~ m|^[A-Z2-7]+$|;
    return decode_b32r($in);
}

##[ NETWORK TIME ]############################################################

## AMOS7::NTIME [ standalone network time ]. file names carry whole ntime
## units in decimal [ base32 does not sort in time order ], record fields the
## base32 form, like the logs [ bin/ntime decodes both ]
sub ntime_now { return AMOS7::NTIME::unix_to_ntime( time, 0 ) }

sub ntime_b32 { return AMOS7::NTIME::ntime_to_b32(shift) }

sub ntime_b32_to_unix { return AMOS7::NTIME::b32_to_unix(shift) }

sub version_to_unix {
    my $version = shift // q{};
    return $version =~ m|^(\d{14})\.|
        ? AMOS7::NTIME::ntime_to_unix( $1 + 0 )
        : undef;
}

sub _random_bytes {
    my $len = shift;
    my $buf = '';

    ## kernel entropy first [ see the 2026-10-06 prng finding ] ##
    if ( open( my $fh, '<:raw', qw| /dev/urandom | ) ) {
        read( $fh, $buf, $len );
        close $fh;
    }
    if ( length $buf != $len ) {
        require Crypt::PRNG;
        $buf = Crypt::PRNG::random_bytes($len);
    }
    die "vault : no random source\n" if length $buf != $len;
    return $buf;
}

## crash safety : content goes to a '.tmp.' name
## [ never matches an entry or the key file ], is synced to disk, THEN gets
## its final name, and the directory is synced so the name survives a power
## cut or a pulled usb key
## [ xfs : rename without fsync can leave a zero length file ]

sub _write_synced_tmp {
    my ( $path, $content ) = @ARG;

    my $tmp = sprintf qw| %s.tmp.%s |, $path, _b32( _random_bytes(5) );
    sysopen( my $fh, $tmp, O_WRONLY | O_CREAT | O_EXCL, 0600 )
        or return ( undef, "cannot create $tmp : $OS_ERROR" );
    binmode $fh;
    my $ok = print {$fh} $content;
    $ok &&= $fh->flush;
    $ok &&= $fh->sync;
    $ok &&= close $fh;

    if ( not $ok ) {
        my $err = "$OS_ERROR";
        unlink $tmp;
        return ( undef, "cannot write $tmp : $err" );
    }
    return ( $tmp, undef );
}

sub _sync_dir {
    my $dir = shift;
    sysopen( my $dh, $dir, O_RDONLY ) or return FALSE;
    my $ok = eval { $dh->sync } ? TRUE : FALSE;
    close $dh;
    return $ok;
}

sub _dir_of { ( my $dir = shift ) =~ s|/[^/]+$||; return $dir }

## a new file that must not exist yet [ entry versions are never replaced ]
sub _write_new_file {
    my ( $path, $content ) = @ARG;

    return ( FALSE, "$path exists" ) if -e $path;
    my ( $tmp, $err ) = _write_synced_tmp( $path, $content );
    return ( FALSE, $err ) if not defined $tmp;

    ## link fails if the name exists [ exclusive ] ; filesystems without hard
    ## links [ vfat usb keys ] fall back to the checked rename
    if ( link $tmp, $path ) {
        unlink $tmp;
    } elsif ( -e $path or not rename $tmp, $path ) {
        my $link_err = "$OS_ERROR";
        unlink $tmp;
        return ( FALSE, "cannot create $path : $link_err" );
    }
    _sync_dir( _dir_of($path) );
    return ( TRUE, undef );
}

sub _replace_file {
    my ( $path, $content ) = @ARG;

    my ( $tmp, $err ) = _write_synced_tmp( $path, $content );
    return ( FALSE, $err ) if not defined $tmp;

    if ( not rename $tmp, $path ) {
        my $rename_err = "$OS_ERROR";
        unlink $tmp;
        return ( FALSE, "cannot replace $path : $rename_err" );
    }
    _sync_dir( _dir_of($path) );
    return ( TRUE, undef );
}

sub _read_file {
    my $path = shift;
    open( my $fh, '<:raw', $path ) or return undef;
    local $INPUT_RECORD_SEPARATOR;
    my $content = <$fh>;
    close $fh;
    return $content;
}

##[ KEY DERIVATION ]##########################################################

## argon2id, two interchangeable implementations : CryptX >= 0.088 has it
## built in, older CryptX [ debian bookworm : 0.077 ] needs Crypt::Argon2
## [ libcrypt-argon2-perl ]. both are rfc 9106 and give identical output
sub _argon2id {
    my ( $secret, $salt, $kdf ) = @ARG;

    require Crypt::KeyDerivation;
    if ( defined &Crypt::KeyDerivation::argon2_pbkdf ) {
        return Crypt::KeyDerivation::argon2_pbkdf( qw| argon2id |,
            $secret, $salt, $kdf->{'t'}, $kdf->{'m'}, $kdf->{'p'}, 32 );
    }

    if ( eval { require Crypt::Argon2; 1 } ) {
        return Crypt::Argon2::argon2id_raw( $secret, $salt, $kdf->{'t'},
            $kdf->{'m'} . 'k',
            $kdf->{'p'}, 32 );
    }

    die "vault : no argon2id available -- install CryptX >= 0.088 "
        . "or Crypt::Argon2 [ debian : libcrypt-argon2-perl ]\n";
}

sub _kdf_line {
    my $kdf = shift;
    return sprintf q{argon2id %d %d %d}, @{$kdf}{qw| t m p |};
}

##[ CASCADE ]#################################################################

## two ciphers, independent keys from one root : twofish-gcm  inside,
## chacha20-poly1305 outside. each layer authenticates on its own, so a break
## of either cipher alone reveals nothing and changes nothing.  the key file
## is cascaded the same way -- with only the entries cascaded, breaking
## chacha20 on vault.key would hand over the vault key and with it both entry
## layers
sub _layer_keys {
    my ( $root, $salt, $label ) = @ARG;
    my $twofish
        = hkdf( $root, $salt, qw| SHA256 |, 44, "$label " . "twofish-gcm" );
    my $chacha
        = hkdf( $root, $salt, qw| SHA256 |, 32, "$label chacha20-poly1305" );
    return ( substr( $twofish, 0, 32 ), substr( $twofish, 32, 12 ), $chacha );
}

## returns ( nonce, ciphertext, tag ) of the outer layer
sub _cascade_encrypt {
    my ( $root, $salt, $label, $ad, $plaintext ) = @ARG;

    my ( $tf_key, $tf_nonce, $cc_key ) = _layer_keys( $root, $salt, $label );
    my ( $inner, $inner_tag )
        = gcm_encrypt_authenticate( qw| Twofish |, $tf_key, $tf_nonce, $ad,
        $plaintext );

    my $nonce = _random_bytes(12);
    my ( $ct, $tag )
        = chacha20poly1305_encrypt_authenticate( $cc_key, $nonce, $ad,
        $inner . $inner_tag );
    return ( $nonce, $ct, $tag );
}

## returns the plaintext, or undef when either layer fails
sub _cascade_decrypt {
    my ( $root, $salt, $label, $ad, $nonce, $ct, $tag ) = @ARG;

    my ( $tf_key, $tf_nonce, $cc_key ) = _layer_keys( $root, $salt, $label );
    my $inner
        = chacha20poly1305_decrypt_verify( $cc_key, $nonce, $ad, $ct, $tag )
        // return undef;
    return undef if length $inner < 16;

    my $inner_tag = substr $inner, -16, 16, '';
    return gcm_decrypt_verify( qw| Twofish |, $tf_key, $tf_nonce, $ad,
        $inner, $inner_tag );
}

sub _wrap_ad {
    my ( $vault, $wrap_name ) = @ARG;
    return join ' ', $KEY_MAGIC, $FORMAT, $vault->{'id'},
        _kdf_line( $vault->{'kdf'} ), $wrap_name;
}

##[ RECOVERY CODE ]###########################################################

## 32 base32 chars [ 160 bit ], shown in groups of four for paper storage
sub recovery_code_new {
    my $code = substr( _b32( _random_bytes(20) ), 0, 32 );
    return join qw| - |, $code =~ m|(.{4})|g;
}

sub recovery_code_normalize {
    my $code = uc( shift // '' );
    $code =~ tr|018|OLB|;      ## common misreadings of the paper copy ##
    $code =~ s|[^A-Z2-7]||g;
    return $code;
}

##[ KEY FILE ]################################################################

## every stored file is one base32 block [ rfc 4648, no padding ] in the frame
## of bin/Protocol-7's inline subroutines : a '.:[ title ]:.' line, ':' lines
## around, payload lines ': ' + 76 chars [ 78 columns ], a short last line
## centred with '0' -- outside the base32 alphabet, so a reader drops every
## '0' \ '1' and joins the ': ' lines. binary fields inside, nothing to align.
## each write is checked to decode back
our $B32_LINE = 76;

sub _b32_file_text {
    my ( $bin, $title ) = @ARG;

    my $b32  = _b32($bin);
    my @rows = $b32 =~ m|(.{1,$B32_LINE})|g;
    my $pad  = $B32_LINE - length $rows[-1];
    $rows[-1]
        = ( '0' x int( $pad / 2 ) )
        . $rows[-1]
        . ( '0' x ( $pad - int( $pad / 2 ) ) );

    my $text = join '', ".:[ $title ]:.\n", ":\n", map( {": $ARG\n"} @rows ),
        ":\n";
    die "vault : base32 round trip failed\n"
        if ( _b32_text_decode($text) // '' ) ne $bin;
    return $text;
}

sub _b32_text_decode {
    my $text = shift // return undef;
    my $b32  = join '', map { substr $ARG, 2 } grep {m|^: [0-9A-Z]+$|}
        split m|\n|, $text;
    $b32 =~ tr|01||d;
    return _unb32($b32);
}

sub _b32_file_read { return _b32_text_decode( _read_file(shift) ) }

sub _key_path { return $ARG[0] . '/vault.key.B32' }

## key file : 'P7VK' format:C vault-id:a10 created-ntime:Q> kdf:C
## [ 1 = argon2id ] t:N m-KiB:N p:N wraps:C , then per wrap : name-length:C
## name salt:a16 nonce:a12 tag:a16 ciphertext-length:n ciphertext
## [ big endian ]
sub _key_file_text {
    my $vault = shift;
    my @names = sort keys %{ $vault->{'wraps'} };

    my $bin = pack(
        q{a4 C a10 Q> C N N N C},
        $KEY_BIN_MAGIC,      $FORMAT, _unb32( $vault->{'id'} ),
        $vault->{'created'}, 1,
        @{ $vault->{'kdf'} }{qw| t m p |},
        scalar @names
    );
    foreach my $name (@names) {
        $bin .= pack( q{C/a a16 a12 a16 n/a},
            $name, @{ $vault->{'wraps'}{$name} }{qw| salt nonce tag ct |} );
    }
    return _b32_file_text( $bin, 'p7-vault key' );
}

sub _key_file_parse {
    my ( $bin, $dir ) = @ARG;

    return ( undef, 'not a vault key file' )
        if length $bin < 37
        or substr( $bin, 0, 4 ) ne $KEY_BIN_MAGIC;

    my ( undef, $format, $vid, $created, $kdf_id, $t, $m, $p, $count, $rest )
        = unpack( q{a4 C a10 Q> C N N N C a*}, $bin );
    return ( undef,
              "vault format $format not supported "
            . "[ this p7-vault : $FORMAT ]" )
        if $format != $FORMAT;
    return ( undef, "unknown kdf $kdf_id" ) if $kdf_id != 1;

    my %wraps;
    foreach ( 1 .. $count ) {
        return ( undef, 'key file truncated' ) if length $rest < 1;
        my ( $name, $salt, $nonce, $tag, $ct, $tail )
            = unpack( q{C/a a16 a12 a16 n/a a*}, $rest );
        return ( undef, 'key file truncated' )
            if not defined $ct
            or length $salt != 16
            or length $nonce != 12
            or length $tag != 16;
        $wraps{$name}
            = { salt => $salt, nonce => $nonce, tag => $tag, ct => $ct };
        $rest = $tail // '';
    }

    return (
        {   dir     => $dir,
            id      => _b32($vid),
            created => $created,
            kdf     => { t => $t, m => $m, p => $p },
            wraps   => \%wraps,
        },
        undef
    );
}

sub _wrap_key {
    my ( $vault, $wrap_name, $secret ) = @ARG;

    my $salt = _random_bytes(16);
    my $root = _argon2id( $secret, $salt, $vault->{'kdf'} );
    my ( $nonce, $ct, $tag ) = _cascade_encrypt(
        $root, $salt,
        "$KEY_MAGIC $FORMAT wrap",
        _wrap_ad( $vault, $wrap_name ),
        $vault->{'key'}
    );

    $vault->{'wraps'}{$wrap_name}
        = { salt => $salt, nonce => $nonce, ct => $ct, tag => $tag };
    return TRUE;
}

## create a new vault in $dir. $recovery may be undef [ no recovery wrap ].
## returns the unlocked vault handle, dies on any failure
sub vault_init {
    my ( $dir, $passphrase, $recovery, %kdf ) = @ARG;

    die "vault : empty passphrase\n"
        if not defined $passphrase or not length $passphrase;
    die "vault : $dir already holds a vault\n" if -e _key_path($dir);

    foreach my $sub_dir ( $dir, "$dir/entries" ) {
        next if -d $sub_dir;
        mkdir $sub_dir, 0700 or die "vault : cannot create $sub_dir\n";
    }
    chmod 0700, $dir;

    my $vault = {
        dir     => $dir,
        id      => _b32( _random_bytes(10) ),
        created => int( ntime_now() ),
        kdf     => { %KDF_DEFAULT, %kdf },
        key     => _random_bytes(32),
        wraps   => {},
    };

    _wrap_key( $vault, qw| passphrase |, $passphrase );
    _wrap_key( $vault, qw| recovery |,   recovery_code_normalize($recovery) )
        if defined $recovery and length $recovery;

    my ( $ok, $err )
        = _write_new_file( _key_path($dir), _key_file_text($vault) );
    die "vault : $err\n" if not $ok;

    return $vault;
}

## read the key file [ no secret needed ]. returns a locked handle or undef
## with an error string
sub vault_open {
    my $dir = shift;

    return ( undef, "no vault in $dir" ) if not -e _key_path($dir);
    my $bin = _b32_file_read( _key_path($dir) )
        // return ( undef, 'key file is not base32' );

    return _key_file_parse( $bin, $dir );
}

sub vault_wraps { return sort keys %{ shift->{'wraps'} } }

## unlock with the secret of one wrap [ 'passphrase' or 'recovery' ]
sub vault_unlock {
    my ( $vault, $secret, $wrap_name ) = @ARG;
    $wrap_name //= qw| passphrase |;

    my $wrap = $vault->{'wraps'}{$wrap_name} // return FALSE;
    $secret = recovery_code_normalize($secret)
        if $wrap_name eq qw| recovery |;

    my @raw = @{$wrap}{qw| salt nonce ct tag |};
    return FALSE if grep { not defined } @raw;

    my $root = _argon2id( $secret, $raw[0], $vault->{'kdf'} );
    my $key  = _cascade_decrypt(
        $root, $raw[0],
        "$KEY_MAGIC $FORMAT wrap",
        _wrap_ad( $vault, $wrap_name ),
        @raw[ 1 .. 3 ]
    );

    return FALSE if not defined $key or length $key != 32;
    $vault->{'key'} = $key;
    return TRUE;
}

## [re]wrap the unlocked key under a new secret
## [ passphrase change, new recovery code ]. $secret undef removes that wrap
sub vault_rewrap {
    my ( $vault, $wrap_name, $secret ) = @ARG;

    die "vault : locked\n" if not defined $vault->{'key'};

    my %before = %{ $vault->{'wraps'} };
    if ( defined $secret ) {
        $secret = recovery_code_normalize($secret)
            if $wrap_name eq qw| recovery |;
        _wrap_key( $vault, $wrap_name, $secret );
    } else {
        delete $vault->{'wraps'}{$wrap_name};
    }

    die "vault : refusing to remove the last wrap\n"
        if not keys %{ $vault->{'wraps'} };

    my ( $ok, $err )
        = _replace_file( _key_path( $vault->{'dir'} ),
        _key_file_text($vault) );
    if ( not $ok ) {
        $vault->{'wraps'} = \%before;
        die "vault : $err\n";
    }
    return TRUE;
}

##[ ENTRIES ]#################################################################

sub _entry_ad {
    my ( $vault, $id, $version ) = @ARG;
    return join ' ', $ENTRY_MAGIC, $FORMAT, $vault->{'id'}, $id, $version;
}

## version names sort in time order : <decimal ntime, 14 digits>.<8 b32 chars>
## -- the random tail keeps two devices editing offline from colliding. the
## stamp is kept above the entry's current latest, so two saves in one
## millisecond [ or a clock step back ] still order as written
sub _new_version {
    my ( $vault, $id ) = @ARG;

    my $stamp  = int( ntime_now() );
    my $latest = ( entry_versions($vault)->{$id} // [] )->[-1];
    if ( defined $latest and $latest =~ m|^(\d{14})\.| and $1 >= $stamp ) {
        $stamp = $1 + 1;
    }

    return sprintf qw| %014d.%s |, $stamp,
        substr( _b32( _random_bytes(5) ), 0, 8 );
}

## write a new version of entry $id [ undef = new entry ]. returns the id
sub entry_save {
    my ( $vault, $id, $record ) = @ARG;

    die "vault : locked\n"               if not defined $vault->{'key'};
    die "vault : record is not a hash\n" if ref $record ne qw| HASH |;

    $id //= _b32( _random_bytes(10) );
    die "vault : invalid entry id\n" if $id !~ m|^[A-Z2-7]{16}$|;

    my %plain     = ( %{$record}, updated => ntime_b32( ntime_now() ) );
    my $plaintext = $JSON->encode( \%plain ) . qq|\n|;
    my $pad       = $PAD_BLOCK - ( length($plaintext) % $PAD_BLOCK );
    $plaintext .= ' ' x $pad;

    my $version = _new_version( $vault, $id );
    my $salt    = _random_bytes(16);
    my ( $nonce, $ct, $tag ) = _cascade_encrypt(
        $vault->{'key'}, $salt,
        "$ENTRY_MAGIC $FORMAT",
        _entry_ad( $vault, $id, $version ), $plaintext
    );

    my ( $stamp, $tail ) = split m|\.|, $version;
    my $bin = pack(
        q{a4 C a10 a10 Q> a5 a16 a12 a16},
        $ENTRY_BIN_MAGIC, $FORMAT, _unb32( $vault->{'id'} ),
        _unb32($id), $stamp, _unb32($tail), $salt, $nonce, $tag
    ) . $ct;

    my ( $ok, $err ) = _write_new_file(
        _entry_path( $vault, $id, $version ),
        _b32_file_text( $bin, 'p7-vault entry' )
    );
    die "vault : $err\n" if not $ok;

    return $id;
}

sub _entry_path {
    my ( $vault, $id, $version ) = @ARG;
    return sprintf qw| %s/entries/%s.%s.vlt.B32 |, $vault->{'dir'}, $id,
        $version;
}

## entry file : 'P7VE' format:C vault-id:a10 entry-id:a10 version-ntime:Q>
## version-tail:a5 salt:a16 nonce:a12 tag:a16 , the ciphertext to the end.
## returns a hash, or an error string
sub _entry_parse {
    my $bin = shift;

    return 'not a vault entry'
        if length $bin < 82
        or substr( $bin, 0, 4 ) ne $ENTRY_BIN_MAGIC;
    my ( undef, $format, $vid, $id, $stamp, $tail, $salt, $nonce, $tag, $ct )
        = unpack( q{a4 C a10 a10 Q> a5 a16 a12 a16 a*}, $bin );
    return "entry format $format not supported" if $format != $FORMAT;

    return {
        vault   => _b32($vid),
        id      => _b32($id),
        version => sprintf( qw| %014d.%s |, $stamp, _b32($tail) ),
        salt    => $salt,
        nonce   => $nonce,
        tag     => $tag,
        ct      => $ct,
    };
}

## { id => [ versions, oldest first ] } from the file names alone
sub entry_versions {
    my $vault = shift;
    my %versions;

    opendir( my $dh, "$vault->{'dir'}/entries" ) or return {};
    foreach my $file ( readdir $dh ) {
        next
            if $file !~ m|^([A-Z2-7]{16})\.(\d{14}\.[A-Z2-7]{8})\.vlt\.B32$|;
        push @{ $versions{$1} }, $2;
    }
    closedir $dh;

    @{$ARG} = sort @{$ARG} foreach values %versions;
    return \%versions;
}

## decrypt one version [ latest when undef ]. returns ( record, undef ) or (
## undef, error )
sub entry_load {
    my ( $vault, $id, $version ) = @ARG;

    return ( undef, 'locked' ) if not defined $vault->{'key'};

    if ( not defined $version ) {
        my $all = entry_versions($vault)->{$id} // [];
        $version = $all->[-1] // return ( undef, "no entry $id" );
    }

    my $file = _entry_path( $vault, $id, $version );
    return ( undef, "cannot read $file" ) if not -r $file;
    my $bin = _b32_file_read($file)
        // return ( undef, "$id.$version : not base32" );

    my $entry = _entry_parse($bin);
    return ( undef, "$id.$version : $entry" ) if not ref $entry;

    ## the header must name the same vault, entry and version as the file name
    ## -- and the ad binds all three, so a renamed or swapped blob fails the
    ## tag below even if this check were skipped
    return ( undef, "$id.$version : header does not match file name" )
        if $entry->{'vault'} ne $vault->{'id'}
        or $entry->{'id'} ne $id
        or $entry->{'version'} ne $version;

    my ( $salt, $nonce, $ct, $tag ) = @{$entry}{qw| salt nonce ct tag |};

    my $plaintext = _cascade_decrypt(
        $vault->{'key'}, $salt,
        "$ENTRY_MAGIC $FORMAT",
        _entry_ad( $vault, $id, $version ),
        $nonce, $ct, $tag
    );
    return ( undef, "$id.$version : authentication failed" )
        if not defined $plaintext;

    my $record = eval { $JSON->decode($plaintext) };
    return ( undef, "$id.$version : bad payload" )
        if ref $record ne qw| HASH |;

    return ( $record, undef );
}

## latest READABLE version of every entry : [ { id, version, record } .. ],
## deleted entries left out unless $with_deleted. a newest version that does
## not decrypt [ truncated copy, damaged medium ] is reported in the second
## value and the next older one stands in -- the entry never disappears
sub entries_latest {
    my ( $vault, $with_deleted ) = @ARG;

    my $versions = entry_versions($vault);
    my ( @list, @errors );

    foreach my $id ( sort keys %{$versions} ) {
        my ( $record, $version );
        foreach my $candidate ( reverse @{ $versions->{$id} } ) {
            my ( $loaded, $err ) = entry_load( $vault, $id, $candidate );
            if ( not defined $loaded ) {
                push @errors, $err;
                next;
            }
            ( $record, $version ) = ( $loaded, $candidate );
            last;
        }
        next if not defined $record;
        next if $record->{'deleted'} and not $with_deleted;
        push @list, { id => $id, version => $version, record => $record };
    }

    @list = sort {
        lc( $a->{'record'}{'title'}     // '' ) cmp
            lc( $b->{'record'}{'title'} // '' )
    } @list;

    return ( \@list, \@errors );
}

## decrypt every version of every entry. returns ( count ok, [ errors ] )
sub vault_verify {
    my $vault    = shift;
    my $versions = entry_versions($vault);
    my ( $ok, @errors ) = (0);

    foreach my $id ( sort keys %{$versions} ) {
        foreach my $version ( @{ $versions->{$id} } ) {
            my ( $record, $err ) = entry_load( $vault, $id, $version );
            defined $record ? $ok++ : push @errors, $err;
        }
    }
    return ( $ok, \@errors );
}

##[ PASSWORD GENERATOR ]######################################################

## uniform draw by rejection sampling. $classes : any of 'a' [ lower ], 'A'
## [ upper ], '9' [ digits ], '#' [ symbols ] -- default all four
sub gen_password {
    my $length  = shift // 24;
    my $classes = shift // q{aA9#};

    my %set = (
        'a' => join( '', 'a' .. 'z' ),
        'A' => join( '', 'A' .. 'Z' ),
        '9' => join( '', 0 .. 9 ),
        '#' => q{-_.:,;!?+*=/%@#~^()[]{}},
    );
    my @used = grep { index( $classes, $ARG ) != -1 } sort keys %set;
    @used = sort keys %set if not @used;
    my @chars = split m||, join '', map { $set{$ARG} } @used;

    ## retry until every requested class occurs [ sites demand it ]
    while (TRUE) {
        my $password = '';
        while ( length $password < $length ) {
            my $byte = ord _random_bytes(1);
            next if $byte >= 256 - ( 256 % @chars );
            $password .= $chars[ $byte % @chars ];
        }
        my $complete = TRUE;
        foreach my $class (@used) {
            my $pattern = quotemeta $set{$class};
            $complete = FALSE if $password !~ m|[$pattern]|;
        }
        return $password if $complete or $length < @used;
    }
}

1;

#,,..,.,,,.,,,,..,..,,,.,,.,.,.,.,,..,,.,,.,.,..,,...,...,.,,,.,.,,..,,,,,..,,
#WC5ITH35PVTWU4GC3MZFCYGZKRSPXK5XZAGLIMRQTV6CAZJNFHALH5NZXJW4TWZ33WNVHTXCWV3B2
#\\\|WFZUA5IPJ5DIFTBODBE2VYUBYJPKN32RBFGCHE2BCBWAQS4WM35 \ / AMOS7 \ YOURUM ::
#\[7]5IXHXXEIDPBYAP7NJK54ULMBYLCLAY3L3VM57UIAUPNNHJ6CNAAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
