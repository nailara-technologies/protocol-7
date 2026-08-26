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
header format:  X-P7-Content-Hash: <ntime>:<bytes>:<lines>:<B32-BMW384>

  this mirrors the proven inline subroutine format in bin/Protocol-7:
    <BMW256-B32:lines:word_count:bytes>
  which validates line count + BMW-256 checksum on every inline sub load.
  the SHM pipeline extends it with ntime (replay protection) and uses BMW-384.

  attribute order = progressive validation cost (cheapest gate first):

  ntime   : ~nanoseconds  — single subtraction against current time
            reject stale/future before reading anything
  bytes   : ~free         — count as chunks arrive, no extra work
            attacker must produce EXACTLY N bytes, collapses search space
            for small N: verifiably impossible if N-byte space scanned for collisions
  lines   : ~free         — count newlines inline while scanning chunks
            independent constraint: same bytes, different structure → rejected
  BMW384  : O(n) incremental — $bmw_ctx->add($chunk) during write, already done
            full integrity: final compare is ~nanoseconds once streaming completes

  all four attributes signed together — mismatch on ANY attribute invalidates
  the signature even if the others match.

sender side (jobsite → httpd):
  1. compute BMW384(body) → B32 encode
     count bytes and lines
     build header: "<ntime>:<bytes>:<lines>:<B32>"
  2. sign header with C25519 host key
  3. POST body with headers:
       X-P7-Content-Hash: <ntime>:<bytes>:<lines>:<B32>
       X-P7-Signature:    <C25519-sig-of-full-header>
       X-P7-Host-Key:     <sender-pubkey-B32>
       X-P7-Key-Cert:     <parent-name>:<parent-sig-of-hostkey-B32>

httpd receive pipeline — progressive gates, cheapest first:

  gate 1 [ ~ns  ]: parse X-P7-Content-Hash — extract ntime, bytes, lines, B32
  gate 2 [ ~ns  ]: check ntime within replay window (e.g. 60s)
                   → reject stale/future before any sig verification
  gate 3 [ ~μs  ]: verify X-P7-Key-Cert — parent signature on host key
  gate 4 [ ~μs  ]: verify X-P7-Signature — C25519 over full content-hash header
                   → reject unauthorized sender before reading any body
  gate 5 [ free ]: generate temp filename + Twofish key, open file chmod 000
  gate 6 [ O(n) ]: as chunks arrive — single pass, all in parallel:
                     byte_count += length($chunk)
                     line_count += ($chunk =~ tr/\n//)
                     $bmw_ctx->add($chunk)
                     $twofish->encrypt($chunk) → write to temp file
  gate 7 [ ~ns  ]: on body complete — final comparisons:
                     byte_count == header bytes  → reject if mismatch
                     line_count == header lines  → reject if mismatch
                     encode_b32r($bmw_ctx->digest) == header B32 → reject if mismatch
     if ALL VALID:
       rename temp file → /var/protocol-7/shm/<B32-BMW384-sum>
       chmod +r for httpd/protocol-7 user
       pass to web zenka via P7: { path => <B32-sum>, key => <twofish-key> }
     if ANY GATE FAILS:
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

this pattern is already proven in `bin/Protocol-7`: every inline subroutine
is verified against `<BMW256-B32:lines:word_count:bytes>` on load. the SHM
pipeline extends the same principle with ntime and BMW-384.

**ntime**:  WHEN — temporal anchor, prevents replay
**bytes**:  HOW MUCH — exact byte count, collapses collision search space
**lines**:  STRUCTURE — independent constraint, different arrangement = rejected
**BMW384**: WHAT — integrity over exact content

four orthogonal commitments. breaking any one invalidates all.

each attribute is progressively more expensive to validate, so rejection
always happens at the earliest, cheapest possible gate:

```
ntime   → reject stale/future:     ~nanoseconds, no body read
C25519  → reject unauthorized:     ~microseconds, no body read
bytes   → reject wrong size:       free, counted during write
lines   → reject wrong structure:  free, counted during write
BMW384  → reject tampered content: O(n) incremental, already done during write
final compare → nanoseconds
```

attack rejected at ntime costs one subtraction.
attack rejected at signature costs one sig verify.
no attack ever reaches the disk without clearing all four header gates first.

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

### replay protection — two-layer design

**layer 1 — time window** (from discover.process_incoming_packet):
```perl
my $timestamp_num = <[base.ntime_BASE32_to_numerical]>->($ntime_b32);
my $delta_secs    = ($timestamp_num - <[base.ntime]>->(3)) / 4200;
return HTTP_403 if abs($delta_secs) > 60;   ## 60s window for HTTP ##
```
reuse `base.ntime_BASE32_to_numerical` directly — already proven in discover.

**layer 2 — per-sender ntime cache** (stricter than discover):
discover overwrites host entries on each packet (replay of presence = harmless).
for authenticated data transfer, exact replay within the window must be rejected:
```perl
## $data{'shm.seen_ntimes'}{$hostkey_L13}{$ntime_b32} = expiry_time ##
return HTTP_403 if exists $data{'shm.seen_ntimes'}{$pkey_L13}{$ntime_b32};
$data{'shm.seen_ntimes'}{$pkey_L13}{$ntime_b32} = <[base.ntime]>->(3) + (60 * 4200);
```
a sweep timer (matching replay window) removes expired ntime entries.
storage cost: one entry per request within the window — negligible.

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
my $bytes    = length($body);
my $lines    = () = $body =~ /\n/g;
my $header   = join ':', $ntime, $bytes, $lines, $b32_hash;
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

#,,,.,.,.,..,,,,.,,,,,...,,,,,..,,..,,..,,.,,,..,,...,...,,..,...,...,,..,..,,
#OSQ5UAI75BE334DHVGJRPYGCOU6CVF4NNSWRDZMUWAGLXPURZWYS6A3GA24BCRXNKY4N63XAIIHHW
#\\\|AXN7K4DUCF5D36HLCGPUNFZYZFXT4LCCEP7KP6IPI5OYBBGI7TI \ / AMOS7 \ YOURUM ::
#\[7]WS4FY4UCR25S3EVNKLJT3QZ6XG4S6M2O35RBV64AK2HOLOFA4MBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
