# ACME Protocol Modules - Quick Reference

**Phase 2 Implementation**: 17 new modules implementing full ACME protocol chain

## Cryptographic Foundation

### `letsencrypt.child.generate_account_key` ✓
**Purpose**: Generate RSA-2048 key for ACME account
**Input**: None
**Output**: `Crypt::OpenSSL::RSA` object
**Stores**: Key to `/var/cache/letsencrypt/account.key` (0600 perms)
**State**: Updates `<letsencrypt.child.acme_client>{account_key}`

### `letsencrypt.child.load_account_key` ✓
**Purpose**: Load existing account key from cache
**Input**: `$key_path` (optional)
**Output**: `Crypt::OpenSSL::RSA` object or undef
**Default Path**: `/var/cache/letsencrypt/account.key`
**State**: Updates `<letsencrypt.child.acme_client>{account_key}`

### `letsencrypt.child.get_jwk` ✓
**Purpose**: Extract public key in JWK format (RFC 7517)
**Input**: None (uses account_key from state)
**Output**: Hashref with `{e, kty, n}`
**Format**: URL-safe Base64 encoded components
**Uses**: For ACME request headers during account creation

### `letsencrypt.child.encode_base64url` ✓
**Purpose**: URL-safe Base64 encoding
**Input**: Binary data
**Output**: URL-safe Base64 string (no padding)
**Notes**: Replaces `+→-`, `/→_`, removes `=`
**Uses**: All ACME payload/signature encoding

## ACME Protocol Communication

### `letsencrypt.child.create_jws` ✓
**Purpose**: Create JSON Web Signature (JWS) for ACME requests
**Input**: `$payload, $nonce, $kid`
**Output**: Hashref with `{protected, payload, signature}`
**Algorithm**: RS256 (RSA with SHA-256)
**Uses**: All authenticated ACME requests

### `letsencrypt.child.acme_http_request` ✓
**Purpose**: Make authenticated HTTP request to ACME server
**Input**: `$method, $url, $payload, $nonce, $kid`
**Methods**: POST (authenticated), GET (public)
**Output**: `{status, data, nonce, headers}`
**Security**: Uses `LWPx::ParanoidAgent` (SSL verification)
**Nonce Extraction**: Reads `Replay-Nonce` header

### `letsencrypt.child.extract_rsa_modulus` ✓
**Purpose**: Extract RSA modulus (n) for JWK
**Input**: `Crypt::OpenSSL::RSA` object
**Output**: Binary representation of modulus
**Uses**: JWK generation for account creation

### `letsencrypt.child.extract_rsa_exponent` ✓
**Purpose**: Extract RSA public exponent (e) for JWK
**Input**: `Crypt::OpenSSL::RSA` object
**Output**: Binary representation (typically 65537 = 0x010001)
**Uses**: JWK generation for account creation

## ACME Directory & Account

### `letsencrypt.child.fetch_acme_directory` ✓
**Purpose**: Fetch ACME directory from Let's Encrypt server
**Input**: `$server_url` (optional, uses config default)
**Output**: `{directory, nonce, endpoints}`
**Endpoints**: newAccount, newOrder, revokeCert, keyChange
**State**: Stores directory and nonce in `<letsencrypt.child.acme_client>`
**Required**: Must run before any ACME operations

### `letsencrypt.child.get_fresh_nonce` ✓
**Purpose**: Get fresh nonce from ACME server
**Input**: None (uses directory from state)
**Output**: Nonce string
**Method**: HEAD request to `newNonce` endpoint
**State**: Updates `<letsencrypt.child.acme_client>{nonce}`
**Required**: Called before each ACME operation

### `letsencrypt.child.acme_register_account` ✓
**Purpose**: Register new ACME account with Let's Encrypt
**Input**: None (uses config email and TOS agreement)
**Output**: `{account_url, account_id, email, created_at}`
**TOS**: Automatically accepted
**Contact**: Includes admin email
**State**: Stores `account_url` as Key ID for future requests
**Cache**: Saves account info to `/var/cache/letsencrypt/account.json`

## Certificate Order

### `letsencrypt.child.acme_create_order` ✓
**Purpose**: Create new certificate order
**Input**: `$domains` (arrayref of domain strings)
**Output**: `{order_url, status, authorizations[], finalize_url}`
**Status**: Starts as `pending`
**Authorizations**: Array of URLs to fetch for each domain
**State**: Stores in `<letsencrypt.child.current_order>`
**Multi-Domain**: Supports SANs (multiple domains)

### `letsencrypt.child.acme_get_authorization` ✓
**Purpose**: Fetch authorization and challenges for a domain
**Input**: `$authorization_url`
**Output**: `{status, identifier, challenges[], http01{}, wildcard}`
**Method**: POST-as-GET (POST with empty payload)
**Challenges**: Array of available challenge types (http-01, dns-01, etc.)
**HTTP-01**: Specific challenge object for HTTP validation
**Filter**: Returns only http-01 challenge

## HTTP-01 Challenge

### `letsencrypt.child.create_http01_challenge` ✓
**Purpose**: Create and write HTTP-01 challenge response to disk
**Input**: `$challenge, $domain`
**Output**: `{token, key_auth, file_path, well_known_url, challenge_url}`
**Key Auth**: `token.jwk_thumbprint` (RFC 7638)
**File Path**: `/.well-known/acme-challenge/{token}`
**Location**: `/var/httpd/default/.well-known/acme-challenge/`
**Permissions**: 0644 (world readable)
**State**: Stores challenge metadata in `<letsencrypt.child.active_challenges>`

### `letsencrypt.child.respond_to_challenge` ✓
**Purpose**: Submit challenge response to ACME server
**Input**: `$challenge_url, $token`
**Output**: `{status, processing}`
**Payload**: Empty JSON object `{}`
**Response**: Tells server to start validation
**Status Change**: `pending` → `processing`
**Nonce**: Gets fresh nonce for next operation

### `letsencrypt.child.poll_challenge_status` ✓
**Purpose**: Poll ACME server for challenge validation result
**Input**: `$authorization_url, $domain`
**Output**: `{valid: 1/0, status, attempts, error}`
**Backoff**: Exponential (1s → 10s max)
**Max Attempts**: 60 (10 minutes total timeout)
**Status**: pending → valid (success) or invalid (failure)
**Method**: POST-as-GET to authorization URL

## Certificate Generation

### `letsencrypt.child.generate_csr` ✓
**Purpose**: Generate new RSA key and Certificate Signing Request
**Input**: `$domains` (arrayref, first = primary)
**Output**: `{csr_pem, csr_b64url, key_pem, domains}`
**Key Size**: RSA-2048
**CSR**: X.509 request with CN and SANs
**Extensions**: subjectAltName for all domains
**State**: Stores CSR and key in `<letsencrypt.child.current_csr/cert_key>`
**Subject**: CN = primary domain, O = Organization

### `letsencrypt.child.acme_finalize_order` ✓
**Purpose**: Submit CSR and download certificate from ACME server
**Input**: None (uses order and CSR from state)
**Output**: `{certificate, key, domains, cert_url, poll_attempts}`
**Step 1**: POST CSR to finalize endpoint
**Step 2**: Poll order status (60 attempts, exponential backoff)
**Status**: processing → valid
**Step 3**: Download certificate from certificate URL
**Result**: PEM-formatted certificate and key

## Complete Operation Flow

### Renewal Operation: `letsencrypt.child.acme_renew` ✓
**Purpose**: Complete certificate renewal (uses all modules above)
**Input**: `{domain, cert_info, san_domains?}`
**Flow**:
```
1. fetch_acme_directory()
2. load_account_key() or generate_account_key()
3. acme_register_account() (if needed)
4. acme_create_order([domain, san_domains])
5. For each authorization:
   a. acme_get_authorization($auth_url)
   b. create_http01_challenge($challenge, $domain)
   c. respond_to_challenge($challenge_url, $token)
   d. poll_challenge_status($auth_url, $domain)
6. generate_csr([domains])
7. acme_finalize_order()
8. send_to_parent({cert_ready, ...})
```
**Error Handling**: Returns `renewal_failed` on any error with error_code

## Usage Examples

### Get Account Key
```perl
my $rsa = <[letsencrypt.child.load_account_key]>->();
unless ($rsa) {
    <[letsencrypt.child.generate_account_key]>->();
}
```

### Create ACME Request
```perl
my $nonce = <[letsencrypt.child.get_fresh_nonce]>->();
my $jws = <[letsencrypt.child.create_jws]->(
    {key => 'value'},  # payload
    $nonce,
    $account_url       # KID
);
```

### Make HTTP Request
```perl
my $resp = <[letsencrypt.child.acme_http_request]>->(
    'POST',
    $order_url,
    {identifiers => [{type => 'dns', value => 'example.com'}]},
    $nonce,
    $account_url
);
# $resp->{status}, $resp->{data}, $resp->{nonce}
```

### Process Challenge
```perl
my $challenge_resp = <[letsencrypt.child.create_http01_challenge]>->(
    $challenge,
    'example.com'
);
<[letsencrypt.child.respond_to_challenge]>->(
    $challenge_resp->{challenge_url},
    $challenge_resp->{token}
);
my $result = <[letsencrypt.child.poll_challenge_status]>->(
    $auth_url,
    'example.com'
);
```

## State Variables

All state stored in child process memory, keyed under `<letsencrypt.child.*>`:

```perl
<letsencrypt.child.acme_client> = {
    server           => 'https://acme-v02.api.letsencrypt.org/directory',
    account_key      => $rsa_object,
    account_key_pem  => 'private key PEM',
    account_pub_pem  => 'public key PEM',
    directory        => {...},
    nonce            => 'current nonce',
    account_url      => 'https://acme.../acme/acct/12345',
};

<letsencrypt.child.current_order> = {
    order_url        => 'https://acme.../acme/order/67890',
    status           => 'pending|ready|processing|valid',
    domains          => ['example.com', 'www.example.com'],
    authorizations   => ['https://acme.../acme/authz/1', ...],
    finalize_url     => 'https://acme.../acme/order/67890/finalize',
    created_at       => 1234567890,
};

<letsencrypt.child.current_csr> = {
    pem             => 'CSR in PEM format',
    der             => 'CSR in binary DER format',
    b64url          => 'DER encoded as base64url for ACME',
    domains         => ['example.com', 'www.example.com'],
    created_at      => 1234567890,
};

<letsencrypt.child.cert_key> = {
    pem             => 'certificate key in PEM format',
    object          => $rsa_object,
};

<letsencrypt.child.active_challenges> = {
    'F8q7VYU3...' => {
        domain          => 'example.com',
        token           => 'F8q7VYU3...',
        key_auth        => 'F8q7VYU3....oFvnlFP1K9ENrzNGHUoi8A',
        challenge_url   => 'https://acme.../acme/challenge/...',
        file_path       => '/var/httpd/default/.../token',
        created_at      => 1234567890,
        status          => 'pending|processing|valid|invalid',
        responded_at    => 1234567900,
    },
};
```

## Constants & Defaults

```perl
# Configuration defaults
ACME_TIMEOUT           = 10 seconds
CHALLENGE_MAX_ATTEMPTS = 60 attempts
CHALLENGE_BACKOFF_MIN  = 1 second
CHALLENGE_BACKOFF_MAX  = 10 seconds
ORDER_POLL_MAX         = 60 attempts
RSA_KEY_SIZE           = 2048 bits
HASH_ALGORITHM         = SHA-256
JWS_ALGORITHM          = RS256 (RSA + SHA-256)

# File Permissions
ACCOUNT_KEY_MODE       = 0600 (owner read/write only)
CERT_KEY_MODE          = 0600 (owner read/write only)
CHALLENGE_FILE_MODE    = 0644 (world readable)
```

## Error Codes

All renewal failures include `error_code`:

- `directory_fetch_failed` - Cannot fetch ACME directory
- `account_registration_failed` - Cannot create account
- `order_creation_failed` - Cannot create certificate order
- `authorization_failed` - Cannot fetch authorization
- `challenge_creation_failed` - Cannot write challenge file
- `challenge_submission_failed` - Cannot submit challenge
- `challenge_validation_failed` - Challenge validation returned invalid
- `csr_generation_failed` - Cannot generate CSR
- `finalization_failed` - Cannot finalize order or download cert

## Dependencies

### Perl Modules
- `Crypt::OpenSSL::RSA` - RSA key operations
- `Crypt::OpenSSL::X509` - X.509 certificate operations
- `Crypt::Random` - Cryptographically secure randomness
- `JSON::XS` - JSON serialization
- `Digest::SHA` - SHA hashing
- `MIME::Base64` - Base64 encoding
- `LWP::UserAgent` - HTTP client
- `LWPx::ParanoidAgent` - HTTPS with SSL verification

### Configuration
- Account key: `/var/cache/letsencrypt/account.key`
- Account cache: `/var/cache/letsencrypt/account.json`
- Challenge path: `/.well-known/acme-challenge/` (in default vhost)
- Cert storage: `/etc/protocol-7/certs/domain.{pem,key}`

