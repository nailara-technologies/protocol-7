## [:< ##

package AMOS7::N7FS::Store;    ##############################################

## N7FS version 1 : content nodes and assimilate.
##
## <root>/<disk>/<epoch>/<amos>/<bmw>/content  /meta/<ntime14>.<tail8>.meta
##
## content : the file's bytes, unchanged [ no chunking in format 1 ]. meta :
## one plain 'P7FN' record per import
## [ name, format, size, mtime, import ntime, source .. ] -- a second import
## of the same content adds a meta file, nothing is rewritten
## [ sync = union of files ].
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

our $VERSION = qw| AMOS7::N7FS::Store-VERSION.MYYML5Y |;

@EXPORT_OK = qw|
    assimilate
    index_sources
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
    plain_record_pack plain_record_parse write_new_file
    write_new_file_stream read_file make_dirs publish_dir remove_tree
    refuse fault |;
use AMOS7::N7FS::Sum qw| bmw384_fh bmw_b32 amos_of_bmw epoch_int epoch_num
    epoch_b32 epoch_from_b32 |;
use AMOS7::N7FS::Disk qw| disk_require_attached disk_read_id state_read
    state_write |;

our $BMW_RE  = qr{\A[A-Z2-7]{77}\z};
our $AMOS_RE = qr{\A[A-Z2-7]{7}\z};
our $META_RE = qr{\A(\d{14})\.[A-Z2-7]{8}\.meta\z};
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

## format 1 : content + meta/ ##

sub _v1_write_node {
    my ( $dir, $node ) = @ARG;
    my $addr = $node->{'addr'};

    my ( $src, $st ) = _open_regular( $node->{'content_path'} );
    my $ctx = Digest::BMW->new(384);
    write_new_file_stream(
        "$dir/content",
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
        0400
    );
    close $src;
    refuse( 'content changed while copying [ %s ]', $node->{'content_path'} )
        if bmw_b32( $ctx->digest ) ne $addr->{'bmw'};

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

##[ NODES ]###################################################################

sub node_path {
    my ( $disk_path, $addr ) = @ARG;
    return join '/', $disk_path, epoch_b32( $addr->{'epoch'} ),
        $addr->{'amos'}, $addr->{'bmw'};
}

sub node_verify {
    my ( $disk_path, $addr, $format ) = @ARG;
    return codec($format)->{'verify_node'}
        ->( node_path( $disk_path, $addr ), $addr );
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

## verifies every node of the active epochs under the store format
sub store_verify {
    my %opt   = @ARG;
    my $id    = disk_read_id(%opt);
    my $state = state_read( $id->{'path'} );
    my @nodes = store_nodes( $id->{'path'}, $state->{'epochs'}->@* );
    node_verify( $id->{'path'}, $ARG, $state->{'store_format'} ) for @nodes;
    return { qw| nodes | => scalar @nodes, qw| state | => $state };
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
        _walk( "$path/$ARG", $items, $skipped ) for _list_dir($path);
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
    my $state = state_read( $id->{'path'} );
    my $codec = codec( $state->{'store_format'} );
    my $epoch = write_epoch($state);

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
                \%opt, $id,     $state, $codec, $epoch,
                $item, \%entry, \$tmp,  $remove
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
        $state = state_read( $id->{'path'} ) if not $opt{'dry_run'};
    }
    return \%report;
}

sub _assimilate_one {
    my ( $opt, $id, $state, $codec, $epoch, $item, $entry, $tmp_ref, $remove )
        = @ARG;
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

    my $bmw  = bmw_b32($digest);
    my $addr = {
        qw| epoch | => $epoch,
        qw| amos |  => amos_of_bmw($bmw),
        qw| bmw |   => $bmw,
    };
    my $final  = node_path( $id->{'path'}, $addr );
    my $exists = -e $final;
    $entry->{'addr'} = join '/', epoch_b32($epoch), $addr->{'amos'}, $bmw;

    if ( $opt->{'dry_run'} ) {
        $entry->{'status'} = $exists ? qw| would-dedup |  : qw| would-store |;
        $entry->{'then'}   = $remove ? qw| would-remove | : qw| keep |;
        return;
    }

    my $ntime = ntime_now();
    my $abs   = abs_path($path) // $path;
    my %meta  = (
        qw| name |         => ( $path =~ m|([^/]+)\z| )[0],
        qw| format |       => $format,
        qw| size |         => $size,
        qw| mtime |        => $st->[9],
        qw| import_ntime | => ntime14($ntime),
        qw| epoch_num |    => epoch_num($ntime),
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

    ## the epoch enters the state before its first node ##
    ## [ readers look there ]                           ##
    if ( not grep { $ARG == $epoch } $state->{'epochs'}->@* ) {
        state_write( $id->{'path'},
            { %{$state}, qw| epochs | => [ $state->{'epochs'}->@*, $epoch ] }
        );
    }

    if ($exists) {
        ## dedup : the stored node must verify before it gains a meta ##
        $codec->{'verify_node'}->( $final, $addr );
        $codec->{'write_meta'}->( $final, \%meta );
        $entry->{'status'} = qw| dedup |;
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
            }
        );
        fault(qw| assimilate:before-publish |);
        publish_dir( ${$tmp_ref}, $final );
        undef ${$tmp_ref};
        $entry->{'status'} = qw| stored |;
    }
    fault(qw| assimilate:after-publish |);

    ## verify the stored node, then the source again ##
    $codec->{'verify_node'}->( $final, $addr );
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

    if ( not $remove ) {
        $entry->{'then'} = qw| kept |;
        return;
    }

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

#,,..,,..,,,,,..,,..,,.,,,,,.,,,,,,.,,...,,,,,..,,...,..,,..,,,..,...,,..,.,.,
#DODZJOKK2NNC4I5KE7S5XWJXXQ7WNFC4CORURFK62RJFNXXBR72XHOSOQ74SKTKXK46E3X5X6ILWY
#\\\|LWGZMURM6QQT6UPWOZCG64674N3SO6DB3J7NBFI22HJS3NCRICJ \ / AMOS7 \ YOURUM ::
#\[7]E44WBUUVNVVC2OBW4O5ZIAEMDEAGCPQR6WB2LC5VIPWC2APWKUCA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
