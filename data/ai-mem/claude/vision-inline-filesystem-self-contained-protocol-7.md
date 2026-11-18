---
name: vision-inline-filesystem-self-contained-protocol-7
description: "long-term: extend bin/Protocol-7's existing inline-subroutine __DATA__ block technique to config and data files too, working toward a fully self-contained Protocol-7 process with nothing external to load -- relevant to the minimal-startup auto-install case where Event.pm/zenka machinery isn't available yet"
metadata:
  node_type: memory
  type: project
  originSessionId: fee6b203-065d-46ee-9e22-bac7aa31efd1
---

2026-08-31, arose while discussing the "minimal startup" auto-install
wiring case (see [[topic-next-steps]]'s 2026-08-31 entry) — a zenka this
early in boot has no Event.pm, no jobqueue, nothing today's async
apt-install pipeline needs. User's framing: this is one motivating case
for a much larger, already-planned direction.

## the existing precedent (already real, not speculative)

`bin/Protocol-7` already inlines subroutines directly into its own file,
past `__DATA__` (line ~5798 per [[topic-amos7-p7-loader]]) — each entry a
named, base32-ish encoded + checksum-signed blob
(`.:[ module.name ]:.` ... `<...:sig:...>` ... `:.`), loaded via
`p7_import_main_subroutines()`. This is how `bin/Protocol-7` can be a
single file with no external `src/*` module loading needed for its own
core operation.

## the vision

Extend the *same* inlining technique beyond subroutines to **config
files, and eventually data files too** — "a sort of inline filesystem,"
per the user, not fundamentally different from what already exists for
inline subs. End state: a Protocol-7 process that is entirely
self-contained — no external `cfg/`, `src/`, or `data/` files needed at
all for it to boot and operate, everything baked into one file the same
way inline subroutines already are.

**Why this matters for the minimal-startup auto-install case**
specifically: if config/data can be inlined the same way subroutines
already are, a zenka at the very earliest point of boot — before
Event.pm, before any external file access assumptions — could still have
everything it needs (including whatever `AMOS7::deps::*` needs to check
and resolve a missing dependency) without depending on the filesystem or
an event loop being ready yet.

## status

Confirmed as genuinely planned by the user ("that is planned"), not a
speculative idea I'm inferring. No design work done yet on how config/data
inlining would actually work (the existing subroutine mechanism is a
useful blueprint, not a spec — data files in particular raise questions
subroutines don't: size, mutability, how a "file" identity survives being
inlined). Don't start designing or building this unprompted; it's framed
as a longer-horizon direction the AMOS7-level dependency-bootstrap idea
would eventually connect to, not a near-term task.


## 2026-11-18 : first concrete hook

owner confirmed : the inline subroutines in the __DATA__ block were built with exactly this end in mind.
data/tasks/amos7-config-reader.md reads config through a source interface [ exists, lines, trust ] :
disk tree first, the inline filesystem later as a stacked source [ inline defaults < disk < host layers ],
names category-relative [ cfg/ src/ data/ ]. appliance recipes [ cfg/appliances/ ] ride on it -- an
appliance image could become one self-contained file plus an os.
naming [ owner 2026-11-18 ] : a bare name stays a subroutine [ src/, dot namespace -- src/ subdirectories
would map to the dots ] ; any other category is a prefix parallel to src/ : `cfg/<path>`, `data/<path>`, ..
so the only format change needed is the category expansion of the entry name.
nesting [ owner ] : `.: parent.namespace :.` sections, child entries drop the prefix -- works for
category paths too [ `.: cfg/appliances :.` ].
status : nesting not implemented yet ; owner sees the inline format as a native general format [ unambiguous enough ], not only bin/Protocol-7's data block.
third source [ 2026-11-18 ] : bin/Protocol-7 ~2164 has an http src loading path [ .v7/file-list/base, http_src_base_urls ], deactivated in p7_httpc__remote_file ~4199. same source interface : inline < disk < remote ; signed entries make remote safe, over a p7 link [ e.g. the pi serving appliances ] rather than plain http.
fourth source : stdin [ p7_stdin_configuration ] -- today zenka.v7 only [ `cat cfg/zenki/cube/zenka.v7 | Protocol-7` = `Protocol-7 cube` = p7-cube ] ; in the inline frame format stdin could carry a whole bundle [ cfg \ src \ data entries ], e.g. `cat bundle | ssh host Protocol-7` boots a zenka with nothing on disk ; signatures still checked.
stdin multiplex [ owner plan, recalled 2026-11-18, NOT written down before ] : send a zenka to a host to assimilate or investigate it -- one stdin stream multiplexes the zenka's code + cfg [ inline file routing : entries routed to their category ] AND its credentials. wire layer = data/md/design/STDIO-MULTIPLEX-PROTOCOL.md [ 3-bit type tags : META frames scope, SIN 001 = silent input fits the credentials ] ; that doc has no file routing yet -- an inline-entry tag \ META scope for `.:[ name ]:.` entries is the missing piece. credentials never touch disk on the target.
line grammar [ owner plan ] : '  ' prefixed lines = inlined payload [ stdio passthrough ] ; lines without it = protocol ; ':' or a group of ':' = special meaning [ inline file access ]. converges with data/md/design/DATA-PROTOCOL-SYNC.md [ DATA open \ 76-char base32 chunk lines \ DATA END + AMOS checksum, DELTA from a base checksum, branch.file.* access ] -- same 76 width and checksum close as the __DATA__ entries : inline entry = DATA at rest, DATA frame = inline entry in motion. sync side : data/md/research/GENERIC-DATA-SYNCHRONIZATION-FABRIC.md. not connected yet.
frame [ checked 2026-11-18 ] : `.:[ name ]:.` opens an entry, every content line starts with `:`, `:.` closes ; meta = a `:` line told apart by its form [ `: <chksum:..>` today ]. `.: name :.` [ no brackets ] stays free for section \ nesting syntax. header regex bin/Protocol-7 ~5347 `[\w\d\-\_\.]+` : needs `/` for category paths.

## src routines for external scripts [ owner 2026-11-18 ]

an AMOS7 module [ AMOS7::Config context first ] can import regular src/ routines the way the loader
imports inline subroutines -- as a TIGHT profile : only the routines a script needs plus their
dependency closure [ data/md/documentation/module-dependency-graph.asc, gen-sub-whitelist logic ],
none unused. a script loading it then has nearly a zenka's capabilities without being one.
AMOS7 is essential already, so no new dependency.

#,,,,,,,,,..,,..,,,.,,,.,,.,,,...,.,,,,.,,,..,..,,...,...,,.,,.,,,...,,..,,,.,
#U7NDZ6RJ6BVYGY7SQEYM4PSE5RP2DL4WRE2H2E7IP5Q4MUTAWSMBY6U32IG6XFLFDQLBIBRN5JWM4
#\\\|HTBL223PS3XQET6R3GSL2QR2D4SZLDBVLEQD365DZPULRE22E6A \ / AMOS7 \ YOURUM ::
#\[7]IF65EJIWY355V3BMV5DI2BMDJMU33LCB6CX52I5VLVJ6NDTJWKBA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
