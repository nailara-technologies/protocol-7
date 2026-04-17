# task: index grid data endpoint for space.v7.ax

## why

this implements sub-component 5.1 from
`data/md/design/SEARCHABLE-INDEX-SESSION-STATE.md` — the first
actionable slice of the searchable checksum-indexed dataspace. it is
intentionally small: expose a checksum-derived namespace grid as json
from an existing working template pipeline, and render one view.

this slice unblocks future work because:
- it validates that `modules/index.gen_path` produces coherent
  coordinates when applied to real files
- it gives the visualization layer real data to iterate on
- it establishes the .tmpl + plugin pattern for future indexer
  endpoints [ e.g. search results, cluster views ]

read section 5.1 of the session state document before starting.

## what already exists — the pattern to follow

`space.v7.ax` is a working template-rendered vhost. two templates serve
two endpoints via the same plugin:

- `/var/httpd/space.v7.ax/index.tmpl` — html overlay, renders
  `<[plugin.web.space.state:summary]>` and embeds json via
  `<[plugin.web.space.state:json]>`
- `/var/httpd/space.v7.ax/state.tmpl` — json api endpoint using
  `<[web.response.content_type:application/json]>` prefix to override
  mime type, then emits `<[plugin.web.space.state:json-raw]>`

the data pipeline:

- `modules/plugin.web.space.init_code` — sets up `<web.space.cache>`
  and `<web.space.cfg.data_source>`
- `modules/plugin.web.space.fetch` — async queries to graphics-matrix zenka
- `modules/plugin.web.space.handler.state_reply` — receives async replies,
  populates cache
- `modules/plugin.web.space.state` — template command, returns html /
  json / json-raw based on section argument

**this task reuses the same pattern for a new `grid` data source** — do
not invent a new pattern. mimic `plugin.web.space.state` closely.

## what to build

### new modules

all under `modules/plugin.web.space.grid.*`:

1. **`modules/plugin.web.space.grid.init_code`**
   - sets up `<web.space.grid.cache>` hash [ mirror `<web.space.cache>` shape ]
   - sets `<web.space.grid.cfg.target_dir>` default [ propose
     `data/md/design` as the starting test target — small, bounded, real ]
   - sets `<web.space.grid.cfg.ttl>` [ e.g. 60 seconds ]

2. **`modules/plugin.web.space.grid.scan`**
   - walks the configured target directory [ use `File::Find` or
     recursive opendir — check for existing idiom in codebase first ]
   - for each file, compute checksum seed [ start simple: absolute path
     as seed ] and call `<[index.gen_path]>->(\$seed)`
   - returns / populates cache with an arrayref of cell entries:

     ```
     [
       {
         'path'        => '/absolute/path/to/file',
         'rel_path'    => 'data/md/design/foo.md',
         'gen_path'    => 'K2N4/V7XQ/...',  # from index.gen_path
         'size'        => 1234,
         'mtime'       => 1712345678,
       },
       ...
     ]
     ```

   - top level of cache hash should include:
     - `target_dir` — string
     - `file_count` — integer
     - `cells` — arrayref of above
     - `timestamp` — epoch when scan completed

3. **`modules/plugin.web.space.grid`**
   - template command [ mirror `plugin.web.space.state` closely ]
   - accepts a section argument, defaults to `summary`
   - sections:
     - `summary` — html fragment showing target_dir, file_count,
       timestamp / cache_age. style-match the existing summary
       in `plugin.web.space.state`: `.space-state`, `.state-row`,
       `.label`, `.value`.
     - `json` — wrapped in `<script>window.spaceGrid = {...};</script>`
       for inline js consumption
     - `json-raw` — raw json for api endpoints
   - handles the case where `<web.space.grid.cache>` is empty [ return
     placeholder with cells=[] and file_count=0 ]
   - on read with stale cache [ age > ttl ], trigger a re-scan
     [ synchronous is fine — scanning `data/md/design` is a few hundred
     files at most, quick ]

   important: keep this file a single callable subroutine like
   `plugin.web.space.state`. do NOT wrap in `sub { ... }`.

### new template

`/var/httpd/space.v7.ax/grid.json.tmpl`:

```
<[web.response.content_type:application/json]><[plugin.web.space.grid:json-raw]>
```

this matches `state.tmpl` exactly. the `grid.json` extension mapping
should route through the template processor because `.tmpl` files are
already matched by `httpd.serve_static` and `httpd.http_head` [ verified
during the apr 16-17 work ].

### update existing template

add a grid view to `/var/httpd/space.v7.ax/index.tmpl`:

- include `<[plugin.web.space.grid:summary]>` below the existing
  `<[plugin.web.space.state:summary]>` section
- include `<[plugin.web.space.grid:json]>` before the closing body tag
  alongside the existing json embed
- add a `<div id="grid-view"></div>` container
- add a small inline `<script>` that reads `window.spaceGrid` and
  renders cells as a simple html grid or tree [ your choice — either
  works, just needs to be visible and readable ]

keep the styling consistent with the existing overlay [ same colors:
`#0a0412`, `#7080c0`, `#4030a0`, monospace font ]. no new stylesheets.
dom manipulation can be vanilla js, no frameworks.

## style rules — MUST follow

1. **no `sub { ... }` wrappers** — the filename IS the subroutine. the
   existing kimi-generated `plugin.storage.checksum.*` modules have
   this wrong — do not copy that pattern. mimic
   `modules/plugin.web.space.state` instead, which is correctly styled.

2. **use `$ARG` not `$_`** in `map` and `grep` — the local llm regresses
   this after compaction, don't you start.

3. **lowercase comments** — `## fetch cache ##` not `## Fetch Cache ##`

4. **bracket annotations** — `[ word ]` not `( word )` in comments

5. **qw| word | style** for barewords where the existing codebase uses it

6. **no signature stub lines** — do not add `#,,.,,,...` ending lines to
   new files. leave clean, let the signing system add real footers later.

7. **module invocation syntax** — `<[module.name]>->($arg)` — the `]>`
   closes before `->`, not `<[module.name]->($arg)`

## acceptance criteria

1. `ptd -c` passes for all 3 new modules
2. `p7c web.reload` [ or equivalent — check start file commands list ]
   reloads the web zenka without errors
3. HTTP GET to `http://space.v7.ax/grid.json` returns valid json with
   the expected shape [ `target_dir`, `file_count`, `cells`, `timestamp` ]
4. HTTP GET to `http://space.v7.ax/` renders the existing overlay
   PLUS a visible grid view showing at least the file count and some
   cell coordinates
5. the grid view is readable — each cell should show at minimum the
   relative path and the gen_path coordinate tuple
6. repeated requests within the ttl window reuse the cache [ same
   timestamp ], after ttl expires the next request triggers re-scan
7. no `$_` usage in any of the new modules
8. no `sub { ... }` wrappers in any of the new modules

## verification steps

before marking complete:

1. `ptd -c modules/plugin.web.space.grid.init_code`
2. `ptd -c modules/plugin.web.space.grid.scan`
3. `ptd -c modules/plugin.web.space.grid`
4. grep for `\$_` in the three new modules — should return nothing
5. grep for `^return sub` in the three new modules — should return nothing
6. test the endpoint: `curl -s http://space.v7.ax/grid.json | head -100`
7. test the html view: `curl -s http://space.v7.ax/ | grep -iE 'grid|cells'`

## not in scope

- do NOT implement content-hash as the seed [ use absolute path string
  for phase 1; content-hash is a follow-up when we wire in
  `base.chk-sum.bmw.filesum` or similar ]
- do NOT implement search / query functionality [ that is 5.4 ]
- do NOT implement deduplication detection [ that is 5.5 ]
- do NOT touch `modules/index.*` [ the existing infrastructure stays
  as-is; this task only consumes `index.gen_path` via `<[...]>` ]
- do NOT write a full filesystem crawler — scanning a single small
  target directory is enough to prove the pipeline
- do NOT create a search zenka or indexer zenka — this is a web plugin
  task, nothing more

## references

- session state doc: `data/md/design/SEARCHABLE-INDEX-SESSION-STATE.md`
  [ section 5.1 is the direct spec for this task ]
- existing plugin reference: `modules/plugin.web.space.state`
  [ correct style, exact pattern to mimic ]
- existing template reference: `/var/httpd/space.v7.ax/state.tmpl`
  [ pattern for json endpoint with content-type override ]
- the primitive: `modules/index.gen_path` [ produces the coordinate
  tuple from any string or scalar ref ]

#,,,,,,,,,,..,.,,,...,.,.,.,,,,.,,,..,...,.,.,..,,...,.,,,,.,,,..,...,.,,,,,.,
#NR5I7OBN4J4CGAAEPRDX6OZMXKTF4NC2QQNGYOVWPI2JXJ6H5OVAHW6EWEGLMUOWIHZ5GVEGLFTVW
#\\\|4KOLC7Z74C674WBTVDYBKEY5YKV7K6MQGICCAZS7J7CERFUTKNI \ / AMOS7 \ YOURUM ::
#\[7]NJ7AZSRW7SPA65R7M26OPCZ25GRH3UC4NXSSNC5KDPTQDFTDRSDA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
