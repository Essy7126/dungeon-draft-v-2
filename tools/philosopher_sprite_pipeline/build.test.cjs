'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const { spriteFrames, checkedAlignment, GROUPS } = require('./build.cjs');
const root = path.resolve(__dirname, '../..');
const output = path.join(root, 'assets/characters/philosopher_mage/sprites_v1');
const prepared = Object.entries(GROUPS).flatMap(([group, value]) => ['N','E','S','W'].map(direction => ({ key: `${group}_${direction}`, group, direction, count: value.count })));
const sha = data => crypto.createHash('sha256').update(data).digest('hex');

test('all four orientations contain exactly eight complete animation families', () => {
  const result = spriteFrames(prepared);
  assert.equal(result.count, 32);
  for (const direction of ['N','E','S','W']) for (const stem of ['idle','walk','attack','heal','control','shield','hit','death']) {
    assert.equal(result.text.split(`"name": &"${stem}_${direction}"`).length - 1, 1);
  }
  assert.equal((result.text.match(/sub_resource type="AtlasTexture"/g) || []).length, 128);
});

test('invalid replacement textures fail instead of silently falling back', () => {
  for (const ref of ['extra_N_16','extra_N_-1','unknown_N_0','extra_Q_0','missing']) {
    assert.throws(() => spriteFrames(prepared, { heal_N: { 2: ref } }), /Invalid frame reference/);
  }
});

test('all source roots are explicit, finite and use one shared scale per sheet', () => {
  const alignment = JSON.parse(fs.readFileSync(path.join(__dirname, 'alignment.json'), 'utf8'));
  for (const item of prepared) {
    const actual = checkedAlignment(item.key, alignment);
    assert.equal(actual.roots.length, 16);
    assert(actual.scale > 0.7 && actual.scale < 0.95);
  }
  assert.throws(() => checkedAlignment('base_N', { base_N: { scale: 1, roots: [[0,0]] } }), /16 explicit/);
  assert.throws(() => checkedAlignment('base_N', { base_N: { scale: 0, roots: [] } }), /positive shared scale/);
});

test('committed sprite resource is reproducible and excludes the four rejected poses', () => {
  const alignment = JSON.parse(fs.readFileSync(path.join(__dirname, 'alignment.json'), 'utf8'));
  const actual = fs.readFileSync(path.join(output, 'philosopher_sprite_frames.tres'), 'utf8');
  assert.equal(actual, spriteFrames(prepared, alignment.clip_overrides).text);
  for (const ref of ['base_N_14','extra_S_2','extra_N_2','extra_W_2']) assert(!actual.includes(`"texture": SubResource("${ref}")`));
  const manifest = JSON.parse(fs.readFileSync(path.join(output, 'manifest.json'), 'utf8'));
  assert.equal(manifest.sprite_frames_sha256, sha(actual));
  assert.equal(manifest.complete, true);
  assert.equal(manifest.animation_count, 32);
});

test('all authored atlas files match inspected transparent nonclipped source manifests', () => {
  const manifest = JSON.parse(fs.readFileSync(path.join(output, 'manifest.json'), 'utf8'));
  assert.equal(manifest.sheets.length, 8);
  for (const sheet of manifest.sheets) {
    assert.equal(sheet.valid, true);
    assert.equal(sheet.atlas_regions_verified, 16);
    assert(sheet.source_alpha.transparent_fraction > 0.35);
    assert(sheet.source_alpha.max_removed_alpha <= 32);
    assert.equal(sheet.source_sha256, sha(fs.readFileSync(path.join(root, sheet.source))));
    assert.equal(sheet.atlas_sha256, sha(fs.readFileSync(path.join(root, sheet.atlas))));
    for (const frame of sheet.frames) {
      assert.equal(frame.border_core_pixels, 0);
      assert(frame.output_core_pixels > 500);
      assert(frame.root_quantization_error.every(value => Math.abs(value) <= 1.2));
    }
  }
});
