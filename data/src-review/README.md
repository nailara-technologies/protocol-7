# data/src-review — per-module review corpus

generated corpus of per-module review records for `src/` modules.
**every record is LLM-generated and NOT hand-verified** — a generated
draft grounded in deterministic check output, not documentation fact.
each record's frontmatter says this explicitly, with timestamp, model id
and source content hash, so staleness is detectable [ hash mismatch =
module changed since review ].

## layout

- `<module.name>.md` — one review record per module [ markdown, YAML-ish
  frontmatter ]. sections: LLM narrative review [ Purpose / Interface /
  Role & dependencies / Observations / Confidence ], then the verbatim
  deterministic check outputs the narrative was grounded in.
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

#,,.,,,..,...,,,.,.,.,..,,,,.,..,,...,...,..,,..,,...,..,,...,.,.,,,,,.,.,,..,
#QPK5WB4M6EZQBEVPCYCKS7BM5TVLZ3GA67XX7QHYD3XKC44I34TSW22I6UVU4RBFVLHEAHH6AG626
#\\\|3KQ4GA2UF4EZNH24JGF52YKDGG6WG7SUBRBODHASUAAIGJLTVS5 \ / AMOS7 \ YOURUM ::
#\[7]VFDVPM4CLIVNEY6S7TMVQHQWICWLYYF4BNCVVLAGPQ2WN7T2QACY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
