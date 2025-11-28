package HTTPSD::LoadCipherProfile;

use v5.24;
use strict;
use warnings;
use Carp qw(croak carp);

our @EXPORT_OK = qw(load_cipher_profile list_profiles);

# Default profiles (hardcoded fallback)
my %DEFAULT_PROFILES = (
    firefox_compatible => {
        description => 'Tested with Firefox, Chrome, Safari, Brave on modern systems',
        tls_versions => ['TLSv1_3', 'TLSv1_2'],
        cipher_suite => join(':', (
            'ECDHE-ECDSA-AES256-GCM-SHA384',
            'ECDHE-ECDSA-CHACHA20-POLY1305',
            'ECDHE-ECDSA-AES128-GCM-SHA256',
            'ECDHE-RSA-AES256-GCM-SHA384',
            'ECDHE-RSA-CHACHA20-POLY1305',
            'ECDHE-RSA-AES128-GCM-SHA256',
        )),
        key_types => ['ECDSA', 'RSA'],
    },
    high_security => {
        description => 'TLS 1.3 only, minimum attack surface',
        tls_versions => ['TLSv1_3'],
        cipher_suite => join(':', (
            'TLS_AES_256_GCM_SHA384',
            'TLS_CHACHA20_POLY1305_SHA256',
            'TLS_AES_128_GCM_SHA256',
        )),
        key_types => ['ECDSA', 'RSA'],
    },
    backward_compatible => {
        description => 'Includes support for older clients',
        tls_versions => ['TLSv1_3', 'TLSv1_2'],
        cipher_suite => join(':', (
            'ECDHE-ECDSA-AES256-GCM-SHA384',
            'ECDHE-ECDSA-CHACHA20-POLY1305',
            'ECDHE-ECDSA-AES128-GCM-SHA256',
            'ECDHE-RSA-AES256-GCM-SHA384',
            'ECDHE-RSA-CHACHA20-POLY1305',
            'ECDHE-RSA-AES128-GCM-SHA256',
            'DHE-RSA-AES256-GCM-SHA384',
            'DHE-RSA-AES128-GCM-SHA256',
        )),
        key_types => ['ECDSA', 'RSA'],
    },
);

sub load_cipher_profile {
    my ($profile_name) = @_;
    $profile_name //= 'firefox_compatible';
    
    my $config_file = '/etc/protocol-7/httpsd-ciphers.yaml';
    
    # Try YAML config first
    if (-f $config_file) {
        my $profile = _load_from_yaml($config_file, $profile_name);
        return $profile if $profile;
    }
    
    # Fall back to hardcoded defaults
    return _get_default_profile($profile_name);
}

sub list_profiles {
    my %profiles;
    foreach my $name (keys %DEFAULT_PROFILES) {
        $profiles{$name} = $DEFAULT_PROFILES{$name}{description};
    }
    return \%profiles;
}

# Private: Load profile from YAML file
sub _load_from_yaml {
    my ($config_file, $profile_name) = @_;
    
    eval {
        require YAML::XS;
    } or do {
        return undef;
    };
    
    my $yaml;
    eval {
        $yaml = YAML::XS::LoadFile($config_file);
    } or do {
        carp("Failed to load YAML config: $@");
        return undef;
    };
    
    my $profile = $yaml->{cipher_profiles}{$profile_name};
    unless ($profile) {
        croak("Cipher profile not found: $profile_name");
    }
    
    # Normalize cipher suite
    my $cipher_suite = $profile->{cipher_suite};
    $cipher_suite =~ s/\s+/ /g;
    $cipher_suite =~ s/^\s+|\s+$//g;
    $cipher_suite =~ s/\s*:\s*/:/g;
    
    return {
        description => $profile->{description},
        tls_versions => $profile->{tls_versions} // ['TLSv1_3', 'TLSv1_2'],
        cipher_suite => $cipher_suite,
        key_types => $profile->{key_types} // ['ECDSA', 'RSA'],
    };
}

# Private: Get default profile
sub _get_default_profile {
    my ($profile_name) = @_;
    
    my $profile = $DEFAULT_PROFILES{$profile_name};
    unless ($profile) {
        my @available = sort keys %DEFAULT_PROFILES;
        croak("Unknown cipher profile: $profile_name. Available: " . 
              join(', ', @available));
    }
    
    return { %$profile };
}

1;
