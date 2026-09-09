const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { loadSharp, verifyEncodedAnimation } = require('./assemble_clip.cjs');

async function main() {
  const sharp = loadSharp();
  sharp.cache(false); // Release temporary GIF handles before Windows cleanup.
  const width = 144, height = 80;
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'achilles-gif-order-'));
  const output = path.join(directory, 'order.gif');
  const makePage = (xOffset, color) => {
    const pixels = Buffer.alloc(width * height * 3, 70);
    for (let y = 30; y < 48; y++) for (let x = xOffset; x < xOffset + 12; x++) {
      const index = (y * width + x) * 3;
      pixels[index] = color[0]; pixels[index + 1] = color[1]; pixels[index + 2] = color[2];
    }
    return pixels;
  };
  const first = makePage(15, [220, 20, 30]);
  const second = makePage(90, [10, 190, 230]);
  const pages = [first, first, second];
  const delays = [60, 80, 70];
  try {
    await sharp(Buffer.concat(pages), {
      raw: { width, height: height * pages.length, channels: 3, pageHeight: height },
    }).gif({ delay: delays, loop: 0, effort: 6, colours: 256 }).toFile(output);
    const valid = await verifyEncodedAnimation(sharp, output, pages, delays, width, height);
    assert.equal(valid.source_images_checked_in_order, 3);
    assert.deepEqual(valid.signature_size, [width, height]);
    assert.equal(valid.encoded_frames, 2, 'Identical consecutive holds may coalesce with their duration preserved');
    await assert.rejects(
      verifyEncodedAnimation(sharp, output, [second, first, first], delays, width, height),
      /image order mismatch/,
      'A reversed real drawing must remain a hard failure',
    );
    await assert.rejects(
      verifyEncodedAnimation(sharp, output, pages, [50, 80, 80], width, height),
      /captured image transition/,
      'Equal total duration cannot hide a displaced image boundary',
    );
    console.log('3 GIF checks passed: full-resolution order, inverted drawing rejection, moved-boundary rejection.');
  } finally {
    // This test owns exactly one file; no recursive or computed-directory deletion.
    if (fs.existsSync(output)) fs.unlinkSync(output);
    fs.rmdirSync(directory);
  }
}

main().catch(error => { console.error(error); process.exitCode = 1; });
