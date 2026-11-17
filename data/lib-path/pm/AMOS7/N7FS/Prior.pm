package AMOS7::N7FS::Prior;
our $VERSION = qw| AMOS7::N7FS::Prior-VERSION.ICWXDUY |;

use v5.32.0;
use strict;
use English;
use warnings;

use Exporter;
use base qw| Exporter |;
use vars qw| @EXPORT_OK |;

use JSON::PP;
use AMOS7::B32       qw| encode_b32r decode_b32r |;
use AMOS7::N7FS::Sum qw| amos_of_bytes |;

@EXPORT_OK = qw| read read_id |;

my $JSON = JSON::PP->new->utf8->canonical;

my %MAGIC = (
    id            => 'P7FS',
    mount         => 'P7FA',
    use           => 'P7FU',
    state         => 'P7FT',
    meta          => 'P7FN',
    journal       => 'P7FJ',
    reference     => 'P7FR',
    drop          => 'P7FD',
    tombstone     => 'P7FX',
    tree          => 'P7FM',
    tree_drop     => 'P7FL',
    category      => 'P7FC',
    assignment    => 'P7FB',
    batch         => 'P7FI',
    sync_cursor   => 'P7FY',
    sync_conflict => 'P7FZ',
    hold          => 'P7FH',
);

my %LABEL = (
    id    => { 1 => 'p7 n7fs disk id v1' },
    mount => { 1 => 'p7 n7fs mount v1' },
    use   => { 1 => 'p7 n7fs use window v1' },
    state => {
        1 => 'p7 n7fs state v1',
        2 => 'p7 n7fs state:0001',
        3 => 'p7 n7fs state:0001',
    },
    meta => {
        1 => 'p7 n7fs meta v1',
        2 => 'p7 n7fs meta:0001',
        3 => 'p7 n7fs meta:0001',
    },
    journal       => { 3 => 'p7 n7fs journal:0001' },
    reference     => { 3 => 'p7 n7fs reference:0001' },
    drop          => { 3 => 'p7 n7fs reference drop:0001' },
    tombstone     => { 3 => 'p7 n7fs tombstone:0001' },
    tree          => { 3 => 'p7 n7fs tree:0001' },
    tree_drop     => { 3 => 'p7 n7fs tree drop:0001' },
    category      => { 3 => 'p7 n7fs category:0001' },
    assignment    => { 3 => 'p7 n7fs category assignment:0001' },
    batch         => { 3 => 'p7 n7fs category batch:0001' },
    sync_cursor   => { 3 => 'p7 n7fs sync cursor:0001' },
    sync_conflict => { 3 => 'p7 n7fs sync conflict:0001' },
    hold          => { 3 => 'p7 n7fs hold:0001' },
);

my %RAW = map { $ARG => 1 } qw|
    manifest seal-root-binding sealed-head map-root map-shard map-tree-blob
    manifest-index manifest-chunk sealed-journal receipt drill covered-cache
    seal-state reservation pending-key request-counter relay-pending
    vault-registry root-file relay-list
    |;

sub _refuse {
    my $message = shift;
    $message = sprintf $message, @ARG if @ARG;
    die "n7fs prior : $message\n";
}

sub _decode {
    my ( $kind, $bytes ) = @ARG;
    my $data = eval { $JSON->decode($bytes) };
    _refuse( '%s payload is not valid json', $kind ) if $EVAL_ERROR;
    return $data;
}

sub _object {
    my ( $kind, $bytes ) = @ARG;
    my $data = _decode( $kind, $bytes );
    _refuse( '%s payload is not an object', $kind ) if ref $data ne q|HASH|;
    return $data;
}

sub _b32 {
    my ( $kind, $field, $encoded, $length ) = @ARG;
    _refuse( '%s %s is not base32', $kind, $field )
        if ( $encoded // '' ) !~ m|\A[A-Z2-7]+\z|;
    my $decoded = decode_b32r($encoded);
    _refuse( '%s %s has noncanonical base32', $kind, $field )
        if not defined $decoded
        or encode_b32r($decoded) ne $encoded;
    _refuse( '%s %s has the wrong decoded length', $kind, $field )
        if defined $length and length($decoded) != $length;
    return $decoded;
}

sub _verified {
    my ( $kind, $record, %opt ) = @ARG;
    my $signed = exists $record->{'signer_pub'};
    _refuse( '%s requires verify or explicit unverified', $kind )
        if $signed
        and not defined $opt{'verify'}
        and not $opt{'unverified'};
    if ( defined $opt{'pub'} ) {
        _refuse( '%s has no stored signer key', $kind ) if not $signed;
        _refuse( '%s signer differs from the caller key', $kind )
            if $record->{'signer_pub'} ne $opt{'pub'};
    }
    if ( defined $opt{'verify'} ) {
        _refuse( '%s verify callback is not code', $kind )
            if ref $opt{'verify'} ne q|CODE|;
        _refuse( '%s is unsigned',               $kind ) if not $signed;
        _refuse( '%s signature does not verify', $kind )
            if
            not $opt{'verify'}->( @{$record}{qw| signer_pub signed sig |} );
        $record->{'verified'} = 1;
    } else {
        $record->{'verified'} = 0;
    }
    return $record;
}

sub _container {
    my ( $kind, $bytes, %opt ) = @ARG;
    _refuse( 'unknown binary record kind [ %s ]', $kind )
        if not exists $MAGIC{$kind};
    _refuse( '%s record is frozen and has its own reader', $kind )
        if $kind eq q|id|;
    _refuse( '%s record bytes are missing', $kind )
        if ref $bytes or not defined $bytes;
    _refuse( '%s record is too short',  $kind ) if length $bytes < 11;
    _refuse( '%s record has bad magic', $kind )
        if substr( $bytes, 0, 4 ) ne $MAGIC{$kind};
    my $format = unpack q|C|, substr( $bytes, 4, 1 );
    my $label  = $LABEL{$kind}{$format}
        // _refuse( '%s record format %d is unknown', $kind, $format );
    my $signed       = $kind !~ m{\A(?:state|meta)\z} || $format >= 2;
    my $pos          = 5;
    my $label_length = unpack q|n|, substr( $bytes, $pos, 2 );
    $pos += 2;
    _refuse( '%s record has a truncated label', $kind )
        if $pos + $label_length + 4 > length $bytes;
    _refuse( '%s record has the wrong label', $kind )
        if substr( $bytes, $pos, $label_length ) ne $label;
    $pos += $label_length;
    my $payload_length = unpack q|N|, substr( $bytes, $pos, 4 );
    $pos += 4;
    my $tail = $signed ? 96 : 0;
    _refuse( '%s record length does not match', $kind )
        if $pos + $payload_length + $tail != length $bytes;
    my $payload = _object( $kind, substr( $bytes, $pos, $payload_length ) );
    $pos += $payload_length;
    my $record = {
        kind    => $kind,
        format  => $format,
        payload => $payload,
        bytes   => $bytes,
    };

    if ($signed) {
        $record->{'signer_pub'} = substr( $bytes, $pos,      32 );
        $record->{'sig'}        = substr( $bytes, $pos + 32, 64 );
        $record->{'signed'}     = substr( $bytes, 0,         $pos + 32 );
    }
    return _verified( $kind, $record, %opt );
}

sub read_id {
    my ( $bytes, %opt ) = @ARG;
    _refuse('id record bytes are missing')
        if ref $bytes or not defined $bytes;
    my $label  = 'p7 n7fs disk id v1';
    my $prefix = "P7FS\x01" . pack( q|n|, length $label ) . $label;
    my $string = qr{(?:[\x20-\x21\x23-\x5b\x5d-\x7e]|\\[\"\\])*};
    my $fields
        = qq|"init_ntime":"([0-9]{14})","intent":"($string)",|
        . qq|"name":"($string)","store_pub":"([A-Z2-7]{52})"|;
    my $pattern = qr|\A\Q$prefix\E(.{4})\{$fields\}(.{32})(.{64})\z|s;
    my ( $length, $init, $intent, $name, $store, $pub, $sig )
        = $bytes =~ $pattern;
    _refuse('id record does not match the frozen format 1 pattern')
        if not defined $sig;
    _refuse('id record payload length does not match')
        if unpack( q|N|, $length ) != length($bytes) - length($prefix) - 100;

    for my $value ( $intent, $name ) {
        $value =~ s|\\([\"\\])|$1|g;
    }
    _refuse('id record has a changed or invalid store key')
        if length( _b32( qw| id store_pub |, $store, 32 ) ) != 32;
    my $record = {
        kind    => q|id|,
        format  => 1,
        payload => {
            init_ntime => $init,
            intent     => $intent,
            name       => $name,
            store_pub  => $store,
        },
        bytes      => $bytes,
        disk       => amos_of_bytes($bytes),
        signer_pub => $pub,
        sig        => $sig,
        signed     => substr( $bytes, 0, length($bytes) - 64 ),
    };
    return _verified( q|id|, $record, %opt );
}

sub _manifest {
    my ( $bytes, %opt ) = @ARG;
    _refuse('manifest bytes are missing') if not defined $bytes;
    my @lines = split m|(?<=\n)|, $bytes;
    _refuse('manifest is empty or has no final LF')
        if not @lines
        or $lines[-1] !~ m|\n\z|;
    my $head = _object( 'manifest header', shift @lines );
    my @entries;
    for my $line (@lines) {
        _refuse('manifest entry is empty') if $line eq "\n";
        push @entries, _object( 'manifest entry', $line );
    }
    return {
        kind     => q|manifest|,
        payload  => { header => $head, entries => \@entries },
        bytes    => $bytes,
        verified => 0,
    };
}

sub _seal_binding {
    my ( $bytes, %opt ) = @ARG;
    my $binding = _object( qw| seal-root-binding |, $bytes );
    my $pub     = _b32( qw| seal-root-binding pub |, $binding->{'pub'}, 32 );
    my $sig     = _b32( qw| seal-root-binding sig |, $binding->{'sig'}, 64 );
    my $signed
        = "p7 n7fs disk seal binding v1\0"
        . ( $binding->{'disk'}    // '' ) . "\0"
        . ( $binding->{'root_id'} // '' );
    return _verified(
        q|seal-root-binding|,
        {   kind       => q|seal-root-binding|,
            payload    => $binding,
            bytes      => $bytes,
            signer_pub => $pub,
            sig        => $sig,
            signed     => $signed,
        },
        %opt
    );
}

sub _nested_signed {
    my ( $kind, $outer_key, $domain, $bytes, %opt ) = @ARG;
    my $outer   = _object( $kind, $bytes );
    my $payload = $outer->{$outer_key};
    _refuse( '%s signed payload is not an object', $kind )
        if ref $payload ne q|HASH|;
    my $pub    = _b32( $kind, q|pub|, $outer->{'pub'}, 32 );
    my $sig    = _b32( $kind, q|sig|, $outer->{'sig'}, 64 );
    my $signed = $domain . $JSON->encode($payload);
    return _verified(
        $kind,
        {   kind       => $kind,
            payload    => $payload,
            outer      => $outer,
            bytes      => $bytes,
            signer_pub => $pub,
            sig        => $sig,
            signed     => $signed,
        },
        %opt
    );
}

sub _sealed_head {
    my ( $bytes, %opt ) = @ARG;
    my $head   = _object( qw| sealed-head |, $bytes );
    my $pub    = _b32( qw| sealed-head pub |, $head->{'pub'}, 32 );
    my $sig    = _b32( qw| sealed-head sig |, $head->{'sig'}, 64 );
    my $signed = { %{$head} };
    delete $signed->{'sig'};
    return _verified(
        q|sealed-head|,
        {   kind       => q|sealed-head|,
            payload    => $head,
            bytes      => $bytes,
            signer_pub => $pub,
            sig        => $sig,
            signed     => $JSON->encode($signed),
        },
        %opt
    );
}

sub _request {
    my ( $token, %opt ) = @ARG;
    my ( $body_b32, $sig_b32 )
        = ( $token // '' ) =~ m|\A([A-Z2-7]+)[.]([A-Z2-7]+)\z|;
    _refuse('holder-request token is invalid') if not defined $sig_b32;
    my $body   = _b32( qw| holder-request body |, $body_b32 );
    my $sig    = _b32( qw| holder-request sig |,  $sig_b32, 64 );
    my $domain = "p7 n7fs holder request v1\0";
    _refuse('holder-request token has the wrong domain')
        if substr( $body, 0, length $domain ) ne $domain;
    my $payload
        = _object( qw| holder-request |, substr( $body, length $domain ) );
    _refuse('holder-request arguments are not an object')
        if ref $payload->{'args'} ne q|HASH|;
    _refuse('holder-request needs the signer key as an option')
        if not defined $opt{'pub'} and not $opt{'unverified'};
    my $record = {
        kind       => q|holder-request|,
        payload    => $payload,
        bytes      => $token,
        signer_pub => $opt{'pub'},
        sig        => $sig,
        signed     => $body,
    };
    return _verified( q|holder-request|, $record, %opt );
}

sub _root_file {
    my ( $bytes, %opt ) = @ARG;
    _refuse('root-file bytes are missing') if not defined $bytes;
    if ( substr( $bytes, 0, 5 ) eq "P7RK\x02" ) {
        _refuse('root-file suite 2 header is truncated')
            if length $bytes < 33;
        my ( $t, $m, $p ) = unpack 'N N N', substr( $bytes, 5, 12 );
        return {
            kind     => q|root-file|,
            payload  => { kdf => 'argon2id', t => $t, m => $m, p => $p },
            salt     => substr( $bytes, 17, 16 ),
            secret   => substr( $bytes, 33 ),
            bytes    => $bytes,
            verified => 0,
        };
    }
    _refuse('root-file has bad magic or suite')
        if substr( $bytes, 0, 5 ) ne "P7RK\x01";
    my $length = unpack q|N|, substr( $bytes, 5, 4 );
    _refuse('root-file header is truncated') if length($bytes) < 9 + $length;
    my $head = _object( qw| root-file |, substr( $bytes, 9, $length ) );
    my $salt = _b32( qw| root-file salt |, $head->{'salt'}, 16 );
    return {
        kind     => q|root-file|,
        payload  => $head,
        salt     => $salt,
        secret   => substr( $bytes, 9 + $length ),
        bytes    => $bytes,
        verified => 0,
    };
}

sub read {
    my ( $kind, $bytes, %opt ) = @ARG;
    $kind //= '';
    return read_id( $bytes, %opt )           if $kind eq q|id|;
    return _container( $kind, $bytes, %opt ) if exists $MAGIC{$kind};
    return _manifest( $bytes, %opt )         if $kind eq q|manifest|;
    return _seal_binding( $bytes, %opt )     if $kind eq q|seal-root-binding|;
    return _sealed_head( $bytes, %opt )      if $kind eq q|sealed-head|;
    return _request( $bytes, %opt )          if $kind eq q|holder-request|;
    return _root_file( $bytes, %opt )        if $kind eq q|root-file|;
    return _nested_signed( q|receipt|, q|receipt|, "p7 n7fs receipt v2\0",
        $bytes, %opt )
        if $kind eq q|receipt|;
    return _nested_signed( q|drill|, q|drill|, "p7 n7fs drill v1\0",
        $bytes, %opt )
        if $kind eq q|drill|;
    _refuse( 'unknown prior record kind [ %s ]', $kind )
        if not $RAW{$kind};
    my $payload
        = $kind eq q|manifest-chunk|
        ? _decode( $kind, $bytes )
        : _object( $kind, $bytes );

    if ( $kind eq q|manifest-chunk| ) {
        _refuse('manifest-chunk payload is not an array')
            if ref $payload ne q|ARRAY|;
    }
    my $record = {
        kind     => $kind,
        payload  => $payload,
        bytes    => $bytes,
        verified => 0,
    };
    $record->{'raw_lines'} = join '',
        map { $JSON->encode($ARG) . "\n" } @{$payload}
        if $kind eq q|manifest-chunk|;
    return $record;
}

1;

#,,,.,,..,.,,,...,,.,,.,.,..,,...,,..,,.,,...,..,,...,...,...,.,,,,,.,..,,.,.,
#ZEHQXATZMYMCJZELCSVBNNWD3KZ64Y3GOSAGJ6F2ZTDSPXPHXCN3OXH6O34LTOVY2GUK7RFZCP5UK
#\\\|V5QHJ256U5FIKF5RY67QESE3TBT754ZF2JMFYVW4O4ZJ44OKLSH \ / AMOS7 \ YOURUM ::
#\[7]B2OG6HJVIZXHRZU7UMHMN6JUDEZQ6I76XAZDQBVAPT47NHIQE4CI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
