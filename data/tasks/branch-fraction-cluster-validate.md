## [:< ##

# task: validate branch.calc.fraction.* + branch.cluster.*

## background

these two namespaces were implemented by kimi in session 49 but
kimi_continue timed out at 47 minutes before the sessions could confirm
clean completion. the timeout has since been raised to 77 minutes.

the modules exist on disk. two known risk patterns from the timeout:
- `FALSE` bareword used instead of numeric 0 / undef
- `use` / `require` statements that do not match p7 module conventions

## signatures note

do not modify or regenerate AMOS7 signature lines. leave them untouched.
all module files end with a 4-line #,,, / #ABC / #\\\ / #\[7] footer —
leave those lines exactly as they are.

## task

validate all 18 module files listed below. for each:

1. read the file
2. check for: `FALSE` bare word, `TRUE` bare word, `use ` / `require `
   statements, `$_` instead of `$ARG`, `@_` instead of `@ARG`,
   `sub {` declarations (none allowed — the file IS the sub), and any
   `die` call (return undef instead)
3. fix any issues found in-place using the p7 `replace_in_file` tool
4. do NOT touch signature lines at the end of each file

## branch.calc.fraction.* modules (10 files)

```
modules/branch.calc.fraction.period
modules/branch.calc.fraction.period_length
modules/branch.calc.fraction.terminates
modules/branch.calc.fraction.remainder_seq
modules/branch.calc.fraction.parent_lookup
modules/branch.calc.fraction.reverse_scale
modules/branch.calc.fraction.coupling_find
modules/branch.calc.fraction.symmetry
modules/branch.calc.fraction.ring_position
modules/branch.calc.fraction.prefix_entropy
```

## branch.cluster.* modules (8 files)

```
modules/branch.cluster.address
modules/branch.cluster.ring_position
modules/branch.cluster.layers_list
modules/branch.cluster.gate_node
modules/branch.cluster.family
modules/branch.cluster.mirror
modules/branch.cluster.validate
modules/branch.cluster.register
```

## acceptance

after fixes:
- `p7c branch.calc.fraction.period 7 11` returns `"63"`
- `p7c branch.calc.fraction.period 5 11` returns `"45"`
- `p7c branch.calc.fraction.terminates 13 5` returns true
- `p7c branch.calc.fraction.reverse_scale 13 5` returns `30`
- `p7c branch.cluster.family task` returns `076923`
- `p7c branch.cluster.family intent` returns `153846`

if any acceptance check fails, read the relevant module, diagnose,
and fix it before marking the task complete.

## dispatch

kimi_dispatch this file as the prompt. previous sessions timed out
at 47min — the new timeout is 77min, which should be sufficient
for 18 files.

## style

- lowercase comments, `[ word ]` bracket annotations
- `$ARG` / `@ARG` — never `$_` / `@_`
- no `die` — return undef + base.logs on error
- no `sub { }` wrappers

#,,.,,.,.,.,.,,,,,,.,,.,.,.,.,..,,.,.,,,,,.,,,..,,...,..,,...,.,.,.,,,,,.,,.,,
#IDQQRIR5AQ46PSLEWOIAW5UNQO2GIRSEV7Q6SZMKWNNC6CXZJXPCROJCECUFR6ES7RLFHA3T23LLQ
#\\\|YJAVUNCDNYRT2NSI3POZ2VRK7PWAB3742UYFCRFQKW2BJG2HSVO \ / AMOS7 \ YOURUM ::
#\[7]2BMJCBLQOPBSEH4FX5KIB6PJ4MXMPEILWRVS2XSWB7TMBBY474DY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
