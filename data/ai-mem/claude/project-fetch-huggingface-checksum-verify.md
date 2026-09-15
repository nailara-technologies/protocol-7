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
