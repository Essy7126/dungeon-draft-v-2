import test from 'node:test';
import assert from 'node:assert/strict';
import { config, variant } from '../simulate.mjs';
import { monotonicViolations, monotonicCandidate, numberArray, progression, independentAtLeastOne,
  bagVariance, relativeSampleSize, duplicateGroups } from './systems_math.mjs';
test('progression contract catches both regressions in historical early_supply', () => {
  assert.deepEqual(monotonicViolations(config), []);
  assert.deepEqual(monotonicViolations(variant(config, 'early_supply')).map(x=>x.channel), ['normal_a','normal_b']);
  assert.deepEqual(monotonicViolations(monotonicCandidate()), []);
  assert.equal(config.rates[0][0], .55);
});
test('XP boundaries apply reward after the fight and handle multiple levels', () => {
  const rows = progression([100, 300], [1, 3], [0, 100, 220, 360], [10,20,30,40], [1,2,3,4]);
  assert.deepEqual(rows.map(x=>[x.level_before,x.level_after]), [[1,2],[2,4]]);
  assert.equal(rows[1].prowess_before, 2);
});
test('source parsing fails explicitly on schema changes', () => {
  assert.deepEqual(numberArray('const XP := [0, 100, 220]', 'XP'), [0,100,220]);
  assert.deepEqual(numberArray('hp = PackedInt32Array(1, 2)', 'hp','resource'), [1,2]);
  assert.throws(()=>numberArray('const XP := [0, nope]', 'XP'));
  assert.throws(()=>numberArray('', 'XP'));
});
test('equal expected cards do not imply equal bag variance', () => {
  assert.equal(bagVariance(.5,3), 3 * 3 * bagVariance(.5,1));
  assert.equal(independentAtLeastOne(.5,3), .875);
  assert.equal(relativeSampleSize(.5,.2), 97);
});
test('duplicate audit matches numeric shape while preserving identities', () => {
  const text = '["a", "one", "A", 1, 1, 2, 0., "move", 2, "Role"],\n["b", "two", "B", 1, 1, 2, 0., "move", 2, "Other"],\n["c", "two", "C", 2, 1, 2, 0., "move", 2, "Role"],';
  const result = duplicateGroups(text);
  assert.equal(result.examined_rows,3); assert.equal(result.groups.length,1);
  assert.deepEqual(result.groups[0].members.map(x=>x.id),['a','b']);
});
