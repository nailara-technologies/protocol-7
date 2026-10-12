#!/usr/bin/env perl
use v5.24;
use strict;
use English;
use warnings;

## nameserv stage-3 timestamp delta sync : signed entries, writer chains,   ##
## grants and the accept rules, with real Ed25519 keys and a real host-root ##
## statement [ 2026-10-11, TIMESTAMP-DELTA-SYNC.md 'stage 3 decisions' ].   ##
## host A signs, host B replays A's reply. it compiles the real             ##
## src/nameserv.sync.* modules and drives them with stubs : base.ntime.*,   ##
## chk-sum.bmw.512.B32, format.yaml.*, file.slurp / file.zenka_dir.write,   ##
## base.logs, base32 encode/decode and nameserv.event.emit. no sockets :    ##
## sync connections are plain hashrefs whose 'out' buffer holds the reply   ##
## lines. no zenka started.                                                 ##

use File::Spec;
use Cwd        qw| abs_path |;
use FindBin    qw| $RealBin |;
use File::Temp qw| tempdir |;
use bytes      ();               ## trust.key_id calls bytes::length ##

BEGIN {
    my $root_path = abs_path(
        File::Spec->rel2abs(
            File::Spec->catdir(
                $RealBin, File::Spec->updir, File::Spec->updir
            )
        )
    );
    $main::root_path = $root_path;
}

use constant { TRUE => 5, FALSE => 0, UNKNOWN => 2 };

my $root_path = $main::root_path;

## tiny base32 [ lowercase, no padding ] -- internal consistency only ##

my @b32_alphabet = split //, 'abcdefghijklmnopqrstuvwxyz234567';

sub encode_b32 {
    my $bytes = shift;
    my $bits  = unpack 'B*', $bytes;
    $bits .= '0' x ( 5 - length($bits) % 5 ) if length($bits) % 5;
    return join '',
        map { $b32_alphabet[ oct "0b$ARG" ] } $bits =~ m|(.....)|g;
}

sub decode_b32 {
    my $str  = shift;
    my %val  = map { $b32_alphabet[$ARG] => $ARG } 0 .. 31;
    my $bits = join '', map { sprintf '%05b', $val{$ARG} // return undef }
        split //, lc $str;
    $bits = substr $bits, 0, length($bits) - length($bits) % 8;
    return pack 'B*', $bits;
}

## ntime shims : same shape the real base.ntime.* modules produce ##
## [ base32 of one compressed integer, 4200 ticks per second ]    ##

sub ntime_val { return time() * 4200 }

sub ntime_b32 { return encode_b32( pack 'w', ntime_val() ) }

sub ntime_b32_at {
    my $epoch = shift;
    return encode_b32( pack 'w', $epoch * 4200 );
}

sub ntime_from_b32 {
    my $ts = shift;
    return undef if $ts !~ m|^[a-z2-7]+$|;
    my $bytes = decode_b32($ts);
    return undef if not defined $bytes;
    my @parts = unpack 'w*', $bytes;
    return @parts == 1 ? $parts[0] : undef;
}

## state ##

our %data;
our %code;
our %keys;    ## C25519 key store [ crypt.C25519 ] ##
our $call;    ## cmd modules read the command parameter from here ##

$data{'nameserv'}{'zones'}                         = {};
$data{'nameserv'}{'zone_dir'}                      = '';
$data{'nameserv'}{'cfg'}{'default_ttl'}            = 3900;
$data{'nameserv'}{'cfg'}{'challenge_ttl'}          = 60;
$data{'nameserv'}{'cfg'}{'sync'}{'tombstone_keep'} = 1123200;
$data{'nameserv'}{'sync'}{'conns'}                 = {};

$code{'base.logs'}           = sub { return 1 };
$code{'base.s_warn'}         = sub { return 1 };
$code{'base.str.os_err'}     = sub { return '' };
$code{'nameserv.event.emit'} = sub { return 1 };

## base32 helpers : the real modules swap-load as base32.* ##
$code{'base32.encode'} = sub { return encode_b32( $_[0] ) };
$code{'base32.decode'} = sub { return decode_b32( $_[0] ) };

$code{'base.ntime.b32'}                = sub { return ntime_b32() };
$code{'base.ntime.b32_is_shape_valid'} = sub {
    my $ts = shift // '';
    return FALSE if not length $ts;
    return
          ( $ts =~ m|^\d+(?:\.\d+)?$| ) ? TRUE
        : defined ntime_from_b32($ts)   ? TRUE
        :                                 FALSE;
};
$code{'base.ntime.delta_seconds'} = sub {
    my $start = shift // '';
    my $end   = shift;
    my $start_val
        = $start =~ m|^\d+(?:\.\d+)?$|
        ? $start
        : ntime_from_b32($start);
    return undef if not defined $start_val;
    my $end_val = defined $end ? $end : ntime_val();
    $end_val = ntime_from_b32($end_val)
        if $end_val !~ m|^\d+(?:\.\d+)?$|;
    return undef if not defined $end_val;
    return ( $end_val - $start_val ) / 4200;
};

$code{'chk-sum.bmw.512.B32'} = sub {
    require Digest::BMW;
    my $input = shift;
    my $bytes = ref $input eq 'SCALAR' ? $input->$* : $input;
    return encode_b32( scalar Digest::BMW::bmw_512($bytes) );
};

$code{'format.yaml.dump_str'} = sub {
    require YAML::XS;
    my $yaml = eval { YAML::XS::Dump( $_[0] ) };
    return $@ ? undef : $yaml;
};
$code{'format.yaml.load_str'} = sub {
    require YAML::XS;
    my $yaml = shift // '';
    my $data = eval { YAML::XS::Load($yaml) };
    return $@ ? ( undef, $EVAL_ERROR ) : ( $data, undef );
};
$code{'file.slurp'} = sub {
    my $path = shift;
    open my $fh, '<', $path or return undef;
    local $INPUT_RECORD_SEPARATOR = undef;
    my $content = <$fh>;
    close $fh;
    return \$content;
};

my $sandbox_dir = tempdir( CLEANUP => 1 );
my $var_dir     = File::Spec->catdir( $sandbox_dir, 'var' );
my $zone_dir    = File::Spec->catdir( $var_dir,     'zones' );
mkdir $var_dir;
mkdir $zone_dir;

$data{'nameserv'}{'zone_dir'} = $zone_dir;

$code{'file.zenka_dir.write'} = sub {
    my $rel     = shift;
    my $content = shift;
    my $path    = File::Spec->catfile( $var_dir, split m|/|, $rel );
    open my $fh, '>', $path or return undef;
    print {$fh} $content->$*;
    close $fh;
    return TRUE;
};

## module loader : translate p7 syntax, compile as anonymous sub ##

sub translate_code {
    my $code = shift;
    $code =~ s{<\[([A-Za-z][-\w.]*)\]>(?=->)}{chr(36).qq|code{'$1'}|}eg;
    $code =~ s{<\[([A-Za-z][-\w.]*)\]>}{chr(36).qq|code{'$1'}->()|}eg;
    $code =~ s{<([a-z][-\w.]*)>}{
        my @keys = split m|\.|, $1;
        chr(36).qq|data{'| . join( "'}{'", @keys ) . qq|'}|
    }ge;
    return $code;
}

sub load_module {
    my $name = shift;
    my $path = File::Spec->catfile( $root_path, 'src', $name );
    open my $fh, '<', $path or die "cannot read $path : $OS_ERROR";
    local $INPUT_RECORD_SEPARATOR = undef;
    my $src = <$fh>;
    close $fh;

    ## drop signature block [ last 4 lines starting with # ] ##
    $src =~ s{\n#[^\n]*\z}{\n} while $src =~ m{\n#[,\[\\|:][^\n]*\z};

    ## split out strings and comments, translate code segments only ##
    my @seg = split m{('(?:[^'\\]|\\.)*'|"(?:[^"\\]|\\.)*"|\#[^\n]*)}x,
        $src, -1;
    for ( my $i = 0; $i < @seg; $i += 2 ) {
        $seg[$i] = translate_code( $seg[$i] );
    }
    my $translated = join '', @seg;
    warn qq|===== $name =====\n$translated\n| if $ENV{'P7_DEBUG'};

    my $sub = eval "sub { $translated }";
    die "compile error in $name : $EVAL_ERROR" if $EVAL_ERROR;
    $code{$name} = $sub;
    return $sub;
}

for my $mod (
    qw|
    trust.key_id
    trust.statement
    trust.chain
    trust.verify
    nameserv.entry.identity
    nameserv.sync.key.id
    nameserv.sync.entry.body
    nameserv.sync.sign
    nameserv.sync.writer.own
    nameserv.sync.writer.verify
    nameserv.sync.accept
    nameserv.zone.tombstone.add
    nameserv.zone.tombstone.clear
    nameserv.zone.tombstone.purge
    nameserv.zone.timestamp
    nameserv.zone.checksum
    nameserv.zone.lookup
    nameserv.zone.save
    nameserv.zones.load
    nameserv.cmd.set-record
    nameserv.cmd.add-txt
    nameserv.cmd.remove-txt
    nameserv.cmd.sign-zone
    nameserv.cmd.add-record
    nameserv.sync.entry.encode
    nameserv.sync.entry.decode
    nameserv.sync.since
    nameserv.sync.apply.entry
    nameserv.sync.apply
    nameserv.sync.checksums.verify
    nameserv.sync.client.apply_reply
    |
) {
    load_module($mod);
}

## assertion helpers ##

my $pass_count = 0;
my $fail_count = 0;

sub check {
    my ( $label, $cond ) = @_;
    if ($cond) {
        $pass_count++;
        printf "ok   : %s\n", $label;
    } else {
        $fail_count++;
        printf "FAIL : %s\n", $label;
    }
    return $cond;
}

sub cmd {    ## call a nameserv.cmd.* module with an args string ##
    my $name = shift;
    my $args = shift;
    $call = { 'args' => $args, 'reply_id' => 'test-reply-id' };
    return $code{"nameserv.cmd.$name"}->($call);
}

my $zones = $data{'nameserv'}{'zones'};

## --- a fake sync connection : replies collect in its out buffer ------- ##

my $conn = {
    id          => 'test:1',
    sock        => undef,
    peer        => 'test-peer',
    in          => '',
    out         => '',
    last_active => time,
    wait        => undef,
};
$data{'nameserv'}{'sync'}{'conns'}{ $conn->{'id'} } = $conn;

sub req {    ## feed one protocol line, return the reply lines ##
    my $line = shift;
    ## the real zenka hands the cmd module a fabricated call hash via the  ##
    ## compiled .cmd. header ; the test has no such header, so the package ##
    ## $call carries the same argument                                     ##
    if ( $line =~ m|^last-data-timestamp(?:\s+(\S+))?$| ) {
        my $zone = $1 // '';
        $zone =~ s{\.+$}{};
        $call = { 'args' => lc $zone };
    }
    $code{'nameserv.sync.request'}->( $conn, $line );
    my @reply = split m|\n|, $conn->{'out'};
    $conn->{'out'} = '';
    return @reply;
}

## --- real keys : host-root + sync key of host A, a foreign host-root ---- ##

require Crypt::Ed25519;
require Crypt::Misc;

sub new_key {
    my ( $pub, $priv ) = Crypt::Ed25519::generate_keypair();
    return { public => $pub, private => $priv };
}

my $hr_a   = new_key();    ## host A's host-root ##
my $sync_a = new_key();    ## host A's nameserv-sync key ##
my $hr_x   = new_key();    ## a host-root nobody granted ##
my $sync_x = new_key();

my $hr_a_id   = $code{'trust.key_id'}->( $hr_a->{'public'} );
my $sync_a_id = $code{'trust.key_id'}->( $sync_a->{'public'} );
my $sync_x_id = $code{'trust.key_id'}->( $sync_x->{'public'} );

sub statement {    ## wire of one host-root statement ##
    my ( $issuer, $subject, $name, $not_after ) = @ARG;
    my $st = $code{'trust.statement'}->(
        'build',
        {   issuer_pub  => $issuer->{'public'},
            subject_pub => $subject->{'public'},
            name        => $name,
            not_before  => time - 300,
            not_after   => $not_after // time + 30 * 86400,
            scope       => '',
        }
    );
    return $code{'trust.statement'}->(
        'wire', $st,
        Crypt::Ed25519::sign(
            $st, $issuer->{'public'}, $issuer->{'private'}
        )
    );
}
my $chain_a = statement( $hr_a, $sync_a, 'hosta.nameserv-sync' );

## crypt.C25519 stand-ins : the key store + the .dlg path ##
my $dlg_file = File::Spec->catfile( $sandbox_dir, 'nameserv-sync.dlg' );
$code{'crypt.C25519.delegation_file'} = sub { return $dlg_file };
$code{'crypt.C25519.sign_data'}       = sub {
    my ( $msg_ref, $name ) = @ARG;
    my $key = $keys{'C25519'}{$name} // return undef;
    return Crypt::Ed25519::sign( $msg_ref->$*, $key->{'public'},
        $key->{'private'} );
};

sub write_dlg {
    open my $fh, '>', $dlg_file or die;
    print {$fh} "$ARG[0]\n";
    close $fh;
}

## --- host A : local changes are signed ---------------------------------- ##

$keys{'C25519'}{'nameserv-sync'} = $sync_a;
write_dlg($chain_a);

cmd( 'set-record', 'z.test A www.z.test 10.0.0.1' );
cmd( 'add-txt',    '_acme-challenge.z.test tok-1' );
cmd( 'add-txt',    '_acme-challenge.z.test tok-2' );
cmd( 'remove-txt', '_acme-challenge.z.test tok-1' );

my $zone_a = $zones->{'z.test'};
my ($www) = grep { $ARG->{'name'} eq 'www.z.test' } @{ $zone_a->{'records'} };
check 'local record signed [ body sig writer ]',
    (       defined $www->{'body'}
        and defined $www->{'sig'}
        and $www->{'writer'} eq $sync_a_id );
check 'local tombstone signed',
    ( @{ $zone_a->{'tombstones'} } == 1
        and defined $zone_a->{'tombstones'}[0]{'sig'} );

my ( $own_id, $own_field ) = $code{'nameserv.sync.writer.own'}->();
check 'own writer line ' . 'from the .dlg',
    ( $own_id eq $sync_a_id and defined $own_field );

my @reply_a
    = $code{'nameserv.sync.since'}->( ntime_b32_at(1), 'z.test', FALSE );
check 'reply starts with ' . 'the WRITER line',
    $reply_a[0] =~ m|^WRITER \Q$sync_a_id\E \S+$|;
check 'reply lists 2 records ' . '+ 1 tombstone',
    ( grep {m|^ENTRY \S+ \S+ \S+$|} @reply_a ) == 3;
check 'signed state line',
    ( grep {m|^CHECKSUM z\.test \S+ \S+ \S+ \Q$sync_a_id\E$|} @reply_a ) == 1;

my $sum_a   = $code{'nameserv.zone.checksum'}->( 'z.test', TRUE );
my %store_a = %{$zones};    ## host A's zones, kept for later ##

## --- host B : replays A's reply             ##
## ------------------------------------------ ##

sub become_b {
    %{$zones} = ();
    delete $keys{'C25519'}{'nameserv-sync'};
    delete $data{'nameserv'}{'sync'}{$ARG}
        for qw| writers own_writer full_seen rejected_logged cursor |;
    $data{'nameserv'}{'cfg'}{'sync'}{'writer'} = {@ARG};
}

sub pull {
    return $code{'nameserv.sync.client.apply_reply'}->(
        { phase => 'since', host => 'a', port => 1, full_done => {} }, [@ARG]
    );
}

become_b();
my $res = pull(@reply_a);
check 'no grants : reply refused',
    ( $res->{'result'} eq 'false' and not exists $zones->{'z.test'} );

become_b( $hr_a_id => 'zone:z.test' );
$res = pull(@reply_a);
check 'granted : reply applied',
    ( $res->{'result'} eq 'ok' and $res->{'applied'} == 3 );
check 'B holds the same signed state',
    $code{'nameserv.zone.checksum'}->( 'z.test', TRUE ) eq $sum_a;
check 'tombstone arrived with its ' . 'signature',
    defined $zones->{'z.test'}{'tombstones'}[0]{'sig'};

## relay : B passes A's entries on byte for byte, also after save + load ##
my @entries_a = grep {m|^ENTRY |} @reply_a;
my @relay     = grep {m|^ENTRY |}
    $code{'nameserv.sync.since'}->( ntime_b32_at(1), 'z.test', FALSE );
check 'relay sends the stored bytes unchanged', "@relay" eq "@entries_a";
$code{'nameserv.zone.save'}->('z.test');
$code{'nameserv.zones.load'}->();
@relay = grep {m|^ENTRY |}
    $code{'nameserv.sync.since'}->( ntime_b32_at(1), 'z.test', FALSE );
check '  :.. also after save + load', "@relay" eq "@entries_a";

## --- accept rules                                           ##
## ---------------------------------------------------------- ##

sub signed_entry {    ## ( body b32, sig b32 ) of an entry signed by $key ##
    my ( $key, %f ) = @ARG;
    my $body = $code{'nameserv.sync.entry.body'}
        ->( { zone => 'z.test', ttl => 0, deleted => FALSE, %f } );
    return (
        encode_b32($body),
        encode_b32(
            Crypt::Ed25519::sign(
                $body, $key->{'public'}, $key->{'private'}
            )
        )
    );
}
become_b( $hr_a_id => 'zone:z.test' );
$code{'nameserv.sync.writer.verify'}->( $sync_a_id, $chain_a );

my ( $b, $s ) = signed_entry(
    $sync_a,
    name  => 'x.z.test',
    type  => 'A',
    value => '10.0.0.9',
    ts    => ntime_b32()
);
my ( $ok, $why ) = $code{'nameserv.sync.accept'}->( $b, $s, $sync_a_id );
check 'valid entry accepted', defined $ok;

## a well-formed body with another value under the original signature ##
my $bent = encode_b32(
    $code{'nameserv.sync.entry.body'}->(
        {   zone    => 'z.test',
            name    => 'x.z.test',
            type    => 'A',
            value   => '10.6.6.6',
            ttl     => 0,
            ts      => $code{'nameserv.sync.entry.decode'}->($b)->{'ts'},
            deleted => FALSE
        }
    )
);
( $ok, $why ) = $code{'nameserv.sync.accept'}->( $bent, $s, $sync_a_id );
check 'tampered body refused ' . 'by the signature',
    ( not defined $ok and $why =~ m|signature| );

( $b, $s ) = signed_entry(
    $sync_a,
    name  => 'x.other.test',
    zone  => 'other.test',
    type  => 'A',
    value => '1',
    ts    => ntime_b32()
);
( $ok, $why ) = $code{'nameserv.sync.accept'}->( $b, $s, $sync_a_id );
check 'zone outside ' . 'the grant refused',
    ( not defined $ok and $why =~ m|no grant| );

( $b, $s ) = signed_entry(
    $sync_a,
    name  => 'x.z.test',
    type  => 'A',
    value => '1',
    ts    => ntime_b32_at( time + 3600 )
);
( $ok, $why ) = $code{'nameserv.sync.accept'}->( $b, $s, $sync_a_id );
check 'ts too far ahead refused', ( not defined $ok and $why =~ m|ahead| );

( $b, $s ) = signed_entry(
    $sync_a,
    name  => 'x.z.test',
    type  => 'A',
    value => '1',
    ts    => ntime_b32_at( time - 20 * 86400 )
);
( $ok, $why ) = $code{'nameserv.sync.accept'}->( $b, $s, $sync_a_id );
check 'ts older than the tombstone ' . 'window refused',
    ( not defined $ok and $why =~ m|old| );

## name: grant : only that TXT name, records and tombstones ##
become_b( $hr_a_id => 'name:_acme-challenge.z.test' );
$code{'nameserv.sync.writer.verify'}->( $sync_a_id, $chain_a );
( $b, $s ) = signed_entry(
    $sync_a,
    name  => '_acme-challenge.z.test',
    type  => 'TXT',
    value => 't',
    ts    => ntime_b32()
);
check 'name grant : its TXT accepted',
    defined scalar $code{'nameserv.sync.accept'}->( $b, $s, $sync_a_id );
( $b, $s ) = signed_entry(
    $sync_a,
    name    => 'www.z.test',
    type    => 'A',
    value   => '10.0.0.1',
    ts      => ntime_b32(),
    deleted => TRUE
);
( $ok, $why ) = $code{'nameserv.sync.accept'}->( $b, $s, $sync_a_id );
check 'name grant : a tombstone for another name refused',
    ( not defined $ok and $why =~ m|no grant| );

## --- writer chains                                         ##
## --------------------------------------------------------- ##

become_b( $hr_a_id => 'zone:z.test' );
( $ok, $why )
    = $code{'nameserv.sync.writer.verify'}
    ->( $sync_x_id, statement( $hr_x, $sync_x, 'hostx.nameserv-sync' ) );
check 'writer under an ungranted ' . 'host-root refused',
    ( not defined $ok and $why =~ m|verify| );
( $ok, $why )
    = $code{'nameserv.sync.writer.verify'}
    ->( $sync_a_id, statement( $hr_a, $sync_a, 'hosta.cube' ) );
check 'a cube statement is no sync ' . 'writer',
    ( not defined $ok and $why =~ m|sync key statement| );
( $ok, $why ) = $code{'nameserv.sync.writer.verify'}->(
    $sync_a_id, statement( $hr_a, $sync_a, 'hosta.nameserv-sync', time - 10 )
);
check 'expired ' . 'delegation refused',
    ( not defined $ok and $why =~ m|expired| );
( $ok, $why )
    = $code{'nameserv.sync.writer.verify'}->( $sync_x_id, $chain_a );
check 'chain of another ' . 'key refused',
    ( not defined $ok and $why =~ m|not this writer| );

## --- equal ts : the lower signature wins, in either order ##
## -----------------                                        ##

$code{'nameserv.sync.writer.verify'}->( $sync_a_id, $chain_a );
my $tie_ts = ntime_b32();
my @tie    = map {
    my ( $tb, $ts_sig ) = signed_entry(
        $sync_a,
        name  => 'alias.z.test',
        type  => 'CNAME',
        value => $ARG,
        ts    => $tie_ts
    );
    scalar $code{'nameserv.sync.accept'}->( $tb, $ts_sig, $sync_a_id );
} qw| one.z.test two.z.test |;
my @winner;
for my $order ( [ 0, 1 ], [ 1, 0 ] ) {
    delete $zones->{'z.test'};
    $code{'nameserv.sync.apply.entry'}->( 'z.test', $tie[$ARG] ) for @$order;
    my ($rec)
        = grep { $ARG->{'name'} eq 'alias.z.test' }
        @{ $zones->{'z.test'}{'records'} };
    push @winner, $rec->{'value'};
}
check 'equal ts : same winner in either ' . 'order',
    ( defined $winner[0] and $winner[0] eq $winner[1] );

## --- sign-zone : unsigned records of older \ hand-written zones ##
## ----------                                                     ##

%{$zones} = ();
$keys{'C25519'}{'nameserv-sync'} = $sync_a;
$zones->{'old.test'} = {
    serial  => 1,
    ttl     => 3900,
    records => [
        { name => 'old.test', type => 'NS', value => 'dn0000.example' },
        {   name  => 'www.old.test',
            type  => 'A',
            value => '10.0.0.5',
            ts    => ntime_b32()
        },
    ],
};
my $r = cmd( 'sign-zone', '' );
check 'sign-zone without a zone : ' . 'usage',
    ( $r->{'mode'} eq 'false' and $r->{'data'} =~ m|usage| );
$r = cmd( 'sign-zone', ':missing:' );
check ':missing: signs the unsigned zone',
    ( $r->{'mode'} eq 'size' and $r->{'data'} =~ m|old\.test : 2 signed| );
check '  :.. every record signed, missing ts set',
    ( 2 == grep { defined $ARG->{'sig'} and length $ARG->{'ts'} }
        @{ $zones->{'old.test'}{'records'} } );
my $sig_before = $zones->{'old.test'}{'records'}[1]{'sig'};
$r = cmd( 'sign-zone', ':missing:' );
check ':missing: with nothing left', $r->{'data'} =~ m|no zone with unsigned|;
$r = cmd( 'sign-zone', 'old.test' );
check 'signed records stay untouched',
    (       $r->{'data'} =~ m|0 signed|
        and $zones->{'old.test'}{'records'}[1]{'sig'} eq $sig_before );

## --- add-record : one more value, the others stay ##
## ------------------------                         ##

$r = cmd( 'add-record', 'old.test NS old.test dn0110.example' );
my @ns = grep { $ARG->{'type'} eq 'NS' } @{ $zones->{'old.test'}{'records'} };
check 'add-record keeps the existing NS',
    ( @ns == 2 and grep { $ARG->{'value'} eq 'dn0000.example' } @ns );
check '  :.. the new one is signed',
    ( grep { $ARG->{'value'} eq 'dn0110.example' and defined $ARG->{'sig'} }
        @ns );
$r = cmd( 'add-record', 'old.test NS old.test dn0110.example' );
check 'identical record : no-op',
    ( $r->{'data'} =~ m|already present|
        and 2 == grep { $ARG->{'type'} eq 'NS' }
        @{ $zones->{'old.test'}{'records'} } );
$r = cmd( 'add-record', 'old.test A www.elsewhere.test 10.0.0.1' );
check 'name outside the zone refused',
    ( $r->{'mode'} eq 'false' and $r->{'data'} =~ m|not in| );

printf "\npassed : %d  failed : %d\n", $pass_count, $fail_count;
exit( $fail_count ? 1 : 0 );

#,,..,..,,,.,,,,,,,,,,,..,...,.,,,...,.,.,...,..,,...,...,..,,,,.,,,,,..,,,..,
#BC4OSA4OOQGZJNUEFOUFRGHF2TDMJ3BICH36HKCN6TPK2G24I3CM5EZLBINEKJLYIT6X5BJ3KXFYW
#\\\|M5GTOIGB22L2OE5YUBPC5VI5L7AUPMAJ6OLSMUTGO6PMQHUN46X \ / AMOS7 \ YOURUM ::
#\[7]CKWE4JNQTUO4UMEUDS5SGAUYMMHG3CEH4VY35GBUYARFQU36VACY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
