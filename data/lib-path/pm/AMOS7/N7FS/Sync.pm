## [:< ##

package AMOS7::N7FS::Sync;    ###############################################

## local one-way union sync : authenticated source history is translated and
## signed again by the receiver. original record identities survive epochs and
## onward syncs; content is never removed by this module.

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

our $VERSION = qw| AMOS7::N7FS::Sync-VERSION.LWAAWKY |;

@EXPORT_OK = qw| store_sync sync_conflict_list sync_conflict_resolve
    sync_records_verify |;

use JSON::PP;
use AMOS7::N7FS
    qw| ntime_now ntime14 b32 random_bytes read_file write_new_file
    write_new_file_stream make_dirs publish_dir remove_tree signed_record_pack
    signed_record_parse refuse fault |;
use AMOS7::N7FS::Sum qw| bmw384_bytes bmw384_fh bmw_b32 amos_of_bmw epoch_num
    epoch_b32 epoch_from_b32 |;
use AMOS7::N7FS::Sign qw| verify |;
use AMOS7::N7FS::Disk qw| disk_lock disk_read_id disk_require_attached
    state_read state_write store_key_signer witness_note_format |;
use AMOS7::N7FS::Store qw| codec node_path node_verify reference_entries
    write_epoch |;
use AMOS7::N7FS::Journal   qw| journal_replay journal_write |;
use AMOS7::N7FS::Record    qw| record_write record_scan |;
use AMOS7::N7FS::Reference qw| reference_write reference_drop_write
    reference_address |;
use AMOS7::N7FS::Category qw| category_definitions category_strict_merge |;
use AMOS7::N7FS::Batch    qw| batch_read batch_write |;
use AMOS7::N7FS::Tree     qw| manifest_open manifest_entry_read |;
use AMOS7::N7FS::Hold     qw| hold_create |;

our $JSON    = JSON::PP->new->utf8->canonical;
our $ADDR_RE = qr{\AV7[A-Z2-7]{5}/[A-Z2-7]{7}/[A-Z2-7]{77}\z};

sub _empty_set {
    return {
        qw| nodes |         => [],
        qw| meta |          => [],
        qw| references |    => [],
        qw| releases |      => [],
        qw| trees |         => [],
        qw| categories |    => [],
        qw| assignments |   => [],
        qw| batches |       => [],
        qw| sync_cursors |  => [],
        qw| conflicts |     => [],
        qw| sync_releases | => [],
    };
}

sub _origin {
    my ( $disk, $record, $field ) = @ARG;
    my $origin
        = ref $record->{'origin'} eq qw| HASH |
        ? $record->{'origin'}
        : {};
    return {
        qw| disk | => $origin->{'disk'} // $disk,
        qw| id |   => $origin->{'id'}   // $record->{$field},
    };
}

sub _okey {
    return join "\0", $ARG[0]->{'disk'} // '', $ARG[0]->{'id'} // '';
}
sub _rkey { return join "\0", @ARG }

sub _address {
    my $address = shift // '';
    refuse( 'sync : bad content address [ %s ]', $address )
        if $address !~ $ADDR_RE;
    my ( $epoch_name, $amos, $bmw ) = split m|/|, $address;
    my $epoch = epoch_from_b32($epoch_name);
    refuse( 'sync : bad content address [ %s ]', $address )
        if not defined $epoch;
    return { qw| epoch | => $epoch, qw| amos | => $amos, qw| bmw | => $bmw };
}

sub _record_operation {
    my ( $record, @fields ) = @ARG;
    my %op = map { $ARG => $record->{$ARG} } @fields;
    $op{'origin'} = $record->{'origin'} if $record->{'origin'};
    return \%op;
}

sub _records {
    my ( $id, $kind, $subdir, $suffix ) = @ARG;
    return { map { $ARG->{'path'} => $ARG }
            record_scan( $id, $kind, $subdir, $suffix ) };
}

sub _policy_same {
    my ( $a, $b ) = @ARG;
    return FALSE if not defined $a or not defined $b;
    foreach my $field (
        qw| local_encryption copies priority replica
        foreign_work layer |
    ) {
        return FALSE if ( $a->{$field} // '' ) ne ( $b->{$field} // '' );
    }
    return
        join( "\0", sort $a->{'want'}->@* ) eq
        join( "\0", sort $b->{'want'}->@* ) ? TRUE : FALSE;
}

sub _new_conflict {
    my ( $c, $kind, $origin, $reference, $receiver, $source ) = @ARG;
    my $key = _okey($origin) . "\0" . ( $reference // '' );
    return if $c->{'conflict_origin'}{$key};
    my $payload = {
        qw| disk |     => $c->{'to'}{'disk'},
        qw| kind |     => $kind,
        qw| origin |   => $origin,
        qw| receiver | => $receiver,
        qw| source |   => $source,
    };
    $payload->{'reference'} = $reference if defined $reference;
    my $record = _record_write(
        $c,
        qw| sync_conflict |,
        qw| sync-conflicts |,
        qw| sync-conflict |, $payload
    );
    push $c->{'add'}{'conflicts'}->@*, { qw| path | => $record->{'path'} };
    $c->{'conflict_origin'}{$key} = $record;
    $c->{'count'}{'conflicts'}++;
    push $c->{'messages'}->@*,
        sprintf 'conflict %s %s : receiver [ %s ] ; source [ %s ]',
        $kind, $origin->{'id'}, $receiver // '', $source // '';
    return $record;
}

sub _record_write {
    my ( $c, $kind, $subdir, $suffix, $payload ) = @ARG;
    return record_write( $c->{'to'}, $c->{'store'}, $kind, $subdir, $suffix,
        $payload )
        if not $c->{'dry_run'};
    my $name = sprintf qw| %s.%s.%s |, ntime14( ntime_now() ),
        b32( random_bytes(5) ), $suffix;
    return { %{$payload}, qw| path | => $name };
}

sub _source_saw_receiver {
    my ( $c, $before, $name, $reference, $current ) = @ARG;
    return FALSE if not defined $current;
    my $current_origin = _origin( $c->{'to'}{'disk'}, $current, 'path' );
    if ( defined $reference ) {
        my $key  = _rkey( $reference->{'node'}, $reference->{'path'} );
        my $seen = $c->{'seen_receiver_assignment'}{$key}
            { _okey($current_origin) };
        return defined $seen && $seen < $before ? TRUE : FALSE;
    }
    my $seen
        = $c->{'seen_receiver_category'}{$name}{ _okey($current_origin) };
    return defined $seen && $seen < $before ? TRUE : FALSE;
}

sub _translate_address {
    my ( $c, $address ) = @ARG;
    my $addr = _address($address);
    return join '/', epoch_b32( $c->{'epoch'} ), $addr->{'amos'},
        $addr->{'bmw'};
}

sub _source_meta {
    my ( $c, $address, $holder ) = @ARG;
    my $addr = _address($address);
    my $read = codec(3)->{'read_node'}->(
        node_path( $c->{'from'}{'path'}, $addr ),
        $addr, { qw| id | => $c->{'from'} }
    );
    my $newest;
    foreach my $meta ( $read->{'metas'}->@* ) {
        next if defined $holder and ( $meta->{'source'} // '' ) ne $holder;
        $newest = $meta
            if not defined $newest
            or $meta->{'import_ntime'} gt $newest->{'import_ntime'};
    }
    refuse( 'sync : source node %s has no matching meta', $address )
        if not defined $newest;
    return $newest;
}

sub _copy_node {
    my ( $c, $source_address, $holder, $manifest_tree ) = @ARG;
    my $target_address = _translate_address( $c, $source_address );
    return $target_address if $c->{'node_ready'}{$target_address};
    refuse( 'sync : receiver has an unjournaled node %s', $target_address )
        if -e node_path( $c->{'to'}{'path'}, _address($target_address) )
        and not $c->{'target_replay'}{'nodes'}{$target_address};
    my $source_addr = _address($source_address);
    my $source_path = node_path( $c->{'from'}{'path'}, $source_addr );
    node_verify( $c->{'from'}{'path'}, $source_addr, 3, $c->{'from'} );
    my $meta = _source_meta( $c, $source_address, $holder );
    my $tmp_manifest;
    my $content = "$source_path/content";

    if ( defined $manifest_tree ) {
        $tmp_manifest = sprintf qw| %s/.n7fs/tmp/sync-manifest.%s |,
            $c->{'to'}{'path'}, b32( random_bytes(5) );
        if ( not $c->{'dry_run'} ) {
            make_dirs( "$c->{'to'}{'path'}/.n7fs/tmp", 0700 );
            my ( $in, $head ) = manifest_open(
                $c->{'from'},
                $c->{'from_state'},
                {   qw| name |     => $manifest_tree,
                    qw| manifest | => $source_address
                }
            );
            write_new_file_stream(
                $tmp_manifest,
                sub {
                    my $out = shift;
                    print {$out} $JSON->encode($head), "\n"
                        or die "manifest write : $OS_ERROR\n";
                    while ( my $entry = manifest_entry_read($in) ) {
                        $entry->{'a'}
                            = _translate_address( $c, $entry->{'a'} )
                            if defined $entry->{'a'};
                        print {$out} $JSON->encode($entry), "\n"
                            or die "manifest write : $OS_ERROR\n";
                    }
                    close $in or die "manifest close : $OS_ERROR\n";
                }
            );
            $content = $tmp_manifest;
            open( my $manifest_fh, '<:raw', $tmp_manifest )
                or refuse( 'sync : cannot read rewritten manifest : %s',
                $OS_ERROR );
            my ($digest) = bmw384_fh($manifest_fh);
            close $manifest_fh;
            my $bmw = bmw_b32($digest);
            $target_address = join '/', epoch_b32( $c->{'epoch'} ),
                amos_of_bmw($bmw), $bmw;
        }
    }
    my %new_meta = (
        %{$meta},
        qw| disk |         => $c->{'to'}{'disk'},
        qw| import_ntime | => ntime14( ntime_now() ),
        qw| epoch_num |    => epoch_num( ntime_now() ),
        qw| epoch |        => epoch_b32( $c->{'epoch'} ),
        qw| amos |         => ( split m|/|, $target_address )[1],
        qw| bmw |          => ( split m|/|, $target_address )[2],
        qw| size |         => -s $content,
        qw| host |         => qw| sync |,
        qw| origin |       => _origin(
            $c->{'from'}{'disk'}, { qw| path | => $meta->{'import_ntime'} },
            'path'
        ),
    );
    $new_meta{'origin'}{'id'} = join ':', 'meta', $source_address,
        $meta->{'import_ntime'}, $meta->{'source'} // '';
    if (    not $c->{'dry_run'}
        and not $c->{'target_replay'}{'nodes'}{$target_address} ) {
        if ( not grep { $ARG == $c->{'epoch'} }
            $c->{'to_state'}{'epochs'}->@* ) {
            state_write(
                $c->{'to'}{'path'},
                {   %{ $c->{'to_state'} },
                    qw| epochs | =>
                        [ $c->{'to_state'}{'epochs'}->@*, $c->{'epoch'} ]
                },
                $c->{'store'}
            );
            $c->{'to_state'}
                = state_read( $c->{'to'}{'path'}, $c->{'to'}{'store_pub'} );
        }
        my $target_addr = _address($target_address);
        my $final       = node_path( $c->{'to'}{'path'}, $target_addr );
        make_dirs( $final =~ s|/[^/]+\z||r, 0700 );
        my $tmp = "$final.tmp." . b32( random_bytes(5) );
        make_dirs( $tmp, 0700 );
        my $ok = eval {
            codec(3)->{'write_node'}->(
                $tmp,
                {   qw| addr |         => $target_addr,
                    qw| content_path | => $content,
                    qw| metas |        => [ \%new_meta ],
                },
                { qw| id | => $c->{'to'}, qw| store | => $c->{'store'} }
            );
            fault(qw| sync:before-node-publish |);
            publish_dir( $tmp, $final );
            codec(3)->{'verify_node'}->(
                $final, $target_addr,
                { qw| id | => $c->{'to'}, qw| store | => $c->{'store'} }
            );
            1;
        };
        if ( not $ok ) {
            my $err = $EVAL_ERROR;
            remove_tree($tmp);
            unlink $tmp_manifest if defined $tmp_manifest;
            die $err;
        }
        opendir( my $dh, "$final/meta" )
            or refuse( 'sync : cannot read new node meta : %s', $OS_ERROR );
        my ($meta_name) = grep { $ARG =~ m|\.meta\z| } readdir $dh;
        closedir $dh;
        push $c->{'add'}{'nodes'}->@*, $target_address;
        push $c->{'add'}{'meta'}->@*,
            { qw| node | => $target_address, qw| name | => $meta_name };
        $c->{'target_replay'}{'nodes'}{$target_address} = TRUE;
        $c->{'count'}{'nodes'}++;
        $c->{'count'}{'bytes'} += -s "$final/content";
    } elsif ( not $c->{'dry_run'} ) {
        my $target_addr = _address($target_address);
        my $final       = node_path( $c->{'to'}{'path'}, $target_addr );
        codec(3)->{'verify_node'}->(
            $final, $target_addr,
            { qw| id | => $c->{'to'}, qw| store | => $c->{'store'} }
        );
        my $read = codec(3)->{'read_node'}
            ->( $final, $target_addr, { qw| id | => $c->{'to'} } );
        my $has_meta = grep {
            ( $ARG->{'source'} // '' ) eq ( $new_meta{'source'} // '' )
        } $read->{'metas'}->@*;
        if ( not $has_meta ) {
            my $meta_name = codec(3)->{'write_meta'}->(
                $final, \%new_meta, $target_addr,
                { qw| id | => $c->{'to'}, qw| store | => $c->{'store'} }
            );
            push $c->{'add'}{'meta'}->@*,
                { qw| node | => $target_address, qw| name | => $meta_name };
        }
    }
    unlink $tmp_manifest if defined $tmp_manifest and not $c->{'dry_run'};
    $c->{'node_ready'}{$target_address} = TRUE;
    return $target_address;
}

sub _reference_for {
    my ( $c, $source_ref ) = @ARG;
    my $origin = _origin( $c->{'from'}{'disk'}, $source_ref, 'path' );
    return ( $origin, $c->{'ref_origin'}{ _okey($origin) } );
}

sub _add_reference {
    my ( $c, $source_ref ) = @ARG;
    return if $c->{'trees_only'} or $source_ref->{'released'};
    my ( $origin, $existing ) = _reference_for( $c, $source_ref );
    return if $origin->{'disk'} eq $c->{'to'}{'disk'};
    return if defined $existing;
    my $key = _okey($origin);
    return if $c->{'dropped_origin'}{$key};
    my $target_address
        = _copy_node( $c, $source_ref->{'node'}, $source_ref->{'holder'} );
    my $target_addr = _address($target_address);
    my $node        = {
        %{$target_addr},
        qw| path | => node_path( $c->{'to'}{'path'}, $target_addr )
    };
    my $ref;

    if ( $c->{'dry_run'} ) {
        my $ntime = ntime14( ntime_now() + ++$c->{'dry_ref_seq'} );
        $ref = {
            qw| disk |   => $c->{'to'}{'disk'},
            qw| node |   => $target_address,
            qw| addr |   => $target_address,
            qw| holder | => $source_ref->{'holder'},
            qw| name |   => $source_ref->{'name'},
            qw| ntime |  => $ntime,
            qw| path |   => "$ntime/$target_addr->{'amos'}"
                . "/$target_addr->{'bmw'}/addr",
            qw| origin |  => $origin,
            qw| dropped | => FALSE,
        };
    } else {
        $ref
            = reference_write( $node, $c->{'to'}, $c->{'store'},
            $source_ref->{'holder'},
            $source_ref->{'name'}, FALSE, undef, $origin );
    }
    push $c->{'add'}{'references'}->@*,
        _record_operation( $ref, qw| node path holder name | );
    $c->{'ref_origin'}{$key} = $ref;
    push $c->{'target_refs_by_node'}{ $ref->{'node'} }->@*, $ref;
    $c->{'count'}{'references'}++;
    return $ref;
}

sub _add_category {
    my ( $c, $source, $index ) = @ARG;
    my $origin = _origin( $c->{'from'}{'disk'}, $source, 'path' );
    return if $c->{'category_origin'}{ _okey($origin) };
    my $current = $c->{'definitions'}{ $source->{'name'} };
    return if _policy_same( $current, $source );
    if (defined $current
        and not _source_saw_receiver(
            $c, $index, $source->{'name'}, undef, $current
        )
    ) {
        my $merged
            = category_strict_merge( $source->{'name'}, $current, $source );
        $source = { %{$source}, %{$merged} };
        $c->{'count'}{'category_merges'}++;
        push $c->{'messages'}->@*,
            "category merge $source->{'name'} : strictest effective policy";
    }
    my $record = _record_write(
        $c,
        qw| category |,
        qw| categories |,
        qw| category |,
        {   %{$source},
            qw| disk |   => $c->{'to'}{'disk'},
            qw| origin | => $origin,
            qw| ntime |  => undef,
        }
    );
    push $c->{'add'}{'categories'}->@*,
        _record_operation( $record, qw| name path | );
    $c->{'definitions'}{ $source->{'name'} } = $record;
    $c->{'category_origin'}{ _okey($origin) } = $record;
    $c->{'count'}{'categories'}++;
    return;
}

sub _add_tree {
    my ( $c, $source ) = @ARG;
    return
        if not $c->{'source_replay'}{'trees'}{ $source->{'name'} }
        or $c->{'source_replay'}{'trees'}{ $source->{'name'} }{'path'} ne
        $source->{'path'};
    my $origin = _origin( $c->{'from'}{'disk'}, $source, 'path' );
    return if $c->{'tree_origin'}{ _okey($origin) };
    if ( my $current = $c->{'live_trees'}{ $source->{'name'} } ) {
        my $current_origin
            = _origin( $c->{'to'}{'disk'}, $current, 'path' );
        return if _okey($current_origin) eq _okey($origin);
        _new_conflict(
            $c, qw| tree |, $origin, undef,
            "$source->{'name'} $current->{'manifest'}",
            "$source->{'name'} $source->{'manifest'}"
        );
        return;
    }
    my ($manifest_fh) = manifest_open(
        $c->{'from'},
        $c->{'from_state'},
        {   qw| name |     => $source->{'name'},
            qw| manifest | => $source->{'manifest'}
        }
    );
    while ( my $entry = manifest_entry_read($manifest_fh) ) {
        _copy_node( $c, $entry->{'a'} ) if defined $entry->{'a'};
    }
    close $manifest_fh
        or
        refuse( 'sync : cannot close source manifest %s', $source->{'name'} );
    my $manifest
        = _copy_node( $c, $source->{'manifest'}, "tree:$source->{'name'}",
        $source->{'name'} );
    my $record = _record_write(
        $c,
        qw| tree |,
        qw| trees |,
        qw| tree |,
        {   qw| disk |     => $c->{'to'}{'disk'},
            qw| name |     => $source->{'name'},
            qw| manifest | => $manifest,
            qw| created |  => $source->{'created'},
            qw| origin |   => $origin,
        }
    );
    push $c->{'add'}{'trees'}->@*,
        _record_operation( $record, qw| name path manifest created | );
    $c->{'live_trees'}{ $source->{'name'} } = $record;
    $c->{'tree_origin'}{ _okey($origin) }   = $record;
    $c->{'tree_address'}{$manifest}         = TRUE;
    $c->{'count'}{'trees'}++;
    return;
}

sub _assignment_values {
    my ( $c,    $source_ref ) = @ARG;
    my ( undef, $target_ref ) = _reference_for( $c, $source_ref );
    return if not defined $target_ref;
    my $key = _rkey( $target_ref->{'node'}, $target_ref->{'path'} );
    return ( $target_ref, $c->{'assignments'}{$key}, $key );
}

sub _assignment_allowed {
    my ( $c, $source, $source_ref, $index, $origin ) = @ARG;
    my ( $target_ref, $current, $key )
        = _assignment_values( $c, $source_ref );
    return ( undef, undef ) if not defined $target_ref;
    return ( undef, undef )
        if defined $current
        and $current->{'category'} eq $source->{'category'};
    if ( defined $current
        and
        not _source_saw_receiver( $c, $index, undef, $source_ref, $current ) )
    {
        _new_conflict(
            $c, qw| assignment |,
            $origin, $target_ref->{'path'}, $current->{'category'},
            $source->{'category'}
        );
        return ( undef, undef );
    }
    return ( $target_ref, $key );
}

sub _add_assignment {
    my ( $c, $source, $index ) = @ARG;
    return if $c->{'trees_only'};
    my $origin = _origin( $c->{'from'}{'disk'}, $source, 'path' );
    return if $c->{'assignment_origin'}{ _okey($origin) };
    my $source_ref = $c->{'source_refs'}{ $source->{'reference'} };
    refuse('sync : assignment source reference is missing')
        if not defined $source_ref;
    my ( $target_ref, $key )
        = _assignment_allowed( $c, $source, $source_ref, $index, $origin );
    return if not defined $target_ref;
    my $record = _record_write(
        $c,
        qw| assignment |,
        qw| assignments |,
        qw| assignment |,
        {   qw| disk |      => $c->{'to'}{'disk'},
            qw| node |      => $target_ref->{'node'},
            qw| reference | => $target_ref->{'path'},
            qw| holder |    => $target_ref->{'holder'},
            qw| category |  => $source->{'category'},
            qw| origin |    => $origin,
        }
    );
    push $c->{'add'}{'assignments'}->@*,
        _record_operation( $record, qw| node reference path category | );
    $c->{'assignments'}{$key} = $record;
    $c->{'assignment_origin'}{ _okey($origin) } = $record;
    $c->{'count'}{'assignments'}++;
    return;
}

sub _add_batch {
    my ( $c, $source, $index ) = @ARG;
    return if $c->{'trees_only'};
    my $origin = _origin( $c->{'from'}{'disk'}, $source, 'path' );
    return if $c->{'batch_origin'}{ _okey($origin) };
    my ( @refs, @keys );
    foreach my $item ( $source->{'references'}->@* ) {
        my $source_ref = $c->{'source_refs'}{ $item->{'reference'} };
        refuse('sync : batch source reference is missing')
            if not defined $source_ref;
        my $as = {
            qw| category | => $source->{'category'},
            qw| path |     => $source->{'path'},
        };
        my ( $target_ref, $key )
            = _assignment_allowed( $c, $as, $source_ref, $index, $origin );
        next if not defined $target_ref;
        push @refs, $target_ref;
        push @keys, $key;
    }
    return if not @refs;
    my $record;
    if ( $c->{'dry_run'} ) {
        $record = _record_write(
            $c,
            qw| batch |,
            qw| batch-assignments |,
            qw| batch-assignment |,
            { qw| disk | => $c->{'to'}{'disk'}, qw| origin | => $origin }
        );
    } else {
        $record = batch_write( $c->{'to'}, $c->{'store'},
            $source->{'category'}, \@refs, $source->{'bytes'}, $origin );
    }
    push $c->{'add'}{'batches'}->@*,
        {
        qw| path |     => $record->{'path'},
        qw| category | => $source->{'category'},
        qw| origin |   => $origin,
        };
    foreach my $key (@keys) {
        $c->{'assignments'}{$key} = {
            qw| category | => $source->{'category'},
            qw| origin |   => $origin,
        };
    }
    $c->{'batch_origin'}{ _okey($origin) } = $record;
    $c->{'count'}{'batches'}++;
    return;
}

sub _drop_reference {
    my ( $c, $source ) = @_;
    return if $c->{'trees_only'};
    my ( $origin, $target ) = _reference_for( $c, $source );
    return if not defined $target or $target->{'dropped'};
    return if $c->{'dropped_origin'}{ _okey($origin) };
    if ( not $c->{'dry_run'} ) {
        reference_drop_write( $target, $c->{'to'}, $c->{'store'} );
    }
    push $c->{'drop'}{'references'}->@*,
        _record_operation( $target, qw| node path holder name | );
    $target->{'dropped'} = TRUE;
    $c->{'dropped_origin'}{ _okey($origin) } = TRUE;
    $c->{'count'}{'drops'}++;
    return;
}

sub _drop_tree {
    my ( $c, $source ) = @_;
    my $tree_origin = {
        qw| disk | => $c->{'from'}{'disk'},
        qw| id |   => $source->{'tree'}
    };
    $tree_origin = $c->{'tree_records'}{ $source->{'tree'} }{'origin'}
        if ref $c->{'tree_records'}{ $source->{'tree'} }{'origin'};
    my $target = $c->{'tree_origin'}{ _okey($tree_origin) };
    return if not defined $target;
    my $current = $c->{'live_trees'}{ $target->{'name'} };
    return if not defined $current or $current->{'path'} ne $target->{'path'};
    my $origin = _origin( $c->{'from'}{'disk'}, $source, 'path' );
    return if $c->{'tree_drop_origin'}{ _okey($origin) };
    my $record = _record_write(
        $c,
        qw| tree_drop |,
        qw| tree-drops |,
        qw| tree-drop |,
        {   qw| disk |   => $c->{'to'}{'disk'},
            qw| name |   => $target->{'name'},
            qw| tree |   => $target->{'path'},
            qw| origin | => $origin,
        }
    );
    push $c->{'drop'}{'trees'}->@*,
        _record_operation( $record, qw| name path tree | );
    delete $c->{'live_trees'}{ $target->{'name'} };
    $c->{'tree_drop_origin'}{ _okey($origin) } = $record;
    $c->{'count'}{'drops'}++;
    return;
}

sub _retained_release {
    my ( $c, $source_address ) = @_;
    return if $c->{'trees_only'};
    return if $c->{'source_replay'}{'nodes'}{$source_address};
    my $target_address = _translate_address( $c, $source_address );
    return if $c->{'released_address'}{$target_address};
    my ( @drops, %release_origin );
    foreach
        my $ref ( ( $c->{'source_release_refs'}{$source_address} // [] )->@* )
    {
        my $origin = _origin( $c->{'from'}{'disk'}, $ref, 'path' );
        $release_origin{ _okey($origin) } = TRUE;
        my $target = $c->{'ref_origin'}{ _okey($origin) };
        next if not defined $target or $target->{'dropped'};
        reference_drop_write( $target, $c->{'to'}, $c->{'store'} )
            if not $c->{'dry_run'};
        push @drops,
            _record_operation( $target, qw| node path holder name | );
        $target->{'dropped'} = TRUE;
        $c->{'dropped_origin'}{ _okey($origin) } = TRUE;
    }
    my @other_live = grep {
        my $origin = _origin( $c->{'to'}{'disk'}, $ARG, 'path' );
        not $ARG->{'dropped'} and not $release_origin{ _okey($origin) }
    } ( $c->{'target_refs_by_node'}{$target_address} // [] )->@*;
    my $tree_held = $c->{'tree_address'}{$target_address};
    if ( @other_live or $tree_held ) {
        push $c->{'drop'}{'references'}->@*, @drops;
        push $c->{'messages'}->@*,
            "release retained $target_address "
            . ": live references or trees remain";
        $c->{'count'}{'retained'}++;
        return;
    }
    my $origin = {
        qw| disk | => $c->{'from'}{'disk'},
        qw| id |   => $source_address
    };
    my $addr  = _address($target_address);
    my $ntime = ntime14( ntime_now() );
    my $name  = "$ntime.$addr->{'amos'}.$addr->{'bmw'}.tombstone";
    if ( not $c->{'dry_run'} ) {
        make_dirs( "$c->{'to'}{'path'}/.n7fs/tombstones", 0700 );
        write_new_file(
            "$c->{'to'}{'path'}/.n7fs/tombstones/$name",
            signed_record_pack(
                qw| tombstone |,
                {   qw| disk |   => $c->{'to'}{'disk'},
                    qw| addr |   => $target_address,
                    qw| ntime |  => $ntime,
                    qw| reason | => 'synced retained release',
                    qw| origin | => $origin,
                },
                $c->{'store'},
                3
            )
        );
    }
    push $c->{'drop'}{'sync_releases'}->@*,
        {
        qw| node |       => $target_address,
        qw| origin |     => $origin,
        qw| references | => \@drops,
        };
    $c->{'released_address'}{$target_address} = TRUE;
    $c->{'count'}{'releases'}++;
    return;
}

sub _source_hash {
    my $entry = shift;
    return bmw_b32( bmw384_bytes( $entry->{'bytes'} ) );
}

sub _indexes {
    my $c = shift;
    $c->{'source_refs'} = {
        map { $ARG->{'path'} => $ARG } reference_entries(
            qw| root |           => $c->{'root'},
            qw| host_dir |       => $c->{'host_dir'},
            qw| host |           => $c->{'host'},
            qw| allow_rollback | => $c->{'allow_rollback'},
            qw| disk |           => $c->{'from'}{'disk'},
        )
    };
    $c->{'tree_records'}
        = _records( $c->{'from'}, qw| tree |, qw| trees |, qw| tree | );
    $c->{'tree_drops'} = _records(
        $c->{'from'},
        qw| tree_drop |,
        qw| tree-drops |,
        qw| tree-drop |
    );
    $c->{'category_records'} = _records(
        $c->{'from'},
        qw| category |,
        qw| categories |,
        qw| category |
    );
    $c->{'assignment_records'} = _records(
        $c->{'from'},
        qw| assignment |,
        qw| assignments |,
        qw| assignment |
    );
    $c->{'batches'} = {
        map { $ARG->{'path'} => $ARG } record_scan(
            $c->{'from'},
            qw| batch |,
            qw| batch-assignments |,
            qw| batch-assignment |
        )
    };
    require AMOS7::N7FS::Release;
    my %journaled_release
        = map { $ARG => TRUE } $c->{'source_replay'}{'release_order'}->@*;
    $c->{'unjournaled_releases'} = [];
    my $tombstones = "$c->{'from'}{'path'}/.n7fs/tombstones";

    if ( -d $tombstones ) {
        opendir( my $dh, $tombstones )
            or
            refuse( 'sync : cannot read source tombstones : %s', $OS_ERROR );
        my @names = sort grep { $ARG =~ m|\.tombstone\z| } readdir $dh;
        closedir $dh;
        foreach my $name (@names) {
            my $tombstone
                = AMOS7::N7FS::Release::tombstone_read( $c->{'from'},
                "$tombstones/$name" );
            push $c->{'unjournaled_releases'}->@*, $tombstone->{'addr'}
                if not $journaled_release{ $tombstone->{'addr'} };
        }
    }
    $c->{'seen_receiver_category'}   = {};
    $c->{'seen_receiver_assignment'} = {};
    foreach my $index ( 0 .. $c->{'source_replay'}{'entries'}->@* - 1 ) {
        my $p = $c->{'source_replay'}{'entries'}[$index]{'payload'};
        foreach my $category ( $p->{'add'}{'categories'}->@* ) {
            my $origin = _origin( $c->{'from'}{'disk'}, $category, 'path' );
            $c->{'seen_receiver_category'}{ $category->{'name'} }
                { _okey($origin) } = $index;
        }
        foreach my $assignment ( $p->{'add'}{'assignments'}->@* ) {
            my $origin = _origin( $c->{'from'}{'disk'}, $assignment, 'path' );
            my $key
                = _rkey( $assignment->{'node'}, $assignment->{'reference'} );
            $c->{'seen_receiver_assignment'}{$key}{ _okey($origin) } = $index;
        }
        foreach my $batch ( $p->{'add'}{'batches'}->@* ) {
            my $origin = _origin( $c->{'from'}{'disk'}, $batch, 'path' );
            my $record = $c->{'batches'}{ $batch->{'path'} };
            foreach my $ref ( $record->{'references'}->@* ) {
                my $key = _rkey( $ref->{'node'}, $ref->{'reference'} );
                $c->{'seen_receiver_assignment'}{$key}{ _okey($origin) }
                    = $index;
            }
        }
    }
    $c->{'ref_origin'}     = {};
    $c->{'dropped_origin'} = {};
    my @target_refs = reference_entries(
        qw| root |           => $c->{'root'},
        qw| host_dir |       => $c->{'host_dir'},
        qw| host |           => $c->{'host'},
        qw| allow_rollback | => $c->{'allow_rollback'},
        qw| disk |           => $c->{'to'}{'disk'},
    );
    foreach my $ref (@target_refs) {
        my $origin = _origin( $c->{'to'}{'disk'}, $ref, 'path' );
        $c->{'ref_origin'}{ _okey($origin) } = $ref;
    }
    foreach my $ref ( values $c->{'target_replay'}{'ref_history'}->%* ) {
        my $origin = _origin( $c->{'to'}{'disk'}, $ref, 'path' );
        $c->{'ref_origin'}{ _okey($origin) } //= $ref;
        $c->{'dropped_origin'}{ _okey($origin) } = TRUE
            if $ref->{'dropped'} or $ref->{'released'};
    }
    $c->{'source_release_refs'} = {};
    foreach my $ref ( values $c->{'source_replay'}{'ref_history'}->%* ) {
        next if not $ref->{'released'};
        push $c->{'source_release_refs'}{ $ref->{'node'} }->@*, $ref;
    }
    $c->{'target_refs_by_node'} = {};
    push $c->{'target_refs_by_node'}{ $ARG->{'node'} }->@*, $ARG
        for values $c->{'ref_origin'}->%*;
    foreach my $release ( $c->{'target_replay'}{'sync_release_order'}->@* ) {
        $c->{'released_address'}{ $release->{'node'} } = TRUE;
        foreach my $ref ( $release->{'references'}->@* ) {
            my $origin = _origin( $c->{'to'}{'disk'}, $ref, 'path' );
            $c->{'dropped_origin'}{ _okey($origin) } = TRUE;
        }
    }
    $c->{'tree_origin'}
        = {
        map { _okey( _origin( $c->{'to'}{'disk'}, $ARG, 'path' ) ) => $ARG }
            values $c->{'target_replay'}{'tree_history'}->%* };
    $c->{'tree_drop_origin'}
        = {
        map { _okey( _origin( $c->{'to'}{'disk'}, $ARG, 'path' ) ) => $ARG }
            values $c->{'target_replay'}{'tree_drops'}->%* };
    $c->{'live_trees'}   = { $c->{'target_replay'}{'trees'}->%* };
    $c->{'tree_address'} = AMOS7::N7FS::Tree::tree_live_addresses( $c->{'to'},
        $c->{'to_state'}, $c->{'target_replay'} );
    $c->{'category_origin'}
        = {
        map { _okey( _origin( $c->{'to'}{'disk'}, $ARG, 'path' ) ) => $ARG }
            values $c->{'target_replay'}{'category_history'}->%* };
    $c->{'assignment_origin'}
        = {
        map { _okey( _origin( $c->{'to'}{'disk'}, $ARG, 'path' ) ) => $ARG }
            values $c->{'target_replay'}{'assignment_history'}->%* };
    $c->{'batch_origin'}
        = {
        map { _okey( _origin( $c->{'to'}{'disk'}, $ARG, 'path' ) ) => $ARG }
            values $c->{'target_replay'}{'batch_history'}->%* };
    $c->{'assignments'} = { $c->{'target_replay'}{'assignments'}->%* };
    $c->{'definitions'}
        = category_definitions( $c->{'to'}, $c->{'target_replay'} );
    $c->{'conflict_origin'} = {};

    foreach
        my $path ( keys $c->{'target_replay'}{'sync_conflict_history'}->%* ) {
        my $record = $c->{'target_conflict_records'}{$path};
        $c->{'conflict_origin'}{ _okey( $record->{'origin'} ) . "\0"
                . ( $record->{'reference'} // '' ) } = $record
            if defined $record;
    }
    return;
}

sub _revisit_tree_conflicts {
    my $c = shift;
    foreach
        my $path ( sort keys $c->{'target_replay'}{'sync_conflicts'}->%* ) {
        my $conflict = $c->{'target_conflict_records'}{$path};
        next if not defined $conflict or $conflict->{'kind'} ne qw| tree |;
        my $origin = $conflict->{'origin'};
        my ($source) = grep {
            _okey( _origin( $c->{'from'}{'disk'}, $ARG, 'path' ) ) eq
                _okey($origin)
        } values $c->{'tree_records'}->%*;
        my $live
            = defined $source
            && $c->{'source_replay'}{'trees'}{ $source->{'name'} }
            && $c->{'source_replay'}{'trees'}{ $source->{'name'} }{'path'} eq
            $source->{'path'};
        if ( not $live ) {
            push $c->{'drop'}{'conflicts'}->@*, { qw| path | => $path };
            next;
        }
        _add_tree( $c, $source );
        my $imported = $c->{'tree_origin'}{ _okey($origin) };
        push $c->{'drop'}{'conflicts'}->@*, { qw| path | => $path }
            if defined $imported
            and $c->{'live_trees'}{ $source->{'name'} }
            and $c->{'live_trees'}{ $source->{'name'} }{'path'} eq
            $imported->{'path'};
    }
    return;
}

sub store_sync {
    my %opt = @ARG;
    refuse('sync : source and receiver are the same disk')
        if $opt{'from'} eq $opt{'to'};
    my $from = disk_read_id( %opt, qw| disk | => $opt{'from'} );
    my $to   = disk_read_id( %opt, qw| disk | => $opt{'to'} );
    refuse('sync : source and receiver have the same disk id [ clone ]')
        if $from->{'disk'} eq $to->{'disk'};
    my ( $first, $second ) = sort { $a->{'disk'} cmp $b->{'disk'} } $from,
        $to;
    my $mode   = $opt{'dry_run'} ? qw| shared | : undef;
    my $lock_a = disk_lock( $first,
        $first->{'disk'} eq $from->{'disk'} ? qw| shared | : $mode );
    my $lock_b = disk_lock( $second,
        $second->{'disk'} eq $from->{'disk'} ? qw| shared | : $mode );
    $from = disk_require_attached( %opt, qw| disk | => $opt{'from'} );
    $to   = disk_require_attached( %opt, qw| disk | => $opt{'to'} );
    my $from_state = state_read( $from->{'path'}, $from->{'store_pub'} );
    my $to_state   = state_read( $to->{'path'},   $to->{'store_pub'} );
    refuse('sync : both disks must use store format 3')
        if $from_state->{'store_format'} != 3
        or $to_state->{'store_format'} != 3;
    my $store = $opt{'dry_run'} ? undef : store_key_signer( %opt, id => $to );
    my $source_replay    = journal_replay($from);
    my $target_replay    = journal_replay($to);
    my $target_conflicts = _records(
        $to,
        qw| sync_conflict |,
        qw| sync-conflicts |,
        qw| sync-conflict |
    );
    my $cursor = $target_replay->{'sync_cursors'}{ $from->{'disk'} };

    if ( defined $cursor ) {
        refuse(
            'sync : source %s head %d is below cursor %d [ rolled back ]',
            $from->{'disk'},
            $source_replay->{'seq'},
            $cursor->{'source_seq'}
        ) if $source_replay->{'seq'} < $cursor->{'source_seq'};
        my $entry
            = $source_replay->{'entries'}[ $cursor->{'source_seq'} - 1 ];
        refuse(
            'sync : source %s entry %d hash differs '
                . 'from cursor [ rewritten or rolled back ]',
            $from->{'disk'},
            $cursor->{'source_seq'}
            )
            if not defined $entry
            or _source_hash($entry) ne $cursor->{'source_hash'};
    }
    my $last = $source_replay->{'entries'}[-1];
    my $c    = {
        %opt,
        qw| from |                    => $from,
        qw| to |                      => $to,
        qw| from_state |              => $from_state,
        qw| to_state |                => $to_state,
        qw| store |                   => $store,
        qw| source_replay |           => $source_replay,
        qw| target_replay |           => $target_replay,
        qw| target_conflict_records | => $target_conflicts,
        qw| epoch |                   => write_epoch($to_state),
        qw| add |                     => _empty_set(),
        qw| drop |                    => _empty_set(),
        qw| node_ready |              => {},
        qw| released_address |        => {},
        qw| messages |                => [],
        qw| count |                   => {
            map { $ARG => 0 }
                qw| nodes bytes references trees categories assignments drops
                conflicts batches releases retained category_merges |
        },
        qw| dry_run |    => $opt{'dry_run'}    ? TRUE : FALSE,
        qw| trees_only | => $opt{'trees_only'} ? TRUE : FALSE,
    };
    my $start = defined $cursor ? $cursor->{'source_seq'} : 0;
    _indexes($c);
    my $needs_hold = FALSE;
    foreach my $index ( $start .. $source_replay->{'seq'} - 1 ) {
        my $p = $source_replay->{'entries'}[$index]{'payload'};
        foreach my $operation ( $p->{'drop'}{'trees'}->@* ) {
            my $source = $c->{'tree_drops'}{ $operation->{'path'} }
                // refuse('sync : source tree-drop record is missing');
            my $origin = {
                qw| disk | => $from->{'disk'},
                qw| id |   => $source->{'tree'}
            };
            $origin = $c->{'tree_records'}{ $source->{'tree'} }{'origin'}
                if ref $c->{'tree_records'}{ $source->{'tree'} }{'origin'};
            my $target  = $c->{'tree_origin'}{ _okey($origin) };
            my $current = $c->{'live_trees'}{ $target->{'name'} // '' };
            $needs_hold = TRUE
                if defined $target
                and defined $current
                and $current->{'path'} eq $target->{'path'};
        }
        next if $c->{'trees_only'};
        foreach my $operation ( $p->{'drop'}{'references'}->@* ) {
            my ( undef, $target ) = _reference_for( $c, $operation );
            $needs_hold = TRUE
                if defined $target
                and not $target->{'dropped'}
                and not $c->{'dropped_origin'}
                { _okey( _origin( $from->{'disk'}, $operation, 'path' ) ) };
        }
        foreach my $address ( $p->{'drop'}{'releases'}->@* ) {
            next if $source_replay->{'nodes'}{$address};
            my $target = _translate_address( $c, $address );
            $needs_hold = TRUE if not $c->{'released_address'}{$target};
        }
    }
    my $hold;
    if ( $needs_hold and not $opt{'no_hold'} ) {
        if ( $c->{'dry_run'} ) {
            push $c->{'messages'}->@*,
                "would hold journal "
                . "$target_replay->{'seq'} before sync drops";
        } else {
            $hold = hold_create(
                %opt,
                qw| disk |     => $to->{'disk'},
                qw| seq |      => $target_replay->{'seq'},
                qw| source |   => $from->{'disk'},
                qw| reason |   => 'before sync drops',
                qw| hold_age | => $opt{'hold_age'},
                qw| _id |      => $to,
                qw| _store |   => $store,
                qw| _replay |  => $target_replay,
            );
            $c->{'journal_seq'} = $hold->{'journal_seq'};
            push $c->{'messages'}->@*,
                "hold $hold->{'path'} before sync from $from->{'disk'} [ "
                . "journal $hold->{'seq'} ; expires $hold->{'expires'} ]";
            fault(qw| sync:after-hold |);
        }
    }
    _revisit_tree_conflicts($c);
    foreach my $index ( $start .. $source_replay->{'seq'} - 1 ) {
        my $p = $source_replay->{'entries'}[$index]{'payload'};
        _drop_tree( $c,
            $c->{'tree_drops'}{ $ARG->{'path'} }
                // refuse('sync : source tree-drop record is missing') )
            for $p->{'drop'}{'trees'}->@*;
    }
    fault(qw| sync:after-tree-drops |);
    my $early_seq;
    if ( $c->{'drop'}{'trees'}->@* and not $c->{'dry_run'} ) {
        fault(qw| sync:before-tree-drop-journal |);
        my $early_add  = _empty_set();
        my $early_drop = _empty_set();
        $early_drop->{'trees'} = $c->{'drop'}{'trees'};
        my $journal
            = journal_write( $to, $store, $early_add, $early_drop, {} );
        $early_seq            = $journal->{'seq'};
        $c->{'journal_seq'}   = $early_seq;
        $c->{'drop'}{'trees'} = [];
        witness_note_format(
            %opt,
            qw| disk |        => $to->{'disk'},
            qw| id |          => $to,
            qw| state |       => $c->{'to_state'},
            qw| journal_seq | => $early_seq
        );
        fault(qw| sync:after-tree-drop-journal |);
    }
    foreach my $index ( $start .. $source_replay->{'seq'} - 1 ) {
        my $p = $source_replay->{'entries'}[$index]{'payload'};
        $c->{'current_index'} = $index;
        _add_category(
            $c,
            $c->{'category_records'}{ $ARG->{'path'} }
                // refuse('sync : source category record is missing'),
            $index
        ) for $p->{'add'}{'categories'}->@*;
    }
    fault(qw| sync:after-categories |);
    foreach my $index ( $start .. $source_replay->{'seq'} - 1 ) {
        my $p = $source_replay->{'entries'}[$index]{'payload'};
        _add_reference( $c,
            $c->{'source_refs'}{ $ARG->{'path'} }
                // refuse('sync : source reference record is missing') )
            for $p->{'add'}{'references'}->@*;
    }
    fault(qw| sync:after-nodes |);
    fault(qw| sync:after-meta |);
    fault(qw| sync:after-references |);
    foreach my $index ( $start .. $source_replay->{'seq'} - 1 ) {
        my $p = $source_replay->{'entries'}[$index]{'payload'};
        _add_tree( $c,
            $c->{'tree_records'}{ $ARG->{'path'} }
                // refuse('sync : source tree record is missing') )
            for $p->{'add'}{'trees'}->@*;
    }
    fault(qw| sync:after-trees |);
    foreach my $index ( $start .. $source_replay->{'seq'} - 1 ) {
        my $p = $source_replay->{'entries'}[$index]{'payload'};
        _add_assignment(
            $c,
            $c->{'assignment_records'}{ $ARG->{'path'} }
                // refuse('sync : source assignment record is missing'),
            $index
        ) for $p->{'add'}{'assignments'}->@*;
        _add_batch(
            $c,
            $c->{'batches'}{ $ARG->{'path'} }
                // refuse('sync : source batch record is missing'),
            $index
        ) for $p->{'add'}{'batches'}->@*;
    }
    fault(qw| sync:after-assignments |);
    fault(qw| sync:after-batches |);
    foreach my $index ( $start .. $source_replay->{'seq'} - 1 ) {
        my $p = $source_replay->{'entries'}[$index]{'payload'};
        _drop_reference( $c, $ARG ) for $p->{'drop'}{'references'}->@*;
    }
    fault(qw| sync:after-drops |);
    foreach my $index ( $start .. $source_replay->{'seq'} - 1 ) {
        my $p = $source_replay->{'entries'}[$index]{'payload'};
        _retained_release( $c, $ARG ) for $p->{'drop'}{'releases'}->@*;
    }
    fault(qw| sync:after-releases |);
    my $work = grep { $c->{'add'}{$ARG}->@* }
        qw| nodes meta references trees categories assignments batches conflicts |;
    $work ||= $c->{'drop'}{'references'}->@*;
    $work ||= $c->{'drop'}{'trees'}->@*;
    $work ||= $c->{'drop'}{'sync_releases'}->@*;
    $work ||= $c->{'drop'}{'conflicts'}->@*;
    if ( not $work ) {
        return {
            qw| changed | => ( defined $early_seq or defined $hold )
            ? TRUE
            : FALSE,
            qw| count |       => $c->{'count'},
            qw| messages |    => $c->{'messages'},
            qw| journal_seq | => $c->{'journal_seq'} // $early_seq,
            qw| hold |        => $hold,
            qw| dry_run |     => $c->{'dry_run'},
        };
    }
    if ( not $c->{'trees_only'} ) {
        my $cursor_record = _record_write(
            $c,
            qw| sync_cursor |,
            qw| sync-cursors |,
            qw| sync-cursor |,
            {   qw| disk |        => $to->{'disk'},
                qw| source |      => $from->{'disk'},
                qw| source_seq |  => $source_replay->{'seq'} + 0,
                qw| source_hash | => _source_hash($last),
            }
        );
        push $c->{'add'}{'sync_cursors'}->@*,
            _record_operation( $cursor_record,
            qw| source source_seq source_hash path | );
    }
    if ( not $c->{'dry_run'} ) {
        fault(qw| sync:before-journal |);
        my $journal
            = journal_write( $to, $store, $c->{'add'}, $c->{'drop'}, {} );
        $c->{'journal_seq'} = $journal->{'seq'};
        witness_note_format(
            %opt,
            qw| disk |        => $to->{'disk'},
            qw| id |          => $to,
            qw| state |       => $c->{'to_state'},
            qw| journal_seq | => $journal->{'seq'}
        );
    }
    return {
        qw| changed |     => TRUE,
        qw| count |       => $c->{'count'},
        qw| messages |    => $c->{'messages'},
        qw| journal_seq | => $c->{'journal_seq'},
        qw| hold |        => $hold,
        qw| dry_run |     => $c->{'dry_run'},
    };
}

sub sync_conflict_list {
    my ( $id, $replay ) = @ARG;
    my $records = _records(
        $id,
        qw| sync_conflict |,
        qw| sync-conflicts |,
        qw| sync-conflict |
    );
    return map { $records->{$ARG} } sort keys $replay->{'sync_conflicts'}->%*;
}

sub sync_conflict_resolve {
    my %opt    = @ARG;
    my $name   = $opt{'name'} // '';
    my $lock   = disk_lock( disk_read_id(%opt) );
    my $id     = disk_require_attached(%opt);
    my $store  = store_key_signer( %opt, qw| id | => $id );
    my $state  = state_read( $id->{'path'}, $id->{'store_pub'} );
    my $replay = journal_replay($id);
    refuse( 'sync-conflicts resolve : no unresolved conflict [ %s ]', $name )
        if not $replay->{'sync_conflicts'}{$name};
    my $journal = journal_write(
        $id,
        $store,
        _empty_set(),
        { %{ _empty_set() }, qw| conflicts | => [ { qw| path | => $name } ] },
        {}
    );
    witness_note_format(
        %opt,
        qw| id |          => $id,
        qw| state |       => $state,
        qw| journal_seq | => $journal->{'seq'}
    );
    return { qw| path | => $name, qw| seq | => $journal->{'seq'} };
}

sub sync_records_verify {
    my ( $id, $replay ) = @ARG;
    my $cursors = _records(
        $id,
        qw| sync_cursor |,
        qw| sync-cursors |,
        qw| sync-cursor |
    );
    my $conflicts = _records(
        $id,
        qw| sync_conflict |,
        qw| sync-conflicts |,
        qw| sync-conflict |
    );
    foreach my $path ( keys %{$cursors} ) {
        refuse( 'format 3 : unlisted sync cursor %s', $path )
            if not $replay->{'sync_cursor_history'}{$path};
    }
    foreach my $path ( keys $replay->{'sync_cursor_history'}->%* ) {
        refuse( 'format 3 : missing sync cursor %s', $path )
            if not $cursors->{$path};
        my $expected = $replay->{'sync_cursor_history'}{$path};
        foreach my $field (qw| source source_seq source_hash |) {
            refuse( 'format 3 : sync cursor %s differs from journal', $path )
                if ( $cursors->{$path}{$field} // '' ) ne
                ( $expected->{$field} // '' );
        }
    }
    foreach my $path ( keys %{$conflicts} ) {
        refuse( 'format 3 : unlisted sync conflict %s', $path )
            if not $replay->{'sync_conflict_history'}{$path};
    }
    foreach my $path ( keys $replay->{'sync_conflict_history'}->%* ) {
        refuse( 'format 3 : missing sync conflict %s', $path )
            if not $conflicts->{$path};
    }
    return ( scalar keys %{$cursors}, scalar keys %{$conflicts} );
}

1;

#,,,.,,,.,..,,..,,..,,,,.,,,.,,,.,.,.,.,,,.,.,.,.,...,...,.,,,..,,,,.,.,,,.,.,
#JRB7K43GXQOYENDRKIWCZXW55ZUGOXLDK2GDXM2FDZVEQDG2EOJULGVJYRVTC7ROWRACEPS3IEEDM
#\\\|NES56YAI2SLWWH54MX4Z7WJ737RQRXQ7HWC3Z5HUBNSO2T26HAK \ / AMOS7 \ YOURUM ::
#\[7]TXMCRLG2EDN2VEUZPWXSBNPW47ZC6MAJ22IKN2NZOWNOUU6XNKAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
