// Renders every app icon / splash asset from the SVG sources in assets/brand/.
// Usage (from repo root): node tool/render_app_icons.js
// Needs Playwright's Chromium and ImageMagick (`convert`). No paid tools.
const { chromium } = require('playwright');
const fs = require('fs'), path = require('path');
const { execFileSync } = require('child_process');
const B = 'assets/brand', RES = 'android/app/src/main/res', IOS = 'ios/Runner/Assets.xcassets';
const svg = n => fs.readFileSync(path.join(B, n), 'utf8');
const stack = (...n) => { // layer several svgs, first = bottom
  const inner = n.map(x => { const s = svg(x); return s.replace(/<svg[^>]*>/, m => '<g>').replace('</svg>', '</g>'); });
  // defs ids collide only inside one file, so nesting is safe
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" width="1024" height="1024">${inner.join('')}</svg>`;
};
(async () => {
  const b = await chromium.launch(); const p = await b.newPage();
  const render = async (markup, size, out, o = {}) => {
    await p.setViewportSize({ width: size, height: size });
    const r = o.round ? `${Math.round(size * o.round)}px` : '0';
    await p.setContent(`<body style="margin:0;background:transparent"><div style="width:${size}px;height:${size}px;border-radius:${r};overflow:hidden">${markup.replace('width="1024" height="1024"', `width="${size}" height="${size}"`)}</div></body>`);
    fs.mkdirSync(path.dirname(out), { recursive: true });
    await p.screenshot({ path: out, omitBackground: true });
    if (o.opaque) execFileSync('convert', [out, '-background', o.opaque, '-alpha', 'remove', '-alpha', 'off', out]);
  };
  // iOS (light, dark and tinted 1024 universal icons)
  const A = IOS + '/AppIcon.appiconset';
  for (const f of fs.readdirSync(A)) if (f.endsWith('.png')) fs.unlinkSync(path.join(A, f));
  await render(svg('icon_light.svg'), 1024, A + '/AppIcon-1024.png', { opaque: '#0B6B4A' });
  await render(svg('icon_dark.svg'), 1024, A + '/AppIcon-1024-dark.png', { opaque: '#05261D' });
  await render(svg('icon_tinted.svg'), 1024, A + '/AppIcon-1024-tinted.png', { opaque: '#000000' });
  fs.writeFileSync(A + '/Contents.json', JSON.stringify({ images: [
    { filename: 'AppIcon-1024.png', idiom: 'universal', platform: 'ios', size: '1024x1024' },
    { appearances: [{ appearance: 'luminosity', value: 'dark' }], filename: 'AppIcon-1024-dark.png', idiom: 'universal', platform: 'ios', size: '1024x1024' },
    { appearances: [{ appearance: 'luminosity', value: 'tinted' }], filename: 'AppIcon-1024-tinted.png', idiom: 'universal', platform: 'ios', size: '1024x1024' }],
    info: { author: 'xcode', version: 1 } }, null, 2) + '\n');
  // iOS launch image: the mark only, on the emerald storyboard background
  const L = IOS + '/LaunchImage.imageset';
  for (const [s, f] of [[252, 'LaunchImage.png'], [504, 'LaunchImage@2x.png'], [756, 'LaunchImage@3x.png']]) await render(svg('splash_mark.svg'), s, `${L}/${f}`);
  // Android adaptive + legacy + splash mark
  const D = { mdpi: 1, hdpi: 1.5, xhdpi: 2, xxhdpi: 3, xxxhdpi: 4 };
  for (const [d, k] of Object.entries(D)) {
    await render(svg('foreground.svg'), 108 * k, `${RES}/mipmap-${d}/ic_launcher_foreground.png`);
    await render(svg('background.svg'), 108 * k, `${RES}/mipmap-${d}/ic_launcher_background.png`);
    await render(svg('monochrome.svg'), 108 * k, `${RES}/mipmap-${d}/ic_launcher_monochrome.png`);
    await render(svg('icon_light.svg'), 48 * k, `${RES}/mipmap-${d}/ic_launcher.png`, { round: 0.224 });
    await render(svg('splash_mark.svg'), 192 * k, `${RES}/drawable-${d}/splash_mark.png`);
  }
  // Web / PWA
  await render(svg('icon_light.svg'), 192, 'web/icons/Icon-192.png', { opaque: '#0B6B4A' });
  await render(svg('icon_light.svg'), 512, 'web/icons/Icon-512.png', { opaque: '#0B6B4A' });
  const mask = stack('background.svg', 'foreground.svg');
  await render(mask, 192, 'web/icons/Icon-maskable-192.png', { opaque: '#0B6B4A' });
  await render(mask, 512, 'web/icons/Icon-maskable-512.png', { opaque: '#0B6B4A' });
  await render(svg('icon_light.svg'), 32, 'web/favicon.png', { round: 0.224 });
  await b.close();
})();
