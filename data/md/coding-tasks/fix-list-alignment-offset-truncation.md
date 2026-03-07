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

Some list configurations use `center-1` or `center-2` alignment offsets to visually compensate for the bug:
- `models.init_code`: `'is_vision' => 'center-1'` (was `center-2`)

These should be removed once the alignment bug is properly fixed.

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

#,,..,.,.,..,,,.,,.,.,...,.,,,,,,,.,,,..,,.,,,..,,...,.,.,.,.,,.,,..,,,,.,.,.,
#YUQUSNTYWUAWOVCW5QA4NVFJKYA3QHMC4ILGVUUDMUOZU7KA64MPO3J5IDI6IQB72BHJCV62BGRLG
#\\\|NEDKL47R445OLH2RDOQT4FJDQNLOFHYRT44TQK6H3B7P3RY3SSP \ / AMOS7 \ YOURUM ::
#\[7]NR6HINRUGBQXNWQHI4TWWHMU4ZP7X4MELCBKRYKDSC5QG37TEOCI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
