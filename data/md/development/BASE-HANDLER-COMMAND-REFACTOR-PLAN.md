# base.handler.command — refactor plan

## context

`base.handler.command` is the largest single subroutine in the system — already noted
as 3MB compilation cost in its own header comment `[LLL]`. STRM and STRM-SIZE additions
have grown it further. Local LLMs were previously unable to work with it due to size;
recent models have regained that capability, making the refactor now tractable.

A SIZE packet loss bug exists that is triggered by STRM interactions (symptom: zenka
stops returning SIZE replies until an unrelated command like `heart` is sent). The radio
zenka group is expected to reproduce it reliably. **Resolve the bug before or during the
refactor** — the split will make the relevant paths much easier to reason about.

See: `data/md/development/` for any related debugging notes when available.

## principles

**1. identical-behavior extractions only, in verified steps**
Each extraction must produce bit-identical protocol behavior. No logic changes during
extraction. Refinement passes come only after equivalence is established across all pieces.

**2. namespace and variable mapping before any code moves**
The local temporaries that traverse into global state — `$src_sid`, `$src_cmd_id`,
`$s_cmd_id`, `$route`, `$stream` etc. — must be mapped to clear sub-namespace names
before extraction begins. Wrong choices here propagate through every extracted piece.

**3. per-session isolation is the natural boundary**
Each session carries its own complete world: input/output buffers, watchers, stream state,
flags. Extracted sub-modules take a `$session` reference and work within that scope.
New session keys introduced by sub-modules self-cleanup on session disconnect — no
additional teardown logic needed.

**4. cross-reference maps are the only explicit cleanup surface**
Only structures that index into sessions from outside — primarily `$data{'route'}` —
need explicit key management on teardown. This surface is small, well-defined, and
already handled in existing disconnect paths. Extracted modules inherit this for free.

**5. refinement only after equivalence**
Once all pieces are cleanly separated and verified equivalent, refinement passes can
improve clarity and reduce duplication within each piece. Each wave builds on the
verified foundation of the last.

## suggested extraction seams

The module naturally divides along these processing phases:

- **buffer pre-processing** — `ignore_bytes` / `ignore_chars` drop logic, watcher
  stop/start, ondemand timeout cancel
- **packet recognition** — the large elsif chain that identifies packet type and
  switches read mode (incomplete SIZE, STRM, STRM-SIZE, CHRSIZE early returns)
- **command dispatch** — routing, alias resolution, access control, handler invocation
- **reply routing** — TRUE/FALSE/WAIT/GET/TERM forwarding to source sessions
- **SIZE reply handler** — byte extraction, handler call or route-to-source
- **CHRSIZE reply handler** — character-aware extraction
- **STRM handler** — unbounded and bounded open/data/close
- **STRM-SIZE handler** — session blocking, chunk accumulation, timeout, close
- **unknown route handler** — ignore_bytes/chars tracking, !TERM! propagation

## execution approach

Claude: namespace map design + seam planning + review each extraction step
Local models: mechanical extraction execution within verified-safe steps

Plan the namespace map in a dedicated session before touching any code.

#,,,.,,..,,.,,.,,,.,,,...,..,,,,,,.,.,.,,,,,,,..,,...,...,,..,.,.,,,.,.,,,,,,,
#YAPPZYYNEMJTWQJYVKSASKEXJ644DYXSOYEQQWKD2EEPQSXD34G2NLK2QHD3YRND5PDXPHSTWDAGG
#\\\|ACCBKV7PRKQLYXFIA7IN3HREVSAA7MXRSMZI3HBREWP6XQMFQSW \ / AMOS7 \ YOURUM ::
#\[7]KLLUTJGCDBCPGNK6YAB25RVM2ROVQYJE46AH3PVCLA6CG3MRYIAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
