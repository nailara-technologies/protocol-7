#!/usr/bin/perl
use v5.32.0;
use strict;
use English;
use warnings;

use FindBin;
BEGIN { unshift @INC, "$FindBin::Bin/../../data/lib-path/pm" }

use Test::More;
use File::Temp         qw| tempdir |;
use AMOS7::B32         qw| encode_b32r |;
use AMOS7::cell::canon qw| bmw384_b32 |;
use AMOS7::N7FS        qw| signed_record_pack plain_record_pack |;
use AMOS7::N7FS::Sign  qw| seed_signer verify |;
use AMOS7::N7FS::Sum   qw| amos_of_bmw amos_of_bytes epoch_num |;
use AMOS7::N7FS::Prior qw| read read_id |;
use AMOS7::N7FS::Canon
    qw| kind body kinds from_prior pack parse encode_token |;

my $tmp = tempdir( 'n7fs-format4-stage2-XXXXXX', TMPDIR => 1, CLEANUP => 1 );
my $signer   = seed_signer( "\x42" x 32 );
my $pub      = $signer->public;
my $disk     = 'AAAAAAA';
my $root_id  = bmw384_b32( 'p7 n7fs seal root id v1' . $pub );
my $blob_a   = bmw384_b32('blob a');
my $blob_b   = bmw384_b32('blob b');
my $addr_a   = 'V7L4C7Y/' . amos_of_bmw($blob_a) . "/$blob_a";
my $addr_b   = 'V7L4C7Y/' . amos_of_bmw($blob_b) . "/$blob_b";
my $ntime    = '00031703855078';
my $raw16    = "\x17" x 16;
my $raw32    = "\x23" x 32;
my $ref_path = "$ntime/" . amos_of_bmw($blob_a) . "/$blob_a/addr";
my $codec    = AMOS7::N7FS::json_codec();
my %seen;

sub raw { return $codec->encode(shift) }
sub b32 { return encode_b32r(shift) }

sub old_signed {
    my ( $kind, $payload, $format ) = @ARG;
    return signed_record_pack( $kind, $payload, $signer, $format );
}

sub verify_signature {
    my ( $public, $message, $signature ) = @ARG;
    return verify( $public, $message, $signature );
}

sub refusal {
    my ( $name, $code, $expected ) = @ARG;
    my $error = do {
        local $EVAL_ERROR;
        eval { $code->(); 1 } ? undef : $EVAL_ERROR;
    };
    ok( defined $error && $error =~ $expected, $name )
        or diag( $error // 'the operation was accepted' );
}

sub compare_meaning {
    my ( $kind, $expected, $actual ) = @ARG;
    for my $key ( sort keys %{ $expected->{'head'} // {} } ) {
        next if $key eq q|sig|;
        next
            if $key =~ m{\A(?:rows|body)\z}
            and ( $actual->{'list'} or exists $actual->{'raw_lines'} );
        is_deeply(
            $actual->{'head'}{$key},
            $expected->{'head'}{$key},
            "$kind head field $key"
        );
    }
    my $expected_rows = $expected->{'rows'} // [];
    my $actual_rows   = $actual->{'rows'}   // [];
    is( scalar @{$actual_rows}, scalar @{$expected_rows}, "$kind row count" );
    for my $index ( 0 .. $#$expected_rows ) {
        for my $column ( 0 .. $#{ $expected_rows->[$index] } ) {
            is_deeply(
                $actual_rows->[$index][$column],
                $expected_rows->[$index][$column],
                "$kind row $index field $column"
            );
        }
    }
    is( $actual->{'raw_lines'},
        $expected->{'raw_lines'},
        "$kind exact lines"
    ) if exists $expected->{'raw_lines'};
}

sub roundtrip {
    my ( $kind_name, $old, %opt ) = @ARG;
    my $prior = read(
        $kind_name, $old,
        verify => \&verify_signature,
        %{ $opt{'prior'} // {} },
    );
    my $meaning
        = from_prior( $kind_name, $prior, %{ $opt{'convert'} // {} } );
    my $table  = eval { kind($kind_name) };
    my $signed = grep { $ARG->{'name'} eq q|pub| } $table->{'fields'}->@*;
    my $new    = pack( $kind_name,
        $meaning,
        $signed && $kind_name ne q|seal-root-binding|
        ? ( signer => $signer )
        : (),
    );
    my $parsed = parse(
        $kind_name, $new,
        $signed ? ( verify => \&verify_signature ) : (),
        %{ $opt{'parse'} // {} },
    );
    compare_meaning( $kind_name, $meaning, $parsed );
    my $repacked = pack( $kind_name,
        $parsed,
        $signed && $kind_name ne q|seal-root-binding|
        ? ( signer => $signer )
        : (),
    );
    is( $repacked, $new, "$kind_name pack of parse is byte equal" );
    $seen{$kind_name}++;
    return ( $new, $parsed );
}

subtest 'disk id, mount, use, state and meta' => sub {
    my $id_payload = {
        store_pub  => b32($pub),
        init_ntime => $ntime,
        name       => 'synthetic "disk" \\ fixture',
        intent     => 'roundtrip only \\ "never live"',
    };
    my $id_bytes = old_signed( 'id', $id_payload );
    my $id = read_id( $id_bytes, verify => \&verify_signature, pub => $pub );
    is_deeply( $id->{'payload'}, $id_payload, 'frozen id fields' );
    is( $id->{'disk'},
        amos_of_bytes($id_bytes),
        'id checksum covers old bytes'
    );
    is( $id->{'verified'}, 1, 'id parent signature verified' );
    $seen{'id'}++;
    my $changed = $id_bytes;
    substr( $changed, index( $changed, 'synthetic' ), 1 ) = 'X';
    refusal(
        'changed id byte fails its old signature',
        sub { read_id( $changed, verify => \&verify_signature ) },
        qr|signature does not verify|,
    );
    my $bad_shape = $id_bytes;
    $bad_shape =~ s|init_ntime|init-time|;
    refusal(
        'changed id key fails the fixed pattern',
        sub { read_id( $bad_shape, verify => \&verify_signature ) },
        qr|frozen format 1 pattern|,
    );
    refusal(
        'id read is fail closed without a callback',
        sub { read_id($id_bytes) },
        qr|requires verify|,
    );

    roundtrip(
        'mount',
        old_signed(
            'mount',
            {   disk        => $disk,
                mount       => 'BBBBBBB',
                event       => 'attach',
                ntime       => $ntime,
                mount_ntime => $ntime,
                host_name   => 'synthetic host',
            }
        )
    );
    roundtrip(
        'use',
        old_signed(
            'use',
            {   disk         => $disk,
                first        => $ntime,
                last         => $ntime,
                written      => $ntime,
                last_record  => "$ntime.BBBBBBB",
                last_event   => 'attach',
                store_format => 3,
                journal_seq  => 19,
            }
        )
    );
    my $state = {
        store_format => 3,
        epochs       => [ 17, 42 ],
        sums         => {
            amos => 'amos7-of-bmw384-b32',
            bmw  => 'bmw384-b32',
            l13  => 'stand-in:bmw384-b32-head13:',
        },
        device => {
            st_dev      => 23,
            mount_point => "$tmp/synthetic-disk",
            fs_type     => 'tmpfs',
            source      => 'synthetic',
        },
        previous  => { store_format => 2, epochs => [16] },
        confirmed => \1,
        converted => '2->3',
    };
    roundtrip( 'state', old_signed( 'state', $state, 3 ) );
    my $meta = {
        name         => 'synthetic.txt',
        format       => 'txt',
        size         => 12345,
        mtime        => 1700000000,
        import_ntime => $ntime,
        epoch_num    => epoch_num(31703855078),
        epoch        => 'V7L4C7Y',
        source       => "$tmp/source/synthetic.txt",
        host         => 'synthetic-host',
        amos         => amos_of_bmw($blob_a),
        bmw          => $blob_a,
        disk         => $disk,
        index_chksum => 'synthetic-index-sum',
        index_name   => 'synthetic index',
        origin       => { disk => 'CCCCCCC', id => 'meta:source:1' },
        converted_from_unsigned => \1,
    };
    my ( undef, $new_meta )
        = roundtrip( 'meta', old_signed( 'meta', $meta, 3 ) );
    is( $new_meta->{'head'}{'epoch-num'},
        $meta->{'epoch_num'}, 'epoch_num text survives exactly' );
};

subtest 'journal and store-set records' => sub {
    my $origin = { disk => 'CCCCCCC', id => 'origin record 1' };
    roundtrip(
        'reference',
        old_signed(
            'reference',
            {   disk      => $disk,
                addr      => $addr_a,
                holder    => "$tmp/source one",
                name      => 'one.txt',
                ntime     => $ntime,
                origin    => $origin,
                converted => \1,
            },
            3
        )
    );
    roundtrip(
        'drop',
        old_signed(
            'drop',
            {   disk   => $disk,
                addr   => $addr_a,
                holder => "$tmp/source one",
                name   => 'one.txt',
                ntime  => $ntime,
                origin => $origin,
            },
            3
        )
    );
    roundtrip(
        'tombstone',
        old_signed(
            'tombstone',
            {   disk   => $disk,
                addr   => $addr_a,
                ntime  => $ntime,
                reason => 'synthetic release',
                origin => $origin,
            },
            3
        )
    );
    roundtrip(
        'tree_drop',
        old_signed(
            'tree_drop',
            {   disk   => $disk,
                name   => 'synthetic tree',
                tree   => "$ntime.AAAAAAAA.tree",
                ntime  => $ntime,
                origin => $origin,
            },
            3
        )
    );
    roundtrip(
        'category',
        old_signed(
            'category',
            {   disk             => $disk,
                name             => 'photos',
                local_encryption => 'none',
                copies           => 2,
                priority         => 50,
                replica          => 'full',
                want             => [qw| durable intake |],
                foreign_work     => 'no',
                layer            => 'private',
                root             => $root_id,
                ntime            => $ntime,
                origin           => $origin,
            },
            3
        )
    );
    roundtrip(
        'assignment',
        old_signed(
            'assignment',
            {   disk      => $disk,
                node      => $addr_a,
                reference => $ref_path,
                holder    => "$tmp/source one",
                category  => 'photos',
                ntime     => $ntime,
                origin    => $origin,
            },
            3
        )
    );
    roundtrip(
        'sync_cursor',
        old_signed(
            'sync_cursor',
            {   disk        => $disk,
                source      => 'CCCCCCC',
                source_seq  => 7,
                source_hash => $blob_b,
                ntime       => $ntime,
            },
            3
        )
    );
    roundtrip(
        'sync_conflict',
        old_signed(
            'sync_conflict',
            {   disk      => $disk,
                kind      => 'assignment',
                origin    => $origin,
                receiver  => 'photos',
                source    => 'incoming',
                reference => $ref_path,
                ntime     => $ntime,
            },
            3
        )
    );
    roundtrip(
        'hold',
        old_signed(
            'hold',
            {   disk    => $disk,
                seq     => 3,
                reason  => 'synthetic hold',
                source  => 'test',
                ntime   => $ntime,
                expires => '00031703856078',
            },
            3
        )
    );
    roundtrip(
        'tree',
        old_signed(
            'tree',
            {   disk       => $disk,
                name       => 'synthetic tree',
                manifest   => $addr_b,
                created    => $ntime,
                ntime      => $ntime,
                origin     => $origin,
                references => [
                    { node => $addr_b, path => $ref_path },
                    { node => $addr_a, path => $ref_path },
                ],
            },
            3
        )
    );
    roundtrip(
        'batch',
        old_signed(
            'batch',
            {   disk       => $disk,
                category   => 'photos',
                bytes      => 4567,
                ntime      => $ntime,
                origin     => $origin,
                references => [
                    { node => $addr_a, reference => $ref_path },
                    { node => $addr_b, reference => $ref_path },
                ],
            },
            3
        )
    );

    my $journal = {
        seq  => 2,
        prev => $blob_a,
        disk => $disk,
        add  => {
            nodes => [$addr_a],
            meta  => [ { node => $addr_a, name => "$ntime.AAAAAAAA.meta" } ],
            references => [
                {   node   => $addr_a,
                    path   => $ref_path,
                    holder => "$tmp/source one",
                    name   => 'one.txt',
                    origin => $origin,
                }
            ],
            trees => [
                {   name       => 'synthetic tree',
                    path       => "$ntime.AAAAAAAA.tree",
                    manifest   => $addr_a,
                    created    => $ntime,
                    references => [ { node => $addr_a, path => $ref_path } ],
                }
            ],
            categories =>
                [ { name => 'photos', path => "$ntime.AAAAAAAA.category" } ],
            assignments => [
                {   node      => $addr_a,
                    reference => $ref_path,
                    path      => "$ntime.AAAAAAAA.assignment",
                    category  => 'photos',
                }
            ],
            batches => [
                {   path     => "$ntime.AAAAAAAA." . "batch-assignment",
                    category => 'photos'
                }
            ],
            sync_cursors => [
                {   source      => 'CCCCCCC',
                    source_seq  => 7,
                    source_hash => $blob_b,
                    path        => "$ntime.AAAAAAAA.sync-cursor",
                }
            ],
            conflicts => [ { path => "$ntime.AAAAAAAA.sync-conflict" } ],
            holds     => [
                {   path    => "$ntime.AAAAAAAA.hold",
                    seq     => 1,
                    reason  => 'synthetic hold',
                    source  => 'test',
                    ntime   => $ntime,
                    expires => '00031703856078',
                }
            ],
        },
        drop => {
            nodes      => [],
            meta       => [],
            references => [],
            releases   => [$addr_b],
            trees      => [
                {   name => 'old tree',
                    path => "$ntime.AAAAAAAB.tree-drop",
                    tree => "$ntime.AAAAAAAC.tree",
                }
            ],
            sync_releases => [
                {   node       => $addr_a,
                    origin     => $origin,
                    references => [ { node => $addr_a, path => $ref_path } ],
                }
            ],
            conflicts => [ { path => "$ntime.AAAAAAAD.sync-conflict" } ],
            holds     => [ { path => "$ntime.AAAAAAAE.hold" } ],
        },
        baseline => \1,
        repaired => \1,
    };
    roundtrip( 'journal', old_signed( 'journal', $journal, 3 ) );
};

sub descriptor {
    my ( $blob, $version ) = @ARG;
    return {
        blob     => $blob,
        checksum => bmw384_b32("plaintext $blob"),
        id       => b32($raw32),
        writer   => b32($raw16),
        version  => $version,
        size     => 4096,
    };
}

sub tree_map {
    return {
        manifest => $addr_b,
        created  => $ntime,
        files    => 2,
        held     => 1,
        state    => 'partial',
        disks    => { $disk => \1, CCCCCCC => \1 },
        index    => descriptor( $blob_a, 8 ),
    };
}

subtest 'manifest and sealed holder records' => sub {
    my $manifest = {
        header => {
            manifest => 1,
            root_b32 => b32("$tmp/tree root"),
            created  => $ntime,
            snapshot => 'synthetic snapshot',
        },
        entries => [
            {   p            => b32('dir/file.txt'),
                t            => 'file',
                mode         => 420,
                uid          => 1000,
                gid          => 1001,
                mtime        => 1700000000,
                mtime_ns     => 123456789,
                size         => 12345,
                a            => $addr_a,
                user_b32     => b32('synthetic-user'),
                group_b32    => b32('synthetic-group'),
                xattrs       => { b32('user.test') => b32("value\x00one") },
                xattr_errors => [
                    {   name_b32 => b32('user.bad'),
                        why      => 'synthetic xattr error'
                    }
                ],
            },
            {   p     => b32('dir/link'),
                t     => 'symlink',
                mode  => 511,
                uid   => 1000,
                gid   => 1001,
                mtime => 1700000001,
                l     => b32("target\nbytes"),
            },
            {   p     => b32('dir/hardlink'),
                t     => 'hardlink',
                mode  => 420,
                uid   => 1000,
                gid   => 1001,
                mtime => 1700000002,
                h     => b32('dir/file.txt'),
            },
            { p => b32('missing'), t => 'skipped', why => "two\nlines" },
        ],
    };
    my $manifest_old = join '',
        raw( $manifest->{'header'} ) . "\n",
        map { raw($ARG) . "\n" } @{ $manifest->{'entries'} };
    roundtrip( 'manifest', $manifest_old );

    require AMOS7::N7FS::Seal;
    my $binding = {
        v       => 1,
        disk    => $disk,
        root_id => $root_id,
        pub     => b32($pub),
        sig     => b32(
            $signer->sign(
                AMOS7::N7FS::Seal::_binding_signed(
                    { root_id => $root_id }, $disk
                )
            )
        ),
    };
    roundtrip( 'seal-root-binding', raw($binding),
        parse => { disk => $disk, root_id => $root_id }, );

    my $head = {
        format   => 'n7fs-head-v2',
        root_id  => $root_id,
        writer   => b32($raw16),
        version  => 8,
        time     => 31703855078,
        holder   => b32($raw16),
        map      => descriptor( $blob_a, 8 ),
        journal  => $blob_b,
        registry => descriptor( $blob_b, 8 ),
        peers    => {
            "$tmp/other holder" => {
                v => 7,
                t => 31703855070,
                r => { v => 7, t => 31703855069, c => 'full', n => 2 },
                d => {
                    t  => 31703855068,
                    tr => 'synthetic tree',
                    f  => 2,
                    b  => 12345,
                },
            },
        },
        pub => b32($pub),
    };
    $head->{'sig'} = b32( $signer->sign( raw($head) ) );
    roundtrip( 'sealed-head', raw($head) );

    my $map = {
        format     => 'n7fs-sharded-map-v1',
        depth      => 1,
        root_id    => $root_id,
        categories => {
            photos => { id => b32($raw16), wrap => b32("wrap\x00photos") },
        },
        retention  => { 'synthetic'      => '2Y4 1Y1' },
        pins       => { 'synthetic tree' => \1 },
        superseded => { $blob_b          => 7 },
        shards     => { AA               => descriptor( $blob_a, 8 ) },
        tree_blob  => descriptor( $blob_b, 8 ),
        trees      => { 'synthetic tree' => tree_map() },
    };
    roundtrip( 'map-root', raw($map) );

    for my $suffix (qw| one two |) {
        my $shard = {
            $addr_a => {
                id       => b32($raw16),
                blob     => $blob_a,
                node     => $blob_a,
                offset   => 17,
                length   => 4096,
                chunks   => 1,
                category => 'photos',
                disks    => { $disk  => \1 },
                wraps    => { photos => b32("wrap $suffix") },
                added    => 8,
                layout   => {
                    mode        => 'complete',
                    chunk_size  => 16777216,
                    header_size => 0,
                },
            },
        };
        roundtrip( 'map-shard', raw($shard) );
    }
    roundtrip( 'map-tree-blob', raw( { 'synthetic tree' => tree_map() } ) );

    my $index = {
        format => 'n7fs-chunked-manifest-v1',
        header => $manifest->{'header'},
        chunks => [
            {   path      => 'dir',
                part      => 0,
                positions => [ 0, 1, 2 ],
                descriptor( $blob_a, 8 )->%*,
            },
            {   path      => 'dir',
                part      => 1,
                positions => [3],
                descriptor( $blob_b, 8 )->%*,
            },
        ],
    };
    roundtrip( 'manifest-index', raw($index) );
    roundtrip(
        'manifest-chunk',
        raw( $manifest->{'entries'} ),
        convert => { path => 'dir', part => 0, positions => [ 0, 1, 2, 3 ] },
    );

    my $journal = {
        writer    => b32($raw16),
        version   => 8,
        map       => $blob_a,
        operation => { unmap => [$addr_a], untag => { $disk => [$addr_b] } },
    };
    roundtrip( 'sealed-journal', raw($journal) );
};

subtest 'receipts, drill and home state' => sub {
    my $receipt = {
        holder        => "$tmp/holder",
        root_id       => $root_id,
        time          => 31703855078,
        local_time    => 31703855077,
        version       => 8,
        nodes         => 2,
        samples       => 4,
        coverage      => 'full',
        covered       => $blob_a,
        covered_nodes => 2,
    };
    my $receipt_old = {
        receipt => $receipt,
        pub     => b32($pub),
        sig => b32( $signer->sign( "p7 n7fs receipt v2\0" . raw($receipt) ) ),
    };
    roundtrip( 'receipt', raw($receipt_old) );
    roundtrip(
        'covered-cache',
        raw(
            {   version => 8,
                digest  => $blob_a,
                covered => [ $addr_b, $addr_a ],
            }
        )
    );

    my $drill = {
        time         => 31703855078,
        holder       => "$tmp/holder",
        holder_id    => b32($raw16),
        tree         => 'synthetic tree',
        snapshot     => 'snapshot one',
        files        => 2,
        bytes        => 12345,
        took         => 19,
        head_version => 8,
        mode         => 'full',
        result       => 'failed',
        max_bytes    => 99999,
        error        => "first line\nsecond line",
        root_id      => $root_id,
    };
    my $drill_old = {
        drill => $drill,
        pub   => b32($pub),
        sig   => b32( $signer->sign( "p7 n7fs drill v1\0" . raw($drill) ) ),
    };
    roundtrip( 'drill', raw($drill_old) );

    roundtrip(
        'seal-state',
        raw(
            {   writer    => b32($raw16),
                version   => 8,
                last_time => 31703855078,
                holders   => {
                    b32($raw16) => {
                        spec    => "$tmp/holder",
                        version => 8,
                        time    => 31703855078,
                        receipt =>
                            { v => 8, t => 31703855077, c => 'full', n => 2 },
                    },
                },
            }
        )
    );
    roundtrip( 'reservation',
        raw( { root_id => $root_id, writer => b32($raw16), version => 9 } ) );
    roundtrip( 'pending-key',
        raw( { node_id => b32($raw16), wrap => b32("pending\x00wrap") } ) );
    roundtrip(
        'request-counter',
        raw( { counter => 9 } ),
        convert => { root_id => $root_id, holder => $blob_a },
    );
    roundtrip(
        'relay-pending',
        raw(
            {   holder => "$tmp/holder",
                time   => 31703855078,
                blobs  => [ $blob_b, $blob_a ]
            }
        )
    );
    roundtrip( 'relay-list',
        raw( { subdir => 'r-AAAAAAA', blobs => [ $blob_b, $blob_a ] } ) );
};

subtest 'prior type checks and new module source boundaries' => sub {
    my $meta = {
        name         => 'bad.txt',
        format       => 'txt',
        size         => 1,
        mtime        => 1700000000,
        import_ntime => $ntime,
        epoch_num    => epoch_num(31703855078),
        epoch        => 'V7L4C7Y',
        source       => "$tmp/source/bad.txt",
        host         => 'synthetic-host',
        amos         => amos_of_bmw($blob_a),
        bmw          => $blob_a,
        disk         => $disk,
    };
    my $record = read(
        'meta',
        old_signed( 'meta', $meta, 3 ),
        verify => \&verify_signature
    );
    for my $case (
        [ 'float count',         size      => 1.5,    qr|canonical count| ],
        [ 'leading zero count',  size      => '0123', qr|canonical count| ],
        [ 'bad decimal text',    epoch_num => '01.2', qr|decimal text| ],
        [ 'character above 255', name      => "bad\x{100}", qr|above 255| ],
        [ 'unknown prior key',   extra     => 1,            qr|unknown key| ],
    ) {
        my ( $name, $key, $value, $expected ) = @{$case};
        my %copy = %{ $record->{'payload'} };
        $copy{$key} = $value;
        refusal(
            $name,
            sub {
                from_prior( 'meta', { %{$record}, payload => \%copy } );
            },
            $expected,
        );
    }
    for my $path (
        qw| data/lib-path/pm/AMOS7/N7FS/Canon.pm
        data/lib-path/pm/AMOS7/N7FS/Prior.pm |
    ) {
        open( my $fh, '<:raw', "$FindBin::Bin/../../$path" ) or die $OS_ERROR;
        local $INPUT_RECORD_SEPARATOR;
        my $source = <$fh>;
        unlike( $source, qr|Digest::SHA|i, "$path has no sha module" );
        if ( $path =~ m|Canon[.]pm\z| ) {
            unlike( $source, qr|JSON::|i, 'canon has no json module' );
        } else {
            like( $source, qr|JSON::PP|,
                'prior is the one legacy json reader' );
        }
    }
};

subtest 'request token, vault registry and root suite' => sub {
    require AMOS7::N7FS::Receiver;
    my $root = { signer => $signer, root_id => $root_id };
    my $args = {
        path    => $blob_a,
        size    => 4096,
        digest  => $blob_a,
        version => 8,
        writer  => b32($raw16),
    };
    my $token = AMOS7::N7FS::Receiver::request_sign( $root, "$tmp/holder",
        'put-head', $args, 9 );
    my ($head_bytes)
        = roundtrip( 'holder-request', $token, prior => { pub => $pub }, );
    my $new_token = encode_token( 'holder-request', $head_bytes,
        verify => \&verify_signature, );
    my $parsed_token = parse( 'holder-request', $new_token,
        verify => \&verify_signature, );
    is( $parsed_token->{'head'}{'counter'}, 9, 'v2 token transport parses' );
    refusal(
        'signed canon head needs a verify callback',
        sub { parse( 'holder-request', $head_bytes ) },
        qr|requires verify|,
    );
    my $inspection = parse( 'holder-request', $head_bytes, unverified => 1 );
    is( $inspection->{'record'}{'verified'},
        0, 'inspection parse is explicitly unverified' );
    my $tampered = $head_bytes;
    $tampered =~ s|counter = 9|counter = 8|;
    refusal(
        'changed signed head byte is refused',
        sub {
            parse( 'holder-request', $tampered,
                verify => \&verify_signature );
        },
        qr|signature does not match|,
    );

    my $registry = {
        holders => {
            synthetic => {
                spec         => "$tmp/holder",
                role         => 'durable',
                domain       => 'test',
                owned        => 1,
                quota        => 1000000,
                reserve      => 1000,
                categories   => [qw| photos |],
                min_priority => 10,
                via          => 'other',
                access       => 'synthetic access',
                id           => b32($raw16),
            },
        },
    };
    my $prior   = read( 'vault-registry', raw($registry) );
    my $meaning = from_prior( 'vault-registry', $prior );
    my $config  = pack( 'vault-registry', $meaning );
    my $parsed  = parse( 'vault-registry', $config );
    is_deeply( $parsed->{'head'}, $meaning->{'head'},
        'vault registry becomes hand-editable config' );
    $seen{'vault-registry'}++;

    require AMOS7::N7FS::Keys;
    my $secret   = "secret\x00\xffbytes";
    my $root_old = AMOS7::N7FS::Keys::_pack( $secret, $raw16,
        { t => 3, m => 65536, p => 2 } );
    my $prior_root   = read( 'root-file', $root_old );
    my $root_meaning = from_prior( 'root-file', $prior_root );
    my $root_new     = pack( 'root-file', $root_meaning );
    ok( substr( $root_new, 0, 5 ) eq "P7RK\x02",
        'root header is suite 2 binary'
    );
    is( length($root_new),
        5 + 12 + 16 + length($secret),
        'root suite 2 has fixed binary header'
    );
    my $root_parsed = parse( 'root-file', $root_new );
    is_deeply( $root_parsed, $root_meaning,
        'root parameters and secret roundtrip' );
    $seen{'root-file'}++;
};

subtest 'security regression checks' => sub {
    my $binding = {
        v       => 1,
        disk    => $disk,
        root_id => $root_id,
        pub     => b32($pub),
        sig     => b32(
            $signer->sign(
                AMOS7::N7FS::Seal::_binding_signed(
                    { root_id => $root_id }, $disk
                )
            )
        ),
    };
    my ($binding_bytes)
        = roundtrip( 'seal-root-binding', raw($binding),
        parse => { disk => $disk, root_id => $root_id }, );
    my $changed_binding = $binding_bytes;
    $changed_binding =~ s|^disk\s+= \Q$disk\E$|disk    = BBBBBBB|m;
    refusal(
        'seal binding stored disk differs from verified disk',
        sub {
            parse(
                'seal-root-binding', $changed_binding,
                disk    => $disk,
                root_id => $root_id,
                verify  => \&verify_signature,
            );
        },
        qr|stored disk differs|,
    );

    my $other = seed_signer( "\x43" x 32 );
    my $other_proof
        = AMOS7::N7FS::Seal::_binding_signed( { root_id => $root_id },
        $disk );
    my $wrong_root = AMOS7::cell::canon::pack_head(
        kind('seal-root-binding'),
        {   suite     => 1,
            disk      => $disk,
            'root-id' => $root_id,
            pub       => $other->public,
            sig       => $other->sign($other_proof),
        },
    );
    refusal(
        'seal binding root id must derive from its signer',
        sub {
            parse(
                'seal-root-binding', $wrong_root,
                disk    => $disk,
                root_id => $root_id,
                verify  => \&verify_signature,
            );
        },
        qr|root id.*signer|,
    );
    my $signed_roundtrip = eval {
        my $new = pack(
            'seal-root-binding',
            { head => { suite => 1, disk => $disk, 'root-id' => $root_id } },
            signer => $signer,
        );
        parse(
            'seal-root-binding', $new,
            disk    => $disk,
            root_id => $root_id,
            verify  => \&verify_signature,
        );
        1;
    };
    ok( $signed_roundtrip, 'seal binding signer round trip' )
        or diag $EVAL_ERROR;

    my $entry = {
        p        => b32('dir/file.txt'),
        t        => 'file',
        mode     => 420,
        uid      => 1000,
        gid      => 1000,
        mtime    => 1700000000,
        mtime_ns => 0,
        size     => 1,
        a        => $addr_a,
    };
    refusal( 'json3 refuses a scalar manifest entry',
        sub { read( 'manifest-chunk', raw( ['not an object'] ) ) },
        qr|object|, );
    refusal(
        'json3 refuses an unknown manifest entry key',
        sub {
            read( 'manifest-chunk', raw( [ { %{$entry}, unknown => 1 } ] ) );
        },
        qr|unknown key|,
    );
    refusal(
        'json3 refuses an unsafe manifest path',
        sub {
            read( 'manifest-chunk',
                raw( [ { %{$entry}, p => b32('../escape') } ] ) );
        },
        qr|unsafe component|,
    );
    my $exact_lines = raw($entry) . "\n";
    refusal(
        'json3 cannot be built from unverified raw lines',
        sub {
            pack(
                'manifest-chunk',
                {   head => {
                        lines     => 'json3',
                        path      => 'dir',
                        part      => 0,
                        positions => [0],
                    },
                    raw_lines => $exact_lines,
                },
            );
        },
        qr|verified legacy conversion|,
    );
    my $not_json        = "not-json\n";
    my $not_json_record = AMOS7::cell::canon::pack_head(
        kind('manifest-chunk'),
        {   lines     => 'json3',
            path      => 'dir',
            part      => 0,
            positions => [0],
            rows      => 1,
            body      => bmw384_b32($not_json),
        },
    ) . $not_json;
    refusal( 'json3 parser validates every line',
        sub { parse( 'manifest-chunk', $not_json_record ) }, qr|json|, );
    my $chunk_prior         = read( 'manifest-chunk', raw( [$entry] ) );
    my $chunk_bad_positions = from_prior(
        'manifest-chunk', $chunk_prior,
        path      => 'dir',
        part      => 0,
        positions => [ 0, 1 ],
    );
    refusal(
        'manifest chunk positions must match its row count',
        sub { pack( 'manifest-chunk', $chunk_bad_positions ) },
        qr|positions.*row count|,
    );

    my $request_head = pack(
        'holder-request',
        {   head => {
                op        => 'delete',
                'root-id' => $root_id,
                holder    => $blob_a,
                counter   => 9,
                nonce     => $raw16,
                path      => $blob_a,
                size      => undef,
                digest    => undef,
                version   => undef,
                writer    => undef,
                from      => undef,
                to        => undef,
                name      => undef,
                tag       => undef,
            },
        },
        signer => $signer,
    );
    refusal(
        'token production requires signature verification',
        sub { encode_token( 'holder-request', $request_head ) },
        qr|requires verify|,
    );
    my $request_token = encode_token( 'holder-request', $request_head,
        verify => \&verify_signature, );
    my ($request_head_b32) = split m|[.]|, $request_token;
    my $wrong_detached     = $request_head_b32 . q|.| . b32( "\0" x 64 );
    refusal(
        'holder token detached signature must match the head',
        sub {
            parse( 'holder-request', $wrong_detached,
                verify => \&verify_signature, );
        },
        qr|detached signature|,
    );
    refusal(
        'token production refuses unsigned trailing bytes',
        sub {
            encode_token(
                'holder-request',
                $request_head . 'unsigned trailer',
                verify => \&verify_signature,
            );
        },
        qr|trailing bytes|,
    );

    my %large_kdf = (
        kdf  => 'argon2id',
        t    => '4294967297',
        m    => 1,
        p    => 1,
        salt => $raw16,
    );
    refusal(
        'root kdf counts cannot wrap at 32 bits',
        sub {
            pack( 'root-file', { head => \%large_kdf, secret => 'secret' } );
        },
        qr|32 bit|,
    );
    refusal(
        'prior exponent float is not a count',
        sub {
            my $exponent_prior = read(
                'reservation',
                '{"root_id":"'
                    . $root_id
                    . '","writer":"'
                    . b32($raw16)
                    . '","version":1e3}',
            );
            from_prior( 'reservation', $exponent_prior );
        },
        qr|float|,
    );
};

subtest 'switch record and complete kind inventory' => sub {
    my $switch = {
        head => {
            disk      => $disk,
            from      => 3,
            to        => 4,
            direction => 'forward',
            rows      => 2,
            body      => $blob_a,
        },
    };
    my $bytes  = pack( 'switch', $switch, signer => $signer );
    my $parsed = parse( 'switch', $bytes, verify => \&verify_signature );
    compare_meaning( 'switch', $switch, $parsed );
    $seen{'switch'}++;

    my @canon = kinds;
    is( scalar @canon, 36, '36 canon kind tables including switch' );
    for my $name (@canon) {
        my $table = kind($name);
        ok( $table->{'label'}
                =~ m{\Ap7 n7fs [a-z0-9-]+(?: [a-z0-9-]+)* v[0-9]+\z},
            "kind label $name"
        );
        my %fields;
        my $duplicate
            = grep { $fields{ $ARG->{'name'} }++ } $table->{'fields'}->@*;
        ok( !$duplicate, "kind fields $name are unique" );
    }
    my @expected = qw|
        id mount use state meta journal reference drop tombstone tree tree_drop
        category assignment batch sync_cursor sync_conflict hold manifest
        seal-root-binding sealed-head map-root map-shard map-tree-blob
        manifest-index manifest-chunk sealed-journal receipt drill covered-cache
        seal-state reservation pending-key request-counter relay-pending
        vault-registry root-file holder-request relay-list
        |;
    my @covered = grep { $ARG ne q|switch| } keys %seen;
    is_deeply(
        [ sort @covered ],
        [ sort @expected ],
        'all 38 documented kinds covered'
    );
    ok( $seen{'switch'}, 'new switch kind covered beside the 38' );
};

done_testing;

#,,..,..,,...,,,,,...,,..,.,,,,.,,.,,,,,,,..,,..,,...,...,.,,,.,.,...,,,.,,,.,
#S3LFBMGTY5H77QFC2T3ZVMKOMWNKJILNAXLHSC7GMDILVFA4PIYFD2LPZ7G743KPHVYY3UJNZ2JZS
#\\\|2N5OXSG4QJWYAD42GIRHSDKF6KJ4455FHIGTWSJNPGL4ZMXGBA7 \ / AMOS7 \ YOURUM ::
#\[7]EJKQSM4DRA6SB55NJ3JBNBZX7RMFP6MLNS6Z5C6OQOSKIA3YDCBA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
