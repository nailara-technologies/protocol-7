---
name: layer-matrix-convergence
description: "reversible layer-matrix/diff algebra recognized as the single primitive underlying v7 self-restart, zenka migration, branching, and differential-addressing — now its own design doc"
metadata: 
  node_type: memory
  type: project
  originSessionId: 4701e5c1-7db4-4798-bcf6-417046499fe6
---

a multi-step design-ideation exchange (2026-06-07, mid
credential-fabric-wiring-verify session) recognized that four
separately-tracked threads are actually one structural primitive:

1. **UI overlay compositing** — async auth-prompt overlays on a
   zenka's own ascii-frame/vterm console output, proposed as a cleaner
   replacement for credential_fabric's unconfirmed `protocol-7-menu`
   gtk-dialog cross-zenka routing (`CREDENTIAL-FABRIC-WIRING-FINDINGS.
   md` open issue #7)
2. **v7 hot self-restart** — the "restarting state" snapshot
   `V7-HOT-SELF-RESTART.md` needs is exactly a captured layer-matrix
   state; importing it = `apply`, fallback-to-cold-restart = `reverse`
3. **zenka migration** (same doc's "related/adjacent" section) — same
   transfer mechanism, just targeting a *different* manager
4. **differential, checksum-addressable network state** (same doc's
   "broader vision" section) — "entity references implicitly resolve
   from the diff space" = `apply`/`reverse` composed across many nodes

now captured as its own doc: `data/md/design/LAYER-MATRIX-STATE-
TRANSFER.md` — defines the algebra as `apply(base,layer)→composite` /
`reverse(composite,layer)→base`, which must be TRUE INVERSES (not a
LIFO stack) for non-LIFO restoration and non-linear inter-node sync to
work at all.

**the open crux**: does `apply` commute under composition? if node A
applies diffs `[x,y]` and node B applies `[y,x]`, do they converge
without canonical-order arbitration? CRDT-territory in spirit — P7's
native checksum-addressed diff-space framing looks like a cleaner fit
than importing CRDT vocabulary wholesale.

**Why this matters**: future work on v7-self-restart, zenka migration,
branching, ascii-frame/vterm overlay UI, or differential-addressing
should check BOTH docs — they're now understood to be facets of the
same unsolved algebra, not separate problems. solving the
commutativity question once, at the small UI-overlay scale, pays off
across all four.

**How to apply**: read `V7-HOT-SELF-RESTART.md` and `LAYER-MATRIX-
STATE-TRANSFER.md` together when picking up any of these threads —
they cross-reference but deliberately don't duplicate each other.

#,,.,,...,..,,,,.,,.,,..,,...,,.,,,.,,..,,,.,,..,,...,...,.,.,,,,,,,.,...,,,.,
#PWYDPPZ25EUBWD4OJGPWFWW63NLWQ3Q4HM3FUZ7MNUBQWOMCARVTNJ3HX47DHBFDJXBSXFVSQN4RU
#\\\|UEJNUFYP67I2LVPHVI66ZCWM6R4U44EG4H4LRES2EM5IL5RIWC7 \ / AMOS7 \ YOURUM ::
#\[7]JLMYMVIJ7XQCB4G4CKLEI5KO6CO2TAETQHFAE6QTCDZXYWBOFODY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
