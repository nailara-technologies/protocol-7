# Auto-install : the layered dependency-completion model

Design reference for how protocol-7 completes missing dependencies —
written after the 2026-10-27 azurum incident, where a missing
`Digest::BMW` killed the system at *compile* time, before any
install layer could run. The layers exist in the tree; this document
names them, their gates, and the invariants between them.

## The layers

**Layer 0 — compile-time resilience** [ `AMOS7::INLINE`, `AMOS7::B32`,
`bin/Protocol-7` truth-check site ]. Soft requires + pure-perl/core
fallbacks: the system always *compiles and starts*, degraded but
deterministic. `AMOS7::B32` is byte-identical to `Crypt::Misc`, so
fallback output keeps the same format; `Digest::SHA` stands in for
`Digest::BMW` with stable, per-host-deterministic names. **Invariant:
nothing below may die at compile time.** Every layer above depends on
this one being reached.

**Layer 1 — bootstrap sync install** [ `src/v7-zenki.pre_init` ].
Root + host opt-in `v7-zenki.cfg.auto_install_deps`. Runs before the
event loop exists, so synchronous apt/cpanm is acceptable — nothing
else could run yet anyway. Sets `<base.perlmod.auto_install> = TRUE`
for the duration of startup; `v7-zenki.post_init` restores it.

**Layer 2 — load-time install** [ `src/base.perlmod.autoload`,
`src/base.perlmod.load` → `src/base.perlmod.install` ]. Per-module at
require time. Every install is recorded to
`var/sys-deps/tracked.yaml` — the strategic record of what actually
happened, which keeps later layers informed instead of blind.

**Layer 3 — async runtime install** [ `sys_deps` conditions :
`src/v7-zenki.resolve.object.sys_deps`,
`src/v7-zenki.callback.object.sys_deps` ]. Event-loop-friendly,
per-zenka declared deps, after startup. Never blocks the loop; routes
through the debian zenka.

**Layer 4 — proactive completeness** [ `bin/p7-deps install`,
profiles, `src/base.known_dependencies` ]. The goal is that layers
1–3 *never fire*. Resolution order: debian package → local `pm-src`
build → cpanm — cheap, offline-capable, no XS toolchain on fresh
hosts where a mapping exists.

## The on-demand digest site

`p7_ensure_bmw_digest()` [ `bin/Protocol-7` ] closes the last
un-strategic dependency in the core path. The embedded-subroutine
loader and `p7_generate_subroutine_checksum` verify BMW chksums; when
`Digest::BMW` is absent they ask for an install **with the same policy
as layer 1** — root + the `auto_install` flag — routed through
`base.perlmod.install` so the debian → pm-src → cpanm order and the
`tracked.yaml` record apply. Without the gate, they fall through to
the layer-0 SHA-256 names. No site may assume a module is loaded
because of another site's compile-time side effects — that was the
azurum root cause: the old `use AMOS7::Assert::Truth` happened to load
`Digest::BMW`, and the loader silently relied on it.

## Policy invariants

1. Compile never dies for a missing optional module [ layer 0 ].
2. Runtime install needs root AND the host opt-in
   [ `v7-zenki.cfg.auto_install_deps` ; the `auto_install` flag is its
   runtime mirror ].
3. Installs are recorded [ `var/sys-deps/tracked.yaml` ].
4. Resolution order : debian → pm-src → cpanm → cpan.
5. Every dependency site is correct in isolation — no load-order
   assumptions, no fully-qualified calls to maybe-unloaded modules.
6. Degraded output stays deterministic: fallback names differ from
   native ones only where the missing primitive forces it, never in
   encoding.

#,,,.,.,,,.,,,,,.,,,,,,..,,.,,..,,.,,,,..,,,.,..,,...,...,.,,,,,,,,,.,,..,,,.,
#ASM6MYWQSZ3L3FY3JTISLERLHQIHVPG2SOEL7CPFDUNEYB3WWYKQ4OY7MHXFCT26TPXWX5X44KOWS
#\\\|DDACPEC5MICN7USZRVCOSMXAVGOQHLKOKDEGWN7LYH7Y33HYZFE \ / AMOS7 \ YOURUM ::
#\[7]HVB22UZJOJZSEMP5DTL6GQFETPTQUGARAJUMV7FS7TR6RTGLM6CA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
