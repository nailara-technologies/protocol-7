## user-edit phase 1 skeleton — start-file sequence note [ 2026-08-10 ]

The task file listed a generic start-file sequence including
`[root.drop_privs]`, `[base.net.connect:'unix']`, `[base.get_session_id]`,
and `[zenka.loop]`, but also said to model `user-edit/start` on
`configuration/zenki/keys/start` and set `modules.load = terminal editor
ascii.frame user-edit` (no `auth.client net protocol io.unix`). The
networked sequence requires those net modules and would contradict the
"standalone console zenka" framing in the design doc and the explicit
out-of-scope warning not to wire into the live network. Resolved by
following `keys/start`'s exact working order: load shared-params, set
`buffer.zenka.log_cmd = ''`, load the four modules, init, and drop into
`[base.call.console_command]`. No networking steps, no access grants, no
`pm-dep/` or `subroutines.load-early` hand-authoring — those are
tool-generated separately.

#,,.,,,.,,,,,,,.,,,.,,.,,,,.,,.,.,,,,,,,.,.,,,..,,...,...,.,.,,,,,,..,,.,,,,.,
#T3ZFWCRYK2KIK5RRDWXM2BKKUG2O6ZCPVWASEKLK6IIM5E4K55KQZH43253AXE35UGREILS6Z2E62
#\\\|RTVQZACN4DBO5P6A5LQ3YMXT6GNBERVUPRPY3RS46NAMUI7U2DH \ / AMOS7 \ YOURUM ::
#\[7]YSS7XFYQFTLFKJBJ776D7TP4U4F7SJV6DHD2YCTR4UHFNHH3DCCA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
