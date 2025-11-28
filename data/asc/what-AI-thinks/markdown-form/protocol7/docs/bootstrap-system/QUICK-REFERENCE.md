# Protocol-7 Quick Reference Card

## One-Command Deployment

### Claude Projects
```bash
GITHUB_TOKEN="ghp_your_token_here" perl /home/ENVIRONMENT-BOOTSTRAP.pl && \
cd /home/protocol-7 && perl bin/zenka-start.pl
```

### Claude Code Web (runsc)
```bash
GITHUB_TOKEN="ghp_your_token_here" perl /home/user/ENVIRONMENT-BOOTSTRAP.pl && \
cd /home/user/protocol-7 && perl bin/zenka-start.pl
```

---

## Common Tasks

### Get Your GitHub Token

```bash
# GitHub Settings → Developer settings → Personal access tokens
# Needs: repo, workflow scopes
# Example token: ghp_1234567890abcdefghijklmnop

# Store for this session:
export GITHUB_TOKEN="ghp_xxx"
```

### Bootstrap Only (No Zenka Start)

**Claude Projects:**
```bash
export GITHUB_TOKEN="ghp_xxx"
perl /home/ENVIRONMENT-BOOTSTRAP.pl
```

**Claude Code Web:**
```bash
export GITHUB_TOKEN="ghp_xxx"
perl /home/user/ENVIRONMENT-BOOTSTRAP.pl
```

### Start Zenka After Bootstrap

**Claude Projects:**
```bash
cd /home/protocol-7
perl bin/zenka-start.pl
```

**Claude Code Web:**
```bash
cd /home/user/protocol-7
perl bin/zenka-start.pl
```

### Check Setup Status

**Claude Projects:**
```bash
cat /home/.config/bootstrap.json
```

**Claude Code Web:**
```bash
cat /home/user/.config/bootstrap.json
```

### Verify Environment Detection

**Both:**
```bash
perl -I./lib -e 'use ENV; print "Platform: " . ENV::detect_platform() . "\n"'
```

### Update Repositories

**Claude Projects:**
```bash
cd /home/workspace-transfer && git pull origin base
cd /home/protocol-7 && git pull origin base
```

**Claude Code Web:**
```bash
cd /home/user/workspace-transfer && git pull origin base
cd /home/user/protocol-7 && git pull origin base
```

### Re-Run Bootstrap (Safe)

**Claude Projects:**
```bash
export GITHUB_TOKEN="ghp_xxx"
perl /home/ENVIRONMENT-BOOTSTRAP.pl
```

**Claude Code Web:**
```bash
export GITHUB_TOKEN="ghp_xxx"
perl /home/user/ENVIRONMENT-BOOTSTRAP.pl
```

---

## Key Paths

| What | Claude Projects | Claude Code Web |
|------|-----------------|-----------------|
| Repo Base | `/home/` | `/home/user/` |
| Bootstrap Script | `/home/ENVIRONMENT-BOOTSTRAP.pl` | `/home/user/ENVIRONMENT-BOOTSTRAP.pl` |
| Config Dir | `/home/.config/` | `/home/user/.config/` |
| Token File | `/home/.config/github.token` | `/home/user/.config/github.token` |
| workspace-transfer | `/home/workspace-transfer` | `/home/user/workspace-transfer` |
| protocol-7 | `/home/protocol-7` | `/home/user/protocol-7` |
| lib | `/home/lib/` | `/home/user/lib/` |

---

## Troubleshooting Quick Fixes

### "GitHub token not found"
```bash
export GITHUB_TOKEN="ghp_your_token"
perl /home/ENVIRONMENT-BOOTSTRAP.pl  # Try again
```

### "Cannot find protocol-7"
```bash
# Verify path exists
ls /home/protocol-7          # Claude Projects
ls /home/user/protocol-7     # Claude Code Web

# If not, check config
cat /home/.config/bootstrap.json  # What platform detected?
```

### "Module not found"
```bash
# Install manually
cpanm Crypt::Twofish_PP
cpanm CryptX

# Or let bootstrap install
perl /home/ENVIRONMENT-BOOTSTRAP.pl
```

### "Zenka won't start"
```bash
# Check it exists
ls /home/protocol-7/bin/zenka-start.pl

# Run with error output
perl /home/protocol-7/bin/zenka-start.pl 2>&1

# Check dependencies
perl -MCryptX -e 'print "CryptX OK\n"'
```

---

## Bootstrap Sequence

```
1. ENVIRONMENT-BOOTSTRAP.pl runs
   ├─ Detect Platform (Claude Projects vs Code Web)
   ├─ Check System Tools (git, perl, openssl)
   ├─ Install Dependencies (Perl modules)
   ├─ Clone Repositories (workspace-transfer, protocol-7)
   ├─ Configure Git Remotes (with auth token)
   └─ Create Configuration (bootstrap.json)

2. Repositories Now Ready
   ├─ /home/workspace-transfer available
   └─ /home/protocol-7 available

3. Start v7 Zenka (Optional)
   └─ perl /home/protocol-7/bin/zenka-start.pl
```

---

## Environment Variables

| Variable | Purpose | Example |
|----------|---------|---------|
| `GITHUB_TOKEN` | GitHub authentication | `ghp_1234567890abcdef...` |
| `PERL5LIB` | Perl module path | `/home/lib` |
| `PATH` | Command search | Include `/home/bin` |

---

## What Gets Installed

### Perl Modules (via cpanm/cpan)
- Crypt::Twofish_PP
- CryptX
- Digest::SHA
- MIME::Base32
- JSON::PP
- File::Temp
- Sys::Hostname
- (and dependencies)

### System Tools Verified
- git (version control)
- perl (execution)
- openssl (cryptography)
- curl (HTTP requests)

### Repositories Cloned
- workspace-transfer (checkpoint management)
- protocol-7 (main system)

---

## Important Notes

⚠️ **GitHub Token Scope**
- Token must have `repo` scope
- Must have `workflow` scope (for GitHub Actions)
- Create at: https://github.com/settings/tokens

⚠️ **Token Security**
- Never commit token to git
- Config files stored in `.config/` with restricted permissions
- Consider rotating token periodically

⚠️ **First Run Timing**
- Clone operations slower on first run (~45 seconds)
- Subsequent runs much faster (~5 seconds)
- Dependency install slower first time (~40 seconds)

⚠️ **Idempotent**
- Safe to run bootstrap multiple times
- Won't re-clone if repositories exist
- Will update existing repositories

---

## One-Liner Commands

### Full Setup to Zenka Running (Claude Projects)
```bash
GITHUB_TOKEN="ghp_xxx" perl /home/ENVIRONMENT-BOOTSTRAP.pl && cd /home/protocol-7 && perl bin/zenka-start.pl
```

### Full Setup to Zenka Running (Claude Code Web)
```bash
GITHUB_TOKEN="ghp_xxx" perl /home/user/ENVIRONMENT-BOOTSTRAP.pl && cd /home/user/protocol-7 && perl bin/zenka-start.pl
```

### Check Everything is Installed
```bash
perl -I./lib -e 'use ENV; use CryptX; use JSON::PP; print "All OK\n"'
```

### See Current Platform
```bash
perl -I./lib -e 'use ENV; print ENV::detect_platform() . "\n"'
```

### See All Paths
```bash
perl -I./lib -e 'use ENV; use Data::Dumper; print Dumper(ENV::get_paths())'
```

---

## Files Created by Bootstrap

```
/home/.config/                          # (or /home/user/.config/ on Code Web)
├── bootstrap.json                      # Configuration + setup verification
├── github.token                        # GitHub authentication (600 perms)
└── ...

/home/workspace-transfer/               # Cloned from GitHub
├── bin/
│   ├── configure-remote
│   ├── deps
│   └── ...
└── ...

/home/protocol-7/                       # Cloned from GitHub
├── bin/
│   ├── zenka-start.pl                 # v7 zenka agent startup
│   ├── p7-deps
│   └── ...
└── ...
```

---

## Getting Help

### Check Configuration
```bash
cat /home/.config/bootstrap.json  # What platform detected?
```

### Check Paths
```bash
perl -I./lib -e 'use ENV; my $p = ENV::get_paths(); print "$_: $p->{$_}\n" for keys %$p'
```

### Check Token
```bash
test -f /home/.config/github.token && echo "Token found" || echo "Token not found"
```

### Run Bootstrap in Verbose Mode
```bash
# Add DEBUG lines to ENVIRONMENT-BOOTSTRAP.pl
perl ENVIRONMENT-BOOTSTRAP.pl 2>&1 | tee bootstrap.log
```

### Manual Dependency Check
```bash
perl -MCryptX -e 'print "CryptX: OK\n"'
perl -MJSON::PP -e 'print "JSON::PP: OK\n"'
perl -MMIME::Base32 -e 'print "MIME::Base32: OK\n"'
```

---

## Performance Expectations

| Task | Time | Notes |
|------|------|-------|
| Environment Detection | <100ms | Instant |
| Dependency Check | 10-15s | First time only |
| Clone Repositories | 30-60s | First time, network dependent |
| Update Repositories | 5-10s | Subsequent runs |
| Total Bootstrap | 1-2 min | First time; 10-20s after |
| Start Zenka | <5s | Agent initialization |

---

**Quick Reference Card v0.6-unified**
Last Updated: 2025-11-28
Tested: Claude Projects, Claude Code Web (runsc)
