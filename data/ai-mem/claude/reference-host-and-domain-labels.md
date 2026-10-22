---
name: reference-host-and-domain-labels
description: live server and wanted-domain names never go into tracked text -- use derived labels srv-<x> \ dom-<x> [ owner 2026-10-22 ] ; no map is stored anywhere, the name derives its label ; exact derivation, template ORDER, depth \ offset rule, freeze rule, the four legacy one-char labels
metadata:
  type: reference
---

why : names in code comments \ commit messages \ docs go stale [ servers
get renamed ], name live deployments, and serve as examples that bring
more of them back. see [[feedback-no-personal-data-in-repo-tree]].

**no map is written down.** whoever knows the name derives the label ; the
label alone confirms a guessed name only weakly [ one checksum char = 5
bits : a wrong guess still 'matches' 1 in 32 ]. never write a name -> label
table into the repo or memory.

**derivation** [ amos-chksum, 7 chars ] :

    <p>-<d><c>    <c> = amos-chksum -T<d>%s -T<p>-<d>%s -T<P>-<d>%s -L1,<d> <name>

- `<p>` prefix lower case [ srv, dom ], `<P>` the same upper case [ SRV,
  DOM : the internal protocol-7 form ]
- the template ORDER is part of the rule -- other orders give other chars
  [ tested : a planned host gave G in this order, U in another ]
- `<d>` = depth = template digit AND offset : start at 0, go up until the
  label is not given yet. at length 1 depths 0-6 [ offset + length <= 7 ] ;
  then length 2 [ <p>-<d><cc>, depths 0-5 ] and so on
- check : name + label -> recompute with the label's own digit ; the depth
  is in the label, so a check never depends on what was assigned since

**legacy exception** : the four servers labelled first carry plain one-char
labels [ amos-chksum -L1 <name>, NO template ] : srv-U srv-F srv-V srv-A.
length < 2 after the prefix = no template. they never change.

**freeze rule** : a label once given never changes -- also one given to a
FUTURE name [ a planned host, a wanted domain ] : it is reserved from its
first use and the registered name later derives exactly it. collisions are
checked against labels already given only, never by recomputing others.

examples : a planned host whose plain char is taken -> srv-0G ; domains
dom-0U, dom-0H, and one colliding with dom-0H at depth 0 -> dom-1V.

**later** : the same scheme over BMW-L13 [ 13 chars ] or longer BMW forms
for larger namespaces [ internal ids ] ; -L3 with templates gives stable
ids but a 15-bit fingerprint [ confirms guesses ] -- fine for internal ids,
not for hiding names ; a keyed variant [ secret in a host-list zenka ]
hides names fully. one shared derive \ check function is a todo, so the
order and limits live in one place.

history : on 2026-10-22 all 78 commit messages naming servers were
rewritten to these labels [ filter-branch, tags kept, 24218 in-file commit
ids remapped, re-signed, force-pushed, remotes reset ].

#,,..,...,,.,,,,.,.,,,,,,,,,,,,,.,,.,,..,,,..,..,,...,..,,,..,.,.,.,.,..,,..,,
#7CCV36L2HJ22FUEETGA4XPMSV5XPFTKBROGEU47K2XEPWPMFDNIHAHOEZPBWNCPJRTEUU56CJQTUK
#\\\|AGW3UXRWB6VBT7YSHIRO32LIGBRDZNK5DEBQGOCEN4NIHP4BZR5 \ / AMOS7 \ YOURUM ::
#\[7]RP42VZTN67RBCOLEL2A63Z3VLFYIR4EIEYD2XBXC4WJQ3BLJPQBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
