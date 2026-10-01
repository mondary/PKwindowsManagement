// ego-browser nodejs < store/media-kit/verify.mjs
const task = await taskSpace(38);
const page = task.page('p1');
const assert = (await import('node:assert/strict')).default;
const fs = await import('node:fs/promises');
const temp = '/var/folders/jb/07k9zyks6_d60c27tclhjd2h0000gn/T/opencode';
const report = {date:new Date().toISOString(),viewports:[],checks:[]};
await page.goto('http://127.0.0.1:4178/store/website/');
await page.evaluate(() => {
  document.documentElement.style.scrollBehavior = 'auto';
  document.querySelectorAll('img').forEach(image => image.loading = 'eager');
});
await page.waitForFunction(() => [...document.images].every(image => image.complete));
assert(await page.evaluate(() => [...document.images].every(image => image.naturalWidth > 0)), 'All images load');
for (const width of [390,768,1440,1920]) {
  await page.cdp('Emulation.setDeviceMetricsOverride',{width,height:1000,deviceScaleFactor:1,mobile:false});
  for (const language of ['fr','en']) {
    await page.evaluate(language => { setLanguage(language); window.scrollTo(0,0); },language);
    const dimensions = await page.evaluate(() => ({viewport:innerWidth,document:document.documentElement.scrollWidth}));
    assert(dimensions.document <= dimensions.viewport, `No overflow ${width}/${language}`);
    report.viewports.push({width,language,...dimensions});
    await page.screenshot({path:`${temp}/site-${width}-${language}.png`});
  }
}
await page.cdp('Emulation.setDeviceMetricsOverride',{width:1440,height:1050,deviceScaleFactor:1,mobile:false});
await page.evaluate(() => setLanguage('fr'));
for (const id of ['playground','launchpad','big-year','all-features','download']) {
  await page.evaluate(id => window.scrollTo(0,document.getElementById(id).offsetTop - 90),id);
  await page.screenshot({path:`${temp}/site-${id}.png`});
}
await page.click('button[data-layout="grid"]');
await page.waitForFunction(() => document.querySelector('#play-desktop').dataset.layout === 'grid');
assert.equal(await page.evaluate(() => document.querySelector('button[data-layout="grid"]').getAttribute('aria-pressed')),'true');
await page.focus('#play-desktop');
await page.press('#play-desktop','ArrowRight');
assert.equal(await page.evaluate(() => document.querySelector('#play-desktop').dataset.layout),'focus');
await page.press('#play-desktop','End');
assert.equal(await page.evaluate(() => document.querySelector('#play-desktop').dataset.layout),'free');
await page.evaluate(() => { const input = document.querySelector('#gap'); input.value = '3'; input.dispatchEvent(new Event('input',{bubbles:true})); });
assert.equal(await page.evaluate(() => document.querySelector('#gap-value').textContent),'3%');
await page.click('button[data-theme="poster"]');
assert(await page.evaluate(() => document.querySelector('#year-preview').src.endsWith('year-poster.webp')));
await page.click('#language');
assert.equal(await page.evaluate(() => document.documentElement.lang),'en');
await page.reload();
assert.equal(await page.evaluate(() => document.documentElement.lang),'en');
report.checks.push('All images load','8 responsive/language combinations without overflow','Layout buttons + keyboard arrows + restore','Margin slider','Big Year theme switching','Manual language persists across reload');
const urls = await page.evaluate(() => [...new Set([...document.querySelectorAll('a[href],img[src],source[src]')].map(node => node.href || node.src).filter(url => url.startsWith(location.origin)))].map(url => url.split('#')[0]));
for (const url of urls) { const response = await fetch(url,{method:'HEAD'}); assert(response.ok, `Local asset/link ${url}: ${response.status}`); }
report.checks.push(`${urls.length} local link/media destinations return HTTP 200`);
await page.cdp('Emulation.setEmulatedMedia',{features:[{name:'prefers-reduced-motion',value:'reduce'}]});
assert.equal(await page.evaluate(() => getComputedStyle(document.querySelector('.demo-window')).transitionDuration),'0s');
report.checks.push('Reduced motion disables transitions');
await page.cdp('Emulation.setEmulatedMedia',{features:[]});
await page.evaluate(() => {
  window.mediaErrors = [];
  const video = document.querySelector('video');
  video.addEventListener('error',() => window.mediaErrors.push(video.error?.message));
  video.muted = true; video.load(); video.play();
});
await page.waitForFunction(() => document.querySelector('video').currentTime > 0.2);
const video = await page.evaluate(() => { const v = document.querySelector('video'); const result = {duration:v.duration,width:v.videoWidth,height:v.videoHeight,errors:window.mediaErrors}; v.pause(); return result; });
assert.equal(video.duration,8); assert.equal(video.errors.length,0);
report.video = video;
await page.cdp('Emulation.setDeviceMetricsOverride',{width:390,height:900,deviceScaleFactor:1,mobile:false});
await page.evaluate(() => { setLanguage('fr'); document.documentElement.style.scrollBehavior = 'auto'; window.scrollTo(0,document.querySelector('#playground').offsetTop-75); });
await page.screenshot({path:`${temp}/site-mobile-playground.png`});
await fs.writeFile(`${temp}/site-qa.json`,JSON.stringify(report,null,2));
console.log(JSON.stringify(report,null,2));
