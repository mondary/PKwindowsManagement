import {execFileSync} from 'node:child_process';
import {mkdirSync, writeFileSync} from 'node:fs';
import assert from 'node:assert/strict';
import {SHOTS} from '../src/timeline.mjs';
mkdirSync('out/qa', {recursive: true});
const file = '../videos/shotcraft.mp4';
const probe = JSON.parse(execFileSync('ffprobe', ['-v', 'error', '-show_streams', '-show_format', '-of', 'json', file], {encoding: 'utf8'}));
const video = probe.streams.find(s => s.codec_type === 'video');
assert.equal(video.codec_name, 'h264');
assert.equal(video.pix_fmt, 'yuv420p');
assert.equal(video.width, 1920);
assert.equal(video.height, 1080);
assert.equal(video.nb_frames, '900');
assert.equal(video.color_range, 'tv');
assert.equal(probe.streams.length, 1, 'Silent master must have only a video stream');
assert.equal(Number(probe.format.duration), 30);
writeFileSync('out/qa/ffprobe.json', JSON.stringify(probe, null, 2));
for (const shot of SHOTS) {
  for (const offset of [20, Math.floor(shot.duration / 2), shot.duration - 20]) {
    const f = shot.from + offset;
    execFileSync('ffmpeg', ['-v', 'error', '-y', '-i', file, '-vf', `select=eq(n\\,${f})`, '-frames:v', '1', `out/qa/f${f}.png`]);
  }
}
execFileSync('ffmpeg', ['-v', 'error', '-y', '-i', file, '-vf', 'fps=1/2,scale=480:270,tile=3x5', '-frames:v', '1', 'out/qa/contact-sheet.png']);
console.log('PASS: H264 yuv420p 1920x1080, 30 seconds, 900 frames; 21 QA stills and contact sheet.');
