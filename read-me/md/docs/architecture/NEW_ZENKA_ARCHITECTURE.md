# New Zenka Architecture: HTTPS, Template Parsing, and Let's Encrypt
**Version**: 1.0
**Date**: 2025-11-07
**Status**: Architecture & Planning Phase
**Objective**: Extend httpd zenka with HTTPS support, dynamic template rendering, and automated certificate management

---

## Overview

Three new specialized zenka are required to cleanly separate concerns from the core HTTP server:

1. **`httpsd`** (HTTPS Server Zenka) - TLS/SSL encrypted connections
2. **`template`** (Template Engine Zenka) - Dynamic HTML/content rendering
3. **`letsencrypt`** (Certificate Manager Zenka) - Automated certificate provisioning and renewal

This architecture maintains Protocol-7's philosophy of **single-responsibility zenka** that communicate through the cube message router.

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                    Cube (Message Router)                        │
└────┬────────────────────────────┬────────────────┬──────────────┘
     │                            │                │
     │                            │                │
┌────▼────────────┐    ┌─────────▼──────────┐   ┌───▼──────────────┐
│     httpd       │    │    httpsd          │   │    template      │
│  (HTTP Server)  │    │ (HTTPS Server)     │   │ (Template Engine)│
│                 │    │                    │   │                  │
│ • HTTP/1.1      │    │ • TLS/SSL wrapper  │   │ • HTML rendering │
│ • File transfer │    │ • Certificate mgmt │   │ • Variable inject │
│ • Ranges        │    │ • Port 443         │   │ • Caching layer  │
│ • Async I/O     │    │ • Passthrough to   │   │ • Format support │
│ • Port 80       │    │   httpd for logic  │   │  (Mustache, etc) │
│                 │    │ • HSTS headers     │   │                  │
└─────────────────┘    └────────────────────┘   └──────────────────┘
                              │
                              │ Routes HTTPS to httpd
                              │
                       ┌──────▼──────────────┐
                       │  letsencrypt       │
                       │  (Cert Manager)    │
                       │                    │
                       │ • Challenge mgmt   │
                       │ • Renewal pipeline │
                       │ • ACME protocol    │
                       │ • Key storage      │
                       │ • Expiry tracking  │
                       │                    │
                       └────────────────────┘
```

---

## Detailed Specifications

### 1. HTTPSD Zenka (HTTPS Server)

#### Purpose
Provide TLS/SSL encrypted HTTP/1.1 connections while delegating application logic to existing httpd zenka.

#### Configuration
```
Location: cfg/zenki/httpsd/zenka.v7

httpsd.cfg.tls_version       = "TLSv1.2"      # Minimum version
httpsd.cfg.cipher_suite      = "modern"       # Mozilla modern ciphers
httpsd.cfg.hsts_max_age      = 31536000       # 1 year
httpsd.cfg.hsts_include_subdomains = 1
httpsd.cfg.certificate_path  = "/etc/protocol-7/certs/current.pem"
httpsd.cfg.key_path          = "/etc/protocol-7/certs/current.key"
httpsd.cfg.dhparams_path     = "/etc/protocol-7/certs/dhparams.pem"

net.https.addr = 0:0:0:0:0:0:0:0
net.https.port = 443

# Delegate request handling to httpd
httpsd.upstream = httpd
```

#### Core Modules

**httpsd.init_code**
- Initialize TLS/OpenSSL context
- Load certificate and key files
- Validate certificate expiration
- Set up cipher suite
- Create secure socket listener

**httpsd.tls_handshake**
- Handle TLS handshake protocol
- Manage session resumption
- Track cipher negotiation
- Update connection metadata

**httpsd.tls_send_data**
- Encrypt data before sending
- Handle partial writes
- Manage send buffers
- Track encryption metrics

**httpsd.tls_recv_data**
- Decrypt incoming data
- Handle partial reads
- Parse encrypted payloads
- Update receive metrics

**httpsd.request_passthrough**
- Convert encrypted request to plain HTTP
- Forward to httpd zenka via cube
- Receive response from httpd
- Encrypt response back to client

**httpsd.hsts_headers**
- Add Strict-Transport-Security header
- Include includeSubDomains directive
- Set appropriate max-age
- Preload list submission (optional)

**httpsd.certificate_validator**
- Validate certificate against key
- Check certificate expiration
- Verify certificate chain
- Log certificate details

**httpsd.cipher_suite_manager**
- Manage TLS version negotiation
- Handle cipher preferences
- Support SNI (Server Name Indication)
- ALPN protocol selection (for HTTP/2 future)

#### Module Dependencies
- `io.ip` - TCP socket operations
- `crypt.C25519` - Cryptographic functions
- `httpsd.tls_*` - TLS protocol handlers
- Messages to: `httpd` (via cube)

#### Design Patterns

**Upstream Delegation Pattern**
```perl
# In httpsd.request_passthrough
my $response = <[cube.send_command]>('httpd', {
    method  => $request->{method},
    path    => $request->{path},
    headers => $request->{headers},
    body    => $request->{body},
});

# Encrypt response
my $encrypted = <[httpsd.tls_send_data]>($session, $response);
return $encrypted;
```

**Certificate Hot-Reload**
```perl
# In httpsd.certificate_validator
# Can reload without restarting on cert update from letsencrypt
if (-M $cert_file < -M $current_cert_cache) {
    <[httpsd.init_code]>();  # Reinitialize with new cert
}
```

---

### 2. Template Zenka (Template Engine)

#### Purpose
Provide dynamic content rendering with support for multiple templating engines while maintaining performance through intelligent caching.

#### Configuration
```
Location: cfg/zenki/template/zenka.v7

template.cfg.engine          = "mustache"     # or "handlebars", "ejs"
template.cfg.cache_enabled   = 1
template.cfg.cache_ttl       = 3600           # 1 hour
template.cfg.template_dir    = "/var/protocol-7/templates"
template.cfg.max_cache_size  = 104857600      # 100MB
template.cfg.safe_mode       = 1              # Disable dangerous operations

# Mustache-specific
template.cfg.mustache.partials_dir = "/var/protocol-7/templates/partials"
template.cfg.mustache.lambdas_enabled = 0

# Performance
template.cfg.precompile_on_load = 1
template.cfg.parallel_renders = 8
```

#### Core Modules

**template.init_code**
- Initialize template engine
- Load template directory structure
- Compile templates (if supported)
- Set up cache infrastructure
- Configure security policies

**template.load_template**
- Fetch template from filesystem or cache
- Validate template syntax
- Track cache hits/misses
- Return compiled template object

**template.render_template**
- Execute template with provided context
- Inject variables and functions
- Handle partials/includes
- Manage nested rendering
- Apply escaping rules

**template.cache.get**
- Query template cache
- Return cached compiled template
- Track cache hit
- Check expiration

**template.cache.set**
- Store compiled template
- Set TTL
- Manage cache eviction
- Log cache operation

**template.cache.invalidate**
- Remove template from cache
- Handle cascading invalidation (partials)
- Notify dependent templates
- Log invalidation reason

**template.context_sanitizer**
- Sanitize context variables
- Apply escaping (HTML, URL, etc.)
- Validate data types
- Prevent injection attacks

**template.error_handler**
- Catch template errors
- Generate error messages
- Return fallback content
- Log error details

**template.profiler**
- Track render times
- Measure cache performance
- Identify slow templates
- Generate performance reports

#### Module Dependencies
- `base.string.*` - String manipulation
- `base.file.*` - File I/O operations
- Template language libraries (Mustache.pm, etc.)
- `httpd.get_mime_type` - Content type detection

#### Design Patterns

**Lazy Cache Loading**
```perl
# In template.load_template
my $cached = <[template.cache.get]>($template_name);
return $cached if $cached;

my $template = load_from_filesystem($template_name);
my $compiled = compile_template($template);
<[template.cache.set]>($template_name, $compiled);
return $compiled;
```

**Cascading Partial Invalidation**
```perl
# In template.cache.invalidate
sub invalidate_cascade {
    my $template_name = shift;
    <[template.cache.invalidate]>($template_name);

    # Find templates that include this one
    my @dependents = find_template_dependencies($template_name);
    foreach my $dep (@dependents) {
        invalidate_cascade($dep);  # Recursive
    }
}
```

---

### 3. Let's Encrypt Zenka (Certificate Manager)

#### Purpose
Automate ACME certificate provisioning, renewal, and storage with minimal manual intervention.

#### Configuration
```
Location: cfg/zenki/letsencrypt/zenka.v7

letsencrypt.cfg.enabled              = 1
letsencrypt.cfg.environment          = "production"  # or "staging"
letsencrypt.cfg.email                = "admin@example.com"
letsencrypt.cfg.domains              = "example.com www.example.com"
letsencrypt.cfg.renewal_check_interval = 86400  # Daily

letsencrypt.cfg.acme_server          = "https://acme-v02.api.letsencrypt.org/directory"
letsencrypt.cfg.challenge_type       = "http-01"      # or "dns-01"
letsencrypt.cfg.challenge_port       = 80             # Must be accessible

letsencrypt.cfg.cert_dir             = "/etc/protocol-7/certs"
letsencrypt.cfg.key_dir              = "/etc/protocol-7/keys"
letsencrypt.cfg.account_key_path     = "/etc/protocol-7/letsencrypt/account.key"

letsencrypt.cfg.auto_renewal_enabled = 1
letsencrypt.cfg.renewal_threshold    = 2592000   # 30 days before expiry

# Notifications
letsencrypt.cfg.notify_renewal_start  = 1
letsencrypt.cfg.notify_renewal_complete = 1
letsencrypt.cfg.notify_renewal_failure = 1
```

#### Core Modules

**letsencrypt.init_code**
- Initialize ACME client
- Load or create account key
- Validate configuration
- Schedule renewal checks
- Set up logging

**letsencrypt.challenge_http_01**
- Create challenge file
- Place in web root
- Wait for validation
- Clean up challenge file
- Handle validation timeout

**letsencrypt.challenge_dns_01**
- Generate DNS challenge record
- Interface with DNS provider API
- Wait for DNS propagation
- Verify challenge resolution
- Clean up DNS record

**letsencrypt.request_certificate**
- Create certificate signing request (CSR)
- Submit to ACME server
- Handle challenge responses
- Poll for completion
- Download certificate chain

**letsencrypt.renewal_check**
- Check expiration dates
- Determine certificates needing renewal
- Schedule renewal tasks
- Track renewal attempts
- Report on renewal status

**letsencrypt.renewal_pipeline**
- Coordinate full renewal process
- Request new certificate
- Validate certificate
- Install to httpsd locations
- Reload httpsd with new cert
- Clean up old certificates

**letsencrypt.key_management**
- Generate RSA/ECDSA keys
- Store keys securely
- Rotate old keys
- Maintain key backups
- Track key usage

**letsencrypt.certificate_validator**
- Validate certificate structure
- Verify certificate chain
- Check certificate dates
- Validate domain coverage
- Report on certificate status

**letsencrypt.notification_handler**
- Send email notifications
- Log important events
- Track notification history
- Handle notification failures
- Support webhook callbacks

**letsencrypt.acme_client**
- Implement ACME protocol
- Handle HTTP requests
- Manage account interaction
- Track request/response
- Implement retry logic

#### Module Dependencies
- `io.ip` - HTTP requests for ACME
- `crypt.C25519` - Key generation
- `base.time.*` - Expiration tracking
- `base.file.*` - Certificate storage
- HTTP client library (LWP, Net::HTTPS, etc.)
- Messages to: `httpsd` (via cube)

#### Design Patterns

**Renewal Pipeline with Rollback**
```perl
# In letsencrypt.renewal_pipeline
sub renewal_pipeline {
    my $domain = shift;

    # Step 1: Request new certificate
    my $new_cert = <[letsencrypt.request_certificate]>($domain);
    return error() unless $new_cert;

    # Step 2: Validate before installing
    my $valid = <[letsencrypt.certificate_validator]>($new_cert);
    return error() unless $valid;

    # Step 3: Backup old certificate
    backup_current_certificate($domain);

    # Step 4: Install new certificate
    install_certificate($new_cert);

    # Step 5: Signal httpsd to reload
    my $reload_result = <[cube.send_command]>('httpsd', {
        action => 'reload_certificates'
    });

    # Step 6: Validate reload succeeded
    unless ($reload_result->{success}) {
        restore_from_backup($domain);
        <[cube.send_command]>('httpsd', { action => 'reload_certificates' });
        return error("Reload failed, rolled back");
    }

    return success();
}
```

**Automatic Renewal Scheduling**
```perl
# In letsencrypt.renewal_check
my $expiry_date = parse_cert_expiry($cert_path);
my $days_until_expiry = ($expiry_date - time()) / 86400;

if ($days_until_expiry < $threshold) {
    my $renewal_time = $expiry_date - (90 * 86400);  # Renew at ~30 days
    schedule_task({
        time => $renewal_time,
        action => 'renewal_pipeline',
        domain => $domain
    });
}
```

---

## Integration with Existing Systems

### Communication Pattern (via Cube)

```
Client 1 (HTTPS) ──┐
                   ├──> httpsd ──┐
Client 2 (HTTPS) ──┤            ├──> Cube ──┬──> httpd (delegates logic)
Client 3 (HTTP) ───┤            │          │
                   ├──> httpd ──┤          ├──> template (renders content)
                   │            │          │
                   │            └──────────┴──> letsencrypt (manages certs)
                   │
                Client Library (HTTP)
```

### Cube Message Examples

**HTTPS Request Flow**
```
1. httpsd receives HTTPS connection
2. httpsd decrypts request
3. httpsd sends to httpd:
   {
     source: 'httpsd',
     action: 'handle_request',
     method: 'GET',
     path: '/api/data',
     headers: {...},
     is_secure: 1
   }
4. httpd processes request
5. httpd may send to template:
   {
     source: 'httpd',
     action: 'render',
     template: 'api_response',
     context: {...}
   }
6. template returns rendered content
7. httpd sends response back
8. httpsd encrypts and sends to client
```

**Certificate Renewal Workflow**
```
1. letsencrypt.renewal_check runs periodically
2. Detects certificate expiring in 30 days
3. Calls letsencrypt.renewal_pipeline
4. Submits ACME challenge (http-01 or dns-01)
5. httpd may serve challenge file via special route
6. ACME server validates
7. letsencrypt receives new certificate
8. Sends to httpsd:
   {
     source: 'letsencrypt',
     action: 'install_certificate',
     cert_path: '/etc/protocol-7/certs/current.pem',
     key_path: '/etc/protocol-7/certs/current.key'
   }
9. httpsd reloads and confirms
10. letsencrypt confirms success
```

---

## File Structure

### Directory Layout
```
src/
  ├── httpsd.init_code
  ├── httpsd.tls_handshake
  ├── httpsd.tls_send_data
  ├── httpsd.tls_recv_data
  ├── httpsd.request_passthrough
  ├── httpsd.hsts_headers
  ├── httpsd.certificate_validator
  ├── httpsd.cipher_suite_manager
  ├── template.init_code
  ├── template.load_template
  ├── template.render_template
  ├── template.cache.get
  ├── template.cache.set
  ├── template.cache.invalidate
  ├── template.context_sanitizer
  ├── template.error_handler
  ├── template.profiler
  ├── letsencrypt.init_code
  ├── letsencrypt.challenge_http_01
  ├── letsencrypt.challenge_dns_01
  ├── letsencrypt.request_certificate
  ├── letsencrypt.renewal_check
  ├── letsencrypt.renewal_pipeline
  ├── letsencrypt.key_management
  ├── letsencrypt.certificate_validator
  ├── letsencrypt.notification_handler
  └── letsencrypt.acme_client

cfg/zenki/
  ├── httpsd/
  │   ├── start
  │   ├── start.cfg
  │   ├── access.zenki
  │   ├── source/
  │   └── pm-dep/
  ├── template/
  │   ├── start
  │   ├── start.cfg
  │   ├── access.zenki
  │   ├── source/
  │   └── pm-dep/
  └── letsencrypt/
      ├── start
      ├── start.cfg
      ├── access.zenki
      ├── source/
      └── pm-dep/

docs/
  ├── architecture/NEW_ZENKA_ARCHITECTURE.md (this file)
  ├── api/
  │   ├── httpsd-api.md
  │   ├── template-api.md
  │   └── letsencrypt-api.md
  └── guides/
      ├── httpsd-deployment.md
      ├── template-usage.md
      └── letsencrypt-setup.md
```

---

## Dependencies & External Libraries

### HTTPSD Zenka
- **IO::Socket::SSL** or **Net::SSLeay** - TLS/SSL handling
- **Crypt::OpenSSL::X509** - Certificate parsing
- **Crypt::OpenSSL::RSA** - Key operations
- **Mozilla::CA** - Root certificate store
- Internal: `io.ip`, `crypt.C25519`

### Template Zenka
- **Template** (Template Toolkit) or **Text::Xslate** - Template engines
- **HTML::Escape** or **JSON::Escape** - Output escaping
- **Digest::MD5** or **Digest::SHA** - Cache key generation
- Internal: `base.string.*`, `base.file.*`, `httpd.get_mime_type`

### Let's Encrypt Zenka
- **JSON::PP** or **JSON::XS** - JSON encoding/decoding
- **LWP::UserAgent** or **Net::HTTPS** - HTTP client
- **Digest::SHA** - ACME signature generation
- **Crypt::OpenSSL::RSA** - Account key operations
- **DateTime** or **Time::Local** - Expiration date handling
- Internal: `crypt.C25519`, `base.file.*`, `base.time.*`

---

## Implementation Phases

### Phase 1: HTTPSD Zenka (2-3 weeks)
1. Create httpsd configuration and startup
2. Implement TLS handshake and protocol
3. Build request passthrough mechanism
4. Add HSTS header support
5. Implement certificate hot-reload
6. Test with curl, nginx, etc.

### Phase 2: Template Zenka (2-3 weeks)
1. Create template configuration and startup
2. Implement template loading
3. Build Mustache/Template Toolkit integration
4. Create caching layer
5. Add context sanitization
6. Implement profiling and metrics
7. Test with HTML, JSON, XML templates

### Phase 3: Let's Encrypt Zenka (3-4 weeks)
1. Create letsencrypt configuration and startup
2. Implement ACME client library
3. Build HTTP-01 challenge handling
4. Implement certificate request pipeline
5. Create renewal scheduler
6. Add notification system
7. Implement key management
8. Test with Let's Encrypt staging/production

### Phase 4: Integration & Testing (1-2 weeks)
1. End-to-end HTTPS to template rendering flow
2. Automatic certificate renewal
3. Performance testing (concurrent connections, template rendering)
4. Security testing (TLS versions, cipher suites)
5. Failure scenarios (cert expiry, renewal failure, etc.)

---

## Performance Considerations

### HTTPSD
- **TLS Handshake Optimization**: Session resumption, session tickets
- **Memory Usage**: Connection pooling, buffer management
- **CPU Usage**: Hardware acceleration (OpenSSL AES-NI), cipher suite selection
- **Throughput**: Keep-alive connections, pipelining

### Template
- **Caching Strategy**: LRU cache with TTL, cascade invalidation
- **Compilation**: Pre-compile on load, lazy compilation
- **Memory**: Streaming rendering for large templates
- **CPU**: Parallel rendering up to configured concurrency

### Let's Encrypt
- **Challenge Timeout**: Configurable with exponential backoff
- **Renewal Scheduling**: Off-peak hours, staggered for multiple domains
- **Credential Storage**: Encrypted key storage, regular backups
- **Rate Limiting**: Respect Let's Encrypt rate limits (50/week per domain)

---

## Security Considerations

### HTTPSD
- TLSv1.2+ only (no SSLv3, TLSv1.0, TLSv1.1)
- Modern cipher suites only
- HSTS preload support
- Certificate pinning (optional)
- TLS session resumption validation

### Template
- HTML escaping by default
- URL encoding for links
- JavaScript escaping for inline scripts
- SQL escaping for database contexts
- Input validation before rendering
- Sandbox unsafe template operations

### Let's Encrypt
- Account key stored with restricted permissions
- Certificate and key encrypted at rest
- Secure challenge validation
- Rate limiting on renewal attempts
- Notification on unusual activity
- Audit logging of all certificate operations

---

## Monitoring & Observability

### Metrics to Track
- **HTTPSD**: TLS handshake success rate, cipher suite usage, connection duration
- **Template**: Render time, cache hit rate, memory usage, error count
- **Let's Encrypt**: Renewal attempts, success rate, cert expiry timeline, challenge pass rate

### Logging
- TLS protocol errors and warnings
- Template compilation errors
- Certificate renewal status and errors
- ACME challenge results

### Alerts
- Certificate expiry in < 7 days
- Renewal failure
- Unusual TLS errors
- Template rendering errors > threshold
- Challenge validation failures

---

## Future Enhancements

1. **HTTP/2 Support**: Implement h2 protocol in httpsd
2. **HTTP/3 (QUIC)**: Modern protocol with connection migration
3. **Advanced Template Engines**: Handlebars, EJS, Liquid
4. **DNS-01 Challenge**: Multi-domain automation (wildcard certs)
5. **OCSP Stapling**: Better certificate status verification
6. **Template Component Library**: Reusable template components
7. **Certificate Transparency**: Log to CT systems
8. **Multi-Domain Management**: SAN certificates, wildcard handling

---

## Reference Documentation

- [RFC 8446 - TLS 1.3](https://tools.ietf.org/html/rfc8446)
- [RFC 8555 - ACME](https://tools.ietf.org/html/rfc8555)
- [OWASP Template Injection](https://owasp.org/www-community/Server-Side_Template_Injection)
- [Mozilla SSL Configuration Generator](https://ssl-config.mozilla.org/)
- [Mustache Template Specification](https://mustache.github.io/)

---

**Status**: Ready for Phase 1 Implementation
**Next Action**: Begin HTTPSD Zenka development
**Contact**: Protocol-7 Development Team

```

#,,,,,...,...,..,,,,.,,,.,,,,,...,,.,,...,,,,,...,...,...,,,,,.,.,,..,,.,,...,
#5DDE7ROM4GBNWUXX23JO26JMG6BRSQ6MX4PVHFE2OGTIRFOHNS34NK5JOB4GB6746ZN26IUW6OSFU
#\\\|254WRUG2OWETO4GTLOXBGBZPXA7R2GGCCRYBWZ3CCX4XWAV3WEX \ / AMOS7 \ YOURUM ::
#\[7]2TVOL5HZFTVBH4MAZZOHVMG5V7K7YZXPVZSCMTTSZEWBB3SJTABQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
