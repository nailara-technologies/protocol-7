# Task: dep-graph whitelist — cmd access filtering + on-demand module exemption

## Background

The current `dep-graph --list-subs` / `gen-sub-whitelist` system generates a
subroutine whitelist by static reachability analysis from a zenka's entry points.
Two related limitations were identified during the 2026-03-19 whitelist
regeneration session.

## Issue 1: devmod.* in every zenka whitelist

`base.sig_NUM53` is unconditionally seeded as an entry point for all zenki
(it is registered dynamically via sprintf in `base.init_zenka.install_signal_handlers`
and cannot be traced statically). It contains:

```perl
<[base.load_runtime_modules]>->('devmod');
<[base.init_modules]>->('devmod');
```

Because dep-graph now detects `load_runtime_modules` calls, the full `devmod.*`
namespace (~40 subs) is included in every zenka's whitelist — even zenki that
never run devmod in production.

This is technically correct (any zenka *can* receive SIGNUM53 and load devmod),
but the devmod commands that become available after loading are governed by the
zenka's `access.cmd.*` config, not by static reachability alone.

## Issue 2: *.cmd.* subs not filtered by enabled commands

Currently all `*.cmd.*` subs reachable from a zenka are whitelisted regardless
of whether those commands are actually enabled in the zenka's `start` or
`access.cmd.*` configuration files. A zenka with:

```
access.cmd.usr.cube  =  *
```

gets every reachable cmd sub whitelisted. A zenka with:

```
access.cmd.usr.cube  =  httpd.reload, httpd.status
```

gets the same full set — the whitelist does not reflect the narrower access.

Filtering whitelisted `*.cmd.*` subs to only those enabled in the zenka's access
config would:
- significantly reduce whitelist sizes
- make the whitelist a precise reflection of what a zenka is permitted to do
- create a concrete incentive to replace wildcard `*` command access with
  explicit lists (because wildcards keep whitelist sizes large, while explicit
  lists shrink them)

## Proposed expansion

### Phase A — cmd access filtering in dep-graph/gen-sub-whitelist

1. Parse the zenka's `access.cmd.*` configuration entries during whitelist
   generation (already accessible via the start file and shared-params).
2. After reachability analysis, filter `*.cmd.*` nodes: only include those
   whose command name matches at least one enabled pattern in the access config.
3. Wildcard `*` access = keep all reachable cmd subs (current behaviour,
   no regression for existing zenki).
4. Explicit list = keep only the listed commands plus transitive deps.

### Phase B — on-demand / signal-loaded module exemption

Modules loaded exclusively via signal handlers (SIGNUM53 → devmod) or
on-demand triggers represent a distinct loading category:

- they are not present at init time
- their availability is controlled by an external signal, not by whitelist
- once loaded, the *access config* (not the whitelist) governs which of their
  commands are callable

Options:
a. **Exempt category**: tag `base.sig_NUM*` handlers as "on-demand loaders";
   the namespaces they load are exempt from whitelist checking entirely
   (the whitelist only covers statically-loaded code).
b. **Separate on-demand whitelist**: generate a secondary
   `subroutine.ondemand-white-list` for signal/on-demand modules; checked
   only after the module has actually been loaded into `%code`.
c. **Access-config-gated**: treat on-demand namespaces identically to Phase A —
   only whitelist their cmd subs if the zenka's access config permits them.

Option (c) is the simplest and most consistent with Phase A.

## Acceptance criteria

- [ ] dep-graph / gen-sub-whitelist parse zenka access.cmd.* entries
- [ ] *.cmd.* whitelist entries are filtered to access-permitted commands
      (wildcard `*` retains current behaviour)
- [ ] devmod.* no longer appears in zenki that have no devmod access configured
- [ ] zenki with explicit access lists show measurably smaller whitelists
- [ ] regression test: zenki with wildcard access produce identical whitelists
      to current output

## Related files

- `bin/dev/dep-graph` — reachability analysis, `--list-subs` mode
- `bin/dev/gen-sub-whitelist` — whitelist file writer
- `configuration/zenki/*/subroutine.white-list` — generated output
- `configuration/zenki/*/start` — modules.load + access.cmd entries
- `modules/base.sig_NUM53` — devmod on-demand loader via SIGNUM53
- `modules/base.init_zenka.install_signal_handlers` — signal registration loop
- `modules/base.parser.access_conf` — **reference for glob-to-regex translation**:
  lines 78–97 show the correct pattern for converting `access.cmd.*` glob patterns
  to anchored regexes. key substitutions (applied after dot-escaping):
  `**` → `.+`, `*` → `[^\\.]+`. dep-graph must replicate this logic when
  checking whether a command name matches an access pattern — do NOT use a
  naive `m/^\$re\$/` or simple string glob.

## Notes

- Phase A alone is already a significant improvement; Phase B can follow.
- The access-config parsing required for Phase A is the same infrastructure
  needed to verify that access.cmd.* entries reference real subs — a useful
  consistency check in its own right.
- Implementing Phase A will surface zenki using overly broad wildcard access,
  creating a natural audit trail for tightening permissions.

#,,,,,..,,.,,,...,,.,,,..,,.,,,..,,.,,,,.,.,,,..,,...,...,...,,.,,.,.,,,,,.,,,
#MGXR3XUE5AXJI4GEKZGAKOD763LOJL4CGWCPHKOIUXBYBMW2E4AYFFLT2NRWHF7ONDZA7JSIX3J6S
#\\\|Z66I5MZ3X32ZPDL2FCJIXUUCUVWJU5RJGHNRYJHCR62WKJEYYTS \ / AMOS7 \ YOURUM ::
#\[7]PQFCSCORBKR72R246OC5ZMG6RGFSZVQXU4VO54WXA3I7T2KLOAAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
