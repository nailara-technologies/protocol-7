# inline doc format inventory [ src/ ]

scope : 5899 module files under `src/`, all starting with the `## [:< ##`
marker line. module format per `CLAUDE.md` : marker, blank, `# key = value`
header block, blank, code. loaders : `bin/Protocol-7` ~line 2895 [ sub source,
with continuation append ] and ~line 2199 [ file header, first `param =` /
`descr =` line only, `<< missing 'descr' >>` fallback ]. consumer stub :
`src/base.console.describe`. read-only analysis, 2026-10-08, branch `base`.

## 1. header key lines `# <key> = value`

file-level presence in the header block [ key counted once per file ] :

| key        | files | notes |
|------------|-------|-------|
| name       | 5895  | near-universal; `# name  =` [ 2 spaces ] aligned with descr/param |
| descr      | 4884  | 1015 files have no descr at all [ 946 are `name`-only headers ] |
| param      | 1407  | argument spec, freeform text |
| return     | 287   | mostly `models.*`, `keys.*`, `plugin.*` |
| note       | 253   | often multi-line, aligned continuation |
| args       | 117   | mostly older `base.chk-sum.bmw384.*` |
| purpose    | 91    | almost only newer `coding.*` |
| todo       | 63    | |
| usage      | 21    | literal invocation line |
| notes      | 15    | plural variant of note |
| returns    | 13    | plural variant of return |
| installed_by | 5   | keys.* |
| one-offs   | ~120  | nonce, op, url, mode, version, handler, protocol, old-form, typed, encrypted, group, comment ... [ 1-3 files each, see counts dump ] |

total distinct keys seen anywhere in files : ~190; beyond the top ~15 the
long tail is mostly body-comment text that happens to match `# word =`.

top key sequences [ order matters for the loader ] :
- `name, descr` : 3099
- `name` : 946
- `name, descr, param` : 612
- `name, param, descr` : 416
- `name, descr, param, return` : 130
- `name, descr, note` : 100 ; `name, descr, purpose` : 89

examples :

```
src/base.init_code:2       # name  = base.init_code
src/base.init_code:3       # descr = initializing base module
src/keys.backup.create:4   # param = <key_name>, <types_arrayref>
src/models.backend.coding.invoke:6   # return = nothing (response handled by callback)
src/coding.async.chunk_handler:5     # purpose = Phase 2/3: Process chunks, detect tool calls, ...
src/auth.zenka.cmd.session-key:6     # todo  = parameter validation ..,
```

multi-line continuation styles [ 889 files have multi-line descr, 19 continue
other keys ] : indentation histogram of `#`-continuation lines inside header
blocks [ leading-space count ] :

| indent | count | style |
|--------|-------|-------|
| 9      | 1779  | value-aligned under `# descr = ` [ dominant ] |
| 10     | 329   | aligned under `# param = ` / `# return = ` |
| 1      | 1342  | single space after `#` [ freeform blocks, newer modules ] |
| 3      | 184   | aligned under `# note  = ` |
| 7,8,11,5,... | ~150 | misc aligned |

real examples :

```
src/coding.init_code:3-5    # descr = initialize coding zenka state, task queue, budget,
                            #         and event handlers
src/keys.backup.list:4-5    # param = [ <key_name> ]  optional filter
src/model_batch.gate.check:6-12  # note  = ... :        [ 9-space aligned ]
                                 # param = { batch_id =>, force => 0|1 } ->
                                 #         { clean => 1, baseline => href }  [ clean ]
                                 #       | { clean => 0, diff => href }      [ refuse ]
src/plugin.storage.p7ref.init_code:4-10   # blank `#` separators + 2-space
                                 #   indented sub-lines inside the header block
```

## 2. comment decoration styles

| style | count | where |
|-------|-------|-------|
| `## text ##` full-line boxed | ~18.2k lines, in all 5899 files | body section banners |
| inline trailing `code    ## comment ##` | ~29.6k lines [ grep `##.*##$` ] / ~3.7k strict ` \S+ ## .. ##` | dominant body-comment style |
| `##  text  ##` double inner spaces | 1537 | older banner style |
| `##[ text ]##` | 224 | mostly ascii/box helpers + section markers, e.g. `src/base.cmd.commands:51 ##[ format and return the command list ]##` |
| `##[ TITLE ]####...` hash-run underline | 2+ | `src/base.chk-sum.amos:38 ##[ CHECKSUM CALCULATION ]####...` |
| `### text ###` / `####` | 138 | rare, ad-hoc emphasis |
| `: [ freeform ] :` colon-brackets | ~6421 ` \ ` sep hits incl. qw\|; e.g. `src/audio.handler.pcm_data:54 :[ eof on this stream ]:` | log/label strings |
| `.:[ text ]:.` | handful | tracker/label strings, `src/base.perlmod.init_install_buffers:15` |
| `:.` log prefix | ~657 | `:. plugin '%s' already loaded` [ log messages, not doc ] |
| `'.. text ..,'` / `. ,'` string wrap | ~475 | end-of-message marker inside quoted strings, e.g. `# todo = parameter validation ..,` |
| `\` separators | 6421 | `qw| A \ B \ C |`, paths, ` \ / AMOS7 \ YOURUM` |
| `[ ... ]` inline annotation | ubiquitous | `[ optional ]`, `[ default : 0 ]`, `[ one-shot ]`, `[ cached ]` |
| `;,` / `:,` mid-sentence separators | common in newer verbose descr | `failure ; returns { ... }` |
| eof signature block | all 5899 files | `#,,,.,..` noise line, `#\\\|...` + `#\[...` base32 signature, `:::...::` rule [ not documentation, but part of every file's tail ] |

right-aligned closing `##` [ banner box right edge padded to ~col 79 ] :

```
src/base.init_code:9   ## register 'base' as a source dependency here, not at bootstrap : the    ##
src/base.event.add_idle:7   ##  [ repeat => 0|1 ],       ##  default : 0 [ one-shot ]  ##
```

boxed-line example with double spaces and `:` body :

```
src/base.cmd.list:7-13   # descr = display named lists with content +opt.regex
                         #
                         # USAGE:
                         #   commands [pattern]
```

## 3. per-argument documentation today

no dedicated per-argument format exists. observed styles, by frequency :

1. freeform `# param =` line, angle-bracket or plain scalar list [ majority ] :
   `src/keys.backup.create:4` `# param = <key_name>, <types_arrayref>`
   `src/keys.backup.remove:4` `# param = <key_name>, <type>, <backup_basename_or_path>, [ \%opts ]`
2. optional-flag idiom inside the param line : `src/keys.backup.list:4`
   `# param = [ <key_name> ]  optional filter`
3. hashref signature with ascii table continuation [ newer model_batch/storage ] :
   `src/model_batch.gate.check:8-12` `# param = { batch_id =>, force => 0|1 } ->` + aligned `| { clean => 0, diff => href }   [ refuse ]` rows
4. `# args  = $digest_bytes` scalar list [ older base.chk-sum.bmw384.* : 117 files ]
5. args hidden in descr continuation : `src/X-11.emit.screen-change:5`
   `#         args: $width, $height (optional; reads cached dims if omitted)`
6. `# usage = <[base.fh-encoding.set]>->($fh, $encoding_mode)` literal call [ 21 files ]
7. return-shape tables with `| undef [ ... ]` rows :
   `src/trust.pin_decide:9`, `src/model_batch.gate.check:11-12`
8. body `## comment ##` notes near `my $x = shift` lines [ pervasive, informal ]

## 4. multi-line descr and loader breakage

the ~2895 loader appends every `# <non-key> text` line after `# descr =`
within the header block [ up to blank line ] onto descr, stopping only at
`\w+ =` lines and `# line N` directives. 181 headers contain lines that would
leak non-description text into descr [ heuristic: `[ x ] y`, `word: rest`,
section labels ending `:` ]. examples :

```
src/storage.9p.filter-check:5-7    # Logic:
                                   # inclusion_add:  [A, B, C] => match if ...
src/plugin.storage.p7ref.init_code:6-10   # P7REF Format: / #   p7://... / # Examples:
src/base.cmd.list:7-13             # USAGE: / #   commands [pattern]
src/X-11.emit.screen-change:5      #         args: $width, $height ...
src/amos-term.interaction.ask:11   # Usage: <[...ask]>->( $question, $reply_handler, $context )
src/auth.client.server_pin.check:11  'C client ], this module only does the file io :'
src/base.event.add_idle:7-9        ##  [ repeat => 0|1 ], ... ## / "# [ desc => 'str' ] }"
```

note : the ~2199 loader does NOT append continuations [ first descr line only ],
so `commands` listings already silently truncate ~889 multi-line descr.
keys appearing after `descr =` in the same block [ safe from append, but
order-dependent ] : param 895, return 280, note 242, purpose 91, args 69, todo 32.

## 5. namespace / era differences

| namespace | character |
|-----------|-----------|
| base.* [ 744 ] | oldest; short 1-line descr [ 250 files descr-less ], `## banner ##` boxes, `args =` in bmw384 cluster, rare param |
| X-11.*, amos-term.*, mpv.*, web-browser.* | older; terse, `todo` used, `##  double-space  ##` banners |
| crypt.*, context.* | mixed; `old-form`, `typed`, `usage` keys appear |
| keys.* [ 73 ] | newest-keys era; verbose multi-line descr + aligned continuations, heavy `[ ... ]` annotation, `;` sentence separators |
| models.* [ 240 ] | `# return = ... (default: N)` convention, cfg-style short descr |
| coding.* [ 436 ] | `# purpose =` header line [ 72 files, unique to this namespace ], phase-numbered purpose, always has descr [ 435/436 ] |
| model_batch.*, storage.*, plugin.* [ newest ] | richest headers : `note` blocks, ascii return tables, freeform `# label:` section lines inside the header block [ main source of loader leaks ] |

trend : old = minimal `name/descr` + boxed `##` banners; new = long aligned
multi-line descr, `param/return/note/purpose` keys, `[ ... ]` annotations and
inline ascii tables in headers.

## observations

most common conventions :
1. `## [:< ##` first line + `# name  =` / `# descr =` aligned header block [ ~100 % and ~83 % of files ]
2. `# key = value` header keys with 9/10-space value-aligned continuations for wrapping descr [ 889 files ]
3. inline trailing `## comment ##` after code lines [ dominant body style ] and full-line `## banner ##` section separators
4. `[ ... ]` square-bracket annotations for optionality/defaults/tags
5. `# param =` freeform one-liner for arguments [ 1407 files ]; return shapes documented via `# return =` or ascii `| row |` continuations

main inconsistencies :
- ~120 distinct header keys beyond the core five; plural/pair drift
  [ note/notes, return/returns, args/param/usage overlap ]
- key order not fixed [ `param` before or after `descr` ], which matters for
  the continuation-appending loader
- 181 headers embed freeform `# label:` / `Examples:` / ascii-table lines that
  leak into descr under the current loader; the second loader instead drops
  all continuations, so `commands` output disagrees with `describe` output
- 1015 files lack `# descr` entirely [ `<< missing 'descr' >>` fallback ]
- continuation alignment varies [ 9 vs 10 vs 1-space vs 2-space styles ],
  and per-argument docs use at least 8 different ad-hoc formats with no
  machine-readable argument structure

#,,.,,,..,,..,.,.,,,.,,..,.,,,.,,,...,,,.,.,,,..,,...,...,...,.,.,.,.,.,,,,.,,
#L5ACIU6ZM73BFH3V2UU2PDN6EPHCSRMRE5Q76DMGGVT6TT6JQKDPGZENCMQHJBVBDIWO3PDHCBOJU
#\\\|GOH5X4WY6B3UNXXEBUSZHRCDS7X63D7OAWLA5CXPMRTEDVR7DBS \ / AMOS7 \ YOURUM ::
#\[7]2QGTJQIZROAYLQ2CGDTNIPBS4BHAR4HYPAABTHGYHR2F44QD7IBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
