# Invoke.ai Backend Integration Plan

## Vision: Visual Feedback Loops

```
┌─────────────────────────────────────────────────────────────────────────┐
│                      VISUAL FEEDBACK LOOP                               │
│                                                                         │
│   ┌─────────────┐    generate     ┌─────────────┐    analyze    ┌─────┐ │
│   │ Text Prompt │ ───────────────►│ Invoke.ai   │ ─────────────►│Image│ │
│   │   (LLM)     │                 │  Backend    │               │     │ │
│   └─────────────┘                 └─────────────┘               └──┬──┘ │
│         ▲                                                          │    │
│         │                    describe/feedback                     │    │
│         └──────────────────────────────────────────────────────────┘    │
│                              (lm-vision.analyze_image)                  │
└─────────────────────────────────────────────────────────────────────────┘
```

## Use Cases

1. **Network Kittens** - Already rendering, need backend integration
2. **Visual Evolution** - Generate → Analyze → Mutate prompt → Regenerate
3. **Style Transfer Loops** - Iterative refinement via vision analysis
4. **Content Filtering** - Generate → Safety check → Publish/Retry
5. **Responsive Graphics** - Network state visualization

---

## Architecture

### Backend Module: `models.backend.invoke.generate`

```perl
## [:< ##
# name  = models.backend.invoke.generate
# descr = generate image via Invoke.ai HTTP API

params:
  prompt          => "cute network kitten with...",
  negative_prompt => "blurry, low quality...",
  width           => 1024,
  height          => 1024,
  steps           => 30,
  cfg_scale       => 7.5,
  lora            => [ { name => "cute-style", weight => 0.8 }, ... ],
  model           => "sd-xl-base",  # or model stack
  seed            => 12345,         # optional, random if not set

  ## For feedback loops
  reply_id        => "...",         # async callback
  analysis_chain  => TRUE,          # auto-analyze with lm-vision
```

### Response Flow

```
1. models.backend.invoke.generate
        ↓ HTTP POST to Invoke.ai
2. Wait for generation (async via AnyEvent::HTTP)
        ↓
3. Receive image path/URL
        ↓
4. models.handler.invoke_result
        ↓
5. Option A: Return to caller
   Option B: Auto-analyze with lm-vision (feedback loop)
        ↓
6. lm-vision.analyze_image → description
        ↓
7. models.chat.append or LLM process → new prompt
        ↓
8. Loop or complete
```

---

## Invoke.ai API Integration

### Endpoints

```
## Text-to-Image
POST /api/v1/images/generate

## Request body
{
  "prompt": "cute network kitten with...",
  "negative_prompt": "blurry, low quality",
  "width": 1024,
  "height": 1024,
  "steps": 30,
  "cfg_scale": 7.5,
  "scheduler": "euler",
  "model": {
    "model_name": "sd-xl-base",
    "base_model": "sdxl"
  },
  "loras": [
    { "lora_name": "cute-style", "weight": 0.8 }
  ]
}

## Response
{
  "images": [
    {
      "image_name": "abc123.png",
      "image_url": "/api/v1/images/abc123.png",
      "width": 1024,
      "height": 1024,
      "seed": 12345
    }
  ]
}
```

### Configuration

```yaml
## data/yaml/models/invoke.yaml
invoke:
  server_url: http://127.0.0.1:9090

  ## Default generation params
  defaults:
    width: 1024
    height: 1024
    steps: 30
    cfg_scale: 7.5
    scheduler: euler

  ## Available models/stacks
  models:
    sd-xl-base:
      name: "Stable Diffusion XL"
      base_model: sdxl

    sd-1.5-anime:
      name: "Anime Style"
      base_model: sd_1_5

  ## Available LoRAs
  loras:
    cute-style:
      file: cute_network_kittens_v1.safetensors
      trigger: "cute style"

    cyberpunk:
      file: cyberpunk_neon_v2.safetensors
      trigger: "cyberpunk aesthetic"
```

---

## Implementation Phases

### Phase 1: Basic Text-to-Image (Current)

- [ ] `models.backend.invoke.generate` - HTTP POST to Invoke.ai
- [ ] `models.handler.invoke_result` - Handle completion
- [ ] Configuration loading from YAML
- [ ] Basic parameters: prompt, width, height, steps

### Phase 2: Advanced Parameters

- [ ] LoRA support (list with weights)
- [ ] Model stack selection
- [ ] Negative prompts
- [ ] CFG scale, scheduler options
- [ ] Seed control (random vs fixed)

### Phase 3: Feedback Loop Integration

- [ ] Auto-analyze option (`analysis_chain => TRUE`)
- [ ] Integration with `lm-vision.analyze_image`
- [ ] Prompt mutation from analysis
- [ ] Iterative generation chains

### Phase 4: Native Backend (Future)

- [ ] ComfyUI-like node graph execution
- [ ] LoRA loading/unloading
- [ ] Model stack management
- [ ] Custom pipelines

---

## Code Structure

### New Files

```
src/
├── models.backend.invoke.generate    # Main generation backend
├── models.handler.invoke_result      # Result handler
├── models.callback.invoke_analyze    # Feedback loop callback
├── models.config.invoke              # Config loader
└── models.cmd.generate_image         # User-facing command

data/yaml/models/
├── invoke.yaml                       # Invoke.ai configuration
└── invoke-models/                    # Model definitions
    ├── sd-xl-base.yaml
    └── loras/
        ├── cute-style.yaml
        └── cyberpunk.yaml
```

### Integration Points

| Module | Purpose |
|--------|---------|
| `lm-vision.cmd.analyze_image` | Analyze generated images |
| `models.chat.invoke_model` | Could trigger generation via special prefix |
| `coding.task.queue` | For batch generation jobs |

---

## Example Usage

### Simple Generation

```bash
# Generate a network kitten
./bin/v7 -c models << 'EOF'
cmd: models.backend.invoke.generate
params:
  prompt: "cute network kitten with glowing circuit patterns, digital art"
  width: 1024
  height: 1024
  reply_id: "kitten_gen_001"
EOF
```

### With LoRA

```yaml
params:
  prompt: "cute network kitten <cute-style>"
  loras:
    - name: cute-style
      weight: 0.8
```

### Feedback Loop

```bash
# Generate → Analyze → Report
./bin/v7 -c models << 'EOF'
cmd: models.backend.invoke.generate
params:
  prompt: "abstract network topology visualization"
  analysis_chain: true
  analysis_prompt: "describe the visual patterns and colors"
  reply_id: "feedback_loop_001"
EOF

# Result: Image + "The image shows interconnected nodes in blue and purple..."
```

---

## Technical Considerations

### 1. File Storage

```
var/invoke-generated/           # Generated images
├── 2026-03-03/
│   ├── kitten_001.png
│   └── abstract_002.png
└── thumbnails/                 # For chat preview
```

### 2. Async Handling

Invoke.ai generation can take 10-60 seconds depending on:
- Model size
- Steps count
- Hardware (GPU VRAM)

**Solution**: Same pattern as local.invoke
- AnyEvent::HTTP for non-blocking
- Deferred reply with `reply_id`
- Progress tracking if Invoke.ai provides it

### 3. Error Handling

| Error | Handling |
|-------|----------|
| Invoke.ai not running | Log error, suggest starting |
| Out of VRAM | Retry with smaller resolution |
| Model not found | List available models |
| Generation timeout | Cancel, report partial |

### 4. Resource Management

- Clean up old generations (configurable retention)
- Throttle requests (max concurrent generations)
- Queue system for batch processing

---

## Comparison: Invoke.ai vs Future Native

| Feature | Invoke.ai | Native (Future) |
|---------|-----------|-----------------|
| Setup | External service | Built-in |
| VRAM | Uses Invoke's GPU | Uses system GPU |
| LoRAs | Full support | Partial (priority) |
| ControlNet | Yes | Maybe |
| Complexity | High | Medium |
| Speed | Network latency | Local (faster) |
| Dependencies | Invoke.ai install | Python + torch |

---

## Next Steps

1. **Review this plan** - Any changes to scope?
2. **Phase 1 implementation** - Basic text-to-image
3. **Test with your Invoke.ai** - Verify API endpoints
4. **Iterate** - Add LoRAs, feedback loops

Ready to start Phase 1 when you are! 🎨

---

#,,,.,,.,,,,.,,.,,..,,,,.,...,,,.,,..,.,.,..,,.,.,...,..,,...,..,,,,.,.,.,,,,,
#HFPQDBXSA76MF4XRSZ7HAAWRZB2UQ4NLFSMDSNB4E2YSYVJ6ZHAV6EMZIX6XRNGIQDYZGJN4KVOUA
#\\\|DJO24GRWA5R6NLFWW73OZQ6X6EWWIUR4PO5ZV6JWZARN7FJABQ2 \ / AMOS7 \ YOURUM ::
#\[7]QBUBFFDLTFQFMV3PFPRFVGOT24ZDEIOYH5AMH73MYAHR3QWF5QDQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
