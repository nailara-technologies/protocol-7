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
[[project-ncode-write-path-2026-07-24]]. `write_with_perms` itself has not
been fixed and should be treated as a broken reference for this specific
detail, not copied from, until it is.

**This is a repeat finding, not a first discovery.** The exact same bug was
already found and fixed once, in `coding.tools.handler.write_append`, on
2026-06-06 (buried in [[topic-next-steps]]'s completed-session log, no
dedicated memory file existed until now — that's likely why it didn't stop
`write_with_perms` from being written with the same bug afterward, and why
it took a second multi-hour live debugging session to rediscover). Treat
`write_with_perms` as a confirmed, unfixed, real bug — not just a "don't
copy this" note — see the roadmap item in [[topic-next-steps]].

#,,,,,,,,,,,,,,.,,,..,.,,,,.,,.,,,.,.,..,,..,,..,,...,...,.,.,.,,,,..,,,,,,..,
#JH3QZHPTTVSAXJJEQUI5Z7FTB2GMBPHDBQYBPK2E537TVDB7L3JQR35B4OVM4I5EOUXGQ3WXZZOOS
#\\\|NPT5FGL6FRIGCNTE3GLOVNEJZR4KZI6OFHYVZWP2UNHPTB7GFDN \ / AMOS7 \ YOURUM ::
#\[7]IUA2WFOPVZ3XP2HTBHLSB42O7FKGJEOGSIQNRBZT3RBBZS3VHUDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
