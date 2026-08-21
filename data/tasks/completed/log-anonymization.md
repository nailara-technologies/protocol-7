## [:< ##

# name  = task: log anonymization via checksum-indexed encrypted table
# descr = filter sensitive data from log lines, encrypt with user system key,
#         store in a separate table indexed by BMW-L13 checksum. log stream
#         keeps full bandwidth and is investigatable without decryption.
#         sensitive context is recoverable on demand in situ.

## status [ 2026-07-23 ] — phase 1 + resolve-line DONE, live-verified; rest of phase 2 and phases 3-5 not started

`p7-log.anon.resolve-line` / `p7-log.anon.cmd.resolve-line` added
(2026-07-23, direct implementation, not dispatched -- small enough to
write in-session): resolves every `[L:<checksum>]` token in a full log
line in place, unresolvable tokens left as-is rather than dropped. bare
alias `p7c p7-log.resolve-line` also works (same auto-registration as
`p7-log.resolve`). live-verified with a real two-token line, both tokens
resolved correctly. this closes out the "log.anon.cmd.resolve command /
resolve-line reconstruction / p7c integration" bullets from the
implementation-phases section's phase 2 -- entropy-based classification
(the *other* phase 2, from the sensitive-data-classification section)
remains unbuilt, as do phases 3-5.

phase 1 implemented (kimi K3 dispatch): `p7-log.anon.classify/.replace/
.store/.resolve/.cmd.resolve/.init_code/.transform/.key` — note the
`log.anon.*` namespace from this spec was renamed to `p7-log.anon.*` post-
implementation (module group lives inside the `p7-log` zenka, not a
standalone `log` zenka — `p7c log.anon.resolve` fails "client not
present"; the working form is `p7c p7-log.resolve` / `p7c p7-log.anon.
resolve`, both live-verified against the real encrypted table). wired
into `p7-log.add_line` as opt-in via `p7-log.anon.enabled` (currently `1`
in `cfg/zenki/p7-log/zenka.v7`). BMW-L13 via existing
`chk-sum.bmw.L13-str`; Twofish key lazily derived from the user's C25519
system key. verify step from the original dispatch prompt passed: logged
line shows `[L:XXXXXXXX]` in place of a `/home/<user>/...` path,
`p7c p7-log.resolve XXXXXXXX` returns the original path.

known issue, follow-up next commit: `p7-log.anon.classify`'s path regex
hardcodes `/home/<user>/...` — misses installs where the home directory
root was renamed (e.g. `/users/`). should read from a configured/detected
prefix instead of a literal `/home/`.

phases 2 (richer resolve/investigation workflow beyond the basic command),
3 (timestamp_encrypt + C25519 chain signing), 4 (entropy classifier +
LMDB table), 5 (full_encrypt + decrypt-range + export/audit) are all still
design-only, not started.

## the problem

log lines contain sensitive data by necessity: file paths, user interaction
fragments, command arguments, context strings with high entropy. these need
to be present during development but are a liability in archives, shared
logs, and any context where the log leaves the local system.

current state: no filtering. everything lands in the log ring buffer and
any archived log file as plaintext.

## the design

```
log line (before):
  [1234567] read file '/home/taeki/projects/secret/design.md' (4200 bytes)

log line (after):
  [1234567] read file [L:X7KQMNS4] (4200 bytes)

encrypted table entry:
  key:   X7KQMNS4   (BMW-L13 checksum of the sensitive fragment)
  value: Twofish( '/home/taeki/projects/secret/design.md', user_system_key )
```

properties:
- log writing stays high-bandwidth: checksum replace is a fast inline op
- log is fully investigatable without decryption: structure, timing, counts
  are all present; only sensitive payload is replaced
- table lookup is O(1) by checksum key
- decryption is on-demand, in context of requirement: read one entry, read
  a range, read all — no bulk decryption needed at rest
- sensitive data is encrypted with the user's system key (same key used for
  other local-key operations in the key-tree)

## sensitive data classification

phase 1 targets (high value, easy to detect):
```
file paths with user home prefix       /home/<user>/...
interaction content strings            quoted multi-word content > N chars
command argument values                args to user-facing commands
session identifiers                    UUIDs, session tokens
network addresses                      IPs, hostnames when not system-internal
```

phase 2 (entropy-based detection):
```
high-entropy substrings                Shannon entropy > threshold
key material fragments                 matches key-material patterns
structured data payloads               JSON/YAML embedded in log lines
```

## components

### `log.anon.classify`
regex + entropy classifier. given a log line, returns list of
(start, end, label) spans for sensitive fragments.
phase 1: regex patterns per class. phase 2: entropy scan.

### `log.anon.replace`
replaces classified spans in a log line with `[L:<checksum>]` tokens.
returns: anonymized line + list of (checksum, plaintext) pairs for storage.

### `log.anon.store`
writes (checksum, encrypted_value) pairs to the anonymization table.
encryption: Twofish with user system key (from key-tree).
table format: flat file or LMDB, checksum as key, 16-byte aligned values.

### `log.anon.resolve`
given `[L:<checksum>]` or bare checksum, decrypt and return plaintext.
used on demand: for investigation, for context injection, for export.

### `log.anon.resolve-line`
given a stored anonymized log line, resolve all `[L:*]` tokens in place.
returns the original line reconstructed.

### `log.anon.cmd.resolve`
```
args: <checksum>
```
on-demand resolution command: p7c log.anon.resolve <checksum>
returns decrypted value for single entry.

## integration points

### p7-log zenka
primary integration point. p7-log receives every log line before it reaches
the ring buffer or disk archive — it is the natural owner of the anonymization
pipeline. after the line is received and before writing, pass through the
enabled transform stages (classify → replace → timestamp_encrypt → sign →
full_encrypt). store resulting pairs via log.anon.store.

### log archival
when archiving ring buffer to disk, anonymized lines are written directly.
the table is written alongside (or to a separate encrypted archive file).

### investigation workflow
```
1. grep log for pattern → find anonymized line with [L:XXXXXXXX]
2. p7c log.anon.resolve XXXXXXXX → decrypted value returned in terminal
3. or: p7c log.anon.resolve-line '<full log line>' → reconstructed line
```

## checksum choice

BMW-L13 (13-char BMW384 substring):
- collision resistance sufficient for local log table (not adversarial)
- 13 chars fits in log line without excessive visual noise
- same checksum family as rest of system → no new dependency
- `[L:X7KQMNS4]` (8-char) or `[L:X7KQMNS4LM7RA]` (13-char) — configure at init

AMOS checksum as alternative:
- shorter (7 chars), slightly weaker collision resistance
- use AMOS for low-entropy fragments (paths), BMW-L13 for high-entropy content

## table storage

```
path:   <system.root_path>/data/log-anon/table.<epoch>.lmdb
        or flat: data/log-anon/table.<epoch>.bin
format: fixed-record [ 16-byte key (checksum+padding) | 128-byte value (encrypted) ]
epoch:  rotates with v7 epoch for temporal scoping
```

flat binary allows fast mmap access; LMDB preferred for concurrent writes.

## optional protection layers (all disabled by default)

four independently toggleable modes, stackable in any combination:

```
$data{log}{anon}{enabled}           = 0  ## fragment anonymization (base)
$data{log}{anon}{timestamp_encrypt} = 0  ## encrypt timestamp field
$data{log}{anon}{sign}              = 0  ## C25519 chain signing
$data{log}{anon}{full_encrypt}      = 0  ## encrypt full line (max privacy)
```

### timestamp encryption

the timestamp `[1234567]` reveals activity patterns even when content is
anonymized — timing side-channels expose usage habits, session boundaries,
and operational rhythms.

```
before:  [1234567] read file [L:X7KQMNS4] (4200 bytes)
after:   [T:A3FQNMKL] read file [L:X7KQMNS4] (4200 bytes)
```

encrypted timestamp: Twofish( raw_timestamp, user_system_key ).
token `[T:XXXXXXXX]` uses same 8-char BMW-L13 format as fragment tokens.
plaintext timestamp stored in same anonymization table — resolved by same
`log.anon.resolve` lookup. log remains structurally readable; timing is
opaque without the key.

### C25519 chain signing

each log line is signed with the user's C25519 private key. the signature
covers: line content + HMAC of the previous line's signature (chain).

```
[T:A3FQNMKL] read file [L:X7KQMNS4] (4200 bytes) [S:BVQK3M7R]
```

`[S:XXXXXXXX]` is an 8-char prefix of the Ed25519 signature (full sig
stored in a parallel signature log). chain property: any tampered line
breaks verification of all subsequent lines. provides:
- tamper evidence for the full log sequence
- proof of origin (user key, not any zenka key)
- auditable log integrity without bulk decryption

### full line encryption

```
$data{log}{anon}{full_encrypt} = 1
```

entire assembled log line is encrypted with Twofish before writing to the
ring buffer. only a fixed-width encrypted blob + BMW-L13 index token is
stored. log is completely opaque without decryption pass.

investigatability requires: `p7c log.anon.decrypt-range <from> <to>` which
decrypts a time range into a temporary buffer for inspection — the buffer
is not persisted.

when combined with timestamp_encrypt: the index token itself is the only
visible structure. when combined with sign: signatures are over plaintext
before encryption, verified after decryption.

### mode interactions

```
fragment only:          partial privacy, full investigatability
+ timestamp_encrypt:    timing hidden, structure visible, fast grep
+ sign:                 tamper-evident, auditable chain
full_encrypt only:      max privacy, requires decryption to investigate
full_encrypt + sign:    max privacy + tamper evidence (sign before encrypt)
```

## implementation phases

```
phase 1:  classifier (regex, path patterns)
          replace + BMW-L13 checksum generation
          flat file table with Twofish encryption
          base.logt integration (opt-in flag first)

phase 2:  log.anon.cmd.resolve command
          resolve-line reconstruction
          p7c integration for investigation workflow

phase 3:  timestamp encryption (timestamp_encrypt flag)
          C25519 chain signing (sign flag)

phase 4:  entropy-based classifier (Shannon threshold)
          LMDB table for concurrent write performance
          table rotation with epoch boundary

phase 5:  full line encryption (full_encrypt flag)
          decrypt-range command for investigation
          export mode: decrypt full archived log for authorized recipient
          audit trail: which resolutions happened, when, by whom
```

## dispatch prompt

implement phase 1 of log anonymization:

1. create `log.anon.classify` — regex classifier returning (start,end,label)
   spans. cover: /home/<user>/ paths, quoted strings > 40 chars, UUIDs.

2. create `log.anon.replace` — apply spans to line, generate BMW-L13
   checksums, return anonymized line + (checksum, plaintext) pairs.

3. create `log.anon.store` — write pairs to flat binary table at
   `<system.root_path>/data/log-anon/table.bin`. Twofish encryption with
   user system key. create directory if absent.

4. create `log.anon.resolve` and `log.anon.cmd.resolve` — lookup + decrypt
   single entry by checksum. return plaintext or FALSE if not found.

5. wire into `p7-log` zenka as opt-in: if `$data{log}{anon}{enabled}` is set,
   pass line through replace + store before writing to ring buffer.

verify: enable anon, run a command with a file path argument, confirm log
shows `[L:XXXXXXXX]` in place of path, `p7c log.anon.resolve XXXXXXXX`
returns the original path.

#,,,.,,.,,...,.,.,,..,,..,,,,,,,.,.,,,,.,,,,.,..,,...,...,.,,,,,,,.,,,,.,,.,.,
#C6PQJ7ZWR3B6BSPMHJYFZLSKJTV4ZYUCC636GAMJLZRTWPDVFPUHM344MMC54SCVJILVJAKX32U3W
#\\\|V5NPC4PF6OLGP4UWJ6JR3Z6HVGWPFJBDC2DVUHD46ACMNY57EUG \ / AMOS7 \ YOURUM ::
#\[7]YPATCJJL77DCSMVS6ULQF4MNYP5ERWRZ3632SSABMLC3SMUEZEDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
