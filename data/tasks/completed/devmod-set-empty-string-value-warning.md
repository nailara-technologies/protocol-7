# devmod.cmd.set warns on empty-string value

## status : fixed

## what happened

`p7c <zenka>.set <key> ''` (attempting to set a config value to an
empty string via devmod) produces:

```
:. audio   : : warn : undef value $value_content in substitution (s///)
:. audio   : :.    .: [devmod.cmd.set:13]
```

hit while live-testing `audio.cfg.post_process` — worked around at the
time by using a `'none'` sentinel string instead of `''` for
"no post-process" (see `audio.post_process.rotation_stack.v1` /
`audio.finalize_decode`'s dispatcher). the sentinel pattern is being
kept regardless (it's clearer at the call site than an empty string
would be), but the underlying warning is now fixed at the source.

## actual root cause

not an empty-string-vs-undef distinction in arg parsing as first
suspected — `src/devmod.cmd.set` ran its `s|^'(.*)'$|...|`
quoted-value substitution on `$value_content` (line 13) *before*
checking whether a value was supplied at all (that check was further
down, at the old line 25). when the command has no value token at all
(e.g. an empty-string shell arg that collapses away before reaching
`$call->{'args'}`), `split` never produces a second field, so
`$value_content` is genuinely undef going into the regex — triggering
the warning.

separately, `$set_keystring_ref->{'r-data'} eq $value_content` (the
"is this a no-op" check) had the same class of bug: a freshly-resolved
key with no prior value has `r-data` undef, and `eq` on an undef
operand warns too (a different warning than the one reported, but same
root pattern).

## fix

reordered `devmod.cmd.set` so the "no value supplied" early-return
happens before the quoted-value substitution touches `$value_content`.
guarded the no-op `eq` check with `defined $set_keystring_ref->{'r-data'}`
first. for the two log lines that print the prior stored value, added a
`$prev_display` that renders a quoted string when defined and an
unquoted `[UNDEF]` marker otherwise (matching the project's existing
`// qw| [UNDEFINED] |` idiom, e.g. in `base.buffer.add_line`) — keeps a
genuine undef visually distinct from a value that happens to just be an
empty string.

live-verified via `p7c audio.set` against the audio zenka: missing-
value, update, no-change, and reset-to-`'none'` paths all clean, no
warnings.

#,,..,,,.,,..,.,.,.,.,,,,,...,,,.,,,.,.,.,...,..,,...,..,,...,,,,,,,,,.,.,,,,,
#CFTBGM2CT2P7Q2LE7OAS7VXDL4BFBI7NN3IR7ZULXTWYRB6JKDWTK3R57T3Q6DV5R55LFQUB65YF2
#\\\|D3OXPQ44IMVWUI27ESWYKZD6NXICZFO3RMM7MILLBHYEMRXQPTG \ / AMOS7 \ YOURUM ::
#\[7]UDN3P33FWQUQRQ7XVEOF2XAOQTQP7JMBQAU7ADFDTAHRAADUISBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
