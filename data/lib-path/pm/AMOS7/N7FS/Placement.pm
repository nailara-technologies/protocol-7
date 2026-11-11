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

our $VERSION = qw| AMOS7::N7FS::Placement-VERSION.CI3KUPA |;

@EXPORT_OK = qw| holders_load holder_add holder_remove receipt_write
    receipt_fresh placement_report place_missing parse_size |;

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
    my $holders = holders_load(%opt);
    $holders->{$name} = {
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
        qw| holder |  => $opt{'spec'},
        qw| root_id | => $opt{'root_id'},
        qw| time |    => time,
        qw| version | => $opt{'version'} + 0,
        qw| nodes |   => $opt{'nodes'} + 0,
        qw| samples | => $opt{'samples'} + 0,
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
    return ( $id, \%nodes, $replay );
}

## which domains hold each node, from the holders' own maps
sub _copies {
    my %opt     = @_;
    my $holders = holders_load(%opt);
    my %copies;
    my %status;
    require AMOS7::N7FS::Seal;
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
        my $used = 0;
        foreach my $address ( keys %{ $map->{'nodes'} // {} } ) {
            $used += $map->{'nodes'}{$address}{'length'} // 0;
            $copies{$address}{ $h->{'domain'} } = TRUE
                if $state eq 'counted';
            $status{$name}{'nodes'}{$address} = TRUE;
        }
        $status{$name}{'state'} = $state;
        $status{$name}{'used'}  = $used;
        $status{$name}{'count'} = scalar keys %{ $map->{'nodes'} // {} };
    }
    return ( $holders, \%copies, \%status );
}

sub placement_report {
    my %opt = @_;
    my ( $id, $nodes ) = _disk_nodes(%opt);
    my ( $holders, $copies, $status ) = _copies(%opt);
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

## seal each under-replicated node to holders in domains not yet holding it :
## owned first, then most quota left. nothing is taken from another node.
sub place_missing {
    my %opt = @_;
    my ( $id,      $nodes,  $replay ) = _disk_nodes(%opt);
    my ( $holders, $copies, $status ) = _copies(%opt);
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
        $left{$name}
            = defined $holders->{$name}{'quota'}
            ? $holders->{$name}{'quota'} - $status->{$name}{'used'}
            : 9**20;
        ## the reserve is space on the holder's disk n7fs never takes ##
        if ( defined $holders->{$name}{'reserve'} ) {
            require AMOS7::N7FS::Holder;
            my $free = AMOS7::N7FS::Holder::holder_free(
                $holders->{$name}{'spec'} );
            my $room
                = defined $free
                ? $free - $holders->{$name}{'reserve'}
                : 0;
            $left{$name} = $room if $room < $left{$name};
        }
    }
    my @unplaced;
    foreach my $address ( sort keys %{$nodes} ) {
        my $n    = $nodes->{$address};
        my %have = %{ $copies->{$address} // {} };
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

1;

#,,..,.,,,...,,..,,.,,.,.,,..,,,.,..,,..,,.,,,..,,...,...,,,.,,.,,,,.,...,,,.,
#GQ4GEN3PT6YQWQTNYETJOBCF3QHPR7G2AP2KP4QVMCY2KIR3WUNIHQGEXFGB6YGZZUFCIDV5QCCTI
#\\\|GWDMNAGEQXVX7C7AGWXXN25A4I6KYSCAR4Q7BHBYFDODHGRNQ6Y \ / AMOS7 \ YOURUM ::
#\[7]F6WZJNFMK743OZBLNCY5UGVJHR3TZ7NATUYMUJ34RPCTKF2DBOBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
