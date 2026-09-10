---
name: reference-zenka-callback-wrapper-prototype-pattern
description: "validated pattern for experimental/prototype zenki -- wire a single callback sub for startup-decision logic (zenka.v7 itself can't do conditionals), use a low-blast-radius sandbox zenka to prove it, assimilate into the real target zenka later"
metadata: 
  node_type: memory
  type: reference
  originSessionId: 25027270-dc9c-4fde-a219-c4e76981a4cf
  modified: 2026-09-09T21:48:46.648Z
---

For any new conditional start-up behavior, wire a single callback sub (e.g.
`zenki.parent.start-up`) called once from `zenka.v7`, and put all the branching logic inside
that sub -- `zenka.v7` itself is a linear bracket-command sequence with no native conditionals.
Established precedent beyond this session's work: `protocol-7-menu.graphical-startup-init`,
`mpv.startup.init`.

When prototyping a new cross-cutting capability that will eventually belong on a load-bearing
zenka (e.g. `v7-zenki`), build and prove it on a low-blast-radius sandbox zenka first (this
session used the pre-existing, unused `zenki` zenka), then transplant the proven callback into
the real target as a deliberate, separate follow-up -- don't build directly on the load-bearing
zenka.

**Why**: confirmed working end-to-end this session (2026-09-02) building `zenki.parent.start-up`
as a hybrid one-shot/resident dispatcher for the `zenki` sandbox zenka, intended for eventual
assimilation into `v7-zenki`. User: "the wrapper | callback approach looks good, exactly the
lightweight and flexible kind of element for experimental prototypes or reference implementations
to later assimilate."

**How to apply**: when a request needs branching startup logic (privilege handling, mode
detection, conditional module loading, etc.), reach for this shape by default rather than trying
to encode conditions in the config file. See [[project-v7-zenki-identity-rename-complete]] /
`HANDOVER.md` and `data/md/design/ZENKA-HYBRID-STARTUP-DISPATCH.md` for the concrete worked
example and its open transplant/marker-gap decisions.

**open disposition question (2026-09-09)**: the `zenki` sandbox is still sitting
unassimilated a week later. it woke up on-demand from a stray/misdirected reference during an
unrelated session, hit a real bug in its own start-up path (a startup-ordering race between
`base.stream.emit`/log-template init and first output), heartbeat-timed-out, and crash-looped
visibly in the live log before being disabled (`start.on-demand` set to 0, manually-stopped in
v7-zenki, ondemand registration removed). the user's framing this time: the namespace/identity
was "grabbed too casually, without much thought invested in the actual zenka" relative to the
care other zenki get, and it's unclear whether it should (a) get the originally-intended
transplant into `v7-zenki` and then be retired, (b) stay as an ongoing low-blast-radius
prototyping ground with more deliberate care put into it, or (c) something else. not decided --
the bug in its start-up path was never root-caused (deliberately, per explicit instruction not
to spend tokens on a disposable sandbox) so don't assume it's fixed if `zenki` is ever
re-enabled for real future use.

#,,..,..,,,..,...,.,,,,,,,..,,..,,.,.,,,,,.,.,..,,...,...,,,.,.,,,,,,,,.,,...,
#U2CASEMDCKFP725DEX7FU6R3NFYKMZERRIOMU2ZPCDDUF662KQIP3A6FTUFMAXIPPCGLLNZS7QNBA
#\\\|5URYJAXRJI4TXP6BSOMMLMNZSRE5TXWUK5OHNZLWH64UV5CUFKI \ / AMOS7 \ YOURUM ::
#\[7]QVBDTR3JVOILK4XQND2TIYEIVSFPFZ2JNFCHJ7RTHMYWF2FUX2AY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
