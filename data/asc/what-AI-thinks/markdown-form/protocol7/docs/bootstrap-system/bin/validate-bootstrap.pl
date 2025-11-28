#!/usr/bin/perl
# bin/validate-bootstrap.pl - Comprehensive validation of unified bootstrap system
# Run without external dependencies to verify all components work

use strict;
use warnings;
use File::Spec;
use File::Temp qw(tempdir);
use Cwd qw(cwd abs_path);

my $VERSION = '0.6-unified';
my $TESTS_PASSED = 0;
my $TESTS_FAILED = 0;

# ============================================================================
# TEST FRAMEWORK
# ============================================================================

sub test_start {
    my ($name) = @_;
    print "\n[TEST] $name\n";
    print "─" x 70 . "\n";
}

sub test_pass {
    my ($msg) = @_;
    print "  ✓ PASS: $msg\n";
    $TESTS_PASSED++;
}

sub test_fail {
    my ($msg) = @_;
    print "  ✗ FAIL: $msg\n";
    $TESTS_FAILED++;
}

sub test_info {
    my ($msg) = @_;
    print "  [i] $msg\n";
}

# ============================================================================
# VALIDATION TESTS
# ============================================================================

sub test_files_exist {
    test_start("FILE EXISTENCE CHECK");

    my @required_files = (
        'ENVIRONMENT-BOOTSTRAP.pl',
        'lib/ENV.pm',
        'bin/quick-start.pl',
        'INDEX.md',
        'README-UNIFIED-BOOTSTRAP.md',
        'QUICK-REFERENCE.md',
        'UNIFIED-BOOTSTRAP-README.md',
        'BOOTSTRAP-MIGRATION-GUIDE.md',
        'SYSTEM-ARCHITECTURE.md',
    );

    foreach my $file (@required_files) {
        if (-f $file) {
            my $size = -s $file;
            test_pass "$file ($size bytes)";
        } else {
            test_fail "$file - NOT FOUND";
        }
    }
}

sub test_script_executability {
    test_start("SCRIPT EXECUTABILITY CHECK");

    my @scripts = (
        'ENVIRONMENT-BOOTSTRAP.pl',
        'bin/quick-start.pl',
    );

    foreach my $script (@scripts) {
        if (-f $script) {
            if (-x $script) {
                test_pass "$script is executable";
            } else {
                test_fail "$script is not executable";
            }
        }
    }
}

sub test_perl_syntax {
    test_start("PERL SYNTAX CHECK");

    my @perl_files = (
        'ENVIRONMENT-BOOTSTRAP.pl',
        'lib/ENV.pm',
        'bin/quick-start.pl',
    );

    foreach my $file (@perl_files) {
        if (-f $file) {
            my $result = system("perl -c '$file' >/dev/null 2>&1");
            if ($result == 0) {
                test_pass "$file syntax is valid";
            } else {
                test_fail "$file has syntax errors";
            }
        }
    }
}

sub test_env_module_functionality {
    test_start("ENV MODULE FUNCTIONALITY");

    my $test_code = <<'PERL';
use strict;
use warnings;
use lib './lib';

# Test 1: Can load module
eval { require ENV; };
if ($@) {
    print "FAIL: Cannot load ENV module: $@\n";
    exit 1;
}
print "PASS: ENV module loads\n";

# Test 2: Can detect platform
my $platform = ENV::detect_platform();
if ($platform && ($platform eq 'claude_projects' || $platform eq 'claude_code_web')) {
    print "PASS: Platform detected: $platform\n";
} else {
    print "FAIL: Invalid platform detection: $platform\n";
    exit 1;
}

# Test 3: Can get paths
my $paths = ENV::get_paths();
if (ref($paths) eq 'HASH' && exists $paths->{workspace_transfer}) {
    print "PASS: Paths resolved\n";
} else {
    print "FAIL: Cannot get paths\n";
    exit 1;
}

# Test 4: Path consistency
if ($paths->{workspace_transfer} && $paths->{protocol_7}) {
    print "PASS: Both repository paths present\n";
} else {
    print "FAIL: Missing repository paths\n";
    exit 1;
}

# Test 5: Boolean checks
my $is_proj = ENV::is_projects();
my $is_web = ENV::is_code_web();
if (($is_proj && !$is_web) || (!$is_proj && $is_web)) {
    print "PASS: Boolean platform checks work\n";
} else {
    print "FAIL: Platform boolean checks failed\n";
    exit 1;
}

print "ALL ENV MODULE TESTS PASSED\n";
exit 0;
PERL

    # Write test to temp file and run it
    my $test_file = '/tmp/env_module_test.pl';
    open my $fh, '>', $test_file or die "Cannot create test file: $!";
    print $fh $test_code;
    close $fh;

    my $output = `perl '$test_file' 2>&1`;
    unlink $test_file;

    foreach my $line (split /\n/, $output) {
        if ($line =~ /^PASS: (.+)/) {
            test_pass $1;
        } elsif ($line =~ /^FAIL: (.+)/) {
            test_fail $1;
        } elsif ($line =~ /^ALL ENV/) {
            test_pass "Module integration test passed";
        }
    }
}

sub test_bootstrap_script_functions {
    test_start("BOOTSTRAP SCRIPT STRUCTURE");

    my $script = 'ENVIRONMENT-BOOTSTRAP.pl';
    open my $fh, '<', $script or do {
        test_fail "Cannot read $script";
        return;
    };

    my $content = do { local $/; <$fh> };
    close $fh;

    my @required_functions = (
        'detect_environment',
        'check_perl_module',
        'install_cpan_modules',
        'check_system_tools',
        'clone_or_update_repo',
        'configure_git_remote',
        'verify_setup',
        'generate_config',
    );

    foreach my $func (@required_functions) {
        if ($content =~ /sub\s+$func\s*\{/) {
            test_pass "Function $func() defined";
        } else {
            test_fail "Function $func() not found";
        }
    }
}

sub test_documentation_completeness {
    test_start("DOCUMENTATION COMPLETENESS");

    my @docs = (
        { file => 'QUICK-REFERENCE.md', must_contain => 'GITHUB_TOKEN' },
        { file => 'INDEX.md', must_contain => 'Getting Started' },
        { file => 'README-UNIFIED-BOOTSTRAP.md', must_contain => 'Quick Start' },
        { file => 'UNIFIED-BOOTSTRAP-README.md', must_contain => 'Usage' },
        { file => 'BOOTSTRAP-MIGRATION-GUIDE.md', must_contain => 'Old' },
        { file => 'SYSTEM-ARCHITECTURE.md', must_contain => 'Directory' },
    );

    foreach my $doc (@docs) {
        if (-f $doc->{file}) {
            open my $fh, '<', $doc->{file} or next;
            my $content = do { local $/; <$fh> };
            close $fh;

            if ($content =~ /$doc->{must_contain}/i) {
                test_pass "$doc->{file} contains expected content";
            } else {
                test_fail "$doc->{file} missing key content: '$doc->{must_contain}'";
            }
        } else {
            test_fail "$doc->{file} not found";
        }
    }
}

sub test_configuration_example {
    test_start("CONFIGURATION FILE EXAMPLES");

    my $arch_doc = 'SYSTEM-ARCHITECTURE.md';
    if (-f $arch_doc) {
        open my $fh, '<', $arch_doc or return;
        my $content = do { local $/; <$fh> };
        close $fh;

        if ($content =~ /bootstrap\.json/) {
            test_pass "bootstrap.json example present";
        } else {
            test_fail "bootstrap.json example missing";
        }

        if ($content =~ /"setup_complete"/) {
            test_pass "Configuration structure documented";
        } else {
            test_fail "Configuration structure not documented";
        }
    }
}

sub test_platform_support {
    test_start("PLATFORM SUPPORT DOCUMENTATION");

    my $doc = 'QUICK-REFERENCE.md';
    if (-f $doc) {
        open my $fh, '<', $doc or return;
        my $content = do { local $/; <$fh> };
        close $fh;

        my $projects_refs = ($content =~ /Claude Projects/gi) // 0;
        my $web_refs = ($content =~ /Claude Code Web|runsc/gi) // 0;

        if ($projects_refs >= 2) {
            test_pass "Claude Projects documented ($projects_refs references)";
        } else {
            test_fail "Claude Projects documentation insufficient";
        }

        if ($web_refs >= 2) {
            test_pass "Claude Code Web documented ($web_refs references)";
        } else {
            test_fail "Claude Code Web documentation insufficient";
        }
    }
}

sub test_error_handling {
    test_start("ERROR HANDLING AND LOGGING");

    my $script = 'ENVIRONMENT-BOOTSTRAP.pl';
    open my $fh, '<', $script or return;
    my $content = do { local $/; <$fh> };
    close $fh;

    my @error_functions = (
        'log_error',
        'log_warn',
        'log_success',
        'log_info',
    );

    foreach my $func (@error_functions) {
        if ($content =~ /sub\s+$func/) {
            test_pass "Logging function $func() defined";
        } else {
            test_fail "Logging function $func() missing";
        }
    }
}

sub test_security_features {
    test_start("SECURITY FEATURES");

    my $env_module = 'lib/ENV.pm';
    open my $fh, '<', $env_module or return;
    my $content = do { local $/; <$fh> };
    close $fh;

    if ($content =~ /chmod.*0600|permissions/) {
        test_pass "Token file permission handling present";
    } else {
        test_fail "Token file permission documentation missing";
    }

    if ($content =~ /save_token/) {
        test_pass "Token storage function defined";
    } else {
        test_fail "Token storage function missing";
    }

    if ($content =~ /get_token/) {
        test_pass "Token retrieval function defined";
    } else {
        test_fail "Token retrieval function missing";
    }
}

sub test_idempotency_documentation {
    test_start("IDEMPOTENCY DOCUMENTATION");

    my $doc = 'UNIFIED-BOOTSTRAP-README.md';
    if (-f $doc) {
        open my $fh, '<', $doc or return;
        my $content = do { local $/; <$fh> };
        close $fh;

        if ($content =~ /idempotent|run multiple times|safe to re/i) {
            test_pass "Idempotency properties documented";
        } else {
            test_fail "Idempotency not documented";
        }
    }
}

# ============================================================================
# MAIN TEST RUNNER
# ============================================================================

sub main {
    print "\n";
    print "╔══════════════════════════════════════════════════════════════════╗\n";
    print "║  UNIFIED BOOTSTRAP VALIDATION TEST SUITE (v$VERSION)              ║\n";
    print "║  Protocol-7 System Verification                                  ║\n";
    print "╚══════════════════════════════════════════════════════════════════╝\n";

    # Run all tests
    test_files_exist();
    test_script_executability();
    test_perl_syntax();
    test_env_module_functionality();
    test_bootstrap_script_functions();
    test_documentation_completeness();
    test_configuration_example();
    test_platform_support();
    test_error_handling();
    test_security_features();
    test_idempotency_documentation();

    # Summary
    print "\n";
    print "╔══════════════════════════════════════════════════════════════════╗\n";
    print "║  TEST SUMMARY                                                    ║\n";
    print "╚══════════════════════════════════════════════════════════════════╝\n";
    print "\n  Passed: $TESTS_PASSED ✓\n";
    print "  Failed: $TESTS_FAILED ✗\n";

    if ($TESTS_FAILED == 0) {
        print "\n  🎉 ALL TESTS PASSED! System ready for deployment.\n\n";
        return 0;
    } else {
        print "\n  ⚠️  Some tests failed. Review output above.\n\n";
        return 1;
    }
}

exit main() unless caller();
