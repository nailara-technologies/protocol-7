---
name: kimi-k2-7-vs-k3-tier-economics
description: "K3 is a categorically stronger reasoning model than K2.7, pricing reflects it (~3.75x output, >3x input) — dispatch higher-impact tasks to K3"
metadata: 
  node_type: memory
  type: project
  originSessionId: e523a9e4-c458-47e5-b27c-c60766dd51a9
  modified: 2026-07-19T03:36:10.161Z
---

2026-07-19, user's assessment after the coding-zenka scratchpad-rescue task
([[topic-scratchpad-rescue-coding-zenka-task]]) landed cleanly: K3 no longer shows the "stream of
self-corrections that is just determined enough" pattern visible when reading K2.7-or-below thinking
traces directly — K2.7 gets to a working result mostly by brute-force iterate-until-convergence; K3
reasons cleanly with only minor course-corrections. This is a categorical difference, not a matter of
better-steered prompting (see the correction in [[topic-dynamic-context-prep-vs-model-size]] — human
hints given during that task were minor, not the main driver of quality).

**Pricing reflects the tier jump**: K2.7 = $4/1M output tokens; K3 = $15/1M output tokens (~3.75x).
Input tokens: K3 is also >3x K2.7's input price. Session usage on this task: 30% session budget, 47%
weekly, 92h remaining in the cycle — real cost, but user judged it a fair trade for this quality level.

**Confirmed via primary source** (buildfastwithai.com/blogs/kimi-k3-review, fetched 2026-07-19, K3
released 2026-07-16): input $3.00/1M, output $15.00/1M, cached input $0.30/1M — "5x above its own K2
family" in cost, pricing described as matching Claude Sonnet's tier. Specs: 2.8T-param MoE, 1M-token
context, text+image+video input, reasoning always-on (tunable effort locked to max at launch — matches
[[topic-kimi-k3-thinking-effort]]'s finding that lower effort isn't wired up yet). Benchmarks: GPQA
Diamond 93.5% (best open-weight published), Terminal-Bench 2.1 88.3% (near GPT-5.6 Sol's 88.8%),
BrowseComp 91.2% (web-agent record), AA Long-horizon Elo 1547 (second only to Claude Fable 5). Explicitly
weaker than K2.7 on high-volume routine coding due to the cost multiplier — matches the K2.7-for-token-
efficiency split below. Open weights promised by 2026-07-27.

**Efficiency data point, same day, second dispatch**: the cred-mesh confused-deputy fix
([[topic-scratchpad-rescue-coding-zenka-task]]'s sibling task,
`data/tasks/completed/cred-mesh-subscribe-handler-reflection.md` conceptually — full security fix +
live verification + a real negative/attack test + regression check against the existing test harness)
cost only **~2% of weekly budget** (47%→49%). Much cheaper than the scratchpad-rescue dispatch despite
comparable real-world stakes, plausibly because the task file had the discovery cost already fully paid
before dispatch — exact mechanism (`command_aliases` source_zenka alias), exact precedent module
(`credentials.cmd.request_session`), and an explicit scope boundary (cred-mesh only, not the wider
audit). Reinforces [[topic-dynamic-context-prep-vs-model-size]]'s thesis directly: token cost isn't just
a function of task difficulty, it's a function of how much of the investigation is still left for the
model to do at dispatch time.

**K3 also self-records more actively into its own memory** (`data/ai-mem/kimi/`) — per the user,
noticeably more than earlier Kimi generations: it writes down gotchas it hits mid-task (see
`data/ai-mem/kimi/2026-07-19-coding-zenka-scratchpad-rescue-tools.md`'s own "Gotchas hit" section from
the scratchpad-rescue task, e.g. the `File::stat` overload) so it doesn't re-discover them next time.
This compounds with the context-prep thesis above: K3 isn't just cheaper to run well-scoped, it's also
building its own front-loaded context over time, unprompted.

**How to apply** (user's stated split, 2026-07-19): K3 is now the tier for tasks that would otherwise
have needed Sonnet or even Opus — "a cheaper Opus-light with its own neutral character," but billed on
the Kimi budget rather than the Anthropic one. Reach for it on higher-impact / correctness-critical work
(permission models, concurrency, protocol design — things where a wrong-but-plausible result is
expensive to catch later). K2.7 stays the right choice for regular or longer tasks where token
efficiency is itself a factor — i.e. don't default everything to K3 just because it's better; use it
where the quality jump is actually worth ~3.75x output / >3x input cost. See
[[topic-kimi-k3-thinking-effort]] for the model-routing param location (`k3|k2.7|k2.7-fast`,
`bin/mcp-server-p7` ~line 3048) and [[project-kimi-token-economics-2026-07]] for the separate
speed-tier (6x) vs regular-speed usage-multiplier finding — a different axis from the k2.7-vs-k3 choice.

**Real API model-key names, confirmed live 2026-08-04** against the running
`kimi-web` backend's own `GET /api/config/` (`http://127.0.0.1:5494`, needs
`--noproxy '*'`/`no_proxy=localhost,127.0.0.1` — plain localhost gets
intercepted by proxy env vars in this environment): the short aliases used
elsewhere in memory (`k2.7`, `k2.7-fast`) are **not** the literal API keys.
Real names: `kimi-code/kimi-for-coding` = k2.7 (262144 ctx), `kimi-code/
kimi-for-coding-highspeed` = k2.7-fast (262144 ctx), `kimi-code/k3` (1048576
ctx), `kimi-code/k3-256k` (262144 ctx). All four currently show
`capabilities: [video_in, image_in, thinking]` except `k3-256k` (no
`video_in`, matches [[reference-kimi-k3-256k-model]]). `default_model` was
`kimi-code/k3`, `default_thinking: true` at check time. `PATCH /api/config/`
can change the global default (optionally forcing already-running sessions
to restart onto it) — model selection is global to the kimi-web process,
not settable per-session (`CreateSessionRequest`/`UpdateSessionRequest` have
no model field). See `data/tasks/kimi-zenka-model-awareness.md` (K3 dispatch
`kcbdrrlm1`, in flight) for wiring this into `kimi.cmd.list-models`/
`kimi.cmd.set-model`.

**Opus-design + k3-256k-implement split, validated end-to-end (2026-08-25)**:
for a task with real FFI/C-interop correctness risk (binding missing
libgit2 functions via FFI::Platypus — pointer lifetime, `git_buf`
alloc/dispose, matching an existing wrapper library's internal conventions),
user proposed splitting into `claude_dispatch(model=opus)` for design-only
output (no code) followed by `kimi_dispatch(model=k3-256k)` implementing
against that spec. Worked cleanly: Opus's spec was independently verified
line-by-line against the actually-installed source (exact `FFI.pm` line
matches, exact `nm -D` symbol offsets, verbatim `check_rc` convention
citation) with zero discrepancies found, then k3-256k implemented against
it, self-caught two real bugs via its own live testing (an FFI `attach()`
package-binding mismatch, and a buffer-lifetime bug in a helper sub) and
fixed both correctly. Confirms this split is worth reaching for whenever a
kimi task's *design* step carries real correctness risk that's cheap to
front-load into a spec (FFI bindings, protocol/wire-format work, anything
with pointer/memory-lifetime stakes) — Opus absorbs that risk in a
code-free pass, k3-256k gets a mechanical-enough target that it can also
self-verify against instead of guessing.

**k2.7 confirmed again same session** for two genuinely narrow, mechanical
MCP-server param-addition tasks (`dispatch-template-param.md`,
`dispatch-create-template.md` — both had the exact Perl code to insert
already written into the task file, one named precedent each) — both
landed clean, no fixes needed on either, consistent with
[[narrow-scoped-kimi-task-file-pattern]]'s track record.

**Default-ordering policy correction, 2026-08-31**: I had been
pre-judging model choice upfront based on whether a task "looked"
foundational/complex (picked K3 for two dispatches same session purely
on that read, before trying K2.7 first). Per the user: **default to
K2.7 even right after a weekly reset with 0% utilized** — not just for
tasks that already look narrow. K2.7's quality is good enough that it
becomes *obvious during scoping/execution* when a task actually needs
K3, and that's the right moment to escalate — not a pre-emptive guess
made from the task's surface shape alone. This matters even when budget
is abundant: it's not purely a cost-conservation habit, the user framed
it as a genuinely better default regardless of how much budget is left,
because starting with K2.7 is how you *find out* whether K3 is actually
needed, rather than assuming it from task type. Concrete trigger for
this correction: two same-session K3 dispatches (both real,
foundational-bootstrap-code tasks touching every zenka's startup/dep-
check path) that may have been able to start on K2.7 first, with K3
reserved for if/when K2.7 actually proved insufficient.

**Mechanism, corrected after verifying against actual code (not the tool
schema's description text)**: I first claimed the omitted-`model`
default was full K3, sourced only from `kimi_dispatch`'s own tool-schema
description string ("model: k3 (default, best reasoning, large
context)"). The user pushed back ("or is it? we should verify that")
and grepping `bin/mcp-server-p7` directly found the real implementation
(~line 3740): `$args->{'model'} //= 'k3-256k';`, with an inline comment
dated 2026-08-16 explaining this was **already a deliberate
cost-conscious choice**: "default is k3-256k, NOT full k3 ... same
reasoning quality at roughly half the quota cost ... so any dispatch
that omits 'model' lands on the cheaper option rather than the most
expensive one." So the tool's *description text* is stale/inaccurate
relative to its actual code (says "k3", code says "k3-256k") — a real
but separate discrepancy, not something to silently "fix" without being
asked, just worth knowing the description can't be trusted as the
source of truth for this tool's actual default behavior.

**What this changes**: the omit-`model` default was never as bad as "no
deliberate reason, full price" — it already defaults to the cheaper
256k tier. The user's actual policy guidance from earlier in this same
exchange still stands on its own terms though (default to K2.7 even
with a fresh full budget, escalate only once K3 becomes obviously
needed) — that's a preference about which tier to reach for by default,
independent of what the tool's own fallback happens to be. Still worth
passing `model` explicitly rather than relying on the omitted-parameter
fallback, both for that reason and because a schema/code mismatch like
this one means the omitted behavior isn't reliably self-documenting
from the tool description alone — verify against the actual source
before trusting a claim about a tool's default, including a claim
written into this memory file.

#,,,,,..,,,..,,,,,,,,,.,.,,,,,,,,,,,.,,,.,,,.,..,,...,...,..,,,.,,,..,...,..,,
#VB3RLF3JN7KIPMEIN2Z4BYEJMZX7XDLTPWSDRRMDLD5TWCXHETEV2NIIYODNCK6EUIJQUWLCERYMC
#\\\|RIGKFH3EYAQGMCQS3EYNLZLQ2W3M7SDIYK57HFYSGS4VIRJ7FS4 \ / AMOS7 \ YOURUM ::
#\[7]3D7RTFSAFAN3UXWJKKS37QET2VTF6P62IBQKKBCUC3UC5B5KFWAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
