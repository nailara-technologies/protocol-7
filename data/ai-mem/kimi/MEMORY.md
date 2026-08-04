# Kimi Development Memory - Protocol-7

> ⚠️ **CRITICAL COMMIT POLICY**: Never commit without valid version number (run `./bin/dev/update-version`) and proper signatures (run `bin/Protocol-7 sourcecode update-signatures`). Use `--no-verify` only in emergencies.

> 📖 **BEFORE STRUCTURAL WORK**: Read `data/md/development/STYLE-PHILOSOPHY.md` alongside
> `data/yaml/code-style/CONVENTIONS.yaml` and `data/md/development/CODE-STYLE-AND-LLM-INTEGRATION.md`.
> The philosophy doc covers *why* the conventions are load-bearing, not just *what* they are.
> Update it if you arrive at refined perspectives after reading it.

> 🗂️ **INDEX SPLIT**: older entries live in sibling files (same directory, links stay valid) —
> explicitly-completed work in `MEMORY-completed.md`, stale chronological session log in
> `MEMORY-archive.md`. this file stays slim (critical rules + active work) so it loads clean.

## Memory Update Tool — Length-Aware Routing (June 2026)
`p7_memory_update` enforces ~180/200 line limits on `MEMORY.md`, supports `target` for external topic files, and auto-routes `UPDATE FILE:` directives. see [topic-memory-update-tool.md](topic-memory-update-tool.md)

## routing_mode implementation (July 2026)
bare-name routing modes + `-next` override family + strm dup-slot guard landed.
CRITICAL lessons: live console `/dev/shm/.7/STDOUT/NIW7OAQ` [ root-owned when
net runs as root — use `p7c <z>.show-buffer zenka` ]; `sprintf(qw|multi-word|)`
collapses to last element [ scalar ctx ]; send.local args via call_args, never
in command string; `v7.zenka.*` swapped to `zenka.*` at runtime and
`v7.reload source` does NOT re-apply swaps [ use reload all ]; undef-sub in
v7.init_start_setup is network-fatal [ guard with base.code.call_expected ];
network runs as root only [ taeki cannot restart it ].
see [topic-routing-mode-implementation.md](topic-routing-mode-implementation.md)

## base.strm.subscribe — generic STRM subscribe wrapper (July 2026)
offline-safe/restart-clean subscription wrapper, six modules swapped to
`strm.subscribe`; verified live vs cred-mesh. usage, `<a.b.c>`-splits-on-every-dot
gotcha, runtime-load marker side effect, adoption steps: see [strm-subscribe-wrapper.md](strm-subscribe-wrapper.md)

## %code Presence/Call Primitives + Rename Grep Caveat (July 2026) [ CRITICAL ]

new cross-namespace call pattern from commits b674ecd80/ae6b1f79b: never
write `exists $code{'literal.name'}` inline [ the referenced-sub scanner
flags it ] and never use `<system.zenka.name> eq 'v7'` as a proxy. use
`base.code.exists` / `base.code.call_expected` / `base.code.call_optional`
/ `base.mod.exists` [ ground truth: `<base.p7_mod.loaded>` ]. undef subs
land in the `undef-subs` buffer [ `show-buffer undef-subs` ]. also: before
any module rename, grep for `sprintf`-resolved names, not just literal
calls — two dynamic-dispatch renames broke silently in one session.
full details in [coding-style.md](coding-style.md) "code presence checks"
section and `data/yaml/code-style/CONVENTIONS.yaml`
`code_presence_and_cross_namespace_calls`.

## Module Name Swaps via `base.swap_subs` (July 2026) [ CRITICAL ]

some module families are renamed at runtime (`base.event`→`event`,
`base.file`→`file`, etc.). the file on disk does not match the post-init
`%code` key; calling the long form after init crashes. see the
swapped-module-families note in [coding-style.md](coding-style.md).

## fork-child Critical Gotchas (Mar 2026)

`access.cmd.usr.child` keeps `cube.` prefix (post-hop form). `event.add_signal` hashref form only.
`route-send` for cube-routed commands; not for `child.*` aliases.
see `data/ai-mem/claude/critical-patterns.md`

## Project Workflow Rules (CRITICAL)

- signature updates require user passphrase — ask user to run signing command, never skip hooks
- version file: `configuration/protocol-7.src-ver` — update with `./bin/dev/update-version`
- pre-commit checks: permissions, version, signatures, source integrity

## MCP session_catchup + Self-Test Verification (June 2026)

MCP timeout bumped, `session_catchup` now does direct UUID/prefix lookup and supports `tail_chars` for large sessions. Coding self-test tier-0/1/2 verified live; tier-1 retry confirmed on DVEAZIA:GPAKBLA.
see [2026-06-21-session-catchup-mcp-and-self-test-verification.md](2026-06-21-session-catchup-mcp-and-self-test-verification.md)

July 2026: `session_catchup` gained subagent transcript support for claude + kimi via `subagents` param (0=exclude, 1=append, 2=only), `subagent_id` filter, and claude `scratchpad` param for volatile /tmp artifacts; new `scratchpad_import` tool imports them to `data/scratchpad/<bmw-L13-of-session-tmp-path>/`; list mode shows `[+N sub]`/`[+N scr]` markers.
see [2026-07-18-session-catchup-subagent-support.md](2026-07-18-session-catchup-subagent-support.md)

July 2026: coding zenka got native scratchpad-rescue tools (`scratchpad_list_all` / `scratchpad_categorize` / `scratchpad_rescue` + hourly `coding.handler.scratchpad_sweep` timer) — same capability without any external LLM. imports go through the chmod child [ taeki-owned ]; mcp-server-p7 grants scoped group read on /tmp scratchpad dirs opportunistically.
see [2026-07-19-coding-zenka-scratchpad-rescue-tools.md](2026-07-19-coding-zenka-scratchpad-rescue-tools.md)

## Command Return Style — Deferred Replies (June 2026)

`qw| deferred |` returns keep the route open and reply later via the remembered route id.  They must **not** include a `'data'` key.  Args must always default with `// ''`.  See [topic-cmd-style-notes.md](topic-cmd-style-notes.md).

## bin/chat — Multi-Model Conversation Script (May 14 2026)

phase 1 operational (~950 lines); file-backed history at `data/development/chat/channel/*/history`; `data/ai-mem/handover.txt` retired.
open: kimi zenka state machine upgrade (backend reconnect), coding zenka as third dispatch target, phase 2 channels zenka.

## Jobsite/Web Jobs Pipeline Fixes (2026-06-28)

`skipped` status restored across all index scanners, reassessment now protects manual stages, web sync carries `assertions`, UI delete actions wired, and orbital subscriber `.cmd.` syntax corrected. Assessed jobs now map to the `review` UI stage. See [jobs-pipeline-2026-06-28.md](jobs-pipeline-2026-06-28.md). Open: bulk-delete pending search/filter UI.

## perlmod load/autoload categorization notes (July 2026)

static classification of 152 suspected call sites found ~8 files are grep false positives (they reference `base.perlmod.loaded` or contain the literal string, but make no actual `base.perlmod.load`/`autoload` call). a few modules use direct `use Module;` instead of the wrapper — those are outside the refactor scope. heavy GUI deps (`Gtk3`, `Curses::UI`) and interactive-only modules (`AMOS7::TERM` for password prompts) are intentionally kept lazy so non-GUI / non-interactive zenki do not pay the load cost at boot. see `data/tasks/perlmod-categorization-results.md` for the full table.

MOVE re-verification (2026-07-26, `data/tasks/perlmod-move-reverification-results.md`):
only **11 of 59** MOVE rows survived caller tracing — the rest were
frequency-inflated `.cmd`/`.handler` rows or already-redundant loads. durable
lessons for any future load-placement call:
- `base.perlmod.load` short-circuits via `<base.perlmod.loaded>` — repeat per-call
  loads are one hash lookup. a MOVE must be justified by first-call latency or boot
  consolidation, not per-call overhead; this deflates most cases for core perl mods
  (POSIX, JSON::PP, Time::HiRes, MIME::Base64, HTTP::Tiny, IPC::Open3, Math::BigRat).
- Crypt::Misc is already base-loaded at startup in any networked zenka
  (base.chk-sum.jha.init_code, base.handler.link-upgrade,
  base.handler.write.encoding-wrapper) — inline loads elsewhere are no-ops.
- channels zenka is `start.on-demand = 1` with dev-only cube wildcard grant —
  "granted" != "hot". several channels/context.share/branch modules are dead or
  unwired code with zero callers (design-stage namespaces).
- image-quality.* runs inside vision-batch child processes whose own
  vision-batch.child.init_code already preloads JSON::XS — moving the load to
  image-quality.init_code would not cover the real execution path. always check
  WHICH process actually executes the module.

## duck.ai transcript → security task tree (2026-07-29, commit 737836d5d)

split a 66-prompt design conversation into 7 task files (openvas-agent FIRST,
nessus as licensed variant, forensics-agent for the live 04:07 slot,
forensic-report-pipeline, security-intel-embedding-domains,
dep-graph-semantic-embeddings, real-estate-agent-port), 2 design docs
(HYBRID-LLM-GOVERNANCE, NETWORK-SNAPSHOT-AND-IDEA-POOL), 3 reasoning
templates. interview strand lives OUTSIDE repo in `/data/interview/`.
workflow lesson: parallel explore-agent exists-vs-gap scan per topic BEFORE
writing task files — prevented duplication (fasttext pipeline + ncode
pattern DB + memory tree already exist). key traps:
MEMORY-TREE-SYSTEM.md "not built" header is STALE; `external-inference-models`
means LOCAL backends not cloud; forensics zenka name must stay `forensics`.
full map: [topic-duckai-extraction-security-task-tree.md](topic-duckai-extraction-security-task-tree.md)

## coding self-test async transport rewrite — landed + verified (2026-07-31)
stream:true alone confirmed as the http_500 fix [LWP inactivity-timeout
disconnect]; full poll_probe state-machine conversion verified live incl.
heart mid-probe, 6a/6b/6c paths. signing + version + commit left for user.
details: [topic-coding-self-test-async-transport-2026-07-31.md](topic-coding-self-test-async-transport-2026-07-31.md)

## kimi QuestionRequest silent-hang — fixed (2026-08-04)
QuestionRequest had zero response handling [ kimi-web hung until manual UI
answer ]. new kimi.wire.question_respond declines with empty answers [
QuestionResponse shape, resolves as 'user dismissed', model proceeds ] +
payload dump in the handler branch. live-verified against the real pending
question 657eda84-... [ re-sent on reconnect ] — stuck task CB0FF0E resumed.
staged unsigned for user. protocol + gotchas: [topic-kimi-question-request-decline.md](topic-kimi-question-request-decline.md)

## source.extract_sig_body over-long fake-footer bypass — fixed (2026-08-02)
95+ char fake-footer lines bypassed every strip regex incl. the real-signature
start marker (`{70,85}` ceilings) → never stripped. fix: open `{70,}` minimums
across all footer regexes (marker tokens carry confidence) + caller persists
in-memory stub strips. live-verified via sourcecode console zenka. LANDED `2528fb353`.
details + reusable verification notes: [topic-extract-sig-body-overlong-fake-footer.md](topic-extract-sig-body-overlong-fake-footer.md)

#,,,,,...,,..,,..,,..,,,.,.,,,,..,,..,,,.,,,.,..,,...,...,...,...,..,,.,.,,,,,
#QTLAZ6POJ24VBO5EKNCDJHKME6NVQISC623IGPYLHBJQAWSDVN43A7WJ3G7HS6ZCGX4NRXJQ2GJXC
#\\\|QQQGMFFWFFGPZ2376VQXW7THCKZGU5KLRVAAHYFJF2FZQQBT3O6 \ / AMOS7 \ YOURUM ::
#\[7]HM6NQMSFZF7NKFIWYIXGNCNNKBL4TASQBAAV6BP6LRG2VIY2FWAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::


---

## audio zenka : spatial-purr standing-wave renderer [ 2026-07-26 ]

implemented data/tasks/audio-waveform-visualization.md : new `audio` zenka,
`audio.spatial-purr <abs-audio-path>` → PNG path under /var/protocol-7/audio/
[ zenka-chosen, 0775 dir / 0664 files per screenshot precedent ].

- modules : audio.init_code, audio.cmd.spatial-purr [ deferred ],
  audio.decode_to_pcm [ open3 + O_NONBLOCK + event.add_io, no blocking
  system() ], audio.handler.pcm_data [ drain, finalize at pcm EOF ],
  audio.handler.decode_timeout, audio.finalize_decode, and
  audio.render_standing_wave [ PURE perl core : PDL FFT + Imager, no p7
  paths, no purr keying — reusable primitive per
  AUDIO-VISUAL-THUMBNAIL-GENERALIZATION.md ].
- visuals : fixed palette [ indigo→royal→violet, pale lavender peaks ],
  concentric squares [ lows ] + lattice cells [ mids ] + speckle at
  intersections [ highs ], additive glow via gaussian-copy paste add,
  lit-pixel budget 2% est → ~5-9% measured, per-pass allowances ∝ band
  energies. tested on purring aa/ab/ac + saturnians.mp3 [ psytrance,
  generalization test ] — deterministic, distinct outputs.
- scaffold : configuration/zenki/audio/{start,zenka-startup.v7,source/,
  pm-dep/[+Imager,PDL,PDL__FFT],os-dep/binary/ffmpeg}, cube auth.zenki +
  access.zenki [ audio.spatial-purr in access.cmd.usr.* ],
  subroutines.load-early generated. ALL UNSIGNED — operator signs.

## incident : `v7.reload init` TORE DOWN the entire network [ again ]

issued to re-scan zenka-startup.v7 files ; re-running v7.init_code hit
the fatal init path [ ai-mem kimi topic-routing-mode-implementation.md
warned exactly this ] → v7 SIGTERMed everything. root restarted v7 on
pts/3 ~2min later ; fresh boot picked up the new zenka config fine.
lesson confirmed : NEVER `v7.reload init|all` on a live network to
register a new zenka — wait for a network restart instead. single-zenka
`audio.reload source` worked fine for module iteration.

#,,..,,..,,..,.,.,,.,,,..,...,,,.,.,,,.,.,,,,,...,...,...,...,..,,,,,,,..,...,
#T5FZ4X6KTG46LVFCVC2J3VYGQURYUIREU6EHFHRQ6KEOIXAMX5QERMK6RET4JADIGOXUTEHPYOMOA
#\\\|UHRIRAQXR3WDBPLWFEXZ2F234UNVF3FHTX5PEZ3PVRY72ZEL6OM \ / AMOS7 \ YOURUM ::
#\[7]DQIJOJZDIY6DTBAZ4HF3VV3I4EOI5OSHQXB22LNIKDRS5NGPRKDQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

## ncode pattern-learning phase 2 — scope-stack landed (2026-07-30)
part 0 status-gate in regex.apply + namespace scope-stack (scope_match /
file_to_namespace helpers, assess stack creation, cmd.apply out_of_scope_count,
ncode.cmd.widen-scope with streak-consuming widen + reset). verified live via
p7c incl. coding.eval-code for the p7c-unreachable regex.apply. details +
reusable verification notes: [topic-ncode-scope-stack-phase2.md](topic-ncode-scope-stack-phase2.md)

#,,,.,,.,,,.,,,,.,.,,,,,.,,,,,,,,,.,,,.,,,,..,..,,...,...,..,,...,...,,,.,,,,,
#CWFT43NITL25NDWK4JFS6PYUB4MIYTVVOOHFUYRMXU42Q775DAHRPQFF6IFCX7WCOO6GD53W5JG3O
#\\\|TS2EQ6AR6NCUB4H4ZYPGUTOZFONGODH3GT3MT6TQQLF7EEVWJJ2 \ / AMOS7 \ YOURUM ::
#\[7]HLLBPRMJRUFDCQQ2SJJO5XVFU6TXPYNW4HAGCH7TAHN72YKQXWCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
