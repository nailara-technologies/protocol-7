# dep-graph output format design

## context

`bin/dev/dep-graph` is a static dependency graph tool for the protocol-7 module
system. it scans `modules/` for `<[module.name]>->()` call patterns, builds a
weighted adjacency graph, and writes it to disk for reference and tooling.

the current full-graph text output has a significant problem : it is a
**non-deduplicated expanded tree**, not an adjacency list. every root module
gets its own full subtree re-expansion, so shared dependencies like `base.log`
and `base.logs` appear thousands of times. the result is 205,908 lines / 8.5M
of text that compresses to 65K with xz — the compression ratio itself
demonstrates how much redundancy is present.

## current format

the current `generate_text_output` format looks like this :

```
:001: net.get
  --> :002: base.log
    --> :001: v7.stdout_log.write
      --> :002: base.logs
        --> :002: base.log
        --> :001: base.s_warn
      --> :001: base.str.os_err
  --> :003: base.buffer.add_line
    --> :002: base.log
    --> :004: base.logs
    ...
```

the number in `:NNN:` is call count [ how many times this edge appears in
source ]. indentation shows depth. subtrees re-expand fully under each caller,
so `base.log` appears as a subtree root hundreds of times across the file.

## the problem to solve

the per-zenka subroutine whitelist (`cfg/zenki/<name>/subroutine.white-list`)
is a **flat deduplicated reachable set** — correct and cheap. the full graph
however needs to retain **edge information** [ which module calls which, with
call counts ] to remain useful for tooling like reachability analysis and dead
code detection. a flat list loses that.

what is needed is a **deduplicated adjacency format** : each module appears
exactly once as a source, its direct callees listed alongside it. the
transitive structure is implied by following edges, not re-expanded. this
would be :

- small enough to track as plain text without compression
- diffable in git : a change to one module's dependencies shows as one changed line
- still carries the full structural information the tool needs
- diff size proportional to actual change impact

## format constraints and project style

- **lowercase comments**, `[ word ]` annotations, no uppercase in running text
- module names use dot notation : `base.log`, `net.get`, `httpd.file_transfer.send`
- numeric weights [ call counts ] are present and meaningful — preserve them
- the format should be **sortable** and **stable** : same graph = identical output
  [ important for the unchanged-file signature preservation logic ]
- should be parseable by simple perl without a grammar : split on whitespace or
  a clear delimiter
- a header or legend line is acceptable if brief

## question for kimi

given the above constraints, what adjacency format would you suggest for this
graph that :

1. deduplicates cleanly [ one line or block per source module ]
2. preserves edge weights [ call counts ]
3. reads naturally alongside the rest of the project
4. has a diff structure that reflects actual dependency changes proportionally

feel free to propose more than one variant and note tradeoffs. a small concrete
example using real module names from the sample above would help evaluate each
option.

## sample graph fragment [ real data ]

these are actual edges from the graph to use as example input :

```
net.get         -> base.log        [ 2 calls ]
net.get         -> base.buffer.add_line [ 3 calls ]
base.log        -> v7.stdout_log.write  [ 1 call  ]
base.log        -> base.utf8.clean_str [ 2 calls ]
base.log        -> base.buffer.add_line [ 3 calls ]
base.buffer.add_line -> base.log   [ 2 calls ]
base.buffer.add_line -> base.logs  [ 4 calls ]
base.buffer.add_line -> base.s_warn [ 1 call  ]
```

[ note : cycles exist in the graph — `base.log` and `base.buffer.add_line`
call each other — the format must handle cycles gracefully without infinite
expansion ]

#,,,.,,,,,..,,,.,,,.,,,..,...,.,.,...,.,,,,.,,..,,...,...,,,.,,..,...,.,,,,..,
#3IQ5VUBXHKMI3IALCONDZ7DN35B244FKAW6XMGAZPLJ7MWUTMMEYPPIRW77LE2W7XQBMS5HULJWAU
#\\\|K3EAZWZATJAVIFLU2BCHAAI2BETFVV767HK6V5GGNL2IRJ5QGSZ \ / AMOS7 \ YOURUM ::
#\[7]744LRFZ7KD37P37C52EYELL3ZZAO2PGC3VUORC6SXJLDRAHFD4CA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
