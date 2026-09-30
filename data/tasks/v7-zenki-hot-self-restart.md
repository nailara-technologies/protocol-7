# v7-zenki : hot self-restart [ from data/md/design/V7-HOT-SELF-RESTART.md ]

research first, design second -- no implementation before the user decides
on the design. read `CLAUDE.md`, the design file, and
`data/ai-mem/claude/feedback-llm-fix-regressions-pattern.md` first.

## why now [ 2026-09-30 ]

a full v7-zenki restart ends invoke.ai and every running zenka -- five
times on 2026-09-29 \ 30 alone. since ba1b07685 a RELOAD applies source
and start.cfg changes [ dependency chains, on-demand registration ], so
the remaining reasons for a restart are narrower : changes to the named
subs in bin/Protocol-7's main:: [ see bin-protocol-7-main-subs-to-modules.md ],
init-only state, a hung or crashed v7-zenki. the last one is what a hot
self-restart would have to survive.

## phase 1 : inventory [ read-only ]

1. **what dies with v7-zenki, and why** : for a zenka started by v7 [
   stdin-zenka start_mode ], trace what ends it when v7 exits -- its
   stdin \ stdout \ stderr pipes to v7 [ EOF, SIGPIPE ], a parent-death
   signal, cube-side session loss, the heartbeat. per start_mode, file:line.
   `v7-zenki.cfg.zenka_stdout_redir` [ v7-zenki.setup_stdout_redir ] may
   already decouple stdout -- check what it covers
2. **what already approximates a handoff** -- check each before inventing :
   - keep-children [ 36a2d8259 ] : `restart.keep_children`, identity =
     pid + start time + cmdline, `v7-zenki.claim-children`, grace timer --
     a new instance already adopts processes it did not start
   - report-pid-file [ 71d620aa1 ] : planned end vs crash, pid files
     kept on an error end
   - reload \ reinit : what `init_code` with `$reinit` keeps, what
     `post_init` rebuilds every run [ dependency chains, on-demand list ]
3. **the restarting-state snapshot** : list the state in
   `<v7-zenki.zenka.instance>`, `<v7-zenki.zenka.setup>`,
   `<dependency.*>`, timers [ heartbeat, restart, pressure sampler,
   deferred restarts \ held starts ], jobqueue jobs, kept_children --
   which is rebuilt from config [ free ], which is live state that
   must travel, which is recoverable from the processes themselves
   [ /proc, cube's session list ]
4. **fd passing** : any SCM_RIGHTS \ IO::FDPass use in the tree or
   data/lib-path/pm ; which fds would have to travel [ unix listeners
   of stdio multiplex, child pipes ]

## phase 2 : design options [ for the user ]

compare at least :
- **a. rescue child** [ the design file's idea ] : fd handoff + state
  import, new instance skips the normal start-up
- **b. adopt instead of hand off** : make zenki independent of v7's
  pipes [ files \ stdio multiplex instead of pipes ], so a cold v7 start
  can claim running zenki the way keep-children already does, from pid
  files + identity + cube's session list -- no fd passing at all
- anything the inventory suggests

for each : what it changes in the generic start path, failure modes
[ rescue child dies mid-handoff, state import fails -> fallback to a
normal cold restart, never a stuck system ], and what can be tested on
mod-test first.

## output

a "findings" section in this file [ file:line for every claim ], the
options with a recommendation, and open questions for the user. no src
changes in this task.

#,,.,,.,.,,,.,,,,,.,.,...,.,.,,.,,,,.,..,,..,,.,.,...,...,,.,,,,,,,.,,,,,,...,
#3ZXENTF4TER2YEYUM2G4YLA56E776AY7HCFAZAUC27RPNGRH4MJUACG4JCMPERJNCM7R6CLOEMWIU
#\\\|KTZABXEG7XDQUP66YGUDF4DQLLLOSLCAKFEXKE26DVOOZMKWBMW \ / AMOS7 \ YOURUM ::
#\[7]VQM23PXTQVNZ5DRJABRY2HEOWAAL6N3DNFXHEOFTPZ4WRKNBGEDQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
