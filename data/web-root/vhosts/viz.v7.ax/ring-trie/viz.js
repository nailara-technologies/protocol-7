// Ring-Trie Geometry — data generation + SVG rendering
// Brief 2 / Protocol-7 / nailara-technologies

(function () {
  'use strict';

  const SVG_NS = 'http://www.w3.org/2000/svg';

  // ── Geometry ──────────────────────────────────────────────────────────
  const CX = 500, CY = 478;
  // Brief radii [60, 110, 170, 240, 320, 410, 510, 620] scaled by ~1.51
  // to fit 1000×1000 canvas with 80px padding.
  const RADII = [40, 73, 113, 160, 213, 273, 340, 413];
  const RING_COUNTS = [96, 248, 412, 538, 422, 263, 134, 51];
  // Blacklight / UV palette — tuned to match the repo's cubic-space-topology screenshot:
  // hues 220–247°, lightness low; one cyan accent at R1 for the iris-seed "cool inner".
  // R7 is the seed's "void ring" — nearly merged with background.
  const RING_COLORS = [
    '#BFD0FF', // R0  soft ice-blue (no pure white)
    '#7CE6FF', // R1  fluorescent cyan
    '#38C1FF', // R2  electric sky-blue
    '#5A78FF', // R3  periwinkle
    '#3645E8', // R4  electric deep blue
    '#1F2DB8', // R5  cobalt
    '#131C7A', // R6  indigo
    '#0A1245'  // R7  void ring (near-black blue)
  ];

  // ── Curated tokens (highest-rank slots per ring; rest synthetic) ─────
  const NAMED = [
    // ring 0 — most-frequent codepoints in an English-leaning corpus
    [' ','e','t','a','o','i','n','s','r','h','l','d','c','u','m','f','p','g',
     'w','y','b','v','k','x','j','q','z','.',',',"'",';',':','-','!','?',
     '0','1','2','3','4','5','9','"','/','*','(',')','[',']','='],
    // ring 1 — top English bigrams
    ['th','he','in','er','an','re','on','at','en','nd','ti','es','or','te',
     'of','ed','is','it','al','ar','st','to','nt','ng','se','ha','as','ou',
     'io','le','ve','co','me','de','hi','ri','ro','ic','ne','ea','ra','ce',
     'li','ch','ll','be','ma','si','om','ur'],
    // ring 2 — top trigrams
    ['the','and','ing','ion','tio','ent','ati','for','her','ter','hat','tha',
     'ere','ate','his','con','res','ver','all','ons','nce','men','ith','ted',
     'ers','pro','thi','wit','are','ess','not','ive','was','ect','rea','com',
     'eve','per','int','est','sta','cti','ica','ist','sio','out','ble'],
    // ring 3 — common 4-grams
    ['tion','atio','that','ther','with','ment','ions','this','here','ould',
     'ight','have','hich','whic','ting','ence','ical','them','ance','ever',
     'from','nter','tive','sion','ress','ound','side','tory','ects','part',
     'pres','some','rate','peop','time','call','want','same','well'],
    // ring 4
    ['ation','tions','other','which','their','would','there','about','these',
     'those','where','after','first','never','every','still','right','under',
     'again','great','being','world','three','years','place','while','large'],
    // ring 5
    ['nation','ration','mation','cation','ations','tional','though','ground',
     'rought','spense','though','people','should','before','number','around',
     'second'],
    // ring 6
    ['nations','rations','mations','cations','tionals','tioning','through',
     'against','however'],
    // ring 7
    ['ication','ications','mations','plications','nications']
  ];

  const ENGLISH_TERMINAL = new Set([
    'the','and','for','his','her','was','not','are','all','but','can','had','has',
    'one','our','out','you','who','how','its','any','two','may','say','she','use',
    'way','will','with','this','that','they','from','have','were','what','your',
    'when','make','like','time','some','more','only','also','into','than','over',
    'very','well','then','them','about','first','their','there','would','these',
    'those','where','after','still','right','great','other','which','three',
    'every','being','world','years','place','while','large','should','before',
    'number','around','second','through','against','however','people','though',
    'around','rate','want','same','part','side','make','call','well','time'
  ]);

  // Deterministic PRNG (mulberry32-like)
  function mkRng(seed) {
    let s = seed | 0;
    return function () {
      s = (s + 0x6D2B79F5) | 0;
      let t = s;
      t = Math.imul(t ^ (t >>> 15), t | 1);
      t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
      return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    };
  }
  const rng = mkRng(0x7717);

  // Plausible synthetic n-gram (alternating consonant/vowel-ish)
  const C = 'bcdfghjklmnprstvwy';
  const V = 'aeiou';
  function synth(ring, idx) {
    const len = ring + 1;
    let s = '';
    let r = mkRng(ring * 1009 + idx * 9173 + 17);
    let cur = (idx + ring) & 1; // start type alternates
    for (let i = 0; i < len; i++) {
      const src = cur ? V : C;
      s += src[Math.floor(r() * src.length)];
      cur = 1 - cur;
      // occasional double-consonant or vowel pair
      if (r() < 0.18) cur = 1 - cur;
    }
    return s;
  }

  // Zipfian frequency falloff per ring
  function freqAt(ring, rank) {
    const base = 48000 * Math.pow(0.52, ring);
    return Math.max(1, Math.round(base / Math.pow(rank, 1.07)));
  }

  // ── Build node lists ──────────────────────────────────────────────────
  const ringNodes = [];
  for (let r = 0; r < 8; r++) {
    const arr = [];
    const named = NAMED[r] || [];
    const seen = new Set();
    for (let i = 0; i < RING_COUNTS[r]; i++) {
      let tok;
      if (i < named.length) tok = named[i];
      else {
        // ensure unique
        let attempt = 0;
        do { tok = synth(r, i + attempt * 7919); attempt++; }
        while (seen.has(tok) && attempt < 12);
      }
      seen.add(tok);
      const freq = freqAt(r, i + 1);
      let terminal;
      if (ENGLISH_TERMINAL.has(tok)) terminal = true;
      else if (r === 0) terminal = (tok === ' ' || tok === '.' || tok === ',' || tok === 'a' || tok === 'I');
      else terminal = (r >= 2 && rng() < (0.10 + 0.04 * r));
      arr.push({ ring: r, rank: i + 1, token: tok, freq, terminal });
    }
    ringNodes.push(arr);
  }

  // Position: evenly distribute around each ring; bigger nodes lead CCW from top
  // (i.e. as you scan counter-clockwise, dots grow — implies CCW rotation).
  const TOP = -Math.PI / 2;
  const PHASE = [0, 0.18, -0.12, 0.22, -0.18, 0.10, -0.06, 0.04];
  for (let r = 0; r < 8; r++) {
    const N = ringNodes[r].length;
    for (let i = 0; i < N; i++) {
      // Bigger (lower i) at top → sequence advances CW so growth is CCW-leading
      const a = TOP + (i / N) * Math.PI * 2 + PHASE[r];
      const radius = RADII[r];
      const node = ringNodes[r][i];
      node.angle = a;
      node.x = CX + Math.cos(a) * radius;
      node.y = CY + Math.sin(a) * radius;
    }
  }

  // ── Parent assignment: prefix match → angular-nearest fallback ────────
  function angDist(a, b) {
    let d = Math.abs(a - b) % (Math.PI * 2);
    if (d > Math.PI) d = Math.PI * 2 - d;
    return d;
  }
  for (let r = 1; r < 8; r++) {
    const here = ringNodes[r];
    const prev = ringNodes[r - 1];
    const byTok = new Map(prev.map(p => [p.token, p]));
    for (const n of here) {
      const prefix = n.token.slice(0, -1);
      let p = byTok.get(prefix);
      if (!p) {
        // nearest by angle, mild bias toward higher-rank parents
        let best = null;
        for (const cand of prev) {
          const d = angDist(cand.angle, n.angle) + 0.0006 * cand.rank;
          if (!best || d < best.d) best = { cand, d };
        }
        p = best.cand;
      }
      n.parent = p;
    }
  }

  // ── Render ────────────────────────────────────────────────────────────
  const ringsG = document.getElementById('rings');
  const edgesG = document.getElementById('edges');
  const nodesG = document.getElementById('nodes');
  const labelsG = document.getElementById('labels');
  const tagsG = document.getElementById('ringTags');
  const hyperG = document.getElementById('hyperGrid');

  // Faint hyperspace grid backdrop (echo of cubic-space-topology)
  if (hyperG) {
    const step = 40;        // px between grid lines in screen space
    const W = 1000, H = 956;
    // Slight 3D-ish perspective: lines fan toward the centre on Y axis
    for (let y = 0; y <= H; y += step) {
      const ln = document.createElementNS(SVG_NS, 'line');
      ln.setAttribute('x1', 0); ln.setAttribute('x2', W);
      ln.setAttribute('y1', y); ln.setAttribute('y2', y);
      const d = Math.abs(y - 478) / 478;
      ln.setAttribute('stroke-opacity', (0.20 + 0.30 * d).toFixed(3));
      hyperG.appendChild(ln);
    }
    for (let x = 0; x <= W; x += step) {
      const ln = document.createElementNS(SVG_NS, 'line');
      ln.setAttribute('y1', 0); ln.setAttribute('y2', H);
      ln.setAttribute('x1', x); ln.setAttribute('x2', x);
      const d = Math.abs(x - 500) / 500;
      ln.setAttribute('stroke-opacity', (0.20 + 0.30 * d).toFixed(3));
      hyperG.appendChild(ln);
    }
  }

  // Guide rings (concentric, faint)
  for (let r = 0; r < 8; r++) {
    const c = document.createElementNS(SVG_NS, 'circle');
    c.setAttribute('cx', CX);
    c.setAttribute('cy', CY);
    c.setAttribute('r', RADII[r]);
    c.setAttribute('class', 'ring-guide');
    c.setAttribute('stroke', RING_COLORS[r]);
    c.setAttribute('stroke-opacity', r === 0 ? '0.25' : (0.20 - r * 0.012).toFixed(3));
    c.setAttribute('stroke-width', '0.45');
    c.setAttribute('stroke-dasharray', r <= 1 ? '' : (r <= 4 ? '1.2 3.5' : '0.8 5'));
    ringsG.appendChild(c);
  }
  // Sparse dotted rings beyond ring 7
  for (let r = 8; r <= 10; r++) {
    const rr = RADII[7] + (r - 7) * 14;
    if (rr > 460) break;
    const c = document.createElementNS(SVG_NS, 'circle');
    c.setAttribute('cx', CX); c.setAttribute('cy', CY); c.setAttribute('r', rr);
    c.setAttribute('class', 'ring-guide');
    c.setAttribute('stroke', '#0A1245');
    c.setAttribute('stroke-opacity', '0.22');
    c.setAttribute('stroke-width', '0.4');
    c.setAttribute('stroke-dasharray', '0.6 7');
    ringsG.appendChild(c);
  }

  // Ring tags (R0..R7) along the right-of-center radius
  for (let r = 0; r < 8; r++) {
    const t = document.createElementNS(SVG_NS, 'text');
    t.setAttribute('x', CX + RADII[r] + 9);
    t.setAttribute('y', CY + 3);
    t.setAttribute('class', 'ring-tag');
    t.setAttribute('fill', RING_COLORS[r]);
    t.setAttribute('opacity', '0.55');
    t.textContent = 'R' + r;
    tagsG.appendChild(t);
  }
  // Ring count tag below R label (small, dim)
  for (let r = 0; r < 8; r++) {
    const t = document.createElementNS(SVG_NS, 'text');
    t.setAttribute('x', CX + RADII[r] + 9);
    t.setAttribute('y', CY + 13);
    t.setAttribute('font-size', '6.5');
    t.setAttribute('fill', RING_COLORS[r]);
    t.setAttribute('opacity', '0.32');
    t.setAttribute('letter-spacing', '0.5');
    t.textContent = RING_COUNTS[r].toString();
    tagsG.appendChild(t);
  }

  // Edges — quadratic Bézier, control point swirled CCW from midpoint
  function makeEdge(parent, child, ring) {
    const mx = (parent.x + child.x) * 0.5;
    const my = (parent.y + child.y) * 0.5;
    const mAng = Math.atan2(my - CY, mx - CX);
    const mRad = Math.hypot(mx - CX, my - CY);
    // Swirl factor — slightly larger near outer rings; bend matches CCW rotation
    const swirl = 0.10 + 0.012 * ring;
    const cAng = mAng + swirl; // trailing curl, visually CCW
    const cRad = mRad * 1.04;
    const ccx = CX + Math.cos(cAng) * cRad;
    const ccy = CY + Math.sin(cAng) * cRad;

    const p = document.createElementNS(SVG_NS, 'path');
    p.setAttribute(
      'd',
      'M ' + parent.x.toFixed(2) + ' ' + parent.y.toFixed(2)
      + ' Q ' + ccx.toFixed(2) + ' ' + ccy.toFixed(2)
      + ' ' + child.x.toFixed(2) + ' ' + child.y.toFixed(2)
    );
    p.setAttribute('fill', 'none');
    p.setAttribute('stroke', RING_COLORS[ring]);
    p.setAttribute('stroke-width', ring <= 3 ? '0.7' : '0.55');
    p.setAttribute('stroke-linecap', 'round');
    p.setAttribute('class', 'edge edge-r' + ring);
    return p;
  }

  // Connect root (center) to every ring-0 node — sparse spokes
  for (const n of ringNodes[0]) {
    const e = makeEdge({ x: CX, y: CY }, n, 0);
    e.setAttribute('stroke-opacity', '0.18');
    edgesG.appendChild(e);
  }
  for (let r = 1; r < 8; r++) {
    for (const n of ringNodes[r]) {
      edgesG.appendChild(makeEdge(n.parent, n, r));
    }
  }

  // Nodes: dot size ∝ freq
  function dotR(freq, ring) {
    const fMax = freqAt(ring, 1);
    const norm = Math.min(1, freq / fMax);
    const minR = ring === 0 ? 1.8 : 1.2;
    const maxR = ring === 0 ? 4.2 : (ring <= 2 ? 3.3 : (ring <= 4 ? 2.7 : 2.2));
    return minR + Math.pow(norm, 0.55) * (maxR - minR);
  }

  for (let r = 0; r < 8; r++) {
    for (const n of ringNodes[r]) {
      const g = document.createElementNS(SVG_NS, 'g');
      g.setAttribute('class', 'node node-r' + r);
      g.dataset.token = n.token;
      g.dataset.ring = r;
      g.dataset.rank = n.rank;
      g.dataset.freq = n.freq;
      g.dataset.terminal = n.terminal ? '1' : '0';
      g.dataset.color = RING_COLORS[r];

      const baseR = dotR(n.freq, r);
      n.r = baseR;

      // Halo for top-ranked nodes
      if (n.rank <= 3) {
        const halo = document.createElementNS(SVG_NS, 'circle');
        halo.setAttribute('cx', n.x.toFixed(2));
        halo.setAttribute('cy', n.y.toFixed(2));
        halo.setAttribute('r', (baseR * 2.6).toFixed(2));
        halo.setAttribute('fill', RING_COLORS[r]);
        halo.setAttribute('fill-opacity', r === 0 ? '0.18' : '0.13');
        halo.setAttribute('filter', 'url(#softGlow)');
        halo.setAttribute('class', 'halo');
        g.appendChild(halo);
      }
      const dot = document.createElementNS(SVG_NS, 'circle');
      dot.setAttribute('cx', n.x.toFixed(2));
      dot.setAttribute('cy', n.y.toFixed(2));
      dot.setAttribute('r', baseR.toFixed(2));
      dot.setAttribute('fill', RING_COLORS[r]);
      dot.setAttribute('fill-opacity', r === 7 ? '0.55' : (r === 6 ? '0.78' : (r === 0 ? '0.85' : '0.95')));
      dot.setAttribute('class', 'dot');
      g.appendChild(dot);

      nodesG.appendChild(g);
    }
  }

  // Rank labels (top-N per ring, position-outward)
  for (let r = 0; r < 8; r++) {
    const arr = ringNodes[r];
    for (let i = 0; i < Math.min(26, arr.length); i++) {
      const n = arr[i];
      const t = document.createElementNS(SVG_NS, 'text');
      const offset = (n.r || 2) + 4.5;
      const lx = CX + Math.cos(n.angle) * (RADII[r] + offset);
      const ly = CY + Math.sin(n.angle) * (RADII[r] + offset);
      t.setAttribute('x', lx.toFixed(2));
      t.setAttribute('y', (ly + 2).toFixed(2));
      t.setAttribute('text-anchor', 'middle');
      t.setAttribute('class', 'rank-label rank-r' + r);
      t.setAttribute('data-rank', n.rank);
      t.setAttribute('fill', RING_COLORS[r]);
      t.setAttribute('fill-opacity', '0.85');
      t.textContent = n.rank;
      labelsG.appendChild(t);
    }
  }

  // ── Tooltip ───────────────────────────────────────────────────────────
  const tip = document.getElementById('tip');
  const tipSeq = document.getElementById('tipSeq');
  const tipMeta = document.getElementById('tipMeta');
  const viz = document.getElementById('viz');
  const vizWrap = document.getElementById('vizWrap');

  function tokenDisplay(t) {
    if (t === ' ') return '␣';
    if (t === '\n') return '↵';
    if (t === '\t') return '⇥';
    return t;
  }

  function showTip(g) {
    const ring = +g.dataset.ring;
    const token = g.dataset.token;
    const color = g.dataset.color;
    const freq = +g.dataset.freq;
    const rank = +g.dataset.rank;
    const terminal = g.dataset.terminal === '1';

    tip.style.color = color;
    tipSeq.textContent = '"' + tokenDisplay(token) + '"';
    tipSeq.style.color = color;
    tipMeta.innerHTML =
      '<span>ring <b>' + ring + '</b></span>'
      + '<span>rank <b>#' + rank + '</b></span>'
      + '<span>freq <b>' + freq.toLocaleString() + '</b></span>'
      + '<span class="term ' + (terminal ? '' : 'no') + '">'
      + (terminal ? 'TERMINAL' : 'PARTIAL') + '</span>';

    // Resolve current visual position (accounting for any rotor transform)
    const dot = g.querySelector('.dot');
    const pt = viz.createSVGPoint();
    pt.x = +dot.getAttribute('cx');
    pt.y = +dot.getAttribute('cy');
    const ctm = dot.getScreenCTM();
    const sp = pt.matrixTransform(ctm);
    const rect = vizWrap.getBoundingClientRect();
    tip.style.left = (sp.x - rect.left) + 'px';
    tip.style.top = (sp.y - rect.top) + 'px';
    tip.classList.add('on');
  }
  function hideTip() { tip.classList.remove('on'); }

  nodesG.addEventListener('mouseover', (e) => {
    const g = e.target.closest('.node');
    if (g) showTip(g);
  });
  nodesG.addEventListener('mouseout', (e) => {
    const to = e.relatedTarget;
    if (to && to.closest && to.closest('.node')) return;
    hideTip();
  });

  // ── Status bar ────────────────────────────────────────────────────────
  const statLeft = document.getElementById('statLeft');
  let peak = 0;
  for (let i = 0; i < RING_COUNTS.length; i++) {
    if (RING_COUNTS[i] > RING_COUNTS[peak]) peak = i;
  }
  const total = RING_COUNTS.reduce((a, b) => a + b, 0);
  const parts = [];
  for (let r = 0; r < 8; r++) {
    parts.push(
      '<span class="pill">r' + r + ': <span class="num">' + RING_COUNTS[r] + '</span></span>'
    );
  }
  parts.push('<span class="peak">peak <b>R' + peak + '</b></span>');
  parts.push('<span class="pill">Σ <span class="num">' + total.toLocaleString() + '</span> nodes</span>');
  statLeft.innerHTML = parts.join('<span class="sep"> · </span>');

  // ── Expose for tweaks.js ──────────────────────────────────────────────
  window.RTViz = {
    edgesG, nodesG, labelsG,
    ringNodes, RING_COLORS, RADII,
    setEdgeOpacity(v01) {
      const o0 = Math.max(0, Math.min(1, v01));
      const paths = edgesG.querySelectorAll('path');
      paths.forEach(p => {
        // Per-ring slight variance
        const cls = p.getAttribute('class') || '';
        const m = cls.match(/edge-r(\d)/);
        const r = m ? +m[1] : 0;
        const factor = (r === 0) ? 0.7 : (r <= 3 ? 1.0 : (r <= 5 ? 0.85 : 0.7));
        p.setAttribute('stroke-opacity', (o0 * factor).toFixed(3));
      });
    },
    setLabelTop(n) {
      const labels = labelsG.querySelectorAll('text');
      labels.forEach(t => {
        const rk = +t.getAttribute('data-rank');
        t.style.display = (rk <= n) ? '' : 'none';
      });
    },
    setRotation(seconds) {
      const rotor = document.getElementById('rotor');
      if (!seconds || seconds <= 0) {
        rotor.classList.remove('spinning');
        rotor.style.removeProperty('--spin-time');
      } else {
        rotor.style.setProperty('--spin-time', seconds + 's');
        rotor.classList.add('spinning');
      }
    },
    setHaze(v01) {
      const hr = document.getElementById('hazeRect');
      hr.setAttribute('opacity', Math.max(0, Math.min(1.5, v01)).toFixed(3));
    },
    setDotScale(scale) {
      const k = Math.max(0.5, Math.min(2.0, scale));
      const dots = nodesG.querySelectorAll('.dot');
      const halos = nodesG.querySelectorAll('.halo');
      // We need original radii; store on the element if not done
      dots.forEach(d => {
        if (!d.dataset.r0) d.dataset.r0 = d.getAttribute('r');
        d.setAttribute('r', (+d.dataset.r0 * k).toFixed(2));
      });
      halos.forEach(h => {
        if (!h.dataset.r0) h.dataset.r0 = h.getAttribute('r');
        h.setAttribute('r', (+h.dataset.r0 * k).toFixed(2));
      });
    },
    setZoom(scale) {
      const vw = document.getElementById('vizWrap');
      const svg = document.getElementById('viz');
      svg.style.transform = 'scale(' + scale + ')';
      svg.style.transformOrigin = '50% 47.7%';
      document.getElementById('zoomLabel').textContent =
        Math.round(scale * 100) + '%';
    }
  };
})();
