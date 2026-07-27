# sweep hardcoded zenka var-dir paths, incl. base.* modules

## status

not started. deferred to a future coding-zenka session, per user's
own explicit call — not fixed ad-hoc during the povray landing that
surfaced it.

## the pattern to fix

modules hardcoding a zenka's own var-directory path (e.g.
`/var/protocol-7/<zenka-name>/`) instead of deriving it from the
already-registered system path variables — concretely:

```perl
## wrong ##
<zenka.cfg.output_dir> //= '/var/protocol-7/<zenka-name>/';

## right, same pattern base.path-set-up.check-zenka-paths itself uses ##
<zenka.cfg.output_dir> //= catdir( <system.path.zenka-dirs.var_P7>,
    <system.zenka.name> );
```

caught live in `povray.init_code` while landing povray milestone 1
(see `project-povray-zenka-milestone1-landed-2026-07-27.md`) and fixed
there directly since it was a single, already-in-hand instance. user
noted more instances exist elsewhere in the codebase, **including
inside `base.*` modules themselves** — a broader sweep, not something
to chase ad-hoc per-file as they're noticed.

## existing infrastructure for this

`data/yaml/context-templates/no-hardcoded-paths.yaml` already exists
as a context template covering this exact convention (`<system.code_path>`,
`<system.cfg_path>`, `<system.root_path>` instead of hardcoded
`modules/`/`configuration/`/project-root paths) — this task extends
that same convention specifically to zenka var-dir paths
(`<system.path.zenka-dirs.var_P7>` + `<system.zenka.name>` via
`catdir`, per `base.path-set-up.check-zenka-paths`'s own pattern),
which the existing template doesn't explicitly call out.

## next steps if picked up

1. grep the codebase for hardcoded `/var/protocol-7/<name>/`-shaped
   literals across `modules/*.init_code` and similar config-default
   lines, to scope how widespread this actually is before starting.
2. dispatch to the coding zenka using (or extending)
   `no-hardcoded-paths.yaml` as the guiding context template — this
   is exactly the kind of scoped, well-defined, repeatable pattern-fix
   sweep that template is meant to drive.
3. include `base.*` modules in scope, not just zenka-specific ones —
   user explicitly flagged base as containing instances too.

#,,,.,,..,,.,,...,.,,,.,,,.,,,...,..,,..,,,,,,..,,...,..,,.,,,.,,,.,,,,..,..,,
#YPA44BRXEUROK2EVMQT6CAUDFF5TKSCAZ2ETZ5KGXIVSXUOHZI5GM3YLE3BBVQQSF344TOTWZ6Y6G
#\\\|YAPMGYTBLL6FSBCAVLTUO7GK35ULYNYRUNPNPWRF7UBP654DNWJ \ / AMOS7 \ YOURUM ::
#\[7]CG2CGDOHMHUJYQCSNB7WD3N5YOAU3ARCS3RIONLKQ7VS423AYABQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
