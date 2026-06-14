#!/usr/bin/perl

# [ scenario 4: credential rotation flushes proxy and transport caches ]

use v5.24;
use strict;
use warnings;
use English;

use File::Spec;
use FindBin qw| $RealBin |;
use lib File::Spec->catdir( $RealBin, 'lib' );
use CredFabTest qw|
    harness_assert temp_dir start_echo_server stop_echo_server
    p7c_eval p7c parse_echo_body get_zenka_log wait_for_log
    |;

my $scenario = 4;
my $verbose  = $ENV{'CREDFAB_TEST_VERBOSE'} // 0;

my $echo_port = 33000 + ( int(rand(2000)) );
my $echo_log  = File::Spec->catfile( temp_dir(), 'echo-scenario-4.log' );
my $echo_pid  = start_echo_server( $echo_port, $echo_log );
my $domain    = "127.0.0.1:$echo_port";
my $slot      = 'rotation-test.api-key';
my $old_value = 'old-key-aaaa';
my $new_value = 'new-key-bbbb';

# [ seed slot ]
my $seed_code = sprintf(
    'my @r; '
    . 'push @r, $code{"credential_fabric.register"}->({slot=>"%s",owner=>"credential_fabric",type=>"api-key",sensitivity=>"low",storage=>"local"})->{data}; '
    . 'push @r, $code{"credential_fabric.rotate"}->({slot=>"%s",new_value=>"%s",reason=>"scenario-4-before"})->{data}; '
    . 'return join ",", @r;',
    $slot, $slot, $old_value
);
my $seed_out = p7c_eval( 'credential_fabric', $seed_code );
print "[ seed ] $seed_out\n" if $verbose;
my $seed_ok = ( defined $seed_out and $seed_out =~ m{rotated} );

harness_assert( $scenario, 'seed rotation slot',
    $seed_ok,
    "register + rotate slot (output: $seed_out)" );

# [ issue request to populate proxy auth cache ]
my $url = "http://$domain/rotate-test";
my $helper = File::Spec->catfile( $RealBin, 'helper-curl-via-proxy.pl' );
my $out = `$helper "$url" 2>&1`;

# [ rotate to new value ]
my $rot_out = p7c( 'credential_fabric.rotate', "$slot $new_value scenario-4" );
print "[ rotate ] $rot_out\n" if $verbose;

harness_assert( $scenario, 'rotate command accepted',
    defined $rot_out and $rot_out =~ m{rotated},
    "expected 'rotated', got '$rot_out'" );

# [ check fabric rotation log ]
my $rot_log = p7c_eval( 'credential_fabric',
    'return YAML::XS::Dump(<credential_fabric.rotation_log>);' );
my $rot_entries = eval { YAML::XS::Load($rot_log) } // [];
my $found_slot = 0;
if ( ref $rot_entries eq 'ARRAY' ) {
    for my $e (@$rot_entries) {
        $found_slot = 1
            if ref $e eq 'HASH' and $e->{'slot'} eq $slot;
    }
}
harness_assert( $scenario, 'rotation log contains slot',
    $found_slot,
    'fabric rotation log recorded the slot' );

# [ proxy and transport cache flush logs ]
# [ note: subscribers only register when credential_fabric modules are co-loaded ]
my $proxy_flush = wait_for_log( 'proxy', 'proxy.handler.cred_rotated: flushed', 5 );
my $trans_flush = wait_for_log( 'transport', 'transport.handler.cred_rotated: flushed', 5 );

harness_assert( $scenario, 'proxy cache flush log',
    $proxy_flush,
    'proxy log shows cache flush for rotated slot' );

harness_assert( $scenario, 'transport cache flush log',
    $trans_flush,
    'transport log shows profile cache flush for rotated slot' );

# [ second request should show new value ]
$out = `$helper "$url" 2>&1`;
my $body = ( $out =~ m{body=\n(.*)}s ) ? $1 : '';
my $echo = parse_echo_body($body);
my $got = $echo->{'headers'}->{'x-api-key'} // '';

harness_assert( $scenario, 'after-rotation header value',
    $got eq $new_value,
    "expected new value '$new_value', got '$got'" );

stop_echo_server();
exit 0;

# [ end ]

#,,,,,,,,,,,.,,,,,,,.,,.,,,.,,,..,,.,,,,.,...,..,,...,..,,,..,,,.,,.,,,,.,..,,
#FKKF3EI5ADI5J7LVP5M67BWQOECI4BVW6EH4WH2BANJ5KSNWHDGYQ4LYEM74YPTMX2WESLKKMCTL4
#\\\|3SEW5NKJNESG3S3MZB7YNXTCJ4RFN6JDABKSYE2RRLEESBPPARI \ / AMOS7 \ YOURUM ::
#\[7]WASTSPX4WNPFYCOHVTGTI2TLS4C4YHSKZ2BPNX6IVZENPXSQQODA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
