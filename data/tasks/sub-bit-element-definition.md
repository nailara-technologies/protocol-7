## [:< ##

# name  = task: sub-bit element definition — 3+1 bit stream framing
# descr = implement the minimal self-synchronizing stream framing protocol

## context

the sub-bit layer is the neutral substrate everything else builds on.
it makes storage, transport, and identity structurally untakeable
by ensuring generic elements have no category until full assembly.

the protocol is already fully derived — this task implements it.

## reference

data/ai-mem/claude/topic-stream-framing-protocol.md
data/md/design/NETWORK-RESOURCE-TOKEN-ARCHITECTURE.md (layer 1)

## the protocol — already defined, implement exactly

### frame format

```
3 bits payload  +  1 bit separator  =  4-bit frame

payload  sep   notes
  001     .    normal  (. = 0)
  010     .    normal
  111     .    normal
  000     .    COLLAPSE — do not emit, invert separator
  000     ,    INVERTED separator (, = 1) — field saved
```

inversion rule: when payload = 000, separator inverts from . to ,
receiver knows: , on 000 payload = structural separator, not data
one rule, zero ambiguity

### direction detection (3-bit assertion window)

```
[..,]   direction: forward   (00→1)
[.,.]   direction: symmetric (0→1→0)
[,..]   direction: backward  (1→00)
```

### frame lock (sliding window)

test every 4th bit position for uniformity:
- separator column is always the same value
- payload columns vary (carry information)
- correct offset = the uniform column = LOCK

```
5 bits:  safe detection  (two separator samples)
7 bits:  certainty       (one complete frame + 3 context bits)
```

### 1001 clamp — eternal continuation

1001 = the void (00) clamped between two ones
trailing 1 means: continuation already present in sample
no terminal condition — the clamp IS the continuation signal

## what to implement

### new module: base.stream.frame

```
# name  = base.stream.frame
# descr = 3+1 bit frame encoder — payload + separator with inversion

my $payload = shift;  # 0-7 (3 bits)
my $sep     = 0;      # separator: . (0) default
$sep = 1 if $payload == 0;  # inversion rule: 000 payload → , (1)
return ( $payload << 1 ) | $sep;  # 4-bit frame
```

### new module: base.stream.frame.detect

```
# name  = base.stream.frame.detect
# descr = sliding window frame lock — find separator column offset

my $bits = shift;  # arrayref of bits
# test offsets 0,1,2,3 — which is uniform every 4th position?
# return offset or undef if insufficient data (need >= 5 bits)
```

### new module: base.stream.frame.decode

```
# name  = base.stream.frame.decode
# descr = decode 4-bit frame to payload, handling inversion

my $frame   = shift;
my $payload = $frame >> 1;
my $sep     = $frame & 1;
# if payload == 000 and sep == 1: valid (inverted separator)
# if payload != 000 and sep == 0: valid (normal separator)
# return payload (0-7)
```

## tests to include in task notes

```
encode 0 (000) → 0001  (inverted separator)
encode 1 (001) → 0010  (normal)
encode 7 (111) → 1110  (normal)

stream: 001. 010. 000, 111. → 0010 0100 0001 1110
lock at offset 3: bits 3,7,11,15 = 0,0,1,0 — wait
lock at offset 3 across multiple frames: all separators
```

## signatures note

leave new files clean — signing system adds footer on commit.
do not add stub footer.

## style

$ARG not $_ in loops
<[base.logs]>->( N, fmt, args ) for logging
lowercase comments, [ word ] bracket annotations
no use statements or pragmas in zenka modules

#,,..,,..,...,,,,,.,.,..,,,,,,...,...,,,,,,,,,..,,...,..,,.,.,...,...,.,,,,,.,
#G2CAC2F4RREKAQ2QGRF36YAPV7QF7QI4T3OH4S4J2IXYAE5HDGTNWXAHVP6BU54AQLGWT24R6MYJY
#\\\|O6C2XNW2MSY2NBRW22ZLO2C63DOOZPGQMOSLNO3STAI6GEMRJG5 \ / AMOS7 \ YOURUM ::
#\[7]5GSNWOWVXTM6JID2DBMWBLKP5DSC6JOMWBSJUIR7YINKQ7IO2YAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
