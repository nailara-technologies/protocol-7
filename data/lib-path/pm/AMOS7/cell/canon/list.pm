package AMOS7::cell::canon::list;
our $VERSION = qw| AMOS7::cell::canon::list-VERSION.YDYRZPA |;

use v5.32.0;
use strict;
use English;
use warnings;

use Exporter;
use base qw| Exporter |;
use vars qw| @EXPORT_OK |;

use AMOS7::cell::canon qw| bmw384_b32 |;

@EXPORT_OK = qw| pack_body index_body |;

sub _refuse {
    my $message = shift;
    $message = sprintf $message, @ARG if @ARG;
    die "canon body : $message\n";
}

sub _fields {
    my $fields = shift;
    _refuse('body columns are not an array') if ref $fields ne q|ARRAY|;
    my %seen;
    for my $field ( $fields->@* ) {
        _refuse('body column is not a hash') if ref $field ne q|HASH|;
        my $name = $field->{'name'} // '';
        _refuse( 'body has a malformed column name [ %s ]', $name )
            if $name !~ m|\A[a-z][a-z0-9-]*\z|;
        _refuse( 'body repeats column [ %s ]', $name ) if $seen{$name}++;
    }
    return $fields;
}

sub _spec {
    my $spec = shift;
    _refuse('body table is not a hash') if ref $spec ne q|HASH|;
    my $shape = $spec->{'shape'} // '';
    if ( $shape eq q|table| ) {
        _fields( $spec->{'columns'} );
        _refuse('table has no columns') if not $spec->{'columns'}->@*;
    } elsif ( $shape eq q|operations| ) {
        _refuse('operations classes are not an array')
            if ref $spec->{'classes'} ne q|ARRAY|
            or not $spec->{'classes'}->@*;
        my %seen;
        for my $class ( $spec->{'classes'}->@* ) {
            _refuse('operation class is not a hash') if ref $class ne q|HASH|;
            my $name = $class->{'name'} // '';
            _refuse( 'operation class is empty or repeated [ %s ]', $name )
                if not length $name or $seen{$name}++;
            _refuse( 'operation class has bad bytes [ %s ]', $name )
                if $name !~ m|\A[\x21-\x7e]+(?: [\x21-\x7e]+)*\z|;
            _fields( $class->{'fields'} );
        }
    } else {
        _refuse( 'unknown body shape [ %s ]', $shape );
    }
    _refuse( 'unknown fixed operation order [ %s ]', $spec->{'order'} )
        if defined $spec->{'order'} and $spec->{'order'} ne q|fixed|;
    return $spec;
}

sub _class {
    my ( $spec, $row ) = @ARG;
    my @classes = sort { length $b->{'name'} <=> length $a->{'name'} }
        $spec->{'classes'}->@*;
    for my $class (@classes) {
        my $name = $class->{'name'};
        return $class if $row eq $name or index( $row, "$name " ) == 0;
    }
    _refuse( 'unknown operation class in row [ %s ]', $row );
}

sub _check_row_bytes {
    my $row = shift;
    _refuse('empty body row') if not length $row;
    _refuse( 'body row has bad bytes, spacing or empty fields [ %s ]', $row )
        if $row !~ m|\A[\x21-\x7e]+(?: [\x21-\x7e]+)*\z|;
}

sub _check_binding {
    my ( $body, $opt ) = @ARG;
    my $count = () = $body =~ m|\n|g;
    if ( defined $opt->{'rows'} ) {
        _refuse( 'wrong row count [ stored %s, actual %d ]',
            $opt->{'rows'}, $count )
            if $opt->{'rows'} !~ m|\A(?:0\|[1-9][0-9]*)\z|
            or $opt->{'rows'} != $count;
    }
    if ( defined $opt->{'body'} ) {
        if ( not length $body ) {
            _refuse('nonempty body binding for an empty body')
                if $opt->{'body'} ne q|0|;
        } else {
            _refuse('body binding is not BMW384 base32')
                if $opt->{'body'} !~ m|\A[A-Z2-7]{77}\z|;
            _refuse('body bytes do not match the stored BMW384 binding')
                if bmw384_b32($body) ne $opt->{'body'};
        }
    }
}

sub new {
    my ( $class, $spec, $body, %opt ) = @ARG;
    $spec = _spec($spec);
    _refuse('body bytes are not a scalar') if ref $body or not defined $body;
    _refuse('body has a missing final LF')
        if length $body and $body !~ m|\n\z|;
    _check_binding( $body, \%opt );

    my @rows;
    if ( length $body ) {
        @rows = split m|\n|, $body, -1;
        pop @rows;
    }
    my $self = bless {
        spec  => $spec,
        body  => $body,
        rows  => \@rows,
        index => {},
    }, $class;

    my ( $previous, $previous_key, $class_index );
    for my $index ( 0 .. $#rows ) {
        my $row = $rows[$index];
        _refuse( 'empty body row at index %d', $index ) if not length $row;
        if ( $spec->{'shape'} eq q|table| ) {
            my $space = index( $row, q| | );
            my $key   = substr( $row, 0, $space < 0 ? length $row : $space );
            _refuse( 'unsorted table rows at index %d', $index )
                if defined $previous and $previous gt $row;
            _refuse( 'repeated table key [ %s ]', $key )
                if defined $previous_key and $previous_key ge $key;
            $self->{'index'}{$key} = $row;
            $previous_key = $key;
        } elsif ( defined $spec->{'order'} or $spec->{'sorted'} ) {
            my $operation = _class( $spec, $row );
            my $wanted    = 0;
            for my $candidate ( $spec->{'classes'}->@* ) {
                last if $candidate->{'name'} eq $operation->{'name'};
                $wanted++;
            }
            _refuse('operations body is outside its fixed class order')
                if defined $class_index and $wanted < $class_index;
            _refuse( 'operations class is not sorted [ %s ]',
                $operation->{'name'} )
                if $spec->{'sorted'}
                and defined $class_index
                and $wanted == $class_index
                and defined $previous
                and $previous gt $row;
            $class_index = $wanted;
        }
        $previous = $row;
    }
    return $self;
}

sub _parse_row {
    my ( $spec, $row, $shape_only ) = @ARG;
    _check_row_bytes($row);
    if ( $spec->{'shape'} eq q|table| ) {
        my @stored  = split q| |, $row, -1;
        my $columns = $spec->{'columns'};
        _refuse(
            'table row has %d fields, expected %d [ %s ]',
            scalar @stored,
            scalar $columns->@*, $row
        ) if @stored != $columns->@*;
        return 1 if $shape_only;
        my @values;
        for my $index ( 0 .. $#stored ) {
            $values[$index]
                = AMOS7::cell::canon::_decode_value( $columns->[$index],
                $stored[$index], 1 );
        }
        return \@values;
    }

    my $class  = _class( $spec, $row );
    my $name   = $class->{'name'};
    my $stored = substr( $row, length $name );
    $stored =~ s|\A ||;
    my @stored = length $stored ? split q| |, $stored, -1 : ();
    my $fields = $class->{'fields'};
    _refuse(
        'operation %s has %d fields, expected %d',
        $name,
        scalar @stored,
        scalar $fields->@*
    ) if @stored != $fields->@*;
    return 1 if $shape_only;
    my @values = ($name);

    for my $index ( 0 .. $#stored ) {
        push @values,
            AMOS7::cell::canon::_decode_value( $fields->[$index],
            $stored[$index], 1 );
    }
    return \@values;
}

sub row {
    my ( $self, $key ) = @ARG;
    my $row = $self->raw_row($key);
    _refuse( 'no row for key [ %s ]', $key ) if not defined $row;
    return _parse_row( $self->{'spec'}, $row );
}

sub raw_row {
    my ( $self, $key ) = @ARG;
    return $self->{'index'}{$key} if $self->{'spec'}{'shape'} eq q|table|;
    _refuse('operation row index is not a count') if $key !~ m|\A[0-9]+\z|;
    return $self->{'rows'}[$key];
}

sub rows  { return shift->{'rows'} }
sub body  { return shift->{'body'} }
sub index { return shift->{'index'} }
sub count { return scalar shift->{'rows'}->@* }

sub validate_shape {
    my $self = shift;
    _parse_row( $self->{'spec'}, $ARG, 1 ) for $self->{'rows'}->@*;
    return $self;
}

sub validate {
    my $self = shift;
    _parse_row( $self->{'spec'}, $ARG ) for $self->{'rows'}->@*;
    return $self;
}

sub _pack_row {
    my ( $spec, $row ) = @ARG;
    _refuse('body row is neither a raw string nor an array')
        if ref $row and ref $row ne q|ARRAY|;
    if ( not ref $row ) {
        _check_row_bytes($row);
        return $row;
    }
    if ( $spec->{'shape'} eq q|table| ) {
        my $columns = $spec->{'columns'};
        _refuse(
            'table row has %d values, expected %d',
            scalar $row->@*,
            scalar $columns->@*
        ) if $row->@* != $columns->@*;
        my @stored;
        for my $index ( 0 .. $row->$#* ) {
            $stored[$index]
                = AMOS7::cell::canon::_encode_value( $columns->[$index],
                $row->[$index], 1 );
        }
        return join q| |, @stored;
    }

    _refuse('operation row has no class') if not $row->@*;
    my $name = $row->[0] // '';
    my ($class) = grep { $ARG->{'name'} eq $name } $spec->{'classes'}->@*;
    _refuse( 'unknown operation class [ %s ]', $name ) if not defined $class;
    my $fields = $class->{'fields'};
    _refuse(
        'operation %s has %d values, expected %d',
        $name,
        scalar( $row->@* ) - 1,
        scalar $fields->@*
    ) if $row->@* - 1 != $fields->@*;
    my @stored;

    for my $index ( 1 .. $row->$#* ) {
        push @stored,
            AMOS7::cell::canon::_encode_value( $fields->[ $index - 1 ],
            $row->[$index], 1 );
    }
    return join q| |, $name, @stored;
}

sub pack_body {
    my ( $spec, $rows ) = @ARG;
    $spec = _spec($spec);
    _refuse('body rows are not an array') if ref $rows ne q|ARRAY|;
    my @stored = map { _pack_row( $spec, $ARG ) } $rows->@*;
    my $body   = @stored ? join( '', map {"$ARG\n"} @stored ) : '';
    return __PACKAGE__->new( $spec, $body )->body;
}

sub index_body {
    my ( $spec, $body ) = @ARG;
    return __PACKAGE__->new( $spec, $body )->index;
}

sub pack {
    my ( $self, $rows ) = @ARG;
    return pack_body( $self->{'spec'}, $rows );
}

1;

#,,..,.,.,,,,,,,,,.,,,.,.,,.,,.,.,..,,.,.,,..,..,,...,...,,,.,.,.,..,,.,,,...,
#U3PK3KWRE55HQJ4K2BO5X7WFNQTSHR5GQ4RXTEBPMRMOW4Y5NTDIR3XO4C7JZWWMKMIWNZN6HAS3S
#\\\|YQAJXND63LI6C4UUPUYNI7N47IM4WVTGBCRMAL2EBPA3QFIWQGX \ / AMOS7 \ YOURUM ::
#\[7]G3U3RANA4VWQDWFFATCTEGOFKS2V353UMMI4M66NVWFTRHDT2SCQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
