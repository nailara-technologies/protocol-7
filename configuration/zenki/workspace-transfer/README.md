# Workspace-Transfer Zenka - Harmonically-Integrated Workspace Operations

## Overview

The workspace-transfer zenka provides Protocol-7's integration with the workspace-transfer repository, wrapping workspace operations with:

- **Checkpoint management** for preserving conversation context
- **GitHub integration** for quick save/restore operations
- **Signature verification** for cryptographic authorization
- **Transfer operations** for moving files to protocol-7
- **Blacklight neon** color scheme for visual consistency

## Structure

```
workspace-transfer/
├── start                    # Zenka entry point
├── zenka-startup.v7         # V7 startup configuration
├── os-dep/                  # OS dependencies
│   ├── binary/git          # git binary marker
│   ├── binary/perl         # perl binary marker
│   ├── debian/git          # git package marker
│   └── debian/perl         # perl package marker
├── pm-dep/                  # Perl module dependencies
│   ├── POSIX
│   ├── Getopt__Long
│   ├── File__Basename
│   ├── File__Copy
│   ├── File__Path
│   ├── File__Find
│   ├── File__Spec
│   ├── Cwd
│   ├── MIME__Base64
│   ├── Digest__SHA
│   └── JSON__PP
└── source/                  # Helper scripts
    ├── bootstrap            # Workspace initialization
    ├── init                 # Check init status
    ├── status-check         # Workspace status
    ├── checkpoint           # Quick checkpoint commits
    ├── quick-save           # Fast GitHub save
    ├── sign                 # Sign workspace files
    ├── verify               # Verify signatures
    ├── load-checkpoint      # Load conversation checkpoints
    └── transfer             # Transfer files to protocol-7
```

## Operations

### bootstrap
Initialize workspace environment:
- Create work directories
- Configure git identity
- Set up remote URLs with credentials
- Verify repository access

### init
Check workspace initialization status:
- Verify .initialized marker exists
- Guide through bootstrap if needed

### status-check
Intelligent workspace status analyzer:
- Check archive processing status
- Show git status and uncommitted changes
- Check remote sync status
- Verify git configuration
- Provide actionable recommendations

### checkpoint
Quick commit and push to save work:
- Add all changes
- Create timestamped commit
- Push to remote branch
- Preserve progress at context limits

### quick-save
Fast GitHub workspace save:
- Check for changes
- Stage and commit
- Push to GitHub
- Complete in 2-3 seconds

### sign
Sign workspace files with cryptographic signatures:
- Generate SHA256 signatures (MVP)
- Create signed YAML files
- Provide mathematical proof of authorization
- Enable models to verify user consent

### verify
Verify signed workspace files:
- Validate signature format
- Extract and verify payload
- Provide cryptographic proof of authorization

### load-checkpoint
View and load saved conversation checkpoints:
- List available checkpoints
- Load by session name or timestamp
- Display checkpoint contents for context restoration

### transfer
Transfer files from workspace-transfer to protocol-7:
- Read manifest configuration
- Interactive or automatic transfer
- Backup existing files
- Preserve permissions

## Dependencies

### Binary
- `git` - Git version control system
- `perl` - Perl interpreter

### Perl Modules
- `POSIX` - POSIX functions
- `Getopt::Long` - Command-line option processing
- `File::Basename` - File path manipulation
- `File::Copy` - File copying operations
- `File::Path` - Directory creation/removal
- `File::Find` - File tree traversal
- `File::Spec` - Cross-platform path operations
- `Cwd` - Current working directory
- `MIME::Base64` - Base64 encoding/decoding
- `Digest::SHA` - SHA checksums for signatures
- `JSON::PP` - JSON parsing

## Workflow Integration

### Standard Workspace Workflow
```bash
# 1. Initialize workspace (first time only)
zenka workspace-transfer bootstrap

# 2. Check status
zenka workspace-transfer status-check

# 3. Do work...

# 4. Quick checkpoint
zenka workspace-transfer checkpoint "Work in progress"

# 5. Quick save to GitHub
zenka workspace-transfer quick-save "Feature complete"

# 6. Transfer files to protocol-7
zenka workspace-transfer transfer --interactive
```

### Checkpoint Workflow
```bash
# 1. Export conversation checkpoint
perl scripts/export-context-checkpoint.pl --session-name=my-session

# 2. List checkpoints
zenka workspace-transfer load-checkpoint --list

# 3. Load specific checkpoint
zenka workspace-transfer load-checkpoint --session-name=my-session

# 4. Attach checkpoint to new chat for context restoration
```

### Signature Workflow
```bash
# 1. Sign a workspace command file
zenka workspace-transfer sign workspace-resume.yaml workspace-resume.signed.yaml

# 2. Verify signed file
zenka workspace-transfer verify workspace-resume.signed.yaml

# 3. Models verify signature before executing
# Math provides proof that language cannot
```

## Color Scheme

Blacklight neon aesthetic (matching git zenka):
- Background: `#090529` (Nailara)
- Blacklight: `#4427ac` (Purple)
- TRUE: `#0647c3` (Blue)
- Success: `#47c306` (Green)
- Warning: `#c58d07` (Orange)

## Integration Points

### With Other Zenki
- **git zenka**: Version control operations
- **debian zenka**: Dependency checking
- **workflow zenka**: Development automation
- **backup zenka**: Workspace backups

### With Workspace-Transfer Repository
- Uses `init.pl` for initialization check
- Uses `bootstrap.pl` for setup
- Uses `status-check.pl` for status
- Uses `commit_checkpoint.pl` for checkpoints
- Uses `workspace-sign.pl` for signatures
- Uses `validate-signature.pl` for verification
- Uses `github-integration/quick_save_workspace.pl` for GitHub saves
- Uses `scripts/load-context-checkpoint.pl` for checkpoint loading
- Uses `scripts/transfer-to-protocol7.pl` for file transfers

## Future Enhancements

- Add `handoff-to-code` operation for environment switching
- Add `handoff-from-code` operation for returns
- Add `export-checkpoint` operation for creating checkpoints
- Add `encrypt-checkpoint` operation for secure storage
- Add `decrypt-checkpoint` operation for restoration
- Add Ed25519 signatures (requires Crypt::Ed25519)
- Add automated backup creation before transfers
- Add harmonic validation for workspace operations

## See Also

- [/home/user/workspace-transfer/CLAUDE_ONBOARDING.md](../../../../workspace-transfer/CLAUDE_ONBOARDING.md) - Workspace onboarding
- [/home/user/workspace-transfer/bootstrap.pl](../../../../workspace-transfer/bootstrap.pl) - Bootstrap script
- [/home/user/workspace-transfer/workspace-sign.pl](../../../../workspace-transfer/workspace-sign.pl) - Signature tool

#,,,,.,.,,,,..,,,,,,,,,....,,,,.,,,.,.,,.,,,..,,,,.,,.,,..,,,...,,..,..,,,..,,,.
#PLACEHOLDER_FOR_AMOS7_SIGNATURE_LINE_1
#\\\|PLACEHOLDER_FOR_AMOS7_SIGNATURE_LINE_2
#\[7]PLACEHOLDER_FOR_AMOS7_SIGNATURE_LINE_3
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
