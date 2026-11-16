package AMOS7::NRT::user::account::transaction;
our $VERSION = qw| AMOS7::NRT::user::account::transaction-VERSION.JSMYKXA |;

use v5.32.0;
use strict;
use English;
use warnings;

use Exporter;
use base qw| Exporter |;
use vars qw| @EXPORT_OK |;
use Math::BigInt;
use AMOS7::NRT::drops         qw| amount |;
use AMOS7::NRT::transaction   qw| prepare |;
use AMOS7::NRT::user::account qw| NETWORK resolve |;

@EXPORT_OK = qw| prepare_transfer |;

sub prepare_transfer {
    my ( $state, $from, $receivers, $signer, $values ) = @ARG;
    my $giver = resolve( $state, $from );
    die "nrt : a key transaction cannot give from the network account\n"
        if $giver eq NETWORK;
    die "nrt : transaction key is not the giver key\n"
        if $signer->public ne $giver->{'pub'};
    die "nrt : transaction needs at least one receiver\n"
        if ref $receivers ne q|ARRAY| or not $receivers->@*;

    my $count = Math::BigInt->new( $state->{'used'}{ $giver->{'address'} } )
        ->badd(1);
    my $total = Math::BigInt->bzero;
    my @rows;
    for my $receiver ( $receivers->@* ) {
        my ( $name, $drops ) = $receiver->@*;
        my $account = resolve( $state, $name );
        die "nrt : a transfer receiver must be a key account\n"
            if $account eq NETWORK;
        my $amount = amount($drops);
        $total->badd($amount);
        push @rows, [ '+', $account->{'address'}, $amount->bstr ];
    }
    unshift @rows, [ '-', $giver->{'address'}, $count->bstr, $total->bstr ];
    @{$values}{qw| reason by drops basis |}
        = ( qw| transfer |, '0', $total->bstr, undef );
    return prepare( $values, \@rows );
}

1;

#,,,.,,,.,..,,,,,,...,,,.,,.,,.,.,.,,,,.,,...,..,,...,...,.,,,,,.,.,.,,,.,,,.,
#TSLE3UNGMSX2EDZ3L5CUIHFANGSN7I32654HZQHESKX4IL3RDVDDAQJPY6TPJE56NXMOV5V7CE76Y
#\\\|ULZRONDJBJ5AYVKDFUS647URH5PNT6IVQ5MZPGNI5LWV7RHNR4T \ / AMOS7 \ YOURUM ::
#\[7]HJ2IR2V26CBL655F4FSCEYLL36ZTIVMWBPDDQGIA2DV5UVKDW2AY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
