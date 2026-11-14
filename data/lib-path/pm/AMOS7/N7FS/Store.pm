## [:< ##

package AMOS7::N7FS::Store;    ##############################################

## N7FS : content nodes and assimilate.
##
## <root>/<disk>/<epoch>/<amos>/<bmw>/content  /meta/<ntime14>.<tail8>.meta
##
## content : the file's bytes, unchanged [ no chunking in format 1, 2 or 3 ].
## meta : one 'P7FN' record per changed import
## [ plain in format 1, signed by the delegated store key in format 2 and 3 ].
## a new source of the same content adds a meta file ; an unchanged repeat
## keeps the newest one, nothing is rewritten [ sync = union of files ].
##
## node formats are CODECS [ read \ write \ verify ] keyed by the store format
## of the state record ; AMOS7::N7FS::Convert chains them.
##
## assimilate order per file : hash the source -> write the node beside
## [ temp name, atomic publish ] -> verify the stored node -> re-hash the
## source -> remove the source ONLY with an explicit 'remove' and only after
## all that. any failure leaves the source untouched.

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
use vars qw| @EXPORT_OK $VERSION %CODEC |;

our $VERSION = qw| AMOS7::N7FS::Store-VERSION.U4BALDA |;

@EXPORT_OK = qw|
    assimilate
    index_sources
    meta_entries
    reference_entries
    reference_drop
    store_repair
    node_path
    node_verify
    store_nodes
    store_verify
    write_epoch
    register_codec
    codec
    |;

use Fcntl qw| O_RDONLY O_NOFOLLOW |;
use Digest::BMW;
use Cwd           qw| abs_path |;
use Sys::Hostname qw| hostname |;
use AMOS7::N7FS   qw| root_dir host_dir ntime_now ntime14 b32 random_bytes
    signed_record_pack signed_record_parse plain_record_pack plain_record_parse
    write_new_file write_new_file_stream read_file make_dirs publish_dir
    remove_tree refuse fault |;
use AMOS7::N7FS::Sum qw| bmw384_fh bmw_b32 amos_of_bmw epoch_int epoch_num
    epoch_b32 epoch_from_b32 |;
use AMOS7::N7FS::Sign qw| verify |;
use AMOS7::N7FS::Disk qw| disk_require_attached disk_read_id state_read
    state_write store_key_signer witness_check_format witness_check_journal
    witness_note_format disk_lock |;
use AMOS7::N7FS::Journal   qw| journal_replay journal_head journal_write |;
use AMOS7::N7FS::Reference qw| reference_write reference_scan
    reference_drop_write reference_address |;

our $BMW_RE  = qr{\A[A-Z2-7]{77}\z};
our $AMOS_RE = qr{\A[A-Z2-7]{7}\z};
our $META_RE = qr{\A(\d{14})\.[A-Z2-7]{8}\.meta\z};
our $ADDR_RE = qr{\AV7[A-Z2-7]{5}/[A-Z2-7]{7}/[A-Z2-7]{77}\z};
our $TMP_RE  = qr{\.tmp\.[A-Z2-7]{8}\z};

##[ CODECS ]##################################################################

sub register_codec {
    my ( $format, $codec ) = @ARG;
    foreach my $sub (qw| write_node read_node verify_node |) {
        refuse( 'codec %s : no %s', $format, $sub )
            if ref $codec->{$sub} ne qw| CODE |;
    }
    $CODEC{$format} = $codec;
    return $codec;
}

sub codec {
    my $format = shift // '';
    refuse( 'store format %s : no codec here [ newer n7fs ? ]', $format )
        if not exists $CODEC{$format};
    return $CODEC{$format};
}

## opens a regular file without following a symlink ; returns the handle and
## its fstat
sub _open_regular {
    my $path = shift;
    sysopen( my $fh, $path, O_RDONLY | O_NOFOLLOW )
        or refuse( 'cannot open %s : %s', $path, $OS_ERROR );
    binmode $fh;
    my @st = stat $fh;
    refuse( '%s is not a regular file', $path ) if not -f _;
    return ( $fh, \@st );
}

sub _list_dir {
    my $dir = shift;
    opendir( my $dh, $dir )
        or refuse( 'cannot read %s : %s', $dir, $OS_ERROR );
    my @names = grep { $ARG ne '.' and $ARG ne '..' } readdir $dh;
    closedir $dh;
    return sort @names;
}

our $LINK   = sub { return link( $ARG[0], $ARG[1] ) };
our $DEVICE = sub { return ( stat $ARG[0] )[0] };

## conversion may ask for a hard link ; every other writer copies into a new
## temporary node. no path opens existing content for writing
sub _write_content {
    my ( $dir, $node ) = @ARG;
    my $source = $node->{'content_path'};
    my $target = "$dir/content";
    my $addr   = $node->{'addr'};
    if ( $node->{'link_content'} ) {
        my @src_st  = lstat $source;
        my $regular = @src_st && -f _ && not -l _;
        my $dst_dev = $DEVICE->($dir);
        if (    $regular
            and defined $dst_dev
            and $DEVICE->($source) == $dst_dev ) {
            fault(qw| convert:before-link |);
            if ( $LINK->( $source, $target ) ) {
                $node->{'content_action'} = qw| linked |;
                fault(qw| convert:after-link |);
                return TRUE;
            }
            $node->{'content_note'} = "hard link failed : $OS_ERROR";
        } else {
            $node->{'content_note'} = 'different filesystem';
        }
        $node->{'content_action'} = qw| copied |;
    }

    my ( $src, $st ) = _open_regular($source);
    my $ctx = Digest::BMW->new(384);
    fault(qw| convert:before-copy |) if $node->{'link_content'};
    write_new_file_stream(
        $target,
        sub {
            my $out = shift;
            while (1) {
                my $got = sysread( $src, my $buf, 1048576 );
                die "read : $OS_ERROR\n" if not defined $got;
                last                     if $got == 0;
                $ctx->add($buf);
                print {$out} $buf or die "$OS_ERROR\n";
            }
        },
        0444
    );
    close $src;
    fault(qw| convert:after-copy |) if $node->{'link_content'};
    refuse( 'content changed while copying [ %s ]', $source )
        if bmw_b32( $ctx->digest ) ne $addr->{'bmw'};
    $node->{'content_action'} //= qw| copied |;
    return TRUE;
}

## format 1 : content + meta/ ##

sub _v1_write_node {
    my ( $dir, $node ) = @ARG;
    my $addr = $node->{'addr'};

    _write_content( $dir, $node );

    make_dirs( "$dir/meta", 0700 );
    _v1_write_meta( $dir, $_ ) for $node->{'metas'}->@*;
    return TRUE;
}

sub _v1_write_meta {
    my ( $dir, $meta ) = @ARG;
    my $name = sprintf qw| %s.%s.meta |, $meta->{'import_ntime'},
        b32( random_bytes(5) );
    write_new_file( "$dir/meta/$name",
        plain_record_pack( qw| meta |, $meta ) );
    return $name;
}

sub _v1_read_node {
    my $dir = shift;
    my @metas;
    foreach my $name ( _list_dir("$dir/meta") ) {
        next                                        if $name =~ $TMP_RE;
        refuse( 'unexpected meta entry %s', $name ) if $name !~ $META_RE;
        my $rec
            = plain_record_parse( qw| meta |, read_file("$dir/meta/$name") );
        refuse( 'meta %s : record format %d is not node format 1',
            $name, $rec->{'format'} )
            if $rec->{'format'} != 1;
        push @metas, $rec->{'payload'};
    }
    return { qw| content_path | => "$dir/content", qw| metas | => \@metas };
}

## verify-by-path : the path IS the checksum
sub _v1_verify_node {
    my ( $dir,    $addr ) = @ARG;
    my ( $fh,     $st )   = _open_regular("$dir/content");
    my ( $digest, $size ) = bmw384_fh($fh);
    close $fh;
    refuse( 'node %s : content does not match its bmw', $dir )
        if bmw_b32($digest) ne $addr->{'bmw'};
    refuse( 'node %s : bmw does not match its amos', $dir )
        if amos_of_bmw( $addr->{'bmw'} ) ne $addr->{'amos'};

    my $node = _v1_read_node($dir);
    refuse( 'node %s : no meta record', $dir ) if not $node->{'metas'}->@*;
    foreach my $meta ( $node->{'metas'}->@* ) {
        refuse( 'node %s : meta does not describe this content', $dir )
            if ( $meta->{'size'} // -1 ) != $size
            or ( $meta->{'bmw'}  // '' ) ne $addr->{'bmw'}
            or ( $meta->{'amos'} // '' ) ne $addr->{'amos'};
    }
    return $size;
}

register_codec(
    1,
    {   qw| write_node |  => \&_v1_write_node,
        qw| read_node |   => \&_v1_read_node,
        qw| verify_node | => \&_v1_verify_node,
        qw| write_meta |  => \&_v1_write_meta,
    }
);

## format 2 : the delegated store key signs every meta record. the payload is
## bound to disk + epoch + amos + bmw ; verification uses only the public key
## from the parent-signed disk id
sub _v2_id {
    my $context = shift;
    refuse('format 2 : no verified disk identity')
        if ref $context ne qw| HASH |
        or ref $context->{'id'} ne qw| HASH |
        or length( $context->{'id'}{'store_pub'} // '' ) != 32;
    return $context->{'id'};
}

sub _v2_binding {
    my ( $dir, $meta, $addr, $context ) = @ARG;
    my $id   = _v2_id($context);
    my %bind = (
        qw| disk |  => $id->{'disk'},
        qw| epoch | => epoch_b32( $addr->{'epoch'} ),
        qw| amos |  => $addr->{'amos'},
        qw| bmw |   => $addr->{'bmw'},
    );
    foreach my $field ( keys %bind ) {
        refuse( 'node %s : meta %s does not match its location',
            $dir, $field )
            if defined $meta->{$field} and $meta->{$field} ne $bind{$field};
    }
    return %bind;
}

sub _v2_write_meta {
    my ( $dir, $meta, $addr, $context ) = @ARG;
    refuse('format 2 : meta write needs the delegated store key')
        if ref $context ne qw| HASH |
        or not ref $context->{'store'};
    my %bind = _v2_binding( $dir, $meta, $addr, $context );
    my $name = sprintf qw| %s.%s.meta |, $meta->{'import_ntime'},
        b32( random_bytes(5) );
    write_new_file(
        "$dir/meta/$name",
        signed_record_pack(
            qw| meta |, { %{$meta}, %bind },
            $context->{'store'}, 2
        )
    );
    return $name;
}

sub _v2_write_node {
    my ( $dir, $node, $context ) = @ARG;
    my $addr = $node->{'addr'};
    _write_content( $dir, $node );

    make_dirs( "$dir/meta", 0700 );
    _v2_write_meta( $dir, $ARG, $addr, $context ) for $node->{'metas'}->@*;
    return TRUE;
}

sub _v2_read_meta {
    my ( $dir, $name, $addr, $context ) = @ARG;
    my $id    = _v2_id($context);
    my $bytes = read_file("$dir/meta/$name");
    refuse( 'node %s : meta %s is unsigned [ format 2 required ]',
        $dir, $name )
        if not defined $bytes
        or length $bytes < 5
        or substr( $bytes, 0, 5 ) ne "P7FN\x02";

    my $rec = eval { signed_record_parse( qw| meta |, $bytes ) };
    if ( not $rec ) {
        my $err = $EVAL_ERROR // 'invalid record';
        chomp $err;
        $err =~ s|\An7fs : ||;
        refuse( 'node %s : meta %s : %s', $dir, $name, $err );
    }
    refuse( 'node %s : meta %s : signed by a foreign store key', $dir, $name )
        if $rec->{'signer_pub'} ne $id->{'store_pub'};
    refuse( 'node %s : meta %s : store signature does not verify',
        $dir, $name )
        if not verify( $id->{'store_pub'}, $rec->{'signed'}, $rec->{'sig'} );

    my $meta = $rec->{'payload'};
    my %bind = (
        qw| disk |  => $id->{'disk'},
        qw| epoch | => epoch_b32( $addr->{'epoch'} ),
        qw| amos |  => $addr->{'amos'},
        qw| bmw |   => $addr->{'bmw'},
    );
    foreach my $field ( keys %bind ) {
        refuse( 'node %s : meta %s : %s does not match its location',
            $dir, $name, $field )
            if ( $meta->{$field} // '' ) ne $bind{$field};
    }
    return $meta;
}

sub _v2_read_node {
    my ( $dir, $addr, $context ) = @ARG;
    my @metas;
    foreach my $name ( _list_dir("$dir/meta") ) {
        next if $name =~ $TMP_RE;
        refuse( 'node %s : unexpected meta entry %s', $dir, $name )
            if $name !~ $META_RE;
        push @metas, _v2_read_meta( $dir, $name, $addr, $context );
    }
    return { qw| content_path | => "$dir/content", qw| metas | => \@metas };
}

sub _v2_verify_node {
    my ( $dir, $addr, $context ) = @ARG;
    my ( $fh,     $st )   = _open_regular("$dir/content");
    my ( $digest, $size ) = bmw384_fh($fh);
    close $fh;
    refuse( 'node %s : content does not match its bmw', $dir )
        if bmw_b32($digest) ne $addr->{'bmw'};
    refuse( 'node %s : bmw does not match its amos', $dir )
        if amos_of_bmw( $addr->{'bmw'} ) ne $addr->{'amos'};

    my $node = _v2_read_node( $dir, $addr, $context );
    refuse( 'node %s : no meta record', $dir ) if not $node->{'metas'}->@*;
    foreach my $meta ( $node->{'metas'}->@* ) {
        refuse( 'node %s : meta does not describe this content', $dir )
            if ( $meta->{'size'} // -1 ) != $size;
    }
    return $size;
}

register_codec(
    2,
    {   qw| write_node |  => \&_v2_write_node,
        qw| read_node |   => \&_v2_read_node,
        qw| verify_node | => \&_v2_verify_node,
        qw| write_meta |  => \&_v2_write_meta,
    }
);

## format 3 : signed meta remains bound to its node. references and the signed
## journal are checked by the store-set readers below, not by content hashing.
sub _v3_write_meta {
    my ( $dir, $meta, $addr, $context ) = @ARG;
    refuse('format 3 : meta write needs the delegated store key')
        if ref $context ne qw| HASH |
        or not ref $context->{'store'};
    my %bind = _v2_binding( $dir, $meta, $addr, $context );
    my $name = sprintf qw| %s.%s.meta |, $meta->{'import_ntime'},
        b32( random_bytes(5) );
    write_new_file(
        "$dir/meta/$name",
        signed_record_pack(
            qw| meta |, { %{$meta}, %bind },
            $context->{'store'}, 3
        )
    );
    return $name;
}

sub _v3_write_node {
    my ( $dir, $node, $context ) = @ARG;
    my $addr = $node->{'addr'};
    _write_content( $dir, $node );

    make_dirs( "$dir/meta", 0700 );
    _v3_write_meta( $dir, $ARG, $addr, $context ) for $node->{'metas'}->@*;
    return TRUE;
}

sub _v3_read_meta {
    my ( $dir, $name, $addr, $context ) = @ARG;
    my $id    = _v2_id($context);
    my $bytes = read_file("$dir/meta/$name");
    refuse( 'node %s : meta %s is not signed format 3', $dir, $name )
        if not defined $bytes
        or length $bytes < 5
        or substr( $bytes, 0, 5 ) ne "P7FN\x03";
    my $rec     = signed_record_parse( qw| meta |, $bytes );
    my $foreign = $rec->{'signer_pub'} ne $id->{'store_pub'};
    refuse( 'node %s : meta %s : signed by a foreign store key', $dir, $name )
        if $foreign;
    my $verified
        = verify( $id->{'store_pub'}, $rec->{'signed'}, $rec->{'sig'} );
    refuse( 'node %s : meta %s : store signature does not verify',
        $dir, $name )
        if not $verified;
    my $meta = $rec->{'payload'};
    my %bind = (
        qw| disk |  => $id->{'disk'},
        qw| epoch | => epoch_b32( $addr->{'epoch'} ),
        qw| amos |  => $addr->{'amos'},
        qw| bmw |   => $addr->{'bmw'},
    );

    foreach my $field ( keys %bind ) {
        my $located = ( $meta->{$field} // '' ) eq $bind{$field};
        refuse( 'node %s : meta %s : %s does not match its location',
            $dir, $name, $field )
            if not $located;
    }
    return $meta;
}

sub _v3_read_node {
    my ( $dir, $addr, $context ) = @ARG;
    my @metas;
    foreach my $name ( _list_dir("$dir/meta") ) {
        next if $name =~ $TMP_RE;
        refuse( 'node %s : unexpected meta entry %s', $dir, $name )
            if $name !~ $META_RE;
        push @metas, _v3_read_meta( $dir, $name, $addr, $context );
    }
    return { qw| content_path | => "$dir/content", qw| metas | => \@metas };
}

sub _v3_verify_node {
    my ( $dir, $addr, $context ) = @ARG;
    my ( $fh,     $st )   = _open_regular("$dir/content");
    my ( $digest, $size ) = bmw384_fh($fh);
    close $fh;
    refuse( 'node %s : content does not match its bmw', $dir )
        if bmw_b32($digest) ne $addr->{'bmw'};
    refuse( 'node %s : bmw does not match its amos', $dir )
        if amos_of_bmw( $addr->{'bmw'} ) ne $addr->{'amos'};
    my $node = _v3_read_node( $dir, $addr, $context );
    refuse( 'node %s : no meta record', $dir ) if not $node->{'metas'}->@*;

    foreach my $meta ( $node->{'metas'}->@* ) {
        refuse( 'node %s : meta does not describe this content', $dir )
            if ( $meta->{'size'} // -1 ) != $size;
    }
    return $size;
}

register_codec(
    3,
    {   qw| write_node |  => \&_v3_write_node,
        qw| read_node |   => \&_v3_read_node,
        qw| verify_node | => \&_v3_verify_node,
        qw| write_meta |  => \&_v3_write_meta,
    }
);

##[ NODES ]###################################################################

sub node_path {
    my ( $disk_path, $addr ) = @ARG;
    return join '/', $disk_path, epoch_b32( $addr->{'epoch'} ),
        $addr->{'amos'}, $addr->{'bmw'};
}

sub node_verify {
    my ( $disk_path, $addr, $format, $id ) = @ARG;
    return codec($format)->{'verify_node'}
        ->( node_path( $disk_path, $addr ), $addr, { qw| id | => $id } );
}

## every node under the given epochs : [ { epoch amos bmw path } .. ]. an
## entry of the wrong shape refuses [ a reader classifies by shape ]
sub store_nodes {
    my ( $disk_path, @epochs ) = @ARG;
    my @nodes;
    foreach my $epoch (@epochs) {
        my $edir = "$disk_path/" . epoch_b32($epoch);
        next if not -d $edir;
        foreach my $amos ( _list_dir($edir) ) {
            next if $amos =~ $TMP_RE;
            refuse( 'unexpected entry %s/%s', $edir, $amos )
                if $amos !~ $AMOS_RE;
            foreach my $bmw ( _list_dir("$edir/$amos") ) {
                next if $bmw =~ $TMP_RE;
                refuse( 'unexpected entry %s/%s/%s', $edir, $amos, $bmw )
                    if $bmw !~ $BMW_RE;
                push @nodes,
                    {
                    qw| epoch | => $epoch,
                    qw| amos |  => $amos,
                    qw| bmw |   => $bmw,
                    qw| path |  => "$edir/$amos/$bmw",
                    };
            }
        }
    }
    return @nodes;
}

sub _checked_state {
    my %opt   = @ARG;
    my $id    = disk_read_id(%opt);
    my $state = state_read( $id->{'path'}, $id->{'store_pub'} );
    if ( ref $opt{'host'} ) {
        witness_check_format( %opt, qw| id | => $id, qw| state | => $state );
        if ( $state->{'store_format'} == 3 ) {
            my $head = journal_head($id);
            witness_check_journal(
                %opt,
                qw| id |          => $id,
                qw| journal_seq | => $head->{'seq'}
            );
            $id->{'journal_seq'}      = $head->{'seq'};
            $id->{'journal_baseline'} = $head->{'baseline'};
        }
    }
    return ( $id, $state );
}

## every meta record of the active epochs as plain hashes. the codec reader
## applies the record checks ; content verification stays with node_verify
sub meta_entries {
    my %opt = @ARG;
    my ( $id, $state ) = _checked_state(%opt);
    my $codec = codec( $state->{'store_format'} );
    my @entries;

    foreach my $node ( store_nodes( $id->{'path'}, $state->{'epochs'}->@* ) )
    {
        my $read = $codec->{'read_node'}
            ->( $node->{'path'}, $node, { qw| id | => $id } );
        foreach my $meta ( $read->{'metas'}->@* ) {
            refuse( 'node %s : meta address does not match', $node->{'path'} )
                if ( $meta->{'amos'} // '' ) ne $node->{'amos'}
                or ( $meta->{'bmw'} // '' ) ne $node->{'bmw'};
            refuse( 'node %s : meta has no import ntime', $node->{'path'} )
                if ( $meta->{'import_ntime'} // '' ) !~ m|\A\d{14}\z|;
            push @entries,
                {
                %{$meta},
                qw| epoch |   => $node->{'epoch'},
                qw| amos |    => $node->{'amos'},
                qw| bmw |     => $node->{'bmw'},
                qw| address | => join( '/',
                    epoch_b32( $node->{'epoch'} ), $node->{'amos'},
                    $node->{'bmw'} ),
                qw| node_path | => $node->{'path'},
                };
        }
    }
    return @entries;
}

sub _key { return join "\0", @ARG }

sub _ref_operation {
    my $ref = shift;
    return {
        ( map { $ARG => $ref->{$ARG} } qw| node path holder name | ),
        $ref->{'origin'} ? ( qw| origin | => $ref->{'origin'} ) : (),
    };
}

sub _format3_compare {
    my ( $id, $state, $replay ) = @ARG;
    my @nodes = store_nodes( $id->{'path'}, $state->{'epochs'}->@* );
    my ( %nodes, %metas, %refs, %drops );
    my ( %expected_meta, %expected_ref );
    push $expected_meta{ $ARG->{'node'} }->@*, $ARG
        for values $replay->{'metas'}->%*;
    push $expected_ref{ $ARG->{'node'} }->@*, $ARG
        for values $replay->{'references'}->%*;
    foreach my $node (@nodes) {
        my $addr = reference_address($node);
        foreach my $meta ( $expected_meta{$addr}->@* ) {
            refuse( 'format 3 : missing meta %s %s', $addr, $meta->{'name'} )
                if not -f "$node->{'path'}/meta/$meta->{'name'}";
        }
        foreach my $ref ( $expected_ref{$addr}->@* ) {
            refuse( 'format 3 : missing reference %s %s',
                $addr, $ref->{'path'} )
                if not -f "$node->{'path'}/references/$ref->{'path'}";
            my $drop = $ref->{'path'} =~ s|/addr\z|/drop|r;
            refuse( 'format 3 : missing drop %s %s', $addr, $drop )
                if $ref->{'dropped'}
                and not -f "$node->{'path'}/references/$drop";
        }
        node_verify( $id->{'path'}, $node, 3, $id );
        $nodes{$addr} = $node;
        foreach my $name ( _list_dir("$node->{'path'}/meta") ) {
            next if $name =~ $TMP_RE;
            $metas{ _key( $addr, $name ) }
                = { qw| node | => $addr, qw| name | => $name };
        }
        foreach my $ref ( reference_scan( $node, $id ) ) {
            my $key = _key( $addr, $ref->{'path'} );
            $refs{$key}  = $ref;
            $drops{$key} = $ref if $ref->{'dropped'};
        }
    }

    my ( @missing, @extra );
    foreach my $addr ( sort keys $replay->{'nodes'}->%* ) {
        push @missing, { qw| type | => 'node', qw| node | => $addr }
            if not $nodes{$addr};
    }
    foreach my $key ( sort keys $replay->{'metas'}->%* ) {
        push @missing, { qw| type | => 'meta', $replay->{'metas'}{$key}->%* }
            if not $metas{$key};
    }
    foreach my $key ( sort keys $replay->{'references'}->%* ) {
        my $expected = $replay->{'references'}{$key};
        push @missing,
            { qw| type | => 'reference', _ref_operation($expected)->%* }
            if not $refs{$key};
        push @missing, { qw| type | => 'drop', _ref_operation($expected)->%* }
            if $expected->{'dropped'} and not $drops{$key};
    }
    foreach my $addr ( sort keys %nodes ) {
        push @extra, { qw| type | => 'node', qw| node | => $addr }
            if not $replay->{'nodes'}{$addr};
    }
    foreach my $key ( sort keys %metas ) {
        push @extra, { qw| type | => 'meta', $metas{$key}->%* }
            if not $replay->{'metas'}{$key};
    }
    foreach my $key ( sort keys %refs ) {
        push @extra,
            {
            qw| type | => 'reference',
            _ref_operation( $refs{$key} )->%*,
            qw| record | => $refs{$key},
            }
            if not $replay->{'references'}{$key};
    }
    foreach my $key ( sort keys %drops ) {
        push @extra,
            {
            qw| type | => 'drop',
            _ref_operation( $drops{$key} )->%*,
            qw| record | => $drops{$key},
            }
            if not $replay->{'references'}{$key}
            or not $replay->{'references'}{$key}{'dropped'};
    }
    return {
        qw| missing | => \@missing,
        qw| extra |   => \@extra,
        qw| nodes |   => \%nodes,
        qw| refs |    => \%refs,
    };
}

sub _set_item_name {
    my $item = shift;
    return $item->{'node'} . ' '
        . ( $item->{'path'} // $item->{'name'} // '' );
}

## verifies every node and the complete signed store-set assertion in format 3
sub store_verify {
    my %opt  = @ARG;
    my $lock = disk_lock( disk_read_id(%opt), qw| shared | );
    my ( $id, $state ) = _checked_state(%opt);
    if ( $state->{'store_format'} != 3 ) {
        my @nodes = store_nodes( $id->{'path'}, $state->{'epochs'}->@* );
        node_verify( $id->{'path'}, $ARG, $state->{'store_format'}, $id )
            for @nodes;
        return { qw| nodes | => scalar @nodes, qw| state | => $state };
    }
    my $replay = journal_replay($id);
    require AMOS7::N7FS::Release;
    AMOS7::N7FS::Release::tombstone_verify( $id, $replay );
    my $cmp = _format3_compare( $id, $state, $replay );
    foreach my $address ( sort keys $replay->{'released'}->%* ) {
        refuse(
            'format 3 : released node still present %s [ n7fs repair %s ]',
            $address, $id->{'disk'} )
            if $cmp->{'nodes'}{$address};
    }
    if ( $cmp->{'missing'}->@* ) {
        my $item = $cmp->{'missing'}[0];
        refuse( 'format 3 : missing %s %s',
            $item->{'type'}, _set_item_name($item) );
    }
    if ( $cmp->{'extra'}->@* ) {
        my $item = $cmp->{'extra'}[0];
        refuse(
            'format 3 : unlisted %s %s [ unjournaled data from '
                . 'a crash or injection ; explicit repair is required ]',
            $item->{'type'}, _set_item_name($item)
        );
    }
    require AMOS7::N7FS::Tree;
    require AMOS7::N7FS::Category;
    my $trees
        = AMOS7::N7FS::Tree::tree_records_verify( $id, $state, $replay );
    my ( $categories, $assignments, $batches )
        = AMOS7::N7FS::Category::category_records_verify( $id, $replay );
    require AMOS7::N7FS::Sync;
    my ( $cursors, $conflicts )
        = AMOS7::N7FS::Sync::sync_records_verify( $id, $replay );
    return {
        qw| nodes | =>
            scalar store_nodes( $id->{'path'}, $state->{'epochs'}->@* ),
        qw| state |       => $state,
        qw| journal |     => $replay,
        qw| trees |       => $trees,
        qw| categories |  => $categories,
        qw| assignments | => $assignments,
        qw| batches |     => $batches,
    };
}

## references joined to their import meta. this replays the journal and scans
## signed meta and reference records, but does not hash content nodes.
sub reference_entries {
    my %opt  = @ARG;
    my $lock = disk_lock( disk_read_id(%opt), qw| shared | );
    my ( $id, $state ) = _checked_state(%opt);
    return () if $state->{'store_format'} != 3;
    my $replay = journal_replay($id);
    my %refs;
    foreach my $node ( store_nodes( $id->{'path'}, $state->{'epochs'}->@* ) )
    {
        refuse( 'format 3 : released node still present %s', $node->{'path'} )
            if $replay->{'released'}{ reference_address($node) };
        foreach my $ref ( reference_scan( $node, $id ) ) {
            my $key = _key( $ref->{'node'}, $ref->{'path'} );
            refuse( 'format 3 : unlisted reference %s', $ref->{'path'} )
                if not $replay->{'references'}{$key};
            my $expected = $replay->{'references'}{$key};
            refuse( 'format 3 : reference origin differs from journal %s',
                $ref->{'path'} )
                if ( $ref->{'origin'}{'id'} // $ref->{'path'} ) ne
                ( $expected->{'origin'}{'id'}   // $expected->{'path'} )
                or ( $ref->{'origin'}{'disk'}   // $id->{'disk'} ) ne
                ( $expected->{'origin'}{'disk'} // $id->{'disk'} );
            refuse( 'format 3 : unlisted drop %s', $ref->{'path'} )
                if $ref->{'dropped'} and not $expected->{'dropped'};
            refuse( 'format 3 : missing drop %s', $ref->{'path'} )
                if not $ref->{'dropped'} and $expected->{'dropped'};
            $refs{$key} = $ref;
        }
    }
    foreach my $key ( sort keys $replay->{'references'}->%* ) {
        refuse(
            'format 3 : missing reference %s',
            $replay->{'references'}{$key}{'path'}
        ) if not $refs{$key};
    }

    my @meta = meta_entries(%opt);
    my @out;
    foreach my $key ( sort keys $replay->{'ref_history'}->%* ) {
        my $history = $replay->{'ref_history'}{$key};
        my $ref     = $refs{$key} // $history;
        my @history = grep {
            $ARG->{'address'} eq $ref->{'node'}
                and ( $ARG->{'source'} // '' ) eq $ref->{'holder'}
        } @meta;
        if ( not @history and $history->{'released'} ) {
            @history = {
                qw| address |      => $ref->{'node'},
                qw| source |       => $ref->{'holder'},
                qw| name |         => $ref->{'name'},
                qw| import_ntime | => $ref->{'ntime'},
                qw| released |     => TRUE,
            };
        }
        refuse( 'format 3 : missing meta for reference %s', $ref->{'path'} )
            if not @history;
        @history
            = sort { $a->{'import_ntime'} cmp $b->{'import_ntime'} } @history;
        push @out,
            {
            %{$ref},
            qw| released | => $history->{'released'} ? TRUE : FALSE,
            qw| meta |     => \@history
            };
    }
    return @out;
}

## below this many references of one category, single records stay ##
our $BATCH_MIN = 16;

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

sub _quarantine_unjournaled_records {
    my ( $id, $replay ) = @ARG;
    require AMOS7::N7FS::Record;
    my @quarantined;
    my @kinds = (
        [ qw| tree |,      qw| trees |,      qw| tree |, 'tree_history' ],
        [ qw| tree_drop |, qw| tree-drops |, qw| tree-drop |, 'tree_drops' ],
        [   qw| category |,
            qw| categories |,
            qw| category |,
            'category_history'
        ],
        [   qw| assignment |,
            qw| assignments |,
            qw| assignment |,
            'assignment_history'
        ],
        [   qw| batch |,
            qw| batch-assignments |,
            qw| batch-assignment |,
            'batch_history'
        ],
        [   qw| sync_cursor |,
            qw| sync-cursors |,
            qw| sync-cursor |,
            'sync_cursor_history'
        ],
        [   qw| sync_conflict |,
            qw| sync-conflicts |,
            qw| sync-conflict |,
            'sync_conflict_history'
        ],
    );
    foreach my $kind (@kinds) {
        my ( $record_kind, $subdir, $suffix, $expected ) = @{$kind};
        foreach my $record (
            AMOS7::N7FS::Record::record_scan(
                $id, $record_kind, $subdir, $suffix
            )
        ) {
            next if $replay->{$expected}{ $record->{'path'} };
            my $destination_dir = "$id->{'path'}/.n7fs/quarantine/$subdir";
            make_dirs( $destination_dir, 0700 );
            my $destination = "$destination_dir/$record->{'path'}";
            refuse( 'repair : quarantine target exists [ %s ]', $destination )
                if -e $destination or -l $destination;
            rename $record->{'full_path'},
                $destination
                or refuse( 'repair : cannot quarantine %s : %s',
                $record->{'path'}, $OS_ERROR );
            push @quarantined,
                {
                qw| type |       => $record_kind,
                qw| path |       => $record->{'path'},
                qw| quarantine | => $destination
                };
        }
    }
    return \@quarantined;
}

sub store_repair {
    my %opt   = @ARG;
    my $lock  = disk_lock( disk_read_id(%opt) );
    my $id    = disk_require_attached(%opt);
    my $store = store_key_signer( %opt, qw| id | => $id );
    my $state = state_read( $id->{'path'}, $id->{'store_pub'} );
    refuse('repair is only available for store format 3')
        if $state->{'store_format'} != 3;
    my $replay = journal_replay($id);
    require AMOS7::N7FS::Release;
    my $finished
        = AMOS7::N7FS::Release::release_repair( $id, $state, $replay );
    return {
        qw| adopted |  => [],
        qw| finished | => $finished,
        qw| seq |      => $replay->{'seq'}
        }
        if $finished->@*;
    my $quarantined = _quarantine_unjournaled_records( $id, $replay );
    my $cmp         = _format3_compare( $id, $state, $replay );

    if ( $cmp->{'missing'}->@* ) {
        my $item = $cmp->{'missing'}[0];
        refuse( 'repair : missing %s %s cannot be adopted',
            $item->{'type'}, _set_item_name($item) );
    }
    return {
        qw| adopted |     => [],
        qw| seq |         => $replay->{'seq'},
        qw| quarantined | => $quarantined
        }
        if not $cmp->{'extra'}->@*;

    my $add  = _empty_set();
    my $drop = _empty_set();
    foreach my $item ( $cmp->{'extra'}->@* ) {
        if ( $item->{'type'} eq qw| node | ) {
            push $add->{'nodes'}->@*, $item->{'node'};
        } elsif ( $item->{'type'} eq qw| meta | ) {
            push $add->{'meta'}->@*,
                {
                qw| node | => $item->{'node'},
                qw| name | => $item->{'name'}
                };
        } elsif ( $item->{'type'} eq qw| reference | ) {
            push $add->{'references'}->@*, _ref_operation($item);
        } elsif ( $item->{'type'} eq qw| drop | ) {
            push $drop->{'references'}->@*, _ref_operation($item);
        }
    }
    my %flags = ( qw| repaired | => TRUE );
    $flags{'baseline'} = TRUE
        if $replay->{'seq'} == 0 and ref $state->{'previous'} eq qw| HASH |;
    my $journal = journal_write( $id, $store, $add, $drop, \%flags );
    witness_note_format(
        %opt,
        qw| id |          => $id,
        qw| state |       => $state,
        qw| journal_seq | => $journal->{'seq'}
    );
    return {
        qw| adopted |     => $cmp->{'extra'},
        qw| seq |         => $journal->{'seq'},
        qw| journal |     => $journal,
        qw| quarantined | => $quarantined,
    };
}

sub reference_drop {
    my %opt    = @ARG;
    my $target = $opt{'address'} // '';
    refuse('drop needs a canonical node address') if $target !~ $ADDR_RE;
    refuse('drop needs a holder') if not length( $opt{'holder'} // '' );
    my $lock  = disk_lock( disk_read_id(%opt) );
    my $id    = disk_require_attached(%opt);
    my $store = store_key_signer( %opt, qw| id | => $id );
    my $state = state_read( $id->{'path'}, $id->{'store_pub'} );
    refuse('drop is only available for store format 3')
        if $state->{'store_format'} != 3;
    my $replay = journal_replay($id);
    my ($node)
        = grep { reference_address($ARG) eq $target }
        store_nodes( $id->{'path'}, $state->{'epochs'}->@* );
    refuse( 'drop : unknown node %s', $target ) if not defined $node;
    my @refs = grep { $ARG->{'holder'} eq $opt{'holder'} }
        reference_scan( $node, $id );
    refuse( 'drop : unknown reference [ %s, %s ]', $target, $opt{'holder'} )
        if not @refs;
    my @live = grep { not $ARG->{'dropped'} } @refs;
    refuse( 'drop : reference is not live [ %s, %s ]',
        $target, $opt{'holder'} )
        if not @live;
    refuse( 'drop : several live references [ %s, %s ]',
        $target, $opt{'holder'} )
        if @live > 1;
    my $ref = $live[0];
    my $key = _key( $target, $ref->{'path'} );
    refuse( 'drop : reference is not live in the journal [ %s ]',
        $ref->{'path'} )
        if not $replay->{'references'}{$key}
        or $replay->{'references'}{$key}{'dropped'};

    reference_drop_write( $ref, $id, $store );
    fault(qw| drop:after-record |);
    my $add  = _empty_set();
    my $drop = _empty_set();
    push $drop->{'references'}->@*, _ref_operation($ref);
    my $journal = journal_write( $id, $store, $add, $drop, {} );
    witness_note_format(
        %opt,
        qw| id |          => $id,
        qw| state |       => $state,
        qw| journal_seq | => $journal->{'seq'}
    );
    return { qw| reference | => $ref, qw| seq | => $journal->{'seq'} };
}

## the epoch new content goes to : the current one, never older than the
## newest active epoch [ after a conversion into a later epoch ]
sub write_epoch {
    my $state = shift;
    my $epoch = epoch_int( ntime_now() );
    foreach my $active ( $state->{'epochs'}->@* ) {
        $epoch = $active if $active > $epoch;
    }
    refuse( 'epoch %d belongs to the previous store format', $epoch )
        if ref $state->{'previous'} eq qw| HASH |
        and grep { $ARG == $epoch } $state->{'previous'}{'epochs'}->@*;
    return $epoch;
}

##[ SOURCES ]#################################################################

## the invoke-web image index as a source list
## [ sources table of invoke-web.index.db ] : opened READ-ONLY, every row is
## untrusted -- rows without a checksum [ missing on disk ] are reported and
## skipped
sub index_sources {
    my $db = shift // refuse('no index path');
    refuse( 'index %s is not a file', $db ) if not -f $db;
    require DBI;
    require DBD::SQLite;
    my $dbh = DBI->connect(
        "dbi:SQLite:dbname=$db",
        '', '',
        {   qw| RaiseError |        => 0,
            qw| PrintError |        => 0,
            qw| sqlite_open_flags | => DBD::SQLite::OPEN_READONLY(),
        }
    ) or refuse( 'cannot open index %s : %s', $db, DBI->errstr // q{?} );
    my $rows
        = $dbh->selectall_arrayref(
        'SELECT image_name, chksum, path FROM sources ORDER BY rowid')
        or refuse( 'index %s : no sources table [ %s ]', $db, $dbh->errstr );
    $dbh->disconnect;

    my ( @items, @skipped );
    foreach my $row ( @{$rows} ) {
        my ( $name, $chksum, $path ) = @{$row};
        if ( not defined $chksum or not length $chksum ) {
            push @skipped,
                {
                qw| source | => $path // $name,
                qw| why |    => 'index : no checksum [ missing on disk ]'
                };
        } elsif ( not defined $path or index( $path, '/' ) != 0 ) {
            push @skipped,
                {
                qw| source | => $path // $name,
                qw| why |    => 'index : not an absolute path'
                };
        } else {
            push @items,
                {
                qw| path |         => $path,
                qw| index_chksum | => $chksum,
                qw| index_name |   => $name
                };
        }
    }
    return ( \@items, \@skipped );
}

## files and directories [ recursive, symlinks never followed ] -> items
sub _walk {
    my ( $path, $items, $skipped ) = @ARG;
    my @st = lstat $path;
    if ( not @st ) {
        push @{$skipped}, { qw| source | => $path, qw| why | => "$OS_ERROR" };
    } elsif ( -l _ ) {
        push @{$skipped}, { qw| source | => $path, qw| why | => 'symlink' };
    } elsif ( -d _ ) {
        my @names;
        my $read = eval { @names = _list_dir($path); 1 };
        if ( not $read ) {
            push @{$skipped},
                {
                qw| source | => $path,
                qw| why |    => 'unreadable directory'
                };
        } else {
            _walk( "$path/$ARG", $items, $skipped ) for @names;
        }
    } elsif ( -f _ ) {
        push @{$items}, { qw| path | => $path };
    } else {
        push @{$skipped},
            { qw| source | => $path, qw| why | => 'not a regular file' };
    }
    return;
}

sub _file_format {
    my ( $path, $fh ) = @ARG;
    sysseek( $fh, 0, 0 );
    sysread( $fh, my $head, 16 );
    sysseek( $fh, 0, 0 );
    $head //= '';
    return qw| png |  if $head =~ m|\A\x89PNG\r\n\x1a\n|;
    return qw| jpeg | if $head =~ m|\A\xff\xd8\xff|;
    return qw| gif |  if $head =~ m|\AGIF8[79]a|;
    return qw| webp | if $head =~ m|\ARIFF....WEBP|s;
    return qw| pdf |  if $head =~ m|\A%PDF-|;
    return lc $1      if $path =~ m|\.([A-Za-z0-9]{1,8})\z|;
    return qw| unknown |;
}

##[ ASSIMILATE ]##############################################################

## %opt : disk, root, host_dir, host [ signer ], paths [ list ] or index
## [ db path ] + index_base [ dir ], remove, keep, dry_run, protect
## [ key file paths never taken ]. returns the report [ one entry per source ]
## ; ->{'failed'} counts failures
sub assimilate {
    my %opt = @ARG;
    refuse('keep and remove exclude each other')
        if $opt{'keep'} and $opt{'remove'};
    refuse('assimilate : -prune needs -remove')
        if $opt{'prune'} and not $opt{'remove'};
    my $remove = $opt{'remove'} ? TRUE : FALSE;

    ## index rows are untrusted : removal only below a named base ##
    refuse(   'index + remove needs an index base [ '
            . '-index-base <dir> ] : index rows are untrusted' )
        if $remove
        and defined $opt{'index'}
        and not defined $opt{'index_base'};
    my $index_base;
    if ( defined $opt{'index_base'} ) {
        $index_base = abs_path( $opt{'index_base'} );
        refuse( 'index base %s is not a directory', $opt{'index_base'} )
            if not defined $index_base
            or not -d $index_base;
    }

    my $id    = disk_require_attached(%opt);
    my $store = store_key_signer( %opt, qw| id | => $id );
    my $state = state_read( $id->{'path'}, $id->{'store_pub'} );
    my $lock  = $opt{'dry_run'} ? undef : disk_lock($id);
    $state = state_read( $id->{'path'}, $id->{'store_pub'} );
    my $codec   = codec( $state->{'store_format'} );
    my $epoch   = write_epoch($state);
    my $context = { qw| id | => $id, qw| store | => $store };
    my $replay
        = $state->{'store_format'} == 3
        ? journal_replay($id)
        : undef;
    my $new_records = (
               defined $opt{'tree'}
            or defined $opt{'category'}
            or ( $opt{'category_rules'} // [] )->@*
    );
    refuse('trees and categories are only available for store format 3')
        if $new_records and $state->{'store_format'} != 3;
    refuse('assimilate : -tree needs exactly one directory path and no index')
        if defined $opt{'tree'}
        and ( ( $opt{'paths'} // [] )->@* != 1 or defined $opt{'index'} );

    if ( defined $opt{'tree'} ) {
        refuse( 'tree : bad tree name [ %s ]', $opt{'tree'} )
            if $opt{'tree'} !~ m|\A[^\x00/]+\z|;
        refuse( 'tree : duplicate live tree [ %s ]', $opt{'tree'} )
            if $replay->{'trees'}{ $opt{'tree'} };
        my @root = lstat $opt{'paths'}[0];
        refuse( 'tree root %s is not a directory', $opt{'paths'}[0] )
            if not @root
            or -l _
            or not -d _;
    }
    my $category_chooser;
    if ($new_records) {
        require AMOS7::N7FS::Category;
        $category_chooser
            = AMOS7::N7FS::Category::category_assignment_plan( $id, $replay,
            \%opt );
    }

    my ( @items, @skipped );
    if ( defined $opt{'index'} ) {
        my ( $i, $s ) = index_sources( $opt{'index'} );
        foreach my $item ( @{$i} ) {
            my $abs = abs_path( $item->{'path'} ) // $item->{'path'};
            if ( defined $index_base
                and index( $abs, "$index_base/" ) != 0 ) {
                push @skipped,
                    {
                    qw| source | => $item->{'path'},
                    qw| why |    => 'index : outside the index base'
                    };
                next;
            }
            push @items, $item;
        }
        push @skipped, @{$s};
    }
    _walk( $ARG, \@items, \@skipped ) for ( $opt{'paths'} // [] )->@*;
    my @prune_roots;
    if ( $opt{'prune'} ) {
        foreach my $path ( ( $opt{'paths'} // [] )->@*, $index_base ) {
            next if not defined $path;
            my @st = lstat $path;
            next if not @st or -l _ or not -d _;
            push @prune_roots, abs_path($path) // $path;
        }
    }

    ## never the store into itself, never the host side [ keys, witness : a ##
    ## holder must not get the store key, a removal must not reset the use  ##
    ## window ]                                                             ##
    my @protect = map { abs_path($ARG) // $ARG } root_dir(%opt),
        host_dir(%opt), ( $opt{'protect'} // [] )->@*;
    @items = grep {
        my $abs = abs_path( $ARG->{'path'} ) // $ARG->{'path'};
        my ($hit)
            = grep { $abs eq $ARG or index( $abs, "$ARG/" ) == 0 } @protect;
        push @skipped,
            {
            qw| source | => $ARG->{'path'},
            qw| why |    => "protected [ $hit ]"
            }
            if defined $hit;
        not defined $hit;
    } @items;

    my %report = (
        qw| disk |    => $id->{'disk'},
        qw| epoch |   => $epoch,
        qw| entries | => [
            map {
                { %{$ARG}, qw| status | => qw| skipped | }
            } @skipped
        ],
        qw| failed |  => 0,
        qw| dry_run | => $opt{'dry_run'} ? TRUE : FALSE,
    );

    foreach my $item (@items) {
        my %entry = ( qw| source | => $item->{'path'} );
        my $tmp;
        my $ok = eval {
            _assimilate_one(
                \%opt, $id,     $state, $codec,  $context, $epoch,
                $item, \%entry, \$tmp,  $remove, $replay
            );
            1;
        };
        if ( not $ok ) {
            my $err = $EVAL_ERROR;
            chomp $err;
            remove_tree($tmp) if defined $tmp;
            %entry = (
                %entry,
                qw| status | => qw| failed |,
                qw| why |    => $err
            );
            $report{'failed'}++;
        }
        push $report{'entries'}->@*, \%entry;
        $state = state_read( $id->{'path'}, $id->{'store_pub'} )
            if not $opt{'dry_run'};
    }

    if ( $state->{'store_format'} == 3 and not $opt{'dry_run'} ) {
        my $add  = _empty_set();
        my $drop = _empty_set();
        my @new_refs;
        foreach my $entry ( $report{'entries'}->@* ) {
            next
                if not $entry->{'verified'}
                or $entry->{'status'} eq qw| failed |;
            push $add->{'nodes'}->@*, $entry->{'addr'}
                if $entry->{'_new_node'};
            push $add->{'meta'}->@*,
                {
                qw| node | => $entry->{'addr'},
                qw| name | => $entry->{'_meta_name'}
                }
                if $entry->{'_meta_name'};
            push $add->{'references'}->@*,
                _ref_operation( $entry->{'_reference'} )
                if $entry->{'_reference'};
            push @new_refs, $entry->{'_reference'}
                if $entry->{'_reference'};
        }
        if (defined $category_chooser
            and ( defined $opt{'category'}
                or ( $opt{'category_rules'} // [] )->@* )
        ) {
            ## a pool import never pulls a sorted reference back ##
            my $to_pool = ( ( $opt{'category'} // '' ) eq qw| incoming |
                    and not @{ $opt{'category_rules'} // [] } );
            my %live;
            foreach my $key ( keys $replay->{'references'}->%* ) {
                my $ref = $replay->{'references'}{$key};
                ## references added by this run carry no holder here ##
                next if $ref->{'dropped'} or not defined $ref->{'holder'};
                next if $to_pool and $replay->{'assignments'}{$key};
                push $live{"$ref->{'node'}\0$ref->{'holder'}"}->@*, $ref;
            }
            foreach my $entry ( $report{'entries'}->@* ) {
                next
                    if not $entry->{'verified'}
                    or $entry->{'_reference'}
                    or not defined $entry->{'addr'};
                push @new_refs,
                    ( $live{"$entry->{'addr'}\0$entry->{'source'}"} // [] )
                    ->@*;
            }
        }
        my $records_ok = eval {
            if ( defined $opt{'tree'} ) {
                require AMOS7::N7FS::Tree;
                my $created
                    = AMOS7::N7FS::Tree::tree_create( $id, $store, $state,
                    $replay, $opt{'paths'}[0], $opt{'tree'}, \%report,
                    $opt{'snapshot'} );
                push $add->{'nodes'}->@*, $created->{'address'}
                    if $created->{'new_node'};
                push $add->{'meta'}->@*,
                    {
                    qw| node | => $created->{'address'},
                    qw| name | => $created->{'meta_name'}
                    }
                    if $created->{'meta_name'};
                push $add->{'trees'}->@*,
                    {
                    qw| name |       => $created->{'record'}{'name'},
                    qw| path |       => $created->{'record'}{'path'},
                    qw| manifest |   => $created->{'address'},
                    qw| created |    => $created->{'record'}{'created'},
                    qw| references | => $created->{'record'}{'references'}
                    };
                $report{'tree'} = $created;
                $report{'failed'} += $created->{'skipped_errors'};
                $report{'failed'} += $created->{'xattr_errors'};
            }
            if ( defined $category_chooser and @new_refs ) {
                ## one signed batch per category instead of one record per ##
                ## reference : 100000 records took hours on a large import ##
                my %by_category;
                push $by_category{ $category_chooser->( $ARG->{'holder'} ) }
                    ->@*, $ARG
                    for @new_refs;
                my @single;
                foreach my $category ( sort keys %by_category ) {
                    my $refs = $by_category{$category};
                    if ( @{$refs} < $BATCH_MIN ) {
                        push @single, @{$refs};
                        next;
                    }
                    require AMOS7::N7FS::Batch;
                    my $record
                        = AMOS7::N7FS::Batch::batch_write( $id, $store,
                        $category, $refs, 0 );
                    push $add->{'batches'}->@*,
                        {
                        qw| path |     => $record->{'path'},
                        qw| category | => $category
                        };
                }
                $add->{'assignments'}
                    = AMOS7::N7FS::Category::category_assignments( $id,
                    $store, \@single, $category_chooser )
                    if @single;
            }
            1;
        };
        if ( not $records_ok ) {
            my $err = $EVAL_ERROR;
            if (   $add->{'nodes'}->@*
                or $add->{'meta'}->@*
                or $add->{'references'}->@*
                or $add->{'trees'}->@* ) {
                my $journal = journal_write( $id, $store, $add, $drop, {} );
                witness_note_format(
                    %opt,
                    qw| id |          => $id,
                    qw| state |       => $state,
                    qw| journal_seq | => $journal->{'seq'}
                );
            }
            die $err;
        }
        if (   $add->{'nodes'}->@*
            or $add->{'meta'}->@*
            or $add->{'references'}->@*
            or $add->{'trees'}->@*
            or $add->{'assignments'}->@* ) {
            my $journal = journal_write( $id, $store, $add, $drop, {} );
            $report{'journal_seq'} = $journal->{'seq'};
            witness_note_format(
                %opt,
                qw| id |          => $id,
                qw| state |       => $state,
                qw| journal_seq | => $journal->{'seq'}
            );
        }
        foreach my $entry ( $report{'entries'}->@* ) {
            next if not $entry->{'_remove_stat'};
            my $ok = eval { _remove_source($entry); 1 };
            next if $ok;
            my $err = $EVAL_ERROR;
            chomp $err;
            $entry->{'status'} = qw| failed |;
            $entry->{'why'}    = $err;
            $report{'failed'}++;
        }
    }
    if ( $opt{'prune'} ) {
        my %removed;
        my @emptied;
        foreach my $entry ( $report{'entries'}->@* ) {
            my $then = $entry->{'then'} // '';
            next
                if $then ne
                ( $opt{'dry_run'} ? qw| would-remove | : qw| removed | );
            my $file = abs_path( $entry->{'source'} =~ s|/[^/]+\z||r );
            next if not defined $file;
            my ($name) = $entry->{'source'} =~ m|([^/]+)\z|;
            $removed{"$file/$name"} = TRUE;
            push @emptied, $file;
        }
        $report{'pruned'}
            = _prune_roots( \@prune_roots, \@emptied, \%removed,
            $opt{'dry_run'} );
    }
    return \%report;
}

## only directories this run emptied : the parents of removed sources, walking
## upward strictly below a named root. named roots, nested named roots,
## symlinks and directories that were already empty or still hold anything are
## kept. a crash mid-prune leaves only empty directories, which a retry no
## longer knows as its own. dry-run treats the files that would be removed as
## absent
sub _prune_roots {
    my ( $roots, $emptied, $removed, $dry_run ) = @ARG;
    my %keep = map { $ARG => TRUE } @{$roots};
    my %candidate;
    foreach my $dir ( @{$emptied} ) {
        my $path = $dir;
        while ( not $keep{$path}
            and grep { index( $path, "$ARG/" ) == 0 } @{$roots} ) {
            $candidate{$path} = TRUE;
            last if $path !~ s|/[^/]+\z||;
        }
    }
    my @pruned;
    my %gone = %{$removed};

    ## deepest first, so a parent is tried after its emptied children
    foreach my $path (
        sort { ( $b =~ tr|/|| ) <=> ( $a =~ tr|/|| ) or $a cmp $b }
        keys %candidate
    ) {
        my @st = lstat $path;
        next if not @st or -l _ or not -d _;
        if ($dry_run) {
            opendir( my $dh, $path )
                or refuse( 'cannot read %s : %s', $path, $OS_ERROR );
            my @left = grep {
                        $ARG ne '.'
                    and $ARG ne '..'
                    and not $gone{"$path/$ARG"}
            } readdir $dh;
            closedir $dh;
            next if @left;
            $gone{$path} = TRUE;
            push @pruned, $path;
            next;
        }
        fault( 'assimilate:before-prune', $path );
        next if not rmdir $path;
        push @pruned, $path;
        fault( 'assimilate:after-prune', $path );
    }
    return \@pruned;
}

## newest record of this source : duplicates share a node, each keeps its own
sub _newest_meta {
    my ( $codec, $dir, $source, $addr, $context ) = @ARG;
    my $node = $codec->{'read_node'}->( $dir, $addr, $context );
    my $newest;
    foreach my $meta ( $node->{'metas'}->@* ) {
        next if ( $meta->{'source'} // '' ) ne ( $source // '' );
        $newest = $meta
            if not defined $newest
            or ( $meta->{'import_ntime'} // '' ) gt $newest->{'import_ntime'};
    }
    return $newest;
}

sub _meta_unchanged {
    my ( $old, $new ) = @ARG;
    return FALSE if not defined $old;
    foreach my $field (qw| name source format |) {
        return FALSE if ( $old->{$field} // '' ) ne ( $new->{$field} // '' );
    }
    foreach my $field (qw| size mtime |) {
        return FALSE
            if not defined $old->{$field}
            or $old->{$field} != $new->{$field};
    }
    foreach my $field (qw| index_chksum index_name |) {
        return FALSE if defined $old->{$field} != defined $new->{$field};
        return FALSE
            if defined $old->{$field}
            and $old->{$field} ne $new->{$field};
    }
    return TRUE;
}

sub _assimilate_one {
    my ($opt,  $id,    $state,   $codec,  $context, $epoch,
        $item, $entry, $tmp_ref, $remove, $replay
    ) = @ARG;
    my $path = $item->{'path'};

    ## pass 1 : identity + content hash of the source ##
    my @lst = lstat $path or refuse( '%s : %s', $path, $OS_ERROR );
    refuse( '%s : symlink', $path ) if -l _;
    my ( $fh, $st ) = _open_regular($path);
    refuse( '%s : replaced while opening', $path )
        if $st->[0] != $lst[0]
        or $st->[1] != $lst[1];
    my $format = _file_format( $path, $fh );
    my ( $digest, $size ) = bmw384_fh($fh);
    close $fh;
    refuse( '%s : size changed while reading', $path ) if $size != $st->[7];
    $entry->{'_source_size'}  = $st->[7];
    $entry->{'_source_mtime'} = $st->[9];

    my $bmw  = bmw_b32($digest);
    my $addr = {
        qw| epoch | => $epoch,
        qw| amos |  => amos_of_bmw($bmw),
        qw| bmw |   => $bmw,
    };
    my $final  = node_path( $id->{'path'}, $addr );
    my $exists = -e $final;
    my $node   = { %{$addr}, qw| path | => $final };
    $entry->{'addr'} = join '/', epoch_b32($epoch), $addr->{'amos'}, $bmw;

    my $ntime = ntime_now();
    if ( $state->{'store_format'} == 3 ) {
        require AMOS7::N7FS::Release;
        my $tombstone
            = AMOS7::N7FS::Release::tombstone_latest( $id, $entry->{'addr'} );
        $ntime = $tombstone->{'ntime'} + 1
            if defined $tombstone and $ntime <= $tombstone->{'ntime'};
    }
    my $abs  = abs_path($path) // $path;
    my %meta = (
        qw| name |         => ( $path =~ m|([^/]+)\z| )[0],
        qw| format |       => $format,
        qw| size |         => $size,
        qw| mtime |        => $st->[9],
        qw| import_ntime | => ntime14($ntime),
        qw| epoch_num |    => epoch_num($ntime),
        qw| epoch |        => epoch_b32($epoch),
        qw| source |       => $abs,
        qw| host |         => hostname(),
        qw| amos |         => $addr->{'amos'},
        qw| bmw |          => $bmw,
        qw| disk |         => $id->{'disk'},
    );
    $meta{'index_chksum'} = $item->{'index_chksum'}
        if defined $item->{'index_chksum'};
    $meta{'index_name'} = $item->{'index_name'}
        if defined $item->{'index_name'};

    my $needs_ref = $state->{'store_format'} == 3 ? TRUE : FALSE;
    refuse( 'node %s is not journaled [ a crash ? n7fs repair %s ]',
        $entry->{'addr'}, $id->{'disk'} )
        if $exists
        and $needs_ref
        and not $replay->{'nodes'}{ $entry->{'addr'} };
    ## one full check per node and run : a node shared by thousands of     ##
    ## paths would otherwise verify every earlier record again for each of ##
    ## them                                                                ##
    my $seen
        = ( $exists and $needs_ref )
        ? $replay->{'_seen_nodes'}{ $entry->{'addr'} }
        : undef;
    $needs_ref = FALSE if $seen and $seen->{'holders'}{$abs};
    my %holders;
    if ( $exists and $needs_ref and not $seen ) {
        foreach my $ref ( reference_scan( $node, $id ) ) {
            my $key      = _key( $entry->{'addr'}, $ref->{'path'} );
            my $expected = $replay->{'references'}{$key};
            refuse( 'assimilate : unlisted reference %s', $ref->{'path'} )
                if not $expected;
            refuse( 'assimilate : reference drop disagrees with journal %s',
                $ref->{'path'} )
                if ( $ref->{'dropped'} ? 1 : 0 )
                != ( $expected->{'dropped'} ? 1 : 0 );
            $needs_ref = FALSE
                if $ref->{'holder'} eq $abs and not $ref->{'dropped'};
            $holders{ $ref->{'holder'} } = TRUE if not $ref->{'dropped'};
        }
    }
    my $unchanged = $exists
        && _meta_unchanged(
          $seen
        ? $seen->{'meta'}{ $meta{'source'} }
        : _newest_meta( $codec, $final, $meta{'source'}, $addr, $context ),
        \%meta
        );
    if ( $opt->{'dry_run'} ) {
        $entry->{'status'}
            = !$exists                  ? qw| would-store |
            : $unchanged && !$needs_ref ? qw| would-unchanged |
            :                             qw| would-dedup |;
        $entry->{'then'} = $remove ? qw| would-remove | : qw| keep |;
        return;
    }

    ## the epoch enters the state before its first node ##
    ## [ readers look there ]                           ##
    if ( not grep { $ARG == $epoch } $state->{'epochs'}->@* ) {
        state_write(
            $id->{'path'},
            { %{$state}, qw| epochs | => [ $state->{'epochs'}->@*, $epoch ] },
            $context->{'store'}
        );
    }

    if ($exists) {
        ## dedup : verify first ; unchanged meta is kept, a new source is ##
        ## added                                                          ##
        $codec->{'verify_node'}->( $final, $addr, $context ) if not $seen;
        if ($unchanged) {
            $entry->{'status'} = qw| unchanged |;
        } else {
            $entry->{'_meta_name'}
                = $codec->{'write_meta'}->( $final, \%meta, $addr, $context );
            $entry->{'status'} = qw| dedup |;
            ## the record just written is still read back and checked ##
            $seen->{'meta'}{ $meta{'source'} }
                = _v3_read_meta( $final, $entry->{'_meta_name'},
                $addr, $context )
                if $seen;
        }
    } else {
        my $amos_dir = $final =~ s|/[^/]+\z||r;
        make_dirs( $amos_dir, 0700 );
        ${$tmp_ref} = sprintf qw| %s.tmp.%s |, $final, b32( random_bytes(5) );
        make_dirs( ${$tmp_ref}, 0700 );
        $codec->{'write_node'}->(
            ${$tmp_ref},
            {   qw| addr |         => $addr,
                qw| content_path | => $path,
                qw| metas |        => [ \%meta ],
            },
            $context
        );
        fault(qw| assimilate:before-publish |);
        publish_dir( ${$tmp_ref}, $final );
        undef ${$tmp_ref};
        $entry->{'status'}    = qw| stored |;
        $entry->{'_new_node'} = TRUE;
        my @meta_names = grep { $ARG =~ $META_RE } _list_dir("$final/meta");
        refuse( 'node %s : new meta record missing', $final )
            if @meta_names != 1;
        $entry->{'_meta_name'} = $meta_names[0];
    }
    fault(qw| assimilate:after-publish |);

    ## verify the stored node, then the source again ##
    $codec->{'verify_node'}->( $final, $addr, $context ) if not $seen;
    my ( $fh2, $st2 ) = _open_regular($path);
    my ($digest2) = bmw384_fh($fh2);
    close $fh2;
    refuse( '%s : changed during assimilate', $path )
        if bmw_b32($digest2) ne $bmw
        or $st2->[0] != $st->[0]
        or $st2->[1] != $st->[1]
        or $st2->[7] != $st->[7]
        or $st2->[9] != $st->[9];
    $entry->{'verified'} = TRUE;
    ## a later source of this batch finds the node on disk ##
    $replay->{'nodes'}{ $entry->{'addr'} } = TRUE if $needs_ref;

    if ($needs_ref) {
        $entry->{'_reference'}
            = reference_write( $node, $id, $context->{'store'},
            $abs, $meta{'name'}, FALSE, $ntime );
        $replay->{'references'}
            { _key( $entry->{'addr'}, $entry->{'_reference'}{'path'} ) }
            = { qw| dropped | => FALSE };
        $entry->{'status'} = qw| dedup |
            if $entry->{'status'} eq qw| unchanged |;
    }

    if ( $state->{'store_format'} == 3 ) {
        if ( not $seen ) {
            my %newest;
            foreach my $m (
                $codec->{'read_node'}->( $final, $addr, $context )->{'metas'}
                ->@* ) {
                my $source = $m->{'source'} // '';
                $newest{$source} = $m
                    if not $newest{$source}
                    or $m->{'import_ntime'}
                    gt $newest{$source}{'import_ntime'};
            }
            $seen = $replay->{'_seen_nodes'}{ $entry->{'addr'} }
                = { qw| holders | => \%holders, qw| meta | => \%newest };
        }
        $seen->{'holders'}{$abs} = TRUE;
    }

    if ( $state->{'store_format'} == 3 and $remove ) {
        $entry->{'_remove_stat'} = $st;
        $entry->{'then'}         = qw| remove-pending |;
        return;
    }
    if ( not $remove ) {
        $entry->{'then'} = qw| kept |;
        return;
    }
    $entry->{'_remove_stat'} = $st;
    _remove_source($entry);
    return;
}

sub _remove_source {
    my $entry = shift;
    my $path  = $entry->{'source'};
    my $st    = $entry->{'_remove_stat'};
    fault(qw| assimilate:before-remove |);
    my @last = lstat $path or refuse( '%s : vanished before removal', $path );
    refuse( '%s : replaced before removal', $path )
        if -l _
        or $last[0] != $st->[0]
        or $last[1] != $st->[1]
        or $last[7] != $st->[7]
        or $last[9] != $st->[9];
    unlink $path or refuse( '%s : cannot remove : %s', $path, $OS_ERROR );
    $entry->{'then'} = qw| removed |;
    return;
}

1;

#,,.,,.,,,.,,,,.,,,.,,,,.,...,,.,,,,,,.,,,...,..,,...,...,.,,,..,,.,.,..,,,,,,
#CFMJQBV5M4UG5OGG6N4A52WHX4SIWYXJZCSWM5PLSG7NUZGNJBQDPTVSRMSN32QDOPEBKOFWCWXEQ
#\\\|RN4GDWZ5FXRN7EYSGLPONJ2B6JVODKMOZGZAGBLDEE4O2QDL5QF \ / AMOS7 \ YOURUM ::
#\[7]4XZEXTXANR7BE4UIHTELCZUF75XMTXJS3RQS6KTSI2TPQJHI5YDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
