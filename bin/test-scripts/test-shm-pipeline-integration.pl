#!/usr/bin/perl
## test-shm-pipeline-integration.pl : loads and EXECUTES the real P7 module
## files (modules/base.shm.{path,write,read}, modules/httpd.handler.shm_write)
## via AMOS7::Protocol::P7Syntax translation -- unlike test-shm-pipeline.pl
## (which reimplements the algorithm standalone with raw Crypt::Ed25519 /
## Digest::BMW / AMOS7::Twofish calls and never touches the real module
## files), this harness proves the actual deliverable works, not just the
## design.
##
## real dependencies used as-is: Crypt::Ed25519, AMOS7::Twofish, Digest::BMW,
## Crypt::Misc encode_b32r/decode_b32r.  stubbed (pure P7-runtime plumbing,
## not part of what's under test): base.logs, base.ntime family (deterministic
## stand-in, same /4200 scale convention as the real code),
## event.add_var/add_timer, httpd.send_error_page, base.perlmod.load/loaded
## (real modules are already `use`d directly).

use v5.24;
use strict;
use warnings;
use English;
use FindBin qw| $RealBin |;

BEGIN { unshift( @INC, "$RealBin/../../data/lib-path/pm" ) }

use AMOS7::Protocol::P7Syntax qw| p7_syntax__translate |;
use Crypt::Ed25519;
use Crypt::Misc qw| encode_b32r decode_b32r |;
use AMOS7::Twofish;
use Digest::BMW;
use File::Path  qw| make_path remove_tree |;
use Time::HiRes qw| time |;

use constant TRUE  => 5;
use constant FALSE => 0;

my $pass = 0;
my $fail = 0;

sub ok {
    my ( $desc, $cond ) = @_;
    if   ($cond) { $pass++; say "ok   - $desc" }
    else         { $fail++; say "FAIL - $desc" }
}

##[ load + translate the real module files into %code entries ]###############

our ( %code, %data, %keys );

sub load_p7_module {
    my ( $file, $name ) = @_;
    open my $fh, '<', $file or die "$file : $!";
    my @body;
    foreach my $line (<$fh>) {
        last if $line =~ m|^#[,\.]{10,}|;
        push @body, $line;
    }
    close $fh;
    my $src = join '', @body;
    $src =~ s|\A## \[:< ##\n||;
    $src =~ s{(?:^# \w[\w ]* = [^\n]*\n)+}{}m;
    my $translated = p7_syntax__translate($src);
    my $coderef    = eval sprintf(
        q|package main;
          use strict; use warnings; use utf8; use English;
          use constant TRUE => 5; use constant FALSE => 0; use constant UNKNOWN => 2;
          our ( %%code, %%data, %%keys );
          sub { my @ARG = @_; %s }|,
        $translated
    );
    die "compile of $name failed : $@" if $@;
    $code{$name} = $coderef;
}

for my $m (
    qw| base.shm.path base.shm.write base.shm.read httpd.handler.shm_write |)
{
    load_p7_module( "$RealBin/../../modules/$m", $m );
}

##[ stub the pure-plumbing dependencies ]#####################################

my $test_dir = "/tmp/p7-shm-integration-$PID";
remove_tree($test_dir) if -d $test_dir;

$data{'system'}{'root_path'} = $test_dir;
$code{'base.cfg.shm_dir'} = "$test_dir/shm";
## <base.cfg.shm_dir> translates to $data{'base'}{'cfg'}{'shm_dir'} ##
$data{'base'}{'cfg'}{'shm_dir'} = "$test_dir/shm";

$code{'base.logs'} = sub {
    shift;
    warn sprintf( shift, @_ ) . "\n" if $ENV{SHM_TEST_DEBUG};
    return 1;
};
$code{'base.s_warn'}         = sub { warn sprintf( shift, @_ ) };
$code{'base.cnt_s'}          = sub { return $_[0] == 1 ? '' : 's' };
$code{'base.str.os_err'}     = sub { return "$OS_ERROR" };
$code{'base.perlmod.load'}   = sub { return TRUE };    ## already `use`d ##
$code{'base.perlmod.loaded'} = sub { return TRUE };
$code{'base.file.make_path'} = sub {
    my ( $path, $mode ) = @_;
    make_path( $path, { mode => $mode // 0755 } );
    chmod( $mode, $path ) if defined $mode;
    return -d $path ? TRUE : FALSE;
};
$code{'base.prng.bytes'} = sub {
    my $n = shift;
    return join '', map { chr( int( rand(256) ) ) } 1 .. $n;
};

## ntime stand-in : same /4200 scale convention as the real deployed code - ##
## a deterministic, round-trippable stub is fine here since correctness of  ##
## the REAL base.ntime.* inline-subroutine implementation is out of scope   ##
## for this test [ it's bootstrap plumbing, not part of the shm pipeline ]  ##
$code{'base.ntime'} = sub {
    my $precision = shift // 3;
    return sprintf( "%.${precision}f", time() * 4200 );
};
$code{'base.ntime.b32'} = sub {
    my ( $precision, $numeric_only ) = @_;
    my $n = $code{'base.ntime'}->($precision);
    ## 64-bit : time()*4200 overflows 32-bit ##
    return encode_b32r( pack( 'Q>', int($n) ) );
};
$code{'base.ntime_BASE32_to_numerical'} = sub {
    my $b32 = shift;
    my $raw = eval { decode_b32r($b32) };
    return undef if not defined $raw or length($raw) != 8;
    return unpack( 'Q>', $raw );
};

## BMW helpers : real Digest::BMW, stand-in for the cache-clone wrapper ##
$code{'base.chk-sum.bmw.ctx'} = sub {
    my $bits = shift || 512;
    return Digest::BMW->new($bits);
};
$code{'base.chk-sum.bmw.L13-str'} = sub {
    my $bmw = Digest::BMW::bmw_512(@_);
    return substr( encode_b32r($bmw), 0, 13 );
};

## event loop stubs : stream mode is driven manually in this test, not by a ##
## real Event->io var-watcher, so these just need to not blow up            ##
$code{'event.add_var'}   = sub { return bless( {}, 'FakeWatcher' ) };
$code{'event.add_timer'} = sub { return bless( {}, 'FakeWatcher' ) };

my @sent_errors;
$code{'httpd.send_error_page'} = sub {
    my ( $id, $code_num ) = @_;
    push @sent_errors, $code_num;
    return 2;
};

$data{'httpd'}{'cfg'}{'shm_replay_window'} = 60;
## simplify : test gate 4 alone, cert tested separately ##
$data{'httpd'}{'cfg'}{'shm_require_cert'} = FALSE;
$data{'httpd'}{'cfg'}{'shm_encrypt'}      = TRUE;

##[ test fixture keys : sender C25519 keypair ]###############################

my ( $pub, $priv ) = Crypt::Ed25519::generate_keypair();

##[ helper : build a full request + drive it through the real handler ]#######

sub build_request {
    my %opt         = @_;
    my $body        = $opt{body}        // 'hello shm pipeline';
    my $ntime_delta = $opt{ntime_delta} // 0;       ## seconds off from now ##
    my $tamper_sig  = $opt{tamper_sig}  // FALSE;
    my $wrong_bytes = $opt{wrong_bytes};
    my $wrong_lines = $opt{wrong_lines};
    my $wrong_bmw   = $opt{wrong_bmw};

    my $ntime_num = int( ( time() + $ntime_delta ) * 4200 );
    my $ntime_b32 = encode_b32r( pack( 'Q>', $ntime_num ) );

    my $bytes = $wrong_bytes // length($body);
    my $lines = $wrong_lines // ( () = $body =~ /\n/g );

    my $bmw = Digest::BMW->new(384);
    $bmw->add($body);
    my $b32sum = $wrong_bmw // encode_b32r( $bmw->digest );

    my $content_hash = "$ntime_b32:$bytes:$lines:$b32sum";
    my $sig          = Crypt::Ed25519::sign( $content_hash, $pub, $priv );
    $sig = "\0" x length($sig) if $tamper_sig;

    return {
        body    => $body,
        headers => {
            'x-p7-content-hash' => $content_hash,
            'x-p7-signature'    => encode_b32r($sig),
            'x-p7-host-key'     => encode_b32r($pub),
            'content-length'    => $bytes,
        },
    };
}

my $next_id = 1000;

sub run_request {
    my $req = shift;
    my $id  = $next_id++;

    $data{'session'}{$id} = {
        'http'    => { 'request' => { 'headers' => $req->{headers} } },
        'buffer'  => { 'input'   => '' },
        'watcher' => {},
    };

    my $init_rc = $code{'httpd.handler.shm_write'}->( $id, 'noop_route', {} );

    my $session = $data{'session'}{$id};
    return ( $id, $init_rc, undef ) if not defined $session->{'http'}{'shm'};

    ## drive stream mode manually : feed the body in two awkward chunks ##
    my $body   = $req->{body};
    my $mid    = int( length($body) / 3 ) || length($body);
    my @chunks = ( substr( $body, 0, $mid ), substr( $body, $mid ) );

    my $fake_event = bless {}, 'FakeEvent';
    my $result;
    for my $chunk (@chunks) {
        next if not length $chunk;
        $data{'session'}{$id}{'buffer'}{'input'} = $chunk;
        $result = $code{'httpd.handler.shm_write'}
            ->( bless( { id => $id }, 'FakeVarEvent' ) );
        ## rejected mid-stream ##
        last if not defined $data{'session'}{$id}{'http'}{'shm'};
    }
    ## final call with empty buffer in case body was exact multiple of ##
    ## chunk                                                           ##
    if ( defined $data{'session'}{$id}{'http'}{'shm'} ) {
        $data{'session'}{$id}{'buffer'}{'input'} = '';
        $result = $code{'httpd.handler.shm_write'}
            ->( bless( { id => $id }, 'FakeVarEvent' ) );
    }

    return ( $id, $init_rc, $result );
}

## FakeVarEvent : minimal stand-in for the real Event->io object ##
package FakeVarEvent;
sub w    { return $_[0] }
sub data { return $_[0]->{id} }
sub stop {return}

package main;

## FakeWatcher : stand-in for the Event->var/Event->timer watcher objects ##
package FakeWatcher;
sub stop  {return}
sub now   {return}
sub again {return}

package main;

##[ test 1 : full valid path ]################################################

{
    my $req     = build_request( body => "line one\nline two\nline three" );
    my ($id)    = run_request($req);
    my $session = $data{'session'}{$id};
    ok( 'valid signed request passes all gates',
        defined $session->{'http'}{'shm_path'}
    );
    ok( 'final file exists, content-addressed',
        defined $session->{'http'}{'shm_path'}
            && -f "$test_dir/shm/$session->{'http'}{'shm_path'}"
    );
    if ( defined $session->{'http'}{'shm_path'} ) {
        my $mode
            = ( stat("$test_dir/shm/$session->{'http'}{'shm_path'}") )[2]
            & 07777;
        ok( 'final file chmod 440', $mode == 0440 );
    } else {
        ok( 'final file chmod 440', 0 );
    }

    ## now read it back via base.shm.read using the real module ##
    my $shm_key  = $session->{'http'}{'shm_key'};
    my $read_ref = $code{'base.shm.read'}
        ->( { path => $session->{'http'}{'shm_path'}, key => $shm_key } );
    ok( 'base.shm.read decrypts + verifies the real handler output',
        defined $read_ref && $read_ref->$* eq $req->{body}
    );
    ok( 'file unlinked after read [ default behavior ]',
        not -f "$test_dir/shm/$session->{'http'}{'shm_path'}"
    );
}

##[ test 2 : tampered signature rejected before any file is opened ]##########

{
    my $req = build_request( body => 'irrelevant', tamper_sig => TRUE );
    my ( $id, $init_rc ) = run_request($req);
    ok( 'tampered signature rejected at gate 4', $init_rc != 1 );
    ok( 'no shm state created for rejected signature',
        not defined $data{'session'}{$id}{'http'}{'shm'}
    );
}

##[ test 3 : stale ntime rejected before signature gate even runs ]###########

{
    my $req = build_request( body => 'irrelevant', ntime_delta => -600 );
    my ( $id, $init_rc ) = run_request($req);
    ok( 'stale ntime rejected at gate 2', $init_rc != 1 );
}

##[ test 4 : byte count mismatch -> mid-stream rejection + cleanup ]##########

{
    ## declared count must be SMALLER than the actual body so the overflow ##
    ## gate [ actual byte_count > declared decl_bytes ] actually trips     ##
    my $req = build_request(
        body        => 'this body is longer than ' . 'declared',
        wrong_bytes => 3
    );
    my ( $id, $init_rc, $stream_rc ) = run_request($req);
    ok( 'byte overflow rejected mid-stream',
        $init_rc == 1 && not defined $data{'session'}{$id}{'http'}{'shm'} );
}

##[ test 5 : BMW384 mismatch detected at finalize, temp file cleaned up ]#####

{
    my $req = build_request(
        body      => 'tamper target body',
        wrong_bmw => ( 'A' x 77 ),    ## syntactically valid, wrong digest ##
    );
    my ( $id, $init_rc, $stream_rc ) = run_request($req);
    ok( 'BMW384 mismatch rejected at gate 7',
        $init_rc == 1 && not defined $data{'session'}{$id}{'http'}{'shm'} );

    ## no leftover temp files in the shm dir after the rejected transfer ##
    opendir( my $dh, "$test_dir/shm" ) or die $!;
    my @leftover = grep { !/^\.\.?$/ } readdir($dh);
    closedir($dh);
    ok( 'no leftover temp file ' . 'after BMW384 rejection',
        scalar(@leftover) == 0 );
}

##[ test 6 : exact replay of the same ntime is rejected ]#####################

{
    my $req = build_request( body => 'replay me' );
    my ($id1) = run_request($req);
    ok( 'first send of this ntime succeeds',
        defined $data{'session'}{$id1}{'http'}{'shm_path'} );

    ## re-send the EXACT same headers [ same ntime + same signature ] ##
    my ( $id2, $init_rc2 ) = run_request($req);
    ok( 'exact replay rejected by per-sender ntime cache', $init_rc2 != 1 );
}

##[ test 7 : unencrypted mode round-trips too ]###############################

{
    $data{'httpd'}{'cfg'}{'shm_encrypt'} = FALSE;
    my $req     = build_request( body => 'plaintext mode body' );
    my ($id)    = run_request($req);
    my $session = $data{'session'}{$id};
    ok( 'unencrypted request passes all gates',
        defined $session->{'http'}{'shm_path'}
    );
    ok( 'unencrypted shm_key is undef',
        not defined $session->{'http'}{'shm_key'} );
    my $read_ref = $code{'base.shm.read'}
        ->( { path => $session->{'http'}{'shm_path'} } );
    ok( 'unencrypted read round-trips',
        defined $read_ref && $read_ref->$* eq $req->{body} );
    $data{'httpd'}{'cfg'}{'shm_encrypt'} = TRUE;
}

##[ test 8 : base.shm.write / base.shm.read directly [ not via the httpd handler ] ]##

{
    my $payload = "direct base.shm.write test body\nwith two lines";
    my $name    = $code{'base.shm.write'}->( { data => $payload } );
    ok( 'base.shm.write returns a content-addressed name', defined $name );
    ok( 'base.shm.write file is chmod 440',
        defined $name
            && ( ( stat("$test_dir/shm/$name") )[2] & 07777 ) == 0440
    );
    my $read_ref = $code{'base.shm.read'}->( { path => $name } );
    ok( 'base.shm.read round-trips base.shm.write output [ unencrypted ]',
        defined $read_ref && $read_ref->$* eq $payload );
}

{
    my $payload = "direct encrypted round-trip test";
    my $key     = $code{'base.prng.bytes'}->(32);
    my $name    = $code{'base.shm.write'}
        ->( { data => $payload, key => encode_b32r($key) } );
    ok( 'base.shm.write [ encrypted ] returns a name', defined $name );
    my $read_ref = $code{'base.shm.read'}
        ->( { path => $name, key => encode_b32r($key) } );
    ok( 'base.shm.read round-trips base.shm.write output [ encrypted ]',
        defined $read_ref && $read_ref->$* eq $payload );
}

##[ summary ]#################################################################

say '';
say "passed : $pass   failed : $fail";
remove_tree($test_dir) if -d $test_dir;
exit( $fail ? 1 : 0 );

#,,.,,...,,.,,,..,,,,,,.,,,,.,,,.,,,.,,,.,..,,..,,...,...,.,.,,,,,...,,..,.,.,
#TCDMDDHEIAKIEUWGDJIFEYVLVYOM6T3L6HZFI74YAJWCHWTPBADYAI7K5FGFFKZEBSTAW44H7NMZA
#\\\|H4HVF3RJVY67JGOFROQEFU5GRKPMHMH4PILU4DSWHNYXQKAUMFT \ / AMOS7 \ YOURUM ::
#\[7]NKLCX5OAPGJ2ZMGHEP2XTNSUFGYAWYIZ3GNPKST4YO3HEH6ZHWAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
