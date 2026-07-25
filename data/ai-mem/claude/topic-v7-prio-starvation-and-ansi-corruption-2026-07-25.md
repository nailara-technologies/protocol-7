---
name: v7-prio-starvation-and-ansi-corruption-2026-07-25
description: "v7.zenka.start prio=>5 was an 11yr-inert typo exposed by the add_io prio fix, causing startup-timeout false failures; separately chased -vvvq ANSI corruption to a likely WezTerm-side throughput limit, landed real write-completion-loop fixes along the way"
metadata:
  node_type: memory
  type: project
  originSessionId: 10c54b94-5d67-41ab-a52a-127a6a5170be
---

## thread 1 : v7.zenka.start prio starvation -- RESOLVED, prio=>0 confirmed live

`base.event.add_io`'s prio copy-paste bug (fixed [[feedback-base-prefix-stripped]]-adjacent
commit `fbe0b6f21`) had an undiscovered side effect: `modules/v7.zenka.start`'s
`zenka_output` watcher (reads a managed child's stdout) had `'prio' => 5` sitting
inert for 11 years -- under the bug, `$params->{'prio'}` actually read
`$params->{'desc'}` (undef here, no desc key passed), and `Event->io(prio=>undef)`
empirically resolves to **prio 0** [ verified live: `perl -MEvent -e '...->prio'` ],
the highest queued priority. once the bug was fixed, the literal `5` became real
for the first time -- deprioritizing zenka-output reads below `base.session.init`'s
session io [ prio 1/2 ], starving it under load. symptom: v7-managed zenka starts
(not cube-standalone) got only the first buffered burst of child stdout, then hit
v7's own 64.7s start-timeout and killed an instance that was likely still fine
underneath, just unread.

**empirical prio sweep under full backend start `-vvvq`** [ live-tested, not
theorized ]: `0` settled fastest; `1,2,3,4` all settled but slower; `5` (original,
broken) and `-1` both confirmed broken. `-1` is NOT simply "more aggressive `0`" --
Event.pm's own docs: negative priority "bypasses the whole point of having an event
queue," invoking the callback **immediately**, not queued. tried live: caused a
reentrant hang ("awaiting init-code on stdin" never resolved) because this is a
`repeat=>1` **streaming** watcher, unlike `base.handler.write`'s/`base.session.init`'s
`output_buffer` watcher's `-1` usage, which is safe only because those are
`repeat=>FALSE` one-shot EAGAIN retries -- a genuinely different category. lesson:
**don't generalize a `prio=>-1` convention from one-shot retry watchers to
long-lived repeating ones** without testing -- the docs' own warning is not
theoretical.

final state: `v7.zenka.start`'s `zenka_output` watcher has explicit `'prio' => 0`,
landed in commit `1391ba11b` [ supersedes `de3e345ca`, which had no explicit
prio key and defaulted to Event's own io default of `4` -- not the
live-tested-fastest value ].

## thread 2 : -vvvq ANSI corruption chase -- inconclusive on root cause, real fixes landed anyway

user observed color-bleed / malformed-looking escape sequences on console during
very high `-vvvq`/`-vvvvv` traffic in WezTerm specifically (xterm comparison:
"hard to tell," no audible bell configured there either way). extensive chase,
most branches ruled out:

- **not** `v7.callback.stdout_log_rotate`'s byte-offset truncation [ real latent
  bug -- rotation seeks to `$size - $rotate_to` with zero line/escape-sequence
  boundary awareness, genuinely can start mid-escape-sequence -- but user
  confirmed this is "the shm log console clone," a different channel from the
  live terminal output being chased. fix was drafted then reverted, unrelated ].
- **not** a UTF-8 mid-character split at the read/reassembly boundary in
  `v7.handler.zenka_output`/`process_output_line` -- `\n` (0x0A) can never appear
  as a UTF-8 continuation or lead byte, so the newline-based line-reassembly
  split is provably always byte-safe. initial theory here was wrong, retracted
  after re-derivation.
- **not** (provably ruled out via live test) a partial/short write in either of
  the two real write sites found: `modules/v7.handler.output_zenka_stdout` (v7's
  own relay of a child's stdout to the terminal) and `bin/Protocol-7`'s
  `p7_devmod_sub` [ aka `base.devmod_sub` via `-core-subs` ] (any traced zenka's
  own `say sprintf(...)` emitting its call-argument trace line into its stdout
  pipe, read by v7 on the other end). both were rewritten from a single
  unchecked `say`/`print` [ return value never checked -- user's own catch ] to
  a loop over `base.s_write` that checks and retries on short writes. **neither
  fix changed the observed corruption** -- the completion loops never needed to
  retry (no short writes actually occurring), and a malformed-escape/BEL
  detector added temporarily to `output_zenka_stdout` never fired either. that
  diagnostic detector was reverted (pure overhead, target dropped) once ruled
  out; the write-completion-loop fixes were **kept** as generically-valid
  correctness improvements independent of this specific bug -- user's framing:
  "we should keep true improvements only... if the fix is generically an
  improvement then that itself is the value."
- working conclusion, not proven: likely a **WezTerm-side** escape-sequence
  parser/renderer limit under sustained extreme throughput (worse at
  `-vvvvv`), not a P7-side data-corruption bug -- nothing generated by P7 was
  ever caught as malformed by the (since-removed) detector, and both real
  write paths now provably complete or explicitly log failure.

**real bug found and fixed along the way, unrelated to the chase's actual
target**: `base.event.add_io` `syswrite()` is refused outright on `\*STDOUT`
because `bin/Protocol-7` globally binmodes it `:encoding(UTF-8)` [ and separately
`use open qw|:encoding(UTF-8)|;` also applies that layer to *any* subsequent
`open()`, including a `'>&='` fd-duplicate -- caught this twice, first forgot the
`binmode($raw_fh, ':raw')` step entirely in the module version, then dropped it
again when rewriting the bin/Protocol-7 version after a syntax-error fix; had to
re-add both times ]. fix: dup the fd via `open($fh, '>&=', fileno(STDOUT))` then
explicitly `binmode($fh, ':raw')` before any `syswrite`/`base.s_write` use.

**a real recursion bug found and fixed**: `bin/Protocol-7`'s devmod tracer
(`p7_devmod_sub`) wraps *every* compiled sub's body with a trace call when
`verbosity.console > 2` -- including `base.s_write` itself. calling
`base.s_write` from inside the tracer's own write path re-enters the tracer for
`base.s_write`, which calls `base.s_write` again -- infinite recursion ("Deep
recursion on anonymous subroutine"). fixed by adding `base.s_write` to the
existing exclusion list (`base.log`, `base.dump_data`, `base.buffer.add_line`
were already excluded for what's presumably the same reason -- worth checking
if any of *those* also call something that could recurse, next time this area
gets touched).

## thread 3 : base.devmod_sub / p7_devmod_sub mechanism, useful reference

every compiled sub gets this injected as its first statement when
`verbosity.console > 2` [ `bin/Protocol-7`, `p7_load_code`, sub-compilation
step ]:
```perl
if ( $data{'system'}{'verbosity'}{'console'} > 2 ) {
    $sub_code = <<~"EOC";
        sub {
        \$code{'base.devmod_sub'}->( qw| $sub_name |, \@ARG );
        # line 1 "$sub_name"
        $data{'code'}{$sub_name}{'source'}
        }
        EOC
}
```
`base.devmod_sub` [ = `p7_devmod_sub`, compiled into `bin/Protocol-7` directly,
inspectable via `Protocol-7 -core-subs devmod_sub` -- not a separate module file
despite the `base.*` naming convention ] formats `. <zenka> : <sub_name> [ <args> ]`
with real ANSI color wrapping, escaping embedded `\n`/`\e`/`\0` in the *argument*
portion to literal text first [ so a traced arg containing real color codes shows
as literal `\e[...` text, not live codes -- this is why `xsel -o`-copied trace
lines show literal backslash-e, not real control chars: terminal text-selection
never preserves real ANSI codes anyway, so that channel can't distinguish "real
codes present" from "none" either way ]. has an exclusion list (`base.log`,
`base.buffer.add_line` w/ 'zenka' arg, `base.dump_data`) for noise, plus an
unconditional reentrancy guard (`local $p7_devmod_sub_tracing`, landed
`1391ba11b`) as the actual recursion defense -- the name-based exclusion
approach (tried first for `base.s_write`/`base.stdout.raw_fh`) was missed
twice in a row before the guard replaced it; don't add more names to the
exclusion list expecting it to prevent recursion, the guard already covers
that generically. password/key-hiding logic lives here too
(`auth.pwd.success`, `crypt.C25519.*`, etc. get redacted before display).

## thread 4 : redirectable stdout-write target -- LANDED `1391ba11b`

user wants the `base.s_write`-based write target (currently a hardcoded raw
duplicate of the process's own STDOUT) generalized into a reassignable slot,
explicitly citing existing design intent rather than inventing new scope:
`data/md/design/STDIO-MULTIPLEX-PROTOCOL.md` [ dated 2026-06-10, "generic stdio
and fd redirection... expand bit groups with types" -- a full typed-multiplex
wire protocol over unix sockets, 8 type-tags in a 3-bit payload group riding on
`[[topic-stream-framing-protocol]]`'s 3+1 self-synchronizing frame ] and
`data/md/design/VTERM-BUFFER-SPECIFICATION.md` [ explicitly names
`v7.setup_stdout_redir` -- the shm-log-clone system from thread 2, ruled-out but
related -- as "the text-mode prototype" for a much larger vterm/5-of-7-consensus
rendering architecture ].

**agreed scope, explicitly NOT the full multiplex protocol**: extracted the
raw-fd-duplicate-plus-redirect-override logic that previously existed twice
[ near-identically, once in `modules/v7.handler.output_zenka_stdout`, once
inline in `bin/Protocol-7`'s `p7_devmod_sub` ] into one shared module,
`modules/base.stdout.raw_fh`, with an explicit override slot
(`<base.stdout.redirect_fh>`) a future redirect command/feature can
pre-populate, and a lazily-cached default (`<base.stdout.default_fh>`) that's
the original raw-STDOUT-dup behavior, unchanged. both write sites now call
this one utility instead of duplicating the logic. this is deliberately a
small, compatible step toward the documented vision, not an attempt to build
the type-tag protocol now -- user's framing: "we can implement step by step,
prioritizing keeping full existing functionality." **named/scoped as
generic** (`base.*`, not `v7.*`) since `bin/Protocol-7`'s devmod tracer runs
inside *every* traced zenka process, not just v7 -- an early naming instinct
(`v7.raw_stdout_fh`) was corrected for this reason before it landed anywhere
permanent. `base.stdout.raw_fh` itself needed adding to `p7_devmod_sub`'s
reentrancy guard for the same recursion reason as `base.s_write` (see
thread 3) before it worked cleanly.

## committed state

everything in this memory landed in commit `1391ba11b` on `base`:
`v7.zenka.start` (`prio=>0`), `bin/Protocol-7` (devmod tracer write-loop +
reentrancy-guard recursion fix + raw-fd/binmode handling),
`modules/v7.handler.output_zenka_stdout` (relay write-completion-loop, the
temporary diagnostic scan already stripped back out before commit), and the
new `modules/base.stdout.raw_fh`. `modules/source.cmd.get-code-signed`
remains separately uncommitted -- unrelated, pre-existing pending TOCTOU work
from earlier in the same session, see [[feedback-base-prefix-stripped]]'s
sibling context / task history.

#,,,,,,,.,,,,,,,,,,,.,,,.,,.,,.,,,..,,,..,.,.,..,,...,...,...,,.,,.,,,.,.,.,.,

#,,.,,,,,,,,.,..,,..,,.,.,...,,,.,,,,,,,.,,,,,..,,...,...,...,,,,,,,.,.,,,,.,,
#HLHSEOM3H35YKLGKXTAUEAUJTF6B2VHCAVKXDYEDDZDNWVCZ4FM2D37YWDCPJKB4ZWQSAPRFOY7XC
#\\\|E2SM2AULTUMTYHGJZYR5SYE4QZZ36HXVEYQF3AI5DL3DKRGCC43 \ / AMOS7 \ YOURUM ::
#\[7]3DWTTETA3ACCZXOWHJYRYF7EQELJ5Q4P7QKF6JAJQZNIDLQBZQBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
