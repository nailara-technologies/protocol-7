#!/usr/bin/perl
use v5.32.0;
use strict;
use English;
use warnings;

use FindBin;
BEGIN { unshift @INC, "$FindBin::Bin/../../data/lib-path/pm" }

use Test::More;
use Time::HiRes qw| time |;
use Crypt::PK::Ed25519;
use AMOS7::B32         qw| encode_b32r |;
use AMOS7::cell::canon qw| bmw384_b32 pack_head parse_head signed_bytes
    record_address |;
use AMOS7::cell::canon::list qw| pack_body |;

sub field {
    my ( $name, $type, %extra ) = @ARG;
    return { name => $name, type => $type, %extra };
}

{

    package CanonTestSigner;
    use English;

    sub new {
        my ( $class, $seed ) = @ARG;
        my $pk = Crypt::PK::Ed25519->new;
        $pk->import_key_raw( $seed, q|private| );
        return bless { pk => $pk, pub => $pk->export_key_raw(q|public|) },
            $class;
    }
    sub public { return shift->{'pub'} }
    sub sign   { return shift->{'pk'}->sign_message(shift) }
}

sub verify_signature {
    my ( $pub, $message, $signature ) = @ARG;
    return eval {
        my $pk = Crypt::PK::Ed25519->new;
        $pk->import_key_raw( $pub, q|public| );
        $pk->verify_message( $signature, $message ) ? 1 : 0;
    } // 0;
}

sub refusal {
    my ( $name, $code, $expected ) = @ARG;
    my $error = do {
        local $EVAL_ERROR;
        eval { $code->(); 1 } ? undef : $EVAL_ERROR;
    };
    ok( defined $error && $error =~ $expected, $name )
        or diag( $error // 'the operation was accepted' );
}

sub set_value {
    my ( $bytes, $key, $value ) = @ARG;
    $bytes =~ s|^(\Q$key\E += ).*$|$1$value|m
        or die "test fixture key not found : $key";
    return $bytes;
}

sub set_line {
    my ( $bytes, $key, $line ) = @ARG;
    $bytes =~ s|^\Q$key\E .*\n|$line\n|m
        or die "test fixture line not found : $key";
    return $bytes;
}

sub field_line {
    my ( $bytes, $key ) = @ARG;
    return ( $bytes =~ m|(^\Q$key\E .*\n)|m )[0];
}

my $signer = CanonTestSigner->new( "\x42" x 32 );
my $pub    = $signer->public;
my @fields = (
    field( 'disk',      'address' ),
    field( 'seq',       'count' ),
    field( 'prev',      'address' ),
    field( 'was',       'address' ),
    field( 'at',        'stamp' ),
    field( 'epoch-num', 'decimal' ),
    field( 'operation', 'word', pattern => qr|[a-z]+(?:-[a-z]+)*| ),
    field( 'note',      'text' ),
    field( 'payload',   'octets' ),
    field( 'tags',      'list',  pattern => qr|[a-z]+| ),
    field( 'links',     'pairs', pattern => qr|[a-z]+| ),
    field( 'flags',     'flags', words   => [qw| converted repaired |] ),
    field( 'rows',      'count' ),
    field( 'body',      'address' ),
    field( 'pub',       'key' ),
    field( 'sig',       'sig' ),
);
my $kind = {
    label  => 'p7 n7fs journal v4',
    fields => \@fields,
};
my $ledger_kind = {
    label  => 'p7 nrt transaction v1',
    fields => \@fields,
};
my $address_a = 'V7AAAAA/AAAAAAA/' . bmw384_b32('node a');
my $address_b = 'V7AAAAA/BBBBBBB/' . bmw384_b32('node b');

my $operations = {
    shape   => 'operations',
    order   => 'fixed',
    sorted  => 1,
    classes => [
        { name => '- release', fields => [ field( 'address', 'address' ) ] },
        {   name   => '+ node',
            fields =>
                [ field( 'address', 'address' ), field( 'meta', 'text' ), ],
        },
    ],
};
my $operation_rows = [
    [ '- release', $address_b ],
    [ '+ node',    $address_a, "meta\nbytes" ],
];
my $body   = pack_body( $operations, $operation_rows );
my %values = (
    disk        => $address_a,
    seq         => '1042',
    prev        => '0',
    was         => undef,
    at          => '00031703855078',
    'epoch-num' => '1042.0123456789012',
    operation   => 'node-add',
    note        => 'plain ASCII text',
    payload     => "\x00\xff",
    tags        => [qw| beta alpha |],
    links       => [qw| photos:BBB incoming:AAA |],
    flags       => [qw| converted |],
    rows        => 2,
    body        => bmw384_b32($body),
    pub         => "\0" x 32,
    sig         => "\0" x 64,
);

subtest 'head, signature, address and both domains' => sub {
    my $head   = pack_head( $kind, \%values, signer => $signer );
    my $parsed = parse_head(
        $head . $body,
        $kind,
        pub    => $pub,
        verify => \&verify_signature,
    );
    is( $parsed->{'label'}, 'p7 n7fs journal v4', 'stored label parsed' );
    is( $parsed->{'values'}{'seq'}, '1042', 'count remains decimal text' );
    is( $parsed->{'values'}{'note'}, 'plain ASCII text',
        'bare text decoded' );
    is_deeply( $parsed->{'values'}{'tags'},
        [qw| alpha beta |], 'list packed sorted by bytes' );
    is_deeply(
        $parsed->{'values'}{'links'},
        [qw| incoming:AAA photos:BBB |],
        'pairs packed sorted by bytes'
    );
    is( $parsed->{'body_bytes'}, $body, 'parser leaves exact body bytes' );
    is( pack_head( $kind, $parsed->{'values'} ),
        $head, 'pack of parse is byte equal' );
    is( signed_bytes( $kind, $parsed->{'values'} ),
        $parsed->{'signed_bytes'},
        'signed bytes include pub and exclude sig'
    );
    ok( verify_signature(
            $pub,
            $parsed->{'signed_bytes'},
            $parsed->{'values'}{'sig'}
        ),
        'ed25519 verifies the stored signed bytes'
    );
    is( length( $parsed->{'address_bytes'} ),
        length($head) - 1,
        'address ends at sig LF and excludes the empty line'
    );
    is( record_address( $head, $kind ),
        $parsed->{'address'},
        'record address is stable'
    );
    is( record_address($parsed),
        bmw384_b32( $parsed->{'address_bytes'} ),
        'record address is BMW384 of the stored address bytes'
    );

    my %ledger_values = ( %values, rows => 0, body => '0' );
    my $ledger_head
        = pack_head( $ledger_kind, \%ledger_values, signer => $signer );
    my $ledger = parse_head(
        $ledger_head, $ledger_kind,
        pub    => $pub,
        verify => \&verify_signature,
    );
    is( $ledger->{'domain'}, 'nrt', 'same parser accepts a ledger domain' );
    is( pack_head( $ledger_kind, $ledger->{'values'} ),
        $ledger_head, 'ledger pack of parse is byte equal' );

    my $unsigned_kind = {
        label  => 'p7 n7fs state v4',
        fields => [ field( 'disk', 'address' ), field( 'seq', 'count' ) ],
    };
    my $unsigned_head
        = pack_head( $unsigned_kind, { disk => $address_a, seq => 4 } );
    my $unsigned = parse_head( $unsigned_head, $unsigned_kind );
    is( $unsigned->{'address'},
        record_address( $unsigned_head, $unsigned_kind ),
        'unsigned address includes the last field LF'
    );
};

my $flat_values = { %values, rows => 0, body => '0' };
my $flat_head   = pack_head( $kind, $flat_values, signer => $signer );

subtest 'signed parsing fails closed' => sub {
    refusal(
        'signed record without verify is refused',
        sub { parse_head( $flat_head, $kind ) },
        qr|signed record requires verify|,
    );
    my $inspection = parse_head( $flat_head, $kind, unverified => 1 );
    is( $inspection->{'verified'},
        0, 'explicit inspection-only parse is marked unverified' );
    my $verified
        = parse_head( $flat_head, $kind, verify => \&verify_signature );
    is( $verified->{'verified'}, 1, 'verified parse is marked verified' );
};

subtest 'strict head structure refusals' => sub {
    my $unknown = $flat_head;
    $unknown =~ s|^pub |extra = value\npub |m;
    refusal(
        'unknown key',
        sub { parse_head( $unknown, $kind ) },
        qr|unknown key|
    );

    my $missing = $flat_head;
    $missing =~ s|^seq .*\n||m;
    refusal(
        'missing key',
        sub { parse_head( $missing, $kind ) },
        qr|missing or reordered key|
    );

    my $repeated = $flat_head;
    my $seq_line = field_line( $flat_head, 'seq' );
    $repeated =~ s|^\Q$seq_line\E|$seq_line$seq_line|m;
    refusal(
        'repeated key',
        sub { parse_head( $repeated, $kind ) },
        qr|repeated key|
    );

    my @lines = split m|(?<=\n)|, $flat_head;
    ( $lines[2], $lines[3] ) = ( $lines[3], $lines[2] );
    my $reordered = join '', @lines;
    refusal(
        'reordered keys',
        sub { parse_head( $reordered, $kind ) },
        qr|missing or reordered key|
    );

    refusal(
        'too little key padding',
        sub {
            parse_head( set_line( $flat_head, 'seq', 'seq  = 1042' ), $kind );
        },
        qr|bad padding|,
    );
    refusal(
        'too much key padding',
        sub {
            parse_head( set_line( $flat_head, 'seq', 'seq     = 1042' ),
                $kind );
        },
        qr|bad padding|,
    );
    refusal(
        'second space after separator',
        sub { parse_head( set_value( $flat_head, 'seq', ' 1042' ), $kind ) },
        qr|second separator space|,
    );
    refusal(
        'trailing value space',
        sub { parse_head( set_value( $flat_head, 'note', 'text ' ), $kind ) },
        qr|trailing space|,
    );
    my $cr = set_line( $flat_head, 'seq', "seq   = 1042\r" );
    refusal(
        'CR in head',
        sub { parse_head( $cr, $kind ) },
        qr|non-ASCII, CR|
    );
    refusal(
        'missing final LF',
        sub { parse_head( substr( $flat_head, 0, -1 ), $kind ) },
        qr|missing final LF|,
    );
    refusal(
        'empty value',
        sub { parse_head( set_value( $flat_head, 'note', '' ), $kind ) },
        qr|empty value|,
    );
    refusal(
        'base32 text where bare was allowed',
        sub {
            parse_head(
                set_value(
                    $flat_head, 'note',
                    q|:| . encode_b32r('plain ASCII text')
                ),
                $kind,
            );
        },
        qr|base32 where bare|,
    );
    refusal(
        'wrong label',
        sub {
            my $copy = $flat_head;
            $copy =~ s|journal|journey|;
            parse_head( $copy, $kind );
        },
        qr|wrong or malformed label|,
    );
    refusal(
        'malformed label',
        sub {
            my $copy = $flat_head;
            $copy =~ s|^p7 |p7  |;
            parse_head( $copy, $kind );
        },
        qr|wrong or malformed label|,
    );
    refusal(
        'missing label',
        sub {
            my $copy = $flat_head;
            $copy =~ s|^[^\n]*\n||;
            parse_head( $copy, $kind );
        },
        qr|wrong or malformed label|,
    );
    refusal(
        'extra empty head line',
        sub { parse_head( "$flat_head\n", $kind ) },
        qr|second closing empty line|,
    );
};

subtest 'strict value types and canonical base32' => sub {
    my @bad = (
        [ 'count leading zeros', 'seq', '01042',       qr|canonical count| ],
        [ 'count float',         'seq', '1.5',         qr|canonical count| ],
        [ 'count sign',          'seq', '+1',          qr|canonical count| ],
        [ 'stamp too short',     'at',  '31703855078', qr|14 digit stamp| ],
        [ 'decimal leading zeros',    'epoch-num', '01.2', qr|decimal text| ],
        [ 'decimal missing fraction', 'epoch-num', '1.',   qr|decimal text| ],
        [ 'bad word',                 'operation', 'Node', qr|bad word| ],
        [ 'bad address', 'disk', 'not-an-address', qr|canonical address| ],
        [ 'short key',   'pub',  'AA',             qr|decodes to| ],
        [ 'short signature',             'sig',     'AA',    qr|decodes to| ],
        [ 'base32 padding character',    'payload', 'AP74=', qr|base32| ],
        [ 'base32 lowercase',            'payload', 'ap74',  qr|base32| ],
        [ 'base32 nonzero padding bits', 'payload', 'AB', qr|padding bits| ],
        [ 'unsorted list', 'tags', 'beta,alpha', qr|unsorted or repeated| ],
        [   'repeated list item', 'tags',
            'alpha,alpha',        qr|unsorted or repeated|
        ],
        [ 'unknown flag', 'flags', 'unknown', qr|unknown word| ],
        [   'unsorted pairs',               'links',
            'photos:BBB,' . 'incoming:AAA', qr|unsorted|
        ],
        [   'repeated pair key',         'links',
            'incoming:AAA,incoming:BBB', qr|repeated pair key|
        ],
    );
    for my $case (@bad) {
        my ( $name, $key, $value, $expected ) = @{$case};
        refusal(
            $name,
            sub { parse_head( set_value( $flat_head, $key, $value ), $kind ) }
            ,
            $expected,
        );
    }
    refusal(
        'unknown key on pack',
        sub { pack_head( $kind, { %{$flat_values}, unknown => 1 } ) },
        qr|unknown key|,
    );
    refusal(
        'missing key on pack',
        sub {
            my %copy = %{$flat_values};
            delete $copy{'seq'};
            pack_head( $kind, \%copy );
        },
        qr|missing key|,
    );
    refusal(
        'bad reference type on pack',
        sub { pack_head( $kind, { %{$flat_values}, seq => [] } ) },
        qr|expects a scalar|,
    );
};

subtest 'signature tamper and domain separation' => sub {
    refusal(
        'stored head byte tamper',
        sub {
            parse_head(
                set_value( $flat_head, 'note', 'tampered text' ), $kind,
                pub    => $pub,
                verify => \&verify_signature,
            );
        },
        qr|signature does not match|,
    );
    refusal(
        'stored pub differs from caller key',
        sub {
            parse_head(
                $flat_head, $kind,
                pub    => "\x24" x 32,
                verify => \&verify_signature,
            );
        },
        qr|stored pub differs|,
    );
    for my $variant (
        [ domain  => 'p7 nrt journal v4',  'p7 n7fs journal v4' ],
        [ kind    => 'p7 n7fs other v4',   'p7 n7fs journal v4' ],
        [ version => 'p7 n7fs journal v5', 'p7 n7fs journal v4' ],
    ) {
        my ( $name, $new_label, $old_label ) = @{$variant};
        my $other_kind = { %{$kind}, label => $new_label };
        my $copy       = $flat_head;
        $copy =~ s|^\Q$old_label\E|$new_label|;
        refusal(
            "signature does not cross $name",
            sub {
                parse_head( $copy, $other_kind,
                    verify => \&verify_signature );
            },
            qr|signature does not match|,
        );
    }
};

subtest 'body binding, lazy rows and both body shapes' => sub {
    my $list = AMOS7::cell::canon::list->new(
        $operations, $body,
        rows => 2,
        body => bmw384_b32($body),
    );
    is( $list->count, 2, 'operation row count' );
    is_deeply(
        $list->row(0),
        [ '- release', $address_b ],
        'ordered operation row decoded'
    );
    is_deeply(
        $list->row(1),
        [ '+ node', $address_a, "meta\nbytes" ],
        'row text is base32 on disk and raw bytes on access'
    );
    unlike( $body, qr|meta\nbytes|,
        'body never carries bare row text bytes' );
    is( pack_body( $operations, $list->rows ),
        $body, 'raw body rows pack byte equal' );

    my $tampered = $body;
    substr( $tampered, -2, 1 )
        = substr( $tampered, -2, 1 ) eq q|A| ? q|B| : q|A|;
    refusal(
        'changed body byte fails BMW384 binding',
        sub {
            AMOS7::cell::canon::list->new(
                $operations, $tampered,
                rows => 2,
                body => bmw384_b32($body),
            );
        },
        qr|BMW384 binding|,
    );
    refusal(
        'wrong rows value',
        sub {
            AMOS7::cell::canon::list->new(
                $operations, $body,
                rows => 3,
                body => bmw384_b32($body),
            );
        },
        qr|wrong row count|,
    );
    my $wrong_order = join '', reverse split m|(?<=\n)|, $body;
    refusal(
        'fixed operation class order',
        sub { AMOS7::cell::canon::list->new( $operations, $wrong_order ) },
        qr|fixed class order|,
    );
    refusal(
        'missing body final LF',
        sub {
            AMOS7::cell::canon::list->new( $operations,
                substr( $body, 0, -1 ) );
        },
        qr|missing final LF|,
    );

    my $table = {
        shape   => 'table',
        columns => [
            field( 'address', 'address' ),
            field( 'text',    'text' ),
            field( 'count',   'count' ),
        ],
    };
    my @table_rows = sort { join( q| |, @{$a} ) cmp join( q| |, @{$b} ) }
        [ $address_a, 'alpha', 2 ], [ $address_b, "line\n", 0 ];
    my $table_body = pack_body( $table, \@table_rows );
    my $table_list = AMOS7::cell::canon::list->new( $table, $table_body );
    is( scalar keys $table_list->index->%*, 2,
        'table index has unique keys' );
    is( $table_list->row($address_a)->[1],
        'alpha', 'only the requested table row is decoded' );

    my @table_lines = split m|(?<=\n)|, $table_body;
    refusal(
        'unsorted table rows',
        sub {
            AMOS7::cell::canon::list->new( $table,
                join( '', reverse @table_lines ) );
        },
        qr|unsorted table rows|,
    );
    refusal(
        'repeated first table column during pack',
        sub {
            pack_body( $table,
                [ [ $address_a, 'alpha', 2 ], [ $address_a, 'beta', 3 ] ],
            );
        },
        qr|repeated table key|,
    );
};

subtest 'table duplicates and lazy type refusal' => sub {
    my $table = {
        shape   => 'table',
        columns =>
            [ field( 'address', 'address' ), field( 'count', 'count' ), ],
    };
    my $row_a = "$address_a 1\n";
    my $row_b = "$address_a 2\n";
    refusal(
        'repeated first table column',
        sub { AMOS7::cell::canon::list->new( $table, $row_a . $row_b ) },
        qr|repeated table key|,
    );
    my $bad_count = "$address_a 02\n";
    my $lazy      = AMOS7::cell::canon::list->new( $table, $bad_count );
    ok( $lazy, 'index does not decode every row value' );
    refusal(
        'touched row refuses its bad type',
        sub { $lazy->row($address_a) },
        qr|canonical count|,
    );
    refusal(
        'strict whole body walk refuses bad spacing',
        sub {
            AMOS7::cell::canon::list->new( $table, "$address_a  1\n" )
                ->validate;
        },
        qr|bad bytes, spacing|,
    );
};

subtest 'new files carry no forbidden codec imports' => sub {
    for my $path (
        qw| data/lib-path/pm/AMOS7/cell/canon.pm
        data/lib-path/pm/AMOS7/cell/canon/list.pm |
    ) {
        open( my $fh, '<:raw', "$FindBin::Bin/../../$path" ) or die $OS_ERROR;
        local $INPUT_RECORD_SEPARATOR;
        my $source = <$fh>;
        unlike( $source, qr|JSON::|i,      "$path has no json module" );
        unlike( $source, qr|Digest::SHA|i, "$path has no sha module" );
    }
    open( my $self, '<:raw', __FILE__ ) or die $OS_ERROR;
    local $INPUT_RECORD_SEPARATOR;
    my $source             = <$self>;
    my ($before_benchmark) = split m|^sub run_benchmark|m, $source, 2;
    my $comparison_codec   = join q|::|, qw| JSON XS |;
    unlike( $before_benchmark, qr|\Q$comparison_codec\E|,
        "$comparison_codec occurs only inside the benchmark comparison" );
};

sub run_benchmark {
    my $repeat     = $ENV{'CANON_BENCH_REPEAT'} // 3;
    my $shard_spec = {
        shape   => 'table',
        columns => [
            field( 'address',  'address' ),
            field( 'category', 'word', pattern => qr|[a-z]+| ),
            field( 'wrap-a',   'octets' ),
            field( 'wrap-b',   'octets' ),
            field( 'wrap-c',   'octets' ),
            field( 'meta',     'octets' ),
        ],
    };
    my @shards;
    my $entry = 0;
    for my $shard ( 0 .. 1023 ) {
        my @objects;
        for ( 0 .. 89 ) {
            my $serial  = pack q|N|, $entry;
            my $raw     = $serial x 12;
            my $address = 'V7AAAAA/AAAAAAA/' . encode_b32r($raw);
            my @wraps   = map { encode_b32r( $_ x 12 ) }
                ( $serial, $serial, $serial );
            my $meta = encode_b32r( ( $serial x 16 ) . ( $serial x 16 ) );
            push @objects,
                {
                address  => $address,
                category => 'photos',
                wraps    => {
                    incoming => $wraps[0],
                    local    => $wraps[1],
                    vault    => $wraps[2],
                },
                meta => $meta,
                };
            $entry++;
        }
        @objects = sort { $a->{'address'} cmp $b->{'address'} } @objects;
        my @rows = map {
            join q| |,
                $ARG->{'address'},
                $ARG->{'category'},
                $ARG->{'wraps'}{'incoming'},
                $ARG->{'wraps'}{'local'},
                $ARG->{'wraps'}{'vault'},
                $ARG->{'meta'};
        } @objects;
        my $body = join '', map {"$ARG\n"} @rows;
        push @shards, { objects => \@objects, rows => \@rows, body => $body };
    }

    require JSON::XS;
    my $codec = JSON::XS->new->canonical;
    $_->{'encoded'} = $codec->encode( $_->{'objects'} ) for @shards;
    my $body_bytes    = 0;
    my $encoded_bytes = 0;
    $body_bytes    += length $_->{'body'}    for @shards;
    $encoded_bytes += length $_->{'encoded'} for @shards;

    my $timer = sub {
        my $code = shift;
        my $best;
        for ( 1 .. $repeat ) {
            my $start   = time;
            my $worked  = $code->();
            my $elapsed = time - $start;
            die 'benchmark work count mismatch' if $worked != 92160;
            $best = $elapsed if not defined $best or $elapsed < $best;
        }
        return $best;
    };

    my $decoded;
    my $decode_time = $timer->(
        sub {
            $decoded = [ map { $codec->decode( $_->{'encoded'} ) } @shards ];
            my $count = 0;
            $count += $ARG->@* for @{$decoded};
            return $count;
        }
    );
    my $index_time = $timer->(
        sub {
            my $count = 0;
            for my $shard (@shards) {
                my $list = AMOS7::cell::canon::list->new( $shard_spec,
                    $shard->{'body'} );
                $count += keys $list->index->%*;
            }
            return $count;
        }
    );
    my $flat_time = $timer->(
        sub {
            my $count = 0;
            for my $shard (@shards) {
                for my $row ( split m|\n|, $shard->{'body'} ) {
                    my @fields = split q| |, $row;
                    $count++ if @fields == 6;
                }
            }
            return $count;
        }
    );
    my $strict_time = $timer->(
        sub {
            my $count = 0;
            for my $shard (@shards) {
                my $list = AMOS7::cell::canon::list->new( $shard_spec,
                    $shard->{'body'} );
                $list->validate_shape;
                $count += keys $list->index->%*;
            }
            return $count;
        }
    );
    my $nested_time = $timer->(
        sub {
            my $count = 0;
            for my $shard (@shards) {
                my $list = AMOS7::cell::canon::list->new( $shard_spec,
                    $shard->{'body'} );
                my %nested;
                for my $row ( $list->rows->@* ) {
                    my @fields = split q| |, $row;
                    $nested{ $fields[0] } = {
                        category => $fields[1],
                        wraps    => {
                            incoming => $fields[2],
                            local    => $fields[3],
                            vault    => $fields[4],
                        },
                        meta => $fields[5],
                    };
                }
                $count += keys %nested;
            }
            return $count;
        }
    );
    my $encode_time = $timer->(
        sub {
            my $count = 0;
            for my $shard ( @{$decoded} ) {
                my $encoded = $codec->encode($shard);
                $count += $shard->@* if length $encoded;
            }
            return $count;
        }
    );
    my $table_encode_time = $timer->(
        sub {
            my $count = 0;
            for my $shard (@shards) {
                my $body = pack_body( $shard_spec, $shard->{'rows'} );
                $count += $shard->{'rows'}->@* if length $body;
            }
            return $count;
        }
    );

    diag sprintf 'benchmark : 1024 shards, 92160 entries, %.1f '
        . 'MiB table, %.1f MiB comparison, best of %d',
        $body_bytes / 1048576, $encoded_bytes / 1048576, $repeat;
    diag sprintf 'benchmark seconds : comparison decode %.4f; lazy index '
        . '%.4f; flat row walk %.4f; strict index %.4f; nested '
        . 'rebuild %.4f; comparison encode %.4f; table encode ' . '%.4f',
        $decode_time, $index_time, $flat_time, $strict_time, $nested_time,
        $encode_time, $table_encode_time;
    ok( $index_time <= $decode_time,
        sprintf 'lazy row index is not slower than '
            . 'comparison decode [ %.4f <= %.4f ]',
        $index_time,
        $decode_time
    );
    ok( $flat_time <= $decode_time,
        sprintf 'flat row walk is not slower than '
            . 'comparison decode [ %.4f <= %.4f ]',
        $flat_time,
        $decode_time
    );
}

subtest '1024 shard benchmark' => \&run_benchmark;

done_testing;

#,,,,,.,.,,,,,,,.,.,,,,,,,,..,,,,,,,.,,,,,,..,..,,...,...,...,,.,,...,,.,,,.,,
#W3SUUMTHD5XPLLJC77SC5VG3UCVTCL2SVPCODEJIODGQJTO35KVYIPUIGWJDWM67CRFZNX6XIDNWA
#\\\|WAI3SVZQX7LAYGSFE4X2GLL2QT7JI5XGCM4NOEBRKCSTMWIUZVH \ / AMOS7 \ YOURUM ::
#\[7]APJVQF4J65RTJ62VWVD75L42KU5V7SI66EWBT54EWJL6TROLQSAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
