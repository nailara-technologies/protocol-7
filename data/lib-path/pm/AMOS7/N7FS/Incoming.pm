## [:< ##

package AMOS7::N7FS::Incoming;    ###########################################

## current incoming-category references, grouping and batched tagging.

use v5.32.0;
use utf8;
use strict;
use English;
use warnings;

use constant TRUE  => 5;
use constant FALSE => 0;

use Exporter;
use base qw| Exporter |;
use vars qw| @EXPORT_OK $VERSION |;

our $VERSION = qw| AMOS7::N7FS::Incoming-VERSION.PI4V6MI |;

@EXPORT_OK
    = qw| incoming_refs incoming_summary incoming_groups incoming_tag |;

use AMOS7::N7FS qw| refuse |;
use AMOS7::N7FS::Disk
    qw| disk_lock disk_read_id disk_require_attached state_read
    store_key_signer witness_note_format |;
use AMOS7::N7FS::Store    qw| meta_entries |;
use AMOS7::N7FS::Journal  qw| journal_replay journal_write |;
use AMOS7::N7FS::Category qw| category_definitions |;
use AMOS7::N7FS::Batch    qw| batch_write |;

our $ADDR_RE = qr{\AV7[A-Z2-7]{5}/[A-Z2-7]{7}/[A-Z2-7]{77}\z};

sub _key { return join "\0", @ARG }

sub incoming_refs {
    my (%opt)  = @ARG;
    my $id     = delete $opt{'_id'};
    my $replay = delete $opt{'_replay'};
    my %newest;
    foreach my $meta ( meta_entries(%opt) ) {
        my $key = _key( $meta->{'address'}, $meta->{'source'} // '' );
        $newest{$key} = $meta
            if not exists $newest{$key}
            or $meta->{'import_ntime'} gt $newest{$key}{'import_ntime'};
    }
    my @refs;
    foreach my $key ( sort keys $replay->{'references'}->%* ) {
        my $ref = $replay->{'references'}{$key};
        next if $ref->{'dropped'} or $ref->{'released'};
        my $assignment = $replay->{'assignments'}{$key};
        next
            if ( $assignment->{'category'} // qw| default | ) ne
            qw| incoming |;
        my $meta = $newest{ _key( $ref->{'node'}, $ref->{'holder'} ) };
        refuse( 'incoming : no meta for reference %s', $ref->{'path'} )
            if not defined $meta;
        push @refs,
            {
            %{$ref},
            qw| size |     => $meta->{'size'} + 0,
            qw| category | => qw| incoming |
            };
    }
    return \@refs;
}

sub incoming_summary {
    my $refs = shift;
    my ( $count, $bytes ) = ( 0, 0 );
    foreach my $ref ( @{$refs} ) {
        $count++;
        $bytes += $ref->{'size'};
    }
    return { qw| count | => $count, qw| bytes | => $bytes };
}

## a prefix ends at a path component : /a/foo never selects /a/foobar ##
sub _under {
    my ( $holder, $prefix ) = @ARG;
    $prefix =~ s|/+\z||;
    return TRUE if not length $prefix;
    return ( $holder eq $prefix or index( $holder, "$prefix/" ) == 0 )
        ? TRUE
        : FALSE;
}

sub _dirname {
    my $path = shift;
    $path =~ s|/+\z|| if length $path > 1;
    $path =~ s|/[^/]+\z||;
    return length $path ? $path : '/';
}

sub incoming_groups {
    my ( $refs, $under, $depth, $limit, $name_len ) = @ARG;
    my %groups;
    foreach my $ref ( @{$refs} ) {
        next if defined $under and not _under( $ref->{'holder'}, $under );
        my $group = _dirname( $ref->{'holder'} );
        if ( defined $name_len ) {
            ( my $name = $ref->{'holder'} ) =~ s|.*/||s;
            $group = substr( $name, 0, $name_len );
        } elsif ( defined $depth ) {
            ( my $base = $under // '' ) =~ s|/+\z||;
            my @parts = grep {length} split m|/|,
                substr( $group, length $base );
            my @keep = splice @parts, 0, $depth;
            $group = join '/', $base, @keep;
            $group = '/' if not length $group;
        }
        $groups{$group}{'count'}++;
        $groups{$group}{'bytes'} += $ref->{'size'};
    }
    my @out = map {
        { qw| path | => $ARG, %{ $groups{$ARG} } }
    } sort { $groups{$b}{'bytes'} <=> $groups{$a}{'bytes'} or $a cmp $b }
        keys %groups;
    splice @out, $limit if defined $limit and @out > $limit;
    return \@out;
}

sub _empty_set {
    return {
        qw| nodes |       => [],
        qw| meta |        => [],
        qw| references |  => [],
        qw| releases |    => [],
        qw| trees |       => [],
        qw| categories |  => [],
        qw| assignments | => [],
        qw| batches |     => [],
    };
}

## a canonical address, a glob over the whole path, or a path prefix ##
sub _matcher {
    my $selector = shift;
    return sub { $ARG[0]->{'node'} eq $selector }
        if $selector =~ $ADDR_RE;
    if ( $selector =~ m|[?*]| ) {
        my $glob = quotemeta $selector;
        $glob =~ s|\\\*|.*|g;
        $glob =~ s|\\\?|.|g;
        my $regex = qr|\A$glob\z|s;
        return sub { $ARG[0]->{'holder'} =~ $regex };
    }
    return sub { _under( $ARG[0]->{'holder'}, $selector ) };
}

sub incoming_tag {
    my %opt = @ARG;
    ## one selector, or many rules in one run : first matching rule wins ##
    my @rules
        = $opt{'rules'}
        ? $opt{'rules'}->@*
        : ( [ $opt{'selector'} // '', $opt{'category'} // '' ] );
    refuse('incoming tag : no rules') if not @rules;
    foreach my $rule (@rules) {
        refuse('incoming tag : the selector is empty')
            if not length $rule->[0];
    }
    my $lock  = disk_lock( disk_read_id(%opt) );
    my $id    = disk_require_attached(%opt);
    my $store = store_key_signer( %opt, qw| id | => $id );
    my $state = state_read( $id->{'path'}, $id->{'store_pub'} );
    refuse('incoming is only available for store format 3')
        if $state->{'store_format'} != 3;
    my $replay  = journal_replay($id);
    my $defined = category_definitions( $id, $replay );

    foreach my $rule (@rules) {
        refuse( 'unknown category [ %s ]', $rule->[1] )
            if not exists $defined->{ $rule->[1] };
    }
    my @left = incoming_refs( %opt, _id => $id, _replay => $replay )->@*;
    my ( %by_category, @matching, @empty );
    foreach my $rule (@rules) {
        my $test = _matcher( $rule->[0] );
        my ( @hit, @rest );
        foreach my $ref (@left) {
            if   ( $test->($ref) ) { push @hit,  $ref }
            else                   { push @rest, $ref }
        }
        @left = @rest;
        push @empty,                         $rule->[0] if not @hit;
        push $by_category{ $rule->[1] }->@*, @hit;
        push @matching,                      @hit;
    }
    refuse( 'incoming tag : no pool references match [ %s ]', $rules[0][0] )
        if not @matching;
    my $bytes = 0;
    $bytes += $ARG->{'size'} for @matching;
    my $add = _empty_set();
    my $record;
    foreach my $category ( sort keys %by_category ) {
        my $list = $by_category{$category};
        next if not @{$list};
        my $size = 0;
        $size += $ARG->{'size'} for @{$list};
        $record = batch_write( $id, $store, $category, $list, $size );
        push $add->{'batches'}->@*,
            { qw| path | => $record->{'path'}, qw| category | => $category };
    }
    my $drop     = _empty_set();
    my %resolved = map { $ARG->{'path'} => TRUE } @matching;

    if ( keys $replay->{'sync_conflicts'}->%* ) {
        my %records
            = map { $ARG->{'path'} => $ARG }
            AMOS7::N7FS::Record::record_scan(
            $id,
            qw| sync_conflict |,
            qw| sync-conflicts |,
            qw| sync-conflict |
            );
        foreach my $path ( keys $replay->{'sync_conflicts'}->%* ) {
            push $drop->{'conflicts'}->@*, { qw| path | => $path }
                if $resolved{ $records{$path}{'reference'} // '' };
        }
    }
    my $journal = journal_write( $id, $store, $add, $drop, {} );
    witness_note_format(
        %opt,
        qw| id |          => $id,
        qw| state |       => $state,
        qw| journal_seq | => $journal->{'seq'}
    );
    return {
        qw| count |    => scalar @matching,
        qw| bytes |    => $bytes,
        qw| category | => $rules[0][1],
        qw| record |   => $record,
        qw| seq |      => $journal->{'seq'},
        qw| rules |    => scalar @rules,
        qw| empty |    => \@empty,
    };
}

1;

#,,,.,...,..,,,,.,.,,,,.,,.,,,.,.,.,.,.,,,,.,,..,,...,...,.,,,,,,,..,,.,,,...,
#2FLLIYL6TTURZV5P237LHMGFAZM4PRWQCADBOHETB6C6Q2HKODZWH7MZK37MTWLAMISTTDA6RA7S4
#\\\|F3GR3EL32M4NWXY3BLZ6BDH2V5R7CM3T2HCYQM2ZJXNQHBZFXLZ \ / AMOS7 \ YOURUM ::
#\[7]Y6CBHZOCTOE4NFKGLXLNBLLZC476FSO6VV47A3JVIK6BQKIEAODI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
