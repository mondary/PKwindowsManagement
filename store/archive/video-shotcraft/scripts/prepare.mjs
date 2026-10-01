import {mkdir, copyFile} from 'node:fs/promises';
import {fileURLToPath} from 'node:url';
const root = new URL('../', import.meta.url);
await mkdir(new URL('public/', root), {recursive: true});
await mkdir(new URL('out/qa/', root), {recursive: true});
for (const name of ['launchpad', 'shortcuts', 'big-year', 'appearance']) {
  await copyFile(new URL(`../screenshots/${name}.png`, root), new URL(`public/${name}.png`, root));
}
await copyFile(new URL('../../icon.png', root), new URL('public/icon.png', root));
console.log(`Prepared only approved assets in ${fileURLToPath(new URL('public/', root))}`);
