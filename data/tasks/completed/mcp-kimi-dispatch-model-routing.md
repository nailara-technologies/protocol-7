# mcp-server-p7: model routing for kimi_dispatch / kimi_continue

## what this is

`claude_dispatch`/`claude_continue` already support a `model=haiku|
sonnet|opus` param, letting the caller pick cheap-and-fast vs.
maximum-quality per task. `kimi_dispatch`/`kimi_continue` have no
equivalent — every dispatch silently uses whatever `default_model` is
set in `~/.kimi/config.toml` (currently `kimi-code/k3`).

Motivation: real pricing data surfaced this session shows the three
available kimi models have sharply different cost/capability tradeoffs
(K3: $15/1M output, 1,048,576 token context, best reasoning; K2.7-code:
$4/1M output, 262,144 context, cheapest; K2.7-code-highspeed: $8/1M
output, 262,144 context, faster turnaround). All three were useful at
different points this session — broad file-search/verification passes
don't need K3's reasoning depth and would cost less on K2.7, while
tricky-bug or design-heavy work benefits from K3's larger context and
stronger reasoning. Right now there's no way to choose per-dispatch.

## resolved design — ready to implement

Mirror `claude_dispatch`'s existing pattern exactly (read
`bin/mcp-server-p7`'s `tool_external_command` sub in full first — the
claude-specific block near the top of that sub, and the `claude_dispatch`/
`claude_continue` entries in `@external_tools`, are the precedent to copy,
not just inspire from).

1. **Command templates** — add `--model %s` to both:
   - `kimi_dispatch`: `'kimi-legacy -y --afk -p %s'` →
     `'kimi-legacy -y --afk -p %s --model %s'`
   - `kimi_continue`: `'kimi-legacy -y --afk -r %s -p %s'` →
     `'kimi-legacy -y --afk -r %s -p %s --model %s'`
   The order of `%s` placeholders must match the order non-skipped params
   appear in each tool's `params` array (read how `tool_external_command`
   builds `@cmd_args` — it iterates `params` in order, skipping anything
   in `%skip_in_cmd` (`auto_summarize`, `keep`), and sprintf-substitutes
   positionally). Add the new `model` param entry to each tool's `params`
   array in the matching position (after `prompt` for `kimi_dispatch`;
   after `prompt` for `kimi_continue` too, i.e. right before
   `auto_summarize`/`keep` in both cases).

2. **Params array entry** (both tools), matching the exact shape of
   claude's `model` param entry:
   ```perl
   [ 'model', 'model: k3 (default, best reasoning, large context) | '
       . 'k2.7 (cheapest, good for broad search/verification) | '
       . 'k2.7-fast (faster turnaround, mid cost)', 0 ],
   ```

3. **Alias-resolution block** in `tool_external_command`, alongside
   (not replacing) the existing `if ( $ext->{'name'} =~ m{^claude_} )`
   block — add a parallel one:
   ```perl
   if ( $ext->{'name'} =~ m{^kimi_} ) {
       $args->{'model'} //= 'k3';

       my %model_map = (
           'k3'        => 'kimi-code/k3',
           'k2.7'      => 'kimi-code/kimi-for-coding',
           'k2.7-fast' => 'kimi-code/kimi-for-coding-highspeed',
       );
       if ( defined $args->{'model'} ) {
           $args->{'model'} = $model_map{ $args->{'model'} }
               // $args->{'model'};
       }
   }
   ```
   The three internal alias strings (`kimi-code/k3` etc.) are confirmed
   live against `~/.kimi/config.toml` — do not change them without
   re-checking that file, they must match the `[models."..."]` table
   keys exactly.

4. **Tool descriptions** — update both tools' `'description'` strings to
   mention the new model param, mirroring claude's phrasing style
   ("specify model=k2.7 for cheap token-heavy work, model=k3 (default)
   for complex reasoning...").

## verification

- `perl -C31 -c bin/mcp-server-p7` must pass.
- Do NOT live-test by actually dispatching a real kimi task (that would
  spend real budget just to test plumbing) — instead, verify by reading
  the resulting code path carefully: trace through `tool_external_command`
  by hand for a `kimi_dispatch` call with `model=k2.7` and confirm the
  final constructed shell command string would be exactly
  `kimi-legacy -y --afk -p '<prompt>' --model kimi-code/kimi-for-coding`
  (mentally substitute, or add a temporary debug print and remove it
  before finishing — do not leave debug output in the final diff).
- Confirm the existing claude-specific block and default behavior
  (omitting `model` entirely) are unchanged — this must be purely
  additive.

## status

LANDED 2026-07-17 (kimi K3). `kimi_continue` was migrated from the
legacy `param_name`/`param2_name` format to the same `params` array
format its siblings already use — necessary to fit a 3rd param in, and
as a side effect gives it `auto_summarize`/`keep` support it never had
before (kimi_dispatch already had both). Reviewed directly: no other
tool definition still used the legacy format, schema-building already
had a generic branch for the array format, `perl -C31 -c` passes.

#,,..,,,,,,.,,...,.,.,,.,,..,,.,.,...,,,.,,,.,..,,...,...,...,.,,,,,.,,..,..,,
#47EBSW44X2PANQZQDJKD26IPKZ3F4Q7JWAH3ZTMK3DI4MZLGYIMWACY5VFL2YPEZDJIGU2D7F34CC
#\\\|LBBGS2K67UDOAUYYLMRJFJ6W2UVTG4KGWK4FWXKIJD4ZC3SQY7O \ / AMOS7 \ YOURUM ::
#\[7]OKHIKO6OSFGHP4FIQL5HRVYU5OMUZTFTEMB356QCMGAFFNGTNADY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
