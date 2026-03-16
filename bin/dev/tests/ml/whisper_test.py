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

#,,,.,...,,..,,,,,,,,,.,.,,.,,,,.,,..,,,,,...,..,,...,...,...,,,.,,..,,.,,,.,,
#FOABOPS745SYR726CEPMWS35OW2UWQN3T4ZJWZQ2ZFN5JRSUKBYI5GAL6I2YFEGFG6QJQVA6CDVPO
#\\\|H3MACGRNPQBAX52GREOUVF5NYBHIAXMPNOGVRGJLY6GVDVEQQ7N \ / AMOS7 \ YOURUM ::
#\[7]C3RO647FIXAHN2VQRFOD7G6UJW3YZRXCUR4PN2VNVGX47DGX2ECY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
