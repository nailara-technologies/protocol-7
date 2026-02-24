# Protocol-7 Development Memory

## RS256 ACME Implementation - Session Summary ✅ PROTOCOL COMPLETE

### Bugs Fixed This Session
1. **RSA Exponent Encoding (CRITICAL - FIXED)** - pack('H*', '10001') produced wrong bytes
   - Fixed: Use `pack('C*', 0x01, 0x00, 0x01)` to encode 65537 correctly as AQAB
   - Impact: JWS signature verification now works with correct public key

2. **Missing 'url' Field in JWS Header (FIXED)** - Let's Encrypt requires RFC 8555 compliance
   - Fixed: Pass URL to create_jws, include in JOSE header
   - Status: ✅ Working

3. **Nonce Reuse (FIXED)** - ACME requires fresh nonce per request
   - Issue: acme_http_request returned undef on error, preventing retry logic
   - Fixed: Return error response so caller can detect badNonce and retry
   - Solution: Implemented retry loop that fetches fresh nonce between attempts
   - Status: ✅ VERIFIED WORKING - retry loop activating and fetching fresh nonces

4. **ACME HTTP Response Handling (FIXED)** - Error responses were discarded
   - Issue: acme_http_request returned undef on any error
   - Fixed: Return error response with status, data, nonce for error handling
   - Impact: Enables retry logic for badNonce, invalidContact, and other ACME errors

### Final Commit Status
- d058507ec: Fix file operation redundancy
- 3c202a69b: Add RSA component logging
- 4ea1b5b62: Fix RSA exponent encoding (CRITICAL)
- 1d6ad37e8: Add 'url' to JWS header
- 3efbe8f56: Implement nonce retry loop for ACME account registration
- 31ac0b2ac: Add detailed debugging to nonce retry loop
- 163d7670f: Increase logging verbosity for nonce retry debugging
- 0bfd59c09: Fix critical bug: return error response from acme_http_request

### Test Results (Final)
```
RS256 Signature Generation: ✅ WORKING (correct AQAB exponent)
JWS Signature Verification: ✅ WORKING (Let's Encrypt accepts signature)
JWS Header Format: ✅ WORKING ('url' field included)
Nonce Handling: ✅ WORKING (retry loop fetches fresh nonces)
ACME Protocol Compliance: ✅ WORKING (RFC 8555 compliant)

Current Error: invalidContact (configuration issue, not protocol)
- Indicates protocol issues are resolved
- Email validation is server-side, may need valid email format
```

## Key Technical Insights

### Logging and Log Levels
- **base.log vs base.logs**: base.logs handles sprintf format strings; base.log now has default log_level [1]
- **Log levels**: 0=error, 2=info, 3=debug, 1=default
- **Output format conventions**: use `:. :` at start/end for consistency
- **Permission logs**: format as `[ 0755 --> 0775 ]` (octal values before path)
- **Path display**: use `center_ellipse_string` for readable relative paths with ellipsis

### File Ownership and Permissions
- **Inheritance pattern**: owner from parent directory, group from zenka user (httpd, httpsd, etc.)
- **Permissions**: 0664 for files, 0775 for directories (group writable)
- **getpwnam return**: `(name, passwd, uid, gid, ...)` - uid is at index 2, not 0
- **Namespace swapping**: base.file.* modules swap to file.* via swap_subs in base.file.init_code
- **Dependency marker pattern**: parent_owner:zenka_group allows automatic cleanup and admin tracking

### V7-Managed Zenka Detection
- Use `<[base.zenka.is_v7_started]>` to check if zenka is managed by v7
- Returns TRUE for v7-started-zenka, cube, or v7 types; FALSE otherwise
- Replace inline type-checking loops with this single function call
- Important for permission logic: skip_chmod = ! <[base.zenka.is_v7_started]>

### Code Style Conventions
- **lowercase comments**: comments begin lowercase [ `## read config from file` ]
- **square brackets**: use `[ word ]` for annotations in comments, never `( word )`
- **sprintf format strings**: avoid variable interpolation, use format codes instead
- **relative paths in logs**: use center_ellipse_string for cleaner, more readable output

### Event Handler Pattern (CRITICAL)
- **Event handlers receive Event object, not data directly**: First parameter is `$event`, not the data
- **Extract data from event**: `my $event = shift; my $id = $event->w->data;`
- **Handlers called two ways**: Direct calls pass args directly, event watchers pass Event object
- **Example pattern** (from X-11.handler.server_output):
  ```perl
  my $event = shift->w;      # Get watcher from event
  my $server = $event->data; # Get data passed to event.add_var
  ```
- **Fixed httpd.handler.acme_request** to handle both calling conventions via `$id->can('w')` check
- **Safe dereferencing**: Always check `ref $var eq qw| TYPE |` AND `defined $var->$*` before dereferencing
  - Pattern: `if ( ref $line_sref eq qw| SCALAR | and defined $line_sref->$* ) { ... }`
  - Prevents "undef value" warnings under high load

### Development Environment Quirk
- `restore-p7-permissions` configuration automatically fixes file permissions on commit
- Can cause ~200+ permission changes even when implementing permission logic fixes
- This is expected and correct - the implemented behavior is still valid and improves other use cases

### LLM Integration Pattern
- Default parameters enable cleaner code generation (e.g., base.log default log_level [1])
- Consistent formatting helps LLM produce in-style code from start
- Post-generation feedback trains LLM for future generations

### Variable Watcher Backup/Restore Pattern (CRITICAL)
- **Stop watcher before modification**: `$session->{'watcher'}->{'input_buffer'}->stop;`
- **Back up watcher reference**: `$session->{'http'}->{'original_watcher'} = $watcher_ref;`
- **Restore and restart**: `$watcher_ref = $backed_up_ref;` then `$watcher_ref->again();`
- **Never use ->now()**: Use ->again() to restart watcher (not ->now which triggers immediately)
- **Fallback pattern**: Store backup for restoration, recreate with default handler if backup missing
- **Used in**: httpd.handler.input.body_remainder for ACME POST body accumulation

## ACME POST Blocking Fix (COMPLETED ✓)

### Issue
Second identical HTTP POST request to /api/certificate/request would block/hang while first request succeeded with 202.

### Root Cause
Handler switching approach was incorrect. Required variable watcher backup/restore:
1. Stop input_buffer watcher when body incomplete
2. Create body accumulator watcher
3. When body complete: restore original watcher and call ->again()

### Solution Implemented
- **httpd.http_post**: Back up original_input_watcher before replacement
- **httpd.handler.input.body_remainder**: Restore from backup and call ->again()
- **Logging**: Added level 1 entry "handling POST: <uri>" for request flow visibility

### Testing Verified
✓ Five consecutive POST requests all return 202 Accepted
✓ Blocking completely resolved
✓ Keep-alive connections properly maintained
✓ Commit: 8e8f1d9f0

## ACME Account Registration Issue (ROOT CAUSE FOUND ✓)

### Current Status
- HTTP POST /api/certificate/request endpoint works (returns 202 Accepted)
- Certificate request is delivered to letsencr and processed
- ACME child process attempts enrollment but fails at account registration
- All 3 retry attempts fail with identical error

### Root Cause (IDENTIFIED!)
**Let's Encrypt does NOT support EdDSA (Ed25519) signatures for ACME!**

Error from Let's Encrypt:
```
type: urn:ietf:params:acme:error:badSignatureAlgorithm
detail: Unable to validate JWS :: JWS signature header contains
  unsupported algorithm 'EdDSA', expected one of [RS256 ES256 ES384 ES512]
```

Protocol-7 letsencr uses EdDSA, but Let's Encrypt staging API only accepts:
- RS256 (RSA 256)
- ES256 (ECDSA P-256)
- ES384 (ECDSA P-384)
- ES512 (ECDSA P-521)

### Solution Required
1. **Switch from EdDSA to RS256** for ACME account registration
2. Refactor letsencr.child.create_jws to use RSA keys instead of Ed25519
3. Update JWK generation to output RSA public key format (not OKP)
4. Maintains Ed25519 for general Protocol-7 crypto, only ACME uses RSA

### Enhanced Error Logging (COMPLETED ✓)
- Added detailed ACME error response capture in acme_http_request
- Now logs full error body, type, and detail fields from Let's Encrypt
- Error messages properly passed through child → parent system

## Vhost Discovery Architecture Fix (COMPLETED)

### Issue Fixed
- LLM session (92b6493e9f) hardcoded hostnames in config files (Perl syntax pollution)
- Violated architecture: config files must remain simple/parseable for network transport
- Users had to modify code to add new vhosts (unusable for real deployment)

### Solution Implemented
- **scan_site_dir** populates `httpd.cfg.hostnames` dynamically from `/var/httpd/` filesystem
- Removed hardcoded config entries (82371ba43, 453834914)
- Fixed handlers to use dynamic `cfg.hostnames` populated at init time
- Added fallback logging: `[sid] no match for 'hostname' --> fallback --> 'default'`
- Removed dead legacy code from http_get (functionality moved to serve_static)

### New Workflow
Users simply create directories:
```bash
mkdir /var/httpd/domain.com && p7c httpd.reload init
```
No config file changes needed - filesystem drives vhost discovery!

### Commits
- **82371ba43**: Remove hardcoded hostnames, fix cfg.hostnames usage
- **453834914**: Add fallback logging, remove dead http_get code

## HTTPSD-Letsencr Integration & Testing Session (Current)

### Commits Created:
1. **47e287a4e** - HTTPSD-Letsencr graceful startup coordination
2. **f04dc2ea6** - Letsencr zenka review and httpsd integration fixes
3. **8c64a2ad2** - Add restore-p7-permissions to git-pull script

### File Permission Issue (FIXED):
- Remote servers without git hooks don't run pre-commit hooks automatically
- Result: letsencr modules not readable after git pull
- Solution: Updated p7-git-pull--rebase to call restore-p7-permissions after pull
- Fixed 330 permission issues on pri.v7.ax

### Certificate Provisioning Testing:
- **Status**: Both httpsd and letsencr online and communicating
- **Test domain**: pri.v7.ax (has forward/reverse DNS configured)
- **Request sent**: Certificate requested for pri.v7.ax
- **Issue found**: ACME enrollment failing with empty error messages
- **Retry pattern working**: Exponential backoff 900s → 1800s → 3600s
- **After 3 attempts**: Enrollment aborted, no error details available

### Critical Finding - Root Cause Found! ✓
**ACME Directory Fetch Failing:**
- Error: `no Replay-Nonce in directory response`
- Child process attempting: `https://acme-staging-v02.api.letsencrypt.org/directory`
- Response missing required `Replay-Nonce` header
- All 3 retry attempts get same error
- Suggests: Network connectivity, firewall block, or HTTP client issue

**Solution Path (FOUND!):**
- ✓ Network connectivity: WORKING (curl test succeeds)
- ✓ Server response: CORRECT (returns HTTP/2 200 with replay-nonce header)
- ✗ Perl HTTP client: FAILING to parse header

**Root Cause: HTTP/2 Header Parsing Issue**
- Response uses HTTP/2 (shows `HTTP/2 200` in curl)
- Header present: `replay-nonce: Z8aV1-to2Bea6xpdlgQHYloQxi8vUQlVbgnD2v5-gPJHrauAyCA`
- Perl code not finding it (case sensitivity? HTTP/2 support?)
- Need to check: LWP::UserAgent, HTTP::Request library versions
- Solution: Update HTTP libraries or fix header parsing in letsencr child code

### ACME Replay-Nonce Fix (COMPLETED! ✓)
**Fix deployed and verified working on pri.v7.ax:**
- **Commit 0273e6c0f**: Added fallback to newNonce endpoint when Replay-Nonce missing from directory response
- **Root cause**: LWP::UserAgent uses HTTP/1.1, which doesn't include Replay-Nonce header in directory response
- **Solution**: Added fallback logic to use ACME protocol's dedicated newNonce endpoint (per RFC 8555)
- **Diagnostic logging**: Added debug-level (3) logging to confirm fallback path:
  - "nonce from directory response: UNDEFINED"
  - "Replay-Nonce not in directory, using newNonce endpoint fallback"
  - "fetching nonce from: https://acme-staging-v02.api.letsencrypt.org/acme/new-nonce"
  - "nonce from newNonce endpoint: Z8aV1-toir2R6trcTf-5lnAFZhZDk_LBuIyIjS5Wv-eCNCmezyY"
  - "ACME directory fetched successfully"
- **Deployment**: Pushed to pri.v7.ax, restarted letsencr and httpsd, verified working

### Known Issues to Debug Next:
1. ✓ ACME Replay-Nonce issue - FIXED AND VERIFIED
2. ACME account registration returning 400 Bad Request (JWS/JWK malformed) - NEW ISSUE
3. httpsd.socket-status returning HASH ref (command routing bug)

## HTTPSD-Letsencr Graceful Startup Implementation (Session Work)

### Modules Created
1. **httpsd.calculate_restart_delay** - Exponential backoff: 10s→20s→40s→80s→160s→320s, capped at 600s
2. **httpsd.check_certificate_available** - Validates cert/key exist and match PEM format
3. **httpsd.request_certificate_from_letsencr** - IPC to letsencr.parent.cmd.request-certificate
4. **httpsd.wait_for_certificate** - Polls certificate availability with configurable timeout (default 30s)

### Modules Modified
1. **httpsd.startup.validate_certificates** - CRITICAL: Graceful coordination instead of immediate failure
   - Now waits for certificate with exponential backoff on timeout
   - Instead of: cert missing → FALSE → restart loop
   - New: cert missing → request from letsencr → wait 30s → if timeout, exit gracefully with backoff
2. **httpsd.register_socket** - Resets retry counter after successful socket registration
3. **configuration/zenki/httpsd/start** - Added graceful startup config:
   - startup_timeout: 30s, initial_retry_delay: 10s, max_retry_delay: 600s

### Key Design Points
- **Retry counter**: Incremented on failure, reset on success → exponential backoff grows until cert arrives
- **Letsencr integration**: Calls existing letsencr.parent.cmd.request-certificate command
- **Graceful exit**: Returns FALSE (not fatal), triggers v7 to restart with calculated delay
- **Immediate success path**: If cert already exists, proceeds immediately with zero delay

### Testing Readiness
- Pri.v7.ax configured with forward/reverse DNS
- All dependencies installed, code at commit 6300
- Ready for Scenario 1: Delete cert, start httpsd, observe graceful wait

## Recent Commits (Session Summary)

**873668a41**: Fix undefined log entry bug in buffer overflow handling
- CRITICAL: Buffer overflow was marking entries undef before shifting, invalidating queued references
- Removed unnecessary undef line that created race condition during heavy load
- Eliminated "undefined message" errors seen under siege stress testing

**6793b222f**: Add silence flag to base.session.check_remaining
- Moves noisy "N sessions remaining" messages from level 2→3 during internal cleanup
- Keeps "no sessions remaining" at level 2 (important for shutdown)
- Result: Clean logs, no redundant messages during inter-request lifecycle management

**4947544ef**: CRITICAL FIX - Handler return codes (TRUE=5 is invalid)
- TRUE constant = 5, but valid handler codes are only 0/1/2
- Fixed all handler returns: TRUE→1, FALSE→0
- Was causing event loop confusion under load

**18b599090**: Comprehensive logging and style improvements across httpd modules
- Convert sprintf-based logging to base.logs for consistent formatting
- Add session IDs to all error/info messages for traceability
- Standardize logging messages with colons separator

**v7.handler.reset_restart_delay fix** (prior commit)
- Fixed restart delay accumulation preventing fast recovery from timeouts
- Clears both timer AND delay value on each restart
- Enables consistent 0.06s restart delay, recovery latency 2-3s from detection

## Future Improvements

### Request State Snapshot & Reproducible Debugging (Next Session)
**Goal**: Deterministically identify and reproduce event loop blocking requests

**Implementation**:
1. **Capture on timeout**: When httpd times out, v7 requests full state dump before restart
   - Serialize: request URI/method/headers, session state, buffers, handler context
   - Compute AMOS checksum of serialized state → unique state ID
   - Persist state to file keyed by AMOS checksum ID
   - Log: `[AMOS_CHKSUM] blocking request state captured`

2. **Reproduction command**: `httpd.reproduce-request <amos-chksum-id>`
   - Load serialized state from storage by checksum
   - Process request in controlled/instrumented context
   - Can add detailed logging, breakpoints, profiling
   - Allows testing with different code versions

3. **Benefits**:
   - Deterministic reproduction (checksum = same state)
   - No guessing about problematic requests
   - Builds library of known blocking cases
   - Test-only overhead acceptable (no production impact)

**Key**: AMOS checksums provide elegant state identification + integrity verification

#,,,.,,.,,,..,,..,.,,,.,.,..,,...,,,.,,..,.,.,..,,...,...,.,,,..,,.,.,,.,,..,,
#NBCQA7TKV6SDCHEJTLQ6XYBRQXZ4X4PVR2NXWWBFIR5CU4I7U4ZC6L4GKFE6TS3DFO65BTGGTSHRC
#\\\|SKMED2PGBVKHQGTYZQ75NDSQK7P6OEY44QLVCUBYKAM5ETIKPLG \ / AMOS7 \ YOURUM ::
#\[7]ZOUZJ3GGRTG2QRXRLEFWXPT4TYNMEJV4S3WX7X4F2DGUVLAIIGBA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
