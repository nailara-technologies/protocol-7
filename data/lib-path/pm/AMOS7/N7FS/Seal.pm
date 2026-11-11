## [:< ##

package AMOS7::N7FS::Seal;    ##############################################

## local sealed holders : twofish-ctr inside, chacha20-poly1305 outside.

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

our $VERSION = qw| AMOS7::N7FS::Seal-VERSION.NIXCYUI |;

@EXPORT_OK = qw| new_keypair seal_nodes unseal_address seal_recover shred_node
    holder_check seal_bytes open_sealed_bytes wrap_bytes unwrap_bytes twofish_crypt |;

use JSON::PP;
use Digest::BMW;
use Cwd   qw| abs_path |;
use Fcntl qw| O_RDONLY |;
use Crypt::Mode::CTR;
use Crypt::AuthEnc::ChaCha20Poly1305 qw| chacha20poly1305_encrypt_authenticate
    chacha20poly1305_decrypt_verify |;
use AMOS7::N7FS qw| b32 unb32 random_bytes read_file write_new_file
    write_new_file_stream make_dirs sync_dir refuse fault |;
use AMOS7::N7FS::Sum      qw| bmw384_bytes bmw_b32 epoch_from_b32 |;
use AMOS7::N7FS::Sign     qw| verify |;
use AMOS7::N7FS::Disk     qw| disk_read_id disk_lock state_read |;
use AMOS7::N7FS::Store    qw| node_path node_verify |;
use AMOS7::N7FS::Journal  qw| journal_replay |;
use AMOS7::N7FS::Category qw| category_report category_definitions |;
use AMOS7::N7FS::Holder   qw| holder_parse holder_canonical holder_mkdir
    holder_read holder_size holder_put holder_delete holder_verify
    holder_download holder_read_range holder_sizes |;

use constant CHUNK_SIZE => 16 * 1024 * 1024;

## sealed nodes up to 1 MiB are concatenated into pack blobs of about
## PACK_SIZE : one upload, one file and one inode for many small nodes, each
## still under its own node keys
sub _pack_limit { return $ENV{'N7FS_TEST_PACK_LIMIT'} // 1024 * 1024 }
## remote packs fetched during this command, removed when it ends ##
our @PACK_CACHE;
END { unlink $ARG for @PACK_CACHE }

sub _pack_size { return $ENV{'N7FS_TEST_PACK_SIZE'} // CHUNK_SIZE }
my $JSON = JSON::PP->new->utf8->canonical;

sub new_keypair {
    my $inner = random_bytes(32);
    my $outer = random_bytes(32);
    return $inner . $outer;
}

sub _keys {
    my $keys = shift // '';
    refuse('suite key material is not 64 bytes') if length $keys != 64;
    return ( substr( $keys, 0, 32 ), substr( $keys, 32, 32 ) );
}

sub _content_iv {
    my ( $layer, $chunk, $final ) = @_;
    refuse('chunk index exceeds 56 bits') if $chunk >= 2**56;
    my $index = substr( pack( qw| Q> |, $chunk ), 1 );
    return $index . pack( 'C Q>', $final ? 1 : 0, 0 )
        if $layer == 0;
    return
          'N7C'
        . pack( qw| C |, $layer )
        . $index
        . pack( qw| C |, $final ? 1 : 0 );
}

sub _long_iv {
    my ( $layer, $domain, $id, $counter ) = @_;
    return substr(
        bmw384_bytes(
                  "p7 n7fs seal $layer $domain v1\0"
                . $id
                . pack( qw| Q> |, $counter )
        ),
        0,
        $layer == 0 ? 16 : 12
    );
}

sub twofish_crypt {
    my ( $key, $iv, $bytes ) = @_;
    refuse('twofish key or iv has the wrong length')
        if length $key != 32
        or length $iv != 16;
    my $ctr = Crypt::Mode::CTR->new( qw| Twofish |, 1, 8 );
    $ctr->start_encrypt( $key, $iv );
    return $ctr->add($bytes);
}

sub _outer {
    my ( $key, $nonce, $aad, $bytes ) = @_;
    return chacha20poly1305_encrypt_authenticate( $key, $nonce, $aad,
        $bytes );
}

sub _open_outer {
    my ( $key, $nonce, $aad, $cipher, $tag ) = @_;
    my $plain = chacha20poly1305_decrypt_verify( $key, $nonce, $aad, $cipher,
        $tag );
    refuse('outer authentication failed') if not defined $plain;
    return $plain;
}

sub _long_aad {
    my ( $domain, $id, $counter ) = @_;
    return "P7SE\x01" . $domain . pack( qw| Q> |, $counter )
        if $domain !~ m{\A(?:head|map|journal)\z};
    return "P7SE\x01" . pack( 'n/a* a16 Q>', $domain, $id, $counter );
}

sub seal_bytes {
    my ( $keys, $plain, $domain, $id, $counter, $chunk, $final ) = @_;
    my ( $inner, $outer ) = _keys($keys);
    my $aad    = _long_aad( $domain, $id, $counter );
    my $middle = twofish_crypt( $inner, _long_iv( 0, $domain, $id, $counter ),
        $plain );
    if ( defined $chunk ) {
        $middle = twofish_crypt( $inner, _content_iv( 0, $chunk, $final ),
            $plain );
        $aad = "P7SC\x01" . pack( 'C Q> C', 1, $chunk, $final ? 1 : 0 );
    }
    my $nonce
        = defined $chunk
        ? _content_iv( 1, $chunk, $final )
        : _long_iv( 1, $domain, $id, $counter );
    my ( $cipher, $tag ) = _outer( $outer, $nonce, $aad, $middle );
    return $cipher . $tag;
}

sub open_sealed_bytes {
    my ( $keys, $sealed, $domain, $id, $counter, $chunk, $final ) = @_;
    refuse('sealed record is truncated') if length $sealed < 16;
    my ( $inner, $outer ) = _keys($keys);
    my $aad   = _long_aad( $domain, $id, $counter );
    my $nonce = _long_iv( 1, $domain, $id, $counter );
    if ( defined $chunk ) {
        $nonce = _content_iv( 1, $chunk, $final );
        $aad   = "P7SC\x01" . pack( 'C Q> C', 1, $chunk, $final ? 1 : 0 );
    }
    my $middle = _open_outer(
        $outer, $nonce, $aad,
        substr( $sealed, 0, -16 ),
        substr( $sealed, -16 )
    );
    return twofish_crypt(
        $inner,
        defined $chunk
        ? _content_iv( 0, $chunk, $final )
        : _long_iv( 0, $domain, $id, $counter ),
        $middle
    );
}

sub wrap_bytes {
    my ( $parent, $wrapped, $id, $counter, $domain ) = @_;
    refuse('wrapped key id is not 16 bytes') if length $id != 16;
    my $head = "P7SW\x01" . $id . pack( qw| Q> |, $counter );
    return $head . seal_bytes( $parent, $wrapped, $domain, $id, $counter );
}

sub unwrap_bytes {
    my ( $parent, $record, $domain ) = @_;
    refuse('wrapped key record is truncated') if length $record < 25 + 16;
    refuse('wrapped key record : bad magic or suite')
        if substr( $record, 0, 5 ) ne "P7SW\x01";
    my $id      = substr( $record, 5, 16 );
    my $counter = unpack qw| Q> |, substr( $record, 21, 8 );
    return open_sealed_bytes( $parent, substr( $record, 29 ),
        $domain, $id, $counter );
}

sub _state_dir { return "$ARG[0]->{'path'}.state" }

sub _replace_file {
    my ( $path, $bytes ) = @_;
    my $tmp = "$path.tmp";
    refuse( 'temporary state exists [ remove %s after checking ]', $tmp )
        if -e $tmp or -l $tmp;
    write_new_file( $tmp, $bytes );
    rename $tmp, $path
        or refuse( 'cannot replace %s : %s', $path, $OS_ERROR );
    my $dir = $path;
    $dir =~ s|/[^/]+\z||;
    sync_dir($dir);
}

sub _reserved_max {
    my $root = shift;
    my $dir  = _state_dir($root) . '/reservations';
    return 0 if not -d $dir;
    opendir( my $dh, $dir ) or refuse('cannot read version reservations');
    my @versions = grep {m|\A[1-9]\d*\z|} readdir $dh;
    closedir $dh;
    return ( sort { $a <=> $b } @versions )[-1] // 0;
}

sub _state_read {
    my $root  = shift;
    my $dir   = _state_dir($root);
    my $state = {};
    if ( -f "$dir/state" ) {
        $state = eval { $JSON->decode( read_file("$dir/state") // '' ) };
        refuse('seal state is invalid') if ref $state ne qw| HASH |;
    }
    $state->{'version'} //= 0;
    $state->{'writer'}  //= b32( random_bytes(16) );
    $state->{'version'} = _reserved_max($root)
        if _reserved_max($root) > $state->{'version'};
    return $state;
}

sub _writer {
    my $state  = shift;
    my $writer = unb32( $state->{'writer'} // '' );
    refuse('seal writer id is invalid')
        if not defined $writer
        or length $writer != 16;
    return $writer;
}

sub _state_write {
    my ( $root, $state ) = @_;
    my $dir = _state_dir($root);
    make_dirs( $dir, 0700 );
    _replace_file( "$dir/state", $JSON->encode($state) );
}

sub _head_name {
    my $root = shift;
    return bmw_b32(
        bmw384_bytes( "p7 n7fs seal head locator v1\0" . $root->{'keys'} ) );
}

sub _write_blob {
    my ( $root, $dir, $bytes, $kind ) = @_;
    my $name = bmw_b32( bmw384_bytes($bytes) );
    if ( holder_parse($dir)->{'type'} eq qw| ssh | ) {
        my $spool = _state_dir($root) . '/spool';
        make_dirs( $spool, 0700 );
        my $path = "$spool/$name";
        write_new_file( $path, $bytes ) if not -e $path;
        holder_put( $dir, $path, $name, $kind, FALSE );
        unlink $path or refuse('cannot remove confirmed spool');
        return $name;
    }
    holder_mkdir($dir);
    my $path = "$dir/$name";
    if ( -e $path ) {
        refuse( 'ciphertext address collision or changed blob %s', $name )
            if read_file($path) ne $bytes;
        return $name;
    }
    write_new_file( $path, $bytes );
    return $name;
}

sub _read_blob {
    my ( $dir, $name ) = @_;
    refuse('bad blob name') if ( $name // '' ) !~ m|\A[A-Z2-7]{77}\z|;
    my $bytes = holder_read( $dir, $name )
        // refuse( 'missing blob %s', $name );
    refuse( 'blob address mismatch %s', $name )
        if bmw_b32( bmw384_bytes($bytes) ) ne $name;
    return $bytes;
}

sub _head_open {
    my ( $root, $dir, $required ) = @_;
    my $name  = _head_name($root);
    my $bytes = holder_read( $dir, $name );
    refuse('sealed head not found')    if not defined $bytes and $required;
    return undef                       if not defined $bytes;
    refuse('sealed head is truncated') if length $bytes < 24 + 16;
    my $version = unpack qw| Q> |, substr( $bytes, 0, 8 );
    my $writer  = substr( $bytes, 8, 16 );
    my $plain   = open_sealed_bytes( $root->{'keys'}, substr( $bytes, 24 ),
        qw| head |, $writer, $version );
    my $head = eval { $JSON->decode($plain) };
    refuse('head payload is invalid') if ref $head ne qw| HASH |;
    my $pub    = unb32( $head->{'pub'} // '' );
    my $sig    = unb32( $head->{'sig'} // '' );
    my $signed = { %{$head} };
    delete $signed->{'sig'};
    refuse('head signature does not verify')
        if not defined $pub
        or $pub ne $root->{'signer'}->public
        or not verify( $pub, $JSON->encode($signed), $sig );
    refuse('head root id does not match')
        if ( $head->{'root_id'} // '' ) ne $root->{'root_id'};
    return $head;
}

sub _head_bytes {
    my ( $root, $writer, $version, $map, $journal ) = @_;
    my $head = {
        qw| root_id | => $root->{'root_id'},
        qw| writer |  => b32($writer),
        qw| version | => $version + 0,
        qw| map |     => $map,
        qw| journal | => $journal,
        qw| pub |     => b32( $root->{'signer'}->public ),
    };
    $head->{'sig'} = b32( $root->{'signer'}->sign( $JSON->encode($head) ) );
    my $plain = $JSON->encode($head);
    return
          pack( qw| Q> |, $version )
        . $writer
        . seal_bytes( $root->{'keys'}, $plain, qw| head |, $writer,
        $version );
}

sub _context {
    my ( $root, $dir, $recover ) = @_;
    holder_mkdir($dir) if not $recover;
    $dir = holder_canonical($dir);
    my $state = _state_read($root);
    my $head  = _head_open( $root, $dir, FALSE );
    refuse('pinned holder head is missing')
        if not defined $head and ( $state->{'pins'}{$dir} // 0 ) > 0;
    $state->{'new_holder'} = not defined $head;
    if ( defined $head ) {
        my $pinned = $state->{'pins'}{$dir} // 0;
        refuse( 'pinned head rollback [ holder %d, pinned %d ]',
            $head->{'version'}, $pinned )
            if $head->{'version'} < $pinned;
        $state->{'version'} = $head->{'version'}
            if $head->{'version'} > $state->{'version'};
        $state->{'pins'}{$dir} = $head->{'version'};
    }
    _state_write( $root, $state );
    my $map = {
        qw| root_id |    => $root->{'root_id'},
        qw| categories | => {},
        qw| nodes |      => {},
        qw| trees |      => {},
    };
    if ( defined $head ) {
        my $writer = unb32( $head->{'writer'} // '' );
        refuse('head writer id is invalid') if not defined $writer;
        my $bytes = _read_blob( $dir, $head->{'map'} );
        refuse('map writer does not match its head')
            if substr( $bytes, 0, 16 ) ne $writer;
        my $plain = open_sealed_bytes( $root->{'keys'}, substr( $bytes, 16 ),
            qw| map |, $writer, $head->{'version'} );
        $map = eval { $JSON->decode($plain) };
        refuse('sealed map is invalid')
            if ref $map ne qw| HASH |
            or ref $map->{'nodes'} ne qw| HASH |
            or ( $map->{'root_id'} // '' ) ne $root->{'root_id'};
        $map->{'trees'} //= {};
    }
    return ( $state, $head, $map );
}

sub _commit {
    my ( $root, $dir, $state, $map, $operation ) = @_;
    $dir = holder_canonical($dir);
    my $writer  = _writer($state);
    my $version = $state->{'version'} + 1;
    fault(qw| seal:before-version |);
    my $state_dir = _state_dir($root);
    make_dirs( "$state_dir/reservations", 0700 );
    write_new_file(
        "$state_dir/reservations/$version",
        $JSON->encode(
            {   qw| root_id | => $root->{'root_id'},
                qw| writer |  => b32($writer),
                qw| version | => $version
            }
        )
    );
    fault(qw| seal:after-reservation |);
    _state_write( $root, { %{$state}, qw| version | => $version } );
    fault(qw| seal:after-version |);
    my %stored = %{$map};
    delete $stored{'_root_keys'};
    $stored{'categories'} = {};

    foreach my $name ( keys $map->{'categories'}->%* ) {
        $stored{'categories'}{$name} = { $map->{'categories'}{$name}->%* };
        delete $stored{'categories'}{$name}{'_key'};
    }
    my $map_bytes = $writer
        . seal_bytes( $root->{'keys'}, $JSON->encode( \%stored ),
        qw| map |, $writer, $version );
    my $map_name = _write_blob( $root, $dir, $map_bytes, qw| map | );
    fault(qw| seal:after-map |);
    my $journal = $JSON->encode(
        {   qw| writer |    => b32($writer),
            qw| version |   => $version,
            qw| map |       => $map_name,
            qw| operation | => $operation,
        }
    );
    my $journal_name = _write_blob(
        $root, $dir,
        $writer
            . seal_bytes(
            $root->{'keys'}, $journal, qw| journal |, $writer, $version
            ),
        qw| journal |
    );
    fault(qw| seal:after-journal |);
    my $head_name = _head_name($root);
    my $head_bytes
        = _head_bytes( $root, $writer, $version, $map_name, $journal_name );

    if ( holder_parse($dir)->{'type'} eq qw| ssh | ) {
        my $spool = "$state_dir/spool";
        make_dirs( $spool, 0700 );
        my $path = "$spool/$head_name";
        write_new_file( $path, $head_bytes ) if not -e $path;
        holder_put( $dir, $path, $head_name, qw| head |, TRUE );
        unlink $path or refuse('cannot remove confirmed head spool');
    } else {
        _replace_file( "$dir/$head_name", $head_bytes );
    }
    $state->{'pins'}{$dir} = $version;
    _state_write( $root, { %{$state}, qw| version | => $version } );
    fault(qw| seal:after-head |);
    return $version;
}

sub _category {
    my ( $map, $name ) = @_;
    if ( exists $map->{'categories'}{$name} ) {
        my $category = $map->{'categories'}{$name};
        $category->{'_key'} //= unwrap_bytes(
            $map->{'_root_keys'},
            unb32( $category->{'wrap'} ),
            'category:' . $name
        );
        return $category;
    }
    my $id   = random_bytes(16);
    my $key  = new_keypair();
    my $wrap = wrap_bytes( $map->{'_root_keys'}, $key, $id, 0,
        'category:' . $name );
    return $map->{'categories'}{$name} = {
        qw| id |   => b32($id),
        qw| wrap | => b32($wrap),
        qw| _key | => $key,
    };
}

sub _node_keys {
    my ( $root, $map, $entry ) = @_;
    my $category = $map->{'categories'}{ $entry->{'category'} }
        // refuse('map category is missing');
    my $cat_key = $category->{'_key'} //= unwrap_bytes(
        $root->{'keys'},
        unb32( $category->{'wrap'} ),
        'category:' . $entry->{'category'}
    );
    my $wrap = $entry->{'wraps'}{ $entry->{'category'} } // $entry->{'wrap'};
    return unwrap_bytes( $cat_key, unb32($wrap), 'node:' . $entry->{'id'} );
}

sub _node_blob {
    my ( $content, $keys, $dir, $expected_bmw, $root, $packing ) = @_;
    my $size   = -s $content;
    my $chunks = $size ? int( ( $size + CHUNK_SIZE - 1 ) / CHUNK_SIZE ) : 1;
    my $remote = holder_parse($dir)->{'type'} eq qw| ssh |;
    my $spool  = $remote ? _state_dir($root) . '/spool' : $dir;
    make_dirs( $spool, 0700 );
    my $tmp
        = $remote
        ? "$spool/.sealing.$expected_bmw"
        : "$spool/.sealing." . b32( random_bytes(8) );
    unlink $tmp if -e $tmp;
    open( my $in, '<:raw', $content )
        or refuse( 'cannot open node %s : %s', $content, $OS_ERROR );
    my $plain_sum = Digest::BMW->new(384);
    write_new_file_stream(
        $tmp,
        sub {
            my $out = shift;
            print {$out} "P7SB\x01"
                . pack( 'C Q> N Q>', 0, CHUNK_SIZE, 0, $chunks )
                or die "$OS_ERROR\n";
            for my $index ( 0 .. $chunks - 1 ) {
                my $plain = '';
                while ( length($plain) < CHUNK_SIZE ) {
                    my $got = sysread( $in, my $part,
                        CHUNK_SIZE - length($plain) );
                    refuse( 'node read failed : %s', $OS_ERROR )
                        if not defined $got;
                    last if not $got;
                    $plain .= $part;
                }
                my $final = $index == $chunks - 1 ? TRUE : FALSE;
                $plain_sum->add($plain);
                my $sealed = seal_bytes( $keys, $plain, qw| content |, '', 0,
                    $index, $final );
                print {$out} pack( qw| N/a* |, $sealed ) or die "$OS_ERROR\n";
            }
            refuse('plaintext does not match its local address')
                if bmw_b32( $plain_sum->digest ) ne $expected_bmw;
        }
    );
    close $in;
    open( my $sealed, '<:raw', $tmp )
        or refuse( 'cannot read sealed temporary blob : %s', $OS_ERROR );
    my $ctx = Digest::BMW->new(384);
    $ctx->addfile($sealed);
    close $sealed;
    my $name = bmw_b32( $ctx->digest );
    if ( $packing and -s $tmp <= _pack_limit() ) {
        my $bytes = read_file($tmp);
        unlink $tmp;
        return ( $name, $chunks, $bytes );
    }
    if ($remote) {
        holder_put( $dir, $tmp, $name, qw| content |, FALSE );
        unlink $tmp or refuse('cannot remove confirmed content spool');
        return ( $name, $chunks );
    }
    refuse('ciphertext blob already exists') if -e "$dir/$name";
    rename $tmp, "$dir/$name"
        or refuse( 'cannot publish content blob : %s', $OS_ERROR );
    sync_dir($dir);
    return ( $name, $chunks );
}

sub _content_path {
    my ( $id, $address ) = @_;
    my ( $epoch, $amos, $bmw ) = split m|/|, $address;
    return node_path(
        $id->{'path'},
        {   qw| epoch | => epoch_from_b32($epoch),
            qw| amos |  => $amos,
            qw| bmw |   => $bmw
        }
    ) . '/content';
}

sub _manifest_files {
    my ( $id, $manifest ) = @_;
    open( my $fh, '<:raw', _content_path( $id, $manifest ) )
        or refuse( 'cannot read tree manifest %s', $manifest );
    my @files;
    while ( my $line = <$fh> ) {
        my $entry = eval { $JSON->decode($line) };
        push @files, $entry->{'a'}
            if ref $entry eq qw| HASH | and defined $entry->{'a'};
    }
    close $fh;
    return @files;
}

sub _select_addresses {
    my %opt = @_;
    delete $opt{'root'};
    my $id = disk_read_id(
        %opt,
        defined $opt{'disk_root'} ? ( qw| root | => $opt{'disk_root'} ) : (),
        qw| disk | => $opt{'disk'}
    );
    my $state = state_read( $id->{'path'}, $id->{'store_pub'} );
    refuse('sealing needs store format 3') if $state->{'store_format'} != 3;
    my $replay      = journal_replay($id);
    my $definitions = category_definitions( $id, $replay );
    my %node_categories;

    foreach my $ref ( values $replay->{'ref_history'}->%* ) {
        my $assignment = $replay->{'assignments'}
            { join( "\0", $ref->{'node'}, $ref->{'path'} ) };
        my $category = $assignment->{'category'} // 'default';
        $node_categories{ $ref->{'node'} }{$category} = 1;
    }
    my %selected = map { $ARG => 1 } $opt{'addresses'}->@*;
    if ( defined $opt{'category'} ) {
        %selected = map { $ARG => 1 }
            grep { $node_categories{$ARG}{ $opt{'category'} } }
            keys $replay->{'nodes'}->%*;
    }
    my %trees;
    foreach my $name ( keys $replay->{'trees'}->%* ) {
        my $tree   = $replay->{'trees'}{$name};
        my $wanted = $opt{'all_trees'}
            || grep { $ARG eq $name } $opt{'trees'}->@*;
        my @files = _manifest_files( $id, $tree->{'manifest'} );
        $wanted ||= grep { $selected{$ARG} } @files
            if defined $opt{'category'};
        next if not $wanted;
        $trees{$name} = {
            qw| manifest | => $tree->{'manifest'},
            qw| created |  => $tree->{'created'}
        };
        $selected{$ARG} = 1 for $tree->{'manifest'}, @files;
    }
    foreach my $name ( $opt{'trees'}->@* ) {
        refuse( 'no live tree named %s', $name ) if not exists $trees{$name};
    }
    my @addresses = sort keys %selected;
    refuse('no addresses selected') if not @addresses;
    foreach my $address (@addresses) {
        refuse( 'node is not live in this disk : %s', $address )
            if not $replay->{'nodes'}{$address};
        my @categories = keys %{ $node_categories{$address} // {} };
        @categories = (qw| default |) if not @categories;
        $node_categories{$address} = { map { $ARG => 1 } @categories };
        foreach my $category (@categories) {
            my $policy = $definitions->{$category};
            refuse(
                      'local_encryption cascade is '
                    . 'not implemented ; refusing %s', $address
                )
                if defined $policy
                and $policy->{'local_encryption'} eq qw| cascade |;
        }
    }
    return ( $id, $replay, \@addresses, \%trees, \%node_categories );
}

sub seal_nodes {
    my %opt = @_;
    my ( $root, $dir ) = @opt{qw| root holder |};
    my ( $id, $replay, $addresses, $trees, $node_categories )
        = _select_addresses(%opt);
    holder_mkdir($dir);
    my ( $counter, $head, $map ) = _context( $root, $dir, FALSE );
    $map->{'_root_keys'} = $root->{'keys'};
    my $tree_changes = grep {
        ( $map->{'trees'}{$ARG}{'manifest'} // '' ) ne
            $trees->{$ARG}{'manifest'}
    } keys %{$trees};
    $map->{'trees'} = { %{ $map->{'trees'} // {} }, %{$trees} };
    my @new;
    my @pending_files;
    my ( $sealed, $batch_bytes ) = ( 0, 0 );
    my %pack  = ( qw| bytes | => "P7SP\x01", qw| entries | => [] );
    my $flush = sub {
        return if not $pack{'entries'}->@*;
        my $name = _write_blob( $root, $dir, $pack{'bytes'}, qw| pack | );
        $ARG->{'blob'} = $name for $pack{'entries'}->@*;
        %pack = ( qw| bytes | => "P7SP\x01", qw| entries | => [] );
        fault(qw| seal:after-pack |);
    };
    foreach my $address ( @{$addresses} ) {
        next if exists $map->{'nodes'}{$address};
        my ( $epoch, $amos, $bmw ) = split m|/|, $address;
        my $path = _content_path( $id, $address );
        refuse( 'local node is missing : %s', $address ) if not -f $path;
        my @categories = sort keys $node_categories->{$address}->%*;
        my $pending;
        my ( $node_id, $keys );
        if ( holder_parse($dir)->{'type'} eq qw| ssh | ) {
            my $pending_dir = _state_dir($root) . '/pending';
            make_dirs( $pending_dir, 0700 );
            $pending = "$pending_dir/" . bmw_b32( bmw384_bytes($address) );
            if ( -f $pending ) {
                my $saved = $JSON->decode( read_file($pending) );
                $node_id = unb32( $saved->{'node_id'} );
                $keys
                    = unwrap_bytes( $root->{'keys'},
                    unb32( $saved->{'wrap'} ),
                    qw| pending | );
            } else {
                $node_id = random_bytes(16);
                $keys    = new_keypair();
                write_new_file(
                    $pending,
                    $JSON->encode(
                        {   qw| node_id | => b32($node_id),
                            qw| wrap |    => b32(
                                wrap_bytes(
                                    $root->{'keys'}, $keys,
                                    $node_id,        0,
                                    qw| pending |
                                )
                            )
                        }
                    )
                );
            }
            push @pending_files, $pending;
        } else {
            $node_id = random_bytes(16);
            $keys    = new_keypair();
        }
        fault(qw| seal:before-blob |);
        my ( $name, $chunks, $packed )
            = _node_blob( $path, $keys, $dir, $bmw, $root, TRUE );
        my ( $length, $offset ) = ( undef, 0 );
        if ( defined $packed ) {
            $offset = length $pack{'bytes'};
            $length = length $packed;
            $pack{'bytes'} .= $packed;
        } else {
            $length = holder_size( $dir, $name );
        }
        fault(qw| seal:after-blob |);
        my %wraps;

        foreach my $category (@categories) {
            my $cat = _category( $map, $category );
            $wraps{$category} = b32(
                wrap_bytes(
                    $cat->{'_key'}, $keys,
                    $node_id,       0,
                    'node:' . b32($node_id)
                )
            );
        }
        $map->{'nodes'}{$address} = {
            qw| id |   => b32($node_id),
            qw| blob | => $name,
            defined $packed ? ( qw| node | => $name ) : (),
            qw| offset |   => $offset,
            qw| length |   => $length,
            qw| chunks |   => $chunks,
            qw| category | => $categories[0],
            qw| wraps |    => \%wraps,
            qw| layout |   => {
                qw| mode |        => qw| complete |,
                qw| chunk_size |  => CHUNK_SIZE,
                qw| header_size | => 0,
            },
        };
        push $pack{'entries'}->@*, $map->{'nodes'}{$address}
            if defined $packed;
        $flush->() if length $pack{'bytes'} >= _pack_size();
        push @new, $address;
        $sealed++;
        $batch_bytes += $length;
        if (   @new >= ( $ENV{'N7FS_TEST_SEAL_BATCH'} // 1000 )
            or $batch_bytes >= 1024**3 ) {
            $flush->();
            $counter->{'version'} = _commit( $root, $dir, $counter, $map,
                { qw| seal | => [@new] } );
            @new          = ();
            $batch_bytes  = 0;
            $tree_changes = 0;
            unlink for @pending_files;
            @pending_files = ();
        }
    }
    $flush->();
    delete $map->{'_root_keys'};
    if ( @new or $tree_changes ) {
        $counter->{'version'}
            = _commit( $root, $dir, $counter, $map,
            { qw| seal | => [@new] } );
    }
    unlink for @pending_files;
    return {
        qw| sealed |     => $sealed,
        qw| version |    => $counter->{'version'},
        qw| new_holder | => $counter->{'new_holder'},
    };
}

sub _read_exact {
    my ( $fh, $len ) = @_;
    my $bytes = '';
    while ( length($bytes) < $len ) {
        my $got = sysread( $fh, my $part, $len - length($bytes) );
        refuse( 'content read failed : %s', $OS_ERROR ) if not defined $got;
        refuse('content blob is truncated')             if not $got;
        $bytes .= $part;
    }
    return $bytes;
}

sub _content_fh {
    my ( $path, $expected, $layout ) = @_;
    open( my $fh, '<:raw', $path )
        or refuse( 'cannot open content blob : %s', $OS_ERROR );
    my $head = _read_exact( $fh, 26 );
    refuse('content blob header is invalid')
        if substr( $head, 0, 5 ) ne "P7SB\x01";
    my ( $mode, $chunk_size, $header_size )
        = unpack( 'C Q> N', substr( $head, 5, 13 ) );
    refuse('blob layout differs from its map')
        if $mode != 0
        or $chunk_size != $layout->{'chunk_size'}
        or $header_size != $layout->{'header_size'};
    my $chunks = unpack qw| Q> |, substr( $head, 18, 8 );
    refuse('content chunk count differs from the map')
        if $chunks != $expected or not $chunks;
    return ( $fh, $head, $chunks );
}

sub _content_chunk {
    my ( $fh, $chunk_size ) = @_;
    my $len = unpack qw| N |, _read_exact( $fh, 4 );
    refuse('content chunk length is invalid')
        if $len < 16
        or $len > $chunk_size + 16;
    return _read_exact( $fh, $len );
}

sub _content_end {
    my $fh  = shift;
    my $got = sysread( $fh, my $extra, 1 );
    refuse( 'content read failed : %s', $OS_ERROR ) if not defined $got;
    refuse('content blob has trailing bytes')       if $got;
    close $fh or refuse( 'cannot close content blob : %s', $OS_ERROR );
}

sub _restore_node {
    my ( $root, $dir, $map, $address, $target ) = @_;
    my $entry = $map->{'nodes'}{$address}
        // refuse( 'address is not in the current sealed map : %s',
        $address );
    my $layout = $entry->{'layout'} // {
        qw| mode |        => qw| complete |,
        qw| chunk_size |  => CHUNK_SIZE,
        qw| header_size | => 0
    };
    refuse('unknown or impossible sealed content layout')
        if ( $layout->{'mode'} // '' ) ne qw| complete |
        or ( $layout->{'chunk_size'}  // 0 ) != CHUNK_SIZE
        or ( $layout->{'header_size'} // -1 ) != 0;
    my $chunk_size = $layout->{'chunk_size'};
    my $keys       = _node_keys( $root, $map, $entry );
    my $path       = "$dir/$entry->{'blob'}";
    my $downloaded;
    my $expect = $entry->{'node'} // $entry->{'blob'};

    if ( defined $entry->{'node'} ) {
        ## a packed node : only its own range is read ##
        my $spool = _state_dir($root) . '/spool';
        make_dirs( $spool, 0700 );
        $path = "$spool/$entry->{'node'}";
        my $bytes;
        if ( holder_parse($dir)->{'type'} eq qw| ssh | ) {
            ## a remote pack is fetched once per command and cut locally ##
            my $whole = "$spool/pack.$entry->{'blob'}";
            if ( not -f $whole ) {
                unlink "$whole.part";
                holder_download( $dir, $entry->{'blob'}, "$whole.part" );
                rename "$whole.part", $whole
                    or refuse( 'cannot keep pack %s', $entry->{'blob'} );
                push @PACK_CACHE, $whole;
            }
            $bytes = holder_read_range( $spool, "pack.$entry->{'blob'}",
                $entry->{'offset'}, $entry->{'length'} );
        } else {
            $bytes = holder_read_range( $dir, $entry->{'blob'},
                $entry->{'offset'}, $entry->{'length'} );
        }
        refuse( 'packed node cannot be read from %s', $entry->{'blob'} )
            if not defined $bytes
            or length $bytes != $entry->{'length'};
        unlink $path if -e $path;
        write_new_file( $path, $bytes );
        $downloaded = TRUE;
    } elsif ( holder_parse($dir)->{'type'} eq qw| ssh | ) {
        my $spool = _state_dir($root) . '/spool';
        make_dirs( $spool, 0700 );
        $path = "$spool/$entry->{'blob'}";
        holder_download( $dir, $entry->{'blob'}, $path );
        $downloaded = TRUE;
    }
    my ( $check, $head, $chunks )
        = _content_fh( $path, $entry->{'chunks'}, $layout );
    my $cipher_sum = Digest::BMW->new(384);
    $cipher_sum->add($head);

    for my $index ( 0 .. $chunks - 1 ) {
        $cipher_sum->add(
            pack( 'N/a*', _content_chunk( $check, $chunk_size ) ) );
    }
    _content_end($check);
    refuse( 'blob address mismatch %s', $expect )
        if bmw_b32( $cipher_sum->digest ) ne $expect;

    my ( $in, undef, undef ) = _content_fh( $path, $chunks, $layout );
    my $plain_sum = Digest::BMW->new(384);
    write_new_file_stream(
        $target,
        sub {
            my $out = shift;
            for my $index ( 0 .. $chunks - 1 ) {
                my $sealed = _content_chunk( $in, $chunk_size );
                my $final  = $index == $chunks - 1 ? TRUE : FALSE;
                my $plain  = open_sealed_bytes( $keys, $sealed,
                    qw| content |, '', 0, $index, $final );
                refuse('nonfinal chunk has the wrong size')
                    if not $final and length($plain) != $chunk_size;
                refuse('final chunk has the wrong size')
                    if $final
                    and $chunks > 1
                    and
                    ( length($plain) < 1 or length($plain) > $chunk_size );
                $plain_sum->add($plain);
                print {$out} $plain or die "$OS_ERROR\n";
            }
            _content_end($in);
            my ( $epoch, $amos, $bmw ) = split m|/|, $address;
            refuse('restored content does not match its local address')
                if bmw_b32( $plain_sum->digest ) ne $bmw;
        }
    );
    unlink $path if $downloaded and -e $path;
}

sub _unseal_tree {
    my %opt = @_;
    my $id  = disk_read_id(
        defined $opt{'host_dir'}
        ? ( qw| host_dir | => $opt{'host_dir'} )
        : (),
        qw| disk | => $opt{'disk'}
    );
    my $replay = journal_replay($id);
    my $tree   = $replay->{'trees'}{ $opt{'address'} }
        // refuse( 'no live tree named %s', $opt{'address'} );
    refuse('tree restore target exists')
        if -e $opt{'target'}
        or -l $opt{'target'};
    my $tmp = $opt{'target'} . '.incomplete.' . b32( random_bytes(5) );
    make_dirs( $tmp, 0700 );
    _restore_node(
        @opt{qw| root holder |}, $opt{'map'},
        $tree->{'manifest'},     "$tmp/.manifest"
    );
    open( my $manifest, '<:raw', "$tmp/.manifest" )
        or refuse('cannot read restored manifest');
    my $head = <$manifest>;
    my @entries;

    while ( my $line = <$manifest> ) {
        my $entry = eval { $JSON->decode($line) };
        refuse('bad restored manifest entry') if ref $entry ne qw| HASH |;
        push @entries, $entry;
    }
    close $manifest;
    unlink "$tmp/.manifest";
    my @links;
    foreach my $entry (@entries) {
        my $relative = _tree_path( $entry->{'p'} );
        my $dest     = "$tmp/$relative";
        my $type     = $entry->{'t'} // '';
        if ( $type eq qw| dir | ) {
            make_dirs( $dest, 0700 );
        } elsif ( $type eq qw| file | ) {
            my $parent = $dest;
            $parent =~ s|/[^/]+\z||;
            make_dirs( $parent, 0700 );
            _restore_node( @opt{qw| root holder |}, $opt{'map'},
                $entry->{'a'}, $dest );
        } elsif ( $type eq qw| symlink | or $type eq qw| hardlink | ) {
            push @links, [ $relative, $entry ];
        } elsif ( $type ne qw| skipped | ) {
            refuse('manifest entry has a bad type');
        }
    }
    foreach my $item (@links) {
        my ( $relative, $entry ) = @{$item};
        my $dest = "$tmp/$relative";
        if ( ( $entry->{'t'} // '' ) eq qw| hardlink | ) {
            my $earlier = _tree_path( $entry->{'h'} );
            link "$tmp/$earlier", $dest
                or refuse( 'cannot restore hardlink : %s', $OS_ERROR );
        } else {
            my $link = unb32( $entry->{'l'} // '' );
            refuse('manifest symlink target is invalid')
                if not defined $link
                or index( $link, "\0" ) >= 0;
            symlink $link, $dest
                or refuse( 'cannot restore symlink : %s', $OS_ERROR );
        }
    }
    rename $tmp, $opt{'target'} or refuse('cannot publish restored tree');
    return TRUE;
}

sub _restore_sealed_tree {
    my %opt  = @_;
    my $tree = $opt{'map'}{'trees'}{ $opt{'address'} };
    if ( not defined $tree and $opt{'disk'} ) {
        my $id     = disk_read_id( qw| disk | => $opt{'disk'} );
        my $replay = journal_replay($id);
        $tree = $replay->{'trees'}{ $opt{'address'} };
    }
    refuse( 'no live tree named %s', $opt{'address'} ) if not defined $tree;
    require File::Temp;
    my $tmp = File::Temp::tempdir(
        'n7fs-sealed-tree-XXXXXX',
        TMPDIR  => 1,
        CLEANUP => 1
    );
    my $manifest = "$tmp/manifest";
    _restore_node(
        @opt{qw| root holder |}, $opt{'map'},
        $tree->{'manifest'},     $manifest
    );
    require AMOS7::N7FS::Tree;
    return AMOS7::N7FS::Tree::tree_restore(
        qw| name |           => $opt{'address'},
        qw| target |         => $opt{'target'},
        qw| owners |         => $opt{'owners'} ? TRUE : FALSE,
        qw| tree_record |    => { %{$tree}, qw| name | => $opt{'address'} },
        qw| manifest_path |  => $manifest,
        qw| content_source | => sub {
            my ( $address, $dest ) = @_;
            _restore_node( @opt{qw| root holder |},
                $opt{'map'}, $address, $dest );
        },
    );
}

sub unseal_address {
    my %opt = @_;
    my ( undef, undef, $map ) = _context( @opt{qw| root holder |}, FALSE );
    return _restore_sealed_tree( %opt, qw| map | => $map )
        if $opt{'address'} !~ m|\AV7[A-Z2-7]{5}/|;
    _restore_node( @opt{qw| root holder |}, $map, $opt{'address'},
        $opt{'target'} );
    return TRUE;
}

sub seal_recover {
    my %opt = @_;
    my ( undef, $head, $map ) = _context( @opt{qw| root holder |}, TRUE );
    refuse('no sealed head to recover') if not defined $head;
    if ( defined $opt{'tree'} ) {
        my $r = _restore_sealed_tree(
            %opt,
            qw| address | => $opt{'tree'},
            qw| map |     => $map
        );
        return { %{$r}, qw| version | => $head->{'version'} };
    }
    make_dirs( $opt{'target'}, 0700 );
    foreach my $address ( sort keys $map->{'nodes'}->%* ) {
        my $safe = $address;
        $safe =~ s|/|_|g;
        _restore_node( @opt{qw| root holder |}, $map, $address,
            $opt{'target'} . "/$safe" );
    }
    return {
        qw| nodes |   => scalar keys $map->{'nodes'}->%*,
        qw| version | => $head->{'version'}
    };
}

sub holder_check {
    my %opt = @_;
    my ( undef, $head, $map ) = _context( @opt{qw| root holder |}, TRUE );
    refuse('no sealed head to check') if not defined $head;
    my $sizes     = holder_sizes( $opt{'holder'} );
    my @addresses = sort keys $map->{'nodes'}->%*;
    my %blobs;
    foreach my $address (@addresses) {
        my $entry = $map->{'nodes'}{$address};
        my $size  = $sizes->{ $entry->{'blob'} };
        my $need  = ( $entry->{'offset'} // 0 ) + $entry->{'length'};
        refuse( 'mapped blob is missing or has the wrong size : %s',
            $entry->{'blob'} )
            if not defined $size
            or ( defined $entry->{'node'} ? $size < $need : $size != $need );
        $blobs{ $entry->{'blob'} } = TRUE;
    }
    my $wanted = $opt{'samples'} // 16;
    refuse('samples must be a positive integer')
        if $wanted !~ m|\A[1-9]\d*\z|;
    for ( my $i = @addresses - 1; $i > 0; $i-- ) {
        my $j = unpack( 'N', random_bytes(4) ) % ( $i + 1 );
        @addresses[ $i, $j ] = @addresses[ $j, $i ];
    }
    my $checked = 0;
    foreach my $address (@addresses) {
        last if $checked >= $wanted;
        my $entry = $map->{'nodes'}{$address};
        my $base  = $entry->{'offset'} // 0;
        my $blob  = holder_read_range( $opt{'holder'}, $entry->{'blob'},
            $base, 26 );
        refuse('mapped blob header cannot be read')
            if not defined $blob
            or length $blob != 26;
        my ( $mode, $chunk_size ) = unpack( 'C Q>', substr( $blob, 5, 9 ) );
        my $chunks = unpack qw| Q> |, substr( $blob, 18, 8 );
        refuse('mapped blob chunk count differs')
            if $chunks != $entry->{'chunks'} or $mode != 0;
        ## every chunk before the last has the same sealed length ##
        my $index = unpack( 'N', random_bytes(4) ) % $chunks;
        my $pos   = $base + 26 + $index * ( 4 + $chunk_size + 16 );
        my $raw
            = holder_read_range( $opt{'holder'}, $entry->{'blob'}, $pos, 4 );
        refuse('sampled chunk cannot be read')
            if not defined $raw
            or length $raw != 4;
        my $sealed = holder_read_range(
            $opt{'holder'}, $entry->{'blob'},
            $pos + 4,       unpack( qw| N |, $raw )
        );
        refuse('sampled chunk cannot be read') if not defined $sealed;
        open_sealed_bytes( _node_keys( $opt{'root'}, $map, $entry ),
            $sealed, qw| content |, '', 0, $index,
            $index == $chunks - 1 ? TRUE : FALSE );
        $checked++;
    }
    return {
        qw| version | => $head->{'version'},
        qw| root_id | => $opt{'root'}{'root_id'},
        qw| nodes |   => scalar @addresses,
        qw| blobs |   => scalar keys %blobs,
        qw| chunks |  => $checked,
        qw| samples | => $checked
    };
}

## blobs a holder keeps that the current head no longer references :
## superseded maps and journals, and nodes dropped from the map. a holder may
## hold other roots, whose blobs look the same from outside, so this only runs
## when the owner states the holder serves this root alone
sub holder_gc {
    my %opt = @_;
    refuse(   'holder-gc needs -only-root : a holder may also hold '
            . 'other roots, and their blobs cannot be told apart' )
        if not $opt{'only_root'};
    my ( undef, $head, $map ) = _context( @opt{qw| root holder |}, TRUE );
    refuse('no sealed head on this holder') if not defined $head;
    my %keep = map { $ARG => TRUE } _head_name( $opt{'root'} ),
        $head->{'map'}, $head->{'journal'};
    $keep{ $map->{'nodes'}{$ARG}{'blob'} } = TRUE
        for keys $map->{'nodes'}->%*;
    my $sizes = holder_sizes( $opt{'holder'} );
    my @drop  = sort grep { not $keep{$ARG} } keys %{$sizes};
    my $bytes = 0;
    $bytes += $sizes->{$ARG} for @drop;

    if ( $opt{'delete'} ) {
        holder_delete( $opt{'holder'}, $ARG ) for @drop;
    }
    return {
        qw| kept |    => scalar( keys %{$sizes} ) - scalar @drop,
        qw| removed | => scalar @drop,
        qw| bytes |   => $bytes,
        qw| deleted | => $opt{'delete'} ? TRUE : FALSE,
    };
}

## drop nodes, and the trees that named any of them, from a holder's current
## map in one commit. bytes stay until holder-gc
sub unmap_nodes {
    my %opt = @_;
    my ( $counter, $head, $map ) = _context( @opt{qw| root holder |}, FALSE );
    refuse('no sealed head on this holder') if not defined $head;
    my %gone = map { $ARG => TRUE }
        grep { exists $map->{'nodes'}{$ARG} } $opt{'addresses'}->@*;
    return { qw| removed | => 0, qw| trees | => 0 } if not %gone;
    delete $map->{'nodes'}{$ARG} for keys %gone;
    my @trees;
    foreach my $name ( sort keys %{ $map->{'trees'} // {} } ) {
        my $files = $opt{'tree_files'}{$name} // [];
        push @trees, $name
            if $gone{ $map->{'trees'}{$name}{'manifest'} }
            or grep { $gone{$ARG} } @{$files};
    }
    delete $map->{'trees'}{$ARG} for @trees;
    $counter->{'version'} = _commit( @opt{qw| root holder |}, $counter, $map,
        { qw| unmap | => [ sort keys %gone ] } );
    return {
        qw| removed | => scalar keys %gone,
        qw| trees |   => scalar @trees,
        qw| version | => $counter->{'version'},
    };
}

sub shred_node {
    my %opt = @_;
    my ( $counter, $head, $map ) = _context( @opt{qw| root holder |}, FALSE );
    refuse( 'address is not in the current sealed map : %s', $opt{'address'} )
        if not exists $map->{'nodes'}{ $opt{'address'} };
    delete $map->{'nodes'}{ $opt{'address'} };
    $counter->{'version'} = _commit( @opt{qw| root holder |}, $counter, $map,
        { qw| shred | => $opt{'address'} } );
    return $counter->{'version'};
}

1;

#,,,.,.,.,..,,,,.,.,,,,..,..,,.,,,,..,,,.,,,.,..,,...,...,..,,,.,,,.,,,,.,..,,
#P7S7FBXO742CEIND7LVZJVHZDR7HRMT2KU5A7GHFK6NB3ZH73LFTYOKW332GNMDAZEUJJS5VUIBAG
#\\\|HRFVJFKEHX4TMQXAWSN7HOSU2XOE43WRYDL4EHTW4MBHYJRJTTS \ / AMOS7 \ YOURUM ::
#\[7]5BFYG3UMNRARKCUHQBUJVINKQ4AFDMCDQAFNRBZLTJNLX6POLSCI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
