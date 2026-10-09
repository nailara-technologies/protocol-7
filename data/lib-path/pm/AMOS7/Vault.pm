## [:< ##

package AMOS7::Vault;    ####################################################

## personal secret vault : logins, notes, contacts -- encrypted at rest, one
## file per entry version, recoverable with plain perl + CryptX
## [ or Crypt::Argon2 ] and nothing else from protocol-7.
##
## format : data/md/design/VAULT-FORMAT.md [ keep both in step ]
##
## standard primitives only [ argon2id, hkdf-blake2b-512, twofish-gcm inside
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
    vault_exists
    vault_unlock
    vault_rewrap
    vault_wraps
    entry_save
    entry_load
    entry_versions
    entries_latest
    vault_verify
    archive_write
    archive_open
    archive_records
    archive_restore
    file_secret
    git_blob_id
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
        = hkdf( $root, $salt, qw| BLAKE2b_512 |, 44,
        "$label " . "twofish-gcm" );
    my $chacha = hkdf( $root, $salt, qw| BLAKE2b_512 |,
        32, "$label chacha20-poly1305" );
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
## HARMONY : values people see [ recovery code, generated passwords ] or that
## define topology [ vault \ entry ids, version tails -- every file name ] are
## drawn again until AMOS7::Assert::Truth::is_true accepts them, as
## base.gen_id and crypt.C25519.gen_keys do. the module is loaded only to
## GENERATE -- unlocking and recovery never need it, so a standalone copy
## without it still opens every vault [ and generates unfiltered ]
our $HARMONY_TRIES = 4096;

sub _truth_loaded {
    state $loaded = eval { require AMOS7::Assert::Truth; 1 } ? TRUE : FALSE;
    return $loaded;
}

## draw with $generator until every form
## [ $forms->( value ) , default the value itself ] is harmonic
sub _harmonic {
    my ( $generator, $forms ) = @ARG;
    $forms //= sub { return @ARG };

    return $generator->() if not _truth_loaded();
    foreach ( 1 .. $HARMONY_TRIES ) {
        my $value = $generator->();
        return $value
            if not grep { not AMOS7::Assert::Truth::is_true($ARG) }
            $forms->($value);
    }
    die "vault : no harmonic value in $HARMONY_TRIES draws\n";
}

## the grouped form is what the owner reads and writes down, the plain form
## goes into argon2id : both harmonic
sub recovery_code_new {
    return _harmonic(
        sub {
            my $code = substr( _b32( _random_bytes(20) ), 0, 32 );
            return join qw| - |, $code =~ m|(.{4})|g;
        },
        sub { return ( $ARG[0], recovery_code_normalize( $ARG[0] ) ) }
    );
}

sub _new_id {
    return _harmonic( sub { _b32( _random_bytes(10) ) } );
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

## true when $dir holds a vault [ its key file ]
sub vault_exists { return -e _key_path(shift) ? TRUE : FALSE }

## key file : 'P7VK' format:C vault-id:a10 created-ntime:Q> kdf:C
## [ 1 = argon2id ] t:N m-KiB:N p:N wraps:C , then per wrap : name-length:C
## name salt:a16 nonce:a12 tag:a16 ciphertext-length:n ciphertext
## [ big endian ]
sub _key_file_text {
    return _b32_file_text( _key_file_bin(shift), 'p7-vault key' );
}

sub _key_file_bin {
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
    return $bin;
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
        id      => _new_id(),
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

    ## refusing must leave the handle as it was -- a later write from it would
    ## otherwise drop the wrap from the key file without a word
    if ( not keys %{ $vault->{'wraps'} } ) {
        $vault->{'wraps'} = \%before;
        die "vault : refusing to remove the last wrap\n";
    }

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
        _harmonic( sub { substr( _b32( _random_bytes(5) ), 0, 8 ) } );
}

## write a new version of entry $id [ undef = new entry ]. returns the id
sub entry_save {
    my ( $vault, $id, $record ) = @ARG;

    die "vault : locked\n"               if not defined $vault->{'key'};
    die "vault : record is not a hash\n" if ref $record ne qw| HASH |;

    $id //= _new_id();
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

##[ ARCHIVE ]#################################################################

## one file for untrusted copies [ the public DATA repo ] : the vault
## directory itself shows how many entries exist and when each was edited
## [ file names ] -- an archive shows neither. layout :
##
## 'P7VA' format:C key-file-length:N key-file [ the binary key file, in the
## clear : the passphrase alone must open the archive ] salt:a16 nonce:a12
## tag:a16 , the cascade ciphertext to the end
##
## payload [ cascade, root = vault key, label 'p7-vault-archive 1' ] : 'P7VP'
## count:N , per record : name-length:C name data-length:N data
## [ the entry's binary content ] , zero filler up to the size class
##
## size classes : 13312 bytes, times 3 while the payload does not fit
## [ the keys archive's classes ] -- a few entries more or less do not show

our $ARCHIVE_MAGIC = qw| P7VA |;
our $PAYLOAD_MAGIC = qw| P7VP |;
our $ARCHIVE_CLASS = 13312;
our $ENTRY_FILE_RE = qr{\A[A-Z2-7]{16}\.\d{14}\.[A-Z2-7]{8}\.vlt\.B32\z};

sub _archive_ad { return "p7-vault-archive $FORMAT " . shift->{'id'} }

## passphrase + key file : the 'passphrase-file' wrap's argon2id input is the
## file's length [ 4 bytes, big endian ], its bytes, then the passphrase bytes
## -- no hash before argon2id, it takes any length. any file can be the key
## file -- one version of a file in a public repository adds about 17 bits
## [ ~106000 versions in protocol-7's history ], a cost factor of ~100000
## argon2id runs on every passphrase guess
sub file_secret {
    my ( $passphrase, $path ) = @ARG;
    open( my $fh, '<:raw', $path ) or die "vault : cannot read $path\n";
    my $content = do { local $INPUT_RECORD_SEPARATOR; <$fh> };
    close $fh;
    return pack( q{N/a*}, $content ) . $passphrase;
}

## the git blob id of a file
## [ sha-1 of 'blob <length>\0<content>', git's own definition ], in base32 :
## names one version of one file in any git history, for the owner's notes.
## identification only, never key material
sub git_blob_id {
    my $path = shift;
    open( my $fh, '<:raw', $path ) or return undef;
    my $content = do { local $INPUT_RECORD_SEPARATOR; <$fh> };
    close $fh;
    require Crypt::Digest::SHA1;
    return _b32(
        Crypt::Digest::SHA1::sha1(
            sprintf( "blob %d\0", length $content ) . $content
        )
    );
}

## the key file an archive carries : by default ONLY the recovery wrap
## [ 160 random bits -- a public copy cannot be brute forced through it ].
## $opt : file_secret [ adds a 'passphrase-file' wrap ], keep_passphrase
## [ copies the plain 'passphrase' wrap -- weak passphrases stay exposed ]
sub _archive_key_bin {
    my ( $vault, $opt ) = @ARG;

    my %copy = ( %{$vault}, wraps => {} );
    foreach my $name (qw| recovery |) {
        $copy{'wraps'}{$name} = $vault->{'wraps'}{$name}
            if exists $vault->{'wraps'}{$name};
    }
    $copy{'wraps'}{'passphrase'} = $vault->{'wraps'}{'passphrase'}
        if $opt->{'keep_passphrase'}
        and exists $vault->{'wraps'}{'passphrase'};
    _wrap_key( \%copy, qw| passphrase-file |, $opt->{'file_secret'} )
        if defined $opt->{'file_secret'};

    die "vault : the archive would have no way to open it [ no recovery code "
        . "in this vault : give a key file or keep the passphrase ]\n"
        if not keys %{ $copy{'wraps'} };
    return ( _key_file_bin( \%copy ), [ sort keys %{ $copy{'wraps'} } ] );
}

## every version of every entry : [ [ file name, binary content ] .. ]
sub _archive_records {
    my $vault    = shift;
    my $versions = entry_versions($vault);
    my @records;
    foreach my $id ( sort keys %{$versions} ) {
        foreach my $version ( @{ $versions->{$id} } ) {
            my $path = _entry_path( $vault, $id, $version );
            my $bin  = _b32_file_read($path)
                // die "vault : cannot read $path\n";
            push @records, [ ( split m|/|, $path )[-1], $bin ];
        }
    }
    return \@records;
}

## write the archive of an unlocked vault to $path, read it back and compare
## every record. returns ( record count, file size )
sub archive_write {
    my ( $vault, $path, $opt ) = @ARG;
    $opt //= {};

    die "vault : locked\n" if not defined $vault->{'key'};
    my $records = _archive_records($vault);

    my $payload = pack( q{a4 N}, $PAYLOAD_MAGIC, scalar @{$records} );
    $payload .= pack( q{C/a N/a}, @{$ARG} ) foreach @{$records};
    my $class = $ARCHIVE_CLASS;
    $class *= 3 while $class < length $payload;
    $payload .= "\0" x ( $class - length $payload );

    my ( $key_bin, $wraps ) = _archive_key_bin( $vault, $opt );
    my $salt = _random_bytes(16);
    my ( $nonce, $ct, $tag )
        = _cascade_encrypt( $vault->{'key'}, $salt,
        "p7-vault-archive " . "$FORMAT",
        _archive_ad($vault), $payload );

    my $bin = pack( q{a4 C N/a a16 a12 a16},
        $ARCHIVE_MAGIC, $FORMAT, $key_bin, $salt, $nonce, $tag ) . $ct;
    my ( $ok, $err )
        = _replace_file( $path, _b32_file_text( $bin, 'p7-vault archive' ) );
    die "vault : $err\n" if not $ok;

    ## a backup nobody checked is a hope : read it back, compare all ##
    my ( $archive, $open_err ) = archive_open($path);
    die "vault : archive does not read back : $open_err\n"
        if not defined $archive;

    ## the new passphrase-file wrap must open it, before anyone relies on ##
    ## it                                                                 ##
    die "vault : the archive's passphrase-file wrap does not open\n"
        if defined $opt->{'file_secret'}
        and not vault_unlock( $archive->{'vault'}, $opt->{'file_secret'},
        qw| passphrase-file | );
    $archive->{'vault'}{'key'} = $vault->{'key'};
    my ( $back, $back_err ) = archive_records($archive);
    die "vault : archive does not decrypt back : $back_err\n"
        if not defined $back;
    die "vault : archive content differs from the vault\n"
        if @{$back} != @{$records}
        or grep {
               $back->[$ARG][0] ne $records->[$ARG][0]
            or $back->[$ARG][1] ne $records->[$ARG][1]
        } 0 .. $#{$records};

    return ( scalar @{$records}, -s $path, $wraps );
}

## read an archive [ no secret needed ]. returns ( archive, undef ) or (
## undef, error ). $archive->{'vault'} is a locked handle : unlock it with
## vault_unlock, as a vault opened from its directory
sub archive_open {
    my $path = shift;

    my $bin = _b32_file_read($path) // return ( undef, 'not a base32 file' );
    return ( undef, 'not a vault archive' )
        if length $bin < 9
        or substr( $bin, 0, 4 ) ne $ARCHIVE_MAGIC;

    my ( undef, $format, $key_bin, $salt, $nonce, $tag, $ct )
        = unpack( q{a4 C N/a a16 a12 a16 a*}, $bin );
    return ( undef, "archive format $format not supported" )
        if $format != $FORMAT;
    return ( undef, 'archive truncated' )
        if not defined $ct
        or length $tag != 16;

    my ( $vault, $err ) = _key_file_parse( $key_bin, undef );
    return ( undef, $err ) if not defined $vault;

    return (
        {   vault   => $vault,
            key_bin => $key_bin,
            salt    => $salt,
            nonce   => $nonce,
            tag     => $tag,
            ct      => $ct,
        },
        undef
    );
}

## decrypt an archive whose vault handle is unlocked. returns  ( [
## [ name, content ] .. ], undef ) or ( undef, error )
sub archive_records {
    my $archive = shift;
    my $vault   = $archive->{'vault'};
    return ( undef, 'locked' ) if not defined $vault->{'key'};

    my $payload = _cascade_decrypt(
        $vault->{'key'},            $archive->{'salt'},
        "p7-vault-archive $FORMAT", _archive_ad($vault),
        @{$archive}{qw| nonce ct tag |}
    ) // return ( undef, 'authentication failed' );

    return ( undef, 'not an archive payload' )
        if length $payload < 8
        or substr( $payload, 0, 4 ) ne $PAYLOAD_MAGIC;
    my ( undef, $count, $rest ) = unpack( q{a4 N a*}, $payload );

    my @records;
    foreach ( 1 .. $count ) {
        return ( undef, 'payload truncated' ) if length $rest < 5;
        my ( $name, $data, $tail ) = unpack( q{C/a N/a a*}, $rest );
        return ( undef, 'payload truncated' ) if not defined $data;
        push @records, [ $name, $data ];
        $rest = $tail // '';
    }
    return ( \@records, undef );
}

## write an unlocked archive's content into $dir [ new, or the SAME vault ].
## names are checked although the archive authenticated : only entry file
## names, only into entries/. existing files are never replaced. returns a
## report : { added, same, conflict [ names ], key => created | kept }
sub archive_restore {
    my ( $archive, $dir ) = @ARG;
    my $vault = $archive->{'vault'};

    my ( $records, $err ) = archive_records($archive);
    die "vault : $err\n" if not defined $records;

    if ( -e _key_path($dir) ) {
        my ( $existing, $open_err ) = vault_open($dir);
        die "vault : $dir : $open_err\n" if not defined $existing;
        die "vault : $dir holds a different vault [ "
            . "$existing->{'id'} , the archive : $vault->{'id'} ]\n"
            if $existing->{'id'} ne $vault->{'id'};
    }

    ## all names checked before the first write : a bad archive writes nothing
    die "vault : archive holds an invalid file name -- nothing written\n"
        if grep { $ARG->[0] !~ $ENTRY_FILE_RE } @{$records};

    foreach my $sub_dir ( $dir, "$dir/entries" ) {
        next if -d $sub_dir;
        mkdir $sub_dir, 0700 or die "vault : cannot create $sub_dir\n";
    }

    my %report = ( added => 0, same => 0, conflict => [] );
    foreach my $record ( @{$records} ) {
        my ( $name, $data ) = @{$record};
        my $target = "$dir/entries/$name";
        if ( -e $target ) {
            my $have = _b32_file_read($target) // '';
            if   ( $have eq $data ) { $report{'same'}++ }
            else                    { push @{ $report{'conflict'} }, $name }
            next;
        }
        my ( $ok, $write_err )
            = _write_new_file( $target,
            _b32_file_text( $data, 'p7-vault entry' ) );
        die "vault : $write_err\n" if not $ok;
        $report{'added'}++;
    }

    ## the key file : created when missing, an existing one is kept -- it may
    ## carry a newer passphrase than the archive's copy
    if ( -e _key_path($dir) ) {
        $report{'key'} = qw| kept |;
    } else {
        my ( $ok, $write_err )
            = _write_new_file( _key_path($dir),
            _b32_file_text( $archive->{'key_bin'}, 'p7-vault key' ) );
        die "vault : $write_err\n" if not $ok;
        $report{'key'} = qw| created |;
    }
    chmod 0700, $dir;

    return \%report;
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
        next if not $complete and $length >= @used;
        return $password
            if not _truth_loaded()
            or AMOS7::Assert::Truth::is_true($password);
    }
}

1;

#,,.,,.,,,,.,,,.,,..,,,,,,,,.,,,.,.,,,,..,,,.,..,,...,...,,..,..,,.,,,.,.,...,
#OC7UFWSG7CG7DVEO3VLJ4FXN6UJEBE45X2BD6YPNJMJDHCV7KTXUTV3AS5ANOOJA57IFVOGXJDYW4
#\\\|JBA4HLC5UBQJKO36I5HDZOVZQ5HUKCGTJF6P2AU5KBXPKLKXEZM \ / AMOS7 \ YOURUM ::
#\[7]LKHT4WVQQJTRQABPPLMM3YIW2H5GGSPS63OI6LGYRAWGU4BAY2BI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
