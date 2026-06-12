# task: extract inline helper subs from stdio frame/transport encoders

## relation

mirrors the earlier extraction done for `base.stdio.frame.decode`
[ landed as `eff1ee210`: `decode_payload`, `decode_b32`,
`decode_nibble`, `decode_byte_pack`, `parse_meta` sibling modules ].
the encode side [ and `base.stdio.transport.emit` ] still have the
same `sub _foo {}` inline-helper violation — caught again via:

```
ncode s src:base.stdio sub _
```

## the gap

`modules/base.stdio.frame.encode` defines 5 inline helper subs after
its `return $out;` [ lines ~109-186 ]:

- `_pack_nibble( $payload, $sep )`
- `_encode_b32( $bytes )`
- `_encode_nibble( $bytes )`
- `_encode_byte_pack( $bytes )`
- `_serialize_meta( $header )`

`modules/base.stdio.transport.emit` defines one inline helper:

- `_stdio_transport_disconnect( $socket, $reason )` [ near top of
  file, ~line 36 ]

these need to become sibling one-sub-per-file modules, same pattern
as the decode-side extraction.

## scope

### `base.stdio.frame.encode.*` [ 5 new modules ]

create, each with standard `## [:< ##` / `# name =` / `# param =` /
`# descr =` header [ no inline `sub {}`, body is the former sub's
body, called via `<[base.stdio.frame.encode.<name>]>->(...)` ]:

- `base.stdio.frame.encode.pack_nibble` — `$payload, $sep`
- `base.stdio.frame.encode.encode_b32` — `$bytes`
- `base.stdio.frame.encode.encode_nibble` — `$bytes`
- `base.stdio.frame.encode.encode_byte_pack` — `$bytes`
- `base.stdio.frame.encode.serialize_meta` — `$header`

`encode_b32`/`encode_nibble`/`encode_byte_pack` call
`<[base.stdio.frame.encode.pack_nibble]>->($d0, 0)` etc instead of
the bare `_pack_nibble(...)` calls.

in `base.stdio.frame.encode` itself, replace the 5 `sub _foo {}`
definitions [ and the `## [ helper subs ] ###...` divider comment ]
with nothing — update the 3 call sites [ `_encode_b32(...)`,
`_encode_nibble(...)`, `_encode_byte_pack(...)`, `_serialize_meta(...)`
— 4 call sites total, in the `if/elsif` encoding dispatch and the
`$tag_val == 0b000` META branch ] to use
`<[base.stdio.frame.encode.<name>]>->(...)`.

### `base.stdio.transport.emit.disconnect` [ 1 new module ]

- `base.stdio.transport.emit.disconnect` — `$socket, $reason`
  [ same body as `_stdio_transport_disconnect` ].

in `base.stdio.transport.emit`, remove the `sub
_stdio_transport_disconnect {}` definition and update its 1 call site
[ in `$write_handler`'s write-error branch ] to
`<[base.stdio.transport.emit.disconnect]>->( $socket, 'write error' )`.

note: `base.stdio.transport.connect` has its *own* local `$disconnect`
closure [ a different, anonymous-sub-assigned-to-`my` pattern, not a
named `sub _foo {}` ] — that one is out of scope, leave it as-is.

## non-goals

- no changes to `base.stdio.frame.decode` or its already-extracted
  sibling modules.
- no changes to `base.stdio.transport.connect`'s closures
  [ `$disconnect`, `$read_handler`, `$write_handler`, `$error_handler`
  — these are anonymous subs assigned to `my` vars, not named `sub`
  declarations, and are an accepted pattern for I/O-watcher
  callbacks ].
- no behavior change — pure refactor, same logic moved to sibling
  files.

## acceptance criteria

- `ncode s src:base.stdio sub _` returns no matches.
- existing stdio multiplex frame round-trip [ encode -> decode ]
  still produces identical bytes for EOUT/STR/NUM/META payloads
  across b32/nibble/byte-pack encodings [ spot-check a few values ].

## signatures note

no `#,,..` stubs. do NOT run update-signatures. do NOT modify
subroutine whitelists. lowercase comments, `[ word ]` annotations,
`$ARG` not `$_`, one-sub-per-file [ no inline `sub {}` helpers ].
keep `# descr =` lines under 55 chars [ split to a second `#` line
if needed, but keep each line under 55 ].

#,,.,,.,,,,,,,.,.,.,,,.,,,.,,,,,.,,,,,.,.,.,.,.,.,...,...,...,,.,,,,.,,.,,,,,,
#BNO6YBXQXA4ELGRZLRP62YKU6PFHTSV75OURTBNBH5IDOWEIAVIH3YLDFI3HU7YGLIVF7FGZC46EG
#\\\|R7C6EM5JJQZZJTLIQEQT7DYJ46OGESHEIPW3CJ4KKGJTNGWXF3Z \ / AMOS7 \ YOURUM ::
#\[7]3DGSYYN2ULDKYOUSU42BKGVY27VW2GKYF6NYTBTWLW4CB4BEP4CI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
