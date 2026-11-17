---
name: session-handover-resource-ledger
description: NEWEST 2026-11-17 handover : resource ledger + n7fs format 4 + canon parser built, reviewed, fixed, on all hosts ; next steps and budgets
metadata:
  type: project
---

session 2026-11-16 \ 17 [ last Fable window ] -- all committed, pushed, bundle on external storage,
pulled [ no restart ] on srv-U srv-F srv-V srv-A azurum, all at b9e3d3b6d.

**commits** : a51999e20 Nested.pm root + parent check ; 2b87fcc73 AMOS7::cell::time exact y-grid ;
252ce0229 design docs [ RESOURCE-ACCOUNTING-UNIFIED, SUBSTRATE-SYNTHESIS, N7FS-FORMAT-4 ] ;
282ee71fe AMOS7::cell::canon [ format 4 stage 1 ] + DECISION-GUIDE-2026-11-16 ; b41ef81db ledger
stage 1a [ AMOS7::NRT, bin/nrt ] ; c4630a1a8 owner idea set into the ledger [ sections 15-22, q35-47 ] ;
189eb2b3d format 4 stage 2 [ N7FS::Canon + Prior ] ; 47a902d23 10 k3.1 security fixes ; b9e3d3b6d
-B argv fix [ [[unanchored-cli-flag-backgrounds-commands]] ] + TRANSPORT-MARK-BITS.md.

**owner positions** : ~/.n/private-notes/owner-pool-authorization-2026-11-16.md [ authoritative ;
read before any ledger \ transport pass ]. briefs + reviews beside it in ~/.n/private-notes/.

**decided** : format 4 canon = ledger journal form ; n7fs CLEAN CUT [ one use only : re-issue all in
format 4, Prior a one-time converter, json3 transient at most ] ; conversion chain lives in version
history ; spare AMOS bits are transient [ 0 rest, 1-6 axes, 7 parent ] ; stored checksums end A I Q Y.

**next** [ fresh budgets ] : format 4 stage 3 [ wire + home state ] ; ledger stage 1b [ shares, slots,
settle, remainders to parent, design-test simulation ] ; later a transport design pass
[ TRANSPORT-MARK-BITS.md open list, read bin/dev/division-13-table ]. live n7fs untouched until
format 4 stage 6 rehearsal passes.

**lessons** : resume of a big Fable agent after > 1 h reloads its whole context at full price --
check its saved files instead ; fresh narrow briefs + medium effort cost ~3 % per Fable pass ;
review new code with k3.1 right after building [ found a critical fail-open ] ; check the 7d window
end against a fixed clock reading before planning resets.

**Fable** : plan access ended 2026-11-17 08:59 CET [ [[fable-access-window]] ].

**route symbol fix [ TRANSPORT-DESIGN q1 + q11, owner agreed 2026-11-17 ]** : the 7 bit route form
`00 0 0 hhh` forward \ `00 1 dd hh` turn \ `00 0 1 ooo` lane follows the original COMMENT ; the code
everywhere lacks forward [ 2 bit turn + 3 bit hops ]. five code copies to fix together, best as
callers of AMOS7::cell::route [ transport stage 1 ] : bin/dev/division-13-table, display-D13-collection,
bit-desc, tests/compression/comp-test, and src/decoder.base.decode_d13_bits [ live decoder zenka,
output 'RT[..]' -- check its consumers first ]. ~15 design docs mention the form [ grep
'hop count|decoded_bits_route' data/md ].

**TRANSPORT-DESIGN q8 lattice -> @INDEXCUBE [ owner pointer 2026-11-17 ]** : data/md/coding-tasks/
indexcube-routing-stack.md already defines it : P7REF `TYPE:CHKSUM7:ADDR_B32`, ADDR_B32 = X Y Z bytes
[ 0..255 ] -> six face neighbours = +-1 on one axis ; @INDEXCUBE push \ pop = descend \ parent
[ mark 7 = pop ] ; stack = signed hop chain [ the hold chain ] ; sub-cube = recursion = scale.
open : what happens at an axis edge [ 0 \ 255 : wrap, or step up a scale ]. Fable never read it
[ narrow brief ] -- fold into TRANSPORT-DESIGN section on neighbour().
**per-axis AMOS [ owner pointer ]** : project-epoch-orbital-harmonic-math-2026-08-03 ->
AMOS-SIGNATURE-FOOTER-BIT-FRAME-HIERARCHY.md ~292 : amos-chksum offset \ `-L<len> <pos>` as axis
selector "0=X 1=Y 2=Z" [ entropy-at-deduplication-root.md:82 ]. an EXISTING per-axis checksum
mechanism -- the transport pass should prefer it over new "x"/"y"/"z" label hashing
[ TRANSPORT-MARK-BITS 3.5 ] or show why labels are needed ; orbital canvas : 3 plane rotations +
1 body-diagonal hyperspace channel [ f4 = the trunk, ORBITAL-CYCLE-CLOCK-AND-MAPPING-CANVAS.md ~744 ].

**transport pass 2 [ done ]** : TRANSPORT-DESIGN.md now uses @INDEXCUBE as the lattice [ section 3.5,
neighbour() complete, axis edge = carry one scale up, never wrap ], link keys = BMW384( mark word .
link secret ), decisions table [ q1-12 accepted, q4 q5 numbers = starting values ], new q13-18.
**FOUND, verified** : src/base.indexcube.push "signs" with an unkeyed chk-sum.amos( p7ref:ts:depth ),
no link to the entry below -- anyone can compute it, entries can be inserted ; the design doc's
"signed at push time" claim is not true in code [ q14 : C25519 over BMW384( entry . sig below ) ].
RT[..] output : keep the `RT` tag [ decoder.zenka.receive_entropy keys on it ].

#,,..,,.,,,,.,...,..,,...,..,,,,.,.,,,,.,,,,.,..,,...,...,.,,,,.,,..,,.,,,,,.,
#GCSVZB5ERSBUPFI2TZ3FMU7PBJFG4RF474DGBG3PIVVYJPAXUWCOQ7PAYAEX4YQC6OU3ECQVA2UKQ
#\\\|75OAID7VXOKN4APNLD67FFF3PCD4BXYOTLNVQF5YEDBSJY3WYJG \ / AMOS7 \ YOURUM ::
#\[7]377BN2MK7R3O3QLJW4K7U2NTBGV6LLVEDQFWYAP4DAVI3PA3A6AI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
