export const FPS = 30;
export const TOTAL = 900;
export const SHOTS = [
  {id: 'intro', from: 0, duration: 120, title: 'Votre Mac.\nBien organisé.', subtitle: 'Fenêtres, apps et calendrier.', kind: 'brand'},
  {id: 'windows', from: 120, duration: 150, title: 'Vos fenêtres.\nÀ leur place.', subtitle: 'Moitiés, tiers, quarts : au clavier.', src: 'shortcuts.png', pageW: 2560, pageH: 2130, a: [1024, 537.6, 0.671875], b: [1024, 921.6, 0.671875]},
  {id: 'launchpad', from: 270, duration: 150, title: 'Vos apps.\nEn un regard.', subtitle: 'Un Launchpad plein écran.', src: 'launchpad.png', pageW: 1600, pageH: 1000, a: [800, 500, 0.66], b: [800, 500, 0.70]},
  {id: 'global', from: 420, duration: 120, title: 'Un raccourci.\nPartout sur Mac.', subtitle: 'Raccourcis globaux par application.', src: 'launchpad.png', pageW: 1600, pageH: 1000, a: [1170, 420, 1], b: [1170, 440, 1.04]},
  {id: 'year', from: 540, duration: 150, title: 'Votre année.\nVue d’ensemble.', subtitle: 'Big Year : événements et vacances.', src: 'big-year.png', pageW: 1600, pageH: 1000, a: [800, 500, 0.86], b: [800, 500, 0.70]},
  {id: 'appearance', from: 690, duration: 120, title: 'Votre écran.\nVos réglages.', subtitle: 'Grille, taille des icônes et tri.', src: 'appearance.png', pageW: 2560, pageH: 2130, a: [1177.6, 627.2, 0.5859375], b: [1177.6, 678.4, 0.5859375]},
  {id: 'outro', from: 810, duration: 90, title: 'Reprenez la main\nsur votre Mac.', subtitle: 'Gratuit et open source.', kind: 'brand'},
];
