## [:< ##

package AMOS7::N7FS::Holder;    ############################################

## local and posix-sh holder transport. remote names are ciphertext only.

use v5.32.0;
use utf8;
use strict;
use English;
use warnings;

use Exporter;
use base qw| Exporter |;
use vars qw| @EXPORT_OK $VERSION |;
our $VERSION = qw| AMOS7::N7FS::Holder-VERSION.7WDEFUI |;

@EXPORT_OK = qw| holder_parse holder_canonical holder_mkdir holder_read
    holder_sizes holder_free
    holder_size holder_put holder_delete holder_verify holder_download
    holder_read_range holder_scrub |;

use Cwd qw| abs_path |;
use IO::Select;
use IPC::Open3 qw| open3 |;
use Symbol     qw| gensym |;
use Digest::BMW;
use AMOS7::N7FS
    qw| random_bytes read_file write_new_file make_dirs refuse b32 sync_dir |;
use AMOS7::N7FS::Sum qw| bmw384_bytes bmw_b32 |;

sub holder_parse {
    my $spec = shift // '';
    return { qw| type | => qw| local |, qw| dir | => $spec }
        if $spec !~ m|\Assh:|;
    my ( $alias, $dir ) = $spec =~ m|\Assh:([^:]+):(/[^:]+)\z|;
    refuse('ssh holder alias or directory is invalid')
        if not defined $alias
        or $alias !~ m|\A[A-Za-z0-9_.][A-Za-z0-9_.-]*\z|
        or $dir   !~ m|\A/[A-Za-z0-9_./-]+\z|
        or index( $dir, '..' ) >= 0
        or index( $dir, '//' ) >= 0;
    return {
        qw| type |  => qw| ssh |,
        qw| alias | => $alias,
        qw| dir |   => $dir,
        qw| spec |  => "ssh:$alias:$dir"
    };
}

sub holder_canonical {
    my $h = holder_parse(shift);
    return $h->{'spec'} if $h->{'type'} eq qw| ssh |;
    my $dir = abs_path( $h->{'dir'} ) // refuse('cannot canonicalize holder');
    return $dir;
}

sub _path {
    my ( $h, $name ) = @_;
    refuse('holder name is invalid')
        if ( $name // '' ) !~ m|\A[A-Za-z0-9_.-]+\z|;
    return "$h->{'dir'}/$name";
}

sub _quote {
    my $text = shift;
    $text =~ s|'|'"'"'|g;
    return "'$text'";
}

sub _delays {
    return map { 0 + $ARG } split m|,|, $ENV{'N7FS_SSH_BACKOFF'}
        if defined $ENV{'N7FS_SSH_BACKOFF'};
    return ( 2, 5, 15, 30, 0 );
}

## upload rate cap in bytes per second, 0 = none [ n7fs -bwlimit ] : a
## wireless link under sustained full load has taken a host down
our $BWLIMIT = 0;

sub _throttle {
    my ( $start, $sent ) = @_;
    return if not $BWLIMIT;
    my $ahead = $sent / $BWLIMIT - ( Time::HiRes::time() - $start );
    Time::HiRes::sleep($ahead) if $ahead > 0;
    return;
}

## free bytes at a holder's directory, undef when unknown ##
sub holder_free {
    my $spec = shift;
    my $h    = holder_parse($spec);
    my $out;
    if ( $h->{'type'} eq qw| local | ) {
        open( my $fh, '-|', 'df', '-Pk', $h->{'dir'} ) or return undef;
        local $INPUT_RECORD_SEPARATOR;
        $out = <$fh>;
        close $fh;
    } else {
        my $status;
        ( $status, $out ) = _result( $h, 'df -Pk ' . _quote( $h->{'dir'} ) );
        return undef if $status;
    }
    my @line = split ' ', ( split m|\n|, $out // '' )[-1] // '';
    return undef if ( $line[3] // '' ) !~ m|\A\d+\z|;
    return $line[3] * 1024;
}

## one shared ssh connection per holder host : a blob costs about ten ssh
## calls [ sizes, upload, readback, sync, rename ], each a full handshake
## without it. off with N7FS_SSH_MUX=0 ; a test ssh [ N7FS_SSH ] gets none
sub _mux_options {
    return ()
        if defined $ENV{'N7FS_SSH'}
        or ( $ENV{'N7FS_SSH_MUX'} // 1 ) eq '0';
    my $dir = ( $ENV{'HOME'} // return () ) . '/.n/n7fs/ssh-mux';
    if ( not -d $dir ) {
        require File::Path;
        File::Path::make_path( $dir, { qw| mode | => 0700 } );
    }
    return () if not -d $dir or not -o $dir;
    chmod 0700, $dir;
    return (
        qw| -o ControlMaster=auto |, '-o',
        "ControlPath=$dir/%C",       qw| -o ControlPersist=60 |
    );
}

sub _ssh {
    my ( $h, $command, $input, $output ) = @_;
    my $program = $ENV{'N7FS_SSH'} // 'ssh';
    my $err     = gensym;
    my ( $in, $out ) = ( undef, gensym );
    ## a silent link is given up after 77 s [ 11 x 7 ], then retried ##
    my $pid = open3(
        $in, $out, $err, $program,
        qw| -o BatchMode=yes -o ConnectTimeout=30 -o ServerAliveInterval=11
            -o ServerAliveCountMax=7 |,
        _mux_options(),
        $h->{'alias'}, $command
    );
    binmode $in;
    binmode $out;
    my $write_ok = 1;
    {
        local $SIG{'PIPE'} = 'IGNORE';
        if ( ref $input ) {
            require Time::HiRes;
            my ( $start, $sent ) = ( Time::HiRes::time(), 0 );
            while (1) {
                my $got = sysread( $input, my $buf, 65536 );
                $write_ok = 0 if not defined $got;
                last if not $got;
                my $offset = 0;
                while ( $offset < length $buf ) {
                    my $put = syswrite( $in, $buf, length($buf) - $offset,
                        $offset );
                    $write_ok = 0 if not defined $put;
                    last          if not $put;
                    $offset += $put;
                }
                last if not $write_ok;
                $sent += $got;
                _throttle( $start, $sent );
            }
        } elsif ( defined $input ) {
            my $offset = 0;
            while ( $offset < length $input ) {
                my $put = syswrite( $in, $input, length($input) - $offset,
                    $offset );
                $write_ok = 0 if not defined $put;
                last          if not $put;
                $offset += $put;
            }
        }
        $write_ok = 0 if not close $in;
    }
    my ( $stdout, $stderr ) = ( '', '' );
    my $dest;
    if ( defined $output ) {
        open( $dest, '>>:raw', $output )
            or refuse( 'cannot open download spool : %s', $output );
    }
    my $select = IO::Select->new( $out, $err );
    while ( $select->count ) {
        for my $fh ( $select->can_read ) {
            my $got = sysread( $fh, my $buf, 1048576 );
            if ( not $got ) {
                $select->remove($fh);
                close $fh;
                next;
            }
            if ( fileno($fh) == fileno($out) ) {
                defined $output ? print {$dest} $buf : ( $stdout .= $buf );
            } else {
                $stderr .= $buf;
            }
        }
    }
    close $dest if defined $dest;
    waitpid $pid, 0;
    my $status = $CHILD_ERROR >> 8;
    $status = 73                       if $write_ok == 0 and not $status;
    $stderr = substr( $stderr, -4096 ) if length($stderr) > 4096;
    return ( $status, $stdout, $stderr );
}

sub _retry {
    my ( $h, $command, $input ) = @_;
    my @delays = _delays();
    my ( $status, $out, $err );
    for my $try ( 0 .. $#delays ) {
        ( $status, $out, $err ) = _ssh( $h, $command, $input );
        return ( $status, $out, $err ) if not $status or $status == 44;
        sleep $delays[$try]            if $try < $#delays;
    }
    refuse( 'ssh holder command failed after retries : %s', $err );
}

sub _result {
    my ( $h, $command ) = @_;
    my @delays = _delays();
    my ( $status, $out, $err );
    for my $try ( 0 .. $#delays ) {
        ( $status, $out, $err ) = _ssh( $h, $command );
        return ( $status, $out, $err )
            if not $status or $status == 44;
        sleep $delays[$try] if $try < $#delays;
    }
    refuse( 'ssh holder read failed after retries : %s', $err );
}

sub holder_mkdir {
    my $h = holder_parse(shift);
    return make_dirs( $h->{'dir'}, 0700 ) if $h->{'type'} eq qw| local |;
    _retry( $h, 'mkdir -p -- ' . _quote( $h->{'dir'} ) );
    return;
}

sub holder_read {
    my ( $spec, $name ) = @_;
    my $h = holder_parse($spec);
    return read_file( _path( $h, $name ) ) if $h->{'type'} eq qw| local |;
    my $path = _quote( _path( $h, $name ) );
    my ( $status, $out )
        = _result( $h, "[ -e $path ] || exit 44; cat -- $path" );
    return undef                                   if $status == 44;
    refuse( 'ssh holder read failed : %s', $name ) if $status;
    return $out;
}

sub holder_size {
    my ( $spec, $name ) = @_;
    my $h = holder_parse($spec);
    return -s _path( $h, $name ) if $h->{'type'} eq qw| local |;
    my $path = _quote( _path( $h, $name ) );
    my ( $status, $out )
        = _result( $h, "[ -e $path ] || exit 44; wc -c < $path" );
    return undef if $status == 44;
    refuse( 'ssh holder size failed : %s', $name )
        if $status or $out !~ m|\A\s*(\d+)|;
    return 0 + $1;
}

## every blob name with its size, in one listing ##
sub holder_sizes {
    my $spec = shift;
    my $h    = holder_parse($spec);
    my %size;
    if ( $h->{'type'} eq qw| local | ) {
        opendir( my $dh, $h->{'dir'} ) or return {};
        foreach my $name ( readdir $dh ) {
            next if $name !~ m|\A[A-Z2-7]{77}\z|;
            $size{$name} = -s "$h->{'dir'}/$name";
        }
        closedir $dh;
        return \%size;
    }
    my ( $status, $out )
        = _result( $h, 'cd ' . _quote( $h->{'dir'} ) . ' && ls -ln' );
    refuse('ssh holder listing failed') if $status;
    foreach my $line ( split m|\n|, $out ) {
        my @f = split ' ', $line;
        next if @f < 9 or $f[-1] !~ m|\A[A-Z2-7]{77}\z|;
        $size{ $f[-1] } = $f[4] + 0;
    }
    return \%size;
}

sub holder_delete {
    my ( $spec, $name ) = @_;
    my $h = holder_parse($spec);
    return unlink( _path( $h, $name ) ) if $h->{'type'} eq qw| local |;
    _retry( $h, 'rm -f -- ' . _quote( _path( $h, $name ) ) );
    return;
}

sub holder_read_range {
    my ( $spec, $name, $offset, $len ) = @_;
    refuse('invalid holder range')
        if $offset !~ m|\A\d+\z| or $len !~ m|\A[1-9]\d*\z|;
    my $h    = holder_parse($spec);
    my $path = _path( $h, $name );
    if ( $h->{'type'} eq qw| local | ) {
        open( my $fh, '<:raw', $path ) or return undef;
        seek $fh, $offset, 0;
        my $got = read( $fh, my $buf, $len );
        close $fh;
        return $buf;
    }
    my $quoted = _quote($path);
    my $start  = $offset + 1;
    my ( $status, $out )
        = _result( $h,
        "[ -e $quoted ] || exit 44; tail -c +$start $quoted | head -c $len" );
    return undef                                     if $status == 44;
    refuse( 'holder range read failed : %s', $name ) if $status;
    return $out;
}

sub holder_download {
    my ( $spec, $name, $local ) = @_;
    my $h = holder_parse($spec);
    if ( $h->{'type'} eq qw| local | ) {
        link( _path( $h, $name ), $local )
            or refuse('cannot spool local content');
        return;
    }
    my $remote_size = holder_size( $spec, $name );
    refuse('remote content is missing') if not defined $remote_size;
    my @delays = _delays();
    my $path   = _quote( _path( $h, $name ) );
    my $status = 1;
    for my $try ( 0 .. $#delays ) {
        my $have = -s $local // 0;
        refuse('download spool is larger than remote content')
            if $have > $remote_size;
        last if $have == $remote_size;
        ## resume : only the bytes after what the spool holds ##
        my $read
            = $have
            ? 'tail -c +' . ( $have + 1 ) . " -- $path"
            : "cat -- $path";
        ($status) = _ssh( $h, $read, undef, $local );
        ## a clean exit with bytes missing is a short read : the next try ##
        ## appends the rest                                               ##
        $status = 1 if not $status and ( -s $local // 0 ) != $remote_size;
        last        if not $status;
        sleep $delays[$try] if $try < $#delays;
    }
    refuse('holder download failed after retries') if $status;
    refuse('holder download size mismatch')
        if ( -s $local // -1 ) != $remote_size;
    return;
}

sub holder_verify {
    my ( $spec, $name, $local, $kind ) = @_;
    my $expected    = -s $local;
    my $remote_size = holder_size( $spec, $name );
    refuse( 'holder readback size mismatch for %s', $name )
        if not defined $remote_size or $remote_size != $expected;
    if ( $kind eq qw| pack | ) {
        ## a pack is checked by two random ranges, not read back whole ##
        for ( 1 .. 2 ) {
            my $len = $expected < 65536 ? $expected : 65536;
            my $offset
                = unpack( 'N', random_bytes(4) ) % ( $expected - $len + 1 );
            my $remote = holder_read_range( $spec, $name, $offset, $len );
            open( my $cf, '<:raw', $local ) or refuse('cannot read pack');
            seek $cf, $offset, 0;
            read( $cf, my $local_part, $len );
            close $cf;
            refuse( 'holder pack readback mismatch for %s', $name )
                if not defined $remote or $remote ne $local_part;
        }
        return 1;
    }
    if ( $kind ne qw| content | ) {
        my $back = holder_read( $spec, $name );
        refuse( 'holder readback checksum mismatch for %s', $name )
            if not defined $back
            or $back ne read_file($local);
        return 1;
    }
    open( my $fh, '<:raw', $local ) or refuse('cannot read spooled blob');
    my $head = '';
    read( $fh, $head, 26 );
    my $chunks = unpack qw| Q> |, substr( $head, 18, 8 );
    my @offsets;
    my $pos = 26;
    for my $index ( 0 .. $chunks - 1 ) {
        read( $fh, my $len_raw, 4 );
        my $len = unpack qw| N |, $len_raw;
        push @offsets, [ $pos, $len ];
        $pos += 4 + $len;
        seek $fh, $len, 1;
    }
    my $pick = $chunks > 1 ? unpack( 'N', random_bytes(4) ) % $chunks : 0;
    for my $index ( 0, $pick ) {
        my ( $offset, $len ) = $offsets[$index]->@*;
        my $remote = holder_read_range( $spec, $name, $offset, $len );
        open( my $cf, '<:raw', $local );
        seek $cf, $offset, 0;
        read( $cf, my $local_chunk, $len );
        close $cf;
        refuse( 'holder chunk readback mismatch for %s', $name )
            if not defined $remote or $remote ne $local_chunk;
    }
    close $fh;
    return 1;
}

## keyless integrity : a blob's name is the bmw384 base32 of its own        ##
## ciphertext, so a holder verifies every byte it keeps without any key.    ##
## with a nonce the digest runs over nonce-bytes + blob-bytes : home sends  ##
## one nonce to two holders and compares their answers, without reading the ##
## blobs. the head is never named by its checksum -- list-less scrub        ##
## reports it among the bad, so verification always passes the map's blob   ##
## names [ holder-check -scrub, n7fs holder-scrub ]                         ##
sub _scrub_bytes {
    my ( $path, $name, $nonce ) = @_;
    open( my $fh, '<:raw', $path ) or return undef;
    my $ctx = Digest::BMW->new(384);
    $ctx->add($nonce) if defined $nonce;
    while (1) {
        my $got = sysread( $fh, my $buf, 1048576 );
        if ( not defined $got ) { close $fh; return undef }
        last if $got == 0;
        $ctx->add($buf);
    }
    close $fh;
    return bmw_b32( $ctx->digest );
}

sub _scrub_result {
    return {
        qw| ok |      => 0,
        qw| bad |     => [],
        qw| missing | => [],
        qw| answer |  => {}
    };
}

## every name checked against its own bytes, streamed : nothing large in ##
## memory                                                                ##
sub _scrub_dir {
    my ( $dir, $names, $nonce ) = @_;
    my @list = @{ $names // [] };
    if ( not @list ) {
        opendir( my $dh, $dir ) or refuse('cannot list the holder');
        @list = sort grep {m|\A[A-Z2-7]{77}\z|} readdir $dh;
        closedir $dh;
    }
    my $result = _scrub_result();
    foreach my $name (@list) {
        my $path = "$dir/$name";
        if ( not -e $path ) { push $result->{'missing'}->@*, $name; next }
        my $digest = _scrub_bytes( $path, $name, $nonce );
        refuse('cannot read a blob during scrub') if not defined $digest;
        if ( defined $nonce ) {
            ## the answer is the digest : home compares two holders ##
            $result->{'ok'}++;
            $result->{'answer'}{$name} = $digest;
        } elsif ( $digest eq $name ) {
            $result->{'ok'}++;
        } else {
            push $result->{'bad'}->@*, $name;
        }
    }
    return $result;
}

sub _scrub_parse {
    my $out    = shift // '';
    my $result = _scrub_result();
    foreach my $line ( split m|\n|, $out ) {
        my ( $state, $name, $digest ) = split ' ', $line;
        if    ( $state eq qw| ok | ) { $result->{'ok'}++ }
        elsif ( $state eq qw| ans | ) {
            $result->{'ok'}++;
            $result->{'answer'}{$name} = $digest;
        } elsif ( $state eq qw| bad | ) {
            push $result->{'bad'}->@*, $name;
        } elsif ( $state eq qw| missing | ) {
            push $result->{'missing'}->@*, $name;
        }
    }
    return $result;
}

sub _scrub_clean {
    my $result = shift;
    $result->{'clean'}
        = $result->{'bad'}->@* || $result->{'missing'}->@* ? 0 : 1;
    return $result;
}

sub holder_scrub {
    my ( $spec, $names, $nonce ) = @_;
    my $h = holder_parse($spec);
    refuse('scrub nonce is invalid')
        if defined $nonce
        and $nonce !~ m|\A[A-Z2-7]{1,64}\z|;
    my @names = @{ $names // [] };
    refuse('invalid blob name')
        if grep { $ARG !~ m|\A[A-Z2-7]{77}\z| } @names;
    return _scrub_clean( _scrub_dir( $h->{'dir'}, \@names, $nonce ) )
        if $h->{'type'} eq qw| local |;
    ## ssh : the restricted receiver answers scrub -- read-only, keyless ##
    my @delays = _delays();
    my $result = _scrub_result();
    ## keep every command line short ##
    for ( my $i = 0; $i < @names or $i == 0; $i += 400 ) {
        my @part
            = @names[ $i .. ( $i + 399 < $#names ? $i + 399 : $#names ) ];
        my $request = join ' ', qw| scrub |,
            ( defined $nonce ? ( '-nonce', $nonce ) : () ), @part;
        my ( $status, $out, $err );
        for my $try ( 0 .. $#delays ) {
            ( $status, $out, $err ) = _ssh( $h, $request );
            last                if not $status or $status == 7;
            sleep $delays[$try] if $try < $#delays;
        }
        ## 7 is the answer too [ corruption or absence ], not a failure ##
        refuse( 'holder scrub failed : %s', $err )
            if $status and $status != 7;
        my $part_result = _scrub_parse($out);
        $result->{'ok'} += $part_result->{'ok'};
        push $result->{'bad'}->@*,     $part_result->{'bad'}->@*;
        push $result->{'missing'}->@*, $part_result->{'missing'}->@*;
        $result->{'answer'}{$ARG} = $part_result->{'answer'}{$ARG}
            foreach keys $part_result->{'answer'}->%*;
    }
    return _scrub_clean($result);
}

sub holder_put {
    my ( $spec, $local, $name, $kind, $replace ) = @_;
    my $h = holder_parse($spec);
    if ( $h->{'type'} eq qw| local | ) {
        my $final = _path( $h, $name );
        refuse('holder destination exists') if -e $final and not $replace;
        unlink $final                       if $replace  and -e $final;
        link $local, $final or refuse('cannot publish local holder blob');
        ## the directory entry must survive a crash as well ##
        sync_dir( $h->{'dir'} );
        return;
    }
    my $size = -s $local;
    if (    not $replace
        and defined holder_size( $spec, $name )
        and holder_size( $spec, $name ) == $size ) {
        holder_verify( $spec, $name, $local, $kind );
        return;
    }
    refuse( 'holder final blob has the wrong size : %s', $name )
        if defined holder_size( $spec, $name )
        and not $replace;
    my $temp = "$name.upload";
    holder_delete( $spec, $temp ) if $kind ne qw| content |;
    my @delays = _delays();
    my $status = 1;
    for my $try ( 0 .. $#delays ) {
        my $have = holder_size( $spec, $temp ) // 0;
        refuse( 'holder temporary is larger than source : %s', $temp )
            if $have > $size;
        open( my $in, '<:raw', $local ) or refuse('cannot read upload spool');
        seek $in, $have, 0;
        ($status) = _ssh( $h, 'cat >> ' . _quote( _path( $h, $temp ) ), $in );
        close $in;
        last                if not $status;
        sleep $delays[$try] if $try < $#delays;
    }
    refuse( 'ssh upload failed after retries for %s', $temp ) if $status;
    refuse( 'holder upload size mismatch for %s',     $temp )
        if ( holder_size( $spec, $temp ) // -1 ) != $size;
    holder_verify( $spec, $temp, $local, $kind );
    my ( $sync_status, undef, $sync_err )
        = _ssh( $h, 'sync ' . _quote( _path( $h, $temp ) ) );
    warn "n7fs : remote sync unavailable : $sync_err" if $sync_status;
    _retry( $h,
              'mv -f -- '
            . _quote( _path( $h, $temp ) ) . ' '
            . _quote( _path( $h, $name ) ) );
    ## renaming leaves the directory entry unsynced : persist it too ##
    my ( $dir_status, undef, $dir_err )
        = _ssh( $h, 'sync -- ' . _quote( $h->{'dir'} ) );
    warn "n7fs : remote directory sync unavailable : $dir_err" if $dir_status;
    return;
}

1;

#,,,,,,..,,..,,,.,.,.,.,,,,..,...,...,,,,,,,.,..,,...,...,.,.,...,,,,,.,.,...,
#QIXYBHGLQGHBHWHXI7J62ASTIIVGARBZ5O4UMNYZRXQXVSEIUOWXNKXRZYB3ORFY2ZLURLJE4CGO6
#\\\|VQ3YS3MZC5QINU4RA446DDEXDFV5JVVQBNP5IW2KBATIFMLUUTT \ / AMOS7 \ YOURUM ::
#\[7]2R5737EVDLQK76QTSALREQ7ND5JFMTHHBAV65AANM5CTQNTZMUDQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
