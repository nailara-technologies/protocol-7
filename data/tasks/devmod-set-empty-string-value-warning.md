# devmod.cmd.set warns on empty-string value

## what happened

`p7c <zenka>.set <key> ''` (attempting to set a config value to an
empty string via devmod) produces:

```
:. audio   : : warn : undef value $value_content in substitution (s///)
:. audio   : :.    .: [devmod.cmd.set:13]
```

hit while live-testing `audio.cfg.post_process` — worked around by using
a `'none'` sentinel string instead of `''` for "no post-process"
(see `audio.post_process.rotation_stack.v1` / `audio.finalize_decode`'s
dispatcher), so this isn't blocking anything right now.

## likely cause

`devmod.cmd.set` (around line 13) presumably does a substitution using
the incoming value as part of a regex/replacement without guarding for
an empty-but-defined string being passed through as unset/undef
somewhere in the arg-parsing path.

## next step

locate `modules/base.devmod.*set*` (or wherever `devmod.cmd.set` lives),
find the `s///` at the line the warning names, and make it handle an
explicit empty-string value distinctly from an absent/undef one.

#,,,.,,,.,,,.,,..,,.,,.,.,...,...,,.,,,..,...,..,,...,...,..,,,,.,,..,,,.,,..,
#UOLEMQZZTQ5M3IPE42F7PCMLOFZZ4HDLVPEMVYIZOA7MPYYESRI65HNPVC3JSTVOMLG4T2JJ2EVYS
#\\\|WIR47C26SIHGWTHDQXHSMMAVV23DYRQNRMXNKJZ3XM274PRNXNW \ / AMOS7 \ YOURUM ::
#\[7]PYX45ZXJYCINT5KZ6LZSEQ4VP4VUBZ22OKAAFUWJ4AAAQ7UESOBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
