## task: add coding_summarize MCP tool — free local summarization via 9B model

### motivation

kimi and claude dispatch results are large (50–300KB of stream-json). reading
them in the parent context is expensive. the local coding zenka already runs
a 9B inference server with a rolling-window contextualization system. delegating
summarization to it is free and keeps the parent context lean.

---

### new MCP tool: coding_summarize

```
tool name:     coding_summarize
description:   summarize text using the local coding zenka (9B model, free).
               if text exceeds the model context window, uses rolling-window
               summarization. returns a concise structured summary.
params:
  text         the content to summarize (required)
  instruction  what to focus on in the summary (optional, default: general)
  max_tokens   target summary length hint (optional, default: 500)
timeout:       120s (local inference, fast)
```

---

### implementation in bin/mcp-server-p7

add to `@ext_tools` after the claude tools:

```perl
{   'name'        => 'coding_summarize',
    'description' =>
          'summarize text using the local coding zenka (9B model, free). '
        . 'if text exceeds model context, uses rolling-window summarization. '
        . 'use for compressing kimi/claude dispatch results before reading.',
    'params'      => [
        [ 'text',        'content to summarize',                            1 ],
        [ 'instruction', 'what to focus on (default: general summary)',     0 ],
        [ 'max_tokens',  'target summary length in tokens (default: 500)',  0 ],
    ],
    'timeout'     => 120,
},
```

the tool sends the text to the coding zenka via `p7c coding.submit`:

```perl
## in the handler for coding_summarize ##
my $text        = $args->{'text'}        // '';
my $instruction = $args->{'instruction'} // 'summarize the following text concisely';
my $max_tokens  = $args->{'max_tokens'}  // 500;

my $prompt = "$instruction. target length: $max_tokens tokens.\n\n$text";

## check size — if > ~8000 chars, use rolling window ##
if ( length($text) > 8000 ) {
    ## chunk and summarize iteratively ##
    ## each chunk = 6000 chars; carry forward previous summary as context ##
    my $running = '';
    my $pos     = 0;
    while ( $pos < length($text) ) {
        my $chunk = substr( $text, $pos, 6000 );
        $pos += 6000;
        my $chunk_prompt
            = length($running)
            ? "previous summary: $running\n\nnew content to integrate:\n$chunk\n\nupdate the summary:"
            : "$instruction:\n\n$chunk";
        $running = _call_coding_zenka($chunk_prompt);
    }
    return $running;
} else {
    return _call_coding_zenka($prompt);
}
```

#### _call_coding_zenka helper

```perl
sub _call_coding_zenka {
    my $prompt = shift;
    my $safe   = quotemeta($prompt);
    my $out    = qx|p7c coding.submit $safe 2>/dev/null|;
    chomp $out;
    return $out;
}
```

alternatively, if `p7c coding.submit` doesn't work cleanly for large inputs,
use the HTTP API directly:

```perl
use LWP::UserAgent;
my $ua  = LWP::UserAgent->new( timeout => 110 );
my $res = $ua->post(
    'http://127.0.0.1:8000/v1/chat/completions',
    Content_Type => 'application/json',
    Content      => JSON::XS::encode_json({
        model    => 'local',
        messages => [{ role => 'user', content => $prompt }],
        max_tokens => $max_tokens + 100,
    })
);
my $body = eval { JSON::XS::decode_json( $res->content ) };
return $body->{'choices'}[0]{'message'}{'content'} // 'summarization failed';
```

check which approach matches the existing coding zenka API first by reading
`modules/coding.handler.process-queued-task` or the coding.cmd.submit module.

---

### usage pattern in parent context

instead of reading full kimi/claude dispatch results:

```
1. dispatch kimi task → gets large output file
2. call coding_summarize(text=<output>, instruction="extract: files changed, issues, resume UUID")
3. read only the 500-token summary
```

this compresses a 200KB output to ~200 words in the parent context.

---

### rolling window details

the rolling window approach is already implemented in the codebase for
the coding zenka's completion-chain handler. reuse that logic if available,
or implement the simple iterative chunking above.

key insight: each chunk summary carries forward the previous summary as
context, so information from early chunks isn't lost.

---

### test

after implementation, test with:
```bash
p7c coding_summarize "$(cat /home/taeki/.claude/projects/-data-projects-protocol-7/56461443-76ee-4bbf-9976-ee5713dd7c8d/tool-results/mcp-protocol-7-kimi_dispatch-1780199431386.txt | head -c 20000)"
```

should return a concise summary of the auth plugin kimi dispatch.

---

### default integration with claude_dispatch and kimi_dispatch

enable `coding_summarize` as an automatic post-processing step for both
dispatch tools. after the command completes and before returning to the
caller, run the output through `coding_summarize` with a structured
extraction prompt:

```
instruction: "extract the following fields from this dispatch output:
  - status: completed/partial/errored
  - files_created: list
  - files_modified: list
  - issues: list of problems found
  - resume_uuid: the session resume ID
  - next_steps: any explicitly stated next actions"
```

return both the summary (for the parent context) and store the full
output to disk (for resuming via claude_continue/kimi_continue). the
caller only reads the summary.

add an `auto_summarize` param to claude_dispatch and kimi_dispatch
(default: TRUE) that controls this behavior.

---

### checklist / tasklist routing expansion

expand `coding_summarize` to operate as a **task completion verifier**
when given a checklist-style instruction:

```
instruction: "check the following acceptance criteria against the output.
  for each criterion, output PASS or FAIL with a brief reason:
  1. module X was created
  2. function Y handles edge case Z
  3. no signature stubs in new files
  if any FAIL: output DISPATCH_NEEDED: <what to fix>"
```

when the summary contains `DISPATCH_NEEDED:`, the MCP tool can:
1. return the summary with a `needs_followup: true` flag
2. optionally auto-dispatch a follow-up to kimi with the failure items

this creates a self-healing dispatch loop:
```
dispatch → summarize → verify checklist → if FAIL → re-dispatch with failures
```

the acceptance criteria come from the task file itself — parse the
task file for a `## acceptance criteria` or `## verification` section
and use those as the checklist items.

---

## dispatch

#,,..,,..,.,.,,..,..,,,,,,.,,,,..,,.,,,,.,...,..,,...,...,..,,,,.,,.,,,,,,.,.,
#VR3MOW3LMDWUO5YKG3PQ54VIYMCM6ERYHJWK6DFL62TBDBAC6FXEWG7PXTK24V7G6JI2PQ4XPLHDW
#\\\|DD3KK6PNDH7EKA37HY3VXFWN4ODGBKODOCK23ZLNXRESS3HKSV6 \ / AMOS7 \ YOURUM ::
#\[7]OHBMWZVZB3JJRCFFIANEO7UTKMVSPAYQWTWL5UCQZL2TNYZ2D6DI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
