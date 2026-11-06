---
name: project-2026-11-06-session-handover-host-labels
description: START HERE 2026-11-06 : host names to labels, letsencr join separator fix deployed ; next N7FS byte form
metadata:
  type: project
---

follows [[project-2026-11-05-session-handover-shm-a]].

**landed** : 9dd6caa7d + 2aed9a96b host labels and neutral examples ; new label srv-16 [ not a project server ].
archives, dn* nodes, service names and the private local address stay as they are. ssh aliases : desktop, and the
four servers on srv-16 for its user [ names resolve, logins from there untested ].

**letsencr fix** : ed16d0d9f wrote join( qw| |, .. ) -- an empty list, so NO separator : domain lists, alt_names and
pinned addresses ran together. same in v7-zenki.cmd.jobsite-sync-token. all 6 now q{ }. the stale enroll test hid it
by dying early. **deployed 2026-11-06 on all four servers** [ 390c46675, letsencr + v7-zenki reloaded ; owner : no multi-name certificates yet ]. was : renewals of multi-name certificates affected until a host has
the fix. full restart on all four the same day, base on-demand log dedup active. checked [ journal since 2026-10-31 ] :
no certificate request or renewal logged on srv-V \ srv-A ; srv-U \ srv-F logs show none either but lack the 10-31 pull
lines, so may not reach back that far.

**lesson** : qw| | is never a space. a test exiting non-zero with no summary line is a crash, read its tail.

**no history rewrite [ owner 2026-11-06 ]** : the labels went in as forward commits, hub history keeps the old names
on purpose -- no force push was forgotten. they are public infrastructure [ dns, mx ] ; the local desktop host was
scanned, its commit messages reworded, long names are in the pii patterns, ip addresses not yet.

**open** : bare short server names in memory [ word-by-word ] ; exfiltration filter in /etc/protocol-7/ has the
long host names [ owner ] : addresses later, check that it sees commit messages ; todo R6D p7_sign says started for a
job that died at startup ; todo PCJ ned paste modes, design recorded ; unsigned top-level files are staged by hand.

**next** : N7FS, from [[project-2026-11-05-n7fs-current-state]] [ binary byte form first ]. labels later : automatic
ones in [[reference-host-and-domain-labels]], may follow from the N7FS namespace.

#,,,.,,.,,,,.,..,,,..,,,,,.,.,,,,,,,,,,,.,...,..,,...,...,...,.,.,,..,...,,,,,
#Q4OLIJM5LO57KDGOGJUL6Q3IYC3I7APYUJWXB5OTQR3HJEU3MFTQ4JUXGTJHXARHQCYGPMGTYABKU
#\\\|OCZC7754E3J5PUVTAFJKXSFN4C4CETTU54SSXXLRYWLVW2Q2ZDW \ / AMOS7 \ YOURUM ::
#\[7]GTNKXINHGEW3T36NF24LRMCTFRDXYRTWMDMNCNSGKNGZFWIKAYCA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
