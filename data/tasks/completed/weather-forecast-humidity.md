## [:< ##

# name  = task: weather — re-enable humidity in forecast extraction
# descr = check openweathermap API and restore humidity field

## context

`src/weather.parent.extract_forecast` disables humidity extraction:

```perl
# 'humidity' is disabled as it always returned '0%'
```

this was likely true for an older openweathermap API response format. the API
may have changed since then, and humidity is a useful forecast field.

analysis reference: `data/md/development/DEGRADED-FEATURES-AUDIT.md`

## signatures note

do not add signature stubs. run `bin/Protocol-7 sourcecode update-signatures`
when done.

---

## fix 1: inspect live API response

trigger a weather fetch and examine the raw JSON:

```bash
./bin/Protocol-7 weather cmd.update_forecast
```

look at the forecast data structure (likely stored in a cache file or logged).
check whether `humidity` is present and non-zero in the `list` elements.

## fix 2: re-enable the field

if humidity data is valid, uncomment or re-add the line in
`src/weather.parent.extract_forecast`:

```perl
'humidity' => $element->{'humidity'},
```

ensure the field is also included in any downstream consumers (display
templates, `weather.cmd.show_forecast`, etc.).

## fix 3: test

verify that the forecast output includes humidity and the value is reasonable
(e.g., `45%` rather than `0%`).

## success criteria

- [ ] live API response confirms `humidity` field exists and is non-zero
- [ ] `weather.parent.extract_forecast` includes humidity in the forecast hash
- [ ] downstream display commands show humidity correctly
- [ ] signatures updated with `bin/Protocol-7 sourcecode update-signatures`

#,,,,,.,,,,,.,..,,,.,,.,,,,..,.,.,,.,,...,...,..,,...,...,...,,,.,,.,,,,.,...,
#7XLWIXCDDEUS6YPIH5FR5GLUPH3UI2LTBCZUDAHFNUYHKYWLXZTDTXCCNEXCFFTXR6WVPFZQHUNK4
#\\\|U6LDDJX56HEEKE24MT4QKEVFGBCV6RCJPLS3JYX2UOL7KIR2VNH \ / AMOS7 \ YOURUM ::
#\[7]HFFQVTHPYZNVGT6U6LRSBAHE6CKXV3E3Z24LFY2JIVVFSK7VROCQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
