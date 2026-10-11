#!/usr/bin/env perl
use v5.24;
use strict;
use English;
use warnings;

## nameserv stage-2 timestamp delta sync : the unsigned tcp line protocol, ##
## the sync-pull apply logic and the waiter wake path                      ##
## [ 2026-10-11, data/md/design/TIMESTAMP-DELTA-SYNC.md stage 2 ] compiles ##
## the real src/nameserv.sync.* modules and drives them with stubs :       ##
## base.ntime.*, chk-sum.bmw.512.B32, format.yaml.*, file.slurp /          ##
## file.zenka_dir.write, base.logs, base32 encode/decode and               ##
## nameserv.event.emit. no sockets : sync connections are plain hashrefs   ##
## whose 'out' buffer holds the reply lines. no zenka started.             ##

use File::Spec;
use Cwd        qw| abs_path |;
use FindBin    qw| $RealBin |;
use File::Temp qw| tempdir |;

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
    nameserv.cmd.last-data-timestamp
    nameserv.cmd.set-record
    nameserv.sync.entry.encode
    nameserv.sync.entry.decode
    nameserv.sync.since
    nameserv.sync.conn.flush
    nameserv.sync.conn.write
    nameserv.sync.conn.close
    nameserv.sync.request
    nameserv.sync.notify
    nameserv.sync.apply.entry
    nameserv.sync.apply
    nameserv.sync.checksums.verify
    nameserv.sync.client.apply_reply
    nameserv.cmd.sync-pull
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

## --- ENTRY encode/decode round trip ----------------------------------- ##

my $entry = {
    zone    => 'test.zone',
    name    => 'www.test.zone',
    type    => 'TXT',
    value   => 'v=spf1-x',
    ttl     => 3900,
    ts      => ntime_b32(),
    deleted => FALSE,
};

my $encoded = $code{'nameserv.sync.entry.encode'}->($entry);
check 'entry encodes ' . 'to base32',
    ( defined $encoded and $encoded =~ m|^[a-z2-7]+$| );

my $decoded = $code{'nameserv.sync.entry.decode'}->($encoded);
check 'entry decode round trip',
    (       ref $decoded eq qw| HASH |
        and $decoded->{'zone'} eq $entry->{'zone'}
        and $decoded->{'name'} eq $entry->{'name'}
        and $decoded->{'type'} eq $entry->{'type'}
        and $decoded->{'value'} eq $entry->{'value'}
        and $decoded->{'ttl'} eq $entry->{'ttl'}
        and $decoded->{'ts'} eq $entry->{'ts'}
        and $decoded->{'deleted'} == FALSE );

my $tomb_entry = { $entry->%*, ts => ntime_b32(), deleted => TRUE };
my $decoded_tomb
    = $code{'nameserv.sync.entry.decode'}
    ->( $code{'nameserv.sync.entry.encode'}->($tomb_entry) );
check 'tombstone flag round trip',
    ( ref $decoded_tomb eq qw| HASH |
        and $decoded_tomb->{'deleted'} == TRUE );

check 'garbage decode -> undef',
    not defined $code{'nameserv.sync.entry.decode'}->('xyz!not-b32');

my $bad_label = encode_b32(
    pack(
        'Z* n/a* n/a* n/a* n/a* N n/a* n/a*',
        'wrong label', 'z', 'n', 'A', 'v', 0, ntime_b32(), '0'
    )
);
check 'wrong label decode -> undef',
    not defined $code{'nameserv.sync.entry.decode'}->($bad_label);

## --- request parser : all five commands + garbage ---------------------- ##

cmd( 'set-record', 'test.zone A www 10.0.0.1' );
my $ts_new = $zones->{'test.zone'}{'records'}[0]{'ts'};

my @reply = req('last-data-timestamp');
check 'last-data-timestamp set reply',
    ( $reply[0] eq "TRUE $ts_new" and $reply[1] eq qw| . | );

@reply = req('last-data-timestamp test.zone');
my ( $ldt_flag, $ldt_ts, $ldt_sum ) = split m|\s+|, $reply[0];
check 'last-data-timestamp zone reply',
    (       $ldt_flag eq qw| TRUE |
        and $ldt_ts eq $ts_new
        and length $ldt_sum
        and $reply[1] eq qw| . | );

@reply = req('last-data-timestamp no-such.zone');
check 'last-data-timestamp unknown zone',
    ( $reply[0] =~ m|^FALSE unknown zone| and $reply[1] eq qw| . | );

## signed since \ full replies :                 ##
## bin/test-scripts/test-nameserv-sync-stage3.pl ##

my $ts_oldest = ntime_b32_at(1);
cmd( 'set-record', 'test.zone A mail 10.0.0.2' );

## next-data-timestamp holds when nothing is newer ##

my $ts_past = ntime_b32_at( time() - 3900 );
@reply = req("next-data-timestamp since:$ts_past");
my $held_newest = $zones->{'test.zone'}{'records'}[1]{'ts'};
## the newest record is newer than the past ts : immediate reply ##
check 'next-data-timestamp immediate when already newer',
    (       $reply[0] eq "TRUE $held_newest"
        and $reply[1] eq qw| . |
        and not defined $conn->{'wait'} );

## hold with the current newest ts : only a strictly newer record may wake ##
## it                                                                      ##
my $ts_future = $zones->{'test.zone'}{'records'}[1]{'ts'};
@reply = req("next-data-timestamp since:$ts_future");
check 'next-data-timestamp holds the connection',
    (       not scalar @reply
        and ref $conn->{'wait'} eq qw| HASH |
        and $conn->{'wait'}{'since'} eq $ts_future );

## a record change wakes the waiter through the notify module ##

sleep 1;
cmd( 'set-record', 'test.zone A woke 10.0.0.3' );
$code{'nameserv.sync.notify'}->();
@reply = split m|\n|, $conn->{'out'};
$conn->{'out'} = '';
my $woke_ts = $zones->{'test.zone'}{'records'}[2]{'ts'};
check 'notify wakes waiter with the new ts',
    (       $reply[0] eq "TRUE $woke_ts"
        and $reply[1] eq qw| . |
        and not defined $conn->{'wait'} );

## already-newer since gets an immediate reply, no wait ##

@reply = req("next-data-timestamp since:$ts_oldest");
check 'next-data-timestamp immediate for old ts',
    ( $reply[0] =~ m|^TRUE \S+$| and $reply[1] eq qw| . | );

## zone-scoped wait predicate : other zones do not wake it ##

$conn->{'out'} = '';
## == newest : holds until the next second ##
my $other_ts = ntime_b32_at(time);
req("next-data-timestamp test.zone since:$other_ts");
check 'waiter registered', ref $conn->{'wait'} eq qw| HASH |;
cmd( 'set-record', 'other.zone A x 10.0.0.9' );
$code{'nameserv.sync.notify'}->();
check 'other zone change does not wake zone waiter',
    not length $conn->{'out'};
sleep 1;
cmd( 'set-record', 'test.zone A woke2 10.0.0.4' );
$code{'nameserv.sync.notify'}->();
@reply = split m|\n|, $conn->{'out'};
$conn->{'out'} = '';
check 'same zone change wakes zone waiter', $reply[0] =~ m|^TRUE \S+$|;

## garbage input ##

@reply = req('bogus-command');
check 'unknown command -> FALSE',
    ( $reply[0] =~ m|^FALSE unknown command| and $reply[1] eq qw| . | );

@reply = req('since');
check 'since without ts -> FALSE usage', $reply[0] =~ m|^FALSE usage: since|;

@reply = req('since not-a-ts');
check 'since with bad ts -> FALSE', $reply[0] =~ m|^FALSE invalid timestamp|;

@reply = req('full');
check 'full without zone -> FALSE usage', $reply[0] =~ m|^FALSE usage: full|;

@reply = req('full no-such.zone');
check 'full unknown zone -> FALSE', $reply[0] =~ m|^FALSE unknown zone|;

@reply = req('next-data-timestamp');
check 'next-data-timestamp without since -> FALSE',
    $reply[0] =~ m|^FALSE missing since|;

@reply = req('next-data-timestamp since:garbage!');
check 'next-data-timestamp bad ts -> FALSE',
    $reply[0] =~ m|^FALSE invalid timestamp|;

## --- applying entries : newer ts wins, tombstones remove --------------- ##

delete $zones->{'filter.zone'};

my $t1 = ntime_b32_at( time() - 200 );
my $t2 = ntime_b32_at( time() - 100 );
my $t3 = ntime_b32_at( time() - 90 );
my $t4 = ntime_b32_at( time() - 80 );
my $t5 = ntime_b32_at( time() - 70 );

$zones->{'apply.zone'} = {
    records => [
        {   name  => 'host.apply.zone',
            type  => 'A',
            value => '10.0.0.7',
            ts    => $t1
        },
    ],
    serial => time(),
    ttl    => 3900,
};

my $apply_res = $code{'nameserv.sync.apply.entry'}->(
    'apply.zone',
    {   zone    => 'apply.zone',
        name    => 'host.apply.zone',
        type    => 'A',
        value   => '10.0.0.7',
        ttl     => 0,
        ts      => $t2,
        deleted => FALSE,
    }
);
check 'newer ts wins per identity',
    (       $apply_res eq qw| applied |
        and scalar @{ $zones->{'apply.zone'}{'records'} } == 1
        and $zones->{'apply.zone'}{'records'}[0]{'value'} eq '10.0.0.7'
        and $zones->{'apply.zone'}{'records'}[0]{'ts'} eq $t2 );

$apply_res = $code{'nameserv.sync.apply.entry'}->(
    'apply.zone',
    {   zone    => 'apply.zone',
        name    => 'host.apply.zone',
        type    => 'A',
        value   => '10.0.0.7',
        ttl     => 0,
        ts      => $t1,
        deleted => FALSE,
    }
);
check 'older ts ignored',
    (       $apply_res eq qw| ignored |
        and $zones->{'apply.zone'}{'records'}[0]{'ts'} eq $t2 );

## a changed value is a new identity : it is added next to the old value ; ##
## the old value disappears via the writer's tombstone                     ##
$apply_res = $code{'nameserv.sync.apply.entry'}->(
    'apply.zone',
    {   zone    => 'apply.zone',
        name    => 'host.apply.zone',
        type    => 'A',
        value   => '10.0.0.8',
        ttl     => 0,
        ts      => $t2,
        deleted => FALSE,
    }
);
check 'new value added alongside',
    ( $apply_res eq qw| applied |
        and scalar @{ $zones->{'apply.zone'}{'records'} } == 2 );

$apply_res = $code{'nameserv.sync.apply.entry'}->(
    'apply.zone',
    {   zone    => 'apply.zone',
        name    => 'host.apply.zone',
        type    => 'A',
        value   => '10.0.0.7',
        ttl     => 0,
        ts      => $t3,
        deleted => TRUE,
    }
);
check 'value-change tombstone removes the old value',
    (       $apply_res eq qw| removed |
        and scalar @{ $zones->{'apply.zone'}{'records'} } == 1
        and $zones->{'apply.zone'}{'records'}[0]{'value'} eq '10.0.0.8' );

my @kept_tombs = @{ $zones->{'apply.zone'}{'tombstones'} // [] };
check 'tombstone kept with the peer ts',
    (       scalar @kept_tombs == 1
        and $kept_tombs[0]{'deleted'} eq $t3
        and $kept_tombs[0]{'value'} eq '10.0.0.7' );

## a live re-add cancels the tombstone ##
$apply_res = $code{'nameserv.sync.apply.entry'}->(
    'apply.zone',
    {   zone    => 'apply.zone',
        name    => 'host.apply.zone',
        type    => 'A',
        value   => '10.0.0.7',
        ttl     => 0,
        ts      => $t4,
        deleted => FALSE,
    }
);
check 'live re-add cancels tombstone',
    (       $apply_res eq qw| applied |
        and scalar @{ $zones->{'apply.zone'}{'records'} } == 2
        and not scalar @{ $zones->{'apply.zone'}{'tombstones'} // [] } );

## a tombstone for the remaining value removes it ##
$apply_res = $code{'nameserv.sync.apply.entry'}->(
    'apply.zone',
    {   zone    => 'apply.zone',
        name    => 'host.apply.zone',
        type    => 'A',
        value   => '10.0.0.8',
        ttl     => 0,
        ts      => $t5,
        deleted => TRUE,
    }
);
check 'tombstone removes the live record',
    ( $apply_res eq qw| removed |
        and scalar @{ $zones->{'apply.zone'}{'records'} } == 1 );

## newest ts wins across live record and tombstone ##

$apply_res = $code{'nameserv.sync.apply.entry'}->(
    'apply.zone',
    {   zone    => 'apply.zone',
        name    => 'host.apply.zone',
        type    => 'A',
        value   => '10.0.0.7',
        ttl     => 0,
        ts      => $t1,
        deleted => TRUE,
    }
);
check 'old tombstone ignored against a newer re-add',
    ( $apply_res eq qw| ignored |
        and grep { $ARG->{'value'} eq '10.0.0.7' }
        @{ $zones->{'apply.zone'}{'records'} } );

$apply_res = $code{'nameserv.sync.apply.entry'}->(
    'apply.zone',
    {   zone    => 'apply.zone',
        name    => 'host.apply.zone',
        type    => 'A',
        value   => '10.0.0.8',
        ttl     => 0,
        ts      => $t2,
        deleted => FALSE,
    }
);
check 'old record does not resurrect a newer delete',
    ( $apply_res eq qw| ignored |
        and not grep { $ARG->{'value'} eq '10.0.0.8' }
        @{ $zones->{'apply.zone'}{'records'} } );

## whole-set apply uses the entry's own zone ##

$apply_res = $code{'nameserv.sync.apply'}->(
    undef,
    [
        {   zone    => 'new.zone',
            name    => 'www.new.zone',
            type    => 'A',
            value   => '10.1.1.1',
            ttl     => 0,
            ts      => $t2,
            deleted => FALSE,
        }
    ]
);
check 'whole-set apply creates the zone',
    ( $apply_res == 1 and exists $zones->{'new.zone'} );

## --- the sync-pull command surface ------------------------------------- ##

$call = { 'args' => '', 'reply_id' => 'test-reply-id' };
my $res = $code{'nameserv.cmd.sync-pull'}->($call);
check 'sync-pull usage', $res->{'mode'} eq qw| false |
    and $res->{'data'} =~ m|^usage:|;

$call = { 'args' => '127.0.0.1 notaport', 'reply_id' => 'test-reply-id' };
$res  = $code{'nameserv.cmd.sync-pull'}->($call);
check 'sync-pull invalid port', $res->{'mode'} eq qw| false |
    and $res->{'data'} =~ m|invalid port|;

$call = { 'args' => '127.0.0.1 5353', 'reply_id' => '' };
$res  = $code{'nameserv.cmd.sync-pull'}->($call);
check 'sync-pull needs a reply route', $res->{'mode'} eq qw| false |
    and $res->{'data'} =~ m|reply route|;

say '';
say "passed : $pass_count  failed : $fail_count";
exit( $fail_count ? 1 : 0 );

#,,.,,.,.,,.,,,..,.,,,.,,,.,,,,,.,,,,,.,,,,,,,..,,...,...,,..,.,.,...,,,,,...,
#G26IFL7UQ464M4TDUWELRVJJR4SGVZ5ESCIZ6MXQFINV6JSHPOED5F3ZS2B345OFT76E63JFNEBJS
#\\\|UMURNGHQE5YNQCVJ5447YEE354YL4YDRYCS73CJ6RYYSC3DP3O7 \ / AMOS7 \ YOURUM ::
#\[7]3HCPUKAZWPMFZPEFOKPMCTDBAUJUZKHLY2BHRT6VLDFAFNJ2QMBA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
