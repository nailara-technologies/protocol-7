---
name: feedback-backslash-keyword-is-not-a-reference
description: "'\\<some.data.key>' does NOT take a reference to that data slot — a leading backslash is the loader's ESCAPE meaning 'leave untranslated', so it silently yields a reference to the literal NAME STRING; use explicit \\$data{..} instead"
metadata:
  type: feedback
---

`bin/Protocol-7`'s keyword translation rule is:

```perl
s|(?<!\\)<([\w\-:]+\.[\w\-\.:]+)>| ... $data{'..'}{'..'} ... |
```

The `(?<!\\)` negative lookbehind means **a leading backslash is the
ESCAPE** — it is how you write a literal `<some.thing>` that must not be
translated. It is NOT "take a reference to this slot."

So `\<user-edit.form.dirty>` does not become
`\$data{'user-edit'}{'form'}{'dirty'}`. It stays untranslated and Perl
evaluates it as a reference to the literal string
`user-edit.form.dirty`.

**Correct form — write the reference out explicitly:**

```perl
my $buffer_ref = \$data{'user-edit'}{'form'}{'input_buffer'};

<[event.add_var]>->(
    { 'var' => \$data{'user-edit'}{'form'}{'dirty'}, ... } );
```

Precedent: `jobqueue.event.register_job_queues` passes
`\$counters->{$queue_name}` — a plain Perl ref, never a `\<keyword>`.

## why this is worth remembering

It fails **silently**, and how it fails depends entirely on what consumes
the ref — both variants happened in one session (2026-08-12):

- **loud:** `editor.input.next_key` was handed the bad ref and cheerfully
  decoded the characters of the literal name, typing
  `user-edit.form.input_buffer` into the form field 21 times. Obvious
  within seconds.
- **silent, and the dangerous one:** `base.event.add_var` registered a
  watcher on a reference to a string that nothing ever writes. It simply
  never fired — the interactive form accepted keystrokes and never
  repainted, with no error anywhere. This shipped in a commit and was only
  caught later by the no-tty driver.

**How to apply:** any time you need a reference to a `%data` slot —
`event.add_var`, a buffer passed by ref, anything taking `\$x` — write
`\$data{..}{..}` explicitly. Treat a `\<...>` in a diff as a bug unless
the intent really is a literal untranslated string. Grep for `\\<[\w-]+\.`
when auditing.

Related: [[feedback-eval-code-no-angle-brackets]],
[[feedback-comp-regex-qr-delimiter-escaping]].

#,,,.,,.,,,..,.,.,..,,.,,,,,,,,.,,,.,,,,,,..,,..,,...,..,,..,,,,,,..,,,.,,,,,,
#S24IUA5JO2NW7KTTAXRVQVRDVMUXPQGII4VXR7UB3ZZCX6NHBQQ3QJ6EAOZVDTEZ6ODOHS2Q4MUIA
#\\\|3KFLQKCTGKKJYIHBQ3JXGFETJR2ZS6M7NFDDO4ETLPASYK5VS7Y \ / AMOS7 \ YOURUM ::
#\[7]SE6DSOSKB5PHHMSV4VW3SNIM6SP6I7SQ6NIGY7WAFLT5YCQZ4EBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
