import React from 'react';
import {AbsoluteFill, Img, Sequence, Easing, interpolate, spring, staticFile, useCurrentFrame} from 'remotion';
import {SHOTS} from './timeline.mjs';

export const COLORS = {ice: '#edf7ff', navy: '#142347', blue: '#3078ed', muted: '#465c79'};
const clamp = {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'} as const;
const ease = Easing.bezier(0.33, 0, 0.15, 1);

// PageCam coordinate model from Shotcraft assets/lib/PageCam.tsx, adapted
// to a 1160 x 740 inset viewport and actual native screenshot dimensions.
export const PageCam = ({shot}: {shot: any}) => {
  const f = useCurrentFrame();
  const t = interpolate(f, [18, shot.duration - 36], [0, 1], {...clamp, easing: ease});
  const [cx, cy, zoom] = shot.a.map((n: number, i: number) => n + (shot.b[i] - n) * t);
  return <div style={{position: 'absolute', inset: 0, overflow: 'hidden', background: shot.src === 'launchpad.png' ? '#111b40' : '#fff'}}>
    <Img src={staticFile(shot.src)} style={{position: 'absolute', width: shot.pageW, height: shot.pageH, maxWidth: 'none', transformOrigin: '0 0', transform: `translate(${580 - cx * zoom}px, ${370 - cy * zoom}px) scale(${zoom})`}}/>
  </div>;
};

export const Scene = ({shot}: {shot: any}) => {
  const f = useCurrentFrame();
  const reveal = interpolate(f, [0, 24], [0, 1], {...clamp, easing: Easing.out(Easing.cubic)});
  const intro = shot.id === 'intro';
  const end = shot.id === 'outro';
  const drop = spring({frame: f - (intro ? 14 : 0), fps: 30, config: {damping: 16, stiffness: 110, mass: 1}});
  if (shot.kind === 'brand') return <AbsoluteFill>
    <div style={{position: 'absolute', left: 180, top: 184, width: 420, height: 420, opacity: Math.min(1, drop * 4), transform: `translateY(${intro ? 560 * (1 - drop) : 40 * (1 - reveal)}px) scale(${intro ? 0.82 + 0.18 * drop : 0.94 + 0.06 * reveal})`}}>
      <Img src={staticFile('icon.png')} style={{width: '100%', height: '100%'}}/>
    </div>
    <div style={{position: 'absolute', left: 720, top: 214, right: 110, opacity: reveal}}>
      <div style={{fontSize: 38, fontWeight: 650, color: COLORS.blue, marginBottom: 35}}>PKwindowsManagement</div>
      <h1 style={{fontSize: 96, lineHeight: 1.04, letterSpacing: -4, fontWeight: 720, margin: 0, whiteSpace: 'pre-line'}}>{shot.title}</h1>
      <div style={{fontSize: 40, marginTop: 36, color: COLORS.muted}}>{shot.subtitle}</div>
    </div>
    {end ? <div style={{position: 'absolute', left: 180, bottom: 185, fontSize: 40, fontWeight: 600, color: COLORS.blue}}>github.com/mondary/PKwindowsManagement</div> : <div style={{position: 'absolute', left: 180, bottom: 185, fontSize: 38, color: COLORS.muted}}>Une app native, dans la barre de menu.</div>}
  </AbsoluteFill>;
  return <AbsoluteFill>
    <div style={{position: 'absolute', left: 112, top: 162, width: 510, opacity: reveal, transform: `translateY(${24 * (1 - reveal)}px)`}}>
      <div style={{fontSize: 34, color: COLORS.blue, fontWeight: 650, marginBottom: 30}}>{String(SHOTS.indexOf(shot)).padStart(2, '0')} / 05</div>
      <h1 style={{fontSize: 78, lineHeight: 1.04, letterSpacing: -3, margin: 0, whiteSpace: 'pre-line'}}>{shot.title}</h1>
      <div style={{fontSize: 38, lineHeight: 1.3, color: COLORS.muted, marginTop: 32}}>{shot.subtitle}</div>
      {shot.id === 'global' && <div style={{fontSize: 36, marginTop: 40, color: COLORS.blue}}>Calendar · Notes</div>}
    </div>
    <div style={{position: 'absolute', left: 664, top: 156, width: 1160, height: 740, borderRadius: 24, overflow: 'hidden', boxShadow: '0 22px 50px #14234722', outline: '1px solid #14234718'}}><PageCam shot={shot}/></div>
  </AbsoluteFill>;
};

// Exact BrandFrameSnap demo timings: 18f grow, 14f delayed spring,
// 44px solid bands, one simultaneous chapter flip + damped thickness pulse.
export const Frame = () => {
  const f = useCurrentFrame();
  const grow = 1 - Math.pow(1 - Math.min(1, Math.max(0, f / 18)), 3);
  const since = f - SHOTS[1].from;
  const pulse = since >= 0 ? Math.exp(-since * 0.22) * Math.cos(since * 0.9) * 10 : 0;
  const w = 44 * grow + pulse;
  const color = since < 0 ? COLORS.blue : COLORS.navy;
  return <AbsoluteFill style={{pointerEvents: 'none'}}>
    {[{left: 0, top: 0, right: 0, height: w}, {left: 0, bottom: 0, right: 0, height: w}, {left: 0, top: 0, bottom: 0, width: w}, {right: 0, top: 0, bottom: 0, width: w}].map((pos, i) => <div key={i} style={{position: 'absolute', background: color, ...pos}}/>)}
    <div style={{position: 'absolute', top: 66, left: 112, fontSize: 32, color: COLORS.muted}}>PKwindowsManagement <span style={{marginLeft: 26, color: COLORS.blue}}>{since < 0 ? 'macOS' : 'Fenêtres · Apps · Calendrier'}</span></div>
    <div style={{position: 'absolute', left: 112, bottom: 76, color: COLORS.muted, fontSize: 32}}>Captures animées · Données de démonstration</div>
    {since >= 0 && since < 3 && <AbsoluteFill style={{background: '#fff', opacity: 0.55 - since * 0.18}}/>}
  </AbsoluteFill>;
};

export const Promo = () => <AbsoluteFill style={{background: COLORS.ice, color: COLORS.navy, fontFamily: '-apple-system, BlinkMacSystemFont, Helvetica, Arial, sans-serif'}}>
  {SHOTS.map(shot => <Sequence key={shot.id} from={shot.from} durationInFrames={shot.duration}><Scene shot={shot}/></Sequence>)}
  <Frame/>
</AbsoluteFill>;
