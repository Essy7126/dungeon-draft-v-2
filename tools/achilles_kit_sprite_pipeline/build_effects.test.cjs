'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');
const crypto = require('node:crypto');
const sharp = require(process.env.SHARP_PATH || 'C:/Users/paolo/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const pipeline = require('./build_effects.cjs');
const ROOT = path.resolve(__dirname, '../..');
const sha = value => crypto.createHash('sha256').update(value).digest('hex');

async function fixture(t, alteration = '') {
  const base = path.resolve(os.tmpdir());
  const directory = fs.mkdtempSync(path.join(base, 'achilles-effects-pipeline-'));
  t.after(() => {
    const resolved = path.resolve(directory);
    assert.equal(path.dirname(resolved), base);
    assert.match(path.basename(resolved), /^achilles-effects-pipeline-/);
    fs.rmSync(resolved, { recursive: true, force: true });
  });
  const cell = 128, width = cell * 4, height = cell * 6;
  const raw = Buffer.alloc(width * height * 4);
  for (let row = 0; row < 6; row++) for (let column = 0; column < 4; column++) {
    // Synthetic fixtures only: known main pixels and a detached, low-alpha
    // sample ensure the extractor cannot silently discard disconnected art.
    for (let y = 52; y < 72; y++) for (let x = 38 + column * 3; x < 78 + column * 3; x++) {
      const index = ((row * cell + y) * width + column * cell + x) * 4;
      raw[index] = 190; raw[index + 1] = 128 + row * 5; raw[index + 2] = 80; raw[index + 3] = 255;
    }
    const spark = ((row * cell + 6) * width + column * cell + 120) * 4;
    raw[spark] = 255; raw[spark + 1] = 232; raw[spark + 2] = 180; raw[spark + 3] = 96;
  }
  if (alteration === 'opaque') for (let index = 3; index < raw.length; index += 4) raw[index] = 255;
  if (alteration === 'edge') raw[3] = 1;
  if (alteration === 'strong_edge') raw[3] = 33;
  const input = path.join(directory, 'source.png');
  await sharp(raw, { raw: { width, height, channels: 4 } }).png().toFile(input);
  return { input, raw, width, height };
}

test('grid extraction keeps detached alpha and one stable transform per row', async t => {
  const input = await fixture(t);
  const result = await pipeline.prepare(input.input);
  assert.equal(result.manifest.frames.length, 24);
  assert.equal(result.manifest.rows.length, 6);
  assert.deepEqual(result.manifest.animation_order, ['arrow', 'impact', 'sweep', 'guard', 'dust', 'barrier']);
  for (const frame of result.manifest.frames) {
    assert.equal(frame.source_alpha.partial_alpha_pixels, 1);
    assert.equal(frame.source_alpha.alpha_sum, frame.cropped_alpha_sum);
    assert.ok(Math.min(...frame.packed_alpha.margins.all) >= 12);
  }
  for (const row of result.manifest.rows) {
    assert.deepEqual(row.source_anchor, [64, 64]);
    assert.deepEqual(row.output_anchor, [128, 128]);
    assert.equal(row.per_frame_recentering, false);
  }
  // A visible authored translation must survive; fitting every frame would
  // hide it. The measured displacement follows the row's common scale.
  const first = result.manifest.frames[0], last = result.manifest.frames[3];
  const sourceDelta = last.source_alpha.alpha_centroid[0] - first.source_alpha.alpha_centroid[0];
  const outputDelta = last.packed_alpha.alpha_centroid[0] - first.packed_alpha.alpha_centroid[0];
  assert.ok(Math.abs(outputDelta - sourceDelta * result.manifest.rows[0].common_scale) < 0.15);
});

test('atlas is deterministic and each 256-square region matches its manifest hash', async t => {
  const input = await fixture(t);
  const first = await pipeline.prepare(input.input);
  const second = await pipeline.prepare(input.input);
  assert.ok(first.atlas.equals(second.atlas));
  const { data, info } = await sharp(first.atlas).raw().toBuffer({ resolveWithObject: true });
  assert.deepEqual([info.width, info.height, info.channels], [1024, 1536, 4]);
  for (let index = 0; index < 24; index++) {
    const region = pipeline.extractRaw(data, info.width, {
      left: index % 4 * 256, top: Math.floor(index / 4) * 256, width: 256, height: 256,
    });
    assert.equal(sha(region), first.manifest.frames[index].packed_rgba_sha256);
  }
});

test('opaque backgrounds and even one clipped alpha pixel are rejected', async t => {
  const opaque = await fixture(t, 'opaque');
  const clipped = await fixture(t, 'edge');
  await assert.rejects(pipeline.prepare(opaque.input), /transparent pixels/);
  await assert.rejects(pipeline.prepare(clipped.input), /cell boundary/);
});

test('RGB sources and non-square or misaligned grid dimensions are rejected', async t => {
  const input = await fixture(t);
  const rgb = path.join(path.dirname(input.input), 'rgb.png');
  await sharp(input.input).removeAlpha().png().toFile(rgb);
  await assert.rejects(pipeline.prepare(rgb), /real 8-bit RGBA/);
  const wrong = path.join(path.dirname(input.input), 'wrong.png');
  await sharp(input.input).resize(512, 770).png().toFile(wrong);
  await assert.rejects(pipeline.prepare(wrong), /4 × 6 square cells/);
});

test('resource references exactly 24 frames and six non-looping authored animations', () => {
  const resource = pipeline.resourceText('res://assets/vfx/achilles_kit_v2/effects.png');
  assert.equal((resource.match(/\[sub_resource type="AtlasTexture"/g) || []).length, 24);
  assert.equal((resource.match(/"loop": false/g) || []).length, 6);
  for (const name of ['arrow', 'impact', 'sweep', 'guard', 'dust', 'barrier']) {
    assert.equal((resource.match(new RegExp(`"name": &"${name}"`, 'g')) || []).length, 1);
  }
  assert.match(resource, /region = Rect2\(768, 1280, 256, 256\)/);
  assert.match(resource, /load_steps=26/);
});

test('inspect writes nothing and invalid builds do not replace an existing atlas', async t => {
  const input = await fixture(t);
  const relative = `artifacts/achilles_effects_pipeline_test_${process.pid}`;
  const output = path.resolve(ROOT, relative);
  assert.equal(path.dirname(output), path.join(ROOT, 'artifacts'));
  assert.ok(!fs.existsSync(output), 'Fixture output must be new.');
  t.after(() => {
    assert.equal(path.dirname(output), path.join(ROOT, 'artifacts'));
    assert.match(path.basename(output), /^achilles_effects_pipeline_test_\d+$/);
    fs.rmSync(output, { recursive: true, force: true });
  });
  await pipeline.build({ source: input.input, output: relative, inspect: true });
  assert.equal(fs.existsSync(output), false);
  await pipeline.build({ source: input.input, output: relative });
  const old = fs.readFileSync(path.join(output, 'effects.png'));
  assert.ok(fs.existsSync(path.join(output, 'effects.tres')));
  const invalid = await fixture(t, 'edge');
  await assert.rejects(pipeline.build({ source: invalid.input, output: relative }), /cell boundary/);
  assert.ok(old.equals(fs.readFileSync(path.join(output, 'effects.png'))));
});

test('unsafe output paths and unknown flags fail explicitly', () => {
  assert.throws(() => pipeline.outputLocation('../outside-project'), /inside the project/);
  assert.throws(() => pipeline.outputLocation('.git/effects'), /inside the project/);
  assert.throws(() => pipeline.options(['--alpha-key', 'white']), /Unknown option/);
  assert.throws(() => pipeline.options(['--source']), /requires a path/);
});

function explicitLayout(input) {
  return {
    source_sha256: sha(fs.readFileSync(input.input)), source_size: [input.width, input.height],
    bands: [[0,125],[125,258],[258,386],[386,514],[514,645],[645,768]],
    columns: Array.from({length:6}, () => [0,124,252,384,512]),
    centers: Array.from({length:6}, (_,row) => Array.from({length:4}, (_,col) => [64+col*128,64+row*128])),
    boundary_cleaning: {width:1,maximum_alpha:32},
  };
}

test('explicit irregular windows preserve declared centers, all strong pixels and interior sparks', async t => {
  const input = await fixture(t, 'edge');
  const layout = explicitLayout(input), before = JSON.stringify(layout);
  const result = await pipeline.prepare(input.input, layout);
  assert.equal(JSON.stringify(layout), before);
  assert.equal(result.manifest.boundary_cleaning.pixels_removed, 1);
  assert.equal(result.manifest.boundary_cleaning.alpha_sum_removed, 1);
  assert.equal(result.manifest.boundary_cleaning.maximum_alpha_removed, 1);
  assert.equal(result.manifest.boundary_cleaning.pixels_above_32_removed, 0);
  for (const frame of result.manifest.frames) {
    assert.equal(frame.source_original_alpha.alpha_sum - frame.source_alpha.alpha_sum,
      frame.boundary_cleaning.alpha_sum_removed);
    assert.equal(frame.source_alpha.alpha_sum, frame.cropped_alpha_sum);
    assert.deepEqual(frame.source_original_alpha.alpha_histogram.slice(33), frame.source_alpha.alpha_histogram.slice(33));
    assert.ok(frame.source_alpha.alpha_histogram[96] >= 1, 'Interior detached sample is untouched.');
    const row = result.manifest.rows[Math.floor(result.manifest.frames.indexOf(frame)/4)];
    const projected = frame.source_anchor.map((value, index) =>
      12 + (value - (index ? frame.common_anchor_crop.top : frame.common_anchor_crop.left)) * 232 / row.common_local_crop.width);
    assert.deepEqual(projected, [128,128]);
  }
});

test('manual layout still rejects any boundary alpha above32 and stale source hashes', async t => {
  const input = await fixture(t, 'strong_edge');
  const layout = explicitLayout(input);
  await assert.rejects(pipeline.prepare(input.input, layout), /cut crosses alpha 33/);
  layout.source_sha256 = 'stale';
  await assert.rejects(pipeline.prepare(input.input, layout), /another source SHA-256/);
});

test('manual layout rejects gaps overlaps unsafe cleaning and undeclared centers', async t => {
  const input = await fixture(t);
  const layout = explicitLayout(input);
  layout.bands[1][0] = 126;
  await assert.rejects(pipeline.prepare(input.input, layout), /contiguous band/);
  layout.bands[1][0] = 125;
  layout.boundary_cleaning.maximum_alpha = 33;
  await assert.rejects(pipeline.prepare(input.input, layout), /limited to one pixel/);
  layout.boundary_cleaning.maximum_alpha = 32;
  layout.centers[0][0] = [500,64];
  await assert.rejects(pipeline.prepare(input.input, layout), /Invalid declared center/);
});
