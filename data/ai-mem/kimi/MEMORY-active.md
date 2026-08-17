# Kimi Development Memory — Active (Protocol-7)

> in-flight / recently-landed work entries moved out of `MEMORY.md` to keep the auto-loaded index
> slim. links remain valid.

## todo zenka — styled detail editor + show command (2026-08-16)

`bin/todo` gained a `details <id>` command and a `show <id>` command.
- items now carry a `details` free-text field; new items initialize it to `''`.
- `show <id>` renders item metadata plus details inside AMOS7::TERM frames
  and colon-prefixed content lines [ matching amos-chksum / amos-data-pager ].
- `details <id>` opens a custom full-screen editor built with `Term::ReadKey`
  and AMOS7::TERM styling — no external `$EDITOR` / vi. chrome uses the
  ascii-frame visual language [ `.:[ title ]:.....:.`, `:..[ details ].....:`,
  `:..[ keys ].....:`, `:...................:` ]. the cursor line is marked
  by single `:   :` borders drawn in bold TRUE-blue (same as the details
  text) for clear highlighting; arrows / enter / backspace / delete edit the
  buffer; ctrl-o saves,
  ctrl-c aborts, ctrl-x saves & quits, ctrl-w deletes the previous word,
  ctrl-l deletes the current line. abort clears the screen before returning.
  escape sequences are assembled by `read_editor_key` because `Term::ReadKey`
  in raw mode returns arrow keys as individual bytes; bottom border is printed
  without a trailing newline to avoid scrolling the header off-screen.
  title and help lines are right-aligned with a 2-space right pad.
  the task title and entered details text use the same bold TRUE-blue color as
  the `.: todo details :.` header. the hardware cursor is hidden during frame
  redraws (`\e[?25l`) and shown only at the final edit position (`\e[?25h`) to
  prevent flicker at the home position. the terminal cursor is set to a steady
  underscore (`\e[4 q`) while editing, reset to default (`\e[0 q`) on exit.
  input is read with `sysread()` and the main loop blocks in `select()` on
  `STDIN` plus a self-pipe; `SIGWINCH` and `SIGINT` handlers write to the pipe
  to wake `select()`, giving event-driven resize/abort handling without polling.
  a resize triggers a full redraw so narrowing the window no longer leaves
  stale wide lines on screen.
- the help line truncates from the right when the terminal is narrow; the
  `saved` indicator from `ctrl-o` is prepended on the left so it stays visible.
- after a successful `ctrl-x` the screen is cleared and a status line is printed
  using the live terminal width (`.:[ saved ]:.` if details changed,
  `.:[ unchanged ]:.` if not), avoiding the stale startup `$TERM_WIDTH`.
- abort (`ctrl-c`) clears the screen and leaves the cursor at the home position
  (`1,1`) for the shell prompt.
- `ctrl-l` deletes the current line.
- free-cursor movement: pressing right at the end of a line adds spaces; pressing
  down at EOF inserts a new line padded to the current column; moving to another
  line strips trailing spaces from the line being left; saving strips trailing
  spaces from every line and removes trailing empty lines. this makes aligning
  ascii art and tables easier.
- `details <id> <text>` also works non-interactively for scripts.
- the list view appends a `◆` marker after tags when an item has non-empty
  details. tested `show`, non-interactive `details`, interactive editor via
  `expect`, and list indicator.

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

## MCP session_catchup + Self-Test Verification (June 2026)

MCP timeout bumped, `session_catchup` now does direct UUID/prefix lookup and supports `tail_chars` for large sessions. Coding self-test tier-0/1/2 verified live; tier-1 retry confirmed on DVEAZIA:GPAKBLA.
see [2026-06-21-session-catchup-mcp-and-self-test-verification.md](2026-06-21-session-catchup-mcp-and-self-test-verification.md)

July 2026: `session_catchup` gained subagent transcript support for claude + kimi via `subagents` param (0=exclude, 1=append, 2=only), `subagent_id` filter, and claude `scratchpad` param for volatile /tmp artifacts; new `scratchpad_import` tool imports them to `data/scratchpad/<bmw-L13-of-session-tmp-path>/`; list mode shows `[+N sub]`/`[+N scr]` markers.
see [2026-07-18-session-catchup-subagent-support.md](2026-07-18-session-catchup-subagent-support.md)

July 2026: coding zenka got native scratchpad-rescue tools (`scratchpad_list_all` / `scratchpad_categorize` / `scratchpad_rescue` + hourly `coding.handler.scratchpad_sweep` timer) — same capability without any external LLM. imports go through the chmod child [ taeki-owned ]; mcp-server-p7 grants scoped group read on /tmp scratchpad dirs opportunistically.
see [2026-07-19-coding-zenka-scratchpad-rescue-tools.md](2026-07-19-coding-zenka-scratchpad-rescue-tools.md)

## bin/chat — Multi-Model Conversation Script (May 14 2026)

phase 1 operational (~950 lines); file-backed history at `data/development/chat/channel/*/history`; `data/ai-mem/handover.txt` retired.
open: kimi zenka state machine upgrade (backend reconnect), coding zenka as third dispatch target, phase 2 channels zenka.

## Jobsite/Web Jobs Pipeline Fixes (2026-06-28)

`skipped` status restored across all index scanners, reassessment now protects manual stages, web sync carries `assertions`, UI delete actions wired, and orbital subscriber `.cmd.` syntax corrected. Assessed jobs now map to the `review` UI stage. See [jobs-pipeline-2026-06-28.md](jobs-pipeline-2026-06-28.md). Open: bulk-delete pending search/filter UI.

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

## amos-term interaction prototype + SHM fixes — landed (2026-08-04)

ask_user_stream buffer-lifecycle design resolved (dedicated named buffer,
no window handle needed); prototype modules live + verified headless. Two
real SHM bugs fixed in amos-term.buffer-create affecting ALL SHM consumers,
not just this feature (whole-scalar assign was detaching the Sys::Mmap
mapping; voxel data wasn't offset past the 512-byte header). Committed
`5d85fd319`. details: [topic-amos-term-interaction-prototype.md](topic-amos-term-interaction-prototype.md)

## source.extract_sig_body over-long fake-footer bypass — fixed (2026-08-02)

95+ char fake-footer lines bypassed every strip regex incl. the real-signature
start marker (`{70,85}` ceilings) → never stripped. fix: open `{70,}` minimums
across all footer regexes (marker tokens carry confidence) + caller persists
in-memory stub strips. live-verified via sourcecode console zenka. LANDED `2528fb353`.
details + reusable verification notes: [topic-extract-sig-body-overlong-fake-footer.md](topic-extract-sig-body-overlong-fake-footer.md)

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

## ncode pattern-learning phase 2 — scope-stack landed (2026-07-30)

part 0 status-gate in regex.apply + namespace scope-stack (scope_match /
file_to_namespace helpers, assess stack creation, cmd.apply out_of_scope_count,
ncode.cmd.widen-scope with streak-consuming widen + reset). verified live via
p7c incl. coding.eval-code for the p7c-unreachable regex.apply. details +
reusable verification notes: [topic-ncode-scope-stack-phase2.md](topic-ncode-scope-stack-phase2.md)

## ascii.frame cursor marker in live field values — WORKS (2026-08-10)

phase-2 open question resolved: inserting a `|` cursor marker [ + `[..]`
focus brackets ] into the active field's value before ascii.frame.render
does NOT break alignment. hand-traced modules/ascii.frame.render: the
same `length($value)` feeds BOTH the required_width computation and the
render-time fill_width padding, so the extra chars cancel out and every
row still pads to the same frame_width. do NOT strip the marker from
width accounting — fill_width would clamp at 0 and the row overflows the
right border by the marker count. only caveat: total frame width can
shift by up to +3 cols [ 2 brackets + 1 marker ] across focus changes
when the active row is/becomes the widest row — cosmetic jitter, safe to
accept for the interactive loop. implemented in
modules/editor.ui.ascii_frame.render_form [ + render_field wrapper,
fixture data/yaml/ascii-frames/user-edit-test-form.yaml ], unsigned.

## user-edit vertical viewport + one-line flicker fix (2026-08-16)

`modules/user-edit.form.render` now slices tall forms to the terminal height and keeps
the active field visible. terminal size is cached in `user-edit.setup_stdin_watcher` and
refreshed on `SIGWINCH` via new `user-edit.handler.term_resize`. a bare trailing `\n`
after the rendered frame was causing a one-line scroll when the frame exactly filled the
screen; the newline is now only emitted when the help block is visible. when the header
scrolls out of view, one empty content row is kept as top padding so fields do not sit
flush against the terminal top. see [topic-user-edit-vertical-viewport.md](topic-user-edit-vertical-viewport.md)

#,,..,,,,,.,,,,,,,,,.,.,,,.,,,.,.,.,,,...,..,,..,,...,...,..,,.,.,..,,,.,,.,,,
#73Y7OI4FVO5IXFDGNOLSLCXGJUIUYTQXJYOE5N2A3VK53RP5GGPPPY2BAGQHIAVVLMMYLOWB3B2JC
#\\\|F332GWD2WFVIVY7XPUEFURSUEZOQJ2XLGNNQ27KALOPD4GDT3K2 \ / AMOS7 \ YOURUM ::
#\[7]PS4TCPLLNHYSUN3NVKMT2PUE2DKRIFJWT4YASUDQ2UYFQ27SMEAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
