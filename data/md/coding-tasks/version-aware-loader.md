## version-aware loader + deferred compilation ##

architectural upgrade to the protocol-7 module loader enabling atomic
reload, rollback, lazy loading, and elimination of the purge exclusion list.

mark checklist items as completed alongside the corresponding commits.

---

### motivation

the current `p7_purge_code` in `bin/Protocol-7` maintains a hardcoded
exclusion list of 30+ modules that must survive reload because they are
called during the reload process itself. this list requires manual maintenance
and is a source of subtle reload failures when new core dependencies are added.

the version-aware loader eliminates this problem entirely: the new version
compiles into a separate hash while the active `%code` is never touched.
the exclusion list exists solely because the current method overwrites the
live hash in-place — modules called during reload must survive the process.
with the staging hash approach, the active version remains fully intact and
callable throughout compilation. the swap only happens after the new version
is complete and all replacement strategy assertions have passed. the exclusion
list becomes structurally unnecessary.

---

### core data structures

#### versioned code hash

```perl
##  $CODE{$version}->{'module.name'} = \&compiled_sub  ##
my %CODE;    ##  versioned code store  ##
```

the swap itself is as simple as it gets:

```perl
$CODE{$old_version} = \%code;        ##  archive current live hash  ##
%code = $CODE{$new_version}->%*;    ##  replace with new version    ##  =)  ##
```

rollback is the mirror:

```perl
%code = $CODE{$old_version}->%*;    ##  restore prior version  ##  =)  ##
```

`%code` remains `%code` at every call site — no proxy, no tie, no
`$active_version` indirection required for phase 1. single-threaded perl
hash assignment is effectively atomic within the event loop.

`$active_version` (a string tracking the current version key) is still
useful for logging, fingerprint comparison, and the rollback window timer,
but is not load-critical for the swap itself.

#### source store

```perl
##  $SOURCE{$version}->{'module.name'} = $source_str  ##
my %SOURCE;    ##  content-addressed source store  ##
```

- `%SOURCE` may later be tied to alternative backends:
  disk (default), SHM, network (fetched via cube routing),
  content-addressed store keyed by AMOS7 checksum
- source is always read at load time — never deferred — to freeze disk state
  and avoid drift. only the `eval` step is deferred.

#### version key

the version key IS the AMOS7 checksum from the module footer —
content-addressed, collision-free, already computed at signing time.
no separate versioning scheme needed.

format: `$CODE{$version_string}->{'module.name'}` where `$version_string`
is the src-ver string e.g. `3PL75UU7LY-6684.0`

---

### load modes

the swap line is identical for all modes — what differs is how the staging
hash is prepared before the swap:

```perl
$CODE{$old_version} = \%code;        ##  archive current live hash  ##
%code = $CODE{$new_version}->%*;    ##  swap in prepared staging    ##
```

patching happens IN `$CODE{$new_version}` before the swap, so the swap
itself stays a simple one-liner regardless of mode.

#### default: transactional load

- compile all modules into `$CODE{$new_version}` staging hash
- if any module fails: abort, discard staging hash, keep active version
- if all succeed: swap as above
- old version hash kept in memory for rollback window (configurable duration)

#### `:force-replace:` and `:force-keep:`

designed for developers and auto-upgrade scenarios where backends must
remain online and a fast iteration pace is required:

- compile new version into staging hash as usual
- for each module that failed compilation:
  ```perl
  $CODE{$new_version}->{$mod} = $CODE{$old_version}->{$mod};  ## borrow working slot ##
  ```
- swap proceeds with the patched staging hash — backend stays fully online
- borrowed slots are tracked and reported: `[ kept from prior: N modules ]`
- on the next reload attempt, successfully compiled modules replace their
  own borrowed slots — the borrowed set shrinks with each bug fixed
- converges to a fully new version over successive reload cycles without
  ever requiring a full restart or a clean-compile gate

`:force-replace:` additionally checks compatibility fingerprint before
borrowing — only borrows if api surface is compatible with the new callers.
`:force-keep:` borrows unconditionally and reports the kept set.

both modes accommodate:
- developers iterating fast with partial fixes
- prod auto-upgrades where some modules may temporarily lag
- systems where intentional restart is the only acceptable downtime event

#### low-memory mode

- keep only one version in memory at a time (no rollback window)
- discard previous version immediately after successful swap

---

### eliminating the purge exclusion list

with atomic swap, the exclusion list in `p7_purge_code` becomes unnecessary:

- reload compiles into `$CODE{$new_version}` — the old `%code` is untouched
- modules called during reload (base.log, base.sort, etc.) continue using
  the active version throughout
- after successful compile: swap active version pointer
- `p7_purge_code` exclusion list can be dropped entirely
- `$data{'base'}{'core_subs'}` registry remains for documentation purposes
  but is no longer load-critical

---

### compatibility fingerprint

a hash of the public api surface of a module set:
- exported subroutine names
- arity (number of expected parameters where statically determinable)

two versions with matching fingerprints are provably safe to hot-swap.
feeds into `:force-keep:` and `:force-replace:` decisions.

stored alongside the version: `$FINGERPRINT{$version}`.

---

### rollback

- after atomic swap, old `$CODE{$old_version}` remains in memory
- rollback = `$active_version = $old_version` (zero recompilation)
- rollback window: configurable, default suggested 60-300s
- after window expires: `delete $CODE{$old_version}` to free memory

#### auto-rollback

- start a one-shot timer after reload (configurable interval)
- monitor error counters in `%data` during window
- if unexpected error rate exceeds threshold → revert active version pointer
- triggers a log event and optional alert via cube routing
- rollback rules (phase 2): declarative rules in
  `cfg/loader/rollback-rules/` specifying conditions under which
  auto-rollback is safe or should be forced

#### fallback machinery protection

the rollback handler, auto-rollback timer, and error counter monitor
dispatch through `$CODE{$old_version}` — the same atomic swap property
that eliminates the exclusion list also protects recovery code:

- a failed reload that never swaps in never touches the old version
- fallback routines cannot be destroyed by the reload they are guarding
- during parallel transition: migrate rollback handler into the versioned
  store FIRST — it is then protected before any other module is migrated
- one-by-one migration is safe: each module moved into `%CODE{$version}`
  is immediately protected; no "all or nothing" cutover required
- slim interface: fallback path needs only `$active_version = $old_version`
  — keep it in compiled-in `bin/Protocol-7` code, not in `%code` at all,
  so it survives any module-level reload failure unconditionally

#### concurrent versions

- different zenki can hold different `$active_version` pointers
- enables staged rollouts: route a subset of requests to the new version
- v7 can coordinate version adoption across the network
- useful for A/B testing module versions in production

---

### deferred / lazy compilation

goal: read source from disk at load time (freeze), defer `eval` to first use.

#### compile-time deferral decision

- dep-graph `-zenka=NAME` reachability analysis determines load tiers:
  - tier 0: entry-point modules → compile immediately (synchronous)
  - tier 1: reachable within 2 hops → compile during init, before loop
  - tier 2: reachable, deeper → compile via short post-init timer
  - tier 3: loaded but unreachable (static analysis) → lazy on first call
  - remove: modules in dep-graph `unreachable` list → drop from `modules.load`

- deferral decision made at load time from dep-graph data
  NOT at disk-read time — source always read immediately

#### lazy trigger

- `%code` proxy: if `$CODE{$active_version}->{'module.name'}` is undef
  but `$SOURCE{$active_version}->{'module.name'}` is present → compile on access
- no change to call sites — `$code{'module.name'}->()` syntax unchanged

#### error reporting while deferred

deferred modules report errors WITHOUT compiling:
- checksum verified against AMOS7 footer at load time
- if checksum matches signed version AND perl version unchanged since signing →
  `perl -c` result from signing time is considered still valid
  → status: `[ deferred, syntax valid ]`
- if checksum mismatch → report immediately as `[ deferred, checksum invalid ]`
- if perl version changed → revalidate with `perl -c` before deferring
- compilation errors surface on first access attempt, reported with module name

---

### %SOURCE tie interface

```perl
tie %SOURCE, 'Protocol7::Source::Disk';       ##  default  ##
tie %SOURCE, 'Protocol7::Source::SHM';        ##  shared memory  ##
tie %SOURCE, 'Protocol7::Source::Network';    ##  cube-routed fetch  ##
tie %SOURCE, 'Protocol7::Source::ContentAddr'; ## by AMOS7 checksum  ##
```

the compile step always reads from `$SOURCE{$version}->{'module.name'}` —
backend is transparent. low-memory mode uses tied backends that do not
cache in `%SOURCE` and re-read on demand.

---

### speed / memory profiles

| profile      | versions kept | source kept | deferred tiers | rollback |
|--------------|--------------|-------------|---------------|---------|
| performance  | 2 (curr+prev)| both        | tier 2+       | yes      |
| balanced     | 2            | active only | tier 3 only   | yes      |
| low-memory   | 1            | none        | none          | no       |
| development  | N (all)      | all         | none          | full     |

configurable per-zenka via start file or runtime command.

---

### integration with dep-graph

- `dep-graph -zenka=NAME` provides the exact tier assignment for all modules
- `dep-graph -zenka=NAME -list-modules` → tier 0+1 eager load list
- unreachable list → candidates for removal from `modules.load`
- `-stdin` mode → allows a zenka to self-report its runtime call patterns
  for dynamic tier refinement beyond static analysis
- rule-resolved dispatch targets → tier 2 (will be called, not necessarily soon)

---

### implementation phases

#### phase 1: versioned staging hash + atomic swap

**known bug found 2026-08-02, see
`data/tasks/loader-reload-stale-cmd-modules.md`**: an already-loaded
zenka-local `.cmd.` module silently fails to actually reload on a live
process (`<zenka>.reload` reports success but the dispatched coderef never
changes) — traced to `$is_reload_batch` (added in `08b42f019`, gating on
`$active_version` + `$data{'code'}{$sub}{status}`), a behavioral fork this
doc's phase-1 design doesn't describe (the swap here is meant to be
unconditional after a clean compile, per the note below on
`$active_version` not being load-critical). checklist below is unchecked
throughout despite the code being live since `4f64720b5` — treat it as
stale bookkeeping, not "not started".

- [ ] add `%CODE` and `$active_version` to `bin/Protocol-7` core
- [ ] compile new loads into `$CODE{$new_version}` staging
- [ ] implement atomic swap on success
- [ ] keep old version for rollback window (default 120s timer)
- [ ] drop purge exclusion list from `p7_purge_code`
- [ ] verify reload of all base modules works without exclusion list

#### phase 2: load modes + fingerprint

- [ ] implement `:force-replace:` and `:force-keep:` merge strategies
- [ ] implement compatibility fingerprint generation and comparison
- [ ] expose reload mode via `base.cmd.reload` parameter

#### phase 3: rollback + auto-rollback

- [ ] manual rollback command: `reload rollback`
- [ ] configurable rollback window timer
- [ ] auto-rollback: error counter monitoring + threshold trigger
- [ ] rollback rules in `cfg/loader/rollback-rules/`

#### phase 4: %SOURCE + deferred compilation

- [ ] introduce `%SOURCE` store (disk-backed by default)
- [ ] compile-time tier assignment from dep-graph data
- [ ] `%code` proxy for lazy compilation on first access
- [ ] signed syntax check status for deferred modules (`[ deferred, syntax valid ]`)
- [ ] low-memory mode (no %SOURCE caching, single version)

#### phase 5: %SOURCE tie backends + concurrent versions

- [ ] `Protocol7::Source::SHM` — shared memory backend
- [ ] `Protocol7::Source::Network` — cube-routed source fetch
- [ ] per-zenka version pointers (staged rollouts)
- [ ] v7 version coordination across network

---

### current loader structure (reference)

`p7_load_code` in `bin/Protocol-7` already has two distinct phases:

**phase A — parse + transform** (lines ~1418–1530):
- read source from disk or HTTP into `$data{'code'}{$file_name}{'source'}`
- join continuation lines
- transform `<[module]>` → `$code{'module'}->()`
- transform `<data.key>` → `$data{'key'}`
- wrap `.cmd.` modules with compiled-in header/footer
- result: preprocessed source string, ready to `eval`

**phase B — compile** (lines ~1579–1740):
- `eval($sub_code)` → `$sub_cref`
- on success: `$code{$sub_name} = $sub_cref` (direct assignment to live hash)

line 1730 already carries the developer's own intent:
```
## todo-list : compile to seperate hash, replace on full success ##
```

the version-aware loader fulfills this exactly:
- `%SOURCE` = phase A output (`$data{'code'}{...}{'source'}` already stores this)
- `$CODE{$version}` = phase B output, currently going directly to `%code`
- the staged hash approach inserts between phase B compile and the live assignment

`$data{'code'}{$file_name}{'source'}` already exists as the preprocessed
source store — `%SOURCE` formalizes and versions it. the transformation
step does NOT need to be re-run on lazy compilation, only the `eval`.

---

### notes

- `$data{'base'}{'core_subs'}` can stay as documentation / introspection
  but must no longer be required for reload correctness
- `base.cmd.reload` keywords (`config`, `source`, `init`, `all`) remain
  unchanged at the user-visible layer
- `p7_purge_code` exclusion list: `bin/Protocol-7` lines ~2759–2808
- `## todo-list` comment at line 1730 documents the known intent this task fulfills
- speed/memory profiles should be adjustable at runtime without restart

#,,,,,,,,,.,,,,,,,,,.,,.,,,.,,..,,.,,,...,...,..,,...,...,...,,.,,,,,,..,,,..,
#3KFBCJUV5RFXMGDIHU6FJKRSN5WJLKG66U33ADK354YXIG2R3O5VHPQIPOU74TH3ZQBV3G6ARVYD2
#\\\|MXYWF2LNEIVZJXY7QSRLEYA5XKZPQP32ZHDUGUMJJR6ZPJMXAWU \ / AMOS7 \ YOURUM ::
#\[7]WJ7O4IE36CS4HRVZV6LX6LBCTKEGFUOZKNHDOZJDORIU3DRA3IDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
