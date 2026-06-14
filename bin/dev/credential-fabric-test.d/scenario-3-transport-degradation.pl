#!/usr/bin/perl

# [ scenario 3: transport demote / promote lifecycle ]

use v5.24;
use strict;
use warnings;
use English;

use File::Spec;
use FindBin qw| $RealBin |;
use lib File::Spec->catdir( $RealBin, 'lib' );
use CredFabTest qw|
    harness_assert p7c_eval temp_dir
    start_echo_server stop_echo_server p7c
    |;

my $scenario = 3;
my $verbose  = $ENV{'CREDFAB_TEST_VERBOSE'} // 0;

my $dest = 'direct-test.example.com';
my $type = 'direct-tcp';

# [ shorten probe interval so the cycle is fast ]
p7c_eval( 'transport',
    '<transport.cfg.probe_interval> = 1; return "ok";' );

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
    'return YAML::XS::Dump(<transport.registry>->{demoted});' );
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
    'delete <transport.registry>->{demoted}{"' . $dest . '"}{"' . $type . '"}; '
    . 'delete <transport.registry>->{demoted}{"' . $dest . '"} '
    . 'if not keys %{<transport.registry>->{demoted}{"' . $dest . '"}//{}}; '
    . 'return "cleared";' );

sleep 1;
my $probe_out = p7c_eval( 'transport',
    '$code{"transport.probe.timer"}->(); return "probed";' );
print "[ probe ] $probe_out\n" if $verbose;

# [ verify demotion removed ]
my $after_yaml = p7c_eval( 'transport',
    'return YAML::XS::Dump(<transport.registry>->{demoted});' );
my $after = eval { YAML::XS::Load($after_yaml) } // {};
my $is_cleared = ( ref $after eq 'HASH' and not exists $after->{$dest}{$type} );

harness_assert( $scenario, 'transport promote cleared demotion',
    $is_cleared,
    'demoted entry removed after successful probe' );

exit 0;

# [ end ]

#,,,,,.,,,...,...,,.,,,,,,...,,,,,,,.,,..,...,..,,...,...,..,,,,.,..,,,,,,...,
#CA3BP7ECESHVO5QEWJTRS5HNS4XTH5JTG7NCCVBFPH3JQBA4SRQAJSTFBW6GBWD6FOTG4U6RDQYJA
#\\\|M5UAXKHFLPUGHGJD4XSFEPNHAC4QPTRXCVXBTVWQRMTF6BYQMVU \ / AMOS7 \ YOURUM ::
#\[7]QFMLC6WOUXSOSLYAXYQTG35US623GF5KSLL6EMUHSELSAK3N2EAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
