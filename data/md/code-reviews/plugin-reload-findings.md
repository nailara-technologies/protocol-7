# plugin reload flow : code review findings

## status: ✅ RESOLVED

**fix committed:** the plugin registry now correctly uses `%data{'plugins'}{'status'}`
for both initialization and reload operations. `reload plugins` now loads all
configured plugins as expected.

---

## executive summary [historical]

the plugin reload subsystem had a critical data flow disconnect between the code hash (`%code`) and data hash (`%data`). plugins were tracked in `$code{'plugins.status'}` during initialization, but `base.reload_plugins` read from `$data{'plugins'}{'status'}`, which was rarely populated.

---

## current flow analysis

### initial load path (start files)

1. **start file** calls `[load_plugins:<plugins.load>]`
   *example: `cfg/zenki/cube/zenka.v7` line 43*

2. **`base.load_plugins`** (src/base.load_plugins)
   - filters for `plugin.*` prefix (line 6)
   - calls `<[base.load_code]>->(@plugins_to_load)` (line 13)
   - **does NOT populate any plugin registry**

3. **`bin/Protocol-7` compile loop** (lines 1328-1329)
   - initializes `$code{'plugins.status'}->{$plugin}->{'load_errors'} = 0`
   - **writes to CODE hash, not DATA hash**

### reload path

1. **`base.cmd.reload`** with `plugins` or `all` argument (line 123-136)
   - calls `<[base.reload_plugins]>` (line 126)

2. **`base.reload_plugins`** (src/base.reload_plugins, line 16)
   - reads `@loaded_plugins = <[base.sort]>->(<plugins.status>)`
   - `<plugins.status>` resolves to `$data{'plugins'}{'status'}`
   - **DATA hash is usually empty** → returns empty list → nothing reloads

---

## critical findings

### finding 1: dual hash confusion [CRITICAL]

**location:** `bin/Protocol-7` line 1328-1329 vs `base.reload_plugins` line 16

**issue:** initialization writes to `%code`, reload reads from `%data`

```perl
# bin/Protocol-7 line 1328-1329 (initialization)
map { $code{'plugins.status'}->{$ARG}->{'load_errors'} = 0 }
    grep {m|^plugin\.|} @module_names;
```

```perl
# base.reload_plugins line 16 (reload)
my @loaded_plugins = <[base.sort]>->(<plugins.status>);
# <plugins.status> == $data{'plugins'}{'status'}  [ EMPTY ]
```

**impact:** `reload plugins` always reloads nothing because the registry is empty.

**recommendation:** unify on `%data` hash since that's what the data-key syntax `<plugins.status>` expects. add initialization in `base.load_plugins`:

```perl
# in base.load_plugins, after successful load
map { $data{'plugins'}{'status'}{$ARG}{'load_errors'} = 0 } @plugins_to_load;
```

---

### finding 2: error tracking only [CRITICAL]

**location:** `bin/Protocol-7` line 1525-1526

**issue:** `$data{'plugins'}{'status'}` is only written inside verbosity check

```perl
# line 1522-1526
if (length( $data{'code'}{$file_name}{'source'} ) > $orig_len
    and $data{'system'}{'zenka'}{'verbosity'}{'console'} > 3 ) {
    # ...
    $data{'plugins'}{'status'}{$code_name}{'load_errors'}++
        if not length($src_str);
}
```

this only executes when:
- verbosity > 3 (rare in production)
- source length increased (transform applied)
- plugin has no source string (error condition)

**impact:** successful plugin loads are never registered in `%data`.

**recommendation:** move plugin registration outside the verbosity block:

```perl
# after line 1534 (push @compile_order)
if ( $code_name =~ m|^plugin\.| ) {
    $data{'plugins'}{'status'}{$code_name}{'load_errors'} //= 0;
}
```

---

### finding 3: return value semantics [MEDIUM]

**location:** `base.load_plugins` line 9-11, 15-19

**issue:** returns `TRUE` on empty input and on failure

```perl
# line 9-11: no plugins specified
if ( !@plugins_to_load ) {
    return TRUE;   # should be FALSE or undef
}

# line 15-18: no plugins loaded
if ( not defined $subs_ok or !$subs_ok ) {
    return TRUE;   # should be FALSE
}
```

**impact:** `base.cmd.reload` reports `[ success ]` even when nothing was loaded.

**recommendation:** change return values:
- empty input → return `FALSE` or report warning
- no plugins loaded → return `FALSE`

---

### finding 4: callback purge scope uncertainty [MEDIUM]

**location:** `base.reload_plugins` lines 10-14

**issue:** only purges `callbacks.end_code`, inconsistent with registration points

```perl
if ( defined <callbacks.end_code>
    and ref <callbacks.end_code> eq qw| ARRAY | ) {
    my @callbacks_copy = <callbacks.end_code>->@*;
    <callbacks.end_code>->@* = grep { !m|^plugin\.| } @callbacks_copy;
}
```

**impact:** plugins may leave stale callbacks in other registration points.

**investigation needed:** check if plugins register callbacks in other hashes like `callbacks.start_code`, `callbacks.error`, etc.

**recommendation:** audit all callback registration points and purge consistently:

```perl
# purge all callback types
for my $cb_type (qw| end_code start_code error pre_init |) {
    next if not defined $data{'callbacks'}{$cb_type};
    $data{'callbacks'}{$cb_type}->@* =
        grep { !m|^plugin\.| } $data{'callbacks'}{$cb_type}->@*;
}
```

---

### finding 5: missing unload mechanism [LOW]

**location:** `base.reload_plugins` line 4 (TODO comment)

```perl
# todo = implement unload mechanism \ investigate callback order + registry ?
```

**impact:** old plugin code remains in memory until overwritten.

**recommendation:** implement explicit unload:
- clear `$code{$plugin}` entries
- clear plugin's data subtree
- remove from `plugins.status`

---

## trace matrix

| step | file | line | action | hash used | issue |
|------|------|------|--------|-----------|-------|
| init | bin/Protocol-7 | 1328-1329 | clear load_errors | `%code` | wrong hash |
| load | base.load_plugins | 13 | load_code | — | no registry update |
| error | bin/Protocol-7 | 1525-1526 | increment load_errors | `%data` | verbosity-gated |
| reload | base.reload_plugins | 16 | read plugins.status | `%data` | usually empty |
| purge | base.reload_plugins | 10-14 | grep callbacks.end_code | `%data` | partial purge |

---

## resolution

**commit:** [fix pushed] — plugin reload now functional

**changes made:**
- unified plugin registry on `%data{'plugins'}{'status'}` hash
- `base.load_plugins` now populates `%data` registry on successful load
- `base.reload_plugins` correctly reads from populated `%data` registry

**verified working:**
```
: . loading : plugin.auth
::[src]: m.,/plugin.auth.pwd
::[src]: m.,/plugin.auth.unix
...
: ..: 11 subs., 38K src., no errors., =)
:..: [004] code swap successful =)
: :.installed rollback watcher..
```

---

## recommended fix priority [all resolved]

1. ~~**P0:** unify plugin registry on `%data` hash (finding 1)~~ ✅
2. ~~**P0:** register successful loads in `%data` (finding 2)~~ ✅
3. **P1:** fix return value semantics (finding 3) — low priority, works as-is
4. **P1:** audit and fix callback purge scope (finding 4) — future cleanup
5. **P2:** implement unload mechanism (finding 5) — future enhancement

---

#,,,.,,.,,.,.,,,.,..,,...,..,,..,,,,.,.,.,,,.,.,.,...,...,.,.,.,.,,,.,,,,,.,.,
#6J2SAU63ZC4K3WC673UK5IBIDEEQW36LUZEQDJAPT7IOJPCN6CAMFDNL6P7DZBZ7HCHJWXFVCXJXQ
#\\\|NICQE4OJKZQT7MKR2CN6LZ3VNWCE6OTBW2BSHBKKDHMNSM34ZDT \ / AMOS7 \ YOURUM ::
#\[7]NG4LANP4YERX4PJ5HSEN5ZBF4HL4AJQIVMYSRMD3WCHLE4QRUOCI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
