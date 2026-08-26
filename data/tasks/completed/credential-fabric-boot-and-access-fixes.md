# task: credential_fabric zenka — fix boot blockers + console access gap

## dispatch
read `data/md/development/CREDENTIAL-FABRIC-WIRING-FINDINGS.md` first —
specifically "additional findings" item **c** (missing auth.zenki
entry), the addendum sections "correction — credential_fabric DOES
boot and seed correctly" and "new — no console/admin user can call ANY
credential_fabric command", and open-issues table rows **#2, #3, #12**.
that doc is a manual verification report against the landed
credential-fabric wiring (commit `21f4edfa5`). this task fixes the
boot-time and access-control blockers it found for `credential_fabric`
— read-write, not read-only.

note: the addendum's "second pass" found credential_fabric actually
DOES boot and seed `var/credential_fabric/registry.yaml` correctly once
its auth/startup config exists — read that section carefully so you
don't duplicate already-working scaffolding. confirm exactly what's
still missing before writing new files.

## problem — three related gaps
1. **missing `auth.zenki` entry.** `cfg/zenki/cube/
   auth.zenki` has `auth.setup.usr.credentials = :zenka:` — but
   `credentials` is a *different*, older zenka. there is no
   `auth.setup.usr.credential_fabric = :zenka:` entry, so cube rejects
   the credential_fabric auth handshake the same way it initially
   rejected `proxy` (which was fixed live during verification by
   adding `auth.setup.usr.proxy = :zenka:` — use that as your
   template/precedent).

2. **missing `start.cfg`.** `cfg/zenki/
   credential_fabric/start.cfg` does not exist (per the
   findings doc's first pass — but the addendum's second pass found
   the zenka boots, so check current state first: it may have been
   added by the operator mid-verification). if it's still missing,
   create it by copying the structure from `proxy/start.cfg` or
   another comparable on-demand zenka and adapting zenka-specific
   values (name, timeouts, restart/heartbeat flags as appropriate for
   an on-demand infrastructure zenka — see the `CLAUDE.md`
   "On-demand Management" section for the pattern: `restart.disabled`,
   `heartbeat.disabled`, `set_ondemand_timeout`).

3. **no console/admin user can call ANY credential_fabric command —
   confirmed live, this is the bigger gap:**
   ```
   :. cr.,.ic : [3577472] no perm. [ src 'cube' cmd|usr 'resolve' ]
   :. cr.,.ic : [3577472] no perm. [ src 'cube' cmd|usr 'rotate'  ]
   :. cr.,.ic : [3577472] no perm. [ src 'cube' cmd|usr 'approve' ]
   ```
   reading both access files explains why:
   - `cube/access.zenki` (around lines 337-344) grants
     `credential_fabric.resolve`, `.request-authorization`,
     `.subscribe_rotation` to **`proxy`** and **`transport`** only
     (cross-zenka), plus `.register`/`.resolve` to a few other zenki
   - `credential_fabric/access.zenki` grants `.rotate` etc only to
     **`credential_fabric` itself** (intra-zenka) — and per finding
     (d) in the doc, this file isn't even loaded by the start config
   - the cube wildcard `access.cmd.usr.*` covers only
     `commands clear heart drain when-present`
   - **nothing anywhere** grants a console/admin user (`taeki`,
     `:unix:<admin-user>`, or `*`) access to `.list`/`.resolve`/
     `.rotate`/`.approve`
   add an `access.cmd.usr.<admin-user>` grant (or extend the `*`
   wildcard, whichever matches existing convention elsewhere in
   `cube/access.zenki` — check how other admin-callable zenka commands
   are granted to `taeki` and follow that pattern exactly) covering at
   minimum `resolve`, `rotate`, `approve`. note also: there is **no
   `credential_fabric.list` (or `.cmd.list`) module at all** — the
   zenka ships 16 modules and none is named `*.list`/`*.cmd.list`, so
   `p7c credential_fabric.list` only ever returns the generic
   cube-provided `buffers` namespace. don't try to grant access to a
   command that doesn't exist; note this mismatch between the
   acceptance spec (which expects `.list`) and the landed module set
   in your summary — it may need a separate follow-up to add a `.list`
   command, out of scope for this task unless trivial.

## constraints
- fixes only — do not refactor surrounding code, do not touch
  signatures, lowercase comments / `[ word ]` bracket annotations if
  you add any
- check live state before creating files that might already exist
  (the addendum notes some of this may have been fixed mid-verification
  by the operator) — don't duplicate or clobber working config
- after each fix, if you can exercise the live system (reload cube
  with `p7c reload`, then try a routed `credential_fabric.resolve` /
  `.rotate` / `.approve` command as the admin user), confirm the "no
  perm" errors are gone
- if you cannot exercise the live system, say so plainly and note
  which fixes are unverified

## acceptance
- `credential_fabric` authenticates with cube and boots cleanly
  (verified or explicitly marked unverified with reason)
- an admin/console user can successfully call
  `credential_fabric.resolve` / `.rotate` / `.approve` without "no
  perm." errors (verified or explicitly marked unverified)
- summary notes whether `credential_fabric.list` exists as a callable
  command or whether that's a spec/implementation mismatch needing a
  separate follow-up

## signatures note
do not add the `#,,..` stub to any new file — the signing system
writes it.

#,,..,,,,,,.,,,,.,.,,,,,,,..,,,.,,,,.,..,,,.,,..,,...,...,,.,,.,.,..,,.,.,.,,,
#4VKUAZGTLU5JHZEZHK4K3YX7SUSEADZ2D4AWMJWSFAEHXAUI7VYWAMEO2DO4HIJOVBUPK2YBIXFMC
#\\\|SDQS4OUFFZD2FJO2T6T7SPPALCBZ5HKKVKBKKIPQML264SX2EYV \ / AMOS7 \ YOURUM ::
#\[7]AUV7IAHRQUI5JO3RO3E4FGSDBYYBHDEUDDISPKEOWCNVNYI3CMBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
