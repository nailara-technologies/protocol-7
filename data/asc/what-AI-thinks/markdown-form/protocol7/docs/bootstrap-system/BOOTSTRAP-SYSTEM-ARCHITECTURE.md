# Complete System Architecture

## Directory Structure

### Claude Projects Environment

```
/home/
├── ENVIRONMENT-BOOTSTRAP.pl          # Master initialization script
├── UNIFIED-BOOTSTRAP-README.md       # Full documentation
├── BOOTSTRAP-MIGRATION-GUIDE.md      # Migration from old system
├── QUICK-REFERENCE.md                # Quick command reference
│
├── lib/
│   └── ENV.pm                        # Environment detection module
│
├── bin/
│   └── quick-start.pl                # User-facing entry point
│
├── .config/
│   ├── bootstrap.json                # Configuration (auto-created)
│   └── github.token                  # Token storage (auto-created)
│
├── workspace-transfer/               # Cloned from GitHub
│   ├── ENVIRONMENT-BOOTSTRAP.pl      # (Symlink or copy for convenience)
│   ├── lib/
│   │   ├── ENV.pm                    # (Symlink for convenience)
│   │   └── ... (ws-transfer libs)
│   ├── bin/
│   │   ├── configure-remote          # (Now uses ENV module)
│   │   ├── deps                      # (Delegates to bootstrap)
│   │   ├── restore-checkpoint.pl
│   │   └── ... (other utilities)
│   └── ... (other files)
│
└── protocol-7/                       # Cloned from GitHub
    ├── ENVIRONMENT-BOOTSTRAP.pl      # (Symlink or copy for convenience)
    ├── lib/
    │   ├── ENV.pm                    # (Symlink for convenience)
    │   ├── AMOS7/
    │   │   ├── Twofish.pm            # (Will use CryptX)
    │   │   └── ...
    │   └── ... (other libs)
    ├── bin/
    │   ├── zenka-start.pl            # v7 zenka agent (main startup)
    │   ├── p7-init.pl
    │   ├── p7-deps                   # (Now uses bootstrap)
    │   └── ... (other scripts)
    └── ... (other files)
```

### Claude Code Web Environment

```
/home/user/
├── ENVIRONMENT-BOOTSTRAP.pl          # Master initialization script
├── UNIFIED-BOOTSTRAP-README.md       # Full documentation
├── BOOTSTRAP-MIGRATION-GUIDE.md      # Migration guide
├── QUICK-REFERENCE.md                # Quick reference
│
├── lib/
│   └── ENV.pm                        # Environment detection module
│
├── bin/
│   └── quick-start.pl                # User-facing entry point
│
├── .config/
│   ├── bootstrap.json                # Configuration (auto-created)
│   └── github.token                  # Token storage (auto-created)
│
├── workspace-transfer/               # Cloned from GitHub
│   ├── (same structure as Projects)
│
└── protocol-7/                       # Cloned from GitHub
    ├── (same structure as Projects)
```

---

## Execution Flow Diagrams

### Complete Bootstrap and Startup

```
User Command (any platform)
│
├─ ENVIRONMENT-BOOTSTRAP.pl (or quick-start.pl)
│  │
│  ├─ detect_platform()
│  │  └─ Checks: hostname, paths, mounts
│  │     Returns: 'claude_projects' or 'claude_code_web'
│  │
│  ├─ get_required_modules()
│  │  └─ Returns environment-specific Perl modules
│  │
│  ├─ check_system_tools()
│  │  └─ Verifies: git, perl, openssl, curl
│  │
│  ├─ install_cpan_modules()
│  │  └─ Uses cpanm/cpan to install missing modules
│  │
│  ├─ get_token()
│  │  └─ Retrieves from: ENV variable or config file
│  │
│  ├─ clone_or_update_repo() [workspace-transfer]
│  │  ├─ git clone (first time)
│  │  └─ git pull (subsequent runs)
│  │
│  ├─ clone_or_update_repo() [protocol-7]
│  │  ├─ git clone (first time)
│  │  └─ git pull (subsequent runs)
│  │
│  ├─ configure_git_remote()
│  │  └─ Sets authenticated HTTPS remotes
│  │
│  ├─ verify_setup()
│  │  └─ Confirms repositories, tools, dependencies
│  │
│  └─ generate_config()
│     └─ Writes bootstrap.json
│
└─ Optional: quick-start.pl --zenka
   │
   └─ bin/zenka-start.pl
      └─ Starts Protocol-7 v7 zenka agent
         └─ Ready for webhook processing
```

### Platform Detection

```
┌─────────────────────────────┐
│ detect_environment()        │
└──────────────┬──────────────┘
               │
        ┌──────┴──────────┐
        │                 │
     ┌──▼──┐          ┌──▼──────────┐
     │Check│          │Check /mnt/  │
     │host=│          │ project &&  │
     │runsc│          │/home/proto-7│
     └──┬──┘          └──┬──────────┘
        │                │
        │ YES            │ YES
        │                │
     ┌──▼────────┐    ┌──▼──────────────┐
     │Claude Code│    │Claude Projects   │
     │Web        │    │                  │
     │/home/user/│    │/home/            │
     └───────────┘    └──────────────────┘
```

### Dependency Resolution

```
get_required_modules()
│
├─ Core Modules (all platforms)
│  ├─ Crypt::Twofish_PP
│  ├─ CryptX
│  ├─ Digest::SHA
│  ├─ Encode
│  ├─ MIME::Base32
│  ├─ JSON::PP
│  ├─ File::Temp
│  └─ Sys::Hostname
│
├─ Claude Projects Specific
│  ├─ Readonly
│  └─ autodie
│
└─ Claude Code Web Specific
   └─ parent
```

---

## Module Dependencies Graph

```
Application Scripts
│
├─ ENVIRONMENT-BOOTSTRAP.pl
│  ├─ uses: Sys::Hostname, Cwd, File::Spec, JSON::PP
│  └─ calls: detect_environment(), install_cpan_modules(), etc.
│
├─ quick-start.pl
│  ├─ uses: Getopt::Long, lib::ENV
│  └─ calls: ENV::get_paths(), run_environment_bootstrap()
│
└─ Protocol-7 Scripts
   ├─ bin/zenka-start.pl
   │  ├─ uses: lib::ENV, CryptX, JSON::PP
   │  └─ implements: v7 zenka agent
   │
   └─ workspace-transfer Scripts
      ├─ bin/restore-checkpoint.pl
      │  ├─ uses: lib::ENV, CryptX::Cipher, MIME::Base32
      │  └─ restores encrypted checkpoints
      │
      └─ bin/export-context.pl
         ├─ uses: lib::ENV, JSON::PP, Digest::SHA
         └─ exports session context
```

---

## Configuration Data Flow

```
Environment Detection
│
└─ Detected Platform
   ├─ hostname
   ├─ mounted paths
   └─ file structure

Result: .config/bootstrap.json
│
├─ environment.platform
├─ environment.hostname
├─ environment.timestamp
├─ environment.bootstrap_version
├─ paths.repo_base
├─ paths.workspace_transfer
└─ paths.protocol_7

Usage by:
├─ lib/ENV.pm (load_config)
├─ Protocol-7 scripts (path resolution)
└─ workspace-transfer scripts (context)
```

---

## Bootstrap State Machine

```
┌──────────────────┐
│  START: No Setup │
└────────┬─────────┘
         │
         ▼
┌──────────────────────┐
│ Detect Environment   │
│ (0-1 second)         │
└────────┬─────────────┘
         │
         ▼
┌──────────────────────┐
│ Check/Install Deps   │
│ (10-40 seconds)      │
└────────┬─────────────┘
         │
         ▼
┌──────────────────────┐
│ Clone Repositories   │
│ (30-60 seconds)      │
└────────┬─────────────┘
         │
         ▼
┌──────────────────────┐
│ Configure Remotes    │
│ (1-2 seconds)        │
└────────┬─────────────┘
         │
         ▼
┌──────────────────────┐
│ Verify Setup         │
│ (2-3 seconds)        │
└────────┬─────────────┘
         │
         ▼
┌──────────────────────┐
│ Save Configuration   │
│ (instant)            │
└────────┬─────────────┘
         │
         ▼
┌──────────────────────┐
│ READY: Zenka Start   │
│ Available            │
└──────────────────────┘
```

---

## Integration Points with Repositories

### workspace-transfer Integration

**Files that can use unified bootstrap:**

```
workspace-transfer/
├── bin/
│   ├── configure-remote
│   │   └─ Changed: Now uses ENV::get_token() and ENV::resolve_path()
│   │
│   ├── deps
│   │   └─ Changed: Delegates to ENVIRONMENT-BOOTSTRAP.pl
│   │
│   ├── restore-checkpoint.pl
│   │   └─ Uses: lib/ENV.pm for path resolution
│   │
│   └── export-context.pl
│       └─ Uses: lib/ENV.pm for config directory
│
└── lib/
    ├── ENV.pm                        # Symlink to /home/lib/ENV.pm
    │  └─ Provides: Environment-aware path resolution
    │
    └── ... (other modules)
```

**Recommended Changes:**

1. Add symlink or copy of `lib/ENV.pm` to workspace-transfer
2. Update `bin/configure-remote` to use ENV module
3. Update `bin/deps` to call ENVIRONMENT-BOOTSTRAP.pl
4. Update `bin/restore-checkpoint.pl` to use ENV paths

### protocol-7 Integration

**Files that can use unified bootstrap:**

```
protocol-7/
├── bin/
│   ├── zenka-start.pl               # Main entry point
│   │   ├─ Uses: lib/ENV for path resolution
│   │   ├─ Uses: CryptX (installed by bootstrap)
│   │   └─ Starts: v7 zenka agent
│   │
│   ├── p7-init.pl
│   │   ├─ Uses: lib/ENV for configuration
│   │   └─ Initializes: Protocol-7 environment
│   │
│   └── p7-deps
│       └─ Changed: Delegates to ENVIRONMENT-BOOTSTRAP.pl
│
└── lib/
    ├── ENV.pm                        # Symlink to /home/lib/ENV.pm
    │  └─ Provides: Platform-aware paths
    │
    ├── AMOS7/
    │   ├── Twofish.pm               # Uses: CryptX (installed by bootstrap)
    │   └── ... (other modules)
    │
    └── ... (other modules)
```

**Recommended Changes:**

1. Add symlink or copy of `lib/ENV.pm` to protocol-7
2. Update `lib/AMOS7/Twofish.pm` to use CryptX (from bootstrap)
3. Update `bin/p7-init.pl` to use ENV paths
4. Update `bin/zenka-start.pl` to validate bootstrap completion

---

## Symlink Strategy (Recommended)

For unified bootstrap availability in both repositories:

```bash
# In workspace-transfer
ln -s /home/lib/ENV.pm lib/ENV.pm
ln -s /home/ENVIRONMENT-BOOTSTRAP.pl ENVIRONMENT-BOOTSTRAP.pl

# In protocol-7
ln -s /home/lib/ENV.pm lib/ENV.pm
ln -s /home/ENVIRONMENT-BOOTSTRAP.pl ENVIRONMENT-BOOTSTRAP.pl
```

**Benefits:**
- Single source of truth (changes propagate)
- Minimal duplication
- Works in both repositories
- Can be added to .gitignore

---

## File Locations Reference

| File | Purpose | Location |
|------|---------|----------|
| ENVIRONMENT-BOOTSTRAP.pl | Master bootstrap | `/home/` + `/home/user/` |
| lib/ENV.pm | Environment module | `/home/lib/` + `/home/user/lib/` |
| bin/quick-start.pl | Entry point | `/home/bin/` + `/home/user/bin/` |
| .config/bootstrap.json | Configuration | `/home/.config/` + `/home/user/.config/` |
| .config/github.token | Authentication | `/home/.config/` + `/home/user/.config/` |
| workspace-transfer/ | Cloned repo | `/home/` + `/home/user/` |
| protocol-7/ | Cloned repo | `/home/` + `/home/user/` |

---

## Initialization Sequence Reference

### First-Time User (Fresh Start)

```
1. User runs: GITHUB_TOKEN="ghp_xxx" perl ENVIRONMENT-BOOTSTRAP.pl
2. System detects platform automatically
3. Installs all dependencies
4. Clones both repositories
5. Configures git authentication
6. User optionally runs: cd protocol-7 && perl bin/zenka-start.pl
7. System ready for Protocol-7 operations
```

### Returning User (Workspace Exists)

```
1. User runs: GITHUB_TOKEN="ghp_xxx" perl ENVIRONMENT-BOOTSTRAP.pl
2. System detects platform automatically
3. Checks dependencies (skips if all present)
4. Updates repositories (git pull)
5. Refreshes configuration
6. User runs: cd protocol-7 && perl bin/zenka-start.pl
7. System ready
```

### Developer (Continuous Development)

```
1. Bootstrap runs once: ENVIRONMENT-BOOTSTRAP.pl
2. Load ENV module: use lib './lib'; use ENV;
3. Resolve paths: my $paths = ENV::get_paths();
4. Write code: Scripts use ENV for platform-aware paths
5. Run tests: Tests inherit environment configuration
6. Commit: Changes to ENV.pm propagate via symlinks
```

---

## Technology Stack Summary

| Component | Technology | Version | Purpose |
|-----------|-----------|---------|---------|
| Language | Perl | 5.20+ | Primary scripting |
| Encryption | CryptX | Latest | Cryptographic operations |
| Hashing | Digest::SHA | Built-in | Checksums and hashing |
| Encoding | MIME::Base32 | Latest | Data serialization |
| Config | JSON::PP | Built-in | Configuration storage |
| VCS | Git | 2.0+ | Repository management |
| Auth | Personal Access Token | GitHub | Remote repository access |

---

## Performance Characteristics

| Operation | Time | Bottleneck | Optimization |
|-----------|------|-----------|--------------|
| detect_platform() | <100ms | None | Cached if called multiple times |
| get_required_modules() | <10ms | Module list size | Pre-computed list |
| install_cpan_modules() | 10-40s | Network/disk I/O | Parallel install (cpanm -j4) |
| clone_or_update_repo() | 30-60s first, 5-10s updates | Network I/O | Clone in background |
| configure_git_remote() | 1-2s | Git subprocess | Batch with clone |
| verify_setup() | 2-3s | File I/O | Parallel verification |

---

## Scalability Considerations

### Single Environment
- Current design handles 1-2 running Protocol-7 instances
- Can be extended to support multiple instances with port variation

### Multiple Repositories
- Architecture supports adding more repositories
- Extend `clone_or_update_repo()` call per repository

### Large Dependency Lists
- Current ~12 modules
- Scales to 50+ modules with parallel installation
- cpanm -j4 flag enables parallel installation

---

## Security Model

```
Token Management
├─ Storage
│  ├─ Priority 1: $ENV{GITHUB_TOKEN}
│  ├─ Priority 2: /home/.config/github.token (0600 perms)
│  └─ Priority 3: Prompt user
│
├─ Usage
│  ├─ Only passed to git via HTTPS URL
│  ├─ Never logged or printed
│  └─ Stored with restricted file permissions
│
└─ Rotation
   ├─ Can save new token with ENV::save_token()
   └─ Old token can be invalidated on GitHub
```

---

## Disaster Recovery

```
If Bootstrap Fails
├─ Check bootstrap.json exists and is valid
├─ Verify git remotes are configured
├─ Ensure all dependencies are installed
├─ Check GitHub token validity
└─ Try re-running: GITHUB_TOKEN="ghp_xxx" perl ENVIRONMENT-BOOTSTRAP.pl

If Repositories Corrupted
├─ Remove repository directory
├─ Re-run bootstrap (will re-clone)
└─ Configuration preserved in .config/

If Dependencies Lost
├─ Re-run: ENVIRONMENT-BOOTSTRAP.pl
├─ All dependencies will be reinstalled
└─ No configuration loss
```

---

**Architecture Document v0.6-unified**
Last Updated: 2025-11-28
Maintainers: Protocol-7 Development Team
