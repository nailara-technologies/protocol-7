## [:< ##

# name  = design: developer workflow acceleration track
# descr = four complementary improvements that compound: ncode zenka
#         (workflow primitives as network commands), intelligent log wrapping,
#         graphical diff + signing client, and LLM session keys for branch
#         commits. each accelerates commit cycles and reduces manual effort.
#         together they tie into the key-tree namespace structure projected
#         onto version control.

## why this track

every commit currently involves: manual staging, signing individual files,
reviewing diffs in terminal, typing commit messages. several minutes of
mechanical work per commit, repeated dozens of times per session.

the acceleration track targets each bottleneck:

```
bottleneck              fix
──────────────────────  ─────────────────────────────────────────────────
ncode functionality     ncode zenka: network-accessible, composable,
only in bin/ncode       integrated with the rest of the system

log review slow         intelligent log wrapping: LLM-assisted optical
                        quality, language quality, auto-splitting

diff review in          graphical diff client: visual, side-by-side,
terminal                color-coded, one-click stage/unstage

signing one file        signing client: batch sign, preview which files
at a time               need signing, verify before commit

LLM can't commit        session keys: models sign to feature branches;
to git directly         base integration re-signs with developer key
```

## 1. ncode zenka — highest priority

`bin/ncode` is a powerful tool. it currently lives as a standalone binary.
as `src/ncode.*`, its functionality becomes:
- composable with other zenki
- callable via p7c from scripts and LLM tools
- a foundation for LLM-assisted log optimization and code review

existing: `data/md/coding-tasks/ncode-zenka-self-refining-regex.md`
          `data/tasks/ncode-workflow-patterns.md`

task: `data/tasks/ncode-zenka-modules.md` (to be written)

core modules to expose:
```
ncode.cmd.search        search codebase by pattern
ncode.cmd.replace       replace in file/range
ncode.cmd.parse-headers parse module headers
ncode.cmd.format-code   perltidy formatting
ncode.cmd.sign-file     sign a single file
ncode.cmd.sign-batch    sign multiple files matching a pattern
ncode.cmd.diff          diff two files or a file vs git HEAD
ncode.cmd.diff-staged   diff all staged files
```

## 2. intelligent log line wrapping

current log lines are long, manually formatted, inconsistent.
intermediate step before full ascii-template-based log rendering:

```
phase 1:  LLM-assisted log message quality review
          ncode zenka reads a log message, LLM ranks it on:
          - optical quality (length, alignment, whitespace)
          - language quality (clarity, precision, style consistency)
          - information density (does it contain what a reader needs?)
          returns: ranked options + suggested rewrites

phase 2:  preview + commit + rollback
          preview change in context before applying
          commit replaces the message in the module
          rollback restores previous version (git-tracked)
          category-level rollback: undo all log message changes in one op

phase 3:  pattern library for log message classes
          similar to signal-cancel-log-library but for output quality:
          known-good patterns → new messages scored against them
          LLM populates the library; scoring is fast regex
```

relates to: `data/tasks/signal-cancel-log-library.md` (same pattern,
different domain)

## 3. graphical diff + code signing client

a GTK3 window (using window.place zenka) showing:

```
left panel:   git diff output, color-coded, file-by-file
right panel:  file list with signing status (signed/unsigned/modified)

actions:
  stage file        one click → git add
  unstage file      one click → git restore --staged
  sign file         one click → sourcecode sign + restage
  sign all unsigned batch sign all modified files in one operation
  commit            message field + commit button
  preview commit    shows what the commit will contain
```

ties into: `data/md/design/SIGNED-COMMAND-INTERFACE.md`,
           `data/md/design/CODE-NAMESPACE-AND-SIGNING-INFRASTRUCTURE.md`

## 4. LLM session keys for branch commits

the key-tree namespace structure projected onto version control:

```
developer key (root):
  → signs base branch commits (highest authority)
  → authorizes creation of session keys

LLM session key (derived, ephemeral):
  → signs commits to feature branches freely
  → cannot directly commit to base
  → base integration: developer key re-signs the merge commit
    (or a signing zenka re-signs under developer supervision)
```

this is the key-tree authority model (`data/md/design/KEY-TREE-AUTHORITY-FIELD.md`)
applied to git:

```
root key      = developer signing key
branch key    = session-derived key for a specific feature branch
commit signing = same HMAC-SHA256 derivation as keyring.sign
base merge    = re-signing ceremony: session key → developer key
```

properties:
- LLMs and zenki can commit freely to feature branches at any time
- base branch integration always requires developer key involvement
- the re-signing ceremony is explicit and auditable
- feature branches can have multiple LLM contributors, each with their
  own derived session key

future: global change-group-aware version control where commits carry
their dependency graph and workflow trees — the deduplication tree applied
to code history.

## 5. knowledge base 3D grid — depth as history

the knowledge base search currently returns flat results. a 3D model:

```
X axis:  topic/namespace position
Y axis:  paragraph/section within document
Z axis:  historical depth — how old is this occurrence?

visualization:
  recent hits:   bright, front plane
  older hits:    dimmer, deeper plane — phosphor persistence metaphor
  oldest hits:   faintest, deepest — still present, still queryable,
                 but naturally attenuated by time
```

the 2D paragraph matrix the user described (match + surrounding context)
is the X-Y plane. Z is history. blue translucent layers in depth,
oldest deepest and least visible but integer-precisely encoded:

```
depth encoding:   full bit range available per layer
                  oldest layer at maximum depth still carries
                  full precision — attenuation is visual, not lossy
                  color-to-depth mapping is invertible
```

this creates a semantic cloud that surfaces relevant context
automatically — not through LLM inference but through the geometric
structure of accumulated history.

relates to: `data/yaml/reasoning-templates/categorical-compartmentalization.yaml`
            (temporal compartmentalization as depth axis),
            `data/md/design/HARMONIC-SILENCE.md` (oldest = most cancelled,
            newest = brightest on the anomaly canvas)

## implementation priority

```
1. ncode zenka modules        — workflow accelerator, enables everything else
2. contextualized error replies — small, immediate value, data/tasks/ ready
3. graphical diff+signing     — commit cycle accelerator
4. LLM session keys           — enables autonomous branch work
5. intelligent log wrapping   — quality improvement, needs ncode zenka first
6. knowledge base 3D grid     — longer horizon, builds on memory tree system
```

#,,.,,...,..,,,,,,.,,,...,,,.,.,.,.,,,.,,,,,.,..,,...,...,..,,.,,,,.,,...,,,.,
#JCLAKKR76P64QM7F5YMSLM5Q3OU5BLZTCFAQ22GNHCQVBYEUYJBM72NW3G4PAMS7II2AN4LI6X72O
#\\\|WYLMPUTRE7PEXSKIS4QZO3OCU3C62Q64TK3VWCWZSCP3VLLHXHS \ / AMOS7 \ YOURUM ::
#\[7]WJHHSDUGMKOCPRU5DGQW7NPTFGQJB75AUKN7NZY33W55FDOABGBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
