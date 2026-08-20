## task: iteration loop e2e test

Write a minimal P7 module `src/test.iteration.hello` that demonstrates
the iteration loop is working end-to-end.

### module spec

```
# name  = test.iteration.hello
# descr = iteration loop test module [ hello ]
```

The module should return a greeting that includes the word "hello" and the
current ntime timestamp:

```perl
my $ts = <[base.ntime.b32]>->();
return { 'mode' => 'size', 'data' => "hello from test.iteration [ $ts ]" };
```

Write this module to `src/test.iteration.hello` using `write_new_file`.
Do NOT add signature stub lines.

### iteration criteria

iteration: true
criteria:
  - id: file_exists
    check: file_exists
    path: src/test.iteration.hello
    weight: 1.0
    fixable_by: model
  - id: has_hello
    check: content_contains
    path: src/test.iteration.hello
    pattern: "hello"
    weight: 1.0
    fixable_by: model
  - id: has_ntime
    check: content_contains
    path: src/test.iteration.hello
    pattern: "base.ntime.b32"
    weight: 0.5
    fixable_by: model
  - id: no_stub
    check: content_not_contains
    path: src/test.iteration.hello
    pattern: "#,,.,,,"
    weight: 0.5
    fixable_by: model

### signatures note

Do NOT copy or invent AMOS7 signatures. Leave the file clean.
The fake single-line stub `#,,.,,,...` blocks signing — never add it.

#,,,,,,,.,.,.,,..,,..,,.,,,,.,.,.,,.,,,.,,,..,..,,...,...,,..,,.,,..,,,,.,,.,,
#SXY7EAGSQTBGOUCYVBAJVL55GTVXSCZRTW3Z7JFDRK3KXPJ4WFBVDX3JXQ7XW7PJFCR3XGHM6BMJM
#\\\|LXDQ6LRJ4H56QM62M3W4LO6DKMO52POPZWX4T2T3FUBLW6IM23S \ / AMOS7 \ YOURUM ::
#\[7]UMPHAANCL466UD3VZP65SZZPQFRHHGNEDSEXKBRB72KF42YTX4AQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
