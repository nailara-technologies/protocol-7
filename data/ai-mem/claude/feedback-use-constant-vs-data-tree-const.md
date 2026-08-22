---
name: feedback-use-constant-vs-data-tree-const
description: "a <module.path.KEY> read resolving to a plausible value is not proof it's actually wired -- use constant {...} and a plain return {...} module both silently fail to populate %data, confirmed twice same day (9P protocol constants, then plan-9.config's port)"
metadata:
  type: feedback
---

## the trap

A P7 module can contain plain Perl:

```perl
use constant {
    MSIZE => 8192,
    QTDIR => 0x80,
};
```

This compiles fine, and `MSIZE`/`QTDIR` work as bareword constants
*within that one compiled module*. But nothing else in the codebase
can see them via `<some.namespace.MSIZE>` — the `<[...]>`/`<...>`
single-bracket syntax reads from the **`%data` tree**, a completely
separate runtime structure. `use constant` never touches `%data`.
Every other module doing `<plan-9.protocol.constants.MSIZE>` silently
got `undef` back — not a compile error, not a warning, just `undef`
propagating through arithmetic and string ops until something far
downstream looked broken for an unrelated-seeming reason.

**Found live, 2026-08-22**: this was the root cause silently breaking
the *entire* `storage.9p.*` / `plan-9.*` 9P client+server subsystem
since it was first written (2026-03-27) — `src/plan-9.protocol.constants`
used `use constant {...}`, and every reader on both the client and
server side had been getting `undef` for message-type opcodes, buffer
sizes, and QID type bits the whole time. It "compiled" and even ran
without crashing (undef coerces to 0/'' in most contexts), so the bug
had zero visible symptom until live wire-protocol behavior was
actually inspected byte-by-byte.

## the established correct pattern

A `.pre_init`-suffixed module (auto-invoked once at zenka startup by
`base.init_modules`, see [[bug-forensics-dotted-command-names]] and the
lifecycle-hook convention in CLAUDE.md) doing real `Const::Fast`, with a
reload-safety guard:

```perl
## [:< ##
# name = plan-9.protocol.constants
# descr = shared 9P2000 wire-protocol constants

delete <plan-9.protocol.constants>
    if <[base.is_defined_recursive]>->( qw| plan-9.protocol.constants | );

const <plan-9.protocol.constants> => {
    'MSIZE' => 8192,
    'QTDIR' => 0x80,
    ...
};
```

Precedent this was modeled on: `crypt.C25519.init_code`'s
`const <crypt.C25519.regex> => {...}` (also preceded by the same
`delete <path> if <[base.is_defined_recursive]>->(...)` guard).
`Const::Fast` is already loaded process-wide by `base.init_code`
(`use Const::Fast;` + `base.perlmod.register_loaded_module`), so any
module can use the bareword `const <path> => {...}` form directly —
no explicit `use Const::Fast;` needed per-file.

**How to apply**: whenever reviewing or writing a P7 module meant to
define constants that OTHER modules will read via `<namespace.KEY>` or
`<[namespace.KEY]>`, immediately reject a plain `use constant {...}`
block — it is a silent no-op from every other module's point of view.
Grep for `<plan-9` / `<some.namespace.` style reads first, then check
the defining file actually uses `const <path> => {...}`, not
`use constant`. If a module needs constants ONLY for its own internal
use and nothing else ever reads them via the data-tree syntax,
`use constant` is fine and simpler — the trap is specifically
cross-module sharing through `<...>`.

Related but distinct: [[feedback-init-code-return-values]] (return-value
semantics of `.init_code`, not what it populates),
[[feedback-v7-zenka-startup-config-placement]] (a different "silent
no-op due to wrong mechanism" class of bug, in `start.cfg` instead of
module constants).

## second instance, same day: a plain `return {...}` module is ALSO not enough

Found a few hours later in the same subsystem: `src/plan-9.config` was
a plain module doing `return { 'port' => 15640, ... };` — no
`use constant`, no `const <path> =>`, just a bare hashref return. Every
reader used `<plan-9.config.port>` (the data-tree read syntax), on the
apparent assumption that a *compiled* module named `plan-9.config`
would somehow auto-populate `%data{'plan-9'}{'config'}` just by
existing. It never did — nothing calls `<[plan-9.config]>->()` and
stores the result anywhere. Proved this empirically (not just by
reading code): changed the file's port value, restarted the zenka,
confirmed the real listening port didn't move, reverted. The file had
been **entirely dead** since it was written — every real caller was
either hitting this exact same silent-`undef`-then-fallback pattern
or just hardcoding the literal directly instead of trusting the read.

**The general lesson, now confirmed twice in one day**: `<some.path>`
resolving to a plausible-looking value is NOT evidence that path is
actually being populated by the mechanism you think it is — it may
simply be falling through to a `// <hardcoded literal>` fallback that
happens to match. Before trusting a `<...>` read as the real source of
a value, verify something concrete actually writes that path: a
`.pre_init`/`.init_code` `const <path> => {...}`/`$data{...} = ...`
call, or plain `key=value` config-file parsing (`shared-params`/
`start.cfg`, confirmed working — see
[[feedback-v7-zenka-startup-config-placement]]). If you can't point at
the actual write, assume the read is silently falling through to
whatever fallback follows the `//`, and test that assumption by
changing the presumed source and confirming live behavior actually
moves — exactly the empirical test that caught this one.

**The fix that actually solved the underlying need** (a single,
per-zenka-overridable default shared across many files) wasn't a
`.pre_init` constant at all — it was a `cfg/shared-params` entry
(`plan-9.default_port = 15640`), the same pattern
`system.zenka.verbosity.*` already uses successfully: loaded via
`[load_config_file:'shared-params']` in each zenka's own `zenka.v7`,
individually overridable by any zenka re-declaring the same key in its
own file afterward. Use `Const::Fast`/`.pre_init` for truly immutable,
never-overridden shared constants (like protocol opcodes); use
`shared-params` for anything a specific zenka might legitimately want
to override. See `data/md/design/STORAGE-9P.md`'s "Config:
plan-9.default_port" section and
[[project-plan-9-storage-9p-subsystem-status]] for the full incident.

#,,.,,,,,,,.,,,.,,,..,.,,,,..,,.,,,..,,.,,,.,,..,,...,...,,.,,...,.,,,...,..,,
#H6NGGX5RT5TGMEXIHZT6YWRQVUCGCE6KJHCVEUS2MC4XNOAMNGSJMOI5IWLCMRHJ2ALDREKPV64PM
#\\\|FGUG56K5XMYJBLNBCTWKRESG4AD2KNWKROZ6YZR2TVTGCXSKFZJ \ / AMOS7 \ YOURUM ::
#\[7]RJRDVY5CMJVDGCASG4EYSHMRJ7U7K4ZD5NTZDFUMUD3XR5GOPUCQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
