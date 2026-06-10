## [:< ##

# name  = base.slot.move
# descr = move a slot to a new surface and/or geometry
# param = { address, surface?, geometry? }

my $address  = $ARG[0]->{'address'} // '';
my $surface  = $ARG[0]->{'surface'};
my $geometry = $ARG[0]->{'geometry'};

return undef if not length $address;

## parse address for chksum7
my $chksum7;
if ( $address =~ m|^SLOT:([^:]+):| ) {
    $chksum7 = $1;
} else {
    warn 'expected slot address <{C1}>';
    return undef;
}

my $entry = <base.slots>->{$chksum7};
if ( not defined $entry ) {
    warn 'slot not found <{C1}>';
    return undef;
}

## canonicalize geometry defaults if provided
if ( defined $geometry ) {
    $geometry->{'row'}  //= 0;
    $geometry->{'col'}  //= 0;
    $geometry->{'cols'} //= 80;
    $geometry->{'rows'} //= 24;
}

my $old_surface = $entry->{'surface'};

## update surface and migrate render set membership
if ( defined $surface ) {
    $entry->{'surface'} = $surface;

    if ( defined $old_surface and defined $entry->{'geometry'} ) {
        delete <base.slots.surfaces>->{$old_surface}->{$chksum7}
            if exists <base.slots.surfaces>->{$old_surface};
    }

    if ( defined $geometry or defined $entry->{'geometry'} ) {
        <base.slots.surfaces>->{$surface} //= {};
        <base.slots.surfaces>->{$surface}->{$chksum7} = 1;
    }
}

## update geometry
if ( defined $geometry ) {
    $entry->{'geometry'}      = $geometry;
    $entry->{'last_geometry'} = $geometry;
    <base.slots.surfaces>->{ $entry->{'surface'} } //= {};
    <base.slots.surfaces>->{ $entry->{'surface'} }->{$chksum7} = 1;
}

## re-render bound content into new slot dimensions
if ( defined $entry->{'content_address'} and defined $entry->{'geometry'} ) {
    my $rendered = eval {
        <[base.ui.unfold]>->(
            {   'address'     => $entry->{'content_address'},
                'slot_budget' => {
                    'cols' => $entry->{'geometry'}->{'cols'},
                    'rows' => $entry->{'geometry'}->{'rows'}
                }
            }
        );
    };
    if (    defined $rendered
        and ref $rendered eq 'HASH'
        and exists $rendered->{'data'} ) {
        $entry->{'rendered'} = $rendered->{'data'};
    }
}

## return updated full address
my $stable = sprintf( qw| SLOT:%s:%s |, $chksum7, $entry->{'surface'} );
if ( defined $entry->{'geometry'} ) {
    my $g = $entry->{'geometry'};
    return sprintf( qw| %s.%d.%d+%dx%d |,
        $stable, $g->{'row'}, $g->{'col'}, $g->{'cols'}, $g->{'rows'} );
}

return $stable;

#,,,.,...,,,,,...,.,.,,,,,,..,,,,,..,,..,,,.,,..,,...,...,,,,,..,,,..,...,...,
#JR4WYPUQTSCODWTHWJO6BPGENKLRKWVNGBMZPCTPFCDN2QSY7TRAYQDSHMUCGPWZHCYV3PCAB7HUI
#\\\|LFDQCK7EIEL3XLTGYZY3OJGAQMGVG7DPNGGGTSUAQXBN3ZKP4WO \ / AMOS7 \ YOURUM ::
#\[7]STMCBNQ2MF6HYBXXA3EOJ4RRNL6KXVTJYEE2AKDD2APCABPFASDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
