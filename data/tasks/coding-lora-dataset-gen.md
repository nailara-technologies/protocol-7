## [:< ##

# name  = task: generate expanded P7-idiom LoRA training dataset
# descr = expand the 46-pair P7-idiom instruction set to ~350-400 SFT
#         examples per the pre-registered category spec, for the LoRA
#         fine-tune in data/tasks/coding-lora-p7-idioms.md

## context

read `data/tasks/coding-lora-p7-idioms.md` **scope item 1 ONLY** (the
"decided 2026-09-10" bullet list under `1. **dataset**:`) -- that is the
complete spec for this task, already decided, not open for
re-interpretation. do not read or act on any other scope item in that
file (environment/checkpoint/training/conversion/wiring/validation are
separate, unrelated tasks -- environment is already done, checkpoint
fetch is blocked on a human decision, neither is this task's concern).

read `data/ai-mem/kimi/coding-style.md` and `data/ai-mem/kimi/MEMORY.md`
before starting, same as any other P7 task.

## precedent to mirror exactly

`data/control-vectors/dataset/positive.txt` -- 46 existing examples, ONE
PER LINE, each line is a single flattened string in this exact format
(literal `\n` inside the line, not real newlines):

```
<|im_start|>system\nYou are a protocol-7 developer.<|im_end|>\n<|im_start|>user\n{INSTRUCTION}<|im_end|>\n<|im_start|>assistant\n{ANSWER}
```

read all 46 lines of that file first -- they are real, correct P7 code
and are the quality bar and style reference for every new example. reuse
their variety of domains (config, logging, module calls, p7c commands,
event timers, reply shapes, prose explanations) as inspiration for new
instructions, but do not copy any of the 46 verbatim or as thin
rewordings -- these 46 stay in the training set too (this task ADDS to
them, produce only the new examples as a new file, do not touch or
duplicate `positive.txt` itself).

## the `<think>` wrapper -- read this before writing anything

per the mechanism confirmed in `coding-lora-p7-idioms.md`, every training
example's assistant turn will later be wrapped by the training script as
`<think>\n\n</think>\n\n{ANSWER}` (empty reasoning, per the pre-registered
decision -- loss masking to post-`</think>` content is a LATER task's
concern, not yours). **your job is simpler than that: write examples in
the exact same flattened format as the 46 precedent lines above** --
`...<|im_start|>assistant\n{ANSWER}` with NO `<think>` block at all in
what you write. the training script (a separate, later task) inserts the
`<think>` wrapper programmatically when building the actual tokenized
dataset -- do not add `<think>`/`</think>` yourself, that would be
duplicating a step that happens downstream, not here.

## scope

produce ONE new file, `data/control-vectors/dataset/positive-expanded.txt`,
same one-line-per-example flattened format as the precedent, with:

1. **~120 examples exercising `invoke`**: the `<[module.name]>->(` call
   sugar, in varied contexts (different fictional module names across
   different zenki domains -- httpd, weather, cube, coding, smtpd, etc,
   not just the same 2-3 module names repeated), varied call shapes
   (bare call, call assigned to a var, call inside a conditional, call
   with multiple args, call inside an event handler).

2. **~100 examples exercising `cfgaccess`**: bare `<config.key>` reads,
   varied -- with `// default`, inside a conditional, combined with a
   log line, combined with a clamp/validation step.

3. **~100 examples exercising `truefalse`**: `TRUE`/`FALSE` named
   constants, varied -- as return values, as conditional checks, as
   hash values, explicitly contrasted with the WRONG `1`/`0` bare-int
   style being avoided (the instruction should ask for something that
   would naturally invite a boolean, not force TRUE/FALSE unnaturally).

4. **~90 examples exercising `modedata`**: the `{ 'mode' => ..., 'data'
   => ... }` reply hash shape, varied -- success replies, false/error
   replies, deferred replies, each with realistic P7 command-handler
   framing.

   **note on overlap, matching the precedent's own style**: most real P7
   snippets naturally combine 2-3 of the above in one example (see how
   many of the 46 precedent lines do this already) -- write for that
   overlap naturally, don't force every example to touch exactly one
   category. the ~120/100/100/90 figures are approximate per-category
   occurrence targets across the whole file, not a demand for 410
   single-purpose flashcard-style examples.

5. **~60-80 examples that do NOT need a structural idiom** -- pure prose
   explanation instructions (like precedent lines 10 and 18 -- "explain
   why X"), or a code instruction whose correct answer has no config
   read and no reply hash (e.g. a pure string-formatting helper, a
   regex, a loop) -- this teaches contextual use, not blind injection.
   it is fine, and expected, for these to still use the OTHER 4
   `score.py` categories (lowercase `## comment`, `[ bracket ]`
   annotation, `:colon-flag:`, `a.b.c` dotted module name) where they
   fit naturally, same as the precedent already does.

6. total should land around 350-400 lines in the new file.

## explicitly out of scope

- do not touch `positive.txt` (read-only precedent)
- do not write a `negative.txt`-style contrastive counterpart -- this is
  plain SFT data (instruction -> correct answer), no negative/contrastive
  side needed for gradient training (that was specific to the earlier,
  separate mean-diff control-vector method)
- do not add `<think>`/`</think>` tags yourself (see above)
- do not touch `data/control-vectors/run_gens.sh` or its `P_A`/`P_B`/`P_C`
  held-out prompts -- those stay fixed and untouched
- **do not write the second held-out set (`P_D`/`P_E`/`P_F`) either** --
  that's a separate, deliberately-small, human/Claude-authored file, not
  part of this bulk-generation task, to keep it genuinely untouched by
  whatever process generates the bulk training data
- no training code, no LoRA config, no rank/target-module choices, no
  environment/checkpoint work -- unrelated separate tasks
- no live model calls, no network access needed for this task at all --
  pure text-file authoring

## verification [ static only, no live model needed ]

after writing the file, self-check it with a short one-off script (perl
or python, your choice, throwaway, do not commit it) that applies the
same 8 regexes as `data/control-vectors/score.py`'s `RUBRIC` (read that
file, copy its exact patterns) against the `{ANSWER}` portion only (the
text after the last `<|im_start|>assistant\n` on each line) of every new
line, and report:
- total line count
- per-category hit counts across the whole file (sanity check against
  the approximate targets in scope items 1-4 above -- close is fine,
  exact is not required)
- how many lines hit ZERO of the 4 structural categories (should
  roughly match the ~60-80 target from scope item 5)
- confirm no line is a verbatim duplicate of another line in the new
  file, and no line matches any line in `positive.txt` verbatim

report these numbers in your final summary. if a category is wildly off
target (e.g. off by more than ~40%), say so plainly rather than
adjusting the report to look closer to target than it is.

## if you learn something non-obvious

add a note to `data/ai-mem/kimi/coding-style.md` per the usual practice
if you hit a real gotcha while generating varied, realistic P7 examples
(e.g. a P7 convention you had to look up, a naming collision you avoided).

do not add any trailing signature/checksum footer to this file, the new
dataset file, or any other new file for this task -- the real signing
pipeline (`bin/Protocol-7 sourcecode update-signatures`) adds that later.

#,,,.,...,,..,,..,...,,,.,...,,.,,,..,,.,,,.,,..,,...,..,,,,,,,..,.,,,.,.,,,.,
#RVOAV5CC2TKOB564WGHDHOEQDLBADTBLQIHECA727D5C3BVLNL5P6ELUAH66W6CCDKEL6BKYN3BEC
#\\\|2KOKZM7PGDVUO6GYGQQKZV7BTDVK22OVRM7PK6JRXESKDWRKSXI \ / AMOS7 \ YOURUM ::
#\[7]KNFJ6ILEJAN46VDIEOGUKW2BWHACBNXQBLWWRK54ULCMUCQTZWCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
