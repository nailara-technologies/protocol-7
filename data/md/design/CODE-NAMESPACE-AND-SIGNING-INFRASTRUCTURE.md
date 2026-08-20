# code namespace + signing infrastructure

## overview

protocol-7 manages all persistent artifacts — code, configuration, application
data — through a unified dot-notation namespace with cryptographic integrity.
this document describes the three-category model, format contracts, the signing
pipeline as policy enforcement gate, and the tool family that wraps it all.

the system grows from working infrastructure. every design decision here has
an existing implementation to extend, not a blank slate to fill.

---

## three-category namespace model

all persistent artifacts fall into three categories, each with distinct entropy
characteristics and format policy:

### code

- **entropy**: controlled — variations are intentional, signed, traceable
- **entry points**: signing gate (modules/), direct load (bin/Protocol-7)
- **format**: single canonical form, ptd-formatted, endline normalized
- **signature**: required, strict — unsigned artifacts not loaded
- **current paths**: `modules/`, `bin/`, future `code/`
- **dot namespace**: `base.callback.cmd_reply` ↔ `modules/base.callback.cmd_reply`

### configuration

- **entropy**: semi-controlled — intentional changes, per-zenka variation
- **entry points**: zenka start files, `[load_config_file:...]` directives
- **format**: v7 config syntax or YAML depending on node; relaxed trailing
  endline tolerance (authors use whitespace deliberately for visual separation)
- **signature**: required, slightly relaxed normalization rules
- **current paths**: `cfg/`
- **dot namespace**: `conf.zenki.radio.start` ↔ `cfg/zenki/radio/start`

### application data

- **entropy**: open — externally sourced, unbounded variation
- **entry points**: zenka runtime, network, user interaction
- **format**: declared per node in attributes table; binary-compatible
- **signature**: verified at boundary, flows freely inside once admitted
- **current paths**: `data/`
- **dot namespace**: `data.yaml.ncode-patterns.p7-common` ↔ `data/yaml/ncode-patterns/p7-common.yaml`

---

## separator-agnostic namespace

the dot notation is the universal address. filesystem paths are one physical
projection of it. the loader resolves transparently:

```
conf.zenki.radio.start
  → cfg/zenki/radio/start   (path fallback)
  → in-memory cache                   (if warm)
  → network-addressed sub             (if remote)
```

the address is stable across all backends. moving an artifact from disk to
network or memory changes only the backend, not the address or the chain.

---

## format contracts and attributes table

each namespace node carries a format contract — not a per-file property but
a property of the namespace itself. the attributes table maps namespace
prefixes to their contract:

```
namespace prefix    format          endline policy      ptd     sig required
modules/            P7 module       LF, strict          yes     yes
bin/dev/            Perl script     LF, strict          no      yes
cfg/      v7 / YAML       LF, relaxed (+2)    no      yes
data/yaml/          YAML            LF, relaxed (+1)    no      yes
data/md/            Markdown        LF, permissive      no      no
```

**endline encoding in footer**: because normalize-then-checksum destroys
original state irreversibly, and checksum-then-normalize requires brute-forcing
states for verification, the signing system records the normalization delta
in the footer. this makes single-pass verification possible without trial and
error. the footer is pattern-matched (not offset-addressed) so re-signing
cannot shift the recording out of alignment.

the attributes table is the verifier's context — read contract first, then
verify. no special cases, no per-file exceptions.

---

## signing pipeline as policy enforcement gate

signing is the canonical entry point for code artifacts. the pipeline runs
in order, each step gated on the previous:

```
1. format detection    — identify namespace from path, load attributes
2. ptd formatting      — apply perltidy profile for namespace (code only)
3. endline normalize   — apply endline policy, record delta in footer
4. policy checks       — header complete? pm-dep declared? bin-dep declared?
                         whitelist entry present? dep declarations consistent?
5. checksum            — AMOS7 over normalized payload
6. footer write        — endline state + checksum + AMOS7 signature block
```

**abort on policy failure**: missing header fields, undeclared dependencies,
or whitelist inconsistencies abort signing with a precise message. the file
is not signed until it meets the contract.

**future — interactive mode**: "this module calls `Crypt::Misc` but it is not
declared as pm-dep — add it?" → fixes and re-signs in one pass. clutter-less
because it only asks when something is actually missing.

---

## loading enforces signature

once signature checking is enforced at load time (code namespace), the
lifecycle closes:

```
edit → sign (normalizes, records, checksums) → load (verifies, drops if invalid)
```

unnormalized or unsigned artifacts dropped into `modules/` are either
transitional (will be signed before use) or flagged and not loaded. no
persistent unsigned state possible in the code namespace.

this also enforces ptd style as a side effect — a loaded module is a
ptd-formatted module, because signing made it so.

---

## tool family

### existing

**`bin/dev/create-code`**
minimal stub creator. given a module name, writes `## [:< ##` header and
`# name = ...` to `modules/<name>`. guards against overwrite. covers the
immediate pain of writing headers by hand in high-iteration sessions.

**`bin/dev/dep-graph`**
static dependency graph generator. `--zenka=NAME --list-subs` produces the
scoped reachable module set for a zenka. foundation for whitelist generation
and self-healing scans. three swap_subs forms now parsed.

**`bin/ncode`** with `modules/ncode.*`
pattern-based code modification. `parse-headers`, `suggest`, `apply`,
`workflow`. higher-level, code-as-code awareness.

**`modules/source.*`**
signature integrity and provenance. `signature_valid`, `extract_sig_body`,
`sign_data`, `acquire_checksums`, `create_harmonic_footer`.

### planned

**`prepare-code`** (absorbs `create-code`)
given a file path or module name:
- detects namespace from path, loads attributes contract
- resolves template for that namespace
- fills header: `name`, `descr`, `pm-dep`, `bin-dep` from context
- looks at namespace siblings for convention reference
- writes ready-to-sign stub if new, validates/completes headers if existing
- hands off to signing pipeline

**`prepare-zenka`**
given a name and type (on-demand / always-on / standalone / child):
- creates `cfg/zenki/<name>/` skeleton
- fills `start` from type template
- populates `auth.zenki`, `access.zenki` from policy template
- adds `zenka-startup.v7` with correct lifecycle hooks
- cross-references `cfg/zenki/cube/access.zenki`, flags additions needed
- one call from zero to a correctly wired, policy-complete zenka skeleton

**signing gate extensions** (incremental additions to signing pipeline):
- pm-dep declaration check against actual `use` / `require` statements
- bin-dep declaration check against `system()` / `exec()` / `which` calls
- whitelist entry consistency check
- dep-graph declared vs inferred divergence as signing error

**`base.modules.check_migrated`**
checks `<base.modules.moved_to>` for a given name, returns new target or undef.
fast path for namespace move recovery without full dep-graph scan.

**`source.target_namespace`**
resolves a module name to its on-disk path and namespace root. used before
`source.signature_valid` so callers never need to know path conventions.

---

## ncode.* vs source.* responsibility split

```
ncode.*    — code AS CODE
             structure, conventions, patterns, intent, modification
             prepare, validate policy, refactor, workflow

source.*   — code AS ARTIFACT
             chain, state, provenance, location, integrity
             sign, verify, normalize, track, resolve
```

they complement without overlapping. `ncode` answers "what should this code
be", `source` answers "is this code what it claims to be".

`create-code` → `prepare-code` sits at the boundary: calls `ncode` for
template and header resolution, calls `source` for initial signing and
registration.

---

## self-healing whitelist (downstream consumer)

the self-healing whitelist handler (`base.handler.whitelist_miss`) is a
consumer of this infrastructure, not part of it. it uses:

- `base.modules.check_migrated` — fast path for namespace moves
- `dep-graph --zenka=NAME --list-subs` — scoped reachable module list
- `source.target_namespace` — path resolution per module
- `source.signature_valid` — per-module integrity check
- `base.load_code` (core sub, see `bin/Protocol-7 -core-subs load_code`)

see `data/tasks/dep-graph-stdout-self-healing.md` for full task spec.

---

## lineage and growth pattern

tools get written at the point of pain, do exactly what was needed, and get
absorbed upward when a higher-level tool earns its complexity:

```
create-code (now)  →  prepare-code (when template resolution adds value)
dep-graph (now)    →  living network map (when core subs become addressable)
source.* (now)     →  cryptographic chain across all three categories
ncode.* (now)      →  policy-aware modification with signing integration
```

no premature abstraction. each tool has clear lineage. the working system
is the foundation, wrappers have immediate multiplier effect.

#,,,,,.,.,...,,..,,.,,,..,,,.,,..,,,.,,,.,,.,,..,,...,...,...,,,,,,.,,,,,,.,.,
#LWYJGHZCRZ76HSGAVP7M3EA245ANF66V22KWKDOOTHK65EO6OHXCQQWJLVIHPEOEWK55TE7WWW6ZE
#\\\|6DTLRHZ2UK6OVKQLUI3BDXOUQETYFYFMUKYLPN6RZ3R376BLWCB \ / AMOS7 \ YOURUM ::
#\[7]CUS2XMSTCKNPCWVPXEPF34WTBGY73BUNJMFEBP4LLYVFHD76UKCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
