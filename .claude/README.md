# Claude Code Configuration

This directory contains Claude Code configuration files and project context.

## Configuration Files

- `settings.local.json` - Local settings (tracked with defaults, changes show in diffs)
- `commands/` - Custom slash commands (untracked, add as needed)
- `hooks/` - Git hooks and automation scripts (untracked, add as needed)

## Project Context

- `project-context.md` - Quick navigation to Protocol-7 documentation
  - Points to YAML extracts for token efficiency
  - References comprehensive markdown documentation
  - Explains module patterns and development workflow
  - **Claude: You may update and improve these context files as needed**

## Protection Strategy

The directory structure is protected via tracked files:
- `.gitkeep` - Ensures directory exists
- `README.md` - This documentation
- `settings.local.json` - Default settings template

## Workflow

1. `settings.local.json` is tracked with minimal defaults
   - Modify locally as needed
   - Changes appear in `git status` and diffs
   - Decide per-change whether to commit or keep local

2. `commands/` and `hooks/` are fully ignored
   - Create custom files without git tracking
   - Remain local to your environment
   - Protected from `git clean` by parent directory structure
