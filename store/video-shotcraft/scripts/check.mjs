import assert from 'node:assert/strict';
import {SHOTS, FPS, TOTAL} from '../src/timeline.mjs';
let end = 0;
for (const shot of SHOTS) {
  assert.equal(shot.from, end, `Gap or overlap at ${shot.id}`);
  assert.ok(shot.duration >= 90);
  if (shot.src) {
    assert.ok(shot.a.every(Number.isFinite) && shot.b.every(Number.isFinite));
    assert.ok(shot.a[2] > 0 && shot.b[2] > 0);
    assert.ok(shot.duration - 36 > 18);
  }
  end += shot.duration;
}
assert.equal(end, TOTAL);
assert.ok(TOTAL / FPS >= 25 && TOTAL / FPS <= 35);
assert.deepEqual(SHOTS.filter(s => s.src).map(s => s.id), ['windows', 'launchpad', 'global', 'year', 'appearance']);
console.log('PASS: contiguous 900-frame timeline; five features; valid cameras and >=1s holds.');
