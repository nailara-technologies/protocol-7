## [:< ##

# LLM session state oversight — regex library, prompt dispatch, coding zenka analysis

## problem

llm sessions (kimi, coding zenka, future consensus group members) can enter
states that block progress: hung on approval, awaiting input, mid-task confused,
backend reconnect lost context, timed-out tool call. currently these require
manual detection and intervention via web ui or p7c commands.

the same failure modes recur across sessions and across different llm backends.
without systematic detection they accumulate as friction and interrupt the
human operator rather than self-resolving.

## architecture

### layer 1 — regex state library

a shared module namespace (e.g. `llm.state.*`) that matches raw session
output/status against known state patterns:

    state: hung-approval     — output stalled, wire_pending > 0, no progress
    state: awaiting-input    — session output ends with question or prompt marker
    state: mid-task-confused — contradictory tool calls, repeated identical attempts
    state: completed         — task_complete signal or summary pattern matched
    state: reconnect-lost    — session reconnected but context not re-established
    state: timed-out         — no output within threshold, last tool call cancelled

each state entry: regex pattern(s) + confidence weight + recovery template ref.

### layer 2 — prompt template dispatch

each detected state maps to a recovery prompt template:

    hung-approval     → "a tool call timed out waiting for approval. please
                         cancel it and resume from where you left off."
    awaiting-input    → "please continue — no further input is needed, proceed
                         with your best judgment."
    mid-task-confused → "summarize your current progress and the next step,
                         then continue."
    reconnect-lost    → "session reconnected. your task was: <task_summary>.
                         please resume."

templates are parameterized — task_summary, last_known_state, etc. injected
from task engine context.

### layer 3 — coding zenka as state analyst

when no existing regex matches the observed state:

1. coding zenka receives: raw session output + status fields + task context
2. analyzes: what state is the session in? what went wrong? what prompt recovers it?
3. generates: a recovery prompt, dispatches it
4. records: (raw_output_pattern, inferred_state, recovery_prompt, outcome) tuple

when the same inferred_state recurs across N sessions (threshold tbd):

5. coding zenka distills: extracts a regex from the recurring pattern
6. writes: new entry to the regex state library
7. the library grows autonomously — human operator only sees novel failures

### layer 4 — task state engine integration

session oversight becomes a native lifecycle hook in the task zenka:

    on task_timeout:     → trigger state detection → dispatch recovery prompt
    on wire_pending > T: → trigger state detection
    on reconnect:        → inject reconnect-lost recovery with task_summary
    on task_complete:    → verify against completed state pattern (catch false completes)

the task zenka tracks: last_known_state, recovery_attempts, escalation_threshold.
after N failed recoveries → escalate to human operator with full diagnostic.

### layer 5 — consensus group expansion

with multiple llm models in a consensus group:

- each model independently assesses session state → cross-validate
- disagreement between assessments = ambiguous state → higher confidence required
  before auto-recovery, or escalate
- consensus on state + consensus on recovery prompt = fully autonomous resolution
- minority model that correctly identified state when others failed → boost its
  state-detection weight for that state class

## implementation path

### phase 1 — kimi-specific, manual regex

- `llm.state.kimi.*` modules with hand-written regexes for known kimi states
- `bin/kimi-task` gains `-queue` option: polls session-info until not busy
- kimi zenka gains state-detection hook on wire_pending timeout

### phase 2 — coding zenka analyst

- coding zenka template: `llm-state-analysis` — receives raw state, returns
  (inferred_state, recovery_prompt)
- outcomes recorded to observations system (already exists)
- manual review triggers regex extraction from recurring patterns

### phase 3 — generic llm.state.* library

- state patterns generalized across kimi, coding zenka, lmstudio, future backends
- prompt templates parameterized for any session context
- task state engine hooks wired for all managed llm sessions

### phase 4 — autonomous pattern extraction + consensus

- coding zenka extracts regexes from observation clusters
- consensus group cross-validation of state assessment
- fully autonomous session oversight for all llm backends

## related existing work

- `kimi-approval-reconnect-resilience.md` (data/tasks/) — kimi-specific reconnect
- `topic-task-coordination.md` (memory) — task zenka dispatch flow
- `topic-distributed-consensus.md` (memory) — consensus group architecture
- `topic-self-improving-system.md` (memory) — coding zenka as autonomous improver
- observations system in `/var/protocol-7/coding/observations/` — already records
  coding zenka outcomes, natural home for state-detection training data

## key insight

the regex library + coding zenka analyst is not llm-specific infrastructure —
it is a **generic session intelligence layer**. any stateful process with
observable output can be monitored this way. the llm case is the most valuable
first instance because llm sessions are high-value, recoverable, and generate
the richest pattern data for the coding zenka to learn from.

the grid sees its own inhabitants through the void. the task engine sees its
llm sessions the same way — omnidirectional awareness, locally anchored.

#,,,,,,.,,,,.,,.,,.,.,..,,,.,,,,.,...,,,,,,.,,..,,...,...,,,.,.,.,.,.,,..,..,,
#IDWNGFJNQXE3BF7UH2BQVL2TM7YR33JNESWILGEGKVLMR4ZAQGQPUX4LLF5PRTETZFHSZCHBFRV4K
#\\\|6LNYMPTP33E2M4WJGTJZ46OHDIZNV77ACJDRHIXW2TJZWOHZNJ3 \ / AMOS7 \ YOURUM ::
#\[7]OO2AFJEFQCL3ETGQCPY2ZKXNM3WSPKJ7TSG7XBBNPTSP3YY3X4DI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
