# idea — periodic access-list self-review via coding zenka [ not yet built ]

2026-09-20, noted mid-way through the category-5 wildcard narrowing pass
([[devmod-zenki-sweep-classification]]). not scoped or started — just
capturing the idea before it's lost.

## the idea

a context template in `data/yaml/context-templates/` that the coding zenka
can run [ scheduled or on-demand ] to:

1. pick a zenka [ or sweep all of them, randomly or round-robin ], read its
   current `access.cmd.usr.*` / `access.devcmd.usr.*` grants against its
   real modules.load-aware command universe [ `bin/dev/access-sweep-preview`
   already does most of this mechanically ], and think about whether the
   split still makes sense — flagging stale/dead grant names [ commands
   that no longer exist, like the `list-deps` / `valued-list` / nshell
   `history`/`eval`/`execute` cases found by hand this session ], newly
   added own-module commands that fell through the cracks, and anything
   that reads as dev-only but is still on the permanent axis.

2. separately, gather commands an LLM dev session actually TRIED to call
   and got denied [ access refusal ] during coding-zenka work — something
   like `sub-list` might turn out to be generally useful and worth adding
   to the regular or devcmd axis, but nobody notices a one-off denial in
   a live session unless it's tracked. needs a capture point somewhere in
   the refusal path [ `base.handler.command`'s `insufficient access
   permissions` branch, or the security log `base.parser.access_conf`
   already writes to ] that a periodic sweep can read back.

## why this matters

the category-5 narrowing pass done by hand this session [ 2026-09-20 ]
found real drift in every zenka touched : stale dead-command grants
sitting unnoticed for who knows how long [ `list-deps`, `valued-list`,
nshell's `history`/`get-history`/`clear-history`/`eval`/`execute` ], and
own-module commands that existed but were never explicitly granted
[ `contributions`, `index-stats`, `summarize-done`, storage's `visual`,
plan-9's `export-directory` ]. that's exactly the kind of thing a
periodic automated pass would catch continuously instead of once per
manual sweep.

## related idea — mine eval-code/exec-sub usage for new devmod commands

added 2026-09-20, same conversation. collect logs of actual `eval-code`/
`exec-sub` invocations [ across coding-zenka sessions and any other LLM
dev usage ] and periodically review them for recurring patterns that
would be better served by a dedicated, named devmod [ or zenka-specific ]
command — e.g. a one-off `eval-code` snippet that just lists a hash,
dumps a buffer, or greps `%code` for a pattern is the LLM "thinking in
code" to work around a missing shortcut. promoting common patterns to
real commands [ list-*, dump-*, etc, parallel to devmod's existing
`list-subs`/`dump-env`/`core-subs` ] would let larger models reach for
a plain command instead of writing perl each time — a direct token-cost
reduction on top of the safety/gating benefit of narrowing eval-code
usage generally.

natural fit with the self-review idea above : the same periodic pass
could read both signals [ commands requested-but-denied, and eval-code/
exec-sub payload patterns ] to build one combined "candidate new
commands" report.

## related idea — same review task on forensics zenka, security-angled

added 2026-09-20, same conversation. the coding-zenka self-review idea
above is optimization/ergonomics-angled [ fewer eval-code round-trips,
lower token cost ]. the same underlying mechanism [ periodic review of
access grants + eval-code/exec-sub usage patterns ] should also exist
on the forensics zenka side, but angled for security review instead :
what got run through eval-code/exec-sub that maybe shouldn't have been
reachable at all, what access patterns look anomalous, whether a
devcmd-gated command was exercised outside an expected devmod-enable
window, etc. two different lenses on the same log data — one asks
"what should become a first-class command", the other asks "what
looks like it needed tighter gating in the first place".

## status

idea only. no template written, no capture mechanism built. revisit
when there's a natural opening — not blocking the current sweep.

#,,,.,.,,,,.,,..,,.,.,.,,,..,,.,.,.,,,..,,..,,..,,...,...,..,,,,.,,,,,.,,,,..,
#BTI3GJGO6PB33OKN2ZOS2YSRCOCGITSJRLYCYSLAJK62TLPW3WGWMZART2GPOY5ABGZPX3KQOIMLK
#\\\|ED2UPW4LD6FQOHZJYPRR2SRFZDLAJB2YR2UYVKTW5GYTF2WDOHK \ / AMOS7 \ YOURUM ::
#\[7]7EKBJ3RHSQQRISTNMKCLVY73DPID347LLNELQSKVFTWHWRQXQCCQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
