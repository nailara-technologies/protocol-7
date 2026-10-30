---
name: feedback-fix-dns-zone-issues-when-seen
description: owner 2026-10-30 : fix dns zone issues [ invalid \ duplicate \ stale records ] when seen, no per-item ask ; mail paths verified with dig before + after
metadata:
  type: feedback
---

owner, 2026-10-30 : "you can of course fix such issues when you see them"
-- about dns zone defects found while reconciling [ CNAME next to MX,
duplicate NS, MX on a stray name, old host names ].

**Why:** the zones get reconciled for the move to our own nameserv
[[project-2026-10-30-nameserv-zone-delegation-plan]] ; leftover defects
only carry over.

**How to apply:** fix them directly in the zones we manage [ nameserv ],
name each fix in the report. anything on a MAIL path [ MX, the CNAME
chain behind it -- @taeki.v7.ax is essential ] : `dig MX` against the
serving nameservers before and after, keep the served answer identical
unless the owner asked to change it. registrar [ inwx ] edits : only
through access the owner set up, never with credentials found elsewhere.

#,,..,,,,,,..,.,.,.,.,,,,,...,..,,..,,,,,,...,..,,...,...,,,.,.,,,,,,,.,,,..,,
#TR6KGMWRBUTM2KWAW475R3X2HXCCQQSTWY2POMOAEGC2BIPKBJ377GNK7G5XPEEN5NGBH2AX5V42I
#\\\|WKQWJWYOUXFTZU55DUISPRF772WJTGHV5ZNOMRETSORQ4IYM4BW \ / AMOS7 \ YOURUM ::
#\[7]TZN7XN4JVPLDPHNUSMNI2D6ZRL7QUA3OBOXJ6ENQGJZQOV7S5SBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
