---
name: feedback-vax-int-digit-only-encoded-ids
description: base32 job ids can be all digits [ 2-7 only ] -- vax-int's ^\d+$ guess re-encodes them [ 65454 -> V37Q ] ; fix = no guessing downstream, never a length rule in the generic tools
metadata:
  type: feedback
---

found 2026-10-23 on pri : listing 14580215 encodes to '65454', 13484023 to '66742'.
base.vax-int.encode \ .decode [ and bin/vax-int without -d ] treat `^\d+$` as numeric,
so these ids got encoded a second time [ V37Q, WYCAC ] : a shadow web card, an empty
apply/V37Q.yaml, a reassess on an empty description -> a hallucinated score 9, and the
mainframe posting recurring with errors.

**Why:** all PERSISTED ids are encoded [ pri : 2314 index + 81 web, 4-5 chars ] but jobsite
works NUMERIC in memory [ site-yaml sends the listing number, load_all decodes file names ] -- each round trip guesses.

**How to apply:** encode once where the listing number comes from the site, pass ids
through everywhere else [ jobsite \ site-yaml \ plugin.web.jobs.* ]. the owner rejected
a length rule in base.vax-int \ bin/vax-int : generic tools [ `vax-int 42` = FI ].
check a digit-only id by hand with `bin/vax-int -dq <id>`. moves jobsite toward generic.

#,,,,,,,,,..,,,,,,.,.,,.,,..,,,,.,,,,,...,,,,,..,,...,...,,,,,,,.,...,,.,,,,.,
#YWTPL776ELKZMOEYZXZ4MV47QVO2YNQ4SVLIGKFKEOGPDKPR67DQCNU4N3JZZHNLWI7NTSQPENB64
#\\\|NQW3P5UAZ2KFBKDAZGJIRQUMNG77PROMAXXRI3LKRYI5XO4SLRJ \ / AMOS7 \ YOURUM ::
#\[7]KENNFV7NIVMUGCKHQKDSU4TNN7M24K4DEUVDUFBSOC6UZ4TH2ECA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
