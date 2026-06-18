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

#,,,,,...,,,.,.,,,,,,,..,,.,.,,,.,,,.,,.,,,,,,..,,...,...,...,.,,,,.,,.,,,.,.,
#3OMCPR4T4UW7PTEQQDQHAG3Z5TPGHLE7QP327IWBLRKJSKO4MH7ZTR2WS7DZ3PVZUSAUHGDQVRJQW
#\\\|7ZZPLKRUIWJQK3GH6L4MP3HAT4NI3L66NUHLSMNZDUFKWGYYMEM \ / AMOS7 \ YOURUM ::
#\[7]266RGBDWOH2HZLK5G2P4CHJO47I5BUJRF6XQ2CKQDVWXC7NXOMAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
