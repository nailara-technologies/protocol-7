// Tweaks panel — vanilla, follows host edit-mode protocol
(function () {
  'use strict';

  const T = window.TWEAKS || {};
  const V = window.RTViz;

  // ── Apply tweak by key ────────────────────────────────────────────────
  function apply(key, val) {
    T[key] = val;
    switch (key) {
      case 'edgeOpacity':
        V.setEdgeOpacity(val / 100);
        document.getElementById('tw_edge_v').textContent = val + '%';
        document.getElementById('tw_edge').value = val;
        break;
      case 'labelTop':
        V.setLabelTop(val);
        markSeg('tw_labels', val);
        break;
      case 'rotation':
        V.setRotation(val);
        markSeg('tw_rot', val);
        break;
      case 'haze':
        V.setHaze(val / 100);
        document.getElementById('tw_haze_v').textContent = val + '%';
        document.getElementById('tw_haze').value = val;
        break;
      case 'dotScale':
        V.setDotScale(val / 100);
        document.getElementById('tw_dot_v').textContent = val + '%';
        document.getElementById('tw_dot').value = val;
        break;
      case 'zoom':
        V.setZoom(val / 100);
        document.getElementById('tw_zoom_v').textContent = val + '%';
        document.getElementById('tw_zoom').value = val;
        break;
    }
  }
  function markSeg(id, v) {
    const seg = document.getElementById(id);
    if (!seg) return;
    seg.querySelectorAll('button').forEach(b => {
      b.classList.toggle('on', +b.dataset.v === +v);
    });
  }

  function persist(edits) {
    try {
      window.parent.postMessage({ type: '__edit_mode_set_keys', edits }, '*');
    } catch (e) { /* not embedded */ }
  }
  function change(key, val) {
    apply(key, val);
    persist({ [key]: val });
  }

  // ── Wire controls ─────────────────────────────────────────────────────
  function wireRange(id, key) {
    const el = document.getElementById(id);
    el.addEventListener('input', () => change(key, +el.value));
  }
  function wireSeg(id, key) {
    const seg = document.getElementById(id);
    seg.querySelectorAll('button').forEach(b => {
      b.addEventListener('click', () => change(key, +b.dataset.v));
    });
  }
  wireRange('tw_edge', 'edgeOpacity');
  wireRange('tw_haze', 'haze');
  wireRange('tw_dot',  'dotScale');
  wireRange('tw_zoom', 'zoom');
  wireSeg('tw_labels', 'labelTop');
  wireSeg('tw_rot',    'rotation');

  // ── Initial apply ─────────────────────────────────────────────────────
  apply('edgeOpacity', T.edgeOpacity);
  apply('labelTop',    T.labelTop);
  apply('rotation',    T.rotation);
  apply('haze',        T.haze);
  apply('dotScale',    T.dotScale);
  apply('zoom',        T.zoom);

  // ── Edit-mode host protocol ───────────────────────────────────────────
  const panel = document.getElementById('tweaks');
  const close = document.getElementById('tweaksClose');

  window.addEventListener('message', (e) => {
    const d = e.data || {};
    if (d.type === '__activate_edit_mode') panel.classList.add('on');
    if (d.type === '__deactivate_edit_mode') panel.classList.remove('on');
  });
  close.addEventListener('click', () => {
    panel.classList.remove('on');
    try { window.parent.postMessage({ type: '__edit_mode_dismissed' }, '*'); } catch (e) {}
  });
  try { window.parent.postMessage({ type: '__edit_mode_available' }, '*'); } catch (e) {}
})();
