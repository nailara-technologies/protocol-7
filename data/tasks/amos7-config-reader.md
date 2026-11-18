# AMOS7 config reader : p7 config outside a zenka

status : brief, not dispatched [ 2026-11-18 ]

## why

standalone scripts [ install scripts, p7-deps, p7-install, the image zenka's offline
steps ] read the same cfg/ tree as zenki : appliance recipes in cfg/appliances/,
shared-params, host overlays. today only zenki parse it [ src/base.parser.config,
210 lines, turns config into perl code to execute ].

## sources and layers [ same order and trust as the zenka side ]

1. tree defaults : cfg/<name> [ relative names resolve under cfg/ ]
2. nested includes : `[load_config_file:'<name>']` inside a file, recursive, cycle-safe
3. optional layers : `[load_config_file_if_present:'var-dir:..' \ 'cfg-dir:..' \ /abs]`
   [ var-dir -> /var/protocol-7 detected, cfg-dir -> /etc/protocol-7 decided ]
4. host overlay : /etc/protocol-7/host-config/<zenka>.cfg
5. caller overrides : a hash given to the reader [ command line, an installer's choices ]

later layers win. every layer outside the tree passes the same trust check as
base.host.trusted_file [ root \ tree owner, no group \ other write up to / ] or is
refused with a reason -- never applied silently.

## file access through a source interface

the reader never opens files directly : it asks a source for `cfg/<name>` [ exists,
read lines, trust ]. first source = the disk tree. later the inline filesystem
[ vision-inline-filesystem-self-contained-protocol-7 : cfg \ src \ data inlined like the
`__DATA__` subroutines of bin/Protocol-7, checksum-signed ] is a second source with
the same three calls. sources stack [ inline defaults < disk tree < host layers ], so
a self-contained image boots from its inline cfg and a host can still override it.
inline naming : a bare entry name is a subroutine [ src/, dot namespace ] ; other
categories are a path prefix parallel to src/ [ `cfg/appliances/<Name>/role.cfg`,
`data/..` ] -- the reader asks for `cfg/<name>`, the same name on disk and inline.
the inline format nests : a `.: parent.namespace :.` section lets its child entries
drop that prefix [ e.g. `.: cfg/appliances :.` then `pi-relay/role.cfg` ] -- the source
resolves full names, the reader never sees the nesting.

## result

- a flat hash `key.sub.key => value` plus, per key, where it came from [ file, line,
  layer ] : `explain(key)` answers why a value is what it is
- `[sub:..]` calls and `<<net>>` lookups are NOT run : returned in a `calls` list
  [ file, line, text ] so a script can show or refuse them
- `: section :` blocks [ e.g. `: v7-init :` ] kept as their own namespaces
- `=` and `:` equivalent, `\` line continuation, `#` comments, `<key>` references
  resolved against keys already read

## shape

- AMOS7::Config [ data/lib-path/pm/AMOS7/Config.pm ], no zenka deps, perl 5.32
- one grammar : share the line rules with base.parser.config so the two never drift
  [ step 1 : extract the line splitting \ continuation \ comment rules into AMOS7::Config,
  base.parser.config calls it ; step 2 : the reader ] -- the zenka parser keeps
  compiling to perl, the reader only collects values
- tests on real files : shared-params, X11-vars, a zenka.v7, a host overlay

## rules

style per CLAUDE.md ; no json, no sha ; format-code -c ; do not change zenka behaviour
in step 1 [ compare parsed output of every cfg/zenki/*/zenka.v7 before \ after ].

#,,,,,.,,,,.,,,.,,,,,,,,.,,,,,,..,,.,,.,,,.,.,..,,...,...,.,.,.,.,...,,..,..,,
#YOCA3IBU7EC67WCP7DS5KWWJC3AROSNG34FGHDWWHVWB57WWZVQCJ6CVKC3SLTUMZOTZK2SHOD4YS
#\\\|7H6QTRWWGNK7NEIIWMWX3N5BJGI37DBBXRIHM4EUUQVECL66LKU \ / AMOS7 \ YOURUM ::
#\[7]WZOMFY2JPHD26FPIWCAYKUGAXEAXT4CD6YKOI5T27BENOC6SH6AQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

## later : the settings zenka rides on this [ owner 2026-11-18 ]

data/md/design/SETTINGS-STATISTICS-ZENKA.md resolves personal < branch < network <
hardcoded -- the same stacked layers as this reader, with `explain(key)` as provenance.
personal settings live in N7FS [ sealed, synced across own hosts, never leave them in
plain ] ; branch \ network defaults arrive as signed inline \ DATA entries ; appliance
recipes [ cfg/appliances/ ] are one kind of branch default. the `settings` namespace
is held open for it [ set-up was renamed to free it ].

#,,,.,,..,,,.,,,.,,,,,.,,,.,.,.,.,.,,,.,,,,,,,..,,...,...,,.,,,,.,,,.,,..,...,
#C5EPGR3Q3U3T3VF33QFSLAEDL5KCH5QGA67SDQJMB46ZL6K7IFJRNKOBV5KWS6JZFLRNFNR7MFGUM
#\\\|XK5MVCRCFYTBGF3T7LVFOZ5CSKTH3VY2SLSYU6C5RGSGKIPDHDP \ / AMOS7 \ YOURUM ::
#\[7]FOM4PXZMEGTRTKVSUKTEBJQCZ7WTANJPHC2U7ZOXBMOXXRVYESDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
