# module registry design

## purpose

a central per-zenka hash structure that all code-loading paths consult
before acting. avoids re-parsing, re-scanning, or re-verifying what is
already known. expensive operations [ dependency resolution, signature
verification, source parsing ] happen once and are cached here.

## registry location

```perl
$data{'base'}{'module'}{'registry'}    ##  keyed by module name  ##
```

or via the short-form alias once defined :

```
<base.module.registry>->{$module_name}
```

## per-module entry structure

```perl
$data{'base'}{'module'}{'registry'}{'some.module.name'} = {

    ##  identity  ##
    'name'      => 'some.module.name',      ##  canonical key, redundant but useful  ##
    'namespace' => 'some',                  ##  top-level prefix  ##

    ##  state  ##
    ##  unknown | registered | deferred | compiled | failed
    'state'     => 'registered',

    ##  source location  ##
    'source' => {
        'type'   => 'disk',                 ##  disk | memory | manifest  ##
        'path'   => 'modules/some.module.name',
        'cached' => undef,                  ##  scalar ref to source when in memory  ##
    },

    ##  signature \ integrity  ##
    'signature' => {
        'amos'    => 'XXXXXXX',             ##  7-char AMOS checksum  ##
        'verified' => FALSE,                ##  set TRUE after verification  ##
    },

    ##  dependencies [ expensive : populated lazily or from manifest ]  ##
    'deps' => {
        'resolved' => FALSE,                ##  flag : dep graph computed?  ##
        'requires' => [],                   ##  arrayref of module names  ##
        'optional' => [],                   ##  optional \ soft dependencies  ##
    },

    ##  init phases present [ scanned once ]  ##
    'phases' => {
        'pre_init'  => FALSE,
        'init_code' => FALSE,
        'post_init' => FALSE,
    },

    ##  deferred compilation context  ##
    'deferred' => {
        'reason'   => undef,               ##  'lazy' | 'on-demand' | 'manifest'  ##
        'placeholder_installed' => FALSE,  ##  TRUE when stub in %code  ##
    },

    ##  timing  ##
    'timestamps' => {
        'registered' => undef,             ##  epoch float  ##
        'compiled'   => undef,
        'last_reload' => undef,
    },

    ##  compile result  ##
    'compile' => {
        'ok'       => undef,               ##  sub count on success  ##
        'errors'   => 0,
        'warnings' => 0,
    },
};
```

## state transitions

```
unknown → registered   [ manifest load or file scan ]
registered → deferred  [ marked for lazy / on-demand load ]
registered → compiled  [ load_code succeeds ]
deferred → compiled    [ first call triggers deferred_compile ]
compiled → compiled    [ reload : updates timestamps and compile result ]
any → failed           [ compile errors, signature mismatch ]
```

## design notes

- `load_code` checks registry state before acting — skips re-scan if
  `deps.resolved` is TRUE, skips re-verify if `signature.verified` is TRUE
- `dep-graph` writes into `deps.requires` and sets `deps.resolved = TRUE`
  so subsequent loads skip the expensive parse pass
- `deferred_compile` handler reads `source.cached` when available [ memory
  path ], falls back to `source.path` [ disk path ] only when not in memory
- manifest loader populates `signature.amos` and sets `state = registered`
  before any source is read — integrity check is decoupled from compilation
- `phases` scanned once at registration time [ cheap header parse ] so
  `base.init_modules` can skip modules with no relevant phase without
  compiling them

## open questions

- shared registry across zenki [ shared memory ] or per-zenka only?
- eviction policy for `source.cached` after compilation [ free memory ]?
- how manifest format maps to this structure [ signed list → registry entries ]

#,,,,,,.,,...,,,,,.,,,,..,..,,,,,,,..,.,.,.,.,..,,...,...,...,,,.,,,.,,,.,...,
#LDT7FVERBUZ5JZR7AE4YAAZWANIUU7WX6GPDG7EHMXXR56Q4NLV5ZEN37474PNNZPYUOMERQY4UMW
#\\\|NY3GY6BHKOZLCSNSRIC3V4US24HF7FWABWIECZDXTUSG6GCDAWE \ / AMOS7 \ YOURUM ::
#\[7]RVHLGL3P4PZW3KJC3AZNADD2LVVSK3DMM3ZRDHCAOYVYWXRCV4DA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
