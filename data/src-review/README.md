# data/src-review — per-module review corpus

generated corpus of per-module review records for `src/` modules.
**every record is LLM-generated and NOT hand-verified** — a generated
draft grounded in deterministic check output, not documentation fact.
each record's frontmatter says this explicitly, with timestamp, model id
and source content hash, so staleness is detectable [ hash mismatch =
module changed since review ].

## layout

- `<module.name>/review.md` — one review record per module [ markdown,
  YAML-ish frontmatter ], nested under a directory named for the module
  [ changed 2026-09-10 from a flat `<module.name>.md`, to leave room for
  future sibling artifacts per module -- disentangled history, usage
  examples, etc. -- without renaming the review itself ]. sections: LLM
  narrative review [ Purpose / Interface / Role & dependencies /
  Observations / Confidence ], then the verbatim deterministic check
  outputs the narrative was grounded in.
- `<module.name>/history` — the first such sibling artifact, added
  2026-09-10 by consolidating a separately-built `data/src-history/`
  tree in here (see `data/tasks/coding-history-disentanglement.md`):
  per-module git history with bulk/mechanical commits (signing passes,
  renames, line-length remediation) filtered into a separate flagged
  section rather than dropped. built by `bin/dev/git-history-
  disentangle`, independent of the review pipeline — not every module
  with a `history` file has a `review.md` yet, and vice versa.
- `worklist.txt` — all `src/` modules ranked by dep-graph caller count
  [ descending ] ; rebuilt by `bin/dev/src-review-priority`.
- `caller-counts.asc` — `module : caller_count` reference data.
- `worklist.txt.state/` — iterator state [ done-set keyed by content
  hash, failed-set, cursor, iterate.log ]. delete to force full re-walk.
- `PROGRESS.md` — session checkpoint notes for the task that built this.

## pipeline

1. `bin/dev/src-review-priority` — ranks modules by caller count
   [ reverse-edge in-degree from
   `data/md/documentation/module-dependency-graph.asc`, parse adapted
   from `bin/dev/depgraph-corpus` ].
2. `bin/dev/worklist-iterate --worklist data/src-review/worklist.txt \
      --cmd bin/dev/src-review-one --hash-cmd 'sha1sum src/{}' \
      --limit <N>` — generic resumable/idempotent walker. safe to kill
   and re-run at any point; already-reviewed modules with unchanged
   content are skipped, changed modules are re-reviewed.
3. `bin/dev/src-review-one <module>` — per-item command: deterministic
   checks via the coding zenka [ `module_convention_check`,
   `validate_module` ], one inference call against the local
   ik_llama.cpp server [ `127.0.0.1:8000` ], atomic record write.

## known limitations

- caller counts come from the static dep-graph: conditional/dynamic
  dispatch is invisible to it [ see
  `data/ai-mem/claude/project-depgraph-conditional-calls-blindspot.md` ].
- source is truncated at 14000 chars in the prompt; reviews of larger
  modules are based on a prefix.
- review quality/prompt design is v1 [ `prompt_version: src-review-v1`
  in each record ] — deliberately not over-invested; refine the prompt
  and bump the version to re-generate.

#,,.,,.,.,..,,,.,,,..,,..,,.,,,.,,,..,,..,,.,,..,,...,,..,,.,,...,..,,,..,,.,,
#UNGRQ3VPGDFD3SHZEBCPQM5HOUDVUYORV63C5PWLMKW5Q3SLKP2QXJHJSXLM2GTVMNGZQUHGNXXIQ
#\\\|WSBACDW7YB6HQPUJVYTCCOJX35OT2RD6A2KMDNAMQ4SV5GOOJ3E \ / AMOS7 \ YOURUM ::
#\[7]P4SE6JRT5AVIHHI2LWTYK54QYJ2BHRHME2AB7QMN6OM4O5K6LEDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
