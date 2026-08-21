## [:< ##

# name  = task: loves_it GPU allocation — real mode checks + shared allocator (phase 1 only)
# descr = replace the non-discriminating proxy scoring in lm-vision.handler.http_analyze
#         with real division-by-13 truth checks via AMOS7::Assert::Truth, extracted into
#         the missing resource.gpu.loves_allocator module the design docs already name

## context

session: 2026-07-30. surfaced while reviewing an unrelated jobsite change,
then followed through a long adversarial-review pass over the resource-token
economy design (`RESOURCE-ECONOMY-DEMYSTIFICATION.md`, same session) — most
objections raised there resolved cleanly to existing, working mechanisms.
this one didn't. reading the actual code behind `loves_it` scoring
(`src/lm-vision.handler.http_analyze:19-58`) instead of the design docs
turned up a real defect: the score is computed from string-length checks and
a permissive regex, not from anything that varies meaningfully with the
input. `ack -ri 'loves.it' data/` surfaced the full design surface this
implementation was supposed to be a first slice of —
`data/md/protocol-7-knowledge/08_NETWORK_INTELLIGENCE/LOVES_IT_RESOURCE_ALLOCATION.md`
(4-layer architecture: GPU/workload → transport → arc scheduling → AMOS
token economic loop) and `data/md/coding-tasks/lm-vision-http-backend.md`
(the original bounded task spec) — considerably more logic than the shipped
code accounts for in any way.

the user did not revert the broken code on finding it — "still a reminder to
improve and actually implement true parts of it" — and asked for this to
become a real task file, built from the fuller reference material, with an
Opus planning pass for the implementation detail. that pass (below) found
two more things worth recording here directly: the design doc's own
reference pseudocode calls a function (`<[amos7.elf.check]>`) that doesn't
exist anywhere in the codebase, and the one piece of code in-tree that looked
like a correct reference pattern for this
(`src/amos-term.plugin-decoder.elf_match`) turned out, on inspection, to
be a second independent instance of the same class of defect — not a
template to follow. the real primitive is `AMOS7::Assert::Truth::is_true`,
confirmed against four existing in-tree call sites, and its behavior under
the corrected logic was measured (2000 sampled workloads), not assumed.

this is a good example of the general pattern worth naming for future
sessions: a model implemented a design doc's *shape* (three modes, a 0-13
score, a 1.13 bonus) without necessarily reading or having available the
primitives the shape was supposed to be built from, produced code that
compiles and runs and looks plausible, and the gap only surfaces by reading
the arithmetic, not by reading the docstrings or the design doc a second
time. worth remembering next to
[[dynamic-context-prep-vs-model-size]] — discovery cost, not model size, is
the recurring lever, and this is a case where the discovery cost was "read
the actual comparison operators," which nothing short of reading the code
pays.

---

## requirement

**scope: phase 1 only — the GPU/workload allocation layer.** what "fixed"
means here is narrow and testable: the loves_it score computed for a vision
workload must actually be a function of the workload, produced by the
codebase's real division-by-13 truth machinery, and must be produced in one
shared place rather than inlined per call site.

three concrete defects to close:

1. **the proxy checks in `src/lm-vision.handler.http_analyze:19-58` are
   not truth checks.** confirmed by reading: `mode4` is "did
   `<[chk-sum.elf]>` return a non-empty string" (true for every successful
   call — `base.chk-sum.elf` returns `sprintf %09d` unconditionally),
   `mode7` is "is the AMOS checksum ≥ 7 chars" (true for every real
   checksum), `mode13` is `$first_13 =~ m{[02759]}` over 13 base32
   characters (~91% true at random). net effect: `$loves_score` is 13 or
   near-13 for essentially every input, so `$priority_weight` gets the
   `*= 1.13` loves_it bonus almost universally. the signal carries no
   information about the workload — it is a constant wearing a score's
   clothing.

2. **`resource.gpu.loves_allocator` does not exist.** both
   `data/md/protocol-7-knowledge/08_NETWORK_INTELLIGENCE/LOVES_IT_RESOURCE_ALLOCATION.md`
   (line 89, "Test Module") and `data/md/coding-tasks/lm-vision-http-backend.md`
   (integration-points table, "Token integration") name it as the scoring
   home; the handler skipped it and inlined instead. the fix must extract,
   not just repair in place — `graphics-matrix` and `opencv` are named as
   the other phase-1 consumers in the design doc and would otherwise each
   re-inline their own variant of the same arithmetic.

3. **`amos_tokens` is a dead parameter.** `http_analyze` accepts it, defaults
   it to `0`, and forwards it verbatim as the `X-AMOS-Tokens` header. the
   only call site — `src/lm-vision.cmd.analyze_image:194` — does not
   pass it at all, so the header is always `0`. the design doc's allocator
   pseudocode makes `tokens` the *base* of the allocation
   (`$base_allocation = $tokens * 4200`), which with a zero balance yields a
   granted allocation of zero regardless of score. the token input needs a
   defined contract before the multiply is written.

**the real mode-check primitive, confirmed.** `AMOS7::Assert::Truth::is_true(
\$data, 0, 1, $mode )` is the actual callable — `$check_as_num = 0`,
`$check_as_elf = 1`, trailing args override `@assertion_modes`. it computes
the elf checksum at `elf_mode = $mode` with `$elf_shift_bits = 13`
(`data/lib-path/pm/AMOS7/Assert/Truth.pm`, `is_true` mode loop) and asserts
division-by-13 truth via `calc_true`, returning `TRUE = 5` / `FALSE = 0`.
existing in-tree call sites: `src/devmod.cmd.true`,
`src/branch.route.calc.resonance:59`, `src/base.gen_id:28`,
`src/base.prng.harmonic_seed:24`. `Truth.pm` ships `@assertion_modes =
qw| 4 7 |` as the default set; mode 13 is a legitimate third elf mode
(`base.chk-sum.elf.inline` accepts any `elf_mode <= 64`), and
`read-me/documentation/dev/NRT.NRD.asc` names exactly this triple in its
proof-of-work section: "all checks true, as numerical assertion and with elf
modes 4, 7 and 13".

**correction to the brief: `amos-term.plugin-decoder.elf_match` is not a
usable reference pattern — it is a second instance of the same class of
defect.** in its `$mode == 13` branch it does `$loves_score = $mode4 +
$mode7` where both operands are raw `%09d` elf checksums (measured:
`elf_chksum("ABCDEFG7")` = `009462711`), so the nominal "0-13" score comes
out at nine-digit scale and the `$loves_score >= 10` visual-feedback
threshold fires unconditionally. its `$mode7 == 7` and `$mode13 == 2` tests
are equality comparisons against a 32-bit hash value — those fire with
probability ~1e-9, i.e. never. it also calls `<[chk-sum.elf]>` (which does
*not* accept an `elf_mode` argument — `base.chk-sum.elf` forwards only the
joined input string to `chk-sum.elf.inline`, leaving `elf_mode = 7`), so all
three of its "modes" are the same mode-7 checksum over different substrings.
this plan derives the mode logic from `Truth.pm` directly and treats
`elf_match` as a separately-scoped follow-up fix, not a template.

**measured, so this is not a hope:** sampling 2000 distinct workload strings
through `is_true(\$s, 0, 1, $mode)` for modes 4/7/13 gives a genuinely spread
distribution — score 0: 188, 2: 241, 4: 195, 6: 299, 7: 246, 9: 249, 11: 297,
13: 285. roughly 14% reach loves_it, each mode is near-50/50 and the three
are near-independent. `calc_true` is a coin flip by construction, not a rare
event: `init_table` builds `%false` from rotations of `230769` and `%true`
from rotations of `461538`, and the truncated six-digit tail can only land in
one of those families. this measured spread is the acceptance oracle for
step 4.

**explicitly out of scope for this task — future work, separate steps:**

- **phase 2, transport/bandwidth allocation** (`transport.allocate.bandwidth.loves_it`,
  56-row channel counts, dancing-kittens formation priority — design doc
  lines 132-160).
- **phase 3, arc scheduling** (`zenki.arc.loves_scheduler`, 13-phase
  lifecycle advancement — design doc lines 163-204).
- **phase 4, the 72-bit truth row and the economic loop** (design doc lines
  206-237; `read-me/documentation/dev/NRT.NRD.asc`), including any actual
  AMOS resource-token ledger.

the reason is not sequencing convenience: phases 2-4 all consume phase 1's
score as their input priority ("`'priority' => $loves_it_score, # From phase
1`", design doc line 143; "average love score determines next arc
advancement", line 195). until the phase-1 score is demonstrably
discriminating — which is precisely what is broken today — building three
more layers on top of it would propagate a constant dressed as a signal into
routing, scheduling and accounting, where it is far harder to notice and far
more expensive to unwind. also relevant:
`data/md/development/IMPLEMENTATION-ROADMAP.md` item 6.2 ("pool per loves-it
group, sized by contribution + loves-it weight") presupposes that loves-it
groups are meaningfully distinguishable in the first place.

## implementation plan

### step 1 — create the shared allocator

**new: `src/base.resource.gpu.loves_allocator`**, callable as
`<[resource.gpu.loves_allocator]>` — the four-segment base-prefix strip is
confirmed in the handler itself (`base.chk-sum.bmw.filesum` invoked as
`<[chk-sum.bmw.filesum]>`, `base.event.add_timer` as `<[event.add_timer]>`).
this gives the exact callable name both documents already use, with **zero
change to `modules.load` in `cfg/zenki/lm-vision/zenka.v7`** (which
loads by namespace prefix: `auth.client net protocol io.unix io.ip ui
crypt.C25519 format.json lm-vision devmod`). the alternative,
`src/resource.gpu.loves_allocator`, would need `resource` added there and
in every future consumer's start file. cost of the base variant: it is loaded
into every zenka — acceptable for a pure scoring function with no state and
no init hook, and see the open question on namespace if that is not wanted.

signature, following the design doc's request-hash shape:

```
my $request  = shift // {};
my $workload = $request->{'workload'};   ## scalar or scalar ref
my $tokens   = $request->{'tokens'} // 0;
my $requester = $request->{'requester'} // 'anonymous';
```

returns the doc's shape plus what the handler needs for headers/logging:
`{ score, loves_it, weight, tier, modes => { 4 => .., 7 => .., 13 => .. },
granted }`.

### step 2 — real mode 4 / 7 / 13 checks

inside the allocator, replace the proxy heuristics with:

```
my $wl_ref = ref $workload eq qw| SCALAR | ? $workload : \"$workload";

my %mode_pass = map { $ARG => AMOS7::Assert::Truth::is_true( $wl_ref, 0, 1, $ARG )
                              ? 1 : 0 } qw| 4 7 13 |;

my $score = ( $mode_pass{4}  ? 4 : 0 )
          + ( $mode_pass{7}  ? 7 : 0 )
          + ( $mode_pass{13} ? 2 : 0 );   ##  4 + 7 + 2 == 13  ##
```

`$check_as_num = 0` matters: the workload input may well be a bare numeric
elf checksum, and leaving the numeric check on would add a second,
differently-derived rejection path on top of the elf modes and skew the
distribution. `$check_as_elf = 1`, trailing mode arg selects the single mode
— this is exactly `devmod.cmd.true`'s call form with the mode set narrowed.

**do not** route this through `<[chk-sum.elf]>` — it does not expose the
`elf_mode` parameter (see the `elf_match` correction above). if a
non-`is_true` formulation is wanted for any reason, the only correct direct
form is `<[chk-sum.elf.inline]>->( $wl_ref, 0, $mode, 13 )` followed by
`AMOS7::Assert::Truth::calc_true(...)`, which is what `is_true` does
internally anyway.

tier / weight table, from the design doc's 13-point scale (lines 79-87)
reconciled with the weight arithmetic actually in the current handler
(`$priority_weight = $loves_score / 13`, floored at `0.25`, `*= 1.13` when
13):

| score | modes | label | weight |
|-------|-------|-------|--------|
| 13 | 4+7+13 | `loves_it` | `1.00 * 1.13` |
| 11 | 4+7 | `warm` | `0.75` |
| 7 | 7 | `heart` | `0.50` |
| 4 | 4 | `like` | `0.25` |
| 0 | none | `void` | `0.25` floor |

**the documented table is not exhaustive and the implementation must not
assume it is.** the measured distribution produces scores 2, 6 and 9 as well
(mode-13-only = 2, 4+13 = 6, 7+13 = 9) — 8 reachable scores against 5
documented tiers, and 2/6/9 together were ~39% of samples. keep the
continuous `$score / 13` weight as the computed value (with the `0.25` floor)
and treat the tier label as a presentation/logging bucket derived from it,
rather than a lookup that silently falls through for 39% of real traffic.
`granted` follows the doc: `int( $tokens * 4200 * $weight )`.

### step 3 — token input contract (not a ledger read)

**the NRT token balance has no producer in this codebase.** confirmed: no
`nrt.*` or `nrd.*` modules exist, and `read-me/documentation/dev/NRT.NRD.asc`
is a development note describing an unbuilt blockchain — 13-digit signed
account values, `'<CHKSUM><C25519-KEY>'` account identifiers, 4200 drops per
token — with no implementation anywhere. so "wire real AMOS-token-balance
reading" cannot mean an actual balance read in this task.

**explicit warning against a plausible wrong turn:** `coding.budget.*`
(`src/coding.cmd.budget`, `src/coding.helper.refund_tokens`,
`<coding.budget.allocated>` / `<coding.budget.used>`) is LLM-inference token
accounting for the coding zenka. it is unrelated to AMOS resource tokens
despite the shared word, and must not be wired in as the balance source.

what this step does deliver:

- allocator treats `tokens` as a caller-supplied non-negative integer with a
  documented default of `0`, and — critically — **decouples `weight` from
  `tokens`**, so a zero balance still yields a valid score and weight for
  the priority headers even though `granted` computes to `0`.
- `src/lm-vision.cmd.analyze_image:194` gains an explicit `amos_tokens`
  pass-through into the `http_analyze` call args (currently absent
  entirely — only `image_path`, `prompt`, `reply_id` are passed), so the
  parameter stops being structurally dead even while the source of the value
  remains a human decision.
- the zero-balance policy itself (floor vs. reject) is an open question
  below, not a step.

### step 4 — replace the handler's inlined block

`src/lm-vision.handler.http_analyze` lines 19-58 collapse to one call.
keep `<[chk-sum.bmw.filesum]>->( 256, $image_path )` as the workload-hash
source (unchanged), drop the now-unused `<[chk-sum.amos]>` call, and pass the
result plus `requester` / `amos_tokens` into the allocator. everything
downstream already consumes named fields and needs only rebinding:

- the `<[base.logs]>` line at :57 (keep the modes breakdown — it is the field
  diagnostic for whether the distribution looks right in production),
- the four `X-*` headers at :121-125,
- `<lm-vision.jobs>->{$job_id}` metadata at the bottom (`loves_score`,
  `loves_it`, `priority_weight`, `modes`) — add `tier`,
- the `[loves_it:%d/13 weight:%.2f]` reply prefix.

behavioural note to expect and not treat as a regression: after this change
most requests will *stop* getting the 1.13 bonus. that is the point.

### step 5 — tests

**harness trap, resolve before writing:** the `load_module` helper at
`bin/dev/tests/stdio-frame-codec.t:14-24` does `eval "sub {\n$src\n}"` over
raw module source. that only works on token-free modules — the allocator will
contain `<[...]>` invocation tokens, which are not valid Perl before the
protocol-7 parser runs. two viable routes, pick at implementation time:

- **(a)** keep the allocator's scoring core token-free (it needs only
  `AMOS7::Assert::Truth::is_true` and plain arithmetic — genuinely
  achievable) so `bin/dev/tests/loves-allocator.t` can load and call it
  directly, matching the existing `.t` convention;
- **(b)** add a `devmod.cmd.*` command surface mirroring `devmod.cmd.true`
  and exercise it against a live zenka.

route (a) is preferred and is a real design constraint on step 1, not an
afterthought.

test content:

1. **distribution / non-degeneracy** — the actual regression guard. score N
   sample workloads, assert the scores are not all-13 and that at least
   several distinct scores appear. this is the test the current code fails.
   the measured 2000-sample spread above is the reference expectation
   (~14% at 13, all 8 scores populated).
2. **determinism** — same workload hash in, same score out, across calls.
3. **weight/tier mapping** — `0.25` floor at score 0, `1.13` only at 13, and
   that scores 2/6/9 produce a defined tier rather than undef.
4. **`tokens = 0`** — `granted == 0` yet `score`/`weight` still populated
   (guards the decoupling from step 3).

## new/changed files

| file | change |
|------|--------|
| `src/base.resource.gpu.loves_allocator` | **new** — shared scoring + tier/weight/granted, callable as `<[resource.gpu.loves_allocator]>` |
| `src/lm-vision.handler.http_analyze` | **changed** — lines 19-58 replaced by one allocator call; drop `<[chk-sum.amos]>`; add `tier` to job metadata |
| `src/lm-vision.cmd.analyze_image` | **changed** — pass `amos_tokens` (and `requester`) through at :194 |
| `bin/dev/tests/loves-allocator.t` | **new** — distribution / determinism / tier / zero-token tests |
| `cfg/zenki/lm-vision/subroutines.load-early` | **changed, verify** — contains an explicit module list including `lm-vision.handler.http_analyze`; check whether the new base module needs an entry here |
| `cfg/zenki/lm-vision/zenka.v7` | **no change expected** with the `base.` naming; needs `resource` added to `modules.load` only if the un-prefixed name is chosen |

not changed by this task, noted as separately-scoped follow-up:
`src/amos-term.plugin-decoder.elf_match` (same class of defect, different
zenka, has its own `<amos-term.windows.by_id>` side effects — should be fixed
to call the allocator once the allocator exists, but not in this task).

## open questions / risks — need a human decision before implementation

1. **passive property or proof-of-work?** this is the one that changes the
   allocator's signature, so it cannot be guessed. as written, the design
   doc's pseudocode checks the workload hash once — meaning the score is a
   content lottery: a given image gets the same priority forever, and a
   requester who wants loves_it treatment perturbs their input until it
   scores 13 (cheap to do, and it is the obvious gaming path). but
   `src/base.chk-sum.elf.get-true` exists specifically to *search* for a
   true elf checksum by iterating start-sums until
   `AMOS7::Assert::Truth::true_int` holds, and `NRT.NRD.asc`'s proof-of-work
   section frames modes 4/7/13 as something a participant must *achieve*
   ("all checks true ... segmentize truth verification, 72 bit rows must be
   TRUE"). if loves_it is meant to be earned, the allocator takes a
   caller-supplied nonce/witness and *verifies* it, which is a different
   module and a different threat model than scoring a hash.
2. **what exactly is the workload input?** the file checksum
   (`<[chk-sum.bmw.filesum]>->( 256, $image_path )`, what the handler uses
   today)? a request hash including prompt + requester + timestamp? or
   different derivations per mode — `elf_match` uses three different
   substrings of one string, and the doc's "data truth / love-truth / cosmic
   assertion" gloss on modes 4/7/13 reads as though the three are meant to
   assert over *different* things (the data, the request, the context). the
   measured distribution above assumed one string, all three modes; a
   per-mode-input design would need its own distribution check.
3. **zero / insufficient token balance: floor or reject?** the tier table
   says score 0 → 25% and the current code floors `$priority_weight` at
   `0.25`, but the doc's own table header says score 0 → "0%" (line 84) while
   the coding-task spec says 25% — the two documents disagree. and separately
   from score: with `tokens = 0`, `granted = $tokens * 4200 * $weight = 0`
   for *every* score including 13. decide whether a zero-balance requester is
   served at the floor, queued, or refused — and whether `granted` is even
   enforced yet (see 4).
4. **is the priority signal a no-op today?** repo-wide grep for
   `X-Loves-It-Score` / `X-Priority-Weight` / `X-AMOS-Tokens` finds only
   `src/lm-vision.handler.http_analyze:121-125` and the two design
   documents. nothing reads them: llama-server ignores unknown request
   headers, and `granted` / GPU cycles are not enforced anywhere. so the
   coding-task spec's success criterion "loves_it 13 requests get measurable
   throughput boost" is **not testable today** — there is no mechanism by
   which the score could produce a throughput difference. decide whether
   phase 1 stops at "correct, well-formed, tested signal emitted" (the honest
   scope, and what this plan delivers) or whether it must also include a
   consumer — a local admission/queue gate in `lm-vision` ordering
   `<lm-vision.pending_requests>` by weight is the smallest real one, and
   `src/lm-vision.cmd.analyze_image` already has that queue.
5. **namespace: `base.resource.*` or `resource.*`?** `base.` gets the exact
   documented callable token for free and loads everywhere; a top-level
   `resource.*` namespace is cleaner conceptually and keeps a
   resource-allocation subsystem out of `base`, at the cost of a
   `modules.load` edit in every consumer zenka's start file
   (`lm-vision`, later `graphics-matrix`, `opencv`). this is a convention
   call, not a technical one.
6. **mode 13 is outside `Truth.pm`'s configured default set.**
   `our @assertion_modes = qw| 4 7 |` is described in-file as "elf truth
   modes : main set-up". passing `13` as an explicit trailing arg to
   `is_true` works (verified — it produces a well-distributed independent
   check), but confirm that using a mode outside the system's main set-up for
   scoring is intended, and that it should not instead be added to
   `@assertion_modes` globally — the latter would change truth semantics
   system-wide for `base.gen_id`, `base.prng.harmonic_seed`,
   `branch.route.calc.resonance` and everything else calling `is_true`
   without explicit modes. **do not** make that global change as part of this
   task.
7. **cost per request.** three `is_true` calls per workload, each an elf
   checksum plus a division-by-13 assertion, on top of the existing
   `chk-sum.bmw.filesum` over the image. cheap relative to a vision inference
   pass, but if `resource.gpu.loves_allocator` later serves high-frequency
   callers (`graphics-matrix` similarity sorting, per-frame), a memo cache
   keyed on workload hash is the obvious addition — deliberately not in this
   task.

## status: planned, not started

design pass complete against real code: the mode-check primitive is
identified and its call form confirmed at four existing sites, the current
proxy's failure mode is characterised, and the score distribution under the
corrected logic is measured rather than assumed (2000 samples, all 8
reachable scores populated, ~14% at loves_it). two claims in the source
material were found false and are corrected in-plan — `<[amos7.elf.check]>`
does not exist, and `amos-term.plugin-decoder.elf_match` is not a working
reference. open questions 1 and 4 are the blocking ones: 1 changes the
allocator's signature, 4 decides whether phase 1 ends at a well-formed
signal or must ship a consumer. everything else can proceed on defaults.

#,,.,,..,,..,,.,,,.,.,.,.,,,.,.,.,,..,,,,,,.,,..,,...,...,...,,,,,,.,,,,.,.,.,
#NELSWD3LJ5T3LNLYSU4RQPNVHGT2ZEGDRES4BZK5AR2BN7V6D5G4I456CDUFPVXH4XHUKK43GREE2
#\\\|6E7N5UAA2C4JDZS7QCONK7F2WVVHOQW55XPF2HMSDHGDVCUSAZ5 \ / AMOS7 \ YOURUM ::
#\[7]UHAD5MHJ2ID5DHMMNDTFHSZUPJAMTWFXOY26CDEMQXEN7MOMQIDI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
