---
name: reference-invoke-web-run-user-and-invokeai-facts
description: invoke-web runs as the invoke user [ not protocol-7 ] ; InvokeAI facts [ port 4707, db in databases/, queue resumes on start ] ; zenka-as-other-user pattern ; landed 138396484 2026-09-29
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

**never block invoke-web's event loop** [ 2026-09-29, a real crash ] :
invoke.ai is a CHILD of invoke-web [ registered via report_child_pid ] --
any end of invoke-web kills it, mid-render. a `p7c invoke-web.reload` with
new namespaces [ ~710 subs recompiled ] blocked long enough for two v7
response timeouts -> `error` -> signal 9 -> invoke.ai gone, the running
item became `canceled`. so : no heavy reloads while it renders [ new code
simply loads at the next zenka start ] ; timer \ event paths use
`invoke-web.api_async` [ clients.http ], never the blocking
`invoke-web.api` [ its 3s LWP call stalled the loop while invoke.ai loaded
models ]. setsid detaching rejected [ v7 must keep the pid : terminate \ restart
protection ] -- instead a generic v7 feature : keep children on a CRASH
restart only, reattach by name + cmdline + start time
[ data/tasks/v7-zenki-keep-children-on-crash.md ].
- `Invoke running on ..` is printed shortly BEFORE the server accepts
  connections : an immediate request gets `Connection refused` [ retry ]
- after a crash invoke.ai marks the interrupted item `canceled` with an
  empty error_type [ = a manual ui cancel ]

**config keys** : `load_config_file` nests dotted names ->
`<external.models.invokeai.path>`, never `$data{'models'}{'external....'}`
[ models export \ resolve \ repair fixed d16c38e49 ].

see [[feedback-init-code-runs-before-drop-privs]].

#,,..,,,.,.,,,.,,,,..,.,,,...,.,.,,.,,,..,,,,,..,,...,...,..,,,..,,..,,,.,,,,,
#Q2QO7ZQRSCSPXQFCIQ5PJLS7FVLDWWXQY6CBTURKT4AESGLH54EXPBH5XDSPRGX4HFHY6WHCZ2MK4
#\\\|ZG7B7TWCQE6QODRQKP7QF3JP3A6NG2D4DKNF5FMXFHW7UJLITQL \ / AMOS7 \ YOURUM ::
#\[7]D7IS3Q5ZHG6F4UDIE5EAH6I5AZNKFWCA3HOXXOBKPFTEF574BUAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
