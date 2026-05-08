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

**How to apply:** Any time generating or reviewing code that reads/writes files in a P7 module, verify the call matches one of the above signatures exactly. Never use `base.file.slurp` directly — always use the swapped short name `file.slurp` (or preferably `file.read`).

#,,.,,,.,,,,.,.,,,,..,.,,,,,,,,.,,,,,,..,,,,.,..,,...,..,,..,,,..,...,.,.,.,,,
#PEVVS4L5UPTL3D3UFKLDUGZVTZQNKAQ2YSJG5Z7XWQG2MYBJ3ZGHRWZ5P4WAC724YKQSOF7H67HTS
#\\\|343KUNMWQ4BQLIL762X6MRCR7JSGFKPPKACZCNYASA76WSZOGJS \ / AMOS7 \ YOURUM ::
#\[7]Q3XYB7NJCEMJE2KG62VHDRL432TXCNGB2HQPNKITFWSEYATDXCDQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
