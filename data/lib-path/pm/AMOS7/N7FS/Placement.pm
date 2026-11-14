## [:< ##

package AMOS7::N7FS::Placement;    ##########################################

## stage 6 : per-root holder registries, holder-check receipts, the placement
## report and placing what is under-replicated.

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

our $VERSION = qw| AMOS7::N7FS::Placement-VERSION.GYE5GGY |;

@EXPORT_OK = qw| holders_load holders_save holders_config holders_parse
    registry_path holder_add holder_remove receipt_write receipt_fresh
    receipt_coverage receipt_covered receipt_digest n7fs_now clock_floor_reset
    placement_report place_missing parse_size parse_age holder_drain
    holder_prune holder_rename holder_room holder_accepts |;

use JSON::PP;
use AMOS7::NTIME qw| parse_y_age |;
use AMOS7::N7FS  qw| b32 unb32 random_bytes read_file write_new_file make_dirs
    sync_dir refuse fault ntime_now |;
use AMOS7::N7FS::Sum      qw| bmw384_bytes bmw_b32 |;
use AMOS7::N7FS::Sign     qw| verify |;
use AMOS7::N7FS::Disk     qw| disk_read_id state_read |;
use AMOS7::N7FS::Journal  qw| journal_replay |;
use AMOS7::N7FS::Category qw| category_definitions |;

my $JSON = JSON::PP->new->utf8->canonical;

our $REGISTRY         = 'n7fs holders';
our $RECEIPT_AGE      = parse_y_age('3Y2');
our $RECEIPT_SKEW     = parse_y_age('1Y5');
our $CLOCK_STEP_LIMIT = parse_y_age('1Y2');
our $CLOCK_WARN_SKEW  = parse_y_age('1Y4');

sub parse_size {
    my $text = shift // return undef;
    my ( $n, $unit ) = $text =~ m|\A(\d+)([KMGT]?)\z|i;
    refuse( 'size must be a number with an optional K M G T [ %s ]', $text )
        if not defined $n;
    my %f = ( '' => 1, K => 1024, M => 1024**2, G => 1024**3, T => 1024**4 );
    return $n * $f{ uc $unit };
}

## durations are ntime : <n>Y<level>, with deprecated unix second forms ##
sub parse_age {
    my $text  = shift // return undef;
    my $ntime = parse_y_age($text);
    return $ntime if defined $ntime;

    my ( $n, $unit ) = $text =~ m|\A(\d+(?:\.\d+)?)([smhdw]?)\z|i;
    refuse( 'age must use <n>Y<level> [ level 0..7 ; %s ]', $text )
        if not defined $n;
    state %warned;
    my ( $file, $line ) = (caller)[ 1, 2 ];
    if ( not $warned{"$file:$line"}++ ) {
        warn "n7fs : age '$text' uses deprecated "
            . "unix units ; use <n>Y<level> instead\n";
    }
    my %f = ( '' => 1, s => 1, m => 60, h => 3600, d => 86400, w => 604800 );
    return int( $n * $f{ lc $unit } * 4200 );
}

sub registry_path {
    my $root = shift // refuse('a registry file needs the open root');
    refuse('a vault root keeps its registry in the vault')
        if $root->{'vault'};
    return ( $root->{'state_dir'} // "$root->{'path'}.state" ) . '/registry';
}

## the file-root and sealed form : one aligned config block per holder. the
## vault note keeps its older json body, but its sealed copy uses this too
## sizes are written in the largest exact unit [ 400G, not 429496729600 ] :
## the registry is a file people read and edit by hand
sub _size_text {
    my $bytes = shift // return undef;
    foreach my $unit (
        [ T => 1024**4 ],
        [ G => 1024**3 ],
        [ M => 1024**2 ],
        [ K => 1024 ]
    ) {
        return ( $bytes / $unit->[1] ) . $unit->[0]
            if $bytes >= $unit->[1] and $bytes % $unit->[1] == 0;
    }
    return $bytes;
}

sub holders_config {
    my $holders = shift // {};
    my @blocks;
    foreach my $name ( sort keys %{$holders} ) {
        my $h = $holders->{$name};
        my %v = (
            qw| spec |   => $h->{'spec'},
            qw| role |   => $h->{'role'} // qw| durable |,
            qw| domain | => $h->{'domain'},
            qw| owned |  => $h->{'owned'} ? 1 : 0,
        );
        $v{'id'}      = $h->{'id'}                  if defined $h->{'id'};
        $v{'quota'}   = _size_text( $h->{'quota'} ) if defined $h->{'quota'};
        $v{'reserve'} = _size_text( $h->{'reserve'} )
            if defined $h->{'reserve'};
        $v{'min_priority'} = $h->{'min_priority'}
            if defined $h->{'min_priority'};
        $v{'via'}        = $h->{'via'}    if defined $h->{'via'};
        $v{'access'}     = $h->{'access'} if defined $h->{'access'};
        $v{'categories'} = join ',', @{ $h->{'categories'} }
            if ref $h->{'categories'} eq qw| ARRAY |;
        my @fields = grep { defined $v{$ARG} }
            qw| id spec role domain owned quota reserve categories
            min_priority via access |;
        my $width = 0;

        foreach my $field (@fields) {
            my $length = length "holder.$name.$field";
            $width = $length if $length > $width;
        }
        push @blocks, join '', map {
            my $key = "holder.$name.$ARG";
            sprintf "%-${width}s : %s\n", $key, $v{$ARG}
        } @fields;
    }
    return join "\n", @blocks;
}

## both separators and arbitrary horizontal spacing are accepted. values keep
## everything after the separator, so access hints may contain ':' or '='
sub holders_parse {
    my $body = shift // '';
    my %holders;
    foreach my $line ( split m|\n|, $body, -1 ) {
        next if $line =~ m|\A\s*(?:#.*)?\z|;
        my ( $name, $field, $value ) = $line =~ m{
            \A\s*holder\.([A-Za-z0-9_.-]{1,64})\.
            (id|spec|role|domain|owned|quota|reserve|categories|
             min_priority|via|access)\s*[:=]\s*(.*?)\s*\z
        }x;
        refuse( 'invalid holder registry line [ %s ]', $line )
            if not defined $field;
        refuse( 'duplicate holder registry key [ %s.%s ]', $name, $field )
            if exists $holders{$name}{$field};
        $holders{$name}{$field} = $value;
    }
    foreach my $name ( keys %holders ) {
        my $h = $holders{$name};
        refuse( 'holder registry entry is incomplete [ %s ]', $name )
            if not defined $h->{'spec'}
            or not defined $h->{'role'}
            or not defined $h->{'domain'};
        $h->{'owned'} = {
            qw| 0 |     => 0,
            qw| 1 |     => 1,
            qw| no |    => 0,
            qw| yes |   => 1,
            qw| false | => 0,
            qw| true |  => 1,
        }->{ lc( $h->{'owned'} // 0 ) };
        refuse( 'holder registry owned flag is invalid [ %s ]', $name )
            if not defined $h->{'owned'};
        foreach my $field (qw| quota reserve |) {
            next if not defined $h->{$field};
            $h->{$field} = parse_size( $h->{$field} );
        }
        foreach my $field (qw| min_priority |) {
            next if not defined $h->{$field};
            refuse( 'holder registry number is invalid [ %s.%s ]',
                $name, $field )
                if $h->{$field} !~ m|\A\d+\z|;
            $h->{$field} += 0;
        }
        refuse( 'holder registry via name is invalid [ %s ]', $name )
            if defined $h->{'via'}
            and $h->{'via'} !~ m|\A[A-Za-z0-9_.-]{1,64}\z|;
        refuse( 'holder registry access hint exceeds 256 bytes [ %s ]',
            $name )
            if defined $h->{'access'}
            and ( length( $h->{'access'} ) > 256
            or $h->{'access'} =~ m|[\0\r]| );
        $h->{'categories'} = [ grep {length} split m|,|, $h->{'categories'} ]
            if defined $h->{'categories'};
    }
    return \%holders;
}

sub holders_load {
    my %opt = @_;
    if ( ref $opt{'root'} eq qw| HASH | and not $opt{'root'}{'vault'} ) {
        my $body = read_file( registry_path( $opt{'root'} ) );
        return {} if not defined $body or not length $body;
        return holders_parse($body);
    }
    $opt{'vault_dir'} = $opt{'root'}{'vault_dir'}
        if ref $opt{'root'} eq qw| HASH |
        and not defined $opt{'vault_dir'};
    require AMOS7::N7FS::Keys;
    my $body = AMOS7::N7FS::Keys::vault_note_load( $REGISTRY, %opt );
    return {} if not defined $body or not length $body;
    my $data = eval { $JSON->decode($body) };
    refuse('the holder registry in the vault is not valid json')
        if ref $data ne qw| HASH |
        or ref $data->{'holders'} ne qw| HASH |;
    return $data->{'holders'};
}

sub holders_save {
    my ( $holders, %opt ) = @_;
    if ( ref $opt{'root'} eq qw| HASH | and not $opt{'root'}{'vault'} ) {
        my $path = registry_path( $opt{'root'} );
        my $dir  = $path;
        $dir =~ s|/[^/]+\z||;
        make_dirs( $dir, 0700 );
        _replace_file(
            $path,
            holders_config($holders),
            qw| registry:before-rename |
        );
        return;
    }
    $opt{'vault_dir'} = $opt{'root'}{'vault_dir'}
        if ref $opt{'root'} eq qw| HASH |
        and not defined $opt{'vault_dir'};
    require AMOS7::N7FS::Keys;
    AMOS7::N7FS::Keys::vault_note_save( $REGISTRY,
        $JSON->encode( { qw| holders | => $holders } ), %opt );
    return;
}

sub _holders_changed {
    my ( $holders, %opt ) = @_;
    holders_save( $holders, %opt );
    return if ref $opt{'root'} ne qw| HASH |;
    require AMOS7::N7FS::Seal;
    AMOS7::N7FS::Seal::registry_publish( $opt{'root'} );
    return;
}

sub holder_add {
    my %opt  = @_;
    my $name = $opt{'name'} // '';
    refuse( 'holder name is invalid [ %s ]', $name )
        if $name !~ m|\A[A-Za-z0-9_.-]{1,64}\z|;
    require AMOS7::N7FS::Holder;
    my $spec = AMOS7::N7FS::Holder::holder_canonical( $opt{'spec'} // '' );
    my $role = $opt{'role'} // qw| durable |;
    refuse('role must be durable or intake')
        if $role ne qw| durable | and $role ne qw| intake |;
    my $domain = $opt{'domain'} // '';
    refuse('a holder needs -domain <label>')
        if $domain !~ m|\A[A-Za-z0-9_.:-]{1,64}\z|;
    ## which categories place may put there : a list, a lowest priority ##
    my @categories = grep {length} split m|,|, $opt{'categories'} // '';
    foreach my $c (@categories) {
        refuse( 'category name is invalid [ %s ]', $c )
            if $c !~ m|\A[A-Za-z0-9_.-]{1,64}\z|;
    }
    refuse('-min-priority must be a whole number')
        if defined $opt{'min_priority'}
        and $opt{'min_priority'} !~ m|\A\d+\z|;
    refuse('-via must name a holder')
        if defined $opt{'via'}
        and $opt{'via'} !~ m|\A[A-Za-z0-9_.-]{1,64}\z|;
    refuse('-access is free text of at most 256 bytes on one line')
        if defined $opt{'access'}
        and ( length( $opt{'access'} ) > 256
        or $opt{'access'} =~ m|[\0\r\n]| );
    my $holders = holders_load(%opt);
    my $old     = $holders->{$name};
    $holders->{$name} = {
        @categories ? ( qw| categories | => [ sort @categories ] ) : (),
        defined $opt{'min_priority'}
        ? ( qw| min_priority | => $opt{'min_priority'} + 0 )
        : (),
        defined $opt{'via'}    ? ( qw| via |    => $opt{'via'} )    : (),
        defined $opt{'access'} ? ( qw| access | => $opt{'access'} ) : (),
        ref $old eq qw| HASH |
            && ( $old->{'spec'} // '' ) eq $spec && defined $old->{'id'}
        ? ( qw| id | => $old->{'id'} )
        : (),
        qw| spec |    => $spec,
        qw| role |    => $role,
        qw| domain |  => $domain,
        qw| owned |   => $opt{'owned'} ? JSON::PP::true : JSON::PP::false,
        qw| quota |   => parse_size( $opt{'quota'} ),
        qw| reserve | => parse_size( $opt{'reserve'} ),
    };
    _holders_changed( $holders, %opt );
    return $holders->{$name};
}

sub holder_remove {
    my %opt     = @_;
    my $holders = holders_load(%opt);
    refuse( 'no holder named %s', $opt{'name'} // '' )
        if not exists $holders->{ $opt{'name'} // '' };
    delete $holders->{ $opt{'name'} };
    _holders_changed( $holders, %opt );
    return;
}

## one registry write : the entry is never missing in between. a new spec
## moves the rollback pin, after its head proved to be the same holder ; the
## receipt is bound to the old spec, so the holder needs a new check
sub holder_rename {
    my %opt = @_;
    my ( $old, $new ) = @opt{qw| name new_name |};
    $old //= '';
    $new //= $old;
    refuse( 'holder name is invalid [ %s ]', $new )
        if $new !~ m|\A[A-Za-z0-9_.-]{1,64}\z|;
    my $holders = holders_load(%opt);
    refuse( 'no holder named %s', $old ) if not exists $holders->{$old};
    refuse( 'a holder named %s exists already', $new )
        if $new ne $old and exists $holders->{$new};
    my %h      = %{ $holders->{$old} };
    my $result = { qw| spec | => $h{'spec'}, qw| respec | => FALSE };

    if ( defined $opt{'new_spec'} ) {
        require AMOS7::N7FS::Holder;
        my $spec = AMOS7::N7FS::Holder::holder_canonical( $opt{'new_spec'} );
        if ( $spec ne $h{'spec'} ) {
            refuse('a new spec needs -root-key') if not ref $opt{'root'};
            require AMOS7::N7FS::Seal;
            $result->{'version'}
                = AMOS7::N7FS::Seal::holder_respec( $opt{'root'}, $h{'spec'},
                $spec, $opt{'dry_run'} );
            @{$result}{qw| spec respec |} = ( $spec, TRUE );
            $h{'spec'} = $spec;
        }
    }
    refuse('nothing to rename') if $new eq $old and not $result->{'respec'};
    return $result              if $opt{'dry_run'};
    delete $holders->{$old};
    $holders->{$new} = \%h;
    _holders_changed( $holders, %opt );
    return $result;
}

sub _receipt_path {
    my ( $host_dir, $spec, $root_id ) = @_;
    return
          "$host_dir/receipts/$root_id/"
        . bmw_b32( bmw384_bytes( "p7 n7fs receipt v1\0" . $spec ) )
        . '.receipt';
}

sub _clock_floor_path {
    my ( $host_dir, $root_id ) = @_;
    return "$host_dir/clock-floor/$root_id";
}

sub _replace_file {
    my ( $path, $bytes, $fault_point ) = @_;
    my $tmp = "$path.tmp." . b32( random_bytes(5) );
    write_new_file( $tmp, $bytes );
    fault( $fault_point // qw| receipt:before-rename | );
    rename $tmp, $path
        or refuse( 'cannot replace %s : %s', $path, $OS_ERROR );
    my $dir = $path;
    $dir =~ s|/[^/]+\z||;
    sync_dir($dir);
    return;
}

## reads never raise the floor ; receipt writes may raise it by at most 1Y2
## unless the operator explicitly accepts a larger clock step
sub n7fs_now {
    my ( $host_dir, $root_id, $now, $raise, $accept_clock ) = @_;
    $now //= ntime_now();
    refuse('n7fs clock is not whole ntime') if $now !~ m|\A\d+\z|;
    my $path  = _clock_floor_path( $host_dir, $root_id );
    my $bytes = read_file($path);
    my $floor = 0;
    if ( defined $bytes ) {
        $bytes =~ s|\s+\z||;
        refuse('n7fs clock floor is not whole ntime')
            if $bytes !~ m|\A\d+\z|;
        $floor = $bytes + 0;
    }
    if ( $floor > $now ) {
        warn sprintf "n7fs : warning : the local clock is %d ntime behind "
            . "the floor ; using the floor\n", $floor - $now
            if $floor - $now > $CLOCK_WARN_SKEW;
        return $floor;
    }
    return $now + 0 if not $raise or $now == $floor;
    refuse(
        'n7fs clock step %d exceeds 1Y2 [ floor %d, '
            . 'local %d ] ; use -accept-clock to raise it',
        $now - $floor,
        $floor, $now
        )
        if $floor > 0
        and $now - $floor > $CLOCK_STEP_LIMIT
        and not $accept_clock;
    make_dirs( "$host_dir/clock-floor", 0700 );
    _replace_file( $path, "$now\n" );
    return $now + 0;
}

sub clock_floor_reset {
    my ( $host_dir, $root_id ) = @_;
    my $path = _clock_floor_path( $host_dir, $root_id );
    return FALSE if not -e $path and not -l $path;
    unlink $path
        or refuse( 'cannot reset clock floor %s : %s', $path, $OS_ERROR );
    sync_dir("$host_dir/clock-floor");
    return TRUE;
}

## the addresses a receipt for $version covers : every entry added at or below
## that head version. entries from before the added field read as 0, so an old
## map is covered by any receipt that digested it
sub receipt_covered {
    my ( $map, $version ) = @_;
    return sort grep { ( $map->{'nodes'}{$ARG}{'added'} // 0 ) <= $version }
        keys %{ $map->{'nodes'} // {} };
}

## a digest over the covered entries' placement fields
## [ address, blob, offset, length, chunks, pack ] : a receipt for $version
## stores it, and _copies recomputes it over the current map -- an equal
## digest proves the covered part only grew since the receipt, never changed
## or lost an entry
sub receipt_digest {
    my ( $map, $version ) = @_;
    my @lines;
    foreach my $address ( receipt_covered( $map, $version ) ) {
        my $e = $map->{'nodes'}{$address};
        push @lines, join "\0", $address, $e->{'blob'} // '',
            $e->{'offset'} // 0, $e->{'length'} // 0,
            $e->{'chunks'} // 0, $e->{'node'}   // '';
    }
    return bmw_b32( bmw384_bytes( join "\n", @lines ) );
}

## the covered-address cache beside a receipt : an unreachable holder cannot
## be read, so place planning falls back to the addresses the receipt listed
## when it was written [ the digest binds cache and receipt ]
sub _covered_cache_path {
    my ( $host_dir, $spec, $root_id ) = @_;
    return _receipt_path( $host_dir, $spec, $root_id ) . '.covered';
}

sub _covered_cache_read {
    my ( $host_dir, $spec, $root_id ) = @_;
    my $bytes
        = read_file( _covered_cache_path( $host_dir, $spec, $root_id ) );
    return undef if not defined $bytes;
    my $data = eval { $JSON->decode($bytes) } // return undef;
    return undef
        if ref $data ne qw| HASH |
        or ref $data->{'covered'} ne qw| ARRAY |;
    return $data;
}

## a holder-check result, signed by the root key
sub receipt_write {
    my %opt       = @_;
    my $root      = $opt{'root'} // refuse('a receipt needs the open root');
    my $root_id   = $root->{'root_id'};
    my $local_now = ntime_now();
    my $now       = n7fs_now( $opt{'host_dir'}, $root_id,
        $local_now, TRUE, $opt{'accept_clock'} );
    my $payload = {
        qw| holder |     => $opt{'spec'},
        qw| root_id |    => $root_id,
        qw| time |       => $now,
        qw| local_time | => $local_now,
        qw| version |    => $opt{'version'} + 0,
        qw| nodes |      => $opt{'nodes'} + 0,
        qw| samples |    => $opt{'samples'} + 0,
        qw| coverage |   => $opt{'coverage'} // qw| sampled |,
        defined $opt{'covered'}
        ? ( qw| covered |       => $opt{'covered'},
            qw| covered_nodes | => $opt{'covered_nodes'} + 0
            )
        : (),
    };
    my $signed = "p7 n7fs receipt v2\0" . $JSON->encode($payload);
    my $path   = _receipt_path( $opt{'host_dir'}, $opt{'spec'}, $root_id );
    my $dir    = $path;
    $dir =~ s|/[^/]+\z||;
    make_dirs( $dir, 0700 );
    _replace_file(
        $path,
        $JSON->encode(
            {   qw| receipt | => $payload,
                qw| pub |     => b32( $root->{'signer'}->public ),
                qw| sig |     => b32( $root->{'signer'}->sign($signed) ),
            }
        )
    );
    ## the covered-address cache is rewritten with the receipt ; without
    ## covered data an old cache must not linger and match a newer receipt
    my $cache
        = _covered_cache_path( $opt{'host_dir'}, $opt{'spec'}, $root_id );
    if ( defined $opt{'covered'}
        and ref $opt{'covered_addresses'} eq qw| ARRAY | ) {
        _replace_file(
            $cache,
            $JSON->encode(
                {   qw| version | => $opt{'version'} + 0,
                    qw| digest |  => $opt{'covered'},
                    qw| covered | => [ sort @{ $opt{'covered_addresses'} } ],
                }
            )
        );
    } else {
        unlink $cache;
    }
    require AMOS7::N7FS::Seal;
    AMOS7::N7FS::Seal::receipt_record( $root, $opt{'spec'}, $payload );
    return $payload;
}

sub receipt_fresh {
    my ( $host_dir, $root, $spec, $now ) = @_;
    my $root_id = $root->{'root_id'};
    my $bytes   = read_file( _receipt_path( $host_dir, $spec, $root_id ) );
    return undef if not defined $bytes;
    my $data = eval { $JSON->decode($bytes) } // return undef;
    return undef if ref $data ne qw| HASH |;
    my $r = $data->{'receipt'};
    return undef
        if ref $r ne qw| HASH |
        or ( $data->{'pub'} // '' ) ne b32( $root->{'signer'}->public )
        or not verify(
        $root->{'signer'}->public,
        "p7 n7fs receipt v2\0" . $JSON->encode($r),
        unb32( $data->{'sig'} // '' ) // ''
        )
        or ( $r->{'holder'}  // '' ) ne $spec
        or ( $r->{'root_id'} // '' ) ne $root_id;

    $r->{'time'} //= 0;
    return undef if $r->{'time'} !~ m|\A\d+\z|;
    $now = n7fs_now( $host_dir, $root_id, $now );
    return undef if $r->{'time'} > $now + $RECEIPT_SKEW;
    return undef if $now - $r->{'time'} > $RECEIPT_AGE;
    return $r;
}

## receipts from before the coverage field read as sampled ##
sub receipt_coverage {
    my $receipt = shift;
    return ( ref $receipt eq qw| HASH | ? $receipt->{'coverage'} : undef )
        // qw| sampled |;
}

## every live node of the disk with its categories and size
sub _disk_nodes {
    my %opt = @_;
    my $id  = disk_read_id(
        %opt,
        defined $opt{'disk_root'} ? ( qw| root | => $opt{'disk_root'} ) : (),
        qw| disk | => $opt{'disk'}
    );
    my $replay      = journal_replay($id);
    my $definitions = category_definitions( $id, $replay );
    my %cats;
    foreach my $ref ( values $replay->{'ref_history'}->%* ) {
        next if $ref->{'dropped'} or $ref->{'released'};
        my $a = $replay->{'assignments'}
            { join( "\0", $ref->{'node'}, $ref->{'path'} ) };
        $cats{ $ref->{'node'} }{ $a->{'category'} // qw| default | } = TRUE;
    }
    my %manifests = map { $replay->{'trees'}{$ARG}{'manifest'} => TRUE }
        keys $replay->{'trees'}->%*;
    require AMOS7::N7FS::Seal;
    my %tree_nodes;
    foreach my $tree ( values $replay->{'trees'}->%* ) {
        $tree_nodes{$ARG} = TRUE
            for AMOS7::N7FS::Seal::_manifest_files( $id,
            $tree->{'manifest'} );
    }
    my %nodes;
    foreach my $address ( keys $replay->{'nodes'}->%* ) {
        next if $manifests{$address};
        my @c = sort keys %{ $cats{$address} // {} };
        next if not @c and not $tree_nodes{$address};
        @c = (qw| default |) if not @c;
        my $target = 0;
        foreach my $c (@c) {
            my $copies = $definitions->{$c}{'copies'} // 1;
            $target = $copies if $copies > $target;
        }
        $nodes{$address} = {
            qw| categories | => \@c,
            qw| target |     => $target,
            qw| size | => -s AMOS7::N7FS::Seal::_content_path( $id, $address )
                // 0,
        };
    }
    return ( $id, \%nodes, $replay, $definitions );
}

## which domains hold each node, from the holders' own maps. two answers :
## %copies counts any fresh receipt [ place planning ], %proven counts only
## full-coverage receipts [ drain and gc on other holders rely on those ].  an
## incremental receipt [ carrying a covered digest ] vouches for exactly the
## entries its version covers, as long as the covered part is unchanged
sub _copies {
    my %opt     = @_;
    my $holders = holders_load(%opt);
    my $now     = n7fs_now( $opt{'host_dir'}, $opt{'root'}{'root_id'} );
    my %copies;
    my %proven;
    my %status;
    require AMOS7::N7FS::Seal;
    my $survey = AMOS7::N7FS::Seal::head_survey( $opt{'root'},
        { map { $ARG => $holders->{$ARG}{'spec'} } keys %{$holders} } );
    ## an excluded holder is read but not counted [ moving away from it ] ##
    my %excluded = map { $ARG => TRUE } @{ $opt{'exclude'} // [] };
    foreach my $name ( sort keys %{$holders} ) {
        my $h     = $holders->{$name};
        my $fresh = $survey->{$name};
        my $receipt
            = receipt_fresh( $opt{'host_dir'}, $opt{'root'}, $h->{'spec'},
            $now );
        refuse(
            'holder %s serves a rolled back head [ v%d, '
                . 'floor v%d via %s ; use -allow-stale to proceed ]',
            $name,             $fresh->{'head'}{'version'},
            $fresh->{'floor'}, $fresh->{'witness'}
        ) if $fresh->{'stale'} and not $opt{'allow_stale'};
        warn "n7fs : warning : holder $name is stale ; "
            . "counting no copies from it [ -allow-stale ]\n"
            if $fresh->{'stale'};
        my ( undef, $head, $map ) = eval {
            AMOS7::N7FS::Seal::_context( $opt{'root'}, $h->{'spec'}, TRUE );
        };
        my $state = qw| counted |;
        my $covered;
        if ( $fresh->{'stale'} ) {
            $state = 'rolled back';
            ( undef, $head, $map ) = ();
        } elsif ($EVAL_ERROR) {
            $state = qw| unreachable |;
            ## within the grace a fresh receipt keeps the covered entries ##
            ## counting in place planning, from the cache it wrote ; the  ##
            ## cache must match the receipt's digest. it never counts for ##
            ## drain : only place passes a grace                          ##
            my $age   = $receipt ? $now - ( $receipt->{'time'} // 0 ) : undef;
            my $grace = $opt{'unreachable_grace'} // 0;
            my $cache
                = $receipt
                ? _covered_cache_read( $opt{'host_dir'}, $h->{'spec'},
                $opt{'root'}{'root_id'} )
                : undef;
            if (    $grace > 0
                and defined $age
                and $age <= $grace
                and defined $cache
                and ( $receipt->{'covered'} // '' ) ne ''
                and $cache->{'digest'} eq $receipt->{'covered'} ) {
                $state   = 'unreachable, counted';
                $covered = { map { $ARG => TRUE } @{ $cache->{'covered'} } };
            }
        } elsif ( not defined $head ) {
            $state = qw| empty |;
        } elsif ( $h->{'role'} ne qw| durable | ) {
            $state = qw| intake |;
        } elsif ( not $receipt ) {
            $state = 'no fresh receipt';
        } elsif ( not defined $receipt->{'covered'} ) {
            ## a receipt from before the covered digest binds the exact ##
            ## head version it checked : any commit, even one that only ##
            ## added entries, waits for the next holder-check           ##
            if ( ( $receipt->{'version'} // -1 ) != $head->{'version'} ) {
                $state = 'no fresh receipt';
            } else {
                ## the exact version : it vouches for every mapped entry ##
                $covered = {
                    map { $ARG => TRUE }
                        keys %{ $map->{'nodes'} // {} }
                };
            }
        } else {
            ## entries the receipt's version covers ; a changed or dropped ##
            ## covered entry changes the digest and voids the receipt      ##
            if ( receipt_digest( $map, $receipt->{'version'} ) ne
                $receipt->{'covered'} ) {
                ## a void receipt vouches for nothing : no copy, no proof ##
                $state = 'no fresh receipt';
            } else {
                $covered = { map { $ARG => TRUE }
                        receipt_covered( $map, $receipt->{'version'} ) };
            }
        }
        if ( $excluded{$name} and $state eq 'counted' ) {
            $state   = 'excluded';
            $covered = undef;
        }
        $status{$name}{'state'} = $state;
        $status{$name}{'coverage'}
            = $receipt ? receipt_coverage($receipt) : undef;
        $status{$name}{'receipt_version'}
            = ref $receipt eq qw| HASH | ? $receipt->{'version'} : undef;
        $status{$name}{'receipt_age'}
            = ref $receipt eq qw| HASH | ? $now - $receipt->{'time'} : undef;
        my $full          = receipt_coverage($receipt) eq qw| full |;
        my $used          = 0;
        my $covered_count = 0;

        if ( $state eq 'unreachable, counted' ) {
            ## the map cannot be read : the cache lists what the receipt ##
            ## covers, counting for place planning only, never for drain ##
            $covered_count                  = scalar keys %{$covered};
            $copies{$ARG}{ $h->{'domain'} } = TRUE for sort keys %{$covered};
            $status{$name}{'nodes'}         = {};
        } elsif ( defined $map ) {
            foreach my $address ( keys %{ $map->{'nodes'} // {} } ) {
                $used += $map->{'nodes'}{$address}{'length'} // 0;
                if ( $covered and $covered->{$address} ) {
                    $covered_count++;
                    $copies{$address}{ $h->{'domain'} } = TRUE;
                    $proven{$address}{ $h->{'domain'} } = TRUE if $full;
                }
                ## the entry itself : drain reads its disk ids ##
                $status{$name}{'nodes'}{$address}
                    = $map->{'nodes'}{$address};
            }
        }
        $status{$name}{'covered_set'} = $covered;
        $status{$name}{'covered'}     = $covered_count;
        $status{$name}{'used'}        = $used;
        $status{$name}{'count'}
            = defined $map ? scalar keys %{ $map->{'nodes'} // {} } : 0;
        ## unreachable holders map nothing readable : their covered set ##
        ## comes from the cache, so there is no pending count either    ##
        $status{$name}{'pending'}
            = defined $map ? $status{$name}{'count'} - $covered_count : 0;
    }
    return ( $holders, \%copies, \%status, \%proven );
}

sub placement_report {
    my %opt = @_;
    my ( $id, $nodes ) = _disk_nodes(%opt);
    my ( $holders, $copies, $status, undef ) = _copies(%opt);
    my %by;
    foreach my $address ( keys %{$nodes} ) {
        my $n    = $nodes->{$address};
        my $have = scalar keys %{ $copies->{$address} // {} };
        my $c    = $n->{'categories'}[0];
        $by{$c}{'target'} = $n->{'target'}
            if $n->{'target'} > ( $by{$c}{'target'} // 0 );
        $by{$c}{'count'}{$have}{'nodes'}++;
        $by{$c}{'count'}{$have}{'bytes'} += $n->{'size'};
        if ( $have < $n->{'target'} ) {
            $by{$c}{'missing_nodes'}++;
            $by{$c}{'missing_bytes'}
                += $n->{'size'} * ( $n->{'target'} - $have );
        }
    }
    return {
        qw| categories | => \%by,
        qw| holders |    => {
            map {
                $ARG => {
                    %{ $holders->{$ARG} },
                    %{ $status->{$ARG} },
                    qw| nodes | => undef
                }
            } keys %{$holders}
        },
    };
}

## may place put a node there : one of its categories is in the holder's list
## [ when it has one ] and at or above its lowest priority. a holder without
## either takes every category
sub holder_accepts {
    my ( $h, $categories, $definitions ) = @_;
    my %allowed = map { $ARG => TRUE } @{ $h->{'categories'} // [] };
    foreach my $c ( @{$categories} ) {
        next if %allowed and not $allowed{$c};
        next
            if defined $h->{'min_priority'}
            and ( $definitions->{$c}{'priority'} // 0 )
            < $h->{'min_priority'};
        return TRUE;
    }
    return FALSE;
}

## bytes n7fs may still put on a holder : its quota less what it holds, and
## never into the reserve. unknown free space with a reserve allows nothing
sub holder_room {
    my ( $h, $used ) = @_;
    my $left
        = defined $h->{'quota'}
        ? $h->{'quota'} - ( $used // 0 )
        : 9**20;
    ## the reserve is space on the holder's disk n7fs never takes ##
    if ( defined $h->{'reserve'} ) {
        require AMOS7::N7FS::Holder;
        my $free = AMOS7::N7FS::Holder::holder_free( $h->{'spec'} );
        my $room = defined $free ? $free - $h->{'reserve'} : 0;
        $left = $room if $room < $left;
    }
    return $left;
}

## seal each under-replicated node to holders in domains not yet holding it :
## owned first, then most quota left. nothing is taken from another node.
sub place_missing {
    my %opt = @_;
    my ( $id, $nodes, $replay, $definitions ) = _disk_nodes(%opt);
    my ( $holders, $copies, $status, undef ) = _copies(%opt);
    ## a holder that gets any file of a tree also gets its manifest ; the tree
    ## inventory says partial until every file is there
    require AMOS7::N7FS::Seal;
    my %tree_of;
    foreach my $name ( keys $replay->{'trees'}->%* ) {
        my $t = $replay->{'trees'}{$name};
        $tree_of{$ARG} = $name
            for AMOS7::N7FS::Seal::_manifest_files( $id, $t->{'manifest'} );
    }
    my %plan;
    my %left;
    foreach my $name ( keys %{$holders} ) {
        next if $holders->{$name}{'role'} ne qw| durable |;
        next if $status->{$name}{'state'} =~ m|\Aunreachable|;
        next if $status->{$name}{'state'} eq 'excluded';
        next if $status->{$name}{'state'} eq 'rolled back';
        $left{$name}
            = holder_room( $holders->{$name}, $status->{$name}{'used'} );
    }
    my @unplaced;
    foreach my $address ( sort keys %{$nodes} ) {
        my $n    = $nodes->{$address};
        my %have = %{ $copies->{$address} // {} };
        ## a durable holder that maps the node without a receipt covering ##
        ## it is pending, not missing : place waits for its check instead ##
        ## of sending the node to another domain                          ##
        ## [ drain still counts only checked copies ]                     ##
        foreach my $name ( keys %{$holders} ) {
            next if $holders->{$name}{'role'} ne qw| durable |;
            next if $status->{$name}{'state'} =~ m|\Aunreachable|;
            next if $status->{$name}{'state'} eq 'excluded';
            next if $status->{$name}{'state'} eq 'rolled back';
            next
                if $status->{$name}{'covered_set'}
                and $status->{$name}{'covered_set'}{$address};
            $have{ $holders->{$name}{'domain'} } = TRUE
                if $status->{$name}{'nodes'}{$address};
        }
        my $need = $n->{'target'} - scalar keys %have;
        next if $need <= 0;
        foreach my $name (
            sort {
                ( $holders->{$b}{'owned'} ? 1 : 0 )
                    <=> ( $holders->{$a}{'owned'} ? 1 : 0 )
                    or $left{$b} <=> $left{$a}
                    or $a cmp $b
            } keys %left
        ) {
            last if $need <= 0;
            my $domain = $holders->{$name}{'domain'};
            next if $have{$domain};
            next if $status->{$name}{'nodes'}{$address};
            next if $left{$name} < $n->{'size'};
            next
                if not holder_accepts( $holders->{$name}, $n->{'categories'},
                $definitions );
            push $plan{$name}->@*, $address;
            $left{$name} -= $n->{'size'};
            $have{$domain} = TRUE;
            $need--;
        }
        push @unplaced, $address if $need > 0;
    }
    my ( %done, %results );
    if ( not $opt{'dry_run'} ) {
        require AMOS7::N7FS::Seal;
        foreach my $name ( sort keys %plan ) {
            $results{$name} = { qw| ok | => FALSE, qw| sealed | => 0 };
            my $r = eval {
                AMOS7::N7FS::Seal::seal_nodes(
                    %opt,
                    qw| holder |    => $holders->{$name}{'spec'},
                    qw| addresses | => $plan{$name},
                    ## only the planned files ; the tree supplies a ##
                    ## manifest                                     ##
                    qw| tree_manifests | => [
                        sort grep {defined}
                        map       { $tree_of{$ARG} } $plan{$name}->@*
                    ],
                );
            };
            if ( not defined $r ) {
                my $err = $EVAL_ERROR // 'seal failed';
                chomp $err;
                $results{$name}{'error'} = $err;
                next;
            }
            $done{$name}    = $r->{'sealed'};
            $results{$name} = {
                qw| ok |      => TRUE,
                qw| sealed |  => $r->{'sealed'},
                qw| version | => $r->{'version'},
            };
        }
    }
    ## every attempted holder is checked : a seal can fail after a commit, and
    ## one bad holder must not leave another holder's new copies pending
    my %checks;
    if ( not $opt{'dry_run'} and not $opt{'no_check'} ) {
        my $coverage = $opt{'check_coverage'} // qw| sampled |;
        foreach my $name ( sort keys %results ) {
            my $r = eval {
                my $check = AMOS7::N7FS::Seal::holder_check(
                    qw| root |     => $opt{'root'},
                    qw| holder |   => $holders->{$name}{'spec'},
                    qw| samples |  => $opt{'samples'},
                    qw| coverage | => $coverage,
                );
                receipt_write(
                    qw| host_dir |          => $opt{'host_dir'},
                    qw| root |              => $opt{'root'},
                    qw| spec |              => $holders->{$name}{'spec'},
                    qw| version |           => $check->{'version'},
                    qw| nodes |             => $check->{'nodes'},
                    qw| samples |           => $check->{'samples'},
                    qw| coverage |          => $check->{'coverage'},
                    qw| covered |           => $check->{'covered'},
                    qw| covered_nodes |     => $check->{'covered_nodes'},
                    qw| covered_addresses | => $check->{'covered_list'},
                    qw| accept_clock |      => $opt{'accept_clock'},
                );
                $check;
            };
            if ( not defined $r ) {
                my $err = $EVAL_ERROR // 'holder-check failed';
                chomp $err;
                $checks{$name} = { qw| ok | => FALSE, qw| error | => $err };
                next;
            }
            $checks{$name}
                = { qw| ok | => TRUE, qw| coverage | => $r->{'coverage'} };
        }
    }
    return {
        qw| plan |   => { map { $ARG => scalar $plan{$ARG}->@* } keys %plan },
        qw| sealed | => \%done,
        qw| results |  => \%results,
        qw| unplaced | => scalar @unplaced,
        qw| checks |   => \%checks,
    };
}

## remove from one holder every node whose copies elsewhere still meet its
## target without it : counted holders in other failure domains only. the
## copies elsewhere must be proven by full-coverage receipts -- a sampled
## receipt never vouches for bytes another holder is about to lose
sub holder_drain {
    my %opt = @_;
    my ( $id, $nodes, $replay ) = _disk_nodes(%opt);
    my ( $holders, $copies, $status, $proven ) = _copies(%opt);
    my $name = $opt{'name'}      // '';
    my $h    = $holders->{$name} // refuse( 'no holder named %s', $name );
    my $held = $status->{$name}{'nodes'} // {};
    my $disk = $id->{'disk'};
    my ( @drop, @untag );
    my ( $kept, $kept_bytes, $bytes, $unknown, $unknown_bytes, $other,
        $sampled_kept )
        = ( 0, 0, 0, 0, 0, 0, 0 );

    foreach my $address ( sort keys %{$held} ) {
        my $entry = $held->{$address};
        my $n     = $nodes->{$address};
        my %disks
            = %{ ref $entry eq qw| HASH | ? $entry->{'disks'} // {} : {} };
        ## only nodes of THIS disk : tagged with its id, or untagged and ##
        ## live here [ maps from before disk ids ]. an untagged node not ##
        ## live here may belong to any disk : kept and reported          ##
        if ( not %disks ) {
            if ( not $n ) {
                $unknown++;
                $unknown_bytes += $entry->{'length'} // 0
                    if ref $entry eq qw| HASH |;
                next;
            }
        } elsif ( not $disks{$disk} ) {
            $other++;
            next;
        }
        delete $disks{$disk};
        my $target    = $n ? $n->{'target'} : 0;
        my %elsewhere = %{ $copies->{$address} // {} };
        ## an intake copy counts zero, so a durable copy in its own domain ##
        ## still counts for it                                             ##
        delete $elsewhere{ $h->{'domain'} } if $h->{'role'} eq qw| durable |;
        my %proven_elsewhere = %{ $proven->{$address} // {} };
        delete $proven_elsewhere{ $h->{'domain'} }
            if $h->{'role'} eq qw| durable |;
        if ( scalar keys %proven_elsewhere >= $target ) {
            if (%disks) {
                ## still another disk's node : drop only this disk's id ##
                push @untag, $address;
            } else {
                push @drop, $address;
                $bytes += $n ? $n->{'size'} : 0;
            }
        } else {
            $kept++;
            $kept_bytes += $n ? $n->{'size'} : 0;
            ## enough copies exist, but at least one of them vouches only ##
            ## by a sampled receipt : report why the node stays           ##
            $sampled_kept++
                if scalar keys %elsewhere >= $target;
        }
    }
    my $result
        = { qw| removed | => 0, qw| trees | => 0, qw| untagged | => 0 };
    if ( ( @drop or @untag ) and not $opt{'dry_run'} ) {
        require AMOS7::N7FS::Seal;
        my %tree_files;
        foreach my $t ( keys $replay->{'trees'}->%* ) {
            $tree_files{$t} = [
                AMOS7::N7FS::Seal::_manifest_files(
                    $id, $replay->{'trees'}{$t}{'manifest'}
                )
            ];
        }
        $result = AMOS7::N7FS::Seal::unmap_nodes(
            %opt,
            qw| holder |     => $h->{'spec'},
            qw| addresses |  => \@drop,
            qw| untag |      => \@untag,
            qw| disk |       => $disk,
            qw| tree_files | => \%tree_files,
        );
    }
    return {
        %{$result},
        qw| drop |          => scalar @drop,
        qw| untag |         => scalar @untag,
        qw| bytes |         => $bytes,
        qw| kept |          => $kept,
        qw| kept_bytes |    => $kept_bytes,
        qw| sampled_kept |  => $sampled_kept,
        qw| unknown |       => $unknown,
        qw| unknown_bytes | => $unknown_bytes,
        qw| other_disks |   => $other,
    };
}

## unmap orphans after checking every disk attached on this host. an entry ##
## tagged for a detached disk stays : that disk's live set is unknown here ##
sub holder_prune {
    my %opt     = @_;
    my $holders = holders_load(%opt);
    my $name    = $opt{'name'}      // '';
    my $h       = $holders->{$name} // refuse( 'no holder named %s', $name );
    require AMOS7::N7FS::Seal;
    my ( undef, $head, $map )
        = AMOS7::N7FS::Seal::_context( $opt{'root'}, $h->{'spec'}, TRUE );
    refuse('no sealed head on this holder') if not defined $head;

    my %disk_opt = %opt;
    delete @disk_opt{qw| root name dry_run |};
    $disk_opt{'root'} = $opt{'disk_root'} if defined $opt{'disk_root'};
    my $root_dir = AMOS7::N7FS::root_dir(%disk_opt);
    opendir( my $dh, $root_dir )
        or refuse( 'cannot read disk root %s', $root_dir );
    my @disks = sort grep {m|\A[A-Z2-7]{7}\z|} readdir $dh;
    closedir $dh;

    my ( %live, %seen, %tree_files, %tree_live );
    foreach my $disk (@disks) {
        $disk_opt{'disk'} = $disk;
        my $attached
            = eval { AMOS7::N7FS::Disk::disk_require_attached(%disk_opt); 1 };
        if ( not $attached ) {
            my $err = $EVAL_ERROR // '';
            die $err if $err !~ m|is not attached here|;
            next;
        }
        my ( $id, $nodes, $replay ) = _disk_nodes(%disk_opt);
        $seen{$disk} = $nodes;
        $live{$ARG}  = TRUE for keys %{$nodes};
        foreach my $tree ( keys $replay->{'trees'}->%* ) {
            my $manifest = $replay->{'trees'}{$tree}{'manifest'};
            $tree_live{$disk}{$tree} = TRUE;
            $tree_files{$tree}{$ARG} = TRUE
                for AMOS7::N7FS::Seal::_manifest_files( $id, $manifest );
        }
    }
    my ( @drop, $bytes, $legacy_kept );
    ( $bytes, $legacy_kept ) = ( 0, 0 );
    my %keep_address = map { $ARG => TRUE } @{ $opt{'keep_addresses'} // [] };
    foreach my $address ( sort keys $map->{'nodes'}->%* ) {
        next if $live{$address} or $keep_address{$address};
        my $entry = $map->{'nodes'}{$address};
        my %disks = %{
            ref $entry->{'disks'} eq qw| HASH |
            ? $entry->{'disks'}
            : {}
        };
        ## no disk ids : it may belong to a detached disk or another host's ##
        ## disk, so only an explicit -legacy drops it                       ##
        if ( not %disks and not $opt{'legacy'} ) {
            $legacy_kept++;
            next;
        }
        next
            if grep { not exists $seen{$ARG} or $seen{$ARG}{$address} }
            keys %disks;
        push @drop, $address;
        $bytes += $entry->{'length'} // 0;
    }
    my ( @tree_drop, @tree_kept, @legacy_tree_kept );
    foreach my $tree ( sort keys $map->{'trees'}->%* ) {
        my %owners = %{
            ref $map->{'trees'}{$tree}{'disks'} eq qw| HASH |
            ? $map->{'trees'}{$tree}{'disks'}
            : {}
        };
        if ( not %owners ) {
            if ( $opt{'legacy'} ) {
                push @tree_drop, $tree;
            } else {
                push @legacy_tree_kept, $tree;
            }
            next;
        }
        if ( grep { not exists $seen{$ARG} } keys %owners ) {
            push @tree_kept, $tree;
            next;
        }
        next if grep { $tree_live{$ARG}{$tree} } keys %owners;
        push @tree_drop, $tree;
    }
    my @untag;
    if ( ref $opt{'tree_addresses'} eq qw| ARRAY | ) {
        refuse('tree address untagging needs a disk')
            if not defined $opt{'disk'};
        my %drop = map { $ARG => TRUE } @drop;
        foreach my $address ( @{ $opt{'tree_addresses'} } ) {
            next
                if $drop{$address}
                or $live{$address}
                or $keep_address{$address};
            my $entry = $map->{'nodes'}{$address} // next;
            my %disks = %{
                ref $entry->{'disks'} eq qw| HASH |
                ? $entry->{'disks'}
                : {}
            };
            next if %disks and not $disks{ $opt{'disk'} };
            delete $disks{ $opt{'disk'} };
            if (%disks) {
                push @untag, $address;
            } else {
                push @drop, $address;
                $drop{$address} = TRUE;
                $bytes += $entry->{'length'} // 0;
            }
        }
    }
    my %tree_drop = map { $ARG => TRUE } @tree_drop;
    my $result    = {
        qw| removed |  => 0,
        qw| trees |    => scalar @tree_drop,
        qw| untagged | => 0
    };
    if ( ( @drop or @untag or @tree_drop ) and not $opt{'dry_run'} ) {
        $result = AMOS7::N7FS::Seal::unmap_nodes(
            %opt,
            qw| holder |     => $h->{'spec'},
            qw| addresses |  => \@drop,
            qw| untag |      => \@untag,
            qw| live_trees | =>
                [ grep { not $tree_drop{$ARG} } keys $map->{'trees'}->%* ],
            qw| tree_files | => {
                map { $ARG => [ sort keys $tree_files{$ARG}->%* ] }
                    keys %tree_files
            },
        );
    }
    return {
        %{$result},
        qw| drop |      => scalar @drop,
        qw| addresses | => \@drop,
        qw| bytes |     => $bytes,
        qw| kept |      => scalar( keys $map->{'nodes'}->%* ) - scalar @drop,
        qw| legacy_kept |      => $legacy_kept,
        qw| tree_addresses |   => \@tree_drop,
        qw| tree_kept |        => \@tree_kept,
        qw| legacy_tree_kept | => \@legacy_tree_kept,
    };
}

1;

#,,,.,.,,,...,.,,,,..,,,,,,,,,.,.,,,,,,,.,,..,..,,...,...,,,.,,..,..,,,,,,,..,
#EVPFU3NALJBLQPW3IUTIE5XTVVFKLUSIP4VOQYAPSFPEQUQ3MY7QCVHIAFAPTB7KUHL3V6AVKB73E
#\\\|RXMCAYYVJH6RXPVCFSNHPF4WLYXROJEDJP4RHLZXRWG6VSJOPYT \ / AMOS7 \ YOURUM ::
#\[7]ZLVRX6PBRMX4ZZPTQJWGPXO5VFZSA2QXCRFPYAUSSHOCWCNO7SDI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
