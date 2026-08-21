---
name: session-60
description: "Session 60 — jobsite assessment pipeline fixed end-to-end; YAML parsing, newline transport, control chars, model config"
metadata: 
  node_type: memory
  type: project
  originSessionId: 06c9f83d-9e58-4010-8157-f4713569c55c
---

## Jobsite assessment pipeline — fully working as of 2026-05-28

All jobs now produce parsed YAML with score/reason/summary. Series of bugs fixed:

### 1. Model config — switch to 9B
`cfg/zenki/coding/zenka.v7`: `coding.cfg.start_model = WZIZD6Y:2BIZKWY`
**Why:** 4B model (YYZYSXQ:ZSNYLYY) produced empty/garbage YAML. 9B loads as fast as 4B with new llama build.

### 2. state_machine no_tools content loss (`src/coding.async.state_machine`)
`no_tools` branch called `complete_task` without saving `$data->{'content'}` to state first → empty result.
Fix: `$state->{'content'} = $data->{'content'} // $state->{'content'} // ''` before complete_task.

### 3. chunk_handler reasoning tool-call false trigger (`src/coding.async.chunk_handler`)
For `:no_tools:` tasks, skip checking `context->reasoning` for XML tool calls — model hallucinating tool calls in thinking trace incorrectly routes to STATE_TOOL_EXEC.
Fix: added `$task_flags_ch->{'no_tools'}` guard. Lines ~184-190.

### 4. Newlines lost in task result transport
Root cause: `models.handler.task-result` line 115 deliberately did `s{\n}{ }g` ("collapse newlines to prevent protocol framing corruption"). This made YAML arrive as one long line.
Fix: B32-encode the result before `task.complete` call:
```perl
my $utf8_bytes = Encode::encode('UTF-8', $response);
my $encoded_response = ':B32:' . <[base32.encode]>->(\$utf8_bytes);
```
And decode in `task.cmd.complete`:
```perl
if ( $result =~ s{^:B32:}{}i ) {
    my $decoded = <[base32.decode]>->($result);
    $result = Encode::decode('UTF-8', $decoded) if defined $decoded;
}
```

### 5. YAML::XS parsing — multiple issues in `jobsite.handler.assess-done` and `repair-done`

**a) Preamble strip regex bug** — `s{^.*?(?=^score\s*:)}{}ms` fails silently: with `/m`, `^` at start of pattern can match at the `score:` line itself, making `.*?` match 0 chars. Fix: use `substr` from match position:
```perl
my $has_yaml = $yaml_src =~ m{score\s*:\s*\d};
$yaml_src = substr($yaml_src, $-[0]) if $has_yaml;
```

**b) YAML::XS Wide character** — `utf8::decode` sets utf8 flag; YAML::XS needs bytes. Fix:
```perl
utf8::decode($yaml_src) if not utf8::is_utf8($yaml_src) and utf8::valid($yaml_src);
# ... strip/process ...
my $yaml_bytes = $yaml_src;
utf8::encode($yaml_bytes) if utf8::is_utf8($yaml_bytes);
$parsed = eval { YAML::XS::Load($yaml_bytes) };
```

**c) Control characters** — YAML 1.1 forbids C0 controls (except tab/LF/CR), DEL, and C1 controls (0x80–0x9F). Strip before encode:
```perl
$yaml_src =~ s/[^\x09\x0A\x0D\x20-\x7E\xA0-\x{FFFD}]//g;
```

### 6. Prompt engineering — model compliance
`src/jobsite.util.build_prompt`: changed preamble to "Output ONLY YAML. No prose. No analysis. No markdown. Start your response with: score:" and added "Beginne jetzt mit: score:" as last line before closing.

### Data flow (for future reference)
jobsite → `task.create` (task zenka) → `models.task-notify` → models/coding zenka → inference → `models.handler.task-result` → B32-encode → `task.complete` → task zenka stores → `task.wait-done` SIZE reply → `base.handler.command` SIZE handler → assess-done callback (no `mode` field — normal for callbacks).

**How to apply:** When touching jobsite assessment pipeline, YAML parsing in assess-done/repair-done, or models.handler.task-result, refer to these fixes.

#,,,,,,,,,.,,,,..,...,..,,...,.,,,...,...,,,.,..,,...,...,.,,,.,,,,.,,.,,,,..,
#2S6IIS7U4M2M4GLAAZ7SPQQMMIKA46T2OUCVLZEFYI62Z62S7ILYRDEUSGW5APGKPEAZCEXRDJJ6W
#\\\|CZGSPXWCUXPP3GNC4YE44FVZOFNXMOOJM7HO7GANGYDLTJR5GQJ \ / AMOS7 \ YOURUM ::
#\[7]RDBZLX5YCTRWPVOISYU3HOODLXFT6AQDVMMCG4XBDHVJVDG2HKCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
