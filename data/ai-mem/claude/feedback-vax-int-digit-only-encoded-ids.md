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

**Why:** all stored ids are encoded since the switch [ pri : 2314 index + 81 web, 4-5
chars ] ; the downstream encode \ decode calls are transition leftovers that guess.

**How to apply:** encode once where the listing number comes from the site, pass ids
through everywhere else [ jobsite \ site-yaml \ plugin.web.jobs.* ]. the owner rejected
a length rule in base.vax-int \ bin/vax-int : generic tools [ `vax-int 42` = FI ].
check a digit-only id by hand with `bin/vax-int -dq <id>`. moves jobsite toward generic.

#,,,,,,,.,,..,.,,,,,.,.,,,,,.,,,.,,,.,,..,..,,..,,...,...,,,.,,.,,.,.,..,,...,
#WUUDIVZYONFCWCOZFFIFDBV4UG3745AWHCRPEXBYXIIO3BQPBKMZU6RW75RJR3SKAMNGI75WQQKTA
#\\\|EN2WY7J3LHSGYEXMTANN4FBFAXTVLAUEMS3B3EYFISJKPT7H3A4 \ / AMOS7 \ YOURUM ::
#\[7]5T67OMYILMRVRJETFCCDG54NJWQBKFNQKHKJY2JIYFMAG4JDR2DY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
