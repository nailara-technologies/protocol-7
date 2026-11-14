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

our $VERSION = qw| AMOS7::N7FS::Seal-VERSION.OV6SUCA |;

@EXPORT_OK = qw| new_keypair seal_nodes unseal_address seal_recover shred_node
    relay_nodes holder_check holder_gc holder_trash_purge holder_trash_restore
    holder_migrate root_subdir retention_update retention_plan repack_packs
    seal_bytes open_sealed_bytes wrap_bytes unwrap_bytes twofish_crypt
    head_survey head_refresh registry_open registry_publish |;

use JSON::PP;
use Digest::BMW;
use Cwd   qw| abs_path |;
use Fcntl qw| O_RDONLY |;
use Crypt::Mode::CTR;
use Crypt::AuthEnc::ChaCha20Poly1305 qw| chacha20poly1305_encrypt_authenticate
    chacha20poly1305_decrypt_verify |;
use Time::Local  qw| timegm |;
use AMOS7::NTIME qw| parse_y_age y_level_ntime unix_to_ntime |;
use AMOS7::N7FS  qw| b32 unb32 random_bytes read_file write_new_file
    write_new_file_stream make_dirs sync_dir refuse fault ntime_now ntime14 |;
use AMOS7::N7FS::Sum      qw| bmw384_bytes bmw_b32 epoch_from_b32 |;
use AMOS7::N7FS::Sign     qw| verify |;
use AMOS7::N7FS::Disk     qw| disk_read_id disk_lock state_read |;
use AMOS7::N7FS::Store    qw| node_path node_verify |;
use AMOS7::N7FS::Journal  qw| journal_replay |;
use AMOS7::N7FS::Category qw| category_report category_definitions |;
use AMOS7::N7FS::Holder   qw| holder_parse holder_canonical holder_mkdir
    holder_read holder_size holder_put holder_delete holder_verify
    holder_download holder_read_range holder_sizes holder_stats holder_now
    holder_scrub holder_isdir holder_sub_spec holder_make_path holder_move
    holder_trash_days holder_trash_list holder_remove_day holder_authorize |;

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

sub _siv_domain {
    my $domain = shift // '';
    return $domain
        =~ m{\A(?:head|map|map-shard-[A-Z2-7]{2}|map-tree|journal|registry|manifest-index|manifest-chunk)\z};
}

sub _long_aad {
    my ( $domain, $id, $counter ) = @_;
    return "P7SE\x01" . $domain . pack( qw| Q> |, $counter )
        if $domain =~ m{\A(?:category:|node:)}
        or $domain eq qw| pending |
        or $domain eq qw| content |
        or $domain eq qw| root-file |;
    refuse( 'unknown long-key domain [ %s ]', $domain )
        if not _siv_domain($domain);
    refuse('long-key id is not 32 bytes') if length( $id // '' ) != 32;
    return "P7SE\x01" . pack( 'n/a* a32 Q>', $domain, $id, $counter );
}

sub _siv_key {
    my $keys = shift;
    my ( undef, $outer ) = _keys($keys);
    return bmw384_bytes( "p7 n7fs siv key v1\0" . $outer );
}

sub _long_id {
    my ( $keys, $writer, $domain, $plain ) = @_;
    refuse('long-key writer id is not 16 bytes') if length $writer != 16;
    return $writer
        . substr(
        bmw384_bytes(
            "p7 n7fs siv v1\0" . _siv_key($keys) . $domain . $plain
        ),
        0, 16
        );
}

sub seal_bytes {
    my ( $keys, $plain, $domain, $id, $counter, $chunk, $final ) = @_;
    my ( $inner, $outer ) = _keys($keys);
    my $aad = _long_aad( $domain, $id, $counter );
    refuse('long-key id does not match its plaintext')
        if _siv_domain($domain)
        and _long_id( $keys, substr( $id, 0, 16 ), $domain, $plain ) ne $id;
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
    my $plain = twofish_crypt(
        $inner,
        defined $chunk
        ? _content_iv( 0, $chunk, $final )
        : _long_iv( 0, $domain, $id, $counter ),
        $middle
    );
    refuse('long-key id does not match its plaintext')
        if _siv_domain($domain)
        and _long_id( $keys, substr( $id, 0, 16 ), $domain, $plain ) ne $id;
    return $plain;
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

sub _state_dir {
    return $ARG[0]->{'state_dir'} // "$ARG[0]->{'path'}.state";
}

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
    $state->{'holders'} //= {};
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
    my $dir    = _state_dir($root);
    my $stored = { %{$state} };
    delete @{$stored}{qw| new_holder holder_id head_registry |};
    make_dirs( $dir, 0700 );
    _replace_file( "$dir/state", $JSON->encode($stored) );
}

sub _head_name {
    my $root = shift;
    return bmw_b32(
        bmw384_bytes( "p7 n7fs seal head locator v1\0" . $root->{'keys'} ) );
}

## one holder subdirectory per root [ review finding 2 ] : r- plus seven
## root-id characters -- short, stable, and no secret, the root id is a
## public-key derivation already carried in every head and map. the
## subdirectory holds that root's head, map, journal and blobs, so a gc of one
## root never lists another root's blobs. a holder is per-root when its
## subdirectory exists and no flat head remains ; a flat-layout holder stays
## flat until holder-migrate moves it
sub root_subdir {
    my $root = shift;
    return 'r-' . substr( $root->{'root_id'}, 0, 7 );
}

## where this root's head lives : the flat head wins when both exist, so a ##
## holder interrupted mid-migration still reads as the old layout and a    ##
## rerun of migrate finishes it                                            ##
sub _head_locate {
    my ( $root, $dir ) = @_;
    my $head = _head_open( $root, $dir, FALSE );
    return ( $head, $dir ) if defined $head;
    my $tag = root_subdir($root);
    return ( undef, $dir ) if not holder_isdir( $dir, $tag );
    my $base = holder_sub_spec( $dir, $tag );
    return ( _head_open( $root, $base, FALSE ), $base );
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
    refuse('sealed head is truncated') if length $bytes < 40 + 16;
    my $sealed = $bytes;
    ## new heads carry a second, clear signature over the complete sealed  ##
    ## head : a blind receiver verifies it without the root symmetric keys ##
    if ( length $bytes >= 69 and substr( $bytes, -69, 5 ) eq "P7SH\x01" ) {
        refuse('outer head signature does not verify')
            if not verify(
            $root->{'signer'}->public,
            "p7 n7fs sealed head exterior v1\0" . substr( $bytes, 0, -69 ),
            substr( $bytes, -64 )
            );
        $sealed = substr( $bytes, 0, -69 );
    }
    my $version = unpack qw| Q> |, substr( $sealed, 0, 8 );
    my $writer  = substr( $sealed, 8, 16 );
    my $id      = $writer . substr( $sealed, 24, 16 );
    my $plain   = open_sealed_bytes( $root->{'keys'}, substr( $sealed, 40 ),
        qw| head |, $id, $version );
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
    refuse('old head form is refused')
        if ( $head->{'format'} // '' ) ne qw| n7fs-head-v2 |;
    refuse('clear and signed head fields differ')
        if ( $head->{'writer'} // '' ) ne b32($writer)
        or ( $head->{'version'} // 0 ) != $version;
    my $holder = unb32( $head->{'holder'} // '' );
    refuse('head holder id is invalid')
        if not defined $holder
        or length $holder != 16;
    refuse('head time is not a whole ntime')
        if ( $head->{'time'} // '' ) !~ m|\A\d+\z|;
    refuse('head map descriptor is missing')
        if ref $head->{'map'} ne qw| HASH |;
    return $head;
}

sub receipt_record {
    my ( $root, $spec, $receipt ) = @_;
    my $state = _state_read($root);
    my ($holder)
        = grep { ( $state->{'holders'}{$ARG}{'spec'} // '' ) eq $spec }
        keys $state->{'holders'}->%*;
    return undef if not defined $holder;
    $state->{'holders'}{$holder}{'receipt'} = {
        qw| v | => $receipt->{'version'} + 0,
        qw| t | => $receipt->{'time'} + 0,
        qw| c | => $receipt->{'coverage'} // qw| sampled |,
        qw| n | => $receipt->{'covered_nodes'} + 0,
    };
    _state_write( $root, $state );
    return $holder;
}

sub _peers {
    my ( $state, $holder, $root ) = @_;
    return {
        map {
            my $known = $state->{'holders'}{$ARG};
            my $drill;
            if ( defined $root and defined $root->{'host_dir'} ) {
                require AMOS7::N7FS::Drill;
                $drill
                    = AMOS7::N7FS::Drill::drill_latest( $root->{'host_dir'},
                    $root, $known->{'spec'} );
            }
            $ARG => {
                qw| v | => $known->{'version'} // 0,
                qw| t | => $known->{'time'}    // 0,
                ref $known->{'receipt'} eq qw| HASH |
                ? ( qw| r | => { $known->{'receipt'}->%{qw| v t c n |} } )
                : (),
                defined $drill
                ? ( qw| d | => {
                        qw| t |  => $drill->{'time'} + 0,
                        qw| tr | => $drill->{'tree'},
                        qw| f |  => $drill->{'files'} + 0,
                        qw| b |  => $drill->{'bytes'} + 0,
                    }
                    )
                : (),
            }
        }
        grep { $ARG ne $holder } keys $state->{'holders'}->%*
    };
}

sub _head_bytes {
    my ($root, $writer,  $version, $holder, $time,
        $map,  $journal, $peers,   $registry
    ) = @_;
    my $head = {
        qw| format |  => qw| n7fs-head-v2 |,
        qw| root_id | => $root->{'root_id'},
        qw| writer |  => b32($writer),
        qw| version | => $version + 0,
        qw| time |    => $time + 0,
        qw| holder |  => $holder,
        qw| map |     => $map,
        qw| journal | => $journal,
        qw| peers |   => $peers // {},
        defined $registry ? ( qw| registry | => $registry ) : (),
        qw| pub | => b32( $root->{'signer'}->public ),
    };
    $head->{'sig'} = b32( $root->{'signer'}->sign( $JSON->encode($head) ) );
    my $plain = $JSON->encode($head);
    my $id    = _long_id( $root->{'keys'}, $writer, qw| head |, $plain );
    my $sealed
        = pack( qw| Q> |, $version )
        . $writer
        . substr( $id, 16 )
        . seal_bytes( $root->{'keys'}, $plain, qw| head |, $id, $version );
    my $outer = $root->{'signer'}
        ->sign( "p7 n7fs sealed head exterior v1\0" . $sealed );
    return $sealed . "P7SH\x01" . $outer;
}

## a keyed plaintext id makes equal writer and version harmless when their ##
## plaintexts differ ; the domain remains bound in both the nonce and aad  ##
sub _map_plain {
    my ( $root, $base, $alt, $desc, $domain ) = @_;
    refuse('sealed map blob descriptor is invalid')
        if ref $desc ne qw| HASH |
        or ( $desc->{'version'} // '' ) !~ m|\A[1-9]\d*\z|;
    my $writer = unb32( $desc->{'writer'} // '' );
    my $id     = unb32( $desc->{'id'}     // '' );
    refuse('sealed map blob id is invalid')
        if not defined $writer
        or not defined $id
        or length $writer != 16
        or length $id != 32
        or substr( $id, 0, 16 ) ne $writer;
    my $bytes = eval { _read_blob( $base, $desc->{'blob'} ) };
    $bytes = _read_blob( $alt, $desc->{'blob'} )
        if not defined $bytes
        and defined $alt
        and $alt ne $base;
    refuse('sealed map blob size does not match its descriptor')
        if defined $desc->{'size'} and length($bytes) != $desc->{'size'};
    refuse('map id does not match its descriptor')
        if substr( $bytes, 0, 32 ) ne $id;
    my $plain = open_sealed_bytes(
        $root->{'keys'},
        substr( $bytes, 32 ),
        $domain // qw| map |,
        $id, $desc->{'version'}
    );
    refuse('sealed map shard checksum does not match')
        if defined $desc->{'checksum'}
        and bmw_b32( bmw384_bytes($plain) ) ne $desc->{'checksum'};
    return $plain;
}

sub _node_shard {
    my $address = shift // '';
    refuse('node address is invalid')
        if $address !~ m|\AV7[A-Z2-7]{5}/[A-Z2-7]{7}/([A-Z2-7]{77})\z|;
    return substr( $1, 0, 2 );
}

sub _lazy_nodes {
    my ( $root, $base, $alt, $shards ) = @_;
    my %nodes;
    tie %nodes, 'AMOS7::N7FS::Seal::LazyNodes', $root, $base, $alt, $shards;
    return \%nodes;
}

sub _map_blob_names {
    my ( $root, $base, $alt, $head, $map ) = @_;
    my %names = map { $ARG => TRUE }
        grep {defined} $head->{'map'}{'blob'}, $head->{'journal'},
        ( $head->{'registry'} ? $head->{'registry'}{'blob'} : () ),
        ( map { $ARG->{'blob'} } values $map->{'_shards'}->%* );
    $names{ $map->{'_tree_blob'}{'blob'} } = TRUE if $map->{'_tree_blob'};
    $names{$ARG} = TRUE
        for map { _manifest_blob_names( $root, $base, $alt, $ARG ) }
        values $map->{'trees'}->%*;
    return keys %names;
}

sub _context {
    my ( $root, $dir, $recover ) = @_;
    holder_mkdir($dir) if not $recover;
    $dir = holder_canonical($dir);
    holder_authorize( $dir, $root );
    my $state = _state_read($root);
    my ( $head, $base ) = _head_locate( $root, $dir );
    $state->{'head_registry'} = $head->{'registry'}
        if defined $head and defined $head->{'registry'};
    if ( not defined $head and not $recover ) {
        ## a writer on a holder with no head anywhere starts it in the    ##
        ## per-root layout : the subdirectory is created before any write ##
        my $tag = root_subdir($root);
        $base = holder_sub_spec( $dir, $tag );
        holder_mkdir($base) if not holder_isdir( $dir, $tag );
    }
    my ($known_spec)
        = grep { ( $state->{'holders'}{$ARG}{'spec'} // '' ) eq $dir }
        keys $state->{'holders'}->%*;
    refuse('pinned holder head is missing')
        if not defined $head and defined $known_spec;
    if ( defined $head ) {
        my $holder       = $head->{'holder'};
        my $wrong_holder = 'head belongs to another holder [ %s ]';
        refuse( $wrong_holder, substr $holder, 0, 7 )
            if defined $known_spec and $known_spec ne $holder;
        my $known  = $state->{'holders'}{$holder} // {};
        my $pinned = $known->{'version'}          // 0;
        refuse( 'pinned head rollback [ holder %d, pinned %d ]',
            $head->{'version'}, $pinned )
            if $head->{'version'} < $pinned;
        warn "n7fs : signed head time moved "
            . "backwards under a higher version\n"
            if $head->{'version'} > $pinned
            and defined $known->{'time'}
            and $head->{'time'} < $known->{'time'};
        warn "n7fs : signed head time is more than 1Y4 ahead of the clock\n"
            if $head->{'time'} > ntime_now() + parse_y_age('1Y4');
        $state->{'version'} = $head->{'version'}
            if $head->{'version'} > $state->{'version'};
        $state->{'last_time'} = $head->{'time'}
            if $head->{'time'} > ( $state->{'last_time'} // 0 );
        $state->{'holders'}{$holder} = {
            qw| spec |    => $dir,
            qw| version | => $head->{'version'},
            qw| time |    => $head->{'time'},
            ref $known->{'receipt'} eq qw| HASH |
            ? ( qw| receipt | => $known->{'receipt'} )
            : (),
        };
    }
    _state_write( $root, $state ) if not $recover;
    $state->{'new_holder'} = not defined $head;
    $state->{'holder_id'}
        = defined $head ? $head->{'holder'}
        : $recover      ? undef
        :                 b32( random_bytes(16) );
    my $map = {
        qw| root_id |    => $root->{'root_id'},
        qw| categories | => {},
        qw| trees |      => {},
        qw| _shards |    => {},
    };
    $map->{'nodes'} = _lazy_nodes( $root, $base, undef, $map->{'_shards'} );
    if ( defined $head ) {
        my $alt = holder_sub_spec( $dir, root_subdir($root) );
        ## mid-migration the root may already sit in the other layout dir ##
        my $plain  = _map_plain( $root, $base, $alt, $head->{'map'} );
        my $stored = eval { $JSON->decode($plain) };
        refuse(   'legacy single-map form is refused '
                . '; reseal into a sharded map' )
            if ref $stored eq qw| HASH | and exists $stored->{'nodes'};
        refuse('sealed map root is invalid')
            if ref $stored ne qw| HASH |
            or ( $stored->{'format'} // '' ) ne qw| n7fs-sharded-map-v1 |
            or ( $stored->{'depth'}  // 0 ) != 1
            or ref $stored->{'shards'} ne qw| HASH |
            or ( $stored->{'root_id'} // '' ) ne $root->{'root_id'};
        $map->{'categories'} = $stored->{'categories'} // {};
        $map->{'trees'}      = $stored->{'trees'}      // {};
        $map->{'retention'}  = $stored->{'retention'}  // {};
        $map->{'pins'}       = $stored->{'pins'}       // {};
        $map->{'superseded'} = $stored->{'superseded'} // {};
        $map->{'_shards'}    = $stored->{'shards'};
        $map->{'_tree_blob'} = $stored->{'tree_blob'};

        if ( $map->{'_tree_blob'} ) {
            my $tree_plain
                = _map_plain( $root, $base, $alt, $map->{'_tree_blob'},
                qw| map-tree | );
            $map->{'trees'} = eval { $JSON->decode($tree_plain) };
            refuse('sealed map trees are invalid')
                if ref $map->{'trees'} ne qw| HASH |;
        }
        $map->{'nodes'}
            = _lazy_nodes( $root, $base, $alt, $map->{'_shards'} );
    }
    return ( $state, $head, $map, $base );
}

package AMOS7::N7FS::Seal::LazyNodes;

use English;

sub TIEHASH {
    my ( $class, $root, $base, $alt, $shards ) = @_;
    return bless {
        qw| root |   => $root,
        qw| base |   => $base,
        qw| alt |    => $alt,
        qw| shards | => $shards,
        qw| cache |  => {},
        qw| plain |  => {},
    }, $class;
}

sub _load {
    my ( $self, $shard ) = @_;
    return $self->{'cache'}{$shard} if exists $self->{'cache'}{$shard};
    my $desc = $self->{'shards'}{$shard} // return $self->{'cache'}{$shard}
        = {};
    my $key = join "\0", $shard, @{$desc}{qw| blob writer version |};
    $self->{'plain'}{$key}
        //= AMOS7::N7FS::Seal::_map_plain( @{$self}{qw| root base alt |},
        $desc, qq|map-shard-$shard| );
    my $plain = $self->{'plain'}{$key};
    my $nodes = eval { $JSON->decode($plain) };
    AMOS7::N7FS::refuse('sealed map shard is invalid')
        if ref $nodes ne qw| HASH |;
    return $self->{'cache'}{$shard} = $nodes;
}

sub FETCH {
    my ( $self, $address ) = @_;
    return _load( $self, AMOS7::N7FS::Seal::_node_shard($address) )
        ->{$address};
}

sub EXISTS {
    my ( $self, $address ) = @_;
    return
        exists _load( $self, AMOS7::N7FS::Seal::_node_shard($address) )
        ->{$address};
}

sub STORE {
    my ( $self, $address, $entry ) = @_;
    _load( $self, AMOS7::N7FS::Seal::_node_shard($address) )->{$address}
        = $entry;
    return $entry;
}

sub DELETE {
    my ( $self, $address ) = @_;
    return
        delete _load( $self, AMOS7::N7FS::Seal::_node_shard($address) )
        ->{$address};
}

sub CLEAR {
    my $self = shift;
    _load( $self, $ARG )
        for keys %{ $self->{'shards'} }, keys %{ $self->{'cache'} };
    $ARG->%* = () for values $self->{'cache'}->%*;
    return;
}

sub FIRSTKEY {
    my $self = shift;
    my @addresses;
    my %shards = map { $ARG => 1 }
        keys %{ $self->{'shards'} }, keys %{ $self->{'cache'} };
    foreach my $shard ( keys %shards ) {
        push @addresses, keys %{ _load( $self, $shard ) };
    }
    @addresses = sort @addresses;
    $self->{'iteration'} = \@addresses;
    return shift $self->{'iteration'}->@*;
}

sub NEXTKEY { return shift $ARG[0]->{'iteration'}->@* }

sub SCALAR {
    my $self   = shift;
    my $count  = 0;
    my %shards = map { $ARG => 1 }
        keys %{ $self->{'shards'} }, keys %{ $self->{'cache'} };
    $count += scalar keys %{ _load( $self, $ARG ) } for keys %shards;
    return $count;
}

package AMOS7::N7FS::Seal;

## a holder reached under a new spec keeps its identity in the head ; the ##
## version pin moves only after that identity and the version both check  ##
sub holder_respec {
    my ( $root, $old, $new, $dry_run ) = @_;
    $old = holder_canonical($old);
    $new = holder_canonical($new);
    holder_authorize( $new, $root );
    my $state = _state_read($root);
    my ($old_id)
        = grep { ( $state->{'holders'}{$ARG}{'spec'} // '' ) eq $old }
        keys $state->{'holders'}->%*;
    my $pinned
        = defined $old_id
        ? $state->{'holders'}{$old_id}{'version'} // 0
        : 0;
    my ($head) = _head_locate( $root, $new );
    refuse('no sealed head under the new spec') if not defined $head;
    refuse(
        'head belongs to another holder [ %s ]',
        substr $head->{'holder'},
        0, 7
    ) if defined $old_id and $head->{'holder'} ne $old_id;
    refuse( 'the new spec serves an older head [ %d, pinned %d ]',
        $head->{'version'}, $pinned )
        if $head->{'version'} < $pinned;
    return $head->{'version'} if $dry_run;
    $state->{'holders'}{ $head->{'holder'} } = {
        qw| spec |    => $new,
        qw| version | => $head->{'version'},
        qw| time |    => $head->{'time'},
        (   defined $old_id
                and ref $state->{'holders'}{$old_id}{'receipt'} eq qw| HASH |
            )
        ? ( qw| receipt | => $state->{'holders'}{$old_id}{'receipt'} )
        : (),
    };
    _state_write( $root, $state );
    return $head->{'version'};
}

## sync holder ids learned from signed heads into the authority, then return
## the config text sealed into every head's registry descriptor
sub _registry_text {
    my ( $root, $state, $pin, $holder ) = @_;
    require AMOS7::N7FS::Placement;
    my $holders = AMOS7::N7FS::Placement::holders_load( qw| root | => $root );
    my $changed = 0;
    foreach my $name ( keys %{$holders} ) {
        my $h = $holders->{$name};
        my ($id) = grep {
            ( $state->{'holders'}{$ARG}{'spec'} // '' ) eq $h->{'spec'}
            }
            keys $state->{'holders'}->%*;
        $id = $holder
            if defined $holder and $h->{'spec'} eq $pin;
        next if not defined $id or ( $h->{'id'} // '' ) eq $id;
        $h->{'id'} = $id;
        $changed++;
    }
    AMOS7::N7FS::Placement::holders_save( $holders, qw| root | => $root )
        if $changed;
    return AMOS7::N7FS::Placement::holders_config($holders);
}

sub registry_open {
    my ( $root, $head, $base, $alt ) = @_;
    refuse('this head names no sealed holder registry')
        if ref $head->{'registry'} ne qw| HASH |;
    my $plain = _map_plain( $root, $base, $alt, $head->{'registry'},
        qw| registry | );
    require AMOS7::N7FS::Placement;
    return AMOS7::N7FS::Placement::holders_parse($plain);
}

## a registry edit refreshes every existing head ; a new empty holder gets its
## first registry on its first seal, and an unreachable existing holder fails
sub registry_publish {
    my $root = shift;
    require AMOS7::N7FS::Placement;
    my $holders = AMOS7::N7FS::Placement::holders_load( qw| root | => $root );
    my $written = 0;
    foreach my $name ( sort keys %{$holders} ) {
        my ($head) = _head_locate( $root, $holders->{$name}{'spec'} );
        next if not defined $head;
        head_refresh( $root, $holders->{$name}{'spec'} );
        $written++;
    }
    return $written;
}

sub _commit {
    my ( $root, $base, $pin, $state, $map, $operation ) = @_;
    my $registry
        = _registry_text( $root, $state, $pin, $state->{'holder_id'} );
    my $writer  = _writer($state);
    my $version = $state->{'version'} + 1;
    my $holder  = $state->{'holder_id'} // refuse('commit has no holder id');
    my $time    = ntime_now();
    $time = $state->{'last_time'} + 1
        if $time <= ( $state->{'last_time'} // 0 );
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
    my $categories = {};

    foreach my $name ( keys $map->{'categories'}->%* ) {
        $categories->{$name} = { $map->{'categories'}{$name}->%* };
        delete $categories->{$name}{'_key'};
    }
    my %sealed_map;
    my $seal_map = sub {
        my ( $plain, $domain ) = @_;
        my $sum = bmw_b32( bmw384_bytes($plain) );
        return $sealed_map{"$domain\0$sum"} if $sealed_map{"$domain\0$sum"};
        my $id = _long_id( $root->{'keys'}, $writer, $domain, $plain );
        my $bytes
            = $writer
            . substr( $id, 16 )
            . seal_bytes( $root->{'keys'}, $plain, $domain, $id, $version );
        return $sealed_map{"$domain\0$sum"} = {
            qw| blob |     => _write_blob( $root, $base, $bytes, qw| map | ),
            qw| checksum | => $sum,
            qw| id |       => b32($id),
            qw| writer   | => b32($writer),
            qw| version  | => $version,
            qw| size     | => length($bytes),
        };
    };
    my $nodes       = tied %{ $map->{'nodes'} };
    my %shards      = %{ $map->{'_shards'} // {} };
    my %shard_names = map { $ARG => TRUE }
        keys %shards, keys %{ $nodes->{'cache'} };
    foreach my $shard ( keys %shard_names ) {
        next if not exists $nodes->{'cache'}{$shard} and $shards{$shard};
        ## an empty shard has no blob : the root simply does not list it ##
        if ( not %{ $nodes->{'cache'}{$shard} // {} } ) {
            delete $shards{$shard};
            next;
        }
        my $plain = $JSON->encode( $nodes->{'cache'}{$shard} );
        my $sum   = bmw_b32( bmw384_bytes($plain) );
        next if ( $shards{$shard}{'checksum'} // '' ) eq $sum;
        $shards{$shard} = $seal_map->( $plain, qq|map-shard-$shard| );
    }
    my $tree_plain = $JSON->encode( $map->{'trees'} // {} );
    my $stored     = {
        qw| format |     => qw| n7fs-sharded-map-v1 |,
        qw| depth |      => 1,
        qw| root_id |    => $root->{'root_id'},
        qw| categories | => $categories,
        qw| retention |  => $map->{'retention'}  // {},
        qw| pins |       => $map->{'pins'}       // {},
        qw| superseded | => $map->{'superseded'} // {},
        qw| shards |     => \%shards,
    };
    if ( length $tree_plain >= 1024**2 ) {
        my $tree_sum = bmw_b32( bmw384_bytes($tree_plain) );
        $stored->{'tree_blob'}
            = ( $map->{'_tree_blob'}{'checksum'} // '' ) eq $tree_sum
            ? $map->{'_tree_blob'}
            : $seal_map->( $tree_plain, qw| map-tree | );
    } else {
        $stored->{'trees'} = $map->{'trees'} // {};
    }
    my $map_desc = $seal_map->( $JSON->encode($stored), qw| map | );
    my $map_name = $map_desc->{'blob'};
    $map->{'_shards'}    = \%shards;
    $map->{'_tree_blob'} = $stored->{'tree_blob'};
    $nodes->{'shards'}   = \%shards;
    my $registry_sum = bmw_b32( bmw384_bytes($registry) );
    my $registry_desc
        = ( $state->{'head_registry'}{'checksum'} // '' ) eq $registry_sum
        ? $state->{'head_registry'}
        : $seal_map->( $registry, qw| registry | );
    $state->{'head_registry'} = $registry_desc;
    fault(qw| seal:after-map |);
    my $journal = $JSON->encode(
        {   qw| writer |    => b32($writer),
            qw| version |   => $version,
            qw| map |       => $map_name,
            qw| operation | => $operation,
        }
    );
    my $journal_id
        = _long_id( $root->{'keys'}, $writer, qw| journal |, $journal );
    my $journal_name = _write_blob(
        $root, $base,
        $writer
            . substr( $journal_id, 16 )
            . seal_bytes(
            $root->{'keys'}, $journal, qw| journal |,
            $journal_id,     $version
            ),
        qw| journal |
    );
    fault(qw| seal:after-journal |);
    my $head_name = _head_name($root);
    my $head_bytes
        = _head_bytes( $root, $writer, $version, $holder, $time,
        $map_desc, $journal_name, _peers( $state, $holder, $root ),
        $registry_desc );

    if ( holder_parse($base)->{'type'} eq qw| ssh | ) {
        my $spool = "$state_dir/spool";
        make_dirs( $spool, 0700 );
        my $path = "$spool/$head_name";
        write_new_file( $path, $head_bytes ) if not -e $path;
        holder_put( $base, $path, $head_name, qw| head |, TRUE );
        unlink $path or refuse('cannot remove confirmed head spool');
    } else {
        _replace_file( "$base/$head_name", $head_bytes );
    }
    $state->{'holders'}{$holder} = {
        qw| spec |    => $pin,
        qw| version | => $version,
        qw| time |    => $time,
        ref $state->{'holders'}{$holder}{'receipt'} eq qw| HASH |
        ? ( qw| receipt | => $state->{'holders'}{$holder}{'receipt'} )
        : (),
    };
    $state->{'last_time'} = $time;
    _state_write( $root, { %{$state}, qw| version | => $version } );
    opendir( my $reservations, "$state_dir/reservations" )
        or refuse('cannot read version reservations for pruning');
    my @expired
        = grep { m|\A[1-9]\d*\z| and $ARG <= $version } readdir $reservations;
    closedir $reservations;
    unlink "$state_dir/reservations/$ARG"
        or refuse( 'cannot remove version reservation %s', $ARG )
        for @expired;
    fault(qw| seal:after-head |);
    return $version;
}

sub head_survey {
    my ( $root, $holders ) = @_;
    my $state = _state_read($root);
    my %survey;
    foreach my $name ( sort keys %{$holders} ) {
        my $spec = holder_canonical( $holders->{$name} );
        my ( $head, $base ) = eval { _head_locate( $root, $spec ) };
        $survey{$name} = {
            qw| spec |  => $spec,
            qw| base |  => $base,
            qw| head |  => $head,
            qw| error | => $EVAL_ERROR || undef,
            qw| floor | => 0,
        };
        next if not defined $head;
        $survey{$name}{'holder'} = $head->{'holder'};
    }
    foreach my $name ( keys %survey ) {
        my $item = $survey{$name};
        my $head = $item->{'head'} // next;
        my $id   = $head->{'holder'};
        my $home = $state->{'holders'}{$id};
        if ( defined $home ) {
            $item->{'floor'}   = $home->{'version'} // 0;
            $item->{'witness'} = 'home state';
        }
        foreach my $other_name ( keys %survey ) {
            next if $other_name eq $name;
            my $other = $survey{$other_name}{'head'} // next;
            my $peer  = $other->{'peers'}{$id}       // next;
            refuse('signed head peer record is invalid')
                if ref $peer ne qw| HASH |
                or ( $peer->{'v'} // '' ) !~ m|\A\d+\z|
                or ( $peer->{'t'} // '' ) !~ m|\A\d+\z|;
            my $r = $peer->{'r'};
            refuse('signed head receipt summary is invalid')
                if defined $r
                and ( ref $r ne qw| HASH |
                or ( $r->{'v'} // '' ) !~ m|\A\d+\z|
                or ( $r->{'t'} // '' ) !~ m|\A\d+\z|
                or ( $r->{'n'} // '' ) !~ m|\A\d+\z|
                or ( $r->{'c'} // '' )
                !~ m{\A(?:sizes-only|sampled|full|scrub)\z} );
            next if $peer->{'v'} <= $item->{'floor'};
            $item->{'floor'}   = $peer->{'v'};
            $item->{'witness'} = $other_name;
            $item->{'seen'}    = $peer->{'t'};
        }
        $item->{'stale'} = $head->{'version'} < $item->{'floor'};
        $item->{'verdict'}
            = $item->{'stale'}   ? qw| stale |
            : keys(%survey) == 1 ? qw| unverified |
            :                      qw| current |;
    }
    return \%survey;
}

sub head_refresh {
    my ( $root, $dir ) = @_;
    my $pin = holder_canonical($dir);
    my ( $state, $head, undef, $base ) = _context( $root, $pin, TRUE );
    refuse('no sealed head to refresh') if not defined $head;
    my $registry = _registry_text( $root, $state, $pin, $head->{'holder'} );
    my $writer   = _writer($state);
    my $version  = $state->{'version'} + 1;
    my $holder   = $head->{'holder'};
    my $time     = ntime_now();
    $time = $state->{'last_time'} + 1
        if $time <= ( $state->{'last_time'} // 0 );
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
    _state_write( $root, { %{$state}, qw| version | => $version } );
    my $registry_sum = bmw_b32( bmw384_bytes($registry) );
    my $registry_desc
        = ( $head->{'registry'}{'checksum'} // '' ) eq $registry_sum
        ? $head->{'registry'}
        : _manifest_seal( $root, $base, $registry, qw| registry |, $version );
    my $head_bytes
        = _head_bytes( $root, $writer, $version, $holder, $time,
        $head->{'map'}, $head->{'journal'}, _peers( $state, $holder, $root ),
        $registry_desc );
    my $head_name = _head_name($root);

    if ( holder_parse($base)->{'type'} eq qw| ssh | ) {
        my $spool = "$state_dir/spool";
        make_dirs( $spool, 0700 );
        my $path = "$spool/$head_name";
        write_new_file( $path, $head_bytes ) if not -e $path;
        holder_put( $base, $path, $head_name, qw| head |, TRUE );
        unlink $path or refuse('cannot remove confirmed head spool');
    } else {
        _replace_file( "$base/$head_name", $head_bytes );
    }
    $state->{'holders'}{$holder} = {
        qw| spec |    => $pin,
        qw| version | => $version,
        qw| time |    => $time,
        ref $state->{'holders'}{$holder}{'receipt'} eq qw| HASH |
        ? ( qw| receipt | => $state->{'holders'}{$holder}{'receipt'} )
        : (),
    };
    $state->{'last_time'} = $time;
    _state_write( $root, { %{$state}, qw| version | => $version } );
    unlink "$state_dir/reservations/$version"
        or refuse( 'cannot remove version reservation %s', $version );
    return {
        qw| version | => $version,
        qw| time |    => $time,
        qw| map |     => $head->{'map'}{'blob'},
    };
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

sub _manifest_entry_limit {
    return $ENV{'N7FS_TEST_MANIFEST_ENTRIES'} // 1024;
}

sub _manifest_seal {
    my ( $root, $base, $plain, $domain, $version ) = @_;
    my $sum    = bmw_b32( bmw384_bytes($plain) );
    my $writer = _writer( _state_read($root) );
    my $id     = _long_id( $root->{'keys'}, $writer, $domain, $plain );
    my $bytes
        = $writer
        . substr( $id, 16 )
        . seal_bytes( $root->{'keys'}, $plain, $domain, $id, $version );
    return {
        qw| blob |     => _write_blob( $root, $base, $bytes, qw| manifest | ),
        qw| checksum | => $sum,
        qw| id |       => b32($id),
        qw| writer |   => b32($writer),
        qw| version |  => $version,
        qw| size |     => length($bytes),
    };
}

sub _manifest_plain {
    my ( $root, $base, $alt, $desc, $domain ) = @_;
    refuse('sealed manifest descriptor is invalid')
        if ref $desc ne qw| HASH |
        or ( $desc->{'version'} // '' ) !~ m|\A[1-9]\d*\z|;
    my $id = unb32( $desc->{'id'} // '' );
    refuse('sealed manifest id is invalid')
        if not defined $id
        or length $id != 32;
    my $writer = unb32( $desc->{'writer'} // '' );
    refuse('sealed manifest writer is invalid')
        if not defined $writer
        or length $writer != 16
        or substr( $id, 0, 16 ) ne $writer;
    my $bytes = eval { _read_blob( $base, $desc->{'blob'} ) };
    if ( not defined $bytes ) {
        die $EVAL_ERROR if not defined $alt or $alt eq $base;
        $bytes = _read_blob( $alt, $desc->{'blob'} );
    }
    refuse('sealed manifest size does not match its descriptor')
        if defined $desc->{'size'} and length($bytes) != $desc->{'size'};
    refuse('manifest id does not match its descriptor')
        if substr( $bytes, 0, 32 ) ne $id;
    my $plain = open_sealed_bytes( $root->{'keys'}, substr( $bytes, 32 ),
        $domain, $id, $desc->{'version'} );
    refuse('sealed manifest checksum does not match')
        if bmw_b32( bmw384_bytes($plain) ) ne ( $desc->{'checksum'} // '' );
    return $plain;
}

sub _chunk_tree_manifest {
    my ( $root, $base, $id, $tree, $previous, $version ) = @_;
    open( my $fh, '<:raw', _content_path( $id, $tree->{'manifest'} ) )
        or refuse( 'cannot read tree manifest %s', $tree->{'manifest'} );
    my $line = <$fh>;
    my $head = eval { $JSON->decode( $line // '' ) };
    refuse('tree manifest header is invalid')
        if ref $head ne qw| HASH |
        or ( $head->{'manifest'} // 0 ) != 1;
    my ( @order, %directories );
    my $position = 0;
    while ( my $line = <$fh> ) {
        my $entry = eval { $JSON->decode($line) };
        refuse('tree manifest entry is invalid') if ref $entry ne qw| HASH |;
        my $path
            = ( $entry->{'p'} // '' ) eq ''
            ? ''
            : unb32( $entry->{'p'} // '' );
        refuse('tree manifest path is invalid') if not defined $path;
        my $parent = $path;
        $parent =~ s|/?[^/]+\z||;
        push @order, $parent if not exists $directories{$parent};
        push @{ $directories{$parent} }, [ $position++, $entry ];
    }
    close $fh;
    my %previous
        = map { join( "\0", @{$ARG}{qw| path part checksum |} ) => $ARG }
        @{ $previous->{'chunks'} // [] };
    my @chunks;
    foreach my $path (@order) {
        my $entries = $directories{$path};
        my $limit   = _manifest_entry_limit();
        refuse('manifest directory chunk size must be positive')
            if $limit !~ m|\A[1-9]\d*\z|;
        for ( my $start = 0; $start < @{$entries}; $start += $limit ) {
            my $part = int( $start / $limit );
            my $end  = $start + $limit - 1;
            $end = $#{$entries} if $end > $#{$entries};
            my @slice = @{$entries}[ $start .. $end ];
            my $plain = $JSON->encode( [ map { $ARG->[1] } @slice ] );
            my $sum   = bmw_b32( bmw384_bytes($plain) );
            my $key   = join "\0", $path, $part, $sum;
            my $desc  = $previous{$key}
                // _manifest_seal( $root, $base, $plain,
                qw| manifest-chunk |, $version );
            push @chunks,
                {
                %{$desc},
                qw| path |      => $path,
                qw| part |      => $part,
                qw| positions | => [ map { $ARG->[0] } @slice ],
                };
        }
    }
    my $index_plain = $JSON->encode(
        {   qw| format | => qw| n7fs-chunked-manifest-v1 |,
            qw| header | => $head,
            qw| chunks | => \@chunks,
        }
    );
    return {
        %{$tree},
        qw| index | => _manifest_seal(
            $root, $base, $index_plain, qw| manifest-index |, $version
        ),
    };
}

sub _manifest_index_read {
    my ( $root, $base, $alt, $tree ) = @_;
    refuse('legacy single-blob tree manifest is refused')
        if ref $tree ne qw| HASH |
        or ref $tree->{'index'} ne qw| HASH |;
    my $plain = _manifest_plain( $root, $base, $alt, $tree->{'index'},
        qw| manifest-index | );
    my $index = eval { $JSON->decode($plain) };
    refuse('sealed manifest index is invalid')
        if ref $index ne qw| HASH |
        or ( $index->{'format'} // '' ) ne qw| n7fs-chunked-manifest-v1 |
        or ref $index->{'header'} ne qw| HASH |
        or ref $index->{'chunks'} ne qw| ARRAY |;
    return $index;
}

sub _manifest_chunk_read {
    my ( $root, $base, $alt, $chunk ) = @_;
    refuse('sealed manifest chunk position list is invalid')
        if ref $chunk->{'positions'} ne qw| ARRAY |;
    my $plain
        = _manifest_plain( $root, $base, $alt, $chunk, qw| manifest-chunk | );
    my $entries = eval { $JSON->decode($plain) };
    refuse('sealed manifest chunk is invalid')
        if ref $entries ne qw| ARRAY |
        or @{$entries} != @{ $chunk->{'positions'} };
    return $entries;
}

sub _manifest_read {
    my ( $root, $base, $alt, $tree ) = @_;
    my $index = _manifest_index_read( $root, $base, $alt, $tree );
    my @entries;
    foreach my $chunk ( $index->{'chunks'}->@* ) {
        my $entries = _manifest_chunk_read( $root, $base, $alt, $chunk );
        push @entries,
            map { [ $chunk->{'positions'}[$ARG], $entries->[$ARG] ] }
            0 .. $#{$entries};
    }
    return ( $index->{'header'},
        map { $ARG->[1] } sort { $a->[0] <=> $b->[0] } @entries );
}

sub _manifest_verify {
    my ( $root, $base, $alt, $name, $tree ) = @_;
    my ( $head, @entries ) = _manifest_read( $root, $base, $alt, $tree );
    my $plain = join '',
        $JSON->encode($head) . "\n",
        map { $JSON->encode($ARG) . "\n" } @entries;
    my ( undef, undef, $expected ) = split m|/|, $tree->{'manifest'} // '';
    refuse( 'rebuilt tree manifest does not match : %s', $name )
        if not defined $expected
        or bmw_b32( bmw384_bytes($plain) ) ne $expected;
    return TRUE;
}

sub _manifest_restore {
    my ( $root, $base, $alt, $tree, $target, $name ) = @_;
    my ( $head, @entries ) = _manifest_read( $root, $base, $alt, $tree );
    my $plain = join '',
        $JSON->encode($head) . "\n",
        map { $JSON->encode($ARG) . "\n" } @entries;
    my ( undef, undef, $expected ) = split m|/|, $tree->{'manifest'} // '';
    refuse( 'rebuilt tree manifest does not match : %s', $name // '' )
        if not defined $expected
        or bmw_b32( bmw384_bytes($plain) ) ne $expected;
    write_new_file( $target, $plain );
    return TRUE;
}

sub _manifest_blob_names {
    my ( $root, $base, $alt, $tree ) = @_;
    my $index = _manifest_index_read( $root, $base, $alt, $tree );
    return ( $tree->{'index'}{'blob'},
        map { $ARG->{'blob'} } $index->{'chunks'}->@* );
}

## disk <-> root binding [ review finding 6 ] : the first seal of a disk    ##
## writes <disk>/.n7fs/seal-root, signed by the sealing root. every later   ##
## seal or unseal of that disk refuses any other root, so an unattended job ##
## holding only a service root can neither read nor write a disk            ##
## [ or its categories ] that belong to the main root                       ##
sub _binding_signed {
    my ( $root, $disk ) = @_;
    return "p7 n7fs disk seal binding v1\0" . $disk . "\0"
        . $root->{'root_id'};
}

sub _disk_binding_check {
    my ( $id, $root, $bind ) = @_;
    my $path  = "$id->{'path'}/.n7fs/seal-root";
    my $bytes = read_file($path);
    if ( not defined $bytes ) {
        return TRUE if not $bind;
        my $binding = {
            qw| v |       => 1,
            qw| disk |    => $id->{'disk'},
            qw| root_id | => $root->{'root_id'},
            qw| pub |     => b32( $root->{'signer'}->public ),
            qw| sig |     => b32(
                $root->{'signer'}
                    ->sign( _binding_signed( $root, $id->{'disk'} ) )
            ),
        };
        my $tmp = "$path.new";
        refuse('disk seal binding temporary exists') if -e $tmp or -l $tmp;
        write_new_file( $tmp, $JSON->encode($binding) );
        rename $tmp, $path
            or
            refuse( 'cannot publish the disk seal binding : %s', $OS_ERROR );
        sync_dir("$id->{'path'}/.n7fs");
        return TRUE;
    }
    my $binding = eval { $JSON->decode($bytes) };
    my $bad     = (
               ref $binding ne qw| HASH |
            or ( $binding->{'v'}       // '' ) != 1
            or ( $binding->{'disk'}    // '' ) ne $id->{'disk'}
            or ( $binding->{'root_id'} // '' ) !~ m|\A[A-Z2-7]{77}\z|
    );
    my $pub = $bad ? undef : unb32( $binding->{'pub'} // '' );
    my $sig = $bad ? undef : unb32( $binding->{'sig'} // '' );
    $bad = TRUE
        if not $bad
        and (
           not defined $pub
        or not defined $sig
        or b32( bmw384_bytes( 'p7 n7fs seal root id v1' . $pub ) ) ne
        $binding->{'root_id'}
        or not verify(
            $pub,
            "p7 n7fs disk seal binding v1\0"
                . $id->{'disk'} . "\0"
                . $binding->{'root_id'},
            $sig
        )
        );
    refuse('disk seal binding is invalid') if $bad;
    refuse(
        'disk is sealed under another root [ tag %s ]',
        substr( $binding->{'root_id'}, 0, 7 )
    ) if $binding->{'root_id'} ne $root->{'root_id'};
    return TRUE;
}

sub _select_addresses {
    my %opt = @_;
    $opt{'trees'} //= [];
    ## the sealing root id, for category binding checks, before the hash is ##
    ## dropped for the disk helpers                                         ##
    my $root_id = ref $opt{'root'} ? $opt{'root'}{'root_id'} : undef;
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
    my %manifest_only
        = map { $ARG => TRUE } @{ $opt{'tree_manifests'} // [] };
    foreach my $name ( keys $replay->{'trees'}->%* ) {
        my $tree   = $replay->{'trees'}{$name};
        my $wanted = $opt{'all_trees'}
            || grep { $ARG eq $name } $opt{'trees'}->@*;
        my @files = _manifest_files( $id, $tree->{'manifest'} );
        $wanted ||= grep { $selected{$ARG} } @files
            if defined $opt{'category'};
        next if not $wanted and not $manifest_only{$name};
        my %distinct = map { $ARG => TRUE } @files;
        $trees{$name} = {
            qw| manifest |        => $tree->{'manifest'},
            qw| created |         => $tree->{'created'},
            qw| files |           => scalar keys %distinct,
            qw| _file_addresses | => [ sort keys %distinct ],
        };
        if ($wanted) {
            $selected{$ARG} = 1 for @files;
        }
    }
    foreach my $name ( $opt{'trees'}->@*, @{ $opt{'tree_manifests'} // [] } )
    {
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
            ## a category bound to one root refuses every other root        ##
            ## [ review finding 6 ] : the service root cannot seal or place ##
            ## what belongs to the main root, and vice versa                ##
            refuse( 'category %s is sealed under another root', $category )
                if defined $root_id
                and defined $policy
                and defined $policy->{'root'}
                and $policy->{'root'} ne $root_id;
        }
    }
    return ( $id, $replay, \@addresses, \%trees, \%node_categories );
}

sub _tree_inventory {
    my ( $map, $trees ) = @_;
    my $changes = 0;
    foreach my $name ( keys %{$trees} ) {
        my $record = $map->{'trees'}{$name} // next;
        my $held   = grep { exists $map->{'nodes'}{$ARG} }
            @{ $trees->{$name}{'_file_addresses'} // [] };
        my $files = $trees->{$name}{'files'} // 0;
        my $state = $held == $files ? qw| complete | : qw| partial |;
        next
            if ( $record->{'files'} // -1 ) == $files
            and ( $record->{'held'}  // -1 ) == $held
            and ( $record->{'state'} // '' ) eq $state;
        @{$record}{qw| files held state |} = ( $files, $held, $state );
        $changes++;
    }
    return $changes;
}

sub seal_nodes {
    my %opt = @_;
    my ( $root, $dir ) = @opt{qw| root holder |};
    my ( $id, $replay, $addresses, $trees, $node_categories )
        = _select_addresses(%opt);
    ## bind the disk to this root on its first seal ; refuse any other root ##
    _disk_binding_check( $id, $root, TRUE );
    holder_mkdir($dir);
    my ( $counter, $head, $map, $base ) = _context( $root, $dir, FALSE );
    my $pin = holder_canonical($dir);
    $map->{'_root_keys'} = $root->{'keys'};
    my $tree_changes = 0;
    foreach my $name ( keys %{$trees} ) {
        my %owners = %{
            ref $map->{'trees'}{$name}{'disks'} eq qw| HASH |
            ? $map->{'trees'}{$name}{'disks'}
            : {}
        };
        $owners{ $id->{'disk'} } = TRUE;
        if ( ( $map->{'trees'}{$name}{'manifest'} // '' ) ne
            $trees->{$name}{'manifest'} ) {
            my $previous = {
                qw| chunks | => [
                    map {
                        @{ _manifest_index_read( $root, $base, undef, $ARG )
                                ->{'chunks'} }
                    }
                    grep { ref $ARG->{'index'} eq qw| HASH | }
                        values $map->{'trees'}->%*
                ]
            };
            my $source = {
                qw| manifest | => $trees->{$name}{'manifest'},
                qw| created |  => $trees->{$name}{'created'},
                qw| files |    => $trees->{$name}{'files'},
            };
            $map->{'trees'}{$name}
                = _chunk_tree_manifest( $root, $base, $id, $source,
                $previous, $counter->{'version'} + 1 );
            $map->{'trees'}{$name}{'disks'} = \%owners;
            $tree_changes++;
        } elsif ( not $map->{'trees'}{$name}{'disks'}{ $id->{'disk'} } ) {
            $map->{'trees'}{$name}{'disks'} = \%owners;
            $tree_changes++;
        }
    }
    $tree_changes += _tree_inventory( $map, $trees );
    my @new;
    my @pending_files;
    my ( $sealed, $batch_bytes, $tagged ) = ( 0, 0, 0 );
    my $commit_bytes = $opt{'commit_bytes'} // $ENV{'N7FS_TEST_SEAL_BYTES'}
        // 64 * 1024**2;
    my $commit_age = $opt{'commit_age'} // $ENV{'N7FS_TEST_SEAL_AGE'}
        // parse_y_age('4Y5');
    $commit_age = parse_y_age($commit_age)
        if defined $commit_age and $commit_age !~ m|\A\d+(?:\.\d+)?\z|;
    refuse('seal commit byte limit must be positive')
        if $commit_bytes !~ m|\A\d+(?:\.\d+)?\z| or $commit_bytes <= 0;
    refuse('seal commit age must be a positive ntime or Y age')
        if not defined $commit_age or $commit_age <= 0;
    my $last_commit = ntime_now();
    my %pack        = ( qw| bytes | => "P7SP\x01", qw| entries | => [] );
    my $flush       = sub {
        return if not $pack{'entries'}->@*;
        my $name = _write_blob( $root, $base, $pack{'bytes'}, qw| pack | );
        $ARG->{'blob'} = $name for $pack{'entries'}->@*;
        %pack = ( qw| bytes | => "P7SP\x01", qw| entries | => [] );
        fault(qw| seal:after-pack |);
    };
    foreach my $address ( @{$addresses} ) {
        ## a node already mapped from another disk gains this disk's id ##
        if ( exists $map->{'nodes'}{$address} ) {
            my $entry = $map->{'nodes'}{$address};
            refuse( 'local node is missing : %s', $address )
                if not -f _content_path( $id, $address );
            if ( not $entry->{'disks'}{ $id->{'disk'} } ) {
                $entry->{'disks'}{ $id->{'disk'} } = TRUE;
                $tagged++;
            }
            next;
        }
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
            = _node_blob( $path, $keys, $base, $bmw, $root, TRUE );
        my ( $length, $offset ) = ( undef, 0 );
        if ( defined $packed ) {
            $offset = length $pack{'bytes'};
            $length = length $packed;
            $pack{'bytes'} .= $packed;
        } else {
            $length = holder_size( $base, $name );
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
            qw| disks |    => { $id->{'disk'} => TRUE },
            qw| wraps |    => \%wraps,
            ## the head version that added the entry : incremental receipts
            ## cover every entry added at or below their version
            qw| added |  => $counter->{'version'} + 1,
            qw| layout | => {
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
        if ( $batch_bytes >= $commit_bytes
            or ntime_now() - $last_commit >= $commit_age ) {
            $flush->();
            _tree_inventory( $map, $trees );
            $counter->{'version'} = _commit( $root, $base, $pin, $counter,
                $map, { qw| seal | => [@new] } );
            @new          = ();
            $batch_bytes  = 0;
            $tree_changes = 0;
            $tagged       = 0;
            $last_commit  = ntime_now();
            unlink for @pending_files;
            @pending_files = ();
        }
    }
    $flush->();
    $tree_changes += _tree_inventory( $map, $trees );
    delete $map->{'_root_keys'};
    if ( @new or $tree_changes or $tagged ) {
        $counter->{'version'}
            = _commit( $root, $base, $pin, $counter, $map,
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

sub _restore_sealed_tree {
    my %opt  = @_;
    my $tree = $opt{'map'}{'trees'}{ $opt{'address'} };
    refuse( 'no live tree named %s', $opt{'address'} ) if not defined $tree;
    my $sources = $opt{'sources'} // [
        {   qw| holder | => $opt{'holder'},
            qw| map |    => $opt{'map'},
        }
    ];
    require File::Temp;
    my $tmp = File::Temp::tempdir(
        'n7fs-sealed-tree-XXXXXX',
        TMPDIR  => 1,
        CLEANUP => 1
    );
    my $manifest = "$tmp/manifest";
    _manifest_restore( $opt{'root'}, $opt{'holder'}, undef,
        $tree, $manifest, $opt{'address'} );
    require AMOS7::N7FS::Tree;
    return AMOS7::N7FS::Tree::tree_restore(
        qw| name |           => $opt{'address'},
        qw| target |         => $opt{'target'},
        qw| owners |         => $opt{'owners'} ? TRUE : FALSE,
        qw| tree_record |    => { %{$tree}, qw| name | => $opt{'address'} },
        qw| manifest_path |  => $manifest,
        qw| content_source | => sub {
            my ( $address, $dest ) = @_;
            my ($source)
                = grep { exists $ARG->{'map'}{'nodes'}{$address} }
                @{$sources};
            refuse( 'address is not in the supplied sealed maps : %s',
                $address )
                if not defined $source;
            _restore_node( $opt{'root'}, $source->{'holder'},
                $source->{'map'}, $address, $dest );
        },
    );
}

sub unseal_address {
    my %opt = @_;
    my ( undef, undef, $map, $base )
        = _context( @opt{qw| root holder |}, FALSE );
    return _restore_sealed_tree(
        %opt,
        qw| holder | => $base,
        qw| map |    => $map
    ) if $opt{'address'} !~ m|\AV7[A-Z2-7]{5}/|;
    _restore_node( $opt{'root'}, $base, $map, $opt{'address'},
        $opt{'target'} );
    return TRUE;
}

sub seal_recover {
    my %opt = @_;
    my @specs
        = ref $opt{'holders'} eq qw| ARRAY |
        ? $opt{'holders'}->@*
        : ( $opt{'holder'} );
    refuse('seal-recover needs -from <holder-dir>') if not @specs;
    my ( $registry, $registry_head );
    if (   $opt{'all_holders'}
        or $opt{'show_holders'}
        or $opt{'import_holders'} ) {
        my $top = holder_canonical( $specs[0] );
        my ( $head, $base ) = _head_locate( $opt{'root'}, $top );
        refuse('no sealed head with a holder registry') if not defined $head;
        my $alt = holder_sub_spec( $top, root_subdir( $opt{'root'} ) );
        $registry      = registry_open( $opt{'root'}, $head, $base, $alt );
        $registry_head = $head;
    }
    push @specs, map { $registry->{$ARG}{'spec'} } sort keys %{$registry}
        if $opt{'all_holders'};
    if ( $opt{'import_holders'} ) {
        require AMOS7::N7FS::Placement;
        AMOS7::N7FS::Placement::holders_save( $registry,
            qw| root | => $opt{'root'} );
    }
    return {
        qw| registry | => $registry,
        qw| head |     => $registry_head,
        qw| imported | => $opt{'import_holders'} ? TRUE : FALSE,
        }
        if $opt{'show_holders'}
        or ( $opt{'import_holders'}
        and not defined $opt{'target'}
        and not $opt{'list'}
        and not defined $opt{'tree'} );
    my %seen;
    @specs = grep { not $seen{ holder_canonical($ARG) }++ } @specs;
    my $peers = $opt{'peers'} // {
        map {
            ( @specs == 1 ? qw| recovery | : "recovery-$ARG" ) => $specs[$ARG]
        } 0 .. $#specs
    };
    my $survey = head_survey( $opt{'root'}, $peers );
    my @sources;
    foreach my $spec (@specs) {
        my ($freshness)
            = grep { ( $ARG->{'spec'} // '' ) eq holder_canonical($spec) }
            values %{$survey};
        refuse('recovery holder is missing from the head survey')
            if not defined $freshness;
        my $served = $freshness->{'head'};
        if ( not defined $served ) {
            refuse('no sealed head to recover') if @specs == 1;
            warn "n7fs : warning : no sealed head on $spec ; skipping it\n";
            next;
        }
        if ( defined $opt{'min_version'}
            and $served->{'version'} < $opt{'min_version'} ) {
            refuse( 'head version %d is below -min-version %d',
                $served->{'version'}, $opt{'min_version'} )
                if @specs == 1;
            warn "n7fs : warning : head on $spec is "
                . "below -min-version ; skipping it\n";
            next;
        }
        if ( $freshness->{'stale'} and not $opt{'allow_stale'} ) {
            refuse( 'refusing a rolled back head [ holder v%d, '
                    . 'floor v%d via %s ; use -allow-stale to proceed ]',
                $served->{'version'},
                $freshness->{'floor'}, $freshness->{'witness'} )
                if @specs == 1;
            warn "n7fs : warning : skipping a rolled back head on $spec\n";
            next;
        }
        warn "n7fs : warning : recovering from a "
            . "proven-stale head [ -allow-stale ]\n"
            if $freshness->{'stale'};
        my ( undef, $head, $map, $base )
            = _context( $opt{'root'}, $spec, TRUE );
        refuse('no sealed head to recover') if not defined $head;
        push @sources,
            {
            qw| spec |      => $spec,
            qw| holder |    => $base,
            qw| map |       => $map,
            qw| head |      => $head,
            qw| freshness | => $freshness,
            };
    }
    refuse('no usable sealed head to recover') if not @sources;
    warn "n7fs : warning : no second holder was reachable "
        . "; a withheld newer head cannot be seen from here\n"
        if @sources == 1
        and $sources[0]{'freshness'}{'verdict'} eq qw| unverified |;
    my $primary = $sources[0];
    my $head    = $primary->{'head'};
    my $served  = $primary->{'freshness'}{'head'};
    my $now     = ntime_now();
    my $age     = $now - $head->{'time'};
    $age = 0 if $age < 0;
    my @receipts;

    foreach my $holder ( sort keys $served->{'peers'}->%* ) {
        my $r = $served->{'peers'}{$holder}{'r'} // next;
        refuse('signed head receipt summary is invalid')
            if ref $r ne qw| HASH |
            or ( $r->{'v'} // '' ) !~ m|\A\d+\z|
            or ( $r->{'t'} // '' ) !~ m|\A\d+\z|
            or ( $r->{'n'} // '' ) !~ m|\A\d+\z|
            or ( $r->{'c'} // '' ) !~ m{\A(?:sizes-only|sampled|full)\z};
        my $receipt_age = $now - $r->{'t'};
        $receipt_age = 0 if $receipt_age < 0;
        push @receipts,
            {
            qw| holder |   => $holder,
            qw| version |  => $r->{'v'} + 0,
            qw| time |     => $r->{'t'} + 0,
            qw| age |      => $receipt_age,
            qw| coverage | => $r->{'c'},
            qw| nodes |    => $r->{'n'} + 0,
            };
    }
    my $fresh = {
        qw| version |    => $head->{'version'},
        qw| head_time |  => $head->{'time'},
        qw| head_age |   => $age,
        qw| unverified | => $primary->{'freshness'}{'verdict'} eq
            qw| unverified |,
        qw| receipts | => \@receipts,
    };

    if ( $opt{'list'} ) {
        my @list;
        foreach my $source (@sources) {
            foreach my $name ( sort keys $source->{'map'}{'trees'}->%* ) {
                next if defined $opt{'tree'} and $name ne $opt{'tree'};
                my $tree  = $source->{'map'}{'trees'}{$name};
                my $files = $tree->{'files'};
                my $held  = $tree->{'held'};
                if ( not defined $files or not defined $held ) {
                    my ( undef, @entries )
                        = _manifest_read( $opt{'root'}, $source->{'holder'},
                        undef, $tree );
                    my %distinct = map { $ARG->{'a'} => TRUE }
                        grep { ( $ARG->{'t'} // '' ) eq qw| file | } @entries;
                    $files = scalar keys %distinct;
                    $held  = grep { exists $source->{'map'}{'nodes'}{$ARG} }
                        keys %distinct;
                }
                push @list,
                    {
                    qw| holder |  => $source->{'spec'},
                    qw| version | => $source->{'head'}{'version'},
                    qw| name |    => $name,
                    qw| created | => $tree->{'created'},
                    qw| files |   => $files,
                    qw| held |    => $held,
                    qw| state |   => $held == $files
                    ? qw| complete |
                    : qw| partial |,
                    };
            }
        }
        return { %{$fresh}, qw| list | => \@list };
    }

    if ( defined $opt{'tree'} ) {
        my ( $tree, $manifest_source );
        foreach my $source (@sources) {
            my $candidate = $source->{'map'}{'trees'}{ $opt{'tree'} } // next;
            if ( defined $tree
                and $tree->{'manifest'} ne $candidate->{'manifest'} ) {
                refuse(
                    'tree %s has different manifests on %s and %s',
                    $opt{'tree'}, $manifest_source->{'spec'},
                    $source->{'spec'}
                );
            }
            if ( not defined $tree
                or $source->{'head'}{'version'}
                > $manifest_source->{'head'}{'version'} ) {
                $tree            = $candidate;
                $manifest_source = $source;
            }
        }
        refuse( 'no live tree named %s', $opt{'tree'} )
            if not defined $tree;
        my ( undef, @entries )
            = _manifest_read( $opt{'root'}, $manifest_source->{'holder'},
            undef, $tree );
        my %files = map { $ARG->{'a'} => TRUE }
            grep { ( $ARG->{'t'} // '' ) eq qw| file | } @entries;
        my ( @missing, %missing );
        foreach my $entry ( grep { ( $ARG->{'t'} // '' ) eq qw| file | }
            @entries ) {
            my $address = $entry->{'a'};
            next
                if grep { exists $ARG->{'map'}{'nodes'}{$address} } @sources;
            $missing{$address} = TRUE;
            my $path
                = ( $entry->{'p'} // '' ) eq ''
                ? ''
                : unb32( $entry->{'p'} // '' );
            refuse('tree manifest path is invalid') if not defined $path;
            push @missing, { qw| path | => $path, qw| address | => $address };
        }
        if (@missing) {
            my $held = scalar keys(%files) - scalar keys(%missing);
            if ( not $opt{'partial'} ) {
                refuse(
                    'tree %s is partial on %s [ %d of %d '
                        . 'files ] ; add -from <holder> or -partial',
                    $opt{'tree'},
                    $manifest_source->{'spec'},
                    $held,
                    scalar keys %files
                ) if @sources == 1;
                refuse(
                    'tree %s is partial across the supplied holders [ '
                        . '%d of %d files ] ; add -from <holder> or -partial',
                    $opt{'tree'}, $held, scalar keys %files
                );
            }
            return {
                %{$fresh},
                qw| tree |    => $opt{'tree'},
                qw| partial | => TRUE,
                qw| files |   => scalar keys %files,
                qw| held |    => $held,
                qw| missing | => \@missing,
            };
        }
        my $r = _restore_sealed_tree(
            %opt,
            qw| holder |  => $manifest_source->{'holder'},
            qw| address | => $opt{'tree'},
            qw| map |     => $manifest_source->{'map'},
            qw| sources | => \@sources,
        );
        return { %{$r}, %{$fresh} };
    }
    my %address_source;
    foreach my $source (@sources) {
        foreach my $address ( keys $source->{'map'}{'nodes'}->%* ) {
            $address_source{$address} = $source
                if not exists $address_source{$address};
        }
    }
    make_dirs( $opt{'target'}, 0700 );
    foreach my $address ( sort keys %address_source ) {
        my $source = $address_source{$address};
        my $safe   = $address;
        $safe =~ s|/|_|g;
        _restore_node( $opt{'root'}, $source->{'holder'}, $source->{'map'},
            $address, $opt{'target'} . "/$safe" );
    }
    return { %{$fresh}, qw| nodes | => scalar keys %address_source, };
}

## the sealed header of a mapped blob : chunk size and chunk count, checked ##
## against the map entry. only pack members carry a real offset             ##
sub _blob_meta {
    my ( $holder, $entry ) = @_;
    my $base = $entry->{'offset'} // 0;
    my $head = holder_read_range( $holder, $entry->{'blob'}, $base, 26 );
    refuse('mapped blob header cannot be read')
        if not defined $head
        or length $head != 26;
    my ( $mode, $chunk_size ) = unpack( 'C Q>', substr( $head, 5, 9 ) );
    my $chunks = unpack qw| Q> |, substr( $head, 18, 8 );
    refuse('mapped blob chunk count differs')
        if $chunks != $entry->{'chunks'} or $mode != 0;
    return ( $base, $chunk_size, $chunks );
}

sub _checked_chunk {
    my ( $holder, $root, $map, $entry, $base, $index, $chunk_size, $chunks )
        = @_;
    my $pos = $base + 26 + $index * ( 4 + $chunk_size + 16 );
    my $raw = holder_read_range( $holder, $entry->{'blob'}, $pos, 4 );
    refuse('sealed chunk cannot be read')
        if not defined $raw
        or length $raw != 4;
    my $sealed
        = holder_read_range( $holder, $entry->{'blob'},
        $pos + 4, unpack( qw| N |, $raw ) );
    refuse('sealed chunk cannot be read') if not defined $sealed;
    open_sealed_bytes( _node_keys( $root, $map, $entry ),
        $sealed, qw| content |, '', 0, $index,
        $index == $chunks - 1 ? TRUE : FALSE );
    return TRUE;
}

## authenticate $wanted chunks, drawing sample positions from the sealed    ##
## byte space : a large pack is sampled proportionally more often than a    ##
## small one. uniform-by-node sampling missed a 1 % rot in ~85 % of runs at ##
## 24k nodes [ review finding 4 ]                                           ##
sub _sampled_chunks {
    my ( $opt, $map, $addresses, $hits ) = @_;
    my $wanted = $opt->{'samples'} // 16;
    refuse('samples must be a positive integer')
        if $wanted !~ m|\A[1-9]\d*\z|;
    my @weight;
    my $total = 0;
    foreach my $address ( @{$addresses} ) {
        my $length = $map->{'nodes'}{$address}{'length'} // 0;
        $length = 1 if $length < 1;
        push @weight, $length;
        $total += $length;
    }
    my $rng = $opt->{'rng'} // sub { random_bytes(8) };
    my ( %seen,  %meta );
    my ( $rolls, $checked ) = ( 0, 0 );
    ## enough samples for every node : each node gets one chunk first, the ##
    ## rest goes by bytes [ a tiny damaged node is never skipped then ]    ##
    if ( $wanted >= @{$addresses} and not $opt->{'rng'} ) {
        foreach my $address ( @{$addresses} ) {
            my $entry = $map->{'nodes'}{$address};
            my ( $base, $chunk_size, $chunks )
                = @{ $meta{$address}
                    //= [ _blob_meta( $opt->{'holder'}, $entry ) ] };
            my $index = unpack( 'Q>', $rng->() ) % $chunks;
            $seen{"$address\0$index"}++;
            _checked_chunk( @{$opt}{qw| holder root |},
                $map, $entry, $base, $index, $chunk_size, $chunks );
            $hits->{$address}++;
            $checked++;
        }
    }
    ## the roll cap only guards a pathological store : every roll that  ##
    ## lands on an already checked chunk is skipped, and duplicates are ##
    ## never counted toward $wanted                                     ##
    while ( $checked < $wanted and $rolls < $wanted * 8 ) {
        $rolls++;
        my $pos = unpack( 'Q>', $rng->() ) % $total;
        ## the node whose byte range covers the sample position ##
        my ( $idx, $upton ) = ( 0, 0 );
        while ( $idx < $#{$addresses} ) {
            $upton += $weight[$idx];
            last if $pos < $upton;
            $idx++;
        }
        my $address = $addresses->[$idx];
        my $entry   = $map->{'nodes'}{$address};
        my ( $base, $chunk_size, $chunks )
            = @{ $meta{$address}
                //= [ _blob_meta( $opt->{'holder'}, $entry ) ] };
        my $index = unpack( 'Q>', $rng->() ) % $chunks;
        next if $seen{"$address\0$index"}++;
        _checked_chunk( @{$opt}{qw| holder root |},
            $map, $entry, $base, $index, $chunk_size, $chunks );
        $hits->{$address}++;
        $checked++;
    }
    return $checked;
}

sub _sampled_manifest_chunks {
    my ( $opt, $map, $sizes ) = @_;
    my $wanted = $opt->{'samples'} // 16;
    refuse('samples must be a positive integer')
        if $wanted !~ m|\A[1-9]\d*\z|;
    my @chunks;
    foreach my $name ( sort keys $map->{'trees'}->%* ) {
        my $tree = $map->{'trees'}{$name};
        my $index
            = _manifest_index_read( @{$opt}{qw| root holder |}, undef,
            $tree );
        push @chunks, map {
            {
                qw| chunk |      => $ARG,
                    qw| weight | => $sizes->{ $ARG->{'blob'} } // 1,
            }
        } $index->{'chunks'}->@*;
    }
    return 0 if not @chunks;
    my $rng = $opt->{'rng'} // sub { random_bytes(8) };
    my @selected;
    if ( $wanted >= @chunks and not $opt->{'rng'} ) {
        @selected = @chunks;
    } else {
        my $total = 0;
        $total += $ARG->{'weight'} for @chunks;
        my %seen;
        my $rolls = 0;
        while ( @selected < $wanted and $rolls < $wanted * 8 ) {
            $rolls++;
            my $pos   = unpack( 'Q>', $rng->() ) % $total;
            my $index = 0;
            $pos -= $chunks[$index]{'weight'}, $index++
                while $index < $#chunks
                and $pos >= $chunks[$index]{'weight'};
            next if $seen{$index}++;
            push @selected, $chunks[$index];
        }
    }
    _manifest_chunk_read( @{$opt}{qw| root holder |}, undef, $ARG->{'chunk'} )
        for @selected;
    return scalar @selected;
}

sub _tree_claims_verify {
    my ( $root, $base, $map ) = @_;
    foreach my $name ( sort keys $map->{'trees'}->%* ) {
        my $tree = $map->{'trees'}{$name};
        next if ( $tree->{'state'} // qw| complete | ) ne qw| complete |;
        my ( undef, @entries ) = _manifest_read( $root, $base, undef, $tree );
        foreach my $entry ( grep { ( $ARG->{'t'} // '' ) eq qw| file | }
            @entries ) {
            refuse( 'complete tree %s does not map %s', $name, $entry->{'a'} )
                if not exists $map->{'nodes'}{ $entry->{'a'} };
        }
    }
    return TRUE;
}

sub holder_check {
    my %opt = @_;
    my ( undef, $head, $map, $base )
        = _context( @opt{qw| root holder |}, TRUE );
    refuse('no sealed head to check') if not defined $head;
    my $coverage = $opt{'coverage'} // qw| sampled |;
    refuse('coverage must be sizes-only, sampled, full or scrub')
        if $coverage !~ m{\A(?:sizes-only|sampled|full|scrub)\z};
    ## every blob read happens in the root's subdirectory on a per-root   ##
    ## holder ; the scrub names carry the tag for the restricted receiver ##
    my $tag
        = $base ne holder_canonical( $opt{'holder'} )
        ? root_subdir( $opt{'root'} )
        : undef;
    my $top = $opt{'holder'};
    my $alt
        = $base eq $top
        ? holder_sub_spec( $top, root_subdir( $opt{'root'} ) )
        : undef;
    $opt{'holder'} = $base;
    my $sizes     = holder_sizes($base);
    my @addresses = sort keys $map->{'nodes'}->%*;
    my %blobs     = map { $ARG => TRUE }
        _map_blob_names( $opt{'root'}, $base, $alt, $head, $map );

    foreach my $name ( keys %blobs ) {
        refuse( 'mapped blob is missing : %s', $name )
            if not defined $sizes->{$name};
    }
    my @descriptors = ( $head->{'map'}, values $map->{'_shards'}->%* );
    push @descriptors, $head->{'registry'}  if $head->{'registry'};
    push @descriptors, $map->{'_tree_blob'} if $map->{'_tree_blob'};
    foreach my $tree ( values $map->{'trees'}->%* ) {
        my $index = _manifest_index_read( $opt{'root'}, $base, undef, $tree );
        push @descriptors, $tree->{'index'}, $index->{'chunks'}->@*;
    }
    foreach my $desc ( grep { defined $ARG->{'size'} } @descriptors ) {
        refuse( 'mapped metadata blob has the wrong size : %s',
            $desc->{'blob'} )
            if $sizes->{ $desc->{'blob'} } != $desc->{'size'};
    }

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
    my ( $checked, %hits ) = ( 0, () );
    if ( $coverage eq qw| scrub | ) {
        ## keyless full coverage : a blob's name is the checksum of its own ##
        ## ciphertext, so verifying every mapped name verifies every byte   ##
        ## the holder keeps. the map and the journal are content-named too  ##
        ## ; only the head is not, and it stays covered by the signed       ##
        ## chain, never by a scrub. this proves ciphertext integrity -- it  ##
        ## says nothing about the map's key material, which the chunked     ##
        ## checks authenticate with the root                                ##
        my @names  = sort keys %blobs;
        my $result = holder_scrub( $top, \@names, undef, $tag );
        refuse(
            'holder scrub is not clean : %s bad, %s missing',
            scalar $result->{'bad'}->@*,
            scalar $result->{'missing'}->@*
        ) if not $result->{'clean'};
        $checked = $result->{'ok'};
    } elsif ( $coverage eq qw| full | ) {
        _manifest_verify( @opt{qw| root holder |}, undef, $ARG,
            $map->{'trees'}{$ARG} )
            for sort keys $map->{'trees'}->%*;
        foreach my $address (@addresses) {
            my $entry = $map->{'nodes'}{$address};
            my ( $base, $chunk_size, $chunks )
                = _blob_meta( $opt{'holder'}, $entry );
            foreach my $index ( 0 .. $chunks - 1 ) {
                _checked_chunk( @opt{qw| holder root |},
                    $map, $entry, $base, $index, $chunk_size, $chunks );
            }
            $checked += $chunks;
        }
    } elsif ( $coverage eq qw| sampled | ) {
        $checked = _sampled_chunks( \%opt, $map, \@addresses, \%hits )
            if @addresses;
        $checked += _sampled_manifest_chunks( \%opt, $map, $sizes );
    }
    _tree_claims_verify( $opt{'root'}, $base, $map )
        if $coverage eq qw| full | or $coverage eq qw| scrub |;
    ## sizes-only falls through : the size pass above is the whole check ##
    ## the incremental-receipt digest : the entries this version covers, ##
    ## over their placement fields -- the receipt stores it and _copies  ##
    ## recomputes it to prove the covered part only grew                 ##
    require AMOS7::N7FS::Placement;
    my @covered_list
        = AMOS7::N7FS::Placement::receipt_covered( $map, $head->{'version'} );
    return {
        qw| version |  => $head->{'version'},
        qw| root_id |  => $opt{'root'}{'root_id'},
        qw| nodes |    => scalar @addresses,
        qw| blobs |    => scalar keys %blobs,
        qw| chunks |   => $checked,
        qw| samples |  => $checked,
        qw| coverage | => $coverage eq qw| scrub | ? qw| full | : $coverage,
        qw| covered |  => AMOS7::N7FS::Placement::receipt_digest(
            $map, $head->{'version'}
        ),
        qw| covered_nodes | => scalar @covered_list,
        qw| covered_list |  => \@covered_list,
        qw| by_node |       => \%hits,
    };
}

sub _retention_rule {
    my $rule = shift // '';
    my @terms;
    while ( $rule =~ m|([1-9]\d*)\s*Y([0-7])|ig ) {
        push @terms, { qw| count | => $1 + 0, qw| level | => $2 + 0 };
    }
    my $canonical = join ' ', map {"$ARG->{'count'}Y$ARG->{'level'}"}
        sort { $b->{'level'} <=> $a->{'level'} } @terms;
    my $compact = $rule;
    $compact =~ s|\s+||g;
    refuse( 'retention rule must be a ladder of <count> Y<level> [ %s ]',
        $rule )
        if not @terms
        or uc($canonical) ne
        uc( join ' ', map {"$ARG->{'count'}Y$ARG->{'level'}"} @terms )
        or uc(
        join( '', map { "$ARG->{'count'}" . "Y$ARG->{'level'}" } @terms ) )
        ne uc($compact);
    return $canonical;
}

## rules and pins live in the same sealed root on every holder ##
sub retention_update {
    my %opt = @_;
    my ( $counter, $head, $map, $base )
        = _context( @opt{qw| root holder |}, FALSE );
    refuse('no sealed head on this holder') if not defined $head;
    my $action = $opt{'action'} // '';
    my $name   = $opt{'name'}   // '';
    refuse('retention needs a nonempty tree prefix or name')
        if not length $name
        or index( $name, "\0" ) >= 0;
    $map->{'retention'} //= {};
    $map->{'pins'}      //= {};
    my $before = $JSON->encode(
        {   qw| retention | => $map->{'retention'},
            qw| pins |      => $map->{'pins'}
        }
    );

    if ( $action eq qw| set | ) {
        $map->{'retention'}{$name} = _retention_rule( $opt{'rule'} );
    } elsif ( $action eq qw| clear | ) {
        delete $map->{'retention'}{$name};
    } elsif ( $action eq qw| pin | ) {
        $map->{'pins'}{$name} = TRUE;
    } elsif ( $action eq qw| unpin | ) {
        delete $map->{'pins'}{$name};
    } else {
        refuse( 'unknown retention action [ %s ]', $action );
    }
    my $after = $JSON->encode(
        {   qw| retention | => $map->{'retention'},
            qw| pins |      => $map->{'pins'}
        }
    );
    return { qw| changed | => FALSE, qw| version | => $head->{'version'} }
        if $before eq $after;
    my $version
        = _commit( $opt{'root'}, $base, holder_canonical( $opt{'holder'} ),
        $counter, $map, { qw| retention | => $action, qw| name | => $name } );
    return { qw| changed | => TRUE, qw| version | => $version };
}

## pure planner : owners and bucket winners are computed once per rule term
sub retention_plan {
    my %opt   = @_;
    my $now   = $opt{'now'}   // ntime_now();
    my $rules = $opt{'rules'} // {};
    my $pins  = $opt{'pins'}  // {};
    my %time;
    foreach my $name ( keys %{ $opt{'trees'} // {} } ) {
        my $record = $opt{'trees'}{$name};
        my $time = ref $record eq qw| HASH | ? $record->{'created'} : $record;
        refuse( 'tree %s has no whole ntime creation time', $name )
            if ( $time // '' ) !~ m|\A\d+\z|;
        $time{$name} = $time;
    }
    my @prefixes
        = sort { length($b) <=> length($a) || $a cmp $b } keys %{$rules};
    my %owner;
    foreach my $name ( keys %time ) {
        my ($best) = grep { index( $name, $ARG ) == 0 } @prefixes;
        $owner{$name} = $best // '';
    }
    my ( %terms, %finest, %bucket_keep );
    foreach my $prefix (@prefixes) {
        my @terms;
        foreach my $text ( split ' ', $rules->{$prefix} ) {
            my ( $count, $level ) = $text =~ m|\A([1-9]\d*)Y([0-7])\z|;
            push @terms,
                { qw| count | => $count + 0, qw| level | => $level + 0 };
        }
        $terms{$prefix} = \@terms;
        ( $finest{$prefix} )
            = sort { $b->{'level'} <=> $a->{'level'} } @terms;
        for my $index ( 0 .. $#terms ) {
            my $term = $terms[$index];
            my $unit = y_level_ntime( $term->{'level'} );
            my %newest;
            foreach my $name ( keys %time ) {
                next if $owner{$name} ne $prefix;
                my $bucket = int( $time{$name} / $unit );
                my $other  = $newest{$bucket};
                $newest{$bucket} = $name
                    if not defined $other
                    or $time{$name} > $time{$other}
                    or ( $time{$name} == $time{$other} and $name gt $other );
            }
            my @buckets = sort { $b <=> $a } keys %newest;
            splice @buckets, $term->{'count'} if @buckets > $term->{'count'};
            $bucket_keep{$prefix}[$index]
                = { map { $newest{$ARG} => TRUE } @buckets };
        }
    }
    my @out;
    foreach my $name ( sort keys %time ) {
        my $time = $time{$name};
        if ( $pins->{$name} ) {
            push @out,
                {
                qw| tree |   => $name,
                qw| keep |   => TRUE,
                qw| reason | => qw| pinned |
                };
            next;
        }
        my $prefix = $owner{$name};
        if ( not length $prefix ) {
            push @out,
                {
                qw| tree |   => $name,
                qw| keep |   => TRUE,
                qw| reason | => 'no retention rule'
                };
            next;
        }
        my $finest    = $finest{$prefix};
        my $fine_unit = y_level_ntime( $finest->{'level'} );
        if ( $time >= int( $now / $fine_unit ) * $fine_unit ) {
            push @out,
                {
                qw| tree |   => $name,
                qw| keep |   => TRUE,
                qw| reason | =>
                    "current $finest->{'count'}Y$finest->{'level'} bucket"
                };
            next;
        }
        my $reason;
        for my $index ( 0 .. $#{ $terms{$prefix} } ) {
            next if not $bucket_keep{$prefix}[$index]{$name};
            my $term = $terms{$prefix}[$index];
            $reason = "$term->{'count'} Y$term->{'level'}";
            last;
        }
        push @out,
            {
            qw| tree |   => $name,
            qw| keep |   => defined $reason ? TRUE : FALSE,
            qw| reason | => $reason // "outside $prefix ladder"
            };
    }
    return \@out;
}

## move live pack members byte-for-byte ; no content is opened or resealed ##
sub repack_packs {
    my %opt       = @_;
    my $threshold = $opt{'threshold'} // 30;
    refuse('repack threshold must be between 0 and 100')
        if $threshold !~ m|\A\d+(?:\.\d+)?\z| or $threshold > 100;
    my ( $counter, $head, $map, $base )
        = _context( @opt{qw| root holder |}, $opt{'dry_run'} ? TRUE : FALSE );
    refuse('no sealed head on this holder') if not defined $head;
    my $sizes = holder_sizes($base);
    my %packs;
    foreach my $address ( keys $map->{'nodes'}->%* ) {
        my $entry = $map->{'nodes'}{$address};
        next if not defined $entry->{'node'};
        push @{ $packs{ $entry->{'blob'} } }, [ $address, $entry ];
    }
    my @candidates;
    foreach my $name ( sort keys %packs ) {
        my $size = $sizes->{$name} // refuse( 'pack is missing : %s', $name );
        my $live = 5;
        $live += $ARG->[1]{'length'} for $packs{$name}->@*;
        my $dead = $size - $live;
        refuse( 'pack live entries exceed its size : %s', $name )
            if $dead < 0;
        my $pct = $size ? 100 * $dead / $size : 0;
        push @candidates,
            {
            qw| pack |    => $name,
            qw| bytes |   => $size,
            qw| dead |    => $dead,
            qw| percent | => $pct,
            qw| nodes |   => scalar $packs{$name}->@*
            }
            if $pct > $threshold;
    }
    return { qw| packs | => \@candidates, qw| repacked | => 0 }
        if $opt{'dry_run'};
    return { qw| packs | => [], qw| repacked | => 0, qw| receipts | => 0 }
        if not @candidates;

    my @prepared;
    foreach my $candidate (@candidates) {
        my $old   = $candidate->{'pack'};
        my $bytes = "P7SP\x01";
        foreach my $item ( sort { $a->[0] cmp $b->[0] } $packs{$old}->@* ) {
            my ( $address, $entry ) = @{$item};
            my $sealed = holder_read_range( $base, $old, $entry->{'offset'},
                $entry->{'length'} );
            refuse( 'cannot read live pack entry : %s', $address )
                if not defined $sealed
                or length $sealed != $entry->{'length'};
            refuse( 'live pack entry checksum does not match : %s', $address )
                if bmw_b32( bmw384_bytes($sealed) ) ne $entry->{'node'};
            $entry->{'_repack_offset'} = length $bytes;
            $bytes .= $sealed;
        }
        my $new = _write_blob( $opt{'root'}, $base, $bytes, qw| pack | );
        foreach my $item ( $packs{$old}->@* ) {
            my ( $address, $entry ) = @{$item};
            my $sealed
                = holder_read_range( $base, $new, $entry->{'_repack_offset'},
                $entry->{'length'} );
            refuse( 'cannot read moved pack entry : %s', $address )
                if not defined $sealed
                or length $sealed != $entry->{'length'};
            refuse( 'moved pack entry checksum does not match : %s',
                $address )
                if bmw_b32( bmw384_bytes($sealed) ) ne $entry->{'node'};
        }
        push @prepared, { %{$candidate}, qw| new_pack | => $new };
    }

    fault(qw| repack:before-commit |);
    my $version = $counter->{'version'} + 1;
    foreach my $candidate (@prepared) {
        my $old = $candidate->{'pack'};
        my $new = $candidate->{'new_pack'};
        foreach my $item ( $packs{$old}->@* ) {
            my $entry = $item->[1];
            $entry->{'blob'}   = $new;
            $entry->{'offset'} = delete $entry->{'_repack_offset'};
            $entry->{'added'}  = $version;
        }
        $map->{'superseded'}{$old} = $version;
    }
    $version = _commit(
        $opt{'root'},
        $base,
        holder_canonical( $opt{'holder'} ),
        $counter, $map,
        {   qw| repack | => [ map { $ARG->{'pack'} } @prepared ],
            qw| pack |   => [ map { $ARG->{'new_pack'} } @prepared ]
        }
    );
    $counter->{'version'} = $version;
    fault(qw| repack:after-commit |);
    my $checked = holder_check(
        qw| root |     => $opt{'root'},
        qw| holder |   => $opt{'holder'},
        qw| coverage | => qw| full |,
    );
    refuse('repack receipt has the wrong version')
        if $checked->{'version'} != $version;
    foreach my $candidate (@prepared) {
        my $new = $candidate->{'new_pack'};
        refuse('repack receipt does not cover every new pack')
            if not grep { $map->{'nodes'}{$ARG}{'blob'} eq $new }
            @{ $checked->{'covered_list'} };
    }
    require AMOS7::N7FS::Placement;
    my $receipt = AMOS7::N7FS::Placement::receipt_write(
        qw| host_dir |          => $opt{'host_dir'},
        qw| root |              => $opt{'root'},
        qw| spec |              => holder_canonical( $opt{'holder'} ),
        qw| version |           => $checked->{'version'},
        qw| nodes |             => $checked->{'nodes'},
        qw| samples |           => $checked->{'samples'},
        qw| coverage |          => $checked->{'coverage'},
        qw| covered |           => $checked->{'covered'},
        qw| covered_nodes |     => $checked->{'covered_nodes'},
        qw| covered_addresses | => $checked->{'covered_list'},
        qw| accept_clock |      => $opt{'accept_clock'},
    );
    fault(qw| repack:after-receipt |);
    my $gc = holder_gc(
        qw| root |      => $opt{'root'},
        qw| holder |    => $opt{'holder'},
        qw| receipt |   => $receipt,
        qw| keep |      => $opt{'keep'},
        qw| only_root | => $opt{'only_root'},
        qw| delete |    => TRUE,
        defined $opt{'grace'} ? ( qw| grace | => $opt{'grace'} ) : (),
    );
    $counter->{'version'} = $gc->{'version'};
    my @done = map {
        {
            %{$ARG},
                qw| version | => $version,
                qw| trashed | => $gc->{'removed'}
        }
    } @prepared;
    return {
        qw| packs |    => \@done,
        qw| repacked | => scalar @done,
        qw| receipts | => 1
    };
}

## blobs a holder keeps that the current head no longer references :
## superseded maps and journals, and nodes dropped from the map. instead of
## deleting, gc MOVES each one to .trash/<ntime14>/<name> inside the holder
## directory [ rename, same filesystem ], and never touches a blob younger
## than the grace age [ default 6Y3, -grace ] : a seal, relay or push in
## flight must not lose its bytes to a concurrent gc. the age is the
## holder-side mtime converted to ntime, listed in one call.
##
## on a per-root holder the listing is the root's own subdirectory, so
## -only-root is structural there and the flag is redundant [ warned ] ; a
## holder may still hold other roots in the old flat layout, whose blobs
## cannot be told apart from outside, so the flat layout keeps requiring it a
## destructive age decision needs one clock on both sides, and refuses a
## home/holder disagreement large enough to void the grace or trash lifetime
sub _age_now {
    my ( $base, $delete ) = @_;
    my $home   = ntime_now();
    my $holder = holder_now($base);
    my $skew   = abs( $home - $holder );
    refuse(
        'home and holder clocks disagree by %d ntime [ '
            . 'limit 1Y3 ] ; refusing a destructive age decision',
        $skew
    ) if $delete and $skew > parse_y_age('1Y3');
    return $holder;
}

sub holder_gc {
    my %opt = @_;
    refuse('holder-gc needs an explicit keep list [ possibly empty ]')
        if not exists $opt{'keep'};
    my ( $counter, $head, $map, $base )
        = _context( @opt{qw| root holder |}, TRUE );
    refuse('no sealed head on this holder') if not defined $head;
    my $per_root = $base ne holder_canonical( $opt{'holder'} );
    refuse(   'holder-gc needs -only-root : a holder may also hold '
            . 'other roots, and their blobs cannot be told apart' )
        if not $per_root and not $opt{'only_root'};
    warn "n7fs : -only-root is redundant : this holder "
        . "keeps each root in its own subdirectory\n"
        if $per_root and $opt{'only_root'};
    my $receipt = $opt{'receipt'};
    my %covered;

    if (    ref $receipt eq qw| HASH |
        and ( $receipt->{'coverage'} // '' ) eq qw| full |
        and ( $receipt->{'version'}  // 0 ) >= $head->{'version'} ) {
        %covered = map { $ARG => TRUE }
            grep { $receipt->{'version'} >= $map->{'superseded'}{$ARG} }
            keys $map->{'superseded'}->%*;
    }
    if ( $opt{'delete'} and keys %covered ) {
        delete $map->{'superseded'}{$ARG} for keys %covered;
        _commit( $opt{'root'}, $base, holder_canonical( $opt{'holder'} ),
            $counter, $map,
            { qw| gc_superseded | => [ sort keys %covered ] } );
        ( undef, $head, $map, $base )
            = _context( @opt{qw| root holder |}, TRUE );
    }
    my %keep = map { $ARG => TRUE } _head_name( $opt{'root'} ),
        _map_blob_names( $opt{'root'}, $base, undef, $head, $map );
    $keep{ $map->{'nodes'}{$ARG}{'blob'} } = TRUE
        for keys $map->{'nodes'}->%*;
    $keep{$ARG} = TRUE
        for grep { not $covered{$ARG} } keys $map->{'superseded'}->%*;
    ## pushed by a relay, not adopted yet ##
    $keep{$ARG} = TRUE for @{ $opt{'keep'} // [] };
    my $grace = $opt{'grace'} // parse_y_age('6Y3');
    my $now   = _age_now( $base, $opt{'delete'} );
    my $stats = holder_stats($base);
    my ( @drop, @young );
    foreach my $name ( sort grep { not $keep{$ARG} } keys %{$stats} ) {
        if ( $now - $stats->{$name}{'mtime'} < $grace ) {
            push @young, $name;
        } else {
            push @drop, $name;
        }
    }
    my $bytes = 0;
    $bytes += $stats->{$ARG}{'size'} for @drop;

    if ( $opt{'delete'} and @drop ) {
        my $day = _trash_day($now);
        holder_make_path( $base, ".trash/$day", 0700 );
        holder_move( $base, $ARG, ".trash/$day/$ARG" ) for @drop;
    }
    return {
        qw| version |  => $head->{'version'},
        qw| kept |     => scalar( keys %{$stats} ) - scalar @drop,
        qw| removed |  => scalar @drop,
        qw| young |    => scalar @young,
        qw| bytes |    => $bytes,
        qw| deleted |  => $opt{'delete'} ? TRUE : FALSE,
        qw| per_root | => $per_root,
    };
}

## the trash bucket of the current 1Y2 interval ##
sub _trash_day {
    my $now  = shift // ntime_now();
    my $unit = y_level_ntime(2);
    return ntime14( int( int( $now / $unit ) * $unit ) );
}

## the holder directory gc, purge and restore act on : the root's  ##
## subdirectory on a per-root holder, the flat directory otherwise ##
sub _trash_base {
    my %opt = @_;
    my ( undef, undef, undef, $base )
        = _context( @opt{qw| root holder |}, TRUE );
    return $base;
}

## holder-trash-purge : remove trash day directories whose holder-side mtime
## is older than the age [ the receipt age by default, set by the caller ].
## dry run unless -delete
sub holder_trash_purge {
    my %opt   = @_;
    my $base  = _trash_base(%opt);
    my $older = $opt{'older'} // refuse('trash purge needs an age');
    my $now   = _age_now( $base, $opt{'delete'} );
    my $days  = holder_trash_days($base);
    my $list  = holder_trash_list($base);
    my @old   = sort grep { $now - $days->{$ARG} > $older } keys %{$days};
    my ( $bytes, $removed ) = ( 0, 0 );

    foreach my $day (@old) {
        $bytes += $ARG for values %{ $list->{$day} // {} };
        next if not $opt{'delete'};
        holder_remove_day( $base, ".trash/$day" );
        $removed++;
    }
    return {
        qw| days |    => scalar @old,
        qw| removed | => $removed,
        qw| bytes |   => $bytes,
        qw| deleted | => $opt{'delete'} ? TRUE : FALSE,
    };
}

sub _trash_bucket_time {
    my $bucket = shift // '';
    return $bucket + 0 if $bucket =~ m|\A[0-9]{14}\z|;
    my ( $year, $month, $day ) = $bucket =~ m|\A(\d{4})-(\d{2})-(\d{2})\z|;
    refuse( 'bad date [ %s ]', $bucket ) if not defined $day;
    my $unix = eval { timegm( 0, 0, 0, $day, $month - 1, $year ) };
    refuse( 'bad date [ %s ]', $bucket ) if not defined $unix;
    return unix_to_ntime($unix);
}

## holder-trash-restore : move blobs back out of the trash. named blobs, or
## everything in day directories since a date [ -all-since ]. a blob already
## back at the holder is skipped, never overwritten
sub holder_trash_restore {
    my %opt  = @_;
    my $base = _trash_base(%opt);
    my $list = holder_trash_list($base);
    my @jobs;    ## [ day, name ] ##
    my $missing = 0;
    if ( defined $opt{'all_since'} ) {
        my $since = _trash_bucket_time( $opt{'all_since'} );
        foreach my $day (
            sort grep { _trash_bucket_time($ARG) >= $since }
            keys %{$list}
        ) {
            push @jobs, map { [ $day, $ARG ] } sort keys %{ $list->{$day} };
        }
    } else {
        my @names = @{ $opt{'names'} // [] };
        refuse('trash restore needs blob names or -all-since') if not @names;
        foreach my $name (@names) {
            refuse( 'invalid blob name [ %s ]', $name )
                if $name !~ m|\A[A-Z2-7]{77}\z|;
            my ($day) = grep { exists $list->{$ARG}{$name} }
                sort keys %{$list};
            if ( not defined $day ) { $missing++; next }
            push @jobs, [ $day, $name ];
        }
    }
    my $have = holder_stats($base);
    my ( $restored, $skipped ) = ( 0, 0 );
    foreach my $job (@jobs) {
        my ( $day, $name ) = @{$job};
        if ( $have->{$name} ) { $skipped++; next }
        holder_move( $base, ".trash/$day/$name", $name );
        $restored++;
    }
    return {
        qw| restored | => $restored,
        qw| skipped |  => $skipped,
        qw| missing |  => $missing,
    };
}

## holder-migrate : move this root's referenced blobs, its map, journal and
## head from the flat layout into its subdirectory. rename-only, idempotent,
## resumable after an interruption -- the head moves LAST as the commit point
## of the new layout. a holder interrupted midway has its blobs in the
## subdirectory and its head still flat : reads refuse [ missing blob ] until
## a rerun finishes the move, never a silent wrong answer. blobs already in
## the subdirectory are skipped, which is what makes a rerun cheap.
## unreferenced flat blobs stay and are reported : they may belong to another
## root. dry run unless -delete
sub holder_migrate {
    my %opt = @_;
    my ( undef, $head, $map, $base )
        = _context( @opt{qw| root holder |}, TRUE );
    my $top = holder_canonical( $opt{'holder'} );
    return {
        qw| already | => TRUE,
        qw| moved |   => 0,
        qw| left |    => 0,
        qw| deleted | => $opt{'delete'} ? TRUE : FALSE,
        }
        if $base ne $top;
    refuse('no sealed head on this holder') if not defined $head;
    my $tag       = root_subdir( $opt{'root'} );
    my $head_name = _head_name( $opt{'root'} );
    my %move
        = map { $ARG => TRUE }
        _map_blob_names( $opt{'root'}, $base, holder_sub_spec( $top, $tag ),
        $head, $map ),
        ( map { $map->{'nodes'}{$ARG}{'blob'} } keys $map->{'nodes'}->%* ),
        @{ $opt{'keep'} // [] };
    my @blobs = sort grep { $ARG ne $head_name } keys %move;
    my $flat  = holder_stats($top);
    my @left  = sort grep { not $move{$ARG} } keys %{$flat};
    my $there
        = holder_isdir( $top, $tag )
        ? holder_stats( holder_sub_spec( $top, $tag ) )
        : {};
    ## a rerun skips what an interrupted run already moved ; a pending ##
    ## relay blob that never arrived is simply not there               ##
    my @todo  = grep { $flat->{$ARG} and not $there->{$ARG} } @blobs;
    my $bytes = 0;
    $bytes += $flat->{$ARG}{'size'} // 0 for @todo;
    return {
        qw| already | => FALSE,
        qw| moved |   => scalar @todo,
        qw| present | => scalar( @blobs - @todo ),
        qw| left |    => scalar @left,
        qw| bytes |   => $bytes,
        qw| deleted | => $opt{'delete'} ? TRUE : FALSE,
        }
        if not $opt{'delete'};
    holder_make_path( $top, $tag, 0700 );
    holder_move( $top, $ARG, "$tag/$ARG" ) for @todo;
    fault(qw| migrate:after-blobs |);
    ## the head last : its move is the commit point of the new layout ##
    holder_move( $top, $head_name, "$tag/$head_name" )
        if not $there->{$head_name};
    fault(qw| migrate:after-head |);
    return {
        qw| already | => FALSE,
        qw| moved |   => scalar @todo,
        qw| present | => scalar( @blobs - @todo ),
        qw| left |    => scalar @left,
        qw| bytes |   => $bytes,
        qw| deleted | => TRUE,
    };
}

## drop nodes, and the trees that named any of them, from a holder's current
## map in one commit. bytes stay until holder-gc
sub unmap_nodes {
    my %opt = @_;
    my ( $counter, $head, $map, $base )
        = _context( @opt{qw| root holder |}, FALSE );
    my $pin = holder_canonical( $opt{'holder'} );
    refuse('no sealed head on this holder') if not defined $head;
    my %gone = map { $ARG => TRUE }
        grep { exists $map->{'nodes'}{$ARG} } $opt{'addresses'}->@*;
    ## untag : the node stays mapped for its other disks  no        ##
    ## autovivification : a missing entry or disk set stays missing ##
    my @untag = grep {
        my $e = $map->{'nodes'}{$ARG};
        not $gone{$ARG}
            and ref $e eq qw| HASH |
            and ref $e->{'disks'} eq qw| HASH |
            and $e->{'disks'}{ $opt{'disk'} // '' }
    } @{ $opt{'untag'} // [] };
    my %live_trees = map  { $ARG => TRUE } @{ $opt{'live_trees'} // [] };
    my @stale      = grep { not $live_trees{$ARG} } keys $map->{'trees'}->%*
        if defined $opt{'live_trees'};
    return { qw| removed | => 0, qw| trees | => 0, qw| untagged | => 0 }
        if not %gone
        and not @untag
        and not @stale;
    delete $map->{'nodes'}{$ARG} for keys %gone;
    delete $map->{'nodes'}{$ARG}{'disks'}{ $opt{'disk'} } for @untag;
    my %trees = map { $ARG => TRUE } @stale;
    foreach my $name ( sort keys %{ $map->{'trees'} // {} } ) {
        my $files = $opt{'tree_files'}{$name} // [];
        $trees{$name} = TRUE
            if $gone{ $map->{'trees'}{$name}{'manifest'} }
            or grep { $gone{$ARG} } @{$files};
    }
    my @trees = sort keys %trees;
    delete $map->{'trees'}{$ARG} for @trees;
    $counter->{'version'} = _commit(
        $opt{'root'},
        $base, $pin, $counter, $map,
        {   qw| unmap | => [ sort keys %gone ],
            @untag
            ? ( qw| untag | => { $opt{'disk'} => [ sort @untag ] } )
            : ()
        }
    );
    return {
        qw| untagged | => scalar @untag,
        qw| removed |  => scalar keys %gone,
        qw| trees |    => scalar @trees,
        qw| version |  => $counter->{'version'},
    };
}

## several blobs in flight : one blob's download, readback, sync and rename
## leave the line idle, a second upload fills it. N7FS_RELAY_JOBS [ 2 ], 1 =
## one after the other. the first failure starts no new blob, the running ones
## finish, then it refuses ; nothing is mapped before the commit
sub _parallel {
    my ( $work, $names ) = @_;
    my $jobs = $ENV{'N7FS_RELAY_JOBS'} // 2;
    $jobs = 2 if $jobs !~ m|\A[1-9]\d?\z|;
    if ( $jobs == 1 or @{$names} < 2 ) {
        $work->($ARG) for @{$names};
        return;
    }
    require POSIX;
    my @queue = @{$names};
    my ( %running, $failed, $reason );
    while ( @queue or %running ) {
        while ( @queue and keys %running < $jobs ) {
            my $name = shift @queue;
            my $pid  = fork // refuse('cannot fork a relay worker');
            if ( $pid == 0 ) {
                my $ok = eval { $work->($name); 1 };
                print STDERR $EVAL_ERROR if not $ok;
                POSIX::_exit( $ok ? 0 : 1 );
            }
            $running{$pid} = $name;
        }
        my $pid = waitpid( -1, 0 );
        last if $pid <= 0;
        my $name = delete $running{$pid} // next;
        if ($CHILD_ERROR) {
            $failed //= $name;
            @queue = ();
        }
    }
    refuse( 'relay of blob %s failed', $failed ) if defined $failed;
    return;
}

## copy the ciphertext of nodes from one holder to another and map them there.
## the copy is blind : each blob is checked against its own checksum name, so
## a wrong or changed blob from the source is refused. the node keys move by
## rewrapping under the target's categories, at home ; the target's map gets
## the nodes in one commit, together with the trees whose manifest it now
## holds. relayed blobs stay unmapped only until that commit [ holder-gc ]
sub relay_nodes {
    my %opt = @_;
    my ( $root, $from, $to ) = @opt{qw| root from to |};
    refuse('relay needs two different holders')
        if holder_canonical($from) eq holder_canonical($to);
    my ( undef, $fhead, $fmap, $fbase ) = _context( $root, $from, TRUE );
    refuse('no sealed head on the source holder') if not defined $fhead;
    my ( $counter, $thead, $tmap, $tbase ) = _context( $root, $to, FALSE );
    my %wanted = map { $ARG => TRUE } @{ $opt{'addresses'} // [] };
    my ( @addresses, @merges );

    foreach my $address ( sort keys $fmap->{'nodes'}->%* ) {
        next if %wanted and not $wanted{$address};
        if ( not exists $tmap->{'nodes'}{$address} ) {
            push @addresses, $address;
            next;
        }
        my $source = $fmap->{'nodes'}{$address}{'disks'};
        my $target = $tmap->{'nodes'}{$address}{'disks'};
        next         if ref $source ne qw| HASH |;
        $target = {} if ref $target ne qw| HASH |;
        push @merges, $address
            if grep { not $target->{$ARG} } keys %{$source};
    }
    my $fsizes = holder_sizes($fbase);
    ## blobs an interrupted relay left there are reused, head or not ##
    my $tsizes = holder_sizes($tbase);
    my %blob;
    my @missing;
    foreach my $address (@addresses) {
        my $entry = $fmap->{'nodes'}{$address};
        my $name  = $entry->{'blob'};
        if ( not defined $fsizes->{$name} ) {
            push @missing, $address;
            next;
        }
        $blob{$name}
            //= defined $entry->{'node'} ? qw| pack | : qw| content |;
    }
    my %have = map { $ARG => TRUE } @missing;
    @addresses = grep { not $have{$ARG} } @addresses;
    ## adopt only : map what a push already delivered, copy nothing ##
    my $waiting = 0;
    if ( $opt{'adopt_only'} ) {
        my @arrived = grep {
            my $name = $fmap->{'nodes'}{$ARG}{'blob'};
            ( $tsizes->{$name} // -1 ) == $fsizes->{$name}
        } @addresses;
        $waiting   = @addresses - @arrived;
        @addresses = @arrived;
        %blob      = map {
            $fmap->{'nodes'}{$ARG}{'blob'} =>
                $blob{ $fmap->{'nodes'}{$ARG}{'blob'} }
        } @addresses;
    }
    my %incoming = map { $ARG => TRUE } @addresses;
    my ( @tree_names, @tree_merges, %tree_files );
    foreach my $name ( sort keys %{ $fmap->{'trees'} // {} } ) {
        my $tree = $fmap->{'trees'}{$name};
        if ( ( $tmap->{'trees'}{$name}{'manifest'} // '' ) eq
            $tree->{'manifest'} ) {
            my $source = $tree->{'disks'};
            my $target = $tmap->{'trees'}{$name}{'disks'};
            next         if ref $source ne qw| HASH |;
            $target = {} if ref $target ne qw| HASH |;
            push @tree_merges, $name
                if grep { not $target->{$ARG} } keys %{$source};
            next;
        }
        my ( undef, @entries )
            = _manifest_read( $root, $fbase, undef, $tree );
        next if grep {
                    ( $ARG->{'t'} // '' ) eq qw| file |
                and not exists $tmap->{'nodes'}{ $ARG->{'a'} }
                and not $incoming{ $ARG->{'a'} }
        } @entries;
        my @names = _manifest_blob_names( $root, $fbase, undef, $tree );
        next if grep { not defined $fsizes->{$ARG} } @names;
        $blob{$ARG} //= qw| manifest | for @names;
        $tree_files{$name} = keys %{
            {   map  { $ARG->{'a'} => TRUE }
                grep { ( $ARG->{'t'} // '' ) eq qw| file | } @entries
            }
        };
        push @tree_names, $name;
    }
    my ( $copied, $bytes ) = ( 0, 0 );
    foreach my $name ( sort keys %blob ) {
        next if ( $tsizes->{$name} // -1 ) == $fsizes->{$name};
        $copied++;
        $bytes += $fsizes->{$name};
    }
    my $used = 0;
    $used += $ARG->{'length'} // 0 for values $tmap->{'nodes'}->%*;
    my $result = {
        qw| nodes |   => scalar @addresses,
        qw| merged |  => scalar @merges,
        qw| blobs |   => $copied,
        qw| bytes |   => $bytes,
        qw| missing | => scalar @missing,
        qw| used |    => $used,
        qw| waiting | => $waiting,
        ## the root's subdirectory on a per-root target : the relay list ##
        ## names it so n7fs-push reads and writes the right directory    ##
        qw| subdir | => $tbase ne holder_canonical($to)
        ? root_subdir($root)
        : undef,
        ## the blobs a push still has to deliver, for a relay list ##
        qw| names | => [
            sort grep { ( $tsizes->{$ARG} // -1 ) != $fsizes->{$ARG} }
                keys %blob
        ],
    };
    return $result
        if $opt{'dry_run'}
        or $opt{'list_only'}
        or not @addresses
        and not @merges
        and not @tree_names
        and not @tree_merges;
    ## quota and reserve of the target, as place keeps them ##
    if ( ref $opt{'room'} eq qw| CODE | ) {
        my $room = $opt{'room'}->($used);
        refuse( 'relay needs %d bytes, the target has room for %d',
            $bytes, $room > 0 ? $room : 0 )
            if $bytes > $room;
    }

    my $spool = _state_dir($root) . '/spool/relay';
    make_dirs( $spool, 0700 );
    my @todo = grep { ( $tsizes->{$ARG} // -1 ) != $fsizes->{$ARG} }
        sort keys %blob;
    foreach my $name (@todo) {
        refuse( 'target holds %s with another size', $name )
            if defined $tsizes->{$name};
    }
    holder_mkdir($tbase) if @todo;
    my $copy = sub {
        my $name = shift;
        my $path = "$spool/$name";
        unlink $path;
        holder_download( $fbase, $name, $path );
        open( my $fh, '<:raw', $path ) or refuse('cannot read relay spool');
        my ($sum) = AMOS7::N7FS::Sum::bmw384_fh($fh);
        close $fh;
        if ( bmw_b32($sum) ne $name ) {
            unlink $path;
            refuse( 'relayed blob does not match its name : %s', $name );
        }
        holder_put( $tbase, $path, $name, $blob{$name}, FALSE );
        unlink $path;
        fault(qw| relay:after-blob |);
    };
    _parallel( $copy, \@todo );
    ## the keys : unwrap under the source's category, wrap under the target's
    $tmap->{'_root_keys'} = $root->{'keys'};
    foreach my $address (@addresses) {
        my $entry   = $fmap->{'nodes'}{$address};
        my $keys    = _node_keys( $root, $fmap, $entry );
        my $node_id = unb32( $entry->{'id'} );
        my %wraps;
        my @categories = sort keys %{ $entry->{'wraps'} // {} };
        @categories = ( $entry->{'category'} ) if not @categories;
        foreach my $category (@categories) {
            my $cat = _category( $tmap, $category );
            $wraps{$category} = b32(
                wrap_bytes(
                    $cat->{'_key'}, $keys,
                    $node_id,       0,
                    'node:' . $entry->{'id'}
                )
            );
        }
        my %copy = %{$entry};
        delete $copy{'wrap'};
        $copy{'wraps'} = \%wraps;
        ## a new entry on the target : its own head version, not the source's
        $copy{'added'} = $counter->{'version'} + 1;
        $copy{'disks'} = { %{ $entry->{'disks'} } } if $entry->{'disks'};
        $tmap->{'nodes'}{$address} = \%copy;
    }
    foreach my $address (@merges) {
        my $source = $fmap->{'nodes'}{$address}{'disks'};
        my $target = $tmap->{'nodes'}{$address}{'disks'} //= {};
        $target->{$ARG} = TRUE for keys %{$source};
    }
    delete $tmap->{'_root_keys'};
    my $trees = 0;
    foreach my $name (@tree_names) {
        $tmap->{'trees'}{$name} = { %{ $fmap->{'trees'}{$name} } };
        @{ $tmap->{'trees'}{$name} }{qw| files held state |}
            = ( $tree_files{$name}, $tree_files{$name}, qw| complete | );
        $tmap->{'trees'}{$name}{'disks'}
            = { %{ $fmap->{'trees'}{$name}{'disks'} } }
            if ref $fmap->{'trees'}{$name}{'disks'} eq qw| HASH |;
        $trees++;
    }
    foreach my $name (@tree_merges) {
        my $source = $fmap->{'trees'}{$name}{'disks'};
        my $target = $tmap->{'trees'}{$name}{'disks'} //= {};
        $target->{$ARG} = TRUE for keys %{$source};
    }
    fault(qw| relay:before-commit |);
    $counter->{'version'} = _commit(
        $root, $tbase,
        holder_canonical($to),
        $counter, $tmap,
        {   qw| relay | => \@addresses,
            @merges ? ( qw| merge_disks | => \@merges ) : ()
        }
    );
    return {
        %{$result},
        qw| trees |   => $trees,
        qw| version | => $counter->{'version'},
    };
}

sub shred_node {
    my %opt = @_;
    my ( $counter, $head, $map, $base )
        = _context( @opt{qw| root holder |}, FALSE );
    my $pin = holder_canonical( $opt{'holder'} );
    refuse( 'address is not in the current sealed map : %s', $opt{'address'} )
        if not exists $map->{'nodes'}{ $opt{'address'} };
    delete $map->{'nodes'}{ $opt{'address'} };
    $counter->{'version'}
        = _commit( $opt{'root'}, $base, $pin, $counter, $map,
        { qw| shred | => $opt{'address'} } );
    return $counter->{'version'};
}

1;

#,,.,,,,.,,..,..,,.,,,,,.,,.,,,,,,,.,,,,.,,..,..,,...,...,.,,,.,,,,,,,.,.,,,,,
#LQU7MRC6FGRPWKVWGA4OHQ4IXGMWSPGPNCCHHYAFWNZZI4TPJZWIG4YNM4PH4GLXEG2QZFHA6E5FM
#\\\|FLOHUPHL65JS27ZYRUQH7B4WFR2KKUPFAFAN4HEINUHGSFXHENB \ / AMOS7 \ YOURUM ::
#\[7]QDX3QY5IRX24KBSRZDZY7YMLA5X6223PEV4MVFUSQYDP3H7ZMQDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
