---
name: feedback-editing-p7-owned-data-files-reowns-them
description: Read/Edit/Write on a file owned by protocol-7 silently rewrites it as my own unix user, breaking the owning zenka's read access — never hand-edit protocol-7-owned data files directly
metadata:
  type: feedback
---

Directly editing a data file owned by `protocol-7:protocol-7` (e.g. a `users.*` record
under `/etc/protocol-7/users/host-system/<name>/details.yaml`) via the Edit/Write tool
silently reassigns its ownership to whatever unix user the tool runs as (`taeki` in this
environment), because the edit is a real filesystem write, not a zenka-mediated one. The
file's *contents* come out correct, but the owning zenka (here, `users`) can then lose read
access to it entirely — and the failure mode is not a permission error, it's the zenka
reporting the record as **not found at all** ("no record for user '<name>'"), which reads
as data loss even though nothing was actually lost.

**Concretely, what happened** (2026-08-13): hand-edited `taeki`'s real `details.yaml` to
migrate an `address` field's stored value back to plain text after reverting
[[topic-user-edit-console-zenka-status]]'s address-cluster plugin. The edit itself was
correct (valid YAML, checksum still matched — `users.record.build`'s checksum is
username-derived only, `chk-sum.amos("host-system:$username")`, so content edits never
invalidate it) — but the file came out owned `taeki:taeki` instead of `protocol-7:protocol-7`,
sibling files in the same directory still correctly owned `protocol-7:protocol-7`. The
user's own live `user-edit` session then reported `taeki`'s account as not existing at all.
Diagnosed by comparing `ls -la` against an untouched sibling record directory. Fixed by
handing the user the exact `chown protocol-7:protocol-7 <path>` command (see
[[feedback-no-sudo-privileged-fs-ops]] — never `sudo` this myself), not by any code change.

**How to apply**: before hand-editing ANY file that turns out to be owned by `protocol-7`
(or another zenka's service user) rather than my own, stop and either (a) find the proper
`p7c`/zenka command that performs the write through the owning zenka itself, or (b) if no
such command exists and a direct edit is genuinely the only path, warn the user up front
that the file's ownership will need restoring afterward via `chown`, so it's expected rather
than alarming. Check ownership with `ls -la` on the target (or a sibling file in the same
directory) BEFORE editing, not after something breaks.

#,,,,,,,.,..,,,.,,..,,,..,.,.,...,.,.,,,,,,..,..,,...,.,.,,..,,,,,.,,,,..,,,,,
#PLACEHOLDER — awaiting sign

#,,..,..,,..,,,..,,,.,,..,..,,,,,,,,,,,..,.,.,..,,...,..,,.,.,...,,..,,.,,,,.,
#4QSK5EIVFWZMB57XDJARIPMGJXSRIJ53Z5KEM33YXWQLJSCYR7V3AJ4OZT3KIUEMH65LPQ7OLT6UI
#\\\|V2A2DQLLTRWBGOUHJQQZWDE65MTMEQWRULH3Y7KA5ITGCAC3Z4M \ / AMOS7 \ YOURUM ::
#\[7]ETD2FDRCGSPVHGUE2TT42YZFAX7CQYGBKLLDHNDQB4M4AFWYGEBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
