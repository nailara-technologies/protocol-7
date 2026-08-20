# ASCII Frame Template System Wiring Survey
## Protocol-7 codebase — what exists / what's missing for memory zenka integration

**Date:** 2026-06-02
**Scope:** context pipeline, terminal backend, ascii frame engine, nshell integration, vterm/color vision docs

---

## A. Pipeline Map

### Existing chain (verified from code)

```
[data/ai-mem/claude/*.md]
         │
         ▼
[context.memory.load] ──► returns flat markdown string
         │                    (budget-truncated, "## basename\ncontent\n")
         │
[data/yaml/context-templates/*.yaml]
         │
         ▼
[context.template.load] ──► parses YAML template with `sections` array
         │
         ▼
[context.template.render] ──► iterates sections, calls providers by name
         │
         ▼
[context.template.resolve] ──► recursive resolver with `when`, `include`,
         │                        `static`, `summarize` (stub), `provider`
         │
         ▼
[context.provider.frame] ──► loads frame YAML, picks mode,
         │                      calls ascii.frame.render, applies double border,
         │                      budget truncation, optional color pass
         │
         ▼
[ascii.frame.load] ──► reads data/yaml/ascii-frames/$name.yaml,
         │                calls parse + validate, caches entry
         │
         ▼
[ascii.frame.render] ──► returns plain ASCII string
         │
         ▼
[ascii.frame.render.color] ──► injects ANSI codes via heuristic char-class
         │
         ▼
[nshell.handler.command_reply] ──► prints to STDOUT with %colors hash
         │                            (direct `print STDOUT`, no vterm layer)
         ▼
Terminal
```

### Where the chain breaks for the memory zenka use case

| Gap | Location | Details |
|-----|----------|---------|
| **1. Memory data is flat, not slotted** | `context.memory.load` | Returns a single markdown string. There is **no parser** that turns `data/ai-mem/claude/*.md` into structured slot values (`ROLE`, `FOCUS`, `FACT`, `WHY`, `TASKS`, etc.) that `ascii.frame.slot.bind` expects. |
| **2. No progress-mode driver** | missing module | `memory-composite.yaml` defines `progress` and `expanded` modes, but nothing animates the progress mode (`\r` loop updating `PROGRESS`/`STATUS` slots). `cfg/ascii-frame` documents `[modes]` flags (`border.only`, `animate`) but **no module references them**. |
| **3. No composed-frame assembler for memory** | missing module | `memory-composite.yaml` has block slots (`PROFILE`, `FEEDBACK`, `PROJECT`, `TASKS`) meant to contain rendered sub-frames. Nothing loads `user-profile.yaml`, `feedback.yaml`, etc., renders each, and composes them into the composite via `ascii.frame.compose`. |
| **4. Terminal backend does not ingest frame output** | `amos-term.render.draw_buffer` | The amos-term voxel renderer draws 3D grids and cursors but **never unpacks SHM buffers to display characters**. All current terminal output in nshell bypasses amos-term and writes directly to `STDOUT`. A frame-rendered string would need to go through `nshell.handler.command_reply` or a new output path. |
| **5. No memory zenka entry point** | missing module | There is no `src/memory.*` or `src/memory-zenka.init_code`. The closest existing module is `context.memory.load`, which is a provider, not a zenka. |

---

## B. ascii.frame.* Completeness

All **10 modules are implemented and functional** for basic use. No explicit `TODO`/`FIXME` stubs exist in the source. However, several features are parsed/validated but **not consumed by renderers**:

| Module | Status | Issues |
|--------|--------|--------|
| `ascii.frame.parse` | ✅ Complete | Extracts `corners` (lines 220–225) and `border_style` from YAML; both are validated but later ignored by renderers. |
| `ascii.frame.validate` | ✅ Complete | 7 check categories; classifies errors into `topology`/`syntax`/`reference`/`structural`. |
| `ascii.frame.from_mockup` | ✅ Complete | Convenience wrapper with strict/escalate logic. |
| `ascii.frame.load` | ✅ Complete | Caches entries; supports single-mode (`mockup:`) and multi-mode (`mockup_progress:`/`mockup_expanded:`). Only `memory-composite.yaml` exercises multi-mode. **YAML `slots` metadata is NOT merged into the descriptor** — callers must look at both `$entry->{slots}` (metadata) and `$entry->{descriptor}{slots}` (geometry). |
| `ascii.frame.render` | ✅ Functional | Width computation duplicated identically in `render.data` and `render.html` (lines 23–77). `corners` key is never read — corners are derived from border element arrays. `border_style` is never consulted. Composed inner frames are padded/truncated correctly. |
| `ascii.frame.render.color` | ✅ Functional | Heuristic char-class coloring (border vs content). Loads `cfg/ascii-frame`. `progress = p7_fg_0003` is documented in config but **no special progress-slot logic exists**. |
| `ascii.frame.render.data` | ✅ Functional | Returns structured hashref. Makes recursive calls to both `ascii.frame.render` (for string) and itself (for data). |
| `ascii.frame.render.html` | ✅ Functional | Emits CSS-classed HTML. **Composed inner frames become independent nested `<div>` blocks** without width reconciliation or outer-border wrapping — diverges semantically from ASCII renderer. |
| `ascii.frame.slot.bind` | ✅ Complete | Binds a `SCALAR` ref to a slot; renderer derefs at render time. |
| `ascii.frame.compose` | ✅ Functional | Nests inner frame into outer slot. Uses inner `min_width`, not actual rendered width, so outer sizing may be too small if content exceeds `min_width`. |

### Key gap: `border_style: double`

- `ascii.frame.load` sets `$desc->{border_style} = 'double'` (line 69 of load module).
- **None of the three renderers (`render`, `render.data`, `render.html`) consult this key.**
- `context.provider.frame` **does** implement double-border expansion as a post-processing step (lines 80–99): it replaces `^:` and `:$` with `::` on content lines after rendering.
- This means double-border is handled at the **provider level**, not the **engine level** — a design inconsistency.

---

## C. Multi-Frontend Readiness

### Four renderer variants

| Variant | Output | Input | Status |
|---------|--------|-------|--------|
| `ascii.frame.render` | Plain ASCII string | descriptor + values | ✅ Functional |
| `ascii.frame.render.color` | ANSI-colored string | already-rendered ASCII string | ✅ Functional (heuristic post-processor) |
| `ascii.frame.render.html` | HTML with CSS classes | descriptor + values + optional inline_style | ✅ Functional (semantic divergence on composed frames) |
| `ascii.frame.render.data` | Structured hashref | descriptor + values | ✅ Functional (programmatic layout analysis) |

### What a GTK3 renderer would need

There is **no GTK3 renderer** today. To build one, the recommended path is:

1. **Consume `ascii.frame.render.data`** — it already produces a traversable tree:
   ```perl
   {
     type => 'p7_frame', width => N, height => N,
     border => { top => ..., bottom => ..., left => ..., right => ... },
     rows => [ { row => N, type => 'field'|'block'|'composed'|'static',
                 slot => $name, prefix => ..., value => ..., width => ... }, ... ],
     composed => { ... }   # recursive structured data
   }
   ```
2. **Map to GTK3 widgets:**
   - A `Gtk3::TextView` with a `Gtk3::TextBuffer` and named `Gtk3::TextTag`s for colors.
   - Or a `Gtk3::DrawingArea` with Pango layout for precise monospace grid rendering.
3. **Missing bridge:** a module that takes the `render.data` output and emits GTK3 widget code or Pango markup. This does not exist.

### Consistency note

The three string renderers (`render`, `render.color`, `render.html`) do **not** share a common width-calculation routine. Width logic is copy-pasted across all three. A shared `ascii.frame.calculate_width` helper would benefit all frontends.

---

## D. Memory Zenka Minimal Wiring

To create a working memory zenka that starts with progress-mode animation, loads memory files, renders each section via its frame, and outputs the expanded composite to the terminal, the following **new src/config** are required:

### New modules needed (concrete names + purpose)

| # | Module | What it does |
|---|--------|--------------|
| 1 | `memory.init_code` | Zenka bootstrap: set up state, register buffers, load frame cache. |
| 2 | `memory.load.structured` | **Replace `context.memory.load`'s flat output.** Read `data/ai-mem/$zenka/*.md`, parse each file into structured slot values (e.g., extract `ROLE`, `FOCUS`, `LEVEL` from `MEMORY.md` or `user-profile.md`; extract feedback entries into `RULE`/`WHY`/`APPLY`). Returns a hashref suitable for `ascii.frame.slot.bind`. |
| 3 | `memory.render.progress` | Drive the progress-mode animation loop: repeatedly render `memory-composite` in `progress` mode with updating `PROGRESS` and `STATUS` slots, printing `\r` to the same terminal line. Commit with `\n` when `STATUS eq 'ready'`. |
| 4 | `memory.composite.build` | Orchestrator: load `memory-composite` (expanded mode), load sub-frames (`user-profile`, `feedback`, `project`, `task-queue`), render each sub-frame with its slot values, use `ascii.frame.compose` to nest each into the composite's block slots. |
| 5 | `memory.render.output` | Take the final rendered string from `context.provider.frame` (with `color => 1`) and emit it to the terminal. **Short term:** direct `print STDOUT` (same path as `nshell.handler.command_reply`). **Long term:** write to the amos-term SHM buffer so the voxel renderer can display it. |
| 6 | `memory.handler.transition` | State machine: `loading` → `progress` → `expanded`. Calls `memory.render.progress`, then `memory.composite.build`, then `memory.render.output`. |

### Existing modules that can be reused as-is

- `ascii.frame.load`, `ascii.frame.render`, `ascii.frame.render.color`, `ascii.frame.compose`, `ascii.frame.slot.bind`
- `context.provider.frame` (with `mode => 'expanded'`, `color => 1`)
- `context.template.load/render/resolve` (if the memory zenka is driven by a context template)
- `nshell.handler.command_reply` (for STDOUT output path)

### Config gaps

- `data/yaml/ascii-frames/` has no `memory-composite` sub-frame content spec. The YAML `slots` section documents intent (`descr`, `mockup`) but there is no automated mapping from `data/ai-mem/claude/*.md` file contents to slot values.
- `cfg/ascii-frame` `[modes]` section is dead code; either remove it or wire `memory.render.progress` to read it.

---

## E. context.memory.load Integration

### What it does today

`src/context.memory.load` (96 lines):

- Expects `$params->{zenka}`, `$params->{topics}`, `$params->{budget}`.
- Resolves `data/ai-mem/$zenka/` directory (falls back to first subdirectory if `zenka` not found).
- Finds `*.md` files, optionally filtered by topic keywords.
- Sorts by file size (smaller first).
- Reads each file via `<[file.slurp]>`, strips signature blocks (line 67 regex), and concatenates into a flat string:
  ```
  ## ai-mem [ data/ai-mem/claude ] ##
  ### filename.md
  <content>
  ### filename2.md
  <content>
  ```
- Budget-aware: truncates when `used + section_len > char_budget`.

### What it returns

**A single plain-text string.** Not a hashref, not structured slot data.

### Can it feed `ascii.frame.slot.bind`?

**No — not directly.** `ascii.frame.slot.bind` expects:
- a descriptor hashref,
- a slot name,
- a `SCALAR` reference (or the renderer expects values in `$params->{values}`).

`context.memory.load` returns flat markdown. A **new intermediate parser** (`memory.load.structured` or similar) must:
1. Split the markdown into sections by file/heading.
2. Extract key/value pairs (e.g., from `## CRITICAL` bullets, `## Active Topics` links, `## Vision / Design` items).
3. Map them to frame slot names (`ROLE`, `FOCUS`, `LEVEL`, `RULE`, `WHY`, `APPLY`, `FACT`, `AGE`, `TASKS`, `SUMMARY`).

### Verified file formats in `data/ai-mem/`

- `claude/MEMORY.md` — markdown with `## CRITICAL`, `## Active Topics`, `## Vision / Design` headings.
- `claude/feedback-*.md` — short feedback entries, often with `rule:`, `why:`, `apply:` pseudo-structure.
- `claude/topic-*.md` — topic notes with free-form markdown.
- `kimi/MEMORY.md` — similar structure.

None of these are YAML or follow a strict schema. A regex/heuristic parser is required.

---

## F. Recommended First Step

> **Write the smallest possible end-to-end demo that proves the frame pipeline works for one memory section.**

### Concrete 5-minute wiring

Create a temporary test module (e.g., `src/memory.render.profile`) that does exactly this:

```perl
## 1. load the user-profile frame
my $entry = <[ascii.frame.load]>->('user-profile');
my $descriptor = $entry->{'descriptor'};

## 2. bind hardcoded test values (no parser yet)
my $values = {
    ROLE  => 'architecture-research',
    FOCUS => 'ascii-frame wiring survey',
    LEVEL => 'deep-dive',
};

## 3. render to ASCII string
my $ascii = <[ascii.frame.render]>->(
    { descriptor => $descriptor, values => $values }
);

## 4. colorize
my $colored = <[ascii.frame.render.color]>->($ascii);

## 5. print to terminal
print STDOUT "\n$colored\n";
```

### Why this is the right first step

- It exercises `ascii.frame.load` → `render` → `render.color` → STDOUT without any new infrastructure.
- It validates that the frame definitions in `data/yaml/ascii-frames/user-profile.yaml` render correctly.
- It proves the terminal output path (nshell/STDOUT) can display colorized frames.
- It requires **zero new modules** — just a throwaway test script or a single new module.
- Once this works, the next increment is:
  1. Replace hardcoded values with a parser that reads `data/ai-mem/claude/MEMORY.md`.
  2. Add `memory-composite` with `ascii.frame.compose` to nest the profile frame.
  3. Add the `progress` animation loop.

### What to verify after writing it

1. Does `user-profile.yaml` render with correct alignment and borders?
2. Does `render.color` inject ANSI codes that look correct in the terminal?
3. Are there any encoding issues with the border characters (UTF-8 vs ASCII)?

---

## Summary Table: Exists vs Missing

| Component | Status | Evidence |
|-----------|--------|----------|
| Frame parser (`ascii.frame.parse`) | ✅ Exists | `src/ascii.frame.parse` |
| Frame validator (`ascii.frame.validate`) | ✅ Exists | `src/ascii.frame.validate` |
| Frame loader (`ascii.frame.load`) | ✅ Exists | `src/ascii.frame.load` |
| ASCII renderer (`ascii.frame.render`) | ✅ Exists | `src/ascii.frame.render` |
| ANSI color post-processor (`ascii.frame.render.color`) | ✅ Exists | `src/ascii.frame.render.color` |
| HTML renderer (`ascii.frame.render.html`) | ✅ Exists | `src/ascii.frame.render.html` |
| Data renderer (`ascii.frame.render.data`) | ✅ Exists | `src/ascii.frame.render.data` |
| Slot binder (`ascii.frame.slot.bind`) | ✅ Exists | `src/ascii.frame.slot.bind` |
| Frame composer (`ascii.frame.compose`) | ✅ Exists | `src/ascii.frame.compose` |
| Context provider bridge (`context.provider.frame`) | ✅ Exists | `src/context.provider.frame` |
| Context template resolver | ✅ Exists | `src/context.template.load/render/resolve` |
| Memory file loader (flat) | ✅ Exists | `src/context.memory.load` |
| Terminal output (nshell STDOUT) | ✅ Exists | `src/nshell.handler.command_reply` |
| **Structured memory parser** | ❌ Missing | No module turns `*.md` into slot hashrefs |
| **Progress-mode animator** | ❌ Missing | No module drives `\r` loop with `memory-composite` progress mode |
| **Composite assembler** | ❌ Missing | No module loads sub-frames and composes them into `memory-composite` |
| **Memory zenka bootstrap** | ❌ Missing | No `memory.init_code` or `memory.*` zenka modules |
| **GTK3 renderer** | ❌ Missing | No `ascii.frame.render.gtk3` or equivalent |
| **Border-style in engine** | ⚠️ Partial | Parsed in `load`, applied in `context.provider.frame`, ignored in `ascii.frame.render` |
| **Modes config wiring** | ⚠️ Dead code | `cfg/ascii-frame [modes]` is not read by any module |

#,,..,...,...,..,,,.,,.,.,...,.,.,,.,,...,.,.,..,,...,...,...,,..,...,.,.,,,.,
#O7GRB7SR2BCA64VAJ6ZIWUAR24D7V7UHWDBLZBS2RNB3HZD4DE6TNQBLRYMAU2WKS7WG6MBQI7436
#\\\|X5N3VGCEZRQWYCHSY2J33ZFULWM774H7QK5ZCN2IDXKE323GZN2 \ / AMOS7 \ YOURUM ::
#\[7]YMESFEJ5YZ5JEDLSEQ5P355ITXKHHEMZFTUMI3QBQWSWUG3I3IDQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
