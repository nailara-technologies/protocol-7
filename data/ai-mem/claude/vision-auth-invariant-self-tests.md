---
name: vision-auth-invariant-self-tests
description: "not yet built - user's idea to add system self-tests / forensics-zenka check templates that live-verify auth invariants (e.g. identity-claim checks actually enforce real-uid matching) as a standing regression guard, since auth modes are expected to keep being altered/refined"
metadata: 
  node_type: memory
  type: project
  originSessionId: 6e49f0ab-caa0-40aa-880e-624860973ca3
  modified: 2026-09-20T13:19:35.718Z
---

Raised 2026-09-20 right after
[[project-2026-09-20-unix-auth-identity-bypass-fixed]] was found and
fixed by live cross-account testing rather than static code reading
alone (see [[feedback-verify-live-not-just-static-read]]).

**The idea**: this class of bug — a check that looks structurally
correct on read-through but silently never enforces the property it's
named for — is exactly what a small, standing self-test suite could
catch automatically, run periodically or on every relevant reload, so
future changes to auth code don't regress the same way silently. A
`forensics` zenka already exists in this system (`auth.setup.usr.forensics
= :zenka:` is a real, already-configured alias per the live `dump
^auth` this session), suggesting this could live there as a natural
home for "check templates" -- but this hasn't been scoped out yet,
just the motivating idea.

**Concrete first candidate test**, straight from this session's
incident: from a real unix account, attempt `USER=<other-configured-
alias-target> p7c whoami` for each `:unix:X` entry in
`auth.setup.usr` where the real connecting account is NOT X, and
assert every one is rejected. Would have caught the
`unix-root`/`unix-protocol-7`/`unix-taeki` bypass immediately and
would keep catching it if the comparison ever regresses back to
comparing a resolved value against itself instead of the real peer
identity.

**Not yet scoped**: whether this lives as a `forensics.*` zenka
command, a `bin/dev/*` standalone script, or a `data/tasks/*.md` design
doc first; how broadly "auth invariant" should be defined beyond this
one incident (e.g. `:zenka:` and `:auth-keypair:` auth paths might
warrant their own analogous checks); whether it should run
automatically (e.g. on every `reload plugins` touching auth code) or
only on demand.

#,,..,..,,.,.,,,,,,.,,..,,..,,...,...,,,,,.,.,..,,...,.,.,,,,,.,.,,..,.,.,,,,,
#ODCYLQTUE67PK27Z4US7GM7E34WPKNVAB46CWK5CVNIZ3FDT4JHYMYLTWSDZVRJIKUHYKITFENSD4
#\\\|OAQNMAQO6QC3MBCG2HECDGNMBAPR667HSRFXDAPP56OCBKYU6Q2 \ / AMOS7 \ YOURUM ::
#\[7]3MMQHTMWS56DT7CG3J4ENUKPVIQMHOLKSVBO3ZHBSPRPLBUIGKCI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
