---
name: feedback-remote-root-ssh-restart-authorized
description: 2026-10-21 owner : root@ ssh works to atom, pri, delta, yourum [ short host aliases ] and may be used any time ; zenki on the remotes may be restarted or reloaded any time
metadata:
  type: feedback
---

stated 2026-10-21 : "root@ logins work to all of them with the short form,
you can use those at any time" and "you can restart or reload them anytime".

- `ssh root@<alias>` [ atom pri delta yourum ] for read-only sweeps, git,
  logs ; `::: <alias> <cmd>` for p7 commands
- remote updates : `::: <alias> v7-zenki.start pull-git` [ runs
  p7-git-pull--rebase as root ], then `<zenka>.reload source`
- zenka restarts \ reloads on the remotes need no per-step ask

**Why:** the owner wants remote steps done without a round trip each.

**How to apply:** still name each restart in the reply as it happens, and
validate every instance id [ see [[never-feed-command-substitution-into-destructive-cmds]] ].
not covered : host config secrets [ never print host.cfg whole -- grep keys,
hash values ; a web.auth.secret leaked into a transcript 2026-10-21 ],
deleting files I did not create, registrar \ dns provider changes.

#,,,,,,.,,,.,,,..,,,.,,.,,...,...,,..,...,,.,,..,,...,...,..,,.,,,,,.,.,,,,,.,
#KBICF3CZOOYIRGAJIPFQJHPB2LT57GXQK63JRQB4XCBOKRRTGUVCELPZLAWQDIVLD63FJQKSMMY6C
#\\\|3QYD6JIKTLM73W7ES2FHHJCCDEHW2V7QHIDLBKLFYS7IMB4XLAC \ / AMOS7 \ YOURUM ::
#\[7]IH32ALFTLRI6D7H2M5Z4BZWFZLST6TWA6PBDKWYNUTWDG4WOJAAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
