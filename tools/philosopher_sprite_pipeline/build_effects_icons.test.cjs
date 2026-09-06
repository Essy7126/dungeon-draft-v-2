'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const pipeline = require('./build_effects.cjs');

test('five spell icons reference the matching authored effect at peak phase', () => {
  const atlas = 'res://assets/vfx/philosopher_mage/sprites_v1/effects.png';
  const icons = pipeline.iconResources(atlas);
  assert.deepEqual(Object.keys(icons), ['axiom', 'refutation', 'mending', 'aporia', 'aegis']);
  for (const [name, row] of Object.entries({ axiom: 0, refutation: 5, mending: 2, aporia: 3, aegis: 4 })) {
    assert.ok(icons[name].includes('path="' + atlas + '"'));
    assert.ok(icons[name].includes('region = Rect2(512, ' + row * 256 + ', 256, 256)'));
    assert.equal((icons[name].match(/\[ext_resource /g) || []).length, 1);
    assert.ok(!icons[name].includes('flip') && !icons[name].includes('rotation'));
  }
});

test('resource cadence matches runtime bursts while holds stay non-looping', () => {
  const resource = pipeline.resourceText('res://effects.png');
  assert.ok(resource.includes('"name": &"bolt",\n"speed": 20.000000'));
  assert.ok(resource.includes('"name": &"heal",\n"speed": 8.333333'));
  assert.ok(resource.includes('"name": &"shield",\n"speed": 13.333333'));
  assert.equal((resource.match(/"loop": false/g) || []).length, 6);
});
