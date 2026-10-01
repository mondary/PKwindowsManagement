/* No frameworks, network calls or OS shortcuts. The playground is a web simulation. */
const root = document.documentElement;
const languageButton = document.querySelector('#language');
const desktop = document.querySelector('#play-desktop');
const layoutButtons = [...document.querySelectorAll('[data-layout]')].filter(node => node.tagName === 'BUTTON');
const layouts = ['split', 'thirds', 'grid', 'focus', 'free'];
const descriptions = {
  fr: {free: 'À vous de jouer. Essayez les moitiés.', split: 'Deux moitiés. Une idée de chaque côté.', thirds: 'Trois colonnes. Tout à portée de regard.', grid: 'Une grille. Chaque fenêtre trouve sa place.', focus: 'Une seule fenêtre. Toute votre attention.'},
  en: {free: 'Your turn. Try the halves.', split: 'Two halves. An idea on each side.', thirds: 'Three columns. Everything in sight.', grid: 'One grid. A place for every window.', focus: 'One window. All your attention.'}
};
const reducedMotion = matchMedia('(prefers-reduced-motion: reduce)');
let timer = null;
let currentTheme = 'pastel';

function updateYearAlt() {
  const name = {pastel:'Pastel',poster:root.lang === 'fr' ? 'Poster bleu' : 'Blue poster',catppuccinMocha:'Catppuccin Mocha'}[currentTheme];
  document.querySelector('#year-preview').alt = root.lang === 'fr' ? `Calendrier Big Year, thème ${name}, année 2026` : `Big Year calendar, ${name} theme, 2026 (native French interface)`;
}

function setLanguage(language) {
  root.lang = language;
  languageButton.textContent = language === 'fr' ? 'EN' : 'FR';
  languageButton.setAttribute('aria-label', language === 'fr' ? 'Switch to English' : 'Passer en français');
  document.title = language === 'fr' ? 'PKwindowsManagement — Votre Mac. À votre rythme.' : 'PKwindowsManagement — Your Mac. Your flow.';
  document.querySelector('meta[name=description]').content = language === 'fr' ? 'Organisez vos fenêtres, lancez vos apps et gardez votre année en vue. Découvrez PKwindowsManagement pour macOS et essayez le playground interactif.' : 'Organize your windows, launch your apps and see your whole year. Discover PKwindowsManagement for macOS and try the interactive playground.';
  document.querySelector('meta[property="og:title"]').content = document.title;
  document.querySelector('meta[property="og:description"]').content = document.querySelector('meta[name=description]').content;
  document.querySelectorAll('[aria-labelledby]').forEach(section => {
    const heading = document.getElementById(section.getAttribute('aria-labelledby'));
    heading.setAttribute('aria-label', heading.innerText);
  });
  document.querySelectorAll('[data-localized]').forEach(image => image.src = `screenshots/${image.dataset.localized}-${language}.webp`);
  document.querySelectorAll('[data-localized-link]').forEach(link => link.href = `screenshots/${link.dataset.localizedLink}-${language}.png`);
  document.querySelectorAll('[data-alt-en]').forEach(image => { image.dataset.altFr ||= image.alt; image.alt = language === 'fr' ? image.dataset.altFr : image.dataset.altEn; });
  desktop.setAttribute('aria-label', language === 'fr' ? 'Bureau de démonstration : flèches gauche et droite pour changer de disposition' : 'Demo desktop: use left and right arrows to change layouts');
  document.querySelector('.hero-shortcut kbd:nth-child(2)').textContent = language === 'fr' ? 'espace' : 'space';
  updateYearAlt();
  setLayout(desktop.dataset.layout);
  updatePlayButton();
}

function setLayout(layout) {
  if (!layouts.includes(layout)) return;
  desktop.dataset.layout = layout;
  layoutButtons.forEach(button => button.setAttribute('aria-pressed', String(button.dataset.layout === layout)));
  document.querySelector('#layout-status').textContent = descriptions[root.lang][layout];
}

function updatePlayButton() {
  document.querySelector('#auto-play').textContent = timer ? (root.lang === 'fr' ? 'Ⅱ Pause' : 'Ⅱ Pause') : (root.lang === 'fr' ? '▶ Voir la démo' : '▶ Play the demo');
  document.querySelector('#auto-play').setAttribute('aria-pressed', String(Boolean(timer)));
}
function stopDemo() { clearInterval(timer); timer = null; updatePlayButton(); }
languageButton.addEventListener('click', () => {
  const language = root.lang === 'fr' ? 'en' : 'fr';
  setLanguage(language);
  try { localStorage.setItem('pk-store2-lang', language); } catch { /* Session choice remains active. */ }
});
layoutButtons.forEach(button => button.addEventListener('click', () => { stopDemo(); setLayout(button.dataset.layout); }));
desktop.addEventListener('keydown', event => {
  if (!['ArrowLeft', 'ArrowRight', 'Home', 'End'].includes(event.key)) return;
  event.preventDefault(); stopDemo();
  const index = layouts.indexOf(desktop.dataset.layout);
  setLayout(event.key === 'Home' ? layouts[0] : event.key === 'End' ? layouts.at(-1) : layouts[(index + (event.key === 'ArrowRight' ? 1 : -1) + layouts.length) % layouts.length]);
});
document.querySelector('#gap').addEventListener('input', event => {
  const gap = Number(event.target.value);
  desktop.style.setProperty('--gap', `${gap}%`);
  document.querySelector('#gap-value').textContent = `${gap}%`;
});
document.querySelector('#auto-play').addEventListener('click', () => {
  if (timer) return stopDemo();
  let index = 0;
  setLayout(layouts[index++]);
  timer = setInterval(() => setLayout(layouts[index++ % layouts.length]), reducedMotion.matches ? 3000 : 2000);
  updatePlayButton();
});
document.addEventListener('visibilitychange', () => { if (document.hidden) stopDemo(); });
new IntersectionObserver(entries => { if (!entries[0].isIntersecting) stopDemo(); }, {threshold:0.1}).observe(desktop);
reducedMotion.addEventListener('change', stopDemo);

// Install commands: copy to clipboard with a transient bilingual confirmation.
document.querySelectorAll('[data-copy]').forEach(button => button.addEventListener('click', async () => {
  const label = button.querySelector('.copy-label');
  try { await navigator.clipboard.writeText(button.dataset.copy); } catch { /* The command stays visible for manual copy. */ }
  const initial = label.innerHTML;
  label.textContent = root.lang === 'fr' ? 'Copié ✓' : 'Copied ✓';
  button.classList.add('copied');
  setTimeout(() => { label.innerHTML = initial; button.classList.remove('copied'); }, 1600);
}));
document.querySelectorAll('[data-theme]').forEach(button => button.addEventListener('click', () => {
  currentTheme = button.dataset.theme;
  document.querySelectorAll('[data-theme]').forEach(item => item.setAttribute('aria-pressed', String(item === button)));
  document.querySelector('#year-preview').src = `screenshots/year-${currentTheme}.webp`;
  document.querySelector('#year-full').href = `screenshots/year-${currentTheme}.png`;
  updateYearAlt();
}));
setLanguage(root.lang);

// Deterministic export hook: interpolates the actual playground's browser geometry.
// Never touches the application or any system window.
window.renderMediaFrame = async function(time) {
  document.body.classList.add('capture-mode');
  const sequence = ['free','split','thirds','grid','focus','free'];
  const phase = Math.min(4, Math.floor(time / 1.6));
  const progress = Math.min(1, (time % 1.6) / 0.7);
  const ease = 1 - Math.pow(1 - progress, 4);
  const windows = [...desktop.querySelectorAll('.demo-window')];
  windows.forEach(node => { node.style.cssText = 'transition:none'; });
  const measure = layout => {
    desktop.dataset.layout = layout;
    return windows.map(node => {
      const style = getComputedStyle(node);
      return ['left','top','width','height','opacity'].map(key => parseFloat(style[key]));
    });
  };
  const start = measure(sequence[phase]);
  const end = measure(sequence[phase + 1]);
  setLayout(sequence[phase + 1]);
  windows.forEach((node, i) => {
    ['left','top','width','height','opacity'].forEach((key,j) => node.style[key] = (start[i][j] + (end[i][j] - start[i][j]) * ease) + (key === 'opacity' ? '' : 'px'));
    node.style.transform = 'none';
  });
  const cursor = document.querySelector('#demo-cursor');
  cursor.style.left = `${20 + phase * 12 + ease * 6}%`;
  cursor.style.top = `${62 - phase * 7}%`;
  cursor.style.scale = progress < .18 ? '.8' : '1';
};
