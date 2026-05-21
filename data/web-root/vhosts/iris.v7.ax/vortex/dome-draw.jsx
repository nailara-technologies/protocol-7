// dome-draw.jsx — bowl-surface drawing primitives.
// All projection happens via the `project(x,y,z)` function passed in.

// Sample N points around a ring at world height y, radius r — return array of
// {sx, sy, depth} for screen draw. Returns null if any point is behind camera.
function sampleRingPoints(project, r, y, samples, spin) {
  const pts = [];
  for (let i = 0; i < samples; i++) {
    const theta = (i / samples) * Math.PI * 2 + spin;
    const x = r * Math.cos(theta);
    const z = r * Math.sin(theta);
    const p = project(x, y, z);
    if (!p) return null;
    pts.push({ sx: p.x, sy: p.y, depth: p.depth, theta });
  }
  return pts;
}

// Draw an ellipse path from already-projected ring points, optionally only
// the front half (positive z, far side closer to camera... actually depending
// on camera convention. Here: back-half points are those whose depth is
// SMALLER (further from camera after pitch). We split by world z sign.
function drawRingPath(ctx, pts, half /* 'full'|'back'|'front' */, spinPhase) {
  // half = 'back' draws points where original z is negative (far side of bowl)
  // half = 'front' draws points where z is positive (near side)
  // We use the precomputed theta to decide front/back relative to spin.
  // Simpler approach: sort points by depth, split.
  if (!pts || pts.length === 0) return;
  ctx.beginPath();
  let started = false;
  for (let i = 0; i <= pts.length; i++) {
    const p = pts[i % pts.length];
    // back half = farther from camera. Camera is at +z looking toward origin,
    // so points with z < 0 (sin(theta) < 0 with our parameterization) are far.
    const isBack = Math.sin(p.theta) < 0;
    const include = half === 'full' || (half === 'back' ? isBack : !isBack);
    if (!include) {
      started = false;
      continue;
    }
    if (!started) { ctx.moveTo(p.sx, p.sy); started = true; }
    else ctx.lineTo(p.sx, p.sy);
  }
  ctx.stroke();
}

function drawDomeRings(ctx, project, R, Hh, palette, t, tweaks, half) {
  const H = window.__domeHelpers;
  const n = palette.length;
  const spin = t * tweaks.spinSpeed * (tweaks.spin === 'ccw' ? -1 : 1);
  ctx.save();
  // Stack innermost (violet, deep in bowl) to outermost (amber, rim)
  for (let i = 0; i < n; i++) {
    const tt = i / Math.max(1, n - 1);
    // Cluster rings slightly toward outer half — matches iris radial mapping
    const tRing = Math.pow(tt, 1.05);
    const r = H.bowlRadius(tRing, R);
    const y = H.bowlHeight(tRing, Hh);
    const c = palette[i];

    const isVoid = tweaks.voidRing && i === Math.round(n * 0.27);
    const breathe = 1 + Math.sin(t * 0.5 + tt * 4) * 0.03;

    // back-half rings sit deeper in 3D — dim them slightly for atmospheric depth
    const halfDim = half === 'back' ? 0.55 : 1.0;
    ctx.strokeStyle = `hsl(${c.h.toFixed(1)} ${c.s.toFixed(0)}% ${c.l.toFixed(0)}%)`;
    ctx.globalAlpha = (isVoid ? 0.22 : 0.78 - tt * 0.10) * breathe * halfDim;
    ctx.lineWidth = (1.05 + tt * 0.45);
    ctx.setLineDash(isVoid ? [2, 7] : []);

    const samples = Math.max(48, Math.floor(60 + tt * 60));
    const pts = sampleRingPoints(project, r, y, samples, 0); // spin doesn't change ring shape
    if (!pts) continue;
    drawRingPath(ctx, pts, half, spin);
  }
  ctx.setLineDash([]);
  ctx.globalAlpha = 1;
  ctx.restore();
}

// ── arms: log-spiral on the bowl surface, descending toward singularity ────

function bowlArmPoint(t, armIdx, armCount, params, spin) {
  const { R, Hh, tightness, ccw } = params;
  // arm parameter t: 0 = at rim, 1 = at singularity (inverted from iris
  // because we want particles streaming inward+downward as t increases)
  // map to bowl t coord: 0(singularity) → 1(rim). So bowlT = 1 - t.
  const bowlT = 1 - t;
  const r = window.__domeHelpers.bowlRadius(bowlT, R);
  const y = window.__domeHelpers.bowlHeight(bowlT, Hh);
  const startAngle = (armIdx / armCount) * Math.PI * 2 + spin;
  // theta winds more as we descend (the funnel tightens visually)
  const theta = startAngle + (ccw ? 1 : -1) * t * tightness;
  return {
    x: r * Math.cos(theta),
    y: y,
    z: r * Math.sin(theta),
    theta,
  };
}

function drawDomeArms(ctx, project, R, Hh, t, tweaks) {
  const armCount = tweaks.armCount;
  const tightness = tweaks.tightness;
  const ccw = tweaks.spin === 'ccw';
  const spin = t * tweaks.spinSpeed * (ccw ? -1 : 1);
  const params = { R, Hh, tightness, ccw };

  ctx.save();
  ctx.globalCompositeOperation = 'screen';
  ctx.lineCap = 'round';

  // gather all arm strokes with depth for back-to-front ordering
  const armStrokes = [];

  for (let a = 0; a < armCount; a++) {
    const hue = window.__domeHelpers.DOME_ARM_HUES[a % window.__domeHelpers.DOME_ARM_HUES.length];
    const isLead = a === 2 && armCount >= 3;
    const baseAlpha = isLead ? 0.85 : 0.5;
    const width = isLead ? 2.6 : 1.7;

    // sample along arm — fewer steps near rim, more near singularity (tighter)
    const steps = 80;
    const screenPts = [];
    let avgDepth = 0;
    for (let i = 0; i <= steps; i++) {
      const tArm = i / steps;
      const wp = bowlArmPoint(tArm, a, armCount, params, spin);
      const p = project(wp.x, wp.y, wp.z);
      if (!p) { screenPts.push(null); continue; }
      screenPts.push(p);
      avgDepth += p.depth;
    }
    avgDepth /= steps;
    armStrokes.push({ hue, baseAlpha, width, pts: screenPts, depth: avgDepth, isLead });
  }

  // far arms first (larger depth value = farther from camera with our setup)
  armStrokes.sort((a, b) => b.depth - a.depth);

  for (const stroke of armStrokes) {
    const { hue, baseAlpha, width, pts } = stroke;
    // outer halo
    ctx.strokeStyle = `hsla(${hue.h} ${hue.s}% ${hue.l}% / ${baseAlpha * 0.32})`;
    ctx.lineWidth = width * 6;
    drawArmStroke(ctx, pts);
    // mid glow
    ctx.strokeStyle = `hsla(${hue.h} ${hue.s}% ${hue.l + 5}% / ${baseAlpha * 0.55})`;
    ctx.lineWidth = width * 2.4;
    drawArmStroke(ctx, pts);
    // sharp core
    ctx.strokeStyle = `hsla(${hue.h} 95% ${Math.min(85, hue.l + 18)}% / ${baseAlpha})`;
    ctx.lineWidth = width;
    drawArmStroke(ctx, pts);
  }
  ctx.restore();
}

function drawArmStroke(ctx, pts) {
  ctx.beginPath();
  let started = false;
  for (let i = 0; i < pts.length; i++) {
    const p = pts[i];
    if (!p) { started = false; continue; }
    if (!started) { ctx.moveTo(p.x, p.y); started = true; }
    else ctx.lineTo(p.x, p.y);
  }
  ctx.stroke();
}

window.__domeDraw = { drawDomeRings, drawDomeArms, bowlArmPoint };
