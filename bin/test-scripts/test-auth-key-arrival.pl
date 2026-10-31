#!/usr/bin/env perl
use v5.32;
use strict;
use warnings;
use bytes;
use English;

use Cwd qw| abs_path |;
use File::Spec;
use FindBin    qw| $RealBin |;
use File::Temp qw| tempdir |;

BEGIN {
    my $up_dir    = File::Spec->updir;
    my $root_path = abs_path(
        File::Spec->rel2abs(
            File::Spec->catdir( $RealBin, $up_dir, $up_dir )
        )
    );
    unshift @INC, File::Spec->catdir( $root_path, qw| data lib-path pm | );
    $main::root_path = $root_path;
}

use AMOS7::Protocol::P7Syntax qw| p7_syntax__translate |;
use Crypt::Ed25519;
use Crypt::Misc;
use File::Spec::Functions qw| catdir catfile |;

use constant TRUE  => 5;
use constant FALSE => 0;

our %code;
our %data;
our %keys;
my $pass = 0;
my $fail = 0;

sub ok ($;$) {
    my ( $condition, $label ) = @ARG;
    if ($condition) { $pass++; say "  ok   : $label"; return }
    $fail++;
    say "  FAIL : $label";
    return;
}

sub compile_module {
    my $name = shift;
    my $path = File::Spec->catfile( $main::root_path, 'src', $name );
    open my $fh, '<:raw', $path or die "cannot read $path : $!";
    my $source = do { local $INPUT_RECORD_SEPARATOR = undef; <$fh> };
    close $fh;
    my $translated = p7_syntax__translate($source);
    my $cref = eval "no bytes; sub {\n# line 1 \"$name\"\n$translated\n}";
    die "compile failed for $name : $EVAL_ERROR" if not defined $cref;
    $code{$name} = $cref;
    return;
}

my $home = tempdir( 'p7-auth-arrival-XXXXXXXX', TMPDIR => 1, CLEANUP => 1 );
my $host_cfg = catdir( $home, qw| host-config | );
mkdir $host_cfg or die "mkdir $host_cfg : $!";

my $clock        = 1000;
my $host_root_id = 'A' x 77;
$code{'base.ntime.b32'}       = sub { return sprintf 'NT%06d', $clock++ };
$code{'base.ntime'}           = sub { return $clock };
$code{'base.host.config_dir'} = sub { return $host_cfg };
$code{'base.get_homedir'}     = sub { return $home };
$code{'base.logs'}            = sub {return};
$code{'base.log'}             = sub {return};
$code{'base.str.os_err'}      = sub { return "$OS_ERROR" };
$code{'crypt.C25519.cmd.host-root-id'}
    = sub { return { qw| mode | => qw| true |, qw| data | => $host_root_id } };
$code{'file.slurp'} = sub {
    my $path = shift;
    open my $fh, '<:raw', $path or return \'';
    my $content = do { local $INPUT_RECORD_SEPARATOR = undef; <$fh> };
    close $fh;
    return \$content;
};
$code{'crypt.C25519.key_vars'} = sub {
    return { qw| uid | => $EUID, qw| gid | => $EGID + 0 };
};

foreach my $module (
    qw| trust.key_id trust.statement trust.chain trust.verify
    authorization.owner_public_key authorization.decision_message authorization.verify_approval
    authorization.key_mapping authorization.buffer.arrive authorization.buffer.approve
    keys.owned_dir keys.authorize_link
    plugin.auth.auth-keypair.validate-incoming-tofu |
) {
    compile_module($module);
}

my ( $owner_pub, $owner_priv )
    = Crypt::Ed25519::generate_keypair( "\x11" x 32 );
my ($alice_pub) = Crypt::Ed25519::generate_keypair( "\x12" x 32 );
my ($bob_pub)   = Crypt::Ed25519::generate_keypair( "\x13" x 32 );
my ($carol_pub) = Crypt::Ed25519::generate_keypair( "\x14" x 32 );
my ($dave_pub)  = Crypt::Ed25519::generate_keypair( "\x15" x 32 );
my ( $other_pub, $other_priv )
    = Crypt::Ed25519::generate_keypair( "\x16" x 32 );
my $b32    = sub { Crypt::Misc::encode_b32r(shift) };
my $arrive = sub {
    my ( $pub, $channel, $source, $user, @extra ) = @ARG;
    return $code{'authorization.buffer.arrive'}->(
        {   qw| public_b32 |     => $b32->($pub),
            qw| channel |        => $channel,
            qw| source |         => $source,
            qw| requested_user | => $user,
            qw| requested_role | => qw| cube |,
            qw| now |            => 2000,
            @extra,
        }
    );
};

my $first = $arrive->( $alice_pub, qw| manual |, qw| console |, qw| alice | );
ok( $first->{'mode'} eq qw| true |, 'manual arrival accepted' );
ok( $first->{'data'}->{'type'} eq qw| key_arrival |,
    'entry type is key_arrival' );
ok( length( $first->{'data'}->{'fingerprint'} ) == 77,
    'full fingerprint stored' );
my $id = $first->{'data'}->{'id'};

my $duplicate
    = $arrive->( $alice_pub, qw| discover |, qw| lan |, qw| alice | );
ok( $duplicate->{'data'}->{'id'} eq $id, 'duplicate merged by fingerprint' );
ok( join( ',', $duplicate->{'data'}->{'channels'}->@* ) eq 'manual,discover',
    'channels appended'
);
ok( $duplicate->{'data'}->{'state'} eq qw| pending |,
    'duplicate count never approves' );
ok( $duplicate->{'data'}->{'first_seen'} == 2000
        && $duplicate->{'data'}->{'last_seen'} == 2000,
    'first and last seen retained'
);

my $unsigned
    = $code{'authorization.buffer.approve'}->( $id, 'A' x 103, 2001 );
ok( $unsigned->{'mode'} eq qw| false |
        && $unsigned->{'data'} =~ m|owner public key not configured|,
    'approval without owner key fails closed with clear reason'
);

$data{'authorization'}{'owner'}{'public_key'} = $b32->($owner_pub);
my $bad_sig = $b32->(
    Crypt::Ed25519::sign( 'wrong decision', $other_pub, $other_priv ) );
my $bad = $code{'authorization.buffer.approve'}->( $id, $bad_sig, 2001 );
ok( $bad->{'mode'} eq qw| false |
        && $data{'authorization.buffer'}->{$id}->{'state'} eq qw| pending |,
    'signature from another key refused'
);

my $message = $code{'authorization.decision_message'}
    ->( $data{'authorization.buffer'}->{$id} );
my $signature
    = $b32->( Crypt::Ed25519::sign( $message, $owner_pub, $owner_priv ) );
my $approved
    = $code{'authorization.buffer.approve'}->( $id, $signature, 2001 );
ok( $approved->{'mode'} eq qw| true |,
    'valid owner-signed approval accepted'
);
my $pin = catfile( $host_cfg, qw| auth remote-keys incoming alice.public | );
ok( -f $pin && !-l $pin, 'approval writes host-local public pin' );
my $link = catfile( $host_cfg,
    qw| auth remote-keys authorized cube alice.public | );
ok( -l $link && readlink($link) eq $pin,
    'approval reuses authorized role link'
);
ok( $code{'file.slurp'}->($pin)->$* eq $b32->($alice_pub) . "\n",
    'only public half stored' );

$host_root_id = 'B' x 77;
my ( $replay, $replay_reason )
    = $code{'authorization.verify_approval'}
    ->( $data{'authorization.buffer'}->{$id}, $signature );
ok( !$replay && $replay_reason =~ m|owner signature not valid|,
    'owner approval cannot be replayed on another host-root id'
);
$host_root_id = 'A' x 77;

my $home_remote     = catdir( $home,        qw| .n remote-keys | );
my $home_incoming   = catdir( $home_remote, qw| incoming | );
my $home_authorized = catdir( $home_remote, qw| authorized cube | );
mkdir catdir( $home, qw| .n | )                or die 'mkdir .n';
mkdir $home_remote                             or die 'mkdir remote-keys';
mkdir $home_incoming                           or die 'mkdir home incoming';
mkdir catdir( $home_remote, qw| authorized | ) or die 'mkdir home authorized';
mkdir $home_authorized                         or die 'mkdir home role';
my $home_pin = catfile( $home_incoming, qw| alice.public | );
open my $home_fh, '>:raw', $home_pin or die "write $home_pin : $!";
print {$home_fh} $b32->($alice_pub), "\n";
close $home_fh;
open my $host_fh, '>:raw', $pin or die "write $pin : $!";
print {$host_fh} $b32->($dave_pub), "\n";
close $host_fh;
my $cross_registry
    = $code{ 'plugin.auth.auth-keypai' . 'r.validate-incoming-tofu' }
    ->( 7, qw| cube alice |, $b32->($alice_pub), qw| peer |, 42 );
ok( $cross_registry == 1,
    'home pin A stays unapproved when host registry approved key B' );

$data{'authorization'}{'buffer'}{'rate_limit'} = 1;
my $rate_first
    = $arrive->( $bob_pub, qw| manual |, qw| limited |, qw| bob | );
my $rate_next
    = $arrive->( $dave_pub, qw| manual |, qw| limited |, qw| dave | );
ok( $rate_first->{'mode'} eq qw| true |
        && $rate_next->{'mode'} eq qw| false |
        && $rate_next->{'data'} =~ m|rate limit|,
    'new arrivals rate limited per source'
);
delete $data{'authorization'}{'buffer'}{'rate_limit'};

my $statement = $code{'trust.statement'}->(
    qw| build |,
    {   qw| issuer_pub |  => $owner_pub,
        qw| subject_pub | => $carol_pub,
        qw| name |        => qw| host.user.carol |,
        qw| not_before |  => 1000,
        qw| not_after |   => 3000,
        qw| scope |       => '',
    }
);
my $cert_sig = Crypt::Ed25519::sign( $statement, $owner_pub, $owner_priv );
my $wire = $code{'trust.statement'}->( qw| wire |, $statement, $cert_sig );
my $automatic = $arrive->(
    $carol_pub,  qw| discover |, qw| lan-carol |,
    qw| carol |, qw| chain |,    [$wire]
);
ok( $automatic->{'data'}->{'state'} eq qw| approved |
        && $automatic->{'data'}->{'decision'}->{'method'} eq
        qw| auto_owner_cert |,
    'owner-certified key is the sole automatic approval'
);

my $expiring = $arrive->( $dave_pub, qw| manual |, qw| expiry |, qw| dave | );
my $expired  = $code{'authorization.buffer.approve'}
    ->( $expiring->{'data'}->{'id'}, $signature, 2000 + 86400 );
ok( $expired->{'mode'} eq qw| false | && $expired->{'data'} =~ m|expired|,
    'expired entry cannot be approved' );

say sprintf ': %d passed, %d failed', $pass, $fail;
exit( $fail ? 1 : 0 );

#,,,.,.,.,,..,,,.,,,,,,,.,,..,.,,,,..,,,,,,..,..,,...,...,...,,..,,..,.,.,,..,
#TIW7JAGSG46ZVRXAY23BP5IZDZH55H5WSZG6JKISSQWOKNHWBFUGCAWBDSAC47VHCUPZIAQPLLGGQ
#\\\|HBALF4WFQECAAN752DPA7OJRPKGHAVLSNJ5MBWOBB53Q4QMEDK2 \ / AMOS7 \ YOURUM ::
#\[7]IWFBCP5V6M7CWH2QQTZQN5UQYV5USZAJ2EYCU4MZDE4ELDR4IWBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
