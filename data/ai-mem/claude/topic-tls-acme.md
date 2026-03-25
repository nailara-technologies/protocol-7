---
name: TLS/ACME internals
description: SNI callback mechanics, SSL chain sending, ACME letsencr child architecture, cert discovery
type: project
---

## SNI callback (httpsd.create_ssl_socket)

- registered via `Net::SSLeay::CTX_set_tlsext_servername_callback` after socket creation
- IO::Socket::SSL `SSL_cert_callback` has version-dependent behaviour — avoided
- callback calls `httpsd.callback.ssl_cert_select` for per-domain cert/key paths
- **must use `use_certificate_chain_file`** (not `use_certificate_file`) — latter only loads leaf cert
- `use_PrivateKey_file` with `FILETYPE_PEM()` for key

## SSL context access

- `${*$ssl_socket}{'_SSL_ctx'}` → object with field name varying by IO::Socket::SSL version:
  `'context'` (newer), `'ssl_ctx'` (mid), `'ctx'` (older) — code tries all three
- `SSL_reuse_ctx` accepts IO::Socket::SSL instance directly — don't reach into internals

## letsencr child architecture

- parent loads `letsencr.base.*` modules; child forked via `letsencr.base.fork_letsencr_child`
- after fork, child deletes `access.cmd.usr.cube` + `access.cmd.usr.child`, keeps `parent` entries
- parent deletes `access.cmd.usr.parent` — so parent list IS the child's command set
- child loads `letsencr.child.*` via prefix-based `load_runtime_modules('letsencr.child')`
- shared modules (letsencr.x509_field, letsencr.der_to_pem, etc.) NOT covered by prefix loading —
  must be loaded individually in child init_code; gen-sub-whitelist doesn't recognize these

## native crypto libraries (no more openssl subprocess)

- **Crypt::OpenSSL::X509**: `new_from_file`, `new_from_string(pem, FORMAT_PEM)`, `subject()`,
  `issuer()`, `key_alg_name()`, `bit_length()`, `extensions_by_name()` (hashref with AIA key)
- **CryptX / Crypt::PK::RSA**: `key2hash` for modulus/exponent extraction (N, e fields as hex)
- **CryptX / Crypt::PK::Ed25519**: `generate_key`, `export_key_pem('private')`
- **Crypt::Misc**: `der_to_pem($der, 'CERTIFICATE')` — one-liner DER→PEM conversion
- **Net::SSLeay**: X509 cert creation API (X509_new, set_version, NAME_add_entry_by_txt,
  X509_sign with digest=0 for Ed25519), PEM_get_string_X509, BIO read/write

## cert chain repair

- `letsencr.child.cmd.repair-chain`: validates chain via `letsencr.child.validate_chain`,
  fetches correct intermediate via AIA if mismatch, rewrites .pem + .chain files
- runs in child (non-blocking AIA HTTP fetch)
- "chain already valid" means .pem file is correct — if curl still fails, it's a sending issue

#,,.,,..,,,,.,,,.,..,,...,,..,,.,,.,.,,.,,..,,..,,...,...,...,.,.,,..,..,,...,
#HRPBKHDSOXULEC2Z6M5Y7QZB3P75PUE4N54QPGN46LFE5WVRVOGYRKWRBEBHFMP7IIEAHZ5SFZIOI
#\\\|572UZOD55PHAECIO2OCK7ACYU2OGQ4TFXZ2I73KJ44OXVNYYGDP \ / AMOS7 \ YOURUM ::
#\[7]KBRK4SQUUGJYTSPM77YNRCB3HMP4BE2HGL5JC7OL72Q4VCJUWGBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
