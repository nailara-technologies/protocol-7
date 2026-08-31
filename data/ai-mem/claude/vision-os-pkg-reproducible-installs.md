---
name: vision-os-pkg-reproducible-installs
description: "os-pkg's real goal is reproducible installs: track which OS packages a user's session actually needed so a fresh Protocol-7 install can recreate that environment, once user package profiles can be mapped to session types"
metadata:
  node_type: memory
  type: project
  originSessionId: fee6b203-065d-46ee-9e22-bac7aa31efd1
---

2026-08-31, clarified in conversation while reviewing `os-pkg` zenka's
state (found empty: `os-pkg.init_code` is a bare `0;`, zero `os-pkg.cmd.*`
files exist despite a wildcard `access.cmd.usr.cube = *` grant).

**bin/os-pkg is not a general package-manager abstraction** — per the
user, it's specifically the *tracking* half of a reproducible-installation
requirement: remember which OS packages a user's session actually needed,
so that on a *new* Protocol-7 installation those same packages are likely
to get installed again automatically, rather than rediscovered by trial
and error. Confirms why the standalone `bin/os-pkg` script already tracks
installs to `var/sys-deps/tracked.yaml` with a `source` field (`manual`
vs `sys-deps`) — that's building toward "what did this kind of session
need," not just a debian-package audit log.

**All still rudimentary.** Both the `os-pkg` zenka (empty stub) and the
OS-genericity in `bin/os-pkg` (only debian implemented, explicit "OS type
'%s' not yet supported" for anything else) are correctly unfinished —
they're waiting on a real dependency, not neglect.

**The actual dependency**: per the user, this whole area moves once
Protocol-7's user data can hold **package profiles mapped to session
types** — i.e. once a "coding session," "media session," etc. is a real,
addressable concept in user data (not just an ad-hoc zenka set), package
tracking can become *contextualized*: recreate not just "packages this
user ever needed" but "packages this specific kind of session needs."
That's the missing piece `os-pkg` zenka is stubbed out waiting for.

## related

[[vision-sessions-zenka-key-holding-children]] — a different but adjacent
"sessions" layer (credential/trust boundary orchestration, not package
profiles) also waiting on a not-yet-built sessions concept; worth
reading together if/when a real `sessions` zenka design gets picked up,
since both treat "session type" as a first-class thing user data doesn't
yet support.

[[vision-user-data-derived-zenka-configuration]] — the user explicitly
generalized this same session immediately after: os-pkg/profiles is one
instance of a broader pattern (collected user data → generated real
zenka config), alongside contact-email → smtpd config generation. Read
that file for the general constraints (step by step, distributed
propagation in mind from the start, reusable primitives) before building
either instance.

## status

Pure vision/context capture, nothing implemented or requested. Don't
build out `os-pkg` zenka commands or generalize `bin/os-pkg` beyond
debian without this profile/session-type foundation existing first —
building the routing layer before the thing it routes against exists
would mean guessing at the shape.

#,,.,,,.,,,.,,.,,,.,,,,..,.,,,..,,.,,,,.,,.,,,..,,...,...,.,.,,.,,...,,,,,.,.,
#D3GTSOIMHHLUIA3SEFCFKGSDQMPVTLW42C3SL6VZHRYHAP7LPFDOQZPZ5LONKD5XEBHDR4UEFIYGK
#\\\|4ODNFFGSW5CRZARIAJCS45OQWE3KKTOMVHPRTAABTSEZ3CX7VRB \ / AMOS7 \ YOURUM ::
#\[7]DD6ACBWTJ4XFUKRBOBETYNBSEC6PUJBMQOFOVG4CGNHNHODB7MAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
