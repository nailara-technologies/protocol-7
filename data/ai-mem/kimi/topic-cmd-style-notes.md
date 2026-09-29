# Command Return Style Notes

## Deferred / async returns

A `qw| deferred |` return keeps the command route open and lets the module reply
later after collecting data.  The event loop remains active and the route id is
remembered.

Correct form:

```perl
return { 'mode' => qw| deferred | };
```

Do **not** add a `'data'` key to a deferred return.  The data is supplied by the
later async reply.

## Args access

Always default args:

```perl
my $args = $call->{'args'} // '';
```

After adding `// ''`, a `not defined $args` check becomes dead.  Use `!length($args)`
instead.

## Mode values use `qw| |`

Use `qw| size |`, `qw| true |`, `qw| false |`, `qw| deferred |` — not quoted
strings.

## Templates updated

- `data/yaml/context-templates/cmd-format-audit.yaml`
- `data/yaml/context-templates/cmd-style-fix.yaml`

Both now explicitly document the deferred-return exception.

## `$call` and `$reply` are pre-declared in `.cmd.` modules

The compiled-in `.cmd.` header already declares `$call` [ the network args ]
and `$reply`. Never write `my $reply = ...` [ or `my $call` ] in a `.cmd.`
module : it masks the earlier declaration and warns at source update
[ hit in `v7-zenki.cmd.pressure`, 2026-09-29 ]. The header presets `$reply`
to a `false` 'error during invocation' reply and the footer returns it when
the module ends without an explicit `return` -- so either fill
`$reply->{'mode'}` \ `$reply->{'data'}` and fall through, or
`return { mode => .., data => .. }`. Use `$text` \ `$out` for a text buffer.

#,,..,,.,,..,,,,,,,..,...,.,.,,.,,...,.,,,,,,,..,,...,..,,.,,,,.,,.,.,.,,,,.,,
#V47GGOIC252SYWIOCGSZOPCB6DGJ2ZHX6EBI2R5VJJ4OY3YO3AH26PV6IHOS3QZO5WGUPBOUDMNJ4
#\\\|VAMAY5XRZROSILQKRJEMGVBE37FKLL2JCS3NQYS3T5MBTJVASMW \ / AMOS7 \ YOURUM ::
#\[7]ADPXIFI5IBFAK46TCQWXWLVZFDWCFGB7JTJAKDASI43CCP555SAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
