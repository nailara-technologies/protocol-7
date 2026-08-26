---
name: feedback-p7-module-call-syntax
description: P7 module call syntax — literal and variable forms, ->() rules
type: feedback
originSessionId: de2c98be-b155-442a-9736-a7ad7941c3cb
---
`<[module.name]>` implicitly calls the module with no args — do NOT add `->()` for zero-argument calls.

**Why:** P7 parser adds the implicit call; `->()` is syntactically redundant and gets removed by ncode replace before commit.

**How to apply:** Only use `<[module.name]>->($arg)` or `<[module.name]>->( \%hash )` when passing arguments. For no-arg calls write `<[module.name]>` alone.

Variable form: `<[$var]>->($arg)` resolves to `$code{$var}->($arg)` — no quotes around the variable. Use this when the module name is dynamic. `<[$var]>` alone (no args) also works.

**%data nested access:** `$data{'key.sub'}` is a flat key with a literal dot — WRONG. Use `<key.sub>->` which the parser expands to `$data{'key'}{'sub'}`. For deeper nesting: `<key.sub>->{'leaf'}` → `$data{'key'}{'sub'}{'leaf'}`. Only `%code` uses flat dot keys intentionally.

#,,,,,,.,,..,,.,.,...,,.,,,,,,...,,,.,.,,,..,,..,,...,...,..,,,.,,,.,,..,,,.,,
#6CB56YNAF55DQI4344KRA4D24LWAQB5RYA4QL7VDB5JBLK3574MYDTV5OA7Z3ISKHHIW77WEAPTRO
#\\\|6CKOYM4CAHWUWEDHHQFT4L7TXCH2AYB2Q7SSY3KOSPQ445RY7IO \ / AMOS7 \ YOURUM ::
#\[7]7H5O5C3WMFKKO2YIMP2TPTHR2M6YMHPPCUS6VMLQNXBYZBH55IDQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
