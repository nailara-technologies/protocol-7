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

#,,.,,,,.,.,.,,,,,..,,.,,,.,.,,.,,,,,,.,.,,,.,..,,...,...,...,,,.,,..,...,,..,
#Q6KIWCWPO6CMJLPLMR7ER5Y7XARTPMLDGUG5TCBW2QYR2CGWCFXCZWFVY5GH2NRCUJ777ZHTRLNWU
#\\\|NZ2GUDS7NGR27KMFD74DSRON6MPT53AFVJJXC663UMRBPQE67VM \ / AMOS7 \ YOURUM ::
#\[7]XYQ5FS564VCOD6MOEI727TCTZXFPOD6H3OMZGQUERKJQT6SA5WAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
