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

#,,,.,,,,,,.,,.,,,.,.,,,.,,,,,,,.,,,.,,,,,,,,,..,,...,...,..,,..,,,..,...,...,
#XRUAIRWFJQRAORCDM2KTEUUOHWSB5ZWMVM6DFZZMSJAS2JTZAHJTNNIMSNTJJYCGUOW7COG2KGTZ6
#\\\|XCJTOJ5RRDMABJD4G2ARQEZF55ZSOQOGGS333YMM6JLAJG7KB3V \ / AMOS7 \ YOURUM ::
#\[7]HXQUE6FECU3RUW5ZID4OQYTQJXADYMAQMW6P52KPJCVRSD5SG2DY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
