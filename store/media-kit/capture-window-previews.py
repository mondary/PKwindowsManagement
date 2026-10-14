"""Render production picker views with fixtures; never enumerate/capture user windows."""
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
MODEL = ROOT / "src/macos/Services/WindowSwitcher/WindowSwitcherModel.swift"
FRAMEWORKS = ROOT / "build/PKwindowsManagement.app/Contents/Frameworks"
RESOURCE = ROOT / ".build/debug/PKwindowsManagement_PKwindowsManagement.bundle"
OUTPUT = ROOT / "build/window-preview-qa"

with tempfile.TemporaryDirectory(prefix="pk-window-preview-qa-") as directory:
    temporary = Path(directory)
    (temporary / RESOURCE.name).symlink_to(RESOURCE.resolve())
    # Only setter access is widened in this disposable copy for fixture injection.
    # All view/layout code and model logic remain the production implementations.
    fixture_model = temporary / MODEL.name
    fixture_model.write_text(MODEL.read_text().replace("private(set) ", ""))
    sources = sorted(str(path) for path in (ROOT / "src/macos").rglob("*.swift")
                     if path.name != "PKwindowsManagementApp.swift" and path != MODEL)
    executable = temporary / "Capture"
    subprocess.run([
        "swiftc", "-swift-version", "5", "-target", "arm64-apple-macos13.0",
        "-sdk", "/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk",
        "-whole-module-optimization", "-Onone", "-F", str(FRAMEWORKS),
        "-framework", "Sparkle", "-Xlinker", "-rpath", "-Xlinker", str(FRAMEWORKS),
        *sources, str(fixture_model), str(Path(__file__).with_suffix(".swift")), "-o", str(executable),
    ], check=True)
    subprocess.run([str(executable), str(OUTPUT)], check=True)
    print(OUTPUT)
