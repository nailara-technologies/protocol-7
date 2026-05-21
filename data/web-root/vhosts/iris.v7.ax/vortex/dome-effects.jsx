// dome-effects.jsx — particles, singularity, bowl interior wash.

function drawDomeParticles(ctx, project, particles, R, Hh, t, tweaks) {
  if (!particles) return;
  const H = window.__domeHelpers;
  const D = window.__domeDraw;
  const armCount = tweaks.armCount;
  const tightness = tweaks.tightness;
  const ccw = tweaks.spin === 'ccw';
  const spin = t * tweaks.spinSpeed * (ccw ? -1 : 1);
  const params = { R, Hh, tightness, ccw };

  ctx.save();
  ctx.globalCompositeOperation = 'screen';

  // collect particle screen positions + depths
  const drawables = [];
  for (let i = 0; i < particles.length; i++) {
    const p = particles[i];
    // tArm advances over time; particle slides from rim (0) toward
    // singularity (1). Wrap.
    const tArm = (p.t + t * p.speed) % 1;
    const arm = p.arm % armCount;
    const isLead = arm === 2 && armCount >= 3;
    const hue = H.DOME_ARM_HUES[arm % H.DOME_ARM_HUES.length];
    const wp = D.bowlArmPoint(tArm, arm, armCount, params, spin);
    // add a tiny wobble perpendicular to the arm so streams feel alive
    const wob = Math.sin(t * 2 + p.wobble) * p.jitter;
    const wx = wp.x + Math.cos(wp.theta + Math.PI / 2) * wob;
    const wz = wp.z + Math.sin(wp.theta + Math.PI / 2) * wob;
    const proj = project(wx, wp.y, wz);
    if (!proj) continue;

    // fade in at rim, full brightness mid-way, super-bright as it falls into
    // the singularity (then snaps back to rim — wrap)
    const fadeIn  = Math.min(1, tArm * 6);
    const fadeOut = 1 - Math.pow(Math.max(0, tArm - 0.92) / 0.08, 2);
    const fade = fadeIn * Math.max(0, fadeOut);
    // brighten as approaching center (implosion acceleration feel)
    const accel = 0.6 + tArm * 1.5;
    const alpha = (isLead ? 0.95 : 0.55) * fade * accel;
    if (alpha <= 0.02) continue;

    const size = p.size * (isLead ? 1.4 : 1.0) * (0.5 + (1 - tArm) * 0.6) * proj.scale * 1.1;
    drawables.push({ proj, hue, alpha: Math.min(1.2, alpha), size, tArm });
  }
  // back-to-front
  drawables.sort((a, b) => b.proj.depth - a.proj.depth);

  for (const d of drawables) {
    const { proj, hue, alpha, size, tArm } = d;
    // ASTRONOMER's blue-shift toward center: hue cools as tArm → 1
    // (lean toward UV blue near the singularity for that "implosion direction" feel)
    const hueShift = tArm > 0.55 ? Math.min(40, (tArm - 0.55) * 90) : 0;
    const h = hue.h - hueShift;

    const g = ctx.createRadialGradient(proj.x, proj.y, 0, proj.x, proj.y, size * 4.2);
    g.addColorStop(0,   `hsla(${h} 100% 82% / ${alpha})`);
    g.addColorStop(0.4, `hsla(${h} 100% 65% / ${alpha * 0.4})`);
    g.addColorStop(1,   `hsla(${h} 100% 60% / 0)`);
    ctx.fillStyle = g;
    ctx.beginPath();
    ctx.arc(proj.x, proj.y, size * 4.2, 0, Math.PI * 2);
    ctx.fill();

    ctx.fillStyle = `hsla(${h} 100% 94% / ${alpha})`;
    ctx.beginPath();
    ctx.arc(proj.x, proj.y, size, 0, Math.PI * 2);
    ctx.fill();
  }
  ctx.restore();
}

// ── bowl interior — a wash of UV blue light pooling in the cavity ──────────

function drawBowlInterior(ctx, W, H, project, R, Hh, t, tweaks) {
  // a soft radial gradient anchored at the projected singularity, slightly
  // elongated vertically (because the bowl mouth opens upward in perspective)
  const center = project(0, 0, 0);
  if (!center) return;

  ctx.save();
  // outer pool — UV blue
  const pool = ctx.createRadialGradient(
    center.x, center.y - 10, 1,
    center.x, center.y + 20, Math.min(W, H) * 0.55
  );
  pool.addColorStop(0.00, 'rgba(110, 130, 255, 0.18)');
  pool.addColorStop(0.35, 'rgba(95, 90, 220, 0.10)');
  pool.addColorStop(0.70, 'rgba(70, 50, 160, 0.05)');
  pool.addColorStop(1.00, 'rgba(40, 20, 80, 0)');
  ctx.fillStyle = pool;
  ctx.fillRect(0, 0, W, H);

  // faint cavity floor highlight — a thin glow just under the rim
  // (suggests light bouncing off the bowl interior)
  const rim = project(0, Hh, 0);
  if (rim) {
    const g2 = ctx.createRadialGradient(W / 2, rim.y, 1, W / 2, rim.y, Math.min(W, H) * 0.4);
    g2.addColorStop(0, 'rgba(150, 110, 200, 0.05)');
    g2.addColorStop(1, 'rgba(0, 0, 0, 0)');
    ctx.fillStyle = g2;
    ctx.fillRect(0, 0, W, H);
  }
  ctx.restore();
}

// ── singularity at the bottom of the bowl ──────────────────────────────────

function drawDomeCenter(ctx, project, t, tweaks) {
  const c = project(0, 0, 0);
  if (!c) return;
  const pulse = 1 + Math.sin(t * 1.2) * 0.06;
  const brightness = tweaks.centerBrightness;
  // base size, scaled by perspective
  const baseR = 16 * c.scale * pulse;

  ctx.save();
  ctx.globalCompositeOperation = 'screen';

  // outer corona — UV violet bleeding upward into bowl
  const coronaR = baseR * 7;
  const corona = ctx.createRadialGradient(c.x, c.y, 0, c.x, c.y, coronaR);
  corona.addColorStop(0,    `rgba(220, 230, 255, ${0.48 * brightness})`);
  corona.addColorStop(0.18, `rgba(140, 170, 255, ${0.26 * brightness})`);
  corona.addColorStop(0.50, `rgba(120, 100, 255, ${0.10 * brightness})`);
  corona.addColorStop(1,    `rgba(140,  80, 255, 0)`);
  ctx.fillStyle = corona;
  ctx.beginPath();
  ctx.arc(c.x, c.y, coronaR, 0, Math.PI * 2);
  ctx.fill();

  // inner star — cool blue-white
  const coreR = baseR * 2.0;
  const core = ctx.createRadialGradient(c.x, c.y, 0, c.x, c.y, coreR);
  core.addColorStop(0,   `rgba(240, 245, 255, ${0.98 * brightness})`);
  core.addColorStop(0.5, `rgba(150, 180, 255, ${0.55 * brightness})`);
  core.addColorStop(1,   `rgba(110, 130, 255, 0)`);
  ctx.fillStyle = core;
  ctx.beginPath();
  ctx.arc(c.x, c.y, coreR, 0, Math.PI * 2);
  ctx.fill();

  // hot pixel — white-gold core (slight warm bias for that ω-gate read)
  const hotG = ctx.createRadialGradient(c.x, c.y, 0, c.x, c.y, baseR * 0.7);
  hotG.addColorStop(0, `rgba(255, 240, 210, ${brightness})`);
  hotG.addColorStop(1, `rgba(255, 230, 180, 0)`);
  ctx.fillStyle = hotG;
  ctx.beginPath();
  ctx.arc(c.x, c.y, baseR * 0.7, 0, Math.PI * 2);
  ctx.fill();

  // sharp center dot
  ctx.fillStyle = `rgba(255, 250, 235, ${brightness})`;
  ctx.beginPath();
  ctx.arc(c.x, c.y, baseR * 0.32, 0, Math.PI * 2);
  ctx.fill();

  // vertical "beam" — a faint UV column rising up from the singularity
  // into the cavity. Suggests the implosion axis.
  if (tweaks.implosionBeam) {
    const beamH = 280 * c.scale;
    const beamW = baseR * 1.4;
    const beam = ctx.createLinearGradient(c.x, c.y, c.x, c.y - beamH);
    beam.addColorStop(0,    `rgba(180, 200, 255, ${0.45 * brightness})`);
    beam.addColorStop(0.35, `rgba(140, 160, 255, ${0.22 * brightness})`);
    beam.addColorStop(0.75, `rgba(110, 130, 230, ${0.08 * brightness})`);
    beam.addColorStop(1,    `rgba(100, 110, 220, 0)`);
    ctx.fillStyle = beam;
    // soft ellipse mask via radial gradient blur — simulate with thin column
    ctx.beginPath();
    ctx.moveTo(c.x - beamW * 0.5, c.y);
    ctx.lineTo(c.x + beamW * 0.5, c.y);
    ctx.lineTo(c.x + beamW * 0.15, c.y - beamH);
    ctx.lineTo(c.x - beamW * 0.15, c.y - beamH);
    ctx.closePath();
    ctx.fill();
  }

  ctx.restore();
}

window.__domeEffects = { drawDomeParticles, drawBowlInterior, drawDomeCenter };
