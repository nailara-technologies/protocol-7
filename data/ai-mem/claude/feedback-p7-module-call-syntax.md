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

#,,,.,.,,,.,.,,.,,..,,...,.,.,.,,,...,...,,,.,..,,...,...,,..,,,,,,,,,.,,,,..,
#ZBNNAJE2ABGRFSNE64MCP5OWQEFA5BWEPO6XYR2SVIQP5IRC5ONCJ4QC5X7XQ2ABRQRHJ3327FMKY
#\\\|3ZW5RGGHVGDSCXGZQX7SZJODUAOCSASJKDFQBPBE2J4NZ2TYJM7 \ / AMOS7 \ YOURUM ::
#\[7]37SBAGFCTYNODIO6TZYQWRSJHDJR2K6A26S7PAWL74YGX3ALKYDI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
