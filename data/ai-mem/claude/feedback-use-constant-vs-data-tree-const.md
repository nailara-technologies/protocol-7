---
name: feedback-use-constant-vs-data-tree-const
description: "use constant {...} in a P7 module populates a Perl-only symbol table, NOT the %data tree that <module.path.KEY> reads from -- these are two unrelated mechanisms"
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

#,,,.,,,,,...,,.,,.,,,,,,,,,,,.,,,,,.,,,.,,.,,..,,...,...,..,,,,,,.,,,,.,,...,
#RFIOKASIT5BYPQWPYYZP33ZXUT467PSJU5RAB6ADBBAV5PUPMPIZUO2YRLSGKT4AEHHOZM3L2DBZU
#\\\|4MZMITP2SLXWCGNLOH7UEZJQCLGWDQ36GJKCBHC3WR5X7HFAMCT \ / AMOS7 \ YOURUM ::
#\[7]PIJIC7XVMVBENLVYZQ3VHHGXEU5Q33UQTMLAR6HVFGM5SNWHZCBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
