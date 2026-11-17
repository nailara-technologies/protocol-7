package AMOS7::N7FS::Canon;
our $VERSION = qw| AMOS7::N7FS::Canon-VERSION.QI5QLVI |;

use v5.32.0;
use strict;
use English;
use warnings;

use Exporter;
use base qw| Exporter |;
use vars qw| @EXPORT_OK |;

use B                        ();
use AMOS7::B32               qw| encode_b32r decode_b32r |;
use AMOS7::cell::canon       qw| bmw384_b32 pack_head parse_head |;
use AMOS7::cell::canon::list qw| pack_body |;

@EXPORT_OK = qw| kind body kinds from_prior pack parse encode_token |;

my $DISK     = qr|[A-Z2-7]{7}|;
my $ADDRESS  = qr|V7[A-Z2-7]{5}/[A-Z2-7]{7}/[A-Z2-7]{77}|;
my $BMW      = qr|[A-Z2-7]{77}|;
my $NAME     = qr|[A-Za-z0-9][A-Za-z0-9_.-]{0,127}|;
my $RECORD   = qr|[0-9]{14}\.[A-Z2-7]{8}\.[A-Za-z0-9_.-]+|;
my $REF      = qr|[0-9]{14}/[A-Z2-7]{7}/[A-Z2-7]{77}/addr|;
my $COUNT    = qr{(?:0|[1-9][0-9]*)};
my $FORMAT   = qr|[a-z][a-z0-9-]*|;
my $B32_LIST = qr|[A-Z2-7]+|;

sub _refuse {
    my $message = shift;
    $message = sprintf $message, @ARG if @ARG;
    die "n7fs canon : $message\n";
}

sub _field {
    my ( $name, $type, %extra ) = @ARG;
    return { name => $name, type => $type, %extra };
}

sub _signed { return ( _field( 'pub', 'key' ), _field( 'sig', 'sig' ) ) }

sub _binding {
    return ( _field( 'rows', 'count' ), _field( 'body', 'address' ) );
}

sub _origin {
    return (
        _field(
            'origin-disk', 'word',
            old     => 'origin.disk',
            pattern => $DISK
        ),
        _field( 'origin-id', 'text', old => 'origin.id' ),
    );
}

sub _disk_field { return _field( 'disk', 'word', pattern => $DISK ) }
sub _ntime_field { return _field( 'ntime', 'stamp' ) }

my %KIND;
$KIND{'mount'} = {
    label  => 'p7 n7fs mount v4',
    fields => [
        _disk_field(),
        _field( 'mount', 'word', pattern => $DISK ),
        _field( 'event', 'word', words   => [qw| attach detach |] ),
        _ntime_field(),
        _field( 'mount-ntime', 'stamp', old => 'mount_ntime' ),
        _field( 'host-name',   'text',  old => 'host_name' ),
        _signed(),
    ],
};
$KIND{'use'} = {
    label  => 'p7 n7fs use v4',
    fields => [
        _disk_field(),
        ( map { _field( $ARG, 'stamp' ) } qw| first last written | ),
        _field( 'last-record', 'text', old => 'last_record' ),
        _field(
            'last-event', 'word',
            old   => 'last_event',
            words => [qw| attach detach |]
        ),
        _field( 'store-format', 'count', old => 'store_format' ),
        _field( 'journal-seq',  'count', old => 'journal_seq' ),
        _signed(),
    ],
};
$KIND{'state'} = {
    label  => 'p7 n7fs state v4',
    fields => [
        _field( 'store-format', 'count', old   => 'store_format' ),
        _field( 'grid',         'word',  words => [qw| float exact |] ),
        _field( 'written',      'stamp' ),
        _field( 'epochs',       'list', pattern => $COUNT ),
        _field(
            'sums-amos', 'word',
            old     => 'sums.amos',
            pattern => qr|[a-z0-9-]+|
        ),
        _field(
            'sums-bmw', 'word',
            old     => 'sums.bmw',
            pattern => qr|[a-z0-9-]+|
        ),
        _field( 'sums-l13',           'text',  old => 'sums.l13' ),
        _field( 'device-st-dev',      'count', old => 'device.st_dev' ),
        _field( 'device-mount-point', 'text',  old => 'device.mount_point' ),
        _field( 'device-fs-type',     'text',  old => 'device.fs_type' ),
        _field( 'device-source',      'text',  old => 'device.source' ),
        _field(
            'previous-store-format', 'count',
            old => 'previous.store_format'
        ),
        _field(
            'previous-epochs', 'list',
            old     => 'previous.epochs',
            pattern => $COUNT
        ),
        _field( 'flags', 'flags', words => [qw| confirmed converted |] ),
        _signed(),
    ],
};
$KIND{'meta'} = {
    label  => 'p7 n7fs meta v4',
    fields => [
        _disk_field(),
        _field( 'address',      'address', old => 'addr' ),
        _field( 'name',         'text' ),
        _field( 'format',       'word', pattern => qr|[a-z0-9]+| ),
        _field( 'size',         'count' ),
        _field( 'mtime',        'count' ),
        _field( 'import-ntime', 'stamp',   old => 'import_ntime' ),
        _field( 'epoch-num',    'decimal', old => 'epoch_num' ),
        _field( 'source',       'text' ),
        _field( 'host',         'text' ),
        _field( 'index-chksum', 'text', old => 'index_chksum' ),
        _field( 'index-name',   'text', old => 'index_name' ),
        _origin(),
        _field(
            'flags', 'flags',
            words => [qw| converted converted-from-unsigned |]
        ),
        _signed(),
    ],
};

my @REFERENCE = (
    _disk_field(),
    _field( 'address', 'address', old => 'addr' ),
    _field( 'holder',  'text' ),
    _field( 'name',    'text' ),
    _ntime_field(),
    _origin(),
    _field( 'flags', 'flags', words => [qw| converted |] ),
    _signed(),
);
$KIND{'reference'} = {
    label  => 'p7 n7fs reference v4',
    fields => [@REFERENCE]
};
$KIND{'drop'}      = { label => 'p7 n7fs drop v4', fields => [@REFERENCE] };
$KIND{'tombstone'} = {
    label  => 'p7 n7fs tombstone v4',
    fields => [
        _disk_field(),  _field( 'address', 'address', old => 'addr' ),
        _ntime_field(), _field( 'reason',  'text' ),
        _origin(),      _signed(),
    ],
};
$KIND{'tree_drop'} = {
    label  => 'p7 n7fs tree-drop v4',
    fields => [
        _disk_field(),
        _field( 'name', 'text' ),
        _field( 'tree', 'word', pattern => $RECORD ),
        _ntime_field(), _origin(), _signed(),
    ],
};
$KIND{'category'} = {
    label  => 'p7 n7fs category v4',
    fields => [
        _disk_field(),
        _field( 'name', 'word', pattern => $NAME ),
        _field(
            'local-encryption', 'word',
            old   => 'local_encryption',
            words => [qw| none cascade |]
        ),
        _field( 'copies',   'count' ),
        _field( 'priority', 'count' ),
        _field( 'replica',  'word', words   => [qw| full manifest |] ),
        _field( 'want',     'list', pattern => $NAME ),
        _field(
            'foreign-work', 'word',
            old   => 'foreign_work',
            words => [qw| no yes |]
        ),
        _field( 'layer', 'word', words => [qw| private generic |] ),
        _field( 'root',  'address' ),
        _ntime_field(),
        _origin(),
        _signed(),
    ],
};
$KIND{'assignment'} = {
    label  => 'p7 n7fs assignment v4',
    fields => [
        _disk_field(),
        _field( 'address',   'address', old     => 'node' ),
        _field( 'reference', 'word',    pattern => $REF ),
        _field( 'holder',    'text' ),
        _field( 'category',  'word', pattern => $NAME ),
        _ntime_field(),
        _origin(),
        _signed(),
    ],
};
$KIND{'sync_cursor'} = {
    label  => 'p7 n7fs sync-cursor v4',
    fields => [
        _disk_field(),
        _field( 'source',      'word',    pattern => $DISK ),
        _field( 'source-seq',  'count',   old     => 'source_seq' ),
        _field( 'source-hash', 'address', old     => 'source_hash' ),
        _ntime_field(),
        _origin(),
        _signed(),
    ],
};
$KIND{'sync_conflict'} = {
    label  => 'p7 n7fs sync-conflict v4',
    fields => [
        _disk_field(),
        _field( 'kind', 'word', words => [qw| tree assignment |] ),
        _origin(),
        _field( 'receiver',  'text' ),
        _field( 'source',    'text' ),
        _field( 'reference', 'word', pattern => $REF ),
        _ntime_field(),
        _signed(),
    ],
};
$KIND{'hold'} = {
    label  => 'p7 n7fs hold v4',
    fields => [
        _disk_field(),
        _field( 'seq',    'count' ),
        _field( 'reason', 'text' ),
        _field( 'source', 'text' ),
        _ntime_field(),
        _field( 'expires', 'stamp' ),
        _signed(),
    ],
};
$KIND{'journal'} = {
    label  => 'p7 n7fs journal v4',
    fields => [
        _disk_field(),
        _field( 'seq',   'count' ),
        _field( 'prev',  'address' ),
        _field( 'was',   'address' ),
        _field( 'flags', 'flags', words => [qw| baseline repaired |] ),
        _binding(),
        _signed(),
    ],
};
$KIND{'tree'} = {
    label  => 'p7 n7fs tree v4',
    fields => [
        _disk_field(),
        _field( 'name',     'text' ),
        _field( 'manifest', 'address' ),
        _field( 'created',  'stamp' ),
        _ntime_field(),
        _origin(),
        _field( 'was-manifest', 'address', old => 'was_manifest' ),
        _binding(),
        _signed(),
    ],
};
$KIND{'batch'} = {
    label  => 'p7 n7fs batch v4',
    fields => [
        _disk_field(),
        _field( 'category', 'word', pattern => $NAME ),
        _field( 'bytes',    'count' ),
        _ntime_field(),
        _origin(),
        _binding(),
        _signed(),
    ],
};
$KIND{'seal-root-binding'} = {
    label     => 'p7 n7fs seal root binding v2',
    signature => 'disk-root-binding',
    fields    => [
        _field( 'suite',   'count',   old => 'v' ),       _disk_field(),
        _field( 'root-id', 'address', old => 'root_id' ), _signed(),
    ],
};
$KIND{'receipt'} = {
    label  => 'p7 n7fs receipt v3',
    fields => [
        _field( 'holder',  'text' ),
        _field( 'root-id', 'address', old => 'root_id' ),
        ( map { _field( $ARG, 'count' ) } qw| time version nodes samples | ),
        _field( 'local-time',    'count', old   => 'local_time' ),
        _field( 'coverage',      'word',  words => [qw| full sampled |] ),
        _field( 'covered',       'address' ),
        _field( 'covered-nodes', 'count', old => 'covered_nodes' ),
        _signed(),
    ],
};
$KIND{'drill'} = {
    label  => 'p7 n7fs drill v2',
    fields => [
        _field( 'time',      'count' ),
        _field( 'holder',    'text' ),
        _field( 'holder-id', 'octets', old => 'holder_id', b32 => 1 ),
        _field( 'tree',      'text' ),
        _field( 'snapshot',  'text' ),
        ( map { _field( $ARG, 'count' ) } qw| files bytes took | ),
        _field( 'head-version', 'count', old => 'head_version' ),
        _field(
            'mode', 'word',
            words => [qw| full attended sampled offline |]
        ),
        _field( 'result',    'word',  words => [qw| passed failed |] ),
        _field( 'max-bytes', 'count', old   => 'max_bytes' ),
        _field( 'error',     'text' ),
        _field( 'root-id',   'address', old => 'root_id' ),
        _signed(),
    ],
};
$KIND{'sealed-journal'} = {
    label  => 'p7 n7fs sealed journal v2',
    fields => [
        _field( 'writer',  'octets', b32 => 1 ),
        _field( 'version', 'count' ),
        _field( 'map',     'address' ),
        _field(
            'operation',
            'word',
            words =>
                [qw| seal repack gc_superseded unmap retention relay shred |]
        ),
        _field(
            'addresses', 'list',
            old     => 'addresses',
            pattern => $ADDRESS
        ),
        _field( 'name',   'text' ),
        _field( 'action', 'word', words   => [qw| set clear pin unpin |] ),
        _field( 'disk',   'word', pattern => $DISK ),
        _field(
            'merge-disks', 'list',
            old     => 'merge_disks',
            pattern => $ADDRESS
        ),
    ],
};
$KIND{'reservation'} = {
    label  => 'p7 n7fs reservation v2',
    fields => [
        _field( 'root-id', 'address', old => 'root_id' ),
        _field( 'writer',  'octets',  b32 => 1 ),
        _field( 'version', 'count' ),
    ],
};
$KIND{'pending-key'} = {
    label  => 'p7 n7fs pending key v2',
    fields => [
        _field( 'node-id', 'octets', old => 'node_id', b32 => 1 ),
        _field( 'wrap',    'octets', b32 => 1 ),
    ],
};
$KIND{'request-counter'} = {
    label  => 'p7 n7fs request counter v2',
    fields => [
        _field( 'root-id', 'address', old => 'root_id' ),
        _field( 'holder',  'address' ),
        _field( 'counter', 'count' ),
    ],
};
$KIND{'switch'} = {
    label  => 'p7 n7fs switch v4',
    fields => [
        _disk_field(),
        _field( 'from',      'count' ),
        _field( 'to',        'count' ),
        _field( 'direction', 'word', words => [qw| forward back |] ),
        _binding(),
        _signed(),
    ],
};

sub _descriptor {
    my ( $prefix, $old ) = @ARG;
    return (
        _field( "$prefix-blob",     'address', old => "$old.blob" ),
        _field( "$prefix-checksum", 'address', old => "$old.checksum" ),
        _field( "$prefix-id",      'octets', old => "$old.id",     b32 => 1 ),
        _field( "$prefix-writer",  'octets', old => "$old.writer", b32 => 1 ),
        _field( "$prefix-version", 'count',  old => "$old.version" ),
        _field( "$prefix-size",    'count',  old => "$old.size" ),
    );
}

$KIND{'sealed-head'} = {
    label  => 'p7 n7fs sealed head v3',
    fields => [
        _field( 'format',  'word',    pattern => qr|n7fs-head-v[0-9]+| ),
        _field( 'root-id', 'address', old     => 'root_id' ),
        _field( 'writer',  'octets',  b32     => 1 ),
        _field( 'version', 'count' ),
        _field( 'time',    'count' ),
        _field( 'holder',  'octets', b32 => 1 ),
        _descriptor( 'map', 'map' ),
        _field( 'journal', 'address' ),
        _descriptor( 'registry', 'registry' ),
        _binding(),
        _signed(),
    ],
};
$KIND{'map-root'} = {
    label  => 'p7 n7fs sealed map v2',
    fields => [
        _field( 'format',  'word', pattern => qr|n7fs-sharded-map-v[0-9]+| ),
        _field( 'depth',   'count' ),
        _field( 'root-id', 'address', old => 'root_id' ),
        _descriptor( 'tree-blob', 'tree_blob' ),
        _binding(),
    ],
};
$KIND{'map-shard'} = {
    label  => 'p7 n7fs sealed map shard v2',
    fields => [ _binding() ],
};
$KIND{'map-tree-blob'} = {
    label  => 'p7 n7fs sealed map trees v2',
    fields => [ _binding() ],
};
$KIND{'manifest'} = {
    label  => 'p7 n7fs manifest v2',
    fields => [
        _field( 'manifest', 'count' ),
        _field( 'root',     'text', old => 'root_b32', b32 => 1 ),
        _field( 'created',  'stamp' ),
        _field( 'snapshot', 'text' ),
    ],
};
$KIND{'manifest-index'} = {
    label  => 'p7 n7fs sealed manifest index v2',
    fields => [
        _field(
            'format', 'word',
            pattern => qr|n7fs-chunked-manifest-v[0-9]+|
        ),
        _field( 'root',     'text',  old => 'header.root_b32', b32 => 1 ),
        _field( 'created',  'stamp', old => 'header.created' ),
        _field( 'snapshot', 'text',  old => 'header.snapshot' ),
        _binding(),
    ],
};
$KIND{'manifest-chunk'} = {
    label  => 'p7 n7fs sealed manifest chunk v2',
    fields => [
        _field( 'lines',     'word', words => [qw| canon2 json3 |] ),
        _field( 'path',      'text' ),
        _field( 'part',      'count' ),
        _field( 'positions', 'list', pattern => $COUNT ),
        _binding(),
    ],
};
$KIND{'covered-cache'} = {
    label  => 'p7 n7fs covered cache v2',
    fields => [
        _field( 'version', 'count' ),
        _field( 'digest',  'address' ),
        _binding(),
    ],
};
$KIND{'seal-state'} = {
    label  => 'p7 n7fs seal state v2',
    fields => [
        _field( 'writer',    'octets', b32 => 1 ),
        _field( 'version',   'count' ),
        _field( 'last-time', 'count', old => 'last_time' ),
        _binding(),
    ],
};
$KIND{'relay-pending'} = {
    label  => 'p7 n7fs relay pending v2',
    fields => [
        _field( 'holder', 'text' ), _field( 'time', 'count' ), _binding(),
    ],
};
$KIND{'relay-list'} = {
    label  => 'p7 n7fs relay list v2',
    fields => [ _field( 'subdir', 'text' ), _binding() ],
};
$KIND{'holder-request'} = {
    label  => 'p7 n7fs holder request v2',
    fields => [
        _field(
            'op',
            'word',
            words => [qw| put-head put-list move migrate purge-day delete |]
        ),
        _field( 'root-id', 'address', old => 'root_id' ),
        _field( 'holder',  'address' ),
        _field( 'counter', 'count' ),
        _field( 'nonce',   'octets',  b32 => 1 ),
        _field( 'path',    'text',    old => 'args.path' ),
        _field( 'size',    'count',   old => 'args.size' ),
        _field( 'digest',  'address', old => 'args.digest' ),
        _field( 'version', 'count',   old => 'args.version' ),
        _field( 'writer',  'octets',  old => 'args.writer', b32 => 1 ),
        _field( 'from',    'text',    old => 'args.from' ),
        _field( 'to',      'text',    old => 'args.to' ),
        _field( 'name',    'text',    old => 'args.name' ),
        _field( 'tag',     'text',    old => 'args.tag' ),
        _signed(),
    ],
};

my $REFERENCE_BODY = {
    shape   => 'table',
    columns => [
        _field( 'address', 'address', old => 'node' ),
        _field( 'path',    'text' ),
    ],
};
my $ADDRESS_BODY = {
    shape   => 'table',
    columns => [ _field( 'address', 'address' ) ],
};
my $BLOB_BODY = {
    shape   => 'table',
    columns => [ _field( 'blob', 'address', old => 'blob' ) ],
};

my $JOURNAL_BODY = {
    shape   => 'operations',
    classes => [
        {   name   => '+ node',
            fields => [ _field( 'address', 'address' ) ],
        },
        {   name   => '- node',
            fields => [ _field( 'address', 'address' ) ],
        },
        {   name   => '- release',
            fields => [ _field( 'address', 'address' ) ],
        },
        {   name   => '+ meta',
            fields => [
                _field( 'address', 'address', old => 'node' ),
                _field(
                    'name', 'word',
                    pattern => qr|[0-9]{14}\.[A-Z2-7]{8}\.meta|
                ),
            ],
        },
        {   name   => '- meta',
            fields => [
                _field( 'address', 'address', old => 'node' ),
                _field(
                    'name', 'word',
                    pattern => qr|[0-9]{14}\.[A-Z2-7]{8}\.meta|
                ),
            ],
        },
        {   name   => '+ reference',
            fields => [
                _field( 'address', 'address', old => 'node' ),
                _field( 'path',    'text' ),
                _field( 'holder',  'text' ),
                _field( 'name',    'text' ),
                _origin(),
            ],
        },
        {   name   => '- reference',
            fields => [
                _field( 'address', 'address', old => 'node' ),
                _field( 'path',    'text' ),
                _field( 'holder',  'text' ),
                _field( 'name',    'text' ),
                _origin(),
            ],
        },
        {   name   => '+ tree',
            fields => [
                _field( 'name',       'text' ),
                _field( 'path',       'text' ),
                _field( 'manifest',   'address' ),
                _field( 'created',    'stamp' ),
                _field( 'references', 'pairs', pattern => $ADDRESS ),
                _origin(),
            ],
        },
        {   name   => '- tree',
            fields => [
                _field( 'name', 'text' ),
                _field( 'path', 'text' ),
                _field( 'tree', 'text' ),
                _origin(),
            ],
        },
        {   name   => '+ category',
            fields => [
                _field( 'name', 'text' ),
                _field( 'path', 'text' ),
                _origin()
            ],
        },
        {   name   => '+ assignment',
            fields => [
                _field( 'address',   'address', old => 'node' ),
                _field( 'reference', 'text' ),
                _field( 'path',      'text' ),
                _field( 'category',  'text' ),
                _origin(),
            ],
        },
        {   name   => '+ batch',
            fields => [
                _field( 'path',     'text' ),
                _field( 'category', 'text' ),
                _origin(),
            ],
        },
        {   name   => '- sync-release',
            fields => [
                _field( 'address', 'address', old => 'node' ),
                _origin(),
                _field( 'references', 'pairs', pattern => $ADDRESS ),
            ],
        },
        {   name   => '+ sync-cursor',
            fields => [
                _field( 'source',      'word',    pattern => $DISK ),
                _field( 'source-seq',  'count',   old     => 'source_seq' ),
                _field( 'source-hash', 'address', old     => 'source_hash' ),
                _field( 'path',        'text' ),
                _origin(),
            ],
        },
        {   name   => '+ conflict',
            fields => [ _field( 'path', 'text' ), _origin() ],
        },
        {   name   => '- conflict',
            fields => [ _field( 'path', 'text' ), _origin() ],
        },
        {   name   => '+ hold',
            fields => [
                _field( 'path',    'text' ),
                _field( 'seq',     'count' ),
                _field( 'reason',  'text' ),
                _field( 'source',  'text' ),
                _field( 'ntime',   'stamp' ),
                _field( 'expires', 'stamp' ),
            ],
        },
        {   name   => '- hold',
            fields => [ _field( 'path', 'text' ) ],
        },
    ],
};

my $PEER_BODY = {
    shape   => 'table',
    columns => [
        _field( 'holder',          'text' ),
        _field( 'version',         'count', old => 'v' ),
        _field( 'time',            'count', old => 't' ),
        _field( 'receipt-version', 'count', old => 'r.v' ),
        _field( 'receipt-time',    'count', old => 'r.t' ),
        _field(
            'receipt-coverage', 'word',
            old   => 'r.c',
            words => [qw| full sampled |]
        ),
        _field( 'receipt-nodes', 'count', old => 'r.n' ),
        _field( 'drill-time',    'count', old => 'd.t' ),
        _field( 'drill-tree',    'text',  old => 'd.tr' ),
        _field( 'drill-files',   'count', old => 'd.f' ),
        _field( 'drill-bytes',   'count', old => 'd.b' ),
    ],
};

sub _tree_columns {
    return (
        _field( 'name',     'text' ),
        _field( 'manifest', 'address' ),
        _field( 'created',  'stamp' ),
        _field( 'files',    'count' ),
        _field( 'held',     'count' ),
        _field( 'state',    'word', words   => [qw| complete partial |] ),
        _field( 'disks',    'list', pattern => $DISK ),
        _descriptor( 'index', 'index' ),
    );
}

my $MAP_ROOT_BODY = {
    shape   => 'operations',
    classes => [
        {   name   => 'category',
            fields => [
                _field( 'name', 'text' ),
                _field( 'id',   'octets', b32 => 1 ),
                _field( 'wrap', 'octets', b32 => 1 ),
            ],
        },
        {   name   => 'retention',
            fields => [ _field( 'name', 'text' ), _field( 'rule', 'text' ) ],
        },
        { name => 'pin', fields => [ _field( 'name', 'text' ) ] },
        {   name   => 'superseded',
            fields => [
                _field( 'blob', 'address' ), _field( 'version', 'count' ),
            ],
        },
        {   name   => 'shard',
            fields => [
                _field( 'name', 'word', pattern => qr|[A-Z2-7]{2}| ),
                _descriptor( 'descriptor', 'descriptor' ),
            ],
        },
        { name => 'tree', fields => [ _tree_columns() ] },
    ],
};

my $SHARD_BODY = {
    shape   => 'table',
    columns => [
        _field( 'address',  'address' ),
        _field( 'id',       'octets', b32 => 1 ),
        _field( 'blob',     'address' ),
        _field( 'node',     'address' ),
        _field( 'offset',   'count' ),
        _field( 'length',   'count' ),
        _field( 'chunks',   'count' ),
        _field( 'category', 'word',  pattern => $NAME ),
        _field( 'disks',    'list',  pattern => $DISK ),
        _field( 'wraps',    'pairs', pattern => $NAME ),
        _field( 'added',    'count' ),
        _field(
            'layout-mode', 'word',
            old   => 'layout.mode',
            words => [qw| complete |]
        ),
        _field( 'layout-chunk-size',  'count', old => 'layout.chunk_size' ),
        _field( 'layout-header-size', 'count', old => 'layout.header_size' ),
    ],
};
my $MAP_TREE_BODY = { shape => 'table', columns => [ _tree_columns() ] };
my $MANIFEST_BODY = {
    shape   => 'table',
    columns => [
        _field( 'path', 'text', old => 'p', b32 => 1 ),
        _field(
            'type', 'word',
            old   => 't',
            words => [qw| file dir symlink hardlink skipped |]
        ),
        _field( 'mode',     'count' ),
        _field( 'uid',      'count' ),
        _field( 'gid',      'count' ),
        _field( 'mtime',    'count' ),
        _field( 'mtime-ns', 'count', old => 'mtime_ns' ),
        _field( 'size',     'count' ),
        _field( 'address',  'address', old => 'a' ),
        _field( 'link',     'text' ),
        _field( 'user',     'text',  old     => 'user_b32',  b32 => 1 ),
        _field( 'group',    'text',  old     => 'group_b32', b32 => 1 ),
        _field( 'xattrs',   'pairs', pattern => qr|[A-Z2-7!]+| ),
        _field( 'why',      'text' ),
    ],
};
my $INDEX_BODY = {
    shape   => 'table',
    columns => [
        _field( 'chunk',     'text' ),
        _field( 'path',      'text' ),
        _field( 'part',      'count' ),
        _field( 'positions', 'list', pattern => $COUNT ),
        _descriptor( 'descriptor', 'descriptor' ),
    ],
};
my $STATE_BODY = {
    shape   => 'table',
    columns => [
        _field( 'holder',          'octets', b32 => 1 ),
        _field( 'spec',            'text' ),
        _field( 'version',         'count' ),
        _field( 'time',            'count' ),
        _field( 'receipt-version', 'count', old => 'receipt.v' ),
        _field( 'receipt-time',    'count', old => 'receipt.t' ),
        _field(
            'receipt-coverage', 'word',
            old   => 'receipt.c',
            words => [qw| full sampled |]
        ),
        _field( 'receipt-nodes', 'count', old => 'receipt.n' ),
    ],
};

my %BODY = (
    journal          => $JOURNAL_BODY,
    tree             => $REFERENCE_BODY,
    batch            => $REFERENCE_BODY,
    'sealed-head'    => $PEER_BODY,
    'map-root'       => $MAP_ROOT_BODY,
    'map-shard'      => $SHARD_BODY,
    'map-tree-blob'  => $MAP_TREE_BODY,
    manifest         => $MANIFEST_BODY,
    'manifest-index' => $INDEX_BODY,
    'covered-cache'  => $ADDRESS_BODY,
    'seal-state'     => $STATE_BODY,
    'relay-pending'  => $BLOB_BODY,
    'relay-list'     => $BLOB_BODY,
);

sub kind {
    my $name = shift // '';
    _refuse( 'unknown record kind [ %s ]', $name ) if not exists $KIND{$name};
    return $KIND{$name};
}

sub body {
    my $name = shift // '';
    _refuse( 'record kind has no body table [ %s ]', $name )
        if not exists $BODY{$name};
    return $BODY{$name};
}

sub kinds { return sort keys %KIND }

sub _only {
    my ( $kind, $payload, @allowed ) = @ARG;
    _refuse( '%s prior payload is not an object', $kind )
        if ref $payload ne q|HASH|;
    my %allowed = map { $ARG => 1 } @allowed;
    for my $key ( keys %{$payload} ) {
        _refuse( '%s prior payload has unknown key [ %s ]', $kind, $key )
            if not $allowed{$key};
    }
    return;
}

sub _old {
    my ( $payload, $path ) = @ARG;
    my $value = $payload;
    for my $part ( split m|[.]|, $path ) {
        return undef if ref $value ne q|HASH|;
        $value = $value->{$part};
    }
    return $value;
}

sub _bytes {
    my ( $kind, $name, $value ) = @ARG;
    _refuse( '%s field %s is not a scalar string', $kind, $name )
        if ref $value;
    return undef if not defined $value;
    my $bytes = "$value";
    if ( utf8::is_utf8($bytes) ) {
        _refuse( '%s field %s has characters above 255', $kind, $name )
            if $bytes =~ m|[^\x00-\xff]|;
        utf8::encode($bytes);
    }
    return $bytes;
}

sub _count {
    my ( $kind, $name, $value ) = @ARG;
    _refuse( '%s field %s is not a count', $kind, $name ) if ref $value;
    my $text = "$value";
    _refuse( '%s field %s is not a canonical count [ %s ]',
        $kind, $name, $text )
        if $text !~ m{\A(?:0|[1-9][0-9]*)\z};
    my $flags = B::svref_2object( \$value )->FLAGS;
    _refuse( '%s field %s is a float, not a count', $kind, $name )
        if $flags & B::SVp_NOK();
    return $text;
}

sub _b32 {
    my ( $kind, $name, $value ) = @ARG;
    my $encoded = _bytes( $kind, $name, $value );
    return undef if not defined $encoded;
    _refuse( '%s field %s is not base32', $kind, $name )
        if $encoded !~ m|\A[A-Z2-7]+\z|;
    my $decoded = decode_b32r($encoded);
    _refuse( '%s field %s has noncanonical base32', $kind, $name )
        if not defined $decoded
        or encode_b32r($decoded) ne $encoded;
    return $decoded;
}

sub _value {
    my ( $kind, $field, $value ) = @ARG;
    my $name = $field->{'name'};
    my $type = $field->{'type'};
    return '0'   if not defined $value and $type =~ m{\A(?:count|address)\z};
    return undef if not defined $value;
    return _b32( $kind, $name, $value )   if $field->{'b32'};
    return _count( $kind, $name, $value ) if $type eq q|count|;
    if ( $type eq q|list| or $type eq q|flags| or $type eq q|pairs| ) {
        _refuse( '%s field %s is not a list', $kind, $name )
            if ref $value ne q|ARRAY|;
        return undef if not @{$value};
        return [ map { _bytes( $kind, $name, $ARG ) } @{$value} ];
    }
    my $text = _bytes( $kind, $name, $value );
    if ( $type eq q|stamp| ) {
        _refuse( '%s field %s is not a 14 digit stamp', $kind, $name )
            if $text !~ m|\A[0-9]{14}\z|;
    } elsif ( $type eq q|decimal| ) {
        _refuse( '%s field %s is not canonical decimal text [ %s ]',
            $kind, $name, $text )
            if $text !~ m{\A(?:0|[1-9][0-9]*)[.][0-9]+\z};
    }
    return $text;
}

my %FLAGS = (
    state => { confirmed => 'confirmed', converted => 'converted' },
    meta  => {
        converted                 => 'converted',
        'converted-from-unsigned' => 'converted_from_unsigned',
    },
    reference => { converted => 'converted' },
    drop      => { converted => 'converted' },
    journal   => { baseline  => 'baseline', repaired => 'repaired' },
);

sub _allowed {
    my ( $kind, @extra ) = @ARG;
    my %allowed = map { $ARG => 1 } @extra;
    for my $field ( $KIND{$kind}{'fields'}->@* ) {
        my $old = $field->{'old'} // do {
            my $name = $field->{'name'} =~ s|-|_|gr;
            $name;
        };
        $allowed{ ( split m|[.]|, $old )[0] } = 1;
    }
    $allowed{$ARG} = 1 for values %{ $FLAGS{$kind} // {} };
    delete @allowed{qw| was was_manifest grid |};
    return sort keys %allowed;
}

sub _flat {
    my ( $kind, $payload, %extra ) = @ARG;
    my $skip_only = delete $extra{'_skip_only'};
    _only( $kind, $payload, _allowed( $kind, keys %extra ) )
        if not $skip_only;
    my %head;
    for my $field ( $KIND{$kind}{'fields'}->@* ) {
        my $name = $field->{'name'};
        next if $name =~ m{\A(?:pub|sig|rows|body|flags)\z};
        next if exists $extra{$name};
        my $old = $field->{'old'} // do {
            my $path = $name =~ s|-|_|gr;
            $path;
        };
        $head{$name} = _value( $kind, $field, _old( $payload, $old ) );
    }
    my @flags;
    for my $flag ( sort keys %{ $FLAGS{$kind} // {} } ) {
        push @flags, $flag if _old( $payload, $FLAGS{$kind}{$flag} );
    }
    $head{'flags'} = @flags ? \@flags : undef
        if grep { $ARG->{'name'} eq q|flags| } $KIND{$kind}{'fields'}->@*;
    $head{$ARG} = $extra{$ARG} for keys %extra;
    return \%head;
}

sub _row_old {
    my ( $kind, $fields, $old, $class ) = @ARG;
    _refuse( '%s prior row is not an object', $kind ) if ref $old ne q|HASH|;
    my @row = defined $class ? ($class) : ();
    for my $field ( @{$fields} ) {
        my $path = $field->{'old'} // do {
            my $name = $field->{'name'} =~ s|-|_|gr;
            $name;
        };
        push @row, _value( $kind, $field, _old( $old, $path ) );
    }
    return \@row;
}

sub _signed_values {
    my ( $head, $record ) = @ARG;
    $head->{'pub'} = $record->{'signer_pub'}
        if defined $record->{'signer_pub'};
    $head->{'sig'} = $record->{'sig'} if defined $record->{'sig'};
    return $head;
}

sub _journal {
    my $record = shift;
    my $p      = $record->{'payload'};
    _only( q|journal|, $p, qw| disk seq prev add drop baseline repaired | );
    my $head = _flat( q|journal|, $p, was => '0', _skip_only => 1 );
    my @rows;
    my %class = (
        nodes        => 'node',
        meta         => 'meta',
        references   => 'reference',
        trees        => 'tree',
        categories   => 'category',
        assignments  => 'assignment',
        batches      => 'batch',
        sync_cursors => 'sync-cursor',
        conflicts    => 'conflict',
        holds        => 'hold',
    );
    my %field = map { $ARG->{'name'} => $ARG }
        map { $ARG->{'fields'}->@* } $JOURNAL_BODY->{'classes'}->@*;
    for my $which (qw| add drop |) {
        _refuse( 'journal %s is not an object', $which )
            if ref $p->{$which} ne q|HASH|;
        for my $part ( keys %{ $p->{$which} } ) {
            _refuse( 'journal has unknown operation list [ %s %s ]',
                $which, $part )
                if not exists $class{$part}
                and $part ne q|releases|
                and $part ne q|sync_releases|;
            my $items = $p->{$which}{$part};
            _refuse( 'journal %s %s is not a list', $which, $part )
                if ref $items ne q|ARRAY|;
            if ( $part eq q|releases| ) {
                _refuse('journal add releases is not a class')
                    if $which eq q|add|;
                push @rows,
                    [
                    '- release',
                    _value(
                        q|journal|, _field( 'address', 'address' ), $ARG
                    )
                    ]
                    for @{$items};
                next;
            }
            if ( $part eq q|sync_releases| ) {
                _refuse('journal add sync_releases is not a class')
                    if $which eq q|add|;
                for my $item ( @{$items} ) {
                    my %copy = %{$item};
                    my $refs = delete $copy{'references'};
                    my $row
                        = _row_old( q|journal|,
                        _class_fields('- sync-release'),
                        \%copy, '- sync-release' );
                    _refuse(  'journal retained release '
                            . 'references are not a list' )
                        if ref $refs ne q|ARRAY|;
                    $row->[-1] = [ sort map {"$ARG->{'node'}:$ARG->{'path'}"}
                            @{$refs} ];
                    push @rows, $row;
                }
                next;
            }
            my $class = ( $which eq q|add| ? '+ ' : '- ' ) . $class{$part};
            for my $item ( @{$items} ) {
                if ( $part eq q|nodes| ) {
                    push @rows,
                        [
                        $class,
                        _value(
                            q|journal|, _field( 'address', 'address' ),
                            $item
                        )
                        ];
                } else {
                    my %copy = %{$item};
                    if ( $class eq q|+ tree| ) {
                        my $refs = $copy{'references'} // [];
                        _refuse('journal tree references are not a list')
                            if ref $refs ne q|ARRAY|;
                        $copy{'references'}
                            = [ sort map {"$ARG->{'node'}:$ARG->{'path'}"}
                                @{$refs} ];
                    }
                    push @rows,
                        _row_old( q|journal|, _class_fields($class), \%copy,
                        $class );
                }
            }
        }
    }
    return { head => $head, rows => \@rows };
}

sub _class_fields {
    my $wanted = shift;
    my ($class)
        = grep { $ARG->{'name'} eq $wanted } $JOURNAL_BODY->{'classes'}->@*;
    _refuse( 'unknown journal operation class [ %s ]', $wanted )
        if not defined $class;
    return $class->{'fields'};
}

sub _references {
    my ( $kind, $payload ) = @ARG;
    my $refs = $payload->{'references'};
    _refuse( '%s references are not a list', $kind ) if ref $refs ne q|ARRAY|;
    return [
        sort { $a->[0] cmp $b->[0] or $a->[1] cmp $b->[1] }
        map {
            my %old = %{$ARG};
            $old{'path'} = delete $old{'reference'} if $kind eq q|batch|;
            _row_old( $kind, $REFERENCE_BODY->{'columns'}, \%old );
        } @{$refs}
    ];
}

sub _manifest {
    my $record = shift;
    my $p      = $record->{'payload'};
    _only( q|manifest|, $p, qw| header entries | );
    my $head_old = $p->{'header'};
    _only( q|manifest header|,
        $head_old, qw| manifest root_b32 created snapshot | );
    my $head = {
        manifest =>
            _count( q|manifest|, q|manifest|, $head_old->{'manifest'} ),
        root     => _b32( q|manifest|, q|root|, $head_old->{'root_b32'} ),
        created  => $head_old->{'created'},
        snapshot => $head_old->{'snapshot'},
    };
    my @rows;
    for my $old ( $p->{'entries'}->@* ) {
        _only(
            q|manifest entry|, $old,
            qw| p t mode uid gid mtime mtime_ns size a l h user_b32 group_b32
                xattrs xattr_errors why |
        );
        my $link = defined $old->{'l'} ? $old->{'l'} : $old->{'h'};
        $link = _b32( q|manifest|, q|link|, $link ) if defined $link;
        my @attrs;
        if ( defined $old->{'xattrs'} ) {
            _refuse('manifest xattrs are not an object')
                if ref $old->{'xattrs'} ne q|HASH|;
            for my $name ( keys %{ $old->{'xattrs'} } ) {
                _b32( q|manifest|, q|xattr name|,  $name );
                _b32( q|manifest|, q|xattr value|, $old->{'xattrs'}{$name} );
                push @attrs, "$name:$old->{'xattrs'}{$name}";
            }
        }
        for my $error ( @{ $old->{'xattr_errors'} // [] } ) {
            _refuse('manifest xattr error is not an object')
                if ref $error ne q|HASH|;
            my $name = $error->{'name_b32'} // '';
            my $why  = $error->{'why'}      // '';
            push @attrs, '!' . $name . ':' . encode_b32r($why);
        }
        @attrs = sort @attrs;
        my %copy = ( %{$old}, link => $link, xattrs => \@attrs );
        $copy{'mtime_ns'} //= 0;
        push @rows,
            _row_old( q|manifest|, $MANIFEST_BODY->{'columns'}, \%copy );
    }
    return { head => $head, rows => \@rows };
}

sub _peers {
    my $peers = shift // {};
    _refuse('sealed head peers are not an object') if ref $peers ne q|HASH|;
    my @rows;
    for my $holder ( keys %{$peers} ) {
        my $old  = $peers->{$holder};
        my %copy = ( %{$old}, holder => $holder );
        push @rows,
            _row_old( q|sealed-head|, $PEER_BODY->{'columns'}, \%copy );
    }
    return \@rows;
}

sub _map_trees {
    my ( $kind, $trees ) = @_;
    _refuse( '%s trees are not an object', $kind ) if ref $trees ne q|HASH|;
    my @rows;
    for my $name ( keys %{$trees} ) {
        my $old = $trees->{$name};
        _refuse( '%s tree is not an object', $kind ) if ref $old ne q|HASH|;
        my %copy = ( %{$old}, name => $name );
        $copy{'disks'} = [ sort keys %{ $old->{'disks'} // {} } ];
        for my $field ( _tree_columns() ) {
            my $path  = $field->{'old'} // $field->{'name'};
            my $value = _old( \%copy, $path );
            $copy{'index'} //= {};
        }
        push @rows, _row_old( $kind, $MAP_TREE_BODY->{'columns'}, \%copy );
    }
    return \@rows;
}

sub _map_root {
    my $record = shift;
    my $p      = $record->{'payload'};
    _only(
        q|map-root|, $p,
        qw| format depth root_id categories retention pins superseded shards
            tree_blob trees |
    );
    my $head = _flat( q|map-root|, $p, _skip_only => 1 );
    my @rows;
    for my $name ( keys %{ $p->{'categories'} // {} } ) {
        my $old = $p->{'categories'}{$name};
        push @rows,
            _row_old(
            q|map-root|,
            _class_fields_map('category'),
            { %{$old}, name => $name }, 'category'
            );
    }
    for my $name ( keys %{ $p->{'retention'} // {} } ) {
        push @rows, [ 'retention', $name, $p->{'retention'}{$name} ];
    }
    push @rows, [ 'pin', $ARG ] for sort keys %{ $p->{'pins'} // {} };
    for my $blob ( keys %{ $p->{'superseded'} // {} } ) {
        push @rows, [ 'superseded', $blob, $p->{'superseded'}{$blob} ];
    }
    for my $name ( keys %{ $p->{'shards'} // {} } ) {
        push @rows,
            _row_old(
            q|map-root|,
            _class_fields_map('shard'),
            { name => $name, descriptor => $p->{'shards'}{$name} }, 'shard'
            );
    }
    push @rows,
        map { [ 'tree', @{$ARG} ] }
        @{ _map_trees( q|map-root|, $p->{'trees'} ) };
    return { head => $head, rows => \@rows };
}

sub _class_fields_map {
    my $wanted = shift;
    my ($class)
        = grep { $ARG->{'name'} eq $wanted } $MAP_ROOT_BODY->{'classes'}->@*;
    return $class->{'fields'};
}

sub _map_shard {
    my $record = shift;
    my $p      = $record->{'payload'};
    _refuse('map-shard payload is not an object') if ref $p ne q|HASH|;
    my @rows;
    for my $address ( keys %{$p} ) {
        my $old = $p->{$address};
        _refuse('map-shard entry is not an object') if ref $old ne q|HASH|;
        my %copy = ( %{$old}, address => $address );
        $copy{'disks'} = [ sort keys %{ $old->{'disks'} // {} } ];
        $copy{'wraps'} = [
            sort map {"$ARG:$old->{'wraps'}{$ARG}"}
                keys %{ $old->{'wraps'} // {} }
        ];
        push @rows,
            _row_old( q|map-shard|, $SHARD_BODY->{'columns'}, \%copy );
    }
    return { head => { rows => 0, body => '0' }, rows => \@rows };
}

sub _sealed_journal {
    my $record = shift;
    my $p      = $record->{'payload'};
    my $old    = $p->{'operation'};
    _refuse('sealed journal operation is not an object')
        if ref $old ne q|HASH|;
    my %known = map { $ARG => 1 }
        qw| seal repack gc_superseded unmap retention relay shred |;
    my @operation = grep { $known{$ARG} } keys %{$old};
    _refuse('sealed journal has no known operation') if @operation != 1;
    my $operation = $operation[0];
    _only( q|sealed-journal|, $p, qw| writer version map operation | );
    _only(
        q|sealed-journal operation|,
        $old,
        $operation,
        $operation eq q|retention| ? qw| name |        : (),
        $operation eq q|unmap|     ? qw| untag |       : (),
        $operation eq q|relay|     ? qw| merge_disks | : ()
    );
    my %copy = ( %{$p}, %{$old}, operation => $operation );
    $copy{'addresses'} = $old->{$operation}
        if $operation ne q|retention|;
    $copy{'addresses'} = [ $old->{'shred'} ]    if $operation eq q|shred|;
    $copy{'action'} = delete $copy{'retention'} if $operation eq q|retention|;
    $copy{'name'}   = $old->{'name'}            if $operation eq q|retention|;

    if ( $operation eq q|unmap| and defined $old->{'untag'} ) {
        _refuse('sealed journal untag is not an object')
            if ref $old->{'untag'} ne q|HASH|
            or keys %{ $old->{'untag'} } != 1;
        my ($disk) = keys %{ $old->{'untag'} };
        $copy{'disk'}      = $disk;
        $copy{'addresses'} = $old->{'untag'}{$disk};
    }
    my $head = _flat( q|sealed-journal|, \%copy, _skip_only => 1 );
    return { head => $head };
}

sub _request {
    my $record = shift;
    my $p      = $record->{'payload'};
    _only( q|holder-request|, $p,
        qw| op root_id holder counter nonce args | );
    my $args      = $p->{'args'};
    my %arguments = (
        'put-head'  => [qw| path size digest version writer |],
        'put-list'  => [qw| path size digest |],
        'move'      => [qw| from to |],
        'migrate'   => [qw| name tag |],
        'purge-day' => [qw| path |],
        'delete'    => [qw| path |],
    );
    my $allowed = $arguments{ $p->{'op'} // '' }
        // _refuse( 'holder-request has unknown operation [ %s ]',
        $p->{'op'} );
    _only( q|holder-request arguments|, $args, @{$allowed} );
    return { head => _flat( q|holder-request|, $p ) };
}

sub from_prior {
    my ( $kind, $record, %opt ) = @ARG;
    if ( $kind eq q|root-file| ) {
        return {
            head => {
                kdf  => $record->{'payload'}{'kdf'},
                t    => _count( $kind, 't', $record->{'payload'}{'t'} ),
                m    => _count( $kind, 'm', $record->{'payload'}{'m'} ),
                p    => _count( $kind, 'p', $record->{'payload'}{'p'} ),
                salt => $record->{'salt'},
            },
            secret => $record->{'secret'},
        };
    }
    return { head => $record->{'payload'} } if $kind eq q|vault-registry|;
    return { head => $record->{'payload'} } if $kind eq q|id|;
    _refuse( 'unknown record kind [ %s ]', $kind ) if not exists $KIND{$kind};
    _refuse( '%s prior record is not a hash', $kind )
        if ref $record ne q|HASH|
        or ref $record->{'payload'} ne q|HASH| and $kind ne q|manifest-chunk|;
    my $meaning;
    if ( $kind eq q|journal| ) {
        $meaning = _journal($record);
    } elsif ( $kind eq q|meta| ) {
        my %copy = %{ $record->{'payload'} };
        _only( q|meta|, \%copy, _allowed( q|meta|, qw| epoch amos bmw | ) );
        $copy{'addr'} = join '/', @copy{qw| epoch amos bmw |};
        $meaning      = { head => _flat( q|meta|, \%copy, _skip_only => 1 ) };
    } elsif ( $kind eq q|tree| or $kind eq q|batch| ) {
        my $p    = $record->{'payload'};
        my $rows = _references( $kind, $p );
        my %copy = %{$p};
        delete $copy{'references'};
        $meaning = { head => _flat( $kind, \%copy ), rows => $rows };
    } elsif ( $kind eq q|manifest| ) {
        $meaning = _manifest($record);
    } elsif ( $kind eq q|sealed-head| ) {
        my $p    = $record->{'payload'};
        my %copy = %{$p};
        delete $copy{'peers'};
        $meaning = {
            head => _flat( q|sealed-head|, \%copy ),
            rows => _peers( $p->{'peers'} ),
        };
    } elsif ( $kind eq q|map-root| ) {
        $meaning = _map_root($record);
    } elsif ( $kind eq q|map-shard| ) {
        $meaning = _map_shard($record);
    } elsif ( $kind eq q|map-tree-blob| ) {
        $meaning = {
            head => { rows => 0, body => '0' },
            rows => _map_trees( $kind, $record->{'payload'} )
        };
    } elsif ( $kind eq q|manifest-index| ) {
        my $p = $record->{'payload'};
        _only( q|manifest-index|, $p, qw| format header chunks | );
        my @rows;
        for my $chunk ( @{ $p->{'chunks'} // [] } ) {
            my %copy = ( %{$chunk}, descriptor => { %{$chunk} } );
            $copy{'chunk'} = "$chunk->{'path'}#$chunk->{'part'}";
            push @rows,
                _row_old( q|manifest-index|, $INDEX_BODY->{'columns'},
                \%copy );
        }
        $meaning = {
            head => _flat( $kind, $p, _skip_only => 1 ),
            rows => \@rows,
        };
    } elsif ( $kind eq q|manifest-chunk| ) {
        _refuse('manifest-chunk prior payload is not an array')
            if ref $record->{'payload'} ne q|ARRAY|;
        require AMOS7::N7FS::Prior;
        AMOS7::N7FS::Prior::validate_json3_lines( $record->{'raw_lines'} );
        $meaning = {
            head => {
                lines     => 'json3',
                path      => $opt{'path'} // '',
                part      => $opt{'part'} // 0,
                positions => $opt{'positions'},
                rows      => 0,
                body      => '0',
            },
            raw_lines      => $record->{'raw_lines'},
            json3_verified => 1,
        };
    } elsif ( $kind eq q|sealed-journal| ) {
        $meaning = _sealed_journal($record);
    } elsif ( $kind eq q|holder-request| ) {
        $meaning = _request($record);
    } elsif ( $kind eq q|covered-cache|
        or $kind eq q|relay-pending|
        or $kind eq q|relay-list| ) {
        my $p    = $record->{'payload'};
        my $old  = $kind eq q|covered-cache| ? 'covered' : 'blobs';
        my %copy = %{$p};
        delete $copy{$old};
        my $head = _flat( $kind, \%copy );
        my @rows = map { $kind eq q|covered-cache| ? [$ARG] : [$ARG] }
            sort @{ $p->{$old} // [] };
        $meaning = { head => $head, rows => \@rows };
    } elsif ( $kind eq q|seal-state| ) {
        my $p = $record->{'payload'};
        _only( q|seal-state|, $p, qw| writer version last_time holders | );
        my @rows;
        for my $holder ( keys %{ $p->{'holders'} // {} } ) {
            push @rows,
                _row_old(
                q|seal-state|,
                $STATE_BODY->{'columns'},
                { %{ $p->{'holders'}{$holder} }, holder => $holder }
                );
        }
        my %copy = %{$p};
        delete $copy{'holders'};
        $meaning = { head => _flat( $kind, \%copy ), rows => \@rows };
    } elsif ( $kind eq q|request-counter| ) {
        my %copy = ( %{ $record->{'payload'} }, %opt );
        $meaning = { head => _flat( $kind, \%copy ) };
    } else {
        $meaning = { head => _flat( $kind, $record->{'payload'} ) };
        $meaning->{'head'}{'grid'} = 'float' if $kind eq q|state|;
    }
    if (    exists $BODY{$kind}
        and $BODY{$kind}{'shape'} eq q|table|
        and $meaning->{'rows'} ) {
        my @keyed = map { [ pack_body( $BODY{$kind}, [$ARG] ), $ARG ] }
            $meaning->{'rows'}->@*;
        $meaning->{'rows'}
            = [ map { $ARG->[1] } sort { $a->[0] cmp $b->[0] } @keyed ];
    }
    _signed_values( $meaning->{'head'}, $record );
    return $meaning;
}

sub _pack_table {
    my ( $spec, $rows ) = @ARG;
    my @lines = map { pack_body( $spec, [$ARG] ) } @{$rows};
    return join '', sort @lines;
}

sub _body_bytes {
    my ( $kind, $meaning ) = @ARG;
    if ( $kind eq q|manifest-chunk| ) {
        my $lines = $meaning->{'head'}{'lines'} // q|canon2|;
        if ( $lines eq q|json3| ) {
            _refuse('json3 requires verified legacy conversion')
                if not $meaning->{'json3_verified'};
            require AMOS7::N7FS::Prior;
            return AMOS7::N7FS::Prior::validate_json3_lines(
                $meaning->{'raw_lines'} // '' );
        }
        _refuse( 'manifest-chunk has unknown line mode [ %s ]', $lines )
            if $lines ne q|canon2|;
        return _pack_table( $MANIFEST_BODY, $meaning->{'rows'} // [] );
    }
    return '' if not exists $BODY{$kind};
    my $rows = $meaning->{'rows'} // [];
    _refuse( '%s rows are not an array', $kind ) if ref $rows ne q|ARRAY|;
    return $BODY{$kind}{'shape'} eq q|table|
        ? _pack_table( $BODY{$kind}, $rows )
        : pack_body( $BODY{$kind}, $rows );
}

sub _root_pack {
    my $meaning = shift;
    my $head    = $meaning->{'head'};
    _refuse('root-file meaning is missing') if ref $head ne q|HASH|;
    _refuse('root-file kdf is not argon2id')
        if ( $head->{'kdf'} // '' ) ne q|argon2id|;
    my @values = @{$head}{qw| t m p |};
    for my $index ( 0 .. 2 ) {
        my $name = (qw| t m p |)[$index];
        _count( q|root-file|, $name, $values[$index] );
        my $count = $values[$index];
        _refuse( 'root-file %s exceeds the 32 bit count bound', $name )
            if length $count > 10
            or length $count == 10 and $count gt q|4294967295|;
    }
    _refuse('root-file salt is not 16 raw bytes')
        if length( $head->{'salt'} // '' ) != 16;
    return
          "P7RK\x02"
        . CORE::pack( 'N N N a16', @values, $head->{'salt'} )
        . ( $meaning->{'secret'} // '' );
}

sub _vault_pack {
    my $meaning = shift;
    my $payload = $meaning->{'head'};
    _refuse('vault-registry meaning is missing')
        if ref $payload ne q|HASH|
        or ref $payload->{'holders'} ne q|HASH|;
    require AMOS7::N7FS::Placement;
    return AMOS7::N7FS::Placement::holders_config( $payload->{'holders'} );
}

sub _seal_binding_message {
    my ( $disk, $root_id ) = @ARG;
    return "p7 n7fs disk seal binding v1\0" . $disk . "\0" . $root_id;
}

sub _check_seal_binding {
    my ( $values, %opt ) = @ARG;
    _refuse('seal-root-binding stored disk differs from the verified disk')
        if defined $opt{'disk'} and $values->{'disk'} ne $opt{'disk'};
    _refuse('seal-root-binding stored root id differs from the verified root')
        if defined $opt{'root_id'}
        and $values->{'root-id'} ne $opt{'root_id'};
    _refuse('seal-root-binding root id is not derived from its signer')
        if not defined $values->{'pub'}
        or length $values->{'pub'} != 32
        or $values->{'root-id'} ne
        bmw384_b32( 'p7 n7fs seal root id v1' . $values->{'pub'} );
    return;
}

sub pack {
    my ( $kind, $meaning, %opt ) = @ARG;
    return _root_pack($meaning)  if $kind eq q|root-file|;
    return _vault_pack($meaning) if $kind eq q|vault-registry|;
    _refuse('id is frozen and cannot be packed again') if $kind eq q|id|;
    my $table = kind($kind);
    _refuse( '%s meaning is not a hash', $kind ) if ref $meaning ne q|HASH|;
    my %values = %{ $meaning->{'head'} // {} };
    my $body   = _body_bytes( $kind, $meaning );

    if ( $kind eq q|manifest-chunk| ) {
        $values{'rows'} = () = $body =~ m|\n|g;
        $values{'body'} = length $body ? bmw384_b32($body) : '0';
        my $positions = $values{'positions'} // [];
        _refuse('manifest-chunk positions are not a list')
            if ref $positions ne q|ARRAY|;
        _refuse('manifest-chunk positions do not match the row count')
            if $values{'rows'} != scalar @{$positions};
    } elsif ( exists $BODY{$kind} and $kind ne q|manifest| ) {
        $values{'rows'} = scalar @{ $meaning->{'rows'} // [] };
        $values{'body'} = length $body ? bmw384_b32($body) : '0';
    }
    return pack_head( $table, \%values ) . $body
        if not defined $opt{'signer'};
    if ( $kind eq q|seal-root-binding| ) {
        _refuse('seal-root-binding needs disk and root-id')
            if not defined $values{'disk'}
            or not defined $values{'root-id'};
        $values{'pub'} = $opt{'signer'}->public;
        _check_seal_binding( \%values );
        $values{'sig'} = $opt{'signer'}
            ->sign( _seal_binding_message( @values{qw| disk root-id |} ) );
        _refuse('seal-root-binding signature is not 64 raw bytes')
            if not defined $values{'sig'}
            or length $values{'sig'} != 64;
        return pack_head( $table, \%values ) . $body;
    }
    return pack_head( $table, \%values, signer => $opt{'signer'} ) . $body;
}

sub _list_rows {
    my ( $kind, $list ) = @ARG;
    my @rows;
    for my $raw ( $list->rows->@* ) {
        if ( $BODY{$kind}{'shape'} eq q|table| ) {
            my ($key) = split q| |, $raw, 2;
            push @rows, $list->row($key);
        } else {
            push @rows, $list->row( scalar @rows );
        }
    }
    return \@rows;
}

sub _binding_verify {
    my ( $kind, $verify, %opt ) = @ARG;
    return $verify
        if ( $KIND{$kind}{'signature'} // '' ) ne q|disk-root-binding|;
    _refuse('seal-root-binding verification needs disk and root_id')
        if not defined $opt{'disk'}
        or not defined $opt{'root_id'};
    return sub {
        my ( $pub, undef, $sig ) = @ARG;
        my $signed = _seal_binding_message( @opt{qw| disk root_id |} );
        return $verify->( $pub, $signed, $sig );
    };
}

sub parse {
    my ( $kind, $bytes, %opt ) = @ARG;
    if ( $kind eq q|id| or $kind eq q|root-file| ) {
        require AMOS7::N7FS::Prior;
        my $record = AMOS7::N7FS::Prior::read( $kind, $bytes, %opt );
        return from_prior( $kind, $record, %opt );
    }
    if ( $kind eq q|vault-registry| ) {
        require AMOS7::N7FS::Placement;
        return { head =>
                { holders => AMOS7::N7FS::Placement::holders_parse($bytes) }
        };
    }
    my $table = kind($kind);
    my $detached_sig;
    if ( $kind eq q|holder-request| and $bytes !~ m|\n| ) {
        my ( $head, $sig ) = split m|[.]|, $bytes, -1;
        _refuse('holder-request token is malformed')
            if not defined $sig or $sig =~ m|[.]|;
        my $head_bytes = decode_b32r($head)
            // _refuse('holder-request head is not base32');
        _refuse('holder-request head is not canonical base32')
            if encode_b32r($head_bytes) ne $head;
        $detached_sig = decode_b32r($sig)
            // _refuse('holder-request detached signature is not base32');
        _refuse('holder-request detached signature is not canonical')
            if length $detached_sig != 64
            or encode_b32r($detached_sig) ne $sig;
        $bytes = $head_bytes;
    }
    my $verify = $opt{'verify'};
    if ( defined $verify ) {
        _refuse( '%s verify callback is not code', $kind )
            if ref $verify ne q|CODE|;
        $opt{'verify'} = _binding_verify( $kind, $verify, %opt );
    }
    my $record = parse_head( $bytes, $table, %opt );
    my $body   = $record->{'body_bytes'};
    my $values = $record->{'values'};
    _check_seal_binding( $values, %opt ) if $kind eq q|seal-root-binding|;
    my $meaning = {
        head   => $values,
        record => $record,
    };
    if ( $kind eq q|holder-request| ) {
        _refuse('holder-request has trailing bytes') if length $body;
        _refuse('holder-request detached signature differs from the head')
            if defined $detached_sig and $detached_sig ne $values->{'sig'};
        return $meaning;
    }
    if ( $kind eq q|manifest-chunk| ) {
        my $count = () = $body =~ m|\n|g;
        _refuse('manifest-chunk row count does not match')
            if $count != $values->{'rows'};
        _refuse('manifest-chunk body checksum does not match')
            if ( length $body ? bmw384_b32($body) : '0' ) ne
            $values->{'body'};
        _refuse('manifest-chunk has no final LF')
            if length $body and $body !~ m|\n\z|;
        my $positions = $values->{'positions'} // [];
        _refuse('manifest-chunk positions do not match the row count')
            if $count != scalar @{$positions};
        $meaning->{'raw_lines'} = $body;
        if ( $values->{'lines'} eq q|json3| ) {
            require AMOS7::N7FS::Prior;
            AMOS7::N7FS::Prior::validate_json3_lines($body);
            $meaning->{'json3_verified'} = 1;
        } elsif ( length $body ) {
            my $list = AMOS7::cell::canon::list->new(
                $MANIFEST_BODY, $body,
                rows => $values->{'rows'},
                body => $values->{'body'},
            );
            $list->validate;
            $meaning->{'rows'} = _list_rows( q|manifest|, $list );
        }
        return $meaning;
    }
    return $meaning if not exists $BODY{$kind};
    my $list = AMOS7::cell::canon::list->new(
        $BODY{$kind},
        $body,
        $kind eq q|manifest|
        ? ()
        : ( rows => $values->{'rows'}, body => $values->{'body'} ),
    );
    $list->validate;
    $meaning->{'rows'} = _list_rows( $kind, $list );
    $meaning->{'list'} = $list;
    return $meaning;
}

sub encode_token {
    my ( $kind, $bytes, %opt ) = @ARG;
    _refuse('only holder-request has token transport')
        if $kind ne q|holder-request|;
    _refuse('token production requires verify callback')
        if $opt{'unverified'}
        or not defined $opt{'verify'};
    my $record = parse_head( $bytes, $KIND{$kind}, %opt );
    _refuse('holder-request has trailing bytes')
        if length $record->{'body_bytes'};
    return encode_b32r( $record->{'head_bytes'} ) . q|.|
        . encode_b32r( $record->{'values'}{'sig'} );
}

1;

#,,,.,,..,,..,,.,,,.,,.,.,.,.,...,,.,,.,.,.,,,..,,...,...,..,,...,.,,,.,.,,,.,
#FFKD55ECH22OGOCBSQ5OZUWXQNA3YTBVAFXLVEDBRQTQMXB6AKJZ4S26T2CO5CYV2PDZZERWFBRFS
#\\\|CLFBMZ77RM3KY7FI4E5CADEQ2YNRMHVPCMSGMHELIF2KP5JKUDD \ / AMOS7 \ YOURUM ::
#\[7]KTAHY222KSL3EJOKCSWHEJ5ROM4VPUAUQ7ASPNUVGHHHTL4MKECA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
