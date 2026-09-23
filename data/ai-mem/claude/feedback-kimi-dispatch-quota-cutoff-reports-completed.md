---
name: feedback-kimi-dispatch-quota-cutoff-reports-completed
description: a kimi_dispatch/kimi_continue that gets cut off by kimi's weekly 403 quota limit mid-run still shows status=completed in kimi_check_status -- the harness reports the PROCESS exited, not that the TASK finished; the actual result text is truncated mid-sentence
metadata:
  type: feedback
---

`kimi_check_status` returning `status=completed` means the underlying kimi
process exited, not that it finished the task. If the weekly (7-day) quota
hits 100% mid-run, kimi's own CLI gets a `403 access_terminated_error` from
the server, prints it, and exits — and from the harness's point of view
that's just... the process ending, which is exactly what a genuinely
finished run also looks like. `status=completed` is silent about the
difference.

**How to tell the difference**: read the actual returned text, don't just
check the status field. A cutoff run's text stops mid-sentence, often
mid-list-item, with no natural closing (a real finish ends with a summary/
report, per whatever the dispatch prompt asked for). If in doubt, `tail` the
raw captured-output file (`data/state/kimi-dispatch-*.out` from the
dispatch call's own reply) — a cutoff run's tail literally contains the
`Server: Error code: 403 ... weekly (7-day) usage limit` text.

**What NOT to do**: don't call `kimi_continue` immediately after spotting a
cutoff. The window is still at (or past) 100% for however long remains
until reset — an immediate continue just hits the same 403 again. Check the
`usage.kimi` reset countdown (or `p7c coding.call-tool check_account_usage`
equivalent) and wait until it's actually passed 0, plus a small margin,
before resuming. Confirmed live 2026-09-23: a k3 dispatch auditing ~14 files
got cut off after finishing 3 of them; waited for the 7d window to hit
0.0%/fresh, then `kimi_continue` on the same session picked up cleanly with
full prior context and finished the rest without re-doing the completed
files (told explicitly not to, in the continue prompt, since the harness
gives no automatic "resume where you left off" — the continuation prompt
has to state exactly which files are already done).

**How to apply**: after any `kimi_dispatch`/`kimi_continue` call that comes
back `status=completed`, actually read the result text before reporting it
as done. If it's truncated and/or the raw output shows a 403, treat it as a
partial result: check `git status` for what was actually written to disk
before the cutoff (verify those files independently, same as any other
kimi output), tell the user the run was cut off and roughly how much
remains, and only issue `kimi_continue` once the quota window has actually
reset.

#,,,,,..,,...,...,...,,..,,,,,,..,..,,.,.,...,.,.,...,...,...,...,,.,,,,.,,..,
#KOLZ3EC72RVGSOUAPEGKKCNZVQUFSIXC4ITI7QDIUR2GFFOD3VCTSAJK7E3QPIQGS4DEFLOKRYCJS
#\\\|7Z2DN6FADNSMULWVYWVXJ4VMFX2CVB23IXUKHCPXPE52U2DHS7A \ / AMOS7 \ YOURUM ::
#\[7]RZEOQJLOY4OQVWUVVVSREK34BHENWQG7FMONSJOO7JJ62WK6TICI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
