## [:< ##

# name  = task: verify checksums on HuggingFace downloads
# descr = fetch.file.huggingface.download currently accepts any file that
#         exits 0 and has a nonzero size -- no content verification at all.
#         this is the confirmed mechanism behind a real incident: a
#         corrupted checkpoint shard silently poisoned four LoRA training
#         runs. add real hash verification to close this gap.

## context

`data/tasks/coding-lora-p7-idioms.md`'s "sixth pass" section (2026-09-15)
found and fixed a real incident: the local `petruhonk/Qwen3.8-9B-Distill-
uncensored-heretic` checkpoint's shard 4 (`model-00004-of-00004.
safetensors`) was corrupted at fetch time on 2026-09-10 -- right file
size, byte-identical safetensors header, wrong data section from roughly
the halfway point onward. sha256 mismatch against the published HF LFS
hash. This sat on disk undetected for five days and silently poisoned
four separate LoRA training runs plus a full session's worth of
diagnostic probes, all of which "worked" in the sense of running to
completion without error -- the corruption was only found by chance,
via an unrelated three-way GGUF numerical cross-check.

## root cause, confirmed by reading the actual code [ not guessed ]

`src/fetch.file.huggingface.handler.download_progress` determines
download success like this (read directly, current as of 2026-09-15):

```perl
my $succeeded
    = defined $exit_code
    ? ( $exit_code == 0 && -f $dest )
    : ( -f $dest && ( -s $dest ) > 0 );    ## no trustworthy exit code ##
```

That is the entire integrity check: exit code (if available) plus file
existence plus nonzero size. **There is no content verification anywhere
in this path.** A file that is the right size with garbage bytes in the
middle -- exactly what happened -- passes this check every time.

`src/fetch.file.huggingface.download` has two possible download tools:

```perl
if ( open( my $null, '-|', 'which', 'huggingface-cli' ) ) {
    while (<$null>) { $use_hf_cli = 1 }
    close($null);
}
```

The official `huggingface-cli`/`hf` client DOES verify LFS file
integrity against the repo's published sha256 as part of its own
download flow -- if that path were actually taken, this incident likely
wouldn't have happened. But `which huggingface-cli` runs in the
fetch-files zenka's own process environment, and that binary is only
installed inside `.venv-lora` (`/data/projects/protocol-7/.venv-lora/
bin/huggingface-cli`), a project-specific python virtualenv the zenka's
process never activates. **`$use_hf_cli` almost certainly evaluates
false in real operation**, meaning production fetches fall through to
the `aria2c` branch -- a generic, HF-unaware downloader with zero
knowledge of LFS checksums. This is the confirmed mechanism: not a bug
in aria2c's resume/retry logic specifically (never proven, still an
open question below), but a total absence of any verification layer
downstream of whichever tool actually ran.

## what HuggingFace actually exposes [ confirmed live, 2026-09-15 ]

Every LFS-tracked file (safetensors, GGUF, any large binary -- which
covers essentially everything this project fetches) has a retrievable
sha256, confirmed via a direct API call:

```
GET https://huggingface.co/api/models/<repo>?blobs=true
```

returns each file's `siblings` entry with an `lfs` block:

```json
{
  "rfilename": "model-00004-of-00004.safetensors",
  "size": 3934446832,
  "lfs": { "sha256": "d5e4084c81ccc203fe573b1b8176f12c9b986c948988f6a94d660bc65079f58", "size": 3934446832, "pointerSize": 135 }
}
```

Small non-LFS files (tiny configs, index.json) have no `lfs` block --
just a git blob id (git's own SHA1-over-`"blob <size>\0<content>"`
scheme, not a plain file sha256, and a different verification method
if ever wanted). These are low-risk given their size and out of scope
here; **this task is specifically about LFS-tracked files**, which is
everything actually worth corrupting silently.

## scope

1. **fetch the expected hash before or after download**: call the
   `?blobs=true` endpoint (or the per-file `/api/models/<repo>/
   resolve/main/<file>` HEAD response, which also carries the LFS
   sha256 in a header on most HF endpoints -- confirm which is more
   reliable/cheaper before picking one) to get the expected sha256 for
   the specific file being fetched. Cache this alongside the existing
   `<fetch.file.downloads>` tracking entry rather than re-fetching it
   redundantly if the download retries. **Use `clients.https.get`**
   (`src/clients.https.get`, this codebase's existing async HTTPS
   client -- non-blocking, already proxy-aware, already hardened
   against real-world reliability issues, see `[[reference-akamai-
   alpn-h2-bot-mitigation]]`) for this call rather than a one-off
   LWP/curl invocation -- it's the natural fit for an event-driven
   zenka and inherits proxy handling that already matters here (the
   user confirmed this host's outbound traffic goes through a hysteria
   proxy for reliability; the file download already gets this via
   aria2c's explicit `--all-proxy` threading, and the hash-fetch call
   should get the same benefit through `clients.https` rather than
   accidentally bypassing it). This host's network can still be flaky
   (mobile uplink) even through the proxy, so still don't assume a
   single request always succeeds: give the hash-fetch call its own
   bounded retry-with-backoff (a metadata call this small doesn't need
   `aria2c`'s unbounded-retry philosophy -- a handful of attempts is
   reasonable, just don't hang forever on one attempt or give up on the
   first failure). **Two failure modes to explicitly avoid**: (a) a
   transient failure fetching the expected hash blocking the whole flow
   ungracefully; (b) treating "couldn't fetch the expected hash" as
   equivalent to "no verification needed" and falling through to the
   old exit-code-only success path -- that would silently reintroduce
   the exact vulnerability this task exists to close. If the expected
   hash genuinely can't be obtained after reasonable retries, the
   download must NOT be marked `complete`; surface a distinct status
   (e.g. `unverified` or `hash-fetch-failed`) so a human/caller can see
   the difference between "verified good," "verified corrupt," and
   "never got to verify" -- these are three different states, don't
   collapse the third into either of the first two.

2. **compute the local file's sha256 after download completes** (exit
   code 0, file exists, size matches expected `lfs.size` too -- a cheap
   pre-check worth doing before the expensive hash pass). **Hazard,
   read before implementing**: this codebase is event-driven/async
   throughout (`base.event.*`, non-blocking I/O everywhere) -- hashing
   a multi-GB file with a blocking `Digest::SHA` call inside the
   handler would stall the entire fetch-files zenka's event loop for
   however long that takes (real, non-trivial time for an 18GB file).
   Do this the same way the download itself is already handled: spawn
   it as a child process (`sha256sum $dest`, or a small forked Perl
   subprocess) via the same `IPC::Open3`/non-blocking-I/O/timer-poll
   pattern `fetch.file.huggingface.download` already uses for the
   download itself, not a synchronous call in the main handler.

3. **only mark `status = complete` on a hash match.** On mismatch:
   mark the download `status = corrupt` (a new status value, distinct
   from `failed`), log loudly with both hashes for diagnosis, and
   **do not leave the corrupt file at its final path** -- move it aside
   (e.g. `$dest.CORRUPT-<timestamp>`, matching the manual convention
   already used to quarantine the shard 4 incident) so a later fetch
   attempt doesn't get confused by a stale bad file sitting where a
   good one is expected, and so nothing downstream can accidentally
   load it. Consider whether to auto-retry the fetch once (a corrupted
   download is often transient) or simply fail loud and let the caller
   decide -- err toward failing loud first; auto-retry silently risks
   masking a real, reproducible corruption source (e.g. a proxy/CDN
   issue) behind an eventual accidental success.

4. **decide the `huggingface-cli`-availability question explicitly**
   rather than leaving it as an accidental fallback: either (a) make
   `.venv-lora`'s `huggingface-cli` (or a system-wide install) actually
   reachable from the fetch-files zenka's process `PATH` so the
   already-verifying official client is the normal path and aria2c
   becomes the true fallback it was designed to be, or (b) keep aria2c
   as primary (it has real advantages already documented in the code --
   resume, stall detection) and treat step 1-3's sha256 check as the
   sole integrity layer regardless of which tool fetched the bytes.
   (b) is probably simpler and more robust (verification independent of
   fetch mechanism, doesn't regress if the venv path ever changes) --
   but record the decision either way, don't silently pick one.

5. **the still-open question from the original incident, worth a real
   answer, not just a shrug**: was this genuinely a chunked-download/
   resume stitching bug in aria2c's `--continue` handling (the original
   suspicion), or something else (a stalled connection that got quietly
   accepted, a disk-level issue, a proxy corrupting bytes in transit)?
   With verification now in place, the NEXT occurrence will be caught
   immediately with a fresh, cleanly-reproducible case -- if this task
   lands the verification layer but doesn't chase the original root
   cause further, say so explicitly in the write-up rather than
   implying the underlying corruption source itself was found and
   fixed (it wasn't -- only its silent-acceptance was).

6. **test it for real**: the quarantined corrupt file from the original
   incident (`/mnt/ext-xfs-data/models-lmstudio/petruhonk/Qwen3.8-9B-
   Distill-uncensored-heretic/model-00004-of-00004.safetensors.
   CORRUPT-20260910-do-not-use`, kept specifically for this) is a ready-
   made real-world negative test case -- confirm the new verification
   logic actually flags it (compute its sha256, confirm it does NOT
   match the published `d5e4084c...`, confirm the code path that would
   fire on a live mismatch behaves as designed) before considering this
   done. A positive test (a small, cheap-to-fetch real HF file, hash
   matches, marked complete normally) is also worth a quick live run to
   confirm no regression to the normal, common-case path.

## out of scope, intentionally

- Non-LFS small file verification (git blob SHA1) -- low value given
  the size/risk profile, different verification scheme, can be a
  follow-up if ever wanted.
- Actually root-causing aria2c's suspected stitching bug in the
  abstract (scope item 5 above only asks to leave the question honestly
  open, not to resolve it without a fresh reproducible case).
- Retroactively re-verifying every other file already on disk from past
  fetches -- this task is about closing the gap going forward, not an
  audit of historical downloads (though if that seems cheap once this
  lands, it's a reasonable separate follow-up to suggest).

## done, 2026-09-17 -- kimi_dispatch(model=k2.8)

Implemented exactly per scope. Expected sha256 fetched via
`clients.https.get` (`?blobs=true`, proxy threaded explicitly), cached
on the download entry, bounded 3-attempt retry with backoff. Hashing
forked via `IPC::Open3` + non-blocking I/O + timer-poll, mirroring the
download child's own pattern -- no blocking `Digest::SHA` in the event
loop. Three distinct terminal states wired through consistently:
`complete` (verified match), `corrupt` (mismatch, quarantined to
`$dest.CORRUPT-<timestamp>`, never left at the final path), `unverified`
/ hash-fetch-failed (never silently treated as "no verification
needed"). Item 4 decided in code: aria2c (later replaced, see the
native-async-transport task) stays primary; the sha256 layer is the
sole integrity layer, independent of fetch mechanism.

**Live-verified, all real, not simulated**: the actual 2026-09-10
quarantined shard's sha256 confirmed mismatched against the published
hash (fetched live, not assumed); a seeded exact-size garbage file
caught and quarantined end-to-end; a real small file downloaded and
verified with no regression to the normal path; a non-LFS file
completing with sha explicitly noted as skipped rather than silently
"verified". Committed `5ac9b18f7`.

**Item 5 (root cause) deliberately left open**, per this task's own
instruction: whether the original corruption was aria2c's `--continue`
stitching, a stalled connection, or something else was NOT investigated
further -- only the silent-acceptance hole is closed. The next real
occurrence will now be caught immediately with a fresh, cleanly-
reproducible case.

#,,.,,,,.,...,..,,.,,,,,,,,,,,,.,,,,.,.,,,,,,,..,,...,...,..,,..,,,..,.,.,,,.,
#FXJNXZ34L6SDZF2UJIUID6ZINK24IWZKTAMZ7XYHGSWTQOTC23SPCHE7YVGXDFIYVR4CRLTBJ6MBC
#\\\|CGC5BLSENW5FFBVSESCJSOGLA5RHZITLTSZN3RDOYGPHOCWXXHC \ / AMOS7 \ YOURUM ::
#\[7]LCNX5ALDHJAVZWIGW3CD36FUF5MFUHLXC2GEV74OMU2NOO2ERYDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
