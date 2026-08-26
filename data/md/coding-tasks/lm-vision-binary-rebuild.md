
 .:[  lm-vision binary rebuild — llama_load_model_from_file  ]:.

## Problem

`lm-vision.analyze_image` fails with:

```
/data/source/ik_llama.cpp/llama-mtmd-cli-cuda-fa: symbol lookup error:
undefined symbol: llama_load_model_from_file
```

## Diagnosis

This is a binary/library ABI mismatch — not a code bug. The compiled
binary `llama-mtmd-cli-cuda-fa` was built against an older version of
the llama.cpp shared library. The function `llama_load_model_from_file`
has since been renamed or removed from the library API in the current
build at `/data/source/ik_llama.cpp/`.

The HTTP backend (`lm-vision.handler.http_analyze`) is unaffected since
it talks to a separately running llama-server process. Only the CLI
backend path triggers this error.

## Fix

Recompile the binary against the current library:

```bash
cd /data/source/ik_llama.cpp

# verify current build target
ls -la llama-mtmd-cli-cuda-fa

# rebuild with CUDA + Flash Attention
cmake -B build -DGGML_CUDA=ON -DGGML_CUDA_FA=ON \
      -DCMAKE_BUILD_TYPE=Release
cmake --build build --target llama-mtmd-cli -- -j$(nproc)

# or if using Makefile:
GGML_CUDA=1 make -j$(nproc) llama-mtmd-cli
```

After rebuild, verify:
```bash
ldd llama-mtmd-cli-cuda-fa | grep llama
nm -D llama-mtmd-cli-cuda-fa | grep llama_load
```

The symbol should resolve, or the new API name should appear instead.

## Notes

- The HTTP backend (coding zenka GPU server) is the preferred path
  anyway and is unaffected by this issue
- `lm-vision.backend = auto` will fall back to CLI — the error occurs
  in that fallback path
- Once rebuilt, set `lm-vision.backend = auto` and both paths work
- If the API changed upstream, check the current llama.cpp header for
  the replacement function name (likely `llama_model_load` or similar)
- Build instructions reference: `data/md/documentation/CUDA-build.md`
  if it exists, otherwise see ik_llama.cpp README

## Priority

Low — HTTP backend works. Fix when rebuilding ik_llama.cpp for other
reasons (model updates, CUDA version, etc.).

#,,.,,,.,,,,.,,,,,...,.,,,,,.,,..,...,...,.,,,..,,...,...,...,..,,,,.,..,,,,,,
#MDC5ZZTLHGV24JZ3JSUG2L47KYHX5YV4RDTKULGGTF5TFBDMOLJKVRZYI5JABBJGLBGSEKIGRZUDG
#\\\|S5URBVILCK55Q6EBSTKD3V2MYOOYE7PHAU273OICSZJWUFBBTQU \ / AMOS7 \ YOURUM ::
#\[7]NMBNF7Q3I762ZCMP7TOAKSBHPM5QHHHOLOEE2335XNJBSORFCGBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
