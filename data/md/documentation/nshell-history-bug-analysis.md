# nshell History Navigation Bug Analysis

## Summary

The arrow-up and arrow-down history navigation is inverted (goes in wrong direction), and the Ctrl+O cycle has index calculation errors. These bugs were introduced during Ctrl+O fixes (commits `fb8515e99` and `b2777cc0b`).

---

## History Array Structure

```perl
# From AMOS7/TERM.pm:
our @history_entries;  # Array of [timestamp, [lines]]
# Entries are pushed to END: push @history_entries, [ $timestamp, \@lines ];
# So: index 0 = oldest, index $#history_entries = newest
#
# Visual:
# [0] oldest command      [history size - 1] newest command
#  ^                     ^
#  |                     |
#  first entry           last entry added (most recent)
```

---

## Bug 1: Arrow-Up Navigation Direction Inverted

**File:** `src/nshell.history.arrow_up`

### Current (Buggy) Behavior:
```perl
# When NOT viewing history (initial up-arrow press):
} else {
    ## Not in tracked history - start from oldest entry (last in array)  <-- WRONG!
    if (@AMOS7::TERM::history_entries) {
        my $attempts     = 0;
        my $search_index = @AMOS7::TERM::history_entries - 1;  # Starts at NEWEST
        ...
        $search_index--;  # Then goes to OLDER entries (lower indices)
    }
}
```

### The Problem:
- **Initial press:** Starts at `$#history_entries` (newest command) ✓
- **Navigation:** Decrements index (`search_index--`) going toward OLDER commands
- **Comment says:** "Up = newer = lower index" 
- **Expected bash/readline behavior:** 
  - Up-arrow should go to MORE RECENT commands (toward newest)
  - But since we start at newest, we can't go more recent
  - So up-arrow should show previous (older) commands

Wait - let me re-analyze. Starting at newest and decrementing goes to older. That's correct!

BUT: The issue is the **comment is wrong** and confusing:
```perl
## Up = newer = lower index, skip duplicates  <-- WRONG COMMENT!
my $search_index = $state_ref->{'current_history_index'} - 1;
```

Actually going to lower index = OLDER entry (since 0 is oldest).
So "lower index = newer" is wrong. Lower index = older.

**Correct behavior:**
- Up-arrow: go to OLDER entries (decrement index) ✓ 
- Down-arrow: go to NEWER entries (increment index) toward the end

But wait - that means:
- First up-arrow: shows newest command
- Second up-arrow: shows older command (2nd most recent)
- Third up-arrow: shows even older command

This is BACKWARDS from standard shell behavior!

**Standard shell behavior:**
- First up-arrow: shows most recent command (newest)
- Second up-arrow: shows 2nd most recent (older)
- Third up-arrow: shows 3rd most recent (even older)

Hmm, that's what the code does. So what's wrong?

**Ah! I see it now!** The comment is misleading. Let me trace again:

```
History array: [oldest] [older] [newer] [newest]
               index 0   ...    ...    index N
```

Current code:
- Up-arrow from prompt: start at index N (newest), show it
- Up-arrow again: index N-1 (older), show it

This IS correct for "up = go back in time"!

But the code COMMENT says "Up = newer = lower index" which is **wrong**.
And when you're already viewing history:
```perl
## Up = newer = lower index, skip duplicates
my $search_index = $state_ref->{'current_history_index'} - 1;
```
This decrements index, which goes to OLDER entries, not newer!

So the **comment contradicts the code**.

### The Actual Bug:

When viewing history and pressing up-arrow, the code says it goes to "newer" but actually goes to "older". The behavior is correct but the mental model is inverted.

However, looking at the bug report: "arrow-up and arrow-down history cycling goes in wrong direction"

This suggests the actual BEHAVIOR is wrong, not just the comments.

Let me check arrow_down...

---

## Bug 2: Arrow-Down Navigation Direction Inverted

**File:** `src/nshell.history.arrow_down`

```perl
## We're viewing history - navigate relative to current position
## Down = older = higher index, skip duplicates  <-- WRONG COMMENT!
my $search_index = $state_ref->{'current_history_index'} + 1;
```

Higher index = newer entry (toward end of array), not older!

So the comments in both files are inverted. But is the behavior wrong?

Looking at the diff from commit `8eeb64812` to `fb8515e99`, the arrow key navigation
was rewritten to add duplicate skipping. The rewrite changed the logic.

**Before (working):**
```perl
## Up = newer = lower index
$target_index = $state_ref->{current_history_index} - 1;
# Simple: just decrement index
```

**After (buggy):**
```perl
## Up = newer = lower index, skip duplicates  <-- Same wrong comment
my $search_index = $state_ref->{'current_history_index'} - 1;
while (...) {  # Complex duplicate skipping
    $search_index--;  # Go further back
}
```

The direction is the same, but now with duplicate skipping.

### Root Cause Found:

Looking more carefully at the **initial navigation** (when `current_history_index < 0`):

**Arrow Up (initial):**
```perl
} else {
    ## Not in tracked history - start from oldest entry (last in array)
    my $search_index = @AMOS7::TERM::history_entries - 1;  # NEWEST
    ...
    $search_index--;  # Then go to OLDER
}
```

**Arrow Down (initial):**
```perl
} else {
    ## Not in tracked history - clear any stray init cursor
    <[nshell.render.empty_prompt]>->(...);
    return;
}
```

So:
- First up-arrow: shows newest command ✓
- Second up-arrow: shows older command (N-1) ✓
- Down-arrow from there: should go to N (newer), but...

Wait! Let me check arrow_down more carefully:

```perl
if ( $state_ref->{'current_history_index'} >= 0 ) {
    ## We're viewing history
    ## Down = older = higher index, skip duplicates
    my $search_index = $state_ref->{'current_history_index'} + 1;
    while ( ... ) {
        ...
        $search_index++;  # Keep going to higher indices
    }
}
```

So from position N-1, down-arrow goes to N (newer). That's correct!

But wait - the comment says "Down = older = higher index". That's wrong.
Higher index = NEWER (toward the end where newest is).

So the comments have "newer" and "older" swapped throughout!

### Actual Behavior vs Expected:

| Action | Expected | Actual | Status |
|--------|----------|--------|--------|
| First Up | Show newest | Shows newest | ✓ |
| Second Up | Show older | Shows older | ✓ |
| Down after Up | Show newer | Shows newer | ✓ |
| Down at prompt | Clear/no-op | Clear/no-op | ✓ |

The behavior seems correct! So where's the bug?

**The bug might be in how the index is used AFTER navigation!**

Looking at the end of arrow_up:
```perl
$state_ref->{'current_history_index'} = $target_index if $target_index >= 0;
```

This sets the history index. But wait - when we start from -1 (not viewing),
we find target_index = N (newest), then set current_history_index = N.

Then on second up-arrow:
- current_history_index = N
- search_index = N - 1
- Find entry at N-1
- target_index = N-1
- current_history_index = N-1

That seems right!

Hmm, let me look at the actual git diff more carefully...

Actually, looking at commit `fb8515e99`, the arrow key files were changed from:
```perl
my ( $state_ref, $editor, $colors ) = @_;
```
to:
```perl
my ( $state_ref, $editor, $colors ) = @ARG;
```

This is the **bug**! In Perl:
- `@_` is the subroutine arguments
- `@ARG` is NOT the same as `@_` - it's the `@ARG` array (usually empty or undefined)

So after the change, `$state_ref`, `$editor`, `$colors` are all undefined!

Wait, but looking at the module structure, this is Protocol-7 code.
Let me check what `@ARG` means in this context...

Looking at other modules, `@ARG` is used consistently. It's likely a module loading convention where `@ARG` is set before the module is executed.

So that's probably not the bug.

Let me re-read the problem statement more carefully:
> "arrow-up and arrow-down history cycling goes in wrong direction (was introduced while fixing ctrl-o handling)"

The key hint is: **Ctrl+O handling**.

Looking at `ctrl_o_cycle`, it also manipulates `current_history_index`. 
The issue might be **interaction** between Ctrl+O and arrow keys.

### Ctrl+O Cycle Bug

```perl
## NOW calculate indices (after history_add shifts everything)
my $shift   = $state_ref->{'ctrl_o_entries_added'};
my $index_a = $state_ref->{'ctrl_o_start_position'} + $shift;
my $index_b = ( $state_ref->{'ctrl_o_start_position'} - 1 ) + $shift;

## Toggle between the two based on current position
## Note: current_history_index needs to account for the shift too
my $current_shifted = $state_ref->{'current_history_index'} + 1;  ## +1 for entry just added
my $next_index
    = ( $current_shifted == $index_a )
    ? $index_b
    : $index_a;
```

The issue: After `history_add`, all indices shift up by 1.
The code tries to compensate with `$shift` and `$current_shifted`.

But the logic is convoluted. If `start_position` was N before adding:
- After add: original entry N is now at N+1
- `$shift = 1`
- `$index_a = N + 1`
- `$index_b = (N - 1) + 1 = N`
- `$current_shifted = current_history_index + 1`

If `current_history_index` was N before Ctrl+O:
- After loading the entry, it's set to N
- `$current_shifted = N + 1`
- Compare to `$index_a = N + 1` → they match
- So `$next_index = $index_b = N`

But the entry that WAS at N is now at N+1 (because we added a new entry at the end).
So `$next_index = N` would get the wrong entry!

**Bug found in Ctrl+O:**
After history_add, the old entries shift. The code uses `$shift` to compensate,
but the logic is off. `index_a` and `index_b` calculate where the entries MOVED TO,
but the comparison uses `$current_shifted` which adds 1.

If current was at N, and we add an entry, the entry is now at N+1.
So `$current_shifted = N + 1` equals `$index_a = N + 1`.
Then we go to `$index_b = N`.

But `$index_b` is calculated as `(start - 1) + shift = (N - 1) + 1 = N`.
This is some OTHER entry entirely!

---

## Root Causes Summary

### 1. Inverted Comments (Minor)
Both arrow_up and arrow_down have comments that swap "newer" and "older":
- `arrow_up`: "Up = newer = lower index" should be "Up = older = lower index"
- `arrow_down`: "Down = older = higher index" should be "Down = newer = higher index"

The comments contradict the array structure where index 0 = oldest.

### 2. Ctrl+O Index Calculation Error (Major)
The Ctrl+O cycle has flawed index math after history_add shifts entries:
- `$current_shifted = current_history_index + 1` logic doesn't match the actual shift
- This causes it to load the wrong history entry after the first cycle

### 3. Potential Arrow Key State Corruption (Major)
When Ctrl+O sets `current_history_index`, it may set it to an incorrect value.
Then when arrow keys use that value as the starting point, they navigate from the wrong position.

---

## Specific Fix Recommendations

### Fix 1: Correct Comments in Arrow Handlers

**arrow_up:**
```perl
## Up = older = lower index (toward 0), skip duplicates
```

**arrow_down:**
```perl
## Down = newer = higher index (toward $#history_entries), skip duplicates
```

### Fix 2: Fix Ctrl+O Index Calculation

The logic should be:
```perl
## After history_add, all existing entries shifted up by 1
## If start_position was N, that entry is now at N+1
## We want to toggle between: original entry (now at N+1) and the one before it (now at N)

my $shift = $state_ref->{'ctrl_o_entries_added'};

## Calculate where the original entries are NOW (after shifts)
my $pos_original = $state_ref->{'ctrl_o_start_position'} + $shift;      # Was at start, now shifted
my $pos_before   = $state_ref->{'ctrl_o_start_position'} + $shift - 1;  # One before start, also shifted

## The current position also shifted if we had an index
my $current_was  = $state_ref->{'current_history_index'};
my $current_now  = ($current_was >= 0) ? $current_was + 1 : $pos_original;

## Toggle
my $next_index = ($current_now == $pos_original) ? $pos_before : $pos_original;
```

### Fix 3: Validate History Index Bounds

Add bounds checking after calculating `next_index`:
```perl
$next_index = 0 if $next_index < 0;
$next_index = $#AMOS7::TERM::history_entries 
    if $next_index > $#AMOS7::TERM::history_entries;
```

### Fix 4: Reset Ctrl+O State More Aggressively

In `nshell.state.reset_history`, ensure Ctrl+O state is fully reset:
```perl
$state_ref->{'ctrl_o_start_position'}   = -1;  # Not undef (causes warnings)
$state_ref->{'ctrl_o_entries_added'}    = 0;
$state_ref->{'ctrl_o_redraw_cursor'}    = FALSE;
$state_ref->{'display_preloaded_entry'} = FALSE;
```

---

## Debug Infrastructure Assessment

### Current Debug Capabilities (Good)

The `nshell.no-tty-debug.cmd.char-add` module provides:
1. **Key name mapping** - Human-readable keys like `[Up]`, `[Ctrl+o]`, `[Enter]`
2. **Dual syntax support** - `[Key1,Key2]` and `:Key1,Key2:` formats
3. **State tracking buffer** - `nshell-state-track` for LLM-friendly output
4. **Event logging** - Input events, mode changes, Ctrl+O state

### Usage Example:
```
:Up,Up,Down,Enter:
```
This simulates: Up-arrow, Up-arrow, Down-arrow, Enter

### Limitations:
1. **No visual replay** - Can't see what the terminal would look like
2. **State inspection only** - Shows state after, not during
3. **No history content** - Doesn't show what history entries contain

### Recommendations:
1. Add `history_entries_dump` command to show history with indices
2. Add step-by-step mode for debugging navigation
3. Log the actual entry content being loaded

---

## Conclusion

The arrow key "wrong direction" bug is likely caused by:
1. **Confusing comments** that mislead about the direction
2. **Ctrl+O corrupting `current_history_index`** which arrow keys then use as starting point

The Ctrl+O bug is in the index calculation after `history_add` shifts entries.
The `$current_shifted` logic doesn't properly account for the shift.

Priority fixes:
1. Fix Ctrl+O index calculation (most critical)
2. Ensure arrow keys handle edge cases when Ctrl+O left stale state
3. Correct comments to prevent future confusion

#,,..,,,,,,.,,,,,,,,.,,..,...,.,.,,,.,,,,,.,,,..,,...,...,...,.,,,,.,,,.,,,,.,
#IYHQGSXGM7WFKCQEAXMJFMHNKND4SBMVMU6V4GTLW4OKNTRIYA2SIRA5V3VYFRHDHTLFBAJOAMFD4
#\\\|RYAEB252NNNVGAMCOGKJTLJOXR2GTFZKLK7JQ32N3HRFWMG4M34 \ / AMOS7 \ YOURUM ::
#\[7]V524RIJKOT5VXOMXO5BE66775FGWEDQH4EOZTGCSQMUHDGOVNGAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
