#!/usr/bin/perl
# bin/commit-bootstrap.pl - Prepare and commit unified bootstrap to base branch
# Usage: GITHUB_TOKEN="ghp_xxx" perl bin/commit-bootstrap.pl
# Or from workspace-transfer: perl bin/commit-bootstrap.pl

use strict;
use warnings;
use File::Spec;
use Cwd qw(cwd abs_path);

my $VERSION = '0.6-unified';

# ============================================================================
# CONFIGURATION
# ============================================================================

my %FILES_TO_COMMIT = (
    # Core scripts
    'ENVIRONMENT-BOOTSTRAP.pl' => 'Master bootstrap orchestrator for unified initialization',
    'lib/ENV.pm' => 'Environment detection and path resolution module',
    'bin/quick-start.pl' => 'User-facing entry point with professional interface',

    # Documentation
    'INDEX.md' => 'Navigation hub and quick reference guide',
    'README-UNIFIED-BOOTSTRAP.md' => 'Complete implementation summary and overview',
    'QUICK-REFERENCE.md' => 'Quick command reference and cheat sheet',
    'UNIFIED-BOOTSTRAP-README.md' => 'Detailed complete guide with troubleshooting',
    'BOOTSTRAP-MIGRATION-GUIDE.md' => 'Architecture documentation and migration guide',
    'SYSTEM-ARCHITECTURE.md' => 'Technical deep dive with diagrams and integration',
);

my $COMMIT_MESSAGE = <<'EOF';
[CLAUDE] Add unified bootstrap system for Protocol-7 (v0.6-unified)

Consolidated initialization across Claude Projects and Claude Code Web:

FEATURES:
- Single ENVIRONMENT-BOOTSTRAP.pl script for all platforms
- Automatic platform detection (Claude Projects vs Code Web)
- ENV module for environment-aware path resolution
- Unified dependency management and repository setup
- One or two commands to get Protocol-7 running (1-2 min first, <30s after)

CORE FILES:
- ENVIRONMENT-BOOTSTRAP.pl: Master bootstrap orchestrator
- lib/ENV.pm: Environment detection and configuration
- bin/quick-start.pl: User-facing entry point

DOCUMENTATION (6 files):
- INDEX.md: Navigation hub
- README-UNIFIED-BOOTSTRAP.md: Implementation summary
- QUICK-REFERENCE.md: Cheat sheet
- UNIFIED-BOOTSTRAP-README.md: Complete guide
- BOOTSTRAP-MIGRATION-GUIDE.md: Architecture & migration
- SYSTEM-ARCHITECTURE.md: Technical details

PLATFORM SUPPORT:
- Claude Projects: /home/ paths, auto-detected
- Claude Code Web: /home/user/ paths, auto-detected
- Identical commands work on both platforms

WHAT HAPPENS AUTOMATICALLY:
1. Detects platform (hostname, mounts, paths)
2. Checks/installs Perl dependencies (CryptX, JSON::PP, etc.)
3. Clones workspace-transfer and protocol-7
4. Configures git remotes with authentication
5. Generates configuration (bootstrap.json, github.token)
6. Verifies complete setup

QUICKEST START:
  GITHUB_TOKEN="ghp_xxx" perl ENVIRONMENT-BOOTSTRAP.pl && \
  cd /home/protocol-7 && perl bin/zenka-start.pl

RESULT: Complete Protocol-7 system ready in 1-2 minutes
EOF

# ============================================================================
# OUTPUT FORMATTING
# ============================================================================

sub log_step {
    my ($msg) = @_;
    print "\n" . ("=" x 70) . "\n";
    print "  $msg\n";
    print "=" x 70 . "\n";
}

sub log_info {
    print "  [●] @_\n";
}

sub log_success {
    print "  [✓] @_\n";
}

sub log_error {
    print "  [✗] @_\n";
}

# ============================================================================
# GIT OPERATIONS
# ============================================================================

sub prepare_commit {
    log_step("Preparing Unified Bootstrap Commit");

    # Check if we're in a git repository
    my $git_check = system("git rev-parse --git-dir >/dev/null 2>&1");
    if ($git_check != 0) {
        log_error "Not in a git repository";
        log_info "Please run this from workspace-transfer or protocol-7 directory";
        return 0;
    }

    log_success "Git repository detected";

    # Verify git configuration
    my $user = `git config user.name 2>/dev/null`;
    chomp $user;
    my $email = `git config user.email 2>/dev/null`;
    chomp $email;

    if ($user && $email) {
        log_info "Git configured: $user <$email>";
    } else {
        log_info "Configuring git for commit...";
        system("git config user.name 'Protocol-7 Bootstrap System' 2>/dev/null");
        system("git config user.email 'protocol-7@nailara.local' 2>/dev/null");
        log_success "Git configured";
    }

    return 1;
}

sub verify_files {
    log_step("Verifying Bootstrap Files");

    my $all_present = 1;
    foreach my $file (sort keys %FILES_TO_COMMIT) {
        if (-f $file) {
            log_success "$file";
        } else {
            log_error "$file - NOT FOUND";
            $all_present = 0;
        }
    }

    return $all_present;
}

sub stage_files {
    log_step("Staging Files for Commit");

    foreach my $file (sort keys %FILES_TO_COMMIT) {
        if (-f $file) {
            my $result = system("git add '$file' 2>/dev/null");
            if ($result == 0) {
                log_info "Staged: $file";
            } else {
                log_error "Failed to stage: $file";
                return 0;
            }
        }
    }

    # Show staged changes
    log_info "Checking staged changes...";
    system("git status --short 2>/dev/null");

    return 1;
}

sub show_commit_details {
    log_step("Commit Details");

    print "\nCOMMIT MESSAGE:\n";
    print "─" x 70 . "\n";
    print $COMMIT_MESSAGE;
    print "─" x 70 . "\n";

    print "\nFILES TO COMMIT (" . scalar(keys %FILES_TO_COMMIT) . "):\n";
    foreach my $file (sort keys %FILES_TO_COMMIT) {
        print "  ✓ $file\n";
        print "    └─ " . $FILES_TO_COMMIT{$file} . "\n";
    }
}

sub create_commit {
    log_step("Creating Commit");

    my $msg_file = '/tmp/commit_msg_bootstrap.txt';
    open my $fh, '>', $msg_file or do {
        log_error "Cannot create commit message file: $!";
        return 0;
    };
    print $fh $COMMIT_MESSAGE;
    close $fh;

    my $result = system("git commit -F '$msg_file' 2>/dev/null");

    unlink $msg_file;

    if ($result == 0) {
        log_success "Commit created successfully";

        # Show commit info
        system("git log -1 --oneline");
        return 1;
    } else {
        log_error "Failed to create commit";
        return 0;
    }
}

sub show_push_instructions {
    log_step("Ready to Push");

    my $current_branch = `git rev-parse --abbrev-ref HEAD 2>/dev/null`;
    chomp $current_branch;

    print <<EOF;

YOUR COMMIT IS READY TO PUSH TO BASE BRANCH

Current branch: $current_branch
Bootstrap version: $VERSION

NEXT STEPS:

1. Verify commit looks good:
   git log -1

2. Push to base branch:
   git push origin base

   Or with token (if needed):
   git push https://TOKEN\@github.com/nailara-technologies/workspace-transfer.git base

3. After push, workspace-transfer and protocol-7 can use:
   - ENVIRONMENT-BOOTSTRAP.pl for initialization
   - lib/ENV.pm for environment detection
   - bin/quick-start.pl as user entry point

4. Test in any Claude environment:
   GITHUB_TOKEN="ghp_xxx" perl ENVIRONMENT-BOOTSTRAP.pl && \\
   cd /home/protocol-7 && perl bin/zenka-start.pl

DOCUMENTATION:
   - Start with: INDEX.md
   - Quick commands: QUICK-REFERENCE.md
   - Full guide: UNIFIED-BOOTSTRAP-README.md
   - Technical: SYSTEM-ARCHITECTURE.md

EOF
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

sub main {
    print "\n";
    print "╔══════════════════════════════════════════════════════════════════╗\n";
    print "║  UNIFIED BOOTSTRAP COMMIT WORKFLOW (v$VERSION)                  ║\n";
    print "║  Protocol-7 Multi-Platform Initialization System                ║\n";
    print "╚══════════════════════════════════════════════════════════════════╝\n";

    # Step 1: Prepare
    unless (prepare_commit()) {
        log_error "Cannot proceed without git repository";
        return 1;
    }

    # Step 2: Verify files
    unless (verify_files()) {
        log_error "Some files missing. Commit aborted.";
        return 1;
    }

    # Step 3: Show details
    show_commit_details();

    # Step 4: Stage files
    unless (stage_files()) {
        log_error "Failed to stage files";
        return 1;
    }

    # Step 5: Create commit
    unless (create_commit()) {
        log_error "Failed to create commit";
        return 1;
    }

    # Step 6: Show push instructions
    show_push_instructions();

    log_step("Commit Preparation Complete");
    print "\n✅ Bootstrap system ready to commit!\n\n";

    return 0;
}

exit main() unless caller();
