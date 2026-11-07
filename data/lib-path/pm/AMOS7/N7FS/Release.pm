## [:< ##

package AMOS7::N7FS::Release;    ############################################

## N7FS store format 3 : signed tombstones, release and explicit reclamation.
## tombstones and the releasing directory live outside every node epoch, so a
## crash cannot make removed history look like an ordinary content node.

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

our $VERSION = qw| AMOS7::N7FS::Release-VERSION.YULHKZI |;

@EXPORT_OK = qw| release_node store_reclaim release_repair tombstone_read
    tombstone_latest tombstone_verify |;

use AMOS7::N7FS qw| ntime_now ntime14 read_file write_new_file make_dirs
    publish_dir remove_tree signed_record_pack signed_record_parse refuse fault |;
use AMOS7::N7FS::Sum  qw| epoch_from_b32 epoch_b32 amos_of_bmw |;
use AMOS7::N7FS::Sign qw| verify |;
use AMOS7::N7FS::Disk qw| disk_lock disk_read_id disk_require_attached
    state_read store_key_signer witness_note_format |;
use AMOS7::N7FS::Store     qw| store_nodes node_verify codec |;
use AMOS7::N7FS::Journal   qw| journal_replay journal_write |;
use AMOS7::N7FS::Reference qw| reference_scan reference_address |;

our $ADDR_RE = qr{\AV7[A-Z2-7]{5}/[A-Z2-7]{7}/[A-Z2-7]{77}\z};
our $TOMB_RE = qr{\A(\d{14})\.([A-Z2-7]{7})\.([A-Z2-7]{77})\.tombstone\z};

sub _empty_set {
    return {
        qw| nodes |      => [],
        qw| meta |       => [],
        qw| references | => [],
        qw| releases |   => []
    };
}

sub _parse_address {
    my $address = shift // '';
    refuse( 'release : not a canonical node address [ %s ]', $address )
        if $address !~ $ADDR_RE;
    my ( $epoch_name, $amos, $bmw ) = split m|/|, $address;
    my $epoch = epoch_from_b32($epoch_name);
    refuse( 'release : not a canonical node address [ %s ]', $address )
        if not defined $epoch
        or amos_of_bmw($bmw) ne $amos;
    return { qw| epoch | => $epoch, qw| amos | => $amos, qw| bmw | => $bmw };
}

sub _aside {
    my ( $id, $address ) = @ARG;
    return "$id->{'path'}/.n7fs/releasing/$address";
}

sub _finish_remove {
    my ( $id, $node, $address ) = @ARG;
    my $aside = _aside( $id, $address );
    ## an aside left by an earlier generation is never good content, and it
    ## must not stop the release of the node now live at this address
    remove_tree($aside) if defined $node and -e $aside;
    if ( defined $node ) {
        make_dirs( $aside =~ s|/[^/]+\z||r, 0700 );
        fault(qw| release:before-rename |);
        publish_dir( $node->{'path'}, $aside );
        fault(qw| release:after-rename |);
    }
    fault(qw| release:before-remove |)                         if -e $aside;
    remove_tree($aside)                                        if -e $aside;
    refuse( 'release : cannot remove aside [ %s ]', $address ) if -e $aside;
    fault(qw| release:after-remove |);
    return;
}

sub tombstone_read {
    my ( $id, $path ) = @ARG;
    my ($name) = $path =~ m|([^/]+)\z|;
    my ( $ntime, $amos, $bmw ) = $name =~ $TOMB_RE;
    refuse( 'tombstone %s : bad file name', $path ) if not defined $ntime;
    my $rec = signed_record_parse( qw| tombstone |, read_file($path) );
    refuse( 'tombstone %s : record format is not 3', $path )
        if $rec->{'format'} != 3;
    refuse( 'tombstone %s : signed by a foreign store key', $path )
        if $rec->{'signer_pub'} ne $id->{'store_pub'};
    refuse( 'tombstone %s : store signature does not verify', $path )
        if not verify( $id->{'store_pub'}, $rec->{'signed'}, $rec->{'sig'} );
    my $p = $rec->{'payload'};
    refuse( 'tombstone %s : payload does not match its path', $path )
        if ( $p->{'disk'} // '' ) ne $id->{'disk'}
        or ( $p->{'ntime'} // '' ) ne $ntime
        or ( $p->{'addr'}  // '' ) !~ $ADDR_RE;
    my ( undef, $a, $b ) = split m|/|, $p->{'addr'};
    refuse( 'tombstone %s : address does not match its path', $path )
        if $a ne $amos or $b ne $bmw;
    refuse( 'tombstone %s : no reason', $path )
        if not defined $p->{'reason'}
        or not length $p->{'reason'};
    return $p;
}

sub tombstone_latest {
    my ( $id, $address ) = @ARG;
    my $latest;
    my $dir = "$id->{'path'}/.n7fs/tombstones";
    return undef if not -d $dir;
    opendir( my $dh, $dir )
        or refuse( 'cannot read %s : %s', $dir, $OS_ERROR );
    my @names = sort grep { $ARG =~ $TOMB_RE } readdir $dh;
    closedir $dh;
    foreach my $name (@names) {
        my $p = tombstone_read( $id, "$dir/$name" );
        $latest = $p if $p->{'addr'} eq $address;
    }
    return $latest;
}

sub tombstone_verify {
    my ( $id, $replay ) = @ARG;
    my $dir = "$id->{'path'}/.n7fs/tombstones";
    my @names;
    if ( -d $dir ) {
        opendir( my $dh, $dir )
            or refuse( 'cannot read %s : %s', $dir, $OS_ERROR );
        @names = sort grep { $ARG ne '.' and $ARG ne '..' } readdir $dh;
        closedir $dh;
    }
    refuse( 'unexpected tombstone entry %s', $names[0] )
        if grep { $ARG !~ $TOMB_RE } @names;
    my %held
        = map { tombstone_read( $id, "$dir/$ARG" )->{'addr'} => TRUE } @names;

    ## tombstones are permanent : every journaled release must still have one
    foreach my $address ( ( $replay->{'release_order'} // [] )->@* ) {
        refuse( 'format 3 : missing tombstone for released node %s',
            $address )
            if not $held{$address};
    }
    return scalar @names;
}

sub _tombstone_write {
    my ( $id, $store, $address, $reason ) = @ARG;
    my ( undef, $amos, $bmw ) = split m|/|, $address;
    my $dir = "$id->{'path'}/.n7fs/tombstones";
    make_dirs( $dir, 0700 );
    opendir( my $dh, $dir )
        or refuse( 'cannot read %s : %s', $dir, $OS_ERROR );
    my @old = grep { $ARG =~ $TOMB_RE } readdir $dh;
    closedir $dh;
    my $ntime = ntime_now();

    foreach my $name (@old) {
        my ($old) = $name =~ $TOMB_RE;
        $ntime = $old + 1 if $ntime <= $old;
    }
    my $nt14    = ntime14($ntime);
    my $path    = "$dir/$nt14.$amos.$bmw.tombstone";
    my %payload = (
        qw| disk |   => $id->{'disk'},
        qw| addr |   => $address,
        qw| ntime |  => $nt14,
        qw| reason | => $reason,
    );
    fault(qw| release:before-tombstone |);
    write_new_file( $path,
        signed_record_pack( qw| tombstone |, \%payload, $store, 3 ) );
    fault(qw| release:after-tombstone |);
    return $path;
}

sub release_node {
    my %opt     = @ARG;
    my $address = $opt{'address'} // '';
    my $addr    = _parse_address($address);
    my $lock    = disk_lock( disk_read_id(%opt) );
    my $id      = disk_require_attached(%opt);
    my $store   = store_key_signer( %opt, qw| id | => $id );
    my $state   = state_read( $id->{'path'}, $id->{'store_pub'} );
    refuse('release is only available for store format 3')
        if $state->{'store_format'} != 3;
    refuse( 'release : epoch is not active [ %s ]', $address )
        if not grep { $ARG == $addr->{'epoch'} } $state->{'epochs'}->@*;
    my $replay = journal_replay($id);
    my @live;
    my @copies;
    my ($node)
        = grep { reference_address($ARG) eq $address }
        store_nodes( $id->{'path'}, $state->{'epochs'}->@* );
    refuse( 'release : unknown node %s', $address )
        if not defined $node and not $replay->{'released'}{$address};

    if ( defined $node and not $replay->{'released'}{$address} ) {
        refuse( 'node %s is not journaled [ a crash ? n7fs repair %s ]',
            $address, $id->{'disk'} )
            if not $replay->{'nodes'}{$address};
        node_verify( $id->{'path'}, $node, 3, $id );
        @live = grep { not $ARG->{'dropped'} } reference_scan( $node, $id );
        refuse(
            "release : live references [ use -force to break them ] :\n  "
                . join( "\n  ", map { $ARG->{'holder'} } @live ), )
            if @live and not $opt{'force'};
        my $reason = $opt{'reason'};
        $reason = 'explicit release'
            if not defined $reason or not length $reason;
        _tombstone_write( $id, $store, $address, $reason );
        my $add  = _empty_set();
        my $drop = _empty_set();
        push $drop->{'releases'}->@*, $address;
        fault(qw| release:before-journal |);
        my $journal = journal_write( $id, $store, $add, $drop, {} );
        fault(qw| release:after-journal |);
        witness_note_format(
            %opt,
            qw| id |          => $id,
            qw| state |       => $state,
            qw| journal_seq | => $journal->{'seq'}
        );
        $opt{'_seq'} = $journal->{'seq'};
    }
    _finish_remove( $id, $node, $address );

    ## a conversion's previous form keeps its own copy until release-epoch
    if ( ref $state->{'previous'} eq qw| HASH | ) {
        @copies = map { reference_address($ARG) }
            grep { $ARG->{'bmw'} eq $addr->{'bmw'} }
            store_nodes( $id->{'path'}, $state->{'previous'}{'epochs'}->@* );
    }
    return {
        qw| copies |  => \@copies,
        qw| address | => $address,
        qw| seq |     => $opt{'_seq'} // $replay->{'seq'},
        qw| live |    => [ map { $ARG->{'holder'} } @live ],
    };
}

sub store_reclaim {
    my %opt   = @ARG;
    my $lock  = $opt{'dry_run'} ? undef : disk_lock( disk_read_id(%opt) );
    my $id    = disk_require_attached(%opt);
    my $state = state_read( $id->{'path'}, $id->{'store_pub'} );
    refuse('reclaim is only available for store format 3')
        if $state->{'store_format'} != 3;
    my $replay = journal_replay($id);
    my @garbage;
    foreach my $node ( store_nodes( $id->{'path'}, $state->{'epochs'}->@* ) )
    {
        my @refs = reference_scan( $node, $id );
        next if grep { not $ARG->{'dropped'} } @refs;
        my $read = codec(3)->{'read_node'}
            ->( $node->{'path'}, $node, { qw| id | => $id } );
        my $newest = 0;
        foreach my $meta ( $read->{'metas'}->@* ) {
            $newest = $meta->{'import_ntime'}
                if $meta->{'import_ntime'} > $newest;
        }
        next
            if defined $opt{'older'}
            and $newest > ntime_now() - $opt{'older'};
        my $size = ( stat "$node->{'path'}/content" )[7];
        push @garbage,
            {
            qw| node |    => $node,
            qw| address | => reference_address($node),
            qw| ntime |   => $newest,
            qw| size |    => $size,
            };
    }
    @garbage = sort {
               $a->{'ntime'} <=> $b->{'ntime'}
            or $a->{'address'} cmp $b->{'address'}
    } @garbage;
    my @released;
    my $freed = 0;
    foreach my $item (@garbage) {
        last if defined $opt{'free'} and $freed >= $opt{'free'};
        push @released, $item;
        $freed += $item->{'size'};
        next if $opt{'dry_run'};
        release_node(
            %opt,
            qw| address | => $item->{'address'},
            qw| reason |  => 'reclaim : no live reference',
        );
    }
    return { qw| released | => \@released, qw| freed | => $freed };
}

sub release_repair {
    my ( $id, $state, $replay ) = @ARG;
    my @finished;
    my %seen;
    foreach my $address ( $replay->{'release_order'}->@* ) {
        next if $seen{$address}++;
        my $addr = _parse_address($address);
        my ($node)
            = grep { reference_address($ARG) eq $address }
            store_nodes( $id->{'path'}, $addr->{'epoch'} );
        undef $node if not $replay->{'released'}{$address};
        next        if not defined $node and not -e _aside( $id, $address );
        _finish_remove( $id, $node, $address );
        push @finished, $address;
    }
    return \@finished;
}

1;

#,,..,,,,,,,,,..,,,.,,,.,,,..,...,.,,,.,.,,,,,..,,...,...,..,,,.,,,.,,.,,,..,,
#VRHQRRRPTKMLMPKRHSQRQIQUJROP7KY3RP25DLF65ZKVXOLATZC3HA4XEVZLK3KZXZXEZZ76H4TSM
#\\\|ZWITBRLCEBYPR525NLXX272C3EBAZZYUAKQAF4HTHYDXQX5W3S6 \ / AMOS7 \ YOURUM ::
#\[7]LRXUOU7QRG22GTOZ3FTVVUFMPOT4ABPNZ6L3BN4A4XROSZNQCSCI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
