## task: fix v3 phase shift-instability, prototype v4 (temporal variance)

### origin

kimi K3 independent code review, 2026-07-27, of the landed
`audio.render_standing_wave.{v1,v2,v3}` styles (see
`data/ai-mem/claude/topic-audio-render-as-similarity-feature-source.md`
for the full review and the design-reasoning corrections it also
produced — this file is just the two concrete, actionable items split
out from that vision-track note).

### 1. v3's absolute-phase ring placement is not shift-invariant (bug)

`audio.render_standing_wave.v3` anchors ring centers to each low-band
peak's absolute FFT phase (`atan2` of one representative window). FFT
phase rotates by `2πfΔt` under any time-shift of the same content — so
the *same audio content*, re-segmented starting from a different offset
(e.g. sampled from two different points in a longer stream, or from two
differently-ordered playlists crossfading into it), renders at a
different position under v3 despite being the same signal. this is
exactly the crossfade/differently-segmented-stream instability already
flagged as an upstream concern in
`data/md/design/AUDIO-VISUAL-THUMBNAIL-GENERALIZATION.md`'s
"segmentation is upstream" section — except it turns out to also exist
*inside* v3's own placement mechanism, not just as a hypothetical
upstream chunking problem.

**fix**: use phase *differences between adjacent peaks* (relative phase)
for placement instead of each peak's absolute phase. relative phase
between two bins in the same spectrum is shift-invariant (both rotate by
the same amount under a time shift, so their difference doesn't change),
while preserving the same "content genuinely determines placement, not
just density" goal v3 was built for. not yet implemented — this file is
the record, not the fix.

### 2. v4 idea: per-window energy variance (temporal information)

all three current styles (v1/v2/v3) share one root limitation: averaging
all ~96 Hann windows into a single magnitude spectrum before any
rendering happens discards all temporal/rhythmic information —
specifically the ~25Hz amplitude modulation that's structurally what
defines a purr's character (or any rhythmic/pulsing audio content more
generally). every style built on top of this shared front-end inherits
the same blind spot regardless of how its geometry differs.

**proposed v4**: before averaging windows away, compute per-window
band-energy *variance* (how much a band's energy fluctuates across the
~96 windows, not just its mean) and map that variance to a new visual
parameter — e.g. dash/gap patterns on the ring strokes (steady tone =
solid ring outline, pulsing/modulated energy = dashed, dash frequency or
gap ratio tracking modulation rate). this is cheap: the per-window FFT
results already exist in the current pipeline, right before they get
summed into `$acc` and thrown away — capturing variance alongside the
existing mean requires no additional FFT computation, just retaining a
second running statistic during the same loop.

this would be the first style to carry genuinely new information rather
than a geometry variant of the same three numbers (`e_low`/`e_mid`/
`e_high`) — relevant both on its own merits and for the similarity-signal
idea in the linked vision note, which specifically needs analysis
diversity (not just geometry diversity) to be meaningful.

### not in scope here

the broader corrections to the similarity-signal reasoning (checksum
analogy overstating current independence) are design-level, not a code
task — see the vision note for that discussion. this file is just the
two concrete, buildable items.

#,,,.,,,.,...,.,.,,,.,,,.,,,.,..,,,..,,.,,,,.,..,,...,..,,..,,.,,,...,,..,.,,,
#ERD2XYEFF4XH6FAVPBX64A45CVYYUOZ4D463IYFDPYWBSXQLEY4ITQH2MFHTMOJKYBNLLL7SHAVS6
#\\\|B66JKYZCXABERDQUI6V2QQMSXDVHDDOG6XWXCL3SWVTX3Q2ZWUV \ / AMOS7 \ YOURUM ::
#\[7]MUISXVMBDPRCR5ROCVPSGYMLPEX2QSFJD747NWCNAPUAT6KV5SCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
