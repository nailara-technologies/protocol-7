# shm streaming payload pipeline — secure large-body transfer between zenki

## problem

large HTTP POST bodies (e.g. jobs sync batch ~1.2MB) cannot pass through the
P7 protocol network as `call_args` parameters — session buffer ceilings apply.
bumping buffer sizes is the wrong direction: memory × connections, and the body
still has to traverse the protocol layer.

## solution

stream the body directly to disk/shm as it arrives, secured by four independent
cryptographic layers. pass only a tiny path reference + key through the P7 network.

```
header format:  X-P7-Content-Hash: <ntime>:<size>:<B32-BMW384>

  ntime first  : freshness + replay anchor — temporal context
  size second  : cryptographic constraint — collapses brute-force search space
                 attacker must find a collision of EXACTLY <size> bytes
                 for small payloads: verifiably impossible if size range scanned
                 for large payloads: multiplicatively harder than unconstrained
  checksum last: BMW384 integrity over the exact <size> bytes

  signature is over the full "<ntime>:<size>:<B32>" string — all three bound
  together. size mismatch alone invalidates the signature even if collision found.

sender side (jobsite → httpd):
  1. compute BMW384(body) → B32 encode
     build header: "<ntime>:<length>:<B32>"
  2. sign header with C25519 host key
  3. POST body with headers:
       X-P7-Content-Hash: <ntime>:<length>:<B32>
       X-P7-Signature:    <C25519-sig-of-full-header>
       X-P7-Host-Key:     <sender-pubkey-B32>
       X-P7-Key-Cert:     <parent-name>:<parent-sig-of-hostkey-B32>

httpd receive pipeline:
  1. parse all X-P7-* headers
  2. verify X-P7-Key-Cert: parent signature on host key (key hierarchy)
  3. verify X-P7-Signature: C25519 sig over full content-hash header
     → reject before reading any body if invalid (instant, zero cost)
  4. check ntime within replay window (e.g. 60 seconds)
     → reject stale or future-dated packets
  5. generate random temp filename: /var/protocol-7/shm/<ntime-b32>-<random>
     chmod 000 — unreadable by anyone during transfer
  6. generate ephemeral Twofish key (held in memory only, never written)
  7. as body chunks arrive:
       $bmw_ctx->add($chunk)           # rolling BMW384
       $twofish->encrypt($chunk)       # stream encrypt
       write encrypted chunk to temp file
  8. on body complete:
       verify received_length == header size
       verify encode_b32r($bmw_ctx->digest) == header B32
     if VALID:
       rename temp file → /var/protocol-7/shm/<B32-BMW384-sum>
       chmod +r for httpd/protocol-7 user
       pass to web zenka via P7: { path => <B32-sum>, key => <twofish-key> }
     if INVALID:
       unlink temp file
       destroy Twofish key (undef + memory clear)
       return HTTP 400 — data cryptographically irrecoverable

web zenka receive:
  1. receive { path, key } via P7 route
  2. open /var/protocol-7/shm/<path>
  3. decrypt with key if encrypted
  4. process data
  5. unlink file when done
```

## security properties

```
C25519 signature   :  authentication — only authorized senders can produce it
                      verified before any body bytes are read
                      attacker is rejected at header parse, body never buffered

BMW384 rolling     :  integrity — computed incrementally, zero memory overhead
                      content-addressed filename: tamper-evident by name itself
                      mismatch = data destroyed, never accessible

Twofish encryption :  confidentiality — only target zenka receives the key
                      multiple zenki sharing same unix user cannot read each other
                      OS permissions are coarse (user-level), crypto is fine (zenka-level)
                      key destroyed on validation failure = irrecoverable data

file permissions   :  access control — chmod 000 during transfer (no one reads)
                      chmod +r only after validation (OS layer)
                      key routing via P7 (application layer — zenka identity)
```

## why sign the header not the data

signing the full body requires buffering or two-pass processing.
signing `"<ntime>:<size>:<B32>"` is signing a commitment to the data —
mathematically stronger than signing the data alone:

**ntime**: binds the commitment to a specific moment — prevents replay
**size**: collapses the collision search space to inputs of exactly N bytes
  - for small N: verifiably impossible if N-byte collision space has been scanned
  - for large N: multiplicatively harder than unconstrained collision search
  - size mismatch alone invalidates the signature even with a valid BMW384 collision
**BMW384**: integrity over the exact content

together they form a triple commitment: WHEN + HOW MUCH + WHAT

this enables:
- instant rejection (sig verification before body read — zero body buffering)
- replay protection (ntime window, e.g. 60s)
- streaming body directly to disk (incremental `$bmw_ctx->add($chunk)`)
- provable uniqueness for small payloads where collision space is bounded

## implementation

### new modules

**`httpd.handler.shm_write`** — replaces body_remainder for large authenticated POSTs:
- called when `X-P7-Content-Hash` + `X-P7-Signature` headers present
- verifies C25519 sig on header immediately
- opens temp file (chmod 000), optionally initializes Twofish cipher
- registers IO watcher on session socket for streaming write
- on each chunk: `$bmw_ctx->add($chunk)`, encrypt, write
- on complete: verify hash+length, rename/chmod or destroy

**`base.shm.write`** — generic SHM write (used by httpd.handler.shm_write):
- params: `{ data, path, key }`
- handles rename + permission management

**`base.shm.read`** — generic SHM read for consumer zenki:
- params: `{ path, key }`
- decrypts if key present, verifies BMW384 checksum on read
- unlinks after read (configurable)

**`base.shm.path`** — returns the SHM directory path:
- `/var/protocol-7/shm/` (created at startup if absent)
- world-unreadable dir: chmod 711, owned by root or p7-admin

### existing modules to extend

**`httpd.http_post`** — detect `X-P7-Content-Hash` + `X-P7-Signature` headers,
dispatch to `httpd.handler.shm_write` instead of body_remainder accumulator

**`httpd.route.handler.web-relay`** — when session has `shm_path` set (written
by shm_write), pass `{ shm_path, shm_key }` as call_args instead of inline body

**`plugin.web.jobs.sync`** — detect `call_args.shm_path`, read via `base.shm.read`
instead of parsing `call_args.args` inline. backwards-compatible: if no shm_path,
use args as before (browser updates still use inline body)

### sender side (jobsite)

**`jobsite.sync.push`** — add signed content-hash headers:
```perl
my $ntime    = <[base.ntime.b32]>->(3, TRUE);
my $b32_hash = <[base.chk-sum.bmw.strsum]>->($body);   # BMW384 → B32
my $header   = join ':', $ntime, length($body), $b32_hash;
my $sig      = <[crypt.C25519.sign_data]>->(\$header, $host_key);

<[clients.http.post]>->({
    url     => $url,
    body    => $body,
    headers => {
        'X-P7-Content-Hash' => $header,
        'X-P7-Signature'    => $sig,
    },
    ...
});
```

once this is working, the chunking approach can be retired — one single POST
regardless of payload size, streamed to disk, no buffer limits.

## incremental BMW384

`Digest::BMW->new(384)` supports incremental hashing:
```perl
my $ctx = Digest::BMW->new(384);
$ctx->add($chunk1);
$ctx->add($chunk2);
my $digest_b32 = encode_b32r($ctx->digest);
```

the `->clone()` method is available if needed for parallel validation.
this means httpd never holds the full body in memory simultaneously.

## twofish encryption

`AMOS7::Twofish` is already available. ephemeral key generation:
```perl
my $key = <[base.prng.bytes]>->(32);   # 256-bit ephemeral key
# encrypt chunks as they arrive
# pass key to target zenka only after BMW384 validation succeeds
# destroy key (undef + memory clear) on validation failure
```

## shm directory

```
/var/protocol-7/shm/           chmod 711  (owner can list, no world read)
/var/protocol-7/shm/<random>   chmod 000  (during transfer — no one reads)
/var/protocol-7/shm/<B32-sum>  chmod 440  (after validation — owner + group read)
```

temp filenames: `<ntime-b32>-<random-8-chars>` to avoid collisions and timing
inference. renamed to `<B32-BMW384-sum>` only on successful validation.

## future extensions

- **distributed**: shm path becomes a nameserv-addressable content store;
  remote zenki request by B32 hash, verified on receipt
- **validator pipeline**: low-priority watcher on shm dir, validates content
  types and schema before consumer zenka is notified
- **caching**: identical payloads (same B32 filename) automatically deduplicated
  — second sender of same content finds file already exists, skips write

## verification

```bash
## after implementation: manual test with large payload
curl -X POST http://localhost/jobs-sync \
  -H "X-P7-Content-Hash: <length>:<b32>" \
  -H "X-P7-Signature: <sig>" \
  -d @large-payload.json

## invalid signature should reject before body is read
## valid sig + bad body should destroy key + return 400
## valid sig + valid body should appear in /var/protocol-7/shm/ as B32 filename
## web zenka should process and unlink
```

## style notes

- all comments lowercase, bracket annotations `[ word ]` not `( word )`
- use `<[base.logs]>->( level, format, args )` — level 2 for pipeline steps
- use `<system.root_path>` not hardcoded paths
- use `<[base.prng.bytes]>` for random key/filename generation
- use `Digest::BMW->new(384)` directly for incremental hashing
- use `encode_b32r()` from AMOS7 for B32 encoding of digest bytes
- do not add the stub signature to new files — signing adds footer

#,,,,,..,,,.,,,..,,.,,,,,,.,.,,.,,.,,,.,.,,,.,..,,...,..,,,..,..,,,,.,,.,,,.,,
#4RYU33Q2G3VGNV3TKV4CHNBCDMJUUHESXIEQTYGTRJPYGKFICIA2YZKX7X7KDQVHTWALWGKHSY25I
#\\\|LPNI3NSO5AZS54SOOCM3HS55NX4JB5GEN3E3TGXBLXYI7ZKKU7M \ / AMOS7 \ YOURUM ::
#\[7]A3BOVAMBYM3BBY6NXZR7ONRPHHTL5WYP3YRIYCUMFLPSBTA6FCCI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
