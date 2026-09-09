'use strict';

const snapStage = document.querySelector('#snap-stage');
const snapStatus = document.querySelector('#snap-status');
const snapShortcut = document.querySelector('#snap-shortcut');
const placements = {
  left: ['Moitié gauche : une fenêtre occupe la moitié gauche de l’écran.', 'Ctrl + Option + H'],
  right: ['Moitié droite : une fenêtre occupe la moitié droite de l’écran.', 'Ctrl + Option + L'],
  third: ['Tiers central : une fenêtre occupe le tiers central de l’écran.', 'Ctrl + Option + 2'],
  tile: ['Carrelage : quatre fenêtres de la même application sont réparties en grille 2 × 2.', 'Ctrl + Option + T'],
  max: ['Maximiser : une fenêtre utilise l’espace disponible, en conservant les marges.', 'Ctrl + Option + M']
};

document.querySelectorAll('[data-snap]').forEach((button) => {
  button.addEventListener('click', () => {
    const placement = button.dataset.snap;
    snapStage.dataset.layout = placement;
    document.querySelectorAll('[data-snap]').forEach((control) => {
      control.setAttribute('aria-pressed', String(control === button));
    });
    snapStatus.textContent = placements[placement][0];
    snapShortcut.textContent = placements[placement][1];
  });
});

// Keep unavailable captures honest without substituting an invented interface.
document.querySelectorAll('.media-slot img, .media-slot video').forEach((media) => {
  const showFallback = () => {
    media.hidden = true;
    const fallback = media.parentElement.querySelector('.media-fallback');
    if (fallback) fallback.hidden = false;
  };
  media.addEventListener('error', showFallback);
  if (media instanceof HTMLImageElement && media.hasAttribute('src') && media.complete && !media.naturalWidth) {
    showFallback();
  }
});

const gifButton = document.querySelector('#gif-toggle');
const gifImage = document.querySelector('#snap-gif img');
const gifIdle = document.querySelector('.gif-idle');
const gifFallback = document.querySelector('#snap-gif .media-fallback');
gifButton.hidden = false;

function stopGif() {
  gifImage.hidden = true;
  gifImage.removeAttribute('src');
  gifIdle.hidden = false;
  gifFallback.hidden = true;
  gifButton.setAttribute('aria-pressed', 'false');
  gifButton.textContent = 'Lire la démo animée ↗';
}

gifButton.addEventListener('click', () => {
  if (gifButton.getAttribute('aria-pressed') === 'true') {
    stopGif();
    return;
  }
  gifIdle.hidden = true;
  gifFallback.hidden = true;
  gifImage.hidden = false;
  gifImage.src = gifImage.dataset.src;
  gifButton.setAttribute('aria-pressed', 'true');
  gifButton.textContent = 'Arrêter la démo animée';
});

gifImage.addEventListener('error', () => {
  gifButton.setAttribute('aria-pressed', 'false');
  gifButton.textContent = 'Réessayer la démo animée';
  gifFallback.setAttribute('role', 'status');
});

// GIFs cannot pause natively: unloading stops playback, including off-screen.
const mediaObserver = new IntersectionObserver((entries) => {
  entries.forEach((entry) => {
    if (entry.isIntersecting) return;
    if (entry.target instanceof HTMLVideoElement) entry.target.pause();
    else if (gifButton.getAttribute('aria-pressed') === 'true') stopGif();
  });
});
mediaObserver.observe(document.querySelector('#snap-gif'));
mediaObserver.observe(document.querySelector('video'));
document.addEventListener('visibilitychange', () => {
  if (document.hidden) {
    document.querySelector('video').pause();
    if (gifButton.getAttribute('aria-pressed') === 'true') stopGif();
  }
});
