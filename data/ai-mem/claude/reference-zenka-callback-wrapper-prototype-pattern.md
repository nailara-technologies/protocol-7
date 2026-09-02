---
name: reference-zenka-callback-wrapper-prototype-pattern
description: validated pattern for experimental/prototype zenki -- wire a single callback sub for startup-decision logic (zenka.v7 itself can't do conditionals), use a low-blast-radius sandbox zenka to prove it, assimilate into the real target zenka later
metadata:
  type: reference
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

#,,,.,,,,,.,.,,,.,..,,.,.,.,,,,..,.,.,,..,,..,..,,...,...,.,,,.,,,,,,,,,.,.,,,
#FEQQJ2GIMPNLJBBNGZZPPCCD6JXBTPSP3QB7LTFTHRO2AUZW36SX6UFOWXXMV4C2MIT6PUK3BYONS
#\\\|GY3AGO4BYUQPLTEOXCECOMDNCRPGSHM6NW3SVQ6CT5TM6PUMVJ4 \ / AMOS7 \ YOURUM ::
#\[7]OTWOCWE4XV4QKIUTI7GPYNBQFBD673LHC3KLBKEF3JAEISK3NIBA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
