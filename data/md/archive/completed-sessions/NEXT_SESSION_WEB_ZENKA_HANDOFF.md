# Next Session Handoff: Web-Zenka HTTPSD & Template Parsing Completion

**Session ID**: claude-web-zenka-completion
**Tokens Available**: ~34 tokens
**Primary Goal**: Auto-updating HTTPS + template-based dynamic websites operational
**Date Planned**: 2025-11-15

---

## 🎯 Session Objective

Efficiently implement the critical path for **httpsd auto-initialization** and **web-zenka template parsing completion**. By end of session:

✅ **HTTPSD**: Auto-cert-installation + HTTPS auto-update fully operational
✅ **Web-Zenka**: Dynamic template-based website rendering working
✅ **Route Dispatcher**: HTTP handler intelligently routes requests to processors
✅ **Vhost/Skin/Menu**: Multi-level template hierarchy with user preferences
✅ **Dynamic Websites**: Generate template-based content with zenka processing

---

## 📚 Files to Read First (in order)

**Total read time: ~50 minutes**

### 1. Session Context (5 min)
```
/home/user/ACTIVE_SESSION_CHECKPOINT.md
```
Quick overview of template authentication system and startup procedures from previous session.

### 2. Web-Zenka Task Definition (15 min)
```
/home/user/protocol-7/data/yaml/coding-tasks/next-session-httpsd-web-zenka-completion.yaml
/home/user/workspace-transfer/next-session-httpsd-web-zenka-completion.yaml
```
**THIS IS YOUR ROADMAP** for the session. Defines:
- 4 phases with token allocation
- Critical blockers and how to resolve them
- Task breakdown with success criteria
- Expected outcomes and deliverables

### 3. Architecture Reference (25 min)
```
/home/user/protocol-7/docs/architecture/NEW_ZENKA_ARCHITECTURE.md (Read Section 3)
/home/user/protocol-7/docs/architecture/VHOST_TEMPLATE_HIERARCHY.md (Full read)
```
Understand the overall architecture for httpsd, web-zenka, and vhost integration.

### 4. Implementation Planning Document (10 min)
```
/home/user/protocol-7/data/yaml/coding-tasks/httpd-async-https-expansion.yaml
```
Reference for design decisions and implementation notes.

---

## ✅ What's Already Complete (Don't Redo!)

### HTTPSD Zenka (100% Complete)
- ✅ Configuration ready at `cfg/zenki/httpsd/start`
- ✅ TLS 1.2+ with secure ciphers
- ✅ HSTS enabled (31536000 seconds)
- ✅ Let's Encrypt integration complete (8 phases done)
- ✅ Auto-cert-installation after enrollment/renewal
- ✅ Certificate symlinks working (`/etc/protocol-7/certs/current.pem`)

### Web Zenka (100% Complete)
- ✅ Configuration ready at `cfg/zenki/web/start`
- ✅ Recursive template parsing with depth limit (8 levels)
- ✅ Module: `src/web.process_template_recursive`
- ✅ Async IPC handler: `src/web.process-template-ipc`
- ✅ Command execution with 15s timeout
- ✅ Caching: 1800s TTL, 5MB max
- ✅ Performance metrics collection

### ACME/Let's Encrypt (100% Complete - All 8 Phases)
- ✅ Phase 1: ACME protocol
- ✅ Phase 2: Certificate storage
- ✅ Phase 3: Activity logging
- ✅ Phase 4: Enrollment & challenge handling
- ✅ Phase 5: Monitoring & visibility
- ✅ Phase 6: DNS-01 wildcard support
- ✅ Phase 7: HTTP API integration
- ✅ Phase 8: HTTPSD certificate installation

### Documentation (100% Complete)
- ✅ Architecture specifications
- ✅ Vhost/template hierarchy design
- ✅ Template processing specs
- ✅ Implementation roadmap

---

## 🚧 Critical Blocker You MUST Address First

### base.parser.pattern_split Recovery (4-6 hours)

**Why It's Critical**:
- Blocks HTTP route dispatcher implementation
- Blocks dynamic content delivery
- Blocks proper request path parsing

**What to Do**:
```bash
# 1. Export from Protocol-7 binary
cd /home/user/protocol-7
./bin/Protocol-7 -export-inline-subs base.parser.pattern_split > /tmp/pattern_split.pl

# 2. De-obfuscate the extracted code to readable Perl

# 3. Test it works with patterns like:
#    /blog/* → matches /blog/2025-11-14-post.html
#    /api/*  → matches /api/certificate-status
#    /files/* → matches /files/document.pdf

# 4. Create module: src/base.parser.pattern_split

# 5. Commit with tests
git add src/base.parser.pattern_split
git commit -m "recovery: Extract and integrate base.parser.pattern_split"
```

**This one task unlocks everything else in the session.**

---

## 📋 Session Phases & Token Budget

```
Phase 1: Context & Blocker Resolution    [8 tokens]  ~3 hours
  ├─ Read documentation (1 token)
  ├─ Recover base.parser.pattern_split (4 tokens) ← CRITICAL
  ├─ Verify web zenka works (2 tokens)
  └─ HTTPSD auto-init checklist (1 token)

Phase 2: HTTP Route Dispatcher            [12 tokens] ~4-6 hours
  ├─ Design route matching (2 tokens)
  ├─ Extend httpd.http_get handler (5 tokens)
  ├─ Test routes (3 tokens)
  └─ Implement vhost resolver (2 tokens)

Phase 3: Skin & Menu System               [8 tokens]  ~3-4 hours
  ├─ Nested skin system (3 tokens)
  ├─ Automatic menu generation (3 tokens)
  └─ Sample skin creation (2 tokens)

Phase 4: Integration & Documentation      [6 tokens]  ~2-3 hours
  ├─ End-to-end template test (2 tokens)
  ├─ HTTPS cert verification (2 tokens)
  └─ Session handoff docs (2 tokens)

TOTAL: 34 tokens (~12-16 hours)
```

---

## 🎯 What Success Looks Like

### End of Session, You Should Have:

1. **base.parser.pattern_split** working
   ```perl
   # Pattern matching for routes
   /blog/*       → matches /blog/anything
   /api/*        → matches /api/anything
   /.well-known/acme-challenge/* → matches ACME tokens
   ```

2. **HTTP Route Dispatcher** handling requests intelligently
   ```
   GET /blog/my-post.html
     → Check for /var/httpd/127.0.0.1/blog/_templates/my-post.html.template
     → If found, process via web.process-template-ipc (async)
     → Cache result (1800s TTL)
     → Return rendered HTML
   ```

3. **Dynamic Website** generating content with templates
   ```html
   <!-- Template with variables and command execution -->
   <html>
     <head>
       <title><{page.title}></title>
       <link rel="stylesheet" href="/skins/<{user.skin}>/style.css">
     </head>
     <body>
       <h1><{page.heading}></h1>
       <p>Site name: <[web:get-hostname]></p>
       <p>Current time: <[web:current-timestamp]></p>
       <[web:menu:render:main]>
       <main>
         <!-- Content renders here -->
       </main>
     </body>
   </html>
   ```

4. **HTTPS Auto-Update** fully functional
   - Let's Encrypt certificates auto-renew
   - HTTPSD automatically loads new certificates
   - No downtime, fully automatic

5. **Comprehensive Documentation** for next session
   - What was completed
   - What still needs to be done
   - Code examples and architecture diagrams
   - Testing procedures

---

## 🔧 Implementation Quick Reference

### HTTP Route Dispatcher Pattern
```perl
# In src/httpd.http_get or similar

sub dispatch_http_request {
  my ($method, $path, $vhost) = @_;

  # Priority 1: ACME challenges (Let's Encrypt)
  if ($path =~ m|^/.well-known/acme-challenge/(.+)$|) {
    return acme.http.challenge_handler($1);
  }

  # Priority 2: API endpoints
  if ($path =~ m|^/api/(.+)$|) {
    return letsencrypt.http.api_handler($1);
  }

  # Priority 3: Dynamic template content
  if (template_exists($vhost, $path)) {
    return web.process-template-ipc($vhost, $path);
  }

  # Priority 4: Static files
  return serve_static($vhost, $path);
}
```

### Template Resolution Hierarchy
```
Priority 1: /var/httpd/{vhost}/{path}/_templates/ (most specific)
Priority 2: /var/httpd/{vhost}/_templates/        (vhost level)
Priority 3: /var/httpd/_global_templates/         (fallback)
```

### Vhost Directory Structure
```
/var/httpd/127.0.0.1/
├── index.html.template          (uses templates from _templates/)
├── _templates/                  (priority 2)
│   ├── header.html.template
│   ├── footer.html.template
│   └── ...
├── _skins/                      (nested skin layers)
│   ├── style.css
│   └── dark/
│       └── style.css (overrides)
├── _menu/                       (menu generation)
├── blog/
│   ├── index.html.template      (uses parent templates)
│   ├── _templates/              (priority 1 - overrides parent)
│   └── 2025-11-14-post.html.template
└── static/
    ├── style.css                (static files)
    └── script.js
```

---

## 📊 Token Efficiency Strategy

**How to maximize the 34 tokens:**

1. **Don't Redo Completed Work**
   - HTTPSD is done ✓
   - Web zenka is done ✓
   - ACME integration is done ✓
   - Just verify they still work (quick tests only)

2. **Focus on Critical Path**
   - Recover base.parser.pattern_split (MUST HAVE)
   - Implement route dispatcher (connects everything)
   - Integrate vhost/skin/menu (adds functionality)
   - Quick integration tests (verify it works)

3. **Reuse Existing Code**
   - web.process_template_recursive already complete
   - web.process-template-ipc already complete
   - httpd.http_get exists, just extend it
   - ACME handlers already working

4. **Skip for Future Sessions**
   - Advanced async I/O optimization
   - Full test suite and benchmarking
   - Performance tuning and caching optimization
   - Production hardening and security features

---

## 🚀 Getting Started (First 30 Minutes)

```bash
# 1. Source bootstrap script (1 min)
source ~/.session-bootstrap.sh

# 2. Verify system state (2 min)
bash /home/user/protocol-7/bin/dev/verify-session-state.sh

# 3. Read context files (20 min)
cat /home/user/ACTIVE_SESSION_CHECKPOINT.md
cat /home/user/protocol-7/data/yaml/coding-tasks/next-session-httpsd-web-zenka-completion.yaml

# 4. Begin Phase 1 (5 min)
cd /home/user/protocol-7
./bin/Protocol-7 -export-inline-subs base.parser.pattern_split > /tmp/pattern_split.pl

# 5. You're ready to go! 🚀
```

---

## 📝 Commits You'll Create

Expected git commits by session end:

```
recovery: Extract and integrate base.parser.pattern_split
feat: Implement HTTP route dispatcher for dynamic content
feat: Add vhost template resolver with 3-level hierarchy
feat: Implement nested skin system with user preferences
feat: Add automatic menu generation from filesystem
docs: Add web-zenka implementation guide
docs: Create session status and handoff documentation
```

---

## 🎓 Key Technical Concepts to Remember

### Two-Level Template Expansion (From Template Auth Session)
- **Parse-time**: config files get templates expanded (already done in template auth)
- **Runtime**: web content gets templates expanded via web.process_template_recursive (already done)

### Route Dispatcher Pattern
- Match incoming HTTP request path to handler
- Use base.parser.pattern_split for flexible pattern matching
- Route to correct processor (ACME, API, template, static)
- Cache results for performance

### Template Hierarchy
- Allows overrides at multiple levels
- Vhost-specific > Global default
- Clean separation of concerns
- Minimal git diffs when changing content

### Skin & Menu System
- Skins: CSS-level personalization (dark mode, mobile, etc.)
- Menu: Auto-generated from filesystem structure
- Both use template system for rendering

---

## ⚠️ Known Limitations & Future Work

**What WON'T be done this session** (for future sessions):

- Advanced async I/O optimization
- Full stress testing and benchmarking
- Multi-domain management
- WAF/DDoS protection
- Advanced monitoring and alerting
- Production deployment hardening
- Full test suite

**Estimated time for these**: 8-10 weeks with dedicated resources

---

## 📞 If You Get Stuck

**Critical Questions to Ask:**

1. **Is base.parser.pattern_split recovered?**
   - If NO: That's why everything else is blocked. Get this first.
   - If YES: Move to phase 2.

2. **Is httpd.http_get being extended correctly?**
   - Test with sample request: `curl http://127.0.0.1/test`
   - Check logs for routing decision
   - Verify correct handler called

3. **Are templates being processed?**
   - Check: `curl http://127.0.0.1/index.html`
   - Should show rendered template with variables expanded
   - If plain text, template processor not being called

4. **Are skins/menus appearing?**
   - Check HTTP response headers for skin cookie
   - Verify menu HTML in response
   - Check for caching headers (Cache-Control, ETag)

---

## 🎉 Session Success Checklist

- [ ] base.parser.pattern_split recovered and tested
- [ ] HTTP route dispatcher routing requests correctly
- [ ] Dynamic templates rendering with variables expanded
- [ ] Multiple skins/themes working with user preferences
- [ ] Navigation menu auto-generated from filesystem
- [ ] HTTPS/certs auto-updating without errors
- [ ] End-to-end test: Create template file, access via browser, see rendered content
- [ ] Comprehensive documentation for next session created
- [ ] All commits pushed to GitHub
- [ ] Handoff document completed and ready for next session

---

## 💾 Session Knowledge Preserved

What WILL be documented by session end:

- ✅ base.parser.pattern_split implementation
- ✅ HTTP route dispatcher architecture
- ✅ Vhost/template resolver integration
- ✅ Skin system implementation
- ✅ Menu generation system
- ✅ End-to-end testing procedures
- ✅ HTTPS auto-update verification
- ✅ What still needs to be done

This ensures zero knowledge loss for future sessions.

---

## 🔗 All Related Files

**Architecture & Design:**
- `/home/user/protocol-7/docs/architecture/NEW_ZENKA_ARCHITECTURE.md`
- `/home/user/protocol-7/docs/architecture/VHOST_TEMPLATE_HIERARCHY.md`

**Task Definitions:**
- `/home/user/protocol-7/data/yaml/coding-tasks/next-session-httpsd-web-zenka-completion.yaml` ← **START HERE**
- `/home/user/protocol-7/data/yaml/coding-tasks/httpd-async-https-expansion.yaml`
- Other ACME phases: `letsencrypt-*.yaml` (reference only, don't touch)

**Configuration:**
- `/home/user/protocol-7/cfg/zenki/httpsd/start`
- `/home/user/protocol-7/cfg/zenki/web/start`

**Modules (Already Complete):**
- `src/web.process_template_recursive`
- `src/web.process-template-ipc`
- `src/letsencrypt.parent.*` (ACME handlers)

**Session Checkpoints:**
- `/home/user/ACTIVE_SESSION_CHECKPOINT.md`
- `/home/user/STARTUP_EFFICIENCY_GUIDE.md`

---

## 🎯 Final Notes

**This is achievable in ~34 tokens** because:

1. All the heavy lifting is already done (HTTPSD, Web zenka, ACME)
2. You're connecting existing pieces, not building from scratch
3. The architecture is fully designed
4. Focus is on critical path only (no nice-to-haves)

**The bottleneck** is recovering `base.parser.pattern_split`. Once you have that, everything else flows naturally because:
- Route matching becomes possible
- HTTP handler can dispatch to correct processor
- Templates can render dynamically
- Dynamic websites become reality

**This is the critical path to get essential web functionality operational behind auto-updating HTTPS setup.**

---

**Status**: ✅ Ready for next session
**All commits pushed**: ✅ Yes (to GitHub)
**Documentation complete**: ✅ Yes
**Token budget optimized**: ✅ Yes (34 tokens for 4 phases)

**You got this! 🚀**

#,,.,,...,..,,.,,,,,,,..,,..,,.,,,,,.,,..,.,.,..,,...,..,,...,.,,,,.,,,,.,,..,
#J4ECXIHZQILG236ZPZGFGYPNRH6RHVS4V7K3DGTX5B5B2U6WT57OYHLUQZS7QRCLG66QAETPTDNO2
#\\\|EXZI6YELEY447LMGHYU27YBUEENQUGOTX4HH7CYERVE6C5DIPLU \ / AMOS7 \ YOURUM ::
#\[7]TSYRGCJOEMT4QJHD3OOQXK2BITDCQ4VMEP7UM4OVHHBSP5QVGQAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
