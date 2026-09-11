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

## session 2 update [ resumed after step-limit ]
- dequant rerun launched [ first attempt killed with CLI session ]
- wiring DONE: zenka.v7 commented keys coding.cfg.lora_adapter/_scale,
  spawn block in src/coding.spawn_inference_server after the cvec block
  [ --lora-scaled verified in common/common.cpp:1707 ], perl -c passes
- run_gens_lora.sh: second held-out set P_D/P_E/P_F x seeds 13/42/7777,
  results-lora/<label>/
- lora_to_gguf.py written; GGUFWriter auto-adds general.architecture from
  arch= [ gguf_writer.py:110 ] -- no extra KV needed beyond
  general.type/adapter.type/adapter.lora.alpha
- dataset ALREADY BUILT in session 1: dataset/sft.jsonl, 403 examples,
  rubric coverage invoke=220 cfgaccess=108 truefalse=187 modedata=93,
  held-out asserts pass [ pair-41 P_A-shape dropped from seeds ]

## session 2 update [ resumed after step-limit ]
- dequant DONE + verified [ 427/427 exact names+shapes, sane values ]
- wiring DONE [ zenka.v7 + spawn block, --lora-scaled verified ]
- run_gens_lora.sh second held-out set [ P_D/P_E/P_F ]
- server stopped for training window [ coding.draining TRUE -> eval-code
  kill worked ; NOTE: plain kill fails, server runs as protocol-7 user ]
- TRAINING ATTEMPT 1 FAILED: loss 14.49 > ln(248320)=12.4 random chance
  -> base model broken. killed.
- mapping bug #1 FOUND+FIXED [ fix_a_log.py ]: GGUF ssm_a is PRECOMPUTED
  -exp(A_log) [ fork's llama-delta-net.cpp:282 uses it raw ] vs HF's
  g=-exp(A_log)*softplus(a+dt) -> A_log=log(-ssm_a), patched 24 tensors
- STILL GARBAGE after fix [ mean loss 15.8, multilingual salad ]
- ruled out : tokenizer [ full 248077-vocab 1:1 match vs GGUF, special
  tokens parse ], tensor shapes [ 427 exact ], residual explosion
  [ hidden norms grow smoothly 0.78->537, no explosion ], embed cosines
  sane, rope/mrope config [ probe identical with/without mrope_section ],
  qkv layout [ C++ splits FLAT q|k|v same as HF -- line 343-362 ],
  full-attn q-gate [ both per-head interleaved 256|256 ]
- ground truth from prod binary [ port 8899 probe ]: next token after
  same prompt = 'Thinking' 0.53 / 'The' 0.42 [ coherent ]
- RUNNING: ablate_probe.py A/B/C [ zero mixers to localize : mlp-only /
  full-attn-only / linear-attn-only ]

## session 2 conclusion [ 2026-09-09, ablation result ]
- ablate_probe.py A/B/C all finished. A [ no mixers ] garbage as expected
  [ uninformative by design -- no attention = no context ]. B [ full-attn
  only ] AND C [ linear-attn only ] BOTH garbage -> corruption is NOT
  isolated to either mixer type, it's in something shared [ embed / norm
  / mlp / lm_head / a global dequant scale ]. per the task's own hazard
  discipline: this is the diffuse case, not the "one fix away" case.
- DECISION: pausing the dequant+PEFT LoRA path here rather than continuing
  to chase a diffuse bug in a from-scratch hybrid-architecture
  dequantizer. handed to an Opus review for an alternative architecture
  that avoids needing an HF-format checkpoint entirely [ the dequant step
  only exists because gradient PEFT requires it -- forward-pass-only
  techniques against the already-correct production GGUF binary don't ].
  see `data/tasks/coding-lora-p7-idioms.md` for the follow-up.
- server state at pause: coding zenka fully stopped [ v7-zenki.terminate,
  not just the drained inference-server child ] -- restart with
  `v7-zenki.start coding` when resuming any GPU-server-dependent work.

## resume checklist [ if session dies again ]
1. read ablate_{A,B,C}.log -> localize broken component
2. fix mapping/config accordingly, re-run sanity_gen.py [ want coherent
   gen + loss ~1.5-3.5 ]
3. retrain [ train_lora.py ], convert [ lora_to_gguf.py ], restart server
   via coding.eval-code spawn [ PROGRESS ops playbook ], validate, restore
4. append results to data/tasks/coding-lora-p7-idioms.md
- server currently STOPPED [ draining flag SET -- must del on restore ]

#,,..,...,,,,,,..,,.,,,..,.,.,...,.,.,..,,.,,,..,,...,..,,,,,,..,,,,.,.,,,,.,,
#HMLWDODKLLSCEKLYWB3BB5FIT35CM5M2UDETD4D2O3373ALNRJWNPIP4CWF5FXHXEENO5BK3RRFQY
#\\\|23WDHLBKTHVXF7M6FPEB2BOYZIRBHVYLVPAPLOXADGUQF7Z2B5Z \ / AMOS7 \ YOURUM ::
#\[7]IZE2DZHGSHJOEHYN7OT6L4ZKPMWL6DVMEJ5Q3Y3IBVH77KPEFODQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
