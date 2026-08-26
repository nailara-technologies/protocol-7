---
name: feedback-file-io-api
description: Correct parameter order and return types for file.read/write/slurp/append in P7 modules
type: feedback
originSessionId: 6538e52c-796d-4a00-bc99-63699ca261f0
---
Use these exact signatures in P7 module code — generated code frequently gets them wrong.

**Reading:**
- `<[file.read]>->($path, $encoding)` — returns content string directly; encoding optional
- `<[file.slurp]>->($path, $target_ref, $encoding)` — encoding is *third* param (after optional target ref); returns scalar ref — must deref with `$$ref`; prefer `file.read` unless you need the ref

**Writing:**
- `<[file.write]>->($path, $content, $encoding)` — encoding optional as *last* param
- `<[file.write_encoded]>->($encoding, $path, @lines)` — encoding *mandatory* as *first* param
- `<[file.append]>->($path, $content, $encoding)` — same as file.write, encoding optional last

**Why:** swap_subs in base.file.pre_init wires these; wrong param order silently passes encoding as target_ref or vice versa, causing empty reads or fatal type errors.

**Never use `base.file.*` names** — always use the short swapped names (`file.read`, `file.write_encoded`, etc.). `base.file.*` calls bypass swap_subs and may not exist as callable subs in module context.

**stat shadowing:** `bin/Protocol-7` does `use File::stat` which shadows the builtin `stat`. Never use `(stat $path)[2]` in modules — use `File::stat::stat($path)->mode` instead.

**How to apply:** Any time generating or reviewing code that reads/writes files or checks file mode in a P7 module, verify against the above.

#,,,.,,..,,..,.,.,,..,,..,...,,,.,,,,,,,.,..,,..,,...,...,.,.,.,.,.,,,...,.,.,
#XBVIX4D2ASZXLS3YSZ7HRDHVWYENFXQU3UYTIEEPUX57VBD5G75SRRLBHZ2A2JD4AUA5ENMWVGR7M
#\\\|B45YDB6YQSNRRZM4NMOHD7VL2BGZ53UWQCGFCCO7JPNWASYFTHH \ / AMOS7 \ YOURUM ::
#\[7]4QD5R2Q7OU7Q56P5JWHGTQFGRRLNGJOMAQMGF4LAUIXOZLNFL4CQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
