---
name: arg-calling-convention
description: P7 modules using $ARG as input must use shift // $ARG when called with explicit Perl arguments
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 4ffce75b-8148-4209-bf51-e550e77dd5ce
---

when a P7 module uses `my $x = $ARG` to receive its input, and it is called
with an explicit Perl argument like `<[module.name]>->($value)`, the `$value`
is in `@_` — NOT in `$_` / `$ARG`. `$ARG` is only set in contexts like
`for`, `map`, `grep` blocks where Perl sets `$_` automatically.

**Why:** discovered session 52 — index.feed.file was receiving `undef` for
every file path because the callback called `<[index.feed.file]>->($file)` but
the module used `my $path = $ARG`. All 415 files silently skipped.

**How to apply:** any module that may be called both ways should use:
```perl
my $x = @ARG ? shift : $ARG;
```
this handles both: explicit arg call (`@ARG` populated) and `$_`-context call
(grep/map/for — `$ARG` set, `@ARG` empty).

affects: index.feed.file, index.ingest, index.deduplicate, index.feed.dir
all fixed in session 52 with `my $x = @_ ? shift : $ARG` pattern.

see also: [[arg-regression]] — related issue where local LLM reverts $ARG→$_

#,,..,,,.,,.,,.,,,...,,,,,.,,,.,.,,,.,,.,,...,..,,...,..,,...,..,,.,.,..,,...,
#VF7NK3BP6K2C5DSB2PIG224TOAVU4I2Z6EPT7PRFBBDAJXI7OTIIMV42QBBKINGNRGJEO2SPQGRXI
#\\\|ZEJH3ZPA5XDCRSXI7EYX65FCGW3O6K7CCSWKXTHKNKQB4LX25DA \ / AMOS7 \ YOURUM ::
#\[7]5EUKDKTYVQ5POY47UETSV42IWHF6QHTRL3TAVE4CO7JVKYBEVIDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
