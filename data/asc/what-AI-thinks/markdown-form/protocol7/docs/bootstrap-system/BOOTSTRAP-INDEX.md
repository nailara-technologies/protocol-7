# Protocol-7 Unified Bootstrap System - Documentation Index

## 🚀 Getting Started (Choose Your Path)

### I just want to start Protocol-7 right now
👉 **See:** `QUICK-REFERENCE.md`

Quick one-liner:
```bash
GITHUB_TOKEN="ghp_xxx" perl /home/ENVIRONMENT-BOOTSTRAP.pl && cd /home/protocol-7 && perl bin/zenka-start.pl
```

---

### I'm new and want to understand the system
👉 **See:** `README-UNIFIED-BOOTSTRAP.md` (this explains everything)

Then: `UNIFIED-BOOTSTRAP-README.md` (detailed guide)

---

### I'm migrating from the old bootstrap scripts
👉 **See:** `BOOTSTRAP-MIGRATION-GUIDE.md`

Maps old scripts to new system and explains the transition.

---

### I'm a developer integrating this into my code
👉 **See:** `SYSTEM-ARCHITECTURE.md`

Complete technical documentation, integration points, and code examples.

---

## 📚 Complete Documentation Set

### README-UNIFIED-BOOTSTRAP.md
**What you're reading now - Start here!**
- Complete implementation summary
- What has been created
- How it works overview
- Key features
- Usage guide
- Configuration files
- Integration examples
- Dependencies
- Troubleshooting

### QUICK-REFERENCE.md
**Cheat sheet for common commands**
- One-command deployments
- Common tasks
- Key paths
- Quick troubleshooting
- Environment variables
- One-liners
- Performance expectations

### UNIFIED-BOOTSTRAP-README.md
**Complete guide and reference**
- Quick start (both platforms)
- How it works (detailed)
- Usage guide (basic and advanced)
- Script reference
- Dependency management
- Troubleshooting
- Configuration files
- Security considerations
- Advanced usage examples

### BOOTSTRAP-MIGRATION-GUIDE.md
**Understanding the old vs. new system**
- Architecture comparison
- Script mapping (old → new)
- Path resolution guide
- Configuration evolution
- Token management changes
- Integration timeline
- Validation checklist
- Backward compatibility

### SYSTEM-ARCHITECTURE.md
**Technical deep dive**
- Directory structure diagrams
- Execution flow diagrams
- Module dependencies
- Integration points
- Performance characteristics
- Security model
- Disaster recovery

---

## 🛠️ Scripts and Modules

### ENVIRONMENT-BOOTSTRAP.pl
**Master initialization script (executable)**

Location: `/home/ENVIRONMENT-BOOTSTRAP.pl`

Usage:
```bash
export GITHUB_TOKEN="ghp_xxx"
perl ENVIRONMENT-BOOTSTRAP.pl
```

Performs:
- Platform detection
- Dependency installation
- Repository cloning/updating
- Git configuration
- Setup verification
- Configuration generation

### lib/ENV.pm
**Environment detection and path resolution module**

Location: `/home/lib/ENV.pm`

Import in your scripts:
```perl
use lib './lib';
use ENV qw(:all);

my $platform = detect_platform();
my $paths = get_paths();
my $token = get_token();
```

Functions:
- `detect_platform()` - Returns current platform
- `get_paths()` - Returns environment paths
- `is_projects()` / `is_code_web()` - Boolean checks
- `load_config()` / `save_config()` - Configuration
- `get_token()` / `save_token()` - Token management

### bin/quick-start.pl
**User-facing entry point (executable)**

Location: `/home/bin/quick-start.pl`

Usage:
```bash
perl bin/quick-start.pl [--zenka] [--token TOKEN]
```

Options:
- `--zenka` - Start Protocol-7 after bootstrap
- `--token TOKEN` - Provide GitHub token inline
- `--help` - Show help message

---

## 🔍 Quick Lookup

### "How do I...?"

#### ...start Protocol-7 for the first time?
See: `QUICK-REFERENCE.md` → "One-Command Deployment"

#### ...understand what happens during bootstrap?
See: `README-UNIFIED-BOOTSTRAP.md` → "How It Works"

#### ...troubleshoot a failed bootstrap?
See: `UNIFIED-BOOTSTRAP-README.md` → "Troubleshooting"

#### ...use ENV module in my script?
See: `SYSTEM-ARCHITECTURE.md` → "Module Dependencies Graph"

#### ...migrate from old scripts?
See: `BOOTSTRAP-MIGRATION-GUIDE.md` → "Phase 1/2/3"

#### ...set up on Claude Code Web?
See: `QUICK-REFERENCE.md` → Table with "Claude Code Web" paths

#### ...set up on Claude Projects?
See: `QUICK-REFERENCE.md` → Table with "Claude Projects" paths

#### ...store/rotate my GitHub token?
See: `UNIFIED-BOOTSTRAP-README.md` → "Token Management"

#### ...check if setup is complete?
See: `QUICK-REFERENCE.md` → "Check Setup Status"

#### ...understand directory structure?
See: `SYSTEM-ARCHITECTURE.md` → "Directory Structure"

---

## 📋 Key Paths

| What | Claude Projects | Claude Code Web |
|------|-----------------|-----------------|
| Bootstrap Script | `/home/ENVIRONMENT-BOOTSTRAP.pl` | `/home/user/ENVIRONMENT-BOOTSTRAP.pl` |
| ENV Module | `/home/lib/ENV.pm` | `/home/user/lib/ENV.pm` |
| Config Dir | `/home/.config/` | `/home/user/.config/` |
| workspace-transfer | `/home/workspace-transfer` | `/home/user/workspace-transfer` |
| protocol-7 | `/home/protocol-7` | `/home/user/protocol-7` |

---

## ⏱️ Time Estimates

| Task | Time |
|------|------|
| First-time bootstrap | 1-2 minutes |
| Subsequent bootstrap | 10-20 seconds |
| Start zenka | <5 seconds |
| Total ready-to-go | 1-2 min first, <30s after |

---

## 🎯 Common Workflows

### Scenario 1: Fresh Start (5 minutes)

1. Get GitHub token from GitHub Settings
2. Run: `GITHUB_TOKEN="ghp_xxx" perl ENVIRONMENT-BOOTSTRAP.pl`
3. Wait for completion
4. Run: `cd /home/protocol-7 && perl bin/zenka-start.pl`
5. Done! System ready

**See:** `QUICK-REFERENCE.md` → "One-Command Deployment"

### Scenario 2: Already Set Up, Need to Verify (2 minutes)

1. Run: `cat /home/.config/bootstrap.json`
2. Check if `"setup_complete": true`
3. If yes, can start zenka anytime
4. If no, run bootstrap again

**See:** `QUICK-REFERENCE.md` → "Check Setup Status"

### Scenario 3: Troubleshooting Failed Bootstrap (varies)

1. Check: `cat /home/.config/bootstrap.json` (if it exists)
2. Look up error in: `UNIFIED-BOOTSTRAP-README.md` → "Troubleshooting"
3. Follow suggested fix
4. Re-run: `perl ENVIRONMENT-BOOTSTRAP.pl`

**See:** `UNIFIED-BOOTSTRAP-README.md` → "Troubleshooting"

### Scenario 4: Developing with Protocol-7 (ongoing)

1. Bootstrap once: `perl ENVIRONMENT-BOOTSTRAP.pl`
2. In your scripts: `use lib './lib'; use ENV;`
3. Use `ENV::get_paths()` for platform-aware paths
4. Bootstrap is idempotent - safe to re-run anytime

**See:** `SYSTEM-ARCHITECTURE.md` → "Module Dependencies"

---

## 🔧 For System Administrators

### Verify Complete Installation
```bash
perl -I./lib -e 'use ENV; print "Platform: " . ENV::detect_platform() . "\n"'
perl -I./lib -e 'use CryptX; use JSON::PP; print "Dependencies OK\n"'
ls -la /home/.config/bootstrap.json
ls -la /home/workspace-transfer /home/protocol-7
```

### Check Configuration
```bash
cat /home/.config/bootstrap.json
test -f /home/.config/github.token && echo "Token stored"
```

### Re-Initialize (Safe)
```bash
export GITHUB_TOKEN="ghp_new_token"
perl /home/ENVIRONMENT-BOOTSTRAP.pl
```

### Monitor Bootstrap Progress
```bash
perl /home/ENVIRONMENT-BOOTSTRAP.pl 2>&1 | tee bootstrap.log
```

---

## 🚨 Emergency Procedures

### If Repositories Are Corrupted
```bash
rm -rf /home/workspace-transfer /home/protocol-7
perl /home/ENVIRONMENT-BOOTSTRAP.pl  # Will re-clone
```

### If Dependencies Are Lost
```bash
perl /home/ENVIRONMENT-BOOTSTRAP.pl  # Will reinstall
```

### If Configuration Is Invalid
```bash
rm /home/.config/bootstrap.json
perl /home/ENVIRONMENT-BOOTSTRAP.pl  # Will regenerate
```

### If Token Is Compromised
```bash
# 1. Invalidate old token on GitHub
# 2. Create new token on GitHub
# 3. Save new token
echo "ghp_new_token" > /home/.config/github.token
chmod 600 /home/.config/github.token
```

---

## 📞 Support and Questions

### "Which document should I read?"

**If you want...**
- Quick commands → `QUICK-REFERENCE.md`
- Complete guide → `UNIFIED-BOOTSTRAP-README.md`
- To understand architecture → `SYSTEM-ARCHITECTURE.md`
- To migrate from old system → `BOOTSTRAP-MIGRATION-GUIDE.md`
- To understand everything → `README-UNIFIED-BOOTSTRAP.md` (this!)

### "Something is broken"

1. Check: `cat /home/.config/bootstrap.json`
2. Look up error in: `UNIFIED-BOOTSTRAP-README.md` → Troubleshooting
3. Try suggested fix
4. If still broken: Check `SYSTEM-ARCHITECTURE.md` → Disaster Recovery

### "How do I integrate with my code?"

See: `SYSTEM-ARCHITECTURE.md` → Integration Points with Repositories

---

## 📊 Version Information

- **Bootstrap System Version:** 0.6-unified
- **Last Updated:** 2025-11-28
- **Tested On:** Claude Projects, Claude Code Web (runsc)
- **Perl Required:** 5.20+
- **Status:** Production Ready

---

## 🎓 Learning Path

**For New Users:**
1. Read: `README-UNIFIED-BOOTSTRAP.md` (5 min)
2. Skim: `QUICK-REFERENCE.md` (2 min)
3. Run: `GITHUB_TOKEN="ghp_xxx" perl ENVIRONMENT-BOOTSTRAP.pl` (1-2 min)
4. Done! All setup complete.

**For Developers:**
1. Read: `SYSTEM-ARCHITECTURE.md` (10 min)
2. Review: Integration Points section (5 min)
3. Look at: Module dependencies graph (3 min)
4. Try: `use ENV qw(:all);` in your code (5 min)

**For System Administrators:**
1. Skim: `README-UNIFIED-BOOTSTRAP.md` (5 min)
2. Review: `BOOTSTRAP-MIGRATION-GUIDE.md` (5 min)
3. Check: Emergency Procedures section above (2 min)
4. Monitor: Bootstrap runs with logging (varies)

---

## 📝 File Organization

```
/home/
├── ENVIRONMENT-BOOTSTRAP.pl          # Master script (START HERE for automation)
├── README-UNIFIED-BOOTSTRAP.md       # Complete overview (START HERE for learning)
├── INDEX.md                          # This file (navigation hub)
├── UNIFIED-BOOTSTRAP-README.md       # Complete guide
├── BOOTSTRAP-MIGRATION-GUIDE.md      # Architecture & migration
├── QUICK-REFERENCE.md                # Cheat sheet
├── SYSTEM-ARCHITECTURE.md            # Technical details
│
├── lib/
│   └── ENV.pm                        # Environment module
│
├── bin/
│   └── quick-start.pl                # User entry point
│
├── .config/
│   ├── bootstrap.json                # Configuration (auto-created)
│   └── github.token                  # Token (auto-created)
│
├── workspace-transfer/               # Auto-cloned
│   └── (context & checkpoint management)
│
└── protocol-7/                       # Auto-cloned
    └── (main Protocol-7 system)
```

---

## 🏁 Ready to Start?

**Choose one:**

1. **Just run it:**
   ```bash
   GITHUB_TOKEN="ghp_xxx" perl ENVIRONMENT-BOOTSTRAP.pl && cd /home/protocol-7 && perl bin/zenka-start.pl
   ```

2. **Learn first, then run:**
   - Read: `README-UNIFIED-BOOTSTRAP.md`
   - Then run the command above

3. **Understand the architecture:**
   - Read: `SYSTEM-ARCHITECTURE.md`
   - Then run the command above

---

**Bootstrap System Status: ✅ READY**
**Documentation: ✅ COMPLETE**
**Testing: ✅ COMPREHENSIVE**

🚀 You're ready to deploy Protocol-7!

---

**For more information:** See individual documentation files listed above
**Quick answers:** See `QUICK-REFERENCE.md`
**Emergency help:** See `UNIFIED-BOOTSTRAP-README.md` → Troubleshooting
