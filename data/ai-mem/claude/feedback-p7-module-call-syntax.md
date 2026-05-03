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

#,,,,,,,.,,,,,.,.,...,,..,..,,..,,,..,.,.,,.,,..,,...,...,..,,,,,,,.,,,,,,.,,,
#VUBDY74YOIPGL45PQU63CYL6K5NA654AC2JAY4VQSXUJQAMT2UQ5FFKCGY6T6OO6RQMUG3MGDSKBM
#\\\|Y43HQLRXU47252YD7F3EAHXE4I5ZBIA3FNOTUCMWKZUUS5QIVQC \ / AMOS7 \ YOURUM ::
#\[7]G3SIMPQAT26BBX4ZBYV7A3FCO7BC3JDLMBUUAAJEZIVSLWQH3CDA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
