# task: code repository indexing pipeline for space.v7.ax

## why

this implements sub-component 5.2 from
`data/md/design/SEARCHABLE-INDEX-SESSION-STATE.md` — the first
persistent / on-demand index built from the 5.1 grid scan primitive.
the difference from 5.1 is that 5.2 **writes the index to disk** as
JSON + YAML, **adds a content checksum** per file, and exposes a
**rebuild command** that is cron-able.

read section 5.2 of the session state document before starting.

## what already exists — the pattern to follow

section 5.1 [ completed, commit `79b72f002` ] built the live in-memory
grid scan for `space.v7.ax`. it already produces the shape:

```
{ path, rel_path, gen_path, size, mtime }
```

per file, populated by `plugin.web.space.grid.scan` and served via
`plugin.web.space.grid` to `/grid.json`.

5.2 is the persistent, checksummed, on-demand variant of that same
pipeline. **reuse the 5.1 pattern.** do not invent a new one.

relevant existing modules to study:

- `modules/plugin.web.space.grid.init_code` — cache + cfg setup
- `modules/plugin.web.space.grid.scan` — directory walk, gen_path
  computation, cache population
- `modules/plugin.web.space.grid` — template command with section
  dispatch [ summary / json / json-raw ]
- `/var/httpd/space.v7.ax/grid.json.tmpl` — json endpoint template

## what to build

### new modules

all under `modules/plugin.web.space.index.*`:

1. **`modules/plugin.web.space.index.init_code`**
   - sets up `<web.space.index.cache>` hash
   - sets `<web.space.index.cfg.target_dir>` default — propose
     `modules` [ project's primary content, ~1700 files, bounded ]
   - sets `<web.space.index.cfg.persist_dir>` default — propose
     `var/index/space.v7.ax` [ resolve against project root ]
   - sets `<web.space.index.cfg.checksum_bits>` default — propose
     `512` [ passes to `<[chk-sum.bmw.filesum]>->(512, $path)` ]
   - on init, **call `plugin.web.space.index.load`** to populate
     cache from disk if a prior index file exists [ idempotent startup ]

2. **`modules/plugin.web.space.index.scan`**
   - walks the configured target directory [ mirror
     `plugin.web.space.grid.scan` recursion ; do NOT use File::Find ]
   - for each regular file:
     - compute content checksum via
       `<[chk-sum.bmw.filesum]>->(<web.space.index.cfg.checksum_bits>, $full_path)`
     - compute coordinate via `<[index.gen_path]>->(\$checksum)` [ seed
       is the checksum itself, not the path — this is what distinguishes
       5.2 from 5.1, the gen_path reflects **content** ]
     - stat the file using `File::stat::stat($path)->size / ->mtime`
       [ CRITICAL — see "known pitfalls" below ]
   - populates `<web.space.index.cache>` with:
     ```
     {
       target_dir  => 'modules',
       file_count  => N,
       cells       => [
         { path, rel_path, checksum, gen_path, size, mtime },
         ...
       ],
       timestamp   => epoch,
     }
     ```
   - returns the populated cache hashref

3. **`modules/plugin.web.space.index.persist`**
   - writes `<web.space.index.cache>` atomically to disk as BOTH:
     - `<persist_dir>/modules.json` — via `JSON::XS::encode_json`
     - `<persist_dir>/modules.yaml` — via `YAML::XS::Dump` or
       `YAML::Tiny` [ check what the codebase already loads ]
   - atomic write pattern: write to `.tmp` sibling, rename over target
   - creates `persist_dir` with `<[base.file.mkdir_p]>` if missing
     [ check codebase for existing mkdir idiom — `mkpath` or similar ]
   - returns TRUE / FALSE

4. **`modules/plugin.web.space.index.load`**
   - reads `<persist_dir>/modules.json` [ prefer json for loading,
     yaml is the eyeballing / perl-native variant ]
   - parses and populates `<web.space.index.cache>`
   - returns FALSE silently if no file yet [ fresh zenka, pre-rebuild ]
   - returns TRUE on successful load

5. **`modules/plugin.web.space.index.cmd.rebuild`**
   - the on-demand trigger; callable via `p7c web.index-rebuild`
     [ the `cmd.` prefix is stripped by the dispatcher — confirm by
     checking how `plugin.web.space.grid` is exposed, if at all ]
   - runs: scan → persist → return status
   - reply shape: `{ file_count, duration_ms, persist_paths => [...] }`
   - protect against re-entry: if a scan is already in progress, return
     early with a `busy` status [ set `<web.space.index.running>` flag ]

6. **`modules/plugin.web.space.index`**
   - template command, mirror `plugin.web.space.grid` section dispatch
   - sections:
     - `summary` — html fragment: target_dir, file_count, last
       rebuild timestamp, persist paths. style-match existing
       `.space-state` classes [ `#0a0412`, `#7080c0`, `#4030a0` ]
     - `json` — `<script>window.spaceIndex = {...};</script>`
     - `json-raw` — raw json for api endpoints
     - `yaml-raw` — raw yaml for perl clients and humans
   - handles empty cache case [ return placeholder, do NOT auto-scan
     here — scanning is explicit via rebuild command only ]

### new templates

in `/var/httpd/space.v7.ax/`:

- **`index.json.tmpl`** — one line:
  ```
  <[web.response.content_type:application/json]><[plugin.web.space.index:json-raw]>
  ```
- **`index.yaml.tmpl`** — one line:
  ```
  <[web.response.content_type:application/yaml]><[plugin.web.space.index:yaml-raw]>
  ```

**both endpoints are default** — this follows the project's parallel
JSON+YAML convention [ see `feedback-web-serialization-and-inlining`
in the memory layer, if you have access ]. JS clients hit `.json`,
perl clients and humans hit `.yaml`.

### update existing overlay

add a small status block to `/var/httpd/space.v7.ax/index.tmpl`:

- one additional `<[plugin.web.space.index:summary]>` section below the
  existing grid/state blocks
- no new js needed — this block is read-only status, no interactive
  view in 5.2

keep inline styling consistent with the existing overlay. no new
stylesheets. if js is needed for anything, inline it in the template.

### configuration

add to `cfg/zenki/web/start` near the `plugins.load` line:

```
plugins.load = plugin.web  ## already there
```

no change needed to plugins.load — `plugin.web.space.index.*` matches
the `plugin.web` prefix. but do **regenerate the whitelist** with
`gen-sub-whitelist web` after adding the new modules so they're
loadable.

## style rules — MUST follow

1. **no `sub { ... }` wrappers** — the filename IS the subroutine.
   mimic `modules/plugin.web.space.grid.scan` exactly.

2. **use `$ARG` not `$_`** — in `map`, `grep`, `for`, everywhere.

3. **lowercase comments** — `## walk target dir ##` not
   `## Walk Target Dir ##`

4. **bracket annotations** — `[ word ]` not `( word )` in comments

5. **`qw| word |` style** for barewords

6. **no signature stub lines** — no `#,,.,,,...` lines at file end.
   leave clean; the signing tool adds the real 4-line footer.

7. **module invocation** — `<[module.name]>->($arg)` with `]>` before
   `->`. never `<[module.name]->($arg)`.

## known pitfalls — READ BEFORE CODING

### File::stat shadows builtin stat()

`bin/Protocol-7` does `use File::stat` at top-level, which shadows the
builtin `stat()` **everywhere** in P7. calling `stat($path)` in list
context returns a File::stat object as a single element — NOT the
13-element list. so:

```perl
##  WRONG — silently gives undef,undef  ##
my ( $size, $mtime ) = ( stat($path) )[ 7, 9 ];

##  CORRECT — OO form, matches rest of P7  ##
my $st = File::stat::stat($path);
my ( $size, $mtime ) = $st ? ( $st->size, $st->mtime ) : ( 0, 0 );
```

this bit the 5.1 implementation. do not repeat.

### index.gen_path is available in the web zenka

confirmed loaded via `cfg/zenki/web/start:9`. call as
`<[index.gen_path]>->(\$seed)` where `$seed` is a string or scalar ref.
returns a `/`-separated coordinate tuple string.

### atomic file writes

use open/print/close/rename, not a direct write over the final path.
prior p7-log events have shown that partial-write visibility is a real
issue on this host. check codebase for an existing atomic-write helper
before writing your own.

## acceptance criteria

1. `ptd -c` passes for all 6 new modules
2. `p7c web.reload` [ or equivalent ] reloads web without errors
3. `p7c web.index-rebuild` completes, returns file_count matching the
   number of regular files under `modules/`
4. `<persist_dir>/modules.json` and `<persist_dir>/modules.yaml` exist
   after the rebuild, both parseable, both containing the full index
5. HTTP GET to `http://space.v7.ax/index.json` returns the index as
   JSON with correct content-type `application/json`
6. HTTP GET to `http://space.v7.ax/index.yaml` returns the index as
   YAML with correct content-type
7. **idempotency**: running rebuild twice with no file changes produces
   identical `modules.json` contents [ byte-for-byte if json key order
   is stable, or parse-equal otherwise ]
8. restarting the web zenka does NOT lose the index — `init_code.load`
   restores it from disk
9. no `$_` usage in any of the 6 new modules
10. no `sub { ... }` wrappers in any of the 6 new modules
11. no bare `stat(` calls as list-context [ all stats go via
    `File::stat::stat` ]

## verification steps

before marking complete:

1. `ptd -c modules/plugin.web.space.index.init_code`
2. `ptd -c modules/plugin.web.space.index.scan`
3. `ptd -c modules/plugin.web.space.index.persist`
4. `ptd -c modules/plugin.web.space.index.load`
5. `ptd -c modules/plugin.web.space.index.cmd.rebuild`
6. `ptd -c modules/plugin.web.space.index`
7. grep for `\$_` in the 6 new modules → empty
8. grep for `^return sub` in the 6 new modules → empty
9. grep for `(^|\W)stat\s*\(` in the 6 new modules → only lines that
   use `File::stat::stat` or `CORE::stat` [ should be no bare stat ]
10. after rebuild, `head -c 2000 <persist_dir>/modules.json`
11. after rebuild, `head -30 <persist_dir>/modules.yaml`
12. `curl -sS --noproxy '*' -H 'Host: space.v7.ax' http://127.0.0.1/index.json | head -c 2000`
13. `curl -sS --noproxy '*' -H 'Host: space.v7.ax' http://127.0.0.1/index.yaml | head -30`

## not in scope

- do NOT implement search / query [ 5.4 ]
- do NOT implement deduplication detection [ 5.5 ]
- do NOT implement the checksum filesystem store/retrieve [ 5.3 ]
- do NOT touch `modules/index.*` infrastructure [ consume
  `index.gen_path` via `<[...]>`, nothing more ]
- do NOT re-scan on HTTP request [ scanning is explicit via
  `web.index-rebuild` command ; HTTP serves the persisted snapshot ]
- do NOT add a cron entry — the task says "cron-able", meaning the
  command must be safely callable from cron. do not actually install
  cron yet.

## references

- session state doc: `data/md/design/SEARCHABLE-INDEX-SESSION-STATE.md`
  [ section 5.2 is the direct spec ]
- 5.1 completed work, to mimic: `modules/plugin.web.space.grid*`
- checksum primitive: `modules/base.chk-sum.bmw.filesum`
  [ signature: `filesum($bit_size, $file_path)` → base32r string ]
- coordinate primitive: `modules/index.gen_path`
- json endpoint template pattern: `/var/httpd/space.v7.ax/grid.json.tmpl`

#,,,.,,,.,.,,,,..,.,,,,..,...,.,.,,,.,...,.,.,..,,...,..,,..,,.,.,,.,,.,.,,,,,
#2K6VBCNII3MPR4XRHI5HFRCIVZCBH4TKQ7CX7ITK2P32TVUB2D42NXP2PMWKR6WAVBKVPNKVMQ6MW
#\\\|2EIHK6H6TPHUJA5LXC5LPE3I4KRJYPBSZK6KFW6ONQVQ7IX5R4F \ / AMOS7 \ YOURUM ::
#\[7]OE3WSH6TC5PWZSHIEBBEBTF6M7WNER237UKSNFVRV2GPF4FXLIBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
