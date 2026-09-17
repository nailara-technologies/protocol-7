---
name: feedback-qw-multiword-list-flattening-in-list-context
description: qw| word1 word2 | is a LIST (one element per word), not a single string -- using it for a multi-word phrase inside a ternary that sits in list context (e.g. a function argument) silently flattens the words into separate positional arguments, shifting everything after them out of alignment. Use qq|word1 word2| (no space padding, per project convention) instead. Recurred 2026-09-17 in a kimi-dispatched fix, caught live via a real warning
metadata:
  type: feedback
---

`coding.spawn_inference_server` had:
```perl
<[base.logs]>->(
    1, '... %s : ... %d ... %d [%s]',
    ( $backend eq qw| cpu | ? qw| cpu backend | : qw| partial gpu offload | ),
    $ctx_size, $configured, $safe->{'explanation'}
);
```
`qw| cpu backend |` is the two-element list `('cpu','backend')`;
`qw| partial gpu offload |` is three elements. The whole
`<[base.logs]>->(...)` call is list context, so whichever branch the
ternary picks flattens directly into the argument list -- the gpu
branch's 3 words displaced `$ctx_size`/`$configured` by two positions,
landing the literal string `'gpu'` in a `%d` slot. Surfaced live as
`argument 'gpu' isn't numeric in base.logs` + `UNDEF LOG MSG` right
after the fix that introduced it was live-verified and committed --
the live verification exercised the *safety math*, not this specific
log line's argument count, so it didn't catch it.

**Why this is a recurring risk, not a one-off typo**: this codebase's
own dominant style is `qw|word|` for single-word bareword-style scalar
constants (`qw| cpu |`, `qw| gpu |`, `qw| minimum |`, etc. -- correct,
because a ONE-word `qw//` list has exactly one element, indistinguishable
in effect from a plain string). The mistake is reaching for the same
`qw|...|` habit for a MULTI-word phrase that's meant to be a single
scalar -- syntactically identical-looking, semantically a list. Both
Kimi and a human editing this codebase are equally likely to make this
exact substitution, precisely because the surrounding code trains the
eye to expect `qw|...|` for this kind of string.

**How to apply**: whenever writing (or reviewing) a `qw| ... |` in this
codebase that contains MORE than one space-separated word and is being
used as a scalar (not deliberately building a list/array), that's the
bug. Fix is `qq|word1 word2|` (no space padding, per this project's own
convention for a multi-word scalar -- confirmed directly by the user),
not a plain `'...'`/`"..."` string (functionally equivalent, but the
project prefers the quote-like-operator style). The one legitimate
multi-word `qw|...|` in this same file,
`qw|  --host  127.0.0.1  |` inside `my @cmd = (...)`, is correct
specifically because that array assignment WANTS multiple elements
(`--host` and `127.0.0.1` as two separate argv entries) -- the tell is
whether the surrounding context wants a list or a scalar, not the
presence of `qw//` itself.

## related

[[project-wsl2-shared-ram-constrains-concurrent-inference]] -- the
incident that motivated the fix this bug was introduced in
(`data/tasks/completed/coding-gpu-partial-offload-context-safety.md`)

#,,..,,.,,..,,,,.,,,,,,,.,.,,,,,.,,,,,..,,,.,,.,.,...,...,..,,..,,,,,,,,,,.,.,
#IAFTWRYXCU6TOJRT6RBP6CZIKCMXSXYYXTMHOM3CSZPTQHILOYIHHCJ3EX2MVUXKPM72UVMLBAE5W
#\\\|DOEVPRHULJLJVPY25NCM5FX4FRW4E7TX2X6JE27M5NY3JYZN4XN \ / AMOS7 \ YOURUM ::
#\[7]AM3IIEWKU7ZWRTF2SZ2QNNS3QOESHJGQHTZTOQARD44ADK2WGQBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
