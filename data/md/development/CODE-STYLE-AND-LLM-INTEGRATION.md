# code style and llm integration vision

## overview

this document describes the protocol-7 code style principles and the vision for intelligent style enforcement through zenki systems, particularly how llm-generated code can be guided toward consistency without disrupting productive flow.

## core style principles

### visual narrative flow

code should read as a continuous, lowercase narrative. this creates a smooth visual rhythm when scanning the codebase quickly. consistent visual texture allows readers to absorb code patterns more naturally.

- **lowercase comments**: comments begin lowercase [ `## read config from stdin` not `## Read config` ]
- **no capital letters**: comments and simple statements maintain lowercase consistency
- **visual consistency**: the eye moves smoothly without jarring capitals breaking rhythm

### bracket and parenthesis conventions

use square brackets for annotations, clarifications, and contextual notes:

- `## read password [ no masking, no tty ]` - brackets for clarifying context
- `[ word ]` instead of `( word )` - consistent bracket style throughout
- maintains visual hierarchy and readability

### holographic consistency

the term "holographic" refers to the idea that each part of the codebase reflects the whole - consistent principles at all scales:

- comments at line level
- function structure
- module organization
- documentation style

when all levels follow the same principles, the codebase becomes more coherent and easier to navigate.

## why these principles matter

### speed reading and cognitive load

- **lowercase narrative**: eliminates visual punctuation that breaks scanning rhythm
- **bracket consistency**: creates predictable visual patterns the eye recognizes instantly
- **holographic structure**: developers recognize patterns immediately across different parts of the codebase

### quality correlation

empirically, codebases with strong visual and structural consistency tend to have higher code quality. the style itself becomes a quality indicator and reinforcement loop.

## llm integration and style enforcement vision

### current challenge

llm-generated code often has high functional quality but inconsistent style:
- capitalized comments breaking narrative flow
- mixed bracket vs parenthesis usage
- inconsistent lowercase conventions

traditional enforcement creates friction - rejecting or requiring rewrites during generation disrupts productive flow.

### proposed solution: intelligent mentoring

instead of strict gating, style enforcement should work like a thoughtful mentor:

#### phase 1: non-blocking correction [ during generation ]
- zenki silently fix minor style issues in generated code
- no rejection, no disruption to llm productivity
- output remains clean and consistent
- developer never sees the rough edges

#### phase 2: post-generation feedback [ after completion ]
- notify the llm of style corrections made
- explain the principle [ lowercase narrative, bracket consistency, etc ]
- document patterns to reinforce learning

#### phase 3: contextual adoption [ future generations ]
- llm naturally integrates style conventions from feedback
- each new generation in the context produces more in-style code
- followup zenki have progressively less cleanup work
- style adoption becomes natural, not forced

### advantages

1. **no disruption**: productive flow continues uninterrupted during generation
2. **quality output**: all delivered code is clean and consistent
3. **learning loop**: llm gradually adopts conventions through repeated feedback
4. **reduced workload**: future generations need less style correction
5. **voluntary improvement**: llm learns through context, not punishment

### example workflow

```
llm generates code with style issues
    ↓
zenki silently corrects style
    ↓
code delivered clean and consistent
    ↓
zenki notifies llm: "corrected lowercase comments and bracket usage"
    ↓
llm incorporates feedback into model context
    ↓
next generation: more in-style code
    ↓
future zenki corrections: fewer issues to fix
```

## implementation roadmap

### stage 1: formalize conventions [ current ]
document style principles clearly in yaml and markdown for reference

### stage 2: basic zenki enforcement [ near term ]
implement zenki that detects and silently correct common style issues:
- capitalize comment first letters → lowercase
- parenthesis in annotations → brackets
- inconsistent spacing patterns

### stage 3: intelligent feedback [ medium term ]
zenki analyze corrections and generate meaningful feedback:
- "corrected 3 capitalized comments for visual flow consistency"
- explain the principle behind each correction

### stage 4: llm context integration [ longer term ]
provide corrections and feedback to llm in structured format for next generation:
- prevents repeated corrections
- accelerates style adoption
- reduces zenki workload

## future expansion

as protocol-7 syntax and conventions grow:
- special module naming conventions
- particular patterns for state management
- zenki-specific code organization rules

all can be added to the yaml conventions file and referenced in llm prompts for initialization or periodic reminders.

## related documents

see `data/yaml/code-style/CONVENTIONS.yaml` for concise reference of all style conventions.

#,,.,,..,,,,.,.,.,,,,,,,,,,.,,,,,,,..,..,,,,,,..,,...,...,,..,.,,,.,,,.,.,,.,,
#DO6HY4O62YHSL7GA22O4EISQQ7P2DODATYLRHUFG4ZH42HWMGS2GLBFDCSH4E2HHQ4H33X4JFG7JQ
#\\\|4CKMCD7ODODTC2KDV77HJ5QJ3MGHFRKPXKUF3UESHXKFJMFGUUK \ / AMOS7 \ YOURUM ::
#\[7]OPSE6KDGN7H2PPQ7OD4KXGBKEGFKLQJZPXMRBNIFZYPK67G3ZADY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
