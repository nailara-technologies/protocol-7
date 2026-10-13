---
name: gemma4-12b-agentic-batch-and-swa-planner
description: 2026-10-12 : gemma4 12b agentic v2 [ yuxinlu1 ] harness 4/9 [ fablevibes 9/9, 35b 8/9 ], manual review ~0.5/9 -- not usable for p7 coding ; planner swa fix [ --swa-compress, 8k -> 145k ctx for gemma4 ] uncommitted
metadata:
  type: project
---

**Model** yuxinlu1/gemma-4-12B-agentic-fable5-composer2.5-v2-3.5x-tau2 Q4_K_M, registry
M6H2OBY:4JUAT6I [ hf sha256 verified, yuxinlu1/ dir ]. BVVT5TI:NMUGZJA = a different
unsloth re-quant in super-inference/super-12B-ste-coding/ [ same chat template, other tensors ].

**Batch gemma4-12b-agentic-check** [ cfg/model-batches/, the 3 coding-35b-compare tasks x3 ] :
harness 4/9 [ vs harness 9/9 fablevibes, 8/9 35b ] ; manual review of the passes ~0.5/9 :
- doc 2/3 : run 2 invented [ `$context->get_resume_state`, a "goroutine" ] ; run 3 breaker part correct, restart part wrong [ claims only no_yield persists ; idx \ candidates \ state do ] ; run 1 = file_not_found_spiral loop [ 2 ncode_search 'invalid characters' ], loop check replied the literal `<reason>.`
- edit 1/3 : wrote a NEW src/coding/image-label.pm instead of editing src/coding.image.label, comments dropped
- module 1/3 : src/coding/image/dims_from_header.pl [ path form ], does not compile, POD not ## style -- the 4/4 is false : score.task skips compile for non-flat paths
quick direct prompts : python fine, perl parse_kv did not compile. ~30 t/s gen, 716 t/s pp [ f16 ].
verdict : not usable for p7 coding \ house style ; fablevibes [ edits \ docs ] and 35b [ new code ] stay.

**Planner fix [ uncommitted, needs signed version ]** [ flag only for a gguf with swa layers -- first version put it on every model incl. qwen : dflash archs also react to it ] gemma4 = 40/48 layers sliding window
[ 1024, kv 8x256 ] + 8 global [ kv 1x512 ]. planner counted all 48 at 512 -> 348.5 KB/token,
8214 ctx. ik_llama gives swa layers n_ctx unless --swa-compress [ GEMMA4 in supports_swa_compress ].
extract_attention reads the swa keys ; calculate_safe_context splits global \ swa, fixed window
term [ window + 1024 rows ] with swa_compress ; spawn passes --swa-compress on opt-in
`coding.cfg.swa_compress = yes` [ set in zenka.v7 ]. live : 16 KB/token f16 + 640 MB, 145k ctx,
26k-token prompt ok at 12.0 GB vram. qwen models : no swa keys, unchanged [ OFSQC4I back at 126869 ].

**Open** score.task should flag files written outside flat src/<module.name> [ false 4/4 ] ;
src/coding/image/ left in the tree [ protocol-7 0700, git cannot see inside ] : batch capture \ revert does not restore a write into a NEW subdirectory -- may hold dims_from_header.pl ; ask before removing, may trip the sign \ format run.
CAUSE of the 0700 dir [ fixed 2026-10-13, uncommitted ] : write_new_file made parents directly whenever the
nearest ancestor was writable -> base.file.make_path's strict 0700 default as protocol-7. src/ is not
writable [ acl mask r-x ] so src/coding went through the chmod child [ taeki 0775, inherits default acl
user:protocol-7:rwx ] -> src/coding/image direct, 0700. now chmod child first [ as apply-staged \
scratchpad_rescue ], direct 0775 only without a child ; live-tested [ new dir taeki 0775 ]. files written
directly stay protocol-7 0664 [ unchanged ]. dep-graph \ gen-sub-whitelist abort on the unreadable dir.

#,,..,.,,,,,,,,.,,..,,,.,,,,,,.,,,.,.,.,,,,..,..,,...,...,..,,,..,..,,..,,...,
#SPTXEFHQEWNIOS4T7N4MSOF6SNWUNCD6IJQZMUFW3TYBWYEBCEH53J5ZZ3HD6UGUM4KH5JB7E7DCA
#\\\|Q5HXGHLCJZM7REHELPAE573ZFDKYA4FYCASEVSHH7DKUWX6KFIS \ / AMOS7 \ YOURUM ::
#\[7]XCTLNBHA5RL3EVDWKBISAP33OHSNK7CZIHIFM64MHBDR3FQADIBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

**2026-10-13 : ternary bonsai 2 27b + multi-runtime [ landed this session ]**
- model : prism-ml/Ternary-Bonsai-2-27B-gguf PQ2_0 [ qwen3.8-27b dense hybrid, 6.7 GB ] PP5HZMQ:JQKYA2Y, in
  prism-ml/Ternary-Bonsai-2-27B-gguf/ + mmproj. needs the prismml llama.cpp fork : /data/source/prismml-llama.cpp
  [ prism-b10772-e8fd209, built in docker nvidia/cuda:12.9.1-devel-ubuntu24.04, arch 86, static ggml, binary
  llama-server-cuda + cudart \ cublas 12.9 copies ; host cuda-12.9 has no nvcc ]. build script in session scratchpad
  [ docker run as root + apt cmake, chown build-cuda after ].
- runtime table : inference.runtime.<name>.{binary,lib_path,match} [ zenka.v7 ] -> spawn_inference_server picks
  the build by model file regex ; an explicit params binary EQUAL to the default still matches [ restart_server \
  async spawn pass it -- bonsai restart got the ik binary, exit 1 x5 ]. LD_LIBRARY_PATH follows the runtime.
- mainline-based servers are STRICT : numbers as json strings -> http 400 'type must be number' [ ik accepts ] :
  coding.helper.numify_body [ http_client + http_inference_client, top-level sampler keys only ] ;
  dry_penalty_last_n -1 rejected : coding.helper.dry_last_n [ -1 -> server n_ctx ]. p7-log anonymizer hid the 400
  text as [L:..] -- reproduce requests by hand with curl.
- BLOCKER : bonsai on full gpu gives NaN logits for some prompts [ first-token top ids 0..4, logprob null ->
  '////////' ; coding aborts on degenerate repetition ] -> batch bonsai-27b-check 0/7, cancelled. NOT the model :
  same prompt on cpu [ CUDA_VISIBLE_DEVICES= ] is sane. partial offload [ -ngl 6, q8_0 kv, fa on\off, 75k ctx,
  mmproj ] all clean ; -ot blk blocks inconclusive [ 'layer N assigned to CPU but fused GDN on CUDA0' ].
  suspects : fused gated delta net cuda kernels or a pq2_0 sm86 kernel. next : full-gpu bisect [ needs coding off
  the gpu ~15 min ], then an upstream issue. not prompt cache, not sampling, not tools, not the jinja template.
- discovery : local_discover skips 'mmproj' anywhere ; extract_name prefers the <name>-GGUF dir when metadata
  diverges [ name_diverges ], quant suffix stripped -- 14 of 82 names changed [ diffed ], mostly corrections.
  stale registry entry VKIXTQA:TJF37JQ [ old mmproj-as-model, rescans never prune ].
- fetch-files : zenka.v7 loads external-inference-models [ base.models_root fell back to /data/models since
  990f88f39 ] ; hf-download default <root>/<publisher>/<repo> ; hf-remove drops empty repo + publisher dirs.
- write_new_file : parents through the chmod child first [ direct make_path = 0700 protocol-7 -> src/coding/image ].
- open : spawn race on switch back [ pending-switch spawn + crash-restart both bind 8000 : 2 crashes, attempt 3 ok ] ;
  model_batch.blob.restore:33 still make_dir 0700 default ; tmp/p7_modules [ empty, model debris, 0700 ] ;
  gemma4 copies removal approved 2026-10-13.

#,,.,,,,,,,,.,,,,,.,.,,,,,..,,,,.,.,,,.,.,.,,,..,,...,...,,..,.,,,,,,,...,,..,
#J4IEKZHH4SYZB5RMC637NOCIYDI6UJB5SRYNLCWSQXOGNWGWBA5PMC2C4LTUROD6NVY6BGAFN2G2G
#\\\|RAQSFYUPAQVR5CC5667IMA3KYKGLM7WVKRVJMNR4TQ7VXF2WOBU \ / AMOS7 \ YOURUM ::
#\[7]KBGOU27WM4QI525B75KX6TUZE6XYMMDUHN7QO3TCCM7LIHWQ22BI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
