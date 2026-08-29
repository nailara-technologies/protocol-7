---
name: feedback-grep-repo-wide-before-listing-all-callers
description: when a task file (mine or a dispatch prompt) claims to enumerate "all callers" of a function/module to update, grep the whole repo for the literal call pattern first -- scoping the search to the specific flow under discussion silently misses real callers elsewhere
metadata:
  type: feedback
---

found 2026-08-27 writing `data/tasks/coding-model-status-tracking.md`
(model-status tracking task 1): the task file's site-3 write-up said
"amos_id available at all three `spawn_inference_server` call sites" --
true only within the switch-model flow I'd been reading
(`spawn_smart`'s direct-path branch, `spawn_smart_path_reply`,
`spawn_with_deps`'s reply handler). A repo-wide `grep -rn
"coding.spawn_inference_server\]>->" src/` (only run LATER, after the
first kimi dispatch already landed and I was reviewing its diff) turned
up 8 real callers, not 3 -- missed `spawn_smart`'s OWN second call site
further down the same file, plus `spawn_with_deps`,
`coding.handler.restart_server`/`inference_crash_restart`, and
`coding.async_spawn_inference_servers` (the primary cold-boot spawner,
flagged in CLAUDE.md as the central async-startup path -- the single
biggest miss, since it meant the most common real-world scenario a
status-tracking feature exists FOR wouldn't get covered at all).

**why the narrow search felt complete at the time**: I'd read one
call chain end-to-end (switch-model -> spawn_smart ->
spawn_smart_path_reply -> spawn_inference_server) and reasonably
concluded "found the callers" without separately asking "are there
OTHER paths into this same sub that this specific investigation never
touched." A grep scoped to files already open in the reading session,
not to the actual target string across the whole tree.

**cost**: required a full second `kimi_continue` follow-up dispatch to
thread the missed callers through, plus manually catching that the new
helper the follow-up touched (`coding.helper.resolve_model_checksum`)
needed its own `gen-sub-whitelist` run the follow-up prompt hadn't
asked for either -- two extra review/fix cycles that a single
repo-wide grep up front would have prevented entirely.

**how to apply**: before writing (or reviewing) any task-file claim of
the shape "X is the only/all caller(s) of Y" -- whether Y is a sub,
a module, a config key, or a data-tree field -- run `grep -rn
"<the literal call/reference pattern>" src/` (or the appropriate
tree) across the WHOLE relevant namespace before enumerating specific
sites, even when a specific investigation already feels thorough. A
call chain traced by following one flow end-to-end is not the same
claim as "these are all the callers" -- only a literal repo-wide
pattern search earns that claim. Distinct from
[[combined-grep-conflated-caller-counts]] (a regex-combining mistake
that INFLATES a count) -- this is the opposite failure: a
correctly-scoped-looking search that's too NARROW in scope and
DEFLATES the real count.

#,,,,,...,...,,..,,,,,...,...,,..,,,,,.,.,,,.,..,,...,...,.,,,.,,,,..,,,.,,,.,
#UU62ZBW7HXOV5IUP5EPT4JBUGYEXVAACV764THDP4KGQCE4C6HIWJILBUPQ7F6OKCIA4IJIDSLGTY
#\\\|77SVI7GAOLIDR2O7JXCLJMHXQVBYWT2OK7SEUVBLLYANIQTAZJF \ / AMOS7 \ YOURUM ::
#\[7]OBNOSO2BK6OBOZPNPUZNFWST2IOR4T3OM3JCZBJIU4XXZHXN5SCI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
