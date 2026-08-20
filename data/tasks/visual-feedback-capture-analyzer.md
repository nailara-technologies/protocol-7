# task: visual-feedback capture and analysis pipeline

## context

implements the frame-intelligence half of the visual feedback editor
(see data/md/development/VISUAL-FEEDBACK-EDITOR.md for full design).

the system lets local vision models (qwen, kimi-vision) autonomously refine
visual designs by seeing what they produce. this task builds the capture,
delta analysis, frame selection, and minimap generation modules.

the vision model evaluation loop is a separate task (visual-feedback-vision-loop.md).

## signatures note

do not add signature stubs. run `bin/Protocol-7 sourcecode update-signatures` when done.

---

## prerequisite check

verify these exist before implementing:
```bash
which chromium || which chromium-browser || which firefox
which Xvfb
p7 screenshot.capture --help   ## check screenshot zenka api
```

if chromium not available: use whatever browser is installed.
the browser command is configurable in zenka-startup.v7.

---

## modules to implement

### visual-feedback.capture-sequence

renders an HTML file in xvfb and captures N frames at regular intervals.

```
args: {
  file       => '/path/to/visualization.html',
  frames     => 60,       ## number of frames to capture
  interval   => 50,       ## ms between frames
  display    => ':99',    ## xvfb display
  width      => 1280,     ## viewport width
  height     => 900,      ## viewport height
  output_dir => '/var/protocol-7/visual-feedback/capture/',
}

returns: {
  frame_paths => [ 'frame_0001.png', ... 'frame_0060.png' ],
  duration_ms => 3000,
  frame_count => 60,
}

implementation:
  1. ensure xvfb is running on cfg.xvfb_display
     start if needed: Xvfb :99 -screen 0 1280x900x24 &
  2. launch browser with --display=:99
     chromium --headless=new --window-size=1280,900 \
              --screenshot --run-all-compositor-stages-before-draw \
              "file:///path/to/file.html"
     OR use browser zenka if available: p7 browser.render ...
  3. for animated files: use puppeteer-compatible approach or
     capture via xwd/scrot at intervals in a loop:
     for i in seq 1 $frames; do
       DISPLAY=:99 scrot frame_$(printf '%04d' $i).png
       sleep $interval_ms/1000
     done
  4. return list of captured frame paths
```

### visual-feedback.analyze-delta

computes pixel delta between consecutive frames and selects informative ones.

```
args: {
  frame_paths => [ 'frame_0001.png', ... ],
  peak_threshold   => 0.15,   ## minimum normalized delta for a peak
  peak_min_spacing => 6,      ## minimum frames between selected peaks
  select_max       => 8,      ## maximum frames to select
}

returns: {
  delta_curve      => [ 0.02, 0.03, 0.51, 0.67, ... ],  ## one value per pair
  selected_indices => [ 0, 12, 31, 45, 58, 22, 59 ],    ## selected frame indices
  selected_paths   => [ 'frame_0001.png', ... ],         ## selected frame files
  peak_positions   => [ 12, 31, 45 ],                    ## where peaks are
  timestamps_ms    => [ 0, 600, 1550, 2250, 2900, 1100, 2950 ],
}

implementation using Imager perl module:
  use Imager;

  my @deltas;
  for my $i ( 0 .. $#frame_paths - 1 ) {
    my $img_a = Imager->new( file => $frame_paths[$i]     ) or die;
    my $img_b = Imager->new( file => $frame_paths[$i + 1] ) or die;

    ## get pixel data as raw bytes
    my $data_a = $img_a->getpixel( x => 0, y => 0, ... );
    ## compute mean absolute difference across all pixels
    ## normalize to [0, 1]
    push @deltas, $normalized_delta;
  }

  ## peak detection
  my @peaks;
  for my $i ( 1 .. $#deltas - 1 ) {
    next if $deltas[$i] < $args{peak_threshold};
    next if $deltas[$i] <= $deltas[$i-1];
    next if $deltas[$i] <= $deltas[$i+1];
    push @peaks, { index => $i, delta => $deltas[$i] };
  }

  ## enforce minimum spacing between peaks
  ## sort by delta descending, select top K with spacing enforced

  ## add bookends (first and last frame always included)
  ## add 1-2 low-delta baseline frames

  ## sort selected by time order for minimap display
```

note on pixel comparison: if Imager is unavailable, use GD.pm or
fallback to external `compare` from ImageMagick:
  `compare -metric MAE frame_a.png frame_b.png /dev/null 2>&1`
  parse the output for the mean absolute error value.

### visual-feedback.render-minimap

generates a minimap HTML file and renders it to a single image.

```
args: {
  selected_paths   => [ 'frame_0001.png', ... ],
  timestamps_ms    => [ 0, 600, 1550, ... ],
  delta_curve      => [ 0.02, 0.51, ... ],
  peak_positions   => [ 12, 31, 45 ],
  output_dir       => '/var/protocol-7/visual-feedback/',
  thumb_width      => 160,
  thumb_height     => 120,
}

returns: {
  minimap_html => '/var/protocol-7/visual-feedback/minimap.html',
  minimap_png  => '/var/protocol-7/visual-feedback/minimap.png',
}

the minimap HTML structure:
  <!DOCTYPE html>
  <html>
  <head>
    <style>
      body { background: #050510; margin: 0; padding: 16px;
             font-family: monospace; color: #E8E0F0; }
      .timeline { display: flex; gap: 8px; align-items: flex-end; }
      .frame { text-align: center; }
      .frame img { width: 160px; height: 120px; border: 1px solid #4A235A; }
      .frame.peak img { border-color: #FFD700; box-shadow: 0 0 8px #FFD700; }
      .timestamp { font-size: 10px; color: #7A7090; margin-top: 4px; }
      .delta-chart { margin-top: 12px; }
    </style>
  </head>
  <body>
    <div class="timeline">
      [thumbnails with timestamps]
    </div>
    <svg class="delta-chart" width="100%" height="60">
      [delta curve as SVG path]
      [▲ markers at selected frame positions]
    </svg>
  </body>
  </html>

render the minimap HTML using the browser zenka / xvfb:
  DISPLAY=:99 chromium --headless --screenshot=minimap.png minimap.html
```

---

## zenka configuration

```
## cfg/zenki/visual-feedback/start
[load_modules:visual-feedback.capture-sequence visual-feedback.analyze-delta
              visual-feedback.render-minimap]
[init_modules]
[zenka.loop]
```

```
## cfg/zenki/visual-feedback/zenka-startup.v7
start.on-demand = 1
restart.disabled = 1
heartbeat.disabled = 1

cfg.capture_frames       = 60
cfg.capture_interval_ms  = 50
cfg.select_frames_max    = 8
cfg.peak_threshold       = 0.15
cfg.peak_min_spacing     = 6
cfg.xvfb_display         = :99
cfg.browser              = chromium
cfg.output_dir           = /var/protocol-7/visual-feedback/
cfg.thumb_width          = 160
cfg.thumb_height         = 120
```

---

## test sequence

```bash
## 1. capture frames from existing iris visualization
p7 visual-feedback.capture-sequence '{
  "file": "data/web-root/vhosts/viz.v7.ax/iris.html",
  "frames": 30
}'

## 2. analyze the captured frames
p7 visual-feedback.analyze-delta '{
  "frame_paths": ["..."]
}'

## 3. render the minimap
p7 visual-feedback.render-minimap '{
  "selected_paths": ["..."],
  "timestamps_ms": [...],
  "delta_curve": [...]
}'

## 4. verify: open minimap.html in browser
##    it should show thumbnails of the iris animation at key moments
##    with a delta curve showing when the arms are sweeping

## 5. verify delta peaks correspond to visible motion:
##    peak frames should show arms at different rotational positions
##    baseline frames should show arms near the same position
```

## success criteria

- [ ] capture-sequence produces N PNG files in output_dir
- [ ] analyze-delta computes delta_curve with one value per frame pair
- [ ] peak detection selects frames that visually show the most change
- [ ] selected frames always include first and last frame
- [ ] render-minimap produces valid HTML with thumbnails + SVG delta curve
- [ ] minimap.png renders cleanly (thumbnails visible, delta curve readable)
- [ ] peak frames in minimap have gold border (visual distinction)
- [ ] full sequence from iris.html → minimap.png completes in under 30 seconds

#,,..,..,,,,.,,.,,,..,.,.,,..,,.,,,,,,,..,...,..,,...,...,..,,,..,...,,,,,..,,
#45JCZRSMGA34NSL2GFU35K75YRSCCLKYF4PNVOIPUZSY6RPG5WGFKQTMZR7FUQY5IL7HY5QLHXCIK
#\\\|MOLLR7DIQ6A6BAEJAOWFMM2VOLSXGMKLWGCCZDM5QS7LCAZZX2R \ / AMOS7 \ YOURUM ::
#\[7]GSTW7NR2TA6RKXM2SOIXGT4VVDWSDDYAMOC5U2CQTBCSP52E4YDA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
