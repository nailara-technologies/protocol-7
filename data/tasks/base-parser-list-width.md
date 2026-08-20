## [:< ##

# name  = task: base.parser.list — resolve remaining width alignment bug
# descr = fix column width math for ex0:ex1 key patterns

## context

`src/base.parser.list` has carried a TODO since at least 2016:

```perl
# todo = fix alignment [width] bug. [ex0:ex1 case]
```

a partial fix was applied in commit `a6cb84fb6` (2026-03-09) for the `<key>:`
prefix case, but the `ex0:ex1` case (nested key names with colons) may still
misalign. the module is used by list commands across many zenki, so width bugs
affect multiple UIs.

analysis reference: `data/md/development/DEGRADED-FEATURES-AUDIT.md`

## signatures note

do not add signature stubs. run `bin/Protocol-7 sourcecode update-signatures`
when done.

---

## fix 1: reproduce the bug

write a small test script that calls `base.parser.list` with a data hash
containing keys in the `ex0:ex1` format (two colon-separated segments without
the `<key>:` prefix):

```perl
my $data = {
    'foo:bar' => { 'col1' => 'a', 'col2' => 'bb' },
    'baz:qux' => { 'col1' => 'ccc', 'col2' => 'd' },
};
my $out = <[base.parser.list]>->('test', 'key', undef, ['col1', 'col2'], undef, undef, undef, undef);
print $out->{'data'};
```

inspect the output for misaligned columns.

## fix 2: audit width math

the critical lines are around:
- `$max_len{$key_name} = length($key_name_str) + $spacing + 3;`
- `$max_len{$key_name} = length($filtered_val) + 4 if ...;`
- `$max_len{$last_d_key} -= 2;`
- `$table_width-- if $table_width >= 80;`

ensure these calculations account for:
- `pack("A$max_len")` padding
- the `" : "` and `" :."` prefix/suffix added to headers
- the trailing space added to values

## fix 3: test with all key patterns

test cases:
- plain keys (`name`, `size`)
- `<key>:` prefix (`<key>:name`)
- `prefix:suffix` (`foo:bar`)
- mixed in the same table

## success criteria

- [ ] bug reproduced with a test script
- [ ] width math corrected for `ex0:ex1` keys
- [ ] all four key patterns align correctly
- [ ] no regressions in existing list commands
- [ ] TODO comment removed or updated
- [ ] signatures updated with `bin/Protocol-7 sourcecode update-signatures`

#,,,.,..,,,..,,..,,,,,.,,,,..,..,,..,,.,,,..,,..,,...,...,...,,,.,,.,,,,.,,.,,
#37HEVT67SJFXK53KOHOE7LBIO4BEOLGQSZI4SS2S66IWBAY3CMKUTTUJIR6XYJGYL56OLK44LL34G
#\\\|CPMJHIGIJHNZCRC43SC4EUAZD556QO6GAGXQOSNPFYULCE2XU2R \ / AMOS7 \ YOURUM ::
#\[7]PRDLFGEFUPJDPSYGCFBGRM6PLQBCNQY4CXZWU5E7VNPRGIM4ZOAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
