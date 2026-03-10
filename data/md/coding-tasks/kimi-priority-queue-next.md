
 .:[  kimi priority queue — next session  ]:.

## Context

Previous session completed all tiers of kimi-priority-queue-mar2026.md.
New modules exist but need integration, wiring, and start-file loading.
This list is ordered by: blocking status, integration value, correctness.

---

## Tier 1 : Commit + Wire New Modules [ ~2h ]

### 1.1 Commit the uncommitted modules from last session

These are built and signed but not yet committed:

```
modules/zulum.loop.generate_entropy
modules/zulum.init_code
modules/zulum.cmd.stream-attach
modules/decoder.zenka.init_code
modules/decoder.zenka.receive_entropy
modules/decoder.cmd.show-buffer
modules/decoder.cmd.erase-level
modules/models.handler.llm_response
modules/models.callback.send_reply
```

Sign any that need it, then commit as a group:
`git add modules/zulum.* modules/decoder.* modules/models.handler.llm_response modules/models.callback.send_reply`

Also add them to `modules/base.list.subroutines` if missing.

### 1.2 Wire zulum → decoder via stream-attach

`zulum.cmd.stream-attach` should register `decoder.zenka.receive_entropy`
as the consumer callback. The connection point:

```perl
## in zulum.cmd.stream-attach or zulum.init_code: ##
push @{ <zulum.stream>{$stream_id}{'attached'} }, sub {
    my ( $sid, $entropy, $iter ) = @ARG;
    <[decoder.zenka.receive_entropy]>->(
        { 'stream_id' => $sid, 'entropy' => $entropy }
    );
};
```

Test with: attach stream 1, run one entropy cycle, verify decoder
accumulates and `show-buffer 5` shows base32 values.

### 1.3 Load new modules in start files

**models zenka** (`configuration/zenki/models/start` or similar):
- add `models.chat.expand_refs` sub-modules to modules.load
  (expand_refs.read_file, format_file, format_code, format_tail,
  format_head, format_grep are in base.list.subroutines — verify they load)
- add `models.callback.send_reply` and `models.handler.llm_response`

**coding zenka** (`configuration/zenki/coding/start`):
- verify `models.handler.llm_response` is loaded for the HTTP inference path

**zulum zenka** (`configuration/zenki/zulum/start`):
- create if it doesn't exist, load `format.json zulum` module groups

**decoder zenka** (`configuration/zenki/decoder/start`):
- create if it doesn't exist, load `decoder.zenka` module group

---

## Tier 2 : Correctness Fixes [ ~2h ]

### 2.1 models.handler.llm_response — use format.json.decode

Currently calls `JSON::PP::decode_json($body)` directly. Since
`models` will load `format.json`, change to:

```perl
my $data = <[format.json.decode]>->($body);
if ( !$data || !exists $data->{'choices'} ) { ... }
```

Remove the `eval { JSON::PP::decode_json... }` and `$@` check —
`format.json.decode` handles errors internally and returns `{}`.

### 2.2 base.p7ref.self — correct ADDR_B32 derivation

Currently uses `encode_b32r($raw_pubkey)` (RFC4648, 32-byte input →
52-char output, substr to 6). The spec says ADDR_B32 should be derived
from AMOS7 checksum of pubkey:

```perl
## use AMOS7 checksum of pubkey as ADDR_B32 — deterministic + compact ##
my $addr_chk = <[chk-sum.amos]>->($addr_input);  ## 7 chars [A-Z0-9] ##
my $addr_b32 = substr( $addr_chk, 0, 6 );
```

Note: `chk-sum.amos` is the post-swap name. Since `base.p7ref.self`
is called from `base.init_code` AFTER swap runs, this is safe to use.
Verify with `list zenki` showing TYPE:CHKSUM7:ADDR_B32 per zenka.

### 2.3 Verify @INDEXCUBE identity anchor with list zenki

After 2.2 is working, verify the full chain:
- `list zenki` shows cube coordinate in P7REF format
- `base.indexcube.here` returns the hashref correctly
- `base.indexcube.depth` returns 1 for a fresh zenka (only anchor)
- Test `push` + `pop` round-trip in devmod

---

## Tier 3 : cube-13 Jump Routing [ ~2h ]

### 3.1 Jump table in modules/cube-13

`data/md/coding-tasks/zulum-cube13-decoder-integration.md` → Phase 2

Commands: `jump true`, `jump reverse`, `jump next`

```
cube-13.cmd.jump:
  'true'    → switch active stream to stream where is_true(state) = TRUE
  'reverse' → switch to the reverse-digit stream
  'next'    → advance to next stream in cycle (mod 13)
```

On stream jump: notify decoder with boundary marker so it knows a
new stream started. The boundary marker is the flipping delimiter
from the octal encoding (see decoder-zenka-stream-protocol.md).

### 3.2 Wire cube-13 → zulum stream selection

cube-13 jump commands call `zulum.cmd.stream-attach` to switch which
stream feeds the decoder. The decoder receives a zipper boundary
marker before the new stream starts.

---

## Do Not Attempt

- `fix-list-alignment-offset-truncation.md` — needs live captures first
- `lm-vision-binary-rebuild.md` — low priority, HTTP path works
- `zenka-key-identity-infrastructure.md` — large, needs key infrastructure
- Any changes to `base.parser.decode_harmonized_refstr` — recently fixed,
  leave stable

---

## Notes for Kimi

- Sign all new files: `bin/Protocol-7 sourcecode update-signatures`
- `format.json.*` is now the canonical JSON module (not `httpd.json.*`)
  — use `<[format.json.encode]>` and `<[format.json.decode]>`
- `models.chat.expand_refs` sub-modules are already committed and in
  `base.list.subroutines` — just need loading in start files
- The identity anchor at `@INDEXCUBE[0]` is now a hashref with
  `{p7ref, timestamp, depth, signature}` — signature is `''` (empty)
  because the anchor is self-evidencing by position
- `bin/dev/gen-div` is the oracle for verifying zulum stream output

#,,,.,,,.,.,,,,..,,,,,,,.,...,..,,.,,,.,.,.,,,.,.,...,...,...,..,,,.,,,..,.,,,
#QZR34CMUMRVCIWDFANCXM37K4GYWW7LLXC2JHE7TVWREVPW6SXCXXYMATJ5VCIKUW7F6LBMAVU24Y
#\\\|R5WCCFUVDNLWK5A6EYVYEMZBEIZJZWJT54KWNUMC6FWLRGSERNB \ / AMOS7 \ YOURUM ::
#\[7]K52DMOMPYPVQUULEVZ6CGKYJD3HJ3TX4W3XR5SF2UXZDMJMSD2BI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
