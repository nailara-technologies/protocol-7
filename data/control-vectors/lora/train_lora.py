#!/usr/bin/env python3
## train_lora.py -- QLoRA fine-tune for protocol-7 coding idioms.          ##
##                                                                         ##
## pre-registered config [ task hazard 4 : decided BEFORE training, not    ##
## tuned against the eval set ] :                                          ##
##   rank 16, alpha 32, dropout 0.0                                        ##
##   targets : q/k/v/o proj [ 8 full-attn layers ] + gate/up/down proj     ##
##   [ all 32 layers ] -- the idioms are low-entropy token-sequence        ##
##   substitutions, so a small rank on attn+mlp projections ; upper end    ##
##   of the task's 8-16 band because 4 of 8 rubric idioms are multi-token  ##
##   precise sequences. ONE training run ; no eval-set-driven retuning.    ##
##   QLoRA 4-bit NF4 + double quant [ 12GB card ], lr 2e-4 cosine,         ##
##   3 epochs, seq cap 1024, batch 2 x accum 8 [ effective 16 ]            ##
##                                                                         ##
## chat format [ matches data/jinja/templates/qwen3.5-fixed.jinja with     ##
## thinking enabled, confirmed from source ] : the generation prompt ends  ##
## <|im_start|>assistant\n<think>\n -- so the training TARGET is           ##
## "{think}\n</think>\n\n{content}<|im_end|>" and loss is masked to the    ##
## target span only [ including the think span : the runtime model always  ##
## generates one ].                                                        ##

import json
import sys

import torch
from torch.utils.data import Dataset
from transformers import (AutoModelForCausalLM, AutoTokenizer,
                          BitsAndBytesConfig, Trainer, TrainingArguments)
from peft import LoraConfig, get_peft_model, prepare_model_for_kbit_training

BASE = sys.argv[1] if len(sys.argv) > 1 else "base-model"
DATA = sys.argv[2] if len(sys.argv) > 2 else "dataset/sft.jsonl"
OUT = sys.argv[3] if len(sys.argv) > 3 else "adapter"
MAX_LEN = 1024

LORA_R = 16
LORA_ALPHA = 32
LORA_DROPOUT = 0.0
TARGETS = ["q_proj", "k_proj", "v_proj", "o_proj",
           "gate_proj", "up_proj", "down_proj"]


class SFTData(Dataset):
    def __init__(self, path, tok):
        self.rows = []
        skipped = 0
        for line in open(path):
            ex = json.loads(line)
            prompt = (f"<|im_start|>system\n{ex['system']}<|im_end|>\n"
                      f"<|im_start|>user\n{ex['user']}<|im_end|>\n"
                      f"<|im_start|>assistant\n<think>\n")
            target = f"{ex['think']}\n</think>\n\n{ex['content']}<|im_end|>"
            p_ids = tok(prompt, add_special_tokens=False)["input_ids"]
            t_ids = tok(target, add_special_tokens=False)["input_ids"]
            if len(p_ids) + len(t_ids) > MAX_LEN:
                skipped += 1
                continue
            self.rows.append((p_ids, t_ids))
        print(f"dataset : {len(self.rows)} examples [{skipped} skipped > "
              f"{MAX_LEN} tokens]")
        lens = sorted(len(p) + len(t) for p, t in self.rows)
        print(f"token len p50={lens[len(lens) // 2]} "
              f"p95={lens[int(len(lens) * 0.95)]} max={lens[-1]}")

    def __len__(self):
        return len(self.rows)

    def __getitem__(self, i):
        p, t = self.rows[i]
        ids = p + t
        labels = [-100] * len(p) + list(t)
        return {"input_ids": ids, "labels": labels}


def collate(batch, pad_id):
    width = max(len(b["input_ids"]) for b in batch)
    input_ids, labels, attn = [], [], []
    for b in batch:
        n = len(b["input_ids"])
        pad = width - n
        input_ids.append(b["input_ids"] + [pad_id] * pad)
        labels.append(b["labels"] + [-100] * pad)
        attn.append([1] * n + [0] * pad)
    return {"input_ids": torch.tensor(input_ids),
            "labels": torch.tensor(labels),
            "attention_mask": torch.tensor(attn)}


def main():
    tok = AutoTokenizer.from_pretrained(BASE)
    data = SFTData(DATA, tok)

    bnb = BitsAndBytesConfig(
        load_in_4bit=True,
        bnb_4bit_quant_type="nf4",
        bnb_4bit_use_double_quant=True,
        bnb_4bit_compute_dtype=torch.bfloat16,
    )
    model = AutoModelForCausalLM.from_pretrained(
        BASE, quantization_config=bnb, device_map="cuda",
        dtype=torch.bfloat16)
    model.config.use_cache = False
    ## manual kbit prep [ peft's prepare_model_for_kbit_training OOM'd on  ##
    ## this 12GB card at the fp32 norm-upcast step -- same effect, done    ##
    ## cheaply : gc first, tiny tensors only ]                             ##
    import gc
    gc.collect()
    torch.cuda.empty_cache()
    for name, param in model.named_parameters():
        if param.ndim == 1 and param.dtype in (torch.float16,
                                               torch.bfloat16):
            param.data = param.data.to(torch.float32)
    model.gradient_checkpointing_enable(
        gradient_checkpointing_kwargs={"use_reentrant": False})
    model.enable_input_require_grads()

    lcfg = LoraConfig(r=LORA_R, lora_alpha=LORA_ALPHA,
                      lora_dropout=LORA_DROPOUT, bias="none",
                      target_modules=TARGETS, task_type="CAUSAL_LM")
    model = get_peft_model(model, lcfg)
    model.print_trainable_parameters()

    args = TrainingArguments(
        output_dir=OUT + "-ckpt",
        per_device_train_batch_size=1,   ## [ was 2 : OOM at the 248320-  ##
        gradient_accumulation_steps=16,  ## vocab logit tensor on a 12GB  ##
        ## card. effective batch unchanged [ 16 ] -- memory-driven, not  ##
        ## eval-driven ]                                                ##
        num_train_epochs=3,
        learning_rate=2e-4,
        lr_scheduler_type="cosine",
        warmup_steps=8,   ## [ v5 dropped warmup_ratio ; ~10% of 76 steps ]
        bf16=True,
        logging_steps=10,
        save_strategy="no",
        gradient_checkpointing=True,
        report_to=[],
        seed=13,
    )
    trainer = Trainer(model=model, args=args, train_dataset=data,
                      data_collator=lambda b: collate(b, tok.pad_token_id))
    trainer.train()
    model.save_pretrained(OUT)
    tok.save_pretrained(OUT)
    print(f"adapter saved -> {OUT}")


if __name__ == "__main__":
    main()
