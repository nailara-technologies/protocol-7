# Git Zenka - Harmonically-Integrated Version Control

## Overview

The Git zenka provides Protocol-7's harmonically-validated version control workflow, wrapping standard git operations with:

- **Harmonic validation** of commit messages via `AMOS7::Assert::Truth`
- **Blacklight neon** color scheme for visual consistency
- **Automated version management** using network time + commit count
- **Integration** with Protocol-7 development workflow

## Structure

```
git/
├── start                    # Zenka entry point
├── zenka-startup.v7         # V7 startup configuration
├── os-dep/                  # OS dependencies
│   ├── binary/git          # git binary marker
│   └── debian/git          # git package marker
├── pm-dep/                  # Perl module dependencies
│   ├── AMOS7__Assert__Truth
│   ├── Git__Wrapper
│   ├── Capture__Tiny
│   ├── Crypt__Misc
│   ├── Term__ReadLine
│   ├── Time__HiRes
│   └── File__Find
└── source/                  # Helper scripts
    ├── commit               # Harmonic commit
    ├── status               # Enhanced status
    ├── changed-files        # Extract modified files
    └── update-version       # Version string update
```

## Operations

### commit
Interactive commit with harmonic validation:
- Enforces message length (13-76 characters)
- Validates harmony via BMW checksum
- Blacklight UI with readline support

### status
Enhanced git status with Protocol-7 colors

### changed-files
Extracts list of modified files from git status

### update-version
Updates version strings using:
- Network time (base32-encoded BMW)
- Git commit count
- Automatic file updates

## Dependencies

### Binary
- `git` - Git version control system

### Perl Modules
- `AMOS7::Assert::Truth` - Harmonic validation
- `Git::Wrapper` - Git command interface
- `Capture::Tiny` - Command output capture
- `Digest::BMW` - BMW checksums
- `Crypt::Misc` - Base32 encoding
- `Term::ReadLine` - Interactive input
- `Time::HiRes` - Precise timing
- `File::Find` - File tree traversal

## Workflow Integration

### Standard Commit Workflow
```bash
# 1. Make changes
vim src/something.pm

# 2. Check status
zenka git status

# 3. Commit with harmonic validation
zenka git commit

# 4. Update version (if needed)
zenka git update-version

# 5. Push
git push
```

### Version Management
Version strings follow the format: `{timestamp}-{count}.{revision}`

Example: `Y7XMK5IX2W-1234.0`
- `Y7XMK5IX2W` = Base32-encoded network time
- `1234` = Git commit count
- `0` = Revision number

## Color Scheme

Blacklight neon aesthetic:
- Background: `#090529` (Nailara)
- Blacklight: `#4427ac` (Purple)
- TRUE: `#0647c3` (Blue)
- Success: `#47c306` (Green)
- Warning: `#c58d07` (Orange)

## Integration Points

### With Other Zenki
- **debian zenka**: Dependency checking
- **workflow zenka**: Development automation
- **backup zenka**: Pre-commit backups

### With Existing Scripts
- Uses `bin/admin/vc_commit` for commits
- Uses `bin/admin/vc-changed-files` for file listing
- Uses `bin/dev/update-version` for versioning

## Future Enhancements

- Add `diff` operation with ccdiff integration
- Add `log` operation with chronological display
- Add `format` operation for pre-commit tidying
- Add `restore-permissions` integration
- Add pre-commit hooks
- Add automated backup creation

## See Also

- [GIT_ZENKA_DESIGN.md](../../../../workspace-transfer/GIT_ZENKA_DESIGN.md) - Detailed design document
- [bin/admin/vc_commit](../../../bin/admin/vc_commit) - Interactive commit tool
- [bin/dev/update-version](../../../bin/dev/update-version) - Version management

#,,,.,,,,,,..,...,,,,,,.,,...,,.,,,.,,.,,,,.,,..,,...,...,..,,,..,,,,,.,,,...,
#5K2V6VJIWIRDNSGVTBDFZ4XWKOXJQA6JGUYO3HXNY5CJHEFTGGXQLRGJTAVFMJ47EMD4RLKL7VAUI
#\\\|CEILWFFRE7ZQT7HTVIFHOX6ZSLSX2XH2RWQ6KUITCRNECR62WUE \ / AMOS7 \ YOURUM ::
#\[7]5SCAM6NJECTKST4EUIUGJQ722HWOWM2O5CLIHQO5FGLLZFCF2QCI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
