package AMOS7::NRT::journal;
our $VERSION = qw| AMOS7::NRT::journal-VERSION.Z5M3I4Q |;

use v5.32.0;
use strict;
use English;
use warnings;

use Exporter;
use base qw| Exporter |;
use vars qw| @EXPORT_OK |;

use Fcntl      qw| O_RDONLY O_WRONLY O_CREAT O_EXCL O_APPEND LOCK_EX |;
use File::Path qw| make_path |;
use Math::BigInt;
use AMOS7::N7FS::Sign          qw| verify |;
use AMOS7::cell::canon         qw| pack_head parse_head |;
use AMOS7::cell::canon::list   qw| pack_body |;
use AMOS7::NRT::drops          qw| bounded |;
use AMOS7::NRT::frame          qw| clock index |;
use AMOS7::NRT::journal::canon qw| kind body |;
use AMOS7::NRT::transaction;
use AMOS7::NRT::user::account qw| NETWORK |;

@EXPORT_OK = qw| refuse read_file lock init common replay verify_head commit
    recover |;

sub refuse {
    my $message = shift;
    $message = sprintf $message, @ARG if @ARG;
    die "nrt : $message\n";
}

sub read_file {
    my $path = shift;
    open( my $fh, '<:raw', $path ) or return undef;
    local $INPUT_RECORD_SEPARATOR;
    my $bytes = <$fh>;
    close $fh;
    return $bytes // '';
}

sub _write_all {
    my ( $fh, $bytes ) = @ARG;
    my $offset = 0;
    while ( $offset < length $bytes ) {
        my $written = syswrite $fh, $bytes, length($bytes) - $offset, $offset;
        refuse( 'write failed : %s', $OS_ERROR ) if not defined $written;
        refuse('write made no progress')         if $written == 0;
        $offset += $written;
    }
    $fh->sync or refuse( 'file sync failed : %s', $OS_ERROR );
    return;
}

sub _sync_dir {
    my $dir = shift;
    sysopen( my $dh, $dir, O_RDONLY )
        or refuse( 'cannot open directory %s : %s', $dir, $OS_ERROR );
    $dh->sync or refuse( 'directory sync failed : %s', $OS_ERROR );
    close $dh;
    return;
}

sub _publish {
    my ( $path, $bytes ) = @ARG;
    my $tmp = "$path.tmp.$$";
    sysopen( my $fh, $tmp, O_WRONLY | O_CREAT | O_EXCL, 0600 )
        or refuse( 'cannot create %s : %s', $tmp, $OS_ERROR );
    my $ok    = eval { _write_all( $fh, $bytes ); 1 };
    my $error = $EVAL_ERROR;
    close $fh;
    if ( not $ok ) {
        unlink $tmp;
        die $error;
    }
    rename $tmp, $path or do {
        my $reason = $OS_ERROR;
        unlink $tmp;
        refuse( 'cannot publish %s : %s', $path, $reason );
    };
    chmod 0600, $path;
    _sync_dir( ( $path =~ m|\A(.+)/[^/]+\z| ) ? $1 : q|.| );
    my $back = read_file($path);
    refuse( 'read back differs for %s', $path )
        if not defined $back or $back ne $bytes;
    return;
}

sub _new_file {
    my ( $path, $bytes ) = @ARG;
    refuse( 'file already exists [ %s ]', $path ) if -e $path or -l $path;
    sysopen( my $fh, $path, O_WRONLY | O_CREAT | O_EXCL, 0600 )
        or refuse( 'cannot create %s : %s', $path, $OS_ERROR );
    _write_all( $fh, $bytes );
    close $fh;
    return;
}

sub lock {
    my $dir = shift;
    sysopen( my $lock, "$dir/.lock", O_WRONLY | O_CREAT, 0600 )
        or refuse( 'cannot lock %s : %s', $dir, $OS_ERROR );
    flock( $lock, LOCK_EX ) or refuse('cannot take the ledger lock');
    chmod 0600, "$dir/.lock";
    return $lock;
}

sub _empty_state {
    my $dir     = shift;
    my $network = NETWORK();
    return {
        dir         => $dir,
        ledger      => undef,
        witness     => undef,
        frame_level => undef,
        seq         => '0',
        last        => '0',
        ntime       => undef,
        accounts    => {},
        addresses   => {},
        balances    => { $network => '0' },
        used        => { $network => '0' },
        supply      => '0',
        records     => [],
    };
}

sub _kind_of {
    my $bytes = shift;
    my ($name) = $bytes =~ m|\Ap7 nrt ([a-z][a-z0-9-]*) v1\n|;
    refuse('missing or changed label line') if not defined $name;
    return $name;
}

sub _decode {
    my ( $bytes, $expected_kind ) = @ARG;
    my $name = _kind_of($bytes);
    refuse('record kind differs from its container')
        if defined $expected_kind and $name ne $expected_kind;
    my $parsed = parse_head( $bytes, kind($name), verify => \&verify );
    refuse('record has trailing bytes')
        if $name ne qw| transaction | and length $parsed->{'body_bytes'};
    my ( $record_body, $rows ) = ( q||, undef );
    if ( $name eq qw| transaction | ) {
        $record_body = $parsed->{'body_bytes'};
        my $list = AMOS7::cell::canon::list->new(
            body(), $record_body,
            rows => $parsed->{'values'}{'rows'},
            body => $parsed->{'values'}{'body'},
        );
        $list->validate;
        refuse('body does not pack to the stored bytes')
            if pack_body( body(), $list->rows ) ne $record_body;
        $rows = [ map { $list->row($ARG) } 0 .. $list->count - 1 ];
    }
    refuse('head does not pack to the stored bytes')
        if pack_head( kind($name), $parsed->{'values'} ) ne
        $parsed->{'head_bytes'};
    return {
        kind    => $name,
        values  => $parsed->{'values'},
        head    => $parsed->{'head_bytes'},
        body    => $record_body,
        rows    => $rows,
        bytes   => $parsed->{'head_bytes'} . $record_body,
        address => $parsed->{'address'},
    };
}

sub _next {
    my $remaining = shift;
    my $name      = _kind_of($remaining);
    my $parsed    = parse_head( $remaining, kind($name), verify => \&verify );
    my $length    = length $parsed->{'head_bytes'};
    if ( $name eq qw| transaction | ) {
        my $rows  = $parsed->{'values'}{'rows'};
        my $body  = $parsed->{'body_bytes'};
        my $start = 0;
        for ( 1 .. $rows ) {
            my $end = CORE::index( $body, "\n", $start );
            refuse('torn transaction body') if $end < 0;
            $start = $end + 1;
        }
        $length += $start;
    }
    return _decode( substr( $remaining, 0, $length ), $name );
}

sub _same_count {
    my ( $left, $right ) = @ARG;
    return Math::BigInt->new($left)->bcmp( Math::BigInt->new($right) ) == 0;
}

sub _zero_sum {
    my $state = shift;
    my $sum   = Math::BigInt->bzero;
    $sum->badd( Math::BigInt->new($ARG) ) for values $state->{'balances'}->%*;
    refuse('balance sum is not zero') if not $sum->is_zero;
    my $network = Math::BigInt->new( $state->{'balances'}{ NETWORK() } );
    refuse('supply differs from the network account')
        if $network->copy->babs->bcmp(
        Math::BigInt->new( $state->{'supply'} ) ) != 0;
    bounded( $network, 1 );
    return;
}

sub _accept {
    my ( $state, $record ) = @ARG;
    my $name   = $record->{'kind'};
    my $values = $record->{'values'};
    refuse('head is not a journal record') if $name eq qw| head |;
    refuse('first journal record is not init')
        if $state->{'seq'} eq '0' and $name ne qw| init |;
    refuse('a second init record is not allowed')
        if $state->{'seq'} ne '0' and $name eq qw| init |;

    my $expected_seq = Math::BigInt->new( $state->{'seq'} )->badd(1);
    refuse( 'wrong seq [ expected %s, got %s ]',
        $expected_seq->bstr, $values->{'seq'} )
        if not _same_count( $values->{'seq'}, $expected_seq );
    refuse('wrong prev address') if $values->{'prev'} ne $state->{'last'};
    refuse('ledger id differs from init')
        if defined $state->{'ledger'}
        and $values->{'ledger'} ne $state->{'ledger'};
    refuse('ntime is below the record before it')
        if defined $state->{'ntime'}
        and $values->{'ntime'} lt $state->{'ntime'};
    refuse('stage 1a accepts only committed pass = 0 records')
        if $values->{'pass'} ne '0';

    my $level
        = $name eq qw| init |
        ? $values->{'frame-level'}
        : $state->{'frame_level'};
    refuse('frame does not match AMOS7::cell::time::frame')
        if $values->{'frame'} ne index( $values->{'ntime'}, $level );

    if ( $name eq qw| init | ) {
        refuse('init witness differs from stored pub')
            if $values->{'witness'} ne $values->{'pub'};
        $state->{'ledger'}      = $values->{'ledger'};
        $state->{'witness'}     = $values->{'witness'};
        $state->{'frame_level'} = $level;
    } elsif ( $name eq qw| account | ) {
        AMOS7::NRT::user::account::apply( $state, $record );
    } elsif ( $name eq qw| transaction | ) {
        AMOS7::NRT::transaction::apply( $state, $record, $record->{'rows'} );
    } elsif ( $name eq qw| void | ) {
        refuse('void is not signed by the witness')
            if $values->{'pub'} ne $state->{'witness'};
    } else {
        refuse( 'unsupported journal kind [ %s ]', $name );
    }

    $state->{'seq'}   = $values->{'seq'};
    $state->{'last'}  = $record->{'address'};
    $state->{'ntime'} = $values->{'ntime'};
    push $state->{'records'}->@*, $record;
    _zero_sum($state);
    return $record;
}

sub _fragment {
    my $remaining = shift;
    my $close     = CORE::index( $remaining, "\n\n" );
    return 1 if $close < 0;
    my $name = eval { _kind_of($remaining) };
    return 0 if not defined $name or $name ne qw| transaction |;
    my $head = substr( $remaining, 0, $close + 2 );
    my ($rows) = $head =~ m|^rows += ([0-9]+)\n|m;
    return 0 if not defined $rows;
    my $tail  = substr( $remaining, $close + 2 );
    my $count = () = $tail =~ m|\n|g;
    return $count < $rows ? 1 : 0;
}

sub _scan {
    my ( $dir, $allow_torn ) = @ARG;
    my $path  = "$dir/journal";
    my $bytes = read_file($path);
    refuse( 'missing journal [ %s ]', $path ) if not defined $bytes;
    refuse('empty journal')                   if not length $bytes;
    my $state  = _empty_state($dir);
    my $offset = 0;
    my $torn;

    while ( $offset < length $bytes ) {
        my $remaining = substr( $bytes, $offset );
        my $seq       = Math::BigInt->new( $state->{'seq'} )->badd(1)->bstr;
        my $record    = eval { _next($remaining) };
        if ( not $record ) {
            my $error = $EVAL_ERROR;
            if ( $allow_torn and _fragment($remaining) ) {
                $torn = $offset;
                last;
            }
            chomp $error;
            die "nrt : seq $seq : $error\n";
        }
        eval { _accept( $state, $record ) };
        if ($EVAL_ERROR) {
            my $error = $EVAL_ERROR;
            chomp $error;
            die "nrt : seq $seq : $error\n";
        }
        $offset += length $record->{'bytes'};
    }
    $state->{'torn_offset'} = $torn;
    $state->{'torn_bytes'}  = defined $torn ? substr( $bytes, $torn ) : q||;
    return $state;
}

sub replay {
    my ( $dir, %opt ) = @ARG;
    return _scan( $dir, $opt{'allow_torn'} );
}

sub common {
    my ( $state, %opt ) = @ARG;
    my $ntime
        = clock( $state->{'ntime'}, accept_clock => $opt{'accept_clock'} );
    my $level = $opt{'frame_level'} // $state->{'frame_level'};
    return {
        ledger => $state->{'ledger'} // $opt{'ledger'},
        seq    => Math::BigInt->new( $state->{'seq'} )->badd(1)->bstr,
        prev   => $state->{'last'},
        ntime  => $ntime,
        frame  => index( $ntime, $level ),
        pass   => '0',
    };
}

sub _read_head {
    my ( $dir, $state ) = @ARG;
    my $path  = "$dir/head";
    my $bytes = read_file($path);
    return undef if not defined $bytes;
    my $parsed
        = eval { parse_head( $bytes, kind(qw| head |), verify => \&verify ); };
    if ( not $parsed ) {
        my $error = $EVAL_ERROR;
        chomp $error;
        refuse( 'head seq %s : %s', $state->{'seq'}, $error );
    }
    refuse('head has trailing bytes') if length $parsed->{'body_bytes'};
    refuse('head does not pack to the stored bytes')
        if pack_head( kind(qw| head |), $parsed->{'values'} ) ne $bytes;
    my $values = $parsed->{'values'};
    refuse( 'head seq %s : head is for another ledger', $values->{'seq'} )
        if $values->{'ledger'} ne $state->{'ledger'};
    refuse( 'head seq %s : not signed by the witness', $values->{'seq'} )
        if $values->{'pub'} ne $state->{'witness'};
    return $parsed;
}

sub verify_head {
    my ( $dir, $state ) = @ARG;
    my $head = _read_head( $dir, $state );
    refuse( 'head seq %s : missing head [ rebuild with recover -witness ]',
        $state->{'seq'} )
        if not defined $head;
    my $values = $head->{'values'};
    refuse( 'head seq %s differs from journal seq %s',
        $values->{'seq'}, $state->{'seq'} )
        if not _same_count( $values->{'seq'}, $state->{'seq'} );
    refuse('head last differs from the journal record address')
        if $values->{'last'} ne $state->{'last'};
    refuse('head ntime differs from the last journal record')
        if $values->{'ntime'} ne $state->{'ntime'};
    return $head;
}

sub _head_bytes {
    my ( $state, $signer ) = @ARG;
    refuse('head rebuild requires the witness key')
        if $signer->public ne $state->{'witness'};
    return pack_head(
        kind(qw| head |),
        {   ledger => $state->{'ledger'},
            seq    => $state->{'seq'},
            last   => $state->{'last'},
            ntime  => $state->{'ntime'},
        },
        signer => $signer,
    );
}

sub _write_head {
    my ( $dir, $state, $signer ) = @ARG;
    _publish( "$dir/head", _head_bytes( $state, $signer ) );
    return;
}

sub _append {
    my ( $dir, $bytes ) = @ARG;
    sysopen( my $fh, "$dir/journal", O_WRONLY | O_CREAT | O_APPEND, 0600 )
        or refuse( 'cannot append journal : %s', $OS_ERROR );
    _write_all( $fh, $bytes );
    close $fh;
    chmod 0600, "$dir/journal";
    _sync_dir($dir);
    return;
}

sub commit {
    my ( $dir, $state, $name, $values, $signer, $record_body, $head_signer )
        = @_;
    $record_body //= q||;
    $head_signer //= $signer;
    my $bytes
        = pack_head( kind($name), $values, signer => $signer ) . $record_body;
    my $record = eval { _decode( $bytes, $name ) };
    die $EVAL_ERROR if not $record;
    eval { _accept( $state, $record ) };
    die $EVAL_ERROR if $EVAL_ERROR;
    _append( $dir, $bytes );
    _write_head( $dir, $state, $head_signer );
    return $record;
}

sub init {
    my ( $dir, $signer, %opt ) = @ARG;
    refuse('ledger directory already has state')
        if -e "$dir/journal" or -e "$dir/head";
    if ( not -d $dir ) {
        make_path( $dir, { mode => 0700 } );
    }
    chmod 0700, $dir;
    my $lock = lock($dir);
    refuse('ledger directory already has state')
        if -e "$dir/journal" or -e "$dir/head";
    my $state = _empty_state($dir);
    my $level = $opt{'frame_level'} // 3;
    refuse('frame level is not 0 .. 7') if $level !~ m|\A[0-7]\z|;
    my $values = common(
        $state,
        ledger       => $opt{'ledger'},
        frame_level  => $level,
        accept_clock => $opt{'accept_clock'},
    );
    refuse('missing ledger id') if not defined $values->{'ledger'};
    @{$values}{qw| witness frame-level |} = ( $signer->public, $level );
    my $record = commit( $dir, $state, qw| init |, $values, $signer );
    _new_file( "$dir/.witness-key", $opt{'witness_path'} . "\n" )
        if defined $opt{'witness_path'};
    verify_head( $dir, $state );
    return ( $state, $record, $lock );
}

sub _truncate {
    my ( $path, $length ) = @ARG;
    sysopen( my $fh, $path, O_WRONLY )
        or refuse( 'cannot open journal for torn recovery : %s', $OS_ERROR );
    truncate( $fh, $length ) or refuse('cannot remove the torn fragment');
    $fh->sync or refuse( 'journal sync failed : %s', $OS_ERROR );
    close $fh;
    _sync_dir( ( $path =~ m|\A(.+)/[^/]+\z| ) ? $1 : q|.| );
    return;
}

sub recover {
    my ( $dir, %opt ) = @ARG;
    my $lock  = lock($dir);
    my $state = replay( $dir, allow_torn => 1 );
    my $head  = _read_head( $dir, $state );
    if ( defined $head ) {
        refuse('journal has fewer whole records than its head names')
            if Math::BigInt->new( $head->{'values'}{'seq'} )
            ->bcmp( Math::BigInt->new( $state->{'seq'} ) ) > 0;
        if ( _same_count( $head->{'values'}{'seq'}, $state->{'seq'} ) ) {
            refuse('head last differs from the journal record address')
                if $head->{'values'}{'last'} ne $state->{'last'};
        }
    }
    my $needs_head = (
        ( not defined $head )
            or not _same_count( $head->{'values'}{'seq'}, $state->{'seq'} )
    );
    refuse('missing or old head requires recover -witness')
        if $needs_head and not defined $opt{'witness'};

    my %result = (
        state => $state,
        torn  => undef,
        void  => undef,
        head  => 0
    );
    if ( defined $state->{'torn_offset'} ) {
        my $torn_dir = "$dir/torn";
        make_path( $torn_dir, { mode => 0700 } ) if not -d $torn_dir;
        chmod 0700, $torn_dir;
        my $base   = sprintf '%s-%s', $state->{'ntime'}, $state->{'seq'};
        my $path   = "$torn_dir/$base";
        my $suffix = 0;
        $path = "$torn_dir/$base." . ++$suffix while -e $path;
        _new_file( $path, $state->{'torn_bytes'} );
        _truncate( "$dir/journal", $state->{'torn_offset'} );
        $result{'torn'} = $path;
        delete @{$state}{qw| torn_offset torn_bytes |};
    }
    if ( defined $opt{'witness'} ) {
        my $values = common( $state, accept_clock => $opt{'accept_clock'} );
        $result{'void'}
            = commit( $dir, $state, qw| void |, $values, $opt{'witness'} );
        $result{'head'} = 1;
    } elsif ($needs_head) {
        _write_head( $dir, $state, $opt{'witness'} );
        $result{'head'} = 1;
    }
    verify_head( $dir, $state );
    $result{'lock'} = $lock;
    return \%result;
}

1;

#,,,,,,.,,.,,,,.,,.,,,,,,,...,.,,,..,,.,,,,,.,..,,...,...,.,.,,,,,,.,,,..,...,
#TD33DMFLNA3UMI2JITATNO7MHWZJM6ASFPYFIFCK7SXP2PF7LF4AVZVJ7FPVSPLFH2JURZIMTXX72
#\\\|366LH63ULMO26Q57YBKOA2DQRFUN5NTHIKZB5VWJ2VFOW4DBCCH \ / AMOS7 \ YOURUM ::
#\[7]WAC726ZARQSFD3BUWREJUTNNKGOVBO2U2VBOLP3VU74CJHVR4MCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
