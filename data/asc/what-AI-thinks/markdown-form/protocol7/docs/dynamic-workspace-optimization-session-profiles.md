# Dynamic Workspace Optimization: Session-Driven Profile Creation

*Concept emerging from dependency introspection recovery (2025-11-27)*

---

## The Idea

Add a new command to drive workspace-transfer dependency evolution based on actual usage patterns:

```bash
bin/p7-deps optimize-workspace-deps
```

This command would:
1. Analyze recent session work (from git history and task documentation)
2. Group modules by topic/workflow used in recent sessions
3. Create session-specific dependency profiles in workspace-transfer
4. Gradually identify which profiles become universally useful
5. Update the default installation profile to something sane (covers interfaces + network)

---

## Why This Matters

### Current State Problem

workspace-transfer has a monolithic dependency structure. Every developer gets the same minimal
base dependencies, but their actual workflow needs vary wildly:

- **Security researcher** needs crypto, penetration testing tools, network analysis
- **Web developer** needs HTTP tools, template engines, asset processing
- **Systems engineer** needs container tools, deployment utilities, monitoring
- **AI developer** needs LLM inference, tokenization, vector operations

All get the same profile. All optimize for the "generic case" that doesn't exist.

### The Solution: Emergent Profiles

Instead of guessing, let the system's actual usage pattern drive profiles:

**Wave 1: Session Topics**
- Create profiles from what people actually needed last week
- Name them by what they do: `web-dev`, `crypto-research`, `ml-playground`, etc.
- Let people choose based on their current work

**Wave 2: Convergence Analysis**
- Track which modules appear in multiple session-profiles
- Identify modules used across 3+ different workflows
- These become candidates for "long-term generic" layer

**Wave 3: Optimization**
- Move high-convergence modules to base profiles
- Keep session-specific profiles lightweight
- Default profile includes convergence layer + interfaces

---

## Implementation Strategy

### Phase 0: Semantic Intent Parsing

```bash
bin/p7-deps parse-intent [--since 1w] [--verbose]
```

Scan task descriptions and commit messages for dependency mentions using pattern matching:

**Additive Patterns** (things we need/added):
- "add.*module X" / "install X" / "need X" / "import X"
- "require.*X" / "use.*X module" / "X dependency"
- Mentions in task descriptions: "implement X using Y module"

**Removal Patterns** (things we removed/don't need):
- "remove.*X" / "delete.*X" / "uninstall X"
- "no longer need X" / "X is obsolete"
- Task closure: "X work complete, can remove Z"

**Result**: Intent markers that trigger detailed scans

### Phase 1: Validation Scans (Intent-Driven)

When dependencies are mentioned, trigger automated verification:

```bash
# When task mentions "we need JSON::XS"
→ bin/p7-deps scan-usage JSON::XS [--aggressive]
  ├─ Grep codebase for actual use: grep -r 'JSON::XS|JSON::PP'
  ├─ Check pm-dep declarations: ls configuration/zenki/*/pm-dep/ | grep JSON
  ├─ Verify in profiles: grep -r 'JSON' .deps/profiles.yaml
  ├─ Find actual imports: ./bin/ncode s src perlmod.autoload | grep JSON
  └─ Report: matches X files, declared in Y zenka, used in Z modules

# When task says "removed X dependency"
→ bin/p7-deps verify-removal X [--aggressive]
  ├─ Search for orphaned references
  ├─ Find any remaining imports or declarations
  ├─ Identify code that might break without X
  └─ Report: safe to remove? (zero references)
```

**Pattern Matching Examples**:
```
Task: "Implemented webhook validation using Crypt::OpenSSL::X509"
→ Parse: needs Crypt::OpenSSL::X509
→ Scan: verify used in code, add to profile if missing

Commit: "Remove obsolete Image::Scale dependency"
→ Parse: removing Image::Scale
→ Scan: confirm no code references it, can safely delete pm-dep entry

Task: "Added cryptographic validation layer"
→ Parse: likely needs Crypt::* modules
→ Scan: find what Crypt modules were actually imported
```

### Phase 1.5: Analysis Command

```bash
bin/p7-deps analyze-sessions [--since 1w] [--format json|yaml] [--intent-driven]
```

Examine:
- Recent commits and task documentation (now with intent parsing)
- Extract stated intent (what dependencies were mentioned)
- Validate against actual code (scan-usage for each mention)
- Which modules were actually loaded in recent work
- Group by session/topic, weighted by intent + reality
- Output dependency profiles for each
- Flag discrepancies: declared but not used, used but not declared

### Phase 2: Profile Creation

```bash
bin/p7-deps create-session-profile <session-name> [modules...]
```

In workspace-transfer/.deps/profiles.yaml:
```yaml
  session-2025-11-27-web-dev:
    description: "Web development session (2025-11-27)"
    includes:
      - minimal
      - runtime
      - network
      - cryptography
    cpan:
      - URI
      - HTTP::Request
      - JSON::XS
      - Template
      # ... modules from this session's actual work

  session-2025-11-27-crypto:
    description: "Cryptography research (2025-11-27)"
    includes:
      - minimal
      - runtime
      - cryptography
    cpan:
      - Crypt::OpenSSL::RSA
      - Crypt::Random
      - Crypt::Cipher
      # ... crypto modules used
```

### Phase 2.5: Discrepancy Detection

Before creating profiles, validate intent vs. reality:

```bash
bin/p7-deps detect-discrepancies [--session recent] [--report detailed]
```

**Types of Discrepancies Caught**:

1. **Declared But Unused**
   - Module in pm-dep/ but never imported in code
   - `scan-usage` returns zero matches
   - Question: Can we remove it?

2. **Used But Not Declared**
   - Code imports module but not in pm-dep/
   - `grep -r "use X"` finds references but declaration missing
   - Question: Should we add it to pm-dep/?

3. **Intent vs. Reality Mismatch**
   - Task says "added JSON module" but code uses JSON::XS from external package
   - Intent parsing found mention but scan shows different actual module used
   - Question: What really happened?

4. **Orphaned Declarations**
   - pm-dep/ entry points to a module that doesn't exist in CPAN
   - Typo in declaration: `JSON-XS` vs `JSON::XS`
   - Question: Fix declaration or remove entry?

**Example Report**:
```
Discrepancies Found: 7

DECLARED BUT UNUSED:
  • Image::Scale (in zulum/pm-dep/) - last used in commit 2025-11-15
    → Candidate for removal (safe, zero references)

USED BUT NOT DECLARED:
  • JSON::PP (imported in workflow code) - not in workflow/pm-dep/
    → Should declare in workflow/pm-dep/JSON__PP

INTENT VS REALITY:
  • Task: "Added cryptographic validation using Crypt::OpenSSL::X509"
  • Code: Actually uses Crypt::Digest::BLAKE2b_384
  → Task intent unclear, real dependency different than stated

ORPHANED:
  • x11-protocol-perl (in X-11/pm-dep/) - no such CPAN module found
  → Typo? Should be X11::Protocol
```

### Phase 3: Convergence Analysis

```bash
bin/p7-deps analyze-convergence [--min-sessions 3]
```

Find modules appearing in 3+ session profiles → candidates for permanent inclusion:
```
┌─ High Convergence (appears in 4+ sessions)
│  ├─ JSON::XS (web, ml, data processing, config)
│  ├─ Crypt::Digest::* (crypto, web, system)
│  └─ ...
├─ Medium Convergence (appears in 3 sessions)
│  ├─ LWP::UserAgent (web, network, testing)
│  └─ ...
└─ Low Convergence (appears in 1-2 sessions)
   ├─ Specific tools for specific work
   └─ Leave in session profiles only
```

### Phase 4: Smart Defaults

```bash
bin/p7-deps set-default-profile [profile-name]
```

The default should:
- Include minimal + runtime + network + cryptography (foundational)
- Include all "high convergence" modules (broadly useful)
- Include interface modules (HTTP, stdio, sockets - enables interaction)
- Be installable in 2-3 minutes

Result: New developers get:
- ✅ Basic Protocol-7 capability
- ✅ Can talk to local/remote zenka (networking)
- ✅ Can spawn processes and interact
- ✅ Secure by default (crypto layer)
- ✅ Can add session-specific modules as needed

---

## Data Flow

```
Recent Sessions
    ↓
[analyze-sessions] → Session Profiles in workspace-transfer
    ↓
[analyze-convergence] → Convergence Score for each module
    ↓
[set-default-profile] → Smart default (minimal + convergence + interfaces)
    ↓
Next Developer Installation
    ├─ Fast (only truly common modules)
    ├─ Complete (can interact with system)
    └─ Extensible (add session profiles as needed)
```

---

## Expected Benefits

### For Developers
- Default installation covers what you actually need (not guessing)
- Session profiles let you install exactly the right tools for current task
- Fast installation (only what's used, not everything possible)

### For System Understanding
- Dependency profiles reflect actual workflow patterns
- New team members can see "what does web dev look like here?"
- Natural way to onboard: pick the profile that matches your work

### For Efficiency
- Convergence analysis shows what's genuinely shared
- Highlights when to refactor (if module appears in 5+ profiles, should be base)
- Tracks system's natural evolution over time

### For Knowledge
- Session profiles become permanent documentation of "here's what we built"
- Future developers reading profiles understand recent work
- Natural history of project priorities and focus areas

---

## Implementation Timeline

### Session N+1 (Short-term)
- Create `analyze-sessions` command to read recent work
- Generate initial session profiles from last 1-2 weeks
- Document the capability

### Session N+2 (Medium-term)
- Implement `analyze-convergence` to find natural commons
- Refine default profile based on convergence analysis
- Test with actual developer onboarding

### Session N+3+ (Long-term)
- Automated weekly analysis as part of workflow
- Natural feedback loop: usage drives profiles → profiles enable new usage
- System optimizes itself through actual patterns

---

## Intent-Driven Architecture: Bridging Communication and Reality

### The Semantic Layer

Most dependency management operates at one layer:
- ❌ **Pure filesystem** - Only look at what's declared in pm-dep/ directories
- ❌ **Pure code** - Only scan for actual imports
- ✅ **Intent + Reality** - Parse what people SAY they need, validate against what code ACTUALLY uses

The intent-driven approach adds critical intelligence:

```
Developer Intent          Code Reality          System State
(Task description)  ↔     (grep/scan)      ↔     (pm-dep/, profiles.yaml)
     ↓                         ↓                        ↓
"Added crypto"        →  grep finds Crypt::*  →  Update pm-dep/Crypt*
"Removed JSON"        →  No code uses JSON    →  Delete pm-dep/JSON*
"Need validation"     →  grep: X509 module    →  Create declaration
```

### Pattern Recognition at Human Level

This enables new capabilities:

**Automatic Declaration Creation**
```
When task says: "Implemented webhook validation using Crypt::OpenSSL::X509"
→ Parse mentions Crypt::OpenSSL::X509
→ Scan confirms it's imported in code
→ Suggest: "Create configuration/zenki/<relevant-zenka>/pm-dep/Crypt__OpenSSL__X509"
```

**Safety Checks for Removal**
```
When task says: "Remove obsolete Image::Scale dependency"
→ Parse extracts Image::Scale
→ Scan confirms: not imported anywhere
→ Verify: safe to remove
→ Suggest: "Delete configuration/zenki/zulum/pm-dep/Image__Scale"
```

**Knowledge Capture**
```
When developer mentions: "Need JSON processing"
→ Intent: JSON-related module
→ Scan: finds JSON::XS being used
→ Document: "This zenka uses JSON::XS for high-speed JSON processing"
→ Profile: Include JSON::XS in this zenka's profile
```

---

## Connection to Larger Vision

This fits perfectly into the emergent development philosophy:

**Top-Down Approach** (Wrong):
"Here's all possible modules. You choose."
→ Overwhelming, wrong defaults, bloated installs

**Emergent Approach** (Right):
"Here's what people actually used last week."
→ Sensible defaults, natural evolution, efficient

The system's own usage patterns become the guide for future structure. No central authority
deciding what's important—let the work reveal it.

---

## Technical Integration

### With Existing bin/p7-deps
- Share introspection functions (get_zenki_pm_deps, get_zenki_os_deps)
- Extend to analyze workspace-transfer session profiles
- Commands integrate smoothly:
  ```bash
  bin/p7-deps zenka-modules              # What zenka need
  bin/p7-deps analyze-sessions           # What sessions actually used
  bin/p7-deps analyze-convergence        # What's broadly useful
  bin/p7-deps set-default-profile        # Smart default based on reality
  ```

### With workflow zenka
- Task documentation → session topics
- Commit history → what was actually built
- Recent module loads → dependencies that matter
- All available through existing workflow commands

### With knowledge repository
- Each session's profile becomes documentation
- Future models reading profiles understand priorities
- Natural history of evolution

---

## Example Output

```
$ bin/p7-deps analyze-sessions --since 2w

Found 4 recent sessions:
┌─ 2025-11-27 workspace-initialization
│  └─ 58 modules (minimal setup, dependency analysis)
├─ 2025-11-25 web-dev-sprint
│  └─ 24 modules (HTTP, templating, JSON)
├─ 2025-11-20 crypto-research
│  └─ 18 modules (cryptography, random, hashing)
└─ 2025-11-15 deployment-work
   └─ 19 modules (process management, networking, system)

Session profiles created in workspace-transfer/.deps/profiles.yaml

$ bin/p7-deps analyze-convergence --min-sessions 2

High Convergence (4+ sessions):
  • JSON::XS (web-dev, ml, data processing, config)
  • Crypt::Digest::* (crypto, web, system)
  • IO::Socket::* (web, network, system)

Medium Convergence (2-3 sessions):
  • LWP::UserAgent (web-dev, testing)
  • Template (web-dev, deployment)

Recommendation: Include high convergence in default profile
```

---

## The Beautiful Thing

This approach makes the system **self-documenting and self-optimizing**:

- **Self-Documenting**: Profiles show what people do
- **Self-Optimizing**: Convergence analysis shows what to prioritize
- **Emergent**: No central planning needed; patterns emerge naturally
- **Responsive**: When work shifts, profiles reflect that quickly
- **Efficient**: Default profiles get better as system matures

The system learns from itself.

---

**Concept Status**: Ready for implementation
**Suggested Timeline**: Next 1-3 sessions
**Dependencies**: Introspection tools just restored
**Integration Points**: bin/p7-deps, workflow zenka, knowledge repository
