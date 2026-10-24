---
name: zenka-open-default-utf8-layer
description: every plain open() in a zenka module gets :encoding(UTF-8) [ bin/Protocol-7 `use open`, deliberate ] -- a file holding OCTETS [ encode_json output, raw bodies, binary ] needs '>:raw' \ '<:raw', else it is double-encoded
metadata:
  type: feedback
---

`bin/Protocol-7` lines 35-38 set `use open qw| :encoding(UTF-8) |` and
binmode STDIN \ STDOUT \ STDERR to UTF-8. deliberate project default [ the
owner confirmed 2026-10-24 ] -- modules are compiled inside its lexical
scope, so EVERY plain `open $fh, '>'` \ `'<'` in src/* carries the layer.

**Why:** 2026-10-24 : `site-yaml.outbox.write` printed `JSON::encode_json`
output [ UTF-8 octets ] through the layer -> double-encoded on disk ; the
backlog read in `site-yaml.cmd.subscribe-fetched` decoded it back into a
CHARACTER string and `base.stream.push` sent that in its internal utf-8 form
-> every umlaut arrived as `DÃ¼sseldorf` [ 58 jobs repaired, fixed in
8b2384420 ]. live frames [ octets, never through a file ] stayed clean, so
the bug only showed via the backlog path. the 2026-10-23 fix [ d34eb7d82,
site-yaml.stepstone.job_from_html ] was a different site of the same class.
see [[project-2026-10-24-delta-link-managed]].

**How to apply:**
- decide per file : text [ perl character strings ] -> plain open is right ;
  octets [ encode_json \ encode('UTF-8') output, http bodies, compressed or
  binary data ] -> `'>:raw'` and `'<:raw'` on BOTH the write and the read
- a write \ read pair that both use the layer can round-trip correctly
  and still leave a double-encoded file on disk -- the damage shows only
  where the data leaves as bytes [ a stream, a socket, another reader ].
  check the bytes on disk [ `od -c`, `ü` must be `303 274` ] not just the
  round trip
- a reduced test of such a bug must include the layer [ `use open` in the
  test ] AND the real send step -- a test that downgrades or encodes by
  hand hides the defect [ the first 2026-10-24 test passed falsely ]
- direction [ owner, 2026-10-24 ] : keep the default for now [ ~217
  plain opens in src/ rely on it -- flipping it = silent reverse mojibake ],
  move file io behind `base.file.*` with an explicit text \ octets mode,
  later swappable for local \ network filesystem or transport layers. done
  when toggling the `use open` default changes NO write anywhere -- every
  site defines its own layer. new code : say the layer, never inherit it
- the transformation runs in prioritized groups [ owner ]. inventory
  2026-10-24 : 267 plain opens in src/ [ keyword heuristic, a perl scan
  over +-40 lines of context -- regenerate before each group, do not
  trust the counts ] :
  1. json \ yaml octets [ 16 : models, letsencr, vision-batch, work,
     jobsite.store.prune, base.pattern-registry, ncode.regex, coding.
     learning, set-up ] -- the ACTIVE double-encode class, check each
     write + read PAIR together ; ascii-only content is why it held so far
  2. binary \ crypto \ compressed [ 143, over-matched ] -- a text layer
     corrupts every byte > 0x7f [ keys ! ] ; base32 \ ascii payloads are
     safe, split those off first
  3. network bodies [ 12 : rss, nameserv, httpd, coding ]
  4. text \ config \ logs [ 79 : workspace-transfer, v7-zenki, base ] --
     already right, only make it explicit [ mechanical, base.file text ]
  5. unclassified [ 17 ] -- classify by hand
  outside src/ [ bin/*, AMOS7::* ] `use open` does NOT apply : own group
- mojibake in jobs : `jobsite.repair-encoding` [ dry run default, owner
  runs `apply` ] ; files : [[reference-unicode-encoding-repair]] ; format
  literals : [[utf8-module-literals]]

#,,.,,.,.,.,.,.,.,,.,,..,,,.,,...,,,,,,..,,,.,..,,...,...,,.,,,,,,..,,.,.,.,.,
#M7XRXVMJ4M5GGVDVVVYJ2SGWY5IVXURVDRDGZ5QWKRCWXK4BCXM3E3TAJAXNQTRR7PMRIUTZVKLXY
#\\\|GTGEDVTPBHWH26RVXSDWEPQU2AWTLN3ZVM7CO7WAAYUZMGQ6OE7 \ / AMOS7 \ YOURUM ::
#\[7]VAVWK7TBPITGCHAVQ2GHNDZZH4ZIIMNBFMQDCVLTE6FBXP76YCBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
