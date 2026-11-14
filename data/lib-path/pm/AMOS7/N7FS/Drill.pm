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

our $VERSION = qw| AMOS7::N7FS::Drill-VERSION.YYUH6HQ |;

@EXPORT_OK = qw| drill_run drill_write drill_records drill_latest |;

use JSON::PP;
use Fcntl             qw| LOCK_EX |;
use File::Temp        qw| tempdir |;
use AMOS7::N7FS       qw| b32 unb32 read_file make_dirs refuse ntime_now |;
use AMOS7::N7FS::Sign qw| verify |;

my $JSON = JSON::PP->new->utf8->canonical;

sub _drill_path {
    my ( $host_dir, $root ) = @_;
    return "$host_dir/receipts/$root->{'root_id'}/drills.json";
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
        if ( $data->{'pub'} // '' ) ne b32( $root->{'signer'}->public );
    refuse('drill record signature does not verify')
        if not verify(
        $root->{'signer'}->public,
        "p7 n7fs drill v1\0" . $JSON->encode($record),
        unb32( $data->{'sig'} // '' ) // ''
        );

    foreach my $field (qw| time files bytes took head_version |) {
        refuse("drill record $field is not whole ntime or a count")
            if ( $record->{$field} // '' ) !~ m|\A\d+\z|;
    }
    refuse('drill record holder id is invalid')
        if ( $record->{'holder_id'} // '' ) !~ m|\A[A-Z2-7]{26}\z|;
    refuse('drill record result is invalid')
        if ( $record->{'result'} // '' ) !~ m{\A(?:passed|failed)\z};
    refuse('drill record mode is invalid')
        if ( $record->{'mode'} // '' ) ne qw| full |;
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
    my ( $host_dir, $root, $spec ) = @_;
    my $records = drill_records( $host_dir, $root );
    my ($latest) = grep {
        $ARG->{'result'} eq qw| passed|
            and ( not defined $spec or $ARG->{'holder'} eq $spec )
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
        qw| mode |         => qw| full |,
        qw| result |       => $opt{'result'},
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
        qw| result |       => qw| failed |,
    };
    my ( $result, $restored );
    my $ok = eval {
        require AMOS7::N7FS::Seal;
        require AMOS7::N7FS::Holder;
        $record->{'holder'} = AMOS7::N7FS::Holder::holder_canonical($holder);
        my ( undef, $head, $map, $base )
            = AMOS7::N7FS::Seal::_context( $root, $holder, TRUE );
        refuse('drill found no sealed head') if not defined $head;
        @{$record}{qw| holder_id head_version |}
            = ( $head->{'holder'}, $head->{'version'} );
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
        $restored = AMOS7::N7FS::Seal::seal_recover(
            qw| root |    => $root,
            qw| holders | => [$holder],
            qw| target |  => "$scratch/tree",
            qw| tree |    => $name,
        );
        $record->{'snapshot'} = $header->{'snapshot'}
            if defined $header->{'snapshot'};
        $record->{'bytes'}
            = _metadata_verify( "$scratch/tree", \@entries, $restored );
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

1;

#,,,.,,,,,..,,,..,.,,,,..,,.,,,.,,..,,,,,,.,,,..,,...,...,,..,,..,,.,,..,,..,,
#UUAQMF2ZTYGQP7YL2MYTIOS5RJZSRMFQZX2ZEFYZB7CHV6JULL7TZGDCKZLSDDE3LFPAVNXCRSRUA
#\\\|SKCLAOSEGK6EF6LOWWN45ROG6ARANELZY6X52ZU34PHN56BCWOQ \ / AMOS7 \ YOURUM ::
#\[7]ZEE5BLQNZZLWJ437BOIQY3EVSTNDMTXBVP3JVFAWVXGXTSQDFMDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
