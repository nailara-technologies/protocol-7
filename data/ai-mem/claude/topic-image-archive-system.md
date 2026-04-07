---
name: image archive and quality scoring system
description: vision-scored tiered image storage with metadata-embedded thumbnails enabling full regeneration, model dependency tracking, and 60-70% storage reduction
type: project
---

## core insight

ai-generated images are deterministic: thumbnail + generation metadata = full image.
invoke already embeds invokeai_metadata JSON chunk in every PNG (prompt, seed,
model, loras, cfg, steps, size, etc.) — extraction pipeline already exists,
just needs preserving through scaling.

## current state

- 47182 output images, 81 GB total
- invoke thumbnails alone: 567 MB
- target: free ~63+ GB while keeping best images at full resolution

## tiered storage by vision llm quality score

- high quality    → full res, lossless or light pngquant
- medium          → scale 50%, pngquant, full metadata preserved
- low / defects   → thumbnail ~512px, pngquant, metadata preserved
- reject          → smallest thumbnail, flagged for human review

## vision llm scoring criteria

- anatomical correctness (finger count, limb structure, face geometry)
- composition and framing quality
- artifact detection (blurry regions, text artifacts, merged forms)
- structured defect report stored back into PNG metadata:
  `"defects": ["extra_finger", "face_distortion"]`
  so user knows WHY it was downgraded and what to fix

## full regeneration from thumbnail

read PNG → extract invokeai_metadata JSON → submit to invoke API
with original parameters → full resolution image reproduced exactly

## model checksum requirement

seed determinism assumes identical model weights. store model checksum
(not just name) in metadata alongside model key. if model is updated or
quantized, regeneration produces different image — checksum flags this.

## model ↔ image dependency graph

this system makes model manager "safe to archive" decisions computable:
"this model is referenced by 12 images, 10 scored below 0.3 — safe to
archive with their thumbnails"

connects directly to topic-invoke-model-manager.md archive feature:
do NOT remove model if referenced by high-quality images at full res.

## implementation path

1. invoke-image-audit: scan images, extract metadata, build dependency db
2. vision zenka quality scoring pass (batch, offline)
3. invoke-image-archive: tier images, scale + pngquant, update metadata
4. invoke-model-manager integration: model safe-to-archive check uses image db
5. invoke-image-restore: from thumbnail → regenerate via invoke API

## output image management scope note

47K+ images at varying quality is not manageable without vision llm assistance.
quality scoring, culling, provenance, and defect detection all require it.

#,,..,...,...,,..,.,,,,,,,.,.,,,,,..,,.,.,,.,,..,,...,...,..,,,.,,..,,,,,,...,
#RMPBI57D6VGHHFNKQMCXTJHO6BPZ37WUJIEQZKXKIF2NODWWYUFKSO5KTN4O4VSRG546CWWTYQHEY
#\\\|GU5NLSQ6KUWEPVHURXSWTEZCWC2G46X6H4LRUPWFD76WD4ABRXW \ / AMOS7 \ YOURUM ::
#\[7]H4KWJY5UCJNUC6GRK52XAH2XRZOL7VVAG4U6M3TYRYTGOZ5NFOBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
