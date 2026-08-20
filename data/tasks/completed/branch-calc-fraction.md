# task: branch.calc.fraction.* — harmonic fraction arithmetic

## context

fractions X/Y where Y is a generator (7, 11, 13 or products) encode
parent group structure in their repeating decimal period. short periods
are coupling points. terminating decimals expose the scale factor by
reversal. this task implements the arithmetic utilities as clean,
composable subroutines for use across the branch, space, and cluster
namespaces.

design reference: `data/md/design/BRANCH-OPEN-CAPACITY-SESSION-DAG.md`
design reference: `data/md/design/HARMONIC-ENTROPY-OBSERVER-GUIDE.md`

## signatures note

do not modify or regenerate AMOS7 signature lines. leave them untouched.

## known parent group mappings

```
period "63"       →  cube nodes  (4³−1, parent of 7 eleven-structures)
period "45"       →  orbital clock feature combinations
period "384615"   →  rotation of 153846 (second generator family)
period "571428"   →  4th rotation of 142857 (1/7 family)
period "076923"   →  first generator family (1/13)
period "142857"   →  complementary generator family (1/7)
terminates        →  scale factor readable by reversal; no harmonic group
```

## reversal operation

for terminating X/Y = a.b:

```
reverse: b.a
decimal part 0.b → denominator of original fraction
integer b × (1/0.b) → parent scale factor

13/5 = 2.6  →  6.2  →  0.2 = 1/5  →  6 × 5 = 30
11/5 = 2.2  →  2.2  →  symmetric → self-referential (scale = 2 × 5 = 10)
```

symmetric terminating decimals (a.b where a = b) are self-referential
boundaries — the scale factor equals the base.

## modules to create

- `src/branch.calc.fraction.period` — compute repeating period string
  for X/Y via long division loop (track remainders, detect repeat).
  return empty string if terminates. args: numerator, denominator.

- `src/branch.calc.fraction.period_length` — return length of minimal
  period. 0 if terminates.

- `src/branch.calc.fraction.terminates` — true if Y has only factors
  2 and 5 (i.e. Y | 10^k for some k). pure arithmetic, no division needed.

- `src/branch.calc.fraction.remainder_seq` — return full list of
  remainders from long division of X/Y. sequence length = period length.
  the sequence is the orbit of X in the group mod Y.

- `src/branch.calc.fraction.parent_lookup` — given period string,
  return known P7 group name from the mapping table above.
  return undef if period not in known set.
  mapping stored in `data/yaml/harmonic/fraction-period-groups.yaml`.

- `src/branch.calc.fraction.reverse_scale` — for terminating X/Y,
  compute reversal and return scale factor as integer.
  return undef if X/Y does not terminate.

- `src/branch.calc.fraction.coupling_find` — given a list of (X,Y)
  pairs and a max_period_length threshold, return all pairs whose period
  length <= threshold. these are coupling points.

- `src/branch.calc.fraction.symmetry` — return symmetry type of period:
    'palindrome'  — period reads same forwards and backwards
    'self-ref'    — terminating with a == b (e.g. 2.2)
    'rotation'    — period is a rotation of a known generator family
    'none'        — no detected symmetry

- `src/branch.calc.fraction.ring_position` — map period string to
  1001-ring harmonic index (0..12). derived from which generator family
  the period belongs to.

- `src/branch.calc.fraction.prefix_entropy` — for X/Y with a
  non-repeating prefix before the period, return the length and
  bit-entropy of the prefix digits. prefix length = v_2(Y) + v_5(Y)
  where v_p is the p-adic valuation.

## configuration

`data/yaml/harmonic/fraction-period-groups.yaml` — period string → group name:

```yaml
"63":      cube-nodes
"45":      orbital-clock
"384615":  generator-153846-r2
"076923":  generator-076923
"142857":  generator-142857
"571428":  generator-142857-r4
"285714":  generator-142857-r2
"428571":  generator-142857-r3
"714285":  generator-142857-r5
```

## style

- pure arithmetic — no external dependencies beyond core Perl math
- `$ARG` not `$_`; `@ARG` not `@_`
- all functions return undef on invalid input, not die
- lowercase comments, `[ word ]` bracket annotations

## acceptance

- period("7","11") returns "63"
- period("5","11") returns "45"
- period("5","13") returns "384615"
- terminates("13","5") returns true; terminates("1","13") returns false
- reverse_scale("13","5") returns 30
- symmetry("11","5") returns 'self-ref'
- parent_lookup("63") returns 'cube-nodes'
- ring_position("076923") returns the 1001-ring index for the 1/13 family

#,,.,,...,.,.,.,.,,,.,..,,,..,.,,,.,,,,,,,..,,..,,...,...,,,,,,,,,,,.,,..,,,,,
#6PLLN6QCRKR4SPM34L5NZRCF6PGTRARZXWHNHE3SMAOEJAWL276JCOC3IVDT52557R7N7E7QSFDJG
#\\\|VL4KLTR55M2AMF64XH7MO4Y23CQNO2NPBACBWXQFI7RZXS7I2ZK \ / AMOS7 \ YOURUM ::
#\[7]Y4GSU2NADYA2SVMTGEH3IXMQMJ2T4XDOEIZ5D342JJABDMFOFUCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
