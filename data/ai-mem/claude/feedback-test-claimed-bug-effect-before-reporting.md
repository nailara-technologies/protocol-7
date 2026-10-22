---
name: feedback-test-claimed-bug-effect-before-reporting
description: before naming a bug's user-visible symptoms [ in a report or a commit message ], reproduce them -- 2026-10-15 load_single stored a reference : I reported 'enc-key-chksum sums SCALAR(0x..)' and 'a wrong password stays loaded as FALSE', both false [ a consumer dereferences, FALSE was unreachable ] and pushed in 1e6fe8766's message
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

#,,..,..,,.,.,,,,,.,.,,.,,.,,,,.,,.,,,..,,,..,..,,...,...,..,,.,.,...,,.,,.,.,
#BHLXVGXXEAQJDNZF2XLLL3L2MBH4KAVB2XDWTWDWZ5GH7UBJ7YLGKIJRF4M3RPUS42AH3TNY7SW3W
#\\\|5KIZ4RNTNIYRY3PSZLESAPALCSRQUABNS4NGOGVWINHCYXTQQHY \ / AMOS7 \ YOURUM ::
#\[7]ZFMXM2V6VSGBOYZ7CF4WHCSYC2F7HCWEETWSPL4JXAPP6GCGPCCI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
