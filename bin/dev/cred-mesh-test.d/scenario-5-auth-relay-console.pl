#!/usr/bin/perl

# [ scenario 5: console auth-relay fallback ]

use v5.24;
use strict;
use warnings;
use English;

use File::Spec;
use FindBin qw| $RealBin |;
use lib File::Spec->catdir( $RealBin, 'lib' );
use CredMeshTest qw|
    harness_assert temp_dir start_echo_server stop_echo_server
    p7c_eval p7c parse_echo_body slurp_yaml
    |;

my $scenario = 5;
my $verbose  = $ENV{'CREDMESH_TEST_VERBOSE'} // 0;

my $echo_port = 35000 + ( int( rand(2000) ) );
my $echo_log  = File::Spec->catfile( temp_dir(), 'echo-scenario-5.log' );
my $echo_pid  = start_echo_server( $echo_port, $echo_log );
## use a real, locally-resolvable destination (matches scenario 1's
## pattern) instead of a .local hostname -- .local triggers mDNS
## resolution on many systems and can fail with an unrelated-looking
## error (e.g. "Invalid argument") when there's no real mDNS responder,
## rather than a normal "unknown host" failure
my $domain  = "127.0.0.1:$echo_port";
my $payload = 'relay-payload-xyz';

# [ deliberately do not seed a session slot for the test domain ]

# [ trigger auth relay via the fabric module directly ]
my $relay_code = sprintf(
    'my $r = $code{"cred-mesh.request-authorization"}->({domain=>"%s",context=>{}}); '
        . 'return YAML::XS::Dump($r);',
    $domain
);
my $relay_yaml = p7c_eval( 'cred-mesh', $relay_code );
print "[ relay ] $relay_yaml\n" if $verbose;
my $relay  = eval { YAML::XS::Load($relay_yaml) } // {};
my $req_id = $relay->{'req_id'}                   // '';

harness_assert(
    $scenario,
    'relay request created',
    length $req_id,
    "got req_id '$req_id'"
);

# [ relay_pending.yaml should contain one entry ]
my $relay_file
    = ( $ENV{'PROTOCOL_7_VAR'} // '/var/protocol-7' )
    . '/cred-mesh/relay_pending.yaml';
my $pending       = slurp_yaml($relay_file) // {};
my $pending_count = scalar keys %$pending;
harness_assert(
    $scenario,
    'relay pending file has entry',
    $pending_count == 1,
    "expected 1 pending entry, got $pending_count"
);

# [ approve the relay ]
my $approve_out = p7c( 'cred-mesh.approve', "$req_id $payload" );
print "[ approve ] $approve_out\n" if $verbose;
harness_assert(
    $scenario,
    'approve command ok',
    ( defined $approve_out and $approve_out =~ m{approved|true} ),
    "expected approval ok, got '$approve_out'"
);

# [ pending entry removed ]
$pending       = slurp_yaml($relay_file) // {};
$pending_count = scalar keys %$pending;
harness_assert(
    $scenario,
    'relay pending entry removed',
    $pending_count == 0,
    "expected 0 pending entries, got $pending_count"
);

# [ retried request should carry the approved session header ]
my $url    = "http://$domain/relay-test";
my $helper = File::Spec->catfile( $RealBin, 'helper-curl-via-proxy.pl' );
my $out    = `$helper "$url" 2>&1`;
my $body   = ( $out =~ m{body=\n(.*)}s ) ? $1 : '';
my $echo   = parse_echo_body($body)         // {};
my $got    = $echo->{'headers'}->{'cookie'} // '';

harness_assert(
    $scenario,
    'retried request carries session cookie',
    $got eq $payload,
    "expected '$payload', got '$got'"
);

stop_echo_server();
exit 0;

# [ end ]

#,,.,,,..,...,..,,.,,,,,,,...,..,,..,,,,.,,.,,..,,...,...,.,.,,..,,..,,,,,...,
#NAHP57ZKNSCYMCUGLQZR6AVIPH4BTNHLXTLBOLSN4EKCIPT2W5MGPQDK2CJXWHZQKJJJ5IYELF3CA
#\\\|OJ7SJSZRFEC5WJ6DBQIAL3V7Z4ETZ5YNBJ5WXEVTEEPPP4DMQ7P \ / AMOS7 \ YOURUM ::
#\[7]MNEIXHSLC4ZFAV2RL6EP3UEZLIFCHCR42B554A5YJ5DXYPIMSGAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
