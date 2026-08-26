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

#,,,,,,,,,,,.,,,.,,..,,.,,,.,,,,,,...,...,,,.,..,,...,...,.,,,...,,,.,,,,,.,,,
#LBJB5PQE5TRDTCCO62IDDKPUT5OAZBMHAD2NB4UUH5CSSFHNDRK57CFQLDFSUX7HPAXZY3AWJM4EI
#\\\|WSLE4ZQXSDZBEGSLV3INSI4XKAGJGPWGNMLFEMJKH44HIC6RKQI \ / AMOS7 \ YOURUM ::
#\[7]25GYHZZ34RILELSADHVOFQOH3PHBLSPY76YCAKLDOG72623PKGBA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
