---
name: condition-dep-start-gate-colon-syntax
description: "v7-zenki condition dependencies (unix_group/httpsd-style) were parsed by set_up_zenka_dependencies but v7-zenki.zenka.cmd.start's dependency loop treated every token as a zenka -- a condition dep failed start_once and was then refused by zenka.profile_refusal under any profile with an on-demand allow list (remote-server-lowram), aborting the dependent (letsencr). Fixed by skipping type:name tokens with a registered v7-zenki.callback.object.<type> in cmd.start + cmd.restart; dependency condition syntax switched '.' -> ':' (unix_group:httpsd) since dots are p7's routing separator and colon is the cfg qualifier, keeping dots free for future remote-aware dep tokens"
metadata:
  node_type: memory
  type: project
  modified: 2026-10-26
---

Reported 2026-10-26 on `delta` (profile `remote-server-lowram`): `v7-zenki.start_once letsencr`
answered `dependency 'unix_group.httpsd' is not in the on-demand allow list of profile
'remote-server-lowram'` — `:ignore-disabled:` did not help, and the user had to comment the
condition out of `cfg/zenki/letsencr/start.cfg` to start the zenka.

**Root cause**: `src/v7-zenki.zenka.cmd.start`'s dependency loop re-parses the raw
`dependencies` string and treats every token as a zenka name. For `unix_group.httpsd`:
`zenka.is_enabled` → false → `zenka.cmd.start_once` fails ("not found in start set-up") →
`zenka.profile_refusal('unix_group.httpsd')` → refusal propagated, dependent aborted. Only visible
on profiles WITH an on-demand allow list: permissive profiles have no `zenki.enabled` list, so
`is_enabled` returns true for any name and the whole branch is skipped — which is why it read as a
"-lowram bug". `:ignore-disabled:` could never help: the flag overrides only the top-level zenka's
own gate; dependency refusals are deliberately checked on their own (a refused dependency would
otherwise leave the dependent waiting forever) — that design stayed.

**Fix** (commit `c790d7d58` on `base`): `cmd.start` and `cmd.restart` now skip any `type:name`
token whose type has a registered `v7-zenki.callback.object.<type>` — nothing to start, nothing
for the profile to refuse. The chain resolver evaluates the callback via `dependency.ok_resolve`
and the job waits in the `depending` queue until the condition holds (the original design, now
unblocked). `src/v7-zenki.set_up_zenka_dependencies` unchanged in shape; its cfg-token regex moved
with the syntax switch (below). `cmd.restart` had the same latent pattern (no refusal propagation,
so benign, but it did fire a pointless `start_once` on restart).

**Syntax switch '.' → ':'** (user-proposed, agreed): condition deps in start.cfg are now
`unix_group:httpsd` / `unix_user:<name>` — parser regex `^([\w-]+):([\w-]+)$`. Rationale: dots are
p7's routing/namespace separator everywhere, the colon is already the cfg qualifier marker
(`: v7-init :`, `:ignore-disabled:`, `:env:...:`), zenka names never contain either character
(`[$anum][$anum\-_]{0,31}`), and keeping dots free preserves the option of remote-aware dependency
tokens later. Hard switch: the old dot spelling is now inert — it reads as a plain zenka name and
gets refused as unknown. In-tree user was only letsencr; callback doc notes updated (incl. fixing
`unix_user`'s copy-pasted letsencr example).

**Coverage + verification**: new `condition dependencies [ type:name ]` section in
`bin/test-scripts/test-v7-zenki-start-gate.pl` (letsencr starts under the allow list; condition
never reaches `start_once`; plain deps still do; dot spelling asserted non-special). 21/21 there,
12/12 in `test-v7-zenki-optional-dependencies.pl` (real-zenka refusal path intact). Live-verified
on delta after pull + `v7-zenki.reload`: on-demand `start_once letsencr` queues and the zenka
presents while `httpsd` is running; user countersigned.

**Same-day follow-up** (delta log: `warn : undef value in join or string` at
`v7-zenki.parser.dependency_chain:11`): the `depends_on_zenki` chain parser joined `'zenka_name'`
for every chained object, but condition objects carry only `type`+`name` — the first real
condition dep (letsencr's `unix_group:httpsd`) made every chain stringify warn. Pre-existing for
any condition type, just never exercised before. Parser now renders zenka objects by name and
condition objects in cfg syntax (`type:name`); unit-harness verified (no warnings, `--` case
intact).

## related

[[project-ondemand-zenki-registry-wipe]] (sibling on-demand-path bug, same subsystem) ·
[[feedback-changed-established-behavior-silently]] (hard-switch shape: old spelling goes inert, not deprecated)

#,,.,,.,.,,,.,.,,,,,.,.,,,,..,,,,,...,,,,,,,,,..,,...,...,,,.,..,,.,.,,..,.,,,
#GO5PBKG4C5OZGDCB6PECZMELK5HLIIV4YMKOLH62GCKFUMCH7CQAJV2VCUTFQLEX533ETIHPOSJO4
#\\\|KJBRUZ4TYNMYHL7LIK7MR7VGXR6TKXY3FUEZPLYG5GEO7NDFG7L \ / AMOS7 \ YOURUM ::
#\[7]YDFRKFXYKFUSYCB6XA7IFPDERJQHSDFTYXM5OANKLHBRNYLBEQAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
