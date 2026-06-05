## task: memory-source-adapters

## dispatch
implement three source adapters that read a source and emit lists of universal
leaf hashrefs: `memory.source.file`, `memory.source.session`,
`memory.source.git`. read first: `data/md/design/MEMORY-TREE-SYSTEM.md`
sections B (node schema) and F (source adapters);
`modules/context.memory.load` (markdown reading + signature-strip regex it
already uses); the ntime feedback note (`encode_b32r` is NOT sortable).
adapters do NOT touch the tree — they only return leaf lists. they can be
demoed standalone by printing the emitted leaf list.

## prompt
implement three `memory.source.*` adapter modules. each reads its source and
returns an arrayref of universal-leaf hashrefs. they never insert into the tree
themselves — the tree caller does that.

universal leaf shape every adapter must emit (fill what it can; leave `score`
at 0):
```perl
{ ntime => $b32, content_hash => $chksum, source_type => '<type>',
  title => $short, body => $text, score => 0, curve_type => '<suggested>' }
```
guidelines for every adapter:
- module header `## [:< ##`, `# name = memory.source.X`, `# descr =` lowercase
  under 55 chars.
- read files via the existing file API (`<[file.slurp]>` etc — see
  `context.memory.load`); never write `#,,.,,,...` stubs anywhere.
- compute `content_hash` with an AMOS checksum module (`base.chk-sum.*` /
  `AMOS7::CHKSUM::*` — pick what is already used for content hashing; if unsure,
  use a stable hex digest helper already present) over the canonical body.
- ntime: convert any source timestamp to BASE32 ntime form via the project's
  ntime helpers; store the b32 string. recency comparison happens downstream via
  `<[base.ntime_BASE32_to_numerical]>`, so adapters only need to store b32.
- lowercase narrative comments, `[ word ]` annotations.

1. `memory.source.file` — params `{ dir => 'data/ai-mem' }`. for each
   `*/*.md` file: strip the AMOS7 signature block (reuse the regex from
   `context.memory.load`), split into sections by `##`/`###` headings. each
   section → one leaf: `title` = heading text, `body` = section content,
   `source_type` = 'file', `source_ref` = `path#heading`. suggested curve_type:
   sections under a `CRITICAL` heading → `gaussian_pulse`, `Active Topics` →
   `quantized`, archive/completed → `exponential`, else `sigmoid`.

2. `memory.source.session` — read session-catchup summaries (find the source the
   `session_catchup`/`session-catchup.yaml` flow uses; if a session archive dir
   exists under `data/ai-mem/*/archive` or similar, read those). each session →
   one leaf, `source_type` = 'session', ntime from the session's recorded time,
   curve_type `exponential` (sessions age).

3. `memory.source.git` — run `git log` (bounded, e.g. last 200 commits) for the
   repo. each commit → one leaf: `title` = subject, `body` = full message,
   `source_ref` = short hash, `source_type` = 'git', ntime from commit date,
   curve_type `exponential` (commits decay by recency). use a bounded git
   invocation; do not stream unbounded history.

## acceptance
- three modules exist: `memory.source.file`, `memory.source.session`,
  `memory.source.git`, each returning an arrayref of leaf hashrefs.
- every emitted leaf has all universal fields populated (score may be 0).
- `content_hash` is a stable checksum of the body (identical body → identical
  hash, enabling later dedup).
- `memory.source.file` correctly strips signature blocks and splits markdown by
  heading; running it over `data/ai-mem` yields one leaf per section.
- `memory.source.git` is bounded (commit limit) and reads commit date as ntime.
- no manual AMOS7 signature stubs written into any source file or output.
- comments lowercase narrative; `[ ... ]` annotation style.

#,,,.,...,...,..,,,..,...,,,,,,,.,.,.,,..,..,,..,,...,...,,,,,.,.,...,,,,,.,,,
#G2VYPJ4PE4WFBH6SELZXXS4NACUXMZN4HZABHCUYXC7YSEURLM7BFFYG3XILMTPALMKHV32UN2NQA
#\\\|2OTCSNWXR5ZSYCYH5DWRR2SJMV6YRHEMYKULLOOZ3BMBOBU6ANF \ / AMOS7 \ YOURUM ::
#\[7]UIEOJ7MNICDUMCNGMQHBGKWGLRG23PY4HVCPKXI34ZEEAIJ2SAAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
