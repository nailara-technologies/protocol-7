---
name: cpanm-force-install-blast-radius
description: "sudo cpanm --force for one new CPAN module can silently pull in an apt dependency chain that upgrades shared system crypto libraries used across the whole P7 stack"
metadata:
  type: feedback
---

2026-08-25: while installing `Git::Native`/`Git::Libgit2` (new CPAN modules,
needed `FFI::Platypus` + `libgit2`) via `sudo cpanm --force` (force needed
because both modules ship with unrelated test failures — remote/config-
snapshot/revwalk areas, not the code actually being used), the accompanying
apt activity on this host also upgraded `libcryptx-perl` from `0.089-1` to
`0.090-1+b1` (confirmed via `/var/log/dpkg.log`, timestamped the same
session). `CryptX` provides `Crypt::Misc`, `Crypt::AuthEnc::
ChaCha20Poly1305`, `Crypt::PRNG::Fortuna`, and other primitives P7's own
crypto stack (`AMOS7::CHKSUM`, key/session encryption) depends on directly.

The 0.089→0.090 changelog's most consequential line: **"bundled libtomcrypt
update branch:develop"** — a version bump of the underlying C library every
`Crypt::*` module in the stack wraps. That's exactly the kind of change
that can silently alter low-level crypto behavior without any Perl-level
API change being visible in a diff.

Shortly after, the user reported general key-decryption failure ("not a
specific key" — broad, not one corrupted record). Correlation timing lines
up exactly with the apt upgrade; root cause not yet 100% confirmed at time
of writing (no cached 0.089-1 `.deb` locally to downgrade-and-confirm —
Debian testing only indexes the latest version, would need pulling from
snapshot.debian.org to test the hypothesis directly), but the mechanism is
plausible and well-evidenced enough to treat as the leading suspect.

**Why this matters beyond this one incident**: `cpanm --force <module>`
for a narrow, unrelated CPAN need can have system-wide blast radius via
apt's own dependency resolution — it is NOT a sandboxed, single-module
action just because the command only names one module. On a project like
this one where the entire security/session layer depends on specific
crypto library behavior staying stable, that blast radius is a real risk,
not a theoretical one.

**How to apply**: before running `cpanm --force` (or any force-install)
for a new CPAN dependency on this host, check what else apt's own
resolver pulls in alongside it — `apt list --upgradable` before/after, or
watch `dpkg.log` during the install — and flag anything crypto-adjacent
(`libcryptx-perl`, `libssl*`, `libgnutls*`, `libcrypt-*-perl`) explicitly
to the user before proceeding, even if the target module itself has
nothing to do with crypto. Don't assume "installing one Git-diff library"
is contained just because that's the stated goal.

#,,,.,.,,,,,,,..,,...,.,,,..,,,,.,..,,,..,...,..,,...,...,..,,..,,,,,,,,.,,,,,
#Z52D2ZLNNS4GUSNH53GW6RJVMHLC7AB5Q6YJ6C7EUOFCFY7ISMS5HS4JVDB2JTX3FN2UCVBXAQZVC
#\\\|WG4YY55QZWNQB5UT4JTFKOWUNVRALS6ZWWU4YCXS4LT2RT773M3 \ / AMOS7 \ YOURUM ::
#\[7]M3BYLN3HTVEZF5RN6Y32XNADQTWFYEGPAVP5HL5YRGULWDVDKSBA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
