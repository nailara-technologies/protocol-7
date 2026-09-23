# Early Exclusion via Reference-Density

## Core Insight

`space.search` already tracks reference density per node and already sorts
results by it (`space.route.resonance`). What it doesn't do yet is use that
density to *skip* work — every node in the grid pays for every filter stage
regardless of how sparse it is, and density only decides ordering at the very
end. Early exclusion means treating low density as a reason to stop looking
at a node early, not just a reason to rank it last.

## What Already Exists

This isn't a proposal for new infrastructure. The pieces are built:

- `branch.space.util.ref_count` / `space.grid.nodes` — reference counts are
  already tracked per node.
- `space.route.resonance` — already combines ref_count, harmonic truth (via
  `AMOS7::Assert::Truth`), and shell distance into a single resonance score.
- `graphics-matrix.glow.compute` — already renders glow intensity per
  distance shell from reference counts. This is the "visual density" half of
  the idea, and it's done.
- `base.indexcube.*` — the cube addressing this would prune against is real.

## The Gap

`space.search` (`src/space.search`) already filters "cheapest first" by its
own comment: shell-range, then character, then type, then group membership,
then a harmonic truth check, then aura lookup, then an *opt-in* `refcount`
range filter — and only after all of that does it sort survivors by
resonance. Two things follow from that order:

1. **Resonance/ref_count is never a filter unless the caller explicitly asks
   for a `refcount` range.** A node with zero references pays for the full
   harmonic-assertion and aura-lookup cost like any other, then gets sorted
   to the bottom.
2. **The harmonic and aura filters are almost certainly the most expensive
   stages** — a checksum truth assertion and an aura table lookup per
   surviving node — and they run on every node regardless of density.

## The Proposal

Move a density check into the "cheapest first" chain, right after the
shell-range filter and before the harmonic/aura filters: drop nodes below a
reference-count threshold before they ever reach the expensive stages, the
same way the shell-range filter already prunes by coordinate before anything
else runs. This doesn't need new data — `ref_count` is already there — it
needs the existing `refcount` filter's logic applied early and by default
for the cheap case, rather than only on explicit request after everything
else already ran.

Concretely: a query against a sparse region currently costs one harmonic
assertion and one aura lookup per empty node before resonance sorts it out
of view. With early exclusion, a node under the threshold never reaches
those two stages at all.

## Visualization

`graphics-matrix.glow.compute` already renders this density as glow
intensity per shell — the same signal the search-side pruning above would
use to exclude, a viewer would use to see "this region is dark, nothing is
there" before ever issuing a query into it. The rendering and the pruning
are two consumers of the same `ref_count` data, not two things to build
separately.

## References

- `data/md/design/THREE-CORE-SELF-CLEANSING-IMPLOSION.md` — the umbrella
  design this sits under
- `data/md/design/VISUAL-ELEMENT-DEDUP-HOLOGRAPHIC-CORE.md` — the
  holographic/dedup framing for reference counts; not repeated here
- `src/space.search`, `src/space.route.resonance`,
  `src/branch.space.util.ref_count`, `src/graphics-matrix.glow.compute` —
  the actual implementation this proposal extends

#,,.,,..,,.,,,,.,,,,,,..,,,.,,,..,,,.,.,.,.,.,..,,...,..,,,,,,..,,..,,..,,..,,
#EDC5ZPE4MSQCBL2DXX6RX3S3S7BXOQSYGP4JJWXIBI5UCRYEZZ57G3U6MLNNXYHHLCSS74BCN5MIC
#\\\|NIZKO7ECHIXUJHL475DEF2LKKKLYIMKVUY5JCCGWV5S5FYUHJFK \ / AMOS7 \ YOURUM ::
#\[7]ULOAOVHZP3KAYROHVFCVLPF57ZDT6YX5GVLXKGBXZF4KTYS7JACQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
