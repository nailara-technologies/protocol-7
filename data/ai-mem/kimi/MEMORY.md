# Kimi Development Memory - Protocol-7

## NShell Ctrl+O Cycle Fixes (February 2025)

### Bugs Fixed

**1. Double-Shift Bug (CRITICAL)**
- **Issue**: `ctrl_o_start_position` was being incremented along with `ctrl_o_entries_added`
- **Effect**: Index calculation drifted, wrong history entries loaded
- **Fix**: Removed `$state_ref->{'ctrl_o_start_position'}++` - only track `entries_added`
- **Commit**: 684c7f64a

**2. Index Calculation Order (CRITICAL)**
- **Issue**: `next_index` calculated BEFORE `history_add()`, but used AFTER
- **Effect**: After history_add() shifts indices up by 1, next_index points to wrong entry
- **Fix**: Reorder code - calculate indices AFTER history_add() when shift is known
- **Code pattern**:
  ```perl
  # WRONG: Calculate before add
  my $next_index = calculate_index();  # Uses old shift
  history_add($cmd);                    # Shifts everything
  load_entry($next_index);              # Wrong index!

  # RIGHT: Calculate after add
  history_add($cmd);                    # Shifts everything
  my $shift = $state_ref->{'ctrl_o_entries_added'};
  my $next_index = $start_position + $shift;  # Correct with new shift
  load_entry($next_index);              # Correct index!
  ```
- **Commit**: Part of b2777cc0b

**3. State Reset When Editing History**
- **Issue**: When user edits a command from history, Ctrl+O cycle state wasn't reset
- **Effect**: Wrong indices on next Ctrl+O cycle
- **Fix**: Added `ctrl_o_start_position` and `ctrl_o_entries_added` reset to `nshell.state.reset_history`
- **Commit**: 684c7f64a

**4. Preloaded Entry Display**
- **Issue**: `display_preloaded_entry` flag set but never checked
- **Effect**: After Ctrl+O, next command loaded in buffer but not displayed (empty prompt)
- **Fix**: Check flag in `read_from_buffer` when showing cursor:
  ```perl
  if ($show_cursor_on_call) {
      if ($state_ref->{'display_preloaded_entry'}) {
          $state_ref->{'display_preloaded_entry'} = FALSE;
          print "\r\e[K" . $colors{'p7_fg_0004'}
              . $state_ref->{'editor'}->{'buffer'}
              . $colors{'p7_fg_0003'} . "_\e[0m";
      }
      ...
  }
  ```
- **Commit**: Part of b2777cc0b

### Key Implementation Details

**Ctrl+O Cycle Logic**:
- `ctrl_o_start_position`: Fixed anchor point where cycle started (never changes during cycle)
- `ctrl_o_entries_added`: Counter incrementing each time command added to history
- `$shift`: Applied dynamically = `ctrl_o_entries_added`
- `index_a = start_position + shift` (current command)
- `index_b = (start_position - 1) + shift` (previous command)
- Toggle between index_a and index_b based on current position

**Why This Works**:
- Each `history_add()` shifts ALL indices up by 1
- `start_position` stays constant (the original cycle start)
- `shift` compensates for entries added since cycle started
- Calculating after add ensures correct post-shift indices

---

## Project Workflow Rules (CRITICAL)

### Signature Updates Require User Passphrase
**NEVER use `SKIP_SIGNATURE_CHECK=1` or `SKIP_VERSION_CHECK=1`**

- Pre-commit hooks enforce signatures and version numbers for integrity
- Circumventing them violates project policy
- **Correct workflow**:
  1. Make code changes
  2. Run `./bin/dev/update-version` (updates version number)
  3. **Ask user to sign files** (requires passphrase)
  4. Commit normally WITHOUT override flags
  5. Pre-commit hook will pass with valid signatures

- **If signatures outdated**: Ask user: "Files need signatures updated. Can you run the signing command?"
- **User will**: Use passphrase to sign, then commit proceeds normally

### Version Management
- Version file: `configuration/protocol-7.src-ver`
- Format: `<AMOS-checksum>-<commit-count>.0`
- Update with: `./bin/dev/update-version`
- Commit count must match `git rev-list --count hub/base..HEAD`

### Pre-Commit Hook Checks
1. File permissions normalized
2. Version number matches commit count
3. All signatures valid and present
4. Source code integrity verified

**Respect these checks** - they protect repository integrity!

---

## No-TTY Debug Infrastructure (Enhanced February 2025)

### Extended Key Syntax
Module: `nshell.no-tty-debug.cmd.char-add`

**Key Mappings Added**:
- Navigation: `Up`, `Down`, `Left`, `Right`, `Home`, `End`, `PageUp`, `PageDown`
- Editing: `Backspace`, `Delete`, `Tab`, `Insert`
- Control: `Ctrl+a` through `Ctrl+z` (most common)
- Special: `Escape`, `Enter`, `Space`
- Function: `F1`, `F2`, `F3`, `F4`

**Dual Syntax Support**:
```
[Up,Down,Ctrl+o,Enter]   # Bracket syntax
:Up,Down,Ctrl+o,Enter:   # Colon syntax
```

### Debug State Tracking
- Buffer: `nshell-state-track` (12K max)
- Logs: Input events, mode changes, Ctrl+O state transitions
- Purpose: LLM-friendly debugging of complex state machines

### Commands Exposed
- `char-add <sequence>`: Inject key sequence into nshell input
- `debug-status`: Query current nshell state

#,,..,.,.,,,,,,,.,.,,,.,.,,.,,,,.,...,..,,,.,,.,.,...,..,,...,.,.,..,,,,.,,,.,
#Q2RT3KEGLS4BESDD7FEVCFR2MG5Y3HZCPOKBNAKWVYL4UNUO3GKVFIZ67FGDA4DSHK3TF6T5KRO22
#\\\|4VKPAQSFECLCDLS7XJ6GRDVZI2QDVAYNOAHICPK6JCCFNWULRLR \ / AMOS7 \ YOURUM ::
#\[7]BFG6VXDGVOWCMH6JEZ5Y7GZF2CGT5NZZXZHSLYIICGAZSXLUIUAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

---

## SSH Zenka Recovery (February 2025)

### Race Condition Fix: Auto-User-Creation

**Issue**: Multiple `register_*_deps` calls racing when creating system user during startup, causing duplicate "not in passwd" errors.

**Root Cause**: SSH zenka loads `ssh.set-up` and `set-up.json` before base module init (unusual pattern), triggering multiple `register_pm_deps`, `register_bin_deps`, `register_src_deps` calls before user exists.

**Fix Strategy**: Check if dependencies already registered before attempting user creation:

```perl
## early return if deps already registered [ prevents user creation race ] ##
if ( -d $mod_dir and scalar( glob("$mod_dir/*") ) > 2 ) {
    return TRUE;    ## already registered, skip user check ##
}
```

**Files Modified**:
- `modules/base.register_pm_deps`
- `modules/base.register_bin_deps`
- `modules/base.register_src_deps`
- `modules/base.load_modules` (add user auto-creation)
- `modules/base.check_dependency_dirs` (add user auto-creation)
- `modules/base.root.check_system_user` (auto-detect make_path for pre_init)

**Commit**: 6a2d76206

---

## Terminal Color Consistency (February 2025)

### Problem: White Text in keys.console.list

Unstyled text appeared white/default, breaking visual consistency of Protocol-7 color scheme.

**Solution**: Base teal color on ALL output first, then specific element coloring:

```perl
##  1. base teal on everything  ##
$key_list_string =~ s|^(.+)$|$C{T}$1|mg;

##  2. specific colors - always restore to teal after  ##
$key_list_string =~ s|  (\.)$|  $C{b}$C{0}$1$C{T}|mg;
```

**Key Principle**: Never use `$C{R}` (reset) mid-string - always restore to base color `$C{T}` to prevent white gaps.

**Color Assignments**:
- Key names: Teal (`$C{T}`)
- Extensions (.public/.private/.secret): Purple (`$C{0}`)
- Quotes, markers, colons: Purple
- Background: Dark (`$C{b}`)

**Files Modified**:
- `modules/keys.console.list`

**Commits**: d3747de61, 0cee4bd9c

---

## Research: Dynamic Harmonic Color Templates

**Document**: `data/md/design/CONCEPT-DYNAMIC-HARMONIC-COLOR-TEMPLATES.md`

**Vision**: Replace fragile regex-based coloring with template system using multi-buffer masks (retro video game approach):

1. **TEXT BUFFER**: Raw content for layout calculation
2. **TYPE BUFFER**: Semantic type IDs (key_name, extension, checksum)
3. **COLOR BUFFER**: Harmonic palette mapped from types
4. **OUTPUT**: Composited result

**Benefits**:
- No sprintf width issues (layout before colors)
- Semantic coloring ("key name" not "purple")
- Dynamic palette adaptation via ELF truth assertions
- Consistent across all tools

**Phases**:
- Phase 1: Forward templates with semantic registry
- Phase 2: Dynamic reverse template inference from data streams

#,,,.,,.,,.,,,,,.,,,,,..,,,.,,..,,...,..,,,,,,.,.,...,...,..,,,..,...,.,.,,,,,
#3PJZUORI2CRMG5WKZK4XM3PO7XDLE26K4QTZWZAY6XB3ETFAP6U2GKYPMSFU7GCBFTT62XSR7BV7A
#\\\|6RNRELHUOHUNQWXH3ZNWH2JCPWZLC4TYI65OKSGP3HJ7E7VFXMI \ / AMOS7 \ YOURUM ::
#\[7]T47ATDSTTF7ZDIN35ZQ6G6IIQRU3JYKZDN3WQTV23MR2CT6M5ODY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
