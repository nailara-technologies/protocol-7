#!/usr/bin/perl
## Wire-level end-to-end test harness for src/storage.9p.* ##
##
## Loads the real module sources from src/, applies the Protocol-7 source
## conventions textually ( <[mod]>->(...) => $code{mod}->(...),
## <plan-9.protocol.constants.X> => P9C('X'), @ARG => @_ ), and runs them
## against a REAL, deliberately STRICT 9P2000 server (separate process,
## real TCP socket) :
##   - Twalk from an open fid     => Rerror  (9P2000 forbids it)
##   - Topen of an open fid       => Rerror
##   - Tread of a non-open fid    => Rerror
##   - Ropen reports iounit = 0   ( exercises client-side fallback )
##   - Rstat uses the double-size-prefix quirk

use strict;
use warnings;
use IO::Socket::INET;
$| = 1;

our %data;
our %code;

my $SRC  = '/data/projects/protocol-7/src';
my $PORT = 15641;

## --- constants -----------------------------------------------------------

my %CONST = (
    Tversion => 100,
    Rversion => 101,
    Tattach  => 104,
    Rattach  => 105,
    Rerror   => 107,
    Twalk    => 110,
    Rwalk    => 111,
    Topen    => 112,
    Ropen    => 113,
    Tread    => 116,
    Rread    => 117,
    Tclunk   => 120,
    Rclunk   => 121,
    Tstat    => 124,
    Rstat    => 125,
    DMDIR    => 0x80000000,
    QTDIR    => 0x80,
    QTFILE   => 0x00,
);
sub P9C { return $CONST{ +shift } // die "unknown constant $_[0]" }

## --- codec primitives ( independently re-implemented for the harness ) ---

%code = (
    'plan-9.protocol.codec.encode-uint8'  => sub { pack( 'C',  $_[0] ) },
    'plan-9.protocol.codec.encode-uint16' => sub { pack( 'v',  $_[0] ) },
    'plan-9.protocol.codec.encode-uint32' => sub { pack( 'V',  $_[0] ) },
    'plan-9.protocol.codec.encode-uint64' => sub { pack( 'Q<', $_[0] ) },
    'plan-9.protocol.codec.decode-uint8'  => sub { unpack( 'C',  $_[0] ) },
    'plan-9.protocol.codec.decode-uint16' => sub { unpack( 'v',  $_[0] ) },
    'plan-9.protocol.codec.decode-uint32' => sub { unpack( 'V',  $_[0] ) },
    'plan-9.protocol.codec.decode-uint64' => sub { unpack( 'Q<', $_[0] ) },
    'plan-9.protocol.codec.encode-string' => sub {
        my $s = shift // '';
        return pack( 'v', length $s ) . $s;
    },
    'plan-9.protocol.codec.decode-string' => sub {
        my $len = unpack( 'v', substr( $_[0], 0, 2 ) );
        return ( substr( $_[0], 2, $len ), substr( $_[0], 2 + $len ) );
    },
    'plan-9.protocol.codec.encode-qid' => sub {
        my ( $t, $v, $p ) = @_;
        return pack( 'C V Q<', $t, $v, $p );
    },
    'plan-9.protocol.codec.decode-qid' => sub {
        return unpack( 'C V Q<', $_[0] );
    },
    'plan-9.protocol.codec.encode-message' => sub {
        my ( $type, $tag, $body ) = @_;
        return pack( 'V C v', 7 + length($body), $type, $tag ) . $body;
    },
    'plan-9.protocol.codec.encode-stat' => sub {
        my ($s) = @_;
        my $enc
            = pack( 'v', 0 )
            . pack( 'v', $s->{type} // 0 )
            . pack( 'V', $s->{dev}  // 0 )
            . $code{'plan-9.protocol.codec.encode-qid'}
            ->( $s->{qid_type}, $s->{qid_version}, $s->{qid_path} )
            . pack( 'V',  $s->{mode}   // 0644 )
            . pack( 'V',  $s->{atime}  // 0 )
            . pack( 'V',  $s->{mtime}  // 0 )
            . pack( 'Q<', $s->{length} // 0 )
            . $code{'plan-9.protocol.codec.encode-string'}->( $s->{name} )
            . $code{'plan-9.protocol.codec.encode-string'}
            ->( $s->{uid} // 'root' )
            . $code{'plan-9.protocol.codec.encode-string'}
            ->( $s->{gid} // 'root' )
            . $code{'plan-9.protocol.codec.encode-string'}
            ->( $s->{muid} // 'root' );
        substr( $enc, 0, 2 ) = pack( 'v', length($enc) - 2 );
        return $enc;
    },
    'base.logs'  => sub { print "  [log] @_\n"; return 1 },
    'base.ntime' => sub { return time },
);

## --- module loader --------------------------------------------------------

sub load_mod {
    my ($name) = @_;
    open( my $fh, '<', "$SRC/$name" ) or die "cannot read $name : $!";
    my $src = do { local $/; <$fh> };
    close $fh;
    $src =~ s/\n#,.*\z//s;    ## strip AMOS7 signature trailer
    $src =~ s/<plan-9\.protocol\.constants\.(\w+)>/P9C('$1')/g;
    $src =~ s/<\[([\w.\-]+)\]>/\$code{'$1'}/g;
    $src =~ s/\@ARG/\@_/g;
    my $cref = eval "sub { $src }";
    die "compile error in $name : $@" if $@;
    $code{$name} = $cref;
    return;
}

for my $m (
    qw|
    storage.9p.connect   storage.9p.version  storage.9p.attach
    storage.9p.walk      storage.9p.open     storage.9p.readdir
    storage.9p.stat      storage.9p.clunk    storage.9p.read-message
    storage.9p.scan      storage.9p.filter-check
    storage.9p.mount     storage.9p.umount
    |
) {
    load_mod($m);
}
print "modules loaded OK\n";

## --- strict 9P2000 test server --------------------------------------------

my %FS = (
    '/' => {
        type    => 'dir',
        entries => [ 'docs', 'file1.txt', 'file2.tmp' ],
    },
    '/docs' => {
        type    => 'dir',
        entries => [ 'report-2024.pdf', 'notes.md' ],
    },
    '/file1.txt' => { type => 'file', content => "hello protocol-7\n" },
    '/file2.tmp' => { type => 'file', content => "temporary\n" },
    '/docs/report-2024.pdf' =>
        { type => 'file', content => "%PDF-fake\n" x 500 },
    '/docs/notes.md' => { type => 'file', content => "# notes\n" },
);

my $listen = IO::Socket::INET->new(
    LocalAddr => '127.0.0.1',
    LocalPort => $PORT,
    Proto     => 'tcp',
    Listen    => 5,
    ReuseAddr => 1,
) or die "listen: $!";

my $pid = fork();
die "fork failed" unless defined $pid;

if ( $pid == 0 ) {    ## server process
    $SIG{CHLD} = 'IGNORE';
    while ( my $client = $listen->accept() ) {
        my $cpid = fork();
        next if not defined $cpid;
        if ( $cpid != 0 ) { close $client; next; }    ## parent: next accept
        close $listen;
        my %fids;
        my $next_qid = 1;
        my %qid_for  = map { $_ => $next_qid++ } sort keys %FS;
        my $msize    = 8192;

        while (1) {
            my $hdr = '';
            while ( length($hdr) < 4 ) {
                my $n = sysread( $client, my $b, 4 - length($hdr) );
                last if !$n;
                $hdr .= $b;
            }
            last if length($hdr) < 4;
            my $size = unpack( 'V', $hdr );
            my $body = '';
            while ( length($body) < $size - 4 ) {
                my $n = sysread( $client, my $b, $size - 4 - length($body) );
                last if !$n;
                $body .= $b;
            }
            last if length($body) < $size - 4;

            my ( $type, $tag ) = unpack( 'C v', substr( $body, 0, 3 ) );
            my $data = substr( $body, 3 );

            my $error = sub {
                my ($msg) = @_;
                my $r = $code{'plan-9.protocol.codec.encode-string'}->($msg);
                my $m = $code{'plan-9.protocol.codec.encode-message'}
                    ->( $CONST{Rerror}, $tag, $r );
                syswrite( $client, $m );
            };
            my $reply = sub {
                my ( $rtype, $rdata ) = @_;
                my $m = $code{'plan-9.protocol.codec.encode-message'}
                    ->( $rtype, $tag, $rdata );
                syswrite( $client, $m );
            };
            my $stat_rec = sub {
                my ( $path, $name ) = @_;
                my $e = $FS{$path};
                return $code{'plan-9.protocol.codec.encode-stat'}->(
                    {   type     => 0,
                        dev      => 0,
                        qid_type => $e->{type} eq 'dir' ? $CONST{QTDIR}
                        : $CONST{QTFILE},
                        qid_version => 0,
                        qid_path    => $qid_for{$path},
                        mode => $e->{type} eq 'dir' ? ( 0755 | $CONST{DMDIR} )
                        : 0644,
                        atime  => 1700000000,
                        mtime  => 1700000000,
                        length => $e->{type} eq 'dir' ? 0
                        : length( $e->{content} ),
                        name => $name,
                        uid  => 'root',
                        gid  => 'root',
                        muid => 'root',
                    }
                );
            };
            my $qid_of = sub {
                my ($path) = @_;
                my $e = $FS{$path};
                return $code{'plan-9.protocol.codec.encode-qid'}->(
                    $e->{type} eq 'dir' ? $CONST{QTDIR} : $CONST{QTFILE},
                    0, $qid_for{$path}
                );
            };

            if ( $type == $CONST{Tversion} ) {
                my $c_msize = unpack( 'V', substr( $data, 0, 4 ) );
                $msize = $c_msize < $msize ? $c_msize : $msize;
                $reply->(
                    $CONST{Rversion},
                    pack( 'V', $msize )
                        . $code{'plan-9.protocol.codec.encode-string'}
                        ->('9P2000')
                );
                %fids = ();
            } elsif ( $type == $CONST{Tattach} ) {
                my $fid = unpack( 'V', substr( $data, 0, 4 ) );
                $fids{$fid} = { path => '/', open => 0 };
                $reply->( $CONST{Rattach}, $qid_of->('/') );
            } elsif ( $type == $CONST{Twalk} ) {
                my ( $fid, $newfid, $nw ) = unpack( 'V V v', $data );
                my $rest = substr( $data, 10 );
                my @names;
                for ( 1 .. $nw ) {
                    my $l = unpack( 'v', substr( $rest, 0, 2 ) );
                    push @names, substr( $rest, 2, $l );
                    $rest = substr( $rest, 2 + $l );
                }
                if ( not exists $fids{$fid} ) {
                    $error->('invalid fid');
                    next;
                }
                if ( $fids{$fid}{open} ) {
                    $error->('walk from open fid');    ## STRICT ##
                    next;
                }
                my $cur  = $fids{$fid}{path};
                my $qids = '';
                my $nq   = 0;
                my $ok   = 1;
                for my $n (@names) {
                    my $np = $cur eq '/' ? "/$n" : "$cur/$n";
                    if ( not exists $FS{$np}
                        or $FS{$cur}{type} ne 'dir' ) {
                        $ok = 0;
                        last;
                    }
                    $cur = $np;
                    $qids .= $qid_of->($cur);
                    $nq++;
                }
                if ( not $ok ) {
                    $error->('file not found');
                    next;
                }
                $fids{$newfid} = { path => $cur, open => 0 };
                $reply->( $CONST{Rwalk}, pack( 'v', $nq ) . $qids );
            } elsif ( $type == $CONST{Topen} ) {
                my ( $fid, $mode ) = unpack( 'V C', $data );
                if ( not exists $fids{$fid} ) {
                    $error->('invalid fid');
                    next;
                }
                if ( $fids{$fid}{open} ) {
                    $error->('fid already open');    ## STRICT ##
                    next;
                }
                $fids{$fid}{open} = 1;
                ## iounit = 0 : 'no preference' : exercises client fallback
                $reply->(
                    $CONST{Ropen},
                    $qid_of->( $fids{$fid}{path} ) . pack( 'V', 0 )
                );
            } elsif ( $type == $CONST{Tread} ) {
                my $fid = unpack( 'V',  substr( $data, 0,  4 ) );
                my $off = unpack( 'Q<', substr( $data, 4,  8 ) );
                my $cnt = unpack( 'V',  substr( $data, 12, 4 ) );
                if ( not exists $fids{$fid} ) {
                    $error->('invalid fid');
                    next;
                }
                if ( not $fids{$fid}{open} ) {
                    $error->('fid not open');    ## STRICT ##
                    next;
                }
                my $e = $FS{ $fids{$fid}{path} };
                my $blob;
                if ( $e->{type} eq 'dir' ) {
                    $fids{$fid}{dirblob} //= join(
                        '',
                        map {
                            $stat_rec->(
                                $fids{$fid}{path} eq '/'
                                ? "/$_"
                                : "$fids{$fid}{path}/$_",
                                $_
                            )
                        } @{ $e->{entries} }
                    );
                    $blob = $fids{$fid}{dirblob};
                } else {
                    $blob = $e->{content};
                }
                my $out = substr( $blob, $off, $cnt );
                $reply->( $CONST{Rread}, pack( 'V', length($out) ) . $out );
            } elsif ( $type == $CONST{Tstat} ) {
                my $fid = unpack( 'V', substr( $data, 0, 4 ) );
                if ( not exists $fids{$fid} ) {
                    $error->('invalid fid');
                    next;
                }
                my $p = $fids{$fid}{path};
                my ($base) = $p =~ m|/([^/]*)$|;
                $base = '/' if $p eq '/';
                my $rec = $stat_rec->( $p, $base );
                ## Rstat double-size-prefix quirk
                $reply->( $CONST{Rstat}, pack( 'v', length($rec) ) . $rec );
            } elsif ( $type == $CONST{Tclunk} ) {
                my $fid = unpack( 'V', substr( $data, 0, 4 ) );
                delete $fids{$fid};
                $reply->( $CONST{Rclunk}, '' );
            } else {
                $error->("unsupported message type $type");
            }
        }
        close $client;
        exit 0;    ## per-connection child exits
    }
    exit 0;
}

sleep 1;    ## let server listen

## --- client-side tests
## ------------------------------------------------------

my ( $pass, $fail ) = ( 0, 0 );

sub ok {
    my ( $cond, $label ) = @_;
    if   ($cond) { $pass++; print "ok   - $label\n"; }
    else         { $fail++; print "FAIL - $label\n"; }
    return $cond;
}

## 1. connect ( version + attach ) ##
my $res = $code{'storage.9p.connect'}
    ->( { host => '127.0.0.1', port => $PORT, name => 'test' } );
ok( $res->{mode} eq 'true', 'connect to strict 9P server' );
my $conn = $data{'storage'}{'9p'}{'connections'}{'test'};
ok( ref $conn && $conn->{msize} == 8192, 'version negotiated msize 8192' );
ok( $conn->{fids}{0}{qid}{type} == $CONST{QTDIR}, 'attach returned dir qid' );

## 2. walk to /docs ##
$res = $code{'storage.9p.walk'}->( $conn, 0, 100, 'docs' );
ok( $res->{mode} eq 'true', 'walk / -> docs' );

## 2b. walk to nonexistent path must fail ( not silently bind parent ) ##
$res = $code{'storage.9p.walk'}->( $conn, 0, 101, 'docs', 'nonexistent' );
ok( $res->{mode} eq 'false', 'partial walk detected as failure' );

## 3. readdir of root : strict server rejects walk-from-open-fid, so a ##
## successful stat below also proves readdir left the fid unopened     ##
$res = $code{'storage.9p.readdir'}->( $conn, 0 );
ok( $res->{mode} eq 'true', 'readdir / on strict server' );
my %root_entries = map { $_ => 1 } @{ $res->{data} };
ok( $root_entries{'docs'}
        && $root_entries{'file1.txt'}
        && $root_entries{'file2.tmp'}
        && keys(%root_entries) == 3,
    'readdir / entries exact [name offset fix verified on the wire]'
);

## 4. readdir of /docs via walked fid ##
$res = $code{'storage.9p.readdir'}->( $conn, 100 );
ok( $res->{mode} eq 'true', 'readdir /docs' );
my %docs_entries = map { $_ => 1 } @{ $res->{data} };
ok( $docs_entries{'report-2024.pdf'}
        && $docs_entries{'notes.md'}
        && keys(%docs_entries) == 2,
    'readdir /docs entries exact'
);
$code{'storage.9p.clunk'}->( $conn, 100 );

## 5. stat with name ( walk + stat + clunk ) ##
$res = $code{'storage.9p.stat'}->( $conn, 0, 'file1.txt' );
ok( $res->{mode} eq 'true'
        && $res->{data}{name} eq 'file1.txt'
        && $res->{data}{length} == length("hello protocol-7\n")
        && $res->{data}{uid} eq 'root',
    'stat /file1.txt fields'
);

## 6. full recursive scan of / ##
$res = $code{'storage.9p.scan'}->( { name => 'test', path => '/' } );
ok( $res->{mode} eq 'true', 'scan / recursive' );
my %scanned = map { $_->{path} => $_ } @{ $res->{data} };
ok( $scanned{'/docs'}
        && $scanned{'/docs/report-2024.pdf'}
        && $scanned{'/docs/notes.md'}
        && $scanned{'/file1.txt'}
        && $scanned{'/file2.tmp'},
    'scan / found all 5 entries ( recursion into subdir worked )'
);
ok( $scanned{'/docs'}{qid}{type} == $CONST{QTDIR}
        && $scanned{'/file1.txt'}{qid}{type} == $CONST{QTFILE},
    'scan qid types correct'
);

## 7. filtered scan : include only *.pdf ##
$res = $code{'storage.9p.scan'}
    ->( { name => 'test', path => '/', inclusion_add => [qr/\.pdf$/] } );
ok( @{ $res->{data} } == 1
        && $res->{data}[0]{path} eq '/docs/report-2024.pdf',
    'inclusion_add filter ( pdf only, still recursed into docs )'
);

## 8. exclusion scan : reject *.tmp ##
$res = $code{'storage.9p.scan'}
    ->( { name => 'test', path => '/', exclusion_add => [qr/\.tmp$/] } );
ok( !grep( { $_->{path} =~ /\.tmp$/ } @{ $res->{data} } ),
    'exclusion_add filter ( no tmp files )' );

## 9. AND filters ##
$res = $code{'storage.9p.scan'}->(
    {   name          => 'test',
        path          => '/',
        inclusion_and => [ qr/report/, qr/2024/ ],
    }
);
ok( @{ $res->{data} } == 1
        && $res->{data}[0]{path} eq '/docs/report-2024.pdf',
    'inclusion_and filter ( report AND 2024 )'
);

## 10. max_results cap ##
$res = $code{'storage.9p.scan'}
    ->( { name => 'test', path => '/', max_results => 2 } );
ok( @{ $res->{data} } == 2, 'max_results honored' );

## 11. no-recurse scan ##
$res = $code{'storage.9p.scan'}
    ->( { name => 'test', path => '/', recursive => 0 } );
ok( @{ $res->{data} } == 3, 'no-recurse scan lists top level only' );

## 12. scan of subpath directly ##
$res = $code{'storage.9p.scan'}->( { name => 'test', path => '/docs' } );
ok( @{ $res->{data} } == 2, 'scan /docs direct walk' );

## 13. storage.9p.mount adapter ##
my $mp = $code{'storage.9p.mount'}
    ->( { authority => "127.0.0.1:$PORT", path => '/docs' } );
ok( defined $mp && $mp eq '/docs', 'mount returns path' );
ok( exists $data{'storage'}{'9p'}{'connections'}{"127.0.0.1:$PORT"},
    'mount registered connection under authority string'
);

## scan via the authority-name connection ( pager.source.9p pattern ) ##
$res = $code{'storage.9p.scan'}
    ->( { name => "127.0.0.1:$PORT", path => '/docs' } );
ok( $res->{mode} eq 'true' && @{ $res->{data} } == 2,
    'scan via authority connection name' );

## 14. mount with bad path : undef + teardown ##
my $mp2 = $code{'storage.9p.mount'}
    ->( { authority => "127.0.0.1:$PORT", path => '/no/such/dir' } );
ok( !defined $mp2, 'mount of nonexistent path returns undef' );

## 15. mount without port : default 5640 must fail cleanly ( nothing ##
## listening there ) and return undef, not die                       ##
my $mp3 = $code{'storage.9p.mount'}
    ->( { authority => '127.0.0.1', path => '/docs' } );
ok( !defined $mp3, 'mount with default port refused cleanly' );

## 16. umount ##
$res = $code{'storage.9p.umount'}->( { mount_point => '/docs' } );
ok( $res->{mode} eq 'true', 'umount mode true' );
ok( !exists $data{'storage'}{'9p'}{'connections'}{"127.0.0.1:$PORT"},
    'umount removed connection entry' );
ok( !exists $data{'storage'}{'9p'}{'mounts'}{'/docs'},
    'umount removed mount entry' );
$res = $code{'storage.9p.scan'}
    ->( { name => "127.0.0.1:$PORT", path => '/docs' } );
ok( $res->{mode} eq 'false', 'scan after umount fails as not connected' );

## 17. umount by connection name fallback + error paths ##
$res = $code{'storage.9p.umount'}->( { mount_point => '/docs' } );
ok( $res->{mode} eq 'false', 'double umount reports not mounted' );
$res = $code{'storage.9p.umount'}->( { mount_point => 'test' } );
ok( $res->{mode} eq 'true', 'umount by connection name fallback' );
ok( !exists $data{'storage'}{'9p'}{'connections'}{'test'},
    'fallback umount removed connection' );

print "\n=== $pass passed, $fail failed ===\n";

kill 9, $pid;
waitpid( $pid, 0 );
exit( $fail ? 1 : 0 );

#,,,.,,,,,,..,...,.,,,,.,,,.,,...,,,,,,.,,...,..,,...,...,.,.,,..,...,,.,,...,
#X5S2S4I22NB5EDWCCUZQHJCTHRC7AAZVUXDVX5IMTQRVJJDKIOTGXFNVCZZSRIMARBBS3MO4I6DPY
#\\\|FYA3YXGSF4JEG2KNHVPGSUPK2DMAA5VSPSJNADJF6IGFHUYR5UT \ / AMOS7 \ YOURUM ::
#\[7]VGHR4YTG36LUW2K7FD3ZGKX3FOBY5NLXMAPPIIZVJBIUO4BGGQAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
