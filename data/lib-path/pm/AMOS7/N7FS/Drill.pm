## [:< ##

package AMOS7::N7FS::Drill;    #############################################

## restore drills from one holder in a clean recovery context.

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

our $VERSION = qw| AMOS7::N7FS::Drill-VERSION.JRRHCAY |;

@EXPORT_OK = qw| drill_run drill_write drill_records drill_latest drill_status
    key_copy_moved |;

use JSON::PP;
use Fcntl        qw| LOCK_EX |;
use File::Temp   qw| tempdir |;
use AMOS7::NTIME qw| parse_y_age y_age_str |;
use AMOS7::N7FS  qw| b32 unb32 read_file write_new_file make_dirs sync_dir
    random_bytes refuse ntime_now ntime14 |;
use AMOS7::N7FS::Sign qw| verify |;

my $JSON = JSON::PP->new->utf8->canonical;

sub _drill_path {
    my ( $host_dir, $root ) = @_;
    return "$host_dir/receipts/$root->{'root_id'}/drills.json";
}

sub _root_public {
    my $root = shift;
    return $root->{'signer'}->public if ref $root->{'signer'};
    return $root->{'public'};
}

sub _record_verify {
    my ( $root, $line ) = @_;
    my $data = eval { $JSON->decode($line) };
    refuse('drill record is not valid json') if ref $data ne qw| HASH |;
    my $record = $data->{'drill'};
    refuse('drill record is not an object') if ref $record ne qw| HASH |;
    refuse('drill record root id does not match')
        if ( $record->{'root_id'} // '' ) ne $root->{'root_id'};
    refuse('drill record is signed by another key')
        if ( $data->{'pub'} // '' ) ne b32( _root_public($root) // '' );
    refuse('drill record signature does not verify')
        if not verify(
        _root_public($root),
        "p7 n7fs drill v1\0" . $JSON->encode($record),
        unb32( $data->{'sig'} // '' ) // ''
        );

    foreach my $field (qw| time files bytes took head_version |) {
        refuse("drill record $field is not whole ntime or a count")
            if ( $record->{$field} // '' ) !~ m|\A\d+\z|;
    }
    refuse('drill record byte budget is invalid')
        if defined $record->{'max_bytes'}
        and $record->{'max_bytes'} !~ m|\A\d+\z|;
    refuse('drill record holder id is invalid')
        if ( $record->{'holder_id'} // '' ) !~ m|\A[A-Z2-7]{26}\z|;
    refuse('drill record result is invalid')
        if ( $record->{'result'} // '' ) !~ m{\A(?:passed|failed)\z};
    refuse('drill record mode is invalid')
        if ( $record->{'mode'} // '' )
        !~ m{\A(?:full|attended|sampled|offline)\z};
    return $record;
}

sub drill_records {
    my ( $host_dir, $root ) = @_;
    my $bytes = read_file( _drill_path( $host_dir, $root ) );
    return [] if not defined $bytes;
    my @records;
    foreach my $line ( split m|\n|, $bytes ) {
        next if not length $line;
        push @records, _record_verify( $root, $line );
    }
    return \@records;
}

sub drill_latest {
    my ( $host_dir, $root, $spec, $modes ) = @_;
    my $records  = drill_records( $host_dir, $root );
    my %mode     = map { $ARG => TRUE } @{ $modes // [] };
    my ($latest) = grep {
                $ARG->{'result'} eq qw| passed|
            and ( not defined $spec or $ARG->{'holder'} eq $spec )
            and ( not keys %mode or $mode{ $ARG->{'mode'} } )
    } reverse @{$records};
    return $latest;
}

sub drill_write {
    my %opt      = @_;
    my $root     = $opt{'root'} // refuse('a drill record needs the root');
    my $host_dir = $opt{'host_dir'} // $root->{'host_dir'}
        // refuse('a drill record needs a host dir');
    my $record = {
        qw| time |         => $opt{'time'} // ntime_now(),
        qw| holder |       => $opt{'holder'},
        qw| holder_id |    => $opt{'holder_id'},
        qw| tree |         => $opt{'tree'} // '',
        qw| snapshot |     => $opt{'snapshot'},
        qw| files |        => $opt{'files'}        // 0,
        qw| bytes |        => $opt{'bytes'}        // 0,
        qw| took |         => $opt{'took'}         // 0,
        qw| head_version | => $opt{'head_version'} // 0,
        qw| mode |         => $opt{'mode'}         // qw| full |,
        qw| result |       => $opt{'result'},
        defined $opt{'max_bytes'}
        ? ( qw| max_bytes | => $opt{'max_bytes'} + 0 )
        : (),
        defined $opt{'error'} ? ( qw| error | => $opt{'error'} ) : (),
        qw| root_id | => $root->{'root_id'},
    };
    $record->{$_} += 0 for qw| time files bytes took head_version |;
    delete $record->{'snapshot'} if not defined $record->{'snapshot'};
    my $signed = "p7 n7fs drill v1\0" . $JSON->encode($record);
    my $line   = $JSON->encode(
        {   qw| drill | => $record,
            qw| pub |   => b32( $root->{'signer'}->public ),
            qw| sig |   => b32( $root->{'signer'}->sign($signed) ),
        }
    );
    my $path = _drill_path( $host_dir, $root );
    my $dir  = $path;
    $dir =~ s|/[^/]+\z||;
    make_dirs( $dir, 0700 );
    open( my $fh, '>>:raw', $path )
        or refuse( 'cannot append drill record %s : %s', $path, $OS_ERROR );
    flock( $fh, LOCK_EX ) or refuse('cannot lock the drill record');
    print {$fh} "$line\n" or refuse('cannot write the drill record');
    $fh->sync             or refuse('cannot sync the drill record');
    close $fh             or refuse('cannot close the drill record');
    chmod 0600, $path or refuse('cannot protect the drill record');
    _record_verify( $root, $line );
    return $record;
}

sub _path {
    my $entry = shift;
    my $path
        = ( $entry->{'p'} // '' ) eq ''
        ? ''
        : unb32( $entry->{'p'} // '' );
    refuse('drill manifest path is invalid') if not defined $path;
    return $path;
}

sub _actual_paths {
    my ( $root, $relative, $paths ) = @_;
    $paths->{$relative} = TRUE;
    my $path = length $relative ? "$root/$relative" : $root;
    return if -l $path or not -d $path;
    opendir( my $dh, $path )
        or refuse( 'drill cannot read restored directory %s', $path );
    my @names = grep { $ARG ne '.' and $ARG ne '..' } readdir $dh;
    closedir $dh;
    _actual_paths( $root, length $relative ? "$relative/$ARG" : $ARG, $paths )
        for @names;
    return;
}

sub _metadata_verify {
    my ( $target, $entries, $restored ) = @_;
    my ( %expected, %source );
    my $bytes = 0;
    foreach my $entry ( @{$entries} ) {
        my $relative = _path($entry);
        refuse('drill manifest has a duplicate path')
            if $expected{$relative}++;
        my $type = $entry->{'t'} // '';
        refuse( 'drill manifest contains a skipped entry [ %s ]', $relative )
            if $type eq qw| skipped |;
        $source{$relative} = $entry;
        $bytes += $entry->{'size'} // 0 if $type eq qw| file |;
    }
    my %actual;
    _actual_paths( $target, '', \%actual );
    foreach my $relative ( sort keys %expected ) {
        refuse( 'drill restored path is missing [ %s ]', $relative )
            if not $actual{$relative};
    }
    foreach my $relative ( sort keys %actual ) {
        refuse( 'drill restored path is not in the manifest [ %s ]',
            $relative )
            if not $expected{$relative};
    }
    foreach my $relative ( sort keys %source ) {
        my $entry = $source{$relative};
        my $path  = length $relative ? "$target/$relative" : $target;
        my @st    = lstat $path;
        refuse( 'drill cannot stat restored path [ %s ]', $relative )
            if not @st;
        my $type = $entry->{'t'};
        my $type_ok
            = $type eq qw| dir |     ? -d _
            : $type eq qw| symlink | ? -l _
            :                          -f _;
        refuse( 'drill restored type differs [ %s ]', $relative )
            if not $type_ok;
        if ( $type eq qw| symlink | ) {
            my $target = unb32( $entry->{'l'} // '' );
            refuse( 'drill restored link target differs [ %s ]', $relative )
                if not defined $target
                or ( readlink($path) // '' ) ne $target;
            next;
        }
        refuse( 'drill restored mode differs [ %s ]', $relative )
            if ( $st[2] & 07777 ) != ( $entry->{'mode'} & 07777 );
        refuse( 'drill restored mtime differs [ %s ]', $relative )
            if int( $st[9] ) != $entry->{'mtime'};
        refuse( 'drill restored size differs [ %s ]', $relative )
            if $type ne qw| dir | and $st[7] != ( $entry->{'size'} // 0 );
    }
    refuse('drill restored file count differs')
        if $restored->{'files'} !=
        grep { ( $ARG->{'t'} // '' ) =~ m{\A(?:file|hardlink)\z} }
        @{$entries};
    return $bytes;
}

sub _offline_anchor {
    my ( $root, $head ) = @_;
    my $copy = $root->{'key_ref'} // '';
    refuse('offline drill needs a file key copy') if $copy =~ m|\Avault:|;
    my $path = "$copy.anchor";
    my $line = read_file($path)
        // refuse( 'offline drill needs its heads -anchor line [ %s ]',
        $path );
    $line =~ s|\s+\z||;
    my ( $tag, $version, $time, $extra ) = split m|\s+|, $line;
    refuse( 'offline anchor must be <root tag> <version> <ntime> [ %s ]',
        $path )
        if defined $extra
        or ( $tag     // '' ) !~ m|\A[A-Z2-7]{7}\z|
        or ( $version // '' ) !~ m|\A[1-9]\d*\z|
        or ( $time    // '' ) !~ m|\A\d+\z|;
    refuse( 'offline anchor belongs to another root [ %s ]', $tag )
        if $tag ne substr( $root->{'root_id'}, 0, 7 );
    refuse( 'offline anchor mismatch : holder head v%d is below anchor v%d',
        $head->{'version'}, $version )
        if $head->{'version'} < $version;
    refuse( 'offline anchor mismatch : holder head time %d is before %d',
        $head->{'time'}, $time )
        if $head->{'version'} == $version and $head->{'time'} < $time;
    return {
        qw| tag |     => $tag,
        qw| version | => $version,
        qw| time |    => $time
    };
}

sub _sampled_restore {
    my ( $root, $base, $map, $entries, $scratch, $budget ) = @_;
    my %candidates;
    foreach
        my $entry ( grep { ( $ARG->{'t'} // '' ) eq qw| file | } @{$entries} )
    {
        my $address = $entry->{'a'} // next;
        $candidates{$address} = $entry->{'size'} // 0;
    }
    make_dirs( "$scratch/sample", 0700 );
    my ( $files, $bytes ) = ( 0, 0 );
    while ( keys %candidates ) {
        my $total = 0;
        $total += $candidates{$ARG} || 1 for keys %candidates;
        my $roll = unpack( 'Q>', random_bytes(8) ) % $total;
        my $address;
        foreach my $candidate ( sort keys %candidates ) {
            $roll -= $candidates{$candidate} || 1;
            if ( $roll < 0 ) {
                $address = $candidate;
                last;
            }
        }
        my $size = delete $candidates{$address};
        next if $bytes + $size > $budget;
        my $safe = $address;
        $safe =~ s|/|_|g;
        AMOS7::N7FS::Seal::_restore_node( $root, $base, $map, $address,
            "$scratch/sample/$safe" );
        $files++;
        $bytes += $size;
    }
    return { qw| files | => $files, qw| bytes | => $bytes };
}

sub drill_run {
    my %opt     = @_;
    my $root    = $opt{'root'}   // refuse('a drill needs the open root');
    my $holder  = $opt{'holder'} // refuse('a drill needs one holder');
    my $start   = ntime_now();
    my $scratch = tempdir( 'n7fs-drill-XXXXXX', TMPDIR => 1, CLEANUP => 0 );
    my $record  = {
        qw| holder |       => $holder,
        qw| holder_id |    => '',
        qw| tree |         => $opt{'tree'} // '',
        qw| head_version | => 0,
        qw| files |        => 0,
        qw| bytes |        => 0,
        qw| mode |         => $opt{'offline'} ? qw| offline |
        : defined $opt{'max_bytes'} ? qw| sampled |
        : $opt{'mode'} // qw| attended |,
        qw| result | => qw| failed |,
        defined $opt{'max_bytes'} ? ( qw| max_bytes | => $opt{'max_bytes'} )
        : (),
    };
    my ( $result, $restored );
    my $ok = eval {
        require AMOS7::N7FS::Seal;
        require AMOS7::N7FS::Holder;
        refuse('drill byte budget must be a positive count or zero')
            if defined $opt{'max_bytes'} and $opt{'max_bytes'} !~ m|\A\d+\z|;
        $record->{'holder'} = AMOS7::N7FS::Holder::holder_canonical($holder);
        my ( undef, $head, $map, $base )
            = AMOS7::N7FS::Seal::_context( $root, $holder, TRUE );
        refuse('drill found no sealed head') if not defined $head;
        @{$record}{qw| holder_id head_version |}
            = ( $head->{'holder'}, $head->{'version'} );
        _offline_anchor( $root, $head ) if $opt{'offline'};
        my $name = $opt{'tree'};

        if ( not defined $name ) {
            my @trees = sort {
                ( $map->{'trees'}{$b}{'created'} // '' )
                    cmp( $map->{'trees'}{$a}{'created'} // '' )
                    or $a cmp $b
            } grep {
                ( $map->{'trees'}{$ARG}{'held'} // -1 )
                    == ( $map->{'trees'}{$ARG}{'files'} // -2 )
            } keys $map->{'trees'}->%*;
            refuse('drill found no complete tree') if not @trees;
            $name = $trees[0];
        }
        my $tree = $map->{'trees'}{$name}
            // refuse( 'drill found no live tree named %s', $name );
        $record->{'tree'} = $name;
        AMOS7::N7FS::Seal::_manifest_verify( $root, $base, undef,
            $name, $tree );
        my ( $header, @entries )
            = AMOS7::N7FS::Seal::_manifest_read( $root, $base, undef, $tree );
        if ( defined $opt{'max_bytes'} ) {
            $restored = _sampled_restore( $root, $base, $map, \@entries,
                $scratch, $opt{'max_bytes'} );
            $record->{'bytes'} = $restored->{'bytes'};
        } else {
            $restored = AMOS7::N7FS::Seal::seal_recover(
                qw| root |    => $root,
                qw| holders | => [$holder],
                qw| target |  => "$scratch/tree",
                qw| tree |    => $name,
            );
            $record->{'bytes'}
                = _metadata_verify( "$scratch/tree", \@entries, $restored );
        }
        $record->{'snapshot'} = $header->{'snapshot'}
            if defined $header->{'snapshot'};
        $record->{'files'}  = $restored->{'files'};
        $record->{'result'} = qw| passed |;
        $result             = $record;
        1;
    };
    my $error = $EVAL_ERROR // '';
    chomp $error;
    $record->{'took'} = ntime_now() - $start;
    $record->{'took'} = 0 if $record->{'took'} < 0;
    if ($ok) {
        drill_write( %opt, %{$record} );
        _key_copy_ack( $opt{'host_dir'} // $root->{'host_dir'}, $root )
            if $opt{'offline'};
        require File::Path;
        File::Path::remove_tree($scratch);
        return $result;
    }
    $record->{'error'} = $error || 'unknown drill failure';
    eval { drill_write( %opt, %{$record} ) };
    $error .= ' ; drill record also failed : ' . $EVAL_ERROR if $EVAL_ERROR;
    die "n7fs : drill FAILED on $record->{'holder'} "
        . ": $error ; scratch kept : $scratch\n";
}

sub drill_disk_root {
    my $id      = shift // refuse('drill status needs a disk id');
    my $bytes   = read_file("$id->{'path'}/.n7fs/seal-root") // return undef;
    my $binding = eval { $JSON->decode($bytes) };
    my $pub
        = ref $binding eq qw| HASH |
        ? unb32( $binding->{'pub'} // '' )
        : undef;
    my $sig
        = ref $binding eq qw| HASH |
        ? unb32( $binding->{'sig'} // '' )
        : undef;
    require AMOS7::N7FS::Sum;
    refuse('disk seal binding is invalid')
        if ref $binding ne qw| HASH |
        or ( $binding->{'v'}       // '' ) != 1
        or ( $binding->{'disk'}    // '' ) ne $id->{'disk'}
        or ( $binding->{'root_id'} // '' ) !~ m|\A[A-Z2-7]{77}\z|
        or not defined $pub
        or not defined $sig
        or b32(
        AMOS7::N7FS::Sum::bmw384_bytes( 'p7 n7fs seal root id v1' . $pub ) )
        ne $binding->{'root_id'}
        or not verify(
        $pub,
        "p7 n7fs disk seal binding v1\0"
            . $id->{'disk'} . "\0"
            . $binding->{'root_id'},
        $sig
        );
    return { qw| root_id | => $binding->{'root_id'}, qw| public | => $pub };
}

sub _key_copy_path {
    my ( $host_dir, $root_id ) = @_;
    refuse('key-copy-moved needs a valid root id')
        if ( $root_id // '' ) !~ m|\A[A-Z2-7]{77}\z|;
    return "$host_dir/receipts/$root_id/key-copies.cfg";
}

sub _key_copy_state {
    my ( $host_dir, $root_id ) = @_;
    my $body = read_file( _key_copy_path( $host_dir, $root_id ) ) // '';
    my %state;
    foreach my $line ( split m|\n|, $body ) {
        next if $line =~ m|\A\s*(?:#.*)?\z|;
        my ( $key, $value )
            = $line =~ m|\A\s*([A-Za-z0-9_.-]+)\s*[:=]\s*(\d+)\s*\z|;
        refuse( 'invalid key-copy state line [ %s ]', $line )
            if not defined $value;
        refuse( 'duplicate key-copy state key [ %s ]', $key )
            if exists $state{$key};
        $state{$key} = $value + 0;
    }
    return \%state;
}

sub _key_copy_write {
    my ( $host_dir, $root_id, $state ) = @_;
    my $path = _key_copy_path( $host_dir, $root_id );
    my $dir  = $path;
    $dir =~ s|/[^/]+\z||;
    make_dirs( $dir, 0700 );
    my $tmp = "$path.tmp." . b32( random_bytes(5) );
    write_new_file( $tmp,
              "format : 1\nkey-copy.last-moved : "
            . "$state->{'moved'}\nkey-copy.pending : "
            . "$state->{'pending'}\noffline-drill.due : "
            . "$state->{'due'}\n" );
    chmod 0600, $tmp or refuse('cannot protect key-copy state');
    rename $tmp, $path or refuse('cannot publish key-copy state');
    sync_dir($dir);
    return;
}

sub key_copy_moved {
    my %opt      = @_;
    my $host_dir = $opt{'host_dir'}
        // refuse('key-copy-moved needs a host dir');
    my $root_id = $opt{'root_id'};
    my $now     = ntime_now();
    _key_copy_write( $host_dir, $root_id,
        { qw| moved | => $now, qw| pending | => 1, qw| due | => $now } );
    return {
        qw| root_id | => $root_id,
        qw| moved |   => $now,
        qw| due |     => $now
    };
}

sub _key_copy_ack {
    my ( $host_dir, $root ) = @_;
    my $state = _key_copy_state( $host_dir, $root->{'root_id'} );
    return if not keys %{$state};
    my $now = ntime_now();
    _key_copy_write(
        $host_dir,
        $root->{'root_id'},
        {   qw| moved |   => $state->{'key-copy.last-moved'} // 0,
            qw| pending | => 0,
            qw| due |     => $now + parse_y_age('3Y1'),
        }
    );
    return;
}

sub drill_status {
    my %opt      = @_;
    my $host_dir = $opt{'host_dir'}
        // refuse('drill status needs a host dir');
    my $root           = $opt{'root'} // refuse('drill status needs a root');
    my $now            = $opt{'now'}  // ntime_now();
    my $holder_cadence = parse_y_age( $opt{'holder_every'} // '1Y1' )
        // parse_y_age('1Y1');
    my $key_copy = _key_copy_state( $host_dir, $root->{'root_id'} );
    my $moved    = $key_copy->{'key-copy.last-moved'} // 0;
    my $pending  = $key_copy->{'key-copy.pending'}    // 0;
    my @items;

    foreach my $spec (
        {   qw| name |    => 'holder drill',
            qw| modes |   => [qw| full |],
            qw| every |   => $holder_cadence,
            qw| cadence | => $opt{'holder_every'} // '1Y1',
        },
        {   qw| name |    => 'attended main-root drill',
            qw| modes |   => [qw| attended sampled |],
            qw| every |   => parse_y_age('1Y1'),
            qw| cadence | => '1Y1',
        },
        {   qw| name |    => 'offline-copy drill',
            qw| modes |   => [qw| offline |],
            qw| every |   => parse_y_age('3Y1'),
            qw| cadence | => '3Y1',
        },
    ) {
        my $latest
            = drill_latest( $host_dir, $root, undef, $spec->{'modes'} );
        my $last = $latest->{'time'} // 0;
        my $due  = $last + $spec->{'every'};
        my $movement_due
            = $spec->{'name'} eq 'offline-copy drill' && $pending;
        $due = $moved if $movement_due;
        push @items,
            {
            %{$spec},
            qw| last |         => $last,
            qw| due |          => $due,
            qw| overdue |      => $now >= $due  ? TRUE : FALSE,
            qw| movement_due | => $movement_due ? TRUE : FALSE,
            };
    }
    return \@items;
}

sub drill_status_say {
    my $items = shift;
    my $now   = shift // ntime_now();
    foreach my $item ( @{$items} ) {
        say ': ', $item->{'name'}, ' : ',
            $item->{'overdue'}
            ? ( $item->{'movement_due'} ? 'due now' : 'overdue' )
            : 'current',
            ' [ last ', $item->{'last'} || '-',
            ', due ', $item->{'due'}, $item->{'overdue'}
            ? ''
            : ', in ' . y_age_str( $item->{'due'} - $now ),
            ', cadence ', $item->{'cadence'}, ' ]';
    }
    return;
}

1;

#,,..,,.,,,,,,,.,,,,.,,,,,..,,.,,,.,.,.,,,,..,..,,...,...,...,.,.,.,.,,.,,,.,,
#OYPHKZKJGI6WF3AQ25AK2HV6CMDANEZHPRZKELL4L2PGBCFTD56H3IE4DSSQ2XVZ23UONPO6DHPSC
#\\\|XLJQ3PGPZIJ4MWO2Z6IQ23FUZIC2DIDXUBXTA324WWS6DJ3AEEF \ / AMOS7 \ YOURUM ::
#\[7]7H5B3G56BNUTRIVEUEPOW2M2J7RJB5R4KBHZ5B6AARPFNMG4COCQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
