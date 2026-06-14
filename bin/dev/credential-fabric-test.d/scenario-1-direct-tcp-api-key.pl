#!/usr/bin/perl

# [ scenario 1: direct-tcp fallback + api-key injection ]

use v5.24;
use strict;
use warnings;
use English;

use File::Spec;
use FindBin qw| $RealBin |;
use lib File::Spec->catdir( $RealBin, 'lib' );
use CredFabTest qw|
    harness_assert start_echo_server stop_echo_server temp_dir
    p7c_eval p7c parse_echo_body
    |;

my $scenario = 1;
my $verbose  = $ENV{'CREDFAB_TEST_VERBOSE'} // 0;

# [ start upstream echo listener ]
my $echo_port = 32000 + ( int(rand(2000)) );
my $echo_log  = File::Spec->catfile( temp_dir(), 'echo-scenario-1.log' );
my $echo_pid  = start_echo_server( $echo_port, $echo_log );
my $domain    = "127.0.0.1:$echo_port";

# [ seed the fabric ]
my $api_slot    = 'openweathermap.api-key';
my $session_slot = "session.$domain";
my $api_value   = 'test-api-key-12345';

my $seed_code = sprintf(
    'my @r; '
    . 'push @r, $code{"credential_fabric.register"}->({slot=>"%s",owner=>"credential_fabric",type=>"api-key",sensitivity=>"low",storage=>"local"})->{data}; '
    . 'push @r, $code{"credential_fabric.rotate"}->({slot=>"%s",new_value=>"%s",reason=>"scenario-1"})->{data}; '
    . 'push @r, $code{"credential_fabric.register"}->({slot=>"%s",owner=>"credential_fabric",type=>"api-key",sensitivity=>"low",storage=>"local"})->{data}; '
    . 'push @r, $code{"credential_fabric.rotate"}->({slot=>"%s",new_value=>"%s",reason=>"scenario-1"})->{data}; '
    . 'return join ",", @r;',
    $api_slot, $api_slot, $api_value,
    $session_slot, $session_slot, $api_value
);
my $seed_out = p7c_eval( 'credential_fabric', $seed_code );
print "[ seed ] $seed_out\n" if $verbose;

my $seed_ok = ( defined $seed_out and $seed_out =~ m{rotated} );
harness_assert( $scenario, 'seed fabric',
    $seed_ok,
    "register + rotate both slots (output: $seed_out)"
);

# [ issue proxied request ]
my $url = "http://$domain/test";
my ( $body, $status, $error ) = ( '', 0, '' );
{
    my $helper = File::Spec->catfile( $RealBin, 'helper-curl-via-proxy.pl' );
    my $out = `$helper "$url" 2>&1`;
    if ( $out =~ m{status=(\d+)} ) { $status = $1; }
    if ( $out =~ m{error=(.+)} )    { $error  = $1; }
    if ( $out =~ m{body=\n(.*)}s )  { $body   = $1; }
}

harness_assert( $scenario, 'proxy response status',
    ( $status == 200 ),
    "expected 200, got $status" );

my $echo = parse_echo_body($body);
harness_assert( $scenario, 'echo body parsed',
    ( defined $echo and ref $echo eq 'HASH' ),
    'upstream echoed a yaml body' );

my $headers = $echo->{'headers'} // {};
my $got_key = $headers->{'x-api-key'} // '';
harness_assert( $scenario, 'injected x-api-key',
    ( length $got_key and $got_key eq $api_value ),
    "expected '$api_value', got '$got_key'" );

# [ no relay pending ]
my $relay_file = '/var/protocol-7/credential_fabric/relay_pending.yaml';
my $relay_exists = -f $relay_file ? 1 : 0;
harness_assert( $scenario, 'no relay pending',
    ( not $relay_exists ),
    'relay_pending.yaml should not exist' );

stop_echo_server();
exit 0;

# [ end ]

#,,,.,,.,,,,.,.,.,..,,.,,,,.,,,,,,..,,.,.,,,.,..,,...,...,,..,...,...,..,,.,,,
#FBSVRY2SJ2ADRKUWCEPJKA43NDKF4MDLZ27DJY6AIFBHMNUP3IP3OKDF7UPHMG65GB272GHQPJBWG
#\\\|GF247IR6UZ2Q7CJPHSGNFG7IOBJBNVM366NXFBSAIRQYYHBVUBV \ / AMOS7 \ YOURUM ::
#\[7]JBWHW7YYW4DQ772SQVGFDEWEHQPCF6NGTTE3PT2XNRDG7M6NW2CI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
