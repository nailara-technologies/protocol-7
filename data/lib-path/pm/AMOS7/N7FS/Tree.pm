## [:< ##

package AMOS7::N7FS::Tree;    ###############################################

## named tree manifests, verified restore and journal-integrated tree drops.

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

our $VERSION = qw| AMOS7::N7FS::Tree-VERSION.2VDGPNQ |;

@EXPORT_OK = qw| tree_create tree_records_verify tree_list tree_live_addresses
    tree_drop tree_restore manifest_open manifest_entry_read |;

use Fcntl qw| O_RDONLY O_WRONLY O_CREAT O_EXCL O_NOFOLLOW |;
use JSON::PP;
use POSIX ();
use Cwd   qw| abs_path |;
use AMOS7::N7FS
    qw| ntime_now ntime14 b32 unb32 read_file write_new_file_stream
    make_dirs publish_dir remove_tree sync_dir refuse fault |;
use AMOS7::N7FS::Sum qw| bmw384_fh bmw_b32 amos_of_bmw epoch_b32
    epoch_from_b32 epoch_num |;
use AMOS7::N7FS::Store     qw| codec node_path node_verify store_nodes |;
use AMOS7::N7FS::Reference qw| reference_scan reference_drop_write |;
use AMOS7::N7FS::Disk
    qw| disk_lock disk_read_id disk_require_attached state_read
    store_key_signer witness_note_format |;
use AMOS7::N7FS::Journal qw| journal_replay journal_write |;
use AMOS7::N7FS::Record  qw| record_write record_scan |;

our $JSON    = JSON::PP->new->utf8->canonical;
our $ADDR_RE = qr{\AV7[A-Z2-7]{5}/[A-Z2-7]{7}/[A-Z2-7]{77}\z};

sub _address {
    my $address = shift // '';
    refuse( 'tree : bad content address [ %s ]', $address )
        if $address !~ $ADDR_RE;
    my ( $epoch_name, $amos, $bmw ) = split m|/|, $address;
    my $epoch = epoch_from_b32($epoch_name);
    refuse( 'tree : bad content address [ %s ]', $address )
        if not defined $epoch
        or amos_of_bmw($bmw) ne $amos;
    return { qw| epoch | => $epoch, qw| amos | => $amos, qw| bmw | => $bmw };
}

sub _tree_record {
    my ( $id, $path ) = @ARG;
    my ($record)
        = grep { $ARG->{'path'} eq $path }
        record_scan( $id, qw| tree |, qw| trees |, qw| tree | );
    refuse( 'tree record %s is missing', $path ) if not defined $record;
    refuse( 'tree record %s has no name or manifest', $path )
        if not length( $record->{'name'} // '' )
        or ( $record->{'manifest'} // '' ) !~ $ADDR_RE
        or ( $record->{'created'}  // '' ) !~ m|\A\d{14}\z|;
    return $record;
}

sub manifest_open {
    my ( $id, $state, $tree ) = @ARG;
    my $addr = _address( $tree->{'manifest'} );
    node_verify( $id->{'path'}, $addr, $state->{'store_format'}, $id );
    my $path = node_path( $id->{'path'}, $addr ) . '/content';
    sysopen( my $fh, $path, O_RDONLY | O_NOFOLLOW )
        or refuse( 'cannot open manifest %s : %s', $path, $OS_ERROR );
    binmode $fh;
    my $line = <$fh>;
    refuse( 'tree %s : empty manifest', $tree->{'name'} )
        if not defined $line;
    my $head = eval { $JSON->decode($line) };
    refuse( 'tree %s : bad manifest header', $tree->{'name'} )
        if ref $head ne qw| HASH |
        or ( $head->{'manifest'} // 0 ) != 1
        or ( $head->{'created'}  // '' ) !~ m|\A\d{14}\z|;
    return ( $fh, $head );
}

sub manifest_entry_read {
    my $fh   = shift;
    my $line = <$fh>;
    return undef if not defined $line;
    my $entry = eval { $JSON->decode($line) };
    refuse('manifest entry is not a json object') if ref $entry ne qw| HASH |;
    return $entry;
}

sub _xattrs_available {
    my $ok = eval { require 'syscall.ph'; 1 };
    return FALSE if not $ok;
    return
           defined &SYS_llistxattr
        && defined &SYS_lgetxattr
        && defined &SYS_lsetxattr ? TRUE : FALSE;
}

sub _read_xattrs {
    my $path = shift;
    return ( undef, [] ) if not _xattrs_available();
    my $size = syscall( SYS_llistxattr(), $path, undef, 0 );
    return ( undef, [ { qw| name | => '', qw| why | => "$OS_ERROR" } ] )
        if $size < 0;
    my $buf = "\0" x $size;
    my $got
        = $size ? syscall( SYS_llistxattr(), $path, $buf, length $buf ) : 0;
    return ( undef, [ { qw| name | => '', qw| why | => "$OS_ERROR" } ] )
        if $got < 0;
    my ( %attr, @errors );

    foreach my $name ( split m|\0|, substr( $buf, 0, $got ) ) {
        next if not length $name;
        my $value_size = syscall( SYS_lgetxattr(), $path, $name, undef, 0 );
        if ( $value_size < 0 ) {
            push @errors, { qw| name | => $name, qw| why | => "$OS_ERROR" };
            next;
        }
        my $value = "\0" x $value_size;
        my $read
            = $value_size
            ? syscall( SYS_lgetxattr(), $path, $name, $value, $value_size )
            : 0;
        if ( $read < 0 ) {
            push @errors, { qw| name | => $name, qw| why | => "$OS_ERROR" };
            next;
        }
        $attr{$name} = substr( $value, 0, $read );
    }
    return wantarray ? ( \%attr, \@errors ) : \%attr;
}

sub _write_xattr {
    my ( $path, $name, $value ) = @ARG;
    return FALSE if not _xattrs_available();
    return
        syscall( SYS_lsetxattr(), $path, $name, $value, length $value, 0 )
        == 0 ? TRUE : FALSE;
}

sub _source_stat {
    my ( $st, $stats ) = @ARG;
    my $seconds = int $st->[9];
    my $ns      = int( ( $st->[9] - $seconds ) * 1000000000 + 0.5 );
    if ( $ns == 1000000000 ) {
        $seconds++;
        $ns = 0;
    }
    my %entry = (
        qw| mode |     => $st->[2] & 07777,
        qw| uid |      => $st->[4],
        qw| gid |      => $st->[5],
        qw| mtime |    => $seconds,
        qw| mtime_ns | => $ns,
    );
    my $user  = getpwuid $st->[4];
    my $group = getgrgid $st->[5];
    $entry{'user_b32'}  = b32($user)  if defined $user;
    $entry{'group_b32'} = b32($group) if defined $group;
    my ( $xattrs, $xattr_errors ) = _read_xattrs( $st->[13] );
    if ( defined $xattrs ) {
        $entry{'xattrs'} = {
            map { b32($ARG) => b32( $xattrs->{$ARG} ) }
            sort keys %{$xattrs}
        };
    }
    if ( @{$xattr_errors} ) {
        $entry{'xattr_errors'} = [
            map {
                {
                    qw| name_b32 | => b32( $ARG->{'name'} ),
                        qw| why |  => $ARG->{'why'}
                }
            } @{$xattr_errors}
        ];
        $stats->{'xattr_errors'} += scalar @{$xattr_errors};
    }
    return \%entry;
}

sub _manifest_skipped {
    my ( $fh, $relative, $why, $skipped, $stats ) = @ARG;
    print {$fh} $JSON->encode(
        {   qw| p |   => b32($relative),
            qw| t |   => qw| skipped |,
            qw| why | => $why
        }
        ),
        "\n"
        or refuse('cannot write tree manifest');
    push @{$skipped}, $relative;
    $stats->{'paths'}{$relative} = TRUE;
    $stats->{'errors'}++;
    return;
}

sub _walk_manifest {
    my ( $root, $relative, $sources, $seen, $fh, $skipped, $stats ) = @ARG;
    my $source = length $relative ? "$root/$relative" : $root;
    my @st     = Time::HiRes::lstat($source);
    if ( not @st ) {
        _manifest_skipped( $fh, $relative, "vanished : $OS_ERROR",
            $skipped, $stats );
        return;
    }
    if ( -f _ ) {
        my $stored = $sources->{$source};
        if ( not defined $stored ) {
            _manifest_skipped( $fh, $relative,
                'not imported [ appeared, unreadable or vanished ]',
                $skipped, $stats );
            return;
        }
        if ( $st[7] != $stored->{'_source_size'}
            or int( $st[9] ) != $stored->{'_source_mtime'} ) {
            _manifest_skipped( $fh, $relative,
                'changed between import and manifest walk',
                $skipped, $stats );
            return;
        }
    }
    $st[13] = $source;
    $stats->{'paths'}{$relative} = TRUE;
    my %entry = (
        qw| p | => b32($relative),
        _source_stat( \@st, $stats )->%*,
    );
    if ( -l _ ) {
        my $target = readlink($source);
        if ( not defined $target ) {
            _manifest_skipped( $fh, $relative, "symlink vanished : $OS_ERROR",
                $skipped, $stats );
            return;
        }
        $entry{'t'} = qw| symlink |;
        $entry{'l'} = b32($target);
    } elsif ( -d _ ) {
        my $dh;
        if ( not opendir( $dh, $source ) ) {
            _manifest_skipped( $fh, $relative,
                "unreadable directory : $OS_ERROR",
                $skipped, $stats );
            return;
        }
        $entry{'t'} = qw| dir |;
        print {$fh} $JSON->encode( \%entry ), "\n"
            or refuse('cannot write tree manifest');
        my @names = sort grep { $ARG ne '.' and $ARG ne '..' } readdir $dh;
        closedir $dh;
        _walk_manifest( $root, length $relative ? "$relative/$ARG" : $ARG,
            $sources, $seen, $fh, $skipped, $stats )
            for @names;
        return;
    } elsif ( -f _ ) {
        my $inode = join ':', @st[ 0, 1 ];
        if ( exists $seen->{$inode} ) {
            $entry{'t'} = qw| hardlink |;
            $entry{'h'} = b32( $seen->{$inode} );
        } else {
            $entry{'t'}     = qw| file |;
            $entry{'a'}     = $sources->{$source}{'addr'};
            $seen->{$inode} = $relative;
        }
    } else {
        $entry{'t'}   = qw| skipped |;
        $entry{'why'} = 'special file';
        push @{$skipped}, $relative;
    }
    print {$fh} $JSON->encode( \%entry ), "\n"
        or refuse('cannot write tree manifest');
    return;
}

sub tree_create {
    my ( $id, $store, $state, $replay, $root, $name, $report ) = @ARG;
    refuse('tree : only store format 3 has trees')
        if $state->{'store_format'} != 3;
    refuse( 'tree : bad tree name [ %s ]', $name // '' )
        if not defined $name or $name !~ m|\A[^\x00/]+\z|;
    refuse( 'tree : duplicate live tree [ %s ]', $name )
        if $replay->{'trees'}{$name};
    my @root_st = lstat $root;
    refuse( 'tree root %s is not a directory', $root )
        if not @root_st
        or -l _
        or not -d _;
    my %sources = map { $ARG->{'source'} => $ARG }
        grep { defined $ARG->{'addr'} and $ARG->{'verified'} }
        $report->{'entries'}->@*;
    my $tmp_dir = "$id->{'path'}/.n7fs/tmp";
    make_dirs( $tmp_dir, 0700 );
    my $tmp = sprintf qw| %s/manifest.%s |, $tmp_dir,
        b32( AMOS7::N7FS::random_bytes(5) );
    my @skipped;
    my $stats  = { qw| errors | => 0, qw| xattr_errors | => 0 };
    my $now    = ntime_now();
    my $newest = 0;

    foreach my $tree ( values $replay->{'trees'}->%* ) {
        my $time = $tree->{'created'} // 0;
        $newest = $time if $time =~ m|\A\d+\z| and $time > $newest;
    }
    ## a clock setback must never make a new snapshot older than its ancestors
    $now = $newest + 1 if $now <= $newest;
    my $created = ntime14($now);
    fault(qw| tree:before-walk |);
    write_new_file_stream(
        $tmp,
        sub {
            my $fh = shift;
            print {$fh} $JSON->encode(
                {   qw| manifest | => 1,
                    qw| root_b32 | => b32( abs_path($root) // $root ),
                    qw| created |  => $created,
                }
                ),
                "\n"
                or die "manifest write : $OS_ERROR\n";
            _walk_manifest( $root, '', \%sources, {}, $fh, \@skipped,
                $stats );
            foreach my $source ( $report->{'entries'}->@* ) {
                my $path = $source->{'source'} // '';
                next if $path eq $root or index( $path, "$root/" ) != 0;
                my $relative = substr( $path, length($root) + 1 );
                next if $stats->{'paths'}{$relative};
                _manifest_skipped( $fh, $relative,
                    'vanished before manifest walk',
                    \@skipped, $stats );
            }
        }
    );
    open( my $manifest_fh, '<:raw', $tmp )
        or refuse( 'cannot read manifest %s : %s', $tmp, $OS_ERROR );
    my ($digest) = bmw384_fh($manifest_fh);
    close $manifest_fh;
    my $bmw  = bmw_b32($digest);
    my $addr = {
        qw| epoch | => $state->{'epochs'}[-1],
        qw| amos |  => amos_of_bmw($bmw),
        qw| bmw |   => $bmw,
    };
    my $address = join '/', epoch_b32( $addr->{'epoch'} ), $addr->{'amos'},
        $bmw;
    my $final = node_path( $id->{'path'}, $addr );
    my ( $new_node, $meta_name );

    if ( -e $final ) {
        refuse( 'tree manifest node %s is not journaled', $address )
            if not $replay->{'nodes'}{$address};
        codec(3)->{'verify_node'}->( $final, $addr, { id => $id } );
    } else {
        my $meta = {
            qw| name |         => "tree:$name.jsonl",
            qw| format |       => qw| jsonl |,
            qw| size |         => -s $tmp,
            qw| mtime |        => ( stat $tmp )[9],
            qw| import_ntime | => $created,
            qw| epoch_num |    => epoch_num( ntime_now() ),
            qw| epoch |        => epoch_b32( $addr->{'epoch'} ),
            qw| source |       => "tree:$name",
            qw| host |         => qw| tree |,
            qw| amos |         => $addr->{'amos'},
            qw| bmw |          => $bmw,
            qw| disk |         => $id->{'disk'},
        };
        make_dirs( $final =~ s|/[^/]+\z||r, 0700 );
        my $node_tmp = "$final.tmp." . b32( AMOS7::N7FS::random_bytes(5) );
        make_dirs( $node_tmp, 0700 );
        codec(3)->{'write_node'}->(
            $node_tmp,
            {   qw| addr |         => $addr,
                qw| content_path | => $tmp,
                qw| metas |        => [$meta],
            },
            { qw| id | => $id, qw| store | => $store }
        );
        fault(qw| tree:before-publish |);
        publish_dir( $node_tmp, $final );
        $new_node = TRUE;
        opendir( my $meta_dir, "$final/meta" )
            or
            refuse( 'cannot read manifest meta %s : %s', $final, $OS_ERROR );
        ($meta_name) = grep { $ARG =~ m|\.meta\z| } readdir $meta_dir;
        closedir $meta_dir;
        codec(3)->{'verify_node'}
            ->( $final, $addr, { qw| id | => $id, qw| store | => $store } );
    }
    unlink $tmp or refuse( 'cannot remove %s : %s', $tmp, $OS_ERROR );
    my $record = record_write(
        $id, $store,
        qw| tree |,
        qw| trees |,
        qw| tree |,
        {   qw| disk |       => $id->{'disk'},
            qw| name |       => $name,
            qw| manifest |   => $address,
            qw| created |    => $created,
            qw| references | => [
                map {
                    {
                        qw| node |     => $ARG->{'addr'},
                            qw| path | => $ARG->{'_reference'}{'path'},
                    }
                }
                grep { defined $ARG->{'_reference'} }
                    $report->{'entries'}->@*
            ],
        }
    );
    fault(qw| tree:after-record |);
    return {
        qw| record |         => $record,
        qw| address |        => $address,
        qw| new_node |       => $new_node ? TRUE : FALSE,
        qw| meta_name |      => $meta_name,
        qw| skipped |        => \@skipped,
        qw| skipped_errors | => $stats->{'errors'},
        qw| xattr_errors |   => $stats->{'xattr_errors'},
    };
}

sub tree_list {
    my ( $id, $state, $replay ) = @ARG;
    my @out;
    foreach my $name ( sort keys $replay->{'trees'}->%* ) {
        my $tree = _tree_record( $id, $replay->{'trees'}{$name}{'path'} );
        refuse( 'tree record %s does not match the journal', $name )
            if $tree->{'name'} ne $name
            or $tree->{'manifest'} ne $replay->{'trees'}{$name}{'manifest'};
        push @out, $tree;
    }
    return @out;
}

sub _path {
    my $entry = shift;
    refuse('manifest entry has no path') if not defined $entry->{'p'};
    my $path = $entry->{'p'} eq '' ? '' : unb32( $entry->{'p'} );
    refuse('manifest path is not base32') if not defined $path;
    return $path                          if not length $path;
    refuse('manifest path is absolute')   if $path =~ m|\A/|;
    refuse('manifest path contains nul')  if index( $path, "\0" ) >= 0;
    my @parts = split m|/|, $path, -1;
    refuse('manifest path has an unsafe component')
        if grep { not length $ARG or $ARG eq '.' or $ARG eq '..' } @parts;
    return $path;
}

sub _each_manifest {
    my ( $id, $state, $tree, $code ) = @ARG;
    my $fh;
    if ( defined $id->{'_manifest_path'} ) {
        open( $fh, '<:raw', $id->{'_manifest_path'} )
            or refuse( 'cannot open supplied tree manifest : %s', $OS_ERROR );
        my $head    = <$fh>;
        my $decoded = eval { $JSON->decode($head) };
        refuse('supplied manifest has a bad header')
            if ref $decoded ne qw| HASH |
            or ( $decoded->{'manifest'} // 0 ) != 1;
    } else {
        ($fh) = manifest_open( $id, $state, $tree );
    }
    while ( my $entry = manifest_entry_read($fh) ) {
        _path($entry);
        $code->($entry);
    }
    close $fh or refuse( 'cannot close tree %s manifest', $tree->{'name'} );
    return;
}

sub tree_live_addresses {
    my ( $id, $state, $replay ) = @ARG;
    my %held;
    foreach my $tree ( tree_list( $id, $state, $replay ) ) {
        $held{ $tree->{'manifest'} }{ $tree->{'name'} } = TRUE;
        _each_manifest(
            $id, $state, $tree,
            sub {
                my $entry = shift;
                if ( defined $entry->{'a'} ) {
                    refuse( 'tree %s : bad file address', $tree->{'name'} )
                        if $entry->{'a'} !~ $ADDR_RE;
                    $held{ $entry->{'a'} }{ $tree->{'name'} } = TRUE;
                }
            }
        );
    }
    return \%held;
}

sub tree_records_verify {
    my ( $id, $state, $replay ) = @ARG;
    my @trees = record_scan( $id, qw| tree |, qw| trees |, qw| tree | );
    my @drops = record_scan( $id, qw| tree_drop |, qw| tree-drops |,
        qw| tree-drop | );
    my %tree = map { $ARG->{'path'} => $ARG } @trees;
    my %drop = map { $ARG->{'path'} => $ARG } @drops;
    foreach my $path ( sort keys $replay->{'tree_history'}->%* ) {
        my $expected = $replay->{'tree_history'}{$path};
        refuse( 'format 3 : missing tree record %s', $path )
            if not $tree{$path};
        foreach my $field (qw| name manifest created |) {
            refuse( 'format 3 : tree record %s differs from journal', $path )
                if ( $tree{$path}{$field} // '' ) ne
                ( $expected->{$field} // '' );
        }
        refuse( 'format 3 : tree record %s origin differs from journal',
            $path )
            if ( $tree{$path}{'origin'}{'id'} // $path ) ne
            ( $expected->{'origin'}{'id'}       // $path )
            or ( $tree{$path}{'origin'}{'disk'} // $id->{'disk'} ) ne
            ( $expected->{'origin'}{'disk'}     // $id->{'disk'} );
    }
    foreach my $path ( sort keys %tree ) {
        refuse( 'format 3 : unlisted tree record %s', $path )
            if not $replay->{'tree_history'}{$path};
    }
    foreach my $path ( sort keys $replay->{'tree_drops'}->%* ) {
        my $expected = $replay->{'tree_drops'}{$path};
        refuse( 'format 3 : missing tree drop %s', $path )
            if not $drop{$path};
        foreach my $field (qw| name tree |) {
            refuse( 'format 3 : tree drop %s differs from journal', $path )
                if ( $drop{$path}{$field} // '' ) ne
                ( $expected->{$field} // '' );
        }
        refuse( 'format 3 : tree drop %s origin differs from journal', $path )
            if ( $drop{$path}{'origin'}{'id'} // $path ) ne
            ( $expected->{'origin'}{'id'}       // $path )
            or ( $drop{$path}{'origin'}{'disk'} // $id->{'disk'} ) ne
            ( $expected->{'origin'}{'disk'}     // $id->{'disk'} );
    }
    foreach my $path ( sort keys %drop ) {
        refuse( 'format 3 : unlisted tree drop %s', $path )
            if not $replay->{'tree_drops'}{$path};
    }
    my $held = tree_live_addresses( $id, $state, $replay );
    foreach my $address ( sort keys %{$held} ) {
        refuse( 'format 3 : tree references missing or released node %s',
            $address )
            if not $replay->{'nodes'}{$address};
    }
    return scalar @trees;
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
    };
}

sub tree_drop {
    my %opt   = @ARG;
    my $name  = $opt{'name'} // '';
    my $lock  = disk_lock( disk_read_id(%opt) );
    my $id    = disk_require_attached(%opt);
    my $store = store_key_signer( %opt, qw| id | => $id );
    my $state = state_read( $id->{'path'}, $id->{'store_pub'} );
    refuse('tree-drop is only available for store format 3')
        if $state->{'store_format'} != 3;
    my $replay = journal_replay($id);
    my $tree   = $replay->{'trees'}{$name};
    refuse( 'tree-drop : no live tree [ %s ]', $name ) if not defined $tree;
    _tree_record( $id, $tree->{'path'} );
    my %wanted = map { join( "\0", @{$ARG}{qw| node path |} ) => $ARG }
        @{ $opt{'references'} // [] };
    my @reference_drops;

    if (%wanted) {
        foreach
            my $node ( store_nodes( $id->{'path'}, $state->{'epochs'}->@* ) )
        {
            foreach my $ref ( reference_scan( $node, $id ) ) {
                my $key = join "\0", $ref->{'node'}, $ref->{'path'};
                next if not exists $wanted{$key};
                refuse( 'reference %s is not live', $ref->{'path'} )
                    if $ref->{'dropped'};
                reference_drop_write( $ref, $id, $store );
                push @reference_drops,
                    { map { $ARG => $ref->{$ARG} }
                        qw| node path holder name | };
                delete $wanted{$key};
            }
        }
        refuse('tree-drop : an import reference is missing')
            if keys %wanted;
    }
    my $drop = record_write(
        $id, $store,
        qw| tree_drop |,
        qw| tree-drops |,
        qw| tree-drop |,
        {   qw| disk | => $id->{'disk'},
            qw| name | => $name,
            qw| tree | => $tree->{'path'},
        }
    );
    fault(qw| tree-drop:after-record |);
    my $journal = journal_write(
        $id, $store,
        _empty_set(),
        {   %{ _empty_set() },
            qw| references | => \@reference_drops,
            qw| trees |      => [
                {   qw| name | => $name,
                    qw| path | => $drop->{'path'},
                    qw| tree | => $tree->{'path'}
                }
            ]
        },
        {}
    );
    witness_note_format(
        %opt,
        qw| id |          => $id,
        qw| state |       => $state,
        qw| journal_seq | => $journal->{'seq'}
    );
    return { qw| tree | => $tree, qw| seq | => $journal->{'seq'} };
}

sub _restore_owner {
    my ( $path, $entry, $owners, $omitted ) = @ARG;
    if ( not $owners or $EFFECTIVE_USER_ID != 0 ) {
        $omitted->{'owners'}++;
        return;
    }
    my ( $uid, $gid ) = @{$entry}{qw| uid gid |};
    if ( defined $entry->{'user_b32'} ) {
        my $name     = unb32( $entry->{'user_b32'} );
        my $resolved = defined $name ? getpwnam($name) : undef;
        if ( defined $resolved ) { $uid = $resolved }
        else                     { $omitted->{'numeric_fallbacks'}++ }
    }
    if ( defined $entry->{'group_b32'} ) {
        my $name     = unb32( $entry->{'group_b32'} );
        my $resolved = defined $name ? getgrnam($name) : undef;
        if ( defined $resolved ) { $gid = $resolved }
        else                     { $omitted->{'numeric_fallbacks'}++ }
    }
    my $changed
        = -l $path
        ? POSIX::lchown( $uid, $gid, $path )
        : chown $uid, $gid, $path;
    refuse( 'cannot chown %s : %s', $path, $OS_ERROR ) if not $changed;
    return;
}

sub _restore_metadata {
    my ( $path, $entry, $owners, $omitted ) = @ARG;
    _restore_owner( $path, $entry, $owners, $omitted );
    if ( not -l $path ) {
        my $mode = $entry->{'mode'} & 07777;
        if ( not $owners or $EFFECTIVE_USER_ID != 0 ) {
            $omitted->{'privileged_modes'}++ if $mode & 06000;
            $mode &= 01777;
        }
        chmod $mode, $path
            or refuse( 'cannot chmod %s : %s', $path, $OS_ERROR );
    }
    if ( defined $entry->{'xattrs'} ) {
        foreach my $encoded ( sort keys $entry->{'xattrs'}->%* ) {
            my $name  = unb32($encoded);
            my $value = unb32( $entry->{'xattrs'}{$encoded} );
            if (   not defined $name
                or not defined $value
                or not _write_xattr( $path, $name, $value ) ) {
                $omitted->{'xattrs'}++;
            }
        }
    }
    return;
}

sub _restore_time {
    my ( $path, $entry, $omitted, $nofollow ) = @ARG;
    my $available = eval { require 'syscall.ph'; defined &SYS_utimensat };
    if ( not $available ) {
        $omitted->{'times'}++;
        return;
    }
    my $seconds = $entry->{'mtime'};
    my $ns      = $entry->{'mtime_ns'} // 0;
    my $omit    = 1073741822;    ## UTIME_OMIT keeps the current atime ##
    my $times   = pack( 'l!l!l!l!', $omit, 0, $seconds, $ns );
    my $flags   = $nofollow ? 0x100 : 0;    ## AT_SYMLINK_NOFOLLOW ##
    if ( syscall( SYS_utimensat(), -100, $path, $times, $flags ) != 0 ) {
        $omitted->{'times'}++;
    }
    return;
}

sub _check_symlink_prefix {
    my ( $path, $symlinks ) = @ARG;
    my $prefix = $path;
    while ( $prefix =~ s|/[^/]+\z|| ) {
        refuse( 'manifest path has a symlink parent [ %s ]', $path )
            if $symlinks->{$prefix};
    }
    return;
}

sub _assert_real_parents {
    my ( $tmp, $relative ) = @ARG;
    my $prefix = $relative;
    while ( $prefix =~ s|/[^/]+\z|| ) {
        my @st = lstat "$tmp/$prefix";
        refuse( 'restore parent is not a real directory [ %s ]', $prefix )
            if not @st
            or -l _
            or not -d _;
    }
    return;
}

sub _manifest_preflight {
    my ( $id, $state, $tree ) = @ARG;
    my ( %paths, %symlinks );
    _each_manifest(
        $id, $state, $tree,
        sub {
            my $entry = shift;
            my $path  = _path($entry);
            refuse('manifest has a duplicate path') if $paths{$path}++;
            $symlinks{$path} = TRUE
                if ( $entry->{'t'} // '' ) eq qw| symlink |;
        }
    );
    return \%symlinks;
}

sub tree_restore {
    my %opt    = @ARG;
    my $name   = $opt{'name'}   // '';
    my $target = $opt{'target'} // '';
    refuse('restore needs a target') if not length $target;
    $target =~ s|/+\z||              if length $target > 1;
    my ( $id, $lock, $state, $tree );
    if ( defined $opt{'tree_record'} ) {
        $id = { qw| _manifest_path | => $opt{'manifest_path'}
                // refuse('supplied tree needs a manifest path') };
        $state = {};
        $tree  = $opt{'tree_record'};
    } else {
        $id    = disk_read_id(%opt);
        $lock  = disk_lock( $id, qw| shared | );
        $state = state_read( $id->{'path'}, $id->{'store_pub'} );
        refuse('restore is only available for store format 3')
            if $state->{'store_format'} != 3;
        my $replay = journal_replay($id);
        ($tree)
            = grep { $ARG->{'name'} eq $name }
            tree_list( $id, $state, $replay );
    }
    refuse( 'restore : no live tree [ %s ]', $name ) if not defined $tree;
    my $manifest_symlinks = _manifest_preflight( $id, $state, $tree );

    if ( -e $target or -l $target ) {
        refuse( 'restore : target %s is not a directory', $target )
            if -l $target or not -d $target;
        opendir( my $dh, $target )
            or refuse( 'cannot read %s : %s', $target, $OS_ERROR );
        my @left = grep { $ARG ne '.' and $ARG ne '..' } readdir $dh;
        closedir $dh;
        refuse( 'restore : target %s is not empty', $target ) if @left;
    }
    my $parent = $target =~ s|/[^/]+\z||r;
    $parent = '.' if $parent eq $target;
    $parent = '/' if not length $parent;
    refuse( 'restore : target parent %s is not a directory', $parent )
        if not -d $parent;
    my $tmp = sprintf qw| %s.tmp.%s |, $target,
        b32( AMOS7::N7FS::random_bytes(5) );
    my $owners  = $opt{'owners'} ? TRUE : FALSE;
    my %omitted = (
        qw| owners |            => 0,
        qw| privileged_modes |  => 0,
        qw| xattrs |            => 0,
        qw| times |             => 0,
        qw| numeric_fallbacks | => 0
    );
    my ( $files, $dirs, $links ) = ( 0, 0, 0 );
    my @directories;
    my @symlinks;
    my $root_entry;
    my $publish = FALSE;
    my $ok      = eval {
        make_dirs( $tmp, 0700 ) if not $opt{'dry_run'};
        if ( not $opt{'dry_run'} ) {
            write_new_file_stream( "$tmp/.n7fs-incomplete",
                sub { print { $_[0] } "tree $name incomplete\n" } );
        }
        _each_manifest(
            $id, $state, $tree,
            sub {
                my $entry    = shift;
                my $relative = _path($entry);
                _check_symlink_prefix( $relative, $manifest_symlinks );
                my $type = $entry->{'t'} // '';
                refuse('manifest entry has a bad type')
                    if $type !~ m{\A(?:file|dir|symlink|hardlink|skipped)\z};
                if ( $type eq qw| file | ) {
                    refuse('manifest file has no address')
                        if not $entry->{'a'};
                    my $addr = _address( $entry->{'a'} );
                    node_verify( $id->{'path'}, $addr, 3, $id )
                        if not ref $opt{'content_source'};
                    $files++;
                    return if $opt{'dry_run'};
                    my $dest = "$tmp/$relative";
                    make_dirs( $dest =~ s|/[^/]+\z||r, 0700 );
                    if ( ref $opt{'content_source'} ) {
                        $opt{'content_source'}->( $entry->{'a'}, $dest );
                    } else {
                        my $source
                            = node_path( $id->{'path'}, $addr ) . '/content';
                        sysopen( my $in, $source, O_RDONLY | O_NOFOLLOW )
                            or refuse( 'cannot open %s : %s',
                            $source, $OS_ERROR );
                        binmode $in;
                        sysopen( my $out, $dest,
                            O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW, 0600 )
                            or refuse( 'cannot create %s : %s',
                            $dest, $OS_ERROR );
                        binmode $out;
                        while (1) {
                            my $got = sysread( $in, my $buf, 1048576 );
                            refuse( 'read %s : %s', $source, $OS_ERROR )
                                if not defined $got;
                            last if $got == 0;
                            print {$out} $buf
                                or refuse( 'write %s failed', $dest );
                        }
                        close $in;
                        $out->sync;
                        close $out or refuse( 'close %s failed', $dest );
                    }
                    _restore_metadata( $dest, $entry, $owners, \%omitted );
                    _restore_time( $dest, $entry, \%omitted, FALSE );
                } elsif ( $type eq qw| dir | ) {
                    $dirs++;
                    push @directories, [ $relative, $entry ];
                    $root_entry = $entry if not length $relative;
                    make_dirs( "$tmp/$relative", 0700 )
                        if not $opt{'dry_run'};
                } elsif ( $type eq qw| symlink | ) {
                    refuse('manifest symlink has no target')
                        if not defined $entry->{'l'};
                    push @symlinks, [ $relative, $entry ];
                    $links++;
                } elsif ( $type eq qw| hardlink | ) {
                    my $earlier = _path( { qw| p | => $entry->{'h'} // '' } );
                    _check_symlink_prefix( $earlier, $manifest_symlinks );
                    $files++;
                    if ( not $opt{'dry_run'} ) {
                        link "$tmp/$earlier",
                            "$tmp/$relative"
                            or refuse( 'cannot hardlink %s : %s',
                            $relative, $OS_ERROR );
                        _restore_metadata( "$tmp/$relative", $entry,
                            $owners, \%omitted );
                        _restore_time( "$tmp/$relative", $entry, \%omitted,
                            FALSE );
                    }
                }
            }
        );
        if ( not $opt{'dry_run'} ) {
            foreach my $item (@symlinks) {
                my ( $relative, $entry ) = @{$item};
                my $link = unb32( $entry->{'l'} );
                refuse('manifest symlink target is not base32')
                    if not defined $link
                    or index( $link, "\0" ) >= 0;
                fault( qw| restore:before-symlink |, $relative );
                _assert_real_parents( $tmp, $relative );
                symlink $link, "$tmp/$relative"
                    or
                    refuse( 'cannot symlink %s : %s', $relative, $OS_ERROR );
                _restore_metadata( "$tmp/$relative", $entry,
                    $owners, \%omitted );
                _restore_time( "$tmp/$relative", $entry, \%omitted, TRUE );
            }
            foreach my $item ( reverse @directories ) {
                my ( $relative, $entry ) = @{$item};
                next if not length $relative;
                my $path = "$tmp/$relative";
                _restore_metadata( $path, $entry, $owners, \%omitted );
            }
            foreach my $item ( reverse @directories ) {
                my ( $relative, $entry ) = @{$item};
                next if not length $relative;
                _restore_time( "$tmp/$relative", $entry, \%omitted, FALSE );
            }
            unlink "$tmp/.n7fs-incomplete"
                or refuse('cannot remove the incomplete marker');
            if ( defined $root_entry ) {
                _restore_metadata( $tmp, $root_entry, $owners, \%omitted );
                _restore_time( $tmp, $root_entry, \%omitted, FALSE );
            }
            fault(qw| restore:before-publish |);
            if ( -d $target ) {
                rmdir $target
                    or refuse( 'cannot replace empty target %s', $target );
            }
            publish_dir( $tmp, $target );
            $publish = TRUE;
        }
        1;
    };
    if ( not $ok ) {
        my $err = $EVAL_ERROR;
        remove_tree($tmp) if not $publish and ( -e $tmp or -l $tmp );
        die $err;
    }
    return {
        qw| name |        => $name,
        qw| target |      => $target,
        qw| files |       => $files,
        qw| directories | => $dirs,
        qw| symlinks |    => $links,
        qw| omitted |     => \%omitted,
        qw| dry_run |     => $opt{'dry_run'} ? TRUE : FALSE,
    };
}

1;

#,,,,,,..,.,,,,,,,,..,.,,,,..,,..,,,,,,.,,,.,,..,,...,...,.,.,,,.,,..,,.,,,,,,
#DTIRXE6S36JFFM5TWXRHB7DOANONLAZPHG2TOYSMNUXIYWB5LXT3MRDQ22NJHQDXLSQROKF4T2VTG
#\\\|2MZNVVG2ASHLONCTCA7R522S37MLGU52VPU2W3QCAF5WNMKC6PO \ / AMOS7 \ YOURUM ::
#\[7]FKVDZSJY6534CHT6EBMSQ3L6TH5GDUCBJY5YDUB2JWHVPCYPFUAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
