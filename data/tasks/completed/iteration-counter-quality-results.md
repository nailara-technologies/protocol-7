# results: signature-footer iteration counter vs code quality

- date: 2026-08-04
- task: `data/tasks/iteration-counter-code-quality-correlation.md`

## verdict

**REJECTED-ON-CHECK.** The footer's harmonization iteration counter does
not correlate with code quality on real files, confirmed by three
independent blind measurements, a controlled within-file distortion test,
and a real pre/post `bin/format-code` reformatting check. It's a chaotic
function of the exact signed bytes (including the signing key), not of
anything semantic. Do not use it as a review-priority signal.

## mechanism recap: what the counter actually is

`source.create_harmonic_footer` starts `$iterations_left` at `07777777`
and decrements once per candidate footer until every truth assertion
passes (first header line, footer BMW checksum, both signature parts,
complete-file ELF checksum, individual footer lines). The stored
`amos-iterations-remaining` is the leftover count, so:

    iterations_taken = 0o7777777 - amos-iterations-remaining + 1

The per-iteration checks are checksum predicates over bytes that include
the counter itself, so the loop is a deterministic-but-chaotic search —
each candidate is effectively a fresh dice roll. Nothing in the loop
inspects code semantics.

## part 1 — extraction (all 5055 src/ files)

- Standalone Python decoder (`bin/test-scripts/sig-iter-cnt-style-chk/quality/extract_iterations.py`),
  cross-verified against the real `amos7.decode_octal_bit_header` logic
  and against `bin/dev/iter-rank` — exact match.
- All 5055 files decoded, 0 undecodable, 0 inverted-mode (all-zero)
  instances in the corpus.
- Distribution of iterations-taken: min 0, p10 2066, median 14144,
  p90 48118, p99 93594, max 178667 (of 2097151 possible), 4756 distinct
  values. Plausibly geometric-ish, no clustering.
- Data: `bin/test-scripts/sig-iter-cnt-style-chk/quality/iterations.tsv` (columns: taken, remaining, endline,
  path).

## part 2 — blind quality scoring

Two independent blind scorers plus one deterministic metric set. In all
cases the scorer never saw the iteration count — footers were stripped
from scoring copies (`bin/test-scripts/sig-iter-cnt-style-chk/study/scratch.tar.xz`) or the scorer was
instructed to treat the footer as opaque, and the count never appeared in
any prompt.

1. **Local 9B scorer** — same Qwen model the coding zenka uses, via direct
   inference calls, fixed rubric (style 0-4 / comments 0-3 / structure
   0-3). Stratified sample: 240 files, 40 per stratum across 6 log-spaced
   iteration-count strata (seed 13). 240/240 scored. Rubric grounded in
   `data/yaml/code-style/CONVENTIONS.yaml`.
   Scripts/data: `bin/test-scripts/sig-iter-cnt-style-chk/study/{score_batch.py,sample.tsv,scores.tsv}`.
2. **Kimi k2.7 scorer** — independent model, 5-criterion rubric, batches
   of 12. Stratified sample: 240 files, 30 per octile (seed 13). 168/240
   scored before the run was stopped (see "scoring dataset decision"
   below). Data: `bin/test-scripts/sig-iter-cnt-style-chk/quality/scores/`.
3. **Scripted style metrics** — deterministic, full corpus n=5055: header
   presence, 78-column violations, comment lowercase fraction, paren-style
   annotations, `s///`-form regexes, interpolated log format strings,
   unguarded data reads — composite 0-10.
   Data: `bin/test-scripts/sig-iter-cnt-style-chk/quality/{style_metrics.py,metrics.tsv}`.

### scoring dataset decision (stated explicitly per review)

The k2.7 second pass was abandoned at 168/240 (batches 00-13 of 20).
Rationale: at n=168 the replication is already adequately powered for the
effect sizes of interest (|rho| >= 0.22 detectable at 80% power), all
three measurements agree, and part 4 is the decisive test anyway. The
remaining 6 batch prompts are unused; `bin/test-scripts/sig-iter-cnt-style-chk/quality/batches/` documents
exactly which files went unscored.

## part 3 — correlation results (Spearman primary)

| measurement                            |    n | Spearman rho |     p |
|-----------------------------------------|-----:|-------------:|------:|
| 9B total score vs iterations-taken       |  240 |       +0.057 | 0.380 |
| 9B style subscale                        |  240 |       +0.142 | 0.028 |
| 9B comments subscale                     |  240 |       -0.014 | 0.826 |
| 9B structure subscale                    |  240 |       +0.121 | 0.062 |
| k2.7 total score (replication)           |  168 |       +0.033 | 0.676 |
| scripted composite (full corpus)         | 5055 |       +0.008 | 0.574 |
| iterations-taken vs file size (confound) | 5055 |       -0.002 | 0.865 |

t-stat for the headline number: 0.88 (matches the orchestrator's
independent recomputation: rho=0.057, n=240, t=0.88, not significant).

- The only nominal p < 0.05 (9B style subscale, +0.142) does not survive
  multiple-comparison correction (4 tests on the same data, Bonferroni
  alpha 0.0125) and is not replicated by k2.7 or the scripted metric.
  Treated as noise.
- Decile means of the 9B score across the iteration range show no trend:
  7.42, 8.38, 7.79, 7.88, 7.96, 8.75, 7.92, 8.00, 8.17, 8.46 (lowest to
  highest decile of iterations-taken).
- Scorer-agreement check was not meaningful: the two samples are
  near-disjoint (4 overlapping files). Noted as a limitation.
- 9B scorer caveat: coarse scale (score 7 given 106/240 times) attenuates
  any real correlation toward zero, but the k2.7 scorer (finer 5-25
  scale) and the deterministic metric both show the same null, so
  attenuation is not the explanation.

## part 4 — controlled distortion-injection test (decisive)

Two base files, re-signed on scratch copies with the temp key
(`bin/Protocol-7 sourcecode test-sign-and-verify`, one console invocation
per series so all variants share one key). Variants: realistic typo-class
bugs plus a comment-only control per series.

**Series v** (base `src/ncode.init_code`, 10 distortions):

| variant                              | iterations |   delta |
|---------------------------------------|-----------:|--------:|
| v00 reference                         |      22673 |      +0 |
| v01 wrong-threshold (0.70 -> 0.07)    |      17165 |   -5508 |
| v02 typo-data-key (patern_dir)        |      16133 |   -6540 |
| v03 inverted-match (`!~` -> `=~`)     |       4310 |  -18363 |
| v04 eq/ne swap                        |        346 |  -22327 |
| v05 if/unless inversion               |      46356 |  +23683 |
| v06 dropped `// 0` default            |       4690 |  -17983 |
| v07 wrong literal (5 -> 50)           |      19121 |   -3552 |
| v08 deleted statement                 |      13796 |   -8877 |
| v09 duplicated line                   |       5456 |  -17217 |
| v10 comment-only (control)            |      31344 |   +8671 |

**Series w** (base `src/coding.cmd.complete-analysis`, 4 distortions):

| variant                    | iterations |   delta |
|-----------------------------|-----------:|--------:|
| w00 reference                |      19772 |      +0 |
| w01 max_resumes 5 -> 6       |       7210 |  -12562 |
| w02 wrong variable           |      45122 |  +25350 |
| w03 dropped negation         |      30309 |  +10537 |
| w04 comment-only (control)   |       3749 |  -16023 |

Reading:

- Real bugs moved the count in both directions (9 down / 3 up across 12
  bug distortions) with swings up to ±25k — no consistent direction.
- Comment-only controls (zero semantic change) moved it just as much:
  +8671 and -16023. The counter cannot distinguish a bug from a comment
  edit — it tracks bytes, not meaning.
- Bonus finding: the count is also key/session-dependent. Identical body
  re-signed under different signing keys gives unrelated counts
  (`ncode.init_code`: 4637 in the corpus vs 22673 under the temp key; w00
  across invocations: 19444, 26471, 81601, 19772 — the console
  regenerates `test-proto7-sourcecode` per invocation). Absolute
  iteration counts are not even stable properties of a file's content.
- Variants: `bin/test-scripts/sig-iter-cnt-style-chk/study/sign-scratch/` (v00-v10, w00-w04).

## part 5 — real-transformation check: pre/post `bin/format-code` (added later)

Part 4 used synthetic typo-class bugs. This uses a real, meaningful,
mechanical transformation instead: running the current
comment-block-capable `bin/format-code` on files that haven't been
reformatted with it yet (670 of 5055 modules still `would reflow` under
`bin/format-code -c`). Unlike a typo, reformatting is unambiguously a
style-quality change in the project's own terms.

Method: stratified sample of 30 files (3 per decile of current iteration
count, seed 13) from the 670 reflow candidates. Each file copied to
`_before` and `_after`; `bin/format-code` run on `_after` only (confirmed
all 30 changed via diff); all 60 files re-signed with the temp key in one
console invocation (`bin/Protocol-7 sourcecode test-sign-and-verify`) so
every pair shares a key.

**Methodology note, kept visible rather than silently redone**: the first
two attempts at this both produced identical before/after footers despite
confirmed-different content — traced to reusing a stale
`test-proto7-sourcecode` temp key across successive invocations combined
with a 2-minute shell timeout truncating a 60-file batch mid-run, not a
bug in the signing tool itself. A clean 2-file test with a freshly
generated key produced correctly distinct checksums immediately; the full
30-pair batch was then re-run to completion in the background with a
fresh key and produced 60/60 valid, non-colliding signatures.

Results (`iterations` = iterations-taken under the shared temp key, not
comparable to the corpus's production-key values):

| file                                        |  before |   after |    delta |
|-----------------------------------------------|--------:|--------:|---------:|
| f01_plugin.web.jobs.cache.write                |    7960 |   43376 |  +35416 |
| f02_ffmpeg.frame_count_slow                    |   14220 |   47127 |  +32907 |
| f03_X-11.init_code                             |    2136 |   36645 |  +34509 |
| f04_base.ntime.B32_2_unix                      |   28101 |   10740 |  -17361 |
| f05_X-11.cmd.set_geometry                      |   18792 |    2246 |  -16546 |
| f06_universal.init_code                        |   30410 |   44285 |  +13875 |
| f07_context.pattern.extract_from_change        |   32012 |   16686 |  -15326 |
| f08_data.topology.interference.map.coord_to_subcube |  2681 |  9275 |   +6594 |
| f09_select.region.set_hover_cursor             |   58958 |   13614 |  -45344 |
| f10_context.review.consolidate                 |   28893 |   13508 |  -15385 |
| f11_v7.parent.attach_zenka_logs                |   17497 |   60694 |  +43197 |
| f12_cube-13.cmd.receive-entropy                |    6903 |   29127 |  +22224 |
| f13_protocol.protocol-7.link-upgrade.handshake |    1331 |     792 |    -539 |
| f14_coding.task.chunk_and_summarize            |    3423 |    2924 |    -499 |
| f15_window.place.handler.button_release        |   47170 |   21203 |  -25967 |
| f16_vision-batch.parent.fork_child             |    8746 |   37640 |  +28894 |
| f17_httpd.init_code                            |    6891 |    6851 |     -40 |
| f18_X-11.cmd.move-window                       |   14200 |   77740 |  +63540 |
| f19_decoder.cmd.show-d13-types                 |    6357 |   22279 |  +15922 |
| f20_zenki.console.attach-logs                  |   10623 |   44264 |  +33641 |
| f21_crypt.C25519.init_code                     |   28937 |   54737 |  +25800 |
| f22_ssh.handler.ssh_io                         |   13032 |   10229 |   -2803 |
| f23_index.tick.persist-cube                    |   42766 |   25147 |  -17619 |
| f24_data.cmd.mount-cube                        |   51963 |   23334 |  -28629 |
| f25_X-11.handler.global_hotkeys                |   19260 |   35435 |  +16175 |
| f26_cube.cmd.reply-encoding-mode               |    4746 |    3682 |   -1064 |
| f27_plnx.cmd.get_ticker                        |   16778 |   19342 |   +2564 |
| f28_bench.key-32-iterations                    |  130986 |    1583 | -129403 |
| f29_screen.setup.handler.geometry_reply        |    3579 |   20565 |  +16986 |
| f30_discover.cmd.list-orbital                  |    4208 |   29327 |  +25119 |

**n=30, 16 up / 14 down, sign test two-sided p=0.856** — indistinguishable
from a coin flip. Mean delta +3361 is not meaningful: stdev is 35016,
entirely driven by a handful of large swings in both directions
(+63540, -129403). A real, quality-relevant, mechanical transformation
moves the counter exactly as chaotically as synthetic typo injection did
in part 4. Fourth independent confirmation of the same null.

**Outliers checked separately, not just the average**: do the biggest
swings correlate with quality on either end? No, on three checks against
the pre-format scripted quality score (n=5055 corpus metric, so no
circularity with the LLM scorers):

| check                                              |    rho | t-stat |
|------------------------------------------------------|-------:|-------:|
| \|delta\| vs pre-format quality score                 | -0.096 |  -0.51 |
| \|delta\| vs diff size (mechanical control)            | +0.145 |    n/a |
| signed delta vs pre-format quality score              | -0.188 |  -1.01 |

Top-8 outliers by \|delta\| have a slightly lower mean score (6.09) than
the remaining 22 (6.75), Welch t=-1.18 — a faint lean in the "lower
quality -> bigger/more-positive swing" direction, but nowhere near
significant at n=30 (need \|t\|~2.05). Diff size doesn't explain the
outliers either, ruling out "big swings are just big edits" as the
boring alternative explanation. The outliers aren't hiding a signal on
either end — they're where the underlying checksum-search chaos happens
to land hardest, consistent with the mechanism already established.

Data: `bin/test-scripts/sig-iter-cnt-style-chk/quality/format-scratch/` (60 files, `_before`/`_after` pairs),
sample list in this task's reproduction notes.

## appendix — sorted iteration counts, full corpus

Part 1 asked for a plain sorted list before any scoring ran, as a sanity
check and a standalone artifact even independent of the correlation
result. Full sorted files: `bin/test-scripts/sig-iter-cnt-style-chk/quality/iterations-sorted-asc.tsv` and
`bin/test-scripts/sig-iter-cnt-style-chk/quality/iterations-sorted-desc.tsv` (5055 rows each, the 6-row
signature footer that `iterations.tsv` itself picked up as a committed
file filtered out). 30 from each end below — read this as "which files
took the fewest/most checksum-search iterations to sign," not as a
quality ranking; that's the whole point of this study.

**lowest 30 (fewest iterations)**

| iterations | file |
|-----------:|------|
|          0 | `src/base.stdio.transport.connect` |
|          5 | `src/base.prng.init_code` |
|         13 | `src/crypt.C25519.gen_keys` |
|         13 | `src/filter.cmd.mount_chain` |
|         16 | `src/power.save_config` |
|         17 | `src/plan-9.protocol.codec.encode-stat` |
|         19 | `src/plan-9.server` |
|         20 | `src/reasoning.tree.lookup` |
|         21 | `src/work.parent.init_code` |
|         26 | `src/models.chat.format_buffer` |
|         26 | `src/models.registry.list_by_context` |
|         32 | `src/web.cmd.process-template` |
|         35 | `src/devmod.cmd.echo` |
|         43 | `src/space.travel.tunnel` |
|         59 | `src/storchencam.init_code` |
|         62 | `src/base.stdio.frame.encode.pack_nibble` |
|         62 | `src/p7-log.anon.cmd.resolve-line` |
|         63 | `src/base.format.inline-nested.pre_init` |
|         73 | `src/httpd.pre_init` |
|         74 | `src/context.pattern.calculate_confidence` |
|         75 | `src/protocol.protocol-7.protocol-version-path-set-up` |
|         77 | `src/v7.setup_stdout_redir` |
|         79 | `src/v7.bin_p7r_comp_chksum` |
|         80 | `src/base.get_max_verbosity` |
|         93 | `src/memory.status.provider.rebuild_age` |
|         95 | `src/models.registry.populate_from_yaml` |
|         99 | `src/base.chk-sum.jha` |
|        101 | `src/X-11.cmd.keep_above` |
|        108 | `src/channels.memory-sync.fetch` |
|        111 | `src/letsencr.parent.install_certificate_to_httpsd` |

**highest 30 (most iterations)**

| iterations | file |
|-----------:|------|
|     178667 | `src/web.scan_content_directories` |
|     162407 | `src/base.file.basename` |
|     157651 | `src/httpd.handler.acme_challenge` |
|     156484 | `src/models.storage.adapter.invoke.repair` |
|     149478 | `src/keys.console.duplicate` |
|     136507 | `src/base.stream.push` |
|     131804 | `src/clients.https.handler.timeout` |
|     131203 | `src/v7.zenka.cmd.subname-sids` |
|     128669 | `src/coding.task.bury` |
|     127899 | `src/base.access.special-user-map` |
|     127115 | `src/protocol-7-menu.pointer-stream-init` |
|     124417 | `src/graphics-matrix.cmd.cursor` |
|     123240 | `src/coding.handler.model_path_reply` |
|     119213 | `src/letsencr.parent.save_certificate` |
|     117828 | `src/task.cmd.continue` |
|     114406 | `src/workspace-transfer.cmd.todo-commit` |
|     114397 | `src/models.cmd.test_discover` |
|     113066 | `src/system.process.handler.pid-instance_response` |
|     112732 | `src/coding.cmd.budget` |
|     111741 | `src/terminal.curses_ui.keybindings` |
|     109990 | `src/pdf.html.base.valid_pdf` |
|     108427 | `src/letsencr.parent.handler_httpd_reload_reply` |
|     108354 | `src/jobqueue.event.register_job_queues` |
|     108154 | `src/reasoning.branch.inject` |
|     105687 | `src/select.region.commit` |
|     105072 | `src/ssh.cmd.profile_enable` |
|     102349 | `src/X-11.cmd.dpms-status` |
|     101521 | `src/graphics.matrix.visual.cluster-center` |
|     101020 | `src/content.handler.weather_urls_reply` |
|     100583 | `src/p7-log.startup.repair_nul_gaps` |

Eyeballing both ends: no thematic clustering by subsystem, complexity, or
apparent quality on either side — `base.stdio.transport.connect` (0
iterations) and `base.file.basename` (162407 iterations, second-highest
in the corpus) are both plain, unremarkable utility modules. That's
exactly the "no signal" pattern the statistics above already established;
this list is here as the raw, inspectable artifact behind that claim, not
a fifth measurement.

## prior art (consistent)

Short-word level test (ledger: `topic-harmonic-correlation-ledger.md`,
REJECTED-ON-CHECK): LOVES=5 vs FRICTION=163 motivating anecdote failed
controlled comparison (FRIKTION -> 7, LOVSE converged faster than LOVES).
This file-level result closes the question for real files, which the
ledger entry explicitly left open.

## caveats / limitations

- Quality scorers are LLMs (9B local, k2.7); both are blind and
  independent of each other and of the counter, but LLM judgment of
  "quality" is itself noisy. The deterministic scripted metric (n=5055,
  full corpus) is the noise-free backstop and shows the strongest null of
  all.
- 9B scores are coarse-grained; see attenuation note above.
- The two LLM samples were drawn independently (different seeds /
  stratifications), so inter-scorer agreement could not be measured.
- Single-codebase result — says nothing about other signing loops.

## conclusion

The hypothesis **does not hold** — tier: REJECTED-ON-CHECK. Rejected
independently four ways now: the two earlier word-level tests, this
study's three blind quality measurements plus synthetic distortion test
(parts 2-4), and part 5's real-formatting check. The iteration counter is
a checksum-search artifact: chaotic in exact file bytes, session/key-
dependent, and insensitive to every dimension of code quality tested,
including an actual quality-improving transformation. `bin/dev/iter-rank`
remains useful for inspecting the footer field, but must not be read as a
quality ranking.

## reproduction

    # part 1
    python3 bin/test-scripts/sig-iter-cnt-style-chk/quality/extract_iterations.py modules
    # part 2 (9B scorer, needs local inference on :8000)
    python3 bin/test-scripts/sig-iter-cnt-style-chk/study/score_batch.py
    # part 3
    python3 bin/test-scripts/sig-iter-cnt-style-chk/quality/analyze.py
    # part 4 (one invocation per series -- key regenerates per run)
    bin/Protocol-7 sourcecode test-sign-and-verify "<space-separated paths>"

#,,..,...,.,,,.,.,...,..,,,.,,.,.,..,,,.,,.,,,..,,...,..,,..,,,,,,...,.,.,.,.,
#HV7FVJL76NYOGDUH73RASGBOYAKRBIIQTR3VCYRB7H46C7ZGEJHIIDLLIGKYQIYT6QRJ4TUK2XTNS
#\\\|DFJGZGWS2WHY5VHCL4MDLALQWTB7XOWSWV4C2RDH2RZO32GXSPW \ / AMOS7 \ YOURUM ::
#\[7]HSCELUON6OU6DHADPZIFPU4PFAQB5G2ZDPKKPF5RWUXPO2K23ADY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
