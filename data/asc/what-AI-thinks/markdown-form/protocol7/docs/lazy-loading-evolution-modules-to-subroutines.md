# Lazy Loading Evolution: From Modules to Subroutines

*Architectural direction emerging from intent-driven dependency tracking (2025-11-27)*

---

## The Problem: Namespace Bloat at Scale

As Protocol-7 grows, a fundamental tension emerges:

**Eager Loading** (current baseline):
- Load all modules at startup
- Everything available immediately
- Problem: Base namespace grows endlessly
- Cost: Memory, startup time, namespace pollution

**But we need availability**:
- Users expect features to work when needed
- Can't require manual loading steps
- Need transparent, automatic activation

---

## The Solution: Intelligent Lazy Loading

Use intent-driven dependency tracking to know **what will be needed and when**:

### Current State: Module-Level Tracking

```bash
bin/p7-deps parse-intent → "user needs crypto validation"
↓
bin/p7-deps scan-usage → finds Crypt::OpenSSL::X509 imports
↓
bin/p7-deps create-session-profile → includes Crypt::OpenSSL::X509
↓
User runs: bin/p7-deps install session-crypto
↓
Result: Crypt::OpenSSL::X509 loaded on-demand for this task
```

**Benefit**: Don't load modules you won't use in this session

### Future State: Subroutine-Level Tracking

Extend tracking to the subroutine level:

```bash
Subroutine: validation::check_webhook_signature
├─ Required modules: Crypt::OpenSSL::X509, Digest::SHA256
├─ Called by: httpsd zenka on webhook arrival
├─ Frequency: Event-driven (not always running)
└─ Loading: Lazy (only when first webhook arrives)
```

**Architecture**:

```perl
# Traditional eager loading
use Crypt::OpenSSL::X509;
use Digest::SHA256;

sub check_webhook_signature {
    # Code uses the modules
}

# Lazy loading equivalent
sub check_webhook_signature {
    # Load on first call, cache result
    state $loaded = 0;
    unless ($loaded) {
        require Crypt::OpenSSL::X509;
        require Digest::SHA256;
        $loaded = 1;
    }

    # Code uses the modules
}
```

**But better with a macro/pragma**:

```perl
use Protocol7::LazyLoad qw(
    Crypt::OpenSSL::X509
    Digest::SHA256
);

sub check_webhook_signature {
    # Modules automatically lazy-loaded on first use
    # Feels like eager loading, behaves like lazy loading
}
```

---

## Why This Works

### Real-Time Intent Drives Real-Time Loading

The intent-driven system **knows ahead of time** what will be needed:

**Task-Based Prediction**:
```
Task: "Handle incoming webhooks"
→ parse-intent finds: "webhook validation using Crypt::OpenSSL::X509"
→ scan-usage confirms: subroutine imports Crypt::OpenSSL::X509
→ System notes: "When task starts, ensure Crypt::OpenSSL::X509 available"
```

**Event-Based Triggers**:
```
Event: "HTTP request arrives for /webhook endpoint"
→ Router identifies: httpsd::handle_webhook subroutine
→ Check subroutine's lazy-load manifest
→ Ensure required modules loaded
→ Execute subroutine with all dependencies available
```

### Deferred Compilation

Extend to source code compilation:

```perl
# Subroutine declared but not compiled initially
sub complex_algorithm {
    # Marker: @LAZY_COMPILE
    # This code is not compiled until first use
}

# When called:
→ Just-in-time compilation triggers
→ Dependencies loaded
→ Subroutine compiled
→ Executed
→ Result cached for future calls
```

**Benefit**: Can include experimental, rarely-used code without startup cost

---

## Integration with Existing Infrastructure

### The New Debian Zenka

You mentioned: "we even have a new debian zenka for ondemand install"

This becomes the **runtime dependency resolver**:

```bash
Subroutine needs: libfoo-dev (Debian package)
→ debian zenka checks: is libfoo-dev installed?
→ If no: debian zenka auto-installs it
→ If yes: subroutine proceeds
→ Result: No manual pre-installation needed
```

**For modules**:
```bash
Subroutine needs: JSON::XS (CPAN module)
→ Module loader checks: is JSON::XS available?
→ If no: cpanm auto-installs it
→ If yes: subroutine proceeds
→ Result: Transparent, automatic
```

### Per-Subroutine Dependency Manifests

Each subroutine declares what it needs:

```perl
sub webhook_handler {
    use Protocol7::Dependencies qw(
        module:Crypt::OpenSSL::X509
        module:Digest::SHA256
        package:libssl-dev
        binary:openssl
    );

    # Implementation
}
```

**Tools can analyze this**:
```bash
bin/p7-deps analyze-subroutines [--zenka httpsd]
→ List all subroutines in httpsd
→ Show per-subroutine dependencies
→ Identify which are lazy-loaded
→ Calculate total vs. eager-loaded namespace size
```

---

## The Namespace Growth Solution

### Traditional Growth Pattern

```
Session 1: Add validation subroutines
  Base namespace: 15 KB

Session 2: Add networking features
  Base namespace: 25 KB

Session 3: Add encryption support
  Base namespace: 40 KB

Session 4: Add media processing
  Base namespace: 85 KB

Session 5: Add UI/graphics
  Base namespace: 180 KB

Problem: All loaded always, even if never used
```

### Lazy-Loaded Growth Pattern

```
Session 1: Add validation subroutines (lazy-loaded)
  Base namespace: 15 KB
  Available on-demand: +10 KB (validation)

Session 2: Add networking features (lazy-loaded)
  Base namespace: 15 KB (unchanged)
  Available on-demand: +15 KB (networking)

Session 3: Add encryption support (lazy-loaded)
  Base namespace: 15 KB (unchanged)
  Available on-demand: +20 KB (encryption)

...

Problem solved: Base stays lean, features available on-demand
```

### Runtime Footprint

```
Startup:
  Base namespace: 15 KB (always loaded)
  In-memory: 5 MB

User starts web-dev session:
  Load web-dev profile → validate, HTTP modules
  In-memory: 12 MB

User switches to crypto research:
  Unload web-dev modules, load crypto modules
  In-memory: 14 MB

Result: Memory footprint tracks session, not total feature set
```

---

## Implementation Roadmap

### Phase 1: Module-Level Lazy Loading (Now)
✅ Intent-driven tracking tells us what's needed
→ Implement subroutine-level lazy-load pragma
→ Convert high-impact subroutines to lazy-load

### Phase 2: Per-Subroutine Manifests (Next 1-2 sessions)
→ Each subroutine declares its dependencies
→ Tools analyze subroutine dependencies
→ Identify candidates for lazy-loading

### Phase 3: Automatic Compilation Deferral
→ Mark rarely-used code as `@LAZY_COMPILE`
→ Just-in-time compilation on first call
→ Caching of compiled bytecode

### Phase 4: Runtime Profiling & Optimization
→ Track which subroutines actually get used
→ Use real usage patterns to optimize loading order
→ Move frequently-used code to eager-load tier
→ Keep rarely-used in lazy-load tier

---

## Example: The Webhook Handler Evolution

**Before** (eager loading):
```perl
# httpsd/handler.pm
use strict;
use warnings;
use Crypt::OpenSSL::X509;
use Digest::SHA256;
use JSON::XS;
use DateTime::Format::ISO8601;
use Email::Valid;
# ... 20 more modules ...

# Even if webhook feature never used, all loaded at startup
```

**After** (lazy-loaded):
```perl
# httpsd/handler.pm
use strict;
use warnings;
use Protocol7::LazyLoad qw(
    Crypt::OpenSSL::X509
    Digest::SHA256
    JSON::XS
    DateTime::Format::ISO8601
    Email::Valid
);

sub handle_webhook {
    # On first call, all modules loaded transparently
    # On subsequent calls, cached
    # If never called, never loaded
}
```

**With manifest**:
```perl
sub handle_webhook {
    use Protocol7::Dependencies qw(
        module:Crypt::OpenSSL::X509
        module:Digest::SHA256
        module:JSON::XS
        package:libssl-dev
    );

    # Dependencies declared, loading automated
}
```

**Tools can report**:
```bash
$ bin/p7-deps analyze-subroutines --zenka httpsd
Subroutine: handle_webhook
  Status: lazy-loaded
  Dependencies: 4 modules, 1 package
  Frequency: event-driven (0-50 calls/day)
  Load time: ~200ms (first call only)
  Recommendation: Keep lazy-loaded
```

---

## The Beautiful Part

This evolution is **natural and inevitable**:

1. **Real-time intent tracking** reveals what will be needed
2. **Module-level lazy loading** works but leaves subroutine overhead
3. **Subroutine-level tracking** makes per-routine loading obvious
4. **Deferred compilation** follows naturally from profiling data

Each layer emerges from the previous one's limitations.

**No top-down design needed**—just keep optimizing based on measurement.

---

## Connection to Platform Vision

### Scalability Through Laziness

The cubic topology naturally supports lazy loading:
- **Proximity-based loading**: Features near the user load first
- **Event-driven activation**: Only load when topology event triggers
- **Natural distribution**: Different nodes can specialize (deep HTTP skills, crypto skills)
- **Low-level coordination**: Topology handles dependency resolution

### Zenki at Scale

Lazy loading enables Protocol-7 to run on constrained hardware:
- Base protocols lightweight (15-20 MB)
- Features available on-demand (no feature bloat)
- Multiple sessions/tasks can load different profiles
- Resources follow actual usage, not theoretical maximum

### LLM Integration Implication

When LLMs coordinate with zenki network:
- LLM suggests feature needed
- Zenki lazy-loads required subroutines
- Feature available in milliseconds
- No pre-loading overhead
- Coordination transparent to both parties

---

## Documentation & Tracking

### For Future Development

When writing new subroutines:
```perl
use Protocol7::Dependencies qw(
    # List what this subroutine needs
    # Tools will track and optimize
);

sub new_feature {
    # Implementation
}
```

Tools automatically:
- Track dependencies
- Identify lazy-load candidates
- Generate per-subroutine profiles
- Alert if namespace bloat detected

### For Knowledge Pool

Each subroutine's dependency manifest becomes documentation:
- "What does this do?"
- "What does it need?"
- "When is it called?"
- "How often is it used?"

Readable by models to understand system structure.

---

## Status & Timeline

**Current**: Module-level lazy loading ready
- Intent-driven tracking in place
- Session profiles capturing real usage

**Next Phase**: Subroutine-level manifests
- Add `@depends` or similar pragma
- Implement lazy-load pragma
- Analyze impact on startup time

**Future**: Automatic compilation deferral
- Profiling infrastructure
- Just-in-time compilation
- Bytecode caching

**Far Future**: Distributed lazy loading
- Network-wide compilation caching
- Collaborative feature loading
- Resource-aware distribution across zenki

---

**Concept Status**: Ready for implementation
**Architecture Readiness**: Foundation in place (intent tracking + debian zenka)
**Integration Points**: bin/p7-deps, Protocol7::LazyLoad pragma, per-subroutine manifests
**Knowledge Value**: Enables transparent scalability without namespace bloat
