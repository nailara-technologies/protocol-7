# bin/format-code : .chk. scratch files out of the source tree

`format-code -c` writes a `.chk.<name>` copy NEXT to the checked file
[ same dir -- needed so `$0`-depth based lib-path detection in the checked
file resolves as for the real file, see real_syntax_errors ]. during a
check they flicker in src/, `git add -A` picks them up, a SIGKILL leaves
them behind [ 2026-09-29 : src/.chk.download.init_code ]. user : "the
current flickering is really hindering".

## direction [ decide ]

- a scratch dir outside the tree : like ncode's backup path, or the user's
  ~/.7/ [ user, 2026-09-30 : "not sure yet how" ]
- the `$0` depth trick must keep working : for P7 modules the depth does not
  matter [ they have no own lib-path BEGIN block ] -- only standalone
  scripts [ bin/* ] need the same-depth copy. so : P7 modules -> external
  scratch dir ; scripts -> keep the sibling copy, or mirror the depth under
  the scratch dir
- pid in the name + cleanup of dead-pid leftovers [ SIGKILL case ]

#,,,.,.,,,.,.,,..,.,,,.,.,.,,,,,,,,..,,.,,,.,,..,,...,...,,..,...,...,..,,,,,,
#LZMP25OMSO2CVOIIHOAXPB5OI74L5I3C47FZJZODFF235OGAE2KXLCP3X5Y3A7AEZQM2JLWKOZEIW
#\\\|Z2NKYFCG3LXNF7LRU44HPYPV7VCCWKK2KS63WS2O27DQRA6JXYM \ / AMOS7 \ YOURUM ::
#\[7]H75XOJO24DYHAH34ZDNFBNXHBFXZVVUADPSRCCDYVU7K6G2U3UDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

## done [ 2026-09-30, kimi ]

bin/format-code : P7 module .chk. copies moved out of the tree to
~/.7/format-code/ [ created mode 0700 , ncode-style home-dir
convention ] ; standalone scripts keep the same-dir sibling copy their
$0-depth lib-path detection needs . pid in the scratch name
[ .chk.<name>.<pid> ] + dead-pid sweep at -c startup [ SIGKILL
leftovers ] . fallback when ~/.7 is unavailable : old sibling copy for
everything . unchanged : sig_stop/$current_chk_file cleanup, the -e
collision check, real_syntax_errors $0 fix [ still points at the chk
copy abs path -- P7 modules never do depth-relative self-location ] .

- bin/format-code : scratch-dir setup + stale sweep after
  'my $current_chk_file' [ ~l.222-248 ], chk-path selection in the -c
  block [ ~l.340-346 ], comment update in real_syntax_errors
  [ ~l.2579-2591 ]

verified : 3000-poll watcher during a 8-module -c run -- zero .chk.
sightings in src/ , none left after ; scratch dir empty after run ;
bin/nshell -c still uses + cleans bin/.chk.nshell [ sibling , depth ] ;
fake ~/.7/format-code/.chk.fake.999999 swept on next run ; self-check
'bin/format-code -c bin/format-code' : syntax valid , no reflow .

#,,..,.,.,..,,,..,...,...,.,,,,,,,.,.,,..,.,.,..,,...,.,.,,,.,.,.,..,,,.,,.,,,
#VJXUIYC552J7YX25VRHEMYR6UUIOMM3DR4BYRSABN4M6WAN77M35Y222YKRPNXZXNNVW7RM4DOI74
#\\\|YKOXV4WZEQ2SKYT2RCO3L766CPMKLMEP3NUOELKFTAZTDKMLAHA \ / AMOS7 \ YOURUM ::
#\[7]FIMQ6UQQXEZ6OAHN3PGJFXYYFM75GC2IKJFDMFMQR6PUI2Q7N2AI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
