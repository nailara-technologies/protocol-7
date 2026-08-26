---
name: feedback-data-shadow-and-client-server-config-drift
description: "lexical 'my $data' next to the global %data tree is a readability hazard even though Perl sigils keep it safe; client/server config defaults (e.g. a port) can silently drift apart across two files -- both caught live in the 9P write-support round, 2026-08-22"
metadata:
  type: feedback
---

## `my $data` next to the global `%data` tree

`my $data = $resp->{'data'};` is a long-established pattern across
this codebase's protocol client code (`plan-9.client.read`/`.open`,
`storage.9p.open`/`.walk`/`.clunk`, ~146 files total per a live
`ncode s` count) — a lexical scalar named the same as the package-wide
`%data` hash that every `<foo.bar>` macro expands into
(`$data{'foo'}{'bar'}`).

**Not a functional bug**: Perl keeps `$data` (scalar) and `%data`
(hash) in separate symbol-table slots by sigil, so `$data{...}`
inside that scope still always means the hash, never the lexical
scalar. But it's a real readability hazard in a codebase this
`<...>`-macro-heavy — a skimming reader, or an LLM asked to add
another `<...>` reference inside that same lexical scope, can easily
conflate the two.

**How to apply**: when writing NEW code in this family, use a
distinct name for the response-body scalar (`$payload` was the choice
made live) instead of copying the inherited `$data` convention.
Do **not** rename it in existing files just because you noticed it —
confirmed with the user this is out of scope for casual cleanup given
the ~146-file blast radius; only touch it where you're already
rewriting the line for another reason, or if a dedicated cleanup pass
is explicitly requested.

## client/server config-default drift

`storage.cmd.plan9-connect` defaulted its port to `5640`; the actual
9P server (`plan-9.config`) defaults to `15640`. Anyone omitting the
port argument got a silent "connection refused" with no hint the two
numbers didn't match — found by hitting it live while testing, not by
review.

**Why it happens**: a config value duplicated as a literal default in
two separate files (one per side of a client/server pair) has no
mechanism keeping them in sync — nothing fails at compile time or even
at first glance; it only surfaces when someone omits the argument and
gets the wrong default.

**How to apply**: whenever reviewing or writing a client for an
existing P7 server (or vice versa), grep for the server's own config
default (e.g. `plan-9.config`'s `'port' => ...`) and confirm the
client's fallback literal actually matches it, rather than trusting
that a `//= <literal>` default was ever verified against the real
server. Worth treating as a checklist item for any future client/
server pair in this codebase, not just 9P.

#,,,,,...,,,,,,..,.,,,,,,,,..,,,,,.,,,...,,,,,..,,...,...,.,.,,,,,,.,,,,,,,,,,
#N74O6TEO2IIRVCCE47CIT5JQ3IDRIOTGYIZ5NFZ6ZGQTMSEKCKMUKXH2HD5VV7OQA7W74Q5TTLJZI
#\\\|BEHIGKISHTDXTIZXFABDLBXM6SYTTLLMNJPCEYUNTGOAQFAXTTQ \ / AMOS7 \ YOURUM ::
#\[7]HWFZSANLEWNWWWPE6N2ZQ2UHT77KTNODHKVDKKCORT4M3IOBO6AQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
