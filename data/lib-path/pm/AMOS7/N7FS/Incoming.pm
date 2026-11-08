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

our $VERSION = qw| AMOS7::N7FS::Incoming-VERSION.Y4JNK2Y |;

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
    my ( $refs, $under, $depth, $limit ) = @ARG;
    my %groups;
    foreach my $ref ( @{$refs} ) {
        next if defined $under and not _under( $ref->{'holder'}, $under );
        my $group = _dirname( $ref->{'holder'} );
        if ( defined $depth ) {
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

sub incoming_tag {
    my %opt      = @ARG;
    my $selector = $opt{'selector'} // '';
    my $category = $opt{'category'} // '';
    refuse('incoming tag : the selector is empty') if not length $selector;
    my $lock  = disk_lock( disk_read_id(%opt) );
    my $id    = disk_require_attached(%opt);
    my $store = store_key_signer( %opt, qw| id | => $id );
    my $state = state_read( $id->{'path'}, $id->{'store_pub'} );
    refuse('incoming is only available for store format 3')
        if $state->{'store_format'} != 3;
    my $replay = journal_replay($id);
    refuse( 'unknown category [ %s ]', $category )
        if not exists category_definitions( $id, $replay )->{$category};
    my $refs = incoming_refs( %opt, _id => $id, _replay => $replay );
    my @matching;

    if ( $selector =~ $ADDR_RE ) {
        @matching = grep { $ARG->{'node'} eq $selector } @{$refs};
    } elsif ( $selector =~ m|[?*]| ) {
        my $glob = quotemeta $selector;
        $glob =~ s|\\\*|.*|g;
        $glob =~ s|\\\?|.|g;
        my $regex = qr|\A$glob\z|s;
        @matching = grep { $ARG->{'holder'} =~ $regex } @{$refs};
    } else {
        @matching = grep { _under( $ARG->{'holder'}, $selector ) } @{$refs};
    }
    refuse( 'incoming tag : no pool references match [ %s ]', $selector )
        if not @matching;
    my $bytes = 0;
    $bytes += $ARG->{'size'} for @matching;
    my $record = batch_write( $id, $store, $category, \@matching, $bytes );
    my $add    = _empty_set();
    push $add->{'batches'}->@*,
        { qw| path | => $record->{'path'}, qw| category | => $category };
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
        qw| category | => $category,
        qw| record |   => $record,
        qw| seq |      => $journal->{'seq'},
    };
}

1;

#,,,,,..,,...,,.,,,..,,,.,..,,,.,,.,.,.,.,,.,,..,,...,...,.,,,.,.,.,.,.,.,.,,,
#SFLCKEDN527BNWW5EB5ZSCDBQIOGQQPAAG7GJD35GUOXBWAVO2CG7MTBJAWFYT4UE4CGQ6NJCNKQU
#\\\|QMMRIDNUHTRRKHV4CQIN4R6HK7AY3WNVDUWV36E6CSHUQAERDGK \ / AMOS7 \ YOURUM ::
#\[7]3PLBQNCXNGCWQOEVJWCDA7OLR3YOJG62WGMA6YYV7KLGTENYCABA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
