#!/usr/bin/env perl
use v5.24;
use strict;
use English;
use warnings;

## the production runtime loads the bytes pragma transitively ##
use bytes;

## host-edit lane B2b : ssh forward + probe [ data/md/design/HOST-SETUP.md ##
## 'add-host flow' ]. a FAKE ssh [ a local port forwarder ] replaces the   ##
## real one, p-7-r is compiled from bin/c_src into a temp dir [ the        ##
## installed one may predate -host ] and the probe runs against the LIVE   ##
## cube on 127.0.0.1:42 -- strict only : the client pin store must be      ##
## byte-identical afterwards. skips cleanly without gcc or a cube.         ##

use File::Spec;
use Cwd        qw| abs_path |;
use FindBin    qw| $RealBin |;
use File::Temp qw| tempdir |;
use IO::Socket::INET;
use Crypt::Misc;
use Digest::BMW;

BEGIN {
    my $up = File::Spec->updir;
    my $root
        = abs_path(
        File::Spec->rel2abs( File::Spec->catdir( $RealBin, $up, $up ) ) );
    unshift( @INC, File::Spec->catdir( $root, qw| data lib-path pm | ) );
    $main::root_path = $root;
}

use AMOS7::Protocol::P7Syntax qw| p7_syntax__translate |;

use constant TRUE    => 5;
use constant FALSE   => 0;
use constant UNKNOWN => 2;

our %code;
our %data;
our %keys;

my ( $test_count, $fail_count ) = ( 0, 0 );

sub ok ($;$) {
    my ( $cond, $label ) = @ARG;
    $test_count++;
    if ($cond) { say "  ok   : $label"; return 1 }
    $fail_count++;
    say "  FAIL : $label";
    return 0;
}

my $runtime_pragmas
    = q{no bytes; use File::stat; use open qw| :encoding(UTF-8) |;};

sub compile_module {
    my ($module_name) = @ARG;
    my $src_path
        = File::Spec->catfile( $main::root_path, 'src', $module_name );
    open( my $fh, '<', $src_path ) or die "cannot read $src_path : $!";
    my $src = join( '', <$fh> );
    close($fh);
    my $cref = eval "$runtime_pragmas sub {\n# line 1 \"$module_name\"\n"
        . p7_syntax__translate($src) . "\n}";
    die "compile failed for $module_name : $EVAL_ERROR" if not defined $cref;
    $code{$module_name} = $cref;
    return $cref;
}

compile_module($ARG)
    for
    qw| host-edit.transport.free_port host-edit.transport.ssh_forward_start
    host-edit.transport.forward_ready host-edit.transport.ssh_forward_stop
    host-edit.action.probe host-edit.action.run_p7r host-edit.action.pin
    host-edit.action.fetch_chain host-edit.action.install
    trust.statement trust.key_id trust.chain |;

my $tmp = tempdir( CLEANUP => 1 );

## never leave a forward [ fake ssh ] running, whatever happens ##
END {
    $code{'host-edit.transport.ssh_forward_stop'}->()
        if ref $code{'host-edit.transport.ssh_forward_stop'} eq 'CODE';
}

## every pin file : name + content [ the store must not change ] ##
sub snapshot_pins {
    my ($dir) = @ARG;
    my @all;
    foreach my $file ( sort glob("$dir/*") ) {
        open( my $fh, '<', $file ) or next;
        local $INPUT_RECORD_SEPARATOR = undef;
        push @all, "$file:" . ( readline($fh) // '' );
        close($fh);
    }
    return join "\n", @all;
}

## --- a fake ssh : forwards -L 127.0.0.1:<L>:127.0.0.1:<R> locally --- ##
my $fake_ssh = File::Spec->catfile( $tmp, 'fake-ssh' );
open( my $sfh, '>', $fake_ssh ) or die;
print {$sfh} <<'FAKE';
#!/usr/bin/env perl
use strict; use warnings; use IO::Socket::INET; use IO::Select;
my ($spec) = map { $ARGV[$_+1] } grep { $ARGV[$_] eq '-L' } 0 .. $#ARGV;
exit 3 if grep { $_ eq 'fail@nowhere' } @ARGV;
my ( undef, $lport, undef, $rport ) = split /:/, $spec;
my $srv = IO::Socket::INET->new( LocalAddr => '127.0.0.1', LocalPort => $lport,
    Listen => 5, ReuseAddr => 1 ) or exit 2;
$SIG{CHLD} = 'IGNORE';
while ( my $c = $srv->accept ) {
    next if fork;
    my $r = IO::Socket::INET->new( PeerAddr => '127.0.0.1', PeerPort => $rport ) or exit 4;
    my $sel = IO::Select->new( $c, $r );
    while ( my @ready = $sel->can_read ) {
        for my $fh (@ready) {
            my $n = sysread( $fh, my $buf, 65536 );
            exit 0 if not $n;
            syswrite( $fh == $c ? $r : $c, $buf );
        }
    }
    exit 0;
}
FAKE
close($sfh);
chmod 0755, $fake_ssh;
$data{'host-edit'}{'cfg'}{'ssh_bin'} = $fake_ssh;

######################################################################
say ': transport [ validation ]';

my $start = $code{'host-edit.transport.ssh_forward_start'};
my ( $r, $why );
( $r, $why ) = $start->( 'zz-test', '-oProxyCommand=x', 22, 42 );
ok( !defined $r && $why =~ m|target not valid|,
    'a target starting with - is refused [ no option injection ]' );
( $r, $why ) = $start->( 'ZZ Bad', 'user@host', 22, 42 );
ok( !defined $r && $why =~ m|record name|, 'a bad record name is refused' );
( $r, $why ) = $start->( 'zz-test', 'user@host', 70000, 42 );
ok( !defined $r && $why =~ m|port|, 'a bad port is refused' );
ok( ( $code{'host-edit.transport.free_port'}->() // 0 ) =~ m|\A\d+\z|,
    'free_port gives a port' );

######################################################################
say ': transport [ a forward that dies ]';

( $r, $why ) = $start->( 'zz-dead', 'fail@nowhere', 22, 42 );
ok( defined $r, 'started [ the fake ssh exits at once ]' );
my ( $ready, $ready_why );
foreach ( 1 .. 50 ) {
    ( $ready, $ready_why )
        = $code{ 'host-edit.transp' . 'ort.forward_ready' }->('zz-dead');
    last if not defined $ready;
    select( undef, undef, undef, 0.05 );
}
ok( !defined $ready && $ready_why =~ m|ssh exited|,
    'forward_ready reports the dead ssh'
);
ok( !exists $data{'host-edit'}{'forwards'}{'zz-dead'},
    '  :.. and ' . 'forgets it' );

######################################################################
say ': transport + probe against the live cube';

my $cube_up = IO::Socket::INET->new(
    PeerAddr => '127.0.0.1',
    PeerPort => 42,
    Timeout  => 1
);
my $gcc = grep { -x "$ARG/gcc" } split m|:|, $ENV{'PATH'} // '';
if ( not $cube_up or not $gcc ) {
    say '  skip : no cube on 127.0.0.1:42 or no gcc';
} else {
    close($cube_up);
    my $p7r = File::Spec->catfile( $tmp, 'p-7-r' );
    system( 'gcc', '-O2', '-o', $p7r,
        File::Spec->catfile( $main::root_path, qw| bin c_src p-7-r.c | ) )
        == 0
        or die 'p-7-r did not compile';
    $data{'host-edit'}{'cfg'}{'p7r_bin'} = $p7r;
    $ENV{'PROTOCOL_7_BIN_P7R_USER'} //= getpwuid($UID);

    my $servers     = "$ENV{'HOME'}/.n/remote-keys/servers";
    my $pins_before = snapshot_pins($servers);

    my $local = $start->( 'zz-test', 'tester@localhost', 22, 42 );
    ok( defined $local, 'forward started' );
    ( $r, $why ) = $start->( 'zz-test', 'tester@localhost', 22, 42 );
    ok( !defined $r && $why =~ m|already running|,
        'a second forward for the same record is refused'
    );
    my $up;
    foreach ( 1 .. 100 ) {
        $up = $code{'host-edit.transport.forward_ready'}->('zz-test');
        last if $up;
        select( undef, undef, undef, 0.05 );
    }
    ok( $up, 'forward_ready : accepting' );

    my $probe = $code{'host-edit.action.probe'};
    my ( $p, $pwhy ) = $probe->( 'zz-test', 42, '127.0.0.1', $local );
    ok( ref $p eq 'HASH'
            && $p->{'state'} eq 'unpinned'
            && $p->{'key_id'} =~ m|\A[A-Z2-7]{77}\z|
            && $p->{'name'}   =~ m|\.cube\z|,
        'probe zz-test through the forward : '
            . 'unpinned, key id + leaf name offered'
    ) or say "    got : " . ( ref $p ? join( ' ', %$p ) : $pwhy // '?' );

    ( $p, $pwhy ) = $probe->( 'localhost', 42, '127.0.0.1', $local );
    ok( ref $p eq 'HASH' && $p->{'state'} eq 'pinned',
        'probe as localhost through the forward : the existing pin matches' )
        or say "    got : " . ( ref $p ? join( ' ', %$p ) : $pwhy // '?' );

    ## pin : a non-strict connect -- into a TEMP home, never the real store ##
    {
        my $home = File::Spec->catdir( $tmp, 'home' );
        mkdir $home;
        local $ENV{'HOME'}                   = $home;
        local $code{'crypt.C25519.key_vars'} = sub {
            return { known_hosts_dir => "$home/.n/remote-keys/servers" };
        };
        my ( $pin, $pin_why )
            = $code{'host-edit.action.pin'}
            ->( 'zz-test', 42, '127.0.0.1', $local, $p->{'key_id'} // '' );
        ok( ref $pin eq 'HASH' && $pin->{'state'} eq 'pinned',
            'pin through the forward : pinned, '
                . 'the pin holds the probed key id'
            )
            or say "    got : "
            . ( ref $pin ? join( ' ', %$pin ) : $pin_why // '?' );
        ok( -f "$home/.n/remote-keys/servers/zz-test_42.public",
            '  :.. named after the RECORD [ zz-test_42 ], not the forward'
        );
        ( $pin, $pin_why )
            = $code{'host-edit.action.pin'}
            ->( 'zz-test', 42, '127.0.0.1', $local, 'A' x 77 );
        ok( !defined $pin && $pin_why =~ m|another key id|,
            'pin with a different expected key id : refused'
        );
    }

    ok( $code{'host-edit.transport.ssh_forward_stop'}->('zz-test') == 1,
        'forward stopped' );
    ok( !IO::Socket::INET->new(
            PeerAddr => '127.0.0.1',
            PeerPort => $local,
            Timeout  => 0.5
        ),
        '  :.. the local port is closed'
    );

    my $pins_after = snapshot_pins($servers);
    ok( $pins_after eq $pins_before,
        'the client pin store is byte-identical '
            . '[ strict probes write nothing ]'
    );
}

######################################################################
say ': fetch_chain + install [ a fake p-7-r prints the reply ]';
{
    my $dlg_path = '/home/protocol-7/.n/user-keys/protocol-7.base.dlg';
    my $field;
    if ( open( my $fh, '<', $dlg_path ) ) {
        local $INPUT_RECORD_SEPARATOR = undef;
        my @lines = grep {length} split m|\n|, readline($fh);
        close($fh);
        $field = join '.', @lines;
    }
    my $fake_reply = sub {    ## a p-7-r that prints $text, exits $code ##
        my ( $text, $code ) = @ARG;
        my $path = File::Spec->catfile( $tmp, 'fake-p7r' );
        open( my $fh, '>', $path ) or die;
        print {$fh} "#!/bin/sh\ncat <<'EOT'\n$text\nEOT\nexit $code\n";
        close($fh);
        chmod 0755, $path;
        $data{'host-edit'}{'cfg'}{'p7r_bin'} = $path;
    };
    if ( defined $field ) {
        my $leaf  = ( split m|\.|, $field )[0];
        my $st    = $code{'trust.statement'}->( 'parse_wire', $leaf );
        my $hr_id = $code{'trust.key_id'}->( $st->{'issuer_pub'} );
        $fake_reply->( " :\n$field\n :", 0 );
        my ( $c, $cwhy )
            = $code{'host-edit.action.fetch_chain'}
            ->( 'zz-test', 42, '127.0.0.1', 4242, $hr_id );
        ok( ref $c eq 'HASH'
                && $c->{'field'} eq $field
                && length( $c->{'root_pub'} ) == 32,
            'fetch_chain : the chain, its leaf issuer = the pinned key id'
        ) or say "    got : " . ( $cwhy // '?' );
        ( $c, $cwhy )
            = $code{'host-edit.action.fetch_chain'}
            ->( 'zz-test', 42, '127.0.0.1', 4242, 'A' x 77 );
        ok( !defined $c && $cwhy =~ m|another host-root|,
            'fetch_chain : a chain for another host-root is refused'
        );
    } else {
        say '  skip : no readable .dlg on this host';
    }
    $fake_reply->( 'nothing useful', 1 );
    my ( $c, $cwhy )
        = $code{'host-edit.action.fetch_chain'}
        ->( 'zz-test', 42, '127.0.0.1', 4242, 'A' x 77 );
    ok( !defined $c && $cwhy =~ m|no delegation chain|,
        'fetch_chain : no chain in the reply'
    );

    my $wire = 'A' x 300;
    $fake_reply->(
        'installed [ owner ABCDEFG.. ' . '] ; delegation re-issued', 0
    );
    my ( $i, $iwhy )
        = $code{'host-edit.action.install'}
        ->( 'zz-test', 42, '127.0.0.1', 4242, $wire );
    ok( ref $i eq 'HASH' && $i->{'state'} eq 'installed',
        'install : ' . 'installed' );
    $fake_reply->( 'this owner statement is already installed', 1 );
    ( $i, $iwhy )
        = $code{'host-edit.action.install'}
        ->( 'zz-test', 42, '127.0.0.1', 4242, $wire );
    ok( ref $i eq 'HASH' && $i->{'state'} eq 'already', 'install : already' );
    $fake_reply->( 'owner chain refused [ name outside issuer scope ]', 1 );
    ( $i, $iwhy )
        = $code{'host-edit.action.install'}
        ->( 'zz-test', 42, '127.0.0.1', 4242, $wire );
    ok( !defined $i && $iwhy =~ m|name outside issuer scope|,
        'install : a refusal is reported with its reason'
    );
    ( $i, $iwhy )
        = $code{'host-edit.action.install'}
        ->( 'zz-test', 42, '127.0.0.1', 4242, 'not b32' );
    ok( !defined $i, 'install : a malformed statement is refused locally' );
}

say '';
say "passed : " . ( $test_count - $fail_count ) . "  failed : $fail_count";
exit( $fail_count ? 1 : 0 );

#,,,,,,..,,..,..,,.,,,,..,.,.,,..,,,.,,,.,,.,,..,,...,...,...,...,,..,..,,..,,
#JQKX3WYYLHCBRVAND7TWBO2XQKFLCGXCU75NRRRDAVB67MNT4CZARDE4UG3ZDVM5I6BFSNLPLDANK
#\\\|JFL55JZ3Q53B3PKJ2VFGBAOMEKV6TS5WDV2CIIBGCY3SFD63VSE \ / AMOS7 \ YOURUM ::
#\[7]ZQRTZXDP2O3XNHBLD7TBP5D52BBYBU3N55AYX2FPXQAORSMXL6CY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
