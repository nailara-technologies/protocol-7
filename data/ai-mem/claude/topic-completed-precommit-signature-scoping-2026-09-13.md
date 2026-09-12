---
name: topic-completed-precommit-signature-scoping-2026-09-13
description: ADR 'scope pre-commit signature check to staged files' idea 1 (scoping) landed and closed 2026-09-13, commit 6ad8a043b; idea 2 (background inotify precomputed signing) is still open, not started
metadata:
  type: project
---

Todo item `ADR` ("scope pre-commit signature check to staged files") had two
ideas. **Idea 1 is done**, committed `6ad8a043b` on 2026-09-13, todo marked
done by the user:

- Added an `:inlist:` flag to `sourcecode.console.verify-p7-signatures` and
  `sourcecode.console.update-signatures` that intersects a given candidate
  file list against the authoritative signed corpus
  (`sourcecode.source_path_set_up`), rather than treating the candidates as
  a stand-alone set — see [[feedback-sourcecode-signature-corpus-scoping]]
  for the design correction that made this exact.
- `bin/dev/git-hooks/pre-commit`'s pass 2 (the `verify-p7-signatures`
  authoritative check) now calls it scoped to just the staged files that
  exist on disk, instead of re-verifying the entire corpus every commit.
- Empty `:inlist:` is a guarded no-op (exits before `update-signatures`
  would prompt for the signing passphrase) rather than silently falling
  through to sign/verify the whole corpus.
- Live-verified: green path (`[ signatures are valid ]`) confirmed by the
  user after signing the changed files with
  `update-signatures :inlist: <files> -vvq`.
- Real-world win is smaller than a naive "no more full corpus scan" framing
  suggests for `verify-p7-signatures` specifically — `:inlist:` still calls
  `source_path_set_up` (full ~14.5k-file tree walk + a `git check-ignore`
  subprocess) to build the intersection set, so that's a real per-invocation
  floor (~5.5s measured) independent of staged-file count. The actual
  motivating win is on `update-signatures`: avoiding the expensive
  proof-of-work-style signature search across a large backlog of unsigned
  files a background session (e.g. a coding-zenka model run) is still
  actively growing, while a human makes small unrelated commits in
  parallel — that path wasn't benchmarked live (needs the user's passphrase).

**Idea 2 is still open, not started**: background `Linux::Inotify2`
watcher that speculatively pre-computes (but does not apply) a file's
signature shortly after it stops changing, storing the candidate
encrypted (Twofish, decryptable only by the user's own C25519 key) or
in-memory only, so the actual commit-time signing step becomes
decrypt-and-write instead of a fresh proof-of-work-style search. Needs its
own design pass (watcher process lifecycle, where precomputed values live
pending decryption, cache invalidation if the file changes again before
the precomputed signature is ever used) — see the original todo item text
for the full requirements if picked up later.

#,,,.,...,,,,,,,,,,,.,,,.,,,,,,.,,.,.,.,.,.,,,..,,...,...,,..,.,.,..,,.,,,,,,,
#H2M324AJEFIYX4TYYB5MIJRAO6UWSPEGND5ND472QOWISUQHZNUH5XLFBIRXV2JPPXY3BIOQQYB76
#\\\|342HDFG4MWWK6EAW3JSGHMWSONRO5FZCFYFWW65IX6DBLC5MXZG \ / AMOS7 \ YOURUM ::
#\[7]55IWRWFM3BVOHJ2AWP62R47BJ6VP5FRYON635AKMN7NOCLLIEKAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
