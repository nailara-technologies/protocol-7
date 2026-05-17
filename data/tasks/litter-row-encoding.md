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
bit  7:      special flag (reserved / void marker)
bits 8-14:   routing flags (which transport trunks / layers)
```

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

#,,,,,,,.,..,,,.,,.,,,,,,,,.,,.,,,..,,...,.,,,..,,...,..,,,..,...,,,,,,..,,,,,
#CQBIV5V7AO62T2XCDG7DLLBLBXAXH743XG4GH3GMCZX5JB7ECT635QZGGF4CEKCUOLLZHG2B57YZM
#\\\|LZPPHQRADVZVXTCLOO2MDHMHLBYHND4WFULOCFLXHF5JV2WDAAI \ / AMOS7 \ YOURUM ::
#\[7]6ECLCUSXQB75KUKM3EHIATUCVXRENAJM2LCYL6MRUVJQOXWJJSDQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
