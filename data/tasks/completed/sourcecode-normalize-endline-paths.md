# sourcecode: normalize-endline-state command + path normalization config

## context

the signing system encodes a delta in each file's amos7 footer indicating how
many trailing newlines were added or removed during signing (state = 5 + delta).
states 5 and 6 are the common canonical cases; state 7 (delta +2) occurs when a
file has no trailing newline at all.

**the bug**: when a file is edited after signing and the last content line
changes, the restoration logic applies the stale encoded delta from the old
signature. if that delta was +2 (state 7), stripping removes 2 newlines and
leaves the content with no trailing newline — the next signing then appends the
footer directly onto the last content line with no separator.

**the pragmatic fix**: rather than solving the ambiguous restoration problem
(zero trailing newlines is valid for json/yaml/binary — can't distinguish
intentional from bug), add:

1. **per-path normalization config** — directories like `src/` are declared
   as canonical paths where content must end with exactly 1 `\n`. during signing,
   files in these paths always get normalized to exactly 1 trailing newline before
   the footer, regardless of what the encoded state says. this silently repairs
   kimi/llm output that arrives in non-canonical form (state 5, 7, etc.).

2. **`normalize-endline-state` command** — proactive normalization tool that
   fixes files before they cause issues.

the only safe universal catch (for all file types) remains: if the delta says
"remove N newlines" but fewer than N exist in the content — that's always wrong,
log a warning and clamp to actual count.

## implementation

### 1. path normalization config

add a config key to the sourcecode zenka (in `sourcecode.init_code` or a
config file):

```
sourcecode.normalize_endline_paths = modules bin configuration
```

in `source.cmd.get-code-signed`, after stripping the old footer and before
counting trailing newlines: check if the file's relative path starts with any
of the normalize paths. if yes, normalize the content to exactly 1 trailing
`\n` before the normal delta-counting logic runs. the delta will then always
be either 5 (content already had 1 `\n`) or 6 (content had 0, one added) for
files in these paths — never 7.

### 2. `sourcecode.console.normalize-endline-state`

**with file/pattern arg**: normalize the given files
**without arg**: walk all configured normalize paths (same as update-signatures
path set-up, filtered to normalize_endline_paths)

for each file:
- **signed files**: strip footer, normalize trailing newlines to exactly 1 `\n`,
  re-sign. if already canonical (state 6 or 5-with-single-\n) — skip silently
  unless verbose
- **unsigned files**: just normalize the trailing newline to exactly 1 `\n`,
  write back

output style (match `report-endline-state` and `update-signatures` patterns):

```
.:[ normalizing endline state ]:.
: src/some.module : state 7 → 6 : normalized
: src/other.module : state 5 → 6 : normalized
: src/already.fine : state 6 : ok
: : N normalized, M already canonical
```

### 3. `source.restore_payload_endline_state` safety check

add a guard: before removing N trailing newlines (negative delta, states 0-4),
count actual trailing newlines. if `actual < N`:
- log a warning: `endline state mismatch: encoded delta=%d but only %d trailing newlines found`
- clamp removal to actual count (do not underflow)

this catches the impossible case safely for all file types without needing
path-based heuristics.

## style notes

- all comments lowercase, bracket annotations `[ word ]` not `( word )`
- match log output style of `sourcecode.console.report-endline-state` and
  `sourcecode.console.update-signatures` for consistent console experience
- use `<[base.logs]>->( level, format, args )` for all output
- use `<system.root_path>` not hardcoded `/data/projects/protocol-7/`
- use `<[base.source.collect_file_list]>` for path resolution
- command registered in sourcecode zenka — no network access needed
- do not add the stub signature `#,,.,,,...` to new files — signing adds footer

## affected modules

- `src/source.cmd.get-code-signed` — add normalize path check before delta
  counting
- `src/source.restore_payload_endline_state` — add underflow guard
- `src/sourcecode.init_code` or config — add normalize_endline_paths config
- new: `src/sourcecode.console.normalize-endline-state`

## verification

after implementation:

```bash
## check no state 7 files remain in canonical paths after normalize
v7.sourcecode normalize-endline-state -vvq
v7.sourcecode report-endline-state src/ -vvq | grep 'state 7'
## should return empty

## check signing a newly-created file without trailing \n stays canonical
echo -n 'return TRUE;' > /tmp/test-no-newline
v7.sourcecode update-signatures /tmp/test-no-newline
v7.sourcecode report-endline-state /tmp/test-no-newline -vvq
## should show state 6

## check the underflow guard fires for a hand-crafted state 4 footer
## (delta -1, but content has 0 trailing newlines)
## should log warning and not corrupt the file
```

#,,,,,,,.,..,,...,,,.,...,...,,.,,..,,,.,,.,.,..,,...,...,.,,,,..,.,.,,.,,,.,,
#TXF6CP2PWOLIEMFSUK26K7IRASOTNMKGYKEMSSH3JLINRJL5HRESL3AEPP4254SKQ7BD4LLIEO3VK
#\\\|AH7DUZSW3LDHXIO3NEFQZAUGPEMLQ3JREUYTM2QFRNRA3QI5OAU \ / AMOS7 \ YOURUM ::
#\[7]E6CERRQXH5FTZ3FE5QSW5UL36OFTGOXOQFQDYIQ3Y4NLMRXHZSBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
