# Production checks

Final master: `../videos/shotcraft.mp4`.
Validated with `npm test`, `npm run qa`, and a full ffmpeg decode to null.

- H.264 High, 1920x1080, 30 fps, 900 frames, exactly 30.000 seconds.
- Pixel format yuv420p, BT.709, limited TV range.
- Single video stream, intentionally silent. Size: 7,152,445 bytes.
- Dependencies, prepared assets and generated QA artifacts are git-ignored.
- No Swift or other pre-existing store source files were edited by this worker.

The first render revealed Remotion's default full-range yuvj420p output. The final
reproducible command explicitly sets `--color-space=bt709`, `--pixel-format=yuv420p`,
`--muted` and `--overwrite`; the QA script asserts the actual encoded result.

Visual self-check: executable styleframe f210; final contact sheet covering all
seven shots; full-size final f480 (global shortcut badges), f750 (appearance),
f880 (CTA). Large captions and CTA remain inside safe bounds. Screenshot details
are naturally smaller than narrative captions; no private names outside the
approved fictional calendar fixtures were observed.

Artifacts in `out/qa/`: 21 exact-frame PNGs, `contact-sheet.png`, `ffprobe.json`.
Downloaded Gallery reference: `reference-brand-frame-snap.mp4`; inspected its
`reference-contact-sheet.png`. Source/card/reference locations are in DESIGN.md.

This is production self-check, not independent sign-off. Parent retains final
review responsibility. Workbench parity and interactive playback were not tested;
no browser, desktop player or workbench was opened during the parent's UI session.
