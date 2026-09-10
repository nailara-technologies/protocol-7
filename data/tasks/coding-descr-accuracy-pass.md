## [:< ##

# name  = task: descr accuracy pass over most-depended-on modules
# descr = correct and complete '# descr =' header lines, source-verified
# param = first pass, top 60 by dep-graph caller count

## context

spin-off from `data/tasks/coding-catalog-retrieval-phase2.md`. that task
tested whether enriching `# descr =` text would improve an embedding-based
module-retrieval feature. it did not, on any of three attempts, and that
thread is closed. what survived it is an independent finding, stated in
that file's section 3:

> **prioritize descr improvement on documentation grounds, not retrieval
> grounds.** it raises accuracy where a descr is vague or wrong [ ... ] a
> fluent-but-wrong descr is worse than a terse-but-right one.

so this pass is documentation work only. nothing here is claimed to help
retrieval, and no retrieval measurement was taken.

nobody had gone through these lines before. the free ranking signal from
the parent task -- dep-graph reverse-edge caller count -- decides which
ones get looked at first.

## confirmed mechanism [ read from source, not assumed ]

### two length rules, not one

`src/coding.tools.handler.module_convention_check` runs **two** checks and
the parent task file only documented one of them:

- **check 2** -- `descr` text longer than `max_descr` [ default **55** ],
  applied only when the relative path matches `\.(cmd|console)\.`
- **check 1** -- any **header** line longer than `max_line` [ default
  **78** ], applied to **every** module. `$in_header` stays true from the
  first line until the first non-comment non-blank line, so it covers the
  whole `# name / # descr / # param / # note` block.

check 1 therefore caps non-`.cmd.` descr text at 78 minus the prefix:
**68 chars** with the usual `# descr = ` [ 10 ], **67** in files that
align `=` one column further for a longer field name such as
`# return =`. "uncapped" was wrong.

verified empirically before relying on it: a local reimplementation of
both checks flagged exactly two pre-existing violations inside the
candidate set -- `base.is_defined_recursive` [ 80-char line ] and
`base.parser.timestamp` [ 79 ] -- both of which this pass fixed as a side
effect of correcting their text. every touched file was re-run through
that checker afterwards; all 24 come back clean.

`.git/hooks/pre-commit` enforces only the 55-char rule, and selects files
by the looser pattern `^src/.*cmd` [ substring, not `.cmd.` ]. no file
touched by this pass matches it, so the 55 cap never applied here -- the
68 line cap did, and every replacement was length-checked against it with
a script rather than estimated.

### ranking

reverse edges parsed out of `data/md/documentation/module-dependency-graph.asc`
with the same `source : callee ...` parse `bin/dev/depgraph-corpus` uses
[ `parse_adjacency` ], caller = number of distinct modules naming it as a
callee, self-edges dropped. top of the list: `base.logs` 1695,
`base.log` 1019, `base.s_warn` 261, `base.event.add_timer` 242. matches
the counts in `data/src-review/caller-counts.asc`.

## hazards

- **the correctness bar is zero inaccuracies.** a wrong-but-fluent descr
  is worse than a terse-but-correct one, and there is no target number of
  files. anything not confidently justifiable from the module body was
  left alone. plenty of accurate-but-plain lines were deliberately not
  polished: `base.logs` "'base.log' sprintf wrapper", `base.s_warn`
  "warn sprintf wrapper", `base.event.add_timer` "install a timer
  watcher", `base.log` "generate a log entry", `base.swap_subs`,
  `base.buffer.add_line`, `base.stream.push`, `format.yaml.*` and others
  were all read and left untouched.

- **`data/src-review/*.md` records are drafts, not ground truth**, and one
  of them was caught being wrong here. the `base.file.slurp` review claims
  its SCALAR branch reads a single line via `readline` while ARRAY reads
  the whole file, and calls the existing descr ["loads a file into memory"]
  contradicted by that. reading the module: the SCALAR branch sets
  `local $INPUT_RECORD_SEPARATOR = undef` before `readline`, which slurps
  the entire file. the descr is correct and the review is not. **that
  module was the single most-called candidate for a "correction" and it
  would have been a fabricated defect.** reviews were used only as
  pointers to look somewhere; every change below is justified from the
  module body.

- **`.cmd.` / `.console.` modules are excluded from this pass entirely.**
  at a 55-char cap with a ~42-char median they have roughly two words of
  headroom, which is not where correction value is.

- **net-new descr lines carry more risk than corrections**: there is no
  original-author intent to cross-check against. they were restricted to
  modules whose whole body is short enough to read in one pass and whose
  behavior is unambiguous. `base.protocol-7.command.send.local` [ 184
  callers, no descr ] and `crypt.C25519.key_vars` [ 63 callers, no descr ]
  were both deliberately **skipped** for exactly this reason -- large
  bodies with routing / identity-resolution subtleties where a one-line
  summary would be a real claim rather than a reading.

- no signature footers were touched or fabricated. every edited file now
  carries a stale-but-real footer; a human re-signs separately.

## scope

top 60 `src/` modules by caller count [ range 1695 down to 19 callers ].
each was read in full from source. 24 were changed: 8 corrections, 16
additions. 36 were read and deliberately left as-is.

adds outnumber corrections, which is the opposite of what a "fix wrong
lines" framing predicts. the reason is factual rather than chosen: among
the 60 highest-caller modules, **18 have no `# descr =` line at all**.
the existing lines are, on the whole, honest -- the documentation gap at
the top of this codebase is absence, not error.

## results

### corrections [ 8 ] -- existing line wrong, misleading, or over-length

| module | callers | was | now |
|---|---|---|---|
| `base.is_defined_recursive` | 40 | `return TRUE if %data key exists, 5 when defined and 0 when not present` | `TRUE when %data key path resolves, FALSE otherwise` |
| `base.parser.timestamp` | 16 | `returns diffenent time-stamp strings for specified unix-\current time` | `date \ time \ time-stamp string for unix or ntime value` |
| `base.file.zenka_dir.write` | 73 | `create file [entry] in /var/protocol-7/zenka/..,` | `write file in /var/protocol-7/zenka/.., [ or /etc/.., ]` |
| `base.file.zenka_dir.load` | 47 | `load file from in /var/protocol-7/zenka/.., [ or /etc/.., ]` | `load file from /var/protocol-7/zenka/.., [ or /etc/.., ]` |
| `plan-9.protocol.codec.encode-message` | 31 | `Encode 9P message header` | `encode a 9P message [ header and payload ]` |
| `base.cfg_bool` | 100 | `interprets boolean configuration options and returns TRUE \ FALSE` | `interprets boolean configuration options [ undef if unknown ]` |
| `base.file.make_path` | 77 | `recursively create a directory path` | `recursively create dir path, apply mode and ownership` |
| `base.file.zenka_dir.data_path` | 31 | `return data directory path for current zenka` | `data dir path for current zenka [ /var/.., or /etc/.., ]` |

reasoning, per change:

- **`base.is_defined_recursive`** -- the old line describes a three-valued
  return [ "TRUE if exists, 5 when defined, 0 when not present" ] that the
  code does not produce. both the defined branch and the exists-only
  branch are literally `return TRUE`, and `TRUE => 5`, so "exists" and
  "defined" return the *same* value; the inline comments `## defined [5] ##`
  and `## only exists [1] ##` record an intent the code does not
  implement. the new line states the two outcomes that actually occur.
  it also cleared the file's 80-char header-line violation.
  the wording is "key **path** resolves", not "key exists", on purpose:
  the traversal is `return FALSE if not defined $next_ref->{$subkey}`
  for every intermediate segment, so a terminal key that exists under a
  path whose intermediate node is undef still yields FALSE. an `exists`
  phrasing would have described the last segment only and over-claimed.
  [ a third outcome exists too -- `return if not @dtree` on invalid key
  syntax -- deliberately not squeezed into the line. ]
  **note for a human: the comment/code mismatch is left in place -- if the
  1-vs-5 distinction was intended, that is a code bug and out of scope
  for a documentation pass. flagging it, not fixing it.**

- **`base.parser.timestamp`** -- typo "diffenent", and 79-char header line.
  the body returns `YYYY-MM-DD HH:MM:SS`, `HH:MM:SS`, or `YYYY-MM-DD`
  depending on a `time|time-stamp|date` mode argument, from either a unix
  time or an ntime value [ `length(int) >= 13` routes through
  `base.n2u_time` ], defaulting to now. the new line names the three modes
  and both accepted time formats and fits the cap.

- **`base.file.zenka_dir.write`** -- the old line names only
  `/var/protocol-7`, but a `cfg-dir:` path prefix switches the base to
  `$zenka_dir_href->{'etc_P7'}` [ `/etc/protocol-7` ], exactly as in the
  sibling `.load` module whose descr does say so. "create" also
  under-describes it: `$open_mode_str` defaults to `>` but append is
  supported. new line mirrors the sibling's phrasing.

- **`base.file.zenka_dir.load`** -- pure typo fix, "load file from in".

- **`plan-9.protocol.codec.encode-message`** -- it does not encode a
  header. `return pack('V C v', $size, $type, $tag) . $payload` returns a
  complete 9P message, header **and** payload, with `$size` counting the
  payload. also the only capitalized descr in the candidate set, against
  the repo's lowercase convention.

- **`base.cfg_bool`** -- "returns TRUE \ FALSE" omits the third outcome:
  a value matching neither the false set `('' 0 -1 n no false)` nor the
  true set `(y yes 1 5 true)` warns via `base.s_warn` and returns
  **undef**. callers testing the result as a boolean get a materially
  different behavior there, so the omission is the misleading kind. the
  original wording is kept verbatim and only the bracket annotation is
  appended -- naming all three outcomes inline
  [ `... options : TRUE \ FALSE \ undef` ] would have forced
  "configuration" down to "config" to stay under the 78-char line, and a
  minimal diff is worth more here than the symmetry.

- **`base.file.make_path`** -- "recursively create a directory path" hides
  the surprising half: on a path that **already exists** the module still
  compares `base.path_perms` against `$param_mode` and `chmod`s on
  mismatch, and compares `base.path_owners` against the optional
  owner/group args and `chown`s on mismatch when `$EUID == 0`. there is no
  `# param` line, so the mode/owner/group arguments were undocumented
  entirely. "apply mode and ownership" covers both the create and the
  existing-path path without over-claiming.

- **`base.file.zenka_dir.data_path`** -- first argument `$global_config`
  selects `etc_P7` over `var_P7`; the old line documents neither the
  argument nor the `/etc` outcome. phrasing kept parallel with the two
  sibling `zenka_dir` modules.

### additions [ 16 ] -- no descr line existed

each of these has a body short enough to read whole; the justification is
the body itself.

| module | callers | added descr |
|---|---|---|
| `base.str.os_err` | 138 | `format $OS_ERROR into an error string [ no caller info ]` |
| `base.sort` | 107 | `sort strings by length, shortest first` |
| `base.str.eval_error` | 104 | `format $EVAL_ERROR into an error string [ caller level ]` |
| `base.gen_id` | 90 | `random id, unused in hashref, harmonic by default` |
| `base.cnt_s` | 80 | `plural suffix for count [ 's' unless count is 1 ]` |
| `base.reverse-sort` | 50 | `sort strings by length, longest first` |
| `base.file.put` | 48 | `write string, arrayref or scalarref content to a file` |
| `mpv.send_command` | 46 | `send JSON IPC command to mpv [ buffered until ready ]` |
| `crypt.C25519.key_exists` | 29 | `check for C25519 key in user key dir [ 4 : virtual ]` |
| `base.file.all_files` | 26 | `list files in a directory [ optionally recursive ]` |
| `plan-9.protocol.codec.decode-uint32` | 26 | `decode little-endian uint32 from a byte string` |
| `httpd.new_header` | 24 | `build HTTP/1.1 response header [ status, params ]` |
| `plan-9.protocol.codec.encode-uint32` | 24 | `encode integer as little-endian uint32 bytes` |
| `base.chk-sum.bmw.filesum` | 22 | `BASE32 BMW file checksum [ 224 256 384 512 bit ]` |
| `base.prng.chars-anum` | 22 | `random alphanumeric string of requested length` |
| `base.zenki.report_child_pid` | 21 | `register a child process pid for reporting` |

the ones worth spelling out:

- **`base.sort` / `base.reverse-sort`** -- the least guessable pair in the
  set, and the reason a missing descr here is a real gap rather than a
  cosmetic one. neither sorts alphabetically. both funnel arguments
  through `base.context.list` [ flattening hash / array / scalar refs ],
  drop undefs, then sort by **string length** -- `base.sort` ascending,
  `base.reverse-sort` descending -- with a `reverse sort` applied first so
  ties fall out in reverse-alphabetical order. a caller reading the name
  alone will assume the wrong thing.
  [ incidental find, not acted on: `base.callback.cmd_reply`'s TREE branch
  carries the comment "sorted by ref_count descending (base.reverse-sort)"
  -- `base.reverse-sort` sorts by length, not by any ref_count. either the
  comment or the call is wrong. flagged, untouched, out of scope. ]

- **`base.str.os_err` / `base.str.eval_error`** -- one-liners over
  `base.format_error`, whose second argument is a caller level. `-1`
  suppresses the appended `[file:line]` location [ the `$c_lvl >= 0`
  gate ]. `os_err` hardcodes `-1`; `eval_error` takes it as an optional
  argument defaulting to `-1`. hence the differing bracket annotations.

- **`base.gen_id`** -- generates a random numeric id from the weighted
  `01234577790` digit set, first digit non-zero, retried until it collides
  with no key of the passed hashref **and** [ default on ] satisfies
  `AMOS7::Assert::Truth::is_true`. "unused in hashref" rather than
  "unique" because the module never inserts anything -- it only avoids
  existing keys. this file aligns `=` at a wider column [ `# name   =`,
  `# return =` ], so the added line uses `# descr  =` to match.

- **`crypt.C25519.key_exists`** -- the `4` is real and not incidental: a
  single match ending in `:seed-phrase` returns `4` for a virtual key,
  distinct from `TRUE` / `FALSE` / `undef`. a caller doing a plain boolean
  test cannot see it, so it belongs in the one line the module gets.

- **`base.chk-sum.bmw.filesum`** -- the bit size is validated against
  exactly `224|256|384|512` and the digest is returned `encode_b32r`.
  descr placed after `# name`, ahead of the file's existing `# note` and
  `# param` lines.

- **`mpv.send_command`** -- serializes to JSON via `mpv.json.command`,
  files reply bookkeeping under a per-command `request_id`, and when
  `<mpv.socket>` is not yet defined pushes the string onto
  `<mpv.pending_commands>` for replay by
  `mpv.startup.handler.socket_ready` instead of writing. the buffering is
  the part a caller needs to know about.

### left alone deliberately -- a sample, with why

- `base.file.slurp` [ 147 ] -- descr correct; see the src-review hazard above.
- `base.log` [ 1019 ] -- "generate a log entry" is not wrong. it also
  dispatches to buffer / console / stdout-log under verbosity gates, but
  making that fit is a rewrite by preference, not a correction.
- `base.perlmod.loaded` [ 55 ] -- "return true when a module is loaded" is
  mildly imprecise: it reads the `<base.perlmod.loaded>` registry that
  only `base.perlmod.register_loaded_module` writes, so a module pulled in
  by a plain `use` elsewhere reads as not loaded. judged below the bar --
  a real but small distinction, and the rewrite risks being less clear
  than the original. **noted here in case a later pass disagrees.**
- `base.net.send_to_socket` [ 40 ] -- "write data to client" is correct.
  its return convention [ `FALSE` on success, `2` on error ] is the
  genuinely surprising part and does not fit one line alongside the
  purpose.
- `base.protocol-7.command.send.local` [ 184 ], `crypt.C25519.key_vars`
  [ 63 ] -- no descr, deliberately still none. see hazards.

## verification performed

- both convention checks reimplemented from
  `coding.tools.handler.module_convention_check` and run over all 24
  touched files: clean.
- then cross-checked against the **real** tool, live:
  `p7c coding.call-tool module_convention_check '{"path":"src"}'` --
  5473 files scanned, 400 issues, **none of them in the 24 touched
  files**. the reimplementation and the tool agree.
- that 400 is a pre-existing repo-wide backlog of over-length header
  lines, untouched by this pass and worth its own cleanup: the worst are
  well past the cap [ `powershell.plugin.screenshot-capture.invoke` at
  124, `letsencr.parent.init_code` at 116 ], which is a mechanical
  wrap/shorten job, not a descr-accuracy job.
- `git diff` reviewed line by line: 24 files, one `# descr =` line each,
  no other content altered in any of them.
- pre-existing violations resolved as a side effect: 2 [ the
  `base.is_defined_recursive` and `base.parser.timestamp` header lines ].

**not verified**: nothing was executed. this pass changes only comment
text in module headers, so there is no runtime behavior to test, but it
also means no zenka was started to confirm the files still load. a
`p7c coding.call-tool validate_module` sweep over the 24 would be a cheap
belt-and-braces check if one is wanted.

**unrelated working-tree changes**: `cfg/zenki/coding/zenka.v7` and
`cfg/zenki/zenki/start.cfg` were already modified when this pass started
[ catalog-harvest enablement, `zenki` on-demand flag ] and belong to
another task. they are **not** part of this one.

## what a second pass would do

- ranks 61 to ~200 by caller count, same method. the descr-absence rate at
  the top [ 18 of 60 ] suggests the addition-heavy shape continues.
- a cheap standalone probe worth having first: count modules with no
  `# descr =` line at all across `src/`, bucketed by caller count. that
  number decides whether this is a finite cleanup or a standing gap, and
  it is one script, no inference.
- `.cmd.` / `.console.` modules remain out of scope until someone wants to
  spend the two words of headroom deliberately.

#,,,.,...,..,,,..,,.,,...,,,,,..,,,.,,..,,.,,,..,,...,...,...,.,,,,,,,.,.,,,,,
#JT62X3LA72LR5CCQJPO6MZNNHFTQAD3FPX6OZZVTWMHUKR3QS742VKPOQ4UNDWANTSGEPUFJQQJ34
#\\\|KRQWOO5RKYW5JVZB27WNRMUSMQLVZU7KPSMBZUFYOO6PXCYUZD4 \ / AMOS7 \ YOURUM ::
#\[7]UV2KXBN2NMMPZ3336SIC4Q75DQ2B4VOL4GOQ4ADVT3KTPBB62ADY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
