## [:< ##

package AMOS7::N7FS::Journal;    ###########################################

## N7FS store format 3 : the signed append-only journal.
##
## an entry names the nodes, meta files and references that the store asserts.
## replay authenticates every record with the store public key from the
## parent-signed disk id, then checks sequence, hash chain and fork rules.

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

our $VERSION = qw| AMOS7::N7FS::Journal-VERSION.BUWMUVA |;

@EXPORT_OK = qw| journal_replay journal_head journal_write |;

use JSON::PP;
use AMOS7::N7FS qw| ntime_now ntime14 read_file write_new_file make_dirs
    signed_record_parse signed_record_pack refuse fault |;
use AMOS7::N7FS::Sum  qw| bmw384_bytes bmw_b32 |;
use AMOS7::N7FS::Sign qw| verify |;

our $JOURNAL_RE = qr{\A\d{14}\.journal\z};
our $TMP_RE     = qr{\.tmp\.[A-Z2-7]{8}\z};
our $ADDR_RE    = qr{\AV7[A-Z2-7]{5}/[A-Z2-7]{7}/[A-Z2-7]{77}\z};
our $REF_RE     = qr{\A\d{14}/[A-Z2-7]{7}/[A-Z2-7]{77}/addr\z};
our $META_RE    = qr{\A\d{14}\.[A-Z2-7]{8}\.meta\z};

sub _list {
    my $dir = shift;
    return () if not -d $dir;
    opendir( my $dh, $dir )
        or refuse( 'cannot read %s : %s', $dir, $OS_ERROR );
    my @names = grep { $ARG ne '.' and $ARG ne '..' } readdir $dh;
    closedir $dh;
    my @bad = grep { $ARG !~ $JOURNAL_RE and $ARG !~ $TMP_RE } @names;
    refuse( 'unexpected entry in %s : %s', $dir, $bad[0] ) if @bad;
    return sort grep { $ARG =~ $JOURNAL_RE } @names;
}

sub _record {
    my ( $id, $path ) = @ARG;
    my $bytes = read_file($path);
    my $rec   = signed_record_parse( qw| journal |, $bytes );
    refuse( 'journal %s : record format is not 3', $path )
        if $rec->{'format'} != 3;
    refuse( 'journal %s : signed by a foreign store key', $path )
        if $rec->{'signer_pub'} ne $id->{'store_pub'};
    refuse( 'journal %s : store signature does not verify', $path )
        if not verify( $id->{'store_pub'}, $rec->{'signed'}, $rec->{'sig'} );
    my $p = $rec->{'payload'};
    refuse( 'journal %s : disk binding does not match', $path )
        if ( $p->{'disk'} // '' ) ne $id->{'disk'};
    refuse( 'journal %s : bad sequence', $path )
        if ( $p->{'seq'} // '' ) !~ m|\A[1-9]\d*\z|;
    refuse( 'journal %s : bad previous-entry checksum', $path )
        if ( $p->{'prev'} // '' ) !~ m|\A(?:[A-Z2-7]{77})?\z|;

    foreach my $which (qw| add drop |) {
        refuse( 'journal %s : %s is not an object', $path, $which )
            if ref $p->{$which} ne qw| HASH |;
        foreach my $part (qw| nodes meta references |) {
            refuse( 'journal %s : %s %s is not a list', $path, $which, $part )
                if ref $p->{$which}{$part} ne qw| ARRAY |;
        }
    }
    refuse( 'journal %s : drop releases is not a list', $path )
        if ref $p->{'drop'}{'releases'} ne qw| ARRAY |;
    foreach my $part (qw| trees categories assignments batches |) {
        $p->{'add'}{$part} //= [];
        refuse( 'journal %s : add %s is not a list', $path, $part )
            if ref $p->{'add'}{$part} ne qw| ARRAY |;
    }
    $p->{'drop'}{'trees'} //= [];
    refuse( 'journal %s : drop trees is not a list', $path )
        if ref $p->{'drop'}{'trees'} ne qw| ARRAY |;
    $p->{'drop'}{'sync_releases'} //= [];
    $p->{'drop'}{'conflicts'}     //= [];
    $p->{'add'}{'conflicts'}      //= [];
    $p->{'add'}{'sync_cursors'}   //= [];
    $p->{'add'}{'holds'}          //= [];
    $p->{'drop'}{'holds'}         //= [];

    foreach my $part (qw| sync_releases conflicts holds |) {
        refuse( 'journal %s : drop %s is not a list', $path, $part )
            if ref $p->{'drop'}{$part} ne qw| ARRAY |;
    }
    foreach my $part (qw| conflicts sync_cursors holds |) {
        refuse( 'journal %s : add %s is not a list', $path, $part )
            if ref $p->{'add'}{$part} ne qw| ARRAY |;
    }
    return { qw| bytes | => $bytes, qw| payload | => $p };
}

sub _ref_id { return join "\0", @ARG[ 0, 1 ] }

sub _operations {
    my ( $p, $expected, $id ) = @ARG;
    $expected->{'released'}      //= {};
    $expected->{'meta_history'}  //= {};
    $expected->{'ref_history'}   //= {};
    $expected->{'release_order'} //= [];
    foreach my $which (qw| add drop |) {
        foreach my $part ( keys $p->{$which}->%* ) {
            next if ref $p->{$which}{$part} ne qw| ARRAY |;
            foreach my $operation ( $p->{$which}{$part}->@* ) {
                next
                    if ref $operation ne qw| HASH |
                    or not defined $operation->{'origin'};
                refuse( 'journal seq %d : bad origin', $p->{'seq'} )
                    if ref $operation->{'origin'} ne qw| HASH |
                    or ( $operation->{'origin'}{'disk'} // '' )
                    !~ m|\A[A-Z2-7]{7}\z|
                    or not length( $operation->{'origin'}{'id'} // '' );
            }
        }
    }
    foreach my $which (qw| add drop |) {
        foreach my $node ( $p->{$which}{'nodes'}->@* ) {
            refuse( 'journal seq %d : bad node address', $p->{'seq'} )
                if ( $node // '' ) !~ $ADDR_RE;
            if ( $which eq qw| add | ) {
                $expected->{'nodes'}{$node} = TRUE;
                delete $expected->{'released'}{$node};
            } else {
                delete $expected->{'nodes'}{$node};
            }
        }
        foreach my $meta ( $p->{$which}{'meta'}->@* ) {
            refuse( 'journal seq %d : bad meta operation', $p->{'seq'} )
                if ref $meta ne qw| HASH |
                or ( $meta->{'node'} // '' ) !~ $ADDR_RE
                or ( $meta->{'name'} // '' ) !~ $META_RE;
            my $key = _ref_id( $meta->{'node'}, $meta->{'name'} );
            if ( $which eq qw| add | ) {
                refuse( 'journal seq %d : meta names an unlisted node %s',
                    $p->{'seq'}, $meta->{'node'} )
                    if not $expected->{'nodes'}{ $meta->{'node'} };
                $expected->{'metas'}{$key}        = $meta;
                $expected->{'meta_history'}{$key} = $meta;
            } else {
                delete $expected->{'metas'}{$key};
            }
        }
        foreach my $ref ( $p->{$which}{'references'}->@* ) {
            refuse( 'journal seq %d : bad reference operation', $p->{'seq'} )
                if ref $ref ne qw| HASH |
                or ( $ref->{'node'} // '' ) !~ $ADDR_RE
                or ( $ref->{'path'} // '' ) !~ $REF_RE
                or !defined $ref->{'holder'}
                or !length $ref->{'holder'}
                or !defined $ref->{'name'}
                or !length $ref->{'name'};
            my $key = _ref_id( $ref->{'node'}, $ref->{'path'} );
            if ( $which eq qw| add | ) {
                refuse(
                    'journal seq %d : reference names an unlisted node %s',
                    $p->{'seq'}, $ref->{'node'} )
                    if not $expected->{'nodes'}{ $ref->{'node'} };
                refuse( 'journal seq %d : duplicate reference %s',
                    $p->{'seq'}, $ref->{'path'} )
                    if exists $expected->{'references'}{$key};
                my $history = { %{$ref}, qw| dropped | => FALSE };
                $expected->{'references'}{$key}  = $history;
                $expected->{'ref_history'}{$key} = $history;
            } else {
                refuse( 'journal seq %d : drop of a non-live reference %s',
                    $p->{'seq'}, $ref->{'path'} )
                    if not $expected->{'references'}{$key}
                    or $expected->{'references'}{$key}{'dropped'};
                $expected->{'references'}{$key}{'dropped'} = TRUE;
            }
        }
    }
    foreach my $tree ( $p->{'add'}{'trees'}->@* ) {
        refuse( 'journal seq %d : bad tree operation', $p->{'seq'} )
            if ref $tree ne qw| HASH |
            or ( $tree->{'name'} // '' ) !~ m|\A[^\x00/]+\z|
            or ( $tree->{'path'} // '' ) !~ m|\A\d{14}\.[A-Z2-7]{8}\.tree\z|
            or ( $tree->{'manifest'} // '' ) !~ $ADDR_RE;
        refuse( 'journal seq %d : duplicate live tree %s',
            $p->{'seq'}, $tree->{'name'} )
            if $expected->{'trees'}{ $tree->{'name'} };
        $expected->{'trees'}{ $tree->{'name'} }        = $tree;
        $expected->{'tree_history'}{ $tree->{'path'} } = $tree;
        refuse( 'journal seq %d : tree names an unlisted manifest %s',
            $p->{'seq'}, $tree->{'manifest'} )
            if not $expected->{'nodes'}{ $tree->{'manifest'} };
    }
    foreach my $tree ( $p->{'drop'}{'trees'}->@* ) {
        refuse( 'journal seq %d : bad tree drop operation', $p->{'seq'} )
            if ref $tree ne qw| HASH |
            or ( $tree->{'name'} // '' ) !~ m|\A[^\x00/]+\z|
            or ( $tree->{'path'} // '' )
            !~ m|\A\d{14}\.[A-Z2-7]{8}\.tree-drop\z|
            or ( $tree->{'tree'} // '' ) !~ m|\A\d{14}\.[A-Z2-7]{8}\.tree\z|;
        refuse( 'journal seq %d : drop of a non-live tree %s',
            $p->{'seq'}, $tree->{'name'} )
            if not $expected->{'trees'}{ $tree->{'name'} }
            or $expected->{'trees'}{ $tree->{'name'} }{'path'} ne
            $tree->{'tree'};
        $expected->{'tree_drops'}{ $tree->{'path'} } = $tree;
        delete $expected->{'trees'}{ $tree->{'name'} };
    }
    foreach my $category ( $p->{'add'}{'categories'}->@* ) {
        refuse( 'journal seq %d : bad category operation', $p->{'seq'} )
            if ref $category ne qw| HASH |
            or ( $category->{'name'} // '' ) !~ m|\A[^\x00/]+\z|
            or ( $category->{'path'} // '' )
            !~ m|\A\d{14}\.[A-Z2-7]{8}\.category\z|;
        $expected->{'categories'}{ $category->{'name'} }       = $category;
        $expected->{'category_history'}{ $category->{'path'} } = $category;
    }
    foreach my $assignment ( $p->{'add'}{'assignments'}->@* ) {
        refuse( 'journal seq %d : bad category assignment', $p->{'seq'} )
            if ref $assignment ne qw| HASH |
            or ( $assignment->{'node'}      // '' ) !~ $ADDR_RE
            or ( $assignment->{'reference'} // '' ) !~ $REF_RE
            or ( $assignment->{'path'}      // '' )
            !~ m|\A\d{14}\.[A-Z2-7]{8}\.assignment\z|
            or not length( $assignment->{'category'} // '' );
        my $key
            = _ref_id( $assignment->{'node'}, $assignment->{'reference'} );
        refuse( 'journal seq %d : assignment names an unknown reference',
            $p->{'seq'} )
            if not $expected->{'ref_history'}{$key};
        $expected->{'assignments'}{$key} = $assignment;
        $expected->{'assignment_history'}{ $assignment->{'path'} }
            = $assignment;
    }
    foreach my $batch ( $p->{'add'}{'batches'}->@* ) {
        refuse( 'journal seq %d : bad batch operation', $p->{'seq'} )
            if ref $batch ne qw| HASH |
            or ( $batch->{'path'} // '' )
            !~ m|\A\d{14}\.[A-Z2-7]{8}\.batch-assignment\z|;
        require AMOS7::N7FS::Batch;
        my $record = AMOS7::N7FS::Batch::batch_read( $id, $batch->{'path'} );
        $expected->{'batch_history'}{ $batch->{'path'} } = $batch;
        foreach my $ref ( $record->{'references'}->@* ) {
            my $key = _ref_id( $ref->{'node'}, $ref->{'reference'} );
            refuse( 'journal seq %d : batch names an unknown reference',
                $p->{'seq'} )
                if not $expected->{'ref_history'}{$key};
            $expected->{'assignments'}{$key} = {
                qw| node |      => $ref->{'node'},
                qw| reference | => $ref->{'reference'},
                qw| path |      => $batch->{'path'},
                qw| category |  => $record->{'category'},
                qw| batch |     => TRUE,
                $batch->{'origin'}
                ? ( qw| origin | => $batch->{'origin'} )
                : (),
            };
        }
    }
    foreach my $release ( $p->{'drop'}{'sync_releases'}->@* ) {
        refuse( 'journal seq %d : bad retained release', $p->{'seq'} )
            if ref $release ne qw| HASH |
            or ( $release->{'node'} // '' ) !~ $ADDR_RE
            or ref $release->{'origin'} ne qw| HASH |
            or ref $release->{'references'} ne qw| ARRAY |;
        $expected->{'sync_releases'}{ $release->{'node'} } = $release;
        push $expected->{'sync_release_order'}->@*, $release;
        foreach my $ref ( $release->{'references'}->@* ) {
            my $key = _ref_id( $ref->{'node'}, $ref->{'path'} );
            refuse(
                'journal seq %d : retained release drops unknown reference',
                $p->{'seq'} )
                if not $expected->{'references'}{$key};
            $expected->{'references'}{$key}{'dropped'} = TRUE;
        }
    }
    foreach my $cursor ( $p->{'add'}{'sync_cursors'}->@* ) {
        refuse( 'journal seq %d : bad sync cursor', $p->{'seq'} )
            if ref $cursor ne qw| HASH |
            or ( $cursor->{'source'}      // '' ) !~ m|\A[A-Z2-7]{7}\z|
            or ( $cursor->{'source_seq'}  // '' ) !~ m|\A\d+\z|
            or ( $cursor->{'source_hash'} // '' ) !~ m|\A[A-Z2-7]{77}\z|
            or ( $cursor->{'path'}        // '' )
            !~ m|\A\d{14}\.[A-Z2-7]{8}\.sync-cursor\z|;
        $expected->{'sync_cursors'}{ $cursor->{'source'} }      = $cursor;
        $expected->{'sync_cursor_history'}{ $cursor->{'path'} } = $cursor;
    }
    foreach my $which (qw| add drop |) {
        foreach my $conflict ( $p->{$which}{'conflicts'}->@* ) {
            refuse( 'journal seq %d : bad sync conflict', $p->{'seq'} )
                if ref $conflict ne qw| HASH |
                or ( $conflict->{'path'} // '' )
                !~ m|\A\d{14}\.[A-Z2-7]{8}\.sync-conflict\z|;
            if ( $which eq qw| add | ) {
                $expected->{'sync_conflicts'}{ $conflict->{'path'} }
                    = $conflict;
            } else {
                refuse( 'journal seq %d : unknown sync conflict resolution',
                    $p->{'seq'} )
                    if
                    not $expected->{'sync_conflicts'}{ $conflict->{'path'} };
                delete $expected->{'sync_conflicts'}{ $conflict->{'path'} };
            }
            $expected->{'sync_conflict_history'}{ $conflict->{'path'} }
                = $conflict;
        }
    }
    foreach my $which (qw| add drop |) {
        foreach my $hold ( $p->{$which}{'holds'}->@* ) {
            refuse( 'journal seq %d : bad hold operation', $p->{'seq'} )
                if ref $hold ne qw| HASH |
                or ( $hold->{'path'} // '' )
                !~ m|\A\d{14}\.[A-Z2-7]{8}\.hold\z|;
            if ( $which eq qw| add | ) {
                refuse( 'journal seq %d : bad hold operation', $p->{'seq'} )
                    if ( $hold->{'seq'} // '' ) !~ m|\A\d+\z|
                    or $hold->{'seq'} >= $p->{'seq'}
                    or ( $hold->{'ntime'}   // '' ) !~ m|\A\d{14}\z|
                    or ( $hold->{'expires'} // '' ) !~ m|\A\d{14}\z|
                    or not length( $hold->{'reason'} // '' );
                refuse( 'journal seq %d : duplicate hold %s',
                    $p->{'seq'}, $hold->{'path'} )
                    if $expected->{'hold_history'}{ $hold->{'path'} };
                $expected->{'holds'}{ $hold->{'path'} }        = $hold;
                $expected->{'hold_history'}{ $hold->{'path'} } = $hold;
            } else {
                refuse( 'journal seq %d : release of a non-live hold %s',
                    $p->{'seq'}, $hold->{'path'} )
                    if not $expected->{'holds'}{ $hold->{'path'} };
                delete $expected->{'holds'}{ $hold->{'path'} };
            }
        }
    }
    foreach my $node ( $p->{'drop'}{'releases'}->@* ) {
        refuse( 'journal seq %d : bad release address', $p->{'seq'} )
            if ( $node // '' ) !~ $ADDR_RE;
        refuse( 'journal seq %d : release of an unlisted node %s',
            $p->{'seq'}, $node )
            if not $expected->{'nodes'}{$node};
        delete $expected->{'nodes'}{$node};
        $expected->{'released'}{$node} = TRUE;
        push $expected->{'release_order'}->@*, $node;
        foreach my $set (qw| metas references |) {
            foreach my $key ( keys $expected->{$set}->%* ) {
                my $item = $expected->{$set}{$key};
                next if $item->{'node'} ne $node;
                $item->{'released'} = TRUE;
                delete $expected->{$set}{$key};
            }
        }
    }
    return;
}

sub journal_replay {
    my ( $id, %opt ) = @ARG;
    my $dir  = "$id->{'path'}/.n7fs/journal";
    my $upto = $opt{'upto'};
    refuse( 'journal replay : bad upper sequence [ %s ]', $upto // '' )
        if defined $upto and $upto !~ m|\A\d+\z|;
    my @name     = _list($dir);
    my %expected = (
        qw| nodes |      => {},
        qw| metas |      => {},
        qw| references | => {}
    );
    my ( $previous, $seq, $bounded, $baseline ) = ( '', 0, 0, FALSE );
    my ( %seen_seq, %seen_prev );
    my @entries;

    foreach my $name (@name) {
        my $r = _record( $id, "$dir/$name" );
        my $p = $r->{'payload'};
        refuse( 'journal %s : fork or duplicate sequence %d',
            $name, $p->{'seq'} )
            if $seen_seq{ $p->{'seq'} }++;
        refuse( 'journal %s : fork [ exactly one successor per entry ]',
            $name )
            if $seen_prev{ $p->{'prev'} }++;
        refuse( 'journal %s : sequence is not contiguous [ expected %d ]',
            $name, $seq + 1 )
            if $p->{'seq'} != $seq + 1;
        refuse( 'journal %s : previous-entry checksum does not match', $name )
            if $p->{'prev'} ne $previous;
        refuse( 'journal %s : baseline is only valid at sequence 1', $name )
            if $p->{'baseline'} and $p->{'seq'} != 1;
        if ( not defined $upto or $p->{'seq'} <= $upto ) {
            _operations( $p, \%expected, $id );
            $baseline = TRUE if $p->{'baseline'};
            $bounded  = $p->{'seq'};
            push @entries,
                {
                qw| name |    => $name,
                qw| bytes |   => $r->{'bytes'},
                qw| payload | => $p
                };
        }
        $previous = bmw_b32( bmw384_bytes( $r->{'bytes'} ) );
        $seq      = $p->{'seq'};
    }
    refuse( 'journal replay : upper sequence %d is beyond the head %d',
        $upto, $seq )
        if defined $upto and $upto > $seq;
    return {
        qw| seq |                   => defined $upto ? $bounded : $seq,
        qw| head_seq |              => $seq,
        qw| baseline |              => $baseline,
        qw| nodes |                 => $expected{'nodes'},
        qw| metas |                 => $expected{'metas'},
        qw| references |            => $expected{'references'},
        qw| released |              => $expected{'released'},
        qw| meta_history |          => $expected{'meta_history'},
        qw| ref_history |           => $expected{'ref_history'},
        qw| release_order |         => $expected{'release_order'},
        qw| trees |                 => $expected{'trees'}               // {},
        qw| tree_history |          => $expected{'tree_history'}        // {},
        qw| tree_drops |            => $expected{'tree_drops'}          // {},
        qw| categories |            => $expected{'categories'}          // {},
        qw| category_history |      => $expected{'category_history'}    // {},
        qw| assignments |           => $expected{'assignments'}         // {},
        qw| assignment_history |    => $expected{'assignment_history'}  // {},
        qw| batch_history |         => $expected{'batch_history'}       // {},
        qw| sync_cursors |          => $expected{'sync_cursors'}        // {},
        qw| sync_cursor_history |   => $expected{'sync_cursor_history'} // {},
        qw| sync_conflicts |        => $expected{'sync_conflicts'}      // {},
        qw| sync_conflict_history | => $expected{'sync_conflict_history'}
            // {},
        qw| sync_releases |      => $expected{'sync_releases'}      // {},
        qw| sync_release_order | => $expected{'sync_release_order'} // [],
        qw| holds |              => $expected{'holds'}              // {},
        qw| hold_history |       => $expected{'hold_history'}       // {},
        qw| entries |            => \@entries,
    };
}

## a cheap reader for get-by-address and mount checks : only the first and
## last records are authenticated. full chain and set validation stay with
## replay.
sub journal_head {
    my $id    = shift;
    my $dir   = "$id->{'path'}/.n7fs/journal";
    my @names = _list($dir);
    return { qw| seq | => 0, qw| baseline | => FALSE } if not @names;
    my $first = _record( $id, "$dir/$names[0]" );
    my $last  = _record( $id, "$dir/$names[-1]" );
    refuse('journal head : first sequence is not 1')
        if $first->{'payload'}{'seq'} != 1;
    refuse('journal head : first previous-entry checksum is not empty')
        if length $first->{'payload'}{'prev'};
    refuse(
        'journal head : sequence %d does not match the entry count %d',
        $last->{'payload'}{'seq'},
        scalar @names
    ) if $last->{'payload'}{'seq'} != scalar @names;
    return {
        qw| seq |      => $last->{'payload'}{'seq'},
        qw| baseline | => $first->{'payload'}{'baseline'} ? TRUE : FALSE,
    };
}

sub journal_write {
    my ( $id, $store, $add, $drop, $flags ) = @ARG;
    refuse('journal write needs the delegated store key') if not ref $store;
    my $replay = journal_replay($id);
    my $seq    = $replay->{'seq'} + 1;
    refuse('a baseline can only be the first journal entry')
        if $flags->{'baseline'} and $seq != 1;
    my $previous
        = $replay->{'seq'}
        ? bmw_b32( bmw384_bytes( $replay->{'entries'}[-1]{'bytes'} ) )
        : '';
    my %payload = (
        qw| seq |  => $seq + 0,
        qw| prev | => $previous,
        qw| disk | => $id->{'disk'},
        qw| add |  => {
            qw| nodes |        => [ $add->{'nodes'}->@* ],
            qw| meta |         => [ $add->{'meta'}->@* ],
            qw| references |   => [ $add->{'references'}->@* ],
            qw| trees |        => [ ( $add->{'trees'}        // [] )->@* ],
            qw| categories |   => [ ( $add->{'categories'}   // [] )->@* ],
            qw| assignments |  => [ ( $add->{'assignments'}  // [] )->@* ],
            qw| batches |      => [ ( $add->{'batches'}      // [] )->@* ],
            qw| sync_cursors | => [ ( $add->{'sync_cursors'} // [] )->@* ],
            qw| conflicts |    => [ ( $add->{'conflicts'}    // [] )->@* ],
            qw| holds |        => [ ( $add->{'holds'}        // [] )->@* ],
        },
        qw| drop | => {
            qw| nodes |         => [ $drop->{'nodes'}->@* ],
            qw| meta |          => [ $drop->{'meta'}->@* ],
            qw| references |    => [ $drop->{'references'}->@* ],
            qw| releases |      => [ $drop->{'releases'}->@* ],
            qw| trees |         => [ ( $drop->{'trees'}         // [] )->@* ],
            qw| sync_releases | => [ ( $drop->{'sync_releases'} // [] )->@* ],
            qw| conflicts |     => [ ( $drop->{'conflicts'}     // [] )->@* ],
            qw| holds |         => [ ( $drop->{'holds'}         // [] )->@* ],
        },
    );
    $payload{'baseline'} = JSON::PP::true if $flags->{'baseline'};
    $payload{'repaired'} = JSON::PP::true if $flags->{'repaired'};

    ## never sign what replay would refuse : one such entry ends the disk ##
    _operations( \%payload, $replay, $id );

    my $dir = "$id->{'path'}/.n7fs/journal";
    make_dirs( $dir, 0700 );
    my @names = _list($dir);
    my $ntime = ntime_now();
    if (@names) {
        my ($last) = $names[-1] =~ m|\A(\d{14})\.journal\z|;
        $ntime = $last + 1 if $ntime <= $last;
    }
    my $path = $dir . '/' . ntime14($ntime) . '.journal';
    fault(qw| journal:before-write |);
    write_new_file( $path,
        signed_record_pack( qw| journal |, \%payload, $store, 3 ) );
    fault(qw| journal:after-write |);
    return {
        qw| seq |     => $seq,
        qw| path |    => $path,
        qw| payload | => \%payload
    };
}

1;

#,,.,,.,,,,.,,.,.,.,.,.,,,...,.,.,..,,..,,..,,.,.,...,...,..,,,..,.,,,.,.,.,,,
#JYPYCIL5FCLLLXM7RDNTQHSEOWPAAC6DMOS4J3JGT7OUS6Z7TWCSMGT2R7JEZMJT4XO3OPQEEBRKG
#\\\|JFZAU44LHQ2XZV3U2VUBICUO2N4DT3DZITQCXT6JXEEH3CRCMQU \ / AMOS7 \ YOURUM ::
#\[7]P5UD6CZZDLNN7OOENRQWUX5XMY6LS5T3MLQDK2RDZL3C3KYMHUAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
