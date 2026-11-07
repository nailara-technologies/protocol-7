## [:< ##

package AMOS7::N7FS::Disk;    ###############################################

## N7FS : disk identity, attach \ detach, use window, signed state.
##
##   <root>/<disk>/.n7fs/id.record      signed by the PARENT [ spec 3 ]
##                       id.amos        amos over id.record = <disk>
##                       id.l13         tagged l13 stand-in [ Sum.pm ]
##                       mounts/<ntime14>.<mount>   signed by the HOST
##                       state/<ntime14>.state      store format + epochs
##   <host dir>/stores/<disk>.store.key  the delegated store key [ 0600 ]
##             mounts/<disk>/<ntime14>.<mount>  the host's copy
##             witness/<disk>/<ntime14>.use     signed first \ last use
##             trusted-parents          base32 parent public keys, one per
##                                      line [ absent = trust on first use ]
##
## two injectable signers [ AMOS7::N7FS::Sign ] : 'parent' signs the id at
## init [ host-root later ], 'host' signs mount and use records.
##
## every check runs before the first write -- a refusal changes nothing.

use v5.32.0;
use utf8;
use strict;
use English;
use warnings;

##[ global constants ]##
use constant TRUE  => 5;    ##  TRUE.  ##
use constant FALSE => 0;    ##  false  ##

use Exporter;
use base qw| Exporter |;
use vars qw| @EXPORT_OK $VERSION |;

our $VERSION = qw| AMOS7::N7FS::Disk-VERSION.SZVYXNA |;

@EXPORT_OK = qw|
    disk_init
    disk_read_id
    disk_attach
    disk_detach
    disk_status
    disk_require_attached
    mount_history
    witness_read
    witness_note_format
    witness_check_format
    host_mounts
    state_read
    state_write
    store_key_signer
    trusted_parents
    |;

use Sys::Hostname qw| hostname |;
use AMOS7::N7FS   qw| root_dir host_dir ntime_now ntime14 b32 unb32
    random_bytes signed_record_pack signed_record_parse plain_record_pack
    plain_record_parse write_new_file read_file make_dirs publish_dir
    remove_tree refuse fault |;
use AMOS7::N7FS::Sum qw| amos_of_bytes l13_standin $AMOS_RULE $BMW_RULE
    $L13_TAG |;
use AMOS7::N7FS::Sign qw| verify key_file_write key_file_signer new_seed
    seed_signer |;

our $DISK_RE  = qr{\A[A-Z2-7]{7}\z};
our $MOUNT_RE = qr{\A(\d{14})\.([A-Z2-7]{7})\z};
our $STATE_RE = qr{\A(\d{14})\.state\z};
our $USE_RE   = qr{\A(\d{14})\.use\z};
our $NAME_RE  = qr{\A[\x20-\x7e]{1,255}\z};
our $TMP_RE   = qr{\.tmp\.[A-Z2-7]{8}\z};

our $INIT_TRIES = 1000;

##[ HELPERS ]#################################################################

sub _disk_path {
    my ( $root, $disk ) = @ARG;
    refuse( 'not a disk id [ %s ]', $disk // '' )
        if ( $disk // '' ) !~ $DISK_RE;
    return "$root/$disk";
}

sub _list {
    my ( $dir, $re ) = @ARG;
    return () if not -d $dir;
    opendir( my $dh, $dir )
        or refuse( 'cannot read %s : %s', $dir, $OS_ERROR );
    my @names = grep { $ARG ne '.' and $ARG ne '..' } readdir $dh;
    closedir $dh;
    my @bad = grep { $ARG !~ $re and $ARG !~ $TMP_RE } @names;
    refuse( 'unexpected entry in %s : %s', $dir, $bad[0] ) if @bad;
    return sort grep { $ARG =~ $re } @names;
}

sub _signer {
    my ( $opt, $which ) = @ARG;
    my $signer = $opt->{$which};
    refuse( 'no %s signer', $which ) if not ref $signer;
    return $signer;
}

## anchors : the option [ list of 32 byte keys ], else the host's
## trusted-parents file ; an empty list = trust on first use
sub trusted_parents {
    my %opt = @ARG;
    return $opt{'anchors'}->@* if ref $opt{'anchors'} eq qw| ARRAY |;
    my $file = host_dir(%opt) . '/trusted-parents';
    return () if not -e $file;
    my @keys;
    foreach my $line ( split m|\r?\n|, read_file($file) // '' ) {
        $line =~ s|#.*||;
        $line =~ s|\s+||g;
        next if not length $line;
        my $pub = unb32($line);
        refuse('trusted-parents : bad key line')
            if not defined $pub
            or length $pub != 32;
        push @keys, $pub;
    }
    return @keys;
}

##[ STATE RECORDS ]###########################################################

## the newest valid state record of a store. refuses a damaged newest one
## [ the state decides what is read -- no silent fallback ]. format 2 verifies
## against the store public key of the parent-signed id, never signer_pub
## alone
sub state_read {
    my ( $disk_path, $store_pub ) = @ARG;
    my @names = _list( "$disk_path/.n7fs/state", $STATE_RE );
    refuse( 'no state record in %s', $disk_path ) if not @names;

    my $signed_present = grep {
        my $bytes = read_file("$disk_path/.n7fs/state/$ARG");
        defined $bytes and substr( $bytes, 0, 5 ) eq "P7FT\x02";
    } @names;

    my $name  = $names[-1];
    my $bytes = read_file("$disk_path/.n7fs/state/$name");
    my $record_format
        = defined $bytes && length $bytes >= 5
        ? unpack( qw| C |, substr( $bytes, 4, 1 ) )
        : 0;
    my $rec;
    if ( $record_format == 2 ) {
        if ( not defined $store_pub ) {
            my ( $root, $disk ) = $disk_path =~ m|\A(.+)/([^/]+)\z|;
            refuse( 'cannot derive disk identity from %s', $disk_path )
                if not defined $disk;
            $store_pub = disk_read_id(
                qw| root |    => $root,
                qw| disk |    => $disk,
                qw| anchors | => []
            )->{'store_pub'};
        }
        refuse( 'state %s : no store public key for verification', $name )
            if not defined $store_pub
            or length $store_pub != 32;
        $rec = signed_record_parse( qw| state |, $bytes );
        refuse( 'state %s : signed by a foreign store key', $name )
            if $rec->{'signer_pub'} ne $store_pub;
        refuse( 'state %s : store signature does not verify', $name )
            if not verify( $store_pub, $rec->{'signed'}, $rec->{'sig'} );
    } else {
        refuse(
            'state %s : unsigned state after a '
                . 'signed state [ store format rollback ]',
            $name
        ) if $signed_present;
        $rec = plain_record_parse( qw| state |, $bytes );
    }

    my $p = $rec->{'payload'};
    refuse( 'state %s : no store format', $name )
        if ( $p->{'store_format'} // '' ) !~ m|\A\d{1,3}\z|;
    refuse( 'state %s : record format does not match store format', $name )
        if $p->{'store_format'} <= 2
        and $rec->{'format'} != $p->{'store_format'};
    refuse( 'state %s : no epoch list', $name )
        if ref $p->{'epochs'} ne qw| ARRAY |;
    $p->{'_name'} = $name;
    return $p;
}

sub state_write {
    my ( $disk_path, $payload, $store ) = @ARG;
    my %p = %{$payload};
    delete $p{'_name'};
    my $format = $p{'store_format'} // 1;
    refuse('state format 2 needs the delegated store key')
        if $format == 2 and not ref $store;
    my @names = _list( "$disk_path/.n7fs/state", $STATE_RE );
    my $ntime = ntime_now();
    if (@names) {
        my ($last) = $names[-1] =~ $STATE_RE;
        $ntime = $last + 1 if $ntime <= $last;
    }
    $p{'written'} = ntime14($ntime);
    my $path = "$disk_path/.n7fs/state/" . ntime14($ntime) . '.state';
    my $bytes
        = $format == 2
        ? signed_record_pack( qw| state |, \%p, $store, 2 )
        : plain_record_pack( qw| state |, \%p );
    write_new_file( $path, $bytes );
    return $path;
}

## the delegated secret stays host-side. a second host gets no key through the
## store ; an operator must provision it separately before writes there
sub store_key_signer {
    my %opt  = @ARG;
    my $id   = $opt{'id'} // disk_read_id(%opt);
    my $path = host_dir(%opt) . '/stores/' . $id->{'disk'} . '.store.key';
    refuse( 'no delegated store key %s [ writes need it ]', $path )
        if not -e $path;
    my $store = key_file_signer($path);
    refuse( 'delegated store key %s does not match the disk id', $path )
        if $store->public ne $id->{'store_pub'};
    return $store;
}

## the physical device below the store
## [ one id per filesystem ; two partitions of one drive are no redundancy ]
## -- informational
sub _device_info {
    my $path = shift;
    my %info = ( qw| st_dev | => ( stat $path )[0] );
    if ( open( my $fh, '<', qw| /proc/self/mountinfo | ) ) {
        my $best = '';
        while ( my $line = <$fh> ) {
            my @f     = split m| |, $line;
            my ($sep) = grep { $f[$ARG] eq '-' } 0 .. $#f;
            next if not defined $sep;
            my $mnt = $f[4];
            next if index( "$path/", $mnt eq '/' ? '/' : "$mnt/" ) != 0;
            next if length $mnt < length $best;
            $best = $mnt;
            @info{qw| mount_point fs_type source |}
                = ( $mnt, $f[ $sep + 1 ], $f[ $sep + 2 ] );
        }
        close $fh;
    }
    return \%info;
}

##[ IDENTITY ]################################################################

sub _id_payload_check {
    my $p   = shift;
    my $pub = unb32( $p->{'store_pub'} // '' );
    refuse('id record : bad store key')
        if not defined $pub
        or length $pub != 32;
    refuse('id record : bad init ntime')
        if ( $p->{'init_ntime'} // '' ) !~ m|\A\d{14}\z|;
    refuse('id record : bad name') if ( $p->{'name'} // '' ) !~ $NAME_RE;
    refuse('id record : bad intent')
        if ( $p->{'intent'} // '' ) !~ m|\A[\x20-\x7e]{1,1024}\z|;
    return $pub;
}

## verifies a disk's identity WITHOUT changing anything : the directory name
## must equal the amos recomputed over id.record, id.amos and id.l13 must
## match, the parent signature must verify
## [ and the parent key be trusted when anchors exist ]
sub disk_read_id {
    my %opt  = @ARG;
    my $root = root_dir(%opt);
    my $disk = $opt{'disk'};
    my $path = _disk_path( $root, $disk );

    refuse( 'no disk %s under %s', $disk, $root ) if not -d $path;
    my $bytes = read_file("$path/.n7fs/id.record");
    refuse( '%s : no id.record', $disk ) if not defined $bytes;

    my $rec       = signed_record_parse( qw| id |, $bytes );
    my $store_pub = _id_payload_check( $rec->{'payload'} );

    my $amos = amos_of_bytes($bytes);
    refuse( 'directory name %s does not match the id %s', $disk, $amos )
        if $amos ne $disk;

    my $id_amos = read_file("$path/.n7fs/id.amos") // '';
    $id_amos =~ s|\n\z||;
    refuse( '%s : id.amos does not match id.record', $disk )
        if $id_amos ne $amos;

    my $id_l13 = read_file("$path/.n7fs/id.l13") // '';
    $id_l13 =~ s|\n\z||;
    refuse( '%s : id.l13 does not match id.record', $disk )
        if $id_l13 ne l13_standin($bytes);

    refuse( '%s : parent signature does not verify', $disk )
        if
        not verify( $rec->{'signer_pub'}, $rec->{'signed'}, $rec->{'sig'} );

    my @anchors = trusted_parents(%opt);
    refuse( '%s : parent key %s is not trusted',
        $disk, b32( $rec->{'signer_pub'} ) )
        if @anchors
        and not grep { $ARG eq $rec->{'signer_pub'} } @anchors;

    return {
        qw| disk |       => $disk,
        qw| path |       => $path,
        qw| store_pub |  => $store_pub,
        qw| parent_pub | => $rec->{'signer_pub'},
        qw| payload |    => $rec->{'payload'},
        qw| anchored |   => @anchors ? TRUE : FALSE,
    };
}

## creates <root>/<disk>/.n7fs/ ; a taken id -> the next ntime [ re-signed ]
sub disk_init {
    my %opt    = @ARG;
    my $root   = root_dir(%opt);
    my $hdir   = host_dir(%opt);
    my $paren  = _signer( \%opt, qw| parent | );
    my $name   = $opt{'name'}   // refuse('init needs a name [ or type ]');
    my $intent = $opt{'intent'} // refuse('init needs an intent');

    refuse( 'root %s is not a directory', $root ) if not -d $root;
    refuse('bad name')   if $name   !~ $NAME_RE;
    refuse('bad intent') if $intent !~ m|\A[\x20-\x7e]{1,1024}\z|;

    my $seed  = $opt{'store_seed'} // new_seed();
    my $store = seed_signer($seed);
    my $ntime = $opt{'ntime'} // ntime_now();

    my ( $record, $disk );
    foreach my $try ( 1 .. $INIT_TRIES ) {
        $record = signed_record_pack(
            qw| id |,
            {   qw| store_pub |  => b32( $store->public ),
                qw| init_ntime | => ntime14($ntime),
                qw| name |       => $name,
                qw| intent |     => $intent,
            },
            $paren
        );
        $disk = amos_of_bytes($record);
        last if not -e "$root/$disk" and not -l "$root/$disk";
        undef $disk;
        $ntime++;    ## collision : the next ntime, checksum again ##
    }
    refuse( 'no free disk id after %d tries', $INIT_TRIES )
        if not defined $disk;

    my $key_path = "$hdir/stores/$disk.store.key";
    refuse( 'store key %s exists', $key_path ) if -e $key_path;

    ## every check done -- writes from here ##
    my $tmp = "$root/.n7fs-init.tmp." . b32( random_bytes(5) );
    my $ok  = eval {
        make_dirs( "$tmp/.n7fs/mounts", 0700 );
        make_dirs( "$tmp/.n7fs/state",  0700 );
        write_new_file( "$tmp/.n7fs/id.record", $record );
        write_new_file( "$tmp/.n7fs/id.amos",   "$disk\n" );
        write_new_file( "$tmp/.n7fs/id.l13",    l13_standin($record) . "\n" );
        state_write(
            $tmp,
            {   qw| store_format | => 2,
                qw| epochs |       => [],
                qw| sums |         => {
                    qw| amos | => $AMOS_RULE,
                    qw| bmw |  => $BMW_RULE,
                    qw| l13 |  => $L13_TAG,
                },
                qw| device | => _device_info($root),
            },
            $store
        );
        make_dirs( "$hdir/stores", 0700 );
        key_file_write( $key_path, $seed );
        fault(qw| init:before-publish |);
        publish_dir( $tmp, "$root/$disk" );
        1;
    };
    if ( not $ok ) {
        my $err = $EVAL_ERROR;
        remove_tree($tmp);
        unlink $key_path if not -e "$root/$disk";
        die $err;
    }

    ## read back : the published store must verify as a stranger would ##
    disk_read_id( %opt, qw| disk | => $disk );
    return $disk;
}

##[ MOUNT RECORDS ]###########################################################

sub _mount_handle {
    my ( $disk, $host_pub, $ntime14 ) = @ARG;
    return amos_of_bytes( pack( 'a7 a32 a14', $disk, $host_pub, $ntime14 ) );
}

## every record of a mount directory, verified ; one bad record refuses the
## whole history [ fail closed ]
sub _read_mount_dir {
    my ( $dir, $disk, $only_pub ) = @ARG;
    my @out;
    foreach my $name ( _list( $dir, $MOUNT_RE ) ) {
        my ( $nt, $mount ) = $name =~ $MOUNT_RE;
        my $rec = signed_record_parse( qw| mount |, read_file("$dir/$name") );
        my $p   = $rec->{'payload'};
        refuse( 'mount record %s : signature does not verify', $name )
            if not verify( $rec->{'signer_pub'}, $rec->{'signed'},
            $rec->{'sig'} );
        refuse( 'mount record %s : fields do not match its name', $name )
            if ( $p->{'ntime'} // '' ) ne $nt
            or ( $p->{'mount'}       // '' ) ne $mount
            or ( $p->{'disk'}        // '' ) ne $disk
            or ( $p->{'event'}       // '' ) !~ m{\A(attach|detach)\z}
            or ( $p->{'mount_ntime'} // '' ) !~ m|\A\d{14}\z|
            or $p->{'mount_ntime'} gt $nt;
        refuse( 'mount record %s : mount handle does not match', $name )
            if _mount_handle( $disk, $rec->{'signer_pub'},
            $p->{'mount_ntime'} ) ne $mount;
        refuse( 'mount record %s : signed by a foreign host key', $name )
            if defined $only_pub and $rec->{'signer_pub'} ne $only_pub;
        push @out,
            {
            qw| name |     => $name,
            qw| ntime |    => $nt,
            qw| host_pub | => $rec->{'signer_pub'},
            $p->%*,
            };
    }
    return @out;
}

sub mount_history {
    my ( $disk_path, $disk ) = @ARG;
    return _read_mount_dir( "$disk_path/.n7fs/mounts", $disk );
}

sub host_mounts {
    my %opt  = @ARG;
    my $host = _signer( \%opt, qw| host | );
    return _read_mount_dir( host_dir(%opt) . "/mounts/$opt{'disk'}",
        $opt{'disk'}, $host->public );
}

##[ WITNESS ]#################################################################

## the newest use record of this host for a disk : undef = never seen. a
## damaged \ unsigned \ foreign newest record or a missing timestamp refuses
## [ like a failed signature ]
sub witness_read {
    my %opt   = @ARG;
    my $host  = _signer( \%opt, qw| host | );
    my $dir   = host_dir(%opt) . "/witness/$opt{'disk'}";
    my @names = _list( $dir, $USE_RE );
    return undef if not @names;

    my $name = $names[-1];
    my $rec  = signed_record_parse( qw| use |, read_file("$dir/$name") );
    my $p    = $rec->{'payload'};
    refuse( 'witness %s : signature does not verify', $name )
        if
        not verify( $rec->{'signer_pub'}, $rec->{'signed'}, $rec->{'sig'} );
    refuse( 'witness %s : not signed by this host', $name )
        if $rec->{'signer_pub'} ne $host->public;

    $p->{'written'} //= $p->{'last'};
    foreach my $field (qw| first last written |) {
        refuse( 'witness %s : %s-use timestamp missing', $name, $field )
            if ( $p->{$field} // '' ) !~ m|\A\d{14}\z|;
    }
    refuse( 'witness %s : bad highest store format', $name )
        if ( $p->{'store_format'} // 1 ) !~ m|\A\d{1,3}\z|
        or ( $p->{'store_format'} // 1 ) < 1;
    refuse( 'witness %s : record does not match', $name )
        if ( $p->{'disk'} // '' ) ne $opt{'disk'}
        or $p->{'first'} gt $p->{'last'}
        or "$p->{'written'}.use" ne $name
        or ( $p->{'last_record'} // '' ) !~ $MOUNT_RE;
    return $p;
}

## the disk's presented state against the witness window [ spec 4 ] : equal to
## last = current ; newer = it travelled [ the last record seen here must
## still be in its history, else a diverging clone ] ; inside [ first, last )
## = an earlier state [ rollback : refused unless allowed ] ; before first =
## foreign
sub _check_window {
    my ( $opt, $id, $history ) = @ARG;
    my $w = witness_read( $opt->%* );
    my $presented
        = @{$history}
        ? $history->[-1]{'ntime'}
        : $id->{'payload'}{'init_ntime'};
    return ( $w, $presented, qw| first-contact | ) if not defined $w;

    if ( $presented eq $w->{'last'} or $presented gt $w->{'last'} ) {
        refuse(
            '%s : history diverges from this host\'s '
                . 'last record %s [ clone or replaced history ]',
            $id->{'disk'},
            $w->{'last_record'}
            )
            if not grep { $ARG->{'name'} eq $w->{'last_record'} } @{$history};
        return ( $w, $presented,
            $presented eq $w->{'last'} ? qw| current | : qw| travelled | );
    }
    if ( $presented ge $w->{'first'} ) {
        refuse( '%s : presents an earlier state %s inside [ '
                . '%s, %s ) [ rollback -- refused by policy ]',
            $id->{'disk'}, $presented, $w->{'first'}, $w->{'last'} )
            if not $opt->{'allow_rollback'};
        return ( $w, $presented, qw| rollback-allowed | );
    }
    refuse( '%s : presents a state %s before the first use %s [ foreign ]',
        $id->{'disk'}, $presented, $w->{'first'} );
}

sub _write_mount_event {
    my ( $opt, $id, $w, $presented, $event, $mount_ntime ) = @ARG;
    my $host = $opt->{'host'};
    my $hdir = host_dir( $opt->%* );
    my $disk = $id->{'disk'};

    my $ntime = ntime_now();
    $ntime = $presented + 1   if $ntime <= $presented;
    $ntime = $w->{'last'} + 1 if defined $w and $ntime <= $w->{'last'};
    $ntime = $w->{'written'} + 1
        if defined $w and $ntime <= $w->{'written'};
    my $nt14 = ntime14($ntime);
    $mount_ntime //= $nt14;
    my $mount = _mount_handle( $disk, $host->public, $mount_ntime );

    my $rec = signed_record_pack(
        qw| mount |,
        {   qw| disk |        => $disk,
            qw| mount |       => $mount,
            qw| event |       => $event,
            qw| ntime |       => $nt14,
            qw| mount_ntime | => $mount_ntime,
            qw| host_name |   => hostname(),
        },
        $host
    );
    my $name    = "$nt14.$mount";
    my $highest = $id->{'state'}{'store_format'};
    $highest = $w->{'store_format'} // 1
        if defined $w
        and ( $w->{'store_format'} // 1 ) > $highest;
    my $use = signed_record_pack(
        qw| use |,
        {   qw| disk |         => $disk,
            qw| first |        => defined $w ? $w->{'first'} : $nt14,
            qw| last |         => $nt14,
            qw| written |      => $nt14,
            qw| last_record |  => $name,
            qw| last_event |   => $event,
            qw| store_format | => $highest + 0,
        },
        $host
    );

    ## disk first, then the host's copy, then the witness : a failure after
    ## the disk record leaves a disk newer than the witness [ = travelled ]
    write_new_file( "$id->{'path'}/.n7fs/mounts/$name", $rec );
    fault(qw| mount:after-disk-record |);
    make_dirs( "$hdir/mounts/$disk", 0700 );
    write_new_file( "$hdir/mounts/$disk/$name", $rec );
    make_dirs( "$hdir/witness/$disk", 0700 );
    write_new_file( "$hdir/witness/$disk/$nt14.use", $use );

    return {
        qw| mount | => $mount,
        qw| ntime | => $nt14,
        qw| name |  => $name
    };
}

## a format observation is append-only too : 'written' orders the use files,
## while first \ last remain the mount window and last_record stays a mount
sub witness_note_format {
    my %opt   = @ARG;
    my $host  = _signer( \%opt, qw| host | );
    my $id    = $opt{'id'} // disk_read_id(%opt);
    my $state = $opt{'state'}
        // state_read( $id->{'path'}, $id->{'store_pub'} );
    my $w = witness_read(%opt);
    return FALSE if not defined $w;
    return FALSE if $state->{'store_format'} <= ( $w->{'store_format'} // 1 );

    my $ntime = ntime_now();
    $ntime = $w->{'written'} + 1 if $ntime <= $w->{'written'};
    my $written = ntime14($ntime);
    my $use     = signed_record_pack(
        qw| use |,
        {   qw| disk |         => $id->{'disk'},
            qw| first |        => $w->{'first'},
            qw| last |         => $w->{'last'},
            qw| written |      => $written,
            qw| last_record |  => $w->{'last_record'},
            qw| last_event |   => $w->{'last_event'},
            qw| store_format | => $state->{'store_format'} + 0,
        },
        $host
    );
    my $dir = host_dir(%opt) . '/witness/' . $id->{'disk'};
    make_dirs( $dir, 0700 );
    write_new_file( "$dir/$written.use", $use );
    return TRUE;
}

sub witness_check_format {
    my %opt   = @ARG;
    my $id    = $opt{'id'} // disk_read_id(%opt);
    my $state = $opt{'state'}
        // state_read( $id->{'path'}, $id->{'store_pub'} );
    $opt{'disk'} //= $id->{'disk'};
    my $w
        = exists $opt{'witness'} ? $opt{'witness'} : witness_read(%opt);
    return TRUE if not defined $w;
    return TRUE
        if $state->{'store_format'} >= ( $w->{'store_format'} // 1 )
        or $opt{'allow_rollback'};
    refuse(
        '%s : store format %d is below the witnessed '
            . 'highest %d [ rollback -- refused by policy ]',
        $id->{'disk'},
        $state->{'store_format'},
        $w->{'store_format'} // 1
    );
}

sub _checks {
    my %opt = @ARG;
    _signer( \%opt, qw| host | );
    my $id      = disk_read_id(%opt);
    my @history = mount_history( $id->{'path'}, $id->{'disk'} );
    my @mine    = host_mounts(%opt);
    my ( $w, $presented, $window ) = _check_window( \%opt, $id, \@history );
    my $state = state_read( $id->{'path'}, $id->{'store_pub'} );
    witness_check_format(
        %opt,
        qw| id |      => $id,
        qw| state |   => $state,
        qw| witness | => $w
    );
    $id->{'state'} = $state;
    return ( $id, \@history, \@mine, $w, $presented, $window );
}

sub disk_attach {
    my %opt = @ARG;
    my ( $id, $history, $mine, $w, $presented, $window ) = _checks(%opt);
    refuse( '%s is attached already [ mount %s ]',
        $id->{'disk'}, $mine->[-1]{'mount'} )
        if @{$mine} and $mine->[-1]{'event'} eq qw| attach |;
    my $done = _write_mount_event( \%opt, $id, $w, $presented, qw| attach | );
    $done->{'window'} = $window;
    $done->{'disk'}   = $id->{'disk'};
    return $done;
}

sub disk_detach {
    my %opt = @ARG;
    my ( $id, $history, $mine, $w, $presented ) = _checks(%opt);
    refuse( '%s is not attached here', $id->{'disk'} )
        if not @{$mine}
        or $mine->[-1]{'event'} ne qw| attach |;
    my $done = _write_mount_event( \%opt, $id, $w, $presented, qw| detach |,
        $mine->[-1]{'mount_ntime'} );
    $done->{'disk'} = $id->{'disk'};
    return $done;
}

## for writers : the identity verifies, the window holds, and this host's
## newest record says attached. returns the id
sub disk_require_attached {
    my %opt = @ARG;
    my ( $id, $history, $mine ) = _checks(%opt);
    refuse( '%s is not attached here [ n7fs attach %s ]',
        $id->{'disk'}, $id->{'disk'} )
        if not @{$mine}
        or $mine->[-1]{'event'} ne qw| attach |;
    $id->{'mount'} = $mine->[-1]{'mount'};
    return $id;
}

sub disk_status {
    my %opt = @ARG;
    my ( $id, $history, $mine, $w, $presented, $window ) = _checks(%opt);
    return {
        qw| disk |     => $id->{'disk'},
        qw| name |     => $id->{'payload'}{'name'},
        qw| intent |   => $id->{'payload'}{'intent'},
        qw| init |     => $id->{'payload'}{'init_ntime'},
        qw| anchored | => $id->{'anchored'},
        qw| records |  => scalar @{$history},
        qw| window |   => $window,
        qw| first |    => defined $w ? $w->{'first'} : undef,
        qw| last |     => defined $w ? $w->{'last'}  : undef,
        qw| attached | =>
            ( @{$mine} and $mine->[-1]{'event'} eq qw| attach | )
        ? $mine->[-1]{'mount'}
        : undef,
        qw| state | => $id->{'state'},
    };
}

1;

#,,.,,,,,,..,,.,.,,..,,,,,..,,,,.,,,,,,,,,,.,,..,,...,...,.,,,.,.,,,,,,,.,...,
#WD6OSS2Q7L2GCTCCSIVSVYSO5Y6ZFFN7XSWCE5Z2Q6ZPYPW4PNJDQMJN4NQOQ3AFIFM6A45P3NEES
#\\\|HZCLPPVM5KXGT2XZF65FKRFIDYGADFKJ2BUNB7SEPU7LL3BQV4E \ / AMOS7 \ YOURUM ::
#\[7]KE2CCBJZEUK3EW4OOGCBISCWMZURBINBNGUHFMVNQIK7HMWZJGDI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
