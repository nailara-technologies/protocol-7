---
name: topic-os-command-zenka
description: planned os-command zenka — network-accessible command/script templates with security levels, async process structure, STDIO streaming, vterm result buffers
metadata:
  node_type: memory
  type: project
  originSessionId: 9ecacc19-6948-4beb-892e-5af7d7d24068
---

idea captured 2026-06-11, right after [[topic-ui-show-security-levels]]
(steps 1-3 landed as `d3f4e5aca`): an **os-command zenka** as one of the
first real consumers of the `ui.caller.security-level` /
`ui.fields.fallback` mechanism, beyond `ui-show` itself.

## the idea

a zenka that:
- holds command and script **templates** (parameterised, like
  `dispatch-create-template.md` / `dispatch-template-param.md` already
  do for LLM dispatch, but for OS commands/scripts)
- makes calling them **network-accessible** via the normal
  zenka-routing mechanism
- gates each template by **security level** (reusing
  `ui.caller.security-level` / the `access.security-level.usr.<group>`
  attribute slot from [[topic-ui-show-security-levels]] step 3 — same
  resolver, different consumer)
- adds **caching** of results per template+args (ties into
  [[topic-checksum-addressing]] / addressing-trinity for cache keys)

## relation to existing extbin/v7 mechanism

v7 already has a related but more limited mechanism: `extbin` mode
zenki entries — zenki-table entries that point at a script path instead
of a zenka name + the Protocol-7 binary (`src/v7.callback.object.zenka`,
`src/v7.handler.zenka_status`, `src/v7.zenka.instance.cmd.change-status`
status enum `online|extbin|queued|depending|error|offline`). extbin
zenki are spawned/monitored like real zenki but run arbitrary external
binaries.

os-command zenka is **not** a replacement for extbin — extbin is for
long-running processes that *become* zenki (connect back to cube).
os-command is for **one-shot or streaming command invocations**
dispatched *as commands* against a catalog of templates, with:
- better security structure (per-template security level, not just
  "can spawn extbin at all")
- async process structure designed for it from the start (not
  retrofitted onto the zenka-spawn lifecycle)
- **STDIO streaming support** — likely riding the existing STRM stack
  ([[topic-stream-transport-layer]], [[topic-stream-reply-modes]],
  [[topic-stream-framing-protocol]]) rather than a new transport
- possibly **vterm result buffers** — i.e. command output captured into
  a addressable/foldable vterm-like buffer, which would make it a
  natural `ui.cmd.ui-show` / `ui.unfold` consumer too (folded buffer =
  one-line summary, unfolded = scrollback) — ties into
  [[topic-ascii-frame-system]] / [[topic-frame-plugin-slots]] /
  console-fold-tree work

## migration path: os-command -> v7 -> cube (added 2026-06-11)

os-command zenka is explicitly framed as a **test bed** for the
security-level model before it migrates further inward:

1. **os-command zenka** — prove the security-level-gated template
   catalog in a low-stakes, isolated zenka first
2. **v7 zenka** — once smooth, migrate the same model into v7 itself
   for fine-grained / selective / dynamic control of zenki-state-
   modifying commands (`v7.start`/`v7.stop`/`v7.restart`/etc, currently
   gated only by coarse `access.cmd.usr.<role>` lists in
   `cube/access.zenki` — see e.g. `access.cmd.usr.system` granting
   `v7.stop v7.start v7.restart ...` as an all-or-nothing block).
   security-level-per-command would let e.g. "restart a specific
   on-demand zenka" be a lower bar than "restart core always-on zenki
   (cube/v7/httpd)".
3. **cube zenka** — once v7 has it, extend cube with **zenki groups**:
   different admins see *completely different sets of zenki and their
   data* on the same cube, not just different *command lists* for the
   same global zenka set. this is a step beyond the existing
   `has_access`-filtered command lists (`base.cmd.show-access`,
   `base.has_access` — already per-user) — it's per-user *visibility*
   of the zenka topology itself, not just per-user command permissions
   on a shared topology. likely needs: a "zenka group" attribute
   (parallel to the `security-level` attribute from
   [[topic-ui-show-security-levels]] step 3, possibly on the same
   `access.*.usr.<group>` config axis), and `list`/`list sessions`/etc
   cube commands filtered by group membership the same way `ui-show`
   field-level filtering works — same mechanism, applied to the
   *zenka-list* dimension instead of the *field* dimension.

this 3-stage path is the long-term justification for getting the
security-level resolver shape right in step 3 of
[[topic-ui-show-security-levels]] — it needs to generalise from
"caller level vs. field level" to "caller level vs. command level" (v7)
and "caller group vs. zenka group" (cube) without reshaping the
resolver's API.

## status

idea only — not yet a design doc or task file. "soon" per the user, no
date committed. natural follow-up once:
- [[topic-ui-show-security-levels]] step 3 (`access.security-level.usr.*`
  attribute) has at least one real non-admin consumer to validate the
  attribute shape against
- STRM stack ([[topic-stream-transport-layer]]) is stable enough to be
  the streaming substrate (it's marked "complete; open: open-0 sentinel"
  as of recent sessions)

## next step when picked up

write `data/md/design/OS-COMMAND-ZENKA.md` covering: template format
(likely YAML, parameterised like the LLM dispatch templates), security
level per template, caching key derivation, STRM-based STDIO streaming,
vterm buffer addressing for results, relation to extbin (explicitly
non-overlapping). then split into task files the same way
[[topic-ui-show-security-levels]] was split.

#,,,,,,,,,.,.,,,.,,.,,...,,.,,...,,..,,,.,.,.,..,,...,...,...,.,.,,.,,,.,,,..,
#3S2MGU2JGBJWBDL425CTMQ3VL5RJ6GS3Z7YEZ2LT6NG6TTL7QWARBYJMFUTUUGIV3RRDVVK5Y7BGK
#\\\|62DLJVHXPAU3VEI4MYCXYBS4HAIYLCQ4TJCQFDQG2XHY462ROPB \ / AMOS7 \ YOURUM ::
#\[7]TOZLATL3M5OJLAHDSVGZPDFLH4H2D7HG4QCDLYCDSC4Z7DVF3CDI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
