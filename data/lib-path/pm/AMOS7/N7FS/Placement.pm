## [:< ##

package AMOS7::N7FS::Placement;    ##########################################

## stage 5 : the holder registry in the vault, holder-check receipts, the
## placement report and placing what is under-replicated.

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

our $VERSION = qw| AMOS7::N7FS::Placement-VERSION.J27AU7I |;

@EXPORT_OK = qw| holders_load holder_add holder_remove receipt_write
    receipt_fresh receipt_coverage placement_report place_missing parse_size
    parse_age holder_drain holder_prune holder_rename holder_room
    holder_accepts |;

use JSON::PP;
use AMOS7::N7FS qw| b32 unb32 read_file write_new_file make_dirs refuse |;
use AMOS7::N7FS::Sum      qw| bmw384_bytes bmw_b32 |;
use AMOS7::N7FS::Sign     qw| verify |;
use AMOS7::N7FS::Disk     qw| disk_read_id state_read |;
use AMOS7::N7FS::Journal  qw| journal_replay |;
use AMOS7::N7FS::Category qw| category_definitions |;

my $JSON = JSON::PP->new->utf8->canonical;

our $REGISTRY    = 'n7fs holders';
our $RECEIPT_AGE = 7 * 24 * 3600;

sub parse_size {
    my $text = shift // return undef;
    my ( $n, $unit ) = $text =~ m|\A(\d+)([KMGT]?)\z|i;
    refuse( 'size must be a number with an optional K M G T [ %s ]', $text )
        if not defined $n;
    my %f = ( '' => 1, K => 1024, M => 1024**2, G => 1024**3, T => 1024**4 );
    return $n * $f{ uc $unit };
}

## durations in seconds : plain seconds or with an s m h d w suffix
## [ the reclaim age form ]. gc's -grace and the trash purge's -older read
## these
sub parse_age {
    my $text = shift // return undef;
    my ( $n, $unit ) = $text =~ m|\A(\d+(?:\.\d+)?)([smhdw]?)\z|i;
    refuse( 'age must be a number with an optional s m h d w [ %s ]', $text )
        if not defined $n;
    my %f = ( '' => 1, s => 1, m => 60, h => 3600, d => 86400, w => 604800 );
    return int( $n * $f{ lc $unit } );
}

sub holders_load {
    my %opt = @_;
    require AMOS7::N7FS::Keys;
    my $body = AMOS7::N7FS::Keys::vault_note_load( $REGISTRY, %opt );
    return {} if not defined $body or not length $body;
    my $data = eval { $JSON->decode($body) };
    refuse('the holder registry in the vault is not valid json')
        if ref $data ne qw| HASH |
        or ref $data->{'holders'} ne qw| HASH |;
    return $data->{'holders'};
}

sub _holders_save {
    my ( $holders, %opt ) = @_;
    require AMOS7::N7FS::Keys;
    AMOS7::N7FS::Keys::vault_note_save( $REGISTRY,
        $JSON->encode( { qw| holders | => $holders } ), %opt );
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
    my $holders = holders_load(%opt);
    $holders->{$name} = {
        @categories ? ( qw| categories | => [ sort @categories ] ) : (),
        defined $opt{'min_priority'}
        ? ( qw| min_priority | => $opt{'min_priority'} + 0 )
        : (),
        qw| spec |    => $spec,
        qw| role |    => $role,
        qw| domain |  => $domain,
        qw| owned |   => $opt{'owned'} ? JSON::PP::true : JSON::PP::false,
        qw| quota |   => parse_size( $opt{'quota'} ),
        qw| reserve | => parse_size( $opt{'reserve'} ),
    };
    _holders_save( $holders, %opt );
    return $holders->{$name};
}

sub holder_remove {
    my %opt     = @_;
    my $holders = holders_load(%opt);
    refuse( 'no holder named %s', $opt{'name'} // '' )
        if not exists $holders->{ $opt{'name'} // '' };
    delete $holders->{ $opt{'name'} };
    _holders_save( $holders, %opt );
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
    _holders_save( $holders, %opt );
    return $result;
}

sub _receipt_path {
    my ( $host_dir, $spec ) = @_;
    return
          "$host_dir/receipts/"
        . bmw_b32( bmw384_bytes( "p7 n7fs receipt v1\0" . $spec ) )
        . '.receipt';
}

## a holder-check result, signed by the host key
sub receipt_write {
    my %opt     = @_;
    my $payload = {
        qw| holder |   => $opt{'spec'},
        qw| root_id |  => $opt{'root_id'},
        qw| time |     => time,
        qw| version |  => $opt{'version'} + 0,
        qw| nodes |    => $opt{'nodes'} + 0,
        qw| samples |  => $opt{'samples'} + 0,
        qw| coverage | => $opt{'coverage'} // qw| sampled |,
    };
    my $signed = $JSON->encode($payload);
    my $path   = _receipt_path( $opt{'host_dir'}, $opt{'spec'} );
    make_dirs( "$opt{'host_dir'}/receipts", 0700 );
    unlink $path;
    write_new_file(
        $path,
        $JSON->encode(
            {   qw| receipt | => $payload,
                qw| pub |     => b32( $opt{'signer'}->public ),
                qw| sig |     => b32( $opt{'signer'}->sign($signed) ),
            }
        )
    );
    return $payload;
}

sub receipt_fresh {
    my ( $host_dir, $host_pub, $spec, $root_id, $now ) = @_;
    my $bytes = read_file( _receipt_path( $host_dir, $spec ) );
    return undef if not defined $bytes;
    my $data = eval { $JSON->decode($bytes) } // return undef;
    my $r    = $data->{'receipt'};
    return undef
        if ref $r ne qw| HASH |
        or ( $data->{'pub'} // '' ) ne b32($host_pub)
        or not verify( $host_pub, $JSON->encode($r),
        unb32( $data->{'sig'} // '' ) // '' )
        or ( $r->{'holder'}  // '' ) ne $spec
        or ( $r->{'root_id'} // '' ) ne $root_id
        or ( $now            // time ) - ( $r->{'time'} // 0 ) > $RECEIPT_AGE;
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
    my %nodes;
    foreach my $address ( keys $replay->{'nodes'}->%* ) {
        my @c = sort keys %{ $cats{$address} // {} };
        next if not @c and not $manifests{$address};
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
## full-coverage receipts [ drain and gc on other holders rely on those ]
sub _copies {
    my %opt     = @_;
    my $holders = holders_load(%opt);
    my %copies;
    my %proven;
    my %status;
    require AMOS7::N7FS::Seal;
    ## an excluded holder is read but not counted [ moving away from it ] ##
    my %excluded = map { $ARG => TRUE } @{ $opt{'exclude'} // [] };
    foreach my $name ( sort keys %{$holders} ) {
        my $h       = $holders->{$name};
        my $receipt = receipt_fresh(
            $opt{'host_dir'}, $opt{'host_pub'},
            $h->{'spec'},     $opt{'root'}{'root_id'}
        );
        my ( undef, $head, $map ) = eval {
            AMOS7::N7FS::Seal::_context( $opt{'root'}, $h->{'spec'}, TRUE );
        };
        my $state = qw| counted |;
        if    ($EVAL_ERROR)                     { $state = 'unreachable' }
        elsif ( not defined $head )             { $state = 'empty' }
        elsif ( $h->{'role'} ne qw| durable | ) { $state = 'intake' }
        elsif ( not $receipt ) {
            $state = 'no fresh receipt';
        }
        ## a receipt vouches for the head it checked : any later commit ##
        ## [ place, relay, drain ] waits for the next holder-check      ##
        elsif ( ( $receipt->{'version'} // -1 ) != $head->{'version'} ) {
            $state = 'no fresh receipt';
        }
        $state = 'excluded' if $excluded{$name} and $state eq 'counted';
        $status{$name}{'state'} = $state;
        $status{$name}{'coverage'}
            = $receipt ? receipt_coverage($receipt) : undef;
        my $full = receipt_coverage($receipt) eq qw| full |;
        my $used = 0;
        foreach my $address ( keys %{ $map->{'nodes'} // {} } ) {
            $used += $map->{'nodes'}{$address}{'length'} // 0;
            if ( $state eq 'counted' ) {
                $copies{$address}{ $h->{'domain'} } = TRUE;
                $proven{$address}{ $h->{'domain'} } = TRUE if $full;
            }
            ## the entry itself : drain reads its disk ids ##
            $status{$name}{'nodes'}{$address} = $map->{'nodes'}{$address};
        }
        $status{$name}{'used'}  = $used;
        $status{$name}{'count'} = scalar keys %{ $map->{'nodes'} // {} };
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
    ## a holder that gets any file of a tree also gets the tree, so it can
    ## recover it by name
    require AMOS7::N7FS::Seal;
    my %tree_of;
    foreach my $name ( keys $replay->{'trees'}->%* ) {
        my $t = $replay->{'trees'}{$name};
        $tree_of{$ARG} = $name
            for $t->{'manifest'},
            AMOS7::N7FS::Seal::_manifest_files( $id, $t->{'manifest'} );
    }
    my %plan;
    my %left;
    foreach my $name ( keys %{$holders} ) {
        next if $holders->{$name}{'role'} ne qw| durable |;
        next if $status->{$name}{'state'} eq 'unreachable';
        next if $status->{$name}{'state'} eq 'excluded';
        $left{$name}
            = holder_room( $holders->{$name}, $status->{$name}{'used'} );
    }
    my @unplaced;
    foreach my $address ( sort keys %{$nodes} ) {
        my $n    = $nodes->{$address};
        my %have = %{ $copies->{$address} // {} };
        ## a durable holder that maps the node but lacks a receipt for its  ##
        ## current head is pending, not missing : place waits for its check ##
        ## instead of sending the node to another domain                    ##
        ## [ drain still counts only checked copies ]                       ##
        foreach my $name ( keys %{$holders} ) {
            next if $holders->{$name}{'role'} ne qw| durable |;
            next if $status->{$name}{'state'} ne 'no fresh receipt';
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
    my %done;
    if ( not $opt{'dry_run'} ) {
        require AMOS7::N7FS::Seal;
        foreach my $name ( sort keys %plan ) {
            my $r = AMOS7::N7FS::Seal::seal_nodes(
                %opt,
                qw| holder |    => $holders->{$name}{'spec'},
                qw| addresses | => $plan{$name},
                ## a placed manifest brings its tree name for recovery ##
                qw| trees | => [
                    sort grep {defined}
                    map       { $tree_of{$ARG} } $plan{$name}->@*
                ],
            );
            $done{$name} = $r->{'sealed'};
        }
    }
    return {
        qw| plan |   => { map { $ARG => scalar $plan{$ARG}->@* } keys %plan },
        qw| sealed | => \%done,
        qw| unplaced | => scalar @unplaced,
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

    my ( %live, %seen, %tree_files );
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
            $tree_files{$tree}{$ARG} = TRUE
                for AMOS7::N7FS::Seal::_manifest_files( $id, $manifest );
        }
    }
    my ( @drop, $bytes, $legacy_kept );
    ( $bytes, $legacy_kept ) = ( 0, 0 );
    foreach my $address ( sort keys $map->{'nodes'}->%* ) {
        next if $live{$address};
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
    my $result = { qw| removed | => 0, qw| trees | => 0 };
    if ( @drop and not $opt{'dry_run'} ) {
        $result = AMOS7::N7FS::Seal::unmap_nodes(
            %opt,
            qw| holder |     => $h->{'spec'},
            qw| addresses |  => \@drop,
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
        qw| legacy_kept | => $legacy_kept,
    };
}

1;

#,,,.,,,.,,,,,.,,,,,,,,,.,.,.,,,.,,.,,,,.,,,.,..,,...,...,.,,,,.,,,..,,.,,,,,,
#6XXJN3QLJPZD6GBA4AXHNZ64CKSG74MBZJXU47LUTDD5GC6727ZMYMKFQQN4GIGMC3BG3EPZRRERS
#\\\|MKFUYC2C5LOYE2SWYQHAOSGC47HH3RDWQ45ERGOV3EOYE4KRGV4 \ / AMOS7 \ YOURUM ::
#\[7]LD2F3NWHBB4AEXCUGM6A7YPLZYMUFHYNNM7CY6ZIYUMK7QN3MWCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
