"""Reproducible media preparation; never reads the original store directory."""
from pathlib import Path
import hashlib
import json
import plistlib
import subprocess
import tempfile
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'Store2'
HUB = Path.home() / 'Documents/GitHub/-agent/skills/pk/premium-promo-media'

def main():
    for directory in ['assets', 'screenshots', 'downloads', 'videos', 'gifs']:
        (OUT / directory).mkdir(exist_ok=True)
    catalog = json.loads((HUB / 'assets/wallpapers/catalog.json').read_text())
    entries = catalog if isinstance(catalog, list) else catalog['images']
    entry = next(x for x in entries if x['id'] == '2a566450c6f9')
    source = HUB / 'assets/wallpapers' / entry['original']
    assert hashlib.sha256(source.read_bytes()).hexdigest() == entry['sha256'], 'Wallpaper source changed'
    Image.open(source).convert('RGB').save(OUT / 'assets/wallpaper.webp', quality=88)
    Image.open(ROOT / 'icon.png').convert('RGBA').resize((160,160), Image.Resampling.LANCZOS).save(OUT / 'assets/icon.png')
    (OUT / 'assets/provenance.json').write_text(json.dumps({'wallpaper': entry, 'crop': 'center, cover', 'source': 'PK premium-promo-media / appWall collection; decorative landscape, not product UI', 'native': 'Production SwiftUI views, temporary catalog fixture, isolated UserDefaults, no personal data'}, indent=2, ensure_ascii=False))
    with tempfile.TemporaryDirectory(prefix='store2-native-', dir='/var/folders/jb/07k9zyks6_d60c27tclhjd2h0000gn/T/opencode') as temporary:
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
        resource = ROOT / 'release/PKwindowsManagement.app/Contents/Resources/PKwindowsManagement_PKwindowsManagement.bundle'
        (temp / resource.name).symlink_to(resource)
        sdk = '/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk'
        subprocess.run(['swiftc', '-swift-version', '5', '-target', 'arm64-apple-macos13.0', '-sdk', sdk, '-whole-module-optimization', '-Onone', *sources, str(OUT / 'media-kit/capture-native.swift'), '-o', str(temp / 'Capture')], check=True)
        subprocess.run([str(temp / 'Capture'), str(OUT / 'screenshots')], check=True)
    for source in (OUT / 'screenshots').glob('*.png'):
        image = Image.open(source).convert('RGB')
        image.thumbnail((1440, 1000), Image.Resampling.LANCZOS)
        image.save(source.with_suffix('.webp'), quality=88)
    archive = OUT / 'downloads/PKwindowsManagement-2026.09.08-arm64.zip'
    info = plistlib.loads((ROOT / 'release/PKwindowsManagement.app/Contents/Info.plist').read_bytes())
    assert info['CFBundleShortVersionString'] == '2026.09.08', 'Update the archive filename and website before packaging a new app version'
    assert subprocess.check_output(['lipo', '-archs', str(ROOT / 'release/PKwindowsManagement.app/Contents/MacOS/PKwindowsManagement')], text=True).strip() == 'arm64'
    subprocess.run(['ditto', '-c', '-k', '--sequesterRsrc', '--keepParent', str(ROOT / 'release/PKwindowsManagement.app'), str(archive)], check=True)
    (OUT / 'downloads/SHA256SUMS.txt').write_text(hashlib.sha256(archive.read_bytes()).hexdigest() + '  ' + archive.name + '\n')

if __name__ == '__main__':
    main()
