## task: iteration loop e2e test

Write a minimal P7 module `modules/test.iteration.hello` that demonstrates
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

Write this module to `modules/test.iteration.hello` using `write_new_file`.
Do NOT add signature stub lines.

### iteration criteria

iteration: true
criteria:
  - id: file_exists
    check: file_exists
    path: modules/test.iteration.hello
    weight: 1.0
    fixable_by: model
  - id: has_hello
    check: content_contains
    path: modules/test.iteration.hello
    pattern: "hello"
    weight: 1.0
    fixable_by: model
  - id: has_ntime
    check: content_contains
    path: modules/test.iteration.hello
    pattern: "base.ntime.b32"
    weight: 0.5
    fixable_by: model
  - id: no_stub
    check: content_not_contains
    path: modules/test.iteration.hello
    pattern: "#,,.,,,"
    weight: 0.5
    fixable_by: model

### signatures note

Do NOT copy or invent AMOS7 signatures. Leave the file clean.
The fake single-line stub `#,,.,,,...` blocks signing — never add it.

#,,..,,.,,,..,,..,.,.,..,,..,,,..,.,,,...,...,..,,...,...,.,,,...,,,.,,,.,,,.,
#OX3EYXWYDNQYERHXQZ2BHCYTUGE7TIP37AMGJN6XZTYFXI4PYJWS3ULIBJBSYKOSWMYYZEUKQJ7DE
#\\\|KRWNJXFSMXSAHZQ37XEHSPDNAYL2KHOMB7YUP2QBMNUQEDONXMO \ / AMOS7 \ YOURUM ::
#\[7]NF4XM3T5DW7HHL5JBLHUUKLWOLGII6VJL2PIZC57RZKDCAT4OWDQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
