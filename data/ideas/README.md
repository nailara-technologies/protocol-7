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

### credential key holder + auth relay architecture
- detached minimal child process = only holder of master decryption key
  after init it detaches completely, communicates only via unix socket
  zero network exposure, minimal attack surface
- unix socket as identity proof: socket path = identity, v7 controls access
- per-client encryption: credential re-encrypted with CLIENT's C25519 public key
  (USR.<name>.* already exists) — plaintext never on the wire
- two delivery modes:
  - credential: raw secret encrypted for client key
  - authorized_session: key holder logs in, returns session token only
    (credential never leaves child process)
- auth relay zenka in the center, all existing transports as delivery channels:
  - SSH zenka: remote scripts authenticate via SSH key = C25519 identity
  - httpsd: HTTPS delivery for web-facing clients
  - SFTP modules: serve encrypted credential files
  - unix socket: local zenka direct delivery
- web-browser zenka for human authorization UI:
  "jobsite zenka requests stepstone credentials — approve?"
- relates to: credential zenka (v2), keys zenka, ssh zenka, httpsd, plan-9
- design doc: planned (data/md/development/CREDENTIAL-KEY-HOLDER.md)

### task buffer pixel visualization — AppIcon dock monitor
- each running task/branch = living dock icon (protocol-7-menu zenka)
- three-click cycle:
  1. pixel: 1 char = 1 translucent pixel, hue=content type, alpha=recency
     read pattern not text — red=errors, violet=reasoning, green=conclusion
  2. status line: "letsencr ▶ [ waiting.. ] ████░░ 0.67" tiny but readable
  3. buffer: full readable chars, tiny font, scrollable
- color: #000013 base → violet (reasoning) → cyan (code) → amber (warn) → red (error)
  alpha=recency: fresh=opaque, old=fading — natural temporal decay visible
- 32×32 icon = 1024 chars as color field; 64×64 = 4096 chars
- Amiga Workbench AppIcons + WindowMaker dock applets as UX model
- amos-term.* zenka: renders the pixel buffer natively in terminal
  combines with vterm.compositor for overlay modes
- relates to: amos-term zenka, vterm.compositor, protocol-7-menu, reasoning.branch.status
- design doc: planned (data/md/development/TASK-BUFFER-PIXEL-MONITOR.md)

### LLM session management + cross-model context
- kimi-cli sessions store hundreds of MB of reasoning in context.jsonl
- segment categories: code_read / hypothesis / dead_end / reasoning /
  conclusion / plan / insight — differential compaction per type
- seed sentence (template 4) as compression unit for reasoning chains
- browser views host remote models (claude.ai, qwen web) — same interface
- design doc: data/md/development/LLM-SESSION-MANAGEMENT.md
- task: data/tasks/kimi-web-session-cache-access.md
