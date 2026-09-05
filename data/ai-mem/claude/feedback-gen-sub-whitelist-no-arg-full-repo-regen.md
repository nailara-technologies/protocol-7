---
name: feedback-gen-sub-whitelist-no-arg-full-repo-regen
description: "bin/dev/gen-sub-whitelist with NO target argument regenerates every zenka's whitelist repo-wide, not just the one you care about -- always pass the specific zenka name"
metadata:
  type: feedback
---

Every prior memory reference to this tool already shows it called with
a zenka argument (`gen-sub-whitelist <zenka>`) by precedent, but nothing
had explicitly documented what happens if you omit it. Found 2026-09-05
mid-task (`models-discover-cleanup.yaml`): ran bare `bin/dev/
gen-sub-whitelist` expecting it to regenerate just the zenka I'd been
editing (`models`). It instead started a full-repo regen across every
zenka's `subroutines.load-early` -- slow (didn't finish inside a 120s
foreground timeout, had to background it), and by the time it was
stopped it had already rewritten 4 unrelated zenki's whitelists
(`debian`, `keys`, `template`, `work`) with real, unreviewed diffs that
would have ridden into a commit meant to be scoped to `models` alone
(see [[feedback-stale-tool-output-rides-into-later-commits]] for the
general version of this risk).

**How to apply:** always pass the specific zenka name —
`bin/dev/gen-sub-whitelist models`, never bare `bin/dev/
gen-sub-whitelist`. If a bare invocation is ever run by mistake, kill
it immediately (it's slow enough that you'll have time) and
`git checkout --` any zenki whitelists you didn't intend to touch
before continuing — don't assume a regen you didn't ask for is
harmless just because the tool is "supposed to" produce correct output;
it's still unreviewed scope creep into an unrelated commit.

#,,,.,.,,,..,,.,.,..,,.,.,.,.,,.,,,.,,,..,.,.,..,,...,..,,..,,...,,,.,,.,,...,
#KUALYLECXJBYYPQQHW6CG7PB66GG33VLNYJFV2NLUV2CZLZZYPLP54TK3UGCIQNSNUD43OSAS5LB6
#\\\|XRMOSC5X3BSEGAHY75CFP23JA4RXGLCRE7D3UKUYRCAOBX2JUAW \ / AMOS7 \ YOURUM ::
#\[7]YIGR7O3X7GEN42FPAVID4YOTNJ33S6ZZUDSJX3YNTGPVZED6C6DI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
