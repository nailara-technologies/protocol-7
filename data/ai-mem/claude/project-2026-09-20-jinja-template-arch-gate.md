---
name: project-2026-09-20-jinja-template-arch-gate
description: "coding.jinja.template_file was applied unconditionally to every spawned model regardless of architecture until this session's fix added coding.jinja.arch_pattern gating -- explicit user decision NOT to retroactively retest/rescue any model deleted before the fix"
metadata: 
  node_type: memory
  type: project
  originSessionId: 6e49f0ab-caa0-40aa-880e-624860973ca3
  modified: 2026-09-20T12:36:31.285Z
---

`coding.spawn_inference_server`'s `--chat-template-file` override
(`coding.jinja.template_file`, currently
`data/jinja/templates/qwen3.8-sharp.jinja`) was force-applied to every
spawned model with zero architecture check, despite the config comment
in `cfg/zenki/coding/zenka.v7` already documenting it as
architecture-scoped (`general.architecture = qwen35`), not universal.
Found while investigating why Bonsai-27B (`BZPO73Q:F7DO47A`, a
near-1-bit `Q1_0`-quantized 27B, see
[[project-2026-09-20-model-sweep-crash-bucket-resolved]]) produced
unusually verbose `<think>` traces during manual interactive testing.

Fixed same session: `general.architecture` is now extracted at
discovery time (`models.discover.scan_directory`), threaded through
`models.registry`/`models.cmd.discover`'s text protocol/
`coding.handler.models_discover_reply` into `coding.model_metadata`,
and `coding.spawn_inference_server` now gates the template override on
a new `coding.jinja.arch_pattern` config (regex against
`general.architecture`) -- empty pattern preserves the old
unconditional behavior, a set pattern skips the override (falls back
to the model's own built-in template) when the architecture doesn't
match, logged clearly either way.

**Live A/B result, same session**: architecture match is a real
improvement over unconditional application, but not a fully reliable
proxy for "this template helps this model." Tested directly on
Bonsai-27B by spoofing its cached `architecture` field to a
non-matching value (skips the override without touching global
config) and re-switching: TTFT for the identical self-test prompt
dropped from 85-103s (template forced on, matching architecture) to
37.74s (template excluded, model's own embedded chat template) --
roughly 2.5-3x faster, with a visibly shorter/terser reasoning trace.
Raw tok/s was unchanged (kernel/quantization-bound, unaffected by
templating). So for Bonsai specifically, the qwen3.8-sharp template
(built for the qwen3.5/3.6/3.8 lineage) actively hurts despite
matching `general.architecture = qwen35` -- Bonsai is architecturally
qwen35 per its GGUF metadata but is enough of an outlier (base
`prism-ml_Bonsai`, near-1-bit `Q1_0`/ftype-40 quantization) that the
architecture-level match doesn't hold for it. Left as a documented
known exception, not fixed further this session -- a future finer-
grained gate (e.g. also checking `general.basename`/source lineage)
is a real option if more counterexamples turn up, but one data point
isn't enough to justify building that now.

**Explicit user decision**: since this bug could plausibly have
contributed to some models' crash/timeout verdicts in earlier
sessions' crash-bucket classification (a mismatched template could
produce malformed prompts or runaway reasoning), the user was asked
whether to retest any already-deleted models against the fix and
explicitly said no -- "we should not re-test any already deleted ones
because of it." Don't second-guess this in a future session; those
models are gone and there's no clean way to verify after the fact
whether the template mismatch specifically was the cause. This only
governs backward-looking re-litigation -- it says nothing about future
sweeps, which will naturally benefit from the fix going forward.

#,,.,,,..,,,,,..,,.,,,..,,...,,,,,,,.,,..,.,,,..,,...,...,,.,,,.,,,..,.,,,,,,,
#E25NW6VS7IKZAHKDZHJELHW2ISSLNWCLRDWML5EAFZWAML7WXSIGX5RFXZGAODQAWC7BJEYXXCMLI
#\\\|MJFI6T2X6PET7I2QZHZLNMSZ3HRDMOEW3BEIXSTGR6PEFHNEE5J \ / AMOS7 \ YOURUM ::
#\[7]4ZHOWHZQAHHRKAP7GNX4WQ6RAE5QHR3SC3E4JIGR7XF45ZZ5QICQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
