## [:< ##

# name  = task: sourcecode — re-enable source header validation
# descr = restore $expect_valid_code_header in source.cmd.get-code-signed

## context

`src/source.cmd.get-code-signed` contains a hardcoded disable of the source
code header validation:

```perl
my $expect_valid_code_header = FALSE;    ## temporarely disabled ##
```

when `TRUE`, this variable causes the routine to reject files that do not begin
with the protocol-7 header (`## [:< ##\n`). disabling it weakens the signature
system's integrity check because unsigned or malformed files can pass through
`get-code-signed` silently.

analysis reference: `data/md/development/DEGRADED-FEATURES-AUDIT.md`

## signatures note

do not add signature stubs. run `bin/Protocol-7 sourcecode update-signatures`
when done.

---

## fix 1: verify all modules have valid headers

before enabling globally, ensure no module in `src/` lacks the header:

```bash
for f in src/*; do
    head -c 10 "$f" | grep -q '^## \[:< ##' || echo "missing header: $f"
done
```

if any file is missing the header, either add the header or exclude that file
from validation (e.g., non-source files in `src/`).

## fix 2: enable validation

file: `src/source.cmd.get-code-signed`

change:
```perl
my $expect_valid_code_header = FALSE;    ## temporarely disabled ##
```

to:
```perl
my $expect_valid_code_header = TRUE;
```

## fix 3: (optional) make it configurable

if some callers need to skip validation, accept a command parameter:

```perl
my $expect_valid_code_header = $call->{'expect-header'} // TRUE;
```

this preserves security by default while allowing exceptions.

## success criteria

- [ ] `$expect_valid_code_header` set to `TRUE` (or parameterized with `TRUE` default)
- [ ] all modules in `src/` verified to have valid `## [:< ##` headers
- [ ] `source.cmd.get-code-signed` rejects files without headers
- [ ] signatures updated with `bin/Protocol-7 sourcecode update-signatures`

#,,,,,..,,.,,,...,,..,..,,...,.,.,,..,..,,...,..,,...,...,.,,,,..,,..,.,,,..,,
#LKHG77EKTWMARZWYKDAFKNNJWRDNRWUC2XBUDWPL7W3MIMSJ5JI5HIKKOWSBT76KSJICGMF4JKM3A
#\\\|TLRWECURJIOOJ32HY2PQR4XBCPRYM2GR2I6UMP4QYDEQH6MMJFS \ / AMOS7 \ YOURUM ::
#\[7]5NZQAY3IRCVLESQYJNGTSCCVS6O3F6MOLZXCMDGSXXKTLD34IUDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
