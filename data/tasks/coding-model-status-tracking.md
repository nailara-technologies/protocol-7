## [:< ##

# name  = task: per-(checksum,backend) model status tracking + read command
# descr = durable functional/failure status for every model a backend has
#         attempted, recorded automatically at the 3 real code paths that
#         already decide pass/fail/resource-insufficient today.

## scope

read ONLY the "part 1 -- status table" section of
`data/md/design/MODEL-STATUS-TRACKING.md` (lines 13-75 as of this writing).
"part 2 -- async sweep iterator" (the rest of that file) is a SEPARATE task
(`data/tasks/coding-model-sweep-iterator.md`) that depends on this one
landing first -- do not build any of it here, do not read it as scope for
this task.

this is a self-contained, dispatchable unit: 1 new module family
(`coding.model_status.*`, 2 files) + small additions to 3 existing files +
2 config registrations. no live zenka execution needed to verify it.

## the 5 states (already decided, do not re-derive)

```
untested              default -- no entry for this (checksum, backend) pair
functional             full self-test pass (3/3, same bar as coding.self_test)
inference-failures     server came up, self-test ran, did not fully pass
startup-failure        server itself never came up
resource-insufficient  spawn_smart declined to even attempt -- model too
                        big for available VRAM/RAM on THIS host right now
```

keyed per `(checksum, backend)` pair, NOT per checksum alone -- `functional`
on gpu implies nothing about cpu. `checksum` here is the `amos` field
already used throughout `coding.*` (format `XXXXXXX:XXXXXXX`, see
`src/coding.cmd.switch-model:21-27` for the format/usage precedent) --
this is the SAME identifier `coding.model_metadata`'s entries carry in
their `.amos` field. do not confuse with `models.registry.*` (a different,
unrelated module family under `src/models.registry.*` -- do not touch it,
do not read from it, this task only reads/writes `coding.model_metadata`
and the new store below).

## the persisted store -- mirror `coding.self_test.archive` exactly

`src/coding.self_test.archive` (read this file in full before starting --
it is the load-merge-write pattern to copy) already solves "durable,
cross-restart, per-model stats" for a different purpose (self-test retry
histograms). its lines 66-102 are the exact shape to reuse:

- file: `state/model_status.yaml`, loaded/written via
  `<[file.zenka_dir.load]>->('state/model_status.yaml')` /
  `<[file.zenka_dir.write]>->( $file, \$yaml_str, qw| > |, 0640 )`
- format string round-trip via `<[format.yaml.load_str]>->($str)` /
  `<[format.yaml.dump_str]>->($hashref)` -- NOT raw `YAML::XS`, that's a
  separate (older) precedent used by `coding.init_code`'s
  `model_metadata.yaml` load, don't copy that one for the new writes.
- on every write: load existing yaml from disk, merge in just this
  `(checksum, backend)` entry, write the whole merged structure back --
  same as `self_test.archive`'s stats block, not a naive overwrite.

on-disk shape:

```yaml
<checksum>:
  <backend>:
    status: functional            # one of the 5 states above
    detail: "3/3 passed"          # free text, human-readable context
    last_updated: <ntime>
```

**pitfall, load-bearing here**: `file.zenka_dir.*` and `format.yaml.*` are
called UNPREFIXED at runtime (`<[file.zenka_dir.load]>`,
`<[format.yaml.dump_str]>`) even though their actual source files are
`src/base.file.zenka_dir.load` and `src/format.yaml.dump_str` -- the
`base.` prefix is stripped for this module family at call time. get this
wrong and the module simply won't resolve. `self_test.archive` and
`self_test.cmd.self-test-detail` both already call it this way -- match
them exactly, do not write `<[base.file.zenka_dir.load]>`.

## new module 1 -- `src/coding.model_status.record`

writer, called only from the 3 sites below (section further down), never
from a `.cmd.` file directly.

- params: `{ checksum, backend, status, detail }`
- **rule, explicit**: if `checksum` is empty/undef, `backend` is
  empty/undef, or `status` is not one of the 5 known state strings, return
  `{ mode => 'false', data => '<reason>' }` and do NOT write anything --
  never create an entry keyed on `''`. this matters because 2 of the 3
  write sites below only have a checksum in scope conditionally.
- on success: update in-memory `<coding.model_status>->{$checksum}{$backend}`
  AND persist to `state/model_status.yaml` per the load-merge-write pattern
  above, in the same call (don't split write-memory and write-disk into
  two subs).
- `last_updated` is always `<[base.ntime]>` at write time, ignore anything
  the caller passes for it.
- return `{ mode => 'true', data => 'recorded' }` on success.

## new module 2 -- `src/coding.model_status.cmd.model-status`

reader, registered as a p7c command. mirror
`src/coding.self_test.cmd.self-test-detail` (read it in full) for the
overall shape: `.cmd.` file, `my $params = shift // {}`,
`$params->{'args'}` as the single optional positional string, reply shape
`{ mode => 'size', data => "<text>\n" }` for a human-readable text blob
(same reply-mode convention `self-test-detail` already uses for its own
listing output).

- `$params->{'args'}`, if present, is an optional backend filter (`gpu` or
  `cpu`) -- empty/absent means show all backends.
- read from in-memory `<coding.model_status>` first; if empty (e.g. zenka
  just restarted and nothing has run yet this session), fall back to
  loading + parsing `state/model_status.yaml` the same way
  `self-test-detail` falls back to `self_test-stats.yaml` at its own
  lines 44-48 -- same fallback shape, different file.
- one output line per `(checksum, backend)` pair, sorted by checksum then
  backend, format: `<checksum> : <backend> : <status>` with `
  [<detail>]` appended when detail is non-empty.
- no records found (after both in-memory and disk-fallback are empty):
  return `{ mode => 'size', data => "no model-status records yet\n" }`,
  same "helpful empty state" convention `self-test-detail` uses at its
  own lines 27-31.

this read command is what makes this task independently verifiable and
useful before the sweep iterator (task 2) exists at all -- without it the
store is write-only and nobody can see what landed.

## registration (2 files, both mechanical)

1. `cfg/zenki/coding/zenka.v7` -- add `model-status` to the `keywords =`
   continuation list (see line ~70, right where `self-test-detail` already
   sits, same list). this is the ONLY manual step; do not hand-edit
   anything else in this file.
2. `cfg/zenki/coding/subroutines.load-early` -- **do not hand-edit this
   file**, it is auto-generated (its own header says so: "regenerate
   with: bin/dev/gen-sub-whitelist coding"). after adding the new files,
   run `bin/dev/gen-sub-whitelist coding` and confirm
   `coding.model_status.record` and `coding.model_status.cmd.model-status`
   now appear in the regenerated file.

## the 3 write sites (all real, all already grounded to exact lines)

### site 1 -- `src/coding.self_test.handler.poll_probe`, the `done` phase

around line 541 (`if ( $state->{'phase'} eq qw| done | )`), after
`$summary` is built (~line 565) and before the guard-release block
(~line 569 onward, `<coding.self_test_probe_in_flight>->{$backend} =
FALSE`), add a call to `coding.model_status.record`:

- `checksum => $model_id` (already in scope, already the amos checksum --
  this is the SAME identifier `<[coding.self_test.archive]>` receives as
  its own `model_id` param a few lines earlier at line 517, no new
  resolution needed)
- `backend => $backend` (already in scope, used at line 577 right below)
- `status => $state->{'all_passed'} ? 'functional' : 'inference-failures'`
- `detail => sprintf('%d/%d passed', $state->{'pass_count'},
  $state->{'test_count'})`

**do not confuse this with the existing `<[coding.self_test.archive]>`
call at line 515** -- that call already exists, fires PER PROMPT, and
records fine-grained per-prompt detail for a different purpose (retry
histograms). the new call here is a single aggregate write at the `done`
phase only, once per self-test round.

### site 2 -- `src/coding.handler.spawn_smart`, resource-insufficient returns

two early `return FALSE;` sites, both inside memory-check blocks that
already have `$matched_entry` (with its `.amos` field) and `$backend` in
scope:

- GPU branch, right before the `return FALSE;` at line 194 (insufficient
  VRAM)
- CPU branch, right before the `return FALSE;` at line 226 (insufficient
  RAM)

at each: `my $checksum = $matched_entry->{'amos'} // '';` then call
`coding.model_status.record` with `checksum => $checksum, backend =>
$backend, status => 'resource-insufficient', detail => '<the same
MB-free/MB-needed numbers already in the surrounding <[base.logs]> call
at that spot>'` -- skip the call entirely (per the "never key on ''"
rule above) if `$checksum` comes back empty.

### site 3 -- `src/coding.handler.verify_inference_startup`, retry exhaustion

line 189 (`if ( $restart_count >= 5 )`), before setting
`$server_info->{'status'} = qw| failed |;` at line 196: this branch has
NO checksum in scope today -- `$server_info` (`<coding.inference_servers>
->{$backend}`) only gets a `'model'` field written once a server reaches
`ready` (`src/coding.handler.monitor_inference_startup:113`,
`$server->{'model'} = <inference.model.amos_id>`), which never happens on
this failure path by definition. fix this by making the checksum
available at SPAWN time instead of ready time, via 3 small threading
changes (do all 3, they're one coherent change):

1. `src/coding.spawn_inference_server` -- accept a new param
   `my $amos_id = $params->{'amos_id'} // '';` near its existing param
   parsing (~line 41, alongside `$model_path`), and add `'model' =>
   $amos_id,` to the `<coding.inference_servers>->{$backend} = { ... }`
   hash literal (~line 515-529). **use the SAME field name `'model'`
   `monitor_inference_startup` already writes on the ready path** -- do
   not invent a second field (`amos_attempted` etc). both paths write the
   identical amos checksum for the same target model; the ready-path
   write later is a harmless no-op overwrite with the same value, not a
   collision. if `amos_id` is never passed, this defaults to `''`,
   unchanged from today's behavior. no guard needed against the
   overwrite: the field means "what this server is/was running," so the
   ready path (the more authoritative, confirmed-live source) is
   correctly allowed to win if it and the spawn-time value ever diverge
   -- the failure path in site 3 below only ever reads this field when
   the server never reached ready in the first place, so no overwrite
   has occurred by the time it reads.
2. `src/coding.handler.spawn_smart` -- the direct-path call to
   `coding.spawn_inference_server` (~line 242-248, the `if ( length
   $model_path && -f $model_path )` branch) already has `$amos_id` in
   scope (computed at line 235, earlier in the same sub) -- add `amos_id
   => $amos_id,` to that call's params hash.
3. `src/coding.handler.spawn_smart_path_reply` -- its own call to
   `coding.spawn_inference_server` (~line 43) -- this handler already
   receives `$amos_id` as one of its own params (line 9,
   `$params->{'amos_id'}`, itself passed in by `spawn_smart`'s async
   `cube.models.get_path_by_amos` dispatch at line 266) -- add `amos_id
   => $amos_id,` to that call's params hash too.

then, back in `verify_inference_startup` at line 189: `my $checksum =
$server_info->{'model'} // '';` and call `coding.model_status.record`
with `checksum => $checksum, backend => $backend, status =>
'startup-failure', detail => 'restart_count exhausted'` -- again, skip
the call if `$checksum` is empty (a spawn attempt that never even reached
`coding.spawn_inference_server`, e.g. the "no model configured" early
return in `spawn_smart`, correctly produces no status entry rather than
one keyed on `''`).

## init-time load (mirror `coding.init_code`'s model_metadata load)

`src/coding.init_code:148-161` already loads `state/model_metadata.yaml`
into `<coding.model_metadata>` at startup. add an equivalent block
immediately after it (after line 161) that loads `state/model_status.yaml`
into `<coding.model_status>`, same shape: `<[file.zenka_dir.load]>`,
`eval { YAML::XS::Load(...) }`, `ref $loaded eq qw| HASH |` guard,
`<coding.model_status> //= {};` fallback. without this, a freshly
restarted zenka answers `coding.model-status` from an empty in-memory hash
until the disk-fallback logic in the `.cmd.` handler kicks in -- both
paths should exist (init-load for the common case, cmd-level fallback as
defense-in-depth, exactly like `self-test-detail` already does for
`self_test-stats.yaml`).

## explicitly out of scope

- the sweep iterator (part 2 of the design doc) -- separate task file,
  separate dispatch, depends on this one.
- `llm.service.consensus_vote`'s hardcoded `%MODELS` (qwen/mathstral/aya,
  none of which exist in the real registry today) -- a real future
  consumer of this status table, per the design doc's own "relation to
  other docs" section, but wiring it up is not part of this task. don't
  touch `src/llm.service.consensus_vote`.
- `models.registry.*` -- unrelated module family, do not touch, do not
  read from it for this task.
- no live network/filesystem execution required or expected for this
  task -- everything above is static code + one generator script run.

## validation (execution-free)

- `bin/dev/ptd -c` on every changed/new file.
- trace each of the 3 write sites by hand against a specific hypothetical
  state and state in your summary what gets written: (a) a self-test that
  finishes 2/3 passed on gpu for checksum `ABC:123`, (b) a gpu spawn_smart
  call where `$matched_entry->{'amos'}` is `DEF:456` and free VRAM is
  below the required threshold, (c) a cpu server whose `restart_count`
  hits 5 after a successful earlier spawn had set `model => 'GHI:789'`.
- confirm `bin/dev/gen-sub-whitelist coding` picks up both new modules
  and re-run it, diff the result.
- do NOT attempt to start a zenka or run `p7c coding.model-status` live
  -- that's for the user to do after review, per this repo's normal
  kimi-dispatch review flow.

#,,.,,,..,.,.,,,.,,,.,...,,..,,,.,.,,,,,,,..,,..,,...,...,..,,,,.,.,,,..,,,..,
#SKEZKBQG2HEL3S357LKWXMJIVXQ5GP54JYRUWGCSJ564QOLN2Q6FE4HWV5CD44ZMFTTUJLEHRAFDG
#\\\|FNE3IFUP7SAWASAAMNNWKWEPCXFGKLVBPKISSXHY2C525CQFYYK \ / AMOS7 \ YOURUM ::
#\[7]2C7XBLRUXVJB3LTSSRWQEMITUVFSD5CQGLSSEMS7ZQ3XPPACQSAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
