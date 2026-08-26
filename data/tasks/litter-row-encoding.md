## [:< ##

# name  = task: :::: footer litter row — 15-bit zenka involvement encoding
# descr = encode zenka involvement bitmap in AMOS7 signature footer line 4

## context

every signed module already has a 4-line footer.
line 4 (the :::: row) is currently structural decoration —
77 characters wide, all colons, unused bandwidth.

15 bits = 3 base32 chars: zenka involvement bitmap embedded here.
the loader already scans the footer → zero overhead to read litter.
passive broadcast: the module declares its own routing manifest.

## the four footer lines — complete identity packet

```
#,,.,,...   line 1: BMW384 checksum    (content integrity)
#\\\|...    line 2: AMOS7 signature    (identity / author)
#\[7]...    line 3: version/instance   (which version)
#:::::...   line 4: zenka litter       (which network / routing)
```

## litter row format

current:   #:::::::::::::::::::::::::::::::::::::::::::::::::::::
proposed:  #:[BASE32_3CHARS]:::::::::::::::::::::::::::::::::::::

the 3 base32 chars (15 bits) are embedded after the opening #:
remaining colons maintain visual consistency and line length.

### 15-bit bitmap — 7+1+7 neighborhood encoding

```
bits 0-6:    zenka involvement flags (which zenki use this module)
bit  7:      transport state — 0 = local, 1 = routing
bits 8-14:   routing flags (which transport trunks / layers)
```

bit 7 [ human-reviewer proposal, 2026-08-04, adopted ]: a single bit
distinguishing whether this module's traffic is contained to the local
litter neighborhood [ 0 ] vs. handed off across a longer routing path
[ 1 ]. it's the natural hinge between the two halves — bits 0-6 say
*who* touches the module, bit 7 says *how far* that touch travels,
bits 8-14 say *which trunks* carry it when it does. a module with only
local zenka involvement leaves bit 7 and bits 8-14 at zero; a module
that's also routed cross-trunk sets bit 7 and populates the trunk flags.

open question [ not resolved by adopting the definition ]: every other
bit in this bitmap derives from a static property, the module's
namespace prefix, computed once at sign time by the "namespace →
bitmap rules" below. "is this routed cross-trunk" is not a namespace
property — it may not be knowable purely from the module's own source
at sign time, unlike bits 0-6 and 8-14. whoever implements this needs
to decide bit 7's actual derivation rule [ e.g. inferred from which
trunk-flag bits end up set, since routing implies at least one trunk
flag on; or left as a manually-asserted flag in the module's own
metadata ]. flagged here rather than guessed at, since it's the one bit
the human reviewer asked about directly.

### coexistence with the harmonic-transit 15-bit spatial coordinate

`data/md/documentation/harmonic-transit-vision-architecture.md` [ section
2 and section 10 ] also describes "the 15-bit footer field" — a 13-bit
L-matrix + 2-bit orientation selector, encoded right-aligned across
positions 47-77 of this same line. that is a different value [ a
dynamic per-signing spatial coordinate, not a static zenka manifest ]
occupying a different character range, so it does not collide with the
3-char litter payload here [ positions 3-5 ]. see
`data/tasks/footer-line4-field-reconciliation.md` for the full
character-position layout and reasoning — including a third, unadopted
candidate [ a 3×5-bit zenki-address routing chain ] logged there as an
open idea for the still-unclaimed positions 7-46, distinct from this
bitmap and from the harmonic coordinate.

zenka bit assignments (0-indexed):
```
bit 0:  base       (loaded by almost all zenki)
bit 1:  httpd      (web-facing modules)
bit 2:  index      (BMW384 index modules)
bit 3:  coding     (coding zenka modules)
bit 4:  kimi       (kimi zenka modules)
bit 5:  letsencr   (TLS/cert modules)
bit 6:  v7         (management modules)
bit 7:  (void/special)
bit 8:  plugin.web (web plugin modules)
bit 9:  jobsite    (job pipeline modules)
bits 10-14: reserved for future zenki
```

## what to implement

### 1. litter encoding in signing system

locate: bin/Protocol-7 sourcecode update-signatures
or:     the module that writes the 4-line footer

add: after generating footer lines 1-3,
     compute 15-bit bitmap from module namespace
     encode as 3 base32r chars
     embed in line 4: #:[CHARS]:::::...

namespace → bitmap rules:
```
module starts with 'base.'          → bit 0
module starts with 'httpd.'         → bit 1
module starts with 'route.bmw384.'  → bit 2
module starts with 'coding.'        → bit 3
module starts with 'kimi'           → bit 4
module starts with 'letsencr.'      → bit 5
module starts with 'v7.'            → bit 6
module starts with 'plugin.web.'    → bit 8
module starts with 'plugin.web.jobs' or 'jobsite.' → bit 9
```

multiple bits can be set (module serves multiple zenki).

### 2. litter reading in module loader

locate: the section of bin/Protocol-7 that reads footer
add: parse line 4 for litter pattern #:[A-Z2-7]{3}:
     decode base32r → 15-bit bitmap
     store in module metadata

### 3. new module: base.module.litter

```
# name  = base.module.litter
# descr = read zenka involvement bitmap from module footer litter row

my $module_name = shift;
# returns 15-bit integer or undef if no litter present
# reads from compiled module source, finds :::: line
# decodes base32r chars to bitmap
```

### 4. new module: base.module.litter.encode

```
# name  = base.module.litter.encode  
# descr = compute zenka involvement bitmap from module namespace

my $module_name = shift;
# returns 15-bit integer
# applies namespace → bitmap rules
# used by signing system
```

## verification

after implementation:
- sign any module
- check line 4 contains 3 base32r chars after #:
- verify bitmap matches module namespace
- verify loader reads and stores bitmap correctly

## signatures note

leave new files clean — signing system adds footer on commit.
the litter row itself will be populated by the signing system
once this task is complete.

## style

$ARG not $_ in loops
<[base.logs]>->( N, fmt, args ) for logging  
lowercase comments, [ word ] bracket annotations

#,,,.,.,.,.,,,,..,...,..,,,..,,..,,.,,.,.,,..,..,,...,..,,,.,,,,.,,,,,...,.,.,
#JM3LEPEP3P53T7QU2D7ZV2TMJCP2ZAEKEIVJOEPMHLUVCWD4SF7WDNH6F6BZONFP2FPQKBLTIR6EK
#\\\|THPFAZA4ZBTCB6VDXUYA2VHY4EI63GCZNURNH4SR42DFDOX3PTT \ / AMOS7 \ YOURUM ::
#\[7]UVZBCOIEZV6K622D74UVEBOPBVBWK3LUFIEHUYE7FO7KQ33I7CCQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
