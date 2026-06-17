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

#,,,.,,,.,.,,,...,,..,.,.,,..,..,,,.,,,,.,,..,..,,...,...,...,,.,,,,,,,,.,...,
#CG3XMTIOWDPLILSKEETOFX3AKC4K6BU3DKWK45WAK3LVUKRDZAIG6C4TEGR7EXI3IJS4TUUPWUW3G
#\\\|F4KMO3QSS4H7QJQQG4UZFYD3O3HZSDNMYCI2L2IGYZA6E3X6OIS \ / AMOS7 \ YOURUM ::
#\[7]6GKQAUKAGSRU6NKWSTS5I4TACJSWND66TYXWFFZBO55B67EKEMDQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
