# Shotcraft - execution record

Mode: autonomous, explicitly chosen by user. Engine: native Remotion, explicitly requested.
Deliverable: store/videos/shotcraft.mp4, 1920x1080, 30 fps, 900 frames, French captions.

## Brief and decisions

Audience: macOS users who organize windows and launch apps with the keyboard.
Evidence: store/description-store.md and four supplied real native screenshots.
Required features: windows, Launchpad, global application shortcuts, Big Year, appearance.
The shortcuts image actually shows window settings; the global-app shot instead crops
the real Calendar/Notes badges in launchpad.png. No invented preference screen.
No interaction is claimed: permanent French disclosure says captures animees and demo data.
Sanitized fixtures: Alex, Sam, Robin, Charlie, generic events and stock macOS applications.
No new capture session; parent owns capture acquisition and approved these frozen assets.

Visual direction selected: native icy white / blue / navy. Rejected ink-paper and neon.
Tokens: #edf7ff canvas, #142347 text/frame, #3078ed accent, #465c79 secondary.
Native system sans, 78-96px headlines, 38-40px supporting copy, 32px disclosure.
24px screenshot corners, 112px safe left edge, quiet soft navy shadow.
Strict supplied visual direction makes an extra HTML styleframe redundant; the first
Remotion still is the executable styleframe before final rendering.

## References and adaptation

Skill root: ~/.agents/skills/externes/video-shotcraft/
Gallery card and style-key: brand-frame-snap (validated against gallery/api/library.json).
Exact source: demos/effects/brand-frame-snap/BrandFrameSnap.tsx.
Card: references/shots/effects/brand-frame-snap.md.
Reference: https://vincentwei1021.github.io/video-shotcraft/media/brand-frame-snap.mp4
Preserved: solid 44px bands, 18f growth, spring delayed 14f (damping16, stiffness110),
560px travel, .82-to-1 scale, single simultaneous chapter flip, 3f pulse and damped border.
Adapted: intro protagonist is the supplied real app icon rather than fake dashboard;
flip is at f120, after a longer settled hold, blue-to-navy rather than blue-to-green.
The card is used once as whole-film framing, not repeated at every cut.
Page cameras follow assets/lib/PageCam.tsx's page-coordinate transform with a 1160x740
inset viewport, native image dimensions and its bezier(.33,0,.15,1). Custom shot paths
are intentionally not claimed as Gallery variants. No 3D tilt on dense text.

## Storyboard

| Frames | Feature | Action | Source | Hold/check frames |
| --- | --- | --- | --- | --- |
| 0-119 | Brand | Frame grows, icon settles | icon.png | 20,60,100 |
| 120-269 | Windows | Vertical camera on halves/quarters | shortcuts.png | 140,195,250 |
| 270-419 | Launchpad | Gentle centered push | launchpad.png | 290,345,400 |
| 420-539 | Global shortcuts | Calendar/Notes detail | launchpad.png | 440,480,520 |
| 540-689 | Big Year | Pull back to annual overview | big-year.png | 560,615,670 |
| 690-809 | Appearance | Settings/grid inspection | appearance.png | 710,750,790 |
| 810-899 | CTA | Icon + repository address | icon.png | 830,855,880 |

Single source of truth: src/timeline.mjs, including exact final French captions.
Every camera stops 36 frames before its cut. Intro/outro wordmarks hold over one second.
Native screenshot text is evidence/detail; large overlaid captions carry the story.

## Explicit style exceptions

Sound: deliberately silent website promo; no BGM, SFX, voice or unverified audio licenses.
Audio guidelines S1-S5 and two-BGM-version delivery are not applicable to this choice.
No clicks or typing are simulated, so no fictional UI sound claims.
Q8: quiet product/CTA close instead of particles and group flight, matching native utility tone.
C3: screen-space captions, because no 3D scene is used. No decorative glow or shaking.
Q2: supplied 1600px captures limit detail; large captions stay vector-rendered, and no
camera exceeds 1.04 source-pixel scale. No claim that the sources are 2x textures.

## Review handoff

Parent performs independent review, as explicitly allocated by user.
Read references/final-review.md and references/aesthetic-rules.md from skill root.
Inputs: this spec, src files, MP4, out/qa/ffprobe.json, 21 stills, contact sheet,
approved original screenshots, and the exact Gallery source/card above.
Workbench manifest provided; opening browser/workbench deferred to parent to avoid
disturbing its active computer UI session. Workbench parity is not claimed tested.
