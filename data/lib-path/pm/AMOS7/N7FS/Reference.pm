## [:< ##

package AMOS7::N7FS::Reference;    #########################################

## N7FS store format 3 : signed references and their drop records.
##
## <node>/references/<ntime14>/<amos>/<bmw>/addr
## <node>/references/<ntime14>/<amos>/<bmw>/drop
##
## both records bind the disk, target address, holder, name and creation
## ntime.  the path repeats the target checksums, so moving either record
## breaks it.

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

our $VERSION = qw| AMOS7::N7FS::Reference-VERSION.PQ5M3CI |;

@EXPORT_OK = qw| reference_write reference_scan reference_drop_write
    reference_address |;

use AMOS7::N7FS qw| ntime_now ntime14 read_file write_new_file make_dirs
    signed_record_parse signed_record_pack refuse |;
use AMOS7::N7FS::Sum  qw| epoch_b32 |;
use AMOS7::N7FS::Sign qw| verify |;

our $ADDR_RE = qr{\AV7[A-Z2-7]{5}/[A-Z2-7]{7}/[A-Z2-7]{77}\z};
our $NT_RE   = qr{\A\d{14}\z};
our $AMOS_RE = qr{\A[A-Z2-7]{7}\z};
our $BMW_RE  = qr{\A[A-Z2-7]{77}\z};
our $TMP_RE  = qr{\.tmp\.[A-Z2-7]{8}\z};

sub reference_address {
    my $node = shift;
    return join '/', epoch_b32( $node->{'epoch'} ), $node->{'amos'},
        $node->{'bmw'};
}

sub _list {
    my ( $dir, $re ) = @ARG;
    opendir( my $dh, $dir )
        or refuse( 'cannot read %s : %s', $dir, $OS_ERROR );
    my @names = grep { $ARG ne '.' and $ARG ne '..' } readdir $dh;
    closedir $dh;
    my @bad = grep { $ARG !~ $re and $ARG !~ $TMP_RE } @names;
    refuse( 'unexpected entry in %s : %s', $dir, $bad[0] ) if @bad;
    return sort grep { $ARG =~ $re } @names;
}

sub _check_payload {
    my ( $rec, $p, $expected, $path ) = @ARG;
    refuse( 'reference %s : record format is not 3', $path )
        if $rec->{'format'} != 3;
    refuse( 'reference %s : signed by a foreign store key', $path )
        if $rec->{'signer_pub'} ne $expected->{'store_pub'};
    refuse( 'reference %s : store signature does not verify', $path )
        if not verify( $expected->{'store_pub'}, $rec->{'signed'},
        $rec->{'sig'} );
    foreach my $field (qw| disk addr ntime |) {
        refuse( 'reference %s : %s does not match its path', $path, $field )
            if ( $p->{$field} // '' ) ne $expected->{$field};
    }
    refuse( 'reference %s : empty holder or name', $path )
        if not length $p->{'holder'}
        or not length $p->{'name'};
    return;
}

sub _read {
    my ( $kind, $path, $expected ) = @ARG;
    my $rec = signed_record_parse( $kind, read_file($path) );
    _check_payload( $rec, $rec->{'payload'}, $expected, $path );
    return $rec;
}

sub reference_scan {
    my ( $node, $id ) = @ARG;
    my $base = "$node->{'path'}/references";
    return () if not -d $base;
    my $addr = reference_address($node);
    my ( undef, $amos, $bmw ) = split m|/|, $addr;
    my @out;

    foreach my $ntime ( _list( $base, $NT_RE ) ) {
        foreach my $a ( _list( "$base/$ntime", $AMOS_RE ) ) {
            foreach my $b ( _list( "$base/$ntime/$a", $BMW_RE ) ) {
                my $dir  = "$base/$ntime/$a/$b";
                my @file = _list( $dir, qr{\A(?:addr|drop)\z} );
                refuse( 'reference %s : no addr record', $dir )
                    if not grep { $ARG eq qw| addr | } @file;
                my $relative = "$ntime/$a/$b/addr";
                my %expected = (
                    qw| store_pub | => $id->{'store_pub'},
                    qw| disk |      => $id->{'disk'},
                    qw| addr |      => $addr,
                    qw| ntime |     => $ntime,
                );
                my $rec = _read( qw| reference |, "$dir/addr", \%expected );
                my $p   = $rec->{'payload'};
                refuse(
                    'reference %s : target checksums do not match its path',
                    $relative )
                    if $a ne $amos or $b ne $bmw;
                my $drop = grep { $ARG eq qw| drop | } @file;

                if ($drop) {
                    my $d = _read( qw| drop |, "$dir/drop", \%expected );
                    foreach my $field (qw| disk addr holder name ntime |) {
                        refuse(
                            'reference %s : drop differs from addr [ %s ]',
                            $relative, $field )
                            if $d->{'payload'}{$field} ne $p->{$field};
                    }
                }
                push @out,
                    {
                    %{$p},
                    qw| node |      => $addr,
                    qw| node_path | => $node->{'path'},
                    qw| path |      => $relative,
                    qw| full_path | => "$dir/addr",
                    qw| drop_path | => "$dir/drop",
                    qw| dropped |   => $drop ? TRUE : FALSE,
                    };
            }
        }
    }
    return @out;
}

sub reference_write {
    my ( $node, $id, $store, $holder, $name, $converted, $minimum ) = @ARG;
    refuse('reference write needs the delegated store key') if not ref $store;
    refuse('reference holder and name must not be empty')
        if not defined $holder
        or not length $holder
        or not defined $name
        or not length $name;
    my $addr  = reference_address($node);
    my $ntime = ntime_now();
    my $base  = "$node->{'path'}/references";
    if ( -d $base ) {
        foreach my $old ( _list( $base, $NT_RE ) ) {
            $ntime = $old + 1 if $ntime <= $old;
        }
    }
    $ntime = $minimum if defined $minimum and $ntime < $minimum;
    my $nt14    = ntime14($ntime);
    my $dir     = join '/', $base, $nt14, $node->{'amos'}, $node->{'bmw'};
    my %payload = (
        qw| disk |   => $id->{'disk'},
        qw| addr |   => $addr,
        qw| holder | => $holder,
        qw| name |   => $name,
        qw| ntime |  => $nt14,
    );
    $payload{'converted'} = JSON::PP::true if $converted;
    make_dirs( $dir, 0700 );
    write_new_file( "$dir/addr",
        signed_record_pack( qw| reference |, \%payload, $store, 3 ) );
    return {
        %payload,
        qw| node |      => $addr,
        qw| node_path | => $node->{'path'},
        qw| path |      => "$nt14/$node->{'amos'}/$node->{'bmw'}/addr",
        qw| full_path | => "$dir/addr",
        qw| drop_path | => "$dir/drop",
        qw| dropped |   => FALSE,
    };
}

sub reference_drop_write {
    my ( $ref, $id, $store ) = @ARG;
    refuse('reference drop needs the delegated store key') if not ref $store;
    refuse( 'reference %s is not live', $ref->{'path'} ) if $ref->{'dropped'};
    my %payload
        = map { $ARG => $ref->{$ARG} } qw| disk addr holder name ntime |;
    $payload{'converted'} = $ref->{'converted'} if $ref->{'converted'};
    refuse( 'reference %s : disk binding changed', $ref->{'path'} )
        if $payload{'disk'} ne $id->{'disk'};
    write_new_file( $ref->{'drop_path'},
        signed_record_pack( qw| drop |, \%payload, $store, 3 ) );
    return $ref->{'drop_path'};
}

1;

#,,,.,,.,,,,,,.,.,,,.,,,.,,.,,.,.,..,,,,.,...,.,.,...,...,...,..,,...,,..,,,,,
#FXACT6SLOBYW3URL3QOUNE5JPIQJTRXWSZ2JEXBMUX2MNOVJYSPPI5NSEMO6VPPYQR4CMHZN6CE44
#\\\|Z27DG53B2WRFH2B2PWOUS6B4NJQYICJS4POEWDP5PVRXTMN2RYF \ / AMOS7 \ YOURUM ::
#\[7]HLJ26QGPKYE5X4AV5SOJVREG7NYI4OYJEGNMCM7BFYFEKRKHV6DQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
