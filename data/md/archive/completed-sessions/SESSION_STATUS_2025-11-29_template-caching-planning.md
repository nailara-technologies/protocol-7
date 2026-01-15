# Session Summary: Web Template Caching & Content Routing Planning

**Date**: 2025-11-29  
**Status**: Planning & Documentation Complete ✅  
**Next Phase**: Implementation (Module creation & testing)

---

## What Was Accomplished

### 1. Comprehensive Documentation (3 files, 2,084 lines)

#### A. TEMPLATE_SYSTEM_STATUS_SUMMARY.md (370 lines)
- Current state of web-zenka infrastructure (11 existing modules documented)
- Identified cache implementation patterns used in Protocol-7
- Documented three cache pattern approaches (in-memory, file-based TTL, persistent line-delimited)
- Mapped existing template system (90% complete, cache not yet implemented)
- Listed dependencies and architectural context

**Key Finding**: Template system infrastructure 90% complete. Only cache logic needs implementation.

#### B. TEMPLATE-SYSTEM-MODULE-REFERENCE.md (1,080 lines)
Complete API reference for all template modules including:

**Existing Modules** (11 documented):
- `web.init_code` - Configuration setup
- `web.process_template_recursive` - Main parsing engine (recursive, with depth limiting)
- `web.process_template_ipc` - Async IPC handler to web zenka
- `httpd.process_template` - HTTP layer handler
- `httpd.handler.web_template_reply` - Async callback for rendered results
- `httpd.vhost_template_resolver` - Template finder (3-level hierarchy)
- `web.skin_resolver` - CSS cascade with fallbacks
- `web.menu_generator` - Navigation from filesystem
- `httpd.route_dispatcher` - Request routing (ACME → API → Template → Static)
- `web.assets.load_registry` - Asset manifest loading
- `web.execute_template_command` - Single command executor

**New Modules to Implement** (4 modules):
1. `web.scan_content_directories` - Index templates at startup
2. `httpsd.route_template_request` - Smart routing with caching
3. `web.template_cache.get` - Retrieve with TTL expiration
4. `web.template_cache.set` - Store with timestamp

**Data Structures**:
- Cache storage format: `$data{'web.template_cache'}{$key} = { content, timestamp, ttl, size }`
- Content index format: `{ path => { has_template, template_path, mtime, ... } }`
- Route cache format: `{ type, handler, handler_args, cached, reason }`

#### C. web-template-caching-implementation.yaml (634 lines)
Complete task specification with 5 phases:

**Phase 1: Design & Environment Setup** (1.0 token)
- Launch v7 zenka and validate runtime
- Verify module naming conventions
- Confirm cache storage strategy

**Phase 2: Core Module Implementation** (2.5 tokens)
- Implement: `web.scan_content_directories` (0.75 tokens)
- Implement: `web.template_cache.get` (0.5 tokens)
- Implement: `web.template_cache.set` (0.5 tokens)
- Implement: `httpsd.route_template_request` (1.0 tokens)

**Phase 3: Integration Testing** (0.75 tokens)
- Create test vhost structure
- Test scanner, router, and cache against real files
- Verify TTL expiration and metrics

**Phase 4: Documentation** (0.5 tokens)
- Document all module APIs
- Plan HTTP handler integration

**Phase 5: Handler Integration** (0.5 tokens, optional)
- Integrate router into `httpd.http_get`
- Full end-to-end testing

**Total Budget**: 3.75-5.25 tokens (with Phase 5 optional)

---

### 2. Environment Setup

#### Dependencies Verified
- ✅ libcryptx-perl (Crypt::Misc) installed
- ✅ Digest::BMW compiled locally and available
- ✅ All required Perl modules documented in dependency scripts
- ✅ PERL5LIB paths configured correctly

#### Installation Scripts Already Support This
Found that `bin/dependencies/install_minimal_dependencies.debian.sh` **already includes**:
```bash
cpanm Crypt::Ed25519 Digest::Skein Digest::BMW Net::IP::Lite URI::QueryParam \
```

This means all necessary CPAN modules are documented and installable through standard Protocol-7 dependency management.

#### Note on v7 Zenka Socket Configuration
v7 zenka requires proper Unix socket configuration in `/var/run/.7/UNIX/`. This is handled by the systemd service or requires additional configuration setup (to be addressed in next session when running live integration tests).

---

### 3. Git Commits Created

```
f1994044c [CLAUDE] docs: Add comprehensive template system documentation and module reference
2564db3a0 [CLAUDE] docs: Add web-template-caching-implementation task specification
```

Commits are atomic, well-documented, and ready for review.

---

## Key Architectural Insights Documented

### 1. Cache Design Strategy
- **Pattern**: Similar to weather.parent.cache (timestamp-based TTL)
- **Storage**: In-memory `$data{'web.template_cache'}`
- **Key Format**: `"$vhost:$path"` (vhost-specific, normalized paths)
- **Expiration**: Check age on retrieval, auto-remove if expired
- **Integration Point**: Inside `web.process_template_recursive`

### 2. Routing Architecture
- **Priority**: ACME Challenge → API → Template → Static (in order)
- **Template Detection**: Uses existing `httpd.vhost_template_resolver`
- **Caching**: Route decisions cached with configurable TTL
- **Integration**: Early in `httpd.http_get` or `httpd.request_handler`

### 3. Content Scanning
- **Purpose**: Pre-index templates for fast route decisions
- **Pattern**: Like web.menu_generator (simple in-memory hash)
- **Invalidation**: Detect changes via mtime tracking
- **Usage**: Feeds route dispatcher for O(1) lookups

### 4. Module Specifications
All 4 new modules have:
- ✅ Clear function signatures
- ✅ Return value documentation
- ✅ Usage examples
- ✅ Success criteria for testing
- ✅ Integration points identified
- ✅ Pseudocode provided

---

## Why This Approach Works

### Documentation First
1. **Prevents Refactoring**: Having a complete spec prevents mid-implementation changes
2. **Coordinates Work**: Clear API contracts make parallel work possible
3. **Reference Point**: Future maintainers have complete architectural context
4. **Flexibility**: Namespace can be optimized later with `ncode replace all` if needed

### Modular Implementation
1. **Independent Testing**: Each module works standalone
2. **Clear Dependencies**: Only uses existing Protocol-7 patterns
3. **Incremental Integration**: Can add modules to system one at a time
4. **Risk Reduction**: Failures are isolated and easy to debug

### Leverages Existing Patterns
1. **Cache TTL**: Uses same approach as weather.parent.cache
2. **IPC Model**: Uses existing httpd ↔ web zenka pattern
3. **Data Storage**: Uses `$data{...}` hashing convention
4. **Metrics**: Tracks performance like other modules

---

## Ready for Implementation

### What's Required to Start
1. ✅ Documentation complete - API specs written
2. ✅ Dependencies documented and available
3. ✅ Testing strategy outlined
4. ✅ Task phases clearly defined
5. ✅ Success criteria established

### Minimal Friction Path to Features
1. Create `modules/web.scan_content_directories` (simple file indexing)
2. Create `modules/web.template_cache.get` (cache lookup with TTL)
3. Create `modules/web.template_cache.set` (cache storage)
4. Create `modules/httpsd.route_template_request` (intelligent routing)
5. Test each independently with mock data
6. Test with live v7 zenka environment
7. Optionally integrate into httpd handler

---

## Token Budget Summary

```
Documentation Phase:  ~12-15 tokens (completed)
  - 3 comprehensive documentation files
  - Module API specifications
  - Task planning and breakdown

Implementation Phase (next):
  - Phase 1: ~1 token (env setup + validation)
  - Phase 2: ~2.5 tokens (4 modules, testing)
  - Phase 3: ~0.75 tokens (integration validation)
  - Phase 4: ~0.5 tokens (final documentation)
  - Phase 5: ~0.5 tokens (optional handler integration)
  
  Subtotal: 3.75-5.25 tokens
  Safety Buffer (10%): 0.4-0.5 tokens
  
  Total Realistic: 4-6 tokens for complete implementation
```

---

## Known Unknowns (Risk Mitigation)

| Risk | Mitigation |
|------|-----------|
| Module syntax errors | Test each immediately after creation in repl |
| Cache key conflicts | Use consistent format with examples |
| TTL logic off-by-one | Test with short TTLs (2-5 seconds) |
| Integration breaks existing code | Keep httpd changes minimal, test static files |
| File path handling issues | Use absolute paths, test on multiple vhosts |
| Unicode/encoding edge cases | Follow existing protocol-7 patterns |

---

## Recommended Next Session

1. **Environment**: Set up v7 zenka with proper socket configuration
2. **Module 1**: Implement `web.scan_content_directories` with unit tests
3. **Module 2**: Implement cache.get/set pair with TTL validation
4. **Module 3**: Implement router with route decision caching
5. **Integration**: Test full workflow with live test vhost
6. **Optional**: Integrate into httpd handler if tokens remain

---

## Documentation Structure Created

```
docs/
├── TEMPLATE_SYSTEM_STATUS_SUMMARY.md              (370 lines)
│   └── Current state, existing modules, gaps
│
├── modules/
│   ├── TEMPLATE-SYSTEM-MODULE-REFERENCE.md       (1,080 lines)
│   │   └── API reference, specifications, data structures
│   │
│   └── [future implementation guides]

data/yaml/coding-tasks/
└── web-template-caching-implementation.yaml       (634 lines)
    └── 5 phases, token budgets, success criteria
```

All files committed and available for next session reference.

---

## Conclusion

**What We Achieved**:
- ✅ Complete architectural documentation (2,084 lines)
- ✅ Detailed task specification (634 lines)
- ✅ API reference for all modules (1,080 lines)
- ✅ Implementation planning with clear phases
- ✅ Testing strategy and success criteria
- ✅ Risk identification and mitigation
- ✅ Token budget estimation

**Ready For**: Implementation phase with clear specification, minimal ambiguity, and flexible namespace strategy.

**Next Session**: Launch v7 zenka and begin implementing the 4 core modules following the YAML specification.

---

**Session Duration**: ~2 hours (documentation + environment setup)  
**Files Created**: 3 major documents (2,084 lines total)  
**Commits**: 2 (both documented and clean)  
**Status**: Documentation phase COMPLETE, ready for implementation phase
