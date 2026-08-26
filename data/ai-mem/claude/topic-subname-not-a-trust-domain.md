---
name: topic-subname-not-a-trust-domain
description: nothing about zenka addressing/process topology implies trust — only session id + whatever explicit auth happened on it; shared name, shared subname, and even parent/child forking are all structural, not trust, facts
metadata:
  type: vision
---

General principle: trust attaches to a **session id**, established by
whatever explicit auth actually happened on that session — never to any
structural fact about how the zenka network is organized. Three separate
ways this gets conflated, all the same mistake:

1. **Shared subname** — a pure routing/grouping convenience layered on top
   of a shared zenka name (`[[topic-x11-bare-name-routing-ambiguity]]`'s
   established principle: "subname is a group tag, not a tie-breaker" — but
   that's about *routing* semantics only). Carries no implied trust
   equivalence between instances sharing that name.
2. **Shared bare name** — same point, one level up: `user[taeki]` and
   `user[root]` sharing the literal string `user` is an addressing
   artifact, not evidence of a shared trust principal.
3. **Parent/child forking** — the child-zenka model (parent forks a child
   for a task, child "remains network-accessible," unlimited nesting depth)
   means a forked child does **not** inherit the parent's trust standing
   just by descending from it. A distinct session id is its own security
   zone regardless of how that session came to exist — forked, on-demand
   spawned, or independently connected, all identical from a trust
   standpoint.

Concretely: a zenka literally named `user`, addressed per-account as
`user[taeki]`, `user[claude]`, `user[root]`, must be reasoned about with
exactly the same severity as if those were three entirely distinct
top-level zenka names (`taeki`, `claude`, `unix-root`).

**Where this bites**: any permission grant or severity judgment phrased
against a bare name (not a resolved `name[subname]` pair) implicitly spans
every subname underneath it in one grant — e.g. a hypothetical
`group-next user` admin-override grant (see
[[topic-zenka-name-routing-modes]]) would simultaneously hand override
power over however many unrelated trust principals happen to share that
name, easy to mis-reason-about as "just the user zenka" rather than "this
grant spans N distinct identities."

**How to apply**: `access.cmd.usr.*` and any future permission/severity
model must evaluate grants per resolved `name[subname]` pair (or per session
id, for the forking case) wherever addressing can span meaningfully distinct
principals, never discounted just because a name, subname, or process
lineage is shared. Note this is adjacent to, but distinct from, the
already-known deferred gap in [[topic-x11-bare-name-routing-ambiguity]]
(`list` granted globally with no parameter-level restriction between
`list:subnames`/`list:sessions` etc.) — that's about restricting *which
query* a grant allows; this is about correctly scoping severity *within* an
action that already spans multiple identities sharing some structural
attribute.

#,,.,,...,,..,..,,.,.,,,.,..,,,,.,.,.,,,,,,,.,..,,...,...,...,,,.,,,,,...,,..,
#FTSFQIYX2CYAGLNOYEXLPPXE7SIZ5X2GSTAMYJBMA3NXSVKHE4ZYBLNHUJGGLLN3QN5AH5LGT5XDU
#\\\|4IUOCR4JZM4G5CUEBVXHUGZUFRSDIF7DYF4KCQCODQS2L747PRT \ / AMOS7 \ YOURUM ::
#\[7]IFIR2FVYNBAM3BS4VFIU7TL52ZCEM4PZBS5YASGZ2FKJD7GC3SAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
