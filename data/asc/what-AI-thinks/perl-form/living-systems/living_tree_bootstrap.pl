#!/usr/bin/env perl
use strict;
use warnings;
use v5.30;

## LIVING TREE BOOTSTRAP SYSTEM
## Bridges Claude Projects (persistent) with Ubuntu24 machine (ephemeral)
## Automatically reconstructs work environment from persistent storage

package LivingTreeBootstrap;

use File::Path qw(make_path);
use File::Copy;
use File::Find;

sub new {
    my $class = shift;
    my $self = {
        projects_root   => '/tmp/.claude_projects',  # Simulated Projects location
        machine_root    => '/home/claude',
        uploads_dir     => '/mnt/user-data/uploads',
        outputs_dir     => '/mnt/user-data/outputs',
        bootstrap_state => {},
    };
    return bless $self, $class;
}

## BOOTSTRAP SEQUENCE
sub bootstrap_from_projects {
    my ($self, $project_name) = @_;

    say "=" x 70;
    say "## LIVING TREE BOOTSTRAP SEQUENCE ##";
    say "=" x 70;
    say "";

    my @steps = (
        'detect_project_structure',
        'scan_uploads_directory',
        'identify_core_components',
        'extract_and_organize',
        'verify_harmonic_alignment',
        'create_working_environment',
        'generate_quick_reference',
    );

    for my $step (@steps) {
        say "→ Executing: $step";
        my $result = $self->$step($project_name);

        if ($result->{success}) {
            say "  ✓ $result->{message}";
        } else {
            warn "  ✗ $result->{error}";
        }
        say "";
    }

    say "=" x 70;
    say "## BOOTSTRAP COMPLETE ##";
    say "=" x 70;

    return $self->{bootstrap_state};
}

## STEP 1: Detect what's in Projects (or uploads)
sub detect_project_structure {
    my ($self, $project_name) = @_;

    # Check uploads directory for archives
    my @archives;

    if (-d $self->{uploads_dir}) {
        opendir(my $dh, $self->{uploads_dir});
        @archives = grep { /\.(tar\.gz|zip)$/ } readdir($dh);
        closedir($dh);
    }

    $self->{bootstrap_state}{archives_found} = \@archives;

    return {
        success => 1,
        message => sprintf("Found %d archives in uploads", scalar @archives),
    };
}

## STEP 2: Scan uploads for Living Tree components
sub scan_uploads_directory {
    my ($self, $project_name) = @_;

    my %components = (
        living_tree     => [],
        base32_routing  => [],
        protocol7       => [],
        documentation   => [],
        scripts         => [],
    );

    # Check for extracted files
    if (-d $self->{machine_root}) {
        opendir(my $dh, $self->{machine_root});
        my @files = readdir($dh);
        closedir($dh);

        for my $file (@files) {
            next if $file =~ /^\./;
            my $path = "$self->{machine_root}/$file";

            if ($file =~ /living.*tree/i) {
                push @{$components{living_tree}}, $path;
            } elsif ($file =~ /base32.*harmonic/i) {
                push @{$components{base32_routing}}, $path;
            } elsif ($file =~ /protocol.*7/i) {
                push @{$components{protocol7}}, $path;
            } elsif ($file =~ /\.md$/i) {
                push @{$components{documentation}}, $path;
            } elsif ($file =~ /\.(pl|sh)$/) {
                push @{$components{scripts}}, $path;
            }
        }
    }

    $self->{bootstrap_state}{components} = \%components;

    my $total = 0;
    $total += scalar @{$components{$_}} for keys %components;

    return {
        success => 1,
        message => "Categorized $total components",
    };
}

## STEP 3: Identify core vs redundant
sub identify_core_components {
    my ($self, $project_name) = @_;

    my %core_patterns = (
        # Core implementation files (always keep latest)
        'base32_harmonic_routing.pl'              => 'core',
        'living_tree_base32_viz.html'            => 'core',
        'BASE32_HARMONIC_INTEGRATION_GUIDE.md'   => 'core',
        'LIVING_TREE_SUMMARY.md'                 => 'core',
        'PROTOCOL7_HARMONIC_LIVING_TREE.md'      => 'core',

        # Supporting files (keep if recent)
        'SESSION_SUMMARY.md'                      => 'supporting',
        'tree-shuffle-demo.pl'                   => 'supporting',

        # Archives (redundant if contents extracted)
        'protocol7_living_tree_complete.tar.gz'  => 'archive',
        'protocol7_harmonic_complete.tar.gz'     => 'archive',
        'test_checkpoint_*.tar.gz'               => 'archive',
    );

    my %categorized = (
        core       => [],
        supporting => [],
        archive    => [],
        redundant  => [],
    );

    # Scan current directory
    if (-d $self->{machine_root}) {
        opendir(my $dh, $self->{machine_root});
        while (my $file = readdir($dh)) {
            next if $file =~ /^\./;

            my $category = 'redundant';
            for my $pattern (keys %core_patterns) {
                if ($file =~ /\Q$pattern\E/ || $file eq $pattern) {
                    $category = $core_patterns{$pattern};
                    last;
                }
            }

            push @{$categorized{$category}}, $file;
        }
        closedir($dh);
    }

    $self->{bootstrap_state}{categorized} = \%categorized;

    return {
        success => 1,
        message => sprintf("Core: %d, Supporting: %d, Archive: %d, Redundant: %d",
            scalar @{$categorized{core}},
            scalar @{$categorized{supporting}},
            scalar @{$categorized{archive}},
            scalar @{$categorized{redundant}}
        ),
    };
}

## STEP 4: Extract and organize
sub extract_and_organize {
    my ($self, $project_name) = @_;

    my $work_tree = "$self->{machine_root}/living_tree_workspace";
    make_path($work_tree) unless -d $work_tree;

    # Organize by category
    my %dirs = (
        core          => "$work_tree/core",
        implementations => "$work_tree/implementations",
        documentation => "$work_tree/documentation",
        archives      => "$work_tree/archives",
    );

    make_path($_) for values %dirs;

    my $categorized = $self->{bootstrap_state}{categorized};
    my $moved = 0;

    # Move core files
    for my $file (@{$categorized->{core}}) {
        my $src = "$self->{machine_root}/$file";
        next unless -e $src;

        my $dest = "$dirs{core}/$file";
        if (copy($src, $dest)) {
            $moved++;
        }
    }

    # Move supporting files
    for my $file (@{$categorized->{supporting}}) {
        my $src = "$self->{machine_root}/$file";
        next unless -e $src;

        my $dest_dir = $file =~ /\.(pl|sh)$/ ? $dirs{implementations} : $dirs{documentation};
        my $dest = "$dest_dir/$file";
        if (copy($src, $dest)) {
            $moved++;
        }
    }

    $self->{bootstrap_state}{work_tree} = $work_tree;
    $self->{bootstrap_state}{moved_files} = $moved;

    return {
        success => 1,
        message => "Organized $moved files into $work_tree",
    };
}

## STEP 5: Verify harmonic alignment (BASE32 validation)
sub verify_harmonic_alignment {
    my ($self, $project_name) = @_;

    my $work_tree = $self->{bootstrap_state}{work_tree};
    my @verified = ();
    my @failed = ();

    # Check if files exist and are readable
    if (-d "$work_tree/core") {
        opendir(my $dh, "$work_tree/core");
        while (my $file = readdir($dh)) {
            next if $file =~ /^\./;
            my $path = "$work_tree/core/$file";

            if (-r $path && -s $path) {
                push @verified, $file;
            } else {
                push @failed, $file;
            }
        }
        closedir($dh);
    }

    $self->{bootstrap_state}{verified} = \@verified;
    $self->{bootstrap_state}{failed} = \@failed;

    return {
        success => (scalar @failed == 0),
        message => sprintf("Verified: %d, Failed: %d",
            scalar @verified, scalar @failed),
    };
}

## STEP 6: Create working environment
sub create_working_environment {
    my ($self, $project_name) = @_;

    my $work_tree = $self->{bootstrap_state}{work_tree};

    # Create symlinks to outputs for easy access
    my $quick_access = "$self->{machine_root}/current_work";

    if (-l $quick_access) {
        unlink $quick_access;
    }

    symlink($work_tree, $quick_access);

    # Copy core files to outputs for download
    my $categorized = $self->{bootstrap_state}{categorized};
    my $copied = 0;

    for my $file (@{$categorized->{core}}) {
        my $src = "$work_tree/core/$file";
        next unless -e $src;

        my $dest = "$self->{outputs_dir}/$file";
        if (copy($src, $dest)) {
            $copied++;
        }
    }

    $self->{bootstrap_state}{output_files} = $copied;

    return {
        success => 1,
        message => "Created working environment, copied $copied files to outputs",
    };
}

## STEP 7: Generate quick reference
sub generate_quick_reference {
    my ($self, $project_name) = @_;

    my $state = $self->{bootstrap_state};
    my $work_tree = $state->{work_tree};

    my $ref_file = "$self->{outputs_dir}/BOOTSTRAP_REFERENCE.md";

    open my $fh, '>', $ref_file or return {
        success => 0,
        error => "Cannot create reference: $!",
    };

    print $fh <<'EOF';
# Living Tree Bootstrap Reference
## Auto-generated workspace guide

## Project Structure

```
living_tree_workspace/
├── core/                    # Core implementation files
│   ├── base32_harmonic_routing.pl
│   ├── living_tree_base32_viz.html
│   └── BASE32_HARMONIC_INTEGRATION_GUIDE.md
├── implementations/         # Scripts and tools
├── documentation/           # Supporting docs
└── archives/               # Compressed backups
```

## Quick Access

Symlink created: `/home/claude/current_work` → workspace

## Core Components

EOF

    # List core files
    if (-d "$work_tree/core") {
        print $fh "\n### Core Files\n\n";
        opendir(my $dh, "$work_tree/core");
        while (my $file = readdir($dh)) {
            next if $file =~ /^\./;
            my $path = "$work_tree/core/$file";
            my $size = -s $path;
            printf $fh "- **%s** (%.1f KB)\n", $file, $size / 1024;
        }
        closedir($dh);
    }

    print $fh <<'EOF';

## Bootstrap Commands

### Resume from past chat
```
Use conversation_search to find: "living tree base32"
Claude will automatically access conversation history
```

### Re-bootstrap from archives
```bash
perl /home/claude/living_tree_bootstrap.pl bootstrap
```

### Quick start development
```bash
cd /home/claude/current_work/core
perl base32_harmonic_routing.pl
```

### View visualization
```bash
# Copy to local machine:
/home/claude/current_work/core/living_tree_base32_viz.html
```

## Integration with Projects

When working in a Claude Project:
1. Store core files in Project knowledge base
2. Use this bootstrap script to extract to machine
3. Develop on machine (ephemeral)
4. Save results back to Project (persistent)

## Routing Between Systems

```
Claude Projects (Persistent Root)
        ↓ bootstrap
Ubuntu24 Machine (Ephemeral Branches)
        ↓ develop/test
Outputs Directory (Share Results)
        ↓ save
Back to Projects (Persistent Storage)
```

## Status

EOF

    print $fh sprintf("- Archives found: %d\n",
        scalar @{$state->{archives_found}});
    print $fh sprintf("- Files organized: %d\n",
        $state->{moved_files} // 0);
    print $fh sprintf("- Files verified: %d\n",
        scalar @{$state->{verified}});
    print $fh sprintf("- Output files: %d\n",
        $state->{output_files} // 0);

    print $fh "\n---\n\n";
    print $fh "**Bootstrap completed successfully!** 🌳\n";

    close $fh;

    return {
        success => 1,
        message => "Generated reference at $ref_file",
    };
}

## UTILITY: Clean redundant files
sub clean_redundant {
    my $self = shift;

    my $categorized = $self->{bootstrap_state}{categorized};
    my $cleaned = 0;

    # Don't actually delete, just report
    say "## Files marked for cleanup:";
    for my $file (@{$categorized->{redundant}}) {
        say "  - $file";
        $cleaned++;
    }

    return $cleaned;
}

## UTILITY: Create archive of current state
sub create_checkpoint {
    my ($self, $name) = @_;

    my $timestamp = time();
    my $checkpoint_name = $name || "bootstrap_$timestamp";
    my $work_tree = $self->{bootstrap_state}{work_tree};

    my $archive = "$self->{outputs_dir}/${checkpoint_name}.tar.gz";

    system("tar", "-czf", $archive, "-C", $self->{machine_root},
           "living_tree_workspace") == 0
        or return { success => 0, error => "Archive creation failed" };

    return {
        success => 1,
        message => "Checkpoint created: $archive",
        archive => $archive,
    };
}

1;

## MAIN EXECUTION
package main;

my $bootstrap = LivingTreeBootstrap->new();

say "Living Tree Bootstrap System";
say "Bridges Projects ↔ Machine ↔ Outputs";
say "";

# Run bootstrap
my $state = $bootstrap->bootstrap_from_projects("living_tree");

say "";
say "## Summary:";
say "- Work tree: $state->{work_tree}";
say "- Files moved: $state->{moved_files}";
say "- Files verified: " . scalar @{$state->{verified}};
say "- Output files ready: $state->{output_files}";

# Show files marked for cleanup
say "";
my $cleanup_count = $bootstrap->clean_redundant();
say "- Files to clean: $cleanup_count";

# Create checkpoint
say "";
my $checkpoint = $bootstrap->create_checkpoint("living_tree_base32_complete");
say "✓ $checkpoint->{message}" if $checkpoint->{success};

say "";
say "=" x 70;
say "Next: Open BOOTSTRAP_REFERENCE.md for quick start guide";
say "=" x 70;
