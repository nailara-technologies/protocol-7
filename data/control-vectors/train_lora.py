#!/usr/bin/env python3
"""train a LoRA adapter so the coding zenka's model reliably emits p7's
structural idioms -- see data/tasks/coding-lora-p7-idioms.md for the full
decision record (dataset scope, rank/target-module choice, loss-masking
hazard). invoked as a child process by src/coding.lora_train_spawn, which
parses this script's stdout as single-line JSON progress events (see
log_json below) -- keep that contract if editing.
"""

import argparse
import json
import sys
import time

import torch
from torch.utils.data import Dataset
from transformers import (
    AutoTokenizer,
    AutoConfig,
    Qwen3_5ForCausalLM,
    BitsAndBytesConfig,
    Trainer,
    TrainingArguments,
    TrainerCallback,
)
from peft import LoraConfig, get_peft_model, prepare_model_for_kbit_training

## the runtime jinja (data/jinja/templates/qwen3.5-fixed.jinja) always opens ##
## `<think>\n` before the model's own generated tokens start (enable_       ##
## thinking defaults true, confirmed live 2026-09-10) -- the closer below   ##
## must match exactly what the model itself would have to emit at inference ##
## time before its real answer, so training data reproduces the same       ##
## boundary the live server actually presents                              ##
THINK_OPEN   = "<think>\n"
THINK_CLOSER = "\n</think>\n\n"
ASSISTANT_MARKER = "<|im_start|>assistant\\n"  ## literal 2-char \n in the dataset file, see below ##


def log_json(**kwargs):
    print(json.dumps(kwargs), flush=True)


def unescape(text):
    ## the dataset file stores literal backslash-n (2 chars) as a plain-text ##
    ## stand-in for newlines within one physical line per example -- NOT    ##
    ## real newline bytes (confirmed: wc -l == example count, not line      ##
    ## count within examples) -- convert back before tokenizing             ##
    return text.replace("\\n", "\n")


def load_examples(paths):
    examples = []
    for path in paths:
        with open(path, encoding="utf-8") as f:
            for line in f:
                line = line.rstrip("\n")
                if not line.strip():
                    continue
                if ASSISTANT_MARKER not in line:
                    log_json(event="error", message=f"skipping malformed line (no assistant marker) in {path}")
                    continue
                prefix_raw, content_raw = line.split(ASSISTANT_MARKER, 1)
                prefix_text = unescape(prefix_raw) + "<|im_start|>assistant\n"
                content_text = unescape(content_raw)
                examples.append((prefix_text, content_text))
    return examples


class IdiomDataset(Dataset):
    def __init__(self, examples, tokenizer, max_length=768):
        self.tokenizer = tokenizer
        self.max_length = max_length
        self.rows = []
        for prefix_text, content_text in examples:
            prefix_full = prefix_text + THINK_OPEN
            masked_span = THINK_CLOSER
            loss_span = content_text + tokenizer.eos_token

            prefix_ids = tokenizer(prefix_full, add_special_tokens=False)["input_ids"]
            masked_ids = tokenizer(masked_span, add_special_tokens=False)["input_ids"]
            loss_ids = tokenizer(loss_span, add_special_tokens=False)["input_ids"]

            input_ids = prefix_ids + masked_ids + loss_ids
            labels = [-100] * (len(prefix_ids) + len(masked_ids)) + list(loss_ids)

            if len(input_ids) > max_length:
                ## truncate from the LEFT of the prefix (system/user prompt) ##
                ## rather than dropping any of the loss-bearing target span  ##
                overflow = len(input_ids) - max_length
                input_ids = input_ids[overflow:]
                labels = labels[overflow:]

            self.rows.append({"input_ids": input_ids, "labels": labels})

    def __len__(self):
        return len(self.rows)

    def __getitem__(self, idx):
        return self.rows[idx]


def collate(batch, pad_token_id):
    max_len = max(len(r["input_ids"]) for r in batch)
    input_ids, labels, attn = [], [], []
    for r in batch:
        pad_len = max_len - len(r["input_ids"])
        input_ids.append(r["input_ids"] + [pad_token_id] * pad_len)
        labels.append(r["labels"] + [-100] * pad_len)
        attn.append([1] * len(r["input_ids"]) + [0] * pad_len)
    return {
        "input_ids": torch.tensor(input_ids, dtype=torch.long),
        "labels": torch.tensor(labels, dtype=torch.long),
        "attention_mask": torch.tensor(attn, dtype=torch.long),
    }


def build_target_modules(model):
    """
    exact-name introspection, not bare-suffix target_modules strings --
    a plain suffix like 'gate_proj' would ALSO match mtp.layers.*.mlp.
    gate_proj (same leaf name, different subtree) via peft's own suffix
    matching. walk the real named_modules() and keep only leaves whose
    full dotted path contains neither 'mtp' nor 'visual' as a path
    component -- see coding-lora-p7-idioms.md hazard 4's re-decided
    target-module section, decided against the real checkpoint's weight
    map, not assumption.
    """
    leaf_names = {
        "q_proj", "k_proj", "v_proj", "o_proj",
        "gate_proj", "up_proj", "down_proj",
        "in_proj_qkv", "in_proj_a", "in_proj_b", "in_proj_z", "out_proj",
    }
    excluded = {"mtp", "visual"}
    targets = []
    for name, _module in model.named_modules():
        leaf = name.rsplit(".", 1)[-1]
        if leaf not in leaf_names:
            continue
        if any(part in excluded for part in name.split(".")):
            continue
        targets.append(name)
    return targets


class JsonProgressCallback(TrainerCallback):
    def on_log(self, args, state, control, logs=None, **kwargs):
        if logs is None or "loss" not in logs:
            return
        log_json(
            event="progress",
            step=state.global_step,
            total_steps=state.max_steps,
            epoch=state.epoch,
            loss=logs["loss"],
        )


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--base-checkpoint", required=True)
    p.add_argument("--dataset", required=True, nargs="+")
    p.add_argument("--out-dir", required=True)
    p.add_argument("--epochs", type=int, default=3)
    p.add_argument("--lr", type=float, default=2e-4)
    p.add_argument("--batch-size", type=int, default=1)
    p.add_argument("--grad-accum", type=int, default=8)
    p.add_argument("--rank", type=int, default=16)
    p.add_argument("--alpha", type=int, default=32)
    p.add_argument("--dropout", type=float, default=0.05)
    p.add_argument("--max-length", type=int, default=768)
    args = p.parse_args()

    t0 = time.time()

    try:
        tokenizer = AutoTokenizer.from_pretrained(args.base_checkpoint)
        cfg = AutoConfig.from_pretrained(args.base_checkpoint)
        text_cfg = cfg.get_text_config() if hasattr(cfg, "get_text_config") else cfg

        bnb = BitsAndBytesConfig(
            load_in_4bit=True,
            bnb_4bit_quant_type="nf4",
            bnb_4bit_compute_dtype=torch.bfloat16,
            bnb_4bit_use_double_quant=True,
        )

        log_json(event="progress", step=0, total_steps=0, epoch=0, loss=0.0)
        model = Qwen3_5ForCausalLM.from_pretrained(
            args.base_checkpoint,
            config=text_cfg,
            quantization_config=bnb,
            device_map={"": 0},
            dtype=torch.bfloat16,
        )
        model.config.use_cache = False
        model = prepare_model_for_kbit_training(model, use_gradient_checkpointing=True)

        target_modules = build_target_modules(model)
        if not target_modules:
            log_json(event="error", message="build_target_modules found zero targets -- refusing to train an un-adapted model")
            sys.exit(1)
        if any("mtp" in t or "visual" in t for t in target_modules):
            log_json(event="error", message="target_modules leaked mtp/visual entries -- aborting")
            sys.exit(1)

        lora_cfg = LoraConfig(
            r=args.rank,
            lora_alpha=args.alpha,
            lora_dropout=args.dropout,
            target_modules=target_modules,
            task_type="CAUSAL_LM",
        )
        model = get_peft_model(model, lora_cfg)

        trainable, total = model.get_nb_trainable_parameters()
        log_json(
            event="progress", step=0, total_steps=0, epoch=0, loss=0.0,
        )
        print(
            json.dumps(
                {
                    "event": "config",
                    "target_module_count": len(target_modules),
                    "trainable_params": trainable,
                    "total_params": total,
                }
            ),
            flush=True,
        )

        examples = load_examples(args.dataset)
        if not examples:
            log_json(event="error", message="dataset produced zero usable examples")
            sys.exit(1)

        dataset = IdiomDataset(examples, tokenizer, max_length=args.max_length)

        pad_id = tokenizer.pad_token_id if tokenizer.pad_token_id is not None else tokenizer.eos_token_id

        training_args = TrainingArguments(
            output_dir=args.out_dir,
            num_train_epochs=args.epochs,
            per_device_train_batch_size=args.batch_size,
            gradient_accumulation_steps=args.grad_accum,
            learning_rate=args.lr,
            bf16=True,
            logging_steps=1,
            save_strategy="no",
            report_to=[],
            optim="paged_adamw_8bit",
        )

        trainer = Trainer(
            model=model,
            args=training_args,
            train_dataset=dataset,
            data_collator=lambda batch: collate(batch, pad_id),
            callbacks=[JsonProgressCallback()],
        )

        trainer.train()

        adapter_path = f"{args.out_dir}/adapter"
        model.save_pretrained(adapter_path)
        tokenizer.save_pretrained(adapter_path)

        final_loss = trainer.state.log_history[-1].get("loss") if trainer.state.log_history else None

        log_json(
            event="complete",
            adapter_path=adapter_path,
            final_loss=final_loss,
            elapsed_s=time.time() - t0,
        )
    except Exception as exc:  # noqa: BLE001 -- top-level guard so the parent zenka gets a structured error, not a bare traceback on stderr
        log_json(event="error", message=str(exc))
        raise


if __name__ == "__main__":
    main()

#,,.,,,.,,,..,..,,..,,,,,,,,,,...,.,.,,..,,..,..,,...,..,,...,.,,,,,,,,,.,,.,,
#6X3W3AWQF2ZO7AY3IIMRMZC4MOLTMGS7YBU7DKIL7C7LDV24HHT26DOGPPAPQICZJKGQTHSAYNHGS
#\\\|DJ5JSZFJI2VI3IIDZ6FHRFTGTCJSINOLTVQNN5QCZEWQIAC7BBL \ / AMOS7 \ YOURUM ::
#\[7]4P7GV6WBRTNVM5X6YV4Z73A2PYNZ2RXDYGA56KFF3GWBZGWAU4BY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
