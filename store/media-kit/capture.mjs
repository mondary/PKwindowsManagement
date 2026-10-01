// Run with: ego-browser nodejs < store/media-kit/capture.mjs
// Reuses the existing task space; change its id when regenerating in a new session.
const task = await taskSpace(38);
const page = task.page('p1');
const fs = await import('node:fs/promises');
const path = await import('node:path');
const base = '/Users/clm/Documents/GitHub/PROJECTS/Macos_PKwindowsManagement/store/website';
const temp = '/var/folders/jb/07k9zyks6_d60c27tclhjd2h0000gn/T/opencode/store-frames';
await fs.mkdir(temp, {recursive:true});
await page.cdp('Emulation.setDeviceMetricsOverride', {width:1200,height:750,deviceScaleFactor:1,mobile:false});
await page.goto('http://127.0.0.1:4178/store/website/');
await page.evaluate(() => {
  document.documentElement.style.scrollBehavior = 'auto';
  document.querySelectorAll('img').forEach(image => image.loading = 'eager');
  setLanguage('fr');
});
await page.waitForFunction(() => [...document.images].every(image => image.complete));
for (let frame = 0; frame < 192; frame++) {
  await page.evaluate(time => { window.scrollTo(0,0); return window.renderMediaFrame(time); }, frame / 24);
  const shot = await page.cdp('Page.captureScreenshot', {format:'png',captureBeyondViewport:false});
  await fs.writeFile(path.join(temp, `${String(frame).padStart(4,'0')}.png`), Buffer.from(shot.data,'base64'));
  if (frame === 30) await fs.writeFile(path.join(base,'..','sources','screenshots','demo-poster.png'),Buffer.from(shot.data,'base64'));
}
await page.goto('http://127.0.0.1:4178/store/website/');
await page.evaluate(() => {
  const style = document.createElement('style');
  style.textContent = `.nav-wrap,main>section:not(.hero),footer,.hero>.eyebrow,.hero-copy,.hero-actions,.hero>.micro,.hero>.scene-caption{display:none!important}.hero{width:100%;height:100vh;padding:0 50px;display:grid;grid-template-columns:.8fr 1.2fr;align-items:center;gap:35px;text-align:left}.hero h1{font-size:74px}.hero-product{width:100%;margin:0}.desktop-scene{aspect-ratio:1.35}.hero-calendar{width:76%}.hero-launchpad{width:50%;top:40%;right:4%}.hero-shortcut>span{display:none!important}.device-base{margin:0 -12px}.hero:before{content:'PKwindowsManagement';position:absolute;left:50px;top:43px;font-size:17px;font-weight:600;letter-spacing:-.5px}.hero:after{content:'Fenêtres · Launchpad · Big Year';position:absolute;left:50px;bottom:43px;font-size:14px;color:#68786e}`;
  style.textContent += '.hero .desktop-scene{height:min(480px,calc(100vh - 140px));aspect-ratio:auto}';
  document.head.append(style);
  setLanguage('fr');
});
for (const [name,width,height,folder] of [['card-1200x630',1200,630,'website/assets'],['banner-1544x500',1544,500,'sources/assets']]) {
  await page.cdp('Emulation.setDeviceMetricsOverride',{width,height,deviceScaleFactor:1,mobile:false});
  await page.screenshot({path:path.join(base,'..',folder,`${name}.png`)});
}
console.log({frames:192,fps:24,duration:8,temp});
