"""Reproducible media preparation; never reads the archive store/archive directory."""
from pathlib import Path
import hashlib
import json
import plistlib
import shutil
import subprocess
import tempfile
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
STORE = ROOT / 'store'
WEB = STORE / 'website'
SRC = STORE / 'sources'
KIT = STORE / 'media-kit'
HUB = Path.home() / 'Documents/GitHub/-agent/skills/pk/premium-promo-media'

# Native PNGs kept on the website (fullscreen links and Big Year theme picker); the
# other captures stay in sources/ as retina originals for the lightweight WebP builds.
DEPLOYED_PNGS = ['windows-fr.png', 'windows-en.png', 'year-pastel.png', 'year-poster.png', 'year-catppuccinMocha.png']

def main():
    for directory in [WEB / 'assets', WEB / 'screenshots', WEB / 'gifs', WEB / 'videos', SRC / 'assets', SRC / 'screenshots', SRC / 'downloads']:
        directory.mkdir(parents=True, exist_ok=True)
    catalog = json.loads((HUB / 'assets/wallpapers/catalog.json').read_text())
    entries = catalog if isinstance(catalog, list) else catalog['images']
    entry = next(x for x in entries if x['id'] == '2a566450c6f9')
    source = HUB / 'assets/wallpapers' / entry['original']
    assert hashlib.sha256(source.read_bytes()).hexdigest() == entry['sha256'], 'Wallpaper source changed'
    Image.open(source).convert('RGB').save(WEB / 'assets/wallpaper.webp', quality=88)
    Image.open(ROOT / 'icon.png').convert('RGBA').resize((160,160), Image.Resampling.LANCZOS).save(WEB / 'assets/icon.png')
    (SRC / 'assets/provenance.json').write_text(json.dumps({'wallpaper': entry, 'crop': 'center, cover', 'source': 'PK premium-promo-media / appWall collection; decorative landscape, not product UI', 'native': 'Production SwiftUI views, temporary catalog fixture, isolated UserDefaults, no personal data'}, indent=2, ensure_ascii=False))
    with tempfile.TemporaryDirectory(prefix='store-native-', dir='/var/folders/jb/07k9zyks6_d60c27tclhjd2h0000gn/T/opencode') as temporary:
        temp = Path(temporary)
        sources = []
        for path in (ROOT / 'src/macos').rglob('*.swift'):
            if path.name == 'PKwindowsManagementApp.swift':
                continue
            text = path.read_text()
            if path.name == 'CompactLaunchpadView.swift':
                text = text.replace('launcher.launcherCommands() + launcher.loadSnippets(settings: settings) + appCatalog', 'appCatalog')
                text = text.replace('launcher.loadAppsAsync(settings: settings) { apps in\n                appCatalog = apps\n                selectedIndex = 0\n            }', 'appCatalog = CaptureFixtures.apps\n            selectedIndex = 0')
            if path.name == 'BigYearView.swift':
                text = text.replace('vacations = await BigYearData.schoolVacations(in: displayedYear)', 'vacations = [:] // Offline fixture; no school vacation fetch.')
            destination = temp / path.name
            destination.write_text(text)
            sources.append(str(destination))
        resource = ROOT / 'build/PKwindowsManagement.app/Contents/Resources/PKwindowsManagement_PKwindowsManagement.bundle'
        (temp / resource.name).symlink_to(resource)
        sdk = '/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk'
        subprocess.run(['swiftc', '-swift-version', '5', '-target', 'arm64-apple-macos13.0', '-sdk', sdk, '-whole-module-optimization', '-Onone', *sources, str(KIT / 'capture-native.swift'), '-o', str(temp / 'Capture')], check=True)
        subprocess.run([str(temp / 'Capture'), str(SRC / 'screenshots')], check=True)
    for source in (SRC / 'screenshots').glob('*.png'):
        image = Image.open(source).convert('RGB')
        image.thumbnail((1440, 1000), Image.Resampling.LANCZOS)
        image.save(WEB / 'screenshots' / source.name.replace('.png', '.webp'), quality=88)
    for name in DEPLOYED_PNGS:
        shutil.copy2(SRC / 'screenshots' / name, WEB / 'screenshots' / name)
    archive = SRC / 'downloads/PKwindowsManagement-2026.09.08-arm64.zip'
    info = plistlib.loads((ROOT / 'build/PKwindowsManagement.app/Contents/Info.plist').read_bytes())
    assert info['CFBundleShortVersionString'] == '2026.09.08', 'Update the archive filename and website before packaging a new app version'
    assert subprocess.check_output(['lipo', '-archs', str(ROOT / 'build/PKwindowsManagement.app/Contents/MacOS/PKwindowsManagement')], text=True).strip() == 'arm64'
    subprocess.run(['ditto', '-c', '-k', '--sequesterRsrc', '--keepParent', str(ROOT / 'build/PKwindowsManagement.app'), str(archive)], check=True)
    (SRC / 'downloads/SHA256SUMS.txt').write_text(hashlib.sha256(archive.read_bytes()).hexdigest() + '  ' + archive.name + '\n')

if __name__ == '__main__':
    main()
