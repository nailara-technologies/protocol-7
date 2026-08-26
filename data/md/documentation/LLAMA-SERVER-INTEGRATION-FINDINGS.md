# Llama-Server Integration Findings

## Test Summary

Successfully tested ik_llama.cpp server with CPU inference. The HTTP server endpoint is fully functional and responds correctly to inference requests.

### Test Result

**Status**: ✓ **PASS** - HTTP inference endpoint working

**Model Used**: SmolLM 360M (Q8_0 quantization)
**Path**: `/mnt/m/HuggingFaceTB/smollm-360M-instruct-v0.2-Q8_0-GGUF/smollm-360m-instruct-add-basics-q8_0.gguf`
**Binary**: `/usr/local/bin/llama-server` (build 4034)

### Inference Example

```bash
# Request
curl -s -X POST http://localhost:8080/completion \
    -H "Content-Type: application/json" \
    -d '{"prompt": "2+2=", "n_predict": 10}'

# Response
{
  "content":"5\n45+35=70",
  "generated_text":"5\n45+35=70",
  "id_slot":0,
  "stop":true,
  "tokens_predicted":10,
  "tokens_evaluated":4
}
```

## Infrastructure Issues Identified

### 1. CUDA Driver Version Mismatch

**Issue**: `ggml_cuda_init: failed to initialize CUDA: CUDA driver version is insufficient for CUDA runtime version`

**Root Cause**:
- Binary was built with: `CUDA 13.0` (`-DCUDAToolkit_ROOT=/usr/local/cuda-13.0`)
- System NVIDIA Driver: 576.88
- Driver 576.88 supports up to CUDA 12.8/12.9, but not CUDA 13.0

**Build Source**:
```bash
cmake -B build \
    -DCMAKE_BUILD_TYPE=Release \
    -DGGML_CUDA=ON \
    -DGGML_SCHED_MAX_COPIES=1 \
    -DCUDAToolkit_ROOT=/usr/local/cuda-13.0 \
    -DCMAKE_CUDA_COMPILER=/usr/local/cuda-13.0/bin/nvcc

cmake --build build --config Release -j $(nproc)
```

**Solution**: The binary falls back to CPU mode gracefully. GPU acceleration is not currently available, but the HTTP server works correctly with CPU inference.

**Required Fix**: Rebuild with compatible CUDA version:
```bash
# Use CUDA 12.8 (highest compatible with driver 576.88)
-DCUDAToolkit_ROOT=/usr/local/cuda-12.8 \
-DCMAKE_CUDA_COMPILER=/usr/local/cuda-12.8/bin/nvcc
```

**Available CUDA Versions**: 12.3, 12.4, 12.5, 12.6, 12.8, 12.9, 13.0

**Recommended CUDA Version**: 12.8 (maximum compatibility with driver 576.88)

### 2. System HTTP Proxy Interference

**Issue**: curl requests to localhost were being intercepted by system proxy

**Environment**:
```bash
http_proxy=http://10.0.110.7:4040
https_proxy=http://10.0.110.7:4040
ALL_PROXY=socks5://10.0.110.7:1040
```

**Symptoms**:
- Direct TCP/netcat connections to server work fine
- curl HTTP requests fail with connection timeout (HTTP 000)
- Setting `no_proxy=localhost` alone doesn't work

**Solution**: Completely unset proxy environment variables for local testing
```bash
unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY ALL_PROXY all_proxy
export NO_PROXY=localhost,127.0.0.1
```

**Alternative**: Use direct TCP connections or Unix sockets for testing

## Server Configuration

### Tested Startup Parameters
```bash
llama-server \
    -m /path/to/model.gguf \
    -ngl 0              # GPU layers (0 = CPU only for testing)
    -n 30               # Max output tokens
    -b 256              # Batch size
    -c 256              # Context window
    # Server binds to 127.0.0.1:8080 (hardcoded, -p flag is ignored)
```

### Available HTTP Endpoints

- **Health Check**: `GET http://localhost:8080/health`
  - Response: `{"status":"ok","slots_idle":1,"slots_processing":0}`

- **Completion**: `POST http://localhost:8080/completion`
  - Input: JSON with `prompt`, `n_predict`, `temperature`, etc.
  - Output: JSON with generated text and metadata

### Important Notes

1. **Port Binding**: The `-p` flag is currently ignored; server always uses port 8080
2. **Performance**: CPU inference is slow but functional (useful for testing API contract)
3. **Fallback Behavior**: When CUDA initialization fails, server automatically uses CPU - no crash

## Multi-Server Fallback Architecture (Planned)

For coding zenka integration, we need:

1. **Server Registry**: Multiple llama-server variants configured with fallback priority
2. **Health Checking**: Periodic health checks to detect server availability
3. **Automatic Failover**: Route requests to next healthy server if primary fails
4. **Configuration Template**:
   ```
   # cfg/zenki/coding/llama-servers
   servers = [
       { variant: "gpu-optimized", port: 8080, cuda: "12.8", priority: 1 },
       { variant: "cpu-fallback", port: 8081, cuda: "none", priority: 2 }
   ]
   ```

## Test Script Location

For future testing reference:
- `bin/dev/tests/ml/test-llama-server-gpu.sh` - GPU/CPU test script

## Recommendations

1. **Immediate**: Use CPU inference for testing until CUDA compilation is fixed
2. **Short-term**: Recompile ik_llama.cpp with compatible CUDA version (12.8 or earlier)
3. **Medium-term**: Implement multi-server registry in coding zenka for fallback support
4. **Long-term**: Consider Unix socket transport for production (avoids proxy/port issues)

#,,,,,,,,,,..,,,,,,..,.,.,,,.,,,,,..,,...,,.,,..,,...,...,.,,,,.,,..,,.,,,,..,
#TOUZKGSOCEKISSVKMFVHWHL2P3UJ6XOXGZBVSCUDQOXM4GT56J7WE7EEVTWAGDAGJYAZUCTGCJRTS
#\\\|5QTIILVNOCLIW4PKE7FXS2I5XPMP5BGRAZUBZ3DNOVCLLDJT6YB \ / AMOS7 \ YOURUM ::
#\[7]ZIJAJ45DX3CPT6IDV5U2WC6WBQ47SRK2EKGQNWWFALW34I67POBA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
