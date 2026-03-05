# Fix List Alignment Offset Truncation Bug

## Problem Summary

The Protocol-7 list display system has a bug where alignment offsets (e.g., `left+2`, `right-5`, `center-1`) cause content truncation.

### Example

With this list definition:
```perl
<list.scan-paths> = {
    'var'   => qw| data |,
    'key'   => qw| models.scan_paths |,
    'mask'  => '<key>:id path:scan-path',
    'align' => {
        'id'   => qw| left+1 |,
        'path' => qw| left+2 |  # <-- This +2 causes truncation!
    },
    'descr' => 'model scan paths and their path-ids'
};
```

A path like `/mnt/ext-xfs-data/models-lmstudio` (36 chars) displays as:
```
/mnt/ext-xfs-data/models-lmstudi   # <-- truncated to 35 chars!
```

## Root Cause Analysis

### Location of Bug

**Primary files:**
- `modules/base.parser.list` - list rendering logic
- `modules/base.parser.align` - alignment helper

**The issue:**

1. In `base.parser.list`, `$max_len` is calculated from content width only (lines 90-104)
2. When rendering data rows (lines 166-212), `$field_len = $max_len{$key_name} - 1` is passed to `base.parser.align`
3. In `base.parser.align` (line 24 for `left` mode):
   ```perl
   return pack( "A$field_len", $l_str . $string );
   ```
   Where `$l_str` is the offset padding (e.g., 2 spaces for `left+2`)
4. `pack("A35", "  " . $string)` truncates the total content to 35 characters

### The Math Problem

For `left+2` with 36-character content:
- `$max_len` = 35 (based on content length)
- `$field_len` = 34 ($max_len - 1)
- Content passed to `pack()`: "  " + 36 chars = 38 chars
- Result: `pack("A34", "  " . $string)` → 34 chars only (truncation!)

## Failed Approaches

**Attempt 1:** Add offset to `$max_len` in the preparation phase (line 106)
- **Result:** Broke table width calculation, causing column drift
- **Why it failed:** `$max_len` is used for both column width AND table width calculation

**Attempt 2:** Add offset only to `$field_len` passed to `align()` in data rows
- **Result:** Data rows wider than headers, misaligned display
- **Why it failed:** Header row doesn't use the same offset calculation

## Requirements for Proper Fix

### Option A: Modify `base.parser.align`

Change alignment logic to NOT include offset padding in the packed string:

```perl
# Current (broken):
return pack( "A$field_len", $l_str . $string );

# Fixed:
my $content_len = length($string);
return $l_str . pack( "A$content_len", $string );
```

**Pros:** Minimal changes, doesn't affect table width calculation
**Cons:** Requires changing all three alignment modes (left, right, center)

### Option B: Unify Header and Data Row Calculations

Ensure headers use the same `$field_len` calculation as data rows:

1. Calculate `$field_len` consistently including offset
2. Update header rendering (line 117) to use same `$field_len`
3. Update separator line calculation (line 123)

**Pros:** Consistent across the module
**Cons:** More invasive changes, risk of breaking other lists

### Option C: Pre-calculate Offset-Aware Column Widths

In the preparation phase (lines 77-107), calculate `$max_len` to include offset:

```perl
# After calculating $max_len from content:
if ( defined $align->{$key_orig_str}
    && $align->{$key_orig_str} =~ m|[-+]\s*(\d+)$| ) {
    $max_len{$key_name} += $1;  # Add offset to column width
}
```

Then ensure table width calculation accounts for this correctly (line 123 may need adjustment).

**Pros:** Cleanest solution, fixes it at the source
**Cons:** Requires careful testing with various list configurations

## Test Cases

After any fix, verify these lists work correctly:

1. **models.list scan-paths** - uses `left+2` for path column
2. **models.list buffers** - uses `right-5`, `right-3` for numeric columns
3. **models.list models** - uses `left+1`, `left+2`, `center-1`, `right-6`
4. **list sessions** - verify no regression
5. **list nodes** - verify no regression

## Files to Modify

- `modules/base.parser.list` - main fix
- `modules/base.parser.align` - optional alternative fix location

## Definition of Done

- [ ] All lists with `+N`/`-N` alignment offsets display correctly
- [ ] No truncation of content longer than column width
- [ ] No column drift/misalignment between headers and data
- [ ] All existing lists continue to work (backward compatible)
- [ ] Test with at least 3 different zenki's list commands

## Related Files

- `modules/base.init_code` - defines `<list.buffers>` with `right-5`
- `modules/models.init_code` - defines `<list.scan-paths>` with `left+2`
- `modules/nodes.init_code` - defines `<list.lan-nodes>` etc.

## Notes

- The TODO comment in `base.parser.list` line 25 mentions alignment bugs
- This bug affects ANY list using alignment offsets with content near column width
- Workaround for now: use plain alignments (`left`, `right`, `center`) without offsets

#,,,,,..,,,,.,,,,,..,,..,,..,,..,,..,,.,,,,,.,..,,...,...,,..,,.,,.,,,..,,,.,,
#LVNQMO5FUUEJ5LLP6UJMKU6HUGRTMAQUSC5FRLGTEPSKEYIRR4JYJTOQYTFLSVHRWNMY5LR3EQ7TE
#\\\|L45NBKGEW7GEH2HQJA2SRDUAXPQ3DQJRJXNIJ7LZF7AJJ4A6FLO \ / AMOS7 \ YOURUM ::
#\[7]64H4B7R7CYITGKFZVS3TWZ6XJRBLNQ2B525BVF7BJC2GEPXXWUCA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
