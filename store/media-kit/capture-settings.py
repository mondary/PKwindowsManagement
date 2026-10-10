"""Capture only settings from production views, without modifying user preferences."""
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
APP = ROOT / "build/PKwindowsManagement.app/Contents"
FRAMEWORKS = APP / "Frameworks"
RESOURCE = APP / "Resources/PKwindowsManagement_PKwindowsManagement.bundle"

with tempfile.TemporaryDirectory(prefix="pk-settings-capture-") as directory:
    temporary = Path(directory)
    (temporary / RESOURCE.name).symlink_to(RESOURCE)
    sources = sorted(str(path) for path in (ROOT / "src/macos").rglob("*.swift")
                     if path.name != "PKwindowsManagementApp.swift")
    executable = temporary / "Capture"
    subprocess.run([
        "swiftc", "-swift-version", "5", "-target", "arm64-apple-macos13.0",
        "-sdk", "/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk",
        "-whole-module-optimization", "-Onone", "-F", str(FRAMEWORKS),
        "-framework", "Sparkle", "-Xlinker", "-rpath", "-Xlinker", str(FRAMEWORKS),
        *sources, str(Path(__file__).with_suffix(".swift")), "-o", str(executable),
    ], check=True)
    subprocess.run([str(executable), str(ROOT / "store/sources/screenshots")], check=True)
