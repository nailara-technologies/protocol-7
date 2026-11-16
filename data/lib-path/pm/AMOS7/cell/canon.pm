package AMOS7::cell::canon;
our $VERSION = qw| AMOS7::cell::canon-VERSION.DGO2UDY |;

use v5.32.0;
use strict;
use English;
use warnings;

use Exporter;
use base qw| Exporter |;
use vars qw| @EXPORT_OK |;

use Digest::BMW;
use AMOS7::B32 qw| encode_b32r decode_b32r |;

@EXPORT_OK
    = qw| bmw384_b32 pack_head parse_head signed_bytes record_address |;

my %VALUE_TYPE = map { $ARG => 1 } qw|
    count stamp decimal word address key sig octets text list flags pairs
    |;

sub _refuse {
    my $message = shift;
    $message = sprintf $message, @ARG if @ARG;
    die "canon : $message\n";
}

sub bmw384_b32 {
    my $bytes = shift // '';
    return encode_b32r( Digest::BMW::bmw_384($bytes) );
}

sub _kind {
    my $kind = shift;
    _refuse('kind table is not a hash') if ref $kind ne q|HASH|;
    my $label = $kind->{'label'} // '';
    my ( $domain, $name, $version )
        = $label
        =~ m|\Ap7 ([a-z][a-z0-9-]*) ([a-z][a-z0-9-]*(?: [a-z][a-z0-9-]*)*) v([1-9][0-9]*)\z|;
    _refuse( 'kind table has a malformed label [ %s ]', $label )
        if not defined $version;
    _refuse('kind table has no ordered fields')
        if ref $kind->{'fields'} ne q|ARRAY|;

    my @fields = $kind->{'fields'}->@*;
    my ( %field, $width );
    for my $field (@fields) {
        _refuse('kind table field is not a hash') if ref $field ne q|HASH|;
        my $name = $field->{'name'} // '';
        my $type = $field->{'type'} // '';
        _refuse( 'kind table has a malformed key [ %s ]', $name )
            if $name !~ m|\A[a-z][a-z0-9-]*\z|;
        _refuse( 'kind table repeats key [ %s ]', $name ) if $field{$name};
        _refuse( 'kind table key %s has unknown type [ %s ]', $name, $type )
            if not $VALUE_TYPE{$type};
        $field{$name} = $field;
        $width = length $name if ( $width // 0 ) < length $name;
    }
    for my $index ( 0 .. $#fields ) {
        my $name = $fields[$index]{'name'};
        if ( $name eq q|sig| ) {
            _refuse('kind table sig is not the last key')
                if $index != $#fields;
            _refuse('kind table sig is not immediately after pub')
                if $index == 0
                or $fields[ $index - 1 ]{'name'} ne q|pub|;
        } elsif ( $name eq q|pub| ) {
            _refuse('kind table pub has no following sig')
                if $index == $#fields
                or $fields[ $index + 1 ]{'name'} ne q|sig|;
        }
    }
    return {
        kind    => $kind,
        domain  => $domain,
        name    => $name,
        version => $version,
        fields  => \@fields,
        field   => \%field,
        width   => $width // 0,
    };
}

sub _decode_b32 {
    my ( $name, $encoded, $bytes ) = @ARG;
    _refuse( 'key %s has noncanonical base32', $name )
        if $encoded !~ m|\A[A-Z2-7]+\z|;
    my $decoded = decode_b32r($encoded);
    _refuse( 'key %s has invalid base32', $name ) if not defined $decoded;
    _refuse( 'key %s has noncanonical base32 padding bits', $name )
        if encode_b32r($decoded) ne $encoded;
    _refuse( 'key %s decodes to %d bytes, expected %d',
        $name, length $decoded, $bytes )
        if defined $bytes and length $decoded != $bytes;
    return $decoded;
}

sub _bare_text {
    my $value = shift;
    return
           $value =~ m|\A[\x20-\x7e]+\z|
        && $value !~ m|\A |
        && $value !~ m| \z|
        && $value !~ m|\A:|
        && $value ne q|-|;
}

sub _word {
    my ( $field, $value ) = @ARG;
    my $name = $field->{'name'} // q|value|;
    _refuse( 'key %s has an empty word', $name ) if not length $value;
    _refuse( 'key %s has a word with separators', $name )
        if $value =~ m|[,\s:]|;
    if ( ref $field->{'words'} eq q|ARRAY| ) {
        my %allowed = map { $ARG => 1 } $field->{'words'}->@*;
        _refuse( 'key %s has unknown word [ %s ]', $name, $value )
            if not $allowed{$value};
    }
    if ( defined $field->{'pattern'} ) {
        my $pattern = $field->{'pattern'};
        _refuse( 'key %s has bad word [ %s ]', $name, $value )
            if $value !~ m|\A(?:$pattern)\z|;
    } elsif ( ref $field->{'words'} ne q|ARRAY|
        and $value !~ m|\A[a-z][a-z0-9-]*\z| ) {
        _refuse( 'key %s has bad word [ %s ]', $name, $value );
    }
    _refuse( 'key %s admits the absent marker as a word', $name )
        if $value eq q|-|;
    return $value;
}

sub _decode_value {
    my ( $field, $value, $in_row ) = @ARG;
    my ( $name, $type ) = @{$field}{qw| name type |};
    _refuse( 'key %s has an empty value', $name ) if not length $value;
    if ( $value eq q|-| ) {
        _refuse( 'key %s uses - instead of 0 for an absent value', $name )
            if $type eq q|count| or $type eq q|address|;
        return undef;
    }
    return $value if $type eq q|count| and $value =~ m|\A0\z|;
    return $value if $type eq q|count| and $value =~ m|\A[1-9][0-9]*\z|;
    _refuse( 'key %s is not a canonical count [ %s ]', $name, $value )
        if $type eq q|count|;
    return $value if $type eq q|stamp| and $value =~ m|\A[0-9]{14}\z|;
    _refuse( 'key %s is not a 14 digit stamp [ %s ]', $name, $value )
        if $type eq q|stamp|;
    if ( $type eq q|decimal| ) {
        return $value if $value =~ m|\A(?:0\|[1-9][0-9]*)\.[0-9]+\z|;
        _refuse( 'key %s is not canonical decimal text [ %s ]',
            $name, $value );
    }
    return _word( $field, $value ) if $type eq q|word|;
    if ( $type eq q|address| ) {
        return $value if $value eq q|0|;
        if ( $value =~ m|\A[A-Z2-7]{7}/[A-Z2-7]{7}/([A-Z2-7]{77})\z| ) {
            _decode_b32( $name, $1, 48 );
            return $value;
        }
        return $value
            if $value =~ m|\A[A-Z2-7]{77}\z|
            and encode_b32r( _decode_b32( $name, $value, 48 ) ) eq $value;
        _refuse( 'key %s is not a canonical address [ %s ]', $name, $value );
    }
    return _decode_b32( $name, $value, 32 ) if $type eq q|key|;
    return _decode_b32( $name, $value, 64 ) if $type eq q|sig|;
    return _decode_b32( $name, $value ) if $type eq q|octets|;
    if ( $type eq q|text| ) {
        if ($in_row) {
            return _decode_b32( $name, $value );
        } elsif ( $value =~ m|\A:| ) {
            _refuse( 'key %s has an empty base32 text value', $name )
                if length $value == 1;
            my $decoded = _decode_b32( $name, substr( $value, 1 ) );
            _refuse( 'key %s uses base32 where bare text was allowed', $name )
                if _bare_text($decoded);
            return $decoded;
        }
        _refuse( 'key %s is not canonical bare text [ %s ]', $name, $value )
            if not _bare_text($value);
        return $value;
    }
    if ( $type eq q|list| or $type eq q|flags| or $type eq q|pairs| ) {
        my @items = split m|,|, $value, -1;
        my ( $previous, %pair_key );
        for my $item (@items) {
            _refuse( 'key %s has an empty list item', $name )
                if not length $item;
            _refuse( 'key %s list is unsorted or repeated', $name )
                if defined $previous and $previous ge $item;
            if ( $type eq q|pairs| ) {
                my ( $left, $right, $extra ) = split m|:|, $item, -1;
                _refuse( 'key %s has a malformed pair [ %s ]', $name, $item )
                    if defined $extra or not defined $right;
                _word( $field, $left );
                _refuse( 'key %s has a repeated pair key [ %s ]',
                    $name, $left )
                    if $pair_key{$left}++;
                _refuse( 'key %s has a bad pair value [ %s ]', $name, $right )
                    if not length $right or $right =~ m|[,\s:]|;
            } else {
                _word( $field, $item );
            }
            $previous = $item;
        }
        return \@items;
    }
    _refuse( 'key %s has unknown type [ %s ]', $name, $type );
}

sub _encode_value {
    my ( $field, $value, $in_row ) = @ARG;
    my ( $name, $type ) = @{$field}{qw| name type |};
    if ( not defined $value ) {
        return q|0| if $type eq q|count| or $type eq q|address|;
        return q|-|;
    }
    _refuse( 'key %s expects a scalar value', $name )
        if ref $value and $type !~ m|\A(?:list\|flags\|pairs)\z|;
    if ( $type eq q|text| ) {
        return q|-|                       if not length $value;
        return encode_b32r($value)        if $in_row;
        return q|:| . encode_b32r($value) if not _bare_text($value);
        return $value;
    }
    if ( $type eq q|octets| ) {
        return q|-| if not length $value;
        return encode_b32r($value);
    }
    if ( $type eq q|key| or $type eq q|sig| ) {
        my $length = $type eq q|key| ? 32 : 64;
        _refuse( 'key %s expects %d raw bytes', $name, $length )
            if length $value != $length;
        return encode_b32r($value);
    }
    if ( $type eq q|list| or $type eq q|flags| ) {
        _refuse( 'key %s expects an array of words', $name )
            if ref $value ne q|ARRAY|;
        my @items = sort $value->@*;
        return q|-| if not @items;
        _word( $field, $ARG ) for @items;
        for my $index ( 1 .. $#items ) {
            _refuse( 'key %s list is repeated', $name )
                if $items[ $index - 1 ] eq $items[$index];
        }
        return join q|,|, @items;
    }
    if ( $type eq q|pairs| ) {
        _refuse( 'key %s expects an array of pairs', $name )
            if ref $value ne q|ARRAY|;
        my @items = sort $value->@*;
        return q|-| if not @items;
        my %seen;
        for my $item (@items) {
            my ( $left, $right, $extra ) = split m|:|, $item, -1;
            _refuse( 'key %s has a malformed pair [ %s ]', $name, $item )
                if defined $extra or not defined $right;
            _word( $field, $left );
            _refuse( 'key %s has a repeated pair key [ %s ]', $name, $left )
                if $seen{$left}++;
            _refuse( 'key %s has a bad pair value [ %s ]', $name, $right )
                if not length $right or $right =~ m|[,\s:]|;
        }
        for my $index ( 1 .. $#items ) {
            _refuse( 'key %s pair list is repeated', $name )
                if $items[ $index - 1 ] eq $items[$index];
        }
        return join q|,|, @items;
    }
    my $encoded = $value;
    _decode_value( $field, $encoded, $in_row );
    return $encoded;
}

sub _values {
    my ( $desc, $values ) = @ARG;
    _refuse('head values are not a hash') if ref $values ne q|HASH|;
    for my $name ( keys $values->%* ) {
        _refuse( 'unknown key [ %s ]', $name )
            if not exists $desc->{'field'}{$name};
    }
    for my $field ( $desc->{'fields'}->@* ) {
        my $name = $field->{'name'};
        _refuse( 'missing key [ %s ]', $name ) if not exists $values->{$name};
    }
}

sub _line {
    my ( $desc, $field, $value ) = @ARG;
    my $name    = $field->{'name'};
    my $encoded = _encode_value( $field, $value );
    return
          $name
        . ( q| | x ( $desc->{'width'} - length($name) ) ) . q| = |
        . $encoded . "\n";
}

sub _signed_bytes {
    my ( $desc, $values ) = @ARG;
    _values( $desc, $values );
    my $bytes = $desc->{'kind'}{'label'} . "\n";
    for my $field ( $desc->{'fields'}->@* ) {
        last if $field->{'name'} eq q|sig|;
        $bytes .= _line( $desc, $field, $values->{ $field->{'name'} } );
    }
    return $bytes;
}

sub signed_bytes {
    my ( $kind, $values ) = @ARG;
    return _signed_bytes( _kind($kind), $values );
}

sub _pack_all {
    my ( $desc, $values ) = @ARG;
    _values( $desc, $values );
    my $bytes = $desc->{'kind'}{'label'} . "\n";
    for my $field ( $desc->{'fields'}->@* ) {
        $bytes .= _line( $desc, $field, $values->{ $field->{'name'} } );
    }
    return $bytes . "\n";
}

sub pack_head {
    my ( $kind, $values, %opt ) = @ARG;
    my $desc = _kind($kind);
    _refuse('head values are not a hash') if ref $values ne q|HASH|;
    my %stored = $values->%*;
    if ( defined $opt{'signer'} ) {
        _refuse('signed kind table has no pub and sig keys')
            if not exists $desc->{'field'}{'pub'}
            or not exists $desc->{'field'}{'sig'};
        my $public = $opt{'signer'}->public;
        _refuse('signer public key is not 32 raw bytes')
            if not defined $public
            or length $public != 32;
        $stored{'pub'} = $public;
        $stored{'sig'} = "\0" x 64;
        my $signature
            = $opt{'signer'}->sign( _signed_bytes( $desc, \%stored ) );
        _refuse('signer signature is not 64 raw bytes')
            if not defined $signature
            or length $signature != 64;
        $stored{'sig'} = $signature;
    }
    return _pack_all( $desc, \%stored );
}

sub parse_head {
    my ( $bytes, $kind, %opt ) = @ARG;
    my $desc = _kind($kind);
    _refuse('record bytes are not a scalar')
        if ref $bytes or not defined $bytes;
    my $close = index( $bytes, "\n\n" );
    _refuse('missing final LF or closing empty line') if $close < 0;
    my $head = substr( $bytes, 0, $close + 2 );
    my $body = substr( $bytes, $close + 2 );
    _refuse('head has non-ASCII, CR, tab or BOM bytes')
        if $head !~ m|\A[\x0a\x20-\x7e]*\z|;
    _refuse('head has a second closing empty line')
        if length $body and substr( $body, 0, 1 ) eq "\n";

    my @lines = $head =~ m|.*\n|g;
    my $blank = pop @lines;
    _refuse('head does not end in exactly one empty line')
        if not defined $blank or $blank ne "\n";
    my $label = shift @lines // '';
    chomp $label;
    _refuse( 'wrong or malformed label [ %s ]', $label )
        if $label ne $desc->{'kind'}{'label'};

    my ( %values, %seen );
    for my $index ( 0 .. $#lines ) {
        my $line = $lines[$index];
        my ($name) = $line =~ m|\A([a-z][a-z0-9-]*)|;
        _refuse( 'malformed field line [ %s ]', $line ) if not defined $name;
        _refuse( 'repeated key [ %s ]',         $name ) if $seen{$name}++;
        my $field = $desc->{'field'}{$name}
            // _refuse( 'unknown key [ %s ]', $name );
        my $expected = $desc->{'fields'}[$index];
        _refuse( 'missing or reordered key [ expected %s, got %s ]',
            $expected->{'name'}, $name )
            if not defined $expected
            or $expected->{'name'} ne $name;
        my ( $padding, $value ) = $line =~ m|\A\Q$name\E( *)= ([^\n]*)\n\z|;
        _refuse( 'bad padding or separator for key [ %s ]', $name )
            if not defined $value;
        my $wanted = $desc->{'width'} - length($name) + 1;
        _refuse( 'bad padding for key %s [ got %d spaces, expected %d ]',
            $name, length $padding, $wanted )
            if length $padding != $wanted;
        _refuse( 'key %s has an empty value', $name ) if not length $value;
        _refuse( 'key %s has a second separator space or trailing space',
            $name )
            if $value =~ m|\A | or $value =~ m| \z|;
        $values{$name} = _decode_value( $field, $value );
    }
    if ( @lines < $desc->{'fields'}->@* ) {
        my $name = $desc->{'fields'}[ scalar @lines ]{'name'};
        _refuse( 'missing key [ %s ]', $name );
    }
    _refuse('too many field lines') if @lines > $desc->{'fields'}->@*;

    my $repacked = _pack_all( $desc, \%values );
    _refuse('head is not canonical when packed again') if $repacked ne $head;
    my $signed_rebuilt = _signed_bytes( $desc, \%values );
    my $signed_stored  = substr( $head, 0, length $signed_rebuilt );
    _refuse('stored signed bytes differ from canonical bytes')
        if $signed_stored ne $signed_rebuilt;

    my $signed_kind = exists $desc->{'field'}{'pub'}
        && exists $desc->{'field'}{'sig'};
    _refuse('signed record requires verify or explicit unverified')
        if $signed_kind
        and not defined $opt{'verify'}
        and not $opt{'unverified'};

    if ( defined $opt{'pub'} ) {
        _refuse('record has no stored pub') if not exists $values{'pub'};
        _refuse('stored pub differs from the caller key')
            if $values{'pub'} ne $opt{'pub'};
    }
    my $verified = 0;
    if ( defined $opt{'verify'} ) {
        _refuse('verify callback is not code')
            if ref $opt{'verify'} ne q|CODE|;
        _refuse('signed record has no pub and sig')
            if not exists $values{'pub'}
            or not exists $values{'sig'};
        _refuse('signature does not match the stored bytes')
            if not $opt{'verify'}
            ->( $values{'pub'}, $signed_stored, $values{'sig'} );
        $verified = 1;
    }

    ## inspection only : unverified must never be used on an accept path ##
    my $address_bytes = substr( $head, 0, length($head) - 1 );
    return {
        domain        => $desc->{'domain'},
        kind          => $desc->{'name'},
        version       => $desc->{'version'},
        label         => $desc->{'kind'}{'label'},
        values        => \%values,
        head_bytes    => $head,
        body_bytes    => $body,
        signed_bytes  => $signed_stored,
        address_bytes => $address_bytes,
        address       => bmw384_b32($address_bytes),
        verified      => $verified,
    };
}

sub record_address {
    my ( $record, $kind ) = @ARG;
    return $record->{'address'} // bmw384_b32( $record->{'address_bytes'} )
        if ref $record eq q|HASH| and exists $record->{'address_bytes'};
    _refuse('record address needs a kind table') if not defined $kind;
    return parse_head( $record, $kind, unverified => 1 )->{'address'};
}

1;

#,,,,,,,.,.,.,,..,,.,,...,,,,,.,.,,,.,...,,.,,..,,...,...,.,,,,,.,.,,,,,.,,,.,
#ZMN3IACHUIP5MZ6FDJ27DVRZF7HS6QN62VYX25SLXCXBYNJRMFVVOZZCTTY6NS3I52WHMKOEWYK72
#\\\|C4Q245B3GSX236WJNJXWH4R2HUR6KHA3DU45XROVAGGYPSK7TD6 \ / AMOS7 \ YOURUM ::
#\[7]RKARBYQTSBAJZSZPWEG64MGNPWSC4GUWAVAT4IVRJJUYS73RTOBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
