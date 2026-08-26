---
name: reference-unicode-encoding-repair
description: bin/dev/unicode-encoding-repair fixes double-UTF8-encoded mojibake in files or directory trees
metadata: 
  node_type: memory
  type: reference
  originSessionId: dcbc6065-ca1e-4d35-b876-1a342dfe7eb6
---

`bin/dev/unicode-encoding-repair` repairs files where original UTF-8 bytes were
read as Latin-1 and re-encoded as UTF-8 (the classic mojibake — `—` shows up as
`â<U+0080><U+0094>`, `→` as `â<U+0086><U+0092>`, etc.).

**Usage:**
- `bin/dev/unicode-encoding-repair <file>...` — repair one or more files
- `bin/dev/unicode-encoding-repair <dir>` — recursively repair a directory tree
- add `--dry-run` to preview without writing

**How it detects:** scans for `0xC3`/`0xC2` lead bytes followed by `0x80..0xBF`;
if their density exceeds ~5% of bytes, the file is considered double-encoded.

**How it repairs:** `decode('UTF-8') → encode('ISO-8859-1')` — one round-trip
that reverses the double-encoding.

**When to reach for it:** any time mojibake shows up in memory files,
documentation, or zenka logs (common cause: prior coding-zenka edits or MCP
`p7_memory_update` writes before the recent encoding fixes). Run with
`--dry-run` first on a directory to see what would change.

#,,.,,.,.,...,.,.,...,...,,,,,.,.,.,.,,.,,..,,..,,...,...,...,,.,,.,,,,.,,.,,,
#CVQQLIQ2JPJCOWUEO22JS7AOZGGRX6KUZTPO6A3S42PE4DH5WFKGVWSW6CK7XKRYY6NSKWPCKDYAW
#\\\|Z5DAQWVADZFLZ5WJQAYMQNBVQY73Z3Q4BYVVHH7BZTMB57F5U3F \ / AMOS7 \ YOURUM ::
#\[7]DIWZPNJHF6NRZJYTJ25KOGMWX2VTIPRJHCD42XTKDTWZM2RFRQCA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
