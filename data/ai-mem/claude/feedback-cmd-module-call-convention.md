---
name: cmd-module-call-convention
description: "network .cmd. command modules receive args via a pre-bound $call hashref, not $ARG or shift — using $ARG silently yields undef args over the network"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 3c264315-73af-4677-a8b4-23ce085cb5a8
---

7 of the ~14 `ncode.cmd.*` modules built in one session (`diff`, `doc`,
`format-code`, `parse-headers`, `replace`, `sign`, `sign-batch` — plus
`search`, found and fixed live by the user before I got to it) all used:

```perl
my $call_args = $ARG                 // {};
my $args      = $call_args->{'args'} // '';
```

This silently receives `undef`/`{}` for every network-dispatched call —
`base.s_warn` logging confirmed both `$target`/`$pattern` were
`[UNDEF]` even though the command *did* dispatch to the right sub (its
own usage-error string came back, proving routing/access were fine).
Root cause: `.cmd.` modules invoked via the network command dispatcher
(`src/base.handler.command`, `$code{ <base.cmd>->{$cmd} }->
($call_args)`) receive their args through **`$call`**, a variable
already populated by the dispatcher — not `$ARG` (that's only ever set
in `map`/`grep`/`for` contexts, see [[arg-calling-convention]] for the
sibling mistake with explicit-Perl-call `@_`) and not bare `shift`
either (that pulls from `@_`, which is empty here — `ncode.cmd.apply`/
`ncode.cmd.suggest` use `my $params = shift // {}`, a third pattern not
yet confirmed correct or broken, see [[topic-ncode-safe-refactor-workflow]]).

**Correct pattern**, confirmed working (`task.cmd.claim`,
`ncode.cmd.transform`, and `ncode.cmd.diff`/`.doc`/etc. after the fix):
```perl
my $args  = $call->{'args'}  // '';
my $param = $call->{'param'} // {};   ## when structured params used ##
```

**Why this is easy to miss**: the bug is invisible in isolation — the
sub still gets *called* (dispatch, access-control, and routing all
succeed), it just silently receives empty args and returns its own
usage-error string, which looks exactly like "the user passed no
argument" rather than "the plumbing dropped the argument." Confirmed
live via `base.s_warn` diagnostic prints inside the failing sub, not
guessed from reading code alone — don't trust "the code text looks
consistent with a working example" as proof; test with a live network
call and an arg that should produce different output for present-vs-
absent.

**How to apply:** when writing or reviewing any new `<zenka>.cmd.<name>`
module meant to be reachable as a network command, use `$call->{'args'}`
/ `$call->{'param'}` directly — never `$ARG` and never bare `shift`.
When a `.cmd.` module's usage-error/blank-args branch fires unexpectedly
during live testing, check this exact pattern before assuming the
caller's input, access grant, or routing is at fault.

**Sibling gotcha, opposite direction (found 2026-08-10,
`coding.cmd.summarize-reply`):** `$call` is already provided to every
`.cmd.` handler by the framework — do NOT write
`my $call = <[protocol-7.call]>;` at the top of one. It compiles and
even works (same value), but it's a redundant redeclaration that shadows
the framework-provided `$call` in the same scope, which `bin/dev/ptd -c`
flags as a warning ("my variable $call masks earlier declaration in same
scope"). Caught via a routine bulk syntax-check run, not a functional
bug — but worth fixing on sight and worth checking for when reviewing
any `.cmd.` module, alongside the `$ARG`/`shift` mistake above.

[[arg-calling-convention]]
[[topic-ncode-safe-refactor-workflow]]

#,,,,,,..,.,.,,,.,..,,,,,,,.,,.,,,.,,,...,.,,,..,,...,...,.,.,,..,,,,,,..,...,
#UIE5EWLJRW77YUZ5WMEXALR26HQR7AL4FY7VKL4TIPK63ZLHIOWEXUO2VDW2MGEK3SLOYYTQ54IFU
#\\\|FGWJQRLI2ZKB2B4VHQICF74J4GJ3LWZ22QNGGMZGUZE236ZHZGZ \ / AMOS7 \ YOURUM ::
#\[7]YG47OKLZVD3RKE5UGMKVDIWCSR4ZQTPMZLXUGTATQDGANM5AWQBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
