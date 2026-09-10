# PROGRESS — src-review iteration task

task file : data/tasks/coding-src-review-iteration.md
started   : 2026-09-09

## built so far [ all unsigned by design — human signs separately ]

- `bin/dev/src-review-priority` — worklist builder, reverse-edge caller-count
  ranking from module-dependency-graph.asc [ parse adapted from
  depgraph-corpus ]. outputs: data/src-review/worklist.txt [5470 items],
  caller-counts.asc. VERIFIED: top-10 matches manual one-liner computation.
- `bin/dev/worklist-iterate` — GENERIC resumable/idempotent worklist walker
  [ cursor + hash-keyed done-set + failed-set, atomic done-writes ].
  VERIFIED with synthetic worklists: skip-on-rerun, hash-change reprocess of
  only changed item, failure recording + retry, kill -TERM mid-flight ->
  done-set only contains completed items, resume redoes in-flight item.
  [ note: in-flight item side-effects can land after kill -> per-item
  commands must write atomically; src-review-one does tmp+rename ]
- `bin/dev/src-review-one` — per-module review generator. deterministic
  grounding via p7c coding.call-tool [ module_convention_check +
  validate_module ], one local inference call [ 127.0.0.1:8000,
  Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M, reasoning_effort=low ], atomic
  markdown record with honest frontmatter [ llm-generated, NOT
  hand-verified, timestamp, model-id, source sha1, caller count + dep-graph
  blindspot caveat ]. VERIFIED on base.log: 17s, sane review content.

## environment facts [ rediscovered, may rot ]

- p7c uses DOT notation: `p7c coding.call-tool <tool> '<json>'`
  [ space form returns "command does not exist" ]
- validate_module wants nested args: {"function":{"arguments":{"module":..}}}
- http_proxy env var breaks 127.0.0.1 curl -> always `curl --noproxy '*'`
- inference server: ik_llama.cpp llama-server-cuda-fa on 127.0.0.1:8000
  [ spawned by coding zenka, model OFSQC4I:QDBKEXY ]

## current step

- first real batch RUNNING [ resumed after kill test ]: top 75 modules by
  caller count, background task. 15/75 done at resume point.

## kill/resume test [ REAL batch, not synthetic ] — DONE

- started batch, let 10 modules complete, killed via SIGTERM mid-item-11
  [ background task bash-0uxzriuc, exit -15 ].
- post-kill state: 10 done markers, 11 review files [ incl. manual base.log
  test ], no orphan processes, one stale .req.<pid>.json request-body tmp
  [ fixed: src-review-one now cleans stale .req.* at startup ].
- restart with --limit 5: exactly 10 skipped [ already current ], items
  11-15 processed. RESUME VERIFIED on the real pipeline.

## DONE [ 2026-09-09 ]

- batch complete: 93 modules reviewed [ top 90 by caller count + 3 from
  a --limit verification run ], 0 failures, ~16s/module avg.
- final idempotency verified: reruns skip all current items; corrupted
  done-marker hash -> exactly that module re-reviewed.
- spot-checks: base.log, base.logs [ claims match verbatim check output
  AND live re-run of the check ], crypt.C25519.gen_keys [ concrete,
  checkable observations ].
- no signature stubs on any new file [ verified by grep ].
- results section appended to data/tasks/coding-src-review-iteration.md.

## round 2 [ 2026-09-09 evening ] — DONE

- main run --limit 200 : 167 done, 33 failed [ transient inference
  bursts, rc 1792 / rc 13312 ], 69 skipped. ~24 of the 167 were
  re-reviews of round-1 modules changed on disk [ hash-keyed redo ].
- cleanup rerun --limit 40 : 40 done, 0 failed [ all 33 failures
  recovered + 7 fresh ].
- totals : 183 new modules this round, 276 / 5470 overall, 0 failures
  outstanding. idempotent skip re-confirmed.

#,,..,,.,,.,,,..,,,,,,.,,,...,,.,,.,,,...,,,,,..,,...,...,,,,,,.,,,..,,,.,..,,
#62BUF6LG5RRGAHQXOUWNTDTJOT2JUV6Q6TINLR6AXARM5IDR5NY4YXVF237ZCTESYIWQZSESTWBD6
#\\\|RQXUKIUJ4HYAVU7XH2ULZL3FMXLU756IFKHSDXVMJCO4VHPD7DX \ / AMOS7 \ YOURUM ::
#\[7]FSNCJREVDNNQQ3STFIWG67GD6UR5U4AJ65QU5DABM43ZRYEH2ADQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
