package ENV;
# lib/ENV.pm - Environment detection and path resolution for cross-platform Claude support
# Handles path resolution, platform detection, and configuration for Protocol-7

use strict;
use warnings;
use Exporter qw(import);
use Sys::Hostname qw(hostname);
use File::Spec;
use Cwd qw(cwd);
use JSON::PP;

our @EXPORT_OK = qw(
    detect_platform
    get_paths
    get_token
    is_projects
    is_code_web
    resolve_path
    ensure_config_dir
    load_config
    save_config
);

our %EXPORT_TAGS = (
    all => [@EXPORT_OK],
);

# ============================================================================
# PLATFORM DETECTION
# ============================================================================

sub detect_platform {
    my $host = hostname();

    # Claude Code Web uses runsc hostname
    return 'claude_code_web' if $host eq 'runsc';

    # Claude Projects - check for characteristic paths
    return 'claude_projects' if -d '/mnt/project' && -d '/home/protocol-7';

    # Fallback: check cwd structure
    my $cwd = cwd();
    return 'claude_code_web' if $cwd =~ m{/home/user/};

    return 'claude_projects';
}

sub is_projects {
    return detect_platform() eq 'claude_projects';
}

sub is_code_web {
    return detect_platform() eq 'claude_code_web';
}

# ============================================================================
# PATH RESOLUTION
# ============================================================================

sub get_paths {
    my $platform = detect_platform();

    my $repo_base = $platform eq 'claude_code_web' ? '/home/user' : '/home';

    return {
        platform => $platform,
        repo_base => $repo_base,
        workspace_transfer => File::Spec->catdir($repo_base, 'workspace-transfer'),
        protocol_7 => File::Spec->catdir($repo_base, 'protocol-7'),
        config_dir => File::Spec->catdir($repo_base, '.config'),
        lib_path => File::Spec->catdir($repo_base, 'lib'),
        bin_path => File::Spec->catdir($repo_base, 'bin'),
    };
}

sub resolve_path {
    my ($key) = @_;
    my $paths = get_paths();
    return $paths->{$key} if exists $paths->{$key};
    return undef;
}

# ============================================================================
# CONFIGURATION MANAGEMENT
# ============================================================================

sub ensure_config_dir {
    my $paths = get_paths();
    mkdir($paths->{config_dir}) unless -d $paths->{config_dir};
    return $paths->{config_dir};
}

sub load_config {
    my ($config_name) = @_;
    $config_name ||= 'bootstrap.json';

    my $paths = get_paths();
    my $config_file = File::Spec->catfile($paths->{config_dir}, $config_name);

    return {} unless -f $config_file;

    open my $fh, '<', $config_file or return {};
    my $content = do { local $/; <$fh> };
    close $fh;

    return JSON::PP->new->decode($content);
}

sub save_config {
    my ($data, $config_name) = @_;
    $config_name ||= 'bootstrap.json';

    my $config_dir = ensure_config_dir();
    my $config_file = File::Spec->catfile($config_dir, $config_name);

    open my $fh, '>', $config_file or die "Cannot write config: $!";
    print $fh JSON::PP->new->pretty->encode($data);
    close $fh;

    return $config_file;
}

# ============================================================================
# TOKEN MANAGEMENT
# ============================================================================

sub get_token {
    # Priority order: ENV variable, config file
    return $ENV{GITHUB_TOKEN} if $ENV{GITHUB_TOKEN};

    my $paths = get_paths();
    my $token_file = File::Spec->catfile($paths->{config_dir}, 'github.token');

    if (-f $token_file) {
        open my $fh, '<', $token_file or return undef;
        my $token = <$fh>;
        chomp $token;
        close $fh;
        return $token;
    }

    return undef;
}

sub save_token {
    my ($token) = @_;
    my $config_dir = ensure_config_dir();
    my $token_file = File::Spec->catfile($config_dir, 'github.token');

    open my $fh, '>', $token_file or die "Cannot write token: $!";
    print $fh $token;
    close $fh;

    # Restrict permissions
    chmod(0600, $token_file);

    return $token_file;
}

# ============================================================================
# MODULE INITIALIZATION
# ============================================================================

1;
__END__

=head1 NAME

ENV - Platform detection and path resolution for Protocol-7 across Claude environments

=head1 SYNOPSIS

    use ENV qw(:all);

    my $platform = detect_platform();
    my $paths = get_paths();

    if (is_projects()) {
        print "Running on Claude Projects\n";
    }

    my $token = get_token();
    my $config = load_config();

=head1 DESCRIPTION

Provides environment detection and path resolution for running Protocol-7 on both
Claude Projects and Claude Code Web platforms. Abstracts platform-specific differences
so the same code works everywhere.

=head1 FUNCTIONS

=over 4

=item detect_platform()

Returns the detected platform as a string: 'claude_projects' or 'claude_code_web'

=item get_paths()

Returns a hashref with platform-appropriate paths:

    {
        platform => 'claude_projects',
        repo_base => '/home',
        workspace_transfer => '/home/workspace-transfer',
        protocol_7 => '/home/protocol-7',
        config_dir => '/home/.config',
        lib_path => '/home/lib',
        bin_path => '/home/bin',
    }

=item is_projects()

Returns true if running on Claude Projects platform.

=item is_code_web()

Returns true if running on Claude Code Web platform.

=item resolve_path($key)

Returns the path for a given key from get_paths().

=item ensure_config_dir()

Creates config directory if it doesn't exist and returns its path.

=item load_config($config_name)

Loads and returns JSON configuration from .config directory.
Defaults to 'bootstrap.json' if no name provided.

=item save_config($data, $config_name)

Saves data as JSON configuration file in .config directory.

=item get_token()

Returns GitHub token from GITHUB_TOKEN environment variable or config file.

=item save_token($token)

Saves GitHub token to secure config file with restricted permissions.

=back

=head1 AUTHOR

Protocol-7 Development Team

=cut
