# Shotcraft FR

Native Remotion source for `../videos/shotcraft.mp4`. No Swift changes.

```sh
npm ci
npm run prepare-assets
npm test
npm run still
npm run render
npm run qa
```

Run from this directory. Requires Node, npm, ffmpeg and ffprobe. The first Remotion
render may download its isolated Chrome Headless Shell. No desktop UI automation.
Pinned dependencies and package-lock.json make installation reproducible.
Assets are copied from the four approved `../screenshots/*.png` files and `../../icon.png`.
Generated assets, dependencies and QA images are ignored locally. Final MP4 is outside
this source directory. The promo is silent by design; all copy is French.

`DESIGN.md` records storyboard, exact Shotcraft reference, adaptations and review inputs.
`src/workbench.ts` exposes shot clips and the framing overlay. Workbench opening and
independent final review belong to the parent agent; parity has not been verified.
