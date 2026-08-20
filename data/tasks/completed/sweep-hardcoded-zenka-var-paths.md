# sweep hardcoded zenka var-dir paths, incl. base.* modules

## status

completed (2026-07-29). grep sweep found hardcoded `/var/protocol-7/...`
defaults across `*.init_code`, `base.file.*_timestamped`, `jobsite.*`,
`coding.*`, and command modules. all clear-cut instances where the path
belongs to the running zenka were converted to
`catdir( <system.path.zenka-dirs.var_P7>, <system.zenka.name> [, ...] )`,
matching `base.path-set-up.check-zenka-paths`'s own pattern.

deliberately left unchanged:
- paths whose directory component intentionally differs from the zenka
  name (e.g. smtpd → `mail`, letsencr → `certs`, web-browser →
  `visual-feedback`), to avoid silently relocating data.
- legacy one-off migration paths (e.g. jobsite `site-yaml/store.yaml`).
- deprecated modules (`models.storage.tier_management`).
- comments, infrastructure modules that already derive the path, and
  cross-zenka shared dirs (`universal` → `ffmpeg/video_frames`).

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
`src/`/`cfg/`/project-root paths) — this task extends
that same convention specifically to zenka var-dir paths
(`<system.path.zenka-dirs.var_P7>` + `<system.zenka.name>` via
`catdir`, per `base.path-set-up.check-zenka-paths`'s own pattern),
which the existing template doesn't explicitly call out.

## next steps if picked up

1. grep the codebase for hardcoded `/var/protocol-7/<name>/`-shaped
   literals across `src/*.init_code` and similar config-default
   lines, to scope how widespread this actually is before starting.
2. dispatch to the coding zenka using (or extending)
   `no-hardcoded-paths.yaml` as the guiding context template — this
   is exactly the kind of scoped, well-defined, repeatable pattern-fix
   sweep that template is meant to drive.
3. include `base.*` modules in scope, not just zenka-specific ones —
   user explicitly flagged base as containing instances too.

#,,,.,...,..,,..,,,,.,...,,,.,..,,..,,..,,...,..,,...,...,,..,..,,.,,,,..,...,
#OGKQEBP5YZVC2PXS7PEW65ULEI27WGUC6FOZ7XVBS4AXUAK6UEC6FIV6GJSMB5AYLFAAFDHBKW7LE
#\\\|QNHR5OFGKNVFA4Y6YBBG2HPD5WUOCSJ7HEP2TS5OSYPXUVMI2XP \ / AMOS7 \ YOURUM ::
#\[7]5ZU76TZBRQ6CK74JN27BF6MGPWBIV4GIZQ4ZIFUPIKGTT3KA52CQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
