## [:< ##

# name  = task: idiom conformance gate for protocol-7 coding idioms
# descr = scan, mechanically repair and hard-gate the four structural P7
#         idioms in model output, and harvest the (draft -> corrected)
#         pairs, after prompt / control-vector / LoRA all failed to move them

## context

raised 2026-09-09, third follow-on in the idiom-adherence thread after
`data/tasks/coding-control-vector-p7-idioms.md` [ + its 2026-09-09
addendum ] and `data/tasks/coding-lora-p7-idioms.md`. the four structural
idioms that make P7 code actually work --

- `<[module.name]>->(` invocation sugar   [ rubric `invoke` ]
- bare `<config.key>` access              [ rubric `cfgaccess` ]
- `TRUE` / `FALSE` named constants        [ rubric `truefalse` ]
- the `mode` / `data` reply shape         [ rubric `modedata` ]

-- have now sat at 0-1 hits out of 9 generations in **every** condition
tested by both prior tasks :

| attempt | intervention class | result on the four |
|---|---|---|
| system-prompt bug fixes | instruction | 0-1 / 9, no movement |
| mean-diff control vector | constant residual-stream bias | 0-1 / 9, moved surface *register* instead |
| LoRA fine-tune | weight update | never reached the model -- dequant blocker |

the LoRA path died on a hard blocker, not fatigue : the original HF-format
checkpoint for this exact hybrid model is private/404, the only route to
gradient PEFT was a from-scratch dequantizer for an architecture
`gguf-py` has no `MODEL_ARCH` enum for, and that dequantizer has a
**diffuse** bug [ `data/control-vectors/lora/PROGRESS.md`, session 2
conclusion : ablating each mixer type in turn left BOTH full-attn-only and
linear-attn-only garbage, so the corruption is in something shared ].

**the constraint that shapes this task** : the dequantization step, and
its bug, exist ONLY because gradient PEFT needs an HF-format checkpoint.
every forward-pass-only technique runs directly against the
already-correct production GGUF via the existing `llama-server` binary.
so : **no approach here may require an HF-format checkpoint of this
model.** not negotiable.

## diagnosis [ why the three prior attempts all missed ]

the production system prompt [ `src/coding.system_prompt` ] **already
enumerates all four idioms explicitly** -- `TRUE = 5, FALSE = 0, UNKNOWN =
2 [ not 1/0 ]`, `<[module.name]>->($args)`, `return { mode => qw| true |,
data => $result }`, `<system.zenka.name>`. the knowledge is in context,
correctly stated, and ignored anyway.

so this is not a knowledge gap and not a prompt-quality gap. it is a
**prior-strength gap** : at the moment of emitting a call, the model's
pretrained distribution over `Foo::Bar::baz(` overwhelms a rule stated
1500 tokens earlier. two consequences drive the design :

1. any intervention that is still an *instruction* is fighting the fight
   that has already lost twice. that includes a corrective-turn prompt --
   more targeted, but the same class, so it gets measured separately and
   is never load-bearing.
2. the four idioms are **enumerable, closed-form and mechanically
   checkable**. that is exactly why they were hard to steer
   [ low-frequency, position-specific, syntactically precise ] and exactly
   why they are easy to *verify and repair*. this asymmetry is the whole
   opportunity.

## approaches considered and rejected

**per-idiom control vectors** [ one vector per idiom instead of one over
the mixed 46-pair set ] -- rejected on three grounds :
- 46 pairs split four ways is ~11-12 pairs per vector. the control-vector
  task's own scope item 2 states a 10-pair vector "proves nothing
  whatsoever about whether the steering works" and sets 40 pairs as the
  floor. doing it properly means **160+ new pairs**, each token-length
  matched per that task's hazard 4 -- the largest build cost on the table,
  spent on the mechanism with the worst prior.
- the loader sums vectors [ `common.cpp: llama_control_vector_load_one`
  does `dst[j] += src[j] * strength` ] and the measured coherence window is
  1.0 fine / 2.0 word salad. four vectors at ~1.0 each land past the cliff.
  applied one-at-a-time instead, they are useless in production -- you do
  not know in advance which idiom a request needs.
- a control vector is a *constant* offset at every token position; the
  target is *conditional* behaviour [ "when about to emit a call, emit this
  form" ]. re-grouping the dataset does not touch that mismatch.

still worth exactly one cheap probe if the mechanism class is ever
revisited : a `truefalse`-only vector [ 187 rows already exist in
`data/control-vectors/lora/dataset/sft.jsonl` ], since a constant upweight
of two ordinary tokens is a shape a steering vector can express. one
category, one day, clean yes/no. do not build four.

**retrieval exemplar bank** -- rejected as an architecture :
- `embedding_search` is **FastText word vectors, not sentence embeddings**
  [ `src/coding.tools.handler.embedding_search` loads
  `data/embeddings/<domain>.vec`, means the in-vocab whitespace-split query
  tokens, returns nearest *vocabulary tokens* ]. there is no snippet index
  and no `/v1/embeddings` usage anywhere in `src/`. "index the bank via
  embedding_search" is a subsystem build, not wiring.
- retrieval solves a long-tail problem that does not exist here. the target
  set has **four** members and all four always apply.
- the discoverability objection [ the model will not search for what it does
  not know exists ] is real but trivially fixed by injecting
  deterministically instead of letting the model choose. that fix reduces
  the idea to "few-shot demonstrations in the prompt" -- which IS worth
  measuring, as arm A3 below, but is a prompt change, and prompt changes
  are the class with two nulls behind them. measured separately, never
  load-bearing.

## confirmed mechanism [ read directly from this checkout ]

- **`src/coding.validate.module` already does part of this job** : it
  checks `<[name]>->` bracket syntax, `base.log` vs `base.logs`, `qw`
  delimiters, forbidden `sub {`. but it is **file-addressed and
  detection-only** -- it takes a module name, reads it off disk, returns
  errors. it is never applied to generated output. this task refactors its
  checks to delegate to `coding.idiom.scan` rather than growing a second,
  divergent rule set.
- `src/coding.async.complete` is where a finished inference result is
  handled -- the point `score.py` measures, so the validation arms attach
  here.
- `src/coding.tools.handler.{write_new_file,edit_file,replace_in_file}` are
  where generated code actually reaches disk -- the point that matters in
  production.
- `src/coding.prompt.assemble` is the injection point for the A3 few-shot
  arm only.
- `src/coding.handler.check-completion-chain` is the established precedent
  for enqueuing a follow-up turn against an in-flight task.
- the model's drafts are **near-misses, not absences** -- confirmed by
  reading `data/control-vectors/results/real-system-prompt-v2/A.*` :
  `<[base.logs]>()->( 1, $msg )` [ correct sugar, wrong arrow ],
  `base.logs->( 0, ... )` [ correct module, missing brackets ],
  `return { mode => qw| true |, data => $value }` [ correct shape,
  unquoted keys ]. this is the single most important observation in the
  task : repair is a *local edit*, not a rewrite.

## hazards that waste a run [ read before doing anything ]

1. **the rubric counts quoted keys only.** `score.py`'s `modedata` test is
   `"'mode'" in text and "'data'" in text` -- literal single quotes. the
   model already emits `mode => qw| true |, data => $value`, which is the
   right *shape* and scores **zero**. normalizing bareword hash keys to
   quoted form is legitimate [ real `src/` uses `{ 'mode' => qw| false |,
   'data' => ... }` ] and meaning-preserving in perl, but it moves a rubric
   number without the model having changed. **report it explicitly as a
   normalization, and always report pre-repair alongside post-repair**, or
   this is the 2026-09-09 confound all over again.

2. **a rubric hit that does not resolve is a regression, not a win.** a
   model that emits `<[plausible.sounding.module]>->()` scores well and
   produces code that dies at load time. every rewrite must be gated on
   `coding.idiom.resolve` confirming the module / config key actually
   exists, and unresolved-reference counts must be reported alongside idiom
   counts in every arm.

3. **`score.py` is the pre-registered instrument and stays frozen.** it
   computes `len(text)` into its rows but never prints it, so
   length-normalized numbers need a **separate wrapper importing
   `score_dir` / `score_text`** [ `data/control-vectors/score_norm.py` ].
   do not edit `score.py` to add normalization.

4. **never report a summed "structural total".** `modedata` is
   presence-based [ 0 or 1 per response, caps at 9 over 9 generations ]
   while `invoke` / `cfgaccess` / `truefalse` are unbounded counts. a sum is
   dominated by whichever category happens to be countable. report the four
   separately, `modedata` as a rate out of 9.

5. **do not repair `comment` or `bracket`.** those are the two categories
   the control-vector task's 2026-09-09 addendum identified as confounded by
   the production prompt's own `## header ##` style. leaving them untouched
   keeps any movement there interpretable as the model's own.

6. **do not compare against a stored baseline.** `run_gens.sh` used the stub
   system prompt `"You are a protocol-7 developer."`; `real-system-prompt-v2`
   used the production template. mixing backdrops is the exact confound
   class that produced the walked-back win. regenerate every arm under one
   harness, production prompt as the backdrop.

7. **the existing 36-generation corpus is thinner than it looks.**
   `baseline` and `scale0.0` are byte-identical duplicates, 6 of 36 are
   empty [ think block overran `max_tokens` ], 7 are **python**, and only
   prompt A asks for code at all. usable P7-shaped code responses in the
   production condition : **three**. widen it before drawing a conclusion.

8. **`cfgaccess` is the weak category.** `<(?!\[)[a-z][\w.]+>` also matches
   generic angle-bracket text in prose, and the model's config accesses
   [ `$config->{threshold}`, `$config->get(...)`, `$ENV{CONFIG}` ] name keys
   that do not exist in the live config tree, so they are un-auto-repairable
   by hazard 2. expect this one to move least.

9. on-demand zenka lifecycle : stop/start the coding zenka with
   `v7-zenki.terminate coding` / `v7-zenki.start coding`, **not** a manual
   `coding.draining` flag plus a direct kill [ last session's improvised
   workaround ]. the lifecycle commands go through the zenka's own graceful
   SIGTERM -> `coding.end_code` path and clean up the spawned inference
   child automatically.

10. no placeholder AMOS7 signature stubs on new files -- leave them
    unsigned, a human signs separately.

11. **the corpus directory must be writable by the zenka's unix user, or
    the whole harvest silently no-ops.** `data/idioms/corpus/` created by
    a developer's own account is NOT writable by the `protocol-7` user the
    zenka runs as ; the only symptom is a `permission denied` warn buried
    in the zenka buffer, and every gate call otherwise succeeds. fix
    without sudo [ a developer account is normally in group `protocol-7` ] :
    `chgrp -R protocol-7 data/idioms && chmod g+w data/idioms
    data/idioms/corpus && chmod g+s data/idioms/corpus`. this is a
    deployment prerequisite, not an incidental step -- it is the single
    most likely reason this does nothing on another machine.

12. **`format.package_decl` and `format.use_pragma` block a recognizable
    CATEGORY of legitimate module, not random noise.** their 21 hits across
    real `src/` are concentrated in forked-child / subprocess-wrapper
    modules and Gtk-subclass definitions [ `web-browser.init_code`,
    `download.init_code`, `llm.service.subprocess_wrapper`,
    `base.start.prio_child` ], which genuinely need `package` and
    `use strict`. at `repair+turn` the zenka would be blocked from writing
    a correct forked-child module. before enabling that mode, either add a
    path or content exemption for those shapes, or demote both rules to
    `report`. do not discover this live.

## scope

1. **rule table** : `data/idioms/rules.yaml` -- for each rule a detect
   pattern, a `score.py`-matching category, a repair class
   [ `auto` / `gate` / `assist` ] and the canonical corrected form. a
   separate artifact from `score.py` on purpose : rules are the repair side,
   `score.py` stays the independent measurement side, and not sharing code
   keeps the scorer from becoming a mirror of the rewriter.

2. **two free offline checks, BEFORE building anything** :
   - *detection recall* over the existing result JSONs : classify every
     structural-idiom opportunity into auto / gate / assist. threshold fixed
     in advance, ~50% landing in auto+gate suggested. below it, **stop** --
     repair is really rewrite and the unproven corrective turn would be
     carrying the design.
   - *false-positive calibration* over real `src/coding.*` -- hundreds of
     files of known-good, human-written idiomatic P7. **anything flagged
     there is a linter bug.** this is what catches an over-eager rewriter
     before it corrupts output.

3. **modules**, all content-addressed [ text in, text out ] so they are
   testable offline and reusable by any zenka handling model output :
   `coding.idiom.rules`, `.scan`, `.resolve`, `.repair.auto`,
   `.repair.request`, `.gate`, `.corpus.record`, plus
   `coding.cmd.idiom-check`.

4. **integration** at the three call sites in the mechanism section, with
   `coding.validate.module` refactored to delegate.

5. **config gating** : `coding.cfg.idiom_gate` =
   `off` | `scan` | `repair` | `repair+turn`, plus
   `coding.cfg.idiom_gate.max_turns`. shipped commented out / `off` in
   `cfg/zenki/coding/zenka.v7` = today's unchanged behaviour, same
   discipline as `coding.cfg.control_vector*`.

6. **validation**, four arms, one harness, production prompt backdrop :
   - **A0** baseline, gate off [ regenerated fresh ]
   - **A1** gate at `repair` -- auto-repair only, no GPU turn
   - **A2** gate at `repair+turn`
   - **A3** few-shot demonstrations from `sft.jsonl`, gate off
   3 prompts x 3 seeds [ 13 / 42 / 7777 ] as every prior condition, then
   confirm on the second held-out set `P_D`/`P_E`/`P_F` already written into
   `run_gens_lora.sh` -- the first set has been reused across four
   experiments and is soft.

7. **restore state** : coding zenka back to normal unmodified startup, gate
   config back to `off`, same discipline as the two prior tasks.

## why this produces a durable artifact

`data/idioms/corpus/*.jsonl` accumulates, from ordinary daily use, pairs of
**model-generated draft** and **verified-correct P7 form**, tagged by
category and by whether the resolver confirmed the target. that is exactly
the dataset both prior attempts lacked and had to synthesise : the control
vector used 46 hand-written pairs whose negatives were *de-idiomatised by
hand* rather than actually produced by the model, and the LoRA task's own
hazard 3 says those 46 are far too small. harvested pairs are
in-distribution by construction -- the negative side is what this model, on
this prompt distribution, actually emits.

secondary reuse : `sft.jsonl` [ 403 examples, coverage invoke=220
cfgaccess=108 truefalse=187 modedata=93 ] is not sunk cost -- it seeds the
canonical-form table and supplies the A3 few-shot pool.

## progress log

[ appended incrementally -- see results section at the bottom when done ]

### progress 2026-09-09 : offline calibration [ scope 2 ] -- GO

both pre-build checks ran against `data/idioms/rules.yaml` via
`data/idioms/offline_check.py`, which reads the same rule table the perl
modules use [ so the calibration measures the shipped rules, not a copy ].

**false-positive calibration** -- the rule table was *shaped by this
check*, not merely validated by it. five rules were demoted after firing
on known-good, human-written, committed P7 :

| rule | flags on real src/ | verdict |
|---|---|---|
| `modedata.bare_keys` | 234 in `src/coding.*` | auto -> **report**. bare `mode =>` is normal committed P7 [ 222 quoted vs 122 bare ]. rewriting it would be pure rubric-gaming |
| `invoke.perl_package_call` | 62 | blanket gate -> **auto + `on_unresolved: drop`**. all 62 were legitimate CPAN/core calls [ `YAML::XS::Load`, `Perl::Tidy::perltidy`, `JSON::PP::decode_json`, `File::stat::stat` ] |
| `truefalse.guarded_return` | 21 | auto -> **report**. `return 0 unless ...` is real committed code |
| `format.log_singular` | 11 | auto -> **report**. `src/base.log` is a REAL module distinct from `src/base.logs` |
| `truefalse.bool_assign` | 9 | auto -> **report**. `my $has_name = 0;` is real committed code |
| `modedata.success_error` | 3 [ widened src/ scan ] | auto -> **gate**. `models.storage.adapter.lmstudio.install` uses that contract and callers may depend on it |

final calibration over the **whole 5462-file `src/` tree** :
- **auto-class flags on known-good code : 0**. this is the criterion that
  matters -- auto is the only class that silently modifies code.
- gate-class flags : 24 files / 5462 = **0.44%**, all in shapes where a
  block is recoverable [ `use strict` in subprocess wrappers, helper
  `package` declarations in `web-browser.init_code` / `download.*` ].

**detection recall** over the production-prompt condition
[ `results/real-system-prompt-v2`, 6 code-bearing responses ] :

| category | auto | gate | gate-unresolved | report |
|---|---|---|---|---|
| invoke    | 2 | 1 | -- | -- |
| cfgaccess | -- | -- | 5 | -- |
| format    | -- | 12 | -- | -- |
| modedata  | -- | -- | -- | 16 |
| truefalse | -- | -- | -- | 0 |

**actionable [ auto+gate ] / real violations = 15/15 = 100%** -- clears the
pre-registered ~50% threshold. auto-only share = 2/15 = 13%.

`baseline` and `baseline-nosys` scored **zero** violations: those conditions
answered prompt A in **python**, and a perl-shaped rule table cannot detect
"wrote the wrong language entirely". noted as a real limitation of the
approach, not a clean bill of health.

**two findings that change what this task can claim, recorded before any
implementation :**

1. **the `modedata` floor is substantially a MEASUREMENT ARTIFACT.**
   `score.py` tests `"'mode'" in text and "'data'" in text` -- quoted keys
   only. all 3 production-condition code responses emit
   `return { mode => qw| true |, data => $value }` : the correct P7 reply
   shape, in a form real `src/` uses 122 times, scoring **zero**. so
   "modedata at 0-1/9 in every condition" across the two prior tasks is not
   purely a model failure. `score.py` stays frozen and unchanged; the
   unquoted-form count is reported as a clearly-labelled supplementary
   number beside it.

2. **`truefalse` is not mechanically enforceable, because the codebase does
   not follow it consistently.** 603 TRUE/FALSE across 165 files vs 34 bare
   `return 0/1` across 11. a rewriter strict enough to move the rubric would
   contradict committed code.

**net effect on scope** : of the four structural categories, the gate can
auto-repair **`invoke`** only. `cfgaccess` and `format` are gate-class [ the
unproven corrective turn carries them ]. `truefalse` and `modedata` are
report-only. this is narrower than the design hoped and is stated here
before the numbers come in, not after.

**decision : PROCEED**, with scope as narrowed above.

### progress 2026-09-09 : implementation [ scope 1, 3, 4, 5 ] -- done

new modules, all perltidy'd with the project profile and syntax-checked
against a replica of `bin/Protocol-7`'s `translate_segment` transform :

- `src/coding.idiom.rules` -- mtime-cached loader for rules.yaml
- `src/coding.idiom.scan` -- pure text -> violations
- `src/coding.idiom.resolve` -- the safety oracle [ %code, then src/ on
  disk ; config keys walked segment-by-segment through the real %data ]
- `src/coding.idiom.repair.auto` -- applies auto-class rules only
- `src/coding.idiom.repair.request` -- corrective-turn message builder
- `src/coding.idiom.gate` -- orchestrator, config-driven
- `src/coding.idiom.check_write` -- shared write-boundary helper
- `src/coding.idiom.corpus.record` -- jsonl harvest
- `src/coding.cmd.idiom-check` -- read-only user command

integration :
- `src/coding.async.complete` -- gates assistant content [ `fenced_only`,
  so prose is not scanned ]
- `src/coding.tools.handler.{write_new_file,edit_file,replace_in_file}` --
  auto-repair carried through, gate-class violations refuse the write
- `src/coding.validate.module` -- checks 4/5/6/8 **replaced** by a
  delegation to `coding.idiom.scan`, so there is one rule table instead of
  two that drift. this also fixed a latent bug in that module : its old
  check 5 flagged a bare `<[module.name]>` as an error, but that form is
  legal -- `bin/Protocol-7`'s parser expands it with an implicit `->()`.

config : `coding.cfg.idiom_gate` / `_max_turns` / `idiom_rules` /
`idiom_corpus_dir` in `cfg/zenki/coding/zenka.v7`, all commented out =
unchanged behavior. note `idiom_gate_max_turns` uses an underscore, not a
dot : `coding.cfg.idiom_gate` is a scalar, so a `coding.cfg.idiom_gate
.max_turns` sibling would be the nested-conflict CLAUDE.md warns about.

two bugs caught during implementation, both before any live run :
1. **offset corruption with `fenced_only`** -- scan extracted the fenced
   code blocks and returned offsets into the *concatenation*, while
   repair.auto splices into the *original* string. every rewrite on a
   reply containing prose would have landed at the wrong offset. fixed by
   carrying a base offset per segment.
2. **the parser ate the corrective-turn examples** -- the literal
   `<[module.name]>->( $args )` in repair.request's reminder text is data,
   not code, and `translate_segment` rewrote it to `$code{'module.name'}`
   on load, so the model would have been shown the expansion instead of
   the sugar it is being asked to produce. fixed with the
   `##[:v7-syn:off:]##` switch, the same guard `coding.system_prompt` uses.

scoring wrapper : `data/control-vectors/score_norm.py` imports
`score_dir`/`score_text` from the frozen `score.py` [ confirmed unchanged,
`git diff` empty ] and adds length normalization, the structural/surface
split, and the supplementary unquoted-modedata count.

first output of that wrapper on the stored production condition confirms
finding 1 above numerically : frozen rubric `modedata` = **0/9**,
supplementary unquoted-or-quoted count = **3/9**.

## results [ 2026-09-09, executed against the live coding zenka ]

### harness [ scope 6 ]

`data/control-vectors/run_gens_idiom.sh` + `run_gens_idiom.py`. differs
from `run_gens.sh` in exactly one way that matters : the system message is
the **real production system prompt**, extracted verbatim from
`coding.show-prompt` [ 3593 chars, byte-identical for all three prompts,
so it is request-independent ] rather than the stub `"You are a protocol-7
developer."`. every arm uses that same backdrop -- no arm is compared
against a stored baseline from a different one.

3 prompts x 3 seeds [ 13 / 42 / 7777 ], temp 0.7, max_tokens 700, n=9 per
arm, same prompts and seeds as every prior condition in this thread.

**note for anyone re-running this** : the host has `http_proxy` set, and
`urllib` honours it -- every request to the local inference server returns
`502 Bad Gateway` until an unproxied opener is used. `run_gens.sh` avoided
this by accident, via `curl --noproxy '*'`.

**A1 needs no inference.** auto-repair is a deterministic function of the
text, so A1 is produced by applying it to A0's own generations. A0 vs A1
is therefore a **paired comparison with zero sampling noise** -- the only
arm in this whole thread that is not confounded by run-to-run variance.

### frozen rubric, length-normalized [ `score.py` unchanged, confirmed by
### `git diff` ; normalization via the `score_norm.py` wrapper ]

structural categories, never summed [ `modedata` is presence-based and
caps at 9 ; the other three are counts ] :

| arm | invoke raw | invoke per1k | cfgaccess raw | truefalse raw | modedata rate | mean chars |
|---|---|---|---|---|---|---|
| A0 baseline      | 3 | 0.401 | 0 | 0 | 0/9 | 832 |
| A1 auto-repair   | 4 | 0.535 | 0 | 0 | 0/9 | 831 |
| A2 corrective    | 2 | 0.333 | 0 | 5 | 0/9 | 668 |
| A3 few-shot      | 5 | 1.099 | 1 | 2 | 2/9 | 505 |

on the raw rubric A3 is the clear winner -- the only arm to move all four
structural categories off the floor, and the first non-zero `cfgaccess` in
the entire thread. **that reading does not survive the pre-registered
checks.** two of them fire :

### check 1 : unresolved references [ hazard 2 ]

every `<[module]>->(` and `<config.key>` in scored output, run through
`coding.idiom.resolve` :

| arm | invoke hits | resolve | **fabricated** | cfgaccess hits | resolve |
|---|---|---|---|---|---|
| A0 | 3 | 3 | 0 | 0 | -- |
| A1 | 4 | 4 | **0** | 0 | -- |
| A2 | 2 | 2 | 0 | 0 | -- |
| A3 | 5 | 3 | **2** | 1 | **0** |

A3's `invoke` advantage is 40% fabricated : `<[base.config]>` is not a
module, and its single `cfgaccess` hit `<coding.cfg.threshold>` is not a
config key [ checked against `zenka.v7` ]. **on resolved references A3
scores 3 -- level with A0 and below A1.** a rubric hit that does not
resolve is a regression, as pre-registered ; scored that way, few-shot did
not beat baseline.

### check 2 : the modedata movement is a quoting switch, not more usage

`score.py` counts `'mode'` with literal quotes. reply-shape usage counted
in **any** form :

| arm | frozen rubric | bare form only | **any form [ real usage ]** |
|---|---|---|---|
| A0 | 0/9 | 3/9 | **3/9** |
| A1 | 0/9 | 3/9 | **3/9** |
| A2 | 0/9 | 3/9 | **3/9** |
| A3 | **2/9** | 0/9 | **2/9** |

A3's `+2` on the frozen rubric is entirely the model switching from bare
`mode =>` to quoted `'mode' =>` [ copying the exemplars' style ]. actual
use of the reply shape went **down**, 3/9 to 2/9. this is the same class of
confound as the walked-back 2026-09-09 result, caught this time before it
was reported as a win.

### the corrective turn [ A2 ] was net harmful -- two concrete mechanisms

1. **it induced a semantic bug while raising a rubric number.** A2's
   `truefalse` = 5 is the largest single-category movement in the table,
   and it is all miscoded : `return { mode => TRUE, data => ... }` and
   `mode => qw| TRUE |`. the model substituted the *constant* TRUE for the
   reply-mode *string* `true`. that is broken code that scores well.
2. **the model copied the placeholders out of the correction message.**
   the reminder block ended with literal specimens `<[module.name]>->(
   $args )` and `<some.config.key>` ; in 2 of 3 code generations the model
   pasted `some.config.key` into its corrected output as a real call site.

both were fixed in `coding.idiom.repair.request` after the run : the four
forms are now **described in words with no copyable specimen**, and the
TRUE-constant-vs-true-mode distinction is called out explicitly. the fix
is not re-measured here -- A2 stands as a recorded negative.

this is the outcome the design anticipated : a corrective turn is still an
instruction, the class that had already failed twice, and it was
deliberately kept out of the load-bearing path.

### what actually worked : A1, small and clean

+1 `invoke` [ 3 -> 4 raw, 0.401 -> 0.535 per1k ], every reference
resolving, zero fabrication, zero semantic damage, deterministic and
paired. the single edit :

```
-        <[base.logs]>()->( 1, $msg );
+        <[base.logs]>->( 1, $msg );
```

that is the whole win, and it is honest : a near-miss the model already
produced, repaired into the real idiom, verified against the live module
registry. only 1 of 9 generations contained an auto-repairable violation,
so the effect is small -- but it is the only movement in the table that
does not evaporate under the checks.

### live end-to-end verification

- `coding.idiom-check` on a CPAN-heavy module [ `coding.tools.handler.
  summarize_context` ] : **clean** -- the `on_unresolved: drop` rule shape
  holds live, no false gating of `JSON::PP::decode_json` etc.
- gate at `scan` : two live `coding.submit` tasks, violations detected via
  `coding.async.complete` and harvested to
  `data/idioms/corpus/2026-09.jsonl`, every line valid JSON.

two integration bugs found and fixed by that live run :
1. **permission denied on the corpus.** `data/idioms/corpus/` was created
   by the `taeki` user ; the coding zenka runs as `protocol-7` and could
   not append. surfaced as `cannot open ... [ permission denied ]` at
   `coding.idiom.corpus.record:95`. fixed by `chgrp protocol-7` +
   `chmod g+w,g+s` on `data/idioms/` and `data/idioms/corpus/` -- no sudo,
   since `taeki` is a member of group `protocol-7`. **anyone deploying
   this elsewhere has to do the same, or the harvest silently no-ops.**
2. **pretty-printed jsonl.** `format.json.encode` hardcodes `->pretty(1)`
   and is shared with other callers, so records spanned many lines and
   broke the one-object-per-line contract. `corpus.record` now collapses
   formatting newlines, which is safe because JSON forbids a raw newline
   inside a string literal.

side finding, not fixed : `base.file.append` warns `binmode() on closed
filehandle` and continues after a failed `open`, instead of returning
early. it is how the permission failure above produced three confusing
warnings instead of one.

### restore state

`coding.cfg.idiom_gate` deleted at runtime [ `coding.get` -> `requested
key not found` ], all four config keys ship commented out in `zenka.v7` =
unchanged behavior, gpu inference server healthy on its normal pid. the
zenka was stopped/started with `v7-zenki.terminate` / `v7-zenki.start`
throughout, never a manual draining flag plus kill.

### honest headline

**the mechanism works and is safe, and the size of the win is small.**

- auto-repair is the only intervention in this three-task thread that
  moved a structural category without a confound underneath it. it is
  deterministic, it has zero false positives across all 5462 `src/` files,
  every rewrite is verified against the live module registry, and A0 vs A1
  is paired. it is also worth +1 hit in 9 generations.
- few-shot demonstrations [ A3 ] looked like the big win and were not :
  40% fabricated module references and a modedata gain that is a quoting
  switch masking a real-usage decrease. worth recording as the fourth null
  in this thread, and as a caution -- it would have been reported as a
  success by raw-rubric reading alone.
- the corrective turn [ A2 ] is worse than nothing in its current form and
  is now fixed but unmeasured.
- **two of the four structural categories cannot be moved by this design
  at all**, and that was established before the experiment ran, not after :
  `truefalse` because the codebase itself keeps the convention only ~95% of
  the time [ 603 TRUE/FALSE vs 34 bare `return 0/1` ], and `modedata`
  because the frozen rubric under-counts a form the codebase uses 122
  times and the model already produces.

the durable artifact is the point that survives all of this. the corpus at
`data/idioms/corpus/` now accumulates real (draft -> corrected) pairs from
ordinary use -- in-distribution by construction, which neither the control
vector's 46 hand-de-idiomatised pairs nor the LoRA task's 403 synthetic
examples were. if the steering or fine-tuning paths are ever revisited with
a working checkpoint, they start from real data instead of invented data,
and it grew for free.

### recommended next step

run the gate at `scan` for a week of ordinary use and re-read the corpus.
that costs nothing, changes no output, and answers the question this
9-generation experiment cannot : **which violations does this model
actually make at volume?** the rule table was calibrated against 6
code-bearing responses ; a week of real tasks is the sample that should
decide whether the auto class deserves to be wider, and whether `cfgaccess`
can be promoted out of gate-only once the resolver has real key names to
work with.

do NOT turn on `repair+turn` until the A2 fixes are re-measured.

### files changed

new [ unsigned, per convention -- a human signs separately ] :
- `src/coding.idiom.{rules,scan,resolve,gate,check_write}`
- `src/coding.idiom.repair.{auto,request}`
- `src/coding.idiom.corpus.record`
- `src/coding.cmd.idiom-check`
- `data/idioms/rules.yaml`, `data/idioms/offline_check.py`
- `data/control-vectors/{score_norm.py,run_gens_idiom.sh,run_gens_idiom.py}`
- `data/control-vectors/results-idiom/{A0,A1,A2,A3}/` [ 36 raw json ]
- `data/idioms/corpus/2026-09.jsonl` [ first harvested pairs ]

edited [ existing signatures now stale, need human signing ] :
- `src/coding.async.complete`
- `src/coding.tools.handler.{write_new_file,edit_file,replace_in_file}`
- `src/coding.validate.module`
- `cfg/zenki/coding/zenka.v7`
- `cfg/zenki/coding/subroutines.load-early`

`data/control-vectors/score.py` deliberately **unchanged**.

### note on zenka state, for the next session

`data/control-vectors/lora/PROGRESS.md` records the coding zenka as fully
STOPPED at the end of the LoRA session. it is now **running** -- started
here with `v7-zenki.start coding` for the validation arms and deliberately
left up [ on-demand, 4620s idle timeout, gpu inference server healthy ].
that is a divergence from what PROGRESS.md describes ; nothing is wrong,
the zenka will simply idle out on its own. the `coding.draining` flag was
never set by this session and `coding.get draining` returns not-found.

#,,,,,..,,.,.,...,,,.,.,.,..,,...,..,,,..,...,..,,...,...,...,.,.,,..,.,,,,.,,
#45MCX4GV5GRC7ENMASACP6BQSVXBUH6R3B6BSUQEXD32IUPTC65CGZGCFOZJUFTVGC5JTDQOBUPEK
#\\\|JBDYHENAFMVXDTMULO6OGVWFRSW6Z7GQF6GKPON4IMAWFF5NYJR \ / AMOS7 \ YOURUM ::
#\[7]5EECDSM7N45OAEKZBBCVRH4YLRDY67VR4TNZDDSBGX3TQGHQXWBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
