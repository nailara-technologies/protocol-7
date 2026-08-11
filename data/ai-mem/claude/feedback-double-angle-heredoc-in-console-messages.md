---
name: feedback-double-angle-heredoc-in-console-messages
description: "a quoted token directly after '<<' in a p7 module (e.g. print \"\\n << 'start' needs a terminal\") parses as a heredoc opener and silently breaks the whole module -- reported as 'cannot modify glob in scalar assignment .. at EOF' pointing at an unrelated line"
metadata:
  type: feedback
---

Protocol-7 console messages conventionally use the `<< message >>` bracket
style:

```perl
print "\n  << no cube session — cannot reach the users zenka >>\n\n";
```

That is fine. What breaks is a **quoted token directly after the `<<`**:

```perl
print "\n  << 'start' needs a terminal "        ## <-- breaks the module
    . "[ use 'show-form' when piped ] >>\n\n";
```

`<< 'start'` reads as a heredoc opener with a single-quoted delimiter
(Perl allows whitespace before a quoted heredoc delimiter), so everything
after it is swallowed as heredoc body.

**Why it is hard to spot:** the reported error names a plausible-looking
but unrelated line and then says `at EOF` —

```
: :  cannot modify glob in scalar assignment at
  : .. user-edit.console.start line 38, at EOF
::[ broken zenka command 'start' ]
..: success on 207 subs, 1 broken., `:|
```

line 38 was an ordinary `<user-edit.form.username> = $username;`
assignment, four lines *below* the real cause. Chasing the named line
finds nothing wrong with it.

**How to apply:** never put a quoted word immediately after `<<` in a
console message — write `<< the start command needs a terminal >>` or
`<< command 'start' needs .. >>`, i.e. keep at least one unquoted word
between `<<` and any quote. The same applies to `<<` followed by a bare
identifier that could read as a delimiter.

**Also worth knowing generally:** a single broken module does not stop the
zenka — it loads, logs `N broken`, and lists the command as
`<< broken command >>` in its console command list. So a broken module can
easily go unnoticed if you only check that the zenka starts. After adding
console modules, grep the start-up output for `broken` explicitly rather
than trusting a clean-looking run.

#,,,.,.,,,,.,,.,,,..,,.,,,..,,,,,,,..,,,,,...,..,,...,...,,..,.,.,,..,,,,,,..,
#W5PLYX3QPDJ7OOSXWNIMFUIB3FTVJLLNSG2VQZZXCIT7SYQIQ26KJPJCVNX4657WLQPXOLK3ZYWJQ
#\\\|55DRPVDQ6H6EJSJK7CXI6BNU7VFOTYUFAGREBDQZSUHOGIOJNSZ \ / AMOS7 \ YOURUM ::
#\[7]YMXFDMTV22KXGHNI4PR3H3BRQRLHCFW5LYGN4MJL2NLACPNFZCCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
