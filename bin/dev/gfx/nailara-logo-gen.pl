#!/usr/bin/env perl
use strict;
use warnings;
use POSIX      qw(ceil floor);
use Math::Trig qw(pi);
use Getopt::Long;

my $output = 'nailara-logo-debug.html';
my $size   = 512;
GetOptions( 'output=s' => \$output, 'size=i' => \$size );

# === GEOMETRIC PARAMETERS (normalized 0..1) ===
my %P = (
    void_r         => 0.125,
    inner_r1       => 0.140,
    inner_r2       => 0.234,
    body_r1        => 0.266,
    body_r2        => 0.484,
    outer_r1       => 0.594,
    outer_r2       => 0.750,
    arm_half_angle => 28,
    inner_scale    => 0.48,
    inner_rot      => 45,
    glow_radius    => 8,
    line_w         => 0.025,
    line_color     => '#6060ff',
);

# Read reference image as base64
my $ref_b64 = '';
if ( open my $fh, '<', '/home/claude/logo-b64.txt' ) {
    local $/;
    $ref_b64 = <$fh>;
    chomp $ref_b64;
    close $fh;
}

my $half = $size / 2;

# Generate SVG element group
sub gen_element_svg {
    my ( $scale, $rotation ) = @_;
    my $sw = $P{line_w} * $half * $scale;
    $sw = 1.5 if $sw < 1.5;
    my $lc = $P{line_color};
    my @lines;

    push @lines, qq{<g transform="translate($half,$half) rotate($rotation)">};

    # Concentric circles
    for my $rn (
        $P{void_r},  $P{inner_r1}, $P{inner_r2}, $P{body_r1},
        $P{body_r2}, $P{outer_r1}, $P{outer_r2}
    ) {
        my $r = $rn * $half * $scale;
        push @lines,
            qq{  <circle cx="0" cy="0" r="$r" stroke="$lc" fill="none" stroke-width="$sw"/>};
    }

    # Arms at 0, 90, 180, 270
    my $aha    = $P{arm_half_angle};
    my $bodyR  = $P{body_r2} * $half * $scale;
    my $outerR = $P{outer_r2} * $half * $scale;
    my $midR   = ( $bodyR + $outerR ) / 2;

    for my $arm_angle ( 0, 90, 180, 270 ) {
        my $a1 = ( $arm_angle - $aha ) * pi / 180;
        my $a2 = ( $arm_angle + $aha ) * pi / 180;

        for my $a ( $a1, $a2 ) {
            my ( $x1, $y1 ) = ( $bodyR * cos($a),  $bodyR * sin($a) );
            my ( $x2, $y2 ) = ( $outerR * cos($a), $outerR * sin($a) );
            push @lines,
                sprintf(
                '  <line x1="%.2f" y1="%.2f" x2="%.2f" y2="%.2f" stroke="%s" fill="none" stroke-width="%.2f"/>',
                $x1, $y1, $x2, $y2, $lc, $sw );
        }

        for my $r ( $bodyR, $midR, $outerR ) {
            my ( $x1, $y1 ) = ( $r * cos($a1), $r * sin($a1) );
            my ( $x2, $y2 ) = ( $r * cos($a2), $r * sin($a2) );
            push @lines,
                sprintf(
                '  <path d="M %.2f %.2f A %.2f %.2f 0 0 1 %.2f %.2f" stroke="%s" fill="none" stroke-width="%.2f"/>',
                $x1, $y1, $r, $r, $x2, $y2, $lc, $sw );
        }
    }

    push @lines, '</g>';
    return join( "\n", @lines );
}

my $svg_outer = gen_element_svg( 1.0,             0 );
my $svg_inner = gen_element_svg( $P{inner_scale}, $P{inner_rot} );

# Build parameter JSON for JS
my @param_json;
for my $spec (
    [ 'void_r',         $P{void_r},   0.05, 0.25, 0.005, 'Void radius' ],
    [ 'inner_r1',       $P{inner_r1}, 0.05, 0.30, 0.005, 'Inner ring start' ],
    [ 'inner_r2',       $P{inner_r2}, 0.10, 0.40, 0.005, 'Inner ring end' ],
    [ 'body_r1',        $P{body_r1},  0.15, 0.40, 0.005, 'Body start' ],
    [ 'body_r2',        $P{body_r2},  0.30, 0.60, 0.005, 'Body end' ],
    [ 'outer_r1',       $P{outer_r1}, 0.40, 0.70, 0.005, 'Outer ring start' ],
    [ 'outer_r2',       $P{outer_r2}, 0.50, 0.95, 0.005, 'Outer ring end' ],
    [ 'arm_half_angle', $P{arm_half_angle}, 10, 45, 1,   'Arm half-angle' ],
    [ 'inner_scale', $P{inner_scale}, 0.20,  0.70,  0.01,  'Inner scale' ],
    [ 'inner_rot',   $P{inner_rot},   0,     90,    1,     'Inner rotation' ],
    [ 'glow_radius', $P{glow_radius}, 0,     20,    1,     'Glow radius' ],
    [ 'line_w',      $P{line_w},      0.005, 0.06,  0.005, 'Line width' ],
) {
    my ( $k, $v, $min, $max, $step, $label ) = @$spec;
    push @param_json,
        qq{  "$k": {"val":$v,"min":$min,"max":$max,"step":$step,"label":"$label"}};
}
my $params_json = "{\n" . join( ",\n", @param_json ) . "\n}";

# === Write HTML ===
open my $fh, '>', $output or die "Cannot write $output: $!";
print $fh <<"HTML_HEAD";
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<title>Nailara Logo - Parametric Reconstruction</title>
<style>
* { margin: 0; padding: 0; box-sizing: border-box; }
body {
    background: #0a0a12; color: #8888cc;
    font-family: 'Courier New', monospace;
    display: flex; flex-direction: column; align-items: center;
    min-height: 100vh; padding: 20px;
}
h1 { color: #6060ff; font-size: 14px; letter-spacing: 4px;
     text-transform: uppercase; margin-bottom: 20px;
     text-shadow: 0 0 10px #4040ff44; }
.canvas-wrap {
    position: relative; width: ${size}px; height: ${size}px;
    border: 1px solid #222244; background: #08081a;
}
.canvas-wrap svg { position: absolute; top:0; left:0; width:100%; height:100%; }
.ref-overlay {
    position: absolute; top:0; left:0; width:100%; height:100%;
    opacity: 0.35; pointer-events: none; image-rendering: pixelated;
    mix-blend-mode: screen;
}
.controls {
    margin-top: 20px;
    display: grid; grid-template-columns: 160px 55px 200px 32px;
    gap: 4px 8px; align-items: center; font-size: 11px;
}
.controls label { text-align: right; }
.controls input[type=range] { width: 100%; accent-color: #6060ff; }
.val { color: #aaaaff; font-size: 11px; }
.toggle-row { margin-top: 16px; display: flex; gap: 16px; font-size: 12px; }
.toggle-row label { cursor: pointer; display: flex; align-items: center; gap: 6px; }
.toggle-row input { accent-color: #6060ff; }
.info { margin-top: 12px; font-size: 10px; color: #444466; text-align: center; }
button.rst { background:#1a1a2e; color:#6060ff; border:1px solid #333;
             cursor:pointer; font-size:12px; padding:1px 5px; }
</style>
</head>
<body>
<h1>Nailara Logo Reconstruction</h1>
<div class="canvas-wrap" id="canvasWrap">
    <svg id="logoSvg" viewBox="0 0 $size $size" xmlns="http://www.w3.org/2000/svg">
        <defs><filter id="glow"><feGaussianBlur stdDeviation="$P{glow_radius}" result="blur"/>
        <feMerge><feMergeNode in="blur"/><feMergeNode in="SourceGraphic"/></feMerge></filter></defs>
        <g filter="url(#glow)">
$svg_outer
$svg_inner
        </g>
    </svg>
HTML_HEAD

if ($ref_b64) {
    print $fh
        qq{    <img class="ref-overlay" id="refImg" src="data:image/png;base64,$ref_b64" alt="ref">\n};
}

# JS as a separate block - no heredoc interpolation issues
print $fh <<'HTML_MID';
</div>
<div class="toggle-row">
    <label><input type="checkbox" id="showRef" checked onchange="toggleRef()"> Reference overlay</label>
    <label><input type="range" id="refOpacity" min="0" max="100" value="35" style="width:100px;accent-color:#6060ff"
           oninput="document.getElementById('refImg').style.opacity=this.value/100"> Ref opacity</label>
</div>
<div class="controls" id="paramControls"></div>
<div class="info">Self-similar design: inner = outer &times; scale @ rotation CCW | Original ~2003 GIMP circle-cutout</div>
<script>
HTML_MID

# Inject the params JSON
print $fh "var PARAMS = $params_json;\n";
print $fh "var SIZE = $size;\n";
print $fh "var HALF = SIZE / 2;\n";
print $fh "var LINE_COLOR = '$P{line_color}';\n";

# Now the JS logic with no interpolation concerns
print $fh <<'JSBLOCK';

function r2px(n, s) { return n * HALF * (s || 1); }

function genElement(scale, rotation) {
    var sw = Math.max(1.5, r2px(PARAMS.line_w.val, scale));
    var lc = LINE_COLOR;
    var s = '<g transform="translate(' + HALF + ',' + HALF + ') rotate(' + rotation + ')">\n';

    var radii = [PARAMS.void_r.val, PARAMS.inner_r1.val, PARAMS.inner_r2.val,
                 PARAMS.body_r1.val, PARAMS.body_r2.val, PARAMS.outer_r1.val, PARAMS.outer_r2.val];
    for (var i = 0; i < radii.length; i++) {
        var r = r2px(radii[i], scale);
        s += '  <circle cx="0" cy="0" r="' + r + '" stroke="' + lc + '" fill="none" stroke-width="' + sw + '"/>\n';
    }

    var aha = PARAMS.arm_half_angle.val;
    var bodyR = r2px(PARAMS.body_r2.val, scale);
    var outerR = r2px(PARAMS.outer_r2.val, scale);
    var midR = (bodyR + outerR) / 2;

    for (var aa = 0; aa < 360; aa += 90) {
        var a1 = (aa - aha) * Math.PI / 180;
        var a2 = (aa + aha) * Math.PI / 180;
        var angles = [a1, a2];
        for (var j = 0; j < 2; j++) {
            var a = angles[j];
            s += '  <line x1="' + (bodyR*Math.cos(a)) + '" y1="' + (bodyR*Math.sin(a)) +
                 '" x2="' + (outerR*Math.cos(a)) + '" y2="' + (outerR*Math.sin(a)) +
                 '" stroke="' + lc + '" fill="none" stroke-width="' + sw + '"/>\n';
        }
        var rads = [bodyR, midR, outerR];
        for (var j = 0; j < rads.length; j++) {
            var r = rads[j];
            s += '  <path d="M ' + (r*Math.cos(a1)) + ' ' + (r*Math.sin(a1)) +
                 ' A ' + r + ' ' + r + ' 0 0 1 ' + (r*Math.cos(a2)) + ' ' + (r*Math.sin(a2)) +
                 '" stroke="' + lc + '" fill="none" stroke-width="' + sw + '"/>\n';
        }
    }
    s += '</g>\n';
    return s;
}

function rebuild() {
    var svgEl = document.getElementById('logoSvg');
    var glowR = PARAMS.glow_radius.val;
    var c = '<defs><filter id="glow"><feGaussianBlur stdDeviation="' + glowR + '" result="blur"/>' +
            '<feMerge><feMergeNode in="blur"/><feMergeNode in="SourceGraphic"/></feMerge></filter></defs>' +
            '<g filter="url(#glow)">\n';
    c += genElement(1.0, 0);
    c += genElement(PARAMS.inner_scale.val, PARAMS.inner_rot.val);
    c += '</g>';
    svgEl.innerHTML = c;
}

function buildControls() {
    var ct = document.getElementById('paramControls');
    ct.innerHTML = '';
    var keys = Object.keys(PARAMS);
    for (var i = 0; i < keys.length; i++) {
        var key = keys[i];
        var p = PARAMS[key];
        var origVal = p.val;

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
            PARAMS[this.dataset.key].val = parseFloat(this.value);
            document.getElementById('val_' + this.dataset.key).textContent = this.value;
            rebuild();
        };

        var rst = document.createElement('button');
        rst.className = 'rst';
        rst.textContent = '\u21BA';
        rst.dataset.key = key;
        rst.dataset.orig = origVal;
        rst.onclick = function() {
            var k = this.dataset.key;
            var ov = parseFloat(this.dataset.orig);
            PARAMS[k].val = ov;
            var inp = this.parentNode.querySelector('input[data-key="' + k + '"]');
            if (inp) inp.value = ov;
            document.getElementById('val_' + k).textContent = ov;
            rebuild();
        };

        ct.appendChild(label);
        ct.appendChild(valSpan);
        ct.appendChild(input);
        ct.appendChild(rst);
    }
}

function toggleRef() {
    var img = document.getElementById('refImg');
    if (img) img.style.display = document.getElementById('showRef').checked ? '' : 'none';
}

buildControls();
rebuild();
</script>
</body>
</html>
JSBLOCK

close $fh;
print "Generated: $output (" . ( -s $output ) . " bytes)\n";

#,,,.,...,,.,,,,.,.,.,,,,,,,.,,,,,.,.,.,.,,..,..,,...,..,,..,,,.,,,..,,..,,,,,
#JVT2CME4JMZZP2K4DB6KRFJOP4KJ2MWJMEFSBOEQ5DPH3JEHA6QGATGRSAJNLR2QJWA6ALP2IQL6Q
#\\\|U5FJECLZJLDSSFIV4XFRMT7G2ZF5VFGSQXFUX5JPTRF4TT7QAVS \ / AMOS7 \ YOURUM ::
#\[7]YS3XBWRUKVZMQMPLVHAE3ST4NYLLGHV5VJ7U2UQ6ZUDTEGY2BCCA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
