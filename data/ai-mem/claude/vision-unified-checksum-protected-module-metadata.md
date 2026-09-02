---
name: vision-unified-checksum-protected-module-metadata
description: future decentralized redesign unifying dependency tracking, signature verification, and updates under one checksum/module-context system, expected 10x-100x acceleration -- reason not to invest in fixing base.known_dependencies' staleness now
metadata:
  type: vision
---

`src/base.known_dependencies` is a static, hand-maintained, single global file with no
auto-update path -- it can't track a user-installed or user-written zenka's own dependencies
without editing the shared committed file (see
[[project-deps-tracking-var-relocation]] for the access-mechanism fix already done, 2026-09-01;
the content-staleness problem itself is separate and still open).

**Why not just add an auto-update mechanism now**: per the user directly (2026-09-02), the real
intended fix is much bigger than patching this one file -- a future refactor that decentralizes
dependency declarations into per-module context, checksum-protected the same way the rest of the
repository already is (AMOS7 signatures). The user's framing: this same redesign would *also*
cover signature verification and updates "in the same style," described as "a main form of
acceleration" with "10x or 100x impact expectable."

**How to apply**: don't invest real design/implementation effort into `known_dependencies`
auto-update, `.deps/profiles.yaml` reorganization, or similar piecemeal fixes to the current
static/centralized dependency-metadata model -- they're going to be superseded by this
decentralized checksum-protected redesign. Only take on trivial, cheap improvements in this area;
defer real architectural work here until the bigger unification is actually scoped. Likely
connects to the existing checksum-addressing-trinity / harmonic-mathematics vision threads in
MEMORY-vision.md -- check those when this becomes active work, and to
[[project-v7-zenki-identity-rename-complete]] / `HANDOVER.md`'s "Next Session Lead" section for
the dependency-installation-queue cluster this sits inside.

#,,,,,.,.,.,.,...,.,.,,,,,..,,,.,,.,.,..,,,,.,..,,...,...,..,,,,.,,,,,...,...,
#GEK6RIDFGSINTCK2VMTIN4EXJDOSGJWM4GQN4TD6O47L4HALWDE6WV7NEWGXN7DJEJICDQOFP63GQ
#\\\|ZU7U2TA2NJS73QAZJQNRBUYOEVN5TJM67TI6EFESBNWV5PNYAQP \ / AMOS7 \ YOURUM ::
#\[7]5DUKOAP7NY7Y2ONARZY7WP42YZ3FWFNEBDHX4EGWB2YIIGSKOODQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
