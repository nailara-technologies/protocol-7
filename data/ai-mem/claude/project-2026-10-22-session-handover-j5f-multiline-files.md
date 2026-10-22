---
name: project-2026-10-22-session-handover-j5f-multiline-files
description: START HERE -- session 2026-10-22 [ evening ] handover [ last 18211bbe6, all pushed ] : J5F multi-line args in p7c \ p-7-r + coding.input.decode, multi-line parser fixes, message templates ; designs FILES-ZENKA [ files \ file-view, N7FS ] and SIGNED-STATEMENTS [ v1 signed lists ] in base, owner answers recorded ; todos FKS VWF
metadata:
  type: project
---

previous : [[project-2026-10-22-session-handover-remote-fetch-link]] [ its
open items 1, 2, 4, 6 still stand ; item 3 : all six cloud docs landed in
7120e0197 ]. budget at the end : claude 7d ~25 %, kimi 7d ~8 %, cloud
credits 22 of 100 [ expire 2026-11-05 ; after that cloud sessions draw
the regular session budget ].

## landed [ pushed, live-tested on this host only ]

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

## design : files + file-view [ 5df195c78, answers 49a2f5d3e ]

- data/md/design/FILES-ZENKA.md [ in base, dev branch deleted ] : `files`
  [ name decided : `file.*` is the base.file.* alias space ] holds read
  rights as its own uid, attach -> handle H [ key_56 ] over content C,
  scoped to a target zenka [ + task label ], expiry \ fetch count \
  revoke as appended record versions, nested attachment groups ;
  `file-view` = user-facing, no file rights, only narrows
- N7FS native : C = node bmw [ one addressing scheme ], records as content
  nodes, heads index outside the disk [ rebuilt at start ] ; gaps marked :
  node release + tombstones, references/, stream writes, assimilate meta
  override entry, shared read across uids
- owner ANSWERED : 14 [ unreferenced -> garbage, reclaim on space need \
  max age, instant purge ; never-recoverable = crypto-shredding, protected
  content never deduplicated ], 18 [ security levels : keys follow the
  group tree, envelope encryption so layers never break chains, end to end
  by default, files direct or via the data zenka, tie \ mapping, keys \
  udev token ], 19 [ udev N7FS automounts, signed disks may trigger code :
  own payload signature, anti-rollback, signed node-set root, dm-verity ].
  still open : 12 C = bmw, 3 task proof via child zenki, and the rest
- existing building blocks listed in the doc : data [ shm mmap,
  lock_memory, signed permissions, fuse ], storage [ P7REF, checksum
  plugins, 9P client ], plan-9 [ 9P server ], keys, index, fs, udev

## design : signed statements [ 9d045c003, answers 18211bbe6 ]

- data/md/design/SIGNED-STATEMENTS.md : the stalled 'clean signature
  trees' question [ format + location ]. v1 = text + the AMOS7 footer,
  canonical form only, `p7 statement 1` + label + state key [ label,
  signer, subject ] + version + witness ; location nowhere specific
  [ content-addressed, index lookup ] ; footer TYPES full \ form and KINDS
  CODE \ DATA [ def 1 signs the slots, 258 bytes ] ; signers via trust.*
  as discover does ; first adopter : the module set
- owner answered : 1 [ sourcecode key \ temp key ; session keys later ],
  8 [ size + checksum signed : one signature, then size compare +
  BMW-384 per loaded module ; v1 member kind `file <name> <size> <bmw>` ],
  11 [ p7 lib set v1 ], 12 [ zenka.v7 = CODE ]
- review found : pre-commit DOES verify [ draft was wrong, corrected ] ;
  todo FKS [ high : AMOS7::SHM::sign_permission is a placeholder hash ] ;
  todo VWF [ signature_valid ignores a caller truth map ] ;
  base.list.subroutines is not enforced at load [ adoption step 4 ]

## lessons

- kimi read the multi-line mode as absent and built B32 : brief with the
  protocol section's line numbers ; the owner knew the '+' mode
- follow-ups into a completed cloud session are cheap [ see
  [[reference-cloud-sessions-first-run]] ]
- logt \ sprint_t templates : one location per protocol message, id =
  amos-chksum of the LITERAL source text [ '\n' as two chars ]
- a design brief must name the existing neighbours [ files missed data,
  storage, plan-9 until the owner pointed ] ; verify a design doc's claims
  about code before relying on them [ the pre-commit claim was wrong ]

#,,,,,.,,,.,,,,.,,...,...,,.,,.,.,.,,,,,,,.,,,..,,...,...,...,,..,.,.,..,,,.,,
#Z5HCJLOCU2AFV2GKFNVD2EI66MNDH4J4CV6PL5DTMGEOKR7FZN6IA4TLG3GMUYJWMRI7LU5T3347W
#\\\|MSVWXDKNJCURTU26XJGHLLZ3PSWH2HTOBZJIZ7WYAOORWEJ52BL \ / AMOS7 \ YOURUM ::
#\[7]IC5WZXOEZ4JA2STAI7NLAZQQNOPQBGTLWMHFPMIJENJI5MCAKMCI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
