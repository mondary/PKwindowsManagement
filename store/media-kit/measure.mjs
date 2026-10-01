// Local performance and fallback checks. No external analytics are installed.
const task = await taskSpace(38);
const page = task.page('p1');
const fs = await import('node:fs/promises');
const assert = (await import('node:assert/strict')).default;
const base = '/Users/clm/Documents/GitHub/PROJECTS/Macos_PKwindowsManagement/store/website';
const temp = '/var/folders/jb/07k9zyks6_d60c27tclhjd2h0000gn/T/opencode';
const source = `window.qa={lcp:0,cls:0,errors:[]};addEventListener('error',event=>qa.errors.push(event.message));addEventListener('unhandledrejection',event=>qa.errors.push(String(event.reason)));new PerformanceObserver(list=>list.getEntries().forEach(entry=>qa.lcp=entry.startTime)).observe({type:'largest-contentful-paint',buffered:true});new PerformanceObserver(list=>list.getEntries().forEach(entry=>{if(!entry.hadRecentInput)qa.cls+=entry.value})).observe({type:'layout-shift',buffered:true});`;
const hook = await page.cdp('Page.addScriptToEvaluateOnNewDocument',{source});
await page.cdp('Network.enable');
await page.cdp('Network.setCacheDisabled',{cacheDisabled:true});
const metrics = [];
for (const width of [390,1440]) {
  await page.cdp('Emulation.setDeviceMetricsOverride',{width,height:1000,deviceScaleFactor:1,mobile:false});
  await page.goto('http://127.0.0.1:4178/store/website/');
  await page.waitForFunction(() => document.querySelector('.hero-launchpad img').complete && window.qa.lcp > 0);
  // Allow delayed layout/paint observer deliveries to settle for this measurement.
  await page.waitForTimeout(700);
  const result = await page.evaluate(() => ({...qa,initialBytes:performance.getEntriesByType('resource').reduce((total,entry)=>total+entry.transferSize,0)+performance.getEntriesByType('navigation')[0].transferSize,resources:performance.getEntriesByType('resource').map(entry=>({name:entry.name.split('/').pop(),bytes:entry.transferSize}))}));
  assert.equal(result.errors.length,0);
  metrics.push({width,...result});
}
await page.cdp('Page.removeScriptToEvaluateOnNewDocument',{identifier:hook.identifier});
await page.cdp('Network.setCacheDisabled',{cacheDisabled:false});
// Test first supported browser language and a blocked localStorage implementation.
const languageHook = await page.cdp('Page.addScriptToEvaluateOnNewDocument',{source:`Object.defineProperty(navigator,'languages',{get:()=>['es-ES','en-GB','fr-FR']});Object.defineProperty(window,'localStorage',{get:()=>{throw new Error('storage disabled')}});`});
await page.reload();
assert.equal(await page.evaluate(() => document.documentElement.lang),'en');
await page.click('#language');
assert.equal(await page.evaluate(() => document.documentElement.lang),'fr');
await page.cdp('Page.removeScriptToEvaluateOnNewDocument',{identifier:languageHook.identifier});
await page.cdp('Emulation.setScriptExecutionDisabled',{value:true});
await page.reload();
await page.screenshot({path:`${temp}/site-no-js.png`});
await page.cdp('Emulation.setScriptExecutionDisabled',{value:false});
await page.goto(`file://${base}/index.html`);
await page.waitForFunction(() => document.querySelector('.hero-launchpad img').complete);
assert(await page.evaluate(() => document.querySelector('.hero-launchpad img').naturalWidth > 0));
await page.click('button[data-layout="split"]');
assert.equal(await page.evaluate(() => document.querySelector('#play-desktop').dataset.layout),'split');
// Visually inspect the MP4 in its actual player, and the animated GIF as an image.
await page.goto('http://127.0.0.1:4178/store/website/');
await page.evaluate(() => { document.documentElement.style.scrollBehavior='auto';const video=document.querySelector('video');video.scrollIntoView({block:'center'});video.load(); });
await page.waitForFunction(() => document.querySelector('video').readyState >= 2);
await page.evaluate(() => { const video=document.querySelector('video'); video.muted=true; return video.play(); });
await page.waitForFunction(() => document.querySelector('video').currentTime >= 5.2);
await page.evaluate(() => document.querySelector('video').pause());
await page.screenshot({path:`${temp}/site-video-check.png`});
await page.goto('http://127.0.0.1:4178/store/website/gifs/window-flow-wide.gif');
await page.screenshot({path:`${temp}/site-gif-check.png`});
const files = {};
for (const relative of ['assets/wallpaper.webp','assets/card-1200x630.png','gifs/window-flow-wide.gif','videos/window-flow.mp4','../sources/assets/banner-1544x500.png','../sources/gifs/window-flow-compact.gif','../sources/downloads/PKwindowsManagement-2026.09.08-arm64.zip']) files[relative] = (await fs.stat(`${base}/${relative}`)).size;
const report = {date:new Date().toISOString(),context:'Ego Lite / Chromium on local macOS, localhost Python server, cache disabled, no network or CPU throttling; one sample per viewport, not a Lighthouse score',metrics,files,additionalChecks:['First supported navigator language: es/en/fr selects English','Manual language works when localStorage throws','No-JS visual capture','file:// assets and playground work','MP4 frame 5.2s and animated GIF opened for visual review']};
await fs.writeFile(`${base}/media-kit/validation.json`,JSON.stringify(report,null,2));
console.log(JSON.stringify(report,null,2));
