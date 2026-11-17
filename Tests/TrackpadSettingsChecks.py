#!/usr/bin/env python3
"""Exercise the real @Published observers without launching the app or its services."""
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
source = (ROOT / "src/macos/AppSettings.swift").read_text()


def property_source(name):
    start = source.index("@Published var " + name + ":")
    opening = source.index("{", start)
    depth = 1
    end = opening + 1
    while depth:
        depth += (source[end] == "{") - (source[end] == "}")
        end += 1
    return source[start:end]


properties = "\n".join(property_source(name) for name in (
    "exposeTrackpadGesture", "exposeTrackpadFingerCount"
))
initializers = "\n".join(
    line.strip() for line in source.splitlines()
    if line.startswith("        exposeTrackpad") and " = defaults." in line
)
assert len(initializers.splitlines()) == 2, "Keep the fixture on the real loading path"
fixture = """
import Foundation
import Combine

final class SettingsFixture: ObservableObject {
    enum Keys {
        static let exposeTrackpadGesture = "expose-trackpad-gesture"
        static let exposeTrackpadFingerCount = "expose-trackpad-finger-count"
    }
    let defaults: UserDefaults
    var backups = 0
    func scheduleAutoBackup() { backups += 1 }
    __PROPERTIES__
    init(defaults: UserDefaults) {
        self.defaults = defaults
        __INITIALIZERS__
    }
}

let suite = "TrackpadSettingsChecks." + UUID().uuidString
let defaults = UserDefaults(suiteName: suite)!
defer { defaults.removePersistentDomain(forName: suite) }
let settings = SettingsFixture(defaults: defaults)
precondition(settings.exposeTrackpadGesture)
precondition(settings.exposeTrackpadFingerCount == 4)

var publications = 0
let subscription = settings.$exposeTrackpadFingerCount.sink { _ in
    publications += 1
    // Abort cleanly before the old observer overflows the stack.
    if publications > 8 {
        print("FAIL: recursive @Published finger-count observer")
        exit(1)
    }
}
for _ in 0..<1000 {
    for value in [3, 4, 4, 3, 0, 5, -1] {
        publications = 0
        let previousBackups = settings.backups
        settings.exposeTrackpadFingerCount = value
        let expected = value == 3 ? 3 : 4
        precondition(settings.exposeTrackpadFingerCount == expected)
        precondition(defaults.integer(forKey: SettingsFixture.Keys.exposeTrackpadFingerCount) == expected)
        precondition(settings.backups == previousBackups + 1)
        precondition(publications <= 2)
    }
}
for value in [false, true, false] {
    settings.exposeTrackpadGesture = value
    precondition(defaults.bool(forKey: SettingsFixture.Keys.exposeTrackpadGesture) == value)
}
let reloaded = SettingsFixture(defaults: defaults)
precondition(reloaded.exposeTrackpadFingerCount == 4)
precondition(!reloaded.exposeTrackpadGesture)
defaults.set(3, forKey: SettingsFixture.Keys.exposeTrackpadFingerCount)
precondition(SettingsFixture(defaults: defaults).exposeTrackpadFingerCount == 3)
defaults.set(99, forKey: SettingsFixture.Keys.exposeTrackpadFingerCount)
precondition(SettingsFixture(defaults: defaults).exposeTrackpadFingerCount == 4)
withExtendedLifetime(subscription) {}
print("Trackpad settings checks passed: 7,000 selections, bounded publications, persistence, reload, normalization and toggle")
""".replace("__PROPERTIES__", properties).replace("__INITIALIZERS__", initializers)

with tempfile.TemporaryDirectory(prefix="pk-trackpad-checks-", dir=os.environ.get("TMPDIR")) as work:
    path = Path(work)
    (path / "main.swift").write_text(fixture)
    command = ["swiftc"]
    if os.environ.get("PK_MACOS_SDK"):
        command += ["-sdk", os.environ["PK_MACOS_SDK"]]
    subprocess.run(command + [str(path / "main.swift"), "-o", str(path / "checks")], check=True)
    subprocess.run([str(path / "checks")], check=True, timeout=30)
