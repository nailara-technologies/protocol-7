---
name: inline sub extraction naming convention
description: how helper subs named _foo become module files when extracted from P7 modules
type: feedback
originSessionId: c1117ac8-6abc-4bfb-87da-871e78f681bc
---
When extracting inline subroutines from P7 modules, helper subs named `_foo` must become module files WITHOUT the underscore prefix.

Pattern: `sub _process_candidate { }` in `ncode.regex.expand` → module file `ncode.regex.expand.util.process_candidate`

**Why:** P7 module names use dot-separated namespaces; a leading `_` in a segment has no meaning and looks wrong. The underscore is a Perl private-sub convention that doesn't carry over to the module naming system.

**How to apply:** Always apply `s/\._/./` to the target module name when instructing the coding zenka to extract inline subs. Include this rule explicitly in the task prompt.

#,,,.,,..,,..,...,..,,,,.,,..,,,.,,.,,,,.,,..,..,,...,...,,..,,,.,,,.,.,,,,,,,
#RJP6RRXUNNX426FCA5RJLYWFEDK6XEX76S2RL64CS5LEYSNRRA4DNBNTKRJJS62ZLKRE4YQTLQWB4
#\\\|UA4QJR7HBRVMQDHEBIVLSBM33PWN7MGWDCRKXD5BSLNWT4VACIZ \ / AMOS7 \ YOURUM ::
#\[7]R57QPUGVHUV72JXTYSUZ6WCMNJMEVF2DLJW4BXZV2IN2GEZDUACA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
