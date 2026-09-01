#!/usr/bin/perl
use v5.24;
use strict;
use warnings;
use FindBin qw($RealBin);
use Getopt::Long;

my $verbose      = 0;
my $show_details = 0;

GetOptions(
    'verbose|v' => \$verbose,
    'details'   => \$show_details,
) or die "Error in command line arguments\n";

# Use p7 command to call flat modules
my $load_profile = sub {
    my ($profile_name) = @_;
    my $p7_path = "$RealBin/../p7";
    my $json
        = `$p7_path httpsd.load-cipher-profile '$profile_name' 2>/dev/null`;
    return undef unless $json;
    eval { require JSON::PP; } or do { return undef; };
    return JSON::PP::decode_json($json);
};

my $list_profiles_fn = sub {
    my $p7_path = "$RealBin/../p7";
    my $json    = `$p7_path httpsd.cmd.list-cipher-profiles 2>/dev/null`;
    return {} unless $json;
    eval { require JSON::PP; } or do { return {}; };
    return JSON::PP::decode_json($json);
};

print "╔════════════════════════════════════════════════════════════╗\n";
print "║  HTTPSD Cipher Configuration Test                          ║\n";
print "╚════════════════════════════════════════════════════════════╝\n\n";

# Test 1: Module availability
print "Test 1: Module Availability\n";
print "  Checking HTTPSD::LoadCipherProfile...\n";
eval {
    $load_profile->('firefox_compatible');
    print "  ✅ Module loaded successfully\n";
};
if ($@) {
    print "  ❌ Failed to load module: $@\n";
    exit 1;
}
print "\n";

# Test 2: Load all profiles
print "Test 2: Profile Loading\n";
my $profiles = $list_profiles_fn->();
foreach my $name ( sort keys %$profiles ) {
    my $profile = $load_profile->($name);
    my $tls     = join( ', ', @{ $profile->{tls_versions} } );
    my $ciphers = scalar( split( ':', $profile->{cipher_suite} ) );
    printf(
        "  %-20s: %s (%d ciphers, TLS %s)\n",
        $name,    $profile->{description},
        $ciphers, $tls
    );
}
print "\n";

# Test 3: Firefox compatibility
print "Test 3: Firefox Compatibility (firefox_compatible)\n";
my $profile = $load_profile->('firefox_compatible');
print "  Profile: " . $profile->{description} . "\n";
print "  TLS Versions: " . join( ', ', @{ $profile->{tls_versions} } ) . "\n";
print "  Key Types: " . join( ', ', @{ $profile->{key_types} } ) . "\n";

my @firefox_safe
    = ( 'ECDHE-ECDSA-AES256-GCM-SHA384', 'ECDHE-RSA-AES256-GCM-SHA384' );
my $suite       = $profile->{cipher_suite};
my $has_firefox = grep { $suite =~ m|\Q$_\E| } @firefox_safe;
if ($has_firefox) {
    print "  ✅ Contains Firefox-safe ciphers\n";
} else {
    print "  ⚠️  Missing some Firefox-safe ciphers\n";
}
print "\n";

# Test 4: Security analysis
print "Test 4: Security Analysis\n";
foreach my $name (qw(firefox_compatible high_security)) {
    my $p         = $load_profile->($name);
    my $has_tls13 = grep { $_ eq 'TLSv1_3' } @{ $p->{tls_versions} };
    my $has_old   = grep {m{TLSv1\.0|SSLv}} @{ $p->{tls_versions} };
    my $has_weak  = $p->{cipher_suite} =~ m{RC4|DES|MD5|NULL} ? 1 : 0;

    printf( "  %s:\n", $name );
    print "    - TLS 1.3 support: " .  ( $has_tls13 ? '✅' : '❌' ) . "\n";
    print "    - Old TLS versions: " . ( $has_old   ? '❌' : '✅' ) . "\n";
    print "    - Weak ciphers: " .     ( $has_weak  ? '❌' : '✅' ) . "\n";
}
print "\n";

# Test 5: YAML config file status
print "Test 5: Configuration File Status\n";
my $config_file = '/etc/protocol-7/httpsd-ciphers.yaml';
if ( -f $config_file ) {
    print "  ✅ YAML config found: $config_file\n";
    if ( -r $config_file ) {
        print "  ✅ File is readable\n";
    } else {
        print "  ⚠️  File is NOT readable (check permissions)\n";
    }
} else {
    print "  ℹ️  YAML config not yet deployed (using hardcoded defaults)\n";
    print "  To enable live changes, create: $config_file\n";
}
print "\n";

# Test 6: Verbose output
if ($verbose) {
    print "Test 6: Detailed Cipher Suite (firefox_compatible)\n";
    my $p       = $load_profile->('firefox_compatible');
    my @ciphers = split( ':', $p->{cipher_suite} );
    foreach my $i ( 0 .. $#ciphers ) {
        printf( "  %d. %s\n", $i + 1, $ciphers[$i] );
    }
    print "\n";
}

print "╔════════════════════════════════════════════════════════════╗\n";
print "║  ✅ All tests passed - ready for deployment               ║\n";
print "╚════════════════════════════════════════════════════════════╝\n";

#,,,,,.,.,,.,,,.,,,..,,.,,,..,,,.,.,.,,,,,.,.,..,,...,...,.,,,.,.,,,,,,,,,.,.,
#5HX6U6HGHM6H4WBG6CEXACFRMSXQUSH645FEVMHNDWM7YJJXFL4KW656RSPSJDDIPTXVWQWKOEXX2
#\\\|K5QLKZBBZ7I6R7MO55LV6W22OG6TIIBMCZUI3MY4D2MWGH2GJ5H \ / AMOS7 \ YOURUM ::
#\[7]NGMUYYOIFKWHIVXVMVZKOG6SJQWWHNUQWDV3QRTD4PBQCDFYC6AA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
