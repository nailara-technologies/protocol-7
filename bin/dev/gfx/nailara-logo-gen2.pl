#!/usr/bin/env perl
use strict;
use warnings;
use Math::Trig qw(pi);
use Getopt::Long;

my $output = 'nailara-logo-v2.html';
my $size   = 600;
GetOptions( 'output=s' => \$output, 'size=i' => \$size );

# Read reference image as base64
my $ref_b64 = '';
if ( open my $fh, '<', '/home/claude/logo-b64.txt' ) {
    local $/;
    $ref_b64 = <$fh>;
    chomp $ref_b64;
    close $fh;
}

# === CONSTRUCTION PARAMETERS ===
# Mimicking the GIMP workflow:
# - 4 offset thick circles -> outline -> invert -> stamp -> rotate 45 -> repeat
#
# We use HTML Canvas for pixel-level boolean operations (union, subtract, outline)
# which maps directly to the GIMP stamp/mask/invert workflow.

open my $fh, '>', $output or die "Cannot write $output: $!";

print $fh <<"HTML_HEAD";
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<title>Nailara Logo v2 - Circle Cutout Construction</title>
<style>
* { margin: 0; padding: 0; box-sizing: border-box; }
body {
    background: #0a0a12; color: #8888cc;
    font-family: 'Courier New', monospace;
    display: flex; flex-direction: column; align-items: center;
    min-height: 100vh; padding: 20px;
}
h1 { color: #6060ff; font-size: 13px; letter-spacing: 3px;
     text-transform: uppercase; margin-bottom: 16px;
     text-shadow: 0 0 10px #4040ff44; }
.row { display: flex; gap: 20px; align-items: flex-start; flex-wrap: wrap; justify-content: center; }
.panel { display: flex; flex-direction: column; align-items: center; gap: 4px; }
.panel-label { font-size: 10px; color: #555577; letter-spacing: 2px; text-transform: uppercase; }
canvas { border: 1px solid #222244; background: #08081a; image-rendering: pixelated; }
.main-canvas { border: 1px solid #333366; }
.controls {
    margin-top: 16px; display: grid;
    grid-template-columns: 180px 50px 200px 32px;
    gap: 3px 8px; align-items: center; font-size: 11px;
}
.controls label { text-align: right; }
.controls input[type=range] { width: 100%; accent-color: #6060ff; }
.val { color: #aaaaff; }
button.rst { background:#1a1a2e; color:#6060ff; border:1px solid #333;
             cursor:pointer; font-size:12px; padding:1px 5px; }
.toggle-row { margin-top: 12px; display: flex; gap: 16px; font-size: 12px; }
.toggle-row label { cursor: pointer; display: flex; align-items: center; gap: 5px; }
.toggle-row input { accent-color: #6060ff; }
.step-row { margin-top: 12px; display: flex; gap: 8px; flex-wrap: wrap; justify-content: center; }
.step-row canvas { width: 96px; height: 96px; }
.info { margin-top: 10px; font-size: 10px; color: #444466; text-align: center; max-width: 700px; }
</style>
</head>
<body>
<h1>Nailara Logo v2 &mdash; Circle Cutout Construction</h1>
<div class="row">
    <div class="panel">
        <span class="panel-label">Result</span>
        <canvas id="mainCanvas" class="main-canvas" width="$size" height="$size"></canvas>
    </div>
    <div class="panel">
        <span class="panel-label">Reference</span>
        <canvas id="refCanvas" width="$size" height="$size"></canvas>
    </div>
</div>

<div class="toggle-row">
    <label><input type="checkbox" id="showOverlay" onchange="rebuild()"> Overlay on reference</label>
    <label><input type="checkbox" id="showSteps" checked onchange="toggleSteps()"> Show construction steps</label>
    <label>Overlay opacity <input type="range" id="overlayOp" min="0" max="100" value="50"
           style="width:80px;accent-color:#6060ff" oninput="rebuild()"></label>
</div>

<div class="step-row" id="stepRow"></div>

<div class="controls" id="paramControls"></div>
<div class="info">
    Construction: 4 offset thick circles &rarr; outline &rarr; invert &rarr; stamp &rarr; rotate 45&deg; &rarr; combine on center ring<br>
    Circles create leaf/vesica shapes through intersection; outline+invert creates the cutout negative
</div>
HTML_HEAD

# Reference image loading
if ($ref_b64) {
    print $fh
        qq{<img id="refImgSrc" src="data:image/png;base64,$ref_b64" style="display:none">\n};
}

print $fh "<script>\n";
print $fh "var SIZE = $size;\n";
print $fh "var HALF = SIZE / 2;\n";

print $fh <<'JSBLOCK';

// === PARAMETERS ===
var P = {
    // 4 cardinal circles
    circle_offset:    { val: 80,  min: 20,  max: 200, step: 2,  label: 'Circle offset from center' },
    circle_radius:    { val: 140, min: 40,  max: 250, step: 2,  label: 'Circle radius' },
    circle_thick:     { val: 20,  min: 4,   max: 50,  step: 1,  label: 'Circle thickness' },

    // Outline extraction
    outline_width:    { val: 10,  min: 2,   max: 30,  step: 1,  label: 'Outline width' },

    // Center ring
    center_ring_r:    { val: 120, min: 40,  max: 200, step: 2,  label: 'Center ring radius' },
    center_ring_w:    { val: 18,  min: 4,   max: 40,  step: 1,  label: 'Center ring width' },

    // Inner element
    inner_scale:      { val: 0.42, min: 0.15, max: 0.70, step: 0.01, label: 'Inner element scale' },

    // Clipping circle
    clip_radius:      { val: 180, min: 80,  max: 280, step: 2,  label: 'Clip circle radius' },

    // Visual
    glow_passes:      { val: 3,   min: 0,   max: 6,   step: 1,  label: 'Glow passes' },
    brightness:       { val: 1.0, min: 0.5,  max: 2.0, step: 0.1, label: 'Brightness' },
};

// Scale params to canvas size (designed for 512, scale proportionally)
var BASE = 512;
function sc(v) { return v * SIZE / BASE; }

// Offscreen buffer for compositing
function createBuf() {
    var c = document.createElement('canvas');
    c.width = SIZE; c.height = SIZE;
    return c;
}

function getCtx(c) { return c.getContext('2d'); }

function clearBuf(c) {
    getCtx(c).clearRect(0, 0, SIZE, SIZE);
}

// Draw a thick circle (annulus)
function drawThickCircle(ctx, cx, cy, radius, thickness) {
    var outer = radius + thickness / 2;
    var inner = radius - thickness / 2;
    ctx.beginPath();
    ctx.arc(cx, cy, outer, 0, Math.PI * 2);
    ctx.arc(cx, cy, inner, 0, Math.PI * 2, true);
    ctx.fill();
}

// Draw filled circle
function drawCircle(ctx, cx, cy, radius) {
    ctx.beginPath();
    ctx.arc(cx, cy, radius, 0, Math.PI * 2);
    ctx.fill();
}

// Extract outline from alpha: pixels where alpha > 0 that border alpha == 0
function extractOutline(srcCanvas, width) {
    var src = getCtx(srcCanvas).getImageData(0, 0, SIZE, SIZE);
    var dst = getCtx(createBuf()).createImageData(SIZE, SIZE);
    var sd = src.data;
    var dd = dst.data;
    var w = width;

    // For each pixel, if it has alpha AND there's a transparent pixel within 'width' distance
    // -> it's an edge pixel. But simpler: dilate then subtract original.
    // Actually: outline = dilate(shape, w) - erode(shape, w)

    // Method: morphological outline using distance from edge
    // Step 1: compute distance to nearest transparent pixel for each opaque pixel
    // Step 2: compute distance to nearest opaque pixel for each transparent pixel
    // Step 3: outline = pixels where dist_to_edge <= w/2

    // Simpler approach: just check neighborhood
    var half = Math.ceil(w / 2);
    for (var y = 0; y < SIZE; y++) {
        for (var x = 0; x < SIZE; x++) {
            var idx = (y * SIZE + x) * 4;
            var a = sd[idx + 3];
            var hasOpaque = false;
            var hasTrans = false;

            for (var dy = -half; dy <= half && !(hasOpaque && hasTrans); dy++) {
                for (var dx = -half; dx <= half && !(hasOpaque && hasTrans); dx++) {
                    if (dx*dx + dy*dy > half*half) continue;
                    var nx = x + dx, ny = y + dy;
                    if (nx < 0 || nx >= SIZE || ny < 0 || ny >= SIZE) {
                        hasTrans = true;
                        continue;
                    }
                    var ni = (ny * SIZE + nx) * 4;
                    if (sd[ni + 3] > 128) hasOpaque = true;
                    else hasTrans = true;
                }
            }

            if (hasOpaque && hasTrans) {
                dd[idx] = 255; dd[idx+1] = 255; dd[idx+2] = 255; dd[idx+3] = 255;
            }
        }
    }

    var outCanvas = createBuf();
    getCtx(outCanvas).putImageData(dst, 0, 0);
    return outCanvas;
}

// Invert alpha channel (opaque <-> transparent)
function invertAlpha(srcCanvas) {
    var ctx = getCtx(srcCanvas);
    var img = ctx.getImageData(0, 0, SIZE, SIZE);
    var d = img.data;
    for (var i = 0; i < d.length; i += 4) {
        if (d[i+3] > 128) {
            d[i] = 0; d[i+1] = 0; d[i+2] = 0; d[i+3] = 0;
        } else {
            d[i] = 255; d[i+1] = 255; d[i+2] = 255; d[i+3] = 255;
        }
    }
    var out = createBuf();
    getCtx(out).putImageData(img, 0, 0);
    return out;
}

// Intersect two canvases (keep pixels where BOTH have alpha)
function intersect(a, b) {
    var ad = getCtx(a).getImageData(0, 0, SIZE, SIZE).data;
    var bd = getCtx(b).getImageData(0, 0, SIZE, SIZE).data;
    var out = createBuf();
    var od = getCtx(out).createImageData(SIZE, SIZE);
    var dd = od.data;
    for (var i = 0; i < dd.length; i += 4) {
        if (ad[i+3] > 128 && bd[i+3] > 128) {
            dd[i] = 255; dd[i+1] = 255; dd[i+2] = 255; dd[i+3] = 255;
        }
    }
    getCtx(out).putImageData(od, 0, 0);
    return out;
}

// Union two canvases
function union(a, b) {
    var out = createBuf();
    var ctx = getCtx(out);
    ctx.drawImage(a, 0, 0);
    ctx.globalCompositeOperation = 'source-over';
    ctx.drawImage(b, 0, 0);
    ctx.globalCompositeOperation = 'source-over';
    return out;
}

// Subtract b from a (keep pixels in a that are NOT in b)
function subtract(a, b) {
    var out = createBuf();
    var ctx = getCtx(out);
    ctx.drawImage(a, 0, 0);
    ctx.globalCompositeOperation = 'destination-out';
    ctx.drawImage(b, 0, 0);
    ctx.globalCompositeOperation = 'source-over';
    return out;
}

// Rotate a canvas by degrees around center
function rotateCanvas(src, degrees) {
    var out = createBuf();
    var ctx = getCtx(out);
    ctx.translate(HALF, HALF);
    ctx.rotate(degrees * Math.PI / 180);
    ctx.drawImage(src, -HALF, -HALF);
    return out;
}

// Scale a canvas from center
function scaleCanvas(src, factor) {
    var out = createBuf();
    var ctx = getCtx(out);
    var offset = HALF * (1 - factor);
    ctx.drawImage(src, offset, offset, SIZE * factor, SIZE * factor);
    return out;
}

// Clip to circle
function clipToCircle(src, radius) {
    var out = createBuf();
    var ctx = getCtx(out);
    ctx.beginPath();
    ctx.arc(HALF, HALF, sc(radius), 0, Math.PI * 2);
    ctx.clip();
    ctx.drawImage(src, 0, 0);
    return out;
}

// Record construction steps
var steps = [];

function recordStep(canvas, label) {
    var copy = createBuf();
    getCtx(copy).drawImage(canvas, 0, 0);
    steps.push({ canvas: copy, label: label });
}

function rebuild() {
    steps = [];

    // === STEP 1: Four thick circles at cardinal positions ===
    var fourCircles = createBuf();
    var ctx = getCtx(fourCircles);
    ctx.fillStyle = 'white';
    var offset = sc(P.circle_offset.val);
    var radius = sc(P.circle_radius.val);
    var thick = sc(P.circle_thick.val);

    // N, E, S, W
    var offsets = [[0, -1], [1, 0], [0, 1], [-1, 0]];
    for (var i = 0; i < 4; i++) {
        var cx = HALF + offsets[i][0] * offset;
        var cy = HALF + offsets[i][1] * offset;
        drawThickCircle(ctx, cx, cy, radius, thick);
    }
    recordStep(fourCircles, '1: Four circles');

    // === STEP 2: Extract outline of the combined shape ===
    var outlined = extractOutline(fourCircles, Math.round(sc(P.outline_width.val)));
    recordStep(outlined, '2: Outline');

    // === STEP 3: Invert ===
    var inverted = invertAlpha(outlined);
    recordStep(inverted, '3: Inverted');

    // === STEP 4: Clip inverted to a circle (clean up) ===
    var clipped = clipToCircle(inverted, P.clip_radius.val);
    recordStep(clipped, '4: Clipped');

    // === STEP 5: Create the "stamp" - intersect with original four circles area ===
    // The stamp is the inverted outline masked to the region of interest
    var stamp = intersect(clipped, fourCircles);
    recordStep(stamp, '5: Stamp');

    // === STEP 6: Add center ring ===
    var withRing = createBuf();
    ctx = getCtx(withRing);
    ctx.drawImage(stamp, 0, 0);
    ctx.fillStyle = 'white';
    drawThickCircle(ctx, HALF, HALF, sc(P.center_ring_r.val), sc(P.center_ring_w.val));
    recordStep(withRing, '6: + Center ring');

    // === STEP 7: Rotate 45 degrees for inner element ===
    var rotated = rotateCanvas(withRing, 45);
    var scaled = scaleCanvas(rotated, P.inner_scale.val);
    recordStep(scaled, '7: Rot45 + scale');

    // === STEP 8: Combine outer + inner ===
    var combined = union(withRing, scaled);
    recordStep(combined, '8: Combined');

    // === STEP 9: Final clip to clean circle ===
    var final = clipToCircle(combined, P.clip_radius.val);
    recordStep(final, '9: Final clip');

    // === RENDER ===
    var mainCanvas = document.getElementById('mainCanvas');
    var mainCtx = mainCanvas.getContext('2d');
    mainCtx.clearRect(0, 0, SIZE, SIZE);

    // Colorize: white -> blue with glow
    var colorized = colorize(final);

    // Apply glow
    var glowPasses = P.glow_passes.val;
    if (glowPasses > 0) {
        mainCtx.filter = 'blur(' + (glowPasses * 3) + 'px) brightness(' + P.brightness.val + ')';
        mainCtx.globalAlpha = 0.5;
        mainCtx.drawImage(colorized, 0, 0);
        mainCtx.filter = 'blur(' + glowPasses + 'px)';
        mainCtx.globalAlpha = 0.7;
        mainCtx.drawImage(colorized, 0, 0);
    }
    mainCtx.filter = 'none';
    mainCtx.globalAlpha = 1.0;
    mainCtx.drawImage(colorized, 0, 0);

    // Overlay on reference
    var refCanvas = document.getElementById('refCanvas');
    var refCtx = refCanvas.getContext('2d');
    refCtx.clearRect(0, 0, SIZE, SIZE);
    var refImg = document.getElementById('refImgSrc');
    if (refImg && refImg.complete) {
        refCtx.drawImage(refImg, 0, 0, SIZE, SIZE);
        if (document.getElementById('showOverlay').checked) {
            var op = parseInt(document.getElementById('overlayOp').value) / 100;
            refCtx.globalAlpha = op;
            refCtx.drawImage(colorized, 0, 0);
            refCtx.globalAlpha = 1.0;
        }
    }

    // Show steps
    showSteps();
}

function colorize(src) {
    var out = createBuf();
    var sCtx = getCtx(src);
    var oCtx = getCtx(out);
    var img = sCtx.getImageData(0, 0, SIZE, SIZE);
    var d = img.data;
    var br = P.brightness.val;
    for (var i = 0; i < d.length; i += 4) {
        if (d[i+3] > 10) {
            var v = d[i+3] / 255;
            d[i] = Math.min(255, Math.round(40 * v * br));    // R
            d[i+1] = Math.min(255, Math.round(50 * v * br));  // G
            d[i+2] = Math.min(255, Math.round(255 * v * br)); // B
            d[i+3] = Math.min(255, Math.round(d[i+3] * br));
        }
    }
    oCtx.putImageData(img, 0, 0);
    return out;
}

function showSteps() {
    var row = document.getElementById('stepRow');
    if (!document.getElementById('showSteps').checked) {
        row.style.display = 'none';
        return;
    }
    row.style.display = 'flex';
    row.innerHTML = '';
    for (var i = 0; i < steps.length; i++) {
        var wrap = document.createElement('div');
        wrap.className = 'panel';
        var lbl = document.createElement('span');
        lbl.className = 'panel-label';
        lbl.textContent = steps[i].label;
        lbl.style.fontSize = '8px';
        var c = document.createElement('canvas');
        c.width = 96; c.height = 96;
        c.style.cssText = 'width:96px;height:96px;border:1px solid #222;background:#050510;image-rendering:pixelated';
        var ctx = c.getContext('2d');
        ctx.drawImage(steps[i].canvas, 0, 0, 96, 96);
        wrap.appendChild(lbl);
        wrap.appendChild(c);
        row.appendChild(wrap);
    }
}

function toggleSteps() { showSteps(); }

function buildControls() {
    var ct = document.getElementById('paramControls');
    ct.innerHTML = '';
    var keys = Object.keys(P);
    for (var i = 0; i < keys.length; i++) {
        var key = keys[i];
        var p = P[key];
        var label = document.createElement('label');
        label.textContent = p.label;
        var valSpan = document.createElement('span');
        valSpan.className = 'val';
        valSpan.id = 'val_' + key;
        valSpan.textContent = p.val;
        var input = document.createElement('input');
        input.type = 'range';
        input.min = p.min; input.max = p.max; input.step = p.step; input.value = p.val;
        input.dataset.key = key;
        input.oninput = function() {
            P[this.dataset.key].val = parseFloat(this.value);
            document.getElementById('val_' + this.dataset.key).textContent = this.value;
            rebuild();
        };
        var rst = document.createElement('button');
        rst.className = 'rst'; rst.textContent = '\u21BA';
        rst.dataset.key = key; rst.dataset.orig = p.val;
        rst.onclick = function() {
            var k = this.dataset.key, ov = parseFloat(this.dataset.orig);
            P[k].val = ov;
            this.parentNode.querySelector('input[data-key="' + k + '"]').value = ov;
            document.getElementById('val_' + k).textContent = ov;
            rebuild();
        };
        ct.appendChild(label); ct.appendChild(valSpan);
        ct.appendChild(input); ct.appendChild(rst);
    }
}

// Init
var refImg = document.getElementById('refImgSrc');
if (refImg) {
    refImg.onload = function() { rebuild(); };
    if (refImg.complete) rebuild();
} else {
    rebuild();
}
buildControls();

</script>
</body>
</html>
JSBLOCK

close $fh;
print "Generated: $output (" . ( -s $output ) . " bytes)\n";

#,,..,,..,...,...,,.,,,..,,..,...,,,,,.,.,.,,,..,,...,...,,,.,..,,.,,,,,.,...,
#T2QL3DCNYRXZ6FMI5KTMEI3TISL5E4OUP7MPEYAZF77JQLDFMH57XO5HZSNCQ5Y22XJZXPHP4ULZY
#\\\|E54ZBAPITY3CYMHBRSIYS4HQUMF32QLAVCLFSQGDAD5B5J5KVLO \ / AMOS7 \ YOURUM ::
#\[7]6WGGRZFB2BL65ZPASD5F6YXAS3OQXEHXVNRNHJYDB4HX3CM2LQBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
