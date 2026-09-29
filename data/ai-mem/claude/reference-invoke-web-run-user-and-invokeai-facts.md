---
name: reference-invoke-web-run-user-and-invokeai-facts
description: invoke-web runs as the invoke user [ not protocol-7 ] ; InvokeAI facts [ port 4707, db in databases/, queue resumes on start ] ; zenka-as-other-user pattern ; landed 0dfb27c8b 2026-09-29
metadata:
  type: reference
---

**zenka running as another user** [ pattern, from X-11 ] : in zenka.v7 set
`system.zenka-user.current = <some.user>` BEFORE `[init_modules]`, drop with
`[root.drop_privs:<system.zenka-user.current>]`, and call
`<[base.path-set-up.check-zenka-paths]>->( TRUE, 0750, FALSE, 0, '', TRUE )`
in init_code [ still root ] so /var/protocol-7/<zenka> gets that owner.
after a uid change the process is non-dumpable : /proc/<pid>/fd, syscall
are closed even to the same user -- use root strace to see a blocked call.
sudo from a zenka prompts on the v7 console [ never use it : no NOPASSWD ].

**InvokeAI [ 6.9.0 ]** :
- listens on port 4707 [ `~/.invokeai/invokeai.yaml` ], not 9090 ;
  `external.models.invokeai.url` fixed. invoke-web also takes the port from
  the `Invoke running on` line
- live db : `<root>/databases/invokeai.db` [ WAL mode ] ; `<root>/db/` is a
  stale March copy. a read-only sqlite reader CREATES missing -shm/-wal :
  never read it as root without `runuser -u <owner>`
- resumes its queue on every start and runs one item BEFORE the api accepts
  a pause -> `invoke-web.start_paused` pauses at ready ; NEVER cancel the
  running item [ user : the queue loses it ]. requeue of interrupted items :
  `data/tasks/invoke-web-interrupted-item-requeue.md`
- item end marker : `::INFO --> Graph stats: <session>` [ same session id as
  `Executing queue item <id>, session <session>` ]
- `curl` needs `--noproxy '*'` for localhost unless no_proxy is set
  [ ~/.bashrc has it since 2026-09-29, /etc/environment does not ]

**config keys** : `load_config_file` nests dotted names ->
`<external.models.invokeai.path>`, never `$data{'models'}{'external....'}`
[ models export \ resolve \ repair still use the dead flat form ].

see [[feedback-init-code-runs-before-drop-privs]].

#,,,,,..,,,,.,..,,..,,.,.,.,,,...,,..,,,.,.,.,..,,...,...,.,,,,,.,,..,,.,,,,,,
#C4JF2OWZWUJVAJZDVSNHCJUVLXOT7JDAGIIM22BZPFFQS7HCGMP7I2M4WQEAOR3TN3YRRUG634OJW
#\\\|XDUOMVTDI6HUTRIG4TSXQAONNXCVQGQN7LKYUY3VYTBDKKJS7RM \ / AMOS7 \ YOURUM ::
#\[7]3MUAXPWFL4ZVDZATRA52CEZDDLEL4GNKWE43KDQWFRD4PMNT7CBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
