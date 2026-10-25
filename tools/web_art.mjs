#!/usr/bin/env node
/**
 * Turn generated key art into the two kinds of file the web shell can ship.
 *
 *   node tools/web_art.mjs plate  SOURCE.png OUT.jpg [--width 1536] [--height 864] [--quality 84]
 *                                                    [--crop l,t,r,b]
 *   node tools/web_art.mjs figure SOURCE.png OUT.png [--threshold 18] [--close 3]
 *                                                    [--feather 1.6] [--scale 0.66]
 *                                                    [--trim] [--preview OUT.jpg]
 *
 * Why this exists
 * ---------------
 * The hero page used to show one picture: a hangar with the operative painted
 * into it. That is a reference, not a screen. A lobby that renders the player's
 * own operative cannot have a second operative baked into the backdrop -- the
 * moment the rig, the livery or the lighting changes, the painted figure is a
 * lie sitting behind the real one, and nothing can move independently: not the
 * breathe loop, not the celebration, not the skin tab.
 *
 * So the key art is split in two:
 *
 *   plate   the empty bay -- the room, the lights, the pad. Shipped as a JPEG,
 *           cropped to the composition the screen needs and scaled down.
 *   figure  the operative alone on a flat black plate, keyed to RGBA. This is a
 *           stand-in layer with a stated contract (see docs/DECISIONS.md 40):
 *           transparent PNG, feet on the bottom edge, centred, no shadow. The
 *           in-engine render of hero.glb drops into the same slot unchanged.
 *
 * --close is a morphological closing of the background before it becomes the
 * matte: the fill leaks through narrow near-black gaps (a shadow between two
 * limbs, a crevice in the armour) and leaves a hole in the silhouette. Eroding
 * then dilating the background seals channels thinner than the radius without
 * moving the outer edge, so the limb gap closes and the outline does not shrink.
 *
 * The key is a flood fill from the border, not a global luminance threshold.
 * A threshold turns every dark pixel transparent, which punches holes through
 * the rifle, the gloves and the shadowed side of the armour; a fill only
 * removes the black that is reachable from the edge of the frame, so interior
 * darks survive and real background gaps (between arm and torso) are still
 * cleared. The matte is then feathered so the silhouette does not alias.
 *
 * No ImageMagick, no Pillow, no sharp in this repo; headless Chromium is
 * already a dependency for the screenshot tools, and a canvas is enough.
 */

import { mkdir, readFile, writeFile } from 'node:fs/promises';
import path from 'node:path';
import puppeteer from 'puppeteer-core';
import chromium from '@sparticuz/chromium';

function arg(name, fallback) {
  const i = process.argv.indexOf(`--${name}`);
  if (i === -1) return fallback;
  const v = process.argv[i + 1];
  if (v === undefined || v.startsWith('--')) return true;
  return v;
}

const [mode, source, target] = process.argv.slice(2);
if (!mode || !source || !target) {
  console.error('usage: web_art.mjs <plate|figure> SOURCE OUT [options]');
  process.exit(2);
}

const WORK = `
async function load(blobUrl) {
  const img = new Image();
  img.src = blobUrl;
  await img.decode();
  return img;
}

function canvasOf(w, h) {
  const c = document.createElement('canvas');
  c.width = w;
  c.height = h;
  return c;
}

// Cover-crop then scale: the screens are 844x390 and 667x375, so a 16:9 plate
// is cropped to the panel's own ratio rather than letterboxed.
window.makePlate = async (blobUrl, width, height, quality, crop) => {
  const img = await load(blobUrl);
  // The crop nudges the composition without a CSS transform: a scaled plate
  // reports an oversized box to the layout QA (which is right to complain about
  // elements outside the viewport), so the push-in is baked into the file.
  const [cl, ct, cr, cb] = crop || [0, 0, 1, 1];
  const regionX = img.naturalWidth * cl;
  const regionY = img.naturalHeight * ct;
  const regionW = img.naturalWidth * (cr - cl);
  const regionH = img.naturalHeight * (cb - ct);
  const srcRatio = regionW / regionH;
  const dstRatio = width / height;
  let sw = regionW;
  let sh = regionH;
  if (srcRatio > dstRatio) sw = sh * dstRatio;
  else sh = sw / dstRatio;
  const sx = Math.round(regionX + (regionW - sw) / 2);
  const sy = Math.round(regionY + (regionH - sh) / 2);
  sw = Math.round(sw);
  sh = Math.round(sh);
  const c = canvasOf(width, height);
  const ctx = c.getContext('2d');
  ctx.imageSmoothingQuality = 'high';
  ctx.drawImage(img, sx, sy, sw, sh, 0, 0, width, height);
  return c.toDataURL('image/jpeg', quality);
};

// Key a subject off a flat black plate: border flood fill, feather, trim.
window.makeFigure = async (blobUrl, threshold, close, feather, scale, trim, preview) => {
  const img = await load(blobUrl);
  const w = img.naturalWidth;
  const h = img.naturalHeight;
  const c = canvasOf(w, h);
  const ctx = c.getContext('2d', { willReadFrequently: true });
  ctx.drawImage(img, 0, 0);
  const data = ctx.getImageData(0, 0, w, h);
  const px = data.data;
  const n = w * h;

  // Is this pixel dark enough to be background?
  const dark = new Uint8Array(n);
  for (let i = 0; i < n; i++) {
    const o = i * 4;
    const m = Math.max(px[o], px[o + 1], px[o + 2]);
    if (m <= threshold) dark[i] = 1;
  }

  // Flood from every border pixel that is dark. Anything the fill does not
  // reach is the subject -- including the shadowed inside of the armour.
  const bg = new Uint8Array(n);
  const stack = [];
  const push = (i) => {
    if (dark[i] && !bg[i]) {
      bg[i] = 1;
      stack.push(i);
    }
  };
  for (let x = 0; x < w; x++) {
    push(x);
    push((h - 1) * w + x);
  }
  for (let y = 0; y < h; y++) {
    push(y * w);
    push(y * w + w - 1);
  }
  while (stack.length) {
    const i = stack.pop();
    const x = i % w;
    const y = (i - x) / w;
    if (x > 0) push(i - 1);
    if (x < w - 1) push(i + 1);
    if (y > 0) push(i - w);
    if (y < h - 1) push(i + w);
  }

  // Seal narrow leaks: min-filter (erode the background) then max-filter
  // (dilate it back). Separable, so it costs four passes over the frame.
  if (close > 0) {
    const pass = (src, r, want, horiz) => {
      const dst = new Uint8Array(n);
      for (let y = 0; y < h; y++) {
        for (let x = 0; x < w; x++) {
          const i = y * w + x;
          let v = src[i];
          for (let k = -r; k <= r && v !== want; k++) {
            const nx = horiz ? x + k : x;
            const ny = horiz ? y : y + k;
            if (nx < 0 || ny < 0 || nx >= w || ny >= h) continue;
            if (src[ny * w + nx] === want) v = want;
          }
          dst[i] = v;
        }
      }
      return dst;
    };
    let m = bg;
    for (let it = 0; it < 2; it++) {
      m = pass(m, close, 0, true); // erode: any 0 in the run clears the pixel
      m = pass(m, close, 0, false);
      m = pass(m, close, 1, true); // dilate: any 1 in the run sets the pixel
      m = pass(m, close, 1, false);
    }
    bg.set(m);
  }

  // A one-pixel halo of background that is brighter than the threshold would
  // leave a black outline; grow the matte by one pixel into pixels that are
  // still very dark, so the silhouette edge keeps the rim light and loses the
  // plate.
  const grow = new Uint8Array(bg);
  for (let y = 0; y < h; y++) {
    for (let x = 0; x < w; x++) {
      const i = y * w + x;
      if (bg[i]) continue;
      const o = i * 4;
      const m = Math.max(px[o], px[o + 1], px[o + 2]);
      if (m > threshold * 2.2) continue;
      if (
        (x > 0 && bg[i - 1]) ||
        (x < w - 1 && bg[i + 1]) ||
        (y > 0 && bg[i - w]) ||
        (y < h - 1 && bg[i + w])
      ) {
        grow[i] = 1;
      }
    }
  }
  bg.set(grow);

  // Alpha into a mask canvas so the feather is a real blur, not a hard step.
  const mask = canvasOf(w, h);
  const mctx = mask.getContext('2d');
  const mdata = mctx.createImageData(w, h);
  for (let i = 0; i < n; i++) {
    const a = bg[i] ? 0 : 255;
    mdata.data[i * 4] = 0;
    mdata.data[i * 4 + 1] = 0;
    mdata.data[i * 4 + 2] = 0;
    mdata.data[i * 4 + 3] = a;
  }
  mctx.putImageData(mdata, 0, 0);

  // Apply the matte to the RGB and blur the alpha in one pass each.
  for (let i = 0; i < n; i++) {
    px[i * 4 + 3] = bg[i] ? 0 : 255;
  }
  ctx.putImageData(data, 0, 0);

  let out = canvasOf(w, h);
  let octx = out.getContext('2d');
  octx.drawImage(c, 0, 0);

  if (feather > 0) {
    const soft = canvasOf(w, h);
    const sctx = soft.getContext('2d');
    sctx.filter = \`blur(\${feather}px)\`;
    sctx.drawImage(mask, 0, 0);
    // keep = soft alpha, applied by destination-in on a copy of the RGB
    const composed = canvasOf(w, h);
    const cctx = composed.getContext('2d');
    cctx.drawImage(out, 0, 0);
    cctx.globalCompositeOperation = 'destination-in';
    cctx.drawImage(soft, 0, 0);
    out = composed;
    octx = composed.getContext('2d');
  }

  // Trim to the subject, with a little air, so the CSS can size the layer by
  // height alone and know where the feet are.
  let x0 = w;
  let y0 = h;
  let x1 = 0;
  let y1 = 0;
  {
    const tctx = octx;
    const tdata = tctx.getImageData(0, 0, w, h).data;
    for (let y = 0; y < h; y++) {
      for (let x = 0; x < w; x++) {
        if (tdata[(y * w + x) * 4 + 3] > 8) {
          if (x < x0) x0 = x;
          if (x > x1) x1 = x;
          if (y < y0) y0 = y;
          if (y > y1) y1 = y;
        }
      }
    }
  }
  if (!trim || x1 <= x0 || y1 <= y0) {
    x0 = 0;
    y0 = 0;
    x1 = w - 1;
    y1 = h - 1;
  }
  const pad = trim ? 2 : 0;
  x0 = Math.max(0, x0 - pad);
  y0 = Math.max(0, y0 - pad);
  x1 = Math.min(w - 1, x1 + pad);
  y1 = Math.min(h - 1, y1 + pad);
  const tw = x1 - x0 + 1;
  const th = y1 - y0 + 1;

  const finalW = Math.max(1, Math.round(tw * scale));
  const finalH = Math.max(1, Math.round(th * scale));
  const resized = canvasOf(finalW, finalH);
  const rctx = resized.getContext('2d');
  rctx.imageSmoothingQuality = 'high';
  rctx.drawImage(out, x0, y0, tw, th, 0, 0, finalW, finalH);

  let previewUrl = null;
  if (preview) {
    const pv = canvasOf(w, h);
    const pctx = pv.getContext('2d');
    pctx.fillStyle = '#6b7480';
    pctx.fillRect(0, 0, w, h);
    pctx.drawImage(out, 0, 0);
    previewUrl = pv.toDataURL('image/jpeg', 0.85);
  }

  return {
    png: resized.toDataURL('image/png'),
    preview: previewUrl,
    box: { x0, y0, x1, y1 },
    size: { w: finalW, h: finalH },
  };
};
`;

const src = await readFile(source);
const dataUrl = `data:image/png;base64,${src.toString('base64')}`;

await mkdir(path.dirname(path.resolve(target)), { recursive: true });

const browser = await puppeteer.launch({
  executablePath: await chromium.executablePath(),
  args: [...chromium.args, '--no-sandbox', '--disable-dev-shm-usage'],
  defaultViewport: { width: 400, height: 300 },
  headless: true,
});

// @sparticuz/chromium needs its shared libraries; the sandbox ships them out of
// the default loader path.
process.env.LD_LIBRARY_PATH = process.env.LD_LIBRARY_PATH || 'tools/.cache/al2023-lib/lib';

try {
  const page = await browser.newPage();
  await page.goto('about:blank');
  await page.addScriptTag({ content: WORK });

  if (mode === 'plate') {
    const width = Number(arg('width', 1536));
    const height = Number(arg('height', 864));
    const quality = Number(arg('quality', 0.84));
    const crop = (arg('crop', null) || '0,0,1,1').split(',').map(Number);
    const out = await page.evaluate(
      (u, w, h, q, c) => window.makePlate(u, w, h, q, c),
      dataUrl,
      width,
      height,
      quality,
      crop,
    );
    await writeFile(target, Buffer.from(out.split(',')[1], 'base64'));
    console.log(`plate  ${target}  ${width}x${height}`);
  } else if (mode === 'figure') {
    const threshold = Number(arg('threshold', 18));
    const close = Number(arg('close', 3));
    const feather = Number(arg('feather', 1.6));
    const scale = Number(arg('scale', 0.66));
    // Trimming is the default: the layer is positioned by its height, so the
    // file must start at the helmet and end at the boots, not at the plate.
    const trim = arg('trim', true) !== false;
    const previewPath = arg('preview', null);
    const res = await page.evaluate(
      (u, t, c, f, s, tr, p) => window.makeFigure(u, t, c, f, s, tr, p),
      dataUrl,
      threshold,
      close,
      feather,
      scale,
      trim,
      Boolean(previewPath),
    );
    await writeFile(target, Buffer.from(res.png.split(',')[1], 'base64'));
    console.log(`figure ${target}  ${res.size.w}x${res.size.h}  box ${JSON.stringify(res.box)}`);
    if (previewPath && res.preview) {
      await mkdir(path.dirname(path.resolve(previewPath)), { recursive: true });
      await writeFile(previewPath, Buffer.from(res.preview.split(',')[1], 'base64'));
      console.log(`preview ${previewPath}`);
    }
  } else {
    console.error(`unknown mode: ${mode}`);
    process.exit(2);
  }
} finally {
  await browser.close();
}
