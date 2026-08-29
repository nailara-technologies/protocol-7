# task: powershell zenka — get-event-log command

## context

Diagnosing a WSL-VM-level incident tonight (`data/ai-mem/claude/
feedback-wsl-oom-full-vm-crash-2026-08-29.md`) needed querying the Windows host's Event
Viewer from inside this session, done ad-hoc via `powershell.exe -Command "Get-WinEvent
..."` shelled out directly. `data/ai-mem/claude/reference-powershell-exe-wsl-interop-
diagnostics.md` documents the technique. The `powershell` zenka already bridges into
Windows for exactly this kind of thing (`powershell.cmd.screenshot-capture`,
`powershell.cmd.notify-recover`, etc.) — this task turns the ad-hoc query into a proper,
reusable zenka command following that zenka's existing conventions, rather than shelling
out by hand each time.

## what to build

`src/powershell.cmd.get-event-log` — new command.

**Param**: `<log_name> <minutes_back> [level] [pattern]`
- `log_name` — Windows event log name, e.g. `System`, `Application`. Validate against a
  simple safe charset (`\w+` — word characters only) BEFORE it goes anywhere near a
  PowerShell script string — do not interpolate an unvalidated caller-supplied string
  directly into PS script text.
- `minutes_back` — positive integer, how far back from now to query.
- `level` — OPTIONAL. One of `critical|error|warning|information|verbose` (case-
  insensitive; also accept the short forms `err`/`warn`/`info` as aliases, matching how
  `journalctl -p err` reads), or `any`/`*` to skip level filtering entirely (also what
  omitting this param should default to). Validate against this fixed small set the
  same way as `log_name` — reject anything else rather than interpolating it. Filter at
  the `Get-WinEvent` level (via its own `Level` numeric property: 1=Critical, 2=Error,
  3=Warning, 4=Information, 5=Verbose — map the validated keyword to the number before
  building the script), not post-hoc in Perl — more efficient over a longer time window,
  and there's no injection risk either way once the keyword is validated against the
  fixed set.
- `pattern` — OPTIONAL, comes after `level` positionally (so passing `pattern` alone
  still requires passing `level` as `any` first — keep the param order simple/positional
  rather than trying to guess intent from argument count). If given, filter the
  returned lines (case-insensitive) — do this filtering in PERL on the text
  `powershell.exec` returns, NOT by interpolating the pattern into the PowerShell script
  itself (unlike `level`, `pattern` is arbitrary text and must never reach PS script
  text unvalidated). Matches the codebase's existing convention for this kind of
  optional trailing filter — see `p7-log.show-buffer <name> [lines] [pattern]`
  (`src/p7-log.cmd.show-buffer` or wherever its actual implementation lives — check via
  `grep -rn "descr.*show-buffer" src/`) for the established shape to mirror.

**Implementation shape** — model directly on `src/powershell.cmd.screenshot-capture` +
`src/powershell.plugin.screenshot-capture.invoke`, which already show the established
pattern for this zenka: validate input, build a PowerShell script as a heredoc, call
`<[powershell.exec]>->($ps_script)` (existing helper — handles spawning `powershell.exe`
via `open3`, non-interactive, normalizes CRLF to LF, returns stdout text or undef on
failure — read `src/powershell.exec` in full before starting, don't reimplement any of
this), then process the returned text.

Suggested PowerShell script body (one event per output line, TAB-separated, so both
`pattern` filtering and general readability work line-by-line — do NOT use PowerShell's
`Format-List`/`Format-Table`, which produce multi-line-per-event output that doesn't
grep or line-filter cleanly):

```powershell
$ErrorActionPreference = 'SilentlyContinue'
$filter = @{LogName='<validated log_name>'; StartTime=(Get-Date).AddMinutes(-<validated minutes_back>)}
<# only add Level to $filter when a level was actually requested -- 'any'/omitted means
   no Level key at all, not an empty/wildcard value #>
Get-WinEvent -FilterHashtable $filter |
    ForEach-Object {
        $msg = ($_.Message -replace '[\r\n]+', ' ')
        "$($_.TimeCreated.ToString('yyyy-MM-dd HH:mm:ss'))`t$($_.Id)`t$($_.ProviderName)`t$($_.LevelDisplayName)`t$msg"
    }
```

(the `Level` key would be added to `$filter` conditionally, in the Perl code building
this script — e.g. `$filter{'Level'} = $level_num if defined $level_num` — before
serializing it into the heredoc, not written as literal PowerShell conditional logic
inside the script itself; keep the actual PS script generation as simple string-building
in Perl, matching `screenshot-capture.invoke`'s heredoc style)

Reply shape, matching this zenka's other commands' `{ 'mode' => ..., 'data' => ... }`
convention: `'true'` with the (optionally pattern-filtered) TSV text as `data` on
success; `'false'` with a clear message for bad params, `powershell.exec` returning
undef, or genuinely zero matching events (distinguish "no events found" from "query
failed" in the message).

## live-testing hazard

Low — this is a read-only diagnostic query, no state changes on either the Linux or
Windows side. Safe and expected to be tested live: `p7c powershell.get-event-log System
10` (last 10 minutes of the System log, default level=any) is a reasonable smoke test,
`p7c powershell.get-event-log System 60 error` exercises the level param, and
`p7c powershell.get-event-log System 60 any memory` exercises pattern (level must be
given as `any` here since pattern is positionally after it). `powershell.exec` itself is
already proven working (screenshot-capture uses it in production) — this task is
composing existing, working pieces, not building a new bridge.

## status : DONE, verified live, 2026-08-28

Kimi's implementation was structurally correct but hit two genuinely subtle bugs, both
found and fixed after Kimi's dispatch (Kimi's own summary got sidetracked chasing a
false access-control lead instead — see below):

1. **Reachability was blocked by a zenka-LOCAL access list, not cube's access.zenki.**
   `cfg/zenki/powershell/zenka.v7` has its own `access.cmd.usr.* = commands heart ...`
   line — an explicit whitelist of command names reachable by the wildcard user, scoped
   to just this zenka, separate from and in addition to cube's global access.zenki/
   access.users. `get-event-log` wasn't in it. Fixed by adding it to that list and
   restarting the zenka (`v7.stop powershell` + `v7.start powershell` — a live `reload`
   is NOT enough, this file is only read at process startup). Kimi's dispatch found the
   symptom (`no perm.`) but went down an unproductive path questioning cube/unix-taeki
   authentication instead of checking the target zenka's own `zenka.v7` for a local
   whitelist — worth remembering as its own pattern: `access.cmd.usr.*` can exist in
   BOTH `cfg/zenki/cube/access.zenki` (global) AND a specific zenka's own `zenka.v7`
   (local, additional restriction) — check both when a new command isn't reachable.

2. **The multi-line heredoc PowerShell script never worked at all** — every invocation
   failed with exit code 1 and completely empty stdout+stderr, no diagnosable error.
   Root cause: `powershell.exec`'s `open3` array-form exec passes the script as a single
   argv element with real embedded newlines; the WSL-to-Windows interop layer that
   marshals that into a Win32 command line does not survive embedded newlines intact.
   The identical script joined into ONE line with `;` instead of newlines works
   correctly — confirmed via a minimal reproduction outside the zenka entirely
   (`open3` + `powershell.exe` directly). Fixed by rewriting the script as a single
   line. This likely affects ANY future `powershell.exec` caller that builds a
   multi-line script — worth remembering generally, not just for this command.

3. **Found while testing, a third bug**: pattern matching (`base.eval.comp_regex`,
   which compiles patterns inside a `Safe` compartment for sandboxing) returns a
   `Safe::RootN::Regexp`-blessed object, not a plain `Regexp`. It stringifies normally
   and matches correctly at its OWN compiled-in case-sensitivity, but an outer `m//i`
   flag on top of it is silently ignored — confirmed via isolated reproduction (exact-
   case match against a Safe-compiled pattern works, case-insensitive match via outer
   `i` on the same object does not). Fixed by embedding `(?i)` into the pattern text
   itself before compilation, not relying on the outer match's flag. Also fixed a
   related latent bug: the original code didn't pass a scalar-ref as
   `base.eval.comp_regex`'s second (error-message) argument, so a genuine compile
   failure would have crashed on `undef->$*` rather than returning a clean error
   message — fixed by passing `\$err_str`. This qr-flag-composition gotcha likely
   affects any other caller of `base.eval.comp_regex` wanting case-insensitive
   matching, not just this command.

4. **User caught a fourth gap after the above**: `log_name` was only charset-validated
   (`\w+`, safe to interpolate), never checked for actually EXISTING. An unknown log
   name hit `Get-WinEvent -FilterHashtable`'s TERMINATING error, which
   `$ErrorActionPreference = 'SilentlyContinue'` does NOT suppress — same
   undiagnosable exit-1-empty-output symptom as bug 2, different root cause. Fixed with
   an explicit `Get-WinEvent -ListLog '<name>' -ErrorAction SilentlyContinue` existence
   check folded into the same single-line script (still one `powershell.exec` round
   trip): outputs a `P7ERR:unknown event log` sentinel line the Perl side detects and
   turns into a clean `unknown event log '<name>'` error, rather than either crashing
   opaquely or trying to thread a detailed error message back through
   `powershell.exec`'s limited text-or-undef return contract.

5. **User reported bug 4's fix itself wasn't enough** — `system 13` (lowercase)
   still failed with the same opaque symptom. Investigated as a suspected
   `-ListLog` (case-insensitive matching) vs `-FilterHashtable`'s `LogName` key
   (suspected case-sensitive) mismatch; built a fix using the canonical-cased
   `$log.LogName` from the `-ListLog` result instead of the caller's raw input.
   That theory turned out to be WRONG on closer testing — the real cause was
   simpler: it was a genuinely empty 13-minute window (quiet system, 3am), and
   `Get-WinEvent -FilterHashtable` throws a TERMINATING error even for
   legitimately zero matching events, not just for invalid input — the same
   uncaught-terminating-error class as bug 4, just a different trigger.
   Per the user's own instinct ("catch exit code 1 generically"), replaced
   the whole approach: rather than pre-empting each specific failure shape
   with its own check (unknown log, empty result, whatever's next), wrap the
   ENTIRE query in `try { ... } catch { Write-Output ('P7ERR:' + $_.Exception.Message) }`
   and surface PowerShell's own real exception text through a generic
   `P7ERR:` sentinel, parsed generically on the Perl side (`if $raw_out =~
   m|^P7ERR:(.+)|`) rather than pattern-matched against specific known
   message strings. This single change covers unknown-log, empty-result, and
   any future failure mode uniformly, and gives more ACCURATE messages too
   (PowerShell's own wording, not a guessed string) — the earlier `-ListLog`
   pre-check is gone entirely; `-ListLog` still runs, but only to obtain the
   canonical-cased `LogName` for the real filter (kept as a defensive
   measure against `-FilterHashtable` case-sensitivity even though it wasn't
   the actual bug this time — cheap to keep, no reason not to).

All five verified live, including the actual failing repro from the user's report:
`p7c powershell.get-event-log system 120` (lowercase, wide window — works, full real
data), `... NoSuchLogXYZ 10` (clean PowerShell-native error text), `... System 1`
(genuinely empty window — clean PowerShell-native error text, not a crash), `... System
120 error` (level filter still works), `... System 120 any deskflow` (pattern filter
still works). `v7.list zenki` confirmed single stable instance throughout every fix and
retest, across all five rounds.

## dispatch notes [ for whoever picks this up, human or AI ]

Read `data/ai-mem/kimi/coding-style.md` and `data/ai-mem/kimi/MEMORY.md` first if
you're kimi. P7 pitfalls: `base.logs` not `base.log` for multi-arg sprintf-style calls,
never redeclare `my $call`, never add fake `PLACEHOLDER_FOR_AMOS7_SIGNATURE_LINE`
footers to new files, `TRUE`/`FALSE` are `5`/`0` not `1`/`0`, use `bin/dev/ptd -c` to
check syntax (NOT raw `perl -c`), and never use `\<var>` for a live reference (macro
translator's escape sequence, silently dead). Mixed-case identifiers are discouraged
project-wide (see the comment in `powershell.plugin.screenshot-capture.invoke` about
this, re: BASE32-over-BASE64 reasoning) — keep new variable/sub names lowercase-with-
underscores matching the rest of this zenka. If you learn something non-obvious while
working on this, add a note to your own memory files, same as any other task.

#,,..,,,.,,,.,,..,..,,,,.,.,,,,,,,,..,..,,,,.,..,,...,...,..,,,.,,...,,,,,...,
#DVYDBMJGDFVHHEFBQJRSRJ2SDKQW6MNSN2T4H7NDYCL6OUSSNJ4XR4AGRE22D222F3Y3ME7VFYMNS
#\\\|22E2DYYPQRD7DHM55EVOWJUPZVCAV2DHDKUHP6LW4NUYXA7BUU6 \ / AMOS7 \ YOURUM ::
#\[7]TSEPSI2AKM3DHGSESWXPJU57ORM4BJNBXWSEHEPNVRVVNWSUGSAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
