## user-edit phase 1 skeleton — start-file sequence note [ 2026-08-10 ]

The task file listed a generic start-file sequence including
`[root.drop_privs]`, `[base.net.connect:'unix']`, `[base.get_session_id]`,
and `[zenka.loop]`, but also said to model `user-edit/start` on
`cfg/zenki/keys/start` and set `modules.load = terminal editor
ascii.frame user-edit` (no `auth.client net protocol io.unix`). The
networked sequence requires those net modules and would contradict the
"standalone console zenka" framing in the design doc and the explicit
out-of-scope warning not to wire into the live network. Resolved by
following `keys/start`'s exact working order: load shared-params, set
`buffer.zenka.log_cmd = ''`, load the four modules, init, and drop into
`[base.call.console_command]`. No networking steps, no access grants, no
`pm-dep/` or `subroutines.load-early` hand-authoring — those are
tool-generated separately.

#,,,,,..,,,..,.,.,,.,,..,,,,.,.,,,..,,.,.,,..,..,,...,..,,,,.,,.,,,,.,.,,,,.,,
#HVPFKBCH6QXCEAJZREGQS7COGMWRT23H4Y4EIMXAYIWNS5BPGKV6KSV4XDIZTH2D2E2SDBLUDHIK2
#\\\|VFSMTGGZGM752MFUPVOPPC4SSFAPY2E7BWY7TTOJZWASOBGOKD4 \ / AMOS7 \ YOURUM ::
#\[7]QZMHA4NXBIOEDIXBDPU4MHWVWJRNFE6WXCYL2KYGCLWRG5SQN6CA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
