#!/usr/bin/python

# test_setup.py
import torch
import whisper
from faster_whisper import WhisperModel

print("=== GPU Check ===")
print(f"CUDA Available: {torch.cuda.is_available()}")
print(f"GPU: {torch.cuda.get_device_name(0) if torch.cuda.is_available() else 'None'}")

print("\n=== Whisper Models ===")
# Standard Whisper
model = whisper.load_model("base")
print(f"Standard Whisper device: {next(model.parameters()).device}")

# Faster Whisper
fast_model = WhisperModel("base", device="cuda", compute_type="float16")
print("✓ Faster Whisper loaded on GPU")

print("\n=== Ready for transcription! ===")
