---
name: project-2026-11-06-session-handover-host-labels
description: START HERE 2026-11-06 : host names to labels, letsencr join separator fix NOT deployed ; next N7FS byte form
metadata:
  type: project
---

follows [[project-2026-11-05-session-handover-shm-a]].

**landed** : 9dd6caa7d + 2aed9a96b host labels and neutral examples ; new label srv-16 [ not a project server ].
archives, dn* nodes, service names and the private local address stay as they are. ssh aliases : desktop, and the
four servers on srv-16 for its user [ names resolve, logins from there untested ].

**letsencr fix** : ed16d0d9f wrote join( qw| |, .. ) -- an empty list, so NO separator : domain lists, alt_names and
pinned addresses ran together. same in v7-zenki.cmd.jobsite-sync-token. all 6 now q{ }. the stale enroll test hid it
by dying early. **not deployed, not pushed yet** : renewals of multi-name certificates are affected until a host has
the fix -- deploy before the next renewal window. not checked yet whether a live certificate or token line was hit.

**lesson** : qw| | is never a space. a test exiting non-zero with no summary line is a crash, read its tail.

**open** : bare short server names in memory [ word-by-word ] ; exfiltration filter in /etc/protocol-7/ has the
long host names [ owner ] : addresses later, check that it sees commit messages ; todo R6D p7_sign says started for a
job that died at startup ; todo PCJ ned paste modes, design recorded ; unsigned top-level files are staged by hand.

**next** : N7FS, from [[project-2026-11-05-n7fs-current-state]] [ binary byte form first ]. labels later : automatic
ones in [[reference-host-and-domain-labels]], may follow from the N7FS namespace.

#,,,,,,..,,..,...,,,,,..,,,..,,..,,.,,..,,,.,,..,,...,...,,..,,,,,,.,,.,,,,..,
#HQQ7F6H2RETGCRYWMDTQU7C4NKZNP4VZUVAS4HWQDD3O5IM25HMWAIMENUPN4UWIQY3J455QF7P22
#\\\|ALSL4XOWXXHLFAM5Q4P6A3SCYZQML3CWUL52PJBT2R7WPWIXPJW \ / AMOS7 \ YOURUM ::
#\[7]RL3L4HV6W5XAPCIFPXLRVHEHI7XOBQFGSCUHVQRBDP3EQRILWGDA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
