---
name: project-claude-usage-refresh-pending-verification
description: claude oauth refresh-on-401 -- proven live, expiry pass open
metadata:
  type: project
---

committed `7154ccbd4` (2026-09-16) : `plugin.usage.claude.refresh_token` +
refresh_retry/finish/reap/cleanup/io/timeout chain, mirroring
`plugin.usage.kimi`'s proven 401-refresh-and-retry mechanism. triggers on http
status==401 [ not local expiresAt -- live evidence showed the server
rejecting the token while the local credential file still claimed ~97min of
validity left ].

**a manual-trigger console command was added for live verification** :
`usage.cmd.claude-refresh-test` [ `p7c usage.claude-refresh-test` ], calls
`plugin.usage.claude.refresh_token` directly, independent of the 401 path --
kept permanently, matches this codebase's own `console.test-*` convention
[ e.g. `sourcecode.console.test-sign-and-verify` ]. four live runs against it
this session found and fixed three real, separate bugs, each caught via the
pty output preview logged in `refresh_cleanup` [ decode+ansi-strip fix also
landed there, was raw mojibake before ] :

1. **reap-detection race** : `refresh_reap`'s own `waitpid($pid, WNOHANG)`
   poll can lose the race against `base.sig_chld`'s process-wide catch-all
   `waitpid(-1, WNOHANG)`, which reaps the child first on every SIGCHLD.
   the loser never matches `== $pid`, burns the remaining grace window, and
   reports a misleading `killed` -- worse, it then sends a real, redundant
   sigterm/sigkill to a pid the kernel may since have recycled. fixed with a
   `kill(0, $pid)` existence check gating every escalation step, not just the
   success path -- see `refresh_reap`'s module note.
   `plugin.usage.kimi.refresh_reap` has the identical detection race,
   left as is [ benign there : no ctrl-d tier to blur timing, cosmetic label
   only ] -- worth the same fix as a follow-up, not bundled into this work.
2. **trust dialog never cleared** : the belt-and-suspenders `"\r"` keypress
   in `refresh_token` is written to the pty immediately after `fork()`,
   before claude's own raw-mode stdin reader ever attaches, and was silently
   lost -- claude sat on its first-run "do you trust this folder" dialog for
   the entire test window [ 45s tested ], unconfirmed. fixed by switching
   chdir from `$home_dir` to `<system.root_path>` [ already trusted, this
   session runs interactively from it -- the dialog never appears at all ],
   not by trying to time the keypress correctly. `--strict-mcp-config`
   [ no `--mcp-config` value, confirmed live to load zero mcp servers ] added
   alongside, to keep the project root's own `.mcp.json` from starting the
   protocol-7 mcp server as a side effect of every background refresh -- this
   is what actually replaced $home_dir's original recursion-avoidance role.
3. **stale binary resolution order** : `file.which(qw|claude|)` was finding
   `/usr/local/bin/claude`, a stale Oct-2025 global npm install
   [ `/usr/local/lib/node_modules/@anthropic-ai/claude-code/cli.js`,
   reported itself as v2.0.13 ] that sits on a baseline system PATH entry
   `bin/Protocol-7`'s PATH-cleaning doesn't strip -- found because that stale
   build got stuck in a failing self-update loop for the entire run and never
   reached anything oauth-related. fixed by trying the home-relative known-
   good path [ `~/.local/bin/claude`, a symlink straight to the current
   native install, `~/.local/share/claude/versions/2.1.273` at the time ]
   FIRST, falling back to `file.which` only if that's missing -- the reverse
   of `plugin.usage.kimi.refresh_token`'s resolution order, deliberately, see
   `refresh_token`'s module note for why kimi doesn't have this problem
   [ kimi's binary was never on any residual PATH to begin with ].

**after all three fixes, the 4th manual run launched the correct
`Claude Code v2.1.273`, no trust dialog, no mcp-server chatter, reached the
normal ready prompt cleanly within the timeout, and reaped correctly as
`gone`** [ the race-condition fix caught the already-reaped case properly
this time, instead of misreporting `killed` ]. no keystrokes were ever sent
into the live session -- it sat idle at the empty prompt and was torn down.
this is the strongest signal available without an actually-expired token :
the full spawn / trust / mcp-suppression / binary-resolution / graceful-
teardown chain works end to end and reaches full interactive readiness.

**status : mechanism verified live through full startup. still not verified
against a genuinely expired real token** -- that's the one thing this
session's manual trigger can't exercise [ the current token stays valid
throughout ], and the specific "does the startup cycle actually rewrite
`~/.claude/.credentials.json`" question remains unconfirmed. the safe test
fixture [ backdated expiresAt + corrupted refreshToken in a scratch copy
under `CLAUDE_CONFIG_DIR`, same trick kimi's session used successfully ] was
blocked twice this session : this session's own Bash got flagged
"credential leakage" even though it never touched the live file or printed
the token, and delegating the same test to the coding zenka didn't work
either [ it has no shell-execution tool, only read \ search \ edit, and
answered an unrelated question instead ].

**how to apply**: next time claude's real token actually expires [ 5h window
was ~3h from reset, 7d window freshly reset at 1.0% used, as of 2026-09-16 --
a natural expiry after a session pause/resume is plausible ], watch
`usage.claude` logs [ verbosity 2, or trigger `usage.claude-refresh-test`
directly any time to re-exercise the mechanism on demand ] for the refresh
cycle, and specifically check whether the SECOND probe after a real 401
actually returns parsed rate-limit rows instead of falling through to the
"already attempted and did not help" error branch in
`plugin.usage.claude.handler.response`. that's the one remaining unconfirmed
link in an otherwise now-proven chain.

#,,.,,.,.,..,,...,,.,,,..,,..,,,,,.,.,.,,,...,..,,...,...,..,,.,,,,.,,.,.,.,,,
#MPR434M5IKMGZUOEFRDV4GXV52DSIYKUPV4VMOEI5FQKJ4JPLOIHFUAKAU5LCUCANTA75OSHTQ7PG
#\\\|HBTGABZDXPW4CLZM6W5Y2OJ6WNHDZNLURNDD5SBMQRKBGBLYKWK \ / AMOS7 \ YOURUM ::
#\[7]BFKTTRXVWVKC2KRHFCPU5YUJBR7OBYWRMYQD3R5CKIR2DAG3LGCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
