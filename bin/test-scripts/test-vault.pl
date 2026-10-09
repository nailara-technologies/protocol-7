#!/usr/bin/perl
use v5.24;
use strict;
use English;
use warnings;

## tests for AMOS7::Vault [ data/md/design/VAULT-FORMAT.md ] : round trip,
## wrong secret fails closed, recovery wrap, tamper + rename detection,
## versions, rewrap, generator. runs on a throwaway dir, cheap kdf.
##
## perl bin/test-scripts/test-vault.pl  P7_VAULT_TEST_CRYPT_ARGON2=1 ... [
## force the Crypt::Argon2 path ]

use FindBin;
use File::Temp qw| tempdir |;
use File::Copy qw| copy |;

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

my ($file) = glob "$dir/entries/$id.*.vlt";
ok( ( ( stat $file )[2] & 0777 ) == 0600, 'entry file is 0600' );
my $raw = do { local ( @ARGV, $RS ) = $file; <> };
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

## tamper : flip one ciphertext char ##
my ($last) = ( sort glob "$dir/entries/$id.*.vlt" )[-1];
my $text   = do { local ( @ARGV, $RS ) = $last; <> };
my @word   = split m| |, $text;
my $orig   = $word[7];
substr( $word[7], 3, 1 ) = substr( $word[7], 3, 1 ) eq 'A' ? 'B' : 'A';
open my $fh, '>', $last or die;
print {$fh} join ' ', @word;
close $fh;
ok( !defined( ( entry_load( $v2, $id ) )[0] ), 'flipped byte fails' );
$word[7] = $orig;
open $fh, '>', $last or die;
print {$fh} join ' ', @word;
close $fh;
ok( defined( ( entry_load( $v2, $id ) )[0] ), 'restored blob loads' );

## rename : put entry B's blob under entry A's name ##
my ($b_file) = ( sort glob "$dir/entries/$id_b.*.vlt" )[0];
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
open $fh, '>', "$dir/entries/$id.$bad_version.vlt" or die;
print {$fh} "p7-vault-entry 1 truncat";
close $fh;
my ( $with_bad, $bad_errors ) = entries_latest($v4);
my ($still) = grep { $ARG->{'id'} eq $id } @{$with_bad};
ok( $still && $still->{'record'}{'password'} eq 'second',
    'damaged newest version : older one stands in'
);
ok( @{$bad_errors} == 1, 'damaged version reported' );
my ( undef, $verify_errors ) = vault_verify($v4);
ok( @{$verify_errors} == 1, 'verify reports the damaged version' );
unlink "$dir/entries/$id.$bad_version.vlt";

## no temp files left behind ##
ok( !grep( {m|\.tmp\.|} glob "$dir/entries/* $dir/*" ),
    'no temp files left' );

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
my ($key_text) = do { local ( @ARGV, $RS ) = "$dir/vault.key"; <> };
ok( $key_text =~ m|^created ([A-Z2-7]+)$|m
        && abs( AMOS7::Vault::ntime_b32_to_unix($1) - time ) < 60,
    'created is ntime b32'
);

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

#,,..,..,,..,,,,.,.,,,,,,,,,,,,..,.,.,..,,,.,,..,,...,...,.,.,,.,,.,.,,..,.,.,
#5YFOYZQMW4LDVFNZX4YGOYBMCD2JTQVTOYZWFF4IV7BFRF6AHMEGGYIRKZ5IZ46JUAKYBJPSEOWRG
#\\\|QLP2T4LXQWDXQVAAAH5OLMYXURSZS32RORRITVEL6QD3Q7LEHR7 \ / AMOS7 \ YOURUM ::
#\[7]M626XIXOMNOG2HJBI5NOZCDN4AG7VZOMR3EJRK6VJ6H7C73I5KAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
