# task: proxy zenka — fix boot-blocking compile/init errors

## dispatch
read `data/md/development/CREDENTIAL-FABRIC-WIRING-FINDINGS.md` first —
specifically section "additional findings" item **a** (proxy startup
errors) and open-issues table rows **#1, #5, #13, #14**. that doc is a
manual verification report against the landed credential-fabric wiring
(commit `21f4edfa5`); it found that the `proxy` zenka currently cannot
finish init. this task fixes those four boot-blockers — read-write,
not read-only (the findings doc was a read-only verification pass;
fixes land here).

## problem — four independent issues, all confirmed live
1. **syntax error in `modules/proxy.handler.accept` line 6:**
   ```perl
   my $listen_sock = shift->w->data // $proxy . listen_sock;
   ```
   `$proxy` is an undeclared bareword → compile-time failure
   (`Global symbol '$proxy' requires explicit package name`). the
   loader marks the module "1 broken" and continues, so the accept
   handler never actually runs and the listening socket stays
   non-functional. fix: `shift->w->data` is always set by
   `proxy.listen`, so the `// $proxy . listen_sock` fallback is dead
   weight — remove it, or replace with `// $data{'proxy'}{'listen_sock'}`
   if you determine the fallback is genuinely needed. prefer removing it.

2. **`modules/proxy.selector.load` dies on undef deref at line 9:**
   ```perl
   my $yaml_str = <[file.slurp]>->($config_path)->$* // '';
   ```
   when the zenka's cwd isn't the project root, `<[file.slurp]>`
   returns `undef` and `undef->$*` throws `'undefined value as SCALAR
   reference'`. the target file
   (`data/yaml/web-proxy/template-selector.yaml`) does exist — this is
   purely a path-resolution / cwd issue. look at lines 6-9: there's
   already a `<system.root_path>`-based fallback path nearby that
   would be cwd-safe. either make `<proxy.cfg.selector_config>`
   resolve to an absolute path (e.g. set it via `<system.root_path>`
   in `cfg/zenki/proxy/start`), or guard the dereference so
   it falls back instead of dying on undef.

3. **`httpd.status_codes` reported "subroutine ... not defined" during
   `proxy.init_code`:**
   ```
   :. cr.,.ic : 'protocol-7 subroutine httpd.status_codes not defined
   :. cr.,.ic : module 'proxy'-init not successful [ init_code != [0|5] ]
   ```
   `httpd.status_codes` IS listed in `cfg/zenki/proxy/start`
   under `modules.load` — but as the *last* entry, after `proxy`
   itself. `proxy.init_code` (line ~14) calls `<[httpd.status_codes]>`
   to populate `<protocol.http.status_codes>` — and that call appears
   to run before `httpd.status_codes` finishes loading. most likely a
   pure load-order problem: move `httpd.status_codes` earlier in the
   `modules.load` list (before `proxy`), reload, and confirm the error
   is gone from the relay log. if reordering does NOT fix it, trace
   `base.load_modules` → `init_modules` sequencing to find the actual
   cause — don't just leave it reordered-but-unverified.

4. **no `max_concurrency` gate in `cfg/zenki/proxy/
   zenka-startup.v7`:** during verification, `proxy` briefly ran as 3
   simultaneous instances. since proxy binds a fixed listening address
   (`127.0.0.1:8118`), concurrent instances race on bind rather than
   share load — actively harmful. compare
   `cfg/zenki/acquire/zenka-startup.v7`, which sets
   `max_concurrency = 1` (a real working gate, checked in
   `v7.zenka.cmd.start` / `v7.zenka.cmd.restart` against
   `v7.start_count`). add the same key to proxy's startup config.

## constraints
- fixes only — do not refactor surrounding code, do not touch
  signatures, lowercase comments / `[ word ]` bracket annotations if
  you add any
- after each fix, if you can exercise the live system (the zenka is
  on-demand — a routed command or `p7c v7.restart proxy` after
  `p7c v7.reload` / `p7c reload` will pick up reloaded modules),
  confirm the specific error is gone from the relay/zenka log before
  moving to the next item — these four issues compound each other
  during boot, so fixing #1 may be required before #3's symptom even
  becomes visible again
- if you cannot exercise the live system, say so plainly in your
  summary and note which fixes are unverified

## acceptance
- all four fixes landed, each verified against a fresh `proxy` boot
  attempt where possible (relay/zenka log shows none of the four
  errors), or explicitly marked unverified with the reason why
- `proxy` reaches `proxy.listen` and binds `127.0.0.1:8118` without
  the `$proxy`-bareword or `httpd.status_codes` errors

## signatures note
do not add the `#,,..` stub to any new file — the signing system
writes it.

#,,,,,.,,,.,.,.,.,,..,.,,,,,,,..,,,,.,...,.,,,..,,...,...,,..,,,.,.,.,,,.,...,
#6K46EFBPA3V6ZLHQKKQQHPEJEZVIL23PMSIPJZI7PBZ37LK2DRAE6QPXJ7LMWPSJVZ2B6OVNOJLLK
#\\\|NTAG2KYF7JQCWHYTUEIPZ6Y4Z2UQ2LI7TIWKS5PDY3ATFXYMGI4 \ / AMOS7 \ YOURUM ::
#\[7]XJREFM542AZ4JPF4KYVGYYGWF3YBVQYEDQF3RFSMBMHBMBTOSUDQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
