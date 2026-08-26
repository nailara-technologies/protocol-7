## task: strip stream-json boilerplate before 9B summarization

### goal

before passing `claude_dispatch` output to `_do_summarize()`, extract just
the assistant text content — discarding all structural stream-json noise
(`system`, `rate_limit_event`, `assistant`-envelope, `content_block_delta`
metadata, etc). this eliminates the ~1.9x json re-encoding inflation that
currently pushes a 58KB stream to ~34K tokens in the 9B model's context.

---

### background

`bin/mcp-server-p7` runs the `claude` CLI with `--output-format stream-json`.
the resulting stdout is a sequence of newline-delimited JSON objects:

```
line 0:  Warning: no stdin data received... (non-JSON warning)
line 1:  {"type":"system","subtype":"init","cwd":"...","session_id":"...","tools":[...]}
line 2:  {"type":"rate_limit_event","rate_limit_info":{...}}
line 3+: {"type":"assistant","message":{"model":"...","content":[{"type":"text","text":"..."}],...},...}
  ...    (one assistant line per turn, content accumulates across turns)
line N:  {"type":"result","subtype":"success","is_error":false,"result":"...FULL TEXT...","session_id":"...","total_cost_usd":0.17,...}
line N+1: (blank)
line N+2: To resume this session: claude -r <uuid>
```

the `result` field on the final `{"type":"result",...}` line is the complete
assistant response as a plain utf-8 string. in the sampled session it was
3,857 chars; the raw stream was 59,543 bytes — a ~15x reduction.

the `To resume this session:` line is already stripped before `_do_summarize`
is called (line 1739). the remaining `$output` is still the full stream.

---

### where to implement

**file**: `bin/mcp-server-p7`

**insertion point**: line 1750 — just before the `_do_summarize` call inside
the `auto_summarize` block:

```perl
## line 1750 (current):
            my $summary = _do_summarize( $output, $instruction, 600 );
```

add one line immediately before it:

```perl
            $output = _extract_stream_content($output);
            my $summary = _do_summarize( $output, $instruction, 600 );
```

**new function**: add `_extract_stream_content` near `_do_summarize` (around
line 1369, before `_do_summarize`). the two functions are logically paired —
extraction feeds summarization.

---

### implementation spec

```perl
sub _extract_stream_content {
    my ($text) = @ARG;

    ## primary: extract result field from final {"type":"result",...} line ##
    for my $line ( split /\n/, $text ) {
        next unless $line =~ m{^\{.*"type"\s*:\s*"result"};
        my $decoded = eval { decode_json($line) };
        next if $@;
        my $result = $decoded->{'result'} // '';
        return $result if length($result) > 10;
    }

    ## fallback: concatenate text from {"type":"assistant",...} message lines ##
    my @parts;
    for my $line ( split /\n/, $text ) {
        next unless $line =~ m{^\{.*"type"\s*:\s*"assistant"};
        my $decoded = eval { decode_json($line) };
        next if $@;
        my $msg = $decoded->{'message'} // {};
        for my $block ( @{ $msg->{'content'} // [] } ) {
            push @parts, $block->{'text'}
                if ( $block->{'type'} // '' ) eq 'text'
                and length( $block->{'text'} // '' );
        }
    }
    return join( "\n", @parts ) if @parts;

    ## last resort: return original — do not lose data ##
    return $text;
}
```

**notes on the implementation**:

- `decode_json` is already imported at the top of the file (used elsewhere)
- the `> 10` guard on result length avoids returning an empty or truncated
  result from a failed/interrupted run; the fallback chain then applies
- the fallback collects all assistant turns — useful for multi-turn sessions
  where no final `result` line was emitted (e.g. interrupted runs)
- last resort returns `$text` unchanged so `_do_summarize` still runs on
  whatever was captured; this preserves current behavior for unknown formats
- `$ARG` not `@_` — follows the P7 convention used everywhere in this file
- do NOT use `@_ ? shift : $ARG` here; function is always called with args

---

### verify imports / deps

`decode_json` is from `JSON::XS` (or `JSON`) which is already imported. grep
to confirm before adding any `use` statement:

```bash
grep -n 'decode_json\|use JSON' bin/mcp-server-p7 | head -10
```

if `decode_json` isn't imported, use inline `JSON::XS->new->decode($line)` or
import it. do not add a new `use` unless the grep shows it's absent.

---

### test plan

**manual smoke test** — after implementing:

```bash
## dispatch a small task and confirm summary is readable prose, not json lines
p7c claude_dispatch "list the files in data/tasks/ and count them"

## dispatch a larger task — confirm rolling window still works
p7c claude_dispatch "summarize the last 5 commits in this repo"
```

expected: output is a human-readable summary paragraph, NOT json fragments
like `{"type":"assistant",...}` or `{"type":"system",...}`.

**edge cases to check**:

1. `kimi_dispatch` output — kimi does NOT use stream-json format; its output
   is plain text. `_extract_stream_content` must return it unchanged. confirm
   by checking: if no `{"type":"result",...}` line and no `{"type":"assistant",...}`
   lines are found, the original text is returned (last-resort path).

2. interrupted claude session — no `result` line, but some `assistant` lines
   present. fallback should return the partial text from assistant lines.

3. completely empty output — function returns `$text` (empty string), same as
   before the fix.

---

## signatures_note

do not add or modify the 4-line `#,,,` signature block at the end of module
files. leave signing to the build system (`bin/Protocol-7 sourcecode
update-signatures`). `bin/mcp-server-p7` is a standalone script — it has no
signature block and does not need one.

---

### dispatch

model: kimi
reasoning: low

prompt: |
  implement the task at data/tasks/strip-dispatch-json-boilerplate.md

  read bin/mcp-server-p7 lines 1350-1410 (_do_summarize and surrounding
  helpers) and lines 1728-1760 (auto_summarize block) before writing
  anything. the change is two parts:
  1. add `_extract_stream_content` sub near _do_summarize (~line 1369)
  2. call it on $output just before the _do_summarize call at line 1750

  follow existing code style exactly: $ARG not @_, lowercase comments,
  bracket annotations. verify decode_json is already imported before
  adding any use statement.

#,,,,,.,,,,..,..,,,.,,.,.,,..,,,.,..,,,,,,...,..,,...,..,,...,,..,...,...,,,,,
#PG43RZ5DJ7J7OMQ66N7H4WOKXMRDFEQAWJC3VJ2RB4BT4F32OYZ7D3NZMBB24ODS5TQ3BZXEZJNWS
#\\\|GORA3MT5NZO2BTNMIUZ33KZEG5SYGV7SHQPGUEYGX3MIW6425XE \ / AMOS7 \ YOURUM ::
#\[7]SB7TUH44UYRCCH5BTXISXBQJGBCDLXGVQ5TWUOTI4CWQRSRFBWAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
