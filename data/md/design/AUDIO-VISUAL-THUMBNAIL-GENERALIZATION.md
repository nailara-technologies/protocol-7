# audio → visual thumbnail: generalization notes

## context

surfaced while scoping `data/tasks/audio-waveform-visualization.md` (the
purr/signal → holographic standing-wave renderer described in
`SPATIAL-AUDIO-AND-PURR-CHANNEL.md`). these are design reasonings that
outlive that one task — they apply to any "audio sample → representative
image" primitive built on the same renderer, not just purrs.

---

## generalizes beyond purrs

the FFT → standing-wave renderer has nothing purr-specific in it — a purr
is just an audio file with an entity_id and a grid coordinate attached.
the same rendering step applies directly to any audio sample: a visual
fingerprint/thumbnail for a psytrance track, or any other audio file that
wants a representative image. what differs per use-case is only the layer
*around* the renderer — what the image is keyed by and stored against
(entity_id + grid coordinate for a purr; a content checksum for a
track-thumbnail cache) — not the rendering step itself. keep the core
render function free of purr-only assumptions [ no entity_id/fade-by-
relevance baked into the image generation ] so it stays reusable as a
generic "audio → psychedelic thumbnail" primitive underneath both.

## quality bar: style coherence over recognizability

the target is diversity and project style [ psychedelic, consistent with
the rest of the grid/holographic visual language ] over literal signal
fidelity or per-track recognizability. there's no fixed correctness
criterion for the mapping from audio to image — the exact
frequency→shape→color parameters can be tuned per use-case until the
output looks right for that context. recognizability comes from repeated
exposure to visually-coherent, sufficiently-varied output, not from the
mapping being an exact or literal representation of the signal.

## segmentation is upstream, not the renderer's concern

recognizing distinct units in an endless audio stream [ silence gaps, or
other attribute-based boundaries ] is a real factor for making a stream of
generated images distinguishable from each other over time — but that
segmentation happens on the input side, chunking a continuous stream into
the discrete audio buffers a renderer receives one at a time. the renderer
itself takes a single buffer/file and produces one image; it is not
responsible for finding boundaries in a continuous stream, and nothing
about its output should be expected to encode or guarantee that grouping.

related prior art for that upstream side: external tools like
`streamripper` do exactly this kind of stream-to-track segmentation, and
the radio zenka already has related work of its own —
`radio.filter.jingle`, `radio.cmd.jingle-log`, `radio.gap_fill.*` detect
jingles and silence gaps in a live stream. none of that is wired to any
renderer today, but it's the natural upstream source if/when segmentation
feeding one is built.

worth flagging even for that upstream work: tracks are frequently
crossfaded into each other, so raw stream-cut boundaries from silence/gap
detection won't line up consistently — the same track sampled from two
differently-ordered playlists can get a different amount of the
neighboring track bleeding into its boundaries each time. producing a
matching image for "the same track" reliably would need some boundary
normalization [ trimming to a stable core region, not just the raw
detected cut points ] on top of segmentation alone. that normalization
work is also upstream of any renderer, not something the renderer itself
compensates for.

#,,.,,.,.,,,,,,,.,.,,,.,,,,.,,.,,,.,.,,.,,..,,..,,...,..,,.,.,,.,,,,,,,.,,,,,,
#4OC3RPMQVKUHMIMIGMKSIHSNOTRQAR7XAEXIN467A62NEFURMUK2ZDAKDKN6KA45HEUIXY5JZ2V6Q
#\\\|OEJEKZLJKIC6KBDM7733JJMLHOZYDAXEK5L2ZUF5PVYHFJ3RFTE \ / AMOS7 \ YOURUM ::
#\[7]JKVUG4FEGQNJPIJCZWJQ3WTGGDCBUQAOFEN4DDNFHW7VABRTQGCI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
