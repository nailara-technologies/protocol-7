#!/usr/bin/env perl
use v5.24;
use strict;
use English;
use warnings;

## nameserv sync grant patterns + the grant-change re-pull decision         ##
## [ 2026-10-19, TIMESTAMP-DELTA-SYNC.md 'who may write what' ]. a zone:    ##
## item with a '*' label covers exactly acme.<one or more labels>.<rest> [  ##
## zone:acme.*.example.org : never the domain itself, never look-alike      ##
## suffixes, never an empty middle label ] ; zones refused for lack of a    ##
## grant are remembered and a grant-set change re-pulls every remembered    ##
## zone the new grants cover but the old ones did not, once, per peer.  it  ##
## compiles the real src modules and drives them with stubs : base.ntime.*, ##
## base32 encode/decode, base.logs and a recording                          ##
## nameserv.sync.client.start. real Ed25519 keys + a real host-root         ##
## statement. no sockets, no zenka started.                                 ##

use File::Spec;
use Cwd     qw| abs_path |;
use FindBin qw| $RealBin |;
use bytes   ();               ## trust.key_id calls bytes::length ##

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
our %keys;

$code{'base.logs'}   = sub { return 1 };
$code{'base.s_warn'} = sub { return 1 };

$code{'base32.encode'} = sub { return encode_b32( $_[0] ) };
$code{'base32.decode'} = sub { return decode_b32( $_[0] ) };

$code{'base.ntime.b32'}           = sub { return ntime_b32() };
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

## the pulls a grant change schedules, recorded ##
my @pulled;
$code{'nameserv.sync.client.start'} = sub {
    my $params = shift // {};
    push @pulled,
        {
        'host'    => $params->{'host'},
        'port'    => $params->{'port'},
        'zone'    => $params->{'zone'},
        'on_done' => $params->{'on_done'},
        };
    return 'test-pull-id';
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
    nameserv.sync.entry.body
    nameserv.sync.entry.decode
    nameserv.sync.grants.zone_match
    nameserv.sync.grants.renew
    nameserv.sync.grants.pulled
    nameserv.sync.writer.verify
    nameserv.sync.accept
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

## --- real keys : host-root + sync key of the writing host ------------- ##

require Crypt::Ed25519;
require Crypt::Misc;

sub new_key {
    my ( $pub, $priv ) = Crypt::Ed25519::generate_keypair();
    return { public => $pub, private => $priv };
}

my $hr_a   = new_key();    ## the granted host-root ##
my $sync_a = new_key();    ## its nameserv-sync key ##

my $hr_a_id   = $code{'trust.key_id'}->( $hr_a->{'public'} );
my $sync_a_id = $code{'trust.key_id'}->( $sync_a->{'public'} );

my $chain_a = $code{'trust.statement'}->(
    'wire',
    $code{'trust.statement'}->(
        'build',
        {   issuer_pub  => $hr_a->{'public'},
            subject_pub => $sync_a->{'public'},
            name        => 'hosta.nameserv-sync',
            not_before  => time - 300,
            not_after   => time + 30 * 86400,
            scope       => '',
        }
    ),
    Crypt::Ed25519::sign(
        $code{'trust.statement'}->(
            'build',
            {   issuer_pub  => $hr_a->{'public'},
                subject_pub => $sync_a->{'public'},
                name        => 'hosta.nameserv-sync',
                not_before  => time - 300,
                not_after   => time + 30 * 86400,
                scope       => '',
            }
        ),
        $hr_a->{'public'},
        $hr_a->{'private'}
    )
);

sub set_grants {
    $data{'nameserv'}{'cfg'}{'sync'}{'writer'} = { $hr_a_id => shift // '' };
    return;
}

sub verified_writer {
    $code{'nameserv.sync.writer.verify'}->( $sync_a_id, $chain_a );
    return;
}

sub try_entry {    ## accept one entry signed by the sync key ##
    my %f    = @ARG;
    my $body = $code{'nameserv.sync.entry.body'}
        ->( { ttl => 0, deleted => FALSE, ts => ntime_b32(), %f } );
    return $code{'nameserv.sync.accept'}->(
        encode_b32($body),
        encode_b32(
            Crypt::Ed25519::sign(
                $body, $sync_a->{'public'}, $sync_a->{'private'}
            )
        ),
        $sync_a_id
    );
}

## --- grant syntax : the exact zone: semantics stay unchanged ---------- ##

say "\n :. exact zone grant unchanged";

set_grants('zone:acme.example.org');
verified_writer();

my ( $ok, $why ) = try_entry(
    zone  => 'acme.example.org',
    name  => 'acme.example.org',
    type  => 'TXT',
    value => 'token'
);
check 'exact zone : the zone apex accepted', defined $ok;

( $ok, $why ) = try_entry(
    zone  => 'acme.example.org',
    name  => '_acme-challenge.acme.example.org',
    type  => 'TXT',
    value => 'token'
);
check 'exact zone : a name below it accepted', defined $ok;

( $ok, $why ) = try_entry(
    zone  => 'sub.acme.example.org',
    name  => 'sub.acme.example.org',
    type  => 'TXT',
    value => 'token'
);
check 'exact zone : a subzone NOT covered',
    ( not defined $ok and $why =~ m|no grant| );

## --- grant patterns : acme subzones below a domain -------------------- ##

say "\n :. zone:acme.*.example.org";

set_grants('zone:acme.*.example.org');
verified_writer();

( $ok, $why ) = try_entry(
    zone  => 'acme.a.example.org',
    name  => 'acme.a.example.org',
    type  => 'TXT',
    value => 'token'
);
check 'pattern : one middle label accepted', defined $ok;

( $ok, $why ) = try_entry(
    zone  => 'acme.a.b.example.org',
    name  => '_acme-challenge.acme.a.b.example.org',
    type  => 'TXT',
    value => 'token'
);
check 'pattern : two middle labels accepted', defined $ok;

( $ok, $why ) = try_entry(
    zone  => 'acme.example.org',
    name  => 'acme.example.org',
    type  => 'TXT',
    value => 'token'
);
check 'pattern : the domain itself refused',
    ( not defined $ok and $why =~ m|no grant| );

( $ok, $why ) = try_entry(
    zone  => 'example.org',
    name  => 'example.org',
    type  => 'TXT',
    value => 'token'
);
check 'pattern : the bare domain refused',
    ( not defined $ok and $why =~ m|no grant| );

( $ok, $why ) = try_entry(
    zone  => 'mail.example.org',
    name  => 'mail.example.org',
    type  => 'TXT',
    value => 'token'
);
check 'pattern : a zone not starting with acme. refused',
    ( not defined $ok and $why =~ m|no grant| );

( $ok, $why ) = try_entry(
    zone  => 'acme.example.org.evil',
    name  => 'acme.example.org.evil',
    type  => 'TXT',
    value => 'token'
);
check 'pattern : look-alike suffix acme.example.org.evil refused',
    ( not defined $ok and $why =~ m|no grant| );

( $ok, $why ) = try_entry(
    zone  => 'acmex.example.org',
    name  => 'acmex.example.org',
    type  => 'TXT',
    value => 'token'
);
check 'pattern : look-alike prefix acmex.example.org refused',
    ( not defined $ok and $why =~ m|no grant| );

( $ok, $why ) = try_entry(
    zone  => 'acme.example.orgx',
    name  => 'acme.example.orgx',
    type  => 'TXT',
    value => 'token'
);
check 'pattern : look-alike tail acme.example.orgx refused',
    ( not defined $ok and $why =~ m|no grant| );

( $ok, $why ) = try_entry(
    zone  => 'acme..example.org',
    name  => 'acme..example.org',
    type  => 'TXT',
    value => 'token'
);
check 'pattern : empty middle label refused',
    ( not defined $ok and $why =~ m|no grant| );

## '*' must not match a bare dot [ '.+' did : acme...example.org ] ##
foreach my $bad_zone (qw| acme...example.org acme.-x.example.org |) {
    ( $ok, $why ) = try_entry(
        zone  => $bad_zone,
        name  => $bad_zone,
        type  => 'TXT',
        value => 'token'
    );
    check "pattern : malformed labels $bad_zone refused",
        ( not defined $ok and $why =~ m|no grant| );
}

( $ok, $why ) = try_entry(
    zone  => 'acme.a.example.org',
    name  => 'www.example.org',
    type  => 'TXT',
    value => 'token'
);
check 'pattern : a name outside the matched zone refused',
    ( not defined $ok and $why =~ m|no grant| );

( $ok, $why ) = try_entry(
    zone  => 'ACME.Mixed.Example.ORG',
    name  => '_acme-challenge.ACME.Mixed.Example.ORG',
    type  => 'TXT',
    value => 'token'
);
check 'pattern : case-insensitive on the entry side', defined $ok;

( $ok, $why ) = try_entry(
    zone  => 'acme.dot.example.org.',
    name  => '_acme-challenge.acme.dot.example.org.',
    type  => 'TXT',
    value => 'token'
);
check 'pattern : trailing dot on the entry tolerated', defined $ok;

set_grants('zone:acme.*.example.org.');
verified_writer();
( $ok, $why ) = try_entry(
    zone  => 'acme.g.example.org',
    name  => 'acme.g.example.org',
    type  => 'TXT',
    value => 'token'
);
check 'pattern : trailing dot on the grant tolerated', defined $ok;

set_grants('zone:ACME.*.EXAMPLE.ORG');
verified_writer();
( $ok, $why ) = try_entry(
    zone  => 'acme.h.example.org',
    name  => 'acme.h.example.org',
    type  => 'TXT',
    value => 'token'
);
check 'pattern : case-insensitive on the grant side', defined $ok;

## --- name: semantics stay unchanged ------------------------------------ ##

say "\n :. name: grant unchanged";

set_grants('name:_acme-challenge.acme.example.org');
verified_writer();

( $ok, $why ) = try_entry(
    zone  => 'acme.example.org',
    name  => '_acme-challenge.acme.example.org',
    type  => 'TXT',
    value => 'token'
);
check 'name grant : its TXT accepted', defined $ok;

( $ok, $why ) = try_entry(
    zone  => 'acme.example.org',
    name  => '_acme-challenge.acme.example.org',
    type  => 'A',
    value => '192.0.2.77'
);
check 'name grant : a non-TXT refused',
    ( not defined $ok and $why =~ m|no grant| );

( $ok, $why ) = try_entry(
    zone  => 'acme.example.org',
    name  => 'other.acme.example.org',
    type  => 'TXT',
    value => 'token'
);
check 'name grant : another name refused',
    ( not defined $ok and $why =~ m|no grant| );

## --- refused zones are remembered -------------------------------------- ##

say "\n :. refused zone memory";

check 'refusals remembered [ acme.example.org ]',
    $data{'nameserv'}{'sync'}{'refused_zones'}{'acme.example.org'};
check 'refusals remembered [ acme.example.org.evil ]',
    $data{'nameserv'}{'sync'}{'refused_zones'}{'acme.example.org.evil'};

## --- the grant-change re-pull decision --------------------------------- ##

say "\n :. grant-change re-pull";

$data{'nameserv'}{'sync'}{'peers'} = {
    'ns1.example.org:7753' => { host => 'ns1.example.org', port => 7753 },
    '192.0.2.10:7753'      => { host => '192.0.2.10',      port => 7753 },
};

my $refused_set = $data{'nameserv'}{'sync'}{'refused_zones'} = {
    'acme.jobsite.example.org' => TRUE,    ## newly covered by the pattern ##
    'acme.example.org'         => TRUE,    ## covered by the old grant too ##
    'mail.example.org'         => TRUE,    ## never covered                ##
};

set_grants('zone:acme.example.org');
@pulled = ();
$code{'nameserv.sync.grants.renew'}->();
check 'first run : baseline only, no pulls', scalar @pulled == 0;

set_grants('zone:acme.example.org zone:acme.*.example.org');
@pulled = ();
$code{'nameserv.sync.grants.renew'}->();
my @pulled_zones = sort map { $ARG->{'zone'} } @pulled;
check 'grant change : the newly covered zone pulled from both peers',
    (       @pulled_zones == 2
        and $pulled_zones[0] eq 'acme.jobsite.example.org'
        and $pulled_zones[1] eq 'acme.jobsite.example.org' );
check 'grant change : peers taken from the peer set',
    (
    join( ',', sort map { $ARG->{'host'} } @pulled ) eq
        join( ',', sort qw| 192.0.2.10 ns1.example.org | ) );
check 'grant change : the on_done chain set',
    ( grep { $ARG->{'on_done'} eq 'nameserv.sync.grants.pulled' } @pulled )
    == 2;
check 'grant change : the zone the old grant covered not re-pulled',
    ( not grep { $ARG->{'zone'} eq 'acme.example.org' } @pulled );
check 'grant change : the never-covered zone not pulled',
    ( not grep { $ARG->{'zone'} eq 'mail.example.org' } @pulled );

@pulled = ();
$code{'nameserv.sync.grants.renew'}->();
check 'unchanged grants : idempotent, no pulls', scalar @pulled == 0;

$refused_set->{'acme.x.v7.example'} = TRUE;
set_grants('zone:acme.example.org zone:acme.*.v7.example');
@pulled = ();
$code{'nameserv.sync.grants.renew'}->();
@pulled_zones = sort map { $ARG->{'zone'} } @pulled;
check 'second grant change : only the zone the new set newly covers',
    (       @pulled_zones == 2
        and $pulled_zones[0] eq 'acme.x.v7.example'
        and $pulled_zones[1] eq 'acme.x.v7.example' );

set_grants('zone:acme.*.v7.example');
@pulled = ();
$code{'nameserv.sync.grants.renew'}->();
check 'a removal-only change pulls nothing', scalar @pulled == 0;

## --- the on_done drops the zone from the refused list ------------------ ##

say "\n :. grant-change pull completion";

$code{'nameserv.sync.grants.pulled'}
    ->( { target => 'acme.jobsite.example.org' }, { mode => 'true' } );
check 'a successful pull forgets the zone',
    not $data{'nameserv'}{'sync'}{'refused_zones'}
    {'acme.jobsite.example.org'};

$code{'nameserv.sync.grants.pulled'}
    ->( { target => 'acme.x.v7.example' }, { mode => 'false' } );
check 'a failed pull keeps the zone remembered',
    $data{'nameserv'}{'sync'}{'refused_zones'}{'acme.x.v7.example'};

printf "\npassed : %d  failed : %d\n", $pass_count, $fail_count;
exit( $fail_count ? 1 : 0 );

#,,,,,,..,..,,.,,,.,,,,,.,...,...,..,,.,,,,,.,..,,...,...,,.,,,..,,.,,...,.,.,
#XPJRB7CMHG6JPK2UTVSA473OF5XSHKIOIOJOGB5LG4FR34FBWD4CXFFEPNA6YQSPN2QVURJG7PSIU
#\\\|6ZK4IM4QNY5J4OZCRHIZA4X7QZT7EJXQUROTZY7OB7B6YHDT52J \ / AMOS7 \ YOURUM ::
#\[7]BZZTWIKO2MZTYFWCKXJMWG4JRSQZ27BHOYVTWU7ATBATQFF3HQAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
