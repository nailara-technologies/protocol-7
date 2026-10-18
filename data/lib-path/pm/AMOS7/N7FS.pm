## [:< ##

package AMOS7::N7FS;    #####################################################

## N7FS version 1 : common layer -- paths, records, synced writes.
##
## format : data/md/design/N7FS-SPEC.md [ the as-built notes are in
## data/md/design/N7FS-FORMAT-1.md -- keep both in step with the code ]
##
## standalone like AMOS7::Vault [ no zenka, no running network ]. the write
## order is the vault's
## [ tmp + fsync + link \ rename + dir fsync, read back + compare ] --
## reimplemented here, AMOS7::Vault's private helpers are not called and that
## file is not changed [ its signature stays valid ].
##
## every refusal is a die with a 'n7fs : ' message BEFORE the first change ;
## callers catch it [ bin/n7fs ].

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
use vars qw| @EXPORT_OK $VERSION |;

our $VERSION = qw| AMOS7::N7FS-VERSION.S5AOMKI |;

@EXPORT_OK = qw|
    root_dir
    host_dir
    ntime_now
    ntime14
    b32
    unb32
    random_bytes
    signed_record_pack
    signed_record_parse
    plain_record_pack
    plain_record_parse
    write_new_file
    write_new_file_stream
    read_file
    sync_dir
    make_dirs
    publish_dir
    remove_tree
    fault
    refuse
    |;

##[ DEPENDENCIES ]############################################################

use Fcntl qw| O_RDONLY O_WRONLY O_CREAT O_EXCL |;
use IO::Handle;
use JSON::PP;
use Time::HiRes qw| time |;
use AMOS7::NTIME;
use Crypt::Misc qw| encode_b32r decode_b32r |;

##[ FORMAT CONSTANTS ]########################################################

## 4-byte magic + 1 format byte in every binary header [ spec section 6 ]
our %MAGIC = (
    qw| id |    => qw| P7FS |,    ## disk identity record ##
    qw| mount | => qw| P7FA |,    ## attach \ detach record ##
    qw| use |   => qw| P7FU |,    ## witness first \ last use window ##
    qw| state | => qw| P7FT |,    ## store state [ format, epochs ] ##
    qw| meta |  => qw| P7FN |,    ## node meta [ one per import ] ##
);

## one label per signed kind : no signature is valid as another kind, and none
## collides with host-root's 'p7 delegation v1' statements
our %LABEL = (
    qw| id |    => 'p7 n7fs disk id v1',
    qw| mount | => 'p7 n7fs mount v1',
    qw| use |   => 'p7 n7fs use window v1',
    qw| state | => 'p7 n7fs state v1',
    qw| meta |  => 'p7 n7fs meta v1',
);

## record formats this code reads [ per kind ; the store format is a field of
## the state record, converters register further node formats ]
our %RECORD_FORMAT = map { $ARG => { 1 => TRUE } } keys %MAGIC;

our $JSON = JSON::PP->new->utf8->canonical;

our $DEFAULT_ROOT = qw| /N7FS |;

##[ PATHS ]###################################################################

## the root is /N7FS unless overridden [ option, then N7FS_ROOT ] -- tests
## never see the default
sub root_dir {
    my %opt  = @ARG;
    my $root = $opt{'root'} // $ENV{'N7FS_ROOT'} // $DEFAULT_ROOT;
    $root =~ s|/+\z|| if length $root > 1;
    return $root;
}

## host-side state : keys, witness, the host's copy of mount records
sub host_dir {
    my %opt = @ARG;
    my $dir = $opt{'host_dir'} // $ENV{'N7FS_HOST_DIR'};
    if ( not defined $dir ) {
        refuse('no home directory [ set N7FS_HOST_DIR ]')
            if not length( $ENV{'HOME'} // '' );
        $dir = "$ENV{'HOME'}/.n/n7fs";
    }
    $dir =~ s|/+\z|| if length $dir > 1;
    return $dir;
}

##[ ERRORS \ TEST HOOKS ]#####################################################

sub refuse {
    my $msg = shift;
    $msg = sprintf $msg, @ARG if @ARG;
    die "n7fs : $msg\n";
}

## fault injection for the tests : a code ref receiving the point name, it
## dies to simulate a failure there. undef in normal use
our $FAULT;

sub fault {
    my $point = shift;
    $FAULT->($point) if ref $FAULT eq qw| CODE |;
    return;
}

##[ NETWORK TIME ]############################################################

## whole ntime units [ AMOS7::NTIME ] ; injectable for the tests
our $CLOCK = sub { return AMOS7::NTIME::unix_to_ntime( time, 0 ) };

sub ntime_now {
    my $ntime = $CLOCK->();
    refuse('clock returned no ntime')
        if not defined $ntime
        or $ntime !~ m|\A\d+\z|;
    return $ntime + 0;
}

## the decimal path form : integer part zero-padded to 14 digits -- a plain
## listing sorts in exact time order [ spec section 2 ]
sub ntime14 {
    my $ntime = shift // '';
    refuse( 'not a whole ntime [ %s ]', $ntime )
        if $ntime !~ m|\A\d{1,14}\z|;
    return sprintf qw| %014d |, $ntime;
}

##[ ENCODING ]################################################################

## rfc 4648, upper case, no '=' padding [ the vault's form ]
sub b32 {
    my $out = encode_b32r(shift);
    $out =~ s|=+\z||;
    return $out;
}

sub unb32 {
    my $in = shift // '';
    return undef if $in !~ m|\A[A-Z2-7]+\z|;
    return eval { decode_b32r($in) };
}

sub random_bytes {
    my $len = shift;
    my $buf = '';

    if ( open( my $fh, '<:raw', qw| /dev/urandom | ) ) {
        read( $fh, $buf, $len );
        close $fh;
    }
    if ( length $buf != $len ) {
        require Crypt::PRNG;
        $buf = Crypt::PRNG::random_bytes($len);
    }
    refuse('no random source') if length $buf != $len;
    return $buf;
}

##[ RECORDS ]#################################################################

## signed record :  magic [ 4 ] , format [ 1 ] , label [ n/a* ] , payload
## [ N/a* ] , signer public key [ 32 ] , signature [ 64 ]  the ed25519
## signature covers every byte before it. the payload is canonical json
## [ utf-8 ] -- verified over the stored bytes, never over a re-serialization.
## lengths are prefixed, nothing is bare concatenation

sub _head {
    my ( $kind, $format ) = @ARG;
    refuse( 'unknown record kind [ %s ]', $kind ) if not exists $MAGIC{$kind};
    return $MAGIC{$kind} . pack( qw| C |, $format // 1 );
}

sub signed_record_pack {
    my ( $kind, $payload, $signer, $format ) = @ARG;

    my $pub = $signer->public;
    refuse('signer public key is not 32 bytes') if length $pub != 32;

    my $body
        = _head( $kind, $format )
        . pack( 'n/a* N/a* a32',
        $LABEL{$kind}, $JSON->encode($payload), $pub );
    my $sig = $signer->sign($body);
    refuse('signer returned no 64 byte signature')
        if not defined $sig
        or length $sig != 64;
    return $body . $sig;
}

## strict reader : magic, a known format, the label of the kind, exact
## lengths, no trailing bytes. returns the parsed record ; the signature is
## checked by the caller with AMOS7::N7FS::Sign::verify over ->{'signed'}
sub signed_record_parse {
    my ( $kind, $bytes ) = @ARG;
    return _parse( $kind, $bytes, TRUE );
}

sub plain_record_pack {
    my ( $kind, $payload, $format ) = @ARG;
    return _head( $kind, $format )
        . pack( 'n/a* N/a*', $LABEL{$kind}, $JSON->encode($payload) );
}

sub plain_record_parse {
    my ( $kind, $bytes ) = @ARG;
    return _parse( $kind, $bytes, FALSE );
}

sub _parse {
    my ( $kind, $bytes, $signed ) = @ARG;

    refuse( 'unknown record kind [ %s ]', $kind ) if not exists $MAGIC{$kind};
    refuse( '%s record missing',          $kind ) if not defined $bytes;
    refuse( '%s record too short',   $kind ) if length $bytes < 5 + 2 + 4;
    refuse( '%s record : bad magic', $kind )
        if substr( $bytes, 0, 4 ) ne $MAGIC{$kind};

    my $format = unpack( qw| C |, substr( $bytes, 4, 1 ) );
    refuse( '%s record : unknown format %d', $kind, $format )
        if not $RECORD_FORMAT{$kind}{$format};

    my $pos       = 5;
    my $label_len = unpack( qw| n |, substr( $bytes, $pos, 2 ) );
    $pos += 2;
    refuse( '%s record : truncated label', $kind )
        if $pos + $label_len + 4 > length $bytes;
    my $label = substr( $bytes, $pos, $label_len );
    $pos += $label_len;
    refuse( '%s record : wrong label', $kind ) if $label ne $LABEL{$kind};

    my $payload_len = unpack( qw| N |, substr( $bytes, $pos, 4 ) );
    $pos += 4;
    my $tail = $signed ? 32 + 64 : 0;
    refuse( '%s record : length mismatch', $kind )
        if $pos + $payload_len + $tail != length $bytes;
    my $payload_raw = substr( $bytes, $pos, $payload_len );
    $pos += $payload_len;

    my $payload = eval { $JSON->decode($payload_raw) };
    refuse( '%s record : payload is not a json object', $kind )
        if ref $payload ne qw| HASH |;

    my %record = (
        qw| kind |    => $kind,
        qw| format |  => $format,
        qw| payload | => $payload,
    );
    if ($signed) {
        $record{'signer_pub'} = substr( $bytes, $pos,      32 );
        $record{'sig'}        = substr( $bytes, $pos + 32, 64 );
        $record{'signed'}     = substr( $bytes, 0,         $pos + 32 );
    }
    return \%record;
}

##[ SYNCED WRITES ]###########################################################

sub read_file {
    my $path = shift;
    open( my $fh, '<:raw', $path ) or return undef;
    local $INPUT_RECORD_SEPARATOR;
    my $content = <$fh>;
    close $fh;
    return $content // '';
}

sub sync_dir {
    my $dir = shift;
    sysopen( my $dh, $dir, O_RDONLY ) or return FALSE;
    my $ok = eval { $dh->sync } ? TRUE : FALSE;
    close $dh;
    return $ok;
}

sub _dir_of { ( my $dir = shift ) =~ s|/[^/]+\z||; return $dir }

## a new file that must not exist yet [ versions are never replaced ]
sub write_new_file {
    my ( $path, $content ) = @ARG;
    my $written = write_new_file_stream( $path,
        sub { print { $ARG[0] } $content or die "$OS_ERROR\n" } );

    ## read back + compare : the final name holds exactly what was meant
    my $back = read_file($path);
    refuse( 'read back of %s differs', $path )
        if not defined $back
        or $back ne $content;
    return $written;
}

## the streaming form : $writer gets the temp handle and dies on a failed
## write. content to disk, THEN the final name [ link fails on an existing
## name ; filesystems without hard links fall back to a checked rename ], then
## the directory is synced so the name survives a power cut
sub write_new_file_stream {
    my ( $path, $writer, $mode ) = @ARG;

    refuse( '%s exists', $path ) if -e $path or -l $path;
    my $tmp = sprintf qw| %s.tmp.%s |, $path, b32( random_bytes(5) );
    sysopen( my $fh, $tmp, O_WRONLY | O_CREAT | O_EXCL, $mode // 0600 )
        or refuse( 'cannot create %s : %s', $tmp, $OS_ERROR );
    binmode $fh;

    my $ok  = eval { $writer->($fh); 1 } ? TRUE : FALSE;
    my $err = $EVAL_ERROR;
    $ok &&= $fh->flush;
    $ok &&= $fh->sync;
    $ok &&= close $fh;

    if ( not $ok ) {
        $err ||= "$OS_ERROR";
        unlink $tmp;
        chomp $err;
        refuse( 'cannot write %s : %s', $tmp, $err );
    }

    if ( link $tmp, $path ) {
        unlink $tmp;
    } elsif ( -e $path or -l $path or not rename $tmp, $path ) {
        my $link_err = "$OS_ERROR";
        unlink $tmp;
        refuse( 'cannot create %s : %s', $path, $link_err );
    }
    sync_dir( _dir_of($path) );
    return $path;
}

## mkdir -p with a sync of the parent of every directory it creates
## [ a new name lives in its parent ] ; returns the created directories
sub make_dirs {
    my ( $dir, $mode ) = @ARG;
    my @created;
    my @parts = grep {length} split m|/|, $dir;
    my $path  = index( $dir, '/' ) == 0 ? '' : '.';
    foreach my $part (@parts) {
        $path = $path eq '.' ? $part : "$path/$part";
        next                                                if -d $path;
        refuse( '%s exists and is not a directory', $path ) if -e $path;
        mkdir $path, $mode // 0700
            or refuse( 'cannot create %s : %s', $path, $OS_ERROR );
        my $parent = _dir_of($path);
        sync_dir( length $parent ? $parent : '/' );
        push @created, $path;
    }
    return @created;
}

## atomic publish : a finished temp directory takes its final name in one
## rename. rename onto an EMPTY directory succeeds on linux, so the target is
## checked first ; the parent is synced afterwards
sub publish_dir {
    my ( $tmp, $final ) = @ARG;
    refuse( '%s exists', $final ) if -e $final or -l $final;
    rename $tmp, $final
        or refuse( 'cannot publish %s : %s', $final, $OS_ERROR );
    sync_dir( _dir_of($final) );
    return $final;
}

## removes a tree this code created [ temp builds, a failed conversion ].
## never follows a symlink
sub remove_tree {
    my $path = shift;
    return TRUE if not -e $path and not -l $path;
    if ( -l $path or not -d _ ) {
        return unlink($path) ? TRUE : FALSE;
    }
    opendir( my $dh, $path ) or return FALSE;
    my @entries = grep { $ARG ne '.' and $ARG ne '..' } readdir $dh;
    closedir $dh;
    remove_tree("$path/$ARG") for @entries;
    return rmdir($path) ? TRUE : FALSE;
}

1;

#,,,,,..,,,,,,...,,..,,,,,...,.,,,.,,,,,,,...,..,,...,...,...,.,.,..,,,.,,...,
#2DZTOXKEIDYXCVYDIFIZBBNTVDWPLMQICAQU27QJTBLBXTOX6PDUS6ME7BFKX5UKIAXCECDRN6C6O
#\\\|PX3AU4QGOBKEWRX6UAMVYXDVAQTQU4U5QA2Y6Z6IEFY3GEU5NXA \ / AMOS7 \ YOURUM ::
#\[7]QJSP2LUO565BFFQQ7ZLWU7JKJJVINGTVRKK3P33UBFOFS434V2AI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
