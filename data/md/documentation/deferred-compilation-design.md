# deferred compilation — design questions

## what exists now

the whitelist skips non-whitelisted modules at load time. the deferred stub
mechanism (partially implemented) installs a placeholder in `%code` for skipped
modules so the first call triggers lazy compilation via
`base.handler.deferred_compile` → `base.load_runtime_modules`.

lifecycle hooks (`*.pre_init`, `*.init_code`, `*.post_init`, `*.end_code`) are
excluded from stub installation because the system treats their absence as
"skip", not "defer". this is correct behavior but exposes a deeper question:
which subs are genuinely deferrable and which carry hidden ordering constraints?

---

## the core tensions

### 1. namespace swap timing

several module families are loaded under a `base.*` prefix and then swapped to
a shorter name during `base.file.init_code` (e.g. `base.file.*` → `file.*`).
the swap happens at a fixed point in the init sequence. a sub deferred past
that point would be compiled into `%code` under its original name, but the
swap alias it should also answer to was never registered. the deferred handler
would need to know whether a swap applies and register the compiled cref under
both names.

### 2. init ordering contracts

`*.init_code` modules often establish state that subsequent runtime subs
silently depend on (locale tables, template caches, perl module paths, fd
handles). "optional" in the init system means "skip if absent", not "run
whenever convenient". deferring these past the point where their effects are
expected would break the implicit ordering contract without any visible error.

### 3. dep-graph coverage gap for dynamic dispatch

`base.init_modules` iterates loaded namespaces and calls `*.init_code` etc. by
constructing sub names at runtime — this is invisible to static dep-graph
tracing. consequence: legitimately reachable `base.*` lifecycle hooks may be
absent from whitelists not because they're unneeded but because the tracer
couldn't follow the path. this means some "deferred" loads during testing were
actually false positives — real modules that belong in the whitelist.

### 4. safe vs unsafe deferred targets

genuinely safe candidates for deferred stubs are pure runtime subs that:
- carry no init ordering constraint
- are not involved in any namespace swap
- are only called on user request or specific event, never from init chains

identifying these programmatically via dep-graph is possible in principle:
flag subs reachable only through cmd/console handlers or explicit timer
callbacks, not through any `init_modules` call chain.

---

## namespace candidacy — the `base` problem

the `base` namespace is a catch-all that mixes at least three distinct
categories:

| category | examples | deferrable? |
|---|---|---|
| bootstrap core | `base.log`, `base.event.*`, `base.init_modules` | no |
| init-time setup | `base.locales.*`, `base.templates.*`, `base.chk-sum.*.init_code` | no (ordering) |
| pure runtime utilities | `base.file.recursive.*`, `base.list.*`, `base.parser.*` | yes, if no swap |

dep-graph could annotate each reachable sub with the earliest call-chain phase
that reaches it (init vs runtime). subs reachable only from runtime phases and
not involved in swaps are safe deferred candidates. subs in the `base` namespace
that belong to the second category might be better homed in a dedicated
namespace (e.g. `locale.*`, `template.*`) that makes their phase clear and
removes them from the large `base` whitelist sweep.

---

## deferred sub-module vs sub-routine loading

current granularity: one stub per sub-routine file.

an alternative: defer at the **sub-module level** — the coarse namespace prefix
(e.g. `base.file.recursive`) rather than individual files. when any sub in that
group is first called, compile all files in the group together. this matches the
existing `p7_load_code($code_name)` call pattern and avoids the overhead of a
full file-list scan per individual deferred call.

trade-off: coarser granularity means slightly more compiled code per trigger,
but far fewer deferred compile events and simpler accounting. for the `base`
namespace specifically, sub-module deferral would let large optional families
(e.g. `base.list.*`, `base.parser.*`) be deferred as a unit rather than file by
file.

the stub in this model is installed per-sub but triggers compilation of the
whole sub-module group, similar to how `autoload` works in standard perl.

---

## open questions for the elegant solution

- how should the loader know which subs participate in a namespace swap, so
  deferred compilation can register the swap alias as well?
- should `base.init_modules` mark its calls with a phase tag (init vs post-init
  vs runtime) so dep-graph can classify reachability by phase?
- is the right move to split `base.*` into phase-annotated sub-namespaces, and
  if so, what is the right boundary — by function family, by call-time phase, or
  by swap involvement?
- could the whitelist itself carry phase metadata per entry rather than being a
  flat list?

---

## notes for kimi

the holographic / namespace topology work on the data zenka may be relevant
here — the same question of "which subs belong together as a unit" applies to
both the memory layout and the deferred compilation unit boundary. there may be
a natural alignment between the sub-module groupings that make sense for
deferred loading and the namespace clusters that make sense for the data
topology.

the swap-boundary dispatch pattern (documented in MEMORY.md) is the sharpest
concrete constraint: any elegant solution must handle the case where a deferred
sub's compiled name differs from the name callers use after a swap has occurred.

#,,..,,,,,,..,.,,,.,.,.,,,,..,,,,,..,,,..,,..,..,,...,...,...,,..,,,.,,.,,..,,
#7T7SAT2SW7HBFFPMCHZI5WZECHZO6H2HESW7GI53F5L3IOOI2ISNXJFSENHZTTO2XWTANIJ5N76VW
#\\\|QWNVKSCAXCQ7Q6ZKV46T2ZJLWUHA4PCIPUCL7BR4ZAB22KMAAYT \ / AMOS7 \ YOURUM ::
#\[7]AVR44ZEWGMA4TKXXUURPDTQBZKBSDZ4QRDJZXU7AZ4FBHLSM36CY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
