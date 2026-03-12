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

### code architecture

- [ ] **function call and dependency tracing** — infrastructure to trace
      protocol-7 module calls and map dependencies at runtime

- [ ] **lazy loading + deferred compilation** — implement after tracing
      infrastructure is in place; load modules on first use

- [ ] **single-script and perl module export** — export protocol-7 code with
      full dependency resolution to standalone script or .pm with no runtime
      dependency on the protocol-7 loader

---

### completed (recent)

- [x] decoder phase 3 — passive boundary detection, level-6 D3, vterm 25×80
- [x] decoder async job system — reduce-entropy with idle-event pattern
- [x] harmonic transit vision architecture — 17 sections documented
- [x] models registry consolidation
- [x] coding zenka async inference spawning
- [x] zulum→decoder entropy wiring
- [x] kimi-web websocket client zenka

#,,,,,,.,,,..,...,..,,.,,,,,,,,,.,,.,,..,,...,..,,...,...,,..,...,...,.,,,,,.,
#JUWVCYAGHUFQED42UTQWTD5ZFAWTRGMON5OYD736UUZ2HP3QZ3LNV7FC7MGDNNU2QFAA2VZB4I5BQ
#\\\|JEXBSBZZ5R47RHJWAMOLL7LN3V5HVEV3ZGC6DT2SVUNNBYBK4OY \ / AMOS7 \ YOURUM ::
#\[7]5R7AE7SX5V5JK5EBNHRRR6YQUKWQBZCLPAROHYLQV5WVMU6KZODI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
