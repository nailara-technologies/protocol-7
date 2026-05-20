## [:< ##

# name  = task: diff-modified — add --no-color mode for LLM-readable output
# descr = when color is stripped from diff-modified output, +/- prefixes are
#         also gone (stripped by default), making additions and removals
#         byte-for-byte identical. --no-color keeps +/- and strips ANSI only.

## context

`bin/dev/diff-modified` is a modified `diff-so-fancy` with custom NAILARA
coloring. by default `$strip_leading_indicators = true` removes the `+`/`-`
line prefixes, leaving color as the only semantic carrier for add/remove.

when kimi or other models receive this output (via tool call or copy-paste
without ANSI), additions and removals look identical — same `: ` prefix, same
text, no distinguishing marker. this caused kimi to invent a "dual commits"
theory when processing git history, because changed lines appeared twice.

the fix: `--no-color` mode that keeps `+`/`-` prefixes AND strips ANSI codes,
producing unambiguous LLM-readable diff output without losing the structural
formatting (file headers, hunk separators, rulers).

## signatures note

do not add signature stubs. do not run `bin/Protocol-7 sourcecode update-signatures`.
do not add or modify subroutine whitelists.

---

## what to read first

```bash
cat bin/dev/diff-modified    ## full script — note argv(), strip_leading_indicators,
                             ## color constants, do_dsf_stuff output path
```

key variables already in the script:
- `$strip_leading_indicators` (line ~47) — controls +/- prefix stripping
- `$args->{color_on}` / `$args->{color_off}` (lines ~72-78) — existing flag pattern
- `sub argv` (line ~846) — parses --flag style args, handles `--no-color` already
- `$colors_add`, `$colors_del` — the ANSI color constants for add/remove lines

---

## implementation

### 1. parse --no-color flag

after the existing `color_on` / `color_off` block (around line 72), add:

```perl
my $no_color_mode = 0;
if ( $args->{'no-color'} ) {
    $no_color_mode          = 1;
    $strip_leading_indicators = 0;   ## keep +/- prefixes when color is gone
}
```

### 2. strip ANSI from output in no-color mode

find where final output lines are printed in `do_dsf_stuff` and the main loop.
the script uses `say` and `print` throughout. add a post-processing step:

option A — filter at output point: wrap every `say`/`print` with an ANSI-strip:
```perl
## at the top, define once:
my $strip_ansi = sub {
    my $s = shift;
    $s =~ s/\e\[[0-9;]*[mK]//g;
    $s =~ s/\e\[[0-9;]*m//g;
    return $s;
};

## then at each output site (or wrap say/print):
say $no_color_mode ? $strip_ansi->($line) : $line;
```

option B — post-process the full output buffer (simpler if output is collected):
if `do_dsf_stuff` builds output into a string, apply the strip to the whole
string before printing.

check how output flows through the script and choose the cleaner approach.
the `say $nailara_bg . $blacklight . '.' . $reset;` header/footer lines should
also be stripped or replaced with plain equivalents in no-color mode.

### 3. replace colored structural markers with plain text equivalents

in no-color mode the framing characters (`$l`, `$d`) become just `: ` and `. `
since the color constants are stripped. verify the rulers and file headers
remain readable without color — adjust if needed.

### 4. add to usage string

find `sub usage` and add `--no-color` to the usage output:

```
git diff | diff-modified --no-color    ## LLM-readable: keeps +/- prefixes, no ANSI
```

### 5. fix the LLL bug in ccdiff if found

`bin/dev/ccdiff` has: `## find out why background color is not working here ## [ LLL ]`
read that section while in the file. if the fix is obvious and small, apply it.
if it requires deeper investigation, note it and leave it.

---

## test sequence

```bash
## standard colored output (unchanged behavior):
git diff HEAD~1 | bin/dev/diff-modified | head -20

## no-color mode — should show +/- prefixes, no ANSI escape codes:
git diff HEAD~1 | bin/dev/diff-modified --no-color | head -20

## verify no ANSI codes remain:
git diff HEAD~1 | bin/dev/diff-modified --no-color | cat -v | grep '\^[' | wc -l
## expected: 0

## verify +/- prefixes are present:
git diff HEAD~1 | bin/dev/diff-modified --no-color | grep '^[+-]' | head -5
## expected: lines starting with + or -
```

## success criteria

- [ ] `--no-color` flag parsed correctly via existing `argv()` mechanism
- [ ] `$strip_leading_indicators` set to 0 when `--no-color` active
- [ ] all ANSI escape codes stripped from output in `--no-color` mode
- [ ] `+` prefix present on added lines in `--no-color` output
- [ ] `-` prefix present on removed lines in `--no-color` output
- [ ] file headers and structural markers still readable without color
- [ ] default behavior (with color) completely unchanged
- [ ] usage string updated to mention `--no-color`
- [ ] no signature stubs added, no subroutine whitelist changes made

#,,,,,...,,,,,.,,,..,,.,.,...,,,.,.,,,.,,,,,.,..,,...,...,.,.,.,.,,,.,.,.,,.,,
#CRNRU4LXFWD7T5YHIQRTIAPUACZPN3JSCZ5DFDJDXULNB6DAWJTSYBNJ6T5AC2U4PT7A5OVRP7RDM
#\\\|3QKLXB5R5XNS2T6RLVPKWVI5DYEROZJZLHVB4NCF3BXI2GRJRDI \ / AMOS7 \ YOURUM ::
#\[7]MFG5XQOGMBNSE3MX573R73NX5JNV7RHAVI6CNR4QGSXR5MVYN6AI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
