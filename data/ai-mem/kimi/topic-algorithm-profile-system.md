# Algorithm Profile System — April 2026

> Extracted from MEMORY.md. See main memory for cross-references.

## Design Pattern: Profiles as Modules, Not Data

For configurable algorithm variants in P7, the elegant approach is:
- **Category modules** on disk (e.g., `base.chk-sum.profile.harmonic-slide`)
- Each returns a hashref with defaults + optional preset merge from `%data`
- **Generic wrapper** (`base.chk-sum.profile.calc`) handles input normalization,
  profile resolution, and dispatch
- **Presets stored as deltas** in `%data` — category module merges them with
  default hash before returning

This is superior to dynamic code generation (`perlmod.load` of generated strings)
because it uses existing infrastructure (files, `swap_subs`, git tracking,
AMOS signatures) and is debuggable.

## Syntax Conventions

```perl
# default category
<[chk-sum.profile.harmonic-slide]>->();

# with preset id (delta merged from %data)
<[chk-sum.profile.harmonic-slide]>->('X7K9');

# direct calc with string profile id
<[chk-sum.profile.calc]>->("harmonic-slide.X7K9", $input);

# store a deviation preset
$data{'chk-sum'}{'profile'}{'harmonic-slide'}{'X7K9'} = {
    length => 7,
};
```

## White-List Registration for Dynamic Namespaces

Dynamic dispatch via `$code{$mod}` is invisible to `dep-graph` static analysis.
Two solutions:

1. **dep-graph rule** (`configuration/dep-graph/rules/*.rules`):
   ```
   chk-sum.profile.calc : mod ~ /chk-sum\.profile/ -> chk-sum.profile.*
   ```

2. **`base.white-list.register`** (preferred hybrid):
   - Call in zenka start file: `[base.white-list.register:'base.chk-sum.profile']`
   - `dep-graph` parses this and eagerly includes all matching modules in whitelist
   - Runtime: verifies files exist, reports missing ones
   - Generic pattern reusable for any dynamic namespace

## Critical Syntax Pitfalls

**`$call` is ONLY predefined for `*.cmd.*` modules**
- Regular modules (including `base.white-list.register`) use `@ARG` / `shift`
- Using `$call` in non-cmd modules causes compilation error

**`//= {}` on data access can break compilation**
- `<data.path> //= {}` looks like typeglob assignment to Perl parser
- Use explicit hashref: `my $ref = <data.path> // {}` or `$data{'key'} //= {}`
- Even `ptd -c` may pass while actual P7 compilation fails

**Dynamic module dispatch syntax**
- `<[$mod]>->(...)` does NOT work — `<[...]>` is static key lookup
- Correct: `$code{$mod}->(...)` with `$mod` as computed string

**No-arg calls: `->()` is implicit**
```perl
<[base.exit]>        ## correct — implicit ->()
<[base.exit]>->()    ## redundant but valid
```
The P7 parser automatically adds `->()` when omitted. This keeps no-arg
calls clean and concise.

## dep-graph Rule Format

```
module_glob : var_name ~ /context_pattern/ -> resolution_template
```

- `module_glob`: `*` for any, or specific module name
- `var_name`: variable used in `$code{$var}`
- `context_pattern`: regex on ±15 lines around dispatch site
- `resolution_template`: `prefix.*` for wildcard (adds all matching graph nodes)

## Files Created/Modified

| file | purpose |
|------|---------|
| `modules/base.chk-sum.profile.calc` | generic checksum wrapper |
| `modules/base.chk-sum.profile.harmonic-slide` | spatial coordinate category |
| `modules/base.chk-sum.profile.gen-path` | path generation category |
| `modules/base.chk-sum.profile.pre_init` | swap_subs |
| `modules/base.white-list.register` | whitelist + runtime verification |
| `bin/dev/dep-graph` | parse white-list.register in start files |

#,,,,,,.,,,,,,,.,,.,.,.,,,,.,,..,,,.,,,,.,,.,,..,,...,..,,..,,,,,,,.,,...,,..,
#5GTETBFTOEMMRGTDQNJOFOBPNTZLLTR6IQLBDGBSZOTLBLRHGGTM3QULNMCUPBNAFJY4YNBSBZSLI
#\\\|XUDPG5ZPIFAVOO6JRRGV3CSY63H72X6ISIRGZCMVZXKITYZYVNL \ / AMOS7 \ YOURUM ::
#\[7]4J3WJZT74RMPD47QT5AAJBY7JBXEQVIHUVBJ55QOKFZGGU6Y5YBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
