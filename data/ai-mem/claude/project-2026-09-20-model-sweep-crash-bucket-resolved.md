---
name: project-2026-09-20-model-sweep-crash-bucket-resolved
description: cross-backend model-sweep lock fix (7003d1345) confirmed live-verified, 25 models deleted (103GB), 18-model "crash bucket" classified, and new safe model-deletion tooling (models.cmd.delete-model/trash-list/trash-rescue/trash-prune/protect/unprotect, path-escape-protected, trash-based not permanent) built and live-verified
metadata:
  type: project
---

Direct continuation of [[project-2026-09-17-model-sweep-session]] and
[[bug-coding-cpu-binary-abi-skew-root-cause-2026-09-17]] — this session
resolved the open "crash bucket" of 18 checksums that session's final
sweep couldn't trust (crash verdicts contaminated by concurrent
gpu/cpu sweep contention, root-caused and fixed as
`coding-sweep-cross-backend-lock.md` / commit `7003d1345` the night
before this session, but not yet re-verified with real data).

**Cross-backend lock fix confirmed live-verified this session**: watched
`coding.model-sweep-status` alternate cleanly between
`gpu: running / cpu: yielding` and `gpu: yielding / cpu: running` —
never both `running` at once — across the whole re-test-failed sweep.
Direct evidence the fix works: several models' crash verdicts flipped
to real non-crash content-quality verdicts on a clean re-test (see
below), confirming the original 09-17 "crashed" tags on those
checksums really were contention artifacts, not per-model faults.

**19 high-confidence models deleted, 74GB freed.** These were the
09-17 session's "high-confidence" bucket — consistent
empty-answer/content-mismatch on both backends, never crash-flaky, so
unaffected by the lock-contention question. 16 deleted directly via
`rm` (taeki-owned files under `/mnt/ext-xfs-data/models-lmstudio/`).
The 3 `Qwen3-VL-4B-Instruct-GGUF` quants (Q8_0/Q6_K/Q4_K_M, same dir,
shared `mmproj-Qwen3-VL-4B-Instruct-F16.gguf`) were `protocol-7`-owned
(directory not group-writable to taeki) — deleted via
`coding.exec-sub base.file.remove_tree '<dir>'`, which runs inside the
coding zenka process as the `protocol-7` user, removing the whole
now-empty model directory (23 items: 3 ggufs + mmproj + README +
.gitattributes + .cache). Per [[feedback-no-sudo-privileged-fs-ops]],
never reached for `sudo` — the zenka's own privileged execution path
was the correct lever, same lesson as that memory's `kill` case.
Deleted checksums: YZGMZMA, DMHOGKQ, GT6M3CQ, 2YZKPTQ, K5ZUHBY,
C2EJSPY, 6KBHXNA, OVC25PI, QGNJ7EY, MKUFGLQ, 32TNYFY, WGMAW5I, XUKEIOQ,
RZANRKA, 7UBCESQ, 2QNZV2Y, RJ357TA, ZMM5MTY, OCMEO7Y.

**Two real bugs found and fixed along the way, both from watching this
exact re-test sweep run live** (both committed, both syntax-checked +
reloaded live via `coding.reload source` — no reinit needed; confirmed
`base.event.add_signal`'s `sub { $code{$handler}->() }` wrapper and
ordinary named-handler reply dispatch both re-resolve `%code` fresh
per-call, so a plain source reload is sufficient for this class of
handler):

1. `coding.handler.switch_model_reply` tried `YAML::XS::Load` on the
   `models` zenka's plain `"error: model not found: X:Y"` / `"error:
   model file not found: /path"` replies — genuinely invalid YAML (a
   second `": "` triggers `mapping values are not allowed in this
   context`), so the real reason was discarded in favor of a cryptic
   parser exception. Fixed to detect the `error:` prefix first and
   surface the real message, at level 1 when
   `<coding.model_sweep_state>->{$backend}` is active (routine for a
   stale/deleted sweep candidate) or level 0 otherwise. A same-session
   follow-up fix caught `$1` being clobbered by the intervening
   `<coding.model_sweep_state>` tag access before it was read — capture
   it into a local var immediately after the match.
2. `coding.self_test.handler.poll_switch` only detects a dead switch by
   polling `<coding.inference_servers>->{$backend}{status}` for
   `crashed`, or its own `max_wait` timeout (default 300s).
   `switch_model_reply`'s early bail-outs never touched that status, so
   every stale/deleted sweep candidate sat out the FULL 300s before
   `poll_switch` gave up — confirmed live, directly visible as a sweep
   speedup once fixed (~3 candidates/30min before → ~8/30min after).
   Fixed by setting `status='crashed'` on the concrete backend from all
   three early-bailout paths, reusing the exact signal
   `monitor_inference_startup` already sets for "spawned, then died
   before ready" — `poll_switch`'s next tick now fails fast instead of
   waiting out the timeout.

Also fixed same session, unrelated to the sweep but found via a side
task: `.deps/profiles.yaml`'s `X11-Desktop` apt list was missing
`libsdl-perl`, so `bin/p7-deps install` on a host with fewer packages
preinstalled (the `atom` remote server) fell through to `cpanm`
building `SDL`/`Alien::SDL` from source against long-dead upstream
tarball URLs, failing on a stale checksum. `libsdl-perl` (verified via
`dpkg -L`) provides every `SDL::*` submodule the profile lists —
same "precompiled Debian binding" pattern as `libgd-perl`/`Image::Hash`
in the `graphics-matrix` profile.

**Final crash-bucket classification** (18 checksums from the 09-17
low-confidence bucket), ntime-verified per entry — see the raw
tree_read dump in this session's transcript if exact timestamps are
needed again:

*Genuinely broken — DELETED, 29GB freed* (consistent
`crash_before_ready` on a clean post-fix retest; user confirmed
deletion after reviewing the classification, "haven't seen them
working either"). 5 of 6 files were directly `rm`-able (owned by
`taeki`, or `protocol-7`-owned with a world-writable 777 directory);
the LFM2.5 one needed `coding.exec-sub base.file.remove_tree` (its
directory was `protocol-7`-owned at 755, not writable by `taeki`) —
same privileged-path pattern as the earlier Qwen3-VL deletion, not
sudo, per [[feedback-no-sudo-privileged-fs-ops]]. Combined with the 19
from the first pass, this session freed 74+29 = **103GB total** on
`/mnt/ext-xfs-data` (105G free at session start → 208G free now):
- `FE64RAQ:S5YM37Q` (EssentialAI rnj-1-Instruct, 8.3G) — both backends
  fresh-retested, both still crash.
- `735VDRI:N27MKYQ` (Samantha-vision, 7.2G) — both backends
  fresh-retested, both still crash.
- `LJDKRYQ:7S73DCY` (LFM2.5 1.2B MEGABRAIN2 Thinking, 0.9G) — both
  backends fresh-retested, both still crash.
- `IFVH27Y:GEI3UDY` (Uncensored_codegemma_7b, 5.0G) — gpu
  fresh-retested and still crashes; cpu untested this run but was
  already `crashed` pre-fix (consistent direction).
- `IN6H5BY:XZWKVNI` (stable-code-3b, 2.8G) — same pattern as above,
  gpu fresh-confirmed crash, cpu untested but consistent.
- `APPLSXQ:GJ2GZHI` (aya-23-8B, 4.8G) — gpu fresh-retested, flipped
  AWAY from crash but still fails (`0/3 passed [3x transport]`) — a
  real non-crash quality/stability failure, same class as the
  already-deleted 19. cpu untested this run.

*Confirmed working — keep* (flipped to a real non-crash verdict on
fresh retest): `ZDMAPAY:AR3OCKQ`, `MBZAAII:BJTRX3I`, `A2B4TAI:JBY5PLA`,
`KPQUUPA:V7VTIZQ`.

*Marginal/mixed — keep, flag as flaky* (produces at least one correct
answer on fresh retest, not a crash, but weak): `ARCYQVY:LE7VOQA`
(cpu 1/3 passed, gpu still crash_before_ready — cpu-only usable),
`ARVENTI:MR2SVSY` (gpu 1/3 passed).

*Never retested this session — status still unknown, do NOT delete or
trust the old verdict either way*: `EBCVWUQ:734SX4I`, `XF2GMAI:25WM54I`,
`XQBLBNQ:SIZ4UDI`, `CNTO5UA:I3LQTMQ`, `ZIZEKAI:AVC2JIY`,
`BZPO73Q:F7DO47A` — all still carry their stale 2026-09-17 07:xx/09:xx
timestamps on every backend they have an entry for. The `re-test-failed`
sweep filter apparently computes its candidate list once at
sweep-start from current status, and multiple earlier
resume/restart cycles this session (before the final clean 47gpu/51cpu
run) evidently already peeled off whichever checksums they reached —
these 6 simply never came up in any of those cycles. A small
follow-up `re-test-failed`-filtered sweep targeting specifically these
6 would resolve them; not done this session.

Also outstanding from `data/tasks/coding-sweep-cross-backend-lock.md`'s
own "explicitly out of scope" list: nothing else pending from that task
— it's fully closed, superseded by this file for status purposes.

**New safe model-deletion tooling, built after the manual `rm`/
`coding.exec-sub` workarounds above got tedious and risky enough to
formalize.** In the `models` zenka (which already owns the
registry/storage adapters and drops to `protocol-7`, same as
`coding`): `models.cmd.delete-model <checksum>`, `trash-list`,
`trash-rescue <checksum>`, `trash-prune [days]`, `protect
<checksum>`/`unprotect <checksum>`/`list-protected`. New files:
`models.trash.root_path` / `.load_protected` / `.save_protected` +
the seven `models.cmd.*` files above. Mirrors the established
`note.trash.*`/`jobsite` stash-rescue-list-prune convention, but the
*mechanism* differs: `note.trash.stash` xz+base32-encodes content into
a text file, which is fine for small notes but would be catastrophic
for a multi-GB `.gguf` (loads the whole file into memory to compress
it). Models use a plain same-filesystem `rename()` into
`<lmstudio_root>/.trash/<ntime>__<checksum>/` instead — O(1) regardless
of file size, content never touches memory, with a `meta.yaml` sidecar
recording the original path(s) for rescue.

Two real things had to be fixed to get this working, both found by
actually exercising the code live rather than trusting it after a
syntax check:
1. `models` zenka's `modules.load` never included `format.yaml`
   (unlike `coding`'s, which does) — `format.yaml.write_file` doesn't
   exist there at all without it. Undefined-sub crash, not a graceful
   error. Added `format.yaml` to `cfg/zenki/models/zenka.v7`'s
   `modules.load`.
2. **The crash above hit a real ordering bug**: `delete-model`
   originally renamed the file into trash BEFORE writing the
   `meta.yaml` sidecar, with no check on the write's return value. The
   undefined-sub crash landed exactly in that gap — file genuinely
   moved (verified: `4144749600` bytes, byte-identical), but
   untracked, invisible to `trash-list`/`trash-rescue` since they key
   entirely off `meta.yaml`. Recovered by hand: found the orphaned
   `.trash/<ntime>__<checksum>/` dir via `coding.exec-sub
   base.file.glob` (same `protocol-7`-permission trick as the
   Qwen3-VL/LFM2.5 deletions), manually wrote the correct `meta.yaml`
   via `models.eval-code`, then ran the real `trash-rescue` to restore
   it properly — exercised the actual rescue code path as a side
   effect. Fixed the real bug after: sidecar now writes immediately
   after the file rename (before the mmproj rename or anything else
   that could fail), a failed rename cleans up the now-useless empty
   trash dir instead of leaving debris (a second, smaller instance of
   the same "leaves stray state on failure" class — the earlier
   Qwythos permission-denied test left exactly this kind of orphaned
   empty dir, cleaned up by hand at the time), and the sidecar write's
   return value is now checked, with a clear "recoverable by hand
   only, original path was X" message on failure instead of silence.
   **`v7-zenki.restart models`/`coding` was used for the `access.cmd.
   usr.cube` and `modules.load` (format.yaml) zenka.v7 changes this
   session -- unnecessary, and a pre-existing memory already said so.**
   [[reference-ntime-x4200-and-cube-cross-zenka-access]] (kimi, 09-15)
   already documents that `<zenka>.reload config` applies an
   `access.cmd.usr` change live, no restart -- should have been
   checked before reaching for a restart twice. `reload source` alone
   genuinely never touches config/access (that part was always
   correct); the fix is a separate `reload config` call (+ `reload
   source` to compile in a newly-listed module namespace like
   `format.yaml`). Checking this also surfaced and fixed a real small
   bug in `base.cmd.reload` itself -- see that reference file's
   2026-09-20 update for the detail, not duplicated here.

**Fully live-verified, including the security-relevant path**: a
round-trip delete→trash-list→rescue on a real 3.86GB model
(`DUYK3LA:5NZPQDY`, Claudette-7B) restored byte-identical; protect
correctly blocks delete-model outright; a crafted `definitions` entry
pointing at `/etc/passwd` was correctly refused by the real command
(not just the isolated logic) with `refusing to delete -- resolved
path '/etc/passwd' is outside the configured models root`. One minor,
known, non-safety gap: `trash-rescue` doesn't re-add the restored
model to the in-memory `<models.registry>` (only `delete-model`
proactively removes it) — a rescued model stays unresolvable via
`resolve.entry` until the next discovery scan/reload. Not fixed this
session; the file itself is always genuinely intact regardless.

Still outstanding from the original ask, not yet built:
`coding.cmd.model-sweep-test <checksum> [backend]` for one-off targeted
retesting without running the whole `:re-test-failed:` sweep — the
switch→self-test→restore state machine `poll_sweep`'s `start_candidate`
already drives is reusable in principle, just not yet extracted into
something a standalone command can call directly.

#,,.,,.,,,...,.,.,.,.,...,,..,,..,,,.,.,,,,,,,.,.,...,..,,..,,,.,,,.,,,,,,.,.,
#236N4M5UBNBJYYVRAKKJF7ES3SYRSLQYI2LBNW5DUMTLWZFLNGCK6BXKGI62ILLJUYPZ62NNXGBJU
#\\\|TFMYEWDRNVDOEMGQTLBVBNKW6ALTAG5S2MU4HVKUBKGO7FGGJW6 \ / AMOS7 \ YOURUM ::
#\[7]M6XRHB3E2PNXBM7QHHVKRM4DRZEQ2AWT6TOTWUF3GTCX7DTPCWDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
