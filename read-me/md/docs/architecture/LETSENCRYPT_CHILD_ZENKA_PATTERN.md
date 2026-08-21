# Let's Encrypt Zenka: Child Zenka Pattern
**Version**: 1.0
**Date**: 2025-11-07
**Based On**: weather.base.fork_weather_child pattern
**Status**: Architecture & Planning

---

## Overview

The weather zenka demonstrates an elegant pattern for handling blocking I/O operations without freezing the main zenka:

1. **Parent Process** - Manages state, caching, commands
2. **Child Process** - Handles blocking operations (API calls)
3. **IPC** - Unix socket pairs for parent-child communication
4. **Event-Driven** - Non-blocking events in event system

This pattern is **perfect for Let's Encrypt operations** because certificate renewal involves blocking HTTP requests to ACME servers.

---

## Weather Zenka Pattern (Reference)

### Structure

```
PARENT PROCESS (main)
  ├─ Initialize: [weather.base.fork_weather_child]
  │  └─ Forks child, creates socketpair, loads weather.parent modules
  ├─ Commands: weather.parent.cmd.*
  │  └─ Query cache, send requests to child
  ├─ Caching: weather.parent.cache.*
  │  └─ Read/write cached weather data
  └─ I/O Handler: base.handler.command
     └─ Receives child responses

CHILD PROCESS (forked)
  ├─ Initialize: weather.child.init_code
  │  └─ Loads weather.child modules
  ├─ API Calls: weather.child.query_api
  │  └─ Makes HTTP request to OpenWeatherMap
  ├─ Commands: weather.child.cmd.*
  │  └─ request-data, get-station-id
  └─ I/O Handler: base.handler.command
     └─ Sends results back to parent
```

### Key Components

**Parent (weather.parent.*)**
- Commands: temp, desc, clouds, humid, location, station-id
- Caching: read_cache_data, write_data, write_station_id
- Data extraction: extract_current, extract_forecast
- Handler: base.handler.command (processes child responses)

**Child (weather.child.*)**
- Init: Loads JSON parser, HTTP client (LWPx::ParanoidAgent)
- Commands: request-data, get-station-id
- API: query_api (makes HTTP request to OpenWeatherMap)
- Returns JSON responses back to parent

**Communication**
- Parent → Child: Command messages via IPC pipe
- Child → Parent: Response messages via IPC pipe
- Parent handles responses in: base.handler.command

---

## Adapted: Let's Encrypt Zenka Pattern

### Module Structure

```
PARENT: letsencrypt.parent.*
├─ letsencrypt.parent.init_code        # Load parent modules
├─ letsencrypt.parent.renewal_check    # Check cert expiry
├─ letsencrypt.parent.cache.*
│  ├─ read_renewal_status
│  ├─ read_cert_metadata
│  └─ write_renewal_log
├─ letsencrypt.parent.cmd.*
│  ├─ start-renewal
│  ├─ status
│  ├─ validate-cert
│  └─ list-certificates
└─ letsencrypt.parent.handler.*
   └─ renewal_response_handler

CHILD: letsencrypt.child.*
├─ letsencrypt.child.init_code         # Load HTTP client, crypto libs
├─ letsencrypt.child.acme.*
│  ├─ get_directory
│  ├─ register_account
│  ├─ create_order
│  └─ finalize_order
├─ letsencrypt.child.challenge.*
│  ├─ http_01_handler
│  ├─ dns_01_handler
│  └─ validate_challenge
├─ letsencrypt.child.cmd.*
│  ├─ request-renewal
│  ├─ perform-challenge
│  └─ install-cert
└─ letsencrypt.child.send_response

SHARED BASE: letsencrypt.base.*
├─ letsencrypt.base.fork_child         # Fork child process
├─ letsencrypt.base.init_code          # Base initialization
└─ letsencrypt.base.config
```

---

## Implementation Flow

### Renewal Initialization

```
1. Parent starts: [letsencrypt.base.fork_child]
   └─ Creates socketpair
   └─ Forks child process
   └─ Loads letsencrypt.parent modules

2. Child starts: <[base.load_modules]>->('letsencrypt.child')
   └─ Loads LWP::UserAgent
   └─ Loads Crypt::OpenSSL::RSA
   └─ Loads JSON parser

3. Parent schedules renewal check
   └─ Every 24 hours: [letsencrypt.parent.renewal_check]
```

### Renewal Request Flow

```
PARENT PROCESS                          CHILD PROCESS
──────────────────────────────────────  ──────────────────────────────

1. [renewal_check]
   ├─ Check cert expiry
   ├─ < 30 days to expiry?
   └─ Send: {action: 'request-renewal',
             domain: 'example.com'}
                                         2. Receives message
                                            [command handler]
                                            ├─ Call [child.cmd.request-renewal]
                                            ├─ HTTP: GET ACME directory
                                            ├─ HTTP: POST new order
                                            └─ Send challenge to parent

3. Receive challenge result
   ├─ Validate challenge
   └─ Send: {action: 'perform-challenge',
             token: 'xxx',
             validation: 'yyy'}
                                         4. Receives challenge
                                            ├─ HTTP: POST challenge proof
                                            ├─ Poll ACME for status
                                            └─ HTTP: Finalize order
                                            └─ Send: {action: 'install-cert',
                                                     cert: 'pem',
                                                     key: 'pem'}

5. Receive certificate
   ├─ Validate cert
   ├─ Write to disk
   ├─ Update httpsd config
   └─ Signal httpsd to reload
```

### Code Pattern Comparison

#### Weather Pattern
```perl
# weather/start
[weather.base.fork_weather_child]
modules.load = auth net protocol io.unix io.ip weather.base
[load_modules:<modules.load>]
[init_modules]

# weather.base.fork_weather_child
<weather.child.pid> = <[base.fork]>;
if ( !<weather.child.pid> ) {  # CHILD
    <[base.load_modules]>->('weather.child');
    <[base.init_modules]>->('weather.child');
} else {  # PARENT
    <[base.load_modules]>->('weather.parent');
    <[base.init_modules]>->('weather.parent');
}
```

#### Let's Encrypt Pattern (Adapted)
```perl
# letsencrypt/start
[letsencrypt.base.fork_child]
modules.load = auth net protocol io.unix io.ip letsencrypt.base
[load_modules:<modules.load>]
[init_modules]

# letsencrypt.base.fork_child
<letsencrypt.child.pid> = <[base.fork]>;
if ( !<letsencrypt.child.pid> ) {  # CHILD
    <[base.load_modules]>->('letsencrypt.child');
    <[base.init_modules]>->('letsencrypt.child');
} else {  # PARENT
    <[base.load_modules]>->('letsencrypt.parent');
    <[base.init_modules]>->('letsencrypt.parent');
}
```

---

## Module Breakdown

### PARENT Modules (Low I/O Operations)

**letsencrypt.parent.init_code**
- Load base modules
- Initialize cache system
- Schedule renewal checks
- Set up signal handlers

**letsencrypt.parent.renewal_check**
- Read certificates from disk
- Check expiration dates
- Compare against threshold (30 days)
- Request renewal from child if needed
- Update renewal status

**letsencrypt.parent.cache.read_renewal_status**
- Read renewal log from disk
- Parse JSON status
- Return {domain, status, last_attempt, next_attempt}

**letsencrypt.parent.cache.read_cert_metadata**
- Read certificate metadata
- Parse certificate dates
- Extract domains
- Return cert information

**letsencrypt.parent.cache.write_renewal_log**
- Write renewal status to JSON
- Track: domain, status, timestamp, error message
- Rotate old logs

**letsencrypt.parent.cmd.start-renewal**
- User command: trigger renewal
- Validate domain parameter
- Send request to child
- Wait for completion

**letsencrypt.parent.cmd.status**
- Return current renewal status
- List all domains
- Show expiration dates

**letsencrypt.parent.cmd.validate-cert**
- Verify certificate validity
- Check certificate chain
- Validate against private key

**letsencrypt.parent.handler.renewal_response_handler**
- Process responses from child
- Handle success: write cert, signal httpsd
- Handle failure: log error, schedule retry
- Update renewal status cache

### CHILD Modules (Blocking I/O Operations)

**letsencrypt.child.init_code**
- Load LWP::UserAgent
- Load Crypt::OpenSSL::RSA
- Load JSON parser
- Disable cube command verification (not needed in child)

**letsencrypt.child.acme.get_directory**
- HTTP GET to ACME server directory
- Parse response JSON
- Return URLs for account, orders, etc.

**letsencrypt.child.acme.register_account**
- HTTP POST to register account
- Use account key
- Parse and store account URL

**letsencrypt.child.acme.create_order**
- HTTP POST to create order
- Request cert for domain(s)
- Parse authorization URLs

**letsencrypt.child.acme.finalize_order**
- HTTP POST CSR
- Poll for certificate ready
- HTTP POST to finalize
- Download certificate

**letsencrypt.child.challenge.http_01_handler**
- Receive challenge from parent
- Write validation file to HTTP server
- Return file path/content
- Parent verifies file exists

**letsencrypt.child.challenge.dns_01_handler**
- Receive challenge from parent
- Call DNS provider API (if configured)
- Return TXT record value
- Parent verifies DNS record

**letsencrypt.child.challenge.validate_challenge**
- Poll ACME server
- Check challenge status
- Return: pending, valid, or invalid

**letsencrypt.child.cmd.request-renewal**
- Main entry point from parent
- Orchestrate: directory → account → order → challenge → finalize
- Return {cert, key, chain} or {error, message}

**letsencrypt.child.send_response**
- Send structured response back to parent
- Format: {status, domain, cert_pem, key_pem, chain_pem, error, message}

---

## Integration with Event System

### Parent Event Scheduling

```perl
# In letsencrypt.parent.init_code
<[base.event.add_recurring]>({
    handler => 'letsencrypt.parent.renewal_check',
    interval => 86400,  # 24 hours
    random_offset => 3600  # +/- 1 hour
});

# In letsencrypt.parent.renewal_check
if ( $days_to_expiry < 30 ) {
    # Schedule immediate renewal
    <[base.event.add_once]>({
        handler => 'letsencrypt.parent.cmd.start-renewal',
        delay => 0,
        args => { domain => $domain }
    });
}
```

### Parent Receives Child Response

```perl
# In base.handler.command (configured for parent)
# Routes responses to:
$data{'session'}{$id}{'input'}{'handler'}
    = 'letsencrypt.parent.handler.renewal_response_handler';
```

---

## Data Flow: Complete Renewal Cycle

```
TIME: 23:59 (nightly check)
┌─────────────────────────────────────────────────────┐
│ Event: [letsencrypt.parent.renewal_check]          │
│ ├─ Read certs from disk                            │
│ ├─ Check: expiry < 30 days?                        │
│ └─ For example.com: YES, expires in 28 days       │
└─────────────────────────────────────────────────────┘

TIME: 00:15 (trigger renewal)
┌─────────────────────────────────────────────────────┐
│ Parent: Send to child via IPC pipe                 │
│ {                                                   │
│   "action": "request-renewal",                     │
│   "domain": "example.com",                         │
│   "challenge_type": "http-01"                      │
│ }                                                   │
└─────────────────────────────────────────────────────┘

TIME: 00:16 (child processes)
┌─────────────────────────────────────────────────────┐
│ Child: [letsencrypt.child.cmd.request-renewal]    │
│ ├─ HTTP: GET acme-v02.api.letsencrypt.org/direc.. │
│ ├─ HTTP: POST /accounts (register)                │
│ ├─ HTTP: POST /orders (new order)                 │
│ ├─ Parse: authorization URLs                      │
│ └─ Send to parent:                                │
│   {                                                │
│     "action": "challenge-needed",                 │
│     "domain": "example.com",                       │
│     "token": "abc123",                            │
│     "auth_url": "https://acme.../authz/..."      │
│   }                                                │
└─────────────────────────────────────────────────────┘

TIME: 00:17 (parent handles challenge)
┌─────────────────────────────────────────────────────┐
│ Parent: [letsencrypt.parent.handler.renewal...]   │
│ ├─ Write validation to /var/httpd/.well-known/..  │
│ ├─ Send to child:                                 │
│   {                                                │
│     "action": "validate-challenge",               │
│     "token": "abc123",                            │
│     "validation": "abc123.xyz789"                 │
│   }                                                │
└─────────────────────────────────────────────────────┘

TIME: 00:18 (child validates & finalizes)
┌─────────────────────────────────────────────────────┐
│ Child: [letsencrypt.child.challenge.validate...]  │
│ ├─ HTTP: POST /challenge/{id} (prove validation)  │
│ ├─ Poll: GET /order/{id} (wait for valid)        │
│ ├─ HTTP: POST /finalize (submit CSR)             │
│ ├─ HTTP: GET /certificate (download cert)        │
│ └─ Send to parent:                                │
│   {                                                │
│     "action": "cert-ready",                       │
│     "cert": "-----BEGIN CERTIFICATE-----...",   │
│     "chain": "-----BEGIN CERTIFICATE-----...",  │
│     "key": "-----BEGIN PRIVATE KEY-----..."      │
│   }                                                │
└─────────────────────────────────────────────────────┘

TIME: 00:19 (parent installs cert)
┌─────────────────────────────────────────────────────┐
│ Parent: Handle cert response                       │
│ ├─ Validate certificate                           │
│ ├─ Write: /etc/protocol-7/certs/current.pem      │
│ ├─ Write: /etc/protocol-7/certs/current.key      │
│ ├─ Update: /etc/protocol-7/certs/chain.pem       │
│ ├─ Send: cube → httpsd (reload-certificates)     │
│ ├─ Update: renewal log (SUCCESS)                 │
│ └─ Log: "Renewed example.com, expires in 90 days"│
└─────────────────────────────────────────────────────┘
```

---

## Advantages of This Pattern

### 1. **Non-Blocking Parent**
- Parent never blocks on network I/O
- Can handle other commands while renewal in progress
- Event system remains responsive

### 2. **Clean Separation**
- Parent: State, caching, commands, events
- Child: Blocking I/O, crypto operations
- Easy to test each independently

### 3. **Fault Isolation**
- Child crash doesn't crash parent
- Can restart child without losing state
- Parent can continue serving cached data

### 4. **Resource Efficiency**
- Child runs only when needed
- Parent uses normal event loop
- Shared libraries (JSON, crypto) in child

### 5. **Easy Error Handling**
- Parent receives responses with status
- Can retry failed operations
- Error logs stored in cache

### 6. **Testability**
- Can test parent without ACME server
- Can test child with mock parent
- Protocol-7 patterns standardized

---

## Cloning from Weather Zenka

### Files to Clone
```
# Configuration
weather/start → letsencrypt/start
weather/start.cfg → letsencrypt/start.cfg
weather/{os-dep,pm-dep,source}/ → letsencrypt/{os-dep,pm-dep,source}/

# Base modules
weather.base.* → letsencrypt.base.*
  (keep: fork_child, init_code, config)
  (remove: calc_zoom_level, tomorrow_unix, check_dirs)
```

### Modules to Keep as Reference
- weather.base.fork_weather_child → template for fork_child
- weather.parent.cache.* → template for letsencrypt.parent.cache.*
- weather.child.init_code → template for letsencrypt.child.init_code

### Modules to Create New
- letsencrypt.parent.* (renewal specific)
- letsencrypt.child.* (ACME operations)
- letsencrypt.parent.handler.renewal_response_handler (custom)

---

## Configuration Changes Needed

### letsencrypt/start (from weather/start)

```perl
# Change
modules.load = auth net protocol io.unix io.ip weather.base
# To
modules.load = auth net protocol io.unix io.ip letsencrypt.base

# Change
[weather.base.fork_weather_child]
# To
[letsencrypt.base.fork_child]

# Add ACME/renewal config
letsencrypt.cfg.acme_server = https://acme-v02.api.letsencrypt.org/directory
letsencrypt.cfg.email = admin@example.com
letsencrypt.cfg.renewal_threshold = 2592000  # 30 days
letsencrypt.cfg.challenge_type = http-01

# Add cache paths
letsencrypt.cache_dir = /var/cache/letsencrypt
letsencrypt.cert_dir = /etc/protocol-7/certs
letsencrypt.key_dir = /etc/protocol-7/keys
```

---

## Event System Integration

### Events to Create

**Daily Renewal Check**
```perl
<[base.event.add_recurring]>({
    handler => 'letsencrypt.parent.renewal_check',
    interval => 86400,  # 24 hours
    random_offset => 3600,  # Randomize start time
    start_delay => 3600  # Start 1 hour after startup
});
```

**Renewal Retry on Failure**
```perl
<[base.event.add_once]>({
    handler => 'letsencrypt.parent.cmd.start-renewal',
    delay => 86400,  # Retry in 24 hours
    args => { domain => $domain, retry => 1 }
});
```

### Events in Event System (New)

We should also create event handlers in an events zenka that can:
1. Subscribe to letsencrypt renewal status
2. Emit notifications on success/failure
3. Trigger httpsd reload on cert update
4. Log to monitoring system

```perl
# In events zenka
<[events.subscribe]>('letsencrypt:renewal-complete',
    'letsencrypt:send-notification');
<[events.subscribe]>('letsencrypt:renewal-failed',
    'letsencrypt:retry-renewal');
<[events.subscribe]>('letsencrypt:cert-installed',
    'httpsd:reload-certificates');
```

---

## Summary: Why This Pattern Works

✅ **Non-blocking**: Parent never waits for ACME servers
✅ **Clean**: Separate parent state from child I/O
✅ **Proven**: Weather zenka uses this pattern successfully
✅ **Scalable**: Multiple domains handled independently
✅ **Resilient**: Child failure doesn't affect parent
✅ **Observable**: Easy to monitor progress via events
✅ **Testable**: Each component testable independently

---

**Next Steps**: Clone weather zenka to create letsencrypt zenka skeleton, then implement ACME modules

#,,,,,,,.,,..,.,,,,.,,.,.,...,.,,,.,.,,,.,,..,..,,...,..,,...,..,,,,,,...,...,
#XZFG7XV266SA3YUQ5UU2X5YOGTO4BOLZKM5HWMPGNWXQCJTDCPI5NWKNUC7CA46ODKICPZYGSRJAW
#\\\|VS7GNNCVYGCNINZMFKNLFWJTQTG6366VZVMRGV23B5NNXCDRJTH \ / AMOS7 \ YOURUM ::
#\[7]CDD22QYJYKC5P7DUVDHFHVOZKCKOZI35GN2A5A4OPGUM7E2IFWCQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
