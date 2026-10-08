#!/usr/bin/env perl
use v5.24;
use strict;
use English;
use warnings;

## :pass-env: LIVE [ keys.passphrase_from_env ] : drives the real p7-keys   ##
## with every passphrase in the environment -- create a throwaway virtual   ##
## key, show its public key, certify this host's host-root with it, check   ##
## the statement's issuer is that key. stdin is /dev/null and every run has ##
## a timeout : a prompt that slips through is a FAILURE, not a hang.  the   ##
## key is unique per run and always removed [ END ], the statement is       ##
## written into a temp dir. skips without p7-keys or a readable .dlg.       ##

use File::Spec;
use Cwd        qw| abs_path |;
use FindBin    qw| $RealBin |;
use File::Temp qw| tempdir |;

BEGIN {
    my $up   = File::Spec->updir;
    my $root = abs_path(
        File::Spec->rel2abs( File::Spec->catdir( $RealBin, $up, $up ) ) );
    unshift( @INC, File::Spec->catdir( $root, qw| data lib-path pm | ) );
}

use Crypt::Misc qw| decode_b32r encode_b32r |;

my ( $test_count, $fail_count ) = ( 0, 0 );

sub ok ($;$) {
    my ( $cond, $label ) = @ARG;
    $test_count++;
    if ($cond) { say "  ok   : $label"; return 1 }
    $fail_count++;
    say "  FAIL : $label";
    return 0;
}

my ($p7_keys) = grep { -x "$ARG/p7-keys" } split m|:|, $ENV{'PATH'} // '';
my $dlg       = '/home/protocol-7/.n/user-keys/protocol-7.base.dlg';
if ( not defined $p7_keys or not -r $dlg ) {
    say '  skip : no p7-keys on PATH or no readable .dlg';
    exit 0;
}
$p7_keys .= '/p7-keys';

my $key  = sprintf 'zz-passenv-%d', $PID;
my $seed = 'zz-throwaway-seed-phrase-for-a-live-test';
my $tmp  = tempdir( CLEANUP => 1 );

## run p7-keys : no stdin, a timeout, the given environment ##
sub p7 {
    my ( $env, @args ) = @ARG;
    local %ENV = ( %ENV, %$env );
    my $cmd = join ' ', map {"'$ARG'"} 'timeout', '60', $p7_keys, @args;
    my $out = qx{cd '$tmp' && $cmd </dev/null 2>&1};
    $out =~ s{\e\[[0-9;]*m}{}g;
    return ( $out, $CHILD_ERROR >> 8 );
}

my $owner_pin = "$ENV{'HOME'}/.n/remote-keys/owners/$key.public";

END {    ## the throwaway key + its owner pin go, whatever happened ##
    p7( {}, qw| remove |, $key ) if defined $key and defined $p7_keys;
    unlink $owner_pin            if defined $owner_pin;
}

say ': :pass-env: live [ real p7-keys, no prompt anywhere ]';

my ( $out, $rc ) = p7( {}, qw| create-stub-key |, $key );
ok( $out =~ m|successfully created virtual key|, 'a throwaway virtual key' );

( $out, $rc ) = p7(
    { PROTOCOL_7_KEY_SEED => $seed },
    qw| get-sp-pub-key |,
    $key, ':pass-env:'
);
my ($pub) = $out =~ m|::\[ ([A-Z2-7]{52}) \]|;
ok( defined $pub, 'get-sp-pub-key :pass-env: : its public key, no prompt' );

## the owner pin [ same name ] : certify checks the phrase against it ##
( $out, $rc ) = p7( {}, qw| owner-pin |, $key, $pub // 'x' );
ok( -f $owner_pin, 'its key id pinned as an owner [ same name ]' );

( $out, $rc ) = p7( {}, qw| get-sp-pub-key |, $key, ':pass-env:' );
ok( $out =~ m|PROTOCOL_7_KEY_SEED is not set|,
    'the tag without the variable : refused, named'
);

( $out, $rc ) = p7(
    { PROTOCOL_7_KEY_SEED => 'short' },
    qw| get-sp-pub-key |,
    $key, ':pass-env:'
);
ok( $out =~ m|shorter than 13|, 'a phrase under 13 characters : refused' );

( $out, $rc ) = p7(
    { PROTOCOL_7_KEY_PASSPHRASE => $seed },
    qw| certify-host |,
    $key, 'zz-test', $dlg, ':pass-env:'
);
ok( $out =~ m|certified host-root of 'zz-test'|,
    'certify-host :pass-env: : certified, no prompt'
);

my $file = File::Spec->catfile( $tmp, 'zz-test.host-root.dlg' );
my $wire = '';
if ( open( my $fh, '<', $file ) ) {
    $wire = readline($fh) // '';
    close($fh);
}
chomp $wire;
my $bytes = length $wire ? eval { decode_b32r($wire) } : undef;
## a plain copy first : encode_b32r gets undef from a substr lvalue ##
my $issuer_pub = defined $bytes      ? substr( $bytes, 17, 32 ) : undef;
my $issuer     = defined $issuer_pub ? encode_b32r($issuer_pub) : '';
ok( defined $pub && $issuer eq $pub,
    '  :.. the statement is signed by exactly that virtual key' );
ok( ( ( ( stat $file )[2] // 0 ) & 07777 ) == 0644, '  :.. public, 0644' )
    if -e $file;

( $out, $rc ) = p7(
    { PROTOCOL_7_KEY_PASSPHRASE => 'not-the-right-phrase' },
    qw| certify-host |,
    $key, 'zz-other', $dlg, ':pass-env:'
);
ok( $out =~ m|does not produce the expected owner key|
        && !-e "$tmp/zz-other.host-root.dlg",
    'a wrong phrase : refused against the owner pin, nothing certified'
);

say '';
say "passed : " . ( $test_count - $fail_count ) . "  failed : $fail_count";
exit( $fail_count ? 1 : 0 );

#,,..,,..,.,.,,,.,,,,,...,.,.,.,,,,..,.,.,,,,,..,,...,...,..,,...,.,,,,,,,,..,
#BKZJ5PKIBOEQY67FLZUHLIKMNEKSQIU2V477VB4PKUQHVF5ZK5M2JIG5IADMVACYTPCI2SFJXBRYC
#\\\|MBDO6M7IDVYLY75UXEAYSCTT4SYG4XSV4QSSSR22ZK5JS7OTT6G \ / AMOS7 \ YOURUM ::
#\[7]M3AADBDKLFBHUBPJEL7ALXDTHW2QME6TCEJEPGZYVJVV6EJF7CAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
