## [:< ##

# name  = task: log anonymization via checksum-indexed encrypted table
# descr = filter sensitive data from log lines, encrypt with user system key,
#         store in a separate table indexed by BMW-L12 checksum. log stream
#         keeps full bandwidth and is investigatable without decryption.
#         sensitive context is recoverable on demand in situ.

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
  key:   X7KQMNS4   (BMW-L12 checksum of the sensitive fragment)
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

### base.logt
primary integration point. after the log line is assembled and before it is
written to the ring buffer or archive, pass through log.anon.replace.
store resulting pairs via log.anon.store.
write anonymized line to ring buffer.

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

BMW-L12 (12-char BMW384 substring):
- collision resistance sufficient for local log table (not adversarial)
- 12 chars fits in log line without excessive visual noise
- same checksum family as rest of system → no new dependency
- `[L:X7KQMNS4]` (8-char) or `[L:X7KQMNS4LM7R]` (12-char) — configure at init

AMOS checksum as alternative:
- shorter (7 chars), slightly weaker collision resistance
- use AMOS for low-entropy fragments (paths), BMW-L12 for high-entropy content

## table storage

```
path:   <system.root_path>/data/log-anon/table.<epoch>.lmdb
        or flat: data/log-anon/table.<epoch>.bin
format: fixed-record [ 16-byte key (checksum+padding) | 128-byte value (encrypted) ]
epoch:  rotates with v7 epoch for temporal scoping
```

flat binary allows fast mmap access; LMDB preferred for concurrent writes.

## implementation phases

```
phase 1:  classifier (regex, path patterns)
          replace + BMW-L12 checksum generation
          flat file table with Twofish encryption
          base.logt integration (opt-in flag first)

phase 2:  log.anon.cmd.resolve command
          resolve-line reconstruction
          p7c integration for investigation workflow

phase 3:  entropy-based classifier (Shannon threshold)
          LMDB table for concurrent write performance
          table rotation with epoch boundary

phase 4:  export mode: decrypt full archived log for authorized recipient
          audit trail: which resolutions happened, when, by whom
```

## dispatch prompt

implement phase 1 of log anonymization:

1. create `log.anon.classify` — regex classifier returning (start,end,label)
   spans. cover: /home/<user>/ paths, quoted strings > 40 chars, UUIDs.

2. create `log.anon.replace` — apply spans to line, generate BMW-L12
   checksums, return anonymized line + (checksum, plaintext) pairs.

3. create `log.anon.store` — write pairs to flat binary table at
   `<system.root_path>/data/log-anon/table.bin`. Twofish encryption with
   user system key. create directory if absent.

4. create `log.anon.resolve` and `log.anon.cmd.resolve` — lookup + decrypt
   single entry by checksum. return plaintext or FALSE if not found.

5. wire into `base.logt` as opt-in: if `$data{log}{anon}{enabled}` is set,
   pass line through replace + store before writing to ring buffer.

verify: enable anon, run a command with a file path argument, confirm log
shows `[L:XXXXXXXX]` in place of path, `p7c log.anon.resolve XXXXXXXX`
returns the original path.

#,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,

#,,.,,,..,,.,,,.,,,.,,,,,,..,,,,.,,.,,...,...,..,,...,...,,..,.,,,,..,,..,.,.,
#6KKZAGE3HUE6WHJQBXOFSB2R4BKLYZCLCKCZTGSFS5KVGUV5WHGSLWF36WKDQR63G5FDWJJN7NIDW
#\\\|YXT2PBULKOQMNRZ3VMKQ47AVNYXMTCAUFJEN4V3ZKX22MVZIKZX \ / AMOS7 \ YOURUM ::
#\[7]K6SMN5RBTKPSRIEWEIJZN6WPAF72SIZHQOQEQZPSOTGWPPRHLOBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
