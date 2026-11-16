package AMOS7::NRT::journal::canon;
our $VERSION = qw| AMOS7::NRT::journal::canon-VERSION.GJ4V4BA |;

use v5.32.0;
use strict;
use English;
use warnings;

use Exporter;
use base qw| Exporter |;
use vars qw| @EXPORT_OK |;

@EXPORT_OK = qw| kind body kinds |;

my $NAME    = qr|[a-z0-9._-]+|;
my $ACCOUNT = qr|(?:network\|[A-Z2-7]{59})|;

sub _field {
    my ( $name, $type, %extra ) = @ARG;
    return { name => $name, type => $type, %extra };
}

sub _common {
    return (
        _field( 'ledger', 'word', pattern => $NAME ),
        _field( 'seq',    'count' ),
        _field( 'prev',   'address' ),
        _field( 'ntime',  'stamp' ),
        _field( 'frame',  'count' ),
    );
}

sub _signed {
    return ( _field( 'pub', 'key' ), _field( 'sig', 'sig' ) );
}

my %KIND = (
    init => {
        label  => 'p7 nrt init v1',
        fields => [
            _common(),
            _field( 'witness',     'key' ),
            _field( 'frame-level', 'count' ),
            _field( 'pass',        'count' ),
            _signed(),
        ],
    },
    account => {
        label  => 'p7 nrt account v1',
        fields => [
            _common(),
            _field( 'name',      'word', pattern => $NAME ),
            _field( 'name-time', 'stamp' ),
            _field( 'proof',     'sig' ),
            _field( 'pass',      'count' ),
            _signed(),
        ],
    },
    transaction => {
        label  => 'p7 nrt transaction v1',
        fields => [
            _common(),
            _field(
                'reason',
                'word',
                words =>
                    [qw| transfer fill earn donate return issue park thaw |],
            ),
            _field( 'by',    'address' ),
            _field( 'drops', 'count' ),
            _field( 'basis', 'word', words => [qw| test |] ),
            _field( 'pass',  'count' ),
            _field( 'rows',  'count' ),
            _field( 'body',  'address' ),
            _signed(),
        ],
    },
    void => {
        label  => 'p7 nrt void v1',
        fields => [ _common(), _field( 'pass', 'count' ), _signed() ],
    },
    head => {
        label  => 'p7 nrt head v1',
        fields => [
            _field( 'ledger', 'word', pattern => $NAME ),
            _field( 'seq',    'count' ),
            _field( 'last',   'address' ),
            _field( 'ntime',  'stamp' ),
            _signed(),
        ],
    },
);

my $BODY = {
    shape   => 'operations',
    order   => 'fixed',
    sorted  => 1,
    classes => [
        {   name   => '-',
            fields => [
                _field( 'account',    'word', pattern => $ACCOUNT ),
                _field( 'from-count', 'count' ),
                _field( 'drops',      'count' ),
            ],
        },
        {   name   => '+',
            fields => [
                _field( 'account', 'word', pattern => $ACCOUNT ),
                _field( 'drops',   'count' ),
            ],
        },
    ],
};

sub kind {
    my $name = shift // '';
    die "nrt : unknown record kind [ $name ]\n" if not exists $KIND{$name};
    return $KIND{$name};
}

sub body  { return $BODY }
sub kinds { return sort keys %KIND }

1;

#,,.,,...,,,,,,..,.,,,.,.,,..,,.,,,..,,..,..,,..,,...,..,,.,,,,,,,.,,,,,.,,..,
#CYB6QGI33O5KRR5RWWUUJ6R3SSGIODNBO7EVI423QK6B7FWUFWJVOOLJETDTMCBBMSYXQ7RH4YX6M
#\\\|IPNUGUMOG4M2NOID3HGXGD6TGMSIAQG3VTA2PKJSIO5GYPAS23M \ / AMOS7 \ YOURUM ::
#\[7]4POND4ANDGXJZHXQG3TJLKXNP7LK3LDVQMA4SREKI5TB56XWRODQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
