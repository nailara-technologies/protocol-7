# Kimi Development Memory — Feedback (Protocol-7)

> gotchas, failure modes, and incidents moved out of `MEMORY.md` to keep the auto-loaded index
> slim. links remain valid.

## fork-child Critical Gotchas (Mar 2026)

`access.cmd.usr.child` keeps `cube.` prefix (post-hop form). `event.add_signal` hashref form only.
`route-send` for cube-routed commands; not for `child.*` aliases.
see `data/ai-mem/claude/critical-patterns.md`

## iteration-counter vs code-quality — REJECTED-ON-CHECK (2026-08-04)

file-level test of the footer's amos-iterations-remaining as quality signal:
three blind measurements [ 9B n=240 rho=+0.057 ; k2.7 n=168 rho=+0.033 ;
scripted metric n=5055 rho=+0.008 ] + distortion-injection [ 12 bugs +
2 comment-only controls, both directions, controls swing as much as bugs ].
also: the count is signing-KEY dependent — identical body, different key →
unrelated count. full writeup: data/tasks/iteration-counter-quality-results.md.

## incident : v7-zenki.terminate vs v7-zenki.restart deadlock (2026-08-04)

ran `v7-zenki.terminate kimi` instead of `v7-zenki.restart kimi` while iterating — with the
zenka stopped there is NO path to send `v7-zenki.start kimi` from inside the
session [ all p7_command/cube routing to kimi dies with it ]. needed user
to restart by hand. NEVER use bare stop on the zenka you are running
inside; use a combined restart [ stops AND starts ] or don't touch it.

**rename update (2026-09-09)**: `v7` zenka renamed to `v7-zenki`, and
`v7.stop`/`v7.stop-implicit` renamed to `v7-zenki.terminate`/
`v7-zenki.terminate-implicit` [ commits 98cc4619c, b81fa7d10 ]. the
LESSON above is unchanged, but the commands are now `v7-zenki.terminate
<zenka>` [ still dangerous on your own zenka, same deadlock risk ] and
`v7-zenki.restart <zenka>` [ `src/v7-zenki.zenka.cmd.restart`, still a
real single command doing stop+start together -- use this one, not a
manual terminate-then-start sequence, unless you specifically need
`:twin:` zero-downtime handover, which only `restart` supports ].

## incident : `v7-zenki.reload init` TORE DOWN the entire network [ again ]

issued to re-scan start.cfg files ; re-running v7-zenki.init_code hit
the fatal init path [ ai-mem kimi topic-routing-mode-implementation.md
warned exactly this ] → v7 SIGTERMed everything. root restarted v7 on
pts/3 ~2min later ; fresh boot picked up the new zenka config fine.
lesson confirmed : NEVER `v7-zenki.reload init|all` on a live network to
register a new zenka — wait for a network restart instead. single-zenka
`audio.reload source` worked fine for module iteration.

#,,..,...,,.,,.,,,,.,,.,.,,.,,,.,,.,.,.,.,,..,..,,...,...,..,,,,,,,.,,,,,,,,.,
#JX4JMXHHDDAWR62U2KXPVPSPVDHZGHYUZY6P25WLCCWHKZSXXSW6VGM2VTRQ5X6ELFUE5J7TBB6LK
#\\\|YVSHLESUVCQTZHIWUR5XUARBADRROGAFF5DTYZQW4RVVNLS2KC6 \ / AMOS7 \ YOURUM ::
#\[7]REKI7EUEUJL3KEG5WQVKINMEHM2HQQ6JHFPVA34PPRRCQ5JZPWDI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
## web-browser capture-slideshow var-watcher [ 2026-08-28 ]

The `event.add_var` var-watcher armed by `web-browser.cmd.start-capture-slideshow`
works correctly once the watched scalar is passed as an explicit
`\$data{'seg1'}{'seg2'}{'leaf'}` reference. The Glib::Event-backed `web-browser`
main loop services `Event->var` watchers normally; the earlier failure was the
escaped `\<web-browser.slideshow.url_index>` form, which the macro translator
turns into a reference to the literal name string and therefore never fires.

Also fixed: `src/web-browser.cmd.stop_slideshow` line 7 was doing a bare `== 0`
comparison against `<web-browser.slideshow.running>`, throwing an undef warning
when called on an already-stopped slideshow. Guarded with `( // 0 )`.

#,,.,,,,,,,..,...,,,.,.,,,.,.,...,,,,,,,.,.,,,..,,...,..,,,,,,..,,,.,,.,,,,..,
#Q3572WYTY4WEOWA6IAVTNNJC6O5XEAQO3NBY3ADE242CAPO37KYJCRQLOWUKSB4FD3NR5HSOWY5TE
#\\\|XE3PNLJSO7RQPL5RMGTLNT5A6QSTLIAEWP4QRRJWDYJYBPK5K4Z \ / AMOS7 \ YOURUM ::
#\[7]UJVFEH5XEKM4IAUDMXF4VCWD2PXRZK3QODPT7KY23HX4DQ7GYADY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
## format-code -m dynamic-key false positive [ fixed 2026-10-20 , commit b79ca628b ]

step7 module-sugar rewrite rewrote `$code{ $var->{'handler'} }->(...)`
to hardcoded `<[handler]>->(...)` — a recursive PPI find() counted the
ONE quote token nested inside $var's own subscript and misread it as
the literal %code key , silently dropping the vital variable part of a
dynamic dispatch . the same damage was ALREADY COMMITTED earlier
[ 2b0d77980 , src/base.X-11.handler.coordinates_timeout ] — `format-code
-c` cannot catch this class : it compiles fine and only fails at
runtime as a wrong call .

verification heuristic [ user-contributed ] : every real P7 module
name on disk is DOTTED , so any `<[word]>` sugar WITHOUT a dot is
guaranteed damage or doc prose — sweep P7-header files for
`<\[([a-zA-Z0-9_.-]+)\]>` and flag no-dot hits . the fix itself : the
subscript's content must BE exactly one literal quote token [ one
child statement whose only child is the quote ] , never merely CONTAIN
one quote anywhere . regression harness : bin/test-scripts
/test-format-code-module-sugar.pl [ convention : one test-format-code-*
.pl per pass , `-n` for deterministic exact-line comparison ] .

## perl 5.42 traps -- constants in scalar context return COUNT (2026-10-26)

verified on perl 5.42.3 : `use constant R => qw| a b c d |` used in
SCALAR context yields `4` [ the element count ] , not the last element.
any multi-word `qw| phrase |` constant silently becomes a number in
scalar context -- v1 bin/ned printed `::: not saved : 4 :::` because
the reason "constant" WAS the count. single-quoted strings for anything
scalar-context. sibling traps from the same session :
`Encode::decode/encode` CONSUME their source string unless
`Encode::LEAVE_SRC` is in CHECK [ valid input too -- buffer goes empty
after a successful decode ] ; `AMOS7::CHKSUM::ELF::elf_chksum` aliases
arg 1 and inline_elf flips its utf8 flag -- pass `q{} . $bytes` copies.
full session record : [topic-bin-ned-file-editor.md].

## SGR dim bleeds until reset (2026-10-26)

`\e[2m` [ dim ] persists until an SGR reset -- wrapping a glyph in
`dim` and moving on re-renders EVERYTHING after it dimmed. caught when
the editor's wrap continuation rows looked 'highlighted' against their
own head row : the dim on the ┊ glyph leaked into the row's text.
rule : scope decorative dim -- `dim . color . glyph . R . color`, never
bare `dim . color . glyph`. pinned by the wrapdarken pty case.
full session record : [topic-bin-ned-file-editor.md].

#,,,.,..,,,,,,...,,.,,.,,,.,.,.,,,...,,,,,.,.,..,,...,...,,,,,,.,,.,.,...,,,,,
#EEHDZ3DARJ6ROVSQGCXNN6VCXJQZETD6JKLAKIQJTJRH5SCFBQQGQODGMA3ZJ5OWZ5CJRAVSGYYBU
#\\\|3KYBT3XJTCTWUYC25CTVWDX763FQQQAVR5LOVK33S2EPUPJL22V \ / AMOS7 \ YOURUM ::
#\[7]MRSTVHRW7SNUEJ6XRRR456UPRJWHX3I3ETFA4BSUTI4JAIPNDSCA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
