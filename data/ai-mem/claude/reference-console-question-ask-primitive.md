---
name: reference-console-question-ask-primitive
description: "AMOS7::TERM::ask + base.term.ask — the generic console question primitive (yes-no/text/masked) with the 'given' parameter-or-prompt shape and a no-tty guard; plus the map of the FIVE places interaction code lives, so nobody adds a sixth"
metadata:
  type: reference
---

Added 2026-08-12, per user: "a good generic and well styled question
subroutine is still very useful in imminent features."

## where it lives and why

- **`AMOS7::TERM::ask`** — the implementation. In the library layer
  because, per user, "AMOS7::TERM has most the interactive code, so zenki
  and scripts both could use it." Exported via `@EXPORT_OK`.
**Namespace, per user — `base.term.ask`, deliberately NOT `base.ask`:**
`base.term.size` already exists as a CORE SUB (inline in `bin/Protocol-7`,
listed by `./bin/Protocol-7 -core-subs term.size`, called as
`$code{'base.term.size'}`), so `base.term.*` is a live namespace and this
belongs beside it. `base.ask` would also have implied it is THE ask, when
the map below shows five distinct interaction media — naming the medium is
more honest. And it leaves a clean later path to a `term.*` family via the
standard `base.term.pre_init` + `swap_subs('base.term','term')` promote
pattern ([[feedback-base-swap-subs-promote-pattern]]) with zero call-site
churn. Renamed while there were still NO callers, which is when such a
move is free.

- **`modules/base.term.ask`** — thin P7 wrapper that autoloads AMOS7::TERM and
  delegates, so zenka code reaches for a `base.*` call rather than a raw
  perlmod one (the established convention — see the `base.get_homedir`
  vs `AMOS7::FILE::get_homepath` lesson in
  [[topic-user-edit-console-zenka-status]]).

```perl
<[base.term.ask]>->( { question => 'create a default record?' } )   ## yes-no
<[base.term.ask]>->( { question => 'user name', type => 'text' } )
<[base.term.ask]>->( { question => 'passphrase', type => 'masked' } )
```

`masked` delegates to `read_password_single`, so secret entry keeps ONE
implementation rather than growing a second.

## the two properties that make it safe to drop in anywhere

1. **`given`** — when defined it is returned immediately, nothing is
   printed. This is `crypt.C25519.load_keypair`'s own shape
   (`if not defined $key_password { prompt } else { use it }`). It is what
   lets a caller expose a `:tag:` or command parameter that converts an
   interactive step into a scripted one **with no second code path** —
   e.g. a planned `:create-admin:` tag (colon-tag convention already used
   by `keys.console.list [:nosums:|:sigs:]`, parsed as a plain
   `$param eq qw| :sigs: |`).
2. **no tty → returns `default` without reading.** Uses
   `AMOS7::TERM::has_tty()` (checks `Term::ReadLine->findConsole` plus all
   three standard streams — more careful than a bare `-t STDIN`). A
   blocking read on a detached STDIN is how an event-driven zenka wedges
   itself, so it refuses instead.

**BLOCKING — the constraint that matters:** it reads STDIN. Only call
before the event loop is entered, or where nothing else needs servicing.
This is exactly why `crypt.C25519`'s passphrase prompts are fine during
`[init_modules]` but would be wrong inside a running form. An
event-loop-safe prompt (needed for `masked` credential entry *inside*
user-edit's form) is a SEPARATE, still-unbuilt thing — do not assume
`base.term.ask` covers it.

## the interaction-code map — FIVE places, do not add a sixth

Per user, spread across media rather than duplicated by accident:

1. **`AMOS7::TERM`** — the library layer: `ask`, `read_password_single`/
   `_repeated`, `has_tty`, `terminal_size`, the `editor_*` and `cursor_*`
   primitives, frame helpers. Usable by zenki AND standalone `bin/`
   scripts.
2. **nshell** — carries its own line-editing/history/search interaction
   (`nshell.read_from_buffer`, `nshell.util.extract_utf8_char`, inline
   escape accumulation). Per user, "nshell for example was its own
   interaction code too". The `editor.*` namespace migration is the effort
   consolidating this core — see
   [[topic-editor-namespace-migration-status]].
3. **`amos-term.interaction.ask`** — named-buffer, NON-blocking, agent
   side. Different medium, not a duplicate.
4. **`coding.tools.handler.ask_user_text`/`_choice`** — GUI modal routed
   to `protocol-7-menu.cmd.input-text`. Different medium.
5. **user-edit's form** — `editor.control.*` + `editor.input.next_key` +
   the `event.add_io`/`add_var` pair; the event-driven one.

**How to apply:** before writing any new "ask the user" code, work out
which medium it belongs to and extend that one. `editor.input.next_key`
and `editor.input.parse_key_spec` were added to the shared `editor.*`
namespace for this reason; `nshell.no-tty-debug.cmd.char-add` still
carries its own copy of the key table and is a known consolidation
candidate.

## not verified

The INTERACTIVE branch has only been reasoned about, not run — all
testing here was the no-tty path (`given` short-circuit, default returned
for truthy/falsy, undef with no default, no blocking under piped stdin).
Confirm the prompt renders acceptably, and whether ` :. ` is the right
prefix, with:

```
perl -Idata/lib-path/pm -MAMOS7::TERM \
     -e 'print AMOS7::TERM::ask({question=>"works?"})'
```

`bin/dev/update-amos-versions` covers only AMOS7::CHKSUM/ELF/ELF::Inline,
so TERM.pm's `$VERSION` tag needs no regeneration when edited.

#,,,.,...,,.,,,,,,...,,..,...,,,.,.,,,.,,,,..,..,,...,...,...,,,.,...,,.,,...,
#233UCXR7TECV6ZOKHN7YWYOQHQD4UPZSKK24HXKQQZUAJSC6TAXEJZH3VP44TAP2D5GEWYXZPPJHS
#\\\|3IBZWROOFU7EWUWKHIR6EB7FAJ347SC67LJWWT5OG65I45JGPOA \ / AMOS7 \ YOURUM ::
#\[7]RAJRFNPTH5DF44B6EWK6OQG4Y3NBZQK6JKMPQBALCRP47654ASBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
