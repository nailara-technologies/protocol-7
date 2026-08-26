All verification complete. Here is the full report.

## 1. Empirical claims verified against the real code

**Tier-1 offset-3 failure — confirmed.** Payloads 1,2,0,7 encode to `0010 0100 0001 1110`. Column extraction over the 16-bit stream shows **no** offset is strictly uniform — offset 3 (the true separator column) reads `0010` because the collapse frame (`0001`) inverts its separator. `detect_tier1` (exact replica of `/data/projects/protocol-7/src/base.stream.frame.detect`) returns `undef`. Matches the task file's status note exactly: tier-1 fails safe (no false lock), but cannot lock.

**`true_int()` non-selectivity — confirmed against the real `AMOS7::CHKSUM::ELF` + `AMOS7::Assert::Truth` (Inline-C `true_int`), not a reimplementation.** Replicating `base.stream.frame.detect.harmonic` exactly (`elf_chksum(column, 0, 7, 13)` then `true_int`): offsets **1, 2, 3 all assert true**; only offset 0 happens to fall in the `230769` false-family (`elf=000796721`). 3-of-4 asserting true matches the module's own header note verbatim. The module as written would return offset 1 — a payload column — a **false lock**, worse than tier-1's honest `undef`.

## 2. Derivation — why no per-column test can work, and what does

**Impossibility argument (the key step).** Any discriminator that looks only at the *contents of one column* is unsound in principle, not just in the `true_int` case. The separator column's content is exactly the indicator sequence of collapse frames — which can be *any* binary sequence (the sender chooses payloads freely). Payload columns can also be any binary sequence. The content spaces overlap completely, so no function of a single column — harmonic checksum, entropy measure, anything — can distinguish separator from payload. I verified this constructively (test [3]): stream `0,5,0,5` has separator column `1010`; stream `5,1,4,3` has p2-payload column `1010` — identical content, different roles. This is why the harmonic-column approach failed and why any repair of it along the same axis must also fail. Truth "flipping under left-shift with period 12" doesn't rescue it: that is a property of *numbers under shift*, and there is no content-independent number attached to "the correct offset" to shift.

**What actually distinguishes the separator column** is not its own content but its **relation to the three bits before it**: the protocol's one rule, `sep = 1 iff payload = 000` (`sep = NOR(p2,p1,p0)`). The primary source says this itself — `topic-stream-framing-protocol.md`: "`000` inversion does not break detection — period is invariant, **inversion is post-lock detail**... one rule, zero ambiguity." Tier-1's strict-uniformity test is an *incomplete implementation of the spec's own grammar*: it tests "column constant" when the spec's actual invariant is "column consistent with the inversion rule." The correct tier-2 discriminator is therefore:

> An offset is valid iff **every complete 4-bit frame aligned to it decodes** under the already-shipped `base.stream.frame.decode` (which encodes precisely the NOR relation). Lock iff **exactly one** offset survives.

This is grammar-as-clock taken to completion — the frame *is* its own validity witness. No new crypto invented; the discriminator is literally the shipped decoder.

**Where the three leads land, honestly:**
- Lead 3 (truth-as-construction / iterate-until-true) is the *shape* this takes, but with bits instead of nonces: when multiple offsets survive, the answer is not "pick one by a secondary oracle" but "the window is genuinely underdetermined — consume more bits" (RECALC ≙ expand window). That is the same loop shape as `source.create_harmonic_footer` and `base.chk-sum.elf.get-true`, and it is the correct role for iteration here.
- Lead 1 (period-12 shift-flip, 4-step rotation): the 4-offset sweep is structurally the 4-step rotation cycle, but I found no way to make the shift-flip property *select* an offset, and the impossibility argument above says no column-content property can. I judge this lead poetic, not operative, for this problem.
- Lead 2 (5×7 AMOS matrix as parent grid): not needed at this layer. Possibly relevant one layer up (framing the framed stream), but claiming it here would be a guess.
- One genuine tie-in from `harmonic-cycle-correlations.md`: its octal-stream analysis already identified `1001` as "the sole ambiguous window, two possible separator positions" — the exact same phenomenon my detector reports as `undef`, generalized. Ambiguity is a real property of the stream content, and the honest output for it is no-lock, which that doc's 5-bit-window resolution also implies (sample more).

## 3. Test results (script: `/tmp/claude-1000/-data-projects-protocol-7/5d437747-f04b-4b79-bedc-b5ebe9e545a1/scratchpad/frame-derivation-test.pl`)

- **Failing case A** (1,2,0,7): tier-2 locks **offset 3, correct** — and all three phase-shifted variants (drop 1/2/3 leading bits) lock the correct shifted offset (2/1/0).
- **Multiple collapse frames** (0,3,0,5,0): tier-1 undef, tier-2 locks 3, correct.
- **2000 randomized trials** (3–8 frames, random payloads, random phase): 1522 locks, **1522 correct, 0 wrong**. 478 no-locks — and a separate diagnosis pass proved **every single no-lock has ≥2 fully-valid alignments** (the true offset was *never* eliminated): they are real ambiguities in the sampled content, not detector weakness. Ambiguity rate falls with window size: 62.6% at 3 frames → 2.5% at 8 frames.
- **Degenerate streams are inherently ambiguous and correctly refused**: all-collapse `0001 0001...` is 4-periodic (reads as valid payload-1 stream at another phase — *no* detector could resolve it); likewise any constant-payload stream (`0010...`, `1000...`). tier-2 returns undef for all.
- **Window-size finding, honest deviation from the spec**: the spec's "5 bits safe / 7 bits certainty" holds only for the idealized never-inverted separator. Under the inversion rule with a unique-lock requirement, case A needs **13 bits** before exactly one alignment survives. Certainty is content-dependent; ≥8 bits is the floor for all four offsets to even be testable (two separator samples each).

## 4. Proposed implementation (not written to repo, per instructions)

```perl
## [:< ##

# name  = base.stream.frame.detect.harmonic
# descr = tier-2 frame lock : inversion-rule consistency across candidate offsets
# param = <bits> [ arrayref of 0/1 bits ]
# return = offset [ 0-3 ] on unique lock, undef on insufficient or ambiguous data
#
# derivation note : the separator column is not uniform [ collapse frames
# invert it ] and is not identifiable from its own content [ any bit sequence
# can appear in both separator and payload columns ] -- the only invariant
# that holds for every valid stream is the grammar rule itself :
# sep = 1 exactly when payload = 000. an offset is valid when every complete
# frame aligned to it decodes under base.stream.frame.decode ; lock requires
# exactly one surviving offset. multiple survivors mean the sampled content
# is genuinely consistent with more than one alignment [ e.g. periodic
# streams ] -- the correct answer is undef : sample more bits, the same
# expand-until-resolved shape as source.create_harmonic_footer iteration.

my $bits = shift // [];

my $bit_count = scalar $bits->@*;

return undef if $bit_count < 5;

my @valid_offsets;
my $undecided = 0;

OFFSET:
for my $offset ( 0 .. 3 ) {
    my $sep_samples = 0;

    for ( my $i = $offset; $i < $bit_count; $i += 4 ) {
        $sep_samples++;

        if ( $i >= 3 ) {    ## complete frame ends at this separator ##
            my $frame
                = $bits->[ $i - 3 ] << 3 | $bits->[ $i - 2 ] << 2
                | $bits->[ $i - 1 ] << 1 | $bits->[$i];

            next OFFSET    ## frame grammar violated : not the separator ##
                if not defined <[base.stream.frame.decode]>->($frame);

        } elsif ( $bits->[$i] == 1 ) {
            ## partial leading frame with inverted separator :        ##
            ## inversion only ever pairs with 000, so every visible   ##
            ## payload bit before it must be 0                        ##
            for my $j ( 0 .. $i - 1 ) {
                next OFFSET if $bits->[$j] != 0;
            }
        }    ## partial frame with separator 0 carries no checkable rule ##
    }

    if ( $sep_samples < 2 ) { $undecided++ }    ## blind spot : no verdict ##
    else                    { push @valid_offsets, $offset }
}

## lock requires a unique surviving offset with no untestable candidates ##
return $valid_offsets[0]
    if scalar(@valid_offsets) == 1 and not $undecided;

return undef;
```

Style matches the existing `base.stream.frame*` family: no pragmas, `$ARG`-free here (no `$_` used), lowercase `[ word ]` comments, reuses the shipped decoder via `<[...]>`.

## 5. Confidence and open questions

**High confidence (verified):** the tier-1 failure mode; the shipped harmonic module's false-lock behavior; the impossibility of any single-column discriminator (constructive proof + argument); soundness of the proposed detector (0 false locks in 2000 randomized trials, true offset never eliminated); correctness on all constructed cases.

**Medium confidence (judgment calls):** (a) the strict "exactly one survivor, no undecided" lock rule — it is the safe choice, but it means minimum 8 bits and content-dependent lock latency; a caller wanting tier-1's greedier semantics could relax the `$undecided` guard, trading safety for earlier locks. (b) My conclusion that the harmonic primitives are *not operative* at this layer — I could not derive a sound use of period-12 shift-flip or the 5×7 matrix here, and the impossibility argument closes the column-content route, but I cannot rule out a cross-frame harmonic construction at a higher layer (packet-raising, lead 2/3 territory) that this task's status section itself defers.

**Open:** inherently ambiguous streams (constant-payload / all-collapse periodic content) are undecidable from the bits alone at any window size; a real receiver needs surrounding varied traffic or a higher-layer marker (the `769230` / `L\` boundary-attractor from `harmonic-cycle-correlations.md` is the codebase's existing candidate for that, but wiring it in is a separate derivation). Also note: this proposal makes tier-2 strictly stronger than tier-1 (tier-1's uniform-column lock is a special case of decode-validity), so tier-1 arguably becomes a fast path rather than a separate correctness tier.

No repo files were modified; the only artifact is the test script in the scratchpad.

#,,,,,...,...,.,,,...,.,.,,,.,,.,,..,,,..,,,,,..,,...,...,.,.,.,.,..,,,,.,,,,,
#2WBCZH3UQDOHOAD2ED7OTYBN7TY2W6ECFP2ZOJSEUOWECGTW2MVOEUBSASDFZU2JVIH2YJW4BCBFM
#\\\|WXJICTCBRWV7VEQXE5N4R6OZ4KP5VU5EFXIAIBOBUP2KCIPKDOP \ / AMOS7 \ YOURUM ::
#\[7]D7MIT2XBT6O7EMDU3OD6ENBOW7APRPODAPYGSPZTH666BVGFAQBA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
