---
name: dist-upgrade-streaming-condenser
description: "bin/p7-deps dist-upgrade reworked from buffered backtick batches into a live stream condensed through AMOS7::deps::aptlog [extracted from src/debian.log.condense] -- root-caused delta's 1.8s no-op exit-0 runs [backticks + help-fallback shape + sudo env_reset stripping DEBIAN_FRONTEND -> whiptail blue-screen blocks]; reader splits on [\\r\\n]+ for the tty progress protocol; condenser rules cover both Get: repo formats, 'The following...' name lists [* and :arch tokens], unicode-ellipsis unpack/setup/removal lines, percent fragments; p7-deps exits 1 on failure, styles the stream with TERM::Frame, house \\b\\b SIGINT clean-exit"
metadata:
  node_type: memory
  type: project
  modified: 2026-10-26
---

Second half of the 2026-10-26 delta session (first half: the condition-dependency
start-gate fix, [[condition-dep-start-gate-colon-syntax]]). The `dist-upgrade` zenka
(via `bin/p7-dist-upgrade` -> `bin/p7-deps dist-upgrade`) ran for ~1.8s, printed
`[ exit 0 ] completed =).` and upgraded NOTHING, repeatedly — while a manual run
seconds later found work. Root causes, in layers:

1. `AMOS7::deps::dist_upgr::run` used backticks per step: all output buffered until
   each step ended, returned as one blob (`{ok, log}`), printed raw. v7's child-stdout
   reader (`v7-zenki.zenka.start` IO::Select on the open2 pipe) was already capable of
   line-by-line relay — the buffering was entirely on the p7-deps side.
2. `run_dist_upgrade` never exited non-zero — 'completed with errors' still meant
   exit 0, so v7 logged success. A `p7-deps` invocation with no command prints help
   and exits 0 — the same fingerprint as the observed no-op (delta's wrapper was
   verified correct; that particular shape remains the failure mode to recognize).
3. The old shell script (`bin/dependencies/debian_dist_upgrade.sh`, deleted in
   `5cf127eaf`) was always exec'd AS ROOT by v7, so its `export DEBIAN_FRONTEND=...`
   reached every child. The perl port kept process-`%ENV` delivery — which sudo's
   `env_reset` strips (manual non-root runs), so debconf fell back to the dialog
   frontend: blocked on an empty blue whiptail ('PAM configuration'), killed leftovers
   left the cursor hidden. Old script's FULL history was verified: its unattended set
   was exactly the five env vars + --force-conf* + -y — nothing was lost in the port;
   only the delivery needed armoring.

**Landed `3dd8b8de8`**:
- `AMOS7::deps::aptlog` (new): the condenser from `src/debian.log.condense`, ported
  pure; the src module is now a thin p7 wrapper (its fixture test passes through the
  delegation). Rules: one condensed line per package on 'Setting up'; 'Removing X (v)…'
  -> 'X  removed  v'; `Get:` in three forms [7-field debian, 3-field cuda-style
  `url pkg ver [size]`, generic catch-all for InRelease/Packages.diff/Index]; 'The
  following ... :' name lists -> '.. N names : <what>' [tokens: lowercase with
  optional :arch and trailing *]; routine progress dropped and counted into
  '.. N routine lines condensed'; percent-terminated progress fragments dropped;
  errors/conffile prompts verbatim; utf-8 ellipsis bytes normalized to '...'
  (dpkg prints ')…' with NO space); unpack/setup/removal regexes accept both spaced
  and unspaced '...'. Blank-line passthrough semantics of the pure condenser
  preserved (padding-skip lives in the reader only — the conffile fixture caught an
  over-reach).
- `dist_upgr`: streams each step through a pipe, splits chunks on `[\r\n]+` (tty
  progress protocol uses bare `\r` overwrites — readline-on-`\n` alone glues bursts
  into lines whose embedded CR+padding corrupt framed rows), feeds the condenser
  line-by-line, emits as produced. Options: `emit` cb, `sudo` prefix, child `path`
  [default `/usr/sbin:/usr/bin:/sbin:/bin`]. Returns `{ok, failed_step}`. The five
  non-interactive env vars travel INLINE in every command (`sudo DEBIAN_FRONTEND=...`)
  — immune to env_reset and to v7's wiped exec-external env.
- `bin/p7-deps`: emit callback styles the stream with AMOS7::TERM::Frame — step
  headers as `frame_section_header`, package/meta lines as status rows, apt-originated
  passthrough as 'apt' rows with warn level for errors; `exit 1` on failure with the
  failed step named; SIGINT uses the house `AMOS7::Util::do_exit` shape (`\b\b` erases
  the echoed ^C, `\e[0m` resets attributes — also sweeps killed-child debris, then the
  framed line, exit 130).

**Live-verified on delta**: v7 `:wait-down:` run ~8s (was 1.8s no-op), framed sections
and colored rows, `.. N names`/`.. N routine lines condensed` summaries, no dialogs;
manual root and sudo+inline-env paths both unattended-clean.

Tests: `test-p7-deps-dist-upgrade-stream.pl` (stubbed apt-get/dpkg/pam-auth-update on
a private PATH; 19 checks: streaming order, all Get: formats, name lists, ellipsis,
`\r` fragments, removal condensing, hard-fail stop, best-effort), condenser fixture
test exact-output green, `test-deps-core-perl.pl` registers aptlog.

## related

[[condition-dep-start-gate-colon-syntax]] (same session, v7-zenki side) ·
[[project-sys-deps-wiring-completion]] (where the old debian zenka stack retired)

#,,,,,,,,,...,.,,,,,.,,..,..,,.,,,,..,,,.,.,.,..,,...,..,,,.,,..,,..,,,,,,.,,,
#BXT7Y6AA2H6GY5FZZB4V6MIV6F2UJIBXIDG3M33MATDZ6I4WDT2RFB6EIMLXQNQB6WBQ3SI5CKGNM
#\\\|3X754CQHWXXH2KXBPS3RVOKZFNOJ3IUOGQKXAYEKCN4FWT6USUM \ / AMOS7 \ YOURUM ::
#\[7]E4P4TFHEGBEGC4LR2TFJXPQYY2LW5KDA6GGDOHIUA4LV2IVJZWCQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
