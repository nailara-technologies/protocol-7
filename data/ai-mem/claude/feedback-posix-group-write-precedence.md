---
name: feedback-posix-group-write-precedence
description: chmod-child grants must set GROUP-write (0020) not other-write (0002) when the writing process is a supplementary-group member of the target file
metadata:
  type: feedback
---

When a zenka process is a supplementary-group member of a taeki-owned file (via
`ncode.cfg.assume_admin_group`/`coding`'s equivalent), a chmod-child grant that
only sets the **other**-write bit (`| 0002`) does nothing — the write still
fails with `Permission denied`, even on a file whose final mode looks
world-writable (e.g. `646`).

**Why:** POSIX file permission checking is a strict priority order — owner
match, else group match (any of the process's real+supplementary groups),
else other — and it stops at the *first* match. It does not take the most
permissive applicable bits. A process whose group matches the file's group
gets evaluated against the **group** permission class only, even if the
**other** class would have been more permissive. `write_with_perms`
(`coding.tools.handler.write_with_perms`) grants with `| 0002` and carries
this exact latent bug; `replace_in_file`'s `"gw"` chmod-child command (`|
0020`, group-write) is the one that actually works, because these processes
are always group members of the taeki-owned files they touch, never
strangers to them.

**How to apply:** any new chmod-child-based write grant must OR in `0020`
(group-write), not `0002` (other-write). Diagnosed and fixed live in
`ncode.cmd.apply` (2026-07-24) after an extended false trail through
Landlock/LSM theories that a direct A/B test against `coding`'s own working
write path (identical uid/gid/groups) disproved — see
[[project-ncode-write-path-2026-07-24]].

**CORRECTION 2026-09-23**: `write_with_perms` WAS fixed, same day
(2026-07-24, commit `fix write_with_perms group-write bug`) — this file's
earlier claim that it "has not been fixed" and is "a broken reference...
until it is" was stale and wrong by the time of writing. Verified live via
`git log -p` before trusting it again: `printf {$chmod_fh} "restore %04o
%s\n", ( $cur_mode | 0020 ), $file_path;` — correct bit, already in place.
Lesson: a memory asserting "X is still broken" is a claim about a point in
time, not a standing fact — check `git log`/current file content before
propagating it into a new session's plan, same as
[[feedback-verify-symptom-shape-before-hypothesis]] already argues for
symptoms.

`write_with_perms` did have a *different*, real, separate bug found the
same 2026-09-23 session as this correction: no cause-and-effect tracking on
the grant, so a successful `restore | 0020` that still left the file
unwritable (or a later write failure) never got reverted — see
[[feedback-chmod-child-revert-on-failed-grant]] for that fix and its sweep
across ~12 other chmod-child callers in both `coding` and `ncode`.

**This is a repeat finding, not a first discovery.** The exact same bug was
already found and fixed once, in `coding.tools.handler.write_append`, on
2026-06-06 (buried in [[topic-next-steps]]'s completed-session log, no
dedicated memory file existed until now — that's likely why it didn't stop
`write_with_perms` from being written with the same bug afterward, and why
it took a second multi-hour live debugging session to rediscover). Treat
`write_with_perms` as a confirmed, unfixed, real bug — not just a "don't
copy this" note — see the roadmap item in [[topic-next-steps]].

#,,..,,,,,...,...,..,,..,,,..,.,.,,.,,..,,...,..,,...,...,...,..,,,,,,,,,,.,,,
#K4FLBPFF5CAPTN2Y3ERGTWTJFXOKHLM2MG24BCWE6KBA5LQRZOG7IZU6IFGZHCDU44EUBJUIIS7KI
#\\\|ESWTZ6TMWGCES6ORZNKEFFGL7TO4SOOD5RIAHJNSMV2CZEGCY47 \ / AMOS7 \ YOURUM ::
#\[7]FP2NW4YFWKHHWPSWONXYTA6OABMGC77DLJDGDZFXCLCHTLNC7WDQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
