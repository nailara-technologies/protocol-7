# task: credential fabric wiring — manual verification + findings report

## dispatch
the wiring task (`data/tasks/cred-mesh-wiring.md`) has landed
(commit 21f4edfa5 — proxy.outbound.connect_or_use, cred-mesh.
seed_registry, cred_rotated subscribers, auth-relay via protocol-7-menu,
cred-mesh.cmd.approve, plus access.zenki/config wiring). read
that task file first, then skim the modules it lists as touched/created.

this is NOT the integration-test-harness task (`data/tasks/credential-
fabric-integration-test.md` — separate, heavier scope, builds a
reproducible automated harness under `bin/dev/`). this is a faster
manual pass: spin the zenki up, walk the wiring task's own `## acceptance`
section by hand, and write up what you find — pass, fail, or "couldn't
verify because X" — plus anything that looks wrong, missing, or
half-finished while you're in there, even outside that list.

## goal
produce a findings document — pick a sensible path under
`data/md/development/` (e.g. `CRED-MESH-WIRING-FINDINGS.md`) —
that walks through each item in `cred-mesh-wiring.md`'s
`## acceptance` section and records:
- how you exercised it (commands run, logs checked)
- verdict: pass / fail / blocked-couldn't-test
- anything suspicious noticed along the way (stubs, TODOs, half-wired
  branches, mismatches between the task spec and the landed code)

## suggested approach
1. use the already-running v7 instance — no root, no fresh spawn
   needed. reload landed code in place: `p7c v7.reload` then
   `p7c reload` for the cube zenka, then start/restart
   `cred-mesh`, `transport`, `proxy` as needed (they're
   on-demand; a command routed to them will start them, or use
   `p7c v7.restart <zenka>` to pick up reloaded modules)
2. confirm `var/cred-mesh/registry.yaml` gets created from a
   seed file — copy `cfg/zenki/cred-mesh/seed.yaml.
   example` to `var/cred-mesh/seed.yaml` as a starting point
3. walk the acceptance list from the wiring task:
   - seeded slots visible via `p7c cred-mesh.list` (or equiv.)
   - transport handle reuse — check the debug log in
     `proxy.outbound.connect_or_use` shows the selected handle's socket
     being used as the outbound socket, not a fresh direct-tcp open
   - header injection — seed a `session.$domain` slot, GET through the
     proxy, confirm the header reaches upstream (httpbin echo or a
     local listener)
   - rotation — `p7c cred-mesh.rotate <slot>`, confirm both
     proxy and transport caches log a flush
   - on-demand auth — hit a domain with no slot, observe the 407 /
     pending log line with req_id, `p7c cred-mesh.approve
     <req_id> <payload>`, retry, confirm success
4. note anything that diverges from the wiring task's spec — e.g. the
   gtk-dialog routing in `cred-mesh.request-authorization`
   (cube routing of `protocol-7-menu.cmd.input-*` was explicitly
   unconfirmed territory when that task was written), the rotation
   channel naming fix, the console-fallback file format

## constraints
- read-only with respect to the zenka modules — if you find something
  broken, document it precisely (file, line, what's wrong, why) rather
  than fixing it; fixes land via a follow-up task once findings are
  reviewed
- fine to create/modify files under `var/`, `/tmp/`, and the findings
  doc itself; fine to write small throwaway probe scripts if needed
- do not touch signatures. lowercase comments, `[ word ]` bracket
  annotations if you add any code

## acceptance
- findings doc exists and covers every item in `cred-mesh-
  wiring.md`'s acceptance section, each with a clear verdict and the
  steps taken to reach it
- a short "open issues" list at the end, roughly prioritized by how
  much each would block real-world use of the proxy

## signatures note
do not add the `#,,..` stub to any new file — the signing system
writes it.

#,,.,,,,,,.,.,,..,,,,,,..,,,.,,,,,.,.,,,.,..,,..,,...,...,,,.,,..,,..,...,,,.,
#M7LED6W4DYWNYDS4M2XC6MW7U6NZEIB3TAGLK4JN5LEPXRONDUTFUT3AMMNIQZR6UA6MDPPUDFGV2
#\\\|ENWCXKRTTUMJWDW6SZVXLCL4HLG6DDUB3G2EZCE7WHQRHHM6MZC \ / AMOS7 \ YOURUM ::
#\[7]HPQ6SXNDDU5NVYQDM3WXQA5XMCNGFY2JXATPFATAI3JKPBX6MADA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
