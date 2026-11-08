## [:< ##

package AMOS7::N7FS::Batch;    ##############################################

## one signed record and one journal operation for a reference-category batch.

use v5.32.0;
use utf8;
use strict;
use English;
use warnings;

use Exporter;
use base qw| Exporter |;
use vars qw| @EXPORT_OK $VERSION |;

our $VERSION = qw| AMOS7::N7FS::Batch-VERSION.TSZSCGQ |;

@EXPORT_OK = qw| batch_write batch_read batch_records_verify |;

use AMOS7::N7FS         qw| read_file signed_record_parse refuse fault |;
use AMOS7::N7FS::Sign   qw| verify |;
use AMOS7::N7FS::Record qw| record_write record_scan |;

our $ADDR_RE = qr{\AV7[A-Z2-7]{5}/[A-Z2-7]{7}/[A-Z2-7]{77}\z};
our $REF_RE  = qr{\A\d{14}/[A-Z2-7]{7}/[A-Z2-7]{77}/addr\z};
our $PATH_RE = qr{\A\d{14}\.[A-Z2-7]{8}\.batch-assignment\z};

sub _payload {
    my ( $id, $path, $rec ) = @ARG;
    refuse( 'batch %s : record format is not 3', $path )
        if $rec->{'format'} != 3;
    refuse( 'batch %s : signed by a foreign store key', $path )
        if $rec->{'signer_pub'} ne $id->{'store_pub'};
    refuse( 'batch %s : store signature does not verify', $path )
        if not verify( $id->{'store_pub'}, $rec->{'signed'}, $rec->{'sig'} );
    my $p = $rec->{'payload'};
    my ($ntime) = $path =~ m|\A(\d{14})|;
    refuse( 'batch %s : disk, ntime or category is invalid', $path )
        if $path !~ $PATH_RE
        or ( $p->{'disk'}     // '' ) ne $id->{'disk'}
        or ( $p->{'ntime'}    // '' ) ne $ntime
        or ( $p->{'category'} // '' )
        !~ m|\A[A-Za-z0-9][A-Za-z0-9_.-]{0,127}\z|
        or ( $p->{'bytes'} // '' ) !~ m|\A\d+\z|
        or ref $p->{'references'} ne qw| ARRAY |;
    my %seen;

    foreach my $ref ( $p->{'references'}->@* ) {
        refuse( 'batch %s : bad reference entry', $path )
            if ref $ref ne qw| HASH |
            or ( $ref->{'node'}      // '' ) !~ $ADDR_RE
            or ( $ref->{'reference'} // '' ) !~ $REF_RE;
        my $key = join "\0", @{$ref}{qw| node reference |};
        refuse( 'batch %s : duplicate reference entry', $path )
            if $seen{$key}++;
    }
    return $p;
}

sub batch_read {
    my ( $id, $path ) = @ARG;
    my $full = "$id->{'path'}/.n7fs/batch-assignments/$path";
    my $rec  = signed_record_parse( qw| batch |, read_file($full) );
    my $p    = _payload( $id, $path, $rec );
    return { %{$p}, qw| path | => $path, qw| full_path | => $full };
}

sub batch_write {
    my ( $id, $store, $category, $references, $bytes, $origin ) = @ARG;
    my $record = record_write(
        $id, $store,
        qw| batch |,
        qw| batch-assignments |,
        qw| batch-assignment |,
        {   qw| disk |     => $id->{'disk'},
            qw| category | => $category,
            qw| bytes |    => $bytes + 0,
            defined $origin ? ( qw| origin | => $origin ) : (),
            qw| references | => [
                map {
                    {
                        qw| node |          => $ARG->{'node'},
                            qw| reference | => $ARG->{'path'}
                    }
                } @{$references}
            ],
        }
    );
    fault(qw| batch:after-record |);
    return $record;
}

sub batch_records_verify {
    my ( $id, $replay ) = @ARG;
    my @records = record_scan(
        $id, qw| batch |,
        qw| batch-assignments |,
        qw| batch-assignment |
    );
    my %records = map { $ARG->{'path'} => $ARG } @records;
    foreach my $path ( sort keys $replay->{'batch_history'}->%* ) {
        refuse( 'format 3 : missing batch record %s', $path )
            if not $records{$path};
        _payload(
            $id, $path,
            signed_record_parse(
                qw| batch |, read_file( $records{$path}{'full_path'} )
            )
        );
        refuse( 'format 3 : batch %s origin differs from journal', $path )
            if ( $records{$path}{'origin'}{'id'} // $path ) ne
            ( $replay->{'batch_history'}{$path}{'origin'}{'id'} // $path )
            or ( $records{$path}{'origin'}{'disk'} // $id->{'disk'} ) ne
            ( $replay->{'batch_history'}{$path}{'origin'}{'disk'}
                // $id->{'disk'} );
    }
    foreach my $path ( sort keys %records ) {
        refuse( 'format 3 : unlisted batch record %s', $path )
            if not $replay->{'batch_history'}{$path};
    }
    return scalar @records;
}

1;

#,,,,,,..,.,.,.,.,,,,,,,.,.,.,,,.,...,...,.,,,..,,...,...,.,.,.,.,.,.,,.,,,.,,
#P6RAK5UMVVR7ZGJJKQG4YPYEBGJ3BM74ISHFSPQO3XBK2NUYKNZX5IVZFZQL5D5STH67H7QIKZUSS
#\\\|CRS6Y7DZNFA3MM5XBQZDICBZ2OQSEP44NN4MC3M4G5HN344QDRV \ / AMOS7 \ YOURUM ::
#\[7]FPH7CC5K2UTDCEJEP3HD5N6C55QS5J344EOCTERVKDXQCMJLSIDQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
