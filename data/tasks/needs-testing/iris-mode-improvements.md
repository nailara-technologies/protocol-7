## [:< ##

# name  = task: iris mode improvements — heatmap speed, namespace filter, gauss fix
# descr = three specific issues to fix in the iris visualization modes

## issue 1: heatmap is blocking slow

the heatmap mode generates up to 26×26 = 676 complex SVG path elements
(annular sectors with 12 floating point numbers each).
it is still slow even with the SVG cache because the first render blocks.

### fix: precompute trig tables in heatmap

in src/route.bmw384.visual.wheel.heatmap:
precompute sin/cos for all 27 arc boundaries ONCE before the cell loop,
store in arrays, reuse inside the nested loop:

```perl
# [ precompute arc boundary angles ]
my @theta;
for my $arc ( 0 .. 26 ) {
    $theta[$arc] = -$arc * $segment_deg * $PI / 180;
}
# precompute sin/cos for all angles
my @sin_theta = map { sin($theta[$_]) } 0 .. 26;
my @cos_theta = map { cos($theta[$_]) } 0 .. 26;
```

then in the cell loop use $sin_theta[$arc] etc. instead of recomputing.

also: skip cells where count == 0 (already done) AND
      skip cells where r_inner >= r_outer (degenerate):

```perl
next if $count == 0;
next if $r_inner >= $r_outer;
```

### fix: limit heatmap rings for first render

add a default of rings=13 for heatmap mode in the UI
(currently defaults to 26 — heatmap with 26 rings = 676 paths).
13 rings = 338 paths, much faster first render.

in data/web-root/vhosts/iris.v7.ax/index.html:
when user selects heatmap mode, if rings > 13, suggest reducing:
  document.getElementById('rings-input').value = '13';

---

## issue 2: namespace filter missing from ring mode

the ring (default) mode has no namespace filter option in the UI.
overlay mode has it, but ring mode should too.

### fix: add universal namespace filter to all wheel modules

add a new config key: <route.bmw384.cfg.namespace_filter>

in each wheel module, after `my @names = keys %$by_name;`:

```perl
# [ optional namespace filter ]
my $ns_filter = <route.bmw384.cfg.namespace_filter> // '';
if ( length $ns_filter ) {
    @names = grep { index( $ARG, $ns_filter ) == 0 } @names;
}
```

apply to ALL modes:
  src/route.bmw384.visual.wheel
  src/route.bmw384.visual.wheel.gauss
  src/route.bmw384.visual.wheel.heatmap
  src/route.bmw384.visual.wheel.arc-width
  src/route.bmw384.visual.wheel.metric
  src/route.bmw384.visual.wheel.density

(overlay already has its own multi-namespace system — skip it)

### fix: add namespace filter to cmd.visual-wheel

in src/route.bmw384.cmd.visual-wheel:
parse 'ns' or 'namespace' as a universal param:
  p7c index.visual-wheel file 26 ring ns=base

save/restore <route.bmw384.cfg.namespace_filter> like other params.

### fix: add namespace filter input to iris UI

in data/web-root/vhosts/iris.v7.ax/index.html:
add a namespace filter input that shows for ALL modes (not just overlay):

```html
<div class="param-row">
  <span class="param-label">namespace</span>
  <input class="param-input" id="ns-input" type="text"
         placeholder="base, kimi, jobsite..." style="width:8rem">
</div>
```

pass as `&ns=base` in the render URL.

in httpd.route.handler.iris-svg:
parse `ns` query param, save/restore <route.bmw384.cfg.namespace_filter>.

---

## issue 3: gauss mode ignores namespace param, shows full disk

in gauss mode, the `param` field is supposed to set `gauss_arcs`
(which arcs to highlight with the gaussian glow).
but the filter has no effect — all modules render.

### fix: verify gauss_arcs is being applied

in src/route.bmw384.visual.wheel.gauss:
check that <route.bmw384.cfg.gauss_arcs> is being read correctly
and that the arc_weight array is computed from it.

the issue may be that the gauss rendering highlights arcs correctly
but still renders ALL nodes (just with different opacity/size).
this is correct behavior — gauss is a glow overlay, not a filter.

### clarify in UI

in data/web-root/vhosts/iris.v7.ax/index.html:
update the gauss mode param placeholder/label to make clear:
  "arcs to glow (e.g. D,H) — all nodes still visible"

the namespace filter (issue 2) will provide actual filtering in gauss mode.

---

## summary of changes needed

modules:
  route.bmw384.visual.wheel.heatmap     (trig precompute + degenerate skip)
  route.bmw384.visual.wheel             (namespace filter)
  route.bmw384.visual.wheel.gauss       (namespace filter)
  route.bmw384.visual.wheel.arc-width   (namespace filter)
  route.bmw384.visual.wheel.metric      (namespace filter)
  route.bmw384.visual.wheel.density     (namespace filter)
  route.bmw384.cmd.visual-wheel         (parse ns= param)
  httpd.route.handler.iris-svg          (pass ns param)

html:
  data/web-root/vhosts/iris.v7.ax/index.html
    - add universal namespace filter input
    - heatmap: suggest rings=13 when mode selected
    - gauss: clarify param label

## signatures note

existing modules: re-signed on commit. leave new code clean.

## style

$ARG not $_ in loops
lowercase comments, [ word ] bracket annotations

#,,..,...,,.,,..,,,,,,.,,,...,.,,,,,,,.,.,.,.,..,,...,..,,.,.,,,,,.,.,.,.,,..,
#TZPN4JZS54UZS7B2YIFFJ2KPF5J4WW7IWYA76GRV6COSPSYX4QX3V2EQDPCCYIJEXTRQBHCAXKVPW
#\\\|F6XLH4UB34VH7DMKTRRO4HFKRVMWAELI6L2ZIPB4UL3UMTHLPL6 \ / AMOS7 \ YOURUM ::
#\[7]GZ5QPS2NY4RSA5V7A6KJKTE6DHASE4NYVXH7UOAEU3R2UNVPGCDQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
