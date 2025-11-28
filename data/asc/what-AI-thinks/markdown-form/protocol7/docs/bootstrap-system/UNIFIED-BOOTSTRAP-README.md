# Protocol-7 Unified Bootstrap System

## Overview

The unified bootstrap system provides a single, consistent way to prepare Protocol-7 across both **Claude Projects** and **Claude Code Web** environments. It automatically detects your platform, installs dependencies, clones repositories, and can start the v7 zenka agent with minimal commands.

**Designed Outcome:** One or two commands to get a running Protocol-7 system.

## Quick Start

### For Claude Projects

```bash
# 1. Set your GitHub token (export or inline)
export GITHUB_TOKEN="ghp_your_token_here"

# 2. Run the complete bootstrap + zenka startup
perl /home/ENVIRONMENT-BOOTSTRAP.pl
cd /home/protocol-7
perl bin/zenka-start.pl
```

Or in one pipeline:
```bash
GITHUB_TOKEN="ghp_xxx" perl /home/bin/quick-start.pl --zenka
```

### For Claude Code Web (runsc)

```bash
# 1. Set your GitHub token
export GITHUB_TOKEN="ghp_your_token_here"

# 2. Run the complete bootstrap + zenka startup
perl /home/user/ENVIRONMENT-BOOTSTRAP.pl
cd /home/user/protocol-7
perl bin/zenka-start.pl
```

Or in one pipeline:
```bash
GITHUB_TOKEN="ghp_xxx" perl /home/user/bin/quick-start.pl --zenka
```

## How It Works

### 1. **Environment Detection** (Automatic)

The system detects your platform by checking:

- **Claude Projects:** Checks for `/mnt/project` directory and `/home/protocol-7` path
  - Repositories cloned to: `/home/workspace-transfer` and `/home/protocol-7`
  - Token storage: `/home/.config/github.token`
  - Lib path: `/home/lib`

- **Claude Code Web:** Checks for `runsc` hostname or `/home/user/` path
  - Repositories cloned to: `/home/user/workspace-transfer` and `/home/user/protocol-7`
  - Token storage: `/home/user/.config/github.token`
  - Lib path: `/home/user/lib`

### 2. **Dependency Installation**

Automatically installs or verifies:

#### Perl Modules
- `Crypt::Twofish_PP` - Encryption
- `CryptX` - Cryptographic utilities
- `Digest::SHA` - Hashing
- `MIME::Base32` - Encoding
- `JSON::PP` - Configuration and data
- `File::Temp` - Temporary file handling
- `Sys::Hostname` - Environment detection

#### System Tools
- `git` - Repository management
- `perl` - Script execution
- `openssl` - Cryptography
- `curl` - HTTP operations

### 3. **Repository Setup**

For both repositories (workspace-transfer and protocol-7):

1. Clones from GitHub if not already present
2. Updates existing repositories with `git pull origin base`
3. Configures git remote with authenticated HTTPS URL
4. Stores configuration in JSON format

### 4. **Configuration Management**

Creates `.config` directory structure:

```
/home/.config/                          # Claude Projects
  ├── bootstrap.json                    # Setup configuration
  ├── github.token                      # GitHub authentication (600 permissions)
  └── ... (other configs)

/home/user/.config/                     # Claude Code Web
  ├── bootstrap.json
  ├── github.token
  └── ...
```

## Usage Guide

### Basic Bootstrap (Prepare Repositories Only)

```bash
export GITHUB_TOKEN="ghp_your_token"
perl ENVIRONMENT-BOOTSTRAP.pl
```

**What it does:**
- Detects your platform
- Installs all dependencies
- Clones workspace-transfer and protocol-7
- Sets up git authentication
- Verifies all components

**What you need next:**
- Navigate to protocol-7 directory
- Run zenka startup script manually

### Full Deployment (Bootstrap + Start Zenka)

```bash
export GITHUB_TOKEN="ghp_your_token"
perl bin/quick-start.pl --zenka
```

**What it does:**
- Runs complete environment bootstrap
- Automatically starts v7 zenka agent
- System immediately ready for processing

### From Clean Environment

If you have **only** the quick-start script available:

```bash
GITHUB_TOKEN="ghp_xxx" perl bin/quick-start.pl --zenka
```

This runs:
1. `ENVIRONMENT-BOOTSTRAP.pl` (if available)
2. Starts zenka agent
3. System ready for Protocol-7 operations

## Script Reference

### ENVIRONMENT-BOOTSTRAP.pl

**Purpose:** Complete environment initialization

**Usage:**
```bash
perl ENVIRONMENT-BOOTSTRAP.pl [OPTIONS]
```

**What it does:**
1. Detects platform (Claude Projects vs Code Web)
2. Checks and installs Perl dependencies
3. Verifies system tools
4. Clones/updates repositories
5. Configures git authentication
6. Generates configuration files
7. Verifies setup completeness

**Environment Variables:**
- `GITHUB_TOKEN` - GitHub personal access token (required for cloning)

**Output:**
- Configuration files in `.config/`
- Repositories in appropriate paths
- JSON bootstrap config with environment details

### quick-start.pl

**Purpose:** Unified entry point for bootstrap + zenka startup

**Usage:**
```bash
perl bin/quick-start.pl [OPTIONS]
```

**Options:**
- `--zenka` - Start Protocol-7 v7 zenka agent after bootstrap
- `--token TOKEN` - Provide GitHub token inline
- `--help` - Show help message

**Examples:**

```bash
# Full bootstrap and zenka start
GITHUB_TOKEN="ghp_xxx" perl bin/quick-start.pl --zenka

# Bootstrap only
GITHUB_TOKEN="ghp_xxx" perl bin/quick-start.pl

# With inline token
perl bin/quick-start.pl --token ghp_xxx --zenka
```

### lib/ENV.pm

**Purpose:** Environment detection and path resolution module

**Exports:**
```perl
use ENV qw(:all);

detect_platform()      # Returns 'claude_projects' or 'claude_code_web'
get_paths()           # Returns hashref with platform paths
is_projects()         # Boolean check
is_code_web()         # Boolean check
resolve_path($key)    # Get specific path
ensure_config_dir()   # Create .config if needed
load_config($name)    # Load JSON config
save_config($data)    # Save JSON config
get_token()          # Retrieve GitHub token
save_token($token)    # Store GitHub token securely
```

**Usage in Scripts:**
```perl
use lib './lib';
use ENV qw(:all);

my $paths = get_paths();
print "Workspace Transfer: " . $paths->{workspace_transfer} . "\n";

my $token = get_token();
```

## Dependency Management Strategy

### Handling Missing Dependencies

If a required Perl module cannot be installed:

1. System logs a warning
2. Bootstrap continues (not all modules are strictly required)
3. Later errors will indicate which module caused the issue
4. User can manually install with `cpanm Module::Name`

### Environment-Specific Dependencies

**Claude Projects:**
- May have different Perl versions
- Includes `Readonly` and `autodie` modules for safety

**Claude Code Web:**
- Standard Perl environment
- Includes `parent` module for compatibility

## Troubleshooting

### GitHub Token Not Found

**Error:** "GitHub token not found"

**Solution:**
```bash
# Option 1: Environment variable
export GITHUB_TOKEN="ghp_your_token"

# Option 2: Command line
perl bin/quick-start.pl --token ghp_your_token

# Option 3: Save to config
echo "ghp_your_token" > /home/.config/github.token
chmod 600 /home/.config/github.token
```

### Cannot Clone Repositories

**Error:** "Failed to clone [repository]"

**Causes:**
1. GitHub token is invalid or has insufficient permissions
2. Network connectivity issue
3. GitHub API rate limit exceeded

**Solutions:**
1. Verify token has `repo` scope
2. Check network connectivity: `ping github.com`
3. Wait 1 hour for rate limit reset
4. Clone manually: `git clone https://[token]@github.com/nailara-technologies/[repo].git`

### Missing Perl Modules After Installation

**Error:** "Module not found" after bootstrap completes

**Solutions:**
```bash
# Manual installation
cpanm Crypt::Twofish_PP

# Or with cpan
cpan -i Crypt::Twofish_PP

# Check what was installed
perl -MModule::Name -e 'print "OK\n"'
```

### Environment Detection Failed

**Error:** System running but platform not detected correctly

**Solutions:**
1. Check hostname: `hostname`
2. Check for `/mnt/project`: `ls /mnt/project`
3. Verify paths exist: `ls /home/protocol-7` or `ls /home/user/protocol-7`
4. Manually set paths in script or use `ENV::get_paths()`

## Configuration Files

### bootstrap.json

Created after successful bootstrap. Example:

```json
{
  "environment": {
    "platform": "claude_projects",
    "hostname": "g-unique-id",
    "timestamp": "Mon Nov 28 14:30:45 2025",
    "bootstrap_version": "0.6-unified"
  },
  "paths": {
    "repo_base": "/home",
    "workspace_transfer": "/home/workspace-transfer",
    "protocol_7": "/home/protocol-7"
  },
  "setup_complete": true
}
```

### github.token

Stores authentication token with `0600` (read-only by owner) permissions.

**Security Note:** Token file is restricted to prevent accidental exposure.

## Integration with Existing Scripts

### Workspace-Transfer Integration

The bootstrap system complements existing workspace-transfer scripts:

```bash
# Bootstrap first
perl ENVIRONMENT-BOOTSTRAP.pl

# Then use workspace-transfer utilities
cd /home/workspace-transfer
perl bin/restore-checkpoint.pl
perl bin/export-context.pl
```

### Protocol-7 Integration

After bootstrap, Protocol-7 bin/ scripts work directly:

```bash
cd /home/protocol-7
perl bin/zenka-start.pl
perl bin/p7-init.pl
```

## Advanced Usage

### Custom Bootstrap Configuration

If you need to override detected paths:

```perl
use lib './lib';
use ENV;

# Override path detection
my $paths = ENV::get_paths();
$paths->{protocol_7} = '/custom/protocol-7';

# Save configuration
ENV::save_config($paths);
```

### Programmatic Bootstrap

Use in other scripts:

```perl
use lib './lib';
use ENV qw(:all);

my $platform = detect_platform();
if (is_projects()) {
    print "Running on Claude Projects\n";
}

my $paths = get_paths();
chdir($paths->{protocol_7}) or die "Cannot chdir: $!";
```

### Multi-Instance Deployment

Run multiple Protocol-7 instances on the same system:

```bash
# Instance 1
cd /home/protocol-7
perl bin/zenka-start.pl --port 8000

# Instance 2
cd /home/protocol-7-staging
perl bin/zenka-start.pl --port 8001
```

## Performance Notes

### Bootstrap Duration

- **First run (clone):** 30-60 seconds (network dependent)
- **Subsequent runs (update):** 5-10 seconds
- **Dependency installation:** 20-40 seconds (varies by modules)
- **Environment detection:** < 100ms

### Minimal Footprint

- Configuration files: ~5KB
- Dependencies: Perl modules only (no external services)
- Disk usage: Repositories (~50-100MB depending on content)

## Security Considerations

1. **Token Storage:** GitHub tokens stored with restricted file permissions (0600)
2. **Remote URLs:** Use authenticated HTTPS, not SSH (better for container environments)
3. **Token Rotation:** Can be updated by re-running with new token
4. **Config Directory:** Created with default permissions; consider restricting

## Support and Debugging

### Enable Verbose Output

Modify scripts to use more logging:

```perl
# Add to scripts
use constant DEBUG => 1;

sub log_debug {
    print "[DEBUG] @_\n" if DEBUG;
}
```

### Check Bootstrap Config

```bash
cat /home/.config/bootstrap.json        # Claude Projects
cat /home/user/.config/bootstrap.json   # Claude Code Web
```

### Verify Environment

```bash
perl -e 'use lib "./lib"; use ENV; print ENV::detect_platform(). "\n"'
```

## Related Documentation

- **workspace-transfer:** Context and checkpoint management
- **protocol-7:** Main project documentation
- **bin/zenka-start.pl:** v7 zenka agent startup script
- **README.md:** Project overview

---

**Last Updated:** 2025-11-28
**Version:** 0.6-unified
**Tested On:** Claude Projects, Claude Code Web (runsc)
