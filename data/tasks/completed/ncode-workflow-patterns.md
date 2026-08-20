# task: ncode workflow frames + pattern registry + ncode.cmd.apply

## context

the ncode.* namespace has the regex pattern infrastructure (load/save/apply/
assess/expand) and the LLM transform layer (transform.wave). this task wires
them into a usable workflow system: content-addressed fix listing, apply-by-id,
workflow frames that sequence what comes next, and pre-seeded common patterns.

existing modules to understand first:
- `src/ncode.init_code` — state setup, <ncode.patterns>
- `src/ncode.regex.load` — load YAML → <ncode.patterns>
- `src/ncode.regex.save` — save <ncode.patterns> → YAML
- `src/ncode.regex.apply` — apply a named pattern to files
- `src/ncode.regex.assess` — score pattern usefulness
- `src/ncode.transform.wave` — LLM-backed batch transform
- `src/ncode.cmd.search` — existing search command

## part 1: ncode.cmd.suggest

scan changed or specified files, detect applicable patterns from the loaded
registry, emit a listing with AMOS checksum IDs.

```
ncode.cmd.suggest  { files, patterns, session_id }

algorithm:
  session_root = amos-chksum( ntime :: files_joined )
  for each loaded pattern in <ncode.patterns>:
    for each file in scope:
      scan for pattern.detect trigger
      if matched:
        fix_id = space.template.chain( parent => session_root,
                                       data   => pattern.name . ':' . file . ':' . line )
        push result: { fix_id, pattern_name, file, line, preview }

output format (one line per fix):
  KQQ6E7A  flat-key→tree   src/space.jump.available:14
  ABCDE7F  exists-guard    src/space.register.node:46
  ...
  session: ROOTCHK
  apply one:  p7c ncode.apply KQQ6E7A
  apply all:  p7c ncode.apply --session ROOTCHK

store pending fixes in <ncode.pending>{$fix_id} = { pattern, file, line, ... }
return { mode => 'size', data => $formatted_listing }
```

## part 2: ncode.cmd.apply

apply one or more fixes by checksum ID from the pending store.

```
ncode.cmd.apply  { ids, session }
  ids     = [ fix_id, ... ]  or empty (apply all in session)
  session = session root checksum (apply all fixes from that session)

for each fix_id:
  look up <ncode.pending>{$fix_id}
  retrieve pattern steps from <ncode.patterns>{pattern_name}
  apply each step in sequence (ncode.regex.apply per step)
  verify: run pattern.verify check
  on pass:  mark fix applied, log
  on fail:  revert via ncode restore-backup, log failure

return { mode => 'size', data => applied_count . ' fixes applied' }
```

## part 3: workflow frames

a workflow frame sequences: detect → steps → verify → suggest_next.
store frames in `<ncode.workflows>` (loaded from YAML alongside patterns).

```
ncode.cmd.workflow  { name, files }
  load workflow frame by name
  run detect on files
  if triggered: run sequence steps in order
  after each step: run verify
  on all verify pass: run suggest_next (emit what to do next)
  return { mode => 'size', data => $workflow_summary }
```

**frame: kimi-output-review** (run after any kimi-generated modules):
```yaml
name: kimi-output-review
detect:
  trigger: any new src/space.* or src/branch.space.*
sequence:
  - pattern: p7-tree-syntax-fix
    verify:   no $<space. remaining, no ->$var}, no ->//
  - pattern: p7-exists-code-guard
    verify:   no exists $code{ in changed modules
  - pattern: p7-comment-style
    verify:   vc-changed-files -exc-len clean
  - step:     ptd-pass
    verify:   all ptd pass
suggest_next: sign-and-commit
```

**frame: namespace-migration** (run after ncode bulk rename):
```yaml
name: namespace-migration
sequence:
  - step: ncode parse-headers
  - step: ncode replace callers
  - pattern: p7-arg-regression
  - step: ptd-pass
suggest_next: update subroutine whitelist
```

## part 4: seed pattern YAML

create `data/yaml/ncode-patterns/p7-common.yaml` with these patterns:

### p7-tree-syntax-fix
```yaml
name: p7-tree-syntax-fix
description: flat $data{'x.y'}{ keys → <x.y>-> P7 tree syntax
detect: "data..space\\."
steps:
  - tool: ncode
    search:  "data..{namespace}..."
    replace: "<{namespace}>->"
    note:    dot-mask braces; 2 leading dots for {', 3 trailing for '}{
  - tool: ncode
    search:  "\\$<{namespace}\\."
    replace: "<{namespace}."
    note:    strip orphaned $ prefix
  - tool: perl
    pattern: '->(\$[a-zA-Z_])'
    replace: '->{$1'
    note:    re-add missing { before variable dereferences
  - tool: perl
    pattern: '->\/\/'
    replace: ' //'
    note:    defined-or is not a dereference
verify:
  - no_match: '\$<[a-z]'
  - no_match: '->\$[a-z]'
  - no_match: '->\/\/'
```

### p7-exists-code-guard
```yaml
name: p7-exists-code-guard
description: remove exists $code{'module'} guards — all modules loaded together
detect: "exists .code."
steps:
  - action: manual
    note: >
      remove if/else guards; keep primary <[module]>->() call; drop else fallback.
      for complex fallbacks: keep logic, remove the guard condition.
verify:
  - no_match: "exists .code."
```

### p7-arg-regression
```yaml
name: p7-arg-regression
description: $ARG not $_ ; TRUE/FALSE not 1/0 for booleans
detect: "\\$_\\b|'repeat' => [01]\\b"
steps:
  - tool: ncode
    search:  "\\$_"
    replace: "$ARG"
    note:    only in non-regex contexts; ncode will show preview
  - tool: ncode
    search:  "'repeat' => 1"
    replace: "'repeat' => TRUE"
verify:
  - no_match: "\\$_\\b"
```

### p7-comment-style
```yaml
name: p7-comment-style
description: lowercase comments, [ word ] annotations, max 79 chars
detect: "## [A-Z]|##.*[A-Z][a-z].*--"
steps:
  - action: manual + ptd
    note: ptd reformats long lines automatically; capitalize detection is advisory
verify:
  - tool: vc-changed-files -exc-len
    expect: no output
```

### p7-signature-stub
```yaml
name: p7-signature-stub
description: detect kimi-added stub signatures — blocks real signing
detect: "#,,.,,,..,,"
steps:
  - action: strip footer lines matching stub pattern
    note: leave file clean; update-signatures adds real footer
verify:
  - no_match: "#,,.,,,..,,"
```

## part 5: basic use case test

after implementing, verify this workflow:

```bash
## 1. load patterns
p7c ncode.regex.load '{"file":"data/yaml/ncode-patterns/p7-common.yaml"}'

## 2. suggest fixes on a test file with known issues
p7c ncode.cmd.suggest '{"files":["src/space.search"]}'
## expect: listing with AMOS IDs for any detected issues

## 3. apply by ID
p7c ncode.cmd.apply '{"ids":["KQQ6E7A"]}'
## expect: fix applied, verify passes

## 4. apply all from session
p7c ncode.cmd.apply '{"session":"ROOTCHK"}'
## expect: all pending fixes applied

## 5. run workflow frame
p7c ncode.cmd.workflow '{"name":"kimi-output-review"}'
## expect: sequenced application, suggest_next = sign-and-commit

## 6. clean test data
p7c ncode.regex.load '{"file":"data/yaml/ncode-patterns/p7-common.yaml"}'
## patterns loaded fresh, no test artifacts
```

## connections

- `space.template.chain` — fix_id derivation (parent:fix_data chaining)
- `amos-matrix` — visualize fix checksums for quick recognition
- `branch.route.cache` — pattern frequency/resonance (most-used patterns inner shell)
- `ncode.regex.expand` — discovers new patterns from fix history
- `data/ai-mem/claude/feedback-ncode-tools.md` — ncode dot-masking patterns

## code style

$ARG not $_, TRUE/FALSE, lowercase comments, [ word ] annotations.
no signature stubs.

## success criteria

- [ ] ncode.cmd.suggest lists fixes with AMOS checksum IDs + session root
- [ ] ncode.cmd.apply KQQ6E7A applies the specific fix
- [ ] ncode.cmd.apply --session ROOTCHK applies all from session
- [ ] ncode.cmd.workflow 'kimi-output-review' runs 4-step sequence
- [ ] data/yaml/ncode-patterns/p7-common.yaml loads cleanly
- [ ] all 5 patterns detect correctly on known test cases
- [ ] test data cleaned, patterns persist in YAML
- [ ] all pass ptd, no signature stubs

#,,,.,,..,...,.,.,,.,,,,,,...,.,.,,,.,,,.,,,.,..,,...,...,..,,...,,.,,,..,,,,,
#5N5QQHUK2YKA3GUL63NQ42AL7XVWJU463WXNBZSYNQ245BO6KDNPIRBI3H4I6AEDEEWOBRTSR6S24
#\\\|6Q2JFT2HKLEKSOUEWRAEB6V2VPCHMVIMWS6XBWAAOZHKKBUP2QT \ / AMOS7 \ YOURUM ::
#\[7]F5TTBAXU342FXF6OF67EXQNISUNTMPGFMGN6K3SNYKRXE34Y4GAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
