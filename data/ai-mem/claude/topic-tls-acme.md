# TLS / SSL / ACME Details

## SNI / IO::Socket::SSL Internals (CONFIRMED ON ATOM)
- **SSL_cert_callback**: unreliable across versions — on some it overrides SSL_cert_file
  and returning `()` does NOT restore default cert → bad_certificate TLS alert
- **SSL_cert => \%hash**: not supported in older IO::Socket::SSL → "passed a null parameter"
  OpenSSL error at socket creation
- **Correct SNI approach**: use `Net::SSLeay::CTX_set_tlsext_servername_callback` directly
  after socket creation
- **SSL_CTX field access**: `${*$ssl_socket}{'_SSL_ctx'}` is the SSL_Context object;
  raw Net::SSLeay ctx lives at key `context` (newer), `ssl_ctx` (mid), or `ctx` (older) — try all
- **Per-connection cert loading**: use `Net::SSLeay::use_certificate_file($ssl, $cert, FILETYPE_PEM)`
  and `use_PrivateKey_file($ssl, $key, FILETYPE_PEM)` (SSL object not CTX — thread-safe)
- **SNI callback**: `CTX_set_tlsext_servername_callback($ctx, sub { my $ssl = shift;
  my $hostname = Net::SSLeay::get_servername($ssl); ... return 1; })`
- **bad_certificate (TLS alert 42)**: staging CA not trusted, cert/domain mismatch,
  Ed25519 cert with incompatible client; log at level 1 not 0

## SSL Server Socket Behavior
- Server socket session fires connect handler TWICE per connection (level-triggered epoll)
- First fire: accept() succeeds → creates client session
- Second fire: accept() returns EAGAIN → return silently
- Fix: `return undef if $!{EAGAIN} or $!{EWOULDBLOCK}` in io.ip.ssl.input.connect
- `client session shutdown` (error 0A000126): client closed before TLS handshake → level 2 (expected)

## httpsd.discover_active_certificate
- Prefer .pem files (leaf + intermediate chain) over .cert (leaf only)
- Without intermediate, curl gets "unable to get local issuer certificate"
- letsencr.parent.save_certificate writes both: `$domain.cert` and `$domain.pem`

## Certificate Discovery & Directory Setup (COMPLETED ✅)
- `httpsd.discover_active_certificate` scans `/etc/protocol-7/certs/` for latest cert
- Automatic directory creation during init with permissions letsencr:httpsd (0775)
- Filesystem drives discovery entirely — configuration-free
- Key commits: 68f2cef1b, bf76cdf13, a022b33e0, 6300dfed7, 2a66d3847, 824815976

## ACME Certificate Download & Enrollment (COMPLETED ✅)
- ACME certificate endpoint (RFC 8555) returns raw PEM chain, NOT JSON
- Let's Encrypt returns: end-entity + intermediates + root
- Parent expects: `certificate` (first cert) + `chain` (rest) + `expires_at`
- Child transmits bundle to parent via base32r encoding (SIZE mode response)
- Field names matter: `certificate` (not `cert`), `expires_at` (not `valid_until`)
- Key commits: 09c04374d (dedicated download handler), 80f4f6a99 (field names + PEM chain)

## RS256 ACME (COMPLETED ✅ — Let's Encrypt rejects EdDSA)
- Let's Encrypt ACME requires: RS256, ES256, ES384, or ES512 (NOT EdDSA)
- RSA exponent encoding: `pack('C*', 0x01, 0x00, 0x01)` for 65537 (NOT `pack('H*', '10001')`)
- JWS header must include `url` field (RFC 8555)
- Nonce: LWP::UserAgent uses HTTP/1.1 so Replay-Nonce missing from directory response
  → fallback to ACME `newNonce` endpoint (commit 0273e6c0f, verified on pri.v7.ax)
- Retry loop for badNonce: fetch fresh nonce between attempts
- Key commits: 4ea1b5b62, 1d6ad37e8, 3efbe8f56, 0bfd59c09, 0273e6c0f

## ACME POST Blocking Fix (COMPLETED ✅)
- Issue: second POST to /api/certificate/request would hang
- Root cause: handler switching needed variable watcher backup/restore
- Fix: httpd.http_post backs up original_input_watcher; body_remainder restores with ->again()
- Commit: 8e8f1d9f0 (five consecutive POSTs all return 202 Accepted)

## HTTPSD-Letsencr Graceful Startup (COMPLETED ✅)
- `httpsd.calculate_restart_delay`: exponential backoff 10s→20s→40s→80s→160s→320s (cap 600s)
- `httpsd.check_certificate_available`: validates cert/key exist and match PEM format
- `httpsd.startup.validate_certificates`: cert missing → request from letsencr → wait 30s → graceful exit
- Retry counter incremented on failure, reset on success (growing backoff until cert arrives)

#,,,,,..,,.,.,,.,,,,.,,..,,.,,..,,,,.,,..,,.,,..,,...,...,,,,,,..,,.,,.,,,..,,
#2QQQCUZWDAV5652666QPYIXZUNXK3Q6QKE2GXLANDVUXVMC7D4SHIWFVCOMIYAPDUGXGL2FJ5VWRG
#\\\|NPYHAVAYEYWCRTTJH6TDRGXY6ZRGNLKAL2JTT6YKL3LLKGBVY7V \ / AMOS7 \ YOURUM ::
#\[7]M2S25W3HKZLGC777CDOMRLH53JEXXSYRS7RG7U2VKOR25N6ODODQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
