---
name: session-handover-host-prep-inline-config
description: 2026-11-18 evening : power drivers [ gembird optional, wol, pin on first use ], inline loader categories, AMOS7::Config ; all 4 servers clean on 68993003f ; host-prep week plan
metadata:
  type: project
---

builds on [[session-handover-release-6-77-7]].

landed + pushed [ hub base ] :
- power stage 1 848bd00c3 : gembird into power.plugin.gembird.*, driver dispatch, deps lazy + optional profile power-gembird
- power stage 2 239bafcb5 : power.plugin.wol.*, base.deps.pin_first_use [ opt-in deps.pin_on_first_use ], power.cmd.drivers, profile power-reach [ Net::Oping ]
- inline loader 18e8409f1 : p7_inline_decode_entry [ shared, for DATA frames later ], `/` names = category entries in base.inline_files, `.: prefix :.` sections, raw base32 re-padded ; fixed BASE32 'none' + meta leak
- AMOS7::Config 68993003f : normalize_lines shared with base.parser.config [ 5547 files x 4 identical offline ]
- notes 2b5cad0e9 49dfd10e2 : cfg/appliances/ [ moved ], briefs in data/tasks [ power-driver-plugins, arm-awareness-p7-deps-install-x11, amos7-config-reader, inline-format-categories-and-detection, amos7-src-adapter ]

servers : all four on 68993003f, cold starts clean [ srv-F 6 online, system \ nameserv \ web disabled there by host.cfg ]. ssh srv-X logs in as taeki [ git log fails there ], root@srv-X for logs [ /var/log/protocol-7 ].

next [ agreed order ] : config reader step 2 [ sources + layers + explain ], inline exporter [ cfg/ entries + sections ], then the hardware steps.

open : power stages 3-4 [ casio XJ-V2 rs232 LOW until cables are wired, x11 coupling ] ; azurum always-on or WoL decides the archive disk place ; base.prng lazy reseed ; untested live : wol + pinning [ store write as power user, host key mapping ].

lessons : sign gate runs perl 5.32 -- `map { $h{..} = .. }` and `map { $x => 1 }` blocks parse as hash constructors there ; descr lines max 55 chars [ commit hook ] ; plan step regenerates base.list.subroutines \ load-early \ dep graph unsigned : sign them before the commit.

#,,,.,.,,,.,.,.,.,...,...,,.,,,,.,..,,.,.,,..,..,,...,...,,,,,,,,,,.,,,..,,..,
#HXVZM2FZ3TX5BKGARI25GX5EEZ7ISSW2PBBPP3IH4SPRBZO2F6ICLI4NKTU46PLU32Q4HHWCU4CUK
#\\\|7NY3IMH726RMEZNQNUPD36EOV6MYJJK6GX2IPPBR2SYJNGFC2NY \ / AMOS7 \ YOURUM ::
#\[7]236HREKALOZ7G6BW2EC5AE2U6AJH4MBTFJXKFTLFGVIWUC5W2IBA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
