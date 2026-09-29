# v7-zenki : report-pid-file [ planned end vs crash for child process state ]

## problem [ 2026-09-29 ]

invoke-web keeps `state/invokeai.pid` while invoke.ai runs ; its own clean
`stop` removes it. at a fresh zenka start an existing pid file with a dead
process means "invoke.ai died with the zenka" -> crash recovery restarts
it [ `invoke-web.recover.after_crash` ]. but a full backend restart also
leaves the file behind, so a planned restart is detected as a crash. the
zenka cannot tell them apart itself : a v7 timeout restart sends SIGTERM
first too and the zenka's TERM handler runs in both cases. only v7-zenki
knows the reason.

## design [ user, 2026-09-29 ]

a `report-pid-file` command in v7-zenki, a clone \ wrapper of the existing
child pid \ temp path reporting [ `v7-zenki.zenka.cmd.report-temp-path` :
cube sid -> instance mapping, owner write-access check, system directory
exclusion, abs_path \ valid chars ] with a different cleanup policy.
registered pid files are removed ONLY :

- on v7-zenki shutdown \ teardown [ backend restart or stop ]
- on a manual zenka stop \ restart [ `v7-zenki.terminate`, `.restart`,
  the zenka's own restart ] -- only when terminating it was successful
- at v7-zenki startup [ whatever is still registered, like the global temp
  paths : `v7-zenki.cleanup_temp_files` \ `v7-zenki.tmp-paths.global.*` ]

NOT on an error restart [ heartbeat response timeout -> `online --> error`
-> restart ] and not when the zenka process dies by itself. so a pid file
that still exists at the next zenka start means : not a planned end.

## pieces

1. `v7-zenki.zenka.cmd.report-pid-file` [ same checks as report-temp-path ;
   a regular file only, not a directory ] + a global registry that
   survives a v7-zenki restart [ like `tmp-paths.global` ]
2. cleanup hooks at the three points above ; the error-restart path must
   skip it [ find where temp paths are cleaned in
   `v7-zenki.handler.zenka_status` and where terminate \ restart \
   teardown distinguish their reason ]
3. zenka side : `base.zenki.report_pid_file` [ like
   `base.zenki.report_child_pid` : deferred until the zenka is initialized
   \ connected ]
4. invoke-web : report `state/invokeai.pid` after writing it in
   `invoke-web.cmd.start` [ the file path via
   `<[file.zenka_dir.data_path]>` ]. its own `cmd.stop` keeps removing it.
   no other invoke-web change : the crash detection in init_code stays
   "pid file exists + process gone"

## tie-in point [ user, 2026-09-29 ]

the zenka restart path of v7-zenki currently cleans up everything the
instance registered [ temp paths ] -- for every restart, the error restart
included. that is where the pid file exception ties in : the restart path
skips the pid file cleanup when the restart comes from an error [ status
error \ heartbeat timeout ], and cleans it for a manual restart.

#,,.,,..,,.,,,.,,,,,.,.,.,.,,,.,,,.,,,.,,,,,,,..,,...,...,...,,..,.,,,.,.,,,.,
#H6SDNHNKHSTYRA2DTLXLVOYLF5QINWTC5H4P2C7ZKAKQGALEMPPISTX4WXC6L7NWBUZN7SS3GTHDE
#\\\|MHASLE3FX6XP6B2NP6T2YNVGSDD2BARTAJ6TJVCGFMREVY2UJS5 \ / AMOS7 \ YOURUM ::
#\[7]DHFATSSGHF2K4WICULS226TWRTLJ63RPHA7SGZTNC5XOEMTRYAAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
