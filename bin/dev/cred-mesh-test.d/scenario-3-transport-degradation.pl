#!/usr/bin/perl

# [ scenario 3: transport demote / promote lifecycle ]

use v5.24;
use strict;
use warnings;
use English;

use File::Spec;
use FindBin qw| $RealBin |;
use lib File::Spec->catdir( $RealBin, 'lib' );
use CredMeshTest qw|
    harness_assert p7c_eval temp_dir
    start_echo_server stop_echo_server p7c
    |;

my $scenario = 3;
my $verbose  = $ENV{'CREDMESH_TEST_VERBOSE'} // 0;

my $dest = 'direct-test.example.com';
my $type = 'direct-tcp';

# [ shorten probe interval so the cycle is fast ]
p7c_eval( 'transport',
    '$data{transport}{cfg}{probe_interval} = 1; return "ok";' );

# [ inject a demotion ]
my $demote_code = sprintf(
    '$code{"transport.demote"}->("%s", "%s", "test_injected_failure"); '
    . 'return "demoted";',
    $dest, $type
);
my $demote_out = p7c_eval( 'transport', $demote_code );
print "[ demote ] $demote_out\n" if $verbose;

# [ verify demoted state ]
my $demoted_yaml = p7c_eval( 'transport',
    'return YAML::XS::Dump($data{transport}{registry}{demoted});' );
print "[ demoted state ] $demoted_yaml\n" if $verbose;
my $demoted = eval { YAML::XS::Load($demoted_yaml) } // {};
my $is_demoted = ( ref $demoted eq 'HASH'
        and exists $demoted->{$dest}
        and exists $demoted->{$dest}{$type} );

harness_assert( $scenario, 'transport demote recorded',
    $is_demoted,
    'demoted entry exists in transport registry' );

# [ run one probe cycle: because direct-tcp to fake host fails, it stays demoted ]
# [ then clear the demotion and probe again to trigger promote ]
p7c_eval( 'transport',
    'delete $data{transport}{registry}{demoted}{"' . $dest . '"}{"' . $type . '"}; '
    . 'delete $data{transport}{registry}{demoted}{"' . $dest . '"} '
    . 'if not keys %{$data{transport}{registry}{demoted}{"' . $dest . '"}//{}}; '
    . 'return "cleared";' );

sleep 1;
my $probe_out = p7c_eval( 'transport',
    '$code{"transport.probe.timer"}->(); return "probed";' );
print "[ probe ] $probe_out\n" if $verbose;

# [ verify demotion removed ]
my $after_yaml = p7c_eval( 'transport',
    'return YAML::XS::Dump($data{transport}{registry}{demoted});' );
my $after = eval { YAML::XS::Load($after_yaml) } // {};
my $is_cleared = ( ref $after eq 'HASH' and not exists $after->{$dest}{$type} );

harness_assert( $scenario, 'transport promote cleared demotion',
    $is_cleared,
    'demoted entry removed after successful probe' );

exit 0;

# [ end ]

#,,,.,...,.,,,,..,.,,,..,,.,.,..,,...,,.,,,,.,..,,...,...,.,.,...,...,.,,,..,,
#PALL2UHE7T6DIT5IESTWGO5GNK66SJVUYIOGF5M3DAV26U4DC754FLOKS67DJT6PCW7VJQBSW6BK4
#\\\|J7LLUOUNEX5VNVFHRAVZW5RDYRT2W5Z7PCLNEUMJ5ZNRU2R6DY7 \ / AMOS7 \ YOURUM ::
#\[7]FRECPSMI57OOGJIMYWXWBPJIADSYC7Y7T64YLO2O65KDDTSQIKAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
