---
name: reference-jobsite-vax-int-id-scheme
description: "jobsite job-id encoding — raw stepstone numeric id vs vax-int-encoded short id, two separate index structures, and how to read a trash archive"
metadata: 
  node_type: memory
  type: reference
  originSessionId: 411cf431-5e68-4206-b38a-3f83e0344616
  modified: 2026-07-27T23:02:52.731Z
---

Derived by tracing `jobsite.job.write`/`jobsite.job.read`/`jobsite.job.index.build`/
`base.vax-int.encode`/`base.vax-int.decode` end to end (2026-07-28), not
documented anywhere in CLAUDE.md.

**The canonical job id is the raw stepstone numeric posting id** (the
digits in `--(\d+)-inline.html`, e.g. `13989040`), extracted by
`site-yaml.stepstone.job` and carried as `'id'` through `job-upsert`.
Everywhere in handler code that decodes `$call->{'params'}{'job_id'}` via
`base.vax-int.decode` is recovering this raw numeric form — that's the
form `jobsite.job.read`/`jobsite.job.write`/`<jobsite.tasks>`/the
in-memory `<jobsite.job.index>` all key on.

**The short base32 form (e.g. `WB2NK`, 5-7 chars) is a filename/display
encoding only**, computed via `base.vax-int.encode` = `base32.encode(pack
'V', $raw_id)` with trailing `A` padding stripped. `job.write` computes
this internally (`$enc_id`) purely to build the on-disk filename
(`jobs/<status>/<enc_id>.yaml`) — callers pass the *raw* id, not
`$enc_id`, to `job.write`/`job.read`. Calling either with the short form
directly does not work (`job.read('WB2NK')` returns `undef` — confirmed
live). User-facing commands like `jobsite.rescue <short-id> [stage]`
accept the short form for convenience and decode it internally, but
direct backend calls (`job.read`, `job.write`, devmod `eval-code` snippets)
need the raw numeric id.

**There are two distinct index structures, differently keyed — do not
confuse them:**
- in-memory `<jobsite.job.index>` (also rebuilt by
  `jobsite.job.index.build` at startup): keyed by **raw numeric** id,
  value is a simple status string (`"trash:V7L36RQ"` etc.). This is what
  `jobsite.cmd.job-upsert`'s dedup check and `jobsite.job.write`/`read`
  use.
- on-disk `/var/protocol-7/jobsite/index.yaml`: keyed by the **encoded
  short id**, value is `{status, score, stage}` — written directly by
  `job.write` (line ~173) for human/debug browsing, unrelated to the
  in-memory lookup path.

Confusing which one a given `$id` variable belongs to is an easy trap —
verified this the hard way mid-review of a kimi-dispatched feature before
realizing the code was actually correct.

**Trash archives are recoverable, not gone**, until
`jobsite.cfg.trash_keep_epochs` (default 1 epoch) rotates them into
`deleted/` and then `deleted_keep_epochs` purges them for good
(`jobsite.store.prune`). A trashed job lives at
`jobs/trash/<V7-epoch-dir>/<enc_id>.yxz.B32` — base32-encoded, xz-compressed
YAML. Decode with:
```perl
my $raw = <slurp the file>;
my $compressed = Crypt::Misc::decode_b32r($raw);   # == base.base32.decode
my $yaml;
IO::Uncompress::UnXz::unxz(\$compressed, \$yaml);
my $job = YAML::XS::Load($yaml);                    # full record, incl. description
```
The epoch-dir name (`V7xxxxx`) decodes to a real date via
`<[base.ntime.epoch_timestamp]>` → `<[base.ntime.epoch_to_ntime]>` →
`<[base.n2u_time]>` (three-step chain; cube's own `localtime <ntime-value>`
console command does the last step and is the easiest way to sanity-check
a result). This is the project's custom "V7 network time" scheme (13-month
network year), unrelated to unix time directly, and **also unrelated to
vax-int** despite both being BASE32-ish short strings — see
[[vax-int-vs-v7-epoch]] for the general warning against cross-decoding
them (this file's job-id encoding uses vax-int; the epoch-dir/trash-batch
dating below uses the V7-epoch scheme; don't feed one into the other's
decoder).

**Writing job data back by hand (recovery/backfill) — pitfalls hit live:**
- devmod `eval-code` via `p7c jobsite.eval-code '...'` works, but multi-line
  scripts embedding literal German (or other non-ASCII) text as inline
  Perl string literals in a bash heredoc are a real mojibake risk — one
  attempt corrupted every umlaut. Safer path: write the target YAML with
  the `Write` tool (UTF-8 safe) to a scratch file, then have the zenka
  `YAML::XS::LoadFile` it and pass the resulting hash straight to
  `jobsite.job.write` — avoids re-transiting non-ASCII text through a
  shell string at all.
- **never call `job.write($id, {})` or any placeholder/empty hash against
  a real id "just to test the call shape"** — it overwrites the live
  record immediately, no confirmation, no dry-run mode. Cost one full
  record (recovered again from the trash-archive dump already sitting in
  scratchpad/conversation output, but only because it happened to still
  be recoverable). Test the call shape against a throwaway id, never a
  real one, or better: read first, mutate the read result, write that
  back — never construct a fresh minimal hash by hand for an existing id.

See also [[project-jobsite-reports-archive-vision]] for the case that
motivated this investigation.

#,,,,,..,,,,.,...,,,,,.,.,,..,,..,,,.,,,.,,,,,..,,...,...,...,.,.,.,.,.,.,.,,,
#4XXQX7COINSVQ3EHRAX34H7VU33JGMCMAYKDLWMY33B6D674OFXPFE5EOGDAGFERFP2JNGOQOBXLI
#\\\|E3LYUBDN6ZKZQV72QI5PXC7NAP4VDZWUSXUCS6PF7EQDGD65EVV \ / AMOS7 \ YOURUM ::
#\[7]OG72W5XK2DEW23O3TW5XCM4DCGM6K7JTJSDSQR37EFBVEFAHOKBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
