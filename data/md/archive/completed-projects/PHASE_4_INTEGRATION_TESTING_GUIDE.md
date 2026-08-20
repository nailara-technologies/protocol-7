# Phase 4: Integration Testing & Documentation Guide

**Status**: Ready for testing  
**Completion Target**: Full end-to-end content delivery pipeline  
**Token Efficiency**: Caching and verification focused  

---

## Overview

Phases 1-3 have created:
- ✅ **Phase 2**: Intelligent HTTP routing via `httpd.route_dispatcher`
- ✅ **Phase 2**: Static file handler `httpd.serve_static`
- ✅ **Phase 3**: Nested skin system `web.skin_resolver`
- ✅ **Phase 3**: Menu generation `web.menu_generator`
- ✅ **Phase 3**: Skin management command `web.cmd.skin`

Phase 4 focuses on **verification and integration** of all components.

---

## Phase 4 Tasks

### Task 1: End-to-End Template Processing Test

**Objective**: Verify complete pipeline from HTTP request to rendered response

**Setup**:
```bash
# Create test vhost
mkdir -p /var/httpd/test.local/{_templates,blog,shop}

# Create test templates
cat > /var/httpd/test.local/index.html.tmpl << 'TMPL'
<html>
  <head><title><{page.title}></title></head>
  <body>
    <h1>Welcome to <{site.name}></h1>
    <p>Time: <[web:current-timestamp]></p>
    <p>Skin: <[web:current-skin]></p>
    <nav><[web:render-menu]></nav>
  </body>
</html>
TMPL

# Create blog index
cat > /var/httpd/test.local/blog/index.html.tmpl << 'TMPL'
<html>
  <body>
    <h2>Blog Posts</h2>
    <!-- List blog posts here -->
  </body>
</html>
TMPL
```

**Test**:
```bash
# Test via Protocol-7
./bin/Protocol-7 test route-dispatcher GET /index.html test.local

# Expected output:
# handler: httpd.process_template
# template_path: /var/httpd/test.local/index.html.tmpl
```

**Verification Points**:
- [ ] Route dispatcher correctly identifies template
- [ ] Template processor receives correct path
- [ ] Web zenka recursive processing works
- [ ] Final HTML rendered correctly
- [ ] Caching TTL applied

---

### Task 2: Route Dispatcher Testing

**Test Cases**:

1. **ACME Challenge Route**
   ```
   GET /.well-known/acme-challenge/abc123
   → handler: httpd.handler.acme_request
   → token: abc123
   ```

2. **API Endpoint Route**
   ```
   GET /api/certificate-status
   → handler: letsencrypt.http.api_handler
   → endpoint: certificate-status
   ```

3. **Template Route**
   ```
   GET /blog/post.html
   → Resolve template via httpd.vhost_template_resolver
   → handler: httpd.process_template
   → template_path: (resolved path)
   ```

4. **Static File Route**
   ```
   GET /style.css
   → handler: httpd.serve_static
   → path: /style.css
   ```

**Test Implementation**:
```bash
cd /home/user/protocol-7
./bin/Protocol-7 test route-dispatcher GET <path> <vhost> <session_id>
```

---

### Task 3: Skin Resolution Testing

**Test Cases**:

1. **Default Skin**
   ```
   Skin resolver with no preferences
   → device: desktop
   → cascade: [default]
   → resolved: default
   ```

2. **User-Selected Dark Skin**
   ```
   user_prefs = { skin => 'dark' }
   → cascade: [dark, default]
   → resolved: dark
   ```

3. **Mobile Detection**
   ```
   user_agent = "Mozilla/5.0 (iPhone ...)"
   → device: mobile
   → cascade: [mobile, dark, default]
   → resolved: mobile (or dark if mobile doesn't exist)
   ```

4. **Dark Mode by Time**
   ```
   current_hour >= 20 or current_hour < 8
   → cascade includes 'dark'
   ```

**Test Command**:
```bash
./bin/Protocol-7 cmd web skin resolve test.local skin=dark
./bin/Protocol-7 cmd web skin list test.local
./bin/Protocol-7 cmd web skin info test.local dark
```

---

### Task 4: Menu Generation Testing

**Setup**:
```bash
mkdir -p /var/httpd/test.local/{blog,shop,about}
touch /var/httpd/test.local/blog/index.html
touch /var/httpd/test.local/shop/index.html
touch /var/httpd/test.local/about/index.html

# Add menu metadata
cat > /var/httpd/test.local/blog/menu.yaml << 'YAML'
label: "Blog"
icon: "book"
order: 1
YAML
```

**Test**:
```bash
./bin/Protocol-7 cmd web menu list test.local

# Expected: Menu items for Home, Blog, Shop, About
```

**Verification Points**:
- [ ] Directories detected correctly
- [ ] Menu items created with proper labels
- [ ] Custom metadata loaded
- [ ] Sorting by order works
- [ ] Icons preserved

---

### Task 5: HTTPS/ACME Verification

**Objective**: Verify HTTPS certificate auto-update still works

**Test**:
```bash
# Check if HTTPSD running with TLS
netstat -tlnp | grep :443

# Verify certificate symlinks
ls -la /etc/letsencrypt/live/test.local/

# Test ACME challenge routing
curl -v http://test.local/.well-known/acme-challenge/test123
```

**Verification Points**:
- [ ] HTTPSD listening on 443
- [ ] Certificates installed properly
- [ ] ACME challenge routing works
- [ ] Certificate auto-renewal functional

---

### Task 6: Integration Test Checklist

| Component | Test | Expected | Status |
|-----------|------|----------|--------|
| route_dispatcher | ACME route | httpd.handler.acme_request | [ ] |
| route_dispatcher | API route | letsencrypt.http.api_handler | [ ] |
| route_dispatcher | Template route | httpd.process_template | [ ] |
| route_dispatcher | Static route | httpd.serve_static | [ ] |
| vhost_template_resolver | Level 1 priority | Subdir-specific | [ ] |
| vhost_template_resolver | Level 2 priority | Vhost root | [ ] |
| vhost_template_resolver | Level 3 priority | Global default | [ ] |
| web.process_template | Recursive parsing | Nested commands | [ ] |
| web.skin_resolver | User preference | Selected skin | [ ] |
| web.skin_resolver | Mobile detection | Mobile skin | [ ] |
| web.skin_resolver | Dark mode | Dark cascade | [ ] |
| web.menu_generator | Auto-scan | Dirs → items | [ ] |
| web.menu_generator | Metadata | menu.yaml load | [ ] |
| httpd.serve_static | Small files | Direct serve | [ ] |
| httpd.serve_static | Large files | Download init | [ ] |

---

## Documentation Deliverables

### 1. Architecture Diagram
- HTTP request flow through dispatcher
- Route decision tree
- Handler invocation pattern
- Template processing pipeline

### 2. API Reference
- `route_dispatcher(method, path, vhost, session_id)` returns
- `skin_resolver(vhost, user_prefs, user_agent)` returns
- `menu_generator(vhost, context, base_path)` returns
- `vhost_template_resolver(vhost, path)` returns

### 3. Integration Guide
- Setup instructions
- Configuration examples
- Troubleshooting guide
- Performance tuning

### 4. Example Site
- Sample vhost structure
- Template examples
- Skin customization
- Menu configuration

---

## Success Criteria for Phase 4

✅ **All Route Tests Pass**
- [ ] ACME challenges routed correctly
- [ ] API endpoints routed correctly
- [ ] Templates resolved and processed
- [ ] Static files served correctly

✅ **Skin System Verified**
- [ ] Default skin resolves
- [ ] User preferences respected
- [ ] Mobile detection works
- [ ] Dark mode cascades correctly

✅ **Menu System Verified**
- [ ] Auto-generation from directories
- [ ] Metadata loading works
- [ ] Sorting by order works
- [ ] Caching functional

✅ **Template Pipeline Verified**
- [ ] Templates found via resolver
- [ ] Recursive processing works
- [ ] Web zenka integration works
- [ ] Final HTML correct

✅ **HTTPS Verified**
- [ ] HTTPSD running with TLS
- [ ] ACME challenges working
- [ ] Certificates valid

✅ **Documentation Complete**
- [ ] Architecture documented
- [ ] API reference complete
- [ ] Integration guide written
- [ ] Examples provided

---

## Next Session Preparation

### For Token Efficiency

1. **Read Files First** (before making changes):
   - This Phase 4 guide
   - Git commit history (git log -20)
   - Protocol-7 workflow overview

2. **Checkpoint Before Starting**:
   ```bash
   ./bin/Protocol-7 workflow overview -v
   git status
   ```

3. **After Phase 4 Testing**:
   - Document any issues found
   - Create test report
   - Update architecture docs
   - Prepare final handoff

### Files to Review
- `PHASE_4_INTEGRATION_TESTING_GUIDE.md` (this file)
- `src/httpd.route_dispatcher`
- `src/httpd.http_get`
- `src/web.skin_resolver`
- `src/web.menu_generator`

### Quick Reference
```bash
# View all commits since Phase 2
git log --oneline --since="2025-11-14" | head -10

# Check which modules were created
git diff --name-only HEAD~5 HEAD

# View specific module
cat src/httpd.route_dispatcher

# Run workflow overview
./bin/Protocol-7 workflow overview -v
```

---

## Token Budget for Phase 4

- Context loading: ~500 tokens (reading files, understanding state)
- Test case development: ~1000 tokens
- Bug fixes (if needed): ~500 tokens  
- Documentation: ~500 tokens
- Final commit: ~200 tokens

**Total Phase 4 budget: ~2700 tokens** (estimated)

---

## Related Documentation

- `next-session-httpsd-web-zenka-completion.yaml` - Original Phase 2-4 definition
- `PROTOCOL7_TRANSFER_WORKFLOW.md` - How to transfer work between repos
- `documentation/CHECKPOINT_ENCRYPTION.md` - Context persistence
- `data/yaml/coding-tasks/recursive-template-parsing-phase9.yaml` - Web zenka details

#,,..,,,,,,,,,,..,.,,,..,,,,.,,,,,,..,,,.,,,.,..,,...,...,.,.,,..,,.,,..,,,,.,
#RSC2EXCZG2XJ2EJRQBGRQRZ2QMC5MEFWDRRTDYGHCG32UWJD3NXG3ASD2SEYSKATT376JGFC2UIM2
#\\\|Y43MBVSKUCQJS5IQQOG257ISEPVF7I43SNJW6EN7TYOQCTPLPFT \ / AMOS7 \ YOURUM ::
#\[7]73OCJ5GFDOQTUYHEE4BNV2QIDTJLL6GCAUONYQKAEL6RSNXHAWCQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
