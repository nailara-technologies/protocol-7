#!/usr/bin/perl
use v5.24;
use strict;
use English;
use warnings;

## tests for AMOS7::Vault [ data/md/design/VAULT-FORMAT.md ] : round trip,
## wrong secret fails closed, recovery wrap, tamper + rename detection,
## versions, rewrap, generator. runs on a throwaway dir, cheap kdf.
##
## perl bin/test-scripts/test-vault.pl  P7_VAULT_TEST_CRYPT_ARGON2=1 ...
## [ force the Crypt::Argon2 path ]

use FindBin;
use File::Temp qw| tempdir |;
use File::Copy qw| copy |;

##[ global constants ]##
use constant TRUE  => 5;    ##  TRUE.  ##
use constant FALSE => 0;    ##  false  ##

BEGIN { unshift @INC, "$FindBin::Bin/../../data/lib-path/pm" }

use AMOS7::Vault qw|
    vault_init vault_open vault_unlock vault_rewrap vault_wraps
    entry_save entry_load entry_versions entries_latest vault_verify
    gen_password recovery_code_new recovery_code_normalize
    |;

## force the Crypt::Argon2 fallback : hide CryptX's argon2 ##
if ( $ENV{'P7_VAULT_TEST_CRYPT_ARGON2'} ) {
    require Crypt::KeyDerivation;
    no warnings qw| redefine |;
    undef &Crypt::KeyDerivation::argon2_pbkdf;
}

my ( $pass, $fail ) = ( 0, 0 );

sub ok {
    my ( $cond, $name ) = @ARG;
    if   ($cond) { $pass++; say "  ok    $name" }
    else         { $fail++; say "  FAIL  $name" }
}

my %kdf = ( t => 1, m => 8192, p => 1 );    ## cheap, test only ##

my $dir      = tempdir( CLEANUP => 1 ) . '/vault';
my $recovery = recovery_code_new();

ok( $recovery =~ m|^([A-Z2-7]{4}-){7}[A-Z2-7]{4}$|, 'recovery code shape' );
ok( recovery_code_normalize( lc $recovery ) eq
        recovery_code_normalize($recovery),
    'recovery code case-insensitive'
);

my $v = vault_init( $dir, "pässphrase one", $recovery, %kdf );
ok( defined $v->{'key'} && length $v->{'key'} == 32, 'init gives a key' );
ok( ( ( stat $dir )[2] & 0777 ) == 0700,             'vault dir is 0700' );
ok( !eval { vault_init( $dir, 'x', undef, %kdf ); 1 },
    'init refuses an existing vault' );

## entries ##
my $id = entry_save(
    $v, undef,
    {   type     => 'login',
        title    => 'Example',
        url      => 'https://example.org',
        username => 'me',
        password => "s3cret \x{263a} with space",
    }
);
ok( $id =~ m|^[A-Z2-7]{16}$|, 'entry id shape' );

my ($file) = glob "$dir/entries/$id.*.vlt.B32";
ok( ( ( stat $file )[2] & 0777 ) == 0600, 'entry file is 0600' );
my $raw = do { local ( @ARGV, $RS ) = $file; <> };

sub framed {    ## the inline subroutine frame of bin/Protocol-7 ##
    my ( $text, $title ) = @ARG;
    my @line = split m|\n|, $text;
    return FALSE if shift(@line) ne ".:[ $title ]:." or shift(@line) ne ':';
    return FALSE if pop(@line) ne ':'                or not @line;
    return FALSE if grep { !m|^: [0A-Z2-7]{76}\z| } @line;
    return FALSE if $line[-1] !~ m{^: 0*[A-Z2-7]+0*\z};
    return TRUE;
}
ok( framed( $raw, 'p7-vault entry' ), 'entry file : framed base32 block' );
ok( framed(
        scalar do { local ( @ARGV, $RS ) = "$dir/vault.key.B32"; <> },
        'p7-vault key'
    ),
    'key file : framed base32 block'
);
ok( index( $raw, 's3cret' ) == -1 && index( $raw, 'Example' ) == -1,
    'no plaintext in the blob' );

## a fresh handle, as a separate process would see it ##
my ( $v2, $err ) = vault_open($dir);
ok( defined $v2,                                            'open' );
ok( join( ',', vault_wraps($v2) ) eq 'passphrase,recovery', 'both wraps' );
ok( !vault_unlock( $v2, 'wrong' ), 'wrong passphrase fails' );
ok( !defined $v2->{'key'},         'still locked after failure' );
ok( !vault_unlock( $v2, 'pässphrase one', 'recovery' ),
    'passphrase does not open the recovery wrap'
);
ok( vault_unlock( $v2, 'pässphrase one' ), 'passphrase unlocks' );

my ( $record, $load_err ) = entry_load( $v2, $id );
ok( defined $record && $record->{'password'} eq "s3cret \x{263a} with space",
    'round trip incl. unicode'
);

my ($v3) = vault_open($dir);
my $typed = lc $recovery;
$typed =~ tr|-| |;
ok( vault_unlock( $v3, $typed, 'recovery' ), 'recovery code unlocks' );

## versions + delete ##
entry_save( $v2, $id, { %{$record}, password => 'second' } );
my $versions = entry_versions($v2)->{$id};
ok( @{$versions} == 2, 'two versions' );
ok( ( entry_load( $v2, $id ) )[0]{'password'} eq 'second', 'latest wins' );
ok( ( entry_load( $v2, $id, $versions->[0] ) )[0]{'password'} =~ m|^s3cret|,
    'old version still readable' );

my $id_b = entry_save( $v2, undef, { type => 'note', title => 'B' } );
entry_save( $v2, $id_b, { type => 'note', title => 'B', deleted => 1 } );
my ($list) = entries_latest($v2);
ok( @{$list} == 1 && $list->[0]{'id'} eq $id, 'deleted entry hidden' );
($list) = entries_latest( $v2, 1 );
ok( @{$list} == 2, 'deleted entry listed on request' );

## the binary content of a stored file, and writing it back ##
sub read_bin { return AMOS7::Vault::_b32_file_read(shift) }

sub write_bin {
    my ( $path, $bin ) = @ARG;
    open my $out, '>', $path or die;
    print {$out} AMOS7::Vault::_b32_file_text( $bin, 'test' );
    close $out;
}

## tamper : flip one ciphertext byte ##
my ($last) = ( sort glob "$dir/entries/$id.*.vlt.B32" )[-1];
my $orig   = read_bin($last);
my $bent   = $orig;
substr( $bent, 90, 1 ) = chr( ord( substr $bent, 90, 1 ) ^ 1 );
write_bin( $last, $bent );
ok( !defined( ( entry_load( $v2, $id ) )[0] ), 'flipped byte fails' );
write_bin( $last, $orig );
ok( defined( ( entry_load( $v2, $id ) )[0] ), 'restored blob loads' );

## rename : put entry B's blob under entry A's name ##
my ($b_file) = ( sort glob "$dir/entries/$id_b.*.vlt.B32" )[0];
( my $b_version = $b_file ) =~ s|.*/$id_b\.||;
copy( $b_file, "$dir/entries/$id.$b_version" ) or die;
ok( !defined( ( entry_load( $v2, $id ) )[0] ), 'swapped blob fails' );
unlink "$dir/entries/$id.$b_version";

## rewrap : new passphrase, old one stops working ##
vault_rewrap( $v2, 'passphrase', 'new one' );
my ($v4) = vault_open($dir);
ok( !vault_unlock( $v4, 'pässphrase one' ), 'old passphrase gone' );
ok( vault_unlock( $v4,  'new one' ),        'new passphrase unlocks' );
ok( ( entry_load( $v4, $id ) )[0]{'password'} eq 'second',
    'entries untouched by rewrap' );
ok( !eval {
        vault_rewrap( $v4, 'passphrase', undef );
        vault_rewrap( $v4, 'recovery',   undef );
        1;
    },
    'last wrap cannot be removed'
);

my ( $count, $errors ) = vault_verify($v4);
ok( $count == 4 && !@{$errors}, "verify : $count ok" );

## a damaged newest version : the older one stands in, the error is listed ##
my $newest = entry_versions($v4)->{$id}[-1];
( my $bad_version = $newest ) =~ s|^(\d+)|sprintf q{%014d}, $1 + 4200|e;
write_bin( "$dir/entries/$id.$bad_version.vlt.B32", "P7VE\x01truncated" );
my ( $with_bad, $bad_errors ) = entries_latest($v4);
my ($still) = grep { $ARG->{'id'} eq $id } @{$with_bad};
ok( $still && $still->{'record'}{'password'} eq 'second',
    'damaged newest version : older one stands in'
);
ok( @{$bad_errors} == 1, 'damaged version reported' );
my ( undef, $verify_errors ) = vault_verify($v4);
ok( @{$verify_errors} == 1, 'verify reports the damaged version' );
unlink "$dir/entries/$id.$bad_version.vlt.B32";

## no temp files left behind ##
ok( !grep( {m|\.tmp\.|} glob "$dir/entries/* $dir/*" ),
    'no temp files left' );

## cascade : twofish-gcm inside chacha20-poly1305 ##
{
    my $file_c = ( sort glob "$dir/entries/$id.*.vlt.B32" )[-1];
    my $bin_c  = read_bin($file_c);
    my $e      = AMOS7::Vault::_entry_parse($bin_c);
    my ( $salt_c, $nonce_c, $ct_c, $tag_c ) = @{$e}{qw| salt nonce ct tag |};
    my $ad    = join ' ', 'p7-vault-entry 1', @{$e}{qw| vault id version |};
    my $label = 'p7-vault-entry 1';

    my ( $tf_key, $tf_nonce, $cc_key )
        = AMOS7::Vault::_layer_keys( $v4->{'key'}, $salt_c, $label );
    ok( $tf_key ne $cc_key && length $tf_key == 32 && length $tf_nonce == 12,
        'cascade : independent layer keys'
    );

    ## peel the outer layer only : still ciphertext ##
    require Crypt::AuthEnc::ChaCha20Poly1305;
    my $inner
        = Crypt::AuthEnc::ChaCha20Poly1305::chacha20poly1305_decrypt_verify(
        $cc_key, $nonce_c, $ad, $ct_c, $tag_c );
    ok( defined $inner
            && index( $inner, '"type"' ) == -1
            && index( $inner, 'second' ) == -1,
        'cascade : outer layer alone reveals nothing'
    );

    ## a broken chacha20 : the attacker re-seals a tampered inner layer -- ##
    ## twofish-gcm's own tag must still refuse it                          ##
    substr( $inner, 5, 1 ) = chr( ord( substr $inner, 5, 1 ) ^ 1 );
    my ( $ct_t, $tag_t )
        = Crypt::AuthEnc::ChaCha20Poly1305::chacha20poly1305_encrypt_authenticate(
        $cc_key, $nonce_c, $ad, $inner );
    ok( !defined AMOS7::Vault::_cascade_decrypt(
            $v4->{'key'}, $salt_c, $label, $ad, $nonce_c, $ct_t, $tag_t
        ),
        'cascade : inner layer authenticates on its own'
    );

    ## an unknown format is refused with a clear reason ##
    my $f1_dir = tempdir( CLEANUP => 1 );
    write_bin( "$f1_dir/vault.key.B32",
        pack( 'a4 C', 'P7VK', 9 ) . "\0" x 40 );
    my ( undef, $f1_err ) = vault_open($f1_dir);
    ok( ( $f1_err // '' ) =~ m|format 9 not supported|,
        'unknown vault ' . 'format ' . 'refused'
    );

    my $v1_name = "$dir/entries/$id.00000000000001.AAAAAAAA.vlt.B32";
    my $bin_9   = $bin_c;
    substr( $bin_9, 4, 1 ) = chr 9;
    write_bin( $v1_name, $bin_9 );
    my ( undef, $e1_err ) = entry_load( $v4, $id, '00000000000001.AAAAAAAA' );
    ok( ( $e1_err // '' ) =~ m|entry format 9 not supported|,
        'unknown entry format refused' );
    unlink $v1_name;
}

## network time ##
my $now_ntime = AMOS7::Vault::ntime_now();
ok( abs(AMOS7::Vault::ntime_b32_to_unix(
            AMOS7::Vault::ntime_b32($now_ntime)
        ) - time
    ) < 2,
    'ntime b32 round trip'
);
my $latest = entry_versions($v4)->{$id}[-1];
ok( abs( AMOS7::Vault::version_to_unix($latest) - time ) < 60,
    'version name carries ntime' );
my ($rec_now) = entry_load( $v4, $id );
ok( abs( AMOS7::Vault::ntime_b32_to_unix( $rec_now->{'updated'} ) - time )
        < 60,
    'updated is ntime b32'
);
my $created = unpack( 'x15 Q>', read_bin("$dir/vault.key.B32") );
ok( abs( AMOS7::NTIME::ntime_to_unix($created) - time ) < 60,
    'created is ntime' );

## generator ##
my $gen = gen_password(24);
ok( length $gen == 24, 'generator length' );
ok( $gen        =~ m|[a-z]|
        && $gen =~ m|[A-Z]|
        && $gen =~ m|\d|
        && $gen =~ m|[^a-zA-Z0-9]|,
    'generator uses every class'
);
ok( gen_password( 16, 'a9' ) =~ m|^[a-z0-9]{16}$|, 'generator classes' );

say '';
say "  $pass passed, $fail failed  [ perl $^V ]";
exit( $fail ? 1 : 0 );

#,,.,,.,,,,..,,.,,.,.,,..,.,.,,,,,,,.,.,.,,..,..,,...,...,.,.,..,,.,.,,,,,.,.,
#ACVCS6FKUMKI72KFJF6224WIX4IGDYTA4FNXVRXNS6MNUZG5QXBUV3BGA35762WAOPKW4PJ6WXSYO
#\\\|WL7FAQ3FCHWICHURYNT7RZLICU7ANFMQMXKF5GLBT622M7OHR6W \ / AMOS7 \ YOURUM ::
#\[7]KFPYXHNS5BO5CBRQIRSSEAANNDP64VI5HTCWBQB2JBBVWPUL2YCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
