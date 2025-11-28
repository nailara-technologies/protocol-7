#!/usr/bin/perl
# ENVIRONMENT-BOOTSTRAP.pl - Unified initialization for Claude Projects and Claude Code Web
# Detects environment, sets paths, installs dependencies, configures git remotes
# Single command to prepare system for Protocol-7 deployment

use strict;
use warnings;
use Cwd qw(cwd abs_path);
use File::Spec;
use Sys::Hostname qw(hostname);
use JSON::PP;

my $VERSION = '0.6-unified';

# ============================================================================
# ENVIRONMENT DETECTION
# ============================================================================

sub detect_environment {
    my $host = hostname();
    my $cwd = cwd();

    my $env = {
        hostname => $host,
        cwd => $cwd,
        is_projects => 0,
        is_code_web => 0,
        platform => 'unknown',
        repo_base => undef,
        workspace_transfer_path => undef,
        protocol_7_path => undef,
    };

    # Claude Code Web uses 'runsc' hostname
    if ($host eq 'runsc') {
        $env->{is_code_web} = 1;
        $env->{platform} = 'claude_code_web';
        $env->{repo_base} = '/home/user';
        $env->{workspace_transfer_path} = '/home/user/workspace-transfer';
        $env->{protocol_7_path} = '/home/user/protocol-7';
    }
    # Claude Projects - detect by checking /mnt/project structure
    elsif (-d '/mnt/project' && -d '/home/protocol-7') {
        $env->{is_projects} = 1;
        $env->{platform} = 'claude_projects';
        $env->{repo_base} = '/home';
        $env->{workspace_transfer_path} = '/home/workspace-transfer';
        $env->{protocol_7_path} = '/home/protocol-7';
    }
    # Fallback: detect by attempting to determine from cwd
    else {
        if ($cwd =~ m{/home/user/}) {
            $env->{is_code_web} = 1;
            $env->{platform} = 'claude_code_web';
            $env->{repo_base} = '/home/user';
            $env->{workspace_transfer_path} = '/home/user/workspace-transfer';
            $env->{protocol_7_path} = '/home/user/protocol-7';
        } else {
            $env->{is_projects} = 1;
            $env->{platform} = 'claude_projects';
            $env->{repo_base} = '/home';
            $env->{workspace_transfer_path} = '/home/workspace-transfer';
            $env->{protocol_7_path} = '/home/protocol-7';
        }
    }

    return $env;
}

# ============================================================================
# LOGGING AND OUTPUT
# ============================================================================

sub log_info {
    my ($msg) = @_;
    print "[INFO] $msg\n";
}

sub log_success {
    my ($msg) = @_;
    print "[✓] $msg\n";
}

sub log_warn {
    my ($msg) = @_;
    print "[WARN] $msg\n";
}

sub log_error {
    my ($msg) = @_;
    print "[ERROR] $msg\n";
}

sub log_step {
    my ($msg) = @_;
    print "\n=== $msg ===\n";
}

# ============================================================================
# DEPENDENCY CHECKING AND INSTALLATION
# ============================================================================

sub check_perl_module {
    my ($module) = @_;
    eval "use $module";
    return !$@;
}

sub get_required_modules {
    my ($env) = @_;

    # Core modules needed across both environments
    my @core = qw(
        Crypt::Twofish_PP
        CryptX
        Digest::SHA
        Encode
        MIME::Base32
        JSON::PP
        File::Temp
        Sys::Hostname
    );

    # Environment-specific modules
    my @extras;
    if ($env->{is_projects}) {
        # Claude Projects may have different Perl versions
        push @extras, qw(
            Readonly
            autodie
        );
    }

    if ($env->{is_code_web}) {
        # Claude Code Web specific dependencies
        push @extras, qw(
            parent
        );
    }

    return (@core, @extras);
}

sub install_cpan_modules {
    my ($env, @modules) = @_;

    log_step "Installing Perl Dependencies";
    log_info "Platform: " . uc($env->{platform});

    my @missing;
    foreach my $mod (@modules) {
        unless (check_perl_module($mod)) {
            push @missing, $mod;
            log_info "Missing: $mod";
        } else {
            log_success "Found: $mod";
        }
    }

    if (@missing) {
        log_info "Installing " . scalar(@missing) . " missing module(s)...";

        # Use cpanm if available, fall back to cpan
        my $installer = `which cpanm 2>/dev/null` ? 'cpanm' : 'cpan';

        foreach my $mod (@missing) {
            log_info "Installing $mod...";
            system("$installer -n $mod 2>/dev/null");

            if (check_perl_module($mod)) {
                log_success "Installed: $mod";
            } else {
                log_error "Failed to install: $mod";
                log_warn "Continuing anyway - module may not be strictly required";
            }
        }
    } else {
        log_success "All dependencies already installed!";
    }
}

sub check_system_tools {
    my ($env) = @_;

    log_step "Checking System Tools";

    my @tools = qw(git perl openssl curl);
    my @missing;

    foreach my $tool (@tools) {
        my $path = `which $tool 2>/dev/null`;
        if ($path) {
            chomp $path;
            log_success "$tool: $path";
        } else {
            log_warn "$tool: not found";
            push @missing, $tool;
        }
    }

    return @missing;
}

# ============================================================================
# GIT CONFIGURATION
# ============================================================================

sub configure_git_remote {
    my ($env, $repo_path, $repo_name, $github_token) = @_;

    return unless -d $repo_path;

    my $https_url = "https://${github_token}\@github.com/nailara-technologies/${repo_name}.git";

    my $current_dir = cwd();
    chdir($repo_path) or do {
        log_error "Cannot cd to $repo_path: $!";
        return 0;
    };

    log_info "Configuring remote for $repo_name in $repo_path";

    # Set authenticated remote
    my $set_result = system("git remote set-url origin '$https_url' 2>/dev/null");

    if ($set_result == 0) {
        log_success "Git remote configured for $repo_name";
    } else {
        log_error "Failed to configure git remote for $repo_name";
    }

    chdir($current_dir);
    return $set_result == 0;
}

# ============================================================================
# REPOSITORY OPERATIONS
# ============================================================================

sub clone_or_update_repo {
    my ($env, $repo_name, $target_path, $github_token) = @_;

    my $https_url = "https://${github_token}\@github.com/nailara-technologies/${repo_name}.git";

    if (-d $target_path) {
        log_info "$repo_name already exists at $target_path";

        my $current_dir = cwd();
        chdir($target_path) or return 0;

        log_info "Pulling latest changes...";
        my $pull_result = system("git pull origin base 2>/dev/null");

        chdir($current_dir);
        return $pull_result == 0;
    } else {
        log_info "Cloning $repo_name to $target_path";
        my $clone_result = system("git clone '$https_url' '$target_path' 2>/dev/null");

        if ($clone_result == 0) {
            log_success "Successfully cloned $repo_name";
            return configure_git_remote($env, $target_path, $repo_name, $github_token);
        } else {
            log_error "Failed to clone $repo_name";
            return 0;
        }
    }
}

# ============================================================================
# ENVIRONMENT SETUP VERIFICATION
# ============================================================================

sub verify_setup {
    my ($env) = @_;

    log_step "Verifying Setup";

    my $status = {
        workspace_transfer_present => -d $env->{workspace_transfer_path},
        protocol_7_present => -d $env->{protocol_7_path},
        git_available => system("which git >/dev/null 2>&1") == 0,
        perl_available => system("which perl >/dev/null 2>&1") == 0,
    };

    if ($status->{workspace_transfer_present}) {
        log_success "workspace-transfer repository found";
    } else {
        log_warn "workspace-transfer repository not found";
    }

    if ($status->{protocol_7_present}) {
        log_success "protocol-7 repository found";
    } else {
        log_warn "protocol-7 repository not found";
    }

    if ($status->{git_available}) {
        log_success "git is available";
    } else {
        log_error "git is not available";
    }

    if ($status->{perl_available}) {
        log_success "Perl is available";
    } else {
        log_error "Perl is not available";
    }

    return $status;
}

# ============================================================================
# CONFIGURATION FILE GENERATION
# ============================================================================

sub generate_config {
    my ($env) = @_;

    my $config = {
        environment => {
            platform => $env->{platform},
            hostname => $env->{hostname},
            timestamp => scalar(localtime),
            bootstrap_version => $VERSION,
        },
        paths => {
            repo_base => $env->{repo_base},
            workspace_transfer => $env->{workspace_transfer_path},
            protocol_7 => $env->{protocol_7_path},
        },
        setup_complete => 1,
    };

    my $config_dir = File::Spec->catdir($env->{repo_base}, '.config');
    mkdir($config_dir) unless -d $config_dir;

    my $config_file = File::Spec->catfile($config_dir, 'bootstrap.json');

    open my $fh, '>', $config_file or do {
        log_error "Cannot write config: $!";
        return 0;
    };

    print $fh JSON::PP->new->pretty->encode($config);
    close $fh;

    log_success "Configuration saved to $config_file";
    return 1;
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

sub main {
    log_step "Protocol-7 Unified Environment Bootstrap v$VERSION";

    # STEP 1: Detect environment
    my $env = detect_environment();

    log_success "Detected platform: " . uc($env->{platform});
    log_info "Hostname: " . $env->{hostname};
    log_info "Repo base: " . $env->{repo_base};
    log_info "workspace-transfer path: " . $env->{workspace_transfer_path};
    log_info "protocol-7 path: " . $env->{protocol_7_path};

    # STEP 2: Check system tools
    my @missing_tools = check_system_tools($env);
    if (@missing_tools) {
        log_warn "Missing tools: " . join(", ", @missing_tools);
    }

    # STEP 3: Install dependencies
    my @modules = get_required_modules($env);
    install_cpan_modules($env, @modules);

    # STEP 4: Get GitHub token (from environment or file)
    my $github_token = $ENV{GITHUB_TOKEN};
    unless ($github_token) {
        my $token_file = File::Spec->catfile($env->{repo_base}, '.config', 'github.token');
        if (-f $token_file) {
            open my $fh, '<', $token_file or log_error "Cannot read token file: $!";
            $github_token = <$fh>;
            chomp $github_token;
            close $fh;
        }
    }

    if ($github_token) {
        log_success "GitHub token available";
    } else {
        log_error "GitHub token not found. Set GITHUB_TOKEN environment variable or place in " .
                 File::Spec->catfile($env->{repo_base}, '.config', 'github.token');
    }

    # STEP 5: Clone/update repositories
    if ($github_token) {
        log_step "Setting Up Repositories";

        clone_or_update_repo($env, 'workspace-transfer',
                           $env->{workspace_transfer_path},
                           $github_token);

        clone_or_update_repo($env, 'protocol-7',
                           $env->{protocol_7_path},
                           $github_token);
    }

    # STEP 6: Verify setup
    my $status = verify_setup($env);

    # STEP 7: Generate config
    generate_config($env);

    # STEP 8: Print final status
    log_step "Bootstrap Complete";

    if ($status->{workspace_transfer_present} &&
        $status->{protocol_7_present} &&
        $status->{git_available} &&
        $status->{perl_available}) {
        log_success "All systems ready for Protocol-7 deployment!";
        log_info "Next step: cd " . $env->{protocol_7_path};
        log_info "Then run: perl bin/zenka-start.pl";
        return 0;
    } else {
        log_warn "Some components missing. Manual review required.";
        return 1;
    }
}

exit main() unless caller();
1;
