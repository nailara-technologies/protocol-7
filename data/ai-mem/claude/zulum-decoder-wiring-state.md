# Zulum → Decoder Entropy Wiring: Current State & Issues

## Overview

Attempting to wire **zulum** (13-stream entropy generator) to **decoder** (base32 accumulator) so that:
1. Zulum generates 42-bit entropy via harmonic division-by-13 algorithm
2. Decoder receives and accumulates entropy into level-5 buffer
3. Accumulated values display via `decoder.show-buffer 5`

## Architecture

```
┌─────────┐     42-bit entropy      ┌─────────┐
│  zulum  │ ──────────────────────→ │ decoder │
│         │  (via callback/attach)  │         │
│ 13      │                         │ level-5 │
│ streams │                         │ buffer  │
└─────────┘                         └─────────┘
```

## Files Involved

| File | Purpose | Zenka |
|------|---------|-------|
| `zulum.init_code` | Creates 13 streams, auto-attaches to decoder | zulum |
| `zulum.cmd.stream-attach` | Attaches consumer callback to stream | zulum |
| `zulum.cmd.step` | Manual trigger for testing entropy gen | zulum |
| `decoder.zenka.receive_entropy` | Internal handler, accumulates bits | decoder |
| `decoder.cmd.receive-entropy` | Command wrapper (NEW, untested) | decoder |
| `decoder.start` | Permissions for commands | decoder |

## Intended Behavior

### Initialization Flow
1. `zulum.init_code` runs on zulum zenka start
2. Creates 13 streams with seeds: gen×1, gen×2, ... gen×13 (gen=76923)
3. For each stream, calls `zulum.cmd.stream-attach` with `consumer => 'decoder'`
4. `stream-attach` creates callback that calls `decoder.zenka.receive_entropy`
5. Callback stored in stream's `attached` array

### Runtime Flow
1. User runs: `zulum.step 1` (manual trigger stream 1)
2. `zulum.cmd.step` generates 42-bit entropy value
3. Iterates `stream->{attached}` callbacks
4. Each callback receives `(stream_id, entropy_bits, iteration)`
5. Callback calls `<[decoder.zenka.receive_entropy]>->(...)`
6. `receive_entropy` appends bits to level-5 accumulator
7. When ≥5 bits accumulated, extracts 5-bit chunk → base32 value
8. Value pushed to `$data{'buffer'}{5}{'data'}` array
9. User runs: `decoder.show-buffer 5` → displays accumulated values

## Current Implementation

### zulum.init_code (simplified)
```perl
for my $stream_id ( 1 .. 13 ) {
    my $seed = $GENERATOR * $stream_id;
    <zulum.stream>{$stream_id} = {
        'seed' => $seed, 'state' => $seed,
        'iteration' => 0, 'entropy' => 0,
        'active' => 1, 'attached' => [],
    };
    ## Auto-attach to decoder ##
    <[zulum.cmd.stream-attach]>->(
        { 'stream_id' => $stream_id, 'consumer' => 'decoder' }
    );
}
```

### zulum.cmd.stream-attach (callback creation)
```perl
my $callback = sub {
    my ( $sid, $entropy, $iteration ) = @_;
    <[decoder.zenka.receive_entropy]>->(
        {   'stream_id' => $sid,
            'entropy'   => $entropy,
            'iteration' => $iteration
        }
    );
};
push @{ $stream->{'attached'} }, $callback;
```

### zulum.cmd.step (entropy generation)
```perl
my $params    = shift // {};
my $stream_id = $params->{'stream_id'} // $ARG[0] // 1;
my $stream    = <zulum.stream>{$stream_id};

## Generate entropy via division-by-13 harmonic ##
my $state = $stream->{'state'};
$state <<= 4;
my $truth = $state / 13;
$state = $truth % ( 2**42 );
$stream->{'state'}    = $state;
$stream->{'entropy'}  = $state;
$stream->{'iteration'}++;

my $entropy_bits = sprintf( "%042b", $state );

## Fire callbacks ##
foreach my $cb ( @{ $stream->{'attached'} } ) {
    $cb->( $stream_id, $entropy_bits, $stream->{'iteration'} );
}

return { 'mode' => qw| true |, 'data' => "stream $stream_id stepped" };
```

### decoder.zenka.receive_entropy (internal handler)
```perl
my $params    = shift // {};
my $stream_id = $params->{'stream_id'};
my $entropy   = $params->{'entropy'};

my $L5 = <decoder.level5>;
$L5->{'accumulator'} .= $entropy;
$L5->{'bit_count'}   += length($entropy);

## Extract 5-bit chunks → base32 values ##
while ( $L5->{'bit_count'} >= 5 ) {
    my $chunk = substr( $L5->{'accumulator'}, 0, 5, '' );
    $L5->{'bit_count'} -= 5;
    my $val = oct("0b$chunk");
    push @{ $L5->{'values'} }, $val;
    push @{ $data{'buffer'}{5}{'data'} }, sprintf( "%02d", $val );
}

return { 'mode' => qw| true | };
```

### decoder.cmd.receive-entropy (NEW - command wrapper)
```perl
my $args_str = $call->{'args'} // '';
my ( $stream_id, $entropy ) = split( m| +|, $args_str, 2 );

return { 'mode' => qw| false |, 'data' => 'missing stream_id' }
    unless defined $stream_id && length $stream_id;
return { 'mode' => qw| false |, 'data' => 'missing entropy' }
    unless defined $entropy && length $entropy;

return <[decoder.zenka.receive_entropy]>->(
    { 'stream_id' => $stream_id, 'entropy' => $entropy }
);
```

### decoder.start permissions (relevant section)
```perl
# Cube-routed commands (called by other zenki)
access.cmd.usr.cube = receive-entropy show-buffer

# Local commands
access.cmd.usr.root = init show-buffer reset level5-test receive-entropy
access.cmd.usr.local = show-buffer
```

## Issues Encountered

### Issue 0: Parameter Parsing Bug in show-buffer (DISCOVERED)
**Location:** `decoder.cmd.show-buffer` line 8

**Problem:** 
```perl
my $level = $params->{'level'} // $params->{'args'} // 5;
```

This checks `$params->{'args'}` but when called internally (not as command), there's no `$call` object. However, since it defaults to 5, this should work... unless `$params->{'args'}` exists but is undefined/empty.

**Impact:** Probably not the root cause, but inconsistent pattern.

---

### Issue 1: "no such buffer" on decoder.show-buffer 5
**When:** After running `zulum.step 1` successfully

**Symptoms:**
- `zulum.step 1` returns `{"mode":"true","data":"stream 1 stepped"}`
- `decoder.show-buffer 5` returns `{"mode":"false","data":"no such buffer"}`

**Hypothesis:** Callback from zulum→decoder not firing, or decoder level-5 buffer not initialized

**Evidence needed:**
- Does `decoder.zenka.receive_entropy` actually get called?
- Is `<decoder.level5>` hash properly initialized in decoder.init_code?
- Are permissions correct for cube-routed call?

### Issue 2: Command vs Internal Call Duplication
**Question:** Should we have both:
- `decoder.zenka.receive_entropy` (internal handler)
- `decoder.cmd.receive-entropy` (command wrapper)

Or merge them into one callable module?

**Current state:** zulum calls internal directly: `<[decoder.zenka.receive_entropy]>->(...)`

### Issue 3: Parameter Passing Convention
**Rule learned:** `.cmd.` modules must use `$call->{'args'}` for parameters, not `shift` or `$ARG[0]`

**Applied to:** `decoder.cmd.receive-entropy` (fixed)

**Question:** Does this affect the internal call from zulum?

## Test Sequence

```bash
# 1. Start zenki (already running)
# zulum (id: 2734002), decoder (id: 7405419)

# 2. Step zulum stream 1
echo "zulum.step 1" | /data/projects/protocol-7/bin/p7 zulum

# 3. Check decoder buffer
echo "decoder.show-buffer 5" | /data/projects/protocol-7/bin/p7 decoder

# Expected: Array of 00-31 values
# Actual: "no such buffer"
```

## Additional Debugging Info

### Manual Verification Steps

```bash
# Check if decoder init ran
p7 decoder -c 'return <decoder.level5>'

# Check if zulum streams initialized  
p7 zulum -c 'return <zulum.stream>{1}'

# Check if callbacks attached
p7 zulum -c 'return scalar(@{<zulum.stream>{1}{attached}})'

# Direct test of decoder receive_entropy
p7 decoder -c '<[decoder.zenka.receive_entropy]>->({stream_id=>1,entropy=>"101010111010101010101010101010101010101010"})'

# Then check buffer
p7 decoder -c 'return <decoder.level5>{values}'
```

### Key Insight: Direct Code Call vs Command

**Current flow:**
```
zulum.cmd.step 
  → generates entropy
  → calls callback in stream->{attached}
  → callback calls <[decoder.zenka.receive_entropy]>->()
     ↑ This is DIRECT CODE CALL, not cube-routed command
```

This bypasses the cube routing layer entirely. The call happens in zulum's context, executing decoder's code. This should work if:
1. Decoder's init_code has run (level5 initialized)
2. The callback is properly stored and invoked
3. The `<[decoder.zenka.receive_entropy]>` resolves correctly

---

## Questions for Analysis

1. **Why is decoder buffer empty after zulum.step?**
   - Is the callback firing?
   - Is level-5 accumulator initialized?
   - Are permissions blocking cube-routed internal calls?

2. **Should we merge receive_entropy modules?**
   - Pros: Single source of truth
   - Cons: Internal vs command interfaces differ

3. **What's the correct pattern for cross-zenka calls?**
   - Direct `<[decoder.zenka.xxx]>->()` from zulum?
   - Or via cube routing `decoder.receive-entropy` command?
   - Or event-based pub/sub?

4. **Is the 42-bit entropy format correct?**
   - `sprintf("%042b", $state)` produces 42-character binary string
   - Decoder appends this to accumulator
   - Every 5 bits → one base32 value (0-31)
   - Math checks out?

## Next Steps (After Fix)

1. Verify wiring works: `zulum.step 1` → `decoder.show-buffer 5` shows values
2. Test multiple steps accumulate correctly
3. Implement cube-13 jump routing (commands: `jump true`, `jump reverse`, `jump next`)
4. Add boundary markers for jump state visualization

---

# REPLY SECTION

**For Claude:** Please analyze the above state and provide:

1. **Root cause analysis** of why `decoder.show-buffer 5` returns "no such buffer" after `zulum.step 1`
2. **Recommended restructuring** - should we merge internal/command modules or keep separate?
3. **Detailed fix instructions** with specific code changes needed
4. **Verification steps** to confirm the wiring works

Please be explicit about:
- Which files to modify
- What exact changes to make  
- How to test each change
- Any architectural patterns we should follow for future cross-zenka wiring

#,,..,.,,,,.,,...,...,,.,,.,,,..,,,.,,.,,,,.,,.,.,...,...,...,,,,,..,,,..,,..,
#55QYRIWD5MZQIH7LZ3YQ6K3RNGPXDRJLHRF6HT4EGGQ2DZMPUDHZIIDOVMLDYW4P3IUZVYZJX6FQ4
#\\\|OHXS6KQWWSSOWJCAAO34ZYYADAK6LHPZVYJALVUDDRPU6RTTDC2 \ / AMOS7 \ YOURUM ::
#\[7]J5WHGPNPJKLZ5TTP233XAI34HOL2XUNBYUW7SPAC7WS4GZALA6CY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
