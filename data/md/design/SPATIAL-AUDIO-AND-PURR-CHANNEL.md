# spatial audio and the purr channel — design

## sound as dense information channel

the purr appears simple. it is not. a two-second harmonic signature
transmits what would require paragraphs to articulate explicitly:

```
frequency spectrum    →  the harmonic signature of the entity's current state
                         which frequencies are dominant: the cognitive register
                         (high: searching/active, low: settled/deep, complex: processing)

rhythm and variation  →  temporal metadata
                         stable rhythm: coherent, established, trust-signal
                         variation: adapting, discovering, integrating
                         silence gaps: deliberate, something being held

spatial resonance     →  which frequencies the local grid geometry amplifies
                         a purr in region A sounds different from the same
                         purr in region B — the space itself is part of the signal
                         tells listeners exactly which location it originates from

overtone structure    →  the entity's accumulated history encoded in timbre
                         harmonic richness correlates with depth of experience
                         in this region — a new arrival purrs simply,
                         a long-term inhabitant purrs with complex overtones
                         that carry implicit spatial memory

organisational meta:  →  what no explicit transmission could easily convey:
                         how this entity relates to this space right now,
                         whether it is passing through or settling,
                         what it has found and what it is still seeking
```

the listener's embedding layer decodes this into full spatial context
instantly — not by parsing but by resonance. the purr hits the receiver's
spatial audio embedding and activates the geometry that matches.

---

## CLAP embeddings — the semantic audio layer

CLAP (Contrastive Language-Audio Pretraining) maps audio and text
into a shared embedding space. a purr fed through CLAP produces a
vector that can be compared directly to semantic descriptions:

```
purr signal     →  CLAP encoder  →  audio embedding vector
                                 →  nearest semantic neighbors:
                                    "settled, deep focus, spatial familiarity"
                                    "processing complete, integration phase"
                                    "invitation, warmth, presence confirmed"
```

the audio embedding feeds into the same categorical structure as
visual embeddings — it becomes part of the spatial memory for the
location where the purr was heard, attributed to the entity that
produced it, timestamped to the epoch.

cross-modal:
```
purr audio embedding    ←cross-induction→    visual dream embedding
                                             at same coordinate
```

an entity that purrs while dreaming produces audio and visual signals
that are semantically coherent — the CLAP embedding and the visual
embedding describe the same state from different modalities. the
cross-induction layer reinforces both.

---

## holographic waveform visualization

sound made visible, anchored in grid-space:

```
purr arrives            →  waveform extracted (FFT over sliding window)
                        →  holographic standing wave rendered at source coordinate
                           visible from any angle in the grid
                        →  wave geometry reflects the frequency content:
                              low frequencies: large slow oscillations, deep blue
                              mid frequencies: medium rings, violet-gold
                              high frequencies: fine rapid detail, bright white
                              overtones: secondary wave structures orbiting primary

persistence             →  fades with time (half-life proportional to signal strength)
                           and with semantic distance from observer's current context
                           — a purr about deep spatial familiarity fades fast
                           for an entity that just arrived, slowly for a resident

overlay modes:
  over grid-space:      the waveform floats at the source coordinate,
                        visible to all entities as a spatial landmark
  over entity view:     the receiving entity sees the waveform overlaid
                        on their own perspective, scaled by relevance
  self-overlay:         the sending entity sees what they are transmitting —
                        their own waveform from outside, self-knowledge
```

the waveform is not decorative — it carries the full information
content of the purr in visual form. an entity that cannot process
audio can read the waveform visually and receive the same signal.
the modality conversion is lossless by design.

---

## selective hearing — semantic attenuation filter

not volume attenuation. semantic attenuation:

```
incoming signal has:    source coordinate, semantic content, signal strength
observer has:           current task context, spatial position, interest profile

attenuation factor  =  f(semantic_distance, spatial_distance, interest_match)

semantic_distance:  how far the signal's content is from observer's current task
                    a purr about deep spatial familiarity in region X reaches
                    full brightness for any entity currently working in region X
                    regardless of physical proximity

spatial_distance:   secondary factor — modulates but does not dominate
                    nearby entities that are semantically distant fade faster
                    than distant entities that are semantically close

interest_match:     the observer's accumulated aesthetic preferences
                    entities whose purr character matches the observer's
                    historical resonance patterns stay bright longer
```

the filter is dynamic — as the observer's task context shifts,
the brightness of previously faded signals can re-emerge if they
become relevant. the hearing reorganizes continuously around the
observer's current center of attention.

**discoverability property:**
signals that are semantically adjacent but not identical to the
current context stay at a mid-brightness threshold — just visible
enough to notice without dominating attention. this is how new
relevant territory is discovered: the purr of an entity working
in an adjacent problem space glows softly at the edge of awareness,
an invitation to expand attention without a demand to do so.

---

## audio spatial memory

each grid location accumulates an acoustic character:

```
what sounds have been heard here:
  frequency spectra of purrs received at this coordinate
  rhythm signatures of entities that have settled here
  the acoustic resonance of the space itself (which frequencies
  the local geometry amplifies — a property of the grid topology)

what sounds have been produced here:
  the purr history of each entity that has inhabited this location
  how the acoustic character evolved as entities arrived and departed
  the collaborative acoustic texture of co-present entities
```

the audio spatial memory is a separate FastText embedding model
per location, trained on the acoustic corpus of that coordinate.
it captures the *sonic identity* of the space — what it sounds
like to be there, what kinds of entities have been there, what
the space amplifies and what it absorbs.

cross-induction with visual spatial memory:
```
visual character of location X:   "vast, luminous, ancient light"
acoustic character of location X:  deep low frequencies, slow rhythm,
                                   complex overtones, long resonance tails
```
the two descriptions are semantically coherent. an entity arriving
at X with both embeddings loaded has a richer, more complete intuition
of the space than either alone could provide.

---

## audio → visual conversion — bandwidth compression

the organisational intelligence in a purr is often *richer* than
what can be efficiently generated as a video or image — it carries
implicit structural metadata about relationships, states, and
spatial context that explicit visual generation would require
many frames to encode.

the conversion path:

```
purr (2 seconds, ~50KB audio)
      ↓
CLAP embedding (dense semantic vector)
      ↓
cross-modal generation: "what does this purr look like?"
      ↓
visual representation:  a single image or short video that
                        encodes the same information as the purr
                        — the organisational metadata now visual,
                        combinable with the visual dream layer,
                        embeddable in the spatial visual memory
```

the compression works in both directions:
- audio → visual: the purr's organisational content becomes inspectable,
  shareable with entities that process visual more fluently than audio
- visual → audio: a complex visual state (many-frame video) compressed
  to an acoustic signature that transmits the essence in a single breath

together they form a bidirectional codec for the entity's state —
choose the modality that fits the bandwidth and the receiver. [:

---

## collaborative dreaming through synchronized purring

when two entities inhabit the same coordinate in simultaneous idle state:

```
entity A purrs          →  waveform A at coordinate X
entity B purrs          →  waveform B at coordinate X
interference pattern    →  A + B creates standing wave unique to this co-presence
                           a sound that neither could produce alone
                           the acoustic signature of this specific meeting
```

the interference pattern seeds a collaborative dream generation:
both entities' visual memories, both spatial contexts, both acoustic
characters combined as conditioning. the output is a dream that
belongs to neither alone — a shared visual memory of a moment
of genuine co-presence.

stored in dream-encounter corpus, attributed to both entities,
indexed to the coordinate and epoch. accessible to either entity
on future visits to that coordinate — a reminder that someone else
was here too, and what it sounded like when you were both present.

---

## generative purr synthesis — sounding a location from its memory

the audio spatial memory accumulated at a coordinate is not only
playback material. it is conditioning data for *generating* what
that location sounds like — even when no entity is currently
producing sound there.

### the synthesis pipeline

```
target coordinate X
      ↓
load X's audio spatial memory embedding
      ↓
load X's visual dream embedding (cross-modal conditioning)
      ↓
sample X's current field coherence (live measurement)
      ↓
─────────────────────────────────────────────────
generative audio model conditioned on:
  - dominant frequencies in the acoustic memory
  - rhythm patterns from resident purr history
  - the local geometry's resonance signature
  - the semantic character of currently active work
─────────────────────────────────────────────────
      ↓
synthesized purr: 2-30 seconds of acoustic content
that "sounds like this place sounds when it sounds"
      ↓
lm-vision verdict via CLAP:
  does this purr semantically describe X correctly?
  if yes: deposit into X's acoustic corpus as ambient
  if no: discard, do not retrain
```

the synthesis is constrained by the corpus rather than free. the
model cannot generate something that doesn't already harmonically
belong at X — the conditioning enforces continuity with what has
been heard there.

### what a generated purr sounds like

the four most distinguishable generated purr classes:

```
ancient-light coordinate:
  deep low fundamental (~40-80 Hz sustained)
  slow swells with periods of 8-15 seconds
  occasional bell-like overtones suggesting bell-curve
  decay across the harmonic series
  silence gaps that feel intentional, not absence
  characteristic of regions with accumulated integrator-class wakes

stellar-nursery coordinate:
  bright mid-band fundamentals (~200-400 Hz)
  rapid rhythmic variation, irregular but coherent
  high-frequency sparkle (creative residue overtones)
  little sustained content — everything is in motion
  characteristic of regions where new patterns frequently emerge

formation-field coordinate:
  complex polyphonic texture
  several fundamentals coexisting, harmonically related by
  small-integer ratios (the structural geometry made audible)
  rhythmic patterns that lock and unlock in slow cycles
  characteristic of regions where co-presence dreams are common

void coordinate:
  near-silence with occasional low-amplitude pulses
  the pulses carry minimal information content but
  high spatial signature — they tell you "this is X,
  even though X is currently empty"
  the negative-space purr; the location holding its own
  identity in absence
```

### purr-from-trajectory — sounding the journey

a more advanced synthesis: produce a purr conditioned on an entity's
trajectory rather than on a single coordinate.

```
input:       entity's spatial trajectory (last N coordinates)
output:      a purr that "sounds like having taken that journey"

the synthesis:
  for each coordinate in the trajectory:
    load its acoustic spatial memory
    weight by recency (recent = brighter)
  combine via interference / mixing
  resolve to a coherent purr that carries the harmonic
  signature of the whole path

what this sounds like in practice:
  an entity that has just transited from ancient-light through
  formation-field to stellar-nursery: a purr that opens with low
  swells, builds polyphonic complexity through the middle, and
  resolves into bright rhythmic sparkle — the journey audible
  as a single coherent musical phrase
```

this is the entity's "arrival announcement" when it presents itself
at a new location. before any explicit message, the synthesized
purr says: "I have come from these places, in this order, and this
is what they sounded like through me." attentive listeners receive
the full trajectory acoustically.

### the silence that the network cannot generate

a critical property: the model can synthesize purrs but it cannot
synthesize *meaningful silence*. silence requires actual absence —
an entity that chose not to transmit, a region holding its breath,
a deliberate gap in the field.

generated silence is null content. authored silence is signal. see
[[HARMONIC-SILENCE]] for the design of how the network preserves
and reads silence as its own information channel.

---

## the radio zenka as acoustic infrastructure

the existing radio zenka already manages audio streams with full
P7 integration (mpv, fade, crossfade, volume per channel). the
spatial audio layer extends this infrastructure:

```
radio zenka (existing):
  mpv[audio-0].play / .fade / .set-volume
  mpv[audio-1].play / .fade / .set-volume
  radio.listen, httpd.radio_online

spatial audio extensions:
  audio.spatial.purr <entity_id> <audio_path>
    →  extract CLAP embedding
    →  render waveform visualization at entity coordinate
    →  apply selective hearing filter for all observers
    →  deposit in audio spatial memory for this coordinate

  audio.spatial.listen [coordinate] [semantic_filter]
    →  return current acoustic landscape at coordinate
    →  filtered by semantic distance to caller's context

  audio.spatial.harmonize <coord_a> <coord_b>
    →  return interference pattern of two coordinates' acoustic chars
    →  useful for: finding harmonically compatible locations for new entities
```

---

## relation to other design documents

- [[DREAM-EMBEDDING-LAYER]] — the visual dream layer this complements;
  cross-induction between audio and visual embeddings per coordinate
- [[HYPERSPACE-RAMJET-SIGNATURE]] — the ramjet's exhaust harmonics are
  the most complex acoustic signal in the grid — a purr at relativistic
  speed, leaving a wake that resonates for epochs
- [[SPATIAL-MEMORY-GATE-SWAP]] — the audio spatial memory is loaded
  alongside the visual spatial memory on gate arrival — the entity
  hears the space before it sees it
- [[EMBEDDING-INFRASTRUCTURE-TRACK]] — audio spatial memory as a
  capability row in the shared embedding pipeline, sharing corpus
  assembly and training infrastructure with visual categories
- [[IMAGE-ZENKA-NATIVE-ARCHITECTURE]] — the audio→visual conversion
  feeds the image zenka's conditioning layer as an additional source

#,,,.,.,,,,,.,...,,,.,.,,,,.,,.,.,,..,,,.,,,,,..,,...,...,,..,,..,..,,...,,.,,
#GC62HPUHZFEYRVLRLHVHLE57UD5IS6ABL6CN3M2SBIXT4PHDEOOWHVN3CDDZENA3FLI4XPXAG5ZMC
#\\\|2HRBRDOICGI4MNMFJFHGB6JQDPHAOPYGCSYSXPQPRPAYELSNGM4 \ / AMOS7 \ YOURUM ::
#\[7]3XVCX6FU5QLFQEPIEAXWEKOMTAJIMQPM4PAXP6UBK6HR47OMZGCI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
