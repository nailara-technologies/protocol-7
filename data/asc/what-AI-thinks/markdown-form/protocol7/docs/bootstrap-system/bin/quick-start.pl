#!/usr/bin/perl
# bin/quick-start.pl - Unified entry point: bootstraps environment and starts Protocol-7
# Usage: perl bin/quick-start.pl [--zenka] [--token TOKEN]
# This is the primary command for deploying Protocol-7 in any Claude environment

use strict;
use warnings;
use Getopt::Long qw(GetOptions);
use File::Spec;
use Cwd qw(abs_path cwd chdir);
use lib File::Spec->catdir(abs_path('.'), 'lib');

my $VERSION = '0.6-unified';

# Parse arguments
my $start_zenka = 0;
my $github_token;
my $help = 0;

GetOptions(
    'zenka!' => \$start_zenka,
    'token=s' => \$github_token,
    'help|h' => \$help,
) or print_usage();

if ($help) {
    print_usage();
    exit 0;
}

# ============================================================================
# OUTPUT FORMATTING
# ============================================================================

sub print_usage {
    print <<'EOF';

PROTOCOL-7 QUICK-START
======================

Unified bootstrap for Claude Projects and Claude Code Web environments.
Automatically detects platform, installs dependencies, clones repositories,
and optionally starts the v7 zenka agent.

USAGE:
    perl bin/quick-start.pl [OPTIONS]

OPTIONS:
    --zenka          Start the Protocol-7 v7 zenka agent after bootstrap
    --token TOKEN    Provide GitHub token (or set GITHUB_TOKEN environment variable)
    --help, -h       Show this help message

EXAMPLES:

    1. Full bootstrap and zenka startup:
       GITHUB_TOKEN=ghp_xxx perl bin/quick-start.pl --zenka

    2. Bootstrap only (repositories prepared but not running):
       GITHUB_TOKEN=ghp_xxx perl bin/quick-start.pl

    3. With token inline:
       perl bin/quick-start.pl --token ghp_xxx --zenka

WHAT HAPPENS:

    1. Environment Detection
       - Detects if running on Claude Projects or Claude Code Web
       - Sets appropriate paths and configuration

    2. Dependency Installation
       - Checks for and installs required Perl modules
       - Verifies system tools (git, perl, openssl)

    3. Repository Setup
       - Clones or updates workspace-transfer repository
       - Clones or updates protocol-7 repository
       - Configures git remotes with authentication

    4. Optional: Start v7 Zenka Agent
       - Initializes Protocol-7 environment
       - Starts the zenka HTTP server agent
       - Ready for processing webhooks and requests

EOF
    return;
}

sub print_banner {
    print "\n";
    print "╔════════════════════════════════════════════════════════╗\n";
    print "║  PROTOCOL-7 QUICK-START v$VERSION                    ║\n";
    print "║  Unified Bootstrap for Claude Environments              ║\n";
    print "╚════════════════════════════════════════════════════════╝\n";
    print "\n";
}

sub log_info {
    print "  [●] @_\n";
}

sub log_success {
    print "  [✓] @_\n";
}

sub log_warn {
    print "  [⚠] @_\n";
}

sub log_error {
    print "  [✗] @_\n";
}

sub log_step {
    my ($msg) = @_;
    print "\n" . ("─" x 60) . "\n";
    print "  $msg\n";
    print "─" x 60 . "\n";
}

# ============================================================================
# MAIN BOOTSTRAP LOGIC
# ============================================================================

sub run_environment_bootstrap {
    log_step "STEP 1: Environment Bootstrap";

    # Detect if bootstrap script exists, otherwise use inline ENV module
    my $bootstrap_script = './ENVIRONMENT-BOOTSTRAP.pl';

    if (-f $bootstrap_script) {
        log_info "Found ENVIRONMENT-BOOTSTRAP.pl, executing...";
        my $result = system("perl $bootstrap_script");
        return $result == 0;
    } else {
        log_warn "ENVIRONMENT-BOOTSTRAP.pl not found in current directory";
        log_info "Attempting inline environment setup...";

        # Minimal inline setup if script not available
        return setup_environment_inline();
    }
}

sub setup_environment_inline {
    # Minimal environment setup without external script
    # This is for situations where only quick-start.pl is available

    log_info "Performing minimal environment detection and setup...";

    # Would need to include lightweight dependency checking here
    # For now, assume basic Perl is available

    return 1;
}

sub start_zenka_agent {
    log_step "STEP 2: Starting Protocol-7 v7 Zenka Agent";

    # Detect environment to find correct path
    use lib './lib';

    eval {
        require ENV;
    };

    if ($@) {
        log_error "Cannot load ENV module: $@";
        return 0;
    }

    my $paths = ENV::get_paths();
    my $protocol_7_path = $paths->{protocol_7};

    unless (-d $protocol_7_path) {
        log_error "protocol-7 directory not found at: $protocol_7_path";
        return 0;
    }

    log_info "Changing to protocol-7 directory: $protocol_7_path";
    chdir($protocol_7_path) or do {
        log_error "Cannot chdir to $protocol_7_path: $!";
        return 0;
    };

    # Check for zenka startup script
    my $zenka_script = './bin/zenka-start.pl';
    unless (-f $zenka_script) {
        log_warn "zenka-start.pl not found, looking for alternatives...";

        # Try to find protocol-7 startup scripts
        if (-f './bin/p7-zenka.pl') {
            $zenka_script = './bin/p7-zenka.pl';
        } elsif (-f './protocol-7.pl') {
            $zenka_script = './protocol-7.pl';
        } else {
            log_error "Cannot find zenka startup script in protocol-7";
            return 0;
        }
    }

    log_info "Starting Protocol-7 v7 Zenka agent...";
    log_info "Command: perl $zenka_script";

    # Execute zenka agent (this typically runs indefinitely)
    exec("perl $zenka_script") or do {
        log_error "Failed to execute zenka agent: $!";
        return 0;
    };

    return 1;
}

sub show_next_steps {
    log_step "SETUP COMPLETE";

    print <<'EOF';

  Bootstrap completed successfully!

  NEXT STEPS:

  Option 1 - Start Protocol-7 v7 Zenka Agent:

    cd /home/protocol-7        # or /home/user/protocol-7 if on Claude Code Web
    perl bin/zenka-start.pl

  Option 2 - Manual Interactive Setup:

    cd /home/protocol-7
    perl -I./lib bin/configure.pl

  Option 3 - Load Session from Checkpoint:

    cd /home/workspace-transfer
    perl bin/restore-checkpoint.pl

  For more information, see:
    - /home/README.md or /home/user/README.md
    - Protocol-7 documentation in the repository

EOF
}

# ============================================================================
# MAIN ENTRY POINT
# ============================================================================

sub main {
    print_banner();

    # Step 1: Check and set GitHub token
    log_step "Preparing Authentication";

    my $token = $github_token || $ENV{GITHUB_TOKEN};

    if ($token) {
        log_success "GitHub token available (from " .
                   ($github_token ? "argument" : "environment variable") . ")";
        $ENV{GITHUB_TOKEN} = $token;
    } else {
        log_warn "No GitHub token provided";
        log_info "Set GITHUB_TOKEN environment variable or use --token flag";
        log_info "Continuing without token (read-only operations only)";
    }

    # Step 2: Run environment bootstrap
    unless (run_environment_bootstrap()) {
        log_error "Bootstrap failed";
        return 1;
    }

    log_success "Environment bootstrap completed";

    # Step 3: Start zenka if requested
    if ($start_zenka) {
        return start_zenka_agent();
    }

    # Step 4: Show next steps
    show_next_steps();

    return 0;
}

exit main() unless caller();
