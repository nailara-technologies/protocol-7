---
name: feedback-compare-against-old-behavior
description: a delegated change to shared code is verified against the OLD behavior too -- "both paths agree" does not prove "nothing changed"
metadata:
  type: feedback
---

2026-10-18 : kimi made the pure-perl truth fallback agree with the
compiled one [ 6 / 6 checks ]. the user asked whether key checksums
change -- only then a comparison with HEAD showed `calc_true` had changed
1377 of 3040 long-number results ON EVERY HOST : the 64-bit clamp of the
C emulation was applied to numbers the compiled path never sees. the
cross-path test could not see it, both of its sides ran the same new
code.

**Why:** a test comparing two paths of the new code only proves they
agree with each other ; shared code that both paths call can drift
without any check failing.

**How to apply:**
- for a change to shared code : run the OLD version [ `git show
  HEAD:<file>` into a temp lib dir, put FIRST on @INC -- a script's own
  `use lib` comes before -I, so print $INC{..} to prove which one
  loaded ] against the new on the same vectors
- check user-visible outputs before and after [ e.g. keys list ]
- add an INDEPENDENT rule to the test [ here : the residue of the
  digits ], not only path-against-path
- related : [[security-fix-verify-both-code-paths-not-just-symptom]]

#,,.,,.,.,,.,,...,..,,.,,,,,.,.,.,,..,,,,,,,,,..,,...,...,.,,,...,..,,,.,,,..,
#FG6QJYL3C4UEYHQZTAXGNJEMCPDHTLR63K42ORFU6LHYPLUFXCTDPRQW4FRRTA2WOPZ6O5JGXPB4W
#\\\|FVHTK2SBCH5P3SFJ5Y6JHQWVFIJSTVJBS55QWWMI2O2FXMZ2TX2 \ / AMOS7 \ YOURUM ::
#\[7]VZY4JHITI74CBLHTRDW6UEZQY5BLUMIKU23ZI63MNNKG4ZMXC6DQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
