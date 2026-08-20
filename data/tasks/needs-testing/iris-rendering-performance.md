## [:< ##

# name  = task: iris rendering performance optimization
# descr = profile and improve iris SVG rendering speed
#         find bugs, add caching, reduce redundant work

## context

the iris at iris.v7.ax renders slowly. the current path:

1. httpd receives GET /iris/svg?mode=ring&rings=26
2. httpd.route.handler.iris-svg checks if bmw384 index is empty
3. if empty: calls route.bmw384.index.from-path() — scans ALL 3881 modules
4. calls route.bmw384.visual.wheel-mode → wheel → generates SVG
5. returns SVG

the first request is very slow (full directory scan).
subsequent requests may also be slow depending on SVG generation cost.

## read first

- src/httpd.route.handler.iris-svg      (the handler)
- src/route.bmw384.visual.wheel         (main SVG generator)
- src/route.bmw384.index.from-path      (index population)
- src/route.bmw384.visual.flying-elements (new — may have issues)

## what to investigate and fix

### 1. startup indexing (highest priority)

the index should be populated when httpd initializes,
not on first request. look for httpd's init or post-init hook
and add index population there.

check: src/httpd.init_code or route.bmw384.init_code
look for where to add:
  <[route.bmw384.index.from-path]>->()
  if not scalar keys %{ <bmw384.index>->{'by_name'} // {} };

this makes the first request as fast as all subsequent ones.

### 2. SVG caching

the wheel SVG for a given (mode, rings, param, label_mode)
combination doesn't change unless the index changes.
add a simple cache keyed on those parameters:

```perl
my $cache_key = join ':', $mode, $rings, $param, $label_mode;
if ( defined <bmw384.svg.cache>->{$cache_key} ) {
    # [ return cached SVG ]
}
# [ generate SVG ]
# [ store in cache ]
<bmw384.svg.cache>->{$cache_key} = $svg;
```

cache invalidation: clear <bmw384.svg.cache> when index is re-populated.

### 3. SVG element count

with 3881 modules × 26 rings = potentially 100k+ circle elements.
the co-location logic groups nodes at the same (arc, color) coordinate
but may still generate too many elements.

check: in route.bmw384.visual.wheel, the inner loop over @sorted_names
look for: are nodes actually being co-located and reduced?
          is the drawn_index{$key} logic working correctly?
          
if many nodes share the same coordinate: only one circle should render
(with radius growing for co-located count) — verify this is working.

### 4. sort optimization

the wheel module does:
  my @sorted_names = sort @names;

sorting 3881 strings on every render is expensive.
consider: sort once when indexing, store sorted in the index.

### 5. flying elements overhead

src/route.bmw384.visual.flying-elements is new and called on
every SVG render. if <bmw384.route.curves> is empty (no routes added),
it should return immediately with minimal overhead:

check: does it return '' quickly when no curves are registered?
fix if not: add early return when curves hash is empty.

### 6. profile the slow path

add timing logs to httpd.route.handler.iris-svg:
  my $t0 = <[base.time]>->(3);
  # [ index populate if needed ]
  <[base.logs]>->( 1, 'index ready: %.3fs', <[base.time]>->(3) - $t0 );
  # [ generate SVG ]  
  <[base.logs]>->( 1, 'svg generated: %.3fs', <[base.time]>->(3) - $t0 );

this tells us where the time actually goes.

## expected improvements

startup indexing:     first request: fast (no more scan on request)
SVG caching:          repeated renders: near-instant
co-location fix:      fewer SVG elements if bug found
sort optimization:    modest improvement per render
flying elements:      zero overhead when no routes active

## signatures note

existing modules: re-signed on commit
new modules: leave clean, no stub footer

## style

$ARG not $_ in loops
lowercase comments, [ word ] bracket annotations
no use statements or pragmas in zenka modules

#,,..,.,.,,,.,,..,.,.,,,.,,,,,,,.,.,.,...,...,..,,...,...,..,,.,.,...,,..,..,,
#SPCF65VRHQSNGI6XV7OK3YUYYQNV53ZQIUJN3OGEN6X72S5YYXFRD44ZY6A5AJOK3D2O7UWLYVTUY
#\\\|5O43IFQZTCXZLZGPVEUY7AXFDTQ6LYCB7WVWPWUJVSJH5A4DIHT \ / AMOS7 \ YOURUM ::
#\[7]SIKUPXV23PWBLWYH57CJ2NPQHEXYSGQJCMP7XBQLLYSFAATQVMBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
