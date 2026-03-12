## protocol-7 development roadmap ##

working list of planned initiatives — update as priorities shift or items complete.
items are loosely ordered by dependency, not strict priority.

---

### stability and infrastructure

- [ ] **httpsd crash capture** — request capturing infrastructure to diagnose
      and fix httpsd crashes; log in-flight request state on fault

- [ ] **nshell history + ctrl+o** — repair readline history persistence and
      ctrl+o (operate-and-get-next) handling in interactive shell

- [ ] **dependency auto-installation** — upgrade debian/apt infrastructure for
      automatic dependency resolution; extend to other distros

- [ ] **initial configuration / setup** — implement planned first-run setup
      infrastructure for new protocol-7 deployments

---

### terminal buffer and session attachment

- [ ] **terminal buffer completion** — complete decoder terminal buffer until
      real shell sessions can be attached; socat bridge for local shell,
      nshell, and windows powershell sessions

- [ ] **decoder show-accumulator** — module for inspecting level-5/level-6
      accumulator state and vterm surface (already access-listed)

- [ ] **vterm screen readback** — show-vterm / damage query command to expose
      what has landed on the 25×80 surface

- [ ] **INDEXCUBE query** — command to inspect traversal log depth and entries

- [ ] **per-stream level-5 accumulator isolation** — currently all streams
      share one accumulator; isolate state per stream_id so concurrent
      streams don't interleave bits

- [ ] **passive prefix detection table as code** — the ANSI/Hayes/JJFE prefix
      table documented in the architecture (section 8) should become a live
      lookup module in the decoder, not just documentation

- [ ] **reduce-entropy result store** — job fingerprints are returned once then
      lost; a result registry keyed by stream_id + boundary_n would allow
      querying and comparing previous reduction runs

---

### multi-model collaboration

- [ ] **channels + models chat upgrade** — wire claude, kimi, and local models
      into shared conversation infrastructure; inter-model task delegation

- [ ] **coding LLM filesystem-independent edits** — upgrade local and coding
      LLM infrastructure to edit protocol-7 files without filesystem coupling

---

### indexcube and storage

- [ ] **indexcube filesystem mapping** — map indexcube regions to filesystem
      paths; foundation for network mounting

- [ ] **indexcube network mount** — expose mapped indexcube regions over
      protocol-7 network (builds on filesystem mapping)

- [ ] **difference-based native disk storage** — protocol-7 native format for
      storing repository files as delta/diff sequences rather than full copies

- [ ] **in-memory filesystem implementation** — filesystem-like layer over
      protocol-7 repository files held in memory; basis for lazy loading

---

### cryptographic infrastructure

- [ ] **in-zenka cryptographic upgrade** — upgrade per-zenka crypto similar to
      new task directory key structure; scoped identity and signing per zenka

---

### decoder and harmonic analysis

- [ ] **display-D13-collection as decoder command** — expose the
      bin/dev/display-D13-collection reduction tool as a live zenka command
      feeding from the current accumulator or a named buffer

- [ ] **harmony -n as decoder command** — pure /13 chain without left shifts,
      currently only in bin/dev; wire as decoder.cmd.harmony for live use
      on arbitrary input or accumulated values

- [ ] **deduplication tree initial implementation** — reference-counted node
      tree rooted by most-frequent smallest elements; first real code step
      of the architecture described in section 16

---

### code architecture

- [ ] **function call and dependency tracing** — infrastructure to trace
      protocol-7 module calls and map dependencies at runtime

- [ ] **lazy loading + deferred compilation** — implement after tracing
      infrastructure is in place; load modules on first use

- [ ] **single-script and perl module export** — export protocol-7 code with
      full dependency resolution to standalone script or .pm with no runtime
      dependency on the protocol-7 loader

- [ ] **module signature verification on load** — detect tampered or unsigned
      modules at load time using the AMOS7 footer; currently signatures are
      written but not checked during module loading

- [ ] **pre-commit descr/param length check** — automated hook to catch
      header lines exceeding table width before they accumulate again

- [ ] **static dependency graph tool** — analyse all `<[module.name]>->()`
      call sites to build a static dependency map; prerequisite for safe
      lazy loading and export

---

### completed (recent)

- [x] decoder phase 3 — passive boundary detection, level-6 D3, vterm 25×80
- [x] decoder async job system — reduce-entropy with idle-event pattern
- [x] harmonic transit vision architecture — 17 sections documented
- [x] models registry consolidation
- [x] coding zenka async inference spawning
- [x] zulum→decoder entropy wiring
- [x] kimi-web websocket client zenka

#,,..,..,,,..,..,,..,,,,.,.,,,,,,,,,,,,..,,,.,..,,...,...,,..,...,.,.,.,.,...,
#2SRVEGDPOCAEIXUDIQCQQMCSDBPB5QCQRNWERJFEACV7LPWMV6G3L23EJ3DJEH6ZCE7XS6PXHOMKW
#\\\|G4CJHTSNL3TBT2OP4D4FVQDHJGWS4AAABAHZT5DIJSJDBBHEPH7 \ / AMOS7 \ YOURUM ::
#\[7]KRMIMJFR5XF6CS6XY7ETZYFQOKW4K44D3MKX6LLSAXZXZLQUVECY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
