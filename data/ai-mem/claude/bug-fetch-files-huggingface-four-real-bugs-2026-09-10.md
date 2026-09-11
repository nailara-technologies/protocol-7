---
name: bug-fetch-files-huggingface-four-real-bugs-2026-09-10
description: fetch-files.hf-search/hf-list/hf-download/hf-lan-check were never actually working end-to-end -- 11 independent real bugs found and fixed live in one session (filename says "four", grew to 11), most verified against the running zenka; includes a CPU-pinning unstoppped io-watcher-on-EOF bug only found via -vvv raw event-trace logging after every higher-level diagnostic looked clean
metadata:
  type: feedback
---

2026-09-10, discovered while trying to fetch a HuggingFace checkpoint for
[[coding-lora-p7-idioms]] (session resumed from `HANDOVER.md`). This
whole module family (`fetch-files.cmd.hf-*`, `fetch.file.huggingface.*`)
had apparently never been exercised end-to-end before -- calling
`fetch-files.hf-search` hit FOUR independent real bugs in sequence, each
only visible once the previous one was fixed:

1. **`JSON::PP::decode_json` called fully-qualified without ever `use
   JSON::PP;`** in 6 files (`fetch-files.cmd.hf-search/hf-list/
   hf-lan-check/hf-download`, `fetch.file.huggingface.handler.
   search_response/list_response`) -- "Undefined subroutine
   &JSON::PP::decode_json". `models.cmd.statistics` shows the correct
   pattern (`use JSON::PP;` at the top). Fixed by adding that line to
   all 6.

2. **stale pre-swap module names**, 8 occurrences across 6 files. `fetch.
   file.huggingface.pre_init` runs `<[base.swap_subs]>->( qw|
   fetch.file.huggingface | , qw| huggingface | )`, which renames the
   `%code` dispatch-table KEYS from `fetch.file.huggingface.*` to
   `huggingface.*` -- but does nothing to string literals or `<[...]>`
   calls already baked into source. Every cross-reference within the
   family that still spelled out the old prefix (`<[fetch.file.
   huggingface.search]>`, `'on_done' => qw| fetch.file.huggingface.
   handler.search_response |`, etc.) resolved to nothing post-swap ->
   "undefined value as subroutine reference". `fetch-files.cmd.hf-
   download` had ALREADY gotten this right (`<[huggingface.download]>`)
   -- inconsistent within the same file family, not a universal miss.
   Fixed by s/fetch.file.huggingface./huggingface./ everywhere within
   the family's own cross-references (both `.cmd` wrapper call sites and
   internal sibling references/callback-name strings).

3. **calling-convention mismatch**: all 4 entry points (`fetch.file.
   huggingface.search/list/lan-check/download`) `shift` a `$call` hash
   and read `$call->{'args'}` -- but all 4 `.cmd` wrappers called them
   as `->($args)` (the bare decoded-JSON hash), not `->({'args' =>
   $args})`. `download.pm`'s OWN internal call to `lan-check` already
   used the correct wrapped shape, again showing the SAME file family
   was inconsistent with itself, not uniformly wrong. Fixed by wrapping
   in all 4 `.cmd` files.

4. **wrong HTTP client family**: `fetch.file.huggingface.search/list`
   called `<[clients.http.get]>` (plain, non-TLS) against `https://
   huggingface.co/...` URLs -- manifested as `clients.http.handler.io:
   read error: Connection reset by peer` (a TLS server resetting a raw
   plaintext HTTP request on port 443, not a proxy/network issue as
   first suspected). This codebase has a separate `clients.https.*`
   family for TLS (confirmed via `cfg/zenki/proxy/zenka.v7` loading
   both, `site-yaml` loading `clients.https` alone). Fixed: both calls
   -> `<[clients.https.get]>`, and `cfg/zenki/fetch-files/zenka.v7`'s
   `modules.load` -> `clients.https` (was missing `clients.http`
   entirely at first, a real 5th bug on top -- see below -- then
   corrected straight to `clients.https` once the client-family bug was
   found, no intermediate wrong-client load ever shipped).
   `download.pm`'s actual file transfer shells out via `IPC::Open3`
   (curl/wget under the hood, not `clients.http/https` at all) --
   unaffected by this specific bug.

   **(5th, load-list) also found along the way**: `cfg/zenki/fetch-
   files/zenka.v7`'s `modules.load` never included `clients.http`(s) at
   all -- "protocol-7 subroutine clients.http.get not defined". Fixed
   as part of (4) above, landing directly on `clients.https` rather than
   `clients.http` since the client-family bug was already known by then.

**6th bug, found while actually driving a real download to completion**:
`fetch.file.huggingface.download` never `use`d `File::Path` despite calling
`make_path($dest, ...)` -- only mattered for a non-`.gguf` destination
(the auto-detected `/tmp/model-downloads` fallback, or any first-use
`dest` dir that doesn't already exist), so it went unnoticed until a
safetensors (not GGUF) fetch actually needed a fresh directory. Fixed:
`use File::Path qw| make_path |;` added.

**7th bug, a genuine functional break, not just noise**: `fetch.file.
huggingface.handler.download_progress` (the 2s-repeating timer that
polls download progress and detects process completion) assumed its
`shift`ed arg was a plain hash (`$timer_data->{'data'}{'dl_id'}`) --
the real convention (confirmed against multiple other timer/io handlers
across the codebase, e.g. `coding.handler.defer_seed_restart`,
`clients.https.handler.handshake`) is `my $event = shift; my $data =
$event->w->data;` (an EV watcher object with a `->w->data` accessor, not
a plain hash). This died with "not a HASH reference" on EVERY tick,
which mattered more than a cosmetic log spam: the die happened BEFORE
the `waitpid` check, so **the zenka could never detect a download's
process exit or fire its deferred reply -- an `hf-download` call would
never resolve, even though the underlying `wget` child (an independent
OS process) kept downloading and completing normally regardless**.
`fetch.file.huggingface.handler.download_stderr` (the sibling io-watcher
handler) already had the correct shape -- only the timer handler was
wrong, an inconsistency within the same file family again, same pattern
as bugs 1-4. Fixed: `my $event = shift; my $timer_data = eval { $event
->w->data } // {}; my $dl_id = $timer_data->{'dl_id'} // '';`

**8th, a side effect of fix 1 above, FULLY ROOT-CAUSED (corrected from an
earlier wrong write-up in this same file)**: adding `use JSON::PP;` to 6
files caused a recurring `Prototype mismatch: sub main::decode_json:
none vs ($)` warning. First attempt (WRONG): changed the 6 files to
`use JSON::PP ();` (no import) -- didn't fix it, because the true
collision wasn't between multiple `use JSON::PP` imports at all. Second
attempt (also a dead end): moved the load into a single `<[base.
perlmod.autoload]>->(qw| JSON::PP |)` call in `fetch.file.huggingface.
pre_init` -- per the user, this was itself wrong for an unrelated reason
(scattered per-file `use` isn't the P7 idiom; `base.perlmod.autoload` in
one `pre_init`/`init_code` is), but the warning persisted regardless,
which was the actual clue that the cause wasn't about import mechanics
at all.

**Real cause, found once a local `$SIG{__WARN__}` override elsewhere
(unrelated pre-existing code, see [[bug-local-sig-warn-bypasses-central-blacklist]])
was removed and the warning surfaced loudly through `bin/Protocol-7`'s
real central handler instead of being silently eaten**: `fetch-files`'
`modules.load` already includes `clients.https` (needed for the TLS fix,
bug 4 above) -- and `clients.https.init_code:8` unconditionally
autoloads **`JSON::XS`**, a SEPARATE JSON backend from `JSON::PP`, which
ALSO exports a function named `decode_json`. `JSON::PP::decode_json` has
NO prototype; `JSON::XS::decode_json` has prototype `($)` -- loading
both into the same process's `main::` namespace is an exact, confirmed
match for "none vs ($)" (verified directly: `perl -MJSON::XS -e
'print prototype(\&JSON::XS::decode_json)'` -> `$`; same for JSON::PP ->
empty). **Fix**: don't load JSON::PP at all -- `fetch.file.huggingface.
pre_init`'s autoload call removed entirely, and all 6 files' `JSON::PP::
decode_json(...)` changed to `JSON::XS::decode_json(...)` (fully
API-compatible, drop-in), reusing the JSON backend `clients.https` was
already guaranteed to load rather than introducing a second, colliding
one. This is the actual root cause -- not "unidentified," as the
previous version of this note said.

Note: `models.cmd.statistics` (the originally-cited "correct precedent"
for bug 1) turned out to `use JSON::PP;` and never call it at all
anywhere in that file -- a dead import, not a real usage precedent;
harmless to have followed its import style initially, but not evidence
it was doing anything right either.

**verified live, end-to-end**, via the user's own console (`tail -f
/dev/shm/.7/STDOUT/NIW7OAQ`-style live zenka log, not just a clean
review) -- `fetch-files.hf-search` returned real HuggingFace search
results after all 4 fixes landed. The `p7_command` MCP tool's own
reply came back `"command route collapsed"` despite the underlying
zenka-side work succeeding and logging its real result -- **same
established lesson as [[topic-kimi-dispatch-infra-hardening]]**: check
the zenka's own live log/console output before trusting a generic
tool-side error as proof the work failed.

**how to apply**: this entire module family was almost certainly never
run end-to-end before this session (all 4 bugs are exactly the kind of
thing a single successful run would have caught immediately) -- treat
any `fetch-files.hf-*` / `fetch.file.huggingface.*` code as now
live-verified working (search path; list/download/lan-check share fixes
1-3 but were not each individually re-tested live this session, only
reasoned about identically), not as still-suspect. If a NEW bug shows up
in `hf-list`/`hf-download`/`hf-lan-check` specifically, check whether
it's a 6th real bug or just an untested-since-fix path.

**not yet committed** -- these are working-tree fixes only as of this
memory being written; check `git status`/`git log` before assuming they
landed.

**9th, found by the user during live testing**: `fetch.file.huggingface.
download`'s spawned child process (`wget`, then `aria2c` after the
switch below) was never registered via `<[base.zenki.report_child_pid]>`
-- so restarting the `fetch-files` zenka (needed repeatedly this session
to pick up fixes) only killed the PARENT process; the child transfer
process was silently ORPHANED and kept running independently, unkillable
through normal zenka lifecycle management. `debian.start.apt_child` is
the exact precedent (`access.cmd.usr.debian = v7-zenki.register_child`
in `cfg/zenki/cube/access.zenki`) -- child-process-spawning zenki need
both the `report_child_pid` call themselves AND a same-named grant on
cube's `access.zenki` (a cross-zenka command call, same access-control
gap class as [[feedback-narrow-scoped-kimi-task-file-pattern]]'s
mpv/access.zenki finding). Fixed: the call added to `download.pm`, plus
`access.cmd.usr.fetch-files = v7-zenki.register_child` added to
`cfg/zenki/cube/access.zenki` -- needs a `cube` reload to take effect,
not yet confirmed live as of this writing.

**switched wget -> aria2c**, per the user, for real resilience against
HF's own CDN stalling/throttling connections (observed live) -- aria2c
natively resumes partial transfers (`--continue=true`, verified live
against a manually-truncated real partial file) and detects a stalled
[not dead] connection via `--lowest-speed-limit`, retrying automatically
(`--max-tries=0`) instead of sitting at a plateau forever like the bare
`wget -O` invocation did. Also fixed the "already exists" pre-check bug
this uncovered: `download.pm` used to treat ANY existing file at the
destination as a complete success without checking size -- exactly the
bug that made a truncated partial from an earlier crash look "done".
Removed that check entirely; aria2c's own `--continue` correctly
distinguishes complete-vs-partial by checking the real remote size.
**New, separate wrinkle found while testing the switch**: aria2c doesn't
auto-read `http_proxy`/`https_proxy` env vars the way wget/curl do --
confirmed via its own `--help=all`, no such behavior documented -- so
`--all-proxy` is now passed explicitly from those env vars, or downloads
would have silently gone direct instead of through this host's
configured proxy. **Still open, not yet root-caused**: aria2c's process
sometimes doesn't exit even after the transfer completes (file reaches
exact target size, process stays alive doing something CPU-active,
observed for 100+ seconds) -- data integrity is unaffected (the file is
correct and complete either way) but the hung process needs a manual
zenka restart to clear, and now ALSO needs the child-pid registration
fix above to actually be killed by that restart rather than orphaned yet
again.

**10th, the actual cause of the recurring post-download CPU-loop/hang,
found by the user via `fetch-files.dump ^fetch`**: `<fetch.file.
downloads>` entries were getting stuck at `status = downloading` FOREVER
even after the real transfer finished (the dump showed `downloaded ==`
the file's true complete size, `status` still `downloading`, the 2s
polling `timer` object still alive). Root cause: `huggingface.handler.
download_progress`'s completion check was `if ($wait_result == $pid)`
where `$wait_result = waitpid($pid, WNOHANG)` -- but `base.sig_chld`
(the actual global handler every zenka installs for `$SIG{'CHLD'}` --
NOT `universal.handler.sig_chld`, a different, specialized handler for
tracking `<universal.running>` child ZENKI specifically, first
misidentified as the culprit here and corrected by the user) loops
`waitpid(-1, WNOHANG)` on every real SIGCHLD delivery and reaps ANY
exited child process immediately, asynchronously -- so it already
collects the child's exit status before this handler's own
2-second-interval poll gets to it, and `waitpid` here returns `-1`
(ECHILD, nothing left to reap) instead of a clean `$pid` match. `-1`
satisfies NEITHER `$wait_result == $pid` NOR `$wait_result == 0`
("still running"), so the download entry never finalized, its 2s timer
kept firing indefinitely, and `resume_ondemand_timeout` never got
called -- explaining both the stuck tracking AND (at least partly) the
recurring high-CPU zenka states this session. Fixed: liveness is now
determined by `kill(0, $pid)` (authoritative existence check) rather
than trusting `waitpid`'s return value alone; a real exit code is used
when available (`$wait_result == $pid`), and file-state (exists +
nonzero size) is the fallback success signal when the exit code was
already consumed elsewhere. **Live-verified working**: `fetch-files.dump
^fetch` after a real download showed `status = complete` cleanly, no
stuck entry, no lingering timer.

**11th, the actual CPU-loop root cause (bug 10 fixed the stuck TRACKING,
this is the separate bug that explains the sustained ~100% CPU itself)**
-- found by the user starting the backend with `-vvv` verbose logging
and reading `/dev/shm/.7/STDOUT/<instance>` directly: `base.s_read` and
`huggingface.handler.download_stderr` were firing on the SAME io-watcher
every single event-loop iteration, forever, after each download's child
process had already exited. Root cause: `fetch.file.huggingface.
download` registers an `event.add_io` watcher on the child's stderr fd
(`huggingface.handler.download_stderr`) but never stores or cancels it
anywhere. Once the child (aria2c/wget) exits, its stderr pipe's write
end closes, making the read side permanently EOF -- and a level-
triggered io-watcher on an EOF'd fd is perpetually "readable" (0 bytes,
over and over). `download_stderr.pm`'s old code did `return if $bytes <=
0;` on EOF -- returning from the HANDLER, but never stopping the WATCHER
itself, so the event loop kept re-firing it continuously, pinning CPU
near 100% even though the download had already completed cleanly
(explains why `fetch-files.heart` still answered in under 1ms throughout
-- the event loop wasn't deadlocked, just spinning on this one watcher
between real work). Matches the exact convention already used elsewhere
in this codebase for the identical situation: `clients.https.handler.io`
calls `clients.https.cleanup` (which does `$state->{$_}->cancel` on its
watchers) on true EOF, rather than just returning. Fixed:
`download_stderr.pm` now does `eval { $event->w->cancel }; return;`
on `$bytes <= 0` instead of a bare `return`.

**How this one hid so effectively**: `ps`/`top` both clearly showed the
elevated CPU, `fetch-files.dump` showed clean tracking state (fixed by
bug 10), `fetch-files.heart` answered instantly, and the normal-verbosity
buffer log (`fetch-files.show-buffer zenka`) showed a fully clean
start-to-complete sequence with nothing after it -- every one of the
normal diagnostic tools said "this looks fine" simultaneously, because
none of them surface a tight loop on a single already-registered
io-watcher that never logs anything. Only enabling `-vvv` and reading
the raw event-dispatch trace directly (`base.s_read` /
`<handler-name>` pairs repeating with IDENTICAL glob/scalar IDs) made it
visible. **Worth remembering as a general diagnostic technique**: when
a zenka shows real, sustained CPU usage that no combination of
dump/heart/buffer-log evidence explains, and the process is still
responsive (not deadlocked), suspect an unstoppped/unwatched io-watcher
spinning on EOF specifically -- and reach for `-vvv` + raw event-trace
reading rather than continuing to infer from higher-level diagnostics
that all look clean.

## related

[[topic-kimi-dispatch-infra-hardening]]

#,,.,,,,.,,,.,.,,,,..,,,.,..,,,,.,.,,,..,,..,,..,,...,...,..,,,,.,,,,,..,,,.,,
#UGIWQLRR4RQYBWMDS2Z5323UB52TF2C2Q4JLMZMBGP5WU7FEHBRCM4DRAH4CVYNUDP2TI72K6MEHY
#\\\|RLTNVRBIZ2KP42HH24VY5OAFFRZGNV6OOWKO437DDWAKJMI5IJU \ / AMOS7 \ YOURUM ::
#\[7]GP3UF7LJMIL75VHNMTUOO2QFLYHMS7F7TPCCYGN77M5YXR6ZR2CQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
