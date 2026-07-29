# dep-graph semantic embeddings — phase 1 results

date: 2026-07-29
task: data/tasks/dep-graph-semantic-embeddings.md [ tasks 1.1 + 1.2 ]

## what was built

### task 1.1 — corpus assembler : `bin/dev/depgraph-corpus`

- transforms `data/md/documentation/module-dependency-graph.asc`
  [ `source : callee ...` adjacency ] into fasttext skipgram training
  lines — one line per module : `source callee callee ...`
- reverse edges [ callee → callers ] emitted as separate lines at lower
  weight. fasttext has no per-line weights, so weight = line repetitions:
  forward lines ×2 [ `--forward-repeat` ], reverse lines ×1
  [ `--reverse-repeat` ]. reverse lines can be disabled with `--no-reverse`
- regeneration hook: `bin/dev/dep-graph` now calls
  `regenerate_depgraph_corpus()` after rewriting the full adjacency .asc
  [ not in `-module` filtered mode ]. failure warns, never breaks dep-graph
- output: `data/training/codebase-depgraph.txt`
  [ 3762 modules, 11540 edges, 10370 training lines ]

### task 1.2 — training

fasttext CLI was **not** installed on this host. built from source
[ facebookresearch/fastText, depth-1 clone, `make` ] into the isolated,
gitignored path `.deps/fasttext/` — binary at `.deps/fasttext/fasttext`.
rebuild: `cd .deps/fasttext/src && make && cp fasttext ..`

**update (2026-07-29)**: debian ships a `fasttext` package [ 0.9.2+ds-9+b1 ]
providing the CLI directly — added as the `embeddings` profile in
`.deps/profiles.yaml` (`bin/p7-deps`). prefer `fasttext` from PATH once
installed; the source build above is a fallback only.

trained with the exact task parameters:

```
.deps/fasttext/fasttext skipgram \
    -input data/training/codebase-depgraph.txt \
    -output data/embeddings/codebase-depgraph \
    -epoch 100 -dim 300 -minn 3 -maxn 6 -wordNgrams 2
```

- vocab: 3092 words, dim 300, ~13s training time, final avg.loss 0.503
- outputs: `data/embeddings/codebase-depgraph.bin` [ 2.3 GB, gitignored ]
  and `codebase-depgraph.vec` [ 7.7 MB, text vectors ]
- note: the 2.3 GB .bin is dominated by the 2M-bucket subword matrix
  [ minn 3 / maxn 6 ]. if size matters, retrain with `-bucket 200000`
  or `fasttext quantize` — vocabulary itself is tiny

## verification — spot queries

### `base.log` [ nn 15 ]

```
base.logs                          0.614
base.logt                          0.592
base.log-delayed                   0.553
base.log.format_entry              0.446   <- direct callee
base.load_modules                  0.433
base.log.send-buffer.init          0.418
base.load_runtime_modules          0.417
base.load_values                   0.413
base.log.send-buffer.send-idle-callback  0.410
base.load_config                   0.405
content.update_hidden              0.394
base.exit                          0.390
base.log.send-buffer.idle-callback-set   0.388
base.log.send-buffer.add-queue     0.385
base.locales.load_file             0.372
```

direct callees from .asc : `v7.stdout_log.write base.utf8.clean_str
base.buffer.add_line base.log.format_entry base.code.call_expected`

**result: logging-adjacent clustering confirmed** [ base.logs, base.logt,
base.log-delayed, base.log.send-buffer.*, base.log.format_entry ].
**direct-callee coverage is weak**: only 1 of 5 callees appears even in
nn 60. cause: base.log is the largest hub in the graph [ thousands of
callers ], so its vector is dominated by calling context — it behaves as
"the logging primitive" rather than as its own small callee set. this is
expected skipgram behavior for hub nodes, not a pipeline defect. if
callee fidelity for hubs matters, lower `--reverse-repeat` or exclude
ultra-hub nodes from reverse lines.

### `data.get.resolve_virtual` [ nn 15 ]

```
data.get.resolve_physical          0.991
data.get.resolve_plugin            0.976
data.get.resolve_interference      0.943
data.get                           0.923
data.get.validate_path_security    0.915
data.get.classify_path             0.901
data.get.path_to_module            0.888
data.resolve_hash_path             0.860
data.init_holographic              0.827
data.init_holographic.calculate_magnetic_trajectory  0.804
data.list_entries                  0.762
zenki.parent.resolve_dependencies  0.737
base.resolve_key                   0.733
data.cmd.attach-fs-mount           0.730
p7-log.anon.cmd.resolve            0.729
```

**result: fully confirmed.** resolve_* cluster [ physical, plugin,
interference ] + classify_path + cross-namespace resolve modules
[ base.resolve_key, zenki.parent.resolve_dependencies ] exactly as
specified. subword sharing [ minn 3 / maxn 6 ] reinforces the
`data.get.*` prefix family as designed.

## caveats / follow-ups

- `bin/dev/depgraph-corpus` and the `bin/dev/dep-graph` hook have **no
  AMOS7 signature footer** — signatures are added at commit time by the
  vc tooling; editing dep-graph also invalidates its current footer
- regenerating the .asc removed its trailing AMOS7 signature block
  [ regenerated output has none; restored at next signed commit ]
- `data/training/` corpus [ 1 MB ] and `.vec` [ 7.7 MB ] are
  committable; `.bin` [ 2.3 GB ] and `.deps/fasttext/` are gitignored
- reverse-edge weighting via repetition is a coarse proxy; the hub-node
  finding above is the knob to tune in phase 2 if semantic-load needs
  callee-precise hubs

#,,.,,.,.,,.,,.,,,..,,,,,,,,.,.,.,...,.,,,...,..,,...,...,..,,,..,.,,,,.,,..,,
#XB3EPT6SSW7R5A7NZSU375DFGBORU4WP2GL2CBISGCTM6WH36EF7BEHOKWA3N6ILXPPHW4YWGBUTI
#\\\|S2MH3MTYL5K5I3H4CYVSR52EJD36QUL24VE6LTAMUFMN2IRKUHF \ / AMOS7 \ YOURUM ::
#\[7]P27UGFSZFP4WYNBCY4L7NBRPCMA2F74GH2RPMSEKRQ4SC5ZKVYCQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
