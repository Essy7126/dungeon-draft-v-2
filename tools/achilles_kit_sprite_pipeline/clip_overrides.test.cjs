'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { checkedClipOverrides, spriteFrames, GROUPS, DIRECTIONS } = require('./build.cjs');

function fixture() {
  const prepared = Object.entries(GROUPS).flatMap(([group, definition]) => DIRECTIONS.map(direction => ({
    group, direction, key: `${group}_${direction}`, count: definition.count,
    atlas: Buffer.from(`unchanged atlas ${group}_${direction}`),
  })));
  const originalBlocks = DIRECTIONS.flatMap(direction => ['idle', 'walk', 'attack'].map(stem =>
    `{\n"frames": [{"duration": 1.0, "texture": SubResource("Idle_${direction}")}],\n"loop": ${stem !== 'attack'},\n"name": &"${stem}_${direction}",\n"speed": 8.0\n}`));
  const legacy = {
    header: '[ext_resource type="Texture2D" path="res://unchanged.png" id="Legacy_atlas"]\n\n'
      + DIRECTIONS.map(direction => `[sub_resource type="AtlasTexture" id="Legacy_Idle_${direction}"]\natlas = ExtResource("Legacy_atlas")\nregion = Rect2(0, 0, 512, 384)\n\n`).join(''),
    resourceCount: 5, originalBlocks,
    blocks: originalBlocks.map(value => value.replace(/SubResource\("([^\"]+)"\)/g, 'SubResource("Legacy_$1")')),
    idle: Object.fromEntries(DIRECTIONS.map(direction => [direction, { id: `Legacy_Idle_${direction}` }])),
  };
  return { prepared, legacy };
}

test('explicit volley release override changes exactly one texture reference', () => {
  const { prepared, legacy } = fixture();
  const preparedBefore = JSON.stringify(prepared);
  const original = spriteFrames(prepared, legacy);
  const definition = { volley_N: { 3: { group: 'base', direction: 'N', index: 6 } } };
  const inputBefore = JSON.stringify(definition);
  const result = spriteFrames(prepared, legacy, definition);
  assert.equal(result.count, 40);
  assert.equal(result.text, original.text.replace('"texture": SubResource("Kit_extra_N_6")',
    '"texture": SubResource("Kit_base_N_6")'));
  assert.equal(JSON.stringify(prepared), preparedBefore);
  assert.equal(JSON.stringify(definition), inputBefore);
  assert.equal(result.clip_overrides.length, 1);
  const trace = result.clip_overrides[0];
  assert.deepEqual([trace.clip, trace.frame_index], ['volley_N', 3]);
  assert.equal(trace.original.resource_id, 'Kit_extra_N_6');
  assert.equal(trace.replacement.resource_id, 'Kit_base_N_6');
  assert.equal(trace.replacement.atlas, 'assets/characters/Achilles/sprites_kit_v2/atlas_base_N.png');
  // Both AtlasTexture declarations remain intact; no atlas is rewritten.
  assert.ok(result.text.includes('[sub_resource type="AtlasTexture" id="Kit_extra_N_6"]'));
  assert.ok(result.text.includes('[sub_resource type="AtlasTexture" id="Kit_base_N_6"]'));
});

test('absent and empty override definitions produce identical resources', () => {
  const { prepared, legacy } = fixture();
  const plain = spriteFrames(prepared, legacy);
  assert.deepEqual(spriteFrames(prepared, legacy, {}), plain);
  assert.deepEqual(plain.clip_overrides, []);
});

test('legacy clips and canonical idle bookends cannot be overridden', () => {
  const { prepared } = fixture();
  const source = { group: 'base', direction: 'N', index: 6 };
  assert.throws(() => checkedClipOverrides(prepared, { idle_N: { 0: source } }), /legacy clips/);
  assert.throws(() => checkedClipOverrides(prepared, { volley_N: { 0: source } }), /idle bookends/);
  assert.throws(() => checkedClipOverrides(prepared, { volley_N: { 5: source } }), /idle bookends/);
});

test('clip names and final zero-based frame bounds are validated', () => {
  const { prepared } = fixture();
  const source = { group: 'base', direction: 'N', index: 6 };
  assert.throws(() => checkedClipOverrides(prepared, { volley_Q: { 3: source } }), /unknown or unavailable/);
  for (const key of ['-1', '3.0', '03', 'NaN']) {
    assert.throws(() => checkedClipOverrides(prepared, { volley_N: { [key]: source } }), /canonical non-negative integer/);
  }
  assert.throws(() => checkedClipOverrides(prepared, { volley_N: { 6: source } }), /outside the final 6-frame/);
  assert.throws(() => checkedClipOverrides(prepared, { dash_N: { 4: source } }), /outside the final 4-frame/);
});

test('source group direction index and availability are validated', () => {
  const { prepared } = fixture();
  for (const source of [
    { group: 'other', direction: 'N', index: 6 },
    { group: 'base', direction: 'north', index: 6 },
  ]) assert.throws(() => checkedClipOverrides(prepared, { volley_N: { 3: source } }), /invalid source/);
  for (const index of [-1, 12, 1.5, '6']) {
    assert.throws(() => checkedClipOverrides(prepared, { volley_N: { 3: { group: 'base', direction: 'N', index } } }), /source index/);
  }
  assert.throws(() => checkedClipOverrides(prepared.filter(item => item.key !== 'base_N'), {
    volley_N: { 3: { group: 'base', direction: 'N', index: 6 } },
  }), /source sheet base_N is unavailable/);
});

test('invalid schemas fail and explicit reasons remain traceable', () => {
  const { prepared } = fixture();
  for (const bad of [null, [], 'volley_N']) assert.throws(() => checkedClipOverrides(prepared, bad), /must be an object/);
  assert.throws(() => checkedClipOverrides(prepared, { volley_N: [] }), /must be an object/);
  assert.throws(() => checkedClipOverrides(prepared, { volley_N: { 3: null } }), /replacement requires/);
  assert.throws(() => checkedClipOverrides(prepared, { volley_N: {
    3: { group: 'base', direction: 'N', index: 6, flip: true },
  } }), /unknown replacement field flip/);
  const result = checkedClipOverrides(prepared, { volley_N: {
    3: { group: 'base', direction: 'N', index: 6, reason: 'Keep the authored back shield at release.' },
  } });
  assert.equal(result[0].reason, 'Keep the authored back shield at release.');
});

test('unbookended clips accept their real first frame and preserve other mappings', () => {
  const { prepared, legacy } = fixture();
  const original = spriteFrames(prepared, legacy);
  const result = spriteFrames(prepared, legacy, { dash_N: { 0: { group: 'base', direction: 'N', index: 1 } } });
  assert.equal(result.clip_overrides[0].original.index, 0);
  assert.equal(result.text, original.text.replace('"texture": SubResource("Kit_base_N_0")',
    '"texture": SubResource("Kit_base_N_1")'));
});
