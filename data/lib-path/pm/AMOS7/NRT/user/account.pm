package AMOS7::NRT::user::account;
our $VERSION = qw| AMOS7::NRT::user::account-VERSION.AS4R4PI |;

use v5.32.0;
use strict;
use English;
use warnings;

use Exporter;
use base qw| Exporter |;
use vars qw| @EXPORT_OK |;

use AMOS7::B32         qw| encode_b32r |;
use AMOS7::N7FS::Sign  qw| verify |;
use AMOS7::cell::canon qw| bmw384_b32 |;

use constant NETWORK => 'network';

@EXPORT_OK = qw| NETWORK message address prepare apply resolve |;

sub message {
    my ( $name, $name_time, $account_time, $pub ) = @ARG;
    return join q|:|, qw| v0 |, $name, $name_time, $account_time,
        encode_b32r($pub);
}

sub address {
    my ( $name, $name_time, $account_time, $pub, $proof ) = @ARG;
    my $input = message( $name, $name_time, $account_time, $pub ) . q|:|
        . encode_b32r($proof);
    require AMOS7::CHKSUM;
    my $bmw = bmw384_b32($input);
    my $sum = AMOS7::CHKSUM::amos_chksum( \$bmw );
    die "nrt : account checksum failed\n"
        if not defined $sum or $sum !~ m|\A[A-Z2-7]{7}\z|;
    return $sum . encode_b32r($pub);
}

sub prepare {
    my ( $values, $signer ) = @ARG;
    $values->{'pub'}   = $signer->public;
    $values->{'proof'} = $signer->sign(
        message( @{$values}{qw| name name-time ntime |}, $signer->public, ) );
    return address( @{$values}{qw| name name-time ntime pub proof |} );
}

sub resolve {
    my ( $state, $name ) = @ARG;
    return $name                       if $name eq NETWORK;
    return $state->{'accounts'}{$name} if exists $state->{'accounts'}{$name};
    return $state->{'addresses'}{$name}
        if exists $state->{'addresses'}{$name};
    die "nrt : unknown account [ $name ]\n";
}

sub apply {
    my ( $state, $record ) = @ARG;
    my $values = $record->{'values'};
    my ( $name, $pub ) = @{$values}{qw| name pub |};
    die "nrt : account name already exists [ $name ]\n"
        if exists $state->{'accounts'}{$name};
    my $expected = message( @{$values}{qw| name name-time ntime pub |} );
    die "nrt : account proof signature does not verify\n"
        if not verify( $pub, $expected, $values->{'proof'} );
    my $address = address( @{$values}{qw| name name-time ntime pub proof |} );
    die "nrt : account key already exists\n"
        if exists $state->{'addresses'}{$address};
    my $account = {
        name      => $name,
        address   => $address,
        pub       => $pub,
        name_time => $values->{'name-time'},
        ntime     => $values->{'ntime'},
    };
    $state->{'accounts'}{$name}     = $account;
    $state->{'addresses'}{$address} = $account;
    $state->{'balances'}{$address}  = '0';
    $state->{'used'}{$address}      = '0';
    return $account;
}

1;

#,,,.,.,,,.,,,,..,.,.,...,,,,,..,,.,,,,.,,.,.,..,,...,...,,..,.,.,,,,,...,,,.,
#E2EPTHTLQTVJFYI2FDYZUV4ORHGOCQNS5B7IOPPZIB36FHQLEIVWDC6ORVSLFZVFSCSNZH2BV2LSQ
#\\\|UQQXY3UK5ZQGH67XLQZW4RTUALGT2NMNEOKTZ2WHO7VLEJGEL4O \ / AMOS7 \ YOURUM ::
#\[7]UNH2XOG6SF5S5MPDZGAV5GZQWBSJVKJL3LFJEXOE7CAK3HUPJUBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
