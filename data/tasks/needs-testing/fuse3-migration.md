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

5. ~~**update `src/base.known_dependencies`**~~ — **DONE** (session 48):
   `Fuse` entry removed; `Filesys::Fuse3` added with `debian => ['libfuse3-dev']`,
   `cpan => 'Filesys::Fuse3'`.

6. ~~**update `.deps/profiles.yaml`**~~ — **DONE** (session 48):
   `- Fuse` replaced with `- Filesys::Fuse3`; `install_fuse2.sh` pre_install removed.
   `bin/dependencies/install_minimal_dependencies.debian.sh` also updated.

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

#,,..,,,,,.,.,.,,,,..,,,,,.,.,.,.,,,,,...,..,,..,,...,...,.,.,...,,.,,,,,,...,
#JNPLXMDHMEUOAEXKRK5CA4VPT7YVHC4MVX2RIHX4AP2GGLKC5LLPSBZD6CCXPEZK6H7MBP7XVXWDO
#\\\|6D3H2XKXUYW7UNG4IRQJJUUWLVYQEZ73SFGSDMKAQNXU2QRZRQE \ / AMOS7 \ YOURUM ::
#\[7]Z2NNHE7BLLQ5MKPPZNB4WUSZRXBGZPNKSGAUQ34K2KWHHAZ2S6AI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
