package AMOS7::NRT::transaction;
our $VERSION = qw| AMOS7::NRT::transaction-VERSION.YQCUDKQ |;

use v5.32.0;
use strict;
use English;
use warnings;

use Exporter;
use base qw| Exporter |;
use vars qw| @EXPORT_OK |;
use Math::BigInt;
use AMOS7::cell::canon         qw| bmw384_b32 |;
use AMOS7::cell::canon::list   qw| pack_body |;
use AMOS7::NRT::drops          qw| amount bounded |;
use AMOS7::NRT::journal::canon qw| body |;
use AMOS7::NRT::user::account  qw| NETWORK resolve |;

@EXPORT_OK = qw| prepare prepare_issue apply |;

sub _sorted_rows {
    my $rows = shift;
    return [
        sort {
            $a->[0] ne $b->[0]
                ? ( $a->[0] eq q|-| ? -1 : 1 )
                : join( q| |, @{$a} ) cmp join( q| |, @{$b} )
        } $rows->@*
    ];
}

sub prepare {
    my ( $values, $rows ) = @ARG;
    my $body = pack_body( body(), _sorted_rows($rows) );
    $values->{'rows'} = scalar $rows->@*;
    $values->{'body'} = bmw384_b32($body);
    return $body;
}

sub prepare_issue {
    my ( $state, $to, $drops, $signer, $values ) = @ARG;
    my $account = resolve( $state, $to );
    die "nrt : an issue receiver must be a key account\n"
        if $account eq NETWORK;
    my $amount = amount($drops)->bstr;
    my $count
        = Math::BigInt->new( $state->{'used'}{ NETWORK() } // 0 )->badd(1);
    my @rows = (
        [ '-', NETWORK, $count->bstr, $amount ],
        [ '+', $account->{'address'}, $amount ],
    );
    @{$values}{qw| reason by drops basis |}
        = ( qw| issue |, '0', $amount, qw| test | );
    return prepare( $values, \@rows );
}

sub _balance {
    my ( $state, $address ) = @ARG;
    return Math::BigInt->new( $state->{'balances'}{$address} // 0 );
}

sub apply {
    my ( $state, $record, $rows ) = @ARG;
    my $values = $record->{'values'};
    my $drops  = amount( $values->{'drops'} );
    die "nrt : transaction must have one giver and a receiver\n"
        if $rows->@* < 2;

    my ( @givers, @receivers, %seen );
    for my $row ( $rows->@* ) {
        my ( $side, $address, @rest ) = $row->@*;
        my $row_drops = $side eq q|-| ? $rest[1] : $rest[0];
        amount($row_drops);
        die "nrt : account occurs twice or on both sides [ $address ]\n"
            if $seen{$address}++;
        if ( $side eq q|-| ) {
            push @givers,
                {
                address => $address,
                count   => $rest[0],
                drops   => $rest[1]
                };
        } else {
            push @receivers, { address => $address, drops => $rest[0] };
        }
    }
    die "nrt : stage 1a permits exactly one giver\n" if @givers != 1;
    my $giver = $givers[0];

    my $sum_give = Math::BigInt->bzero;
    my $sum_take = Math::BigInt->bzero;
    $sum_give->badd( amount( $ARG->{'drops'} ) ) for @givers;
    $sum_take->badd( amount( $ARG->{'drops'} ) ) for @receivers;
    die "nrt : giving rows do not sum to head drops\n"
        if $sum_give->bcmp($drops) != 0;
    die "nrt : receiving rows do not sum to head drops\n"
        if $sum_take->bcmp($drops) != 0;

    my $issue = $values->{'reason'} eq qw| issue |;
    die "nrt : unsupported stage 1a transaction reason\n"
        if not $issue and $values->{'reason'} ne qw| transfer |;
    die "nrt : key transaction must use by = 0\n"
        if $values->{'by'} ne '0';
    if ($issue) {
        die "nrt : test issue must carry basis = test\n"
            if ( $values->{'basis'} // '' ) ne qw| test |;
        die "nrt : issue giver is not the network account\n"
            if $giver->{'address'} ne NETWORK;
        die "nrt : issue must have exactly one key-account receiver\n"
            if @receivers != 1
            or $receivers[0]{'address'} eq NETWORK;
        die "nrt : issue is not signed by the witness\n"
            if $values->{'pub'} ne $state->{'witness'};
    } else {
        die "nrt : transfer cannot carry an issue basis\n"
            if defined $values->{'basis'};
        die "nrt : network account changes only by an issue\n"
            if $giver->{'address'} eq NETWORK
            or grep { $ARG->{'address'} eq NETWORK } @receivers;
    }

    for my $row ( @givers, @receivers ) {
        next if $row->{'address'} eq NETWORK;
        die "nrt : unknown account [ $row->{'address'} ]\n"
            if not exists $state->{'addresses'}{ $row->{'address'} };
    }
    if ( not $issue ) {
        my $account = $state->{'addresses'}{ $giver->{'address'} };
        die "nrt : transaction pub is not the giver key\n"
            if $values->{'pub'} ne $account->{'pub'};
    }

    my $expected
        = Math::BigInt->new( $state->{'used'}{ $giver->{'address'} } // 0 )
        ->badd(1);
    die "nrt : from-count is not the next account count\n"
        if Math::BigInt->new( $giver->{'count'} )->bcmp($expected) != 0;

    $state->{'balances'}{ NETWORK() } //= '0';
    for my $row (@givers) {
        my $next = _balance( $state, $row->{'address'} )
            ->bsub( amount( $row->{'drops'} ) );
        $state->{'balances'}{ $row->{'address'} }
            = bounded( $next, $row->{'address'} eq NETWORK )->bstr;
        $state->{'used'}{ $row->{'address'} } = $expected->bstr;
    }
    for my $row (@receivers) {
        my $next = _balance( $state, $row->{'address'} )
            ->badd( amount( $row->{'drops'} ) );
        $state->{'balances'}{ $row->{'address'} }
            = bounded( $next, $row->{'address'} eq NETWORK )->bstr;
    }
    if ($issue) {
        $state->{'supply'}
            = bounded(
            Math::BigInt->new( $state->{'supply'} // 0 )->badd($drops) )
            ->bstr;
        die "nrt : issue would exceed the 9999999999999 drop bound\n"
            if _balance( $state, NETWORK )
            ->copy->babs->bcmp( Math::BigInt->new( $state->{'supply'} ) )
            != 0;
    }
    return;
}

1;

#,,,.,.,,,,.,,.,,,,,,,,,.,.,.,,,,,,,.,..,,,.,,..,,...,...,,,.,..,,,,,,,,.,,,.,
#4GXMVHFNKLMGEQ4OHM4E7K34S2F57RFQFYOJSBN5GSINU7MUO76JVAATH2VQDQONCC3OCM6RLNY7C
#\\\|DIE56XVFDOKJVL5XCZLYYEQU2YMT4UZG72JHC65HXR224R7PASD \ / AMOS7 \ YOURUM ::
#\[7]5YSDXM2BAWOYQ4FKBKH5ZSFFXZYX7T3OJHY65MSHC2FFVP62YWCA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
