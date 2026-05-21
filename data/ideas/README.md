# ideas — components and thought experiments

drop zone for future component ideas, integration candidates,
and thought experiments for idle exploration.

## current candidates

### TAWS — The Amiga Workbench Simulation
- taws.ch — pure JS Workbench 1.0 through 4.1
- task: data/tasks/taws-integration.md
- status: task written, contact Michael Rupp pending

### AMOS Professional
- github.com/AOZ-Studio/AMOS-Professional-Official
- public domain since ~2024
- thought experiment: visual zenka world designer
  draw zenka networks in AMOS, translate to P7 node configs
- design doc: planned

### El Gato Animation (Kevin Sullivan, 1987)
- youtube.com/watch?v=hNT4w8DLEaI — 4K/60fps preservation
- original: translucent rotating cat, blue version on crashed disk
- todo: extract frames, LLM translucent P7 style upgrade
- use: zenka status indicator, orbiting recovery animation

### AOZ Studio
- successor to AMOS Professional
- runs in browser
- potential: P7 zenka design environment in web-browser zenka

### browser-as-authenticated-data-layer
- web-browser zenka = universal authenticated data source for P7 network
- pattern: script requests authenticated page → browser loads it → DOM
  mounted as filesystem → script reads structured data, no HTML parsing
- examples:
  - yt-dlp: browser opens youtube, gets session cookies → yt-dlp uses them
  - jobsite zenka: stepstone session via browser + credential zenka
  - any web service requiring real browser fingerprinting/JS execution
- DOM filesystem mount via plan-9 zenka + data zenka namespace
  each DOM node identified by AMOS checksum → content-addressable
  inotify on DOM changes → scripts react to page mutations
- design doc: data/md/development/LLM-SESSION-MANAGEMENT.md (browser section)
  extended design: data/md/development/DOM-FILESYSTEM-MOUNT.md (planned)
- relates to: credential zenka, web-browser view stack, plan-9 zenka

### LLM session management + cross-model context
- kimi-cli sessions store hundreds of MB of reasoning in context.jsonl
- segment categories: code_read / hypothesis / dead_end / reasoning /
  conclusion / plan / insight — differential compaction per type
- seed sentence (template 4) as compression unit for reasoning chains
- browser views host remote models (claude.ai, qwen web) — same interface
- design doc: data/md/development/LLM-SESSION-MANAGEMENT.md
- task: data/tasks/kimi-web-session-cache-access.md
