## 2026-07-19: native scratchpad-rescue tools for the coding zenka

Task spec: data/tasks/mcp-scratchpad-rescue-coding-zenka-tools.md — mirrors the
MCP scratchpad functionality as native coding-zenka tools so the local model
can sweep/categorize/rescue /tmp scratchpads on a timer, no external LLM needed.

### New modules [ all verified live via p7_call_tool after coding.reload ]

- `coding.scratchpad.scan` — shared enumerator: globs
  `/tmp/claude-*/*/*/scratchpad`, computes bmw via
  `<[chk-sum.bmw.L13-str]>->("$sdir/")` [ trailing slash convention ],
  merges repo state from data/scratchpad/*/IMPORT-INFO. marks unreadable dirs.
- `coding.tools.handler.scratchpad_list_all` — table output, empty dirs
  collapsed, unreadable counted.
- `coding.tools.handler.scratchpad_categorize` — reads files [ text, capped
  24KB/file 120KB total ], LWP chat call, backend fallback chain
  cpu[8001]→gpu[8000] on connection-refused, parses `verdict:` line
  [ keep|drop|needs-human-review, unsure→review ]. system prompt rubric from
  the task file.
- `coding.tools.handler.scratchpad_rescue` — imports via chmod child
  [ mkdir → created taeki-owned 0775, create → 0664 files, content through
  group bit; pattern from coding.tools.handler.delete_lines ]. IMPORT-INFO
  records per-file original mtimes [ child has no utime cmd ].
- `coding.handler.scratchpad_sweep` — timer callback: categorize tmp-only
  dirs [ max 5/run, LWP blocks event loop ], verdict keep → rescue, verdicts
  in <coding.scratchpad_sweep.verdicts>, aborts run early on inference error.

### Edits

- coding.tools.definitions: 3 gated tool blocks [ handler fallback = no
  dispatch edit needed ].
- coding.init_code: one-shot [ after 180s ] + hourly repeating sweep timers
  inside `not $already_initialized` — REGISTER ONLY ON ZENKA RESTART, reload
  does not re-register [ pending ].
- configuration/zenki/coding/subroutines.load-early: 5 new names appended
  [ required or modules don't compile at startup ].
- system-tools.yaml: 3 tools documented for the local model.
- bin/mcp-server-p7: permission bridge `_scratchpad_group_grant` — g+rx
  scratchpad dir, g+x uuid dir [ traverse-only ], g+rx fixed parents
  [ /tmp/claude-<uid> + proj ] — glob/readdir needs r on enumerated dirs,
  x alone doesn't list. called opportunistically from all scratchpad paths.

### Gotchas hit [ important for future zenka module work ]

- **File::stat overloads stat() in the coding zenka** — `( stat($f) )[9]`
  silently yields undef [ object, not list ] → use
  `File::stat::stat($f)->mtime // 0`. caused all-zero mtimes on first test.
- reasoning models [ Qwen3.5 distilled ] answer in `reasoning_content`,
  `content` empty — parse both, prefer content.
- shell env has http_proxy set — llama-server probes via curl need
  `--noproxy '*'` [ 502 from the hysteria proxy otherwise ]. LWP::UserAgent
  in zenka doesn't use env_proxy → unaffected.
- use `<[file.match_files]>->( $dir, qw| ** | )` for file enumeration in
  zenka modules [ codebase convention, files-only; dir discovery stays glob ].
- `bin/dev/ptd` reformats module whitespace in place [ grep {-f} etc. ] — re-read
  files after running it before StrReplace edits.
- p7c commands: coding.reload [ reload config/p-mods/source/reinit ],
  coding.list-buffers, coding.show-buffer <id>, coding.ask-reply <prompt>
  [ GPU backend, loaded model ].

### Verified live

list_all: 35 dirs, correct counts/mtimes/status. categorize on 5d437747 →
needs-human-review with accurate per-file analysis. rescue on 2bf5be89 →
data/scratchpad/3RCH5NDGD3ZFA as taeki:taeki, content identical, IMPORT-INFO
complete [ test import deleted after — claude triage: all droppable ].

### Pending

- signatures on all new/edited modules + mcp-server-p7 [ user passphrase ].
- coding zenka restart to register the sweep timers.
- commit [ files staged for review ].

#,,,,,,,.,,.,,,,,,,,,,...,.,.,...,,.,,,,,,...,..,,...,..,,,..,.,,,...,,.,,,,.,
#CRH36SV5FMZLXPKCLLL76CAWCPNRWIIZZSMXTPEJUCHI5D6OA2FB45BGADOBNQSFW3WBR7YIT6ANC
#\\\|PAGKDTI2LWVWQ7PC7RASFIRXEGOZXXAHKZLQDBKK6XRDZLUVRFH \ / AMOS7 \ YOURUM ::
#\[7]B3MT2POYUPOYWKESKQQ6PRKDYCIKRJIHQ6WQXYHI4H5EZXVHM2AY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
