# Fix List Alignment / Offset Truncation Bug

## Problem Description

The separator line in `base.parser.list` does not match the header width, causing misalignment:

```
list sessions

 : usid :.  : protocol :.  : type :.  : mode :.  : uname :.  : since :.
--------------------------------------------------------------------------
  7147002     protocol-7     unix      server       ---        20h 49'26"
```

The separator (74 dashes) is 2 chars shorter than the actual header (76 chars). This causes visual misalignment.

## Root Cause Analysis

The code calculates `$table_width` by summing `$max_len{$key_name}` for all columns during the first pass (line 106):

```perl
foreach my $key_name ( $display_keys->@* ) {
    # ... calculate max_len{$key_name} ...
    $table_width += $max_len{$key_name};
}
```

Then it reduces the last column width AFTER calculating `$table_width` (lines 120-121):

```perl
my $last_d_key = $$display_keys[ scalar $display_keys->@* - 1 ];
$max_len{$last_d_key} -= 2;
$table_width-- if $table_width >= 80;
```

**Problem**: The header is rendered using the REDUCED `$max_len{$last_d_key}`, but `$table_width` still has the ORIGINAL (unreduced) value. This causes a 2-char mismatch.

Additionally, `<key>` columns in data rows add 2 extra spaces (leading `'  '` + trailing `' '`) that aren't accounted for in `$table_width`.

## Progress

### Option B: Implemented (Mar 2026)

`<key>:` column data rows now produce exactly `$max_len{$key_name}` chars, matching
the header. Changed `$max_len{$key_name} - 1` → `$max_len{$key_name} - 3` in the
`<key>:` data branch, which accounts for the `'  '` (2) prefix + `' '` (1) suffix.

The `<key>:` data/header alignment is now correct. The remaining separator bug is
simpler: `$table_width -= 2` alongside `$max_len{$last_d_key} -= 2` to keep them
in sync.

### ⚠ Before Applying the Remaining Fix: Capture Reference Output

There are **46 manual `center-1` / `center-2` / `center-3` alignment offsets** across
the codebase that were tuned to compensate for the current buggy layout. After the
separator fix these will all need re-evaluation — some may shift by 1-2 chars.

**Affected zenki (partial list):** `system`, `httpd`, `web`, `v7`, `coding`, `index`,
`menu-commands`, `channels`, `models`, `events`, `ssh`, `letsencr`, `mpv`

**Required before fixing:**
1. Capture `list <name>` output for every affected list command while the bug is
   present (this is the reference baseline)
2. Apply `$table_width -= 2` fix
3. Capture the same list outputs again
4. Diff each pair — any column that shifted needs its `center-N` tuned or removed

The captures must be on a live system with real data so column widths reflect actual
content, not empty tables. Commands to capture: `list sessions`, `list zenki`,
`list models`, `list processes`, `list connections`, etc.

Without this before/after record it is difficult to know which offsets were compensating
for the bug vs. which are genuinely needed for the data shape of that column.

Once a few representative before/after pairs are captured and the shift pattern is clear
(likely a consistent 1 or 2 char delta), the remaining offsets can be calculated and
batch-adjusted rather than checked individually — e.g. all `center-2` → `center-1`,
or all `center-1` → `center`. The representative sample only needs to cover a few
different column types (`<key>:`, regular field, last column, non-last column) to be
confident the formula generalises.

---

## Failed Approaches

### Attempt 1: Remove width reduction entirely

**Change**: Removed `$max_len{$last_d_key} -= 2` and `$table_width--`

**Result**: Still broken. The `<key>` columns add 2 extra spaces in data rows (line 174: `'  '` prefix, line 179: `' '` suffix), making data rows wider than the separator.

### Attempt 2: Use actual header string length for separator

**Change**: `$sub_line = '-' x (length($table_string) - 1)`

**Result**: Separator became 4 chars too SHORT. The calculation didn't account for the 2-char padding in `<key>` columns.

### Attempt 3: Statically add 2 to separator width

**Change**: `$sub_line = '-' x ($table_width + 2)`

**Result**: Works for tables with exactly one `<key>` column, but breaks tables with zero or multiple `<key>` columns. This is a static hack that doesn't generalize.

### Attempt 4: Dynamic adjustment based on `<key>` column count

**Change**: `$key_col_count = scalar grep { m|^<key>:| } $display_keys->@*; $sub_line = '-' x ($table_width + ($key_col_count * 2))`

**Result**: Rejected. User considered this "bending" (workaround) rather than a proper fix.

## Correct Solution (Not Yet Implemented)

The proper fix requires ensuring consistent width calculation between:
1. Header generation (uses `$max_len{$key_name}` via `pack`)
2. Data row generation (uses `$max_len{$key_name}` with hardcoded padding for `<key>` columns)
3. Separator generation (uses `$table_width`)

**Options:**

### Option A: Account for padding in `$table_width`
```perl
# During first pass
my $key_col_count = 0;
foreach my $key_name ( $display_keys->@* ) {
    $max_len{$key_name} = ...;
    $table_width += $max_len{$key_name};
    $key_col_count++ if $key_name =~ m|^<key>:|;
}
$table_width += $key_col_count * 2;  # Account for <key> padding
```

### Option B: Remove hardcoded padding from `<key>` columns
Modify data row generation to not add extra spaces, making widths consistent.

### Option C: Calculate separator from rendered header + data width
Generate both header and a sample data row, then use the max length for separator.

## Current Workarounds

46 `center-N` alignment offsets across the codebase compensate for the bug. Full list
(grep: `center-[123]` in `modules/`, excluding CSS):

| Module | Fields |
|--------|--------|
| `system.process.init_code` | pid (center-1), state (center-2) |
| `httpd.init_code` | added_at (center-1) |
| `web.init_code` | client_id, status, depth, started_at, template_id, status, created_at (all center-1) |
| `v7.init_code` | status (center-1), status (center-2) |
| `coding.init_code` | status, backend, amos-chksum-id (center-1) |
| `index.init_code` | type (center-2) |
| `menu-commands.init_code` | enabled (center-1), order (center-2), items (center-1) |
| `channels.init_code` | subscribers (center-1) |
| `models.init_code` | quantization, is_vision (center-1) |
| `events.init_code` | event_ID (center-1) |
| `ssh.init_code` | profile (center-2) |
| `letsencr.parent.init_code` | issued_at, expires_at, status, started, status, type (center-1) |
| `mpv.init_code` | key (center) |

These should be audited (not blindly removed) once the fix is applied with before/after
reference captures in hand.

## Files Involved

- `modules/base.parser.list` - Main list rendering logic
- `modules/models.init_code` - Has `center-1` workaround
- Other init_code files may have similar workarounds

## Related Code Sections

```perl
# base.parser.list line ~77-122
my $table_width = 0;
foreach my $key_name ( $display_keys->@* ) {
    # ... calculate max_len ...
    $table_width += $max_len{$key_name};  # Uses unreduced width
}

# Header generation uses reduced max_len
foreach my $key_name ( $display_keys->@* ) {
    $table_string .= pack( "A$max_len{$key_name}", ... );
}
$max_len{$last_d_key} -= 2;  # Reduction happens AFTER table_width calc
$table_width-- if $table_width >= 80;

# Data rows for <key> columns have extra padding (lines 174-179)
$table_string .= '  '  # 2 leading spaces
    . <[base.parser.align]>->( ..., $max_len{$key_name} - 1 )
    . ' ';  # 1 trailing space
```

#,,,,,.,,,...,.,.,,,,,,.,,,.,,,.,,,,,,,,,,,,.,..,,...,...,...,,..,,..,,,.,...,
#GJ6DNOIOM2MSJJAZJ7UZYJ4JGQLSUOB7EYEG7S5LYZFSUJAQ6TVMIFYYJM4UIIPIPJMK3G46DRILE
#\\\|FTKSITPQJ3TK2LJDVHZVGUVPJI3B2CYN25YWJZPQXI5ZSKIWBX3 \ / AMOS7 \ YOURUM ::
#\[7]4XVRL4A63H6GTZXO4ELH7Y2DS6XPLXRYF5HTJSTUZ2FNYYVUAEAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
