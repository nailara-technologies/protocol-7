#!/usr/bin/perl

# [ scenario 2: quic-hysteria transport selection + bearer credential ]

use v5.24;
use strict;
use warnings;
use English;

use File::Spec;
use FindBin qw| $RealBin |;
use lib File::Spec->catdir( $RealBin, 'lib' );
use CredMeshTest qw|
    harness_assert temp_dir p7c_eval
    start_echo_server stop_echo_server get_zenka_log
    |;

use IO::Socket::IP;

my $scenario = 2;
my $verbose  = $ENV{'CREDMESH_TEST_VERBOSE'} // 0;

# [ real transport type string is quic-hysteria, not hysteria-socks5 ]
my $profile_name = 'atom-test';
my $slot         = 'api.atom-host.bearer';
my $bearer_value = 'test-bearer-token-67890';

# [ pick a mock socks5 proxy port ]
my $socks_port = 34000 + ( int(rand(2000)) );
my $socks_pid  = fork // die "fork: $ERRNO\n";
if ( $socks_pid == 0 ) {
    # [ detach from parent stdout so harness backticks do not wait on us ]
    open STDOUT, '>', '/dev/null' or die "mock socks stdout redirect: $ERRNO\n";
    open STDERR, '>&', 'STDOUT'   or die "mock socks stderr redirect: $ERRNO\n";

    my $listen = IO::Socket::IP->new(
        LocalHost => '127.0.0.1',
        LocalPort => $socks_port,
        Type      => SOCK_STREAM(),
        Listen    => 5,
        ReuseAddr => 1,
    ) or die "mock socks listen: $ERRNO\n";
    while ( my $c = $listen->accept ) {
        my $buf;
        $c->sysread( $buf, 256 );    # [ consume handshake, do nothing ]
        $c->close;
    }
    exit 0;
}

# [ wait for mock socks to be reachable ]
my $ready_deadline = time + 5;
while ( time < $ready_deadline ) {
    my $probe = IO::Socket::IP->new(
        PeerHost => '127.0.0.1',
        PeerPort => $socks_port,
        Type     => SOCK_STREAM(),
        Timeout  => 1,
    );
    last if defined $probe;
    select undef, undef, undef, 0.1;
}

# [ write temporary transport profile ]
my $profile_dir = '/data/projects/protocol-7/data/yaml/transport/profiles';
my $profile_path = File::Spec->catfile( $profile_dir, "$profile_name.yaml" );
my $profile_yaml = <<"YAML";
context:
  destination: atom-test.host
  tags: []

transports:
  - type: quic-hysteria
    endpoint: atom-test.host:443
    proxy_host: 127.0.0.1
    proxy_port: $socks_port
    credential: $slot
    min_quality: { loss_max: 0.95 }

fallback: direct-tcp
YAML

open my $pfh, '>', $profile_path or die "profile write: $ERRNO\n";
print {$pfh} $profile_yaml;
close $pfh;

# [ seed bearer slot ]
my $seed_code = sprintf(
    'my @r; '
    . 'push @r, $code{"cred-mesh.register"}->({slot=>"%s",owner=>"cred-mesh",type=>"bearer-token",sensitivity=>"medium",storage=>"local"})->{data}; '
    . 'push @r, $code{"cred-mesh.rotate"}->({slot=>"%s",new_value=>"%s",reason=>"scenario-2"})->{data}; '
    . 'return join ",", @r;',
    $slot, $slot, $bearer_value
);
my $seed_out = p7c_eval( 'cred-mesh', $seed_code );
print "[ seed ] $seed_out\n" if $verbose;
my $seed_ok = ( defined $seed_out and $seed_out =~ m{rotated} );
harness_assert( $scenario, 'seed bearer slot',
    $seed_ok,
    "register + rotate bearer slot (output: $seed_out)" );

# [ call transport.select in the transport zenka directly ]
my $select_code = sprintf(
    'my $ctx = { request => { domain => "atom-test.host" }, session => { destination => "atom-test.host" } }; '
    . 'my $h = $code{"transport.select"}->($ctx); '
    . 'return defined $h ? YAML::XS::Dump($h) : "undef";'
);
my $handle_yaml = p7c_eval( 'transport', $select_code );
print "[ handle ] $handle_yaml\n" if $verbose;
my $handle = eval { YAML::XS::Load($handle_yaml) };
$handle = undef if defined $handle and not ref $handle;

harness_assert( $scenario, 'transport handle returned',
    ( defined $handle and ref $handle eq 'HASH' ),
    'transport.select returned a handle hashref' );

my $handle_type = $handle->{'type'} // '';
harness_assert( $scenario, 'handle type is quic-hysteria',
    $handle_type eq 'quic-hysteria',
    "expected quic-hysteria, got '$handle_type'" );

# [ bearer value must not appear in transport or proxy logs ]
my $transport_log = get_zenka_log('transport');
my $proxy_log     = get_zenka_log('proxy');
my $leak = 0;
$leak = 1
    if ( defined $transport_log and $transport_log =~ m{\Q$bearer_value\E} )
    or ( defined $proxy_log     and $proxy_log     =~ m{\Q$bearer_value\E} );

harness_assert( $scenario, 'no credential leak in logs',
    ( not $leak ),
    'bearer token did not appear in transport/proxy logs' );

# [ credential resolution produced authorization header inside handle ]
my $auth_header = '';
if ( defined $handle and ref $handle->{'credential'} eq 'HASH' ) {
    my $d = $handle->{'credential'}->{'data'} // {};
    $auth_header = $d->{'inject_header'}->{'Authorization'} // '';
}
harness_assert( $scenario, 'handle carries authorization header',
    $auth_header eq "Bearer $bearer_value",
    "expected 'Bearer $bearer_value', got '$auth_header'" );

# [ cleanup ]
kill 'TERM', $socks_pid;
waitpid $socks_pid, 0;
unlink $profile_path;

exit 0;

# [ end ]

#,,,,,..,,..,,...,...,.,.,,,,,.,,,.,.,,..,,..,..,,...,...,...,,,.,.,.,,,.,,,.,
#C5XJH6BFDVEVGWS227WX6Z4LA76N4WLZW342ML4FTPDO4FG3A6WRPSNNX2NEA7C7CFCM2GVP4YFDQ
#\\\|GQ5FJOFUDXTUXUCDXUDZ6QVLJJVZLZXBOYLPAXMLNP7BTB4ZDQK \ / AMOS7 \ YOURUM ::
#\[7]CII2JSCGJI547PL2DRLODT7PFJZWNHYOVRTQJSTZICE5YWUH7SBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
