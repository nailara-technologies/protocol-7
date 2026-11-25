---
name: session-handover-native-hub-watchers
description: 2026-11-25 pm handover [ new form : pointer + decisions + lessons + next ] -- shard fix, session registry \ keep-alive \ stable ids, unless= reminders, native writer, watcher stage 1 ; tier A place running on azurum
metadata:
  type: project
---

**the current state is derived, not written here** : run `p7c coding.handover` [ or read
data/ai-mem/claude/handover-live.md, refreshed by `p7c coding.handover write` ] and
`p7c coding.sessions`, `p7c coding.reminders`, `p7c usage.plan`, `::: azurum system.watches`.
base pushed up to 71ba3f9d2a ; azurum deployed at 71ba3f9d2a.

## decisions of the day [ owner ]

- NATIVE IS THE HUB [ memory p7-config-style-not-json ] : extend native, never a classic format
  inside ; converters at the edges, inward exact, outward may simplify ; native may evolve
- persistence follows reality ; bare timers never carried over ; a session may detach early ;
  the handover is DERIVED -- this file is the new form [ pointer + what cannot be derived ]
- task elements, thinking as content-addressed nodes, the dedup tree first, the always current
  tree language, one node across languages and senders, privacy by addressee, contexts as
  branched node selections with targeted compaction as a model tool [ data/tasks/task-elements.md ]
- sessions started by signals [ claude-zenka.md item 8 ] ; system detects, events routes,
  channels carries, transports as registered backends [ data/tasks/watcher-registry.md ]

## lessons

- review every dispatch : today caught a token leak [ kimi runs inherited the inbox socket and
  token -> fixed in _sanitize_agent_env ], a broken whitelist [ unless modules ], a test suite
  missed after the ntime switch [ test-usage-budget ] -- run EVERY suite touching changed code
- the commit hook's restore-permissions cut ACL masks [ data/ai-mem/claude lost protocol-7 write ]
  -> fixed, masks kept ; the script runs with `local $/ = undef`
- core module changes [ AMOS7::Config, base.sig_chld ] : prove them broadly -- Config was compared
  over 5488 cfg files [ deep Data::Dumper compare, two separate subs ], no real config changed
- WSL crashed twice : stable session id [ CLAUDE_CODE_SESSION_ID ] now carries session state ;
  /var/run is tmpfs [ never persist there ]

## running \ waiting

- tier A place on azurum [ tmux tierB:placement, as taeki ], watched : watch.place.complete fires
  on azurum when it ends [ rc=unknown : not a child ] ; then verify, then the intel disk rule
- reminders : 30.11 16:00 + 01.12 11:30 [ owner's video call, to=notify ], 20:42 kimi
  [ unless=budget:kimi:7d>=100 ]
- the 512 GB PM871 disk is arriving

## next [ ideas, each a small step ]

1. n7fs place \ placement raise their own completion signal with the real rc [ p7c events.signal ]
2. a session-start action plugin [ claude \ kimi, prompt file, context template ]
3. watcher stage 2 : events -> channels, p7-link as first transport backend [ place.complete@azurum ]
4. a context.handover provider for the dynamic context templates
5. the first native extension : multi-line values [ the writer reports the gap ]
6. kimi wire.jsonl normaliser for the session archive [ notes in session-archive.md ]
7. small : handover write error names the real cause [ said ENOENT on EACCES ]
8. context size reminder [ owner ] : the mcp server finds the session transcript by its stable id
   [ ~/.claude/projects/<dir>/<CLAUDE_CODE_SESSION_ID>.jsonl ], reads the last assistant turn's
   token usage, and at thresholds [ ~70 \ 85 % of the window ] posts through the inbox channel
   "context at N % : a good moment for a handover or a targeted compaction" -- an offer, with
   unless= [ a handover was just written ] ; fits task-elements.md's compaction-as-a-tool
 9. budget-aware resume [ owner ] : a dispatch that stops on a plan limit registers a reminder for the window reset [ the exact time from usage.kimi \ usage.claude -- one plan, to the second ; usage.plan rounds to 0.1 h ] ; at the reset the inbox offers to resume it [ kimi_continue / claude_continue with the session uuid ] -- an offer, unless= [ resumed already ]
 10. sign \ commit job ids [ owner ] : also the reminder ids [ src/coding.remind.add : remind-<unix ms><counter> ] ;  [ STARTED by kimi, stopped at the 7d limit : partial diff in data/state/kimi-ntime-job-ids.patch, files reset to HEAD ; resume session_d15117af-0fd1-4bba-8bcb-c9b7551e16d2 after the reset, git apply the patch first ] p7-sign-<unix time>-<pid> \ p7-commit-.. -> ntime [ bin/dev/p7-sign-run, p7-commit, p7-sign-wait parse them ]
 11. small : coding.remind rejects an at= that p7c split at a space [ at=<date> alone became due at once ; the time landed in the text ]
 12. local models [ owner ] : Moonlight-16B-A3B-Instruct Q4_K_M downloaded for a test [ coding \ assessment samples vs the current Qwen3.8-9B on ik_llama.cpp :8000 ] ; Kimi-Linear-48B-A3B-Instruct [ ~28 GB at 4 bit ] once linux runs native on the host and the windows ram comes back -- check llama.cpp support for its linear attention first
 13. web 429 lockout [ zulum 2026-11-25 ] : a second jobsite tab kept sending a stale token -> per-source bearer fails [ 31 / 27 / 17 ] -> up to 1 h 429 for the whole address, valid token too. cleared by stopping web, zeroing the counters in shared/web-auth/admission/state.yaml [ web writes them back on shutdown ], starting web. fix : the ui stops polling after a 401 ; the gate counts repeats of the SAME stale token once
 14. jobsite ui session lifetime [ owner ] : sessions already survive a web restart [ disk, token hash, ttl 86400 ] ; the overlap renewal fails after a longer absence [ the token expired, nothing left to renew with ]. plan : sliding lifetime on real activity + absolute max ; a separate long-lived renew credential [ hashed, renew path only, rotated on each use, a reused old one revokes the chain ] ; a clean logged-out state, no retry loop [ #13 ]. in-memory detach \ re-attach not for sessions : disk hash is safe and survives crashes \ reboots. options beyond : a client certificate [ owner ; strong, but import \ renewal per browser + device -- only with one-step enrollment through the existing request-certificate path ] or a passkey [ webauthn : device-bound key, browser-native ui, no file to import ]. with a local protocol-7 set-up [ owner ] : the node already holds C25519 keys and an authenticated link -- a local login helper [ `p7c web.login` signs the server challenge, hands the browser a fresh session ], or the ui served locally and proxied over p7-link [ no browser credential at all ]. the REGULAR path [ owner ] : proxy zenka + cred-mesh \ credential fabric + transport [ round trip working since 2026-06-09, topic-credential-fabric-proxy-transport.md ] -- check first how far a real jobsite ui session runs through it ; renew credential \ passkey only as the fallback for devices without protocol-7
 15. local composition [ owner, long envisioned ] : templates travel [ content-addressed, signed ], data syncs [ jobsite already pushes jobs ], the site is composed locally by the own httpd + web zenka -- no remote session in the browser at all, offline-capable ; #14 then shrinks to the node link. related : signed files in httpd [ 01bf2290c5 ], element exchange by checksum in VISUAL-ELEMENT-DEDUP-HOLOGRAPHIC-CORE.md ; the mode itself is not written down yet. trust [ owner ] : templates are code -- for a while the same precautions as running zenki : an incoming template update is shown as a readable diff and applied only after a signed approval [ the p7-sign-agent y \ n \ d flow ], until single elements are safe enough that their combinations can be asserted safe or desirable too. review [ owner ] : templates are simpler to review automatically -- a fixed grammar check first [ no scripts \ foreign urls \ new capabilities ], then a local model reviews the diff ; answers FALSE \ UNKNOWN \ TRUE : only UNKNOWN goes to a human, every approval feeds the assertions. multi-model policy [ owner ] : against targeted entropy -- several models of different families [ llm.service.consensus_vote exists ] ; TRUE only when all agree, any FALSE refuses, disagreement is UNKNOWN ; a review prompt never carries the template as instructions. reviewer state [ owner ] : each reviewer starts from its context template + a condensed history + current security notices -- initial entropy, no predictable state to plan an attack against ; notices raise suspicion for certain activity types, a hit may go to forensics silently instead of a refusal. record the init state checksum with every verdict, so a decision stays auditable -- and replayable : new models \ templates \ notices run against all past reviews, the owner's UNKNOWN decisions are the reference, forensics cases stay as regression tests [ infinitely optimisable ]
 16. icon pipeline [ owner ] : notify icons as one family [ loves.png medallion style ; kittens = system notices, elves = personal \ agent ] ; automated : prompts -> invoke \ qwen 2.1 -> scaled to 64 px -> a local vision model scores legibility, family match, level colour -> best kept ; prompt, seed, model and verdict recorded by checksum, so every run is replayable and tunable [ the #15 pattern ] -- the direction is already planned : data/tasks/images-elfdb-feature-collection.md [ images \ elfdb zenki, self-refining, extraction into a common target style ] and network-elf-avatar-pipeline.md [ IS ELF? filter, essence, recreatable zenka avatars ] ; the icons are a first concrete use. the owner's experiment : two stages -- a full elf as the identity source, then the round version from it with context [ gaze direction, attributes, level colour ] and the round mask, ready to scale down ; one identity, many medallions
 17. NEXT SESSION START : windows-host pulse fallback for mpv [ owner, wslg bridge goes stale ]. pgaskin/pulseaudio-win32 v5 [ pulseaudio 15.0, mit, unmaintained since 2021-08 ] : use pulseaudio.zip [ 8.75 MB, portable ], NOT pasetup.exe [ service + firewall 4713/tcp, system.pa loads tcp with auth-anonymous=1 ]. steps : 1 winget manager gains a `source: url` entry type [ url, pinned BMW checksum recorded on first verified download -- no upstream digest exists, so no sha needed ; target dir under %LOCALAPPDATA%\protocol-7 ] ; 2 powershell.pulse-start \ pulse-status [ Start-Process detached, survives wsl --shutdown ; own .pa : module-native-protocol-tcp listen=<wsl host ip> auth-ip-acl=<wsl subnet>, no anonymous, no firewall rule ; status = tcp connect from wsl ] ; 3 mpv picks the server at start [ wslg if pactl info answers, else the host server ; replaces the pin in cfg/zenki/mpv/zenka.v7:78 ] ; 4 remove the old /user/pulseaudio/bin copy after testing. pattern : powershell.pointer-stream [ open3 ]

#,,..,.,.,,..,,,.,.,.,,,,,.,,,,,,,...,,.,,.,,,..,,...,...,...,,.,,.,.,,.,,,..,
#7BWBZ5GS32QA43ND2V4YNMRYVXHKZGMEMG53DSFPDGTBV2QJ5KDTGB7N7EUXIHMNXHCRQ366PBUAU
#\\\|ZTMPPLWCZ6HRB6ZXR5PZRDQTQBEUF6GLYPUK575X57GSZPLT42B \ / AMOS7 \ YOURUM ::
#\[7]7JI3LS3BR2ZMAZGAFRVOBKMRASAZGUTSE6TDYU2IHRYH4CAO4OBA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
