// dome.jsx — main 3D dome render component.
// Uses dome-helpers.jsx for geometry + palette + projection.

const { useEffect: useEffectDomeMain, useRef: useRefDomeMain } = React;

function Dome({ tweaks }) {
  const canvasRef = useRefDomeMain(null);
  const starsRef = useRefDomeMain(null);
  const particlesRef = useRefDomeMain(null);
  const sizeRef = useRefDomeMain({ w: 0, h: 0 });

  // rebuild particles when arm count / density changes
  useEffectDomeMain(() => {
    const { makeDomeParticles } = window.__domeHelpers;
    particlesRef.current = makeDomeParticles(tweaks.armCount, tweaks.particleDensity);
  }, [tweaks.armCount, tweaks.particleDensity]);

  useEffectDomeMain(() => {
    const canvas = canvasRef.current;
    const ctx = canvas.getContext('2d');
    const H = window.__domeHelpers;
    let raf = 0;
    const t0 = performance.now();

    const resize = () => {
      const dpr = Math.min(window.devicePixelRatio || 1, 2);
      const w = window.innerWidth;
      const h = window.innerHeight;
      canvas.width = w * dpr;
      canvas.height = h * dpr;
      canvas.style.width = w + 'px';
      canvas.style.height = h + 'px';
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
      sizeRef.current = { w, h };
      starsRef.current = H.makeDomeStars(Math.round((w * h) / 4500));
    };
    resize();
    window.addEventListener('resize', resize);

    if (!particlesRef.current) {
      particlesRef.current = H.makeDomeParticles(tweaks.armCount, tweaks.particleDensity);
    }

    const draw = (now) => {
      const t = (now - t0) / 1000;
      const { w: W, h: HH } = sizeRef.current;

      // Background — same deep space as iris
      ctx.fillStyle = '#03030a';
      ctx.fillRect(0, 0, W, HH);
      drawDomeUVField(ctx, W, HH, t);
      drawDomeStarfield(ctx, starsRef.current, W, HH, t);

      // world bowl dims
      const R = 1.25;            // bowl rim radius
      const Hh = 0.95;           // bowl total height (rim above origin)
      const project = H.makeProjector(W, HH, {
        tiltDeg: tweaks.tilt,
        camY: tweaks.camHeight,     // camera height above origin
        camDist: tweaks.camDistance,// camera distance in +z (in front of bowl)
        focal: 1.0,
        worldScale: 0.52,
        originScreenY: 0.74,        // anchor singularity at ~74% down screen
      });

      // pre-compute palette
      const ringPalette = H.domeBuildRingPalette(tweaks.ringCount, tweaks.palette);

      const D = window.__domeDraw;
      const E = window.__domeEffects;

      // 1) Bowl interior wash — a soft gradient suggesting the cavity volume
      E.drawBowlInterior(ctx, W, HH, project, R, Hh, t, tweaks);

      // 2) Rings (back halves first, then front halves — for depth illusion)
      D.drawDomeRings(ctx, project, R, Hh, ringPalette, t, tweaks, 'back');

      // 3) Arms — spiral down the bowl wall toward singularity
      D.drawDomeArms(ctx, project, R, Hh, t, tweaks);

      // 4) Singularity at bottom — bright white-gold point with UV halo
      E.drawDomeCenter(ctx, project, t, tweaks);

      // 5) Front halves of rings (over the singularity glow)
      D.drawDomeRings(ctx, project, R, Hh, ringPalette, t, tweaks, 'front');

      // 6) Particles — sorted by depth so close ones overlap distant ones
      E.drawDomeParticles(ctx, project, particlesRef.current, R, Hh, t, tweaks);

      // 7) Soft horizon vignette (above the rim — outer space)
      drawDomeVignette(ctx, W, HH);

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

// ── background fields (same DNA as iris) ────────────────────────────────────

function drawDomeUVField(ctx, W, H, t) {
  const blobs = [
    { x: 0.18, y: 0.14, r: 0.55, h: 270, s: 80, l: 30, a: 0.22 },
    { x: 0.84, y: 0.20, r: 0.50, h: 250, s: 90, l: 28, a: 0.18 },
    { x: 0.78, y: 0.86, r: 0.45, h: 285, s: 90, l: 26, a: 0.14 },
    { x: 0.22, y: 0.82, r: 0.42, h: 305, s: 70, l: 26, a: 0.12 },
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

function drawDomeStarfield(ctx, stars, W, H, t) {
  if (!stars) return;
  ctx.save();
  // stars cluster more strongly above the horizon (top half) — beyond the rim
  for (let i = 0; i < stars.length; i++) {
    const s = stars[i];
    const x = s.x * W;
    const y = s.y * H;
    // dim stars near where the singularity sits (the bowl's interior region)
    const cx = W / 2, cy = H * 0.62;
    const d = Math.hypot(x - cx, y - cy);
    const fade = Math.min(1, d / (Math.min(W, H) * 0.4));
    // stars FADE inside the bowl projection area, brighten above
    const heightBoost = y < H * 0.45 ? 1.2 : 0.6;
    const tw = (Math.sin(t * 0.9 + s.tw) + 1) * 0.5;
    const a = s.a * fade * heightBoost * (0.55 + tw * 0.45);
    ctx.fillStyle = `rgba(220, 215, 255, ${a})`;
    ctx.beginPath();
    ctx.arc(x, y, s.r, 0, Math.PI * 2);
    ctx.fill();
  }
  ctx.restore();
}

function drawDomeVignette(ctx, W, H) {
  // light vignette tying canvas to page edges
  const g = ctx.createRadialGradient(W / 2, H * 0.62, Math.min(W, H) * 0.2,
                                     W / 2, H * 0.62, Math.max(W, H) * 0.8);
  g.addColorStop(0, 'rgba(0,0,0,0)');
  g.addColorStop(1, 'rgba(0,0,0,0.55)');
  ctx.fillStyle = g;
  ctx.fillRect(0, 0, W, H);
}

window.Dome = Dome;
