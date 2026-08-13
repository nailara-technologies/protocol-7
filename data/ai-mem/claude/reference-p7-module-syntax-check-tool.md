---
name: reference-p7-module-syntax-check-tool
description: "bin/test-scripts/p7-module-syntax-check translates P7 macro syntax (<[module.name]>, bare <name> data-slot reads) then perl -c's the result — plain perl -c on a raw module file gives false results in both directions depending which macro forms it uses, this tool is the actual reliable check"
metadata:
  type: reference
---

Found 2026-08-13, mid-session, after wasting a few `perl -c` calls that
gave misleading results.

## plain `perl -c` on a raw module file is not reliable either way

A module built purely from `<[module.name]>->()` sub-call syntax happens
to parse as valid (if semantically meaningless) raw Perl — the `<...>`
diamond-read-then-call shape is coincidentally legal — so `perl -c`
passes clean on those, correctly or not by luck rather than design.

A module using the bare `<name>` **data-slot** syntax (a plain data read/
write, not a sub call — e.g. `<user-edit.plugin.registry> {'by_key'}
{$x}`) does NOT parse as raw Perl at all: `perl -c` throws a hard
`syntax error ... near "<user-edit.plugin.registry> {"` on a file that is
completely correct P7 source. Confirmed this is true even for long-
established, working, already-shipped files (`plugin.user-edit.registry.
post_init`, `user-edit.form.schema_from_record`) — it is not a sign of a
real bug, just proof `perl -c` never saw the macro-translated form.

Do not conclude a module is broken from a bare `perl -c` syntax error
without first checking whether it uses this bare `<name>{...}` shape —
and don't trust a clean `perl -c` pass as full verification either, for
the unrelated reason [[feedback-cmd-call-injection-not-caught-by-perl-c]]
already documents (the `$call` header injection for `.cmd.`-named
modules is invisible to both `perl -c` AND this tool — see below).

## the actual tool

```
perl bin/test-scripts/p7-module-syntax-check modules/some.module.name [more...]
```

It reads the file, strips the AMOS7 signature footer, runs it through
`AMOS7::Protocol::P7Syntax::p7_syntax__translate` (the SAME translation
the real module loader applies), wraps the result in a `sub { ... }`
with `%data`/`%code`/`%keys` declared as package globals, and `perl -c`s
THAT. This correctly accepts both macro forms above.

**Known false positives, not a translation bug**: `%colors` and other
package-globals declared with `our` in `bin/Protocol-7` itself (not in
the module being checked) still fail as "Global symbol requires explicit
package name" — the wrapper only declares `%data`/`%code`/`%keys`, not
the full runtime environment. Confirmed by running the SAME check against
the unmodified `git show HEAD:<file>` version of an already-shipped,
working file and seeing the identical error — if a fresh error only
appears on your edited version and not on `HEAD`'s, it's real; if it
already existed on `HEAD`, it's this class of noise, not a regression.

**Known blind spot, shared with plain `perl -c`**: does NOT inject
`$call` for `.cmd.`-named modules, so it cannot catch the [[feedback-cmd-
call-injection-not-caught-by-perl-c]] class of bug either — boot-testing
the owning zenka is still the only real verification for that one.

#,,,.,,,,,..,,,..,...,.,.,,,.,,.,,.,.,..,,.,,,.,.,...,...,,.,,.,.,,.,,..,,,,,,
#A7PWPZQEAIUTHGHTAJHHB7SJQSBTHI4PJFPKDCVYZVV4SAYKB3ZUNDPVY2QLYEI5L6G4GN3RLOOU6
#\\\|VWF7OJKGM27F5ZR2R7I3YWMYURYSRJROEBIDJHXNRJRUMGWPMFY \ / AMOS7 \ YOURUM ::
#\[7]RMIGCRJDGOVW7DV5YLBI74RXDLSN33SJP5FIPVG7RAMCEC43NADI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
