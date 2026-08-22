#!/usr/bin/perl
## Harness 2 : REAL src/storage.9p.* client modules against the REAL
## src/plan-9.server.* handler modules ( the same code the plan-9 zenka runs
## ), communicating over a real TCP socket. Cross-validates the client against
## an independent implementation of the 9P2000 server side.

use strict;
use warnings;
use IO::Socket::INET;
$| = 1;

our %data;
our %code;

my $SRC  = '/data/projects/protocol-7/src';
my $PORT = 15640;

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
    Twrite   => 118,
    Rwrite   => 119,
    Tclunk   => 120,
    Rclunk   => 121,
    Tstat    => 124,
    Rstat    => 125,
    DMDIR    => 0x80000000,
    QTDIR    => 0x80,
    QTFILE   => 0x00,
);
sub P9C { return $CONST{ +shift } // die "unknown constant $_[0]" }

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
    'plan-9.protocol.codec.decode-qid' => sub { unpack( 'C V Q<', $_[0] ) },
    'plan-9.protocol.codec.encode-message' => sub {
        my ( $type, $tag, $body ) = @_;
        return pack( 'V C v', 7 + length($body), $type, $tag ) . $body;
    },
    'base.logs'  => sub { print "  [log] @_\n"; return 1 },
    'base.ntime' => sub { return time },
);

sub load_mod {
    my ($name) = @_;
    open( my $fh, '<', "$SRC/$name" ) or die "cannot read $name : $!";
    my $src = do { local $/; <$fh> };
    close $fh;
    $src =~ s/\n#,.*\z//s;
    $src =~ s/<plan-9\.protocol\.constants\.(\w+)>/P9C('$1')/g;
    $src =~ s/<\[([\w.\-]+)\]>/\$code{'$1'}/g;
    $src =~ s/\@ARG/\@_/g;
    my $cref = eval "sub { $src }";
    die "compile error in $name : $@" if $@;
    $code{$name} = $cref;
    return;
}

## real client modules ##
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

## real server modules ##
for my $m (
    qw|
    plan-9.protocol.error
    plan-9.protocol.codec.encode-stat
    plan-9.server.handle_version   plan-9.server.handle_attach
    plan-9.server.handle_walk      plan-9.server.handle_request
    plan-9.server.handle-io-open   plan-9.server.handle-io-read
    plan-9.server.handle-io-stat   plan-9.server.handle-io-clunk
    plan-9.server.buffer-stat
    plan-9.server.buffer-read-root-dir
    plan-9.server.buffer-read-buffer-dir
    plan-9.server.buffer-read-layer
    plan-9.server.buffer-read-metadata
    plan-9.server.export_buffer
    |
) {
    load_mod($m);
}
print "modules loaded OK [ client + real plan-9 server handlers ]\n";

## export two fake amos-term buffers via the real export_buffer ##
my $mk_window = sub {
    my ($sid) = @_;
    return {
        session_id => $sid,
        created    => time - 3600,
        buffer     => {
            width      => 80,
            height     => 24,
            depth      => 13,
            layer_size => 64,
            layers     => [ map {"layer-$_ content of $sid\n"} 0 .. 12 ],
        },
    };
};
$code{'plan-9.server.export_buffer'}->( $mk_window->('AAA'), 'term-alpha' );
$code{'plan-9.server.export_buffer'}->( $mk_window->('BBB'), 'term-beta' );
print "exported buffers : term-alpha, term-beta\n";

## server loop## server loop : real handlers, one forked child per ##
## connection                                                      ##
my $listen = IO::Socket::INET->new(
    LocalAddr => '127.0.0.1',
    LocalPort => $PORT,
    Proto     => 'tcp',
    Listen    => 5,
    ReuseAddr => 1,
) or die "listen: $!";

my $pid = fork();
die "fork failed" unless defined $pid;

if ( $pid == 0 ) {
    $SIG{CHLD} = 'IGNORE';
    while ( my $sock = $listen->accept() ) {
        my $cpid = fork();
        next if not defined $cpid;
        if ( $cpid != 0 ) { close $sock; next; }
        close $listen;

        my $client = { fids => {}, msize => 8192, socket => $sock };
        while (1) {
            my $hdr = '';
            while ( length($hdr) < 4 ) {
                my $n = sysread( $sock, my $b, 4 - length($hdr) );
                last if !$n;
                $hdr .= $b;
            }
            last if length($hdr) < 4;
            my $size = unpack( 'V', $hdr );
            last if $size < 7 or $size > 66000;
            my $body = '';
            while ( length($body) < $size - 4 ) {
                my $n = sysread( $sock, my $b, $size - 4 - length($body) );
                last if !$n;
                $body .= $b;
            }
            last if length($body) < $size - 4;
            my ( $type, $tag ) = unpack( 'C v', substr( $body, 0, 3 ) );
            my $data = substr( $body, 3 );

            ## real dispatcher ##
            my $resp = $code{'plan-9.server.handle_request'}
                ->( $client, 0, $type, $tag, $data );
            syswrite( $sock, $resp ) if defined $resp;
        }
        close $sock;
        exit 0;
    }
    exit 0;
}
print qq[server daemon entering accept loop\n];

#,,,,,.,,,,,,,.,.,,,,,.,,,.,,,...,.,,,,..,,..,..,,...,...,..,,,,,,...,...,.,.,
#JGWZEKQKSG6O6J2T6FZGZ4IAWP2YSXHYB2HCJTSLRCPJBDMNYE4WKUP5GZYHMFMDAZ4V6X5PWLNGQ
#\\\|NPIAH7IWPRHERKT45WCKT2EJBSWJHMFB3ISHDM7KQES6SC3GCSL \ / AMOS7 \ YOURUM ::
#\[7]JBS54FV6IMETGJFBMIE5QSEQRNSJSC3N47EWUFO3MOWJGAATHKBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
