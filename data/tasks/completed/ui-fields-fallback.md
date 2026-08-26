# task: ui.fields.fallback — universal level-0 field map

## relation

`data/md/design/UI-SHOW-SECURITY-LEVELS.md` step (1) of the
implementation queue. lays the foundation for steps (2) and (3): a
generic, structurally-derived set of "interesting base values" that
every zenka exposes safely at security level 0, regardless of whether
the zenka has bothered to declare its own `<namespace>.ui.fields`.

without this, the level-0 default of `*.ui-show` has nothing safe to
render — the whole point of the security-level system is that level 0
is "safe by construction", and this module is what makes that true for
zenki that haven't opted in.

read first:
- `data/md/design/UI-SHOW-SECURITY-LEVELS.md` (whole doc, especially
  "per-zenka interesting base values map" and "security level 0")
- `src/ui.unfold`, `src/ui.render.fallback` — these will be
  taught to read this map in [[ui-unfold-fields-filtering]]
- `src/base.cmd.list` and similar for the SIZE-mode reply shape
- where pid/uptime/restart-count/source-mtime live in `%data` already —
  grep `<system.` and `<v7.` in modules to find what's there:
  - `<system.zenka.name>`, `<system.zenka.startup-time>` etc
  - `<system.callbacks.initialized>` (init-completion timestamp)
  - check `src/system.*` and `src/v7.*` for what's broadly
    available across zenki [ this is generic, so only use addresses
    that every zenka has after init ]

## scope

### `src/ui.fields.fallback`

```perl
## [:< ##
# name  = ui.fields.fallback
# descr = universal level-0 field map used when a zenka has no
#         <namespace>.ui.fields of its own
# param = none [ pure data producer ]
```

returns a hash-ref of the shape:

```perl
{
    'pid'           => { 'value' => sub {...}, 'level' => 0 },
    'uptime'        => { 'value' => sub {...}, 'level' => 0 },
    'restart-count' => { 'value' => sub {...}, 'level' => 0 },
    'start-file'    => { 'value' => sub {...}, 'level' => 0 },
    'log-file'      => { 'value' => sub {...}, 'level' => 0 },
    'idle'          => { 'value' => sub {...}, 'level' => 0 },
    'source-age'    => { 'value' => sub {...}, 'level' => 0 },
    ## op stats — request/queue/error counts, if available generically
}
```

constraints:
- every `value` sub must be safe to call from any zenka — derive from
  `%data` addresses that are populated for all zenki, or fall back to
  empty string. do NOT touch the filesystem outside of `stat()` on the
  zenka's own start/log/source paths
- `value` subs return a plain scalar (string/number), not a hashref —
  the field map is what carries structure, the values are leaves
- `level` is always `0` in this module. levels 1+ belong to per-zenka
  maps (out of scope here per [[topic-ui-show-security-levels]] non-
  goals)
- paths only, never contents. `start-file` returns the path string, not
  the file body. the design doc is explicit about this — "paths only,
  not contents"

### no callers yet

this module is pure scaffolding. nothing calls it until
[[ui-unfold-fields-filtering]] lands. that's intentional — splitting
the producer from the consumer keeps each task small and reviewable.

## acceptance

- `perl -c src/ui.fields.fallback` clean
- calling the module returns a hash-ref with all level-0 keys above,
  every entry `{ value => CODE, level => 0 }`
- each `value` sub, called with no args from any zenka context, returns
  a defined scalar (possibly empty string) — never dies, never returns
  a hashref/listref
- no field exposes file contents, no field reads outside the zenka's
  own paths

## non-goals

- no per-zenka level 1+ fields — covered by step (5) of the design doc
- no changes to `ui.unfold` / `ui.render.fallback` — that's
  [[ui-unfold-fields-filtering]]
- no caller-identity / security-level resolution — that's
  [[ui-caller-security-level]]
- do NOT add `*.ui-show` to `cube/access.zenki` — explicitly deferred
  to step (4) of the design doc, called out as out-of-scope by the
  spawning prompt
- no key-based authorization — step (6), separate task later

## signatures note

no `#,,..` stubs. do NOT run update-signatures (pre-commit hook
re-signs on commit). lowercase comments, `[ word ]` annotations, `$ARG`
not `$_`.

## checks

```
perl -c src/ui.fields.fallback
```

#,,..,.,.,,.,,.,,,,.,,.,,,,..,.,,,...,,,,,..,,..,,...,...,,,,,,.,,...,.,,,,,,,
#D24EODKGMTKSJC5ENZQ4BONEBITBJZ43O67F7I2QYJ6JJSM6QKU5YKSCDGINE2FCJCHMCF5DIMX5I
#\\\|EEH3KJOBTUBWDRL3MOJCEGTPVNV4WW7UGUIGPQXMVSFUKLPFXBQ \ / AMOS7 \ YOURUM ::
#\[7]U7HDQZKPIYMVF5RTL5NTMKYNSFZA5CQP4DWKPY4GBC2BMRP3ZUAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
