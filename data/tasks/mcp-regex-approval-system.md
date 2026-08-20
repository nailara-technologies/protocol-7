## task: regex-based multi-model consensus approval system for MCP permissions

### motivation

current MCP approval is per-tool-call (user clicks allow/deny each time).
a regex approval system lets the user approve a PATTERN of commands once,
encoded by a multi-model security consensus, repeatable automatically for
all matching future calls.

### design

#### approval flow

1. a new command arrives needing approval
2. **multi-model security review** (parallel):
   - model A (e.g. Qwen 9B): is this command safe in general? what class is it?
   - model B (e.g. second Qwen 9B or NIST-specialized): catch reasoning errors
   - consensus: if both agree safe → proceed to regex generation
   - if disagreement → escalate to user
3. **regex generation**: model generates a regex that matches this command
   AND all structurally similar safe commands, but NOT unsafe variants
4. **regex testing**: test regex against:
   - the current command (must match)
   - known-safe examples (must match)
   - known-dangerous variants (must NOT match)
5. **store decision**: if tests pass → store regex in approval library
6. **future calls**: run regex against command; if match → auto-approve;
   if no match → trigger review again

#### exception mode

when a model determines a command is safe ONLY in the specific current
context (not generally safe), it returns:
```
CONTEXT_EXCEPTION: <reason why this is safe only now>
```
this approval is NOT stored in the regex library — it's one-time only.
the model must explicitly choose this path; silence = store the regex.

#### approval library

stored at `cfg/mcp/approval-patterns.yaml`:
```yaml
---
patterns:
  - regex: 'p7c\s+jobsite\.(status|progress|reload)\b'
    description: jobsite read-only status commands
    approved_by: [qwen-9b, qwen-9b-2]
    approved_at: 3TBNBF6YLGCNKCQ
    risk_level: none
  - regex: 'git\s+(log|diff|status|show)\b'
    description: git read-only inspection
    approved_by: [qwen-9b, qwen-9b-2]
    approved_at: 3TBNBF6YLGCNKCQ
    risk_level: none
```

#### implementation

new MCP tool `approval_review`:
```
params:
  command     the command string needing approval (required)
  context     brief description of why it's needed (optional)
returns:
  decision:   approved|rejected|exception|escalate
  regex:      the generated approval pattern (if approved)
  reason:     explanation from models
```

integrates with the existing Claude Code permission system — when a tool
call is blocked, the harness can call `approval_review` before prompting
the user.

two local 9B models run in parallel (using the coding zenka's multi-model
inference already implemented in `llm.service.consensus_vote`). the NIST
SP 800-53 security control catalog can be embedded as a system prompt
context for the reviewer models.

#### regex safety properties

the generated regex must satisfy:
- **specificity**: matches the command class, not any string
- **anchoring**: uses `\b` word boundaries, not loose `.*`
- **no escalation capture**: regex cannot match `sudo`, `rm -rf`, `dd if=`,
  or other destructive patterns even via wildcards
- **tested**: passed against a built-in test suite of 20+ dangerous variants

---

## dispatch

#,,.,,,,,,,.,,.,,,,..,,.,,..,,.,,,,.,,,.,,.,.,..,,...,...,..,,...,,,,,.,.,,..,
#L4MKTHMGFUVV5NBR2TLYKMKYFGH2JQE73OJXG7DSH2NNPXXADJWZJLVY2GSVFFJMSX7WMT2X2PCGE
#\\\|BORR6QKVOPFA6PBWAH5N3M6O27NSZGVJBRNXDJIMQAW3GG2FP6W \ / AMOS7 \ YOURUM ::
#\[7]B53SZ2RVH6RTFEEVGTHAWOJHXALMA6MZW7DQJQ4XGIHIG4RS5SAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
