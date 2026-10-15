---
name: feedback-test-claimed-bug-effect-before-reporting
description: before naming a bug's user-visible symptoms [ in a report or a commit message ], reproduce them -- 2026-10-15 load_single stored a reference : I reported 'enc-key-chksum sums SCALAR(0x..)' and 'a wrong password stays loaded as FALSE', both false [ a consumer dereferences, FALSE was unreachable ] and pushed in e13135150's message
metadata:
  type: feedback
---

the code defect was real [ `$keys{..}{'private'} = decrypt_priv_keystr(..)`
stores a SCALAR ref ], the fix right. the EFFECTS I wrote down came from
reading one function, not the call chain : `key_bin_checksums` goes through
`base.reverse-sort` -> `base.context.list`, which dereferences SCALAR refs,
and `decrypt_priv_keystr` returns FALSE only when given a public key, which
load_single never passes. a test against the old file [ test-keys-single-
file.pl ] passed on both versions -- that is how it surfaced, after the push.

**Why:** a commit message is permanent and others act on reported symptoms ;
an invented effect costs trust and sends readers after things that never
happened.

**How to apply:** for each symptom claimed, either reproduce it [ run the
old code ] or follow every consumer of the value ; otherwise say "the
defect" and "possible effect, not verified". a regression test is only one
if it FAILS on the old code -- run it there. related :
[[security-fix-verify-both-code-paths-not-just-symptom]].

#,,,,,,.,,,.,,.,,,,,.,,..,,..,,..,,.,,,.,,.,,,..,,...,...,,..,.,.,,,,,..,,.,,,
#6D2PDE4AB6RO57T4GVTOHWHIVPCK3PMVATEUCUPHT4HAGY7KA7XQ4LTA44LYBGOGNNRAP35AU2LWA
#\\\|345YGSSP5TB4JG22WLRVLDGCFAZASHDVEVFBBT3VBEOB7WLCMWP \ / AMOS7 \ YOURUM ::
#\[7]3WPFL2DN4LIBYSJD4UFTZDXFS5KL5UNIQFLLERXW2AQEYKDYZYBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
