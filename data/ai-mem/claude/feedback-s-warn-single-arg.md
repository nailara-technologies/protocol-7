---
name: s-warn-single-arg
description: "fixing base.s_warn 'sprintf parameter expected' errors - use plain warn for non-sprintf messages, not <{C1}>, '' padding"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 1fae67f1-7fe7-41e7-9119-372afacccc2b
---

`<[base.s_warn]>->(...)` requires >=2 args (sprintf template + at least one
param), else it warns "sprintf parameter expected". When fixing a single-arg
`<[base.s_warn]>->('fixed message <{C1}>')` call that has no real sprintf
params, do NOT pad it to `<[base.s_warn]>->('msg <{C1}>', '')`.

Instead replace it with plain `warn 'msg <{C1}>';` — `warn` is overloaded
with a SIGWARN handler that already expands `<{C1}>`/`<{NC}>` caller-info
placeholders, same as `base.s_warn` does for sprintf-style messages.

**Why:** user explicitly corrected the `<{C1}>, ''` workaround
(2026-06-15, cred-mesh.key_holder.parent fixes) — said `<{C1}>, ''` is "a
workaround" and plain `warn '... <{C1}>'` is the correct/regular form.

**How to apply:** for messages WITH real sprintf params, keep/add them as
extra args to `base.s_warn`. For fixed messages with no params, use plain
`warn`.

#,,,.,,,,,.,.,,,,,,,.,...,,,.,,,,,...,,,,,...,..,,...,...,,,,,,.,,...,...,..,,
#KQHCQ5XH4W3BIBMS26SU3KS7LFU4FJSHNDP27ZTNUYKNLFSA3KH6OFKB4LHS2CUUCZBW47ANARSIG
#\\\|7IGFQHOND4G4YENIXK5RVBLZJF2XJ4ZMYD2FKAF4UV35SUKS2HJ \ / AMOS7 \ YOURUM ::
#\[7]I5FT2Y5KQUVRDKGZY32ZLH2NMTMDN4WGYSO2UEZPFT6HSVZDVWDQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
