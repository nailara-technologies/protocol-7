## [:< ##

# name  = task: iris logo overlay — nailara logo at SVG center void
# descr = embed nailara_logo.trans-dark.png at iris center via SVG image element

## context

the iris disc is a living visualization of the BMW384 field index.
the center void at (400,400) radius 24 is the darksun — position 27.
the nailara logo belongs at this center: the iris as living logo background.

## logo reference files

primary source (transparent PNG for overlay):
  data/gfx/logos/nailara_logo.trans-dark.png

additional logo variants (for visual reference):
  data/gfx/logos/nailara.png
  data/gfx/logos/nailara.jpg
  data/gfx/nailara/nailara-test.png

## logo recreation attempts — study these for visual intent

four previous AI attempts to reconstruct the logo
(original XCF lost ~2003, these show what the logo looks like):

  data/gfx/nailara/iterations/nailara-logo-v2.html
    canvas-based with interactive controls
    "Circle Cutout Construction" approach
    dark background #08081a, blue-purple palette #6060ff
    
  data/gfx/nailara/iterations/nailara-logo-debug.html
    debug/analysis version
    
  data/asc/what-AI-thinks/html-form/branding/logo-html.html
    "Psychedelic Logo Recreation"
    background #000014, animated
    
  data/asc/what-AI-thinks/html-form/branding/logo-html-v1.html
    earlier version

read these files to understand:
  - the color palette (deep blue/purple/black aesthetic)
  - the geometric structure being recreated
  - what "nailara logo" looks like visually
  - how it relates to the iris disc as its natural background

the logo at the center void (position 27 = the darksun)
should feel like the iris was always built around it.

## what to implement

### 1. in route.bmw384.visual.wheel

add SVG <image> element at center void, before </svg>:

```perl
# [ center logo — nailara at the darksun ]
my $logo_size = 44;    # diameter covering the void circle (r=24)
my $logo_xy   = 400 - $logo_size / 2;

$svg .= sprintf
    '  <image x="%.1f" y="%.1f" width="%d" height="%d"'
    . ' href="%s" opacity="0.7"'
    . ' style="mix-blend-mode:screen"/>'
    . "\n",
    $logo_xy, $logo_xy, $logo_size, $logo_size,
    '/gfx/logos/nailara_logo.trans-dark.png';
```

replace the existing center void circle with:
```perl
$svg .= '  <circle cx="400" cy="400" r="24" fill="none"'
    . ' stroke="rgba(255,255,255,0.08)" stroke-width="0.5"/>'
    . "\n";
```
(reduce opacity — logo provides the visual anchor now)

### 2. apply to all wheel modes

the image element should appear in:
  src/route.bmw384.visual.wheel          (base wheel)
  src/route.bmw384.visual.wheel.gauss    (gauss mode)
  src/route.bmw384.visual.wheel.heatmap  (heatmap mode)
  src/route.bmw384.visual.wheel.arc-width
  src/route.bmw384.visual.wheel.overlay
  src/route.bmw384.visual.wheel.metric
  src/route.bmw384.visual.wheel.density

in each: find the '# [ center void ]' comment block
replace with the logo + reduced-opacity void circle

### 3. static file serving for iris.v7.ax

the logo is referenced as /gfx/logos/nailara_logo.trans-dark.png
httpd needs to serve this from the vhost.

option A: symlink into iris.v7.ax vhost:
  data/web-root/vhosts/iris.v7.ax/gfx/ →
  data/gfx/ (or copy the logos/ subdir)

option B: add httpd route for /gfx/ path serving from data/gfx/

option A is simpler — create the directory and symlink:
```
mkdir -p data/web-root/vhosts/iris.v7.ax/gfx
ln -s /data/projects/protocol-7/data/gfx/logos \
      data/web-root/vhosts/iris.v7.ax/gfx/logos
```

### 4. sizing refinement

test at: p7c index.visual-wheel file 26
open /tmp/bmw384-wheel.html in browser
adjust $logo_size if needed:
  too small: the void feels empty
  too large: obscures inner rings
  target: fills the void circle naturally

opacity 0.7 with mix-blend-mode:screen
allows the field glow to show through
the logo glows as part of the field rather than
sitting on top of it

## signatures note

existing modules: re-signed on commit
new symlinks: not signed (not perl modules)

## style

$ARG not $_ in loops
lowercase comments, [ word ] bracket annotations

#,,,,,,,,,,.,,,.,,,..,...,..,,.,,,,,.,,.,,..,,..,,...,...,,..,,,,,,,.,.,,,.,.,
#HR54VAXLWMWVZWPQ7QBRTQGLRQCSRHUYJDKXRPWE5BOTLIAZZRB5JLL2DFMN7B3J2ZR6X4BH4GHSS
#\\\|EZTUJHZPN353BBUINWSQSXZWO3XRRNUG2QCF4AEDSUDJP4WI2AO \ / AMOS7 \ YOURUM ::
#\[7]3R3FYU4TB2AACRMU55ZCB2K7XDEX6X7NDEMNAPPNLOB72L35O6BY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
