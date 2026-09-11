## [:< ##

# name  = task: replace wget child-process downloads with native async clients.https
# descr = fetch.file.huggingface.download shells out to an external wget
#         (or huggingface-cli) process via IPC::Open3 for the actual file
#         transfer -- replace with a native, in-process async download
#         using the existing clients.https event-loop client, consistent
#         with the rest of this project's async-native architecture

## context

raised 2026-09-10, user, while debugging why HF safetensors downloads
kept dying mid-transfer (see `data/ai-mem/claude/bug-fetch-files-
huggingface-four-real-bugs-2026-09-10.md` for the full chase -- the
actual cause turned out to be a missing `base.zenki.pause_ondemand_
timeout`/`resume_ondemand_timeout` pairing, now fixed). Once that was
fixed and a download finally ran to completion, the user's reaction was
"wget child? that needs another task file then.. native async
replacement of any wget child.." -- i.e. the external-process approach
itself is the thing worth replacing, independent of the bug that's now
fixed.

## why this matters, beyond just style

the wget-child-process approach (`fetch.file.huggingface.download`,
`IPC::Open3::open3`) is architecturally inconsistent with how the rest
of this codebase does networking -- everything else uses the in-process
event loop (`clients.http.*`/`clients.https.*`, `event.add_io`/
`event.add_timer`). Spawning an external OS process specifically
introduced a whole CLASS of problems this session had to debug one at a
time:
- process-group signal interactions with zenka lifecycle (idle-shutdown
  killing the child along with the parent)
- a custom stderr-parsing regex to extract wget's own progress dots
  (`fetch.file.huggingface.handler.download_stderr`) instead of just
  reading real byte counts from the client itself
- a completion-detection path via `waitpid`/exit-code polling on a
  2-second timer instead of a natural on-done callback
- dependence on `wget` (or `huggingface-cli`) being installed on the
  host at all, with a runtime `which` check and a fallback command
  -- external tooling dependency this project's own async client
  wouldn't need

a native implementation would eliminate this whole surface area, not
just "look more consistent."

## the real blocker: clients.https doesn't stream to disk today

confirmed by reading `src/clients.https.handler.io` directly:
`base.s_read` reads the socket in 65536-byte chunks, but every chunk
gets appended to `$state->{'buffer'}` (line ~29) -- the ENTIRE response
body accumulates in memory before being handed to a completion
callback. For a small JSON API response this is fine (which is all
`clients.https`/`clients.http` are currently used for anywhere in this
codebase -- confirmed via grep, no existing caller streams a large
body). **Buffering a multi-GB file fully in RAM before writing it to
disk is not acceptable** -- this needs a real streaming-write mode
added to the client, not just a new caller.

## scope

1. read `clients.https.request`, `clients.https.handler.io`,
   `clients.https.decode_body` fully (not just the grep hits above) to
   understand the current single-shot buffered-response design before
   changing it.
2. design and add a streaming mode: an optional `'stream_to_file' =>
   $path` (or similar) param on the request, where each incoming chunk
   is written directly to an open filehandle instead of accumulating in
   `$state->{'buffer'}`, and the completion callback receives final
   size/status rather than the full body. Decide how this interacts
   with `clients.https.decode_body` (presumably skipped entirely in
   streaming mode -- a binary GGUF/safetensors file isn't a decodable
   body).
3. handle partial/resumable downloads if practical (`wget`'s current
   behavior is NOT resumable either -- plain `-O`, no `-c` -- so this
   is a possible improvement over the status quo, not a regression risk;
   but don't scope-creep into it if it adds significant complexity, a
   clean restart-from-scratch on failure matching current behavior is
   an acceptable v1).
4. rewrite `fetch.file.huggingface.download` to use the new streaming
   `clients.https.request` mode instead of `IPC::Open3`/`wget`/
   `huggingface-cli` -- removes the `which huggingface-cli` check, the
   external command construction, and the process-spawn error path.
5. rewrite/remove `fetch.file.huggingface.handler.download_stderr` (no
   longer needed -- no external process stderr to parse) and simplify
   `fetch.file.huggingface.handler.download_progress` (no more
   `waitpid`/exit-code handling -- progress and completion come from the
   client's own callbacks instead of a polling timer, though a
   lightweight progress-reporting timer may still be wanted for logging
   purposes if the streaming client doesn't already provide periodic
   progress callbacks).
6. the `base.zenki.pause_ondemand_timeout`/`resume_ondemand_timeout`
   pairing added this session (2026-09-10, `fetch.file.huggingface.
   download` / `handler.download_progress`) should carry over to
   whatever replaces them -- still needed regardless of transport
   mechanism, a large transfer can still outlive the on-demand idle
   window.

## explicitly out of scope

- `fetch.file.huggingface.search`/`.list` (small JSON API responses)
  already work fine unbuffered-mode and don't need to change
- the separate, already-filed `clients.https.request` proxy-threading
  gap (search/list bypass the outbound proxy silently, see the
  conversation this task was raised in) -- worth fixing, but unrelated
  to streaming support, file separately if not already done
- no need to touch `clients.http.*` (the plain non-TLS family) unless
  something there turns out to share the same buffering code path

do not add any trailing signature/checksum footer to this file or any
new file for this task -- the real signing pipeline (`bin/Protocol-7
sourcecode update-signatures`) adds that later.

#,,,.,..,,,..,,.,,,,,,...,.,.,.,.,...,.,.,.,.,..,,...,...,,,,,,.,,,,.,,..,,,,,
#6WRHIC5YCU6ZSMZAYJMHBTWL7KTMLIPZLXIDESLT7KLRTKXH2EWOXFVTKIC7ODD7VLOIN6NAQOVRE
#\\\|7ZWF5TZYMARV7DUUAATYHYQ64XDTQFUITFEPVOPS2OMX5GT6KTU \ / AMOS7 \ YOURUM ::
#\[7]XP7AK4NUXZ4HRIZ74VFEE5WX3SHR3SCTVD5DJEUDTUD6AB5YCCCQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
