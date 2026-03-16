#!/usr/bin/env perl
# nailara-tool.pl - Scriptable circle-based image construction toolkit
# Outputs PNG via GD. All coordinates in 128px space, scaled to output.
#
# Usage: perl nailara-tool.pl [--size 1024] [--out logo.png] [--preview steps.html] [--ref ref.png]
#
# Edit the BUILD section at the bottom.

use strict;
use warnings;
use GD;
use Math::Trig qw(pi);
use Getopt::Long;

my $OUT_SIZE = 1024;
my $OUT_FILE = 'nailara.png';
my $PREVIEW  = '';
my $REF_IMG  = '';
my $COORD    = 128;

GetOptions(
    'size=i'    => \$OUT_SIZE,
    'out=s'     => \$OUT_FILE,
    'preview=s' => \$PREVIEW,
    'ref=s'     => \$REF_IMG,
    'coord=i'   => \$COORD,
) or die "Usage: $0 [options]\n";

my $SCALE = $OUT_SIZE / $COORD;
my $HALF  = $COORD / 2;
my @layers;
my $current;

sub px { $_[0] * $SCALE }

sub _mk {
    my $img = GD::Image->new( $OUT_SIZE, $OUT_SIZE, 1 );
    $img->saveAlpha(1);
    $img->alphaBlending(0);
    $img->filledRectangle(
        0, 0,
        $OUT_SIZE - 1,
        $OUT_SIZE - 1,
        $img->colorAllocateAlpha( 0, 0, 0, 127 )
    );
    return $img;
}

# === LAYERS ===
sub new_layer {
    my ($name) = @_;
    push @layers, { name => $name // "L" . scalar(@layers), img => _mk() };
    $current = $#layers;
    printf STDERR "  [new] %s (#%d)\n", $layers[$current]{name}, $current;
    return $current;
}

sub dup_layer {
    my ( $src, $name ) = @_;
    $src //= $current;
    my $dst = _mk();
    $dst->copy( $layers[$src]{img}, 0, 0, 0, 0, $OUT_SIZE, $OUT_SIZE );
    push @layers,
        { name => $name // $layers[$src]{name} . "_cp", img => $dst };
    $current = $#layers;
    printf STDERR "  [dup] -> %s (#%d)\n", $layers[$current]{name}, $current;
    return $current;
}

# === PRIMITIVES (128px coord space) ===
sub fill_disc {
    my (%o) = @_;
    my ( $cx, $cy, $r )
        = ( px( $o{cx} // $HALF ), px( $o{cy} // $HALF ), px( $o{r} ) );
    my $img = $layers[$current]{img};
    $img->alphaBlending(1);
    $img->filledEllipse(
        int($cx), int($cy),
        int( $r * 2 ),
        int( $r * 2 ),
        $img->colorAllocateAlpha( 255, 255, 255, 0 )
    );
    printf STDERR "  [disc+] r=%g @ (%g,%g)\n", $o{r}, $o{cx} // $HALF,
        $o{cy} // $HALF;
}

sub fill_ring {
    my (%o) = @_;
    my ( $cx, $cy ) = ( px( $o{cx} // $HALF ), px( $o{cy} // $HALF ) );
    my ( $ro, $ri ) = ( px( $o{r_out} ), px( $o{r_in} ) );
    my $img = $layers[$current]{img};
    $img->alphaBlending(1);
    $img->filledEllipse(
        int($cx), int($cy),
        int( $ro * 2 ),
        int( $ro * 2 ),
        $img->colorAllocateAlpha( 255, 255, 255, 0 )
    );
    $img->alphaBlending(0);
    $img->filledEllipse(
        int($cx), int($cy),
        int( $ri * 2 ),
        int( $ri * 2 ),
        $img->colorAllocateAlpha( 0, 0, 0, 127 )
    );
    $img->alphaBlending(1);
    printf STDERR "  [ring+] %g->%g\n", $o{r_out}, $o{r_in};
}

sub cut_disc {
    my (%o) = @_;
    my ( $cx, $cy, $r )
        = ( px( $o{cx} // $HALF ), px( $o{cy} // $HALF ), px( $o{r} ) );
    my $img = $layers[$current]{img};
    $img->alphaBlending(0);
    $img->filledEllipse(
        int($cx), int($cy),
        int( $r * 2 ),
        int( $r * 2 ),
        $img->colorAllocateAlpha( 0, 0, 0, 127 )
    );
    $img->alphaBlending(1);
    printf STDERR "  [disc-] r=%g @ (%g,%g)\n", $o{r}, $o{cx} // $HALF,
        $o{cy} // $HALF;
}

sub cut_cardinal {
    my (%o) = @_;
    my $a0 = ( $o{angle} // 0 ) * pi() / 180;
    for my $i ( 0 .. 3 ) {
        my $a = $a0 + $i * pi() / 2;
        cut_disc(
            cx => $HALF + cos($a) * $o{offset},
            cy => $HALF + sin($a) * $o{offset},
            r  => $o{r}
        );
    }
}

sub cut_radial {
    my (%o) = @_;
    my $n   = $o{n} // 4;
    my $a0  = ( $o{angle} // 0 ) * pi() / 180;
    for my $i ( 0 .. $n - 1 ) {
        my $a = $a0 + $i * 2 * pi() / $n;
        cut_disc(
            cx => $HALF + cos($a) * $o{offset},
            cy => $HALF + sin($a) * $o{offset},
            r  => $o{r}
        );
    }
}

# === TRANSFORMS ===
sub rotate_layer {
    my (%o)  = @_;
    my $si   = $o{layer} // $current;
    my $deg  = $o{angle};
    my $name = $o{name} // "rot$deg";
    my $src  = $layers[$si]{img};
    my $dst  = _mk();
    my $rad  = -$deg * pi() / 180;
    my ( $ca, $sa ) = ( cos($rad), sin($rad) );
    my $c = $OUT_SIZE / 2;

    for my $y ( 0 .. $OUT_SIZE - 1 ) {
        for my $x ( 0 .. $OUT_SIZE - 1 ) {
            my ( $dx, $dy ) = ( $x - $c, $y - $c );
            my $sx = int( $ca * $dx + $sa * $dy + $c + 0.5 );
            my $sy = int( -$sa * $dx + $ca * $dy + $c + 0.5 );
            next
                if $sx < 0 || $sx >= $OUT_SIZE || $sy < 0 || $sy >= $OUT_SIZE;
            my $p = $src->getPixel( $sx, $sy );
            $dst->setPixel( $x, $y, $p ) if ( ( $p >> 24 ) & 0x7f ) < 127;
        }
    }
    push @layers, { name => $name, img => $dst };
    $current = $#layers;
    printf STDERR "  [rot] %g° -> %s (#%d)\n", $deg, $name, $current;
    return $current;
}

sub scale_layer {
    my (%o)  = @_;
    my $si   = $o{layer} // $current;
    my $f    = $o{scale};
    my $name = $o{name} // "s" . int( $f * 100 );
    my $src  = $layers[$si]{img};
    my $dst  = _mk();
    my $ns   = int( $OUT_SIZE * $f );
    my $off  = int( ( $OUT_SIZE - $ns ) / 2 );
    $dst->alphaBlending(0);
    $dst->copyResampled( $src, $off, $off, 0, 0, $ns, $ns, $OUT_SIZE,
        $OUT_SIZE );
    $dst->alphaBlending(1);
    push @layers, { name => $name, img => $dst };
    $current = $#layers;
    printf STDERR "  [scale] *%g -> %s (#%d)\n", $f, $name, $current;
    return $current;
}

sub union_layers {
    my (%o) = @_;
    my ( $ai, $bi ) = ( $o{a}, $o{b} );
    my $name = $o{name} // "union";
    my $dst  = _mk();
    $dst->alphaBlending(1);
    $dst->copy( $layers[$ai]{img}, 0, 0, 0, 0, $OUT_SIZE, $OUT_SIZE );
    $dst->copy( $layers[$bi]{img}, 0, 0, 0, 0, $OUT_SIZE, $OUT_SIZE );
    push @layers, { name => $name, img => $dst };
    $current = $#layers;
    printf STDERR "  [union] %s + %s -> %s (#%d)\n",
        $layers[$ai]{name}, $layers[$bi]{name}, $name, $current;
    return $current;
}

# === OUTPUT ===
sub save_png {
    my ( $file, $idx ) = @_;
    $idx  //= $current;
    $file //= $OUT_FILE;
    $layers[$idx]{img}->saveAlpha(1);
    open my $fh, '>', $file or die "Cannot write $file: $!";
    binmode $fh;
    print $fh $layers[$idx]{img}->png;
    close $fh;
    printf STDERR "  [save] %s\n", $file;
}

sub save_preview {
    my ($file) = @_;
    $file //= $PREVIEW;
    return unless $file;
    require MIME::Base64;

    my $ref_b64 = '';
    if ( $REF_IMG && -f $REF_IMG ) {
        open my $rf, '<', $REF_IMG or warn "ref: $!";
        if ($rf) {
            binmode $rf;
            local $/;
            $ref_b64 = MIME::Base64::encode_base64( <$rf>, '' );
            close $rf;
        }
    }

    my @b64;
    for my $i ( 0 .. $#layers ) {
        $layers[$i]{img}->saveAlpha(1);
        push @b64, MIME::Base64::encode_base64( $layers[$i]{img}->png, '' );
    }

    open my $fh, '>', $file or die;

    # Write HTML header
    print $fh
        qq{<!DOCTYPE html><html><head><meta charset="utf-8"><title>Nailara</title>\n};
    print $fh qq{<style>\n};
    print $fh
        qq{*{margin:0;padding:0}body{background:#0a0a12;color:#aac;font-family:monospace;padding:12px;display:flex;flex-direction:column;align-items:center}\n};
    print $fh
        qq{.r{display:flex;flex-wrap:wrap;gap:6px;justify-content:center;margin:8px 0}\n};
    print $fh
        qq{.s{display:flex;flex-direction:column;align-items:center;gap:2px;cursor:pointer}.s span{font-size:9px;color:#556}\n};
    print $fh
        qq{.s img{width:128px;height:128px;border:1px solid #333;background:#06060f}\n};
    print $fh qq{.s.active img{border-color:#6060ff}\n};
    print $fh
        qq{.comp{position:relative;margin:8px 0;border:1px solid #333;background:#06060f}\n};
    print $fh
        qq{.comp img,.comp canvas{position:absolute;top:0;left:0;width:100%;height:100%}\n};
    print $fh
        qq{.ctrl{display:flex;gap:10px;font-size:10px;align-items:center;margin:4px 0;color:#778}\n};
    print $fh qq{.ctrl input[type=range]{accent-color:#6060ff;width:100px}\n};
    print $fh
        qq{.ctrl select{background:#1a1a2e;color:#aaf;border:1px solid #333;font-size:10px}\n};
    print $fh qq{</style></head><body>\n};

    # Steps thumbnails
    print $fh qq{<div class="r" id="thumbs">\n};
    for my $i ( 0 .. $#layers ) {
        printf $fh
            qq{<div class="s%s" onclick="show(%d)" id="t%d"><span>#%d %s</span><img src="data:image/png;base64,%s"></div>\n},
            ( $i == $#layers ? ' active' : '' ), $i, $i, $i,
            $layers[$i]{name}, $b64[$i];
    }
    print $fh qq{</div>\n};

    # Controls
    print $fh qq{<div class="ctrl">\n};
    if ($ref_b64) {
        print $fh
            qq{<label>Ref: <input type="range" id="rop" min="0" max="100" value="40" oninput="upd()"></label>\n};
        print $fh
            qq{<label><select id="rmode" onchange="upd()"><option value="under">Under</option><option value="over">Over</option><option value="none">Off</option></select></label>\n};
    }
    print $fh
        qq{<label>Color: <select id="bcol" onchange="upd()"><option value="w">White</option><option value="g">Green</option><option value="r">Red</option><option value="n">Native</option></select></label>\n};
    print $fh
        qq{<label>Size: <select id="bsz" onchange="rsz()"><option value="512">512</option><option>640</option><option>768</option><option>1024</option></select></label>\n};
    print $fh qq{</div>\n};

    # Comparison area
    print $fh
        qq{<div class="comp" id="comp" style="width:512px;height:512px">\n};
    if ($ref_b64) {
        printf $fh
            qq{<img id="ri" src="data:image/png;base64,%s" style="image-rendering:pixelated;opacity:0.4;z-index:1">\n},
            $ref_b64;
    }
    print $fh qq{<canvas id="cv" style="z-index:2"></canvas>\n};
    print $fh qq{</div>\n};

    # JavaScript - write as single-quoted chunks to avoid interpolation
    print $fh qq{<script>\n};

    # Layer data array
    print $fh "var LD=[";
    for my $i ( 0 .. $#layers ) {
        print $fh ( $i ? ',"' : '"' ) . $b64[$i] . '"';
    }
    print $fh "];\n";

    # Names array
    print $fh "var NM=[";
    for my $i ( 0 .. $#layers ) {
        print $fh ( $i ? ',"' : '"' ) . $layers[$i]{name} . '"';
    }
    print $fh "];\n";

    # JS code - avoid Perl interpolation by writing line by line
    my @js = (
        'var cur=' . $#layers . ';',
        'var ims=[];',
        'for(var i=0;i<LD.length;i++){var m=new Image();m.src="data:image/png;base64,"+LD[i];ims.push(m)}',
        'function show(i){cur=i;document.querySelectorAll(".s").forEach(function(e,j){e.className=j===i?"s active":"s"});upd()}',
        'function upd(){',
        '  var cv=document.getElementById("cv"),sz=parseInt(document.getElementById("bsz").value);',
        '  cv.width=sz;cv.height=sz;var ctx=cv.getContext("2d");ctx.clearRect(0,0,sz,sz);',
        '  ctx.imageSmoothingEnabled=false;',
        '  var img=ims[cur];if(!img.complete){img.onload=upd;return}',
        '  ctx.drawImage(img,0,0,sz,sz);',
        '  var c=document.getElementById("bcol").value;',
        '  if(c!=="n"){ctx.globalCompositeOperation="source-atop";',
        '    ctx.fillStyle=c==="g"?"#44ff44":c==="r"?"#ff4444":"white";',
        '    ctx.fillRect(0,0,sz,sz);ctx.globalCompositeOperation="source-over"}',
        '  var ri=document.getElementById("ri");',
        '  if(ri){var rm=document.getElementById("rmode").value;',
        '    ri.style.opacity=parseInt(document.getElementById("rop").value)/100;',
        '    ri.style.display=rm==="none"?"none":"block";',
        '    ri.style.zIndex=rm==="over"?"3":"1"}',
        '}',
        'function rsz(){var s=parseInt(document.getElementById("bsz").value);',
        '  var c=document.getElementById("comp");c.style.width=s+"px";c.style.height=s+"px";upd()}',
        'var ld=0;for(var i=0;i<ims.length;i++){if(ims[i].complete)ld++;',
        '  else ims[i].onload=function(){ld++;if(ld>=ims.length)upd()}}',
        'if(ld>=ims.length)setTimeout(upd,50);',
    );
    print $fh join( "\n", @js ) . "\n";

    print $fh qq{</script></body></html>\n};
    close $fh;
    printf STDERR "  [preview] %s (%d steps%s)\n", $file, scalar(@layers),
        ( $ref_b64 ? ' +ref' : '' );
}

# ============================================================
# BUILD - EDIT THIS SECTION
# ============================================================

print STDERR "=== Nailara Build ===\n";
print STDERR "Space: ${COORD}px -> ${OUT_SIZE}px (${SCALE}x)\n\n";

new_layer('base');
fill_disc( r => 48 );
cut_cardinal( r => 25, offset => 35 );
cut_disc( r => 29 );
cut_cardinal( r => 17, offset => 47 );

my $leaf4 = dup_layer( $current, 'leaf4' );
my $rot   = rotate_layer( layer => $leaf4, angle => 45 );
my $outer = union_layers( a => $leaf4, b => $rot, name => 'outer' );

my $ir    = rotate_layer( layer => $outer, angle => -22.5, name => 'irot' );
my $is    = scale_layer( layer => $ir, scale => 0.425, name => 'inner' );
my $final = union_layers( a => $outer, b => $is, name => 'final' );

save_png( $OUT_FILE, $final );
save_preview($PREVIEW) if $PREVIEW;
print STDERR "\nDone.\n";

#,,..,,..,,.,,,.,,.,.,,,.,,.,,,,,,.,.,,.,,,,.,..,,...,..,,,,,,.,,,.,.,,,,,,.,,
#MVA2VCOESCBH6AN3GJIHKKUK2HAA2UA63YXONUJITIZLFXATAES3KTMU2ACJCFXREF7WF7HIS7LDO
#\\\|YRNV5IH6N6K2KPFU6V4SQYQJ6FRKFQIG2E2YO5TBFRYE4LBTW3Z \ / AMOS7 \ YOURUM ::
#\[7]CDMRCQCJLF72WNIOGBGJFY43B4EOBGKD4OXNRFAH4M7RMMUX7UCI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
