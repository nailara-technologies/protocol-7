#!/usr/bin/env perl
use v5.24;
use strict;
use English;
use warnings;

## the production runtime [ bin/Protocol-7 : use utf8 + Encode ] loads the ##
## bytes pragma transitively ; keep it so compiled modules resolve it.     ##
use bytes;

## discover : host packets carry the host-root delegation [ 2026-10-06,   ##
## data/md/design/HOST-ROOT-DELEGATION.md ] : compiles the REAL discover \ ##
## nodes \ trust modules and drives them with stubs only [ harness :       ##
## bin/test-scripts/test-host-root-delegation.pl ]. the real sender builds ##
## a packet, the real receiver consumes it : a valid .dlg round-trips      ##
## [ build -> parse -> verify ] ; each trust state [ pinned offered        ##
## unverified invalid ] ; pinned detection from a tempdir pin store ;      ##
## an invalid delegation drops the packet ; a changed root_fp is kept-old  ##
## + invalid + logged ; the old '.sig.*' lines are gone from the packet ;  ##
## discover.cmd.host_details output ; and the nodes route carries          ##
## root_fp + trust. no network, no key dir read, nothing signed on disk.   ##

use File::Spec;
use Cwd        qw| abs_path |;
use FindBin    qw| $RealBin |;
use File::Temp qw| tempdir |;
use List::Util qw| max |;

BEGIN {
    my $up_dir    = File::Spec->updir;
    my $root_path = abs_path(
        File::Spec->rel2abs(
            File::Spec->catdir( $RealBin, $up_dir, $up_dir )
        )
    );
    my $local_lib_path
        = File::Spec->catdir( $root_path, qw| data lib-path pm | );
    die "not found : $local_lib_path" if !-d $local_lib_path;
    unshift( @INC, $local_lib_path );
    $main::root_path = $root_path;
}

use AMOS7::Protocol::P7Syntax qw| p7_syntax__translate |;
use Crypt::Misc               qw| encode_b32r decode_b32r |;
use Crypt::Ed25519;
use Digest::BMW;

use constant TRUE    => 5;
use constant FALSE   => 0;
use constant UNKNOWN => 2;

our %code;
our %data;
our %keys;

$OUTPUT_AUTOFLUSH = 1;

my $fail_count = 0;
my $pass_count = 0;

sub ok ($;$) {
    my ( $cond, $label ) = @ARG;
    if ($cond) { $pass_count++; say "  ok   : $label"; return }
    $fail_count++;
    say "  FAIL : $label";
    return;
}

## $prefix : source prepended inside the compiled sub [ the .cmd. header ]  ##
## mirrored from bin/Protocol-7 [ use open :encoding(UTF-8), File::stat ] : ##
## a bare list-context stat or a sysread on a default handle fails here too ##
my $runtime_pragmas
    = q{no bytes; use File::stat; use open qw| :encoding(UTF-8) |;};

sub compile_module {
    my ( $module_name, $prefix ) = @ARG;
    $prefix //= '';
    my $src_path
        = File::Spec->catfile( $main::root_path, 'src', $module_name );
    open( my $fh, '<', $src_path ) or die "cannot read $src_path : $!";
    my $src = join( '', <$fh> );
    close($fh);
    my $translated = p7_syntax__translate($src);
    ## the runtime : File::stat object stat + :utf8 default open layer ##
    my $cref
        = eval "$runtime_pragmas sub {\n$prefix\n# "
        . "line 1 \"$module_name\"\n$translated\n}";
    die "compile failed for $module_name : $EVAL_ERROR"
        if not defined $cref;
    $code{$module_name} = $cref;
    return $cref;
}

my $cmd_header = 'my $call = {}; if ( ref( $ARG[0] ) eq q|HASH| ) { $call '
    . '= $ARG[0] } else { $call->{q|args|} = $ARG[0] }';

## ---------------------------------------------------------------------- ##
## generic stubs                                                          ##

my @logged;
my @complaints;
my @nodes_sent;
$code{'base.logs'} = sub { push @logged, [@ARG]; return };
$code{'base.log'}  = sub { push @logged, [@ARG]; return };
$code{'base.s_warn'}
    = sub { push @complaints, sprintf( shift, @ARG ); return };
$code{'base.ntime'}     = sub { return 0 };                 ##  tstamp-adj  ##
$code{'base.ntime.b32'} = sub { return 'AAAAAAAAAAAAA' };   ## 13 chars ##
$code{'base.ntime_BASE32_to_numerical'}       = sub { return 0 };
$code{'base.anum_log_time'}                   = sub { return 'TS' };
$code{'base.buffer.add_line'}                 = sub {return};
$code{'discover.log_mcast_packet'}            = sub {return};
$code{'discover.check_packet_timeouts'}       = sub {return};
$code{'discover.orbital.get_local_p7ref'}     = sub { return undef };
$code{'discover.orbital.store_remote'}        = sub {return};
$code{'discover.orbital.share_grid_fragment'} = sub {return};
$code{'base.is_defined_recursive'}            = sub { return TRUE };
$code{'base.cfg_bool'}                        = sub {
    my $v = shift;
    return TRUE
        if defined $v
        and ( $v eq 'yes' or $v eq '1' or ( $v =~ m|\A\d+\z| and $v ) );
    return FALSE;
};
$code{'base.sort'} = sub {
    return sort keys $_[0]->%* if ref $_[0] eq 'HASH';
    return sort @ARG;
};
$code{'base.reverse-sort'} = sub {
    return reverse sort keys $_[0]->%* if ref $_[0] eq 'HASH';
    return reverse sort @ARG;
};
$code{'base.reverse-sort.key-name'} = sub {
    my ( $field, $href ) = @ARG;
    return reverse sort { $href->{$a}{$field} cmp $href->{$b}{$field} }
        keys $href->%*;
};
## a deterministic L13 : distinct inputs -> distinct ids ##
$code{'chk-sum.bmw.L13-str'} = sub {
    my $in = join '', map { defined $ARG ? $ARG : '' } @ARG;
    return sprintf 'L%u', unpack( '%32C*', $in );
};
## the nodes route : capture what discover sends ##
$code{'protocol-7.command.send.local'}
    = sub { push @nodes_sent, $ARG[0]; return TRUE };

sub logged_at {
    my ( $level, $pattern ) = @ARG;
    return scalar grep {
                defined $ARG->[0]
            and $ARG->[0] eq $level
            and do {
            no warnings;
            sprintf( $ARG->[1] // '', @{$ARG}[ 2 .. $ARG->$#* ] );
            }
            =~ $pattern
    } @logged;
}

my @perl_warnings;
local $SIG{__WARN__} = sub { push @perl_warnings, @ARG };

## ---------------------------------------------------------------------- ##
## the client home : the read-only host-root pin store lives here         ##

my $client_home = tempdir( 'p7-dd-XXXXXXXX', TMPDIR => 1, CLEANUP => 1 );
my $pin_dir     = "$client_home/.n/remote-keys/servers";
system( 'mkdir', '-p', $pin_dir ) == 0 or die 'mkdir pin dir';

## the pin reader + key_vars it consults for the home directory ##
$code{'crypt.C25519.key_vars'}
    = sub { return { 'usr_home' => $client_home } };

sub clear_pins {
    unlink glob "$pin_dir/*.public";
    return;
}

sub write_pin {    ## pin a fingerprint as <name>.public ##
    my ( $name, $fingerprint ) = @ARG;
    open( my $fh, '>', "$pin_dir/$name.public" ) or die "pin : $OS_ERROR";
    print {$fh} "$fingerprint\n";
    close($fh);
    return;
}

## the .dlg file the sender reads [ stubbed delegation_file returns it ] ##
my $dlg_path = "$client_home/.n/user-keys/protocol-7.base.dlg";
system( 'mkdir', '-p', "$client_home/.n/user-keys" ) == 0 or die 'mkdir keys';
$code{'crypt.C25519.delegation_file'} = sub { return $dlg_path };

## ---------------------------------------------------------------------- ##
## fixed-seed throwaway keys [ the spec vector : host-root \x03, S \x02 ] ##

my ( $hr_pub, $hr_priv ) = Crypt::Ed25519::generate_keypair( "\x03" x 32 );
my ( $s_pub,  $s_priv )  = Crypt::Ed25519::generate_keypair( "\x02" x 32 );
my ( $fr_pub, $fr_priv ) = Crypt::Ed25519::generate_keypair( "\x04" x 32 );
my ( $x_pub,  $x_priv )  = Crypt::Ed25519::generate_keypair( "\x05" x 32 );

my $b32 = sub { Crypt::Misc::encode_b32r(shift) };

compile_module('trust.statement');
compile_module('trust.fingerprint');
compile_module('trust.verify');
compile_module('discover.read_host_root_pins');
compile_module('discover.format_discover_mcast_packet');
compile_module('discover.process_incoming_packet');
compile_module('discover.process_host_packet');
compile_module( 'discover.cmd.host_details', $cmd_header );

my $statement   = $code{'trust.statement'};
my $fingerprint = $code{'trust.fingerprint'};
my $hr_fp       = $fingerprint->($hr_pub);
my $fr_fp       = $fingerprint->($fr_pub);

## a delegation wire : host-root [ default ] delegates to S [ default ] ##
sub dlg {
    my %o = @ARG;
    my ( $i_pub, $i_priv ) = ( $o{'issuer'} // [ $hr_pub, $hr_priv ] )->@*;
    my $st = $statement->(
        'build',
        {   issuer_pub  => $i_pub,
            subject_pub => $o{'subject'}    // $s_pub,
            name        => $o{'name'}       // 'test-host.cube',
            not_before  => $o{'not_before'} // ( time - 300 ),
            not_after   => $o{'not_after'}  // ( time + 86400 ),
            scope       => $o{'scope'}      // '',
        }
    );
    die 'dlg build' if not defined $st;
    my $sig = Crypt::Ed25519::sign( $st, $i_pub, $i_priv );
    $sig = ~$sig if $o{'bad_sig'};
    return $statement->( 'wire', $st, $sig );
}

## ---------------------------------------------------------------------- ##
## the sender : crypt.C25519.sign_data stubbed to sign with S             ##

$code{'crypt.C25519.sign_data'} = sub {
    my $msg_ref = shift;
    return Crypt::Ed25519::sign( $$msg_ref, $s_pub, $s_priv );
};
$data{'discover'}{'crypt'}{'key_name'} = 'protocol-7.base';
$keys{'C25519'}{'protocol-7.base'} = { 'public' => $s_pub };

## a HOST announce payload matching discover.process_host_packet ##
my $host_payload = "HOST[ testhost ] {\n              192.168.0.5 "
    . " aa:bb:cc:dd:ee:ff  <eth0>\n              }\n";

## build a full ANNOUNCE packet with [ or without ] a .dlg in the file ##
sub make_packet {
    my ($wire) = @ARG;
    if ( defined $wire ) {
        open( my $fh, '>', $dlg_path ) or die "dlg : $OS_ERROR";
        print {$fh} "$wire\n";
        close($fh);
    } else {
        unlink $dlg_path;
    }
    ## header + dlg are rebuilt per call for the test ##
    delete $data{'discover'}{'announce_msg_header'};
    return $code{'discover.format_discover_mcast_packet'}
        ->( 'ANNOUNCE', $host_payload );
}

## reset the receiver's per-run state ##
sub reset_receiver {
    delete $data{'hosts'};
    delete $data{'discover.host-root'};
    delete $data{'discover.host-root-log'};
    delete $data{'discover.ntime_watermark'};
    delete $data{'discover.nodes-trust'};
    @logged     = ();
    @complaints = ();
    @nodes_sent = ();
    return;
}

## the host entry the receiver stored [ exactly one, by L13 of the key ] ##
sub host_entry {
    my @id = grep { ref $data{'hosts'}{$ARG} eq 'HASH' }
        keys $data{'hosts'}->%*;
    return undef if @id != 1;
    return $data{'hosts'}{ $id[0] };
}

######################################################################
say ': sender [ discover.format_discover_mcast_packet ]';
{
    delete $data{'discover'}{'dlg'};    ## reset the change tracker ##
    @logged = ();
    my $wire   = dlg();
    my $packet = make_packet($wire);
    ok( defined $packet && $packet =~ m|^ {3}dlg:\Q$wire\E$|m,
        'valid .dlg : shipped as a 3-space "dlg:" field'
    );
    ok( logged_at( 2, qr{announcing host delegation} ),
        '  :.. a newly seen delegation is noted at level 2'
    );
    ## once per change : the same state does not log again ##
    @logged = ();
    make_packet($wire);
    ok( !logged_at( 2, qr{announcing host delegation} ),
        '  :.. unchanged : not logged again' );

    ## no .dlg readable : sent without it, level 1 log once per change ##
    @logged = ();
    my $no_dlg = make_packet(undef);
    ok( $no_dlg !~ m|^ {3}dlg:|m, 'no .dlg : packet carries no dlg field' );
    ok( logged_at( 1, qr{not readable} ),
        '  :.. the no-delegation case logs once at level 1' );
    @logged = ();
    make_packet(undef);
    ok( !logged_at( 1, qr{not readable} ),
        '  :.. still unavailable : not logged again' );
}

######################################################################
say ': receiver trust states [ process_incoming_packet -> host_packet ]';

$data{'discover'}{'notify-nodes-zenka'} = 'yes';
$data{'discover'}{'cfg'}{'nodes'}{'host_status_command'}
    = 'cube.nodes.host-status';

## offered : valid delegation, empty pin store ##
clear_pins();
reset_receiver();
{
    my $packet = make_packet( dlg() );
    $code{'discover.process_incoming_packet'}->( $packet, 2 );
    my $e = host_entry();
    ok( ref $e eq 'HASH' && $e->{'trust'} eq 'offered',
        'offered : valid delegation, root not pinned'
    );
    ok( ref $e eq 'HASH' && ( $e->{'root_fp'} // '' ) eq $hr_fp,
        '  :.. root_fp is the host-root fingerprint'
    );
    ok( ref $e eq 'HASH'
            && ( $e->{'delegated_name'} // '' ) eq 'test-host.cube',
        '  :.. delegated_name carried through'
    );
    ok( scalar(@nodes_sent)
            && $nodes_sent[0]->{'call_args'}{'args'} eq
            "online testhost $hr_fp offered",
        '  :.. nodes route carries root_fp + trust'
    );
}

## pinned : the fingerprint is in the pin store ##
clear_pins();
write_pin( 'testhost_42', $hr_fp );
reset_receiver();
{
    my $packet = make_packet( dlg() );
    $code{'discover.process_incoming_packet'}->( $packet, 2 );
    my $e = host_entry();
    ok( ref $e eq 'HASH' && $e->{'trust'} eq 'pinned',
        'pinned : root_fp present in the pin store'
    );
}

## pinned detection ignores an old 52 char [ S ] pin ##
clear_pins();
write_pin( 'legacy_42', substr( $b32->($s_pub), 0, 52 ) );
reset_receiver();
{
    my $packet = make_packet( dlg() );
    $code{'discover.process_incoming_packet'}->( $packet, 2 );
    my $e = host_entry();
    ok( ref $e eq 'HASH' && $e->{'trust'} eq 'offered',
        'old 52 char pin ignored : offered, never pinned'
    );
}
clear_pins();

## unverified : no delegation field ##
reset_receiver();
{
    my $packet = make_packet(undef);
    ok( $packet !~ m|^ {3}dlg:|m, '  [ no dlg line in the packet ]' );
    $code{'discover.process_incoming_packet'}->( $packet, 2 );
    my $e = host_entry();
    ok( ref $e eq 'HASH' && $e->{'trust'} eq 'unverified',
        'unverified : no delegation field' );
    ok( ref $e eq 'HASH' && !exists $e->{'root_fp'},
        '  :.. no root_fp stored' );
}

## invalid : a delegation that fails verify -> packet dropped ##
reset_receiver();
{
    my $packet = make_packet( dlg( bad_sig => 1 ) );
    my $ret    = $code{'discover.process_incoming_packet'}->( $packet, 2 );
    ok( !defined host_entry(),
        'invalid [ bad signature ] : packet dropped, no entry' );
    ok( logged_at( 0, qr{invalid host-root delegation} ),
        '  :.. logged at level 0' );
}

## invalid : subject is not the announcing host key -> dropped ##
reset_receiver();
{
    my $packet = make_packet( dlg( subject => $x_pub ) );
    $code{'discover.process_incoming_packet'}->( $packet, 2 );
    ok( !defined host_entry(),
        'invalid [ subject mismatch ] : packet dropped' );
    ok( logged_at( 0, qr{invalid host-root delegation} ),
        '  :.. logged at level 0' );
}

## invalid : a parseable-looking but corrupt wire -> dropped ##
reset_receiver();
{
    my $packet = make_packet( $b32->( 'x' x 120 ) );
    $code{'discover.process_incoming_packet'}->( $packet, 2 );
    ok( !defined host_entry(), 'invalid [ unparsable ] : packet dropped' );
}

## root_fp change : packet dropped, old entry kept + marked invalid ##
reset_receiver();
{
    ## first : the known-good host-root ##
    $code{'discover.process_incoming_packet'}->( make_packet( dlg() ), 2 );
    my $e1 = host_entry();
    ok( ref $e1 eq 'HASH' && ( $e1->{'root_fp'} // '' ) eq $hr_fp,
        'root change : first packet establishes the root'
    );
    @logged = ();
    ## second : a DIFFERENT, valid host-root for the same host key ##
    $code{'discover.process_incoming_packet'}
        ->( make_packet( dlg( issuer => [ $fr_pub, $fr_priv ] ) ), 2 );
    my $e2 = host_entry();
    ok( ref $e2 eq 'HASH' && $e2->{'trust'} eq 'invalid',
        '  :.. second [ changed ] root : trust invalid'
    );
    ok( ref $e2 eq 'HASH' && ( $e2->{'root_fp'} // '' ) eq $hr_fp,
        '  :.. the OLD root_fp is kept, the new one not adopted'
    );
    ok( logged_at( 0, qr{host-root changed for 'testhost' : dropping} ),
        '  :.. logged "host-root changed" at level 0' );
    ok( ref $e2 eq 'HASH' && $e1 == $e2,
        '  :.. packet DROPPED : the entry is the old one, not rebuilt' );
    ## repeats : adaptive log level, capped at 3 [ flood protection ] ##
    my @levels;
    for ( 1 .. 5 ) {
        @logged = ();
        $code{'discover.process_incoming_packet'}
            ->( make_packet( dlg( issuer => [ $fr_pub, $fr_priv ] ) ), 2 );
        my ($hit) = grep { $ARG->[1] =~ m{host-root changed} } @logged;
        push @levels, defined $hit ? $hit->[0] : -1;
    }
    ok( "@levels" eq '1 2 3 3 3',
        "  :.. repeats logged at rising levels [ @levels ], capped at 3" );
}

######################################################################
say ': nodes gets trust CHANGES of a host that stays online';

clear_pins();
reset_receiver();
{
    my $args = sub { $nodes_sent[ $ARG[0] ]->{'call_args'}{'args'} // '' };

    $code{'discover.process_incoming_packet'}->( make_packet( dlg() ), 2 );
    ok( @nodes_sent == 1 && $args->(0) eq "online testhost $hr_fp offered",
        'first packet : nodes told [ offered ]' );

    $code{'discover.process_incoming_packet'}->( make_packet( dlg() ), 2 );
    ok( @nodes_sent == 1, '  :.. same trust again : nothing sent' );

    write_pin( 'testhost_42', $hr_fp );
    $code{'discover.process_incoming_packet'}->( make_packet( dlg() ), 2 );
    ok( @nodes_sent == 2 && $args->(1) eq "online testhost $hr_fp pinned",
        'root pinned meanwhile : nodes told [ pinned ], no re-appearance'
    );

    $code{'discover.process_incoming_packet'}
        ->( make_packet( dlg( issuer => [ $fr_pub, $fr_priv ] ) ), 2 );
    ok( @nodes_sent == 3 && $args->(2) eq "online testhost $hr_fp invalid",
        'root changed : nodes told [ invalid ] with the OLD root_fp'
    );

    $code{'discover.process_incoming_packet'}
        ->( make_packet( dlg( issuer => [ $fr_pub, $fr_priv ] ) ), 2 );
    ok( @nodes_sent == 3, '  :.. repeated changed root : nothing sent' );
}
clear_pins();

######################################################################
say ': the old .sig.* lines are gone from the packet';
{
    my $packet = make_packet( dlg() );
    ok( $packet !~ m|^ {3}[A-Z0-9_.\-]{1,32}:[A-Z2-7]{103}$|m,
        'no 3-space "<name>:<sig>" signature line'
    );
    ok( $packet =~ m|^ {3}dlg:[A-Z2-7]+$|m,
        '  :.. a single 3-space "dlg:" field instead' );
    ## round trip : the dlg in the packet parses + verifies for S ##
    my ($wire) = $packet =~ m|^ {3}dlg:([A-Z2-7]+)$|m;
    my $r = $code{'trust.verify'}->(
        {   chain   => [$wire],
            anchors => [$hr_fp],
            subject => $s_pub,
            now     => time,
        }
    );
    ok( ref $r eq 'HASH' && $r->{'name'} eq 'test-host.cube',
        '  :.. the packet .dlg round-trips [ build -> parse -> verify ]'
    );
}

######################################################################
say ': discover.cmd.host_details shows root_fp, delegated_name, trust';
clear_pins();
write_pin( 'testhost_42', $hr_fp );
reset_receiver();
{
    $code{'discover.process_incoming_packet'}->( make_packet( dlg() ), 2 );
    my $r = $code{'discover.cmd.host_details'}->( { 'args' => 'testhost' } );
    my $out = ref $r eq 'HASH' ? ( $r->{'data'} // '' ) : '';
    ok( $out =~ m|trust : pinned|,       'trust shown' );
    ok( $out =~ m|root_fp : \Q$hr_fp\E|, 'root_fp shown [ 77 chars ]' );
    ok( $out =~ m|delegated_name : test-host\.cube|,
        'delegated_name shown VERBATIM [ not uppercased ]'
    );
}
clear_pins();

my @unexpected
    = grep { !m{Use of uninitialized|no read permissions} } @perl_warnings;
ok( !@unexpected, 'no unexpected perl warnings' );
say "         $ARG" for @unexpected;

say '';
say "passed : $pass_count  failed : $fail_count";
exit( $fail_count ? 1 : 0 );

#,,,,,,,,,,.,,,..,,,.,,,.,.,.,,,,,..,,...,.,.,..,,...,..,,..,,,.,,,,.,...,,,.,
#TJCSK4VKBSLOG6KXQ5HUL2Z3JSEXIK3XF4ZBLF2BPV4YWMJVLNUZY75V6KXBFDZMS5SOGVL7GL37A
#\\\|Y7J5WKLPTIGKVD77GAC665TBDQC4OEH42AT627UU46ILCT3KYDR \ / AMOS7 \ YOURUM ::
#\[7]I5L67RJMLG53MNOG7FBV2LHKGB2HLWFZLM4HMJRVNR3ZLOV6F4CY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
