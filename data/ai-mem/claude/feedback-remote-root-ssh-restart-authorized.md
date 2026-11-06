---
name: feedback-remote-root-ssh-restart-authorized
description: 2026-10-21 owner : root@ ssh works to the four servers [ srv-U srv-F srv-V srv-A : their short Host aliases in ~/.ssh/config, label = amos-chksum -L1 <alias> ] and may be used any time ; zenki on the remotes may be restarted or reloaded any time
metadata:
  type: feedback
---

stated 2026-10-21 : "root@ logins work to all of them with the short form,
you can use those at any time" and "you can restart or reload them anytime".

- `ssh root@<alias>` [ the aliases come from ~/.ssh/config : the Host
  entries whose amos-chksum -L1 gives U F V A -- names stay out of the repo,
  see [[reference-host-and-domain-labels]] ] for read-only sweeps, git,
  logs ; `::: <alias> <cmd>` for p7 commands
- remote updates : `::: <alias> v7-zenki.start pull-git` [ runs
  p7-git-pull--rebase as root ], then `<zenka>.reload source` -- for v7-zenki itself
  `reload init` + one harmless start as the test [ 2026-10-22 ]. after a
  history rewrite : fetch + `reset --hard origin/base` +
  bin/admin/restore-p7-permissions instead [ pull --rebase would replay ]
- zenka restarts \ reloads on the remotes need no per-step ask

- 2026-11-06 owner adds azurum : `ssh root@azurum` under the same terms [ `::: azurum` answers 'user not authorized',
  its checkout is root-owned ] -- the practical way until better options exist for all hosts

**Why:** the owner wants remote steps done without a round trip each.

**How to apply:** still name each restart in the reply as it happens, and
validate every instance id [ see [[never-feed-command-substitution-into-destructive-cmds]] ].
not covered : host config secrets [ never print host.cfg whole -- grep keys,
hash values ; a web.auth.secret leaked into a transcript 2026-10-21 ],
deleting files I did not create, registrar \ dns provider changes.

#,,..,.,,,,..,,,.,...,.,,,.,.,.,,,,,.,,..,.,.,..,,...,...,...,.,.,..,,.,,,..,,
#65WQW4ZD5CA5O4ENKKIUKJ6ZNDDFYZ2VMFNIVKWYRW4V4KMZ5SDTW6TCAP4KL6OGL6XLKLONDTY6S
#\\\|U3P56DQ5ZBL454B3TCPSOPSUFD4B5IGEV2NISQVJBDPWHPUTJMB \ / AMOS7 \ YOURUM ::
#\[7]LO3S2J5YWICI6Z3IAAODRXP3HT3DOL7FCSBVL4ATDQV4W7GW4QCA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
