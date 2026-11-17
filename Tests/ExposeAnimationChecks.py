#!/usr/bin/env python3
"""Timing + source integration guards; no screen, capture, AX or app launch."""
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
view = (ROOT / "src/macos/Views/WindowSwitcher/ExposeView.swift").read_text()
controller = (ROOT / "src/macos/Services/WindowSwitcher/WindowSwitcherController.swift").read_text()
scene = (ROOT / "src/macos/Services/WindowSwitcher/ExposeScene.swift").read_text()


def body(source, declaration):
    start = source.index(declaration)
    opening = source.index("{", start)
    depth = 1
    end = opening + 1
    while depth:
        depth += (source[end] == "{") - (source[end] == "}")
        end += 1
    return source[opening + 1:end - 1]


# The production view must use fixed target geometry, including on exit.
replica = body(view, "private func windowReplica(")
assert "let frame = target" in replica
assert "ExposeLayout.sourceFrame" not in replica
assert "scene.expanded ?" not in replica
assert "\n        .opacity(" not in replica, "All previews share the layer fade"
layer = body(view, "private var windowLayer:")
assert ".opacity(scene.expanded ? 1 : 0)" in layer
assert "let clip = scene.mode == .strip\n" in layer, "Do not unclip the strip on exit"
for declaration in (
    "private func caption(", "private func groupCard(",
    "private func stripBadge(", "private func islandTitle("
):
    assert ".opacity(decorationsVisible" not in body(view, declaration), "Decorations must not fade twice"

exit_body = body(controller, "private func endExpose(")
assert "scene.exitDuration(activating: id != nil)" in exit_body
assert exit_body.index("let choice =") < exit_body.index("scene.dismissing = true")
assert exit_body.index("self.hide()") < exit_body.index("self.activateAfterExpose(choice)")
assert "self.interactionID == interaction" in exit_body
assert "ExposeAnimation.entryDuration(reduceMotion: reduceMotion)" in scene
assert "ExposeAnimation.exitDuration(activating: activating, reduceMotion: reduceMotion)" in scene

fixture = """
import Foundation

let entry = ExposeAnimation.entryDuration(reduceMotion: false)
let selected = ExposeAnimation.exitDuration(activating: true, reduceMotion: false)
let cancelled = ExposeAnimation.exitDuration(activating: false, reduceMotion: false)
precondition(entry > 0 && entry <= 0.18)
precondition(selected > 0 && selected <= 0.08 && selected < cancelled)
precondition(cancelled <= 0.12 && cancelled < entry)
for activating in [false, true] {
    let reduced = ExposeAnimation.exitDuration(activating: activating, reduceMotion: true)
    precondition(reduced > 0 && reduced <= selected)
}
precondition(ExposeAnimation.entryDuration(reduceMotion: true) <= selected)
print("Exposé animation checks passed: 160 ms entry / 70 ms selection / 100 ms cancel, reduced motion, fixed geometry, shared fade, stable strip clipping and hide-before-focus")
"""
with tempfile.TemporaryDirectory(prefix="pk-expose-animation-", dir=os.environ.get("TMPDIR")) as work:
    path = Path(work)
    (path / "main.swift").write_text(fixture)
    command = ["swiftc"]
    if os.environ.get("PK_MACOS_SDK"):
        command += ["-sdk", os.environ["PK_MACOS_SDK"]]
    subprocess.run(command + [
        str(ROOT / "src/macos/Services/WindowSwitcher/ExposeAnimation.swift"),
        str(path / "main.swift"), "-o", str(path / "checks")
    ], check=True)
    subprocess.run([str(path / "checks")], check=True, timeout=15)
