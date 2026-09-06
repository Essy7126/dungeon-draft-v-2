'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const build = require('./build.cjs');
let sharp;
try {sharp = require('sharp');} catch {
  sharp = require(process.env.SHARP_PATH || 'C:/Users/paolo/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
}
const ROOT = path.resolve(__dirname, '../..');

// Artificial rectangles are strictly in-memory fixtures for ownership and
// byte conservation. No synthetic picture is written into game artwork.
function fixtureRGBA(variant = 'E', count = 16) {
  const width = 512, height = count / 4 * 128;
  const raw = Buffer.alloc(width * height * 4), roots = [];
  const first = variant === 'E' ? 4 : 8, second = first + 4;
  function rectangle(x, y, w, h, color) {
    for (let yy = y; yy < y + h; yy++) for (let xx = x; xx < x + w; xx++) {
      const offset = (yy * width + xx) * 4;
      raw.set(color, offset);
    }
  }
  for (let index = 0; index < count; index++) {
    const col = index % 4, row = Math.floor(index / 4);
    const x = col * 128 + 20, y = row * 128 + (index === second ? 4 : 20);
    roots.push([col * 128 + 64, (row + 1) * 128 - 8]);
    rectangle(x, y, 42, 42, [30 + index * 10, 70, 190 - index * 4, 255]);
    rectangle(x - 4, y - 4, 1, 1, [211, 47, 103, 1]);
  }
  if (count === 16) {
    const row = Math.floor(first / 4), y = row * 128;
    // This L-shaped extension crosses a nominal row border, while the next
    // pose occupies another x range. Their bounding rectangles overlap but
    // their opaque silhouettes are not connected, even diagonally.
    rectangle(55, y + 42, 57, 12, [235, 82, 41, 255]);
    rectangle(100, y + 42, 12, 102, [235, 82, 41, 255]);
    if (variant === 'N') {
      // A detached opaque prop >1500 pixels must merge into source pose 12.
      rectangle(90, 405, 30, 60, [160, 90, 20, 255]);
    }
  }
  rectangle(460, 66, 3, 3, [208, 120, 13, 200]);
  rectangle(1, 1, 1, 1, [7, 81, 209, 1]);
  rectangle(width - 2, height - 2, 1, 1, [10, 90, 180, 1]);
  return {raw, width, height, roots, overlap: [first, second]};
}

async function withSource(fixture, key, run) {
  const bytes = await sharp(fixture.raw, {raw: {width: fixture.width, height: fixture.height, channels: 4}}).png().toBuffer();
  const source = path.join(ROOT, `art/source/characters/paris/sprites_v1/source_${key}.png`);
  const original = fs.readFileSync;
  fs.readFileSync = function(candidate, ...args) {
    return typeof candidate === 'string' && path.resolve(candidate) === source
      ? bytes : original.call(fs, candidate, ...args);
  };
  try {return await run(bytes);} finally {fs.readFileSync = original;}
}

function assertPackedReconstruction(packed, fixture) {
  const reconstructed = Buffer.alloc(fixture.raw.length);
  const coverage = new Uint8Array(fixture.width * fixture.height);
  let alphaOne = 0;
  for (const frame of packed.frames) {
    const [sourceX, sourceY, right, bottom] = frame.source_preserved_bbox;
    const [x0, y0, width, height] = frame.placement;
    assert.equal(width, right - sourceX); assert.equal(height, bottom - sourceY);
    const pixels = packed.raws[frame.index];
    for (let y = 0; y < height; y++) for (let x = 0; x < width; x++) {
      const outputOffset = ((y0 + y) * 512 + x0 + x) * 4;
      if (!pixels[outputOffset + 3]) continue;
      const sourcePixel = (sourceY + y) * fixture.width + sourceX + x;
      coverage[sourcePixel]++;
      alphaOne += pixels[outputOffset + 3] === 1;
      pixels.copy(reconstructed, sourcePixel * 4, outputOffset, outputOffset + 4);
    }
  }
  let expectedAlphaOne = 0;
  for (let pixel = 0; pixel < coverage.length; pixel++) {
    const alpha = fixture.raw[pixel * 4 + 3];
    assert.equal(coverage[pixel], alpha ? 1 : 0, 'Each original visible pixel belongs to exactly one prepared pose');
    expectedAlphaOne += alpha === 1;
  }
  assert.equal(alphaOne, expectedAlphaOne);
  assert.deepEqual(reconstructed, fixture.raw, 'The actual prepared frame pixels reconstruct all source RGBA bytes at scale 1');
}

for (const variant of ['E', 'N']) {
  test(`segmentation separates overlapping ${variant} pose boxes and preserves alpha=1 through packing`, async () => {
    const fixture = fixtureRGBA(variant);
    const key = `spectral_${variant}`;
    await withSource(fixture, key, async () => {
      const legacy = await build.inspect(key);
      assert(legacy.cells.some(cell => cell.border > 0), 'Nominal rectangles really do cut this fixture');
      await assert.rejects(build.prepare(legacy, {scale: 1, roots: fixture.roots}), /clipped|border/i);
      const inspected = await build.inspect(key, {segmentation: true});
      assert.equal(inspected.extraction_mode, 'segmentation');
      assert.equal(inspected.cells.length, 16);
      assert(inspected.cells.every(cell => cell.border === 0));
      const [first, second] = fixture.overlap.map(index => inspected.cells[index].window);
      assert(first[1] + first[3] > second[1], 'The source pose boxes still overlap vertically');
      assert.equal(inspected.source_window_coverage.omitted_nonzero_pixels, 0);
      assert.equal(inspected.source_window_coverage.duplicated_nonzero_pixels, 0);
      assert.equal(inspected.source_window_coverage.source_visible_rgba_sha256,
        inspected.source_window_coverage.reconstructed_visible_rgba_sha256);
      assert(inspected.source_window_coverage.preserved_alpha_one_pixels >= 18);
      assert.equal(inspected.segmentation.discarded_core_components, 0);
      assert(!JSON.stringify(inspected).includes('_segmentedPixels'), 'Working pixel ownership cannot leak into the manifest');
      const packed = await build.prepare(inspected, {segmentation: true, scale: 1, roots: fixture.roots});
      assertPackedReconstruction(packed, fixture);
      if (variant === 'N') {
        assert.equal(inspected.segmentation.principal_component_count, 17);
        assert.equal(inspected.segmentation.principal_groups[12].core_components.length, 2,
          'The detached bow belongs to the same pose instead of becoming a seventeenth frame');
      }
    });
  });
}

test('small opaque fragments attach to a principal while isolated faint pixels get deterministic owners', () => {
  const fixture = fixtureRGBA('E');
  const first = build.segmentSource(fixture.raw, fixture.width, fixture.height, 16);
  const second = build.segmentSource(fixture.raw, fixture.width, fixture.height, 16);
  assert.deepEqual(first.labels, second.labels);
  assert.equal(first.summary.attached_small_components.length, 1);
  assert.equal(first.summary.attached_small_components[0].frame_index, 3);
  assert.equal(first.labels[fixture.width + 1], 1, 'An alpha=1 island is preserved even without touching a core');
  assert.equal(first.labels[(fixture.height - 2) * fixture.width + fixture.width - 2], 16);
});

test('segmentation refuses missing principal poses rather than fabricating or borrowing a model', () => {
  const fixture = fixtureRGBA('E');
  for (let y = 0; y < 128; y++) for (let x = 256; x < 384; x++) fixture.raw.fill(0, (y * fixture.width + x) * 4, (y * fixture.width + x + 1) * 4);
  assert.throws(() => build.segmentSource(fixture.raw, fixture.width, fixture.height, 16), /missing principal.*2/i);
  assert.throws(() => build.segmentSource(Buffer.alloc(8), 2, 2, 16), /RGBA dimensions/);
});

test('the same segmentation contract supports eight transformation poses and rejects implicit modes', async () => {
  const fixture = fixtureRGBA('E', 8);
  await withSource(fixture, 'transform_ALL', async () => {
    const inspected = await build.inspect('transform_ALL', {segmentation: true});
    assert.equal(inspected.cells.length, 8);
    assert.deepEqual(inspected.segmentation.source_grid, [4, 2]);
    const packed = await build.prepare(inspected, {segmentation: true, scale: 1, roots: fixture.roots});
    assertPackedReconstruction(packed, fixture);
    await assert.rejects(build.inspect('transform_ALL', {segmentation: 'yes'}), /explicit boolean/);
  });
});
