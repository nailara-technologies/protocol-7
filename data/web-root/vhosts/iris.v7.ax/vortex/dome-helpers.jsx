// dome.jsx — 3D dome/bowl visualization of the vortex.
// The same iris seen from inside the resonant cavity: rings are ellipses in
// perspective, the EXISTENCE center sits at the bottom of the bowl, particles
// stream inward and downward toward the white-gold singularity. CCW spin is
// visible as motion around the bowl wall.

const { useEffect: useEffectDome, useRef: useRefDome } = React;

// ── palette (shared visual DNA with iris.jsx) ───────────────────────────────

function domeBuildRingPalette(n, paletteMode) {
  const colors = [];
  for (let i = 0; i < n; i++) {
    const t = i / Math.max(1, n - 1);
    let h, s, l;
    if (paletteMode === 'mono-violet') {
      h = 285 - t * 30; s = 65 - t * 15; l = 50 + t * 20;
    } else if (paletteMode === 'inverted') {
      const tt = 1 - t;
      h = domeLerpHue(tt); s = domeRingSat(tt); l = domeRingLight(tt);
    } else {
      h = domeLerpHue(t); s = domeRingSat(t); l = domeRingLight(t);
    }
    colors.push({ h, s, l });
  }
  return colors;
}
function domeLerpHue(t) {
  const stops = [
    [0.00, 288],[0.16, 278],[0.30, 250],[0.46, 215],[0.58, 190],
    [0.70, 158],[0.82, 105],[0.92, 58],[1.00, 38],
  ];
  for (let i = 0; i < stops.length - 1; i++) {
    const [a, ha] = stops[i], [b, hb] = stops[i + 1];
    if (t <= b) { const k = (t - a) / (b - a); return ha + (hb - ha) * k; }
  }
  return stops[stops.length - 1][1];
}
function domeRingLight(t) { return 48 + t * 24 + Math.sin(t * Math.PI) * 4; }
function domeRingSat(t)   { return 60 + Math.sin(t * Math.PI) * 25; }

const DOME_ARM_HUES = [
  { h: 188, s: 100, l: 60 },  // cyan
  { h: 275, s:  70, l: 65 },  // violet
  { h:  42, s:  95, l: 62 },  // amber (leading arm)
  { h: 145, s:  65, l: 55 },  // green
  { h: 300, s:  70, l: 60 },  // magenta
  { h: 220, s:  85, l: 60 },  // blue
  { h: 350, s:  75, l: 65 },  // rose
];

// ── bowl geometry ──────────────────────────────────────────────────────────
// t ∈ [0,1] runs from singularity (bottom, t=0) outward/upward to the rim (t=1).
// The bowl is a stretched half-sphere. y is up in world space; the singularity
// is at origin (0,0,0). Increasing t lifts the ring AND grows its radius.

function bowlRadius(t, R)  { return R * Math.pow(Math.sin(t * Math.PI / 2), 0.92); }
function bowlHeight(t, H)  { return H * (1 - Math.cos(t * Math.PI / 2)); }

// 3D → 2D projection. Camera sits above and behind the bowl, tilted forward
// so we look down INTO the cavity. We compute a raw projection then offset so
// the world origin (the singularity at the bowl's bottom) lands at a chosen
// fraction of screen height — this guarantees the singularity is always
// visible regardless of camera tweaks.
function makeProjector(W, H, opts) {
  const { tiltDeg, camY, camDist, focal, worldScale, originScreenY } = opts;
  const pitch = (tiltDeg * Math.PI) / 180;
  const cp = Math.cos(pitch), sp = Math.sin(pitch);
  const s = Math.min(W, H) * worldScale;

  // World axes: +x right, +y up, +z toward viewer.
  // Camera position: (0, camY, camDist) with camDist > 0 (camera in front of
  // the bowl). Camera tilts DOWN by `pitch` so it looks into the bowl.
  function rawProj(x, y, z) {
    const dx = x;
    const dy = y - camY;
    const dz = z - camDist;
    // tilt-down rotation around x-axis:
    //   yc =  dy*cos(p) + dz*sin(p)
    //   zc = -dy*sin(p) + dz*cos(p)   (in front of camera = negative)
    const yc = dy * cp + dz * sp;
    const zcRaw = -dy * sp + dz * cp;
    const zc = -zcRaw; // flip so positive = in front of camera
    if (zc <= 0.05) return null;
    const inv = focal / zc;
    return { rx: dx * inv * s, ry: -yc * inv * s, zc, scale: inv };
  }

  // Anchor: project world origin once, then offset so it lands at desired
  // screen position. This decouples camera tweaks from on-screen framing.
  const o = rawProj(0, 0, 0);
  const ax = W / 2 - (o ? o.rx : 0);
  const ay = H * (originScreenY ?? 0.72) - (o ? o.ry : 0);

  return function project(x, y, z) {
    const p = rawProj(x, y, z);
    if (!p) return null;
    return { x: ax + p.rx, y: ay + p.ry, scale: p.scale, depth: p.zc };
  };
}

// ── stars & particles ───────────────────────────────────────────────────────

function makeDomeStars(count) {
  const s = [];
  for (let i = 0; i < count; i++) {
    s.push({
      x: Math.random(), y: Math.random(),
      r: Math.random() * 1.2 + 0.2,
      a: Math.random() * 0.7 + 0.15,
      tw: Math.random() * Math.PI * 2,
    });
  }
  return s;
}

function makeDomeParticles(armCount, perArm) {
  const ps = [];
  for (let a = 0; a < armCount; a++) {
    for (let i = 0; i < perArm; i++) {
      ps.push({
        arm: a,
        t: Math.random(),
        speed: 0.035 + Math.random() * 0.055,
        size: 0.6 + Math.random() * 1.4,
        jitter: (Math.random() - 0.5) * 0.04,
        wobble: Math.random() * Math.PI * 2,
      });
    }
  }
  return ps;
}

window.__domeHelpers = {
  domeBuildRingPalette, DOME_ARM_HUES,
  bowlRadius, bowlHeight, makeProjector,
  makeDomeStars, makeDomeParticles,
};
