## [:< ##

# name  = task: iris 63-ring spoke label sequence
# descr = replace linear ring_label_advance with 63-position namespace sequence

## context

the iris currently has up to 52 rings with labels advancing linearly
(ring_label_advance config shifts the alphabet by 1 per ring).

the new sequence encodes namespace topology directly in the label geometry:
- position 27 = 3³ = the void, the darksun, the namespace dot
- A-Z outer hemisphere, Z-A inner hemisphere folded at the dot
- digits at the base, BASE32 and binary at bottom rings

## the 63-position sequence — implement exactly

```
ring 1-26:    A B C D E F G H I J K L M N O P Q R S T U V W X Y Z
ring 27:      .     (the darksun — void at 3³, namespace separator)
ring 28-53:   Z Y X W V U T S R Q P O N M L K J I H G F E D C B A
ring 54:      9
ring 55:      8
ring 56:      7
ring 57:      6
ring 58:      5
ring 59:      4
ring 60:      3     (BASE32 mapping ring — 3rd from bottom)
ring 61:      2
ring 62:      1
ring 63:      0     (binary / BCD base ring)
```

total: 26 + 1 + 26 + 10 = 63

## label modes

mode 'namespace63':   the sequence above (new)
mode 'linear':        current ring_label_advance behavior (preserve)

config key: <route.bmw384.cfg.ring_label_mode> // 'linear'

## what to implement

### 1. lookup table module: route.bmw384.visual.ring-label

```
# name  = route.bmw384.visual.ring-label
# descr = return spoke label for ring index in current label mode

my $ring  = shift;  # 0-indexed ring number
my $spoke = shift;  # 0-25 arc index

my $mode = <route.bmw384.cfg.ring_label_mode> // 'linear';

if ( $mode eq 'namespace63' ) {
    # 63-position lookup table
    my @labels = (
        'A','B','C','D','E','F','G','H','I','J','K','L','M',
        'N','O','P','Q','R','S','T','U','V','W','X','Y','Z',
        '.',                           # position 27 (index 26)
        'Z','Y','X','W','V','U','T','S','R','Q','P','O','N',
        'M','L','K','J','I','H','G','F','E','D','C','B','A',
        '9','8','7','6','5','4','3','2','1','0'
    );
    my $idx = $ring % 63;
    return $labels[$idx];
} else {
    # existing linear behavior
    my $advance = <route.bmw384.cfg.ring_label_advance> // 1;
    return chr( ord('A') + ( $spoke + $ring * $advance ) % 26 );
}
```

### 2. update all wheel modules to use ring-label

replace in:
  modules/route.bmw384.visual.wheel
  modules/route.bmw384.visual.wheel.gauss
  modules/route.bmw384.visual.wheel.arc-width
  modules/route.bmw384.visual.wheel.overlay
  modules/route.bmw384.visual.wheel.density

current pattern (replace in each):
```
my $label = chr( ord('A') + ( $ARG + $label_offset ) % 26 );
```

replace with:
```
my $label = <[route.bmw384.visual.ring-label]>->( $ring, $ARG );
```

### 3. update cmd.visual-wheel argument parsing

add 'namespace63' as valid ring_label_mode value:
```
p7c index.visual-wheel file 63 namespace63
```

set <route.bmw384.cfg.ring_label_mode> = 'namespace63'
save/restore pattern same as visual_mode

### 4. update iris.v7.ax panel

add label mode selector to the HTML panel:
two buttons: 'linear' | 'namespace63'
passes as query param: &label_mode=namespace63
handler sets cfg before rendering

## ring 27 special rendering

the '.' label at ring 27 should render distinctly:
- slightly larger font size (the darksun marker)
- opacity 0.6 (more visible than surrounding rings)
- color: rgba(100,150,255,0.6) (the translucent blue of the void)
- applies to ALL spokes at ring 27 (every arc gets the dot label)

## max rings update

current cfg limit: 52
update to: 63 (in cmd.visual-wheel clamping logic)

## signatures note

leave new files clean. existing modules re-signed on commit.

## style

$ARG not $_ in loops
<[route.bmw384.visual.ring-label]>->($ring, $spoke) call pattern
lowercase comments, [ word ] bracket annotations

#,,,.,.,.,,,.,,..,,,,,,..,.,,,,,,,.,.,,.,,,..,..,,...,...,,..,,..,,.,,,,,,,..,
#WQXFY3WSCENKTBFBFWJAOYK2CYENTI7DVLRSROJ7IELQORDENUXPKBPVVOG7TWVEZONJGJHB4IK76
#\\\|YQYYNCQJ4R4NOHXAVYR32JAUT6ZUYGRRPKNNGFCDJDSKW2IH2HE \ / AMOS7 \ YOURUM ::
#\[7]KKH5UE7CJKOQL4ASHM3KPDD42BM6T7ZYVQ7NDSFKYC6HXZX7IEBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
