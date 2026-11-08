## [:< ##

package AMOS7::N7FS::Record;    #############################################

## signed, immutable store-set records outside the content epochs.

use v5.32.0;
use utf8;
use strict;
use English;
use warnings;

use Exporter;
use base qw| Exporter |;
use vars qw| @EXPORT_OK $VERSION |;

our $VERSION = qw| AMOS7::N7FS::Record-VERSION.FCDTWBQ |;

@EXPORT_OK = qw| record_write record_scan |;

use AMOS7::N7FS
    qw| ntime_now ntime14 b32 random_bytes read_file write_new_file
    make_dirs signed_record_pack signed_record_parse refuse |;
use AMOS7::N7FS::Sign qw| verify |;

sub _names {
    my ( $dir, $suffix ) = @ARG;
    return () if not -d $dir;
    opendir( my $dh, $dir )
        or refuse( 'cannot read %s : %s', $dir, $OS_ERROR );
    my @names = grep { $ARG ne '.' and $ARG ne '..' } readdir $dh;
    closedir $dh;
    my @bad = grep {
                $ARG !~ m|\A\d{14}\.[A-Z2-7]{8}\.\Q$suffix\E\z|
            and $ARG !~ m|\.tmp\.[A-Z2-7]{8}\z|
    } @names;
    refuse( 'unexpected record entry %s/%s', $dir, $bad[0] ) if @bad;
    return sort grep { $ARG =~ m|\.\Q$suffix\E\z| } @names;
}

sub record_write {
    my ( $id, $store, $kind, $subdir, $suffix, $payload ) = @ARG;
    refuse('record write needs the delegated store key') if not ref $store;
    my $dir = "$id->{'path'}/.n7fs/$subdir";
    make_dirs( $dir, 0700 );
    my $ntime = ntime_now();
    foreach my $name ( _names( $dir, $suffix ) ) {
        my ($old) = $name =~ m|\A(\d{14})|;
        $ntime = $old + 1 if $ntime <= $old;
    }
    my $name = sprintf qw| %s.%s.%s |, ntime14($ntime),
        b32( random_bytes(5) ), $suffix;
    $payload->{'ntime'} //= ntime14($ntime);
    refuse( 'record %s : ntime does not match its path', $name )
        if $payload->{'ntime'} ne ntime14($ntime);
    write_new_file( "$dir/$name",
        signed_record_pack( $kind, $payload, $store, 3 ) );
    return {
        %{$payload},
        qw| path |      => $name,
        qw| full_path | => "$dir/$name"
    };
}

sub record_scan {
    my ( $id, $kind, $subdir, $suffix ) = @ARG;
    my $dir = "$id->{'path'}/.n7fs/$subdir";
    my @out;
    foreach my $name ( _names( $dir, $suffix ) ) {
        my $path = "$dir/$name";
        my $rec  = signed_record_parse( $kind, read_file($path) );
        refuse( '%s %s : record format is not 3', $kind, $name )
            if $rec->{'format'} != 3;
        refuse( '%s %s : signed by a foreign store key', $kind, $name )
            if $rec->{'signer_pub'} ne $id->{'store_pub'};
        refuse( '%s %s : store signature does not verify', $kind, $name )
            if
            not verify( $id->{'store_pub'}, $rec->{'signed'}, $rec->{'sig'} );
        my $p = $rec->{'payload'};
        if ( defined $p->{'origin'} ) {
            refuse( '%s %s : bad origin', $kind, $name )
                if ref $p->{'origin'} ne qw| HASH |
                or ( $p->{'origin'}{'disk'} // '' ) !~ m|\A[A-Z2-7]{7}\z|
                or not length( $p->{'origin'}{'id'} // '' );
        }
        my ($ntime) = $name =~ m|\A(\d{14})|;
        refuse( '%s %s : disk or ntime does not match its path',
            $kind, $name )
            if ( $p->{'disk'} // '' ) ne $id->{'disk'}
            or ( $p->{'ntime'} // '' ) ne $ntime;
        push @out, { %{$p}, qw| path | => $name, qw| full_path | => $path };
    }
    return @out;
}

1;

#,,..,,.,,.,.,...,..,,,,,,.,.,,.,,...,,..,..,,..,,...,...,..,,,..,.,.,,.,,,,,,
#2KZ7FLWZNR4OKPDUC4ZNLZHXZLHKF5M4WA62EMHARZA47O6T5QKYBD3KNGXW7GLELAVRN25YZUC5S
#\\\|BJMAGSYAE266DTSFPISA23L6OPNRYWSE4UVKLRCTXTUS26CQFXD \ / AMOS7 \ YOURUM ::
#\[7]BYKJT3NZBKITEE64U5VOD2BBF2NNYWLY4PPVDZ564UU6AL2DPGAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
