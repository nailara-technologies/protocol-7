// iris.jsx — full-page iris/vortex visualization
// 26 concentric rings (violet inner → amber outer), 5 CCW galactic arms,
// white-gold center, deep space UV blacklight background.

const { useEffect, useRef, useState } = React;

// ── palette helpers ─────────────────────────────────────────────────────────

// Build N ring colors going violet → blue → cyan → green → amber.
// Hue path is hand-curated so the inner rings sit firmly in violet/UV range
// and the outermost few feel hot (gold/amber).
function buildRingPalette(n, paletteMode) {
  const colors = [];
  for (let i = 0; i < n; i++) {
    const t = i / Math.max(1, n - 1); // 0..1, inner→outer
    let h, s, l;
    if (paletteMode === 'mono-violet') {
      // single-hue gradient inside the violet/UV range
      h = 285 - t * 30;
      s = 65 - t * 15;
      l = 50 + t * 20;
    } else if (paletteMode === 'inverted') {
      // amber inner → violet outer
      const tt = 1 - t;
      h = lerpHue(tt);
      s = ringSaturation(tt);
      l = ringLightness(tt);
    } else {
      // default: galactic spectrum (violet → amber)
      h = lerpHue(t);
      s = ringSaturation(t);
      l = ringLightness(t);
    }
    colors.push(`hsl(${h.toFixed(1)} ${s.toFixed(0)}% ${l.toFixed(0)}%)`);
  }
  return colors;
}

// Piecewise hue: 285° (violet) → 245° (indigo) → 195° (cyan) → 150° (teal-green)
// → 90° (yellow-green) → 38° (amber). Lightness drops on the inner end so the
// violet rings read as violet (not lavender-washed-to-white).
function lerpHue(t) {
  const stops = [
    [0.00, 288], // deep violet
    [0.16, 278],
    [0.30, 250], // indigo
    [0.46, 215], // blue
    [0.58, 190], // cyan
    [0.70, 158], // teal
    [0.82, 105], // green-yellow
    [0.92, 58],  // yellow
    [1.00, 38],  // amber
  ];
  for (let i = 0; i < stops.length - 1; i++) {
    const [a, ha] = stops[i], [b, hb] = stops[i + 1];
    if (t <= b) {
      const k = (t - a) / (b - a);
      return ha + (hb - ha) * k;
    }
  }
  return stops[stops.length - 1][1];
}

// Lightness curve: dimmer (richer) on the inner violet end, brighter on the
// amber outer end so the colors read as their hues, not pale tints of white.
function ringLightness(t) {
  // inner ~48%, middle ~62%, outer ~70%
  return 48 + t * 24 + Math.sin(t * Math.PI) * 4;
}
function ringSaturation(t) {
  // peak saturation in the middle range, slightly cooler on both ends
  return 60 + Math.sin(t * Math.PI) * 25;
}

const ARM_HUES = [
  { name: 'cyan',    h: 188, s: 100, l: 60 },
  { name: 'violet',  h: 275, s:  70, l: 65 },
  { name: 'amber',   h:  42, s:  95, l: 62 }, // the leading / brightest arm
  { name: 'green',   h: 145, s:  65, l: 55 },
  { name: 'magenta', h: 300, s:  70, l: 60 },
  { name: 'blue',    h: 220, s:  85, l: 60 },
  { name: 'rose',    h: 350, s:  75, l: 65 },
];

// ── starfield (precomputed once) ────────────────────────────────────────────

function makeStars(count, w, h) {
  const stars = [];
  for (let i = 0; i < count; i++) {
    stars.push({
      x: Math.random(),
      y: Math.random(),
      r: Math.random() * 1.2 + 0.2,
      a: Math.random() * 0.7 + 0.15,
      tw: Math.random() * Math.PI * 2, // twinkle phase
    });
  }
  return stars;
}

// ── particles flowing outward along arms ────────────────────────────────────

function makeParticles(armCount, perArm) {
  const ps = [];
  for (let a = 0; a < armCount; a++) {
    for (let i = 0; i < perArm; i++) {
      ps.push({
        arm: a,
        t: Math.random(),         // 0..1 progress along arm (0=center, 1=edge)
        speed: 0.04 + Math.random() * 0.06,
        size: 0.6 + Math.random() * 1.4,
        jitter: (Math.random() - 0.5) * 0.04,
      });
    }
  }
  return ps;
}

// Log spiral: r(theta) = r0 * exp(b * theta).
// We parameterize by t ∈ [0,1] mapping to theta ∈ [0, thetaMax].
// CCW visually on the screen: y axis is flipped, so we DECREASE the angle as
// t grows (a positive-mathematical CCW rotation is a visual CW one on screen).
function armPoint(t, armIdx, armCount, params) {
  const { cx, cy, rInner, rOuter, tightness, ccw } = params;
  // total angle swept from center to outer edge for one arm
  const thetaMax = tightness; // radians (~2.6 → about 150°)
  // start angle offset per arm
  const startAngle = (armIdx / armCount) * Math.PI * 2;
  const theta = startAngle + (ccw ? 1 : -1) * t * thetaMax;
  // logarithmic spiral radius
  const b = Math.log(rOuter / rInner) / thetaMax;
  const r = rInner * Math.exp(b * (t * thetaMax));
  return {
    x: cx + r * Math.cos(theta),
    y: cy + r * Math.sin(theta),
    r,
    theta,
  };
}

// ── main component ──────────────────────────────────────────────────────────

function Iris({ tweaks }) {
  const canvasRef = useRef(null);
  const starsRef = useRef(null);
  const particlesRef = useRef(null);
  const sizeRef = useRef({ w: 0, h: 0, dpr: 1 });

  // rebuild particles whenever arm count changes
  useEffect(() => {
    particlesRef.current = makeParticles(tweaks.armCount, tweaks.particleDensity);
  }, [tweaks.armCount, tweaks.particleDensity]);

  useEffect(() => {
    const canvas = canvasRef.current;
    const ctx = canvas.getContext('2d');
    let raf = 0;
    let t0 = performance.now();

    const resize = () => {
      const dpr = Math.min(window.devicePixelRatio || 1, 2);
      const w = window.innerWidth;
      const h = window.innerHeight;
      canvas.width = w * dpr;
      canvas.height = h * dpr;
      canvas.style.width = w + 'px';
      canvas.style.height = h + 'px';
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
      sizeRef.current = { w, h, dpr };
      starsRef.current = makeStars(Math.round((w * h) / 4500), w, h);
    };
    resize();
    window.addEventListener('resize', resize);

    if (!particlesRef.current) {
      particlesRef.current = makeParticles(tweaks.armCount, tweaks.particleDensity);
    }

    const draw = (now) => {
      const t = (now - t0) / 1000;
      const { w: W, h: H } = sizeRef.current;
      const cx = W / 2;
      const cy = H / 2;
      const baseR = Math.min(W, H);
      const maxR = baseR * 0.48;
      const rInner = baseR * 0.045;

      // Background fill (deep space)
      ctx.fillStyle = '#03030a';
      ctx.fillRect(0, 0, W, H);

      // UV blacklight blobs — large soft radial gradients painted at corners
      drawUVField(ctx, W, H, t);

      // Starfield
      drawStarfield(ctx, starsRef.current, W, H, t);

      // 26 (configurable) concentric rings
      const ringColors = buildRingPalette(tweaks.ringCount, tweaks.palette);
      drawRings(ctx, cx, cy, rInner, maxR, ringColors, t, tweaks);

      // Five CCW spiral arms
      drawArms(ctx, cx, cy, rInner, maxR, t, tweaks);

      // Particles streaming outward along arms (CCW spin)
      drawParticles(ctx, particlesRef.current, cx, cy, rInner, maxR, t, tweaks);

      // White-gold center glow
      drawCenter(ctx, cx, cy, rInner, t, tweaks);

      raf = requestAnimationFrame(draw);
    };
    raf = requestAnimationFrame(draw);

    return () => {
      cancelAnimationFrame(raf);
      window.removeEventListener('resize', resize);
    };
  }, [tweaks]);

  return (
    <canvas
      ref={canvasRef}
      style={{ position: 'fixed', inset: 0, width: '100vw', height: '100vh' }}
    />
  );
}

// ── drawing primitives ──────────────────────────────────────────────────────

function drawUVField(ctx, W, H, t) {
  // slow drifting blacklight blobs
  const blobs = [
    { x: 0.20, y: 0.18, r: 0.55, h: 270, s: 80, l: 30, a: 0.22 },
    { x: 0.82, y: 0.78, r: 0.50, h: 285, s: 90, l: 28, a: 0.18 },
    { x: 0.78, y: 0.22, r: 0.45, h: 250, s: 90, l: 26, a: 0.14 },
    { x: 0.22, y: 0.80, r: 0.42, h: 305, s: 70, l: 26, a: 0.12 },
  ];
  blobs.forEach((b, i) => {
    const driftX = Math.sin(t * 0.06 + i) * 0.02;
    const driftY = Math.cos(t * 0.05 + i * 1.3) * 0.02;
    const cx = (b.x + driftX) * W;
    const cy = (b.y + driftY) * H;
    const rr = b.r * Math.max(W, H);
    const g = ctx.createRadialGradient(cx, cy, 0, cx, cy, rr);
    g.addColorStop(0, `hsla(${b.h} ${b.s}% ${b.l}% / ${b.a})`);
    g.addColorStop(0.6, `hsla(${b.h} ${b.s}% ${b.l}% / ${b.a * 0.25})`);
    g.addColorStop(1, `hsla(${b.h} ${b.s}% ${b.l}% / 0)`);
    ctx.fillStyle = g;
    ctx.fillRect(0, 0, W, H);
  });
}

function drawStarfield(ctx, stars, W, H, t) {
  if (!stars) return;
  ctx.save();
  for (let i = 0; i < stars.length; i++) {
    const s = stars[i];
    const x = s.x * W;
    const y = s.y * H;
    // distance from center; dim stars near the iris so it pops
    const cx = W / 2, cy = H / 2;
    const d = Math.hypot(x - cx, y - cy);
    const fade = Math.min(1, d / (Math.min(W, H) * 0.4));
    const tw = (Math.sin(t * 0.9 + s.tw) + 1) * 0.5;
    const a = s.a * fade * (0.55 + tw * 0.45);
    ctx.fillStyle = `rgba(220, 215, 255, ${a})`;
    ctx.beginPath();
    ctx.arc(x, y, s.r, 0, Math.PI * 2);
    ctx.fill();
  }
  ctx.restore();
}

function drawRings(ctx, cx, cy, rInner, rOuter, colors, t, tweaks) {
  const n = colors.length;
  ctx.save();
  // Single crisp pass per ring — no 'lighter' accumulation, so each hue stays
  // recognizable (violet inner, cyan/teal middle, amber outer).
  for (let i = 0; i < n; i++) {
    const tt = i / (n - 1);
    // Cluster rings slightly toward the outer edge so the inner few (violet)
    // have breathing room around the bright center rather than crammed under it.
    const r = rInner + (rOuter - rInner) * Math.pow(tt, 1.18);
    // ring at ~27% from center is the "dot-fold / void ring" — dimmer, broken
    const isVoid = tweaks.voidRing && i === Math.round(n * 0.27);
    const breathe = 1 + Math.sin(t * 0.5 + tt * 4) * 0.03;
    ctx.strokeStyle = colors[i];
    ctx.globalAlpha = (isVoid ? 0.25 : 0.78 - tt * 0.08) * breathe;
    ctx.lineWidth = (1.05 + tt * 0.45);
    ctx.setLineDash(isVoid ? [2, 7] : []);
    ctx.beginPath();
    ctx.arc(cx, cy, r, 0, Math.PI * 2);
    ctx.stroke();
  }
  ctx.setLineDash([]);
  ctx.globalAlpha = 1;
  ctx.restore();
}

function drawArms(ctx, cx, cy, rInner, rOuter, t, tweaks) {
  const armCount = tweaks.armCount;
  const tightness = tweaks.tightness;
  const ccw = tweaks.spin === 'cw'; // y-axis flip: 'cw' value → visual CCW
  const spin = t * 0.04 * (ccw ? 1 : -1); // very slow global rotation
  ctx.save();
  ctx.globalCompositeOperation = 'screen';
  for (let a = 0; a < armCount; a++) {
    const hue = ARM_HUES[a % ARM_HUES.length];
    // arm 2 (index 2) — the amber one — is brightest, drawing the eye out CCW
    const isLead = a === 2 && armCount >= 3;
    const baseAlpha = isLead ? 0.75 : 0.42;
    const width = isLead ? 2.4 : 1.6;
    // draw arm as a series of glowing strokes (outer halo + sharp core)
    const startAngle = (a / armCount) * Math.PI * 2 + spin;
    const params = {
      cx, cy, rInner, rOuter, tightness, ccw,
    };
    // outer halo
    ctx.strokeStyle = `hsla(${hue.h} ${hue.s}% ${hue.l}% / ${baseAlpha * 0.35})`;
    ctx.lineWidth = width * 6;
    ctx.lineCap = 'round';
    drawSpiralPath(ctx, startAngle, params);
    // mid glow
    ctx.strokeStyle = `hsla(${hue.h} ${hue.s}% ${hue.l + 5}% / ${baseAlpha * 0.55})`;
    ctx.lineWidth = width * 2.4;
    drawSpiralPath(ctx, startAngle, params);
    // sharp core
    ctx.strokeStyle = `hsla(${hue.h} 95% ${Math.min(85, hue.l + 18)}% / ${baseAlpha})`;
    ctx.lineWidth = width;
    drawSpiralPath(ctx, startAngle, params);
  }
  ctx.restore();
}

function drawSpiralPath(ctx, startAngle, params) {
  const { cx, cy, rInner, rOuter, tightness, ccw } = params;
  const thetaMax = tightness;
  const b = Math.log(rOuter / rInner) / thetaMax;
  const steps = 90;
  ctx.beginPath();
  for (let i = 0; i <= steps; i++) {
    const t = i / steps;
    const theta = startAngle + (ccw ? 1 : -1) * t * thetaMax;
    const r = rInner * Math.exp(b * (t * thetaMax));
    const x = cx + r * Math.cos(theta);
    const y = cy + r * Math.sin(theta);
    if (i === 0) ctx.moveTo(x, y);
    else ctx.lineTo(x, y);
  }
  ctx.stroke();
}

function drawParticles(ctx, particles, cx, cy, rInner, rOuter, t, tweaks) {
  if (!particles) return;
  const armCount = tweaks.armCount;
  const tightness = tweaks.tightness;
  const ccw = tweaks.spin === 'cw'; // y-axis flip: 'cw' value → visual CCW
  const spin = t * 0.04 * (ccw ? 1 : -1);
  const thetaMax = tightness;
  const b = Math.log(rOuter / rInner) / thetaMax;
  ctx.save();
  ctx.globalCompositeOperation = 'screen';

  for (let i = 0; i < particles.length; i++) {
    const p = particles[i];
    // particle moves INWARD (implosion) — tt counts down from 1 (outer) to 0 (center).
    // Visually: motes pulled along arms toward the bright center.
    const tt = 1 - ((p.t + t * p.speed) % 1);
    const arm = p.arm % armCount;
    const isLead = arm === 2 && armCount >= 3;
    const hue = ARM_HUES[arm % ARM_HUES.length];
    const startAngle = (arm / armCount) * Math.PI * 2 + spin;
    const theta = startAngle + (ccw ? 1 : -1) * tt * thetaMax + p.jitter;
    const r = rInner * Math.exp(b * (tt * thetaMax));
    const x = cx + r * Math.cos(theta);
    const y = cy + r * Math.sin(theta);
    // alpha fades in and out so particles "wink" rather than pop at ends
    const fade = Math.sin(tt * Math.PI);
    const alpha = (isLead ? 0.95 : 0.55) * fade;
    const size = p.size * (isLead ? 1.4 : 1.0) * (0.5 + tt * 0.8);

    // glow halo
    const g = ctx.createRadialGradient(x, y, 0, x, y, size * 4);
    g.addColorStop(0, `hsla(${hue.h} 100% 80% / ${alpha})`);
    g.addColorStop(0.4, `hsla(${hue.h} 100% 65% / ${alpha * 0.4})`);
    g.addColorStop(1, `hsla(${hue.h} 100% 60% / 0)`);
    ctx.fillStyle = g;
    ctx.beginPath();
    ctx.arc(x, y, size * 4, 0, Math.PI * 2);
    ctx.fill();
    // sharp core
    ctx.fillStyle = `hsla(${hue.h} 100% 92% / ${alpha})`;
    ctx.beginPath();
    ctx.arc(x, y, size, 0, Math.PI * 2);
    ctx.fill();
  }
  ctx.restore();
}

function drawCenter(ctx, cx, cy, rInner, t, tweaks) {
  const pulse = 1 + Math.sin(t * 1.2) * 0.06;
  const brightness = tweaks.centerBrightness;
  ctx.save();
  ctx.globalCompositeOperation = 'screen';

  // outer corona — UV blacklight / violet-blue halo. Cool whisper-white at the
  // very middle, blooming out through electric-violet.
  const coronaR = rInner * 7 * pulse;
  const corona = ctx.createRadialGradient(cx, cy, 0, cx, cy, coronaR);
  corona.addColorStop(0,    `rgba(220, 230, 255, ${0.48 * brightness})`);
  corona.addColorStop(0.18, `rgba(140, 170, 255, ${0.26 * brightness})`);
  corona.addColorStop(0.50, `rgba(120, 100, 255, ${0.10 * brightness})`);
  corona.addColorStop(1,    `rgba(140,  80, 255, 0)`);
  ctx.fillStyle = corona;
  ctx.beginPath();
  ctx.arc(cx, cy, coronaR, 0, Math.PI * 2);
  ctx.fill();

  // inner bright core — cool blue-white star
  const coreR = rInner * 2.0 * pulse;
  const core = ctx.createRadialGradient(cx, cy, 0, cx, cy, coreR);
  core.addColorStop(0,   `rgba(240, 245, 255, ${0.98 * brightness})`);
  core.addColorStop(0.5, `rgba(150, 180, 255, ${0.55 * brightness})`);
  core.addColorStop(1,   `rgba(110, 130, 255, 0)`);
  ctx.fillStyle = core;
  ctx.beginPath();
  ctx.arc(cx, cy, coreR, 0, Math.PI * 2);
  ctx.fill();

  // hot center point — almost pure white with the faintest cool tint
  ctx.fillStyle = `rgba(245, 250, 255, ${brightness})`;
  ctx.beginPath();
  ctx.arc(cx, cy, rInner * 0.5 * pulse, 0, Math.PI * 2);
  ctx.fill();

  ctx.restore();
}

// ── chrome / labels ─────────────────────────────────────────────────────────

function Chrome({ tweaks }) {
  return (
    <>
      <div className="chrome chrome-tl">
        <div className="chrome-glyph">[:&lt;</div>
        <div className="chrome-line">iris.v7.ax</div>
        <div className="chrome-dim">{tweaks.ringCount} rings &middot; {tweaks.armCount} arms &middot; {tweaks.spin}</div>
      </div>
      <div className="chrome chrome-br">
        <div className="chrome-dim">{tweaks.palette}</div>
        <div className="chrome-line">[ TRUE ]</div>
      </div>
      <div className="chrome chrome-bl">
        <div className="chrome-dim">vortex.overhead</div>
        <div className="chrome-dim">26 / 5 / CCW</div>
      </div>
    </>
  );
}

// ── app ─────────────────────────────────────────────────────────────────────

const TWEAK_DEFAULTS = /*EDITMODE-BEGIN*/{
  "ringCount": 26,
  "armCount": 5,
  "spin": "ccw",
  "palette": "galactic",
  "tightness": 2.6,
  "particleDensity": 28,
  "centerBrightness": 1,
  "voidRing": true,
  "showChrome": true
}/*EDITMODE-END*/;

function App() {
  const [t, setTweak] = useTweaks(TWEAK_DEFAULTS);
  return (
    <>
      <Iris tweaks={t} />
      {t.showChrome && <Chrome tweaks={t} />}
      <TweaksPanel>
        <TweakSection label="Structure" />
        <TweakSlider label="Rings"        value={t.ringCount}  min={12} max={40} step={1}
                     onChange={(v) => setTweak('ringCount', v)} />
        <TweakSlider label="Arms"         value={t.armCount}   min={2}  max={7}  step={1}
                     onChange={(v) => setTweak('armCount', v)} />
        <TweakSlider label="Arm tightness" value={t.tightness} min={1.4} max={4.2} step={0.1}
                     onChange={(v) => setTweak('tightness', v)} unit="rad" />
        <TweakRadio  label="Spin"          value={t.spin}
                     options={['ccw','cw']}
                     onChange={(v) => setTweak('spin', v)} />
        <TweakToggle label="Void ring (#7)" value={t.voidRing}
                     onChange={(v) => setTweak('voidRing', v)} />

        <TweakSection label="Light" />
        <TweakSlider label="Particles"        value={t.particleDensity}   min={0} max={60} step={2}
                     onChange={(v) => setTweak('particleDensity', v)} unit="/arm" />
        <TweakSlider label="Center brightness" value={t.centerBrightness} min={0.3} max={1.6} step={0.05}
                     onChange={(v) => setTweak('centerBrightness', v)} />
        <TweakSelect label="Palette"           value={t.palette}
                     options={['galactic','inverted','mono-violet']}
                     onChange={(v) => setTweak('palette', v)} />

        <TweakSection label="Chrome" />
        <TweakToggle label="Show labels" value={t.showChrome}
                     onChange={(v) => setTweak('showChrome', v)} />
      </TweaksPanel>
    </>
  );
}

ReactDOM.createRoot(document.getElementById('root')).render(<App />);
