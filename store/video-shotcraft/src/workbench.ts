import {Scene, Frame, Promo, COLORS} from './Promo';
import {SHOTS, FPS, TOTAL} from './timeline.mjs';
export const WORKBENCH = {
  name: 'PKwindowsManagement - captures animees FR', fps: FPS, width: 1920, height: 1080,
  total: TOTAL, background: COLORS.ice,
  shots: SHOTS.map(shot => ({id: shot.id, label: shot.title.replace('\n', ' '), from: shot.from, duration: shot.duration, component: Scene, props: {shot}})),
  overlays: [{id: 'frame', label: 'Cadre et mention captures', from: 0, duration: TOTAL, component: Frame}],
  captions: [], transitions: [], sfx: [], bgm: [], original: Promo,
};
