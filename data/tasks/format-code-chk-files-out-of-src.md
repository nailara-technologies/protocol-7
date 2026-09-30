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
