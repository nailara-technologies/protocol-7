---
name: project-2026-10-22-session-handover-j5f-multiline-files
description: START HERE -- session 2026-10-22 [ evening ] handover [ last 90da4d578 ] : J5F multi-line args in p7c \ p-7-r + coding.input.decode, multi-line parser fixes, message templates ; files \ file-view zenka design with N7FS on dev/files-zenka-design [ 17 open questions ]
metadata:
  type: project
---

previous : [[project-2026-10-22-session-handover-remote-fetch-link]] [ its
open items 1, 2, 4, 6 still stand ; item 3 : all six cloud docs landed in
7120e0197 ]. budget at the end : claude 7d ~25 %, kimi 7d ~8 %, cloud
credits ~$39 minus one design session [ expire 2026-11-05 ].

## landed [ local, live-tested on this host ; push pending owner go ]

- 7c3231a56 J5F : p7c \ p-7-r send an argument with a linebreak in
  MULTI-LINE mode [ '<cmd>+', empty header, args as body, '.' -- the mode
  existed, B32 was not needed ] ; dot-stuffing ONLY for lines of dots
  alone [ hand-typed '.foo' passes ; owner : compat with old remotes is
  no issue, update them in a loop -- pick the best form ]
- 7c3231a56 base.handler.command : capture NON-GREEDY [ a pipelined 2nd
  packet was swallowed ] ; inner strip + incomplete check take the
  capture's strict head [ replies frame with SIZE \ STRM, never '+' ;
  '(id)cmd' without a blank is the route form ]
- 7c3231a56 coding.input.decode : plain \ B32: \ :file: , no base32
  guessing, :file: repo tree only [ realpath, tree check before existence,
  256K \ summarize 4M ] ; submit \ summarize-context \ ask-reply use it ;
  summarize-context path= confined ; mcp-server-p7 summarize-file reads
  client-side and sends :B32: [ active after an MCP server restart ]
- 90da4d578 a refused '+' head drops its packet [ stripped to its '.'
  line, else session ignore_ml_packet until it arrives ] -- before, its
  body ran as single-line commands ; replies \ logs as templates A6ZTSCY
  KA4I2BY OAZPKOI H7KA5EY M2MLE6A ; param syntax reply APPENDED [ '='
  overwrote waiting replies ]
- bd32643ca strip re-sign [ kimi left a signature fragment ]
- todo J5F : PROGRESS line, remaining items listed there

## deploy notes

- new templates load on `reload init` \ `reload all` or a restart ONLY :
  `reload source` keeps the old registry and sprint_t sends nothing [ the
  client hangs ]. remotes : pull + `reload all` or restart
- the installed /usr/local/bin/p7c is still the old binary until
  v7-zenki reinstalls it [ start ] ; tests used a scratch build
- devmod for tests : `p7c v7-zenki.devmod-enable coding` [ SIGNUM53, no
  restart ] -> `coding.receive-multiline` echoes ; `devmod-clear` after

## design : files + file-view [ cloud, dev/files-zenka-design ba33750b7 ]

- data/md/design/FILES-ZENKA.md [ 893 lines, NOT yet in base ] : `files`
  [ name decided : `file.*` is the base.file.* alias space ] holds read
  rights as its own uid, attach -> handle H [ key_56 ] over content C,
  scoped to a target zenka [ + task label ], expiry \ fetch count \
  revoke as appended record versions, nested attachment groups ;
  `file-view` = user-facing, no file rights, only narrows
- N7FS native : C = node bmw [ one addressing scheme ], records as content
  nodes, heads index outside the disk [ rebuilt at start ] ; gaps marked :
  node release + tombstones, references/, stream writes, assimilate meta
  override entry, shared read across uids
- 17 open questions for the owner [ start with 12 C = bmw, 14 removing
  bytes, 3 task proof via child zenki ]

## lessons

- kimi read the multi-line mode as absent and built B32 : brief with the
  protocol section's line numbers ; the owner knew the '+' mode
- follow-ups into a completed cloud session are cheap [ see
  [[reference-cloud-sessions-first-run]] ]
- logt \ sprint_t templates : one location per protocol message, id =
  amos-chksum of the LITERAL source text [ '\n' as two chars ]

#,,,.,,,,,..,,,,,,..,,,,,,..,,.,,,,,,,..,,,..,..,,...,...,...,,..,.,,,.,.,,,,,
#Z332WZ4YVFTYWY5C7GGWCKAYXCNTROH5IKKBC7U2B6JD7QSNA564DVLBQ4A7LUSB34JMVPTASFDSS
#\\\|36H35XADBC4KLVWSFQZ5O3MXVBCL45EWBGOWMAY5KNGSVSB5K6Q \ / AMOS7 \ YOURUM ::
#\[7]QLBPNBAIDD6SF4U7ZLMO4S5WOEBE43G27QVXU3VKKDZFQ5P7HAAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
