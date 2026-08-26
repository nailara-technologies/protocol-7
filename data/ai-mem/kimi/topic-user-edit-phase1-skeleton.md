## user-edit phase 1 skeleton — start-file sequence note [ 2026-08-10 ]

The task file listed a generic start-file sequence including
`[root.drop_privs]`, `[base.net.connect:'unix']`, `[base.get_session_id]`,
and `[zenka.loop]`, but also said to model `user-edit/start` on
`cfg/zenki/keys/zenka.v7` and set `modules.load = terminal editor
ascii.frame user-edit` (no `auth.client net protocol io.unix`). The
networked sequence requires those net modules and would contradict the
"standalone console zenka" framing in the design doc and the explicit
out-of-scope warning not to wire into the live network. Resolved by
following `keys/start`'s exact working order: load shared-params, set
`buffer.zenka.log_cmd = ''`, load the four modules, init, and drop into
`[base.call.console_command]`. No networking steps, no access grants, no
`pm-dep/` or `subroutines.load-early` hand-authoring — those are
tool-generated separately.

#,,,.,.,.,,,.,.,,,.,.,.,,,...,.,,,,,.,..,,,,,,..,,...,...,.,.,.,,,,..,..,,..,,
#F2EW3LWVCXPJLKALD2UEAVTQCHVK6VOAPJSADWJKMJ63YHDWZE376A73ED66DAYUVB7F47FYZUZBI
#\\\|V7R5JB4RMAYKBTQXTNT7LLOPAJGKXLJMDV6XGQ6HVUSQYMZFGYZ \ / AMOS7 \ YOURUM ::
#\[7]52XZTWWLZU7XZLGQQB5QVU3F3YYWRBZYZXM5C4M2BVAUNQJ7AAAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
