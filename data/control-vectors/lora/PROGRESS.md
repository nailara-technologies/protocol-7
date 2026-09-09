# LoRA task progress [ 2026-09-09 ]

## done
- read task + control-vector addendum, confirmed mechanism/hazards
- live state: llama-server-cuda-fa pid 1261725, 11.87/12.29 GB VRAM, port 8000
- think-block question RESOLVED: qwen3.5-fixed.jinja emits
  `<|im_start|>assistant\n<think>\n` as generation prompt -> training
  assistant targets MUST be `<reasoning>\n</think>\n\n<content><|im_end|>`
- base model: GGUF general.name "Qwen3.8 9B Heretic Uncensored", arch
  qwen35 (hybrid: linear_attn ssm layers + full attn every 4th, 32 layers,
  hidden 4096, n_embd 4096, vocab 248320)
- source HF repo rohit267/Qwen3.8-9B-heretic-uncensored is PRIVATE/404 with
  valid token -> cannot fetch original fp16 checkpoint (task hazard
  confirmed). decision: DEQUANTIZE the exact production i1-Q4_K_M GGUF to
  bf16 safetensors instead -- effective weights at inference are
  dequant(Q4_K_M(W)) = identical tensors to what the adapter will be
  applied against. better match than the lost fp16 original. recorded as
  judgment call.
- training stack: venv at data/control-vectors/lora/.venv :
  torch 2.11.0+cu128 (CUDA ok, RTX 3060 12GB), transformers 5.16.1
  (has Qwen3_5ForCausalLM), peft 0.20.0, bnb 0.50.2, accelerate 1.14.0
- conversion: vendored convert_lora_to_gguf.py has NO qwen35 support
  (gguf-py lacks MODEL_ARCH.QWEN35). plan: minimal custom GGUF LoRA writer
  (only q/k/v/o/gate/up/down tensors, 1:1 name map), verified live via
  --lora-scaled load. deviation to be recorded in results.
- ops playbook (from prev session transcripts):
  coding.set/get/del <key> ; respawn = coding.eval-code
  <[coding.spawn_inference_server]>->({backend=>'gpu',model_path=><inference.model.path>,amos_id=><inference.model.amos_id>})
  ; coding.reload source after editing src/
- training-window stop: set coding.draining TRUE (crash_restart skips),
  kill -KILL -<pgid>, verify VRAM; restore = respawn + del draining

## pre-registered training config [ hazard 4, decided BEFORE training ]
- rank 16, alpha 32, dropout 0.0 ; target q,k,v,o,gate,up,down proj
  (all 32 layers mlp + 8 full-attn layers attn)
- rationale: idioms are low-entropy token-sequence substitutions -> small
  rank; upper end of the task's 8-16 band because 4 of 8 rubric idioms are
  multi-token precise sequences. ONE shot, no eval-set tuning.
- QLoRA 4-bit NF4, lr 2e-4 cosine, 3 epochs, seq 1024, batch 2 x accum 8
- dataset target ~350 examples, assistant-target-only loss incl. think span

## todo
- dequant GGUF -> HF bf16 checkpoint [ after server stop ]
- dataset build + held-out exclusion check
- train, convert, wire, validate, restore, write results
