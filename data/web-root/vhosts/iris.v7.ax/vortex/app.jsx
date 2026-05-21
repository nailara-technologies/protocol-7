// app.jsx — orchestrates view (iris | dome) toggle + chrome + tweaks panel.

const { useState: useStateApp, useEffect: useEffectApp } = React;
const Iris = window.Iris;
const Dome = window.Dome;

const TWEAK_DEFAULTS = /*EDITMODE-BEGIN*/{
  "view": "dome",
  "ringCount": 26,
  "armCount": 5,
  "spin": "ccw",
  "palette": "galactic",
  "tightness": 2.6,
  "particleDensity": 28,
  "centerBrightness": 1,
  "voidRing": true,
  "showChrome": true,
  "tilt": 42,
  "camHeight": 0.55,
  "camDistance": 2.0,
  "spinSpeed": 0.18,
  "implosionBeam": true
}/*EDITMODE-END*/;

function Chrome({ tweaks }) {
  const isDome = tweaks.view === 'dome';
  return (
    <>
      <div className="chrome chrome-tl">
        <div className="chrome-glyph">{isDome ? '[v' : '[:<'}</div>
        <div className="chrome-line">iris.v7.ax</div>
        <div className="chrome-dim">
          {tweaks.ringCount} rings &middot; {tweaks.armCount} arms &middot; {tweaks.spin}
        </div>
      </div>
      <div className="chrome chrome-br">
        <div className="chrome-dim">{tweaks.palette}</div>
        <div className="chrome-line">[ TRUE ]</div>
      </div>
      <div className="chrome chrome-bl">
        <div className="chrome-dim">vortex.{isDome ? 'dome' : 'overhead'}</div>
        <div className="chrome-dim">
          {isDome ? 'inside · CCW · Ω ↓' : '26 / 5 / CCW'}
        </div>
      </div>
    </>
  );
}

function ViewToggle({ value, onChange }) {
  return (
    <div className="view-toggle" role="tablist" aria-label="vortex view">
      <button
        role="tab"
        aria-selected={value === 'overhead'}
        className={'vt-btn' + (value === 'overhead' ? ' active' : '')}
        onClick={() => onChange('overhead')}
      >
        <span className="vt-glyph">◎</span>
        <span className="vt-label">overhead</span>
      </button>
      <button
        role="tab"
        aria-selected={value === 'dome'}
        className={'vt-btn' + (value === 'dome' ? ' active' : '')}
        onClick={() => onChange('dome')}
      >
        <span className="vt-glyph">⌒</span>
        <span className="vt-label">dome</span>
      </button>
    </div>
  );
}

function App() {
  const [t, setTweak] = useTweaks(TWEAK_DEFAULTS);

  // Update the document title to reflect active view (subtle nicety)
  useEffectApp(() => {
    document.title = (t.view === 'dome' ? 'dome' : 'overhead') + ' · iris.v7.ax';
  }, [t.view]);

  return (
    <>
      {t.view === 'dome' ? <Dome tweaks={t} /> : <Iris tweaks={t} />}

      {t.showChrome && <Chrome tweaks={t} />}

      <ViewToggle value={t.view} onChange={(v) => setTweak('view', v)} />

      <TweaksPanel>
        <TweakSection label="View" />
        <TweakRadio label="Vantage" value={t.view}
                    options={['overhead', 'dome']}
                    onChange={(v) => setTweak('view', v)} />

        <TweakSection label="Structure" />
        <TweakSlider label="Rings" value={t.ringCount} min={12} max={40} step={1}
                     onChange={(v) => setTweak('ringCount', v)} />
        <TweakSlider label="Arms" value={t.armCount} min={2} max={7} step={1}
                     onChange={(v) => setTweak('armCount', v)} />
        <TweakSlider label="Arm tightness" value={t.tightness} min={1.4} max={4.2} step={0.1}
                     onChange={(v) => setTweak('tightness', v)} unit="rad" />
        <TweakRadio label="Spin" value={t.spin}
                    options={['ccw', 'cw']}
                    onChange={(v) => setTweak('spin', v)} />
        <TweakToggle label="Void ring (#7)" value={t.voidRing}
                     onChange={(v) => setTweak('voidRing', v)} />

        {t.view === 'dome' && (
          <>
            <TweakSection label="Camera (dome)" />
            <TweakSlider label="Tilt" value={t.tilt} min={10} max={75} step={1}
                         onChange={(v) => setTweak('tilt', v)} unit="°" />
            <TweakSlider label="Cam height" value={t.camHeight} min={0.05} max={1.6} step={0.05}
                         onChange={(v) => setTweak('camHeight', v)} />
            <TweakSlider label="Cam distance" value={t.camDistance} min={0.6} max={4.0} step={0.05}
                         onChange={(v) => setTweak('camDistance', v)} />
            <TweakSlider label="Spin speed" value={t.spinSpeed} min={0} max={0.6} step={0.02}
                         onChange={(v) => setTweak('spinSpeed', v)} unit="rad/s" />
            <TweakToggle label="Implosion beam" value={t.implosionBeam}
                         onChange={(v) => setTweak('implosionBeam', v)} />
          </>
        )}

        <TweakSection label="Light" />
        <TweakSlider label="Particles" value={t.particleDensity} min={0} max={60} step={2}
                     onChange={(v) => setTweak('particleDensity', v)} unit="/arm" />
        <TweakSlider label="Center brightness" value={t.centerBrightness} min={0.3} max={1.6} step={0.05}
                     onChange={(v) => setTweak('centerBrightness', v)} />
        <TweakSelect label="Palette" value={t.palette}
                     options={['galactic', 'inverted', 'mono-violet']}
                     onChange={(v) => setTweak('palette', v)} />

        <TweakSection label="Chrome" />
        <TweakToggle label="Show labels" value={t.showChrome}
                     onChange={(v) => setTweak('showChrome', v)} />
      </TweaksPanel>
    </>
  );
}

ReactDOM.createRoot(document.getElementById('root')).render(<App />);
