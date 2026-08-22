# 9P live-test harnesses

Rescued from `/tmp/p7-9p-test/` (2026-08-22, ephemeral, would not have
survived a reboot) after the `storage.9p.*` client review/fix pass — see
`git log` for `storage.9p.*`/`plan-9.protocol.constants.pre_init` around
commit `f24495bc0` for the bugs these harnesses helped find and confirm
fixed.

All scripts load the *real* `src/*` module sources and apply the P7
source-to-Perl textual conventions by hand (`<[mod]>->(...)` ->
`$code{mod}->(...)`, `<path.to.const>` -> a lookup, `@ARG` -> `@_`), then
exercise them over a real TCP socket speaking real 9P2000 — no mocking of
the protocol layer itself.

- **harness.pl** — runs `storage.9p.*` against a deliberately strict,
  hand-written fake 9P2000 server built to reject spec violations:
  Twalk from an already-open fid, Topen of an already-open fid, Tread of
  a non-open fid (all `Rerror`), `Ropen` reporting `iounit = 0` (client
  fallback path), and the stat-record double-size-prefix quirk. Good for
  probing client-side spec compliance in isolation.
- **harness2.pl** / **server-daemon.pl** — run `storage.9p.*` against the
  *real* `src/plan-9.server.*` handler modules (the same code the
  `plan-9` zenka runs) over a real TCP socket — cross-validates the
  client against an independent server-side implementation of the same
  protocol, using `plan-9.server.export_buffer`'s in-memory vterm-window
  buffers as the exported content (not a real directory tree — see the
  `plan-9.server.export_directory` follow-up task for real-filesystem
  export).
- **cube-cmd.pl** — minimal raw-unix-socket cube client, bypassing `p7c`
  entirely; useful for probing cube's own auth/select/command framing
  directly. The socket path/auth user embedded in it are a snapshot of
  one session and will need updating to match whatever `cube`'s current
  unix socket path is (`list sessions` / `/var/run/.7/UNIX/`).
- **dbg.pl / dbg2.pl / trace.pl** — ad hoc debugging scripts used while
  chasing the `plan-9.protocol.constants` bug live.
- **\*.patch** — snapshots of in-progress edits during the investigation;
  superseded by the actual committed fixes, kept only as a record of the
  exploration path.
- **\*.log** — captured output from the harness/daemon runs referenced
  above.

#,,,.,,,,,...,,,,,,,,,,,,,...,,..,.,,,.,.,,..,..,,...,...,.,,,..,,,,,,..,,,,.,
#PIG3XB6BMXHCCK2CFF235XIJDHJDQD3ECWFIRUQUZTFPUHUFFVCCAAPHPJFVZJK6NNLWLZEMWDPWE
#\\\|T4U3DUKKIYYR6LDNLMZDE3OEMGPDVG2GIFXSBM35CMAPWSJJSYB \ / AMOS7 \ YOURUM ::
#\[7]7A3W7QUTD6XP7YNUVQ5IN4TXTS6IXNKLG3UCENNQ72RI5EV2DOBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
