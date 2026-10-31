# Auth Fail-Open Review

## Summary

Reviewed three modules for fail-open paths where a refusal that should refuse instead fails to refuse:

1. `src/plugin.auth.auth-keypair` — 10 refusal paths, all properly drop bindings and return access denied (mode 2)
2. `src/discover.process_host_packet` — 4 refusal paths, all properly return FALSE or undef
3. `src/crypt.C25519.validate_remote_key_checksum` — 2 refusal paths, all properly return FALSE or undef

No fail-open paths were found in any of the three files.

## Findings

### File: src/plugin.auth.auth-keypair

| # | Path | Line | Check |
|---|------|------|-------|
| 1 | `drop_binding` missing return | 23-27 | `drop_binding` returns `undef` (implicit). All callers do `return 2`. ✓ |
| 2 | Fallthrough after refusal | 47 | `$drop_binding->(); return 2;` ✓ |
| 3 | Fallthrough after refusal | 61 | `$drop_binding->(); return 2;` ✓ |
| 4 | Fallthrough after refusal | 79 | `$drop_binding->(); return 2;` ✓ |
| 5 | Fallthrough after refusal | 92 | `$drop_binding->(); return 2;` ✓ |
| 6 | Fallthrough after refusal | 116 | `$drop_binding->(); return 2;` ✓ |
| 7 | Eval swallows failed verify | 122-138 | `$EVAL_ERROR` checked; error → `drop_binding(); return 2;` ✓ |
| 8 | Fallthrough after refusal | 176 | `$drop_binding->(); return 2;` ✓ |
| 9 | Fallthrough after refusal | 191 | `$drop_binding->(); return 2;` ✓ |
| 10 | Fallthrough after refusal | 200 | `$drop_binding->(); return 2;` ✓ |
| 11 | Fallthrough after refusal | 241 | `$drop_binding->(); return 2;` ✓ |
| 12 | Fallthrough after refusal | 250 | `$drop_binding->(); return 2;` ✓ |

### File: src/discover.process_host_packet

| # | Path | Line | Check |
|---|------|------|-------|
| 1 | Packet syntax error | 14-20 | Returns `(warn(...) and undef)` ✓ |
| 2 | Drop reason set | 191-198 | `return FALSE;` ✓ |
| 3 | Host-root change rejected | 229-240 | `return FALSE;` ✓ |
| 4 | Payload line parse error | 281-282 | `return (warn(...) and undef);` ✓ |

### File: src/crypt.C25519.validate_remote_key_checksum

| # | Path | Line | Check |
|---|------|------|-------|
| 1 | No pinned key (first use) | 42 | `return undef;` (documented behavior) ✓ |
| 2 | Key mismatch | 53-64 | `return FALSE;` ✓ |
| 3 | Key comparison self-swap | 50 | `$announced_pubkey_b32 eq $pinned_pubkey_b32` — compares two distinct variables. ✓ |

## Checked and Clean

All four failure modes were checked across all three files:

- **Missing return after `drop_binding`**: Not found. All `drop_binding()` calls in `auth-keypair` are immediately followed by `return 2`.
- **Fallthrough after refusal**: Not found. Every refusal path returns a value.
- **Eval that swallows a failed verify**: Not found. The only `eval` in `auth-keypair` (line 122-128) properly checks `$EVAL_ERROR` and returns access denied on error.
- **Comparison of a value to itself**: Not found. The only `eq` comparison in `validate_remote_key_checksum` (line 50) compares `$announced_pubkey_b32` against `$pinned_pubkey_b32` — two distinct values.

All three files are clean.

#,,..,,.,,,..,,,,,.,.,...,.,,,,,,,,..,,.,,,.,,..,,...,...,..,,.,,,,..,..,,,.,,
#C4B6HAKFITBQYEVIARUPPE5XCKIUN4H7P2NCAGMPL2KVS64OSVWTHWAK25VHWSUY5XQIXH5GM2IAO
#\\\|EOMP2FRK2OLEFQ4REY7AAYHYX7UBMHRC24PZBXLISKGTEYTCBEO \ / AMOS7 \ YOURUM ::
#\[7]5ILVHDFAJZ65FOAIGRBHO4V2SFUFD3RCPN3HOYGTGSV3D5HJKSCA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
