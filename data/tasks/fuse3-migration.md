## task: migrate data.mount.fuse.* from Fuse to Filesys::Fuse3

### context

the `Fuse` CPAN module requires FUSE2, which was dropped from debian repos
(`libfuse-perl` no longer exists). modern debian only ships FUSE3 headers.

`Filesys::Fuse3` (v0.02, cpanm only — not in apt repos) provides Perl bindings
for FUSE3 and should be used as the replacement.

current setup:
- 7 modules: `data.mount.fuse.*` (getattr, init_code, open, read, readdir, release, spawn, statfs)
- `amos-term.fuse.*` also references fuse constants and callbacks
- main entry point: `data.mount.fuse.spawn` — calls `Fuse::main(@mount_opts)` with
  a named-key option hash (getattr, readdir, read, open, release, statfs, debug, threaded, etc.)
- module loading is on-demand via `<[base.perlmod.autoload]>->('Fuse')`
- soft-fail if module unavailable (eval + graceful error return)

### what to do

1. **read the `Filesys::Fuse3` documentation** — `ncpan readme Filesys::Fuse3`
   understand the API: how to register callbacks, how the main loop is started,
   what the callback signatures look like vs the old `Fuse::main` approach.

2. **compare callback signatures** — the old `Fuse` module uses specific return
   value conventions. check if `Filesys::Fuse3` uses the same POSIX errno returns
   or a different interface. document any differences found.

3. **update `data.mount.fuse.spawn`**:
   - change `<[base.perlmod.autoload]>->('Fuse')` to load `Filesys::Fuse3`
   - replace `Fuse::main(@mount_opts)` with the Fuse3 equivalent
   - keep the soft-fail pattern (eval + error log) — just update module name in messages

4. **update callback modules** if `Filesys::Fuse3` has different return conventions:
   - `data.mount.fuse.getattr` — returns list: (errno, mode, nlink, uid, gid, rdev, size, ...)
   - `data.mount.fuse.readdir` — returns list of filenames
   - `data.mount.fuse.read` — returns (errno, data)
   - `data.mount.fuse.open` / `release` / `statfs` — check return formats

5. **update `modules/base.known_dependencies`**:
   replace the `Fuse` entry:
   ```perl
   'Fuse' => {
       'debian'        => [],    ## libfuse-perl dropped; build fuse2 from source first ##
       'cpan_fallback' => 'Fuse'
   },
   ```
   with:
   ```perl
   'Filesys::Fuse3' => {
       'debian'        => [],    ## not in apt repos — cpanm only ##
       'cpan_fallback' => 'Filesys::Fuse3'
   },
   ```
   and remove the `Fuse` entry entirely.

6. **update `.deps/profiles.yaml`** — replace `- Fuse` with `- Filesys::Fuse3`
   under the `cpan:` block. remove the `install_fuse2.sh` reference if Fuse3
   headers (`libfuse3-dev`) are already available on the system.

7. **check `amos-term.fuse.*` modules** — these use `<data.fuse.const.MODE_DIR>`,
   `<data.fuse.const.S_IFREG>`, etc. verify these constants are still correct for
   Fuse3 or if they need updating.

### notes

- `Filesys::Fuse3` is v0.02 — very new, minimal docs, check CPAN source carefully
- the system likely already has `libfuse3-dev` (apt) — verify before requiring a build step
- keep the soft-fail pattern in `data.mount.fuse.init_code` and `spawn` — fuse is optional
- signatures note: do not modify the 4-line checksum footer at end of module files —
  those are added by the signing system. write clean module bodies only.
- module file format: starts with `## [:< ##` header block, no `sub {}` wrappers,
  module name = filename, invoked as `<[module.name]>->()`

#,,,,,,.,,,,,,,,,,..,,.,.,,..,,,,,.,.,,..,,,,,..,,...,...,,.,,..,,..,,,,.,,..,
#54SUXMEYWFYOEAWU65KYHJEWCP42YSX3UWGUPHQKTX77VEM3BVQAOCRNPYYQ3VDLPMMZRGG6N6TUO
#\\\|YAU3E6BK5D6LFQEP2Q4LS4VUU5YU3EUZ3HT6XWIWA2CGGQKXQ5U \ / AMOS7 \ YOURUM ::
#\[7]T3OXWE2QM4SSZQSS3CBH5M4MJ43PGH57QY4ARQ7GYC2ABUH7D2CI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
