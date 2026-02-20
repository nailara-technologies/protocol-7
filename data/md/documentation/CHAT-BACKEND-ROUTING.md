# Chat Backend Routing

**Status:** ✅ Implemented (2025-02-20)

Model backend routing infrastructure for multi-model chat system. Routes chat messages to appropriate backends (API, local, test) based on model name.

## Model Name Mapping

```perl
'kimi'       => 'api'      # kimi-code API (Moonshot AI)
'kimi-code'  => 'api'
'claude'     => 'api'      # Future Claude API integration
'llama'      => 'local'    # Local llama-server
'local'      => 'local'
'test-model' => 'test'     # Test echo (no API call)
```

## Usage

### Test Model (No API Required)
```bash
p7c models.chat test-model "Hello! Testing chat system."
# Returns: :note: test echo: <message>
```

### Kimi-Code API (Requires API Key)
```bash
p7c models.chat kimi "Explain async/await in Perl."
# Routes to: models.backend.api.invoke
# Requires: <models.api.key> configured
```

### Local Llama Server
```bash
p7c models.chat llama "Generate a Perl function to parse JSON."
# Routes to: models.backend.local.invoke
# Requires: llama-server running and reachable
```

## Architecture

```
models.cmd.chat
     ↓
models.chat.invoke_model (routing wrapper)
     ↓
┌────────────────┬─────────────────┬─────────────┐
│                │                 │             │
test backend     api backend       local backend
(echo)           (kimi/claude)     (llama)
     ↓                ↓                  ↓
   return    models.backend.api  models.backend.local
                     ↓                   ↓
              HTTP API call      HTTP to llama-server
              (moonshot.cn)      (localhost:8080)
```

## Backend Parameters

All backends receive standardized parameters:
```perl
{
    'participant_id'  => $model_name,
    'job_id'          => 'chat',
    'model_id'        => $model_name,
    'system_prompt'   => '',
    'messages'        => [ { role => 'user', content => $message } ],
    'temperature'     => 0.7,
    'max_tokens'      => 2048,
    'timeout_seconds' => 30,
    'context'         => 'chat',
}
```

## Response Format

### Success
Backend returns:
```perl
{ success => TRUE, response => "Model response text..." }
```

Chat displays:
```
[05:25:19] [model-name]: Model response text...
```

### Error
Backend returns:
```perl
{ success => FALSE, error => "API key not configured" }
```

Chat displays:
```
[05:25:19] [model-name]: :note: model error:
                          :. error: API key not configured :.
```

## Configuration

### API Key (for kimi/claude)
```perl
## in models.init_code or config
<models.api.key> = 'sk-...your-api-key...';
```

### Local Server Endpoint
Default: `http://localhost:8080` (configured in models.backend.local.invoke)

## Error Handling

All errors are caught and returned with `:. error: ... :.` format:
- `error: model name required`
- `error: message required`
- `error: API key not configured`
- `error: empty response from model`
- `error: unknown backend type`

## Future Enhancements

### Claude API Integration
```perl
## Add to backend_map when ready
'claude' => 'api'

## Implement in models.backend.api.invoke:
if ( $model_id =~ /^claude/ ) {
    ## Use Anthropic API endpoint
    $api_url = 'https://api.anthropic.com/v1/messages';
}
```

### Streaming Responses
For long model outputs, support streaming via STRM-SIZE protocol:
```perl
## Post chunks to chat buffer as they arrive
while ( my $chunk = get_next_chunk() ) {
    <[models.chat.append]>->( undef, $model, $chunk );
}
```

### Model Auto-Selection
```perl
## Based on message content/keywords
if ( $message =~ /:code:/ ) {
    $model = 'kimi';  # Better for code
} elsif ( $message =~ /:analysis:/ ) {
    $model = 'claude';  # Better for reasoning
}
```

## See Also
- `modules/models.chat.invoke_model` - Routing implementation
- `modules/models.backend.api.invoke` - API backend
- `modules/models.backend.local.invoke` - Local backend
- `MULTI-MODEL-CHAT.md` - Chat system overview

## Testing

```bash
## Test mode (no API required)
p7c models.chat test-model "Test message"

## Check for errors
p7c models.chat unknown-model "Test"
# Should return: :. error: ... :.

## View chat buffer
p7c models.chat
# Shows conversation with all models
```
