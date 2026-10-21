---
name: managed-abstraction
description: base design principle [ user 2026-10-21 ] -- layered managed abstraction : each layer settles what it can know, the user enters only where a real decision remains ; the layering is what keeps it stable
metadata:
  type: project
---

**managed abstraction** [ named by the user 2026-10-21, "will be a base principle" ] : a system built in LAYERS, each settling what it can know on its own -- detection from what a user or admin already stated once [ /etc/hosts, ~/.ssh/config, known_hosts, pins, discover \ nodes, dns, other records ], a sanity filter that drops invalid \ contradicting values and says why, defaults that are the user's own earlier answers. the user enters only the layer where a real decision is left.

- **depth per moment** : under time pressure [ clarity reduced to accept, accept, accept ] the top layer alone yields a CORRECT result ; with time, any layer opens and overrides. same system, no separate "expert mode"
- **the layering is what makes it stable** [ user ] : each layer is small, checkable and replaceable on its own ; a wrong guess stays contained in one layer and is visible there
- **context ranks the options** [ user ] : each candidate carries where it came from [ which file, which earlier statement, which pin agrees ] -- that context and those references let the layer RANK, so the best answer comes first and the reason is visible. a flat, indifferent list of options leaves all the weighing to the user, the exact work time pressure takes away
- offer and explain, never apply silently, never refuse -- same line as [[warn-dont-restrict-user-choices]]

**Why:** setups happen under pressure ; defaults must BE the right answer then, not something to remember. **How to apply:** for any setup \ config \ form flow [ host-edit first : todo Q7O, then user-edit, p7-deps profiles, zenka configs ], ask per field : what layer can already know this, from which prior statement, and what filter rejects a bad candidate -- before adding another prompt.

#,,,.,,,.,..,,.,,,..,,,.,,..,,..,,,.,,,..,,,.,..,,...,..,,,..,..,,,.,,.,,,.,.,
#CPOLEIKKNYTFBI5RM4TSSBD3XHOXFT7TRPVWNDYQ627EWLNQ3IW7UNYAL4TFCCHJISSDEVMZZRBNA
#\\\|42AO6YMAQCTMTJISAXHMT2XV4YL6KYQ5MQCDERPDTPY3SUM6MPL \ / AMOS7 \ YOURUM ::
#\[7]K2IMGMULNSUJCVBIJFKUIDAYMTJ5Z47N7GVVZE4UNWWFR56ZE6CQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
