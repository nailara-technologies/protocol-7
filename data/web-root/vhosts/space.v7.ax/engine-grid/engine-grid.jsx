/* eslint-disable */
// Space Engine Grid — Protocol-7 observer-centric reference space
// Brief 1: darksun-centered isometric 3D wireframe of Z.Y.X signature space.

const { useState, useMemo, useEffect, useRef, useCallback, Fragment } = React;

const maxShellPreview = (focal) => Math.ceil(63 / focal);

// -----------------------------------------------------------------------------
// Constants
// -----------------------------------------------------------------------------

const W = 1200, H = 900;
const CX = W / 2, CY = H / 2;
const COS30 = Math.cos(Math.PI / 6);
const SIN30 = 0.5;

// Iso projection: y is vertical, x and z are floor axes
function project(x, y, z, unit) {
  const sx = (x - z) * COS30 * unit;
  const sy = -(y - (x + z) * SIN30) * unit;
  return [CX + sx, CY + sy];
}

// 32-char alphabet for the AMOS7-style checksum (Crockford-ish, no 0/1)
const ALPHABET = "23456789ABCDEFGHIJKLMNPQRSTUVWXYZ";

function hash7(z, y, x) {
  // splitmix32-ish deterministic hash → 7 chars (Math.imul keeps 32-bit truncation)
  let h = (((z + 1024) & 2047) << 22) ^ (((y + 1024) & 2047) << 11) ^ ((x + 1024) & 2047);
  h = (h ^ 0x9E3779B1) >>> 0;
  let out = "";
  for (let i = 0; i < 7; i++) {
    h ^= h << 13; h >>>= 0;
    h ^= h >>> 17;
    h ^= (h << 5) >>> 0;
    h = Math.imul(h, 2654435761) >>> 0;
    out += ALPHABET[h % 32];
  }
  return out;
}

function dominantChar(z, y, x) {
  // a pretend "dominant char at that position"; deterministic, used in tooltip
  const h = hash7(z + 1, y + 1, x + 1);
  return h[3];
}

// Generate every node on shell s (max(|z|,|y|,|x|) == s)
function shellNodes(s) {
  const list = [];
  for (let z = -s; z <= s; z++) {
    for (let y = -s; y <= s; y++) {
      for (let x = -s; x <= s; x++) {
        if (Math.max(Math.abs(z), Math.abs(y), Math.abs(x)) === s) {
          list.push({ z, y, x });
        }
      }
    }
  }
  return list;
}

// Reference-count gravity: nodes closer to a coordinate axis (face centers) are
// "heavier" (more references) than corners. Used to pick which to render when sampling.
function gravity(n) {
  const ax = [Math.abs(n.z), Math.abs(n.y), Math.abs(n.x)].sort((a,b)=>b-a);
  // face centers: ax[1] = ax[2] = 0  → high gravity
  // edges:       ax[1] > 0, ax[2] = 0
  // corners:     all equal           → low gravity
  return -(ax[1] + ax[2] * 1.5);
}

// -----------------------------------------------------------------------------
// Palettes  (default = brief tokens; alts emphasize the project's deep-blue
// / fluorescent backlight vocabulary while preserving harmonic balance)
// -----------------------------------------------------------------------------

const PALETTES = {
  // Default — deep electric-blue dominant, glowing out of an indigo field.
  // Tuned so the visible shells (1..5 at focal=13) span enough cool-hue range
  // to read distinctly after bloom; outer stops carry the ÷13 harmonic into
  // gold/violet for low-focal views.
  "backlight": {
    stops: [
      "#2a1a8a",  // 1  deep indigo
      "#1340d8",  // 2  saturated electric blue
      "#2b88f0",  // 3  bright cyan-blue
      "#5fcaff",  // 4  cyan
      "#a8e8ff",  // 5  pale cyan
      "#d4f0c8",  // 6  cool mint
      "#f0e090",  // 7  fluorescent gold
      "#f0b860",  // 8  warm gold
      "#d878b8",  // 9  coral-violet
      "#9858d0",  // 10 violet
      "#6038b0",  // 11 deep violet
      "#3a1f80",  // 12 deeper violet
      "#1a0a48",  // 13 near-bg violet
    ],
    axis: "#1a1f3a",
    floor: "#1a1f3a",
    label: "#7ea8d4",
    bg: "#06050f",
  },
  // Original brief spec — kept available for fidelity reference.
  "brief": {
    stops: [
      "#0A2F2F","#0F4D52","#108088","#00B8CC","#00E5FF","#56D9C2",
      "#B8C76A","#FFB300","#FF8C2A","#E14B6C","#9D4EDD","#5A1D9C","#2E003E"
    ],
    axis: "#2A3A4A",
    floor: "#1d2a3a",
    label: "#B8D4E3",
    bg: "#05070A",
  },
  // ÷13 harmonic, violet-warm rotation — same family as the iris reference.
  "vortex-13": {
    stops: [
      "#1a0a3d","#2c1466","#3a1f96","#4a2dd0","#6a4cff","#a47cff",
      "#3df0d6","#10ffd1","#2af0a0","#bfff5a","#ffd33d","#ff7a3d","#ff2a6d"
    ],
    axis: "#2a1f4a",
    floor: "#221a3a",
    label: "#a8a0e0",
    bg: "#06031a",
  }
};

// -----------------------------------------------------------------------------
// Perspective grid floor — faint vanishing-point grid behind everything to
// give the dark field a sense of depth (echoes the holographic-cube reference).
// -----------------------------------------------------------------------------

function PerspectiveFloor({ palette }) {
  // Vanishing point at the darksun
  const vp = [CX, CY];
  const lines = [];
  // Horizontal "rails" rising toward the vanishing point
  const railCount = 14;
  for (let i = 1; i <= railCount; i++) {
    const t = i / railCount;
    // exponential spacing — denser near the horizon
    const ease = Math.pow(t, 1.6);
    const yBelow = CY + (H * 0.55) * ease;
    const yAbove = CY - (H * 0.55) * ease;
    const op = 0.05 + (1 - t) * 0.05;
    if (yBelow < H + 40)
      lines.push(<line key={`rb${i}`} x1={-40} y1={yBelow} x2={W + 40} y2={yBelow}
        stroke={palette.floor} strokeOpacity={op} strokeWidth="0.5" />);
    if (yAbove > -40)
      lines.push(<line key={`ra${i}`} x1={-40} y1={yAbove} x2={W + 40} y2={yAbove}
        stroke={palette.floor} strokeOpacity={op * 0.55} strokeWidth="0.5" />);
  }
  // Radial "spokes" — rays from vanishing point to canvas edge
  const spokes = 32;
  for (let i = 0; i < spokes; i++) {
    const a = (i / spokes) * Math.PI * 2;
    const x2 = vp[0] + Math.cos(a) * 1400;
    const y2 = vp[1] + Math.sin(a) * 1400;
    lines.push(<line key={`s${i}`} x1={vp[0]} y1={vp[1]} x2={x2} y2={y2}
      stroke={palette.floor} strokeOpacity="0.045" strokeWidth="0.5" />);
  }
  return <g className="floor">{lines}</g>;
}

// -----------------------------------------------------------------------------
// Iris halo around darksun: 13 concentric rings.
// -----------------------------------------------------------------------------

function IrisHalo({ palette, maxShell }) {
  const stops = palette.stops;
  return (
    <g className="iris">
      {stops.map((c, i) => {
        // Inner-most iris ring at r=18, expanding to r=64.
        const r = 18 + i * 3.6;
        const active = i + 1 <= maxShell;
        const dash = active ? "0" : "1 2";
        return (
          <circle
            key={i}
            className={active ? "iris-active" : ""}
            cx={CX} cy={CY} r={r}
            fill="none"
            stroke={c}
            strokeOpacity={active ? 0.40 : 0.14}
            strokeWidth={active ? 0.9 : 0.5}
            strokeDasharray={dash}
            style={active ? { animationDelay: `${i * 0.18}s` } : undefined}
          />
        );
      })}
    </g>
  );
}

// -----------------------------------------------------------------------------
// Darksun core: pulsing indigo-cyan void with multi-stop radial gradient.
// -----------------------------------------------------------------------------

function Darksun({ palette }) {
  const cyan = palette.stops[3];
  const teal = palette.stops[1];
  const indigo = palette.stops[0];
  return (
    <g>
      <defs>
        <radialGradient id="darksunGrad" cx="50%" cy="50%" r="50%">
          <stop offset="0%"  stopColor={cyan} stopOpacity="0.55" />
          <stop offset="35%" stopColor={cyan} stopOpacity="0.30" />
          <stop offset="70%" stopColor={indigo} stopOpacity="0.20" />
          <stop offset="100%" stopColor="#000" stopOpacity="0" />
        </radialGradient>
        <radialGradient id="darksunVoid" cx="50%" cy="50%" r="50%">
          <stop offset="0%"  stopColor="#000" stopOpacity="0.92" />
          <stop offset="65%" stopColor="#040314" stopOpacity="0.55" />
          <stop offset="100%" stopColor="#040314" stopOpacity="0" />
        </radialGradient>
        <radialGradient id="darksunCore" cx="50%" cy="50%" r="50%">
          <stop offset="0%"  stopColor="#dff4ff" stopOpacity="0.85" />
          <stop offset="30%" stopColor={cyan} stopOpacity="0.7" />
          <stop offset="100%" stopColor={cyan} stopOpacity="0" />
        </radialGradient>
      </defs>
      {/* outer glow */}
      <circle cx={CX} cy={CY} r={72} fill="url(#darksunGrad)" />
      {/* void */}
      <circle cx={CX} cy={CY} r={16} fill="url(#darksunVoid)" />
      {/* core pulse */}
      <circle className="darksun-core" cx={CX} cy={CY} r={10} fill="url(#darksunCore)" />
      {/* hard center pixel */}
      <circle cx={CX} cy={CY} r={1.1} fill="#eaf6ff" opacity="0.9" />
    </g>
  );
}

// -----------------------------------------------------------------------------
// Axis lines (±Z, ±Y, ±X) extending to canvas edges through darksun.
// -----------------------------------------------------------------------------

function Axes({ palette, unit }) {
  // length large enough to cross canvas
  const L = 18;
  const axes = [
    { from: [-L,0,0], to: [L,0,0], label: ["+X","-X"] },
    { from: [0,-L,0], to: [0,L,0], label: ["+Y","-Y"] },
    { from: [0,0,-L], to: [0,0,L], label: ["+Z","-Z"] },
  ];
  return (
    <g className="axes">
      {axes.map((a, i) => {
        const p1 = project(...a.from, unit);
        const p2 = project(...a.to,   unit);
        // tick marks at integer positions
        const ticks = [];
        for (let t = -L; t <= L; t++) {
          if (t === 0) continue;
          let p;
          if (i === 0) p = project(t,0,0,unit);
          else if (i === 1) p = project(0,t,0,unit);
          else p = project(0,0,t,unit);
          const big = (t % 5 === 0);
          ticks.push(
            <circle key={t} cx={p[0]} cy={p[1]} r={big ? 1 : 0.5} fill={palette.axis} opacity={big ? 0.6 : 0.3} />
          );
        }
        return (
          <Fragment key={i}>
            <line x1={p1[0]} y1={p1[1]} x2={p2[0]} y2={p2[1]} stroke={palette.axis} strokeWidth="0.6" />
            {ticks}
          </Fragment>
        );
      })}
      {/* axis end labels */}
      {(() => {
        const ends = [
          { p:[9,0,0],  t:"+X" }, { p:[-9,0,0], t:"-X" },
          { p:[0,9,0],  t:"+Y" }, { p:[0,-9,0], t:"-Y" },
          { p:[0,0,9],  t:"+Z" }, { p:[0,0,-9], t:"-Z" },
        ];
        return ends.map((e, i) => {
          const [x, y] = project(...e.p, unit);
          return (
            <text key={i} x={x + 6} y={y + 3} fontSize="9"
              fontFamily="JetBrains Mono, monospace" fill={palette.axis} opacity="0.85"
              letterSpacing="0.1em">{e.t}</text>
          );
        });
      })()}
    </g>
  );
}

// -----------------------------------------------------------------------------
// Orbital path ellipses: three orthogonal great-circles per shell.
// -----------------------------------------------------------------------------

function OrbitalEllipses({ palette, maxShell, unit }) {
  const segments = 96;
  const out = [];
  for (let s = 1; s <= maxShell; s++) {
    const color = palette.stops[Math.min(s - 1, 12)];
    // three orthogonal planes
    const planes = [
      (t) => [s*Math.cos(t), s*Math.sin(t), 0],  // XY plane
      (t) => [0, s*Math.cos(t), s*Math.sin(t)],  // YZ plane
      (t) => [s*Math.cos(t), 0, s*Math.sin(t)],  // XZ plane
    ];
    planes.forEach((fn, pi) => {
      let d = "";
      for (let i = 0; i <= segments; i++) {
        const t = (i / segments) * Math.PI * 2;
        const [x, y, z] = fn(t);
        const [sx, sy] = project(x, y, z, unit);
        d += (i === 0 ? "M" : "L") + sx.toFixed(2) + "," + sy.toFixed(2) + " ";
      }
      out.push(
        <path key={`${s}-${pi}`} d={d} fill="none" stroke={color}
          strokeOpacity={0.10} strokeWidth="0.55" strokeDasharray="2 5" />
      );
    });
  }
  return <g className="orbits">{out}</g>;
}

// -----------------------------------------------------------------------------
// Node generation + same-shell adjacency
// -----------------------------------------------------------------------------

function buildNodes(maxShell, densityLimit) {
  let all = [];
  for (let s = 1; s <= maxShell; s++) {
    let shell = shellNodes(s);
    // Sample outer shells if too dense
    if (shell.length > densityLimit && s >= 3) {
      shell.sort((a, b) => gravity(b) - gravity(a));
      shell = shell.slice(0, Math.max(densityLimit, Math.floor(shell.length * 0.45)));
    }
    shell.forEach(n => {
      n.shell = s;
      n.id = hash7(n.z, n.y, n.x);
      all.push(n);
    });
  }
  return all;
}

function adjacencyEdges(nodes) {
  // Build lookup for O(1) neighbor checks
  const key = (z, y, x) => `${z},${y},${x}`;
  const idx = new Map();
  nodes.forEach((n, i) => idx.set(key(n.z, n.y, n.x), i));
  const edges = [];
  const seen = new Set();
  const dirs = [
    [0,0,1],[0,0,-1],[0,1,0],[0,-1,0],[1,0,0],[-1,0,0]
  ];
  nodes.forEach((n, i) => {
    for (const [dz, dy, dx] of dirs) {
      const nz = n.z + dz, ny = n.y + dy, nx = n.x + dx;
      const ns = Math.max(Math.abs(nz), Math.abs(ny), Math.abs(nx));
      if (ns !== n.shell) continue; // only same-shell
      const k = key(nz, ny, nx);
      if (!idx.has(k)) continue;
      const j = idx.get(k);
      const eKey = i < j ? `${i}-${j}` : `${j}-${i}`;
      if (seen.has(eKey)) continue;
      seen.add(eKey);
      edges.push({ a: i, b: j, shell: n.shell });
    }
  });
  return edges;
}

// -----------------------------------------------------------------------------
// Connection arc geometry: a curved hairline arc between two same-shell nodes,
// bowing slightly outward (away from origin). Reinforces the "passing through
// crystal" feel.
// -----------------------------------------------------------------------------

function arcPath(p1, p2) {
  const midx = (p1[0] + p2[0]) / 2;
  const midy = (p1[1] + p2[1]) / 2;
  // outward bow direction
  const dx = midx - CX, dy = midy - CY;
  const len = Math.hypot(dx, dy) || 1;
  const bow = 6;
  const cx = midx + (dx / len) * bow;
  const cy = midy + (dy / len) * bow;
  return `M${p1[0].toFixed(2)},${p1[1].toFixed(2)} Q${cx.toFixed(2)},${cy.toFixed(2)} ${p2[0].toFixed(2)},${p2[1].toFixed(2)}`;
}

// -----------------------------------------------------------------------------
// Glyph shapes — diamond or hexagon, sized by shell distance.
// -----------------------------------------------------------------------------

function nodeShape(kind, x, y, r) {
  if (kind === "hex") {
    // pointy-top hexagon
    const pts = [];
    for (let i = 0; i < 6; i++) {
      const a = (Math.PI / 3) * i - Math.PI / 2;
      pts.push(`${(x + r * Math.cos(a)).toFixed(2)},${(y + r * Math.sin(a)).toFixed(2)}`);
    }
    return <polygon points={pts.join(" ")} />;
  }
  // diamond
  return (
    <polygon points={`${x},${(y - r).toFixed(2)} ${(x + r).toFixed(2)},${y} ${x},${(y + r).toFixed(2)} ${(x - r).toFixed(2)},${y}`} />
  );
}

// -----------------------------------------------------------------------------
// Main grid component
// -----------------------------------------------------------------------------

function EngineGrid({ tweaks }) {
  const palette = PALETTES[tweaks.palette] || PALETTES.backlight;
  // focal length controls max visible shell. 63 = cube group 4³−1.
  const maxShell = Math.max(1, Math.ceil(63 / tweaks.focal));
  // unit scale: keep shell maxShell within useful canvas radius
  // shell s max iso extent in y ≈ 2s; in x ≈ 2s*cos(30°) ≈ 1.73s
  // canvas inner = 1000 x 700 (margins 100), so radius cap ≈ 320
  const targetExtent = 340;
  const unit = Math.min(40, targetExtent / Math.max(2, maxShell * 1.9));

  // Build nodes
  const { nodes, edges, projected } = useMemo(() => {
    const densityLimit = tweaks.density === "sparse" ? 80 :
                        tweaks.density === "dense" ? 260 : 160;
    const ns = buildNodes(maxShell, densityLimit);
    const proj = ns.map(n => project(n.z, n.y, n.x, unit));
    const es = tweaks.connections ? adjacencyEdges(ns) : [];
    return { nodes: ns, edges: es, projected: proj };
  }, [maxShell, tweaks.density, tweaks.connections, unit]);

  // Hover state
  const [hover, setHover] = useState(null); // {index, neighbors:[i...]}
  const leaveTimerRef = useRef(null);
  const onEnter = useCallback((i) => {
    if (leaveTimerRef.current) {
      clearTimeout(leaveTimerRef.current);
      leaveTimerRef.current = null;
    }
    // compute neighbor indices via adjacency
    const nbrs = edges.filter(e => e.a === i || e.b === i).map(e => e.a === i ? e.b : e.a);
    setHover({ i, nbrs });
  }, [edges]);
  const onLeave = useCallback(() => {
    // small grace delay so the cursor can travel toward the tooltip without
    // flickering hover off.
    if (leaveTimerRef.current) clearTimeout(leaveTimerRef.current);
    leaveTimerRef.current = setTimeout(() => setHover(null), 120);
  }, []);

  // Update HUD readouts
  useEffect(() => {
    document.getElementById('hud-focal').textContent = String(tweaks.focal);
    document.getElementById('hud-maxshell').textContent = String(maxShell);
    document.getElementById('hud-visible').textContent = nodes.length.toLocaleString();
  }, [tweaks.focal, maxShell, nodes.length]);

  // Update tooltip content + position (offset to the LEFT of the node, with a
  // gap so it doesn't cover surrounding nodes; auto-flip to the right if the
  // node is close to the left edge).
  useEffect(() => {
    const tt = document.getElementById('tooltip');
    if (hover == null) {
      tt.style.display = 'none';
      return;
    }
    const n = nodes[hover.i];
    document.getElementById('tt-id').textContent = n.id;
    document.getElementById('tt-coord').textContent = `${n.z} : ${n.y} : ${n.x}`;
    document.getElementById('tt-shell').textContent = `${n.shell}  ·  ${nodes.filter(x=>x.shell===n.shell).length} nodes`;
    document.getElementById('tt-dom').textContent = dominantChar(n.z, n.y, n.x);

    const [sx, sy] = projected[hover.i];
    const gap = 44;
    const flipRight = sx < 260; // near left edge → flip
    tt.classList.toggle('flip-right', flipRight);
    tt.style.display = 'block';
    tt.style.left = (flipRight ? (sx + gap) : (sx - gap)) + 'px';
    tt.style.top  = sy + 'px';
  }, [hover, nodes, projected]);

  // Render
  const hoverSet = useMemo(() => {
    if (!hover) return null;
    const s = new Set(hover.nbrs); s.add(hover.i); return s;
  }, [hover]);

  return (
    <svg className="grid" viewBox={`0 0 ${W} ${H}`} xmlns="http://www.w3.org/2000/svg">
      <defs>
        {/* bloom filter — colors emerge from the field rather than punch against pure black */}
        <filter id="bloom" x="-50%" y="-50%" width="200%" height="200%">
          <feGaussianBlur stdDeviation="0.8" result="b1" />
          <feGaussianBlur in="SourceGraphic" stdDeviation="2.6" result="b2" />
          <feMerge>
            <feMergeNode in="b2" />
            <feMergeNode in="b1" />
            <feMergeNode in="SourceGraphic" />
          </feMerge>
        </filter>
        <filter id="softGlow" x="-50%" y="-50%" width="200%" height="200%">
          <feGaussianBlur stdDeviation="1.0" result="b" />
          <feMerge>
            <feMergeNode in="b" />
            <feMergeNode in="SourceGraphic" />
          </feMerge>
        </filter>
      </defs>

      <PerspectiveFloor palette={palette} />

      {/* faint dot-matrix backdrop in the interior */}
      {tweaks.matrix && (
        <g opacity="0.18">
          {Array.from({length: 35}).map((_, ry) => (
            Array.from({length: 50}).map((_, rx) => {
              const x = 100 + rx * 20;
              const y = 100 + ry * 20;
              return <circle key={`${rx}-${ry}`} cx={x} cy={y} r="0.4" fill={palette.axis} />;
            })
          ))}
        </g>
      )}

      <Axes palette={palette} unit={unit} />
      {tweaks.ellipses && <OrbitalEllipses palette={palette} maxShell={maxShell} unit={unit} />}

      {/* connection arcs (under nodes) */}
      <g className="connections">
        {edges.map((e, i) => {
          const p1 = projected[e.a];
          const p2 = projected[e.b];
          const c = palette.stops[Math.min(e.shell - 1, 12)];
          const isHover = hoverSet && (hoverSet.has(e.a) && hoverSet.has(e.b));
          return (
            <path key={i} d={arcPath(p1, p2)}
              stroke={c}
              strokeOpacity={isHover ? 0.85 : 0.22}
              strokeWidth={isHover ? 1.0 : 0.45}
              fill="none"
            />
          );
        })}
      </g>

      <IrisHalo palette={palette} maxShell={maxShell} />
      <Darksun palette={palette} />

      {/* nodes — each with its own colored halo (renders correctly without SVG filter quirks) */}
      <g className="nodes">
        {nodes.map((n, i) => {
          const [x, y] = projected[i];
          const c = palette.stops[Math.min(n.shell - 1, 12)];
          const isHover = hover && hover.i === i;
          const isNeighbor = hoverSet && hoverSet.has(i) && !isHover;
          const kind = (n.shell % 2 === 0) ? "hex" : "diamond";
          // Reference-count gravity: inner shells = high-ref = bigger/brighter.
          const shellWeight = 1 - (n.shell - 1) / Math.max(maxShell, 6) * 0.45;
          const baseR = 3.2 + shellWeight * 2.5;
          const r = isHover ? baseR + 3 : (isNeighbor ? baseR + 2 : baseR);
          const op = isHover ? 1 : (isNeighbor ? 0.95 : 0.55 + shellWeight * 0.4);
          // Only the inner shells carry a prominent halo — creates a luminous
          // core fading into crystalline outer structure.
          const innerness = Math.max(0, 1 - (n.shell - 1) / 3); // 1 at shell 1, 0 by shell 4
          const haloR = r * (2.0 + innerness * 1.4);
          const haloOp = isHover ? 0.32 : (isNeighbor ? 0.28 : innerness * 0.25 + 0.04);
          return (
            <g key={i}
              className={`node ${isHover ? 'hover' : ''}`}
              onMouseEnter={() => onEnter(i)}
              onMouseLeave={onLeave}
              style={{ color: c }}
            >
              {/* colored halo */}
              <circle cx={x} cy={y} r={haloR} fill={c} fillOpacity={haloOp * 0.4} />
              <circle cx={x} cy={y} r={haloR * 0.55} fill={c} fillOpacity={haloOp} />
              <g className={`node-glyph ${isNeighbor ? 'neighbor-pulse' : ''}`} style={{ color: c }}>
                {React.cloneElement(nodeShape(kind, x, y, r), {
                  fill: c,
                  fillOpacity: op,
                  stroke: isHover ? "#9db4ff" : c,
                  strokeOpacity: isHover ? 0.55 : 0,
                  strokeWidth: 0.5,
                })}
              </g>
              {/* invisible hit target — generous radius so the cursor can travel
                  toward the tooltip without leaving the hover region */}
              <circle className="node-hit" cx={x} cy={y} r="16" />
            </g>
          );
        })}
      </g>

      {/* labels: hover + neighbors always; ALL labels only when tweak is on */}
      <g className="labels">
        {nodes.map((n, i) => {
          const isHover = hover && hover.i === i;
          const isNeighbor = hoverSet && hoverSet.has(i) && !isHover;
          if (!tweaks.labels && !isHover && !isNeighbor) return null;
          const [x, y] = projected[i];
          const r = isHover ? 7 : (isNeighbor ? 6 : 4);
          return (
            <text
              key={i}
              className="nlabel"
              x={x + r + 3}
              y={y + 2.5}
              fill={palette.label}
              fillOpacity={isHover ? 0.95 : (isNeighbor ? 0.8 : 0.42)}
            >
              {n.id}
            </text>
          );
        })}
      </g>

      {/* small frame/payload glyphs in the 4 quadrants (076923 / 153846 motifs) */}
      <g opacity="0.32">
        <text x={130} y={H - 130} fontSize="9" fontFamily="JetBrains Mono, monospace"
          fill={palette.axis} letterSpacing="0.15em">076923</text>
        <text x={W - 200} y={H - 130} fontSize="9" fontFamily="JetBrains Mono, monospace"
          fill={palette.stops[7]} letterSpacing="0.15em">153846</text>
      </g>
    </svg>
  );
}

// -----------------------------------------------------------------------------
// Mount + Tweaks
// -----------------------------------------------------------------------------

function App() {
  const TWEAK_DEFAULTS = /*EDITMODE-BEGIN*/{
    "focal": 13,
    "palette": "backlight",
    "labels": false,
    "connections": true,
    "ellipses": true,
    "matrix": false,
    "density": "balanced"
  }/*EDITMODE-END*/;

  const [tweaks, setTweak] = useTweaks(TWEAK_DEFAULTS);

  return (
    <Fragment>
      <EngineGrid tweaks={tweaks} />
      <TweaksPanel title="Tweaks · Engine Grid">
        <TweakSection label="OBSERVER">
          <TweakSlider label={`Focal · max shell ${maxShellPreview(tweaks.focal)}`} value={tweaks.focal}
            min={3} max={31} step={1}
            onChange={(v) => setTweak('focal', v)} />
        </TweakSection>

        <TweakSection label="PALETTE">
          <TweakRadio
            value={tweaks.palette}
            options={[
              { value: "backlight", label: "Backlight" },
              { value: "brief",     label: "Brief" },
              { value: "vortex-13", label: "÷13 Vortex" },
            ]}
            onChange={(v) => setTweak('palette', v)} />
        </TweakSection>

        <TweakSection label="GEOMETRY">
          <TweakToggle label="Adjacency arcs"   value={tweaks.connections} onChange={(v) => setTweak('connections', v)} />
          <TweakToggle label="Orbital ellipses" value={tweaks.ellipses}    onChange={(v) => setTweak('ellipses', v)} />
          <TweakToggle label="All node labels"  value={tweaks.labels}      onChange={(v) => setTweak('labels', v)} />
          <TweakToggle label="Dot-matrix field" value={tweaks.matrix}      onChange={(v) => setTweak('matrix', v)} />
        </TweakSection>

        <TweakSection label="DENSITY">
          <TweakRadio
            value={tweaks.density}
            options={[
              { value: "sparse",    label: "Sparse" },
              { value: "balanced",  label: "Balanced" },
              { value: "dense",     label: "Dense" },
            ]}
            onChange={(v) => setTweak('density', v)} />
        </TweakSection>
      </TweaksPanel>
    </Fragment>
  );
}

ReactDOM.createRoot(document.getElementById('grid-root')).render(<App />);
