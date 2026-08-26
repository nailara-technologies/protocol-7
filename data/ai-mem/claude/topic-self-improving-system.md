---
name: self-improving system vision
description: long-term architecture goal — autonomous LLM coordination as foundation for self-improving P7 network
type: project
---

## vision

the llm coordination zenka (task: llm-coordination-zenka.yaml) is not just
a workflow tool — it is the foundation for a self-improving system and network.
each clean implementation step becomes a permanent, well-used foundation from
that point on.

## the loop

the system closes when it can:
1. look at its own task queue
2. identify which steps are independently executable (no user input needed)
3. assign them to the llm with capacity and affinity
4. verify results autonomously
5. update the queue and surface only genuine decision points to the user

## user role in the loop

the user's role is direction and domain knowledge — not gatekeeping between
steps. LLMs work through gaps (nights, between sessions) on clearly defined
testable steps. tokens do not expire unused at session boundaries.

## what already exists as foundation

- task decomposition: data/yaml/coding-tasks/ system
- handover context packaging: AI-COLLABORATION-GUIDE.md pattern
- message routing: cube zenka
- autonomous execution scaffolding: coding zenka
- the coordination zenka is largely the integration layer making these
  pieces self-aware and self-directing

## key design requirement

tasks must be decomposed to the point where the next step is *executable
without a question* — enough context, clear acceptance criteria, verifiable
result. the llm should never be idle at a boundary waiting for input it
could have been given in advance.

## noted

2026-03-17 — after kimi weekly token reset with >50% unused due to work
blocked on user input during sleep. the coordination system prevents this
by making work independently continuable.

#,,,.,.,,,...,...,,,.,.,,,,,.,.,,,,,.,,,.,..,,..,,...,...,.,,,.,,,...,..,,,,.,
#2KQCI3ZNJMGOPORAPCEXZ5VKNPK3YTVMSSVRZ76BOA5KQWWNNUEMS3VERFF37E7QBJDKVTE6L7NHE
#\\\|AIJMJIBY7X3C3MGWCKKQGSM6AQNF4ADRFLA3BTN5IIUG6CSPPZE \ / AMOS7 \ YOURUM ::
#\[7]HEQYMNGBU24YCMWU3VSDUSIETCA5OV55ABH5STX6Q3YLD23XLCDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
