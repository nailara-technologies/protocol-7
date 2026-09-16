---
name: project-fetch-huggingface-checksum-verify
description: "task file scoped to add real sha256 verification to HuggingFace downloads, directly motivated by the shard-4 corruption incident that poisoned four LoRA training runs"
metadata: 
  node_type: memory
  type: project
  originSessionId: eabc6187-b212-4e16-91e1-d998efd6d5a1
  modified: 2026-09-15T05:15:47.326Z
---

Task file: `data/tasks/coding-fetch-huggingface-checksum-verify.md`, not
started as of 2026-09-15.

**Why:** `src/fetch.file.huggingface.handler.download_progress` currently
marks a download `complete` based only on exit code + file existing +
nonzero size -- no content verification at all. This is the confirmed
mechanism behind the [[coding-lora-p7-idioms]] thread's corrupted-shard
incident: a checkpoint file corrupted mid-download (right size, wrong
data) sat undetected for five days and poisoned four separate LoRA
training runs before being found by chance via an unrelated numerical
cross-check. `huggingface-cli` (which does verify LFS hashes internally)
is only reachable from inside `.venv-lora`, not the fetch-files zenka's
own process PATH, so real fetches almost certainly fall through to the
`aria2c` branch, which has zero knowledge of HF's checksums.

**How to apply:** every HF LFS-tracked file (safetensors, GGUF -- i.e.
everything actually worth fetching) has a retrievable sha256 via
`GET https://huggingface.co/api/models/<repo>?blobs=true`, confirmed
live. The task file has the full scope: fetch the expected hash,
compute the local file's hash as a non-blocking child process (this
codebase is event-driven throughout -- a blocking multi-GB sha256 call
would stall the whole zenka), only mark complete on a match, quarantine
on mismatch rather than silently leaving a corrupt file at its final
path. A ready-made real negative test case already exists: the
quarantined `model-00004-of-00004.safetensors.CORRUPT-20260910-do-not-
use` file. Deliberately does NOT try to root-cause the original
corruption mechanism (aria2c resume bug vs something else) -- only
closes the silent-acceptance gap, and the task file says so explicitly
rather than implying more was fixed than was. Also: the hash-fetch call
should use `clients.https.get` (this codebase's existing async, proxy-
aware HTTP client, see [[reference-akamai-alpn-h2-bot-mitigation]]) with
its own bounded retry/backoff -- this host routes outbound traffic
through a hysteria proxy for reliability, and the file download already
benefits from that (aria2c's explicit `--all-proxy` threading) plus
aria2c's own resilient download logic, but the hash-fetch call needs the
same care rather than accidentally bypassing it. A failed hash fetch
must surface as a distinct "unverified" status, never silently fall
back to the old unverified-success path.

## related

[[coding-lora-p7-idioms]]

#,,..,,,,,..,,..,,.,,,,,,,,.,,,..,.,,,..,,..,,..,,...,...,,,,,.,,,..,,,,.,..,,
#3DJNDDRVDYXMZPRQDGDNGZ3URD7QBSNI2QD3UB7EJAZENIRKJJY2IAAESH6WTD2BJQLYGIDSZVVY6
#\\\|2EZCB5ITTIGWUHS2DUGGBNYQ573L6BF66OPF27UELQTWXGCJKVM \ / AMOS7 \ YOURUM ::
#\[7]YRJZHKT7DDJZGHLLJD4PKFWVCY4CD4AQTSJA3EIHOUACEJQQTMCQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
**Status: IMPLEMENTED + LIVE-TESTED [ 2026-09-17, uncommitted ]** — task
`data/tasks/coding-fetch-huggingface-checksum-verify.md` scope items 1-6
done. New modules (all whitelisted in cfg/zenki/fetch-files/
subroutines.load-early, all pass bin/format-code -c):
`fetch.file.huggingface.hash.fetch` (clients.https.get to
/api/models/<repo>?blobs=true, proxy threaded from env explicitly,
bounded retry 3 attempts backoff 3s/6s via handler.hash_retry),
`handler.blob_hash_response` (resolves hash_state pending -> ok|failed|
non-lfs), `verify.start` (cheap lfs.size pre-check then forks sha256sum
via IPC::Open3 + 2s timer-poll, mirrors download child's
pause_ondemand_timeout + report_child_pid lifecycle), `verify.reject`
(quarantine to $dest.CORRUPT-<ts>, status=corrupt), `resume_idle`.
`download` module: decision recorded IN CODE — option (b), aria2c stays
primary, sha256 layer is sole integrity layer independent of fetch tool;
starts hash.fetch in parallel with download. `handler.download_progress`:
success now branches to verifying / awaiting-hash / unverified / non-lfs
complete; complete ONLY reachable via verified match. Three terminal
states: complete (verified), corrupt (quarantined), unverified (hash
unobtainable — NEVER falls through to exit-code-only success).

Live tests 2026-09-17 all passed: (1) quarantined shard-4 sha256 =
fac711b499a5... != published d5e4084c81ccc203... (published hash
re-fetched live from API, confirmed); (2) negative e2e: pre-seeded
size-correct garbage tokenizer.json (19,989,325 B, lfs-exact) ->
aria2c exit 0 -> mismatch detected -> status=corrupt -> quarantined to
tokenizer.json.CORRUPT-20260916-224232, not left at final path; (3)
positive e2e: real 19MB tokenizer.json download -> sha256 verified
06b9509352d2af50... -> status=complete, no regression; (4) non-LFS
config.json -> complete with explicit sha-skipped note. TEST GOTCHA: zenka
runs as user protocol-7 — pre-seeded files must live in a dir protocol-7
can write AND rename in (sticky /tmp bit blocks rename of another user's
file; use non-sticky 0777 for test dirs). p7c deferred-reply commands
print 'command route collapsed' client-side but DO execute — verify via
/dev/shm/.7/STDOUT/NIW7OAQ tail, not the client output.

**Deliberately left open (stated honestly):** the ORIGINAL corruption
root cause — aria2c --continue stitching bug vs proxy/disk vs stalled
connection — was NOT investigated further and NOT fixed. Only the
silent-acceptance hole was closed. Next real occurrence will now be
caught immediately with both hashes logged for diagnosis.

#,,,,,.,.,.,.,,.,,.,,,..,,,..,,,,,,.,,,.,,..,,...,...,...,...,..,,,.,,,,.,,.,,
#HXDEZPHDEWLGPHVQC6UJBX4VWRSIJ2HPDDEXBYGHADOHWK4RMACJP5KVOJRDXAK42Q3TRTRDYIC3S
#\\\|KU6FX2JABBGG3LKN7RQJDYMJLE65F7M73A7EIAVMRY7Q2EZZDHN \ / AMOS7 \ YOURUM ::
#\[7]HISBEVRSOO64XRCVKA6HKDOWIAJLYPMG7IR46KYHMK5H4QV6ZODQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
