#!/usr/bin/env node
'use strict';
// Mechanical packing only; all artwork is authored in the ImageGen sources.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
let sharp;
try { sharp = require('sharp'); } catch {
  sharp = require(process.env.SHARP_PATH || 'C:/Users/paolo/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
}
const ROOT = path.resolve(__dirname, '../..');
const SOURCE = 'art/source/characters/philosopher_mage/sprites_v1';
const OUTPUT = 'assets/characters/philosopher_mage/sprites_v1';
const DIRECTIONS = ['N', 'E', 'S', 'W'];
const WIDTH = 512, HEIGHT = 384, ANCHOR = [256, 320], COLS = 4;
const CORE_ALPHA = 32, EDGE_RADIUS = 2;
const GROUPS = {
  base: { rows: 4, count: 16, clips: {
    idle: { indices: [0], duration: 1, loop: true },
    walk: { indices: [1,2,3,4,5,6,7], duration: 0.8, loop: true },
    attack: { indices: [8,9,10,11], duration: 0.64, release: 0.32 },
    heal: { indices: [12,13,14,15], duration: 0.80, release: 0.40 },
  } },
  extra: { rows: 4, count: 16, clips: {
    control: { indices: [0,1,2,3], duration: 0.72, release: 0.36 },
    shield: { indices: [4,5,6,7], duration: 0.64, release: 0.32 },
    hit: { indices: [8,9,10,11], duration: 0.24 },
    death: { indices: [12,13,14,15], duration: 0.52 },
  } },
};
const KEYS = Object.keys(GROUPS).flatMap(group => DIRECTIONS.map(direction => `${group}_${direction}`));
const sha = buffer => crypto.createHash('sha256').update(buffer).digest('hex');
const round = number => Math.round(number * 1000000) / 1000000;
const toResourcePath = relative => `res://${relative.replaceAll('\\', '/')}`;

function options(argv) {
  const parsed = { inspect: false, allowPartial: false, minComponentPixels: 2000 };
  for (let index = 0; index < argv.length; index++) {
    const arg = argv[index];
    if (arg === '--inspect') parsed.inspect = true;
    else if (arg === '--allow-partial') parsed.allowPartial = true;
    else if (arg === '--min-component-pixels') {
      parsed.minComponentPixels = Number(argv[++index]);
      if (!Number.isInteger(parsed.minComponentPixels) || parsed.minComponentPixels < 1) {
        throw Error('--min-component-pixels requires a positive integer');
      }
    } else if (arg === '--help' || arg === '-h') {
      console.log('node tools/philosopher_sprite_pipeline/build.cjs [--inspect] [--allow-partial] [--min-component-pixels 2000]');
      process.exit(0);
    } else throw Error(`Unknown option ${arg}; use --help`);
  }
  return parsed;
}

function extractComponents(data, width, height, minPixels) {
  const labels = new Int32Array(width * height);
  const stack = new Int32Array(width * height);
  const components = [];
  let identifier = 0;
  for (let start = 0; start < labels.length; start++) {
    if (labels[start] || data[start * 4 + 3] <= CORE_ALPHA) continue;
    const component = { id: ++identifier, count: 0, bbox: [width, height, 0, 0], sx: 0, sy: 0, pixels: [] };
    let pending = 0;
    stack[pending++] = start;
    labels[start] = identifier;
    while (pending) {
      const pixel = stack[--pending], x = pixel % width, y = Math.floor(pixel / width);
      component.count++;
      component.sx += x;
      component.sy += y;
      component.pixels.push(pixel);
      component.bbox[0] = Math.min(component.bbox[0], x);
      component.bbox[1] = Math.min(component.bbox[1], y);
      component.bbox[2] = Math.max(component.bbox[2], x + 1);
      component.bbox[3] = Math.max(component.bbox[3], y + 1);
      for (let dy = -1; dy <= 1; dy++) for (let dx = -1; dx <= 1; dx++) {
        const nx = x + dx, ny = y + dy;
        if (nx < 0 || ny < 0 || nx >= width || ny >= height) continue;
        const neighbor = ny * width + nx;
        if (labels[neighbor] || data[neighbor * 4 + 3] <= CORE_ALPHA) continue;
        labels[neighbor] = identifier;
        stack[pending++] = neighbor;
      }
    }
    component.center = [component.sx / component.count, component.sy / component.count];
    components.push(component);
  }

  const selected = components.filter(component => component.count >= minPixels);
  const validIds = new Set(selected.map(component => component.id));
  for (let pixel = 0; pixel < labels.length; pixel++) if (!validIds.has(labels[pixel])) labels[pixel] = 0;
  // Retain each source RGBA value in the connected core and the two-pixel edge
  // neighborhood. There is no background-color key and no alpha thresholding
  // of the retained pixels themselves.
  const retained = labels.slice();
  for (const component of selected) for (const pixel of component.pixels) {
    const x = pixel % width, y = Math.floor(pixel / width);
    for (let dy = -EDGE_RADIUS; dy <= EDGE_RADIUS; dy++) for (let dx = -EDGE_RADIUS; dx <= EDGE_RADIUS; dx++) {
      const nx = x + dx, ny = y + dy;
      if (nx < 0 || ny < 0 || nx >= width || ny >= height) continue;
      const neighbor = ny * width + nx;
      if (!data[neighbor * 4 + 3] || retained[neighbor]) continue;
      retained[neighbor] = component.id;
    }
  }
  return {
    components: selected,
    labels: retained,
    discardedCoreComponents: components.filter(component => component.count < minPixels)
      .map(component => ({ pixels: component.count, bbox: component.bbox })),
  };
}

function summarizeAlpha(data, labels) {
  const result = { zero: 0, full: 0, partial: 0, removed_pixels: 0, removed_alpha_sum: 0, max_removed_alpha: 0 };
  for (let pixel = 0; pixel < labels.length; pixel++) {
    const alpha = data[pixel * 4 + 3];
    if (!alpha) result.zero++;
    else if (alpha === 255) result.full++;
    else result.partial++;
    if (alpha && !labels[pixel]) {
      result.removed_pixels++;
      result.removed_alpha_sum += alpha;
      result.max_removed_alpha = Math.max(result.max_removed_alpha, alpha);
    }
  }
  result.transparent_fraction = round(result.zero / labels.length);
  return result;
}

async function inspectDirection(key, minPixels) {
  const [group, direction] = key.split('_');
  const { rows: ROWS, count: FRAME_COUNT } = GROUPS[group];
  const source = `${SOURCE}/source_${group}_${direction}.png`;
  const original = fs.readFileSync(path.join(ROOT, source));
  const metadata = await sharp(original).metadata();

  const { data, info } = await sharp(original).ensureAlpha().raw().toBuffer({ resolveWithObject: true });
  const { width, height } = info;
  const segmentation = extractComponents(data, width, height, minPixels);
  const ordered = Array(FRAME_COUNT).fill(null);
  const errors = [];
  if (!metadata.hasAlpha) errors.push('Source lacks a real alpha channel');
  if (segmentation.components.length !== FRAME_COUNT && !(key === 'base_N' && segmentation.components.length === 17)) errors.push(`Expected ${FRAME_COUNT} full sprites, found ${segmentation.components.length}`);
  for (const component of segmentation.components) {
    const col = Math.min(COLS - 1, Math.floor(component.center[0] / (width / COLS)));
    const row = Math.min(ROWS - 1, Math.floor(component.center[1] / (height / ROWS)));
    const index = row * COLS + col;
    Object.assign(component, { col, row, index });
    if (ordered[index]) {
      // Explicit art review: rejected healing drawing N/14 contains a detached
      // staff. Preserve both source parts in its unused atlas cell; never erase
      // an opaque prop or silently merge parts in another cell.
      if (key !== 'base_N' || index !== 14) { errors.push(`Ambiguous source cell ${index}`); continue; }
      const primary = ordered[index];
      for (let p = 0; p < segmentation.labels.length; p++) if (segmentation.labels[p] === component.id) segmentation.labels[p] = primary.id;
      primary.bbox = [Math.min(primary.bbox[0], component.bbox[0]), Math.min(primary.bbox[1], component.bbox[1]), Math.max(primary.bbox[2], component.bbox[2]), Math.max(primary.bbox[3], component.bbox[3])];
      primary.count += component.count; primary.sx += component.sx; primary.sy += component.sy;
      primary.center = [primary.sx / primary.count, primary.sy / primary.count];
      primary.merged_source_parts = [primary.id, component.id];
    } else ordered[index] = component;
  }
  if (ordered.some(component => !component)) errors.push('At least one source cell has no complete connected sprite');
  const alpha = summarizeAlpha(data, segmentation.labels);
  if (alpha.transparent_fraction < 0.35) errors.push('Suspiciously opaque background');
  if (alpha.max_removed_alpha > CORE_ALPHA) errors.push(`Removing isolated opaque content is forbidden (alpha ${alpha.max_removed_alpha})`);
  const summary = {
    key, group, direction, source_grid: [COLS, ROWS], source, source_sha256: sha(original), source_dimensions: [width, height],
    source_alpha: alpha,
    segmentation: {
      alpha_threshold: CORE_ALPHA, min_component_pixels: minPixels,
      edge_preservation_radius: EDGE_RADIUS,
      discarded_core_components: segmentation.discardedCoreComponents,
    },
    valid: errors.length === 0, errors,
    components: ordered.filter(Boolean).map(component => ({
      index: component.index, source_cell: [component.col, component.row],
      core_pixels: component.count, source_core_bbox: component.bbox,
      source_center: component.center.map(round),
    })).sort((a, b) => a.index - b.index),
  };
  return { key, group, direction, rows: ROWS, count: FRAME_COUNT, data, width, height, labels: segmentation.labels, ordered, summary };
}

function checkedAlignment(key, alignment) {
  const [group, direction] = key.split('_');
  const FRAME_COUNT = GROUPS[group].count;
  const selected = alignment[key] || alignment[group]?.[direction];
  if (!selected || !Number.isFinite(selected.scale) || selected.scale <= 0) {
    throw Error(`${key}: alignment.json requires a positive shared scale`);
  }
  if (!Array.isArray(selected.roots) || selected.roots.length !== FRAME_COUNT || selected.roots.some(root =>
    !Array.isArray(root) || root.length !== 2 || root.some(value => !Number.isFinite(value)))) {
    throw Error(`${key}: alignment.json requires ${FRAME_COUNT} explicit [sourceGlobalX, sourceGlobalY] roots`);
  }
  return selected;
}

async function prepareDirection(inspected, alignment) {
  const { key, group, direction, data, width, height, labels, ordered } = inspected;
  const { rows: ROWS, count: FRAME_COUNT } = GROUPS[group];
  if (!inspected.summary.valid) throw Error(`${direction}: ${inspected.summary.errors.join('; ')}`);
  const scale = alignment.scale;
  const buffers = [], frameRaws = [], frames = [];
  for (const component of ordered) {
    const index = component.index, root = alignment.roots[index];
    let bx = width, by = height, ex = 0, ey = 0;
    for (let y = Math.max(0, component.bbox[1] - EDGE_RADIUS); y < Math.min(height, component.bbox[3] + EDGE_RADIUS); y++) {
      for (let x = Math.max(0, component.bbox[0] - EDGE_RADIUS); x < Math.min(width, component.bbox[2] + EDGE_RADIUS); x++) {
        if (labels[y * width + x] !== component.id) continue;
        bx = Math.min(bx, x); by = Math.min(by, y); ex = Math.max(ex, x + 1); ey = Math.max(ey, y + 1);
      }
    }
    const sourceWidth = ex - bx, sourceHeight = ey - by;
    const pixels = Buffer.alloc(sourceWidth * sourceHeight * 4);
    for (let y = by; y < ey; y++) for (let x = bx; x < ex; x++) {
      if (labels[y * width + x] !== component.id) continue;
      const sourceOffset = (y * width + x) * 4;
      data.copy(pixels, ((y - by) * sourceWidth + x - bx) * 4, sourceOffset, sourceOffset + 4);
    }
    const resizedWidth = Math.max(1, Math.round(sourceWidth * scale));
    const resizedHeight = Math.max(1, Math.round(sourceHeight * scale));
    const left = Math.round(ANCHOR[0] + (bx - root[0]) * scale);
    const top = Math.round(ANCHOR[1] + (by - root[1]) * scale);
    if (left < 0 || top < 0 || left + resizedWidth > WIDTH || top + resizedHeight > HEIGHT) {
      throw Error(`${direction}/${index}: source would clip canvas at ${[left, top, resizedWidth, resizedHeight]}; review shared scale or explicit root`);
    }
    const resized = await sharp(pixels, { raw: { width: sourceWidth, height: sourceHeight, channels: 4 } })
      .resize(resizedWidth, resizedHeight, { kernel: 'lanczos3' }).raw().toBuffer();
    const raw = Buffer.alloc(WIDTH * HEIGHT * 4);
    for (let y = 0; y < resizedHeight; y++) {
      resized.copy(raw, ((top + y) * WIDTH + left) * 4, y * resizedWidth * 4, (y + 1) * resizedWidth * 4);
    }
    const png = await sharp(raw, { raw: { width: WIDTH, height: HEIGHT, channels: 4 } }).png().toBuffer();
    const bbox = [WIDTH, HEIGHT, 0, 0];
    let outputPixels = 0, borderPixels = 0;
    for (let y = 0; y < HEIGHT; y++) for (let x = 0; x < WIDTH; x++) {
      if (raw[(y * WIDTH + x) * 4 + 3] <= CORE_ALPHA) continue;
      outputPixels++;
      if (x === 0 || y === 0 || x === WIDTH - 1 || y === HEIGHT - 1) borderPixels++;
      bbox[0] = Math.min(bbox[0], x); bbox[1] = Math.min(bbox[1], y);
      bbox[2] = Math.max(bbox[2], x + 1); bbox[3] = Math.max(bbox[3], y + 1);
    }
    if (outputPixels < 500 || borderPixels) throw Error(`${direction}/${index}: empty or clipped output`);
    const quantizedRoot = [
      left + (root[0] - bx) * resizedWidth / sourceWidth,
      top + (root[1] - by) * resizedHeight / sourceHeight,
    ];
    buffers.push(png);
    frameRaws.push(raw);
    frames.push({
      index, source_cell: [component.col, component.row], source_core_bbox: component.bbox,
      source_preserved_bbox: [bx, by, ex, ey], source_root: root,
      source_core_pixels: component.count, output_core_pixels: outputPixels,
      output_core_bbox: bbox, border_core_pixels: borderPixels,
      placement: [left, top, resizedWidth, resizedHeight],
      quantized_source_root_in_canvas: quantizedRoot.map(round),
      root_quantization_error: quantizedRoot.map((value, axis) => round(value - ANCHOR[axis])),
      preserved_source_rgba_sha256: sha(pixels), frame_png_sha256: sha(png), frame_rgba_sha256: sha(raw),
      crosses_nominal_source_cell: component.bbox[0] < component.col * width / COLS ||
        component.bbox[1] < component.row * height / ROWS ||
        component.bbox[2] > (component.col + 1) * width / COLS ||
        component.bbox[3] > (component.row + 1) * height / ROWS,
    });
  }
  // Composite would perform a second premultiply/unpremultiply operation,
  // rounding straight-alpha RGB on translucent garment edges. Copy RGBA
  // scanlines directly and encode once so every atlas region stays exact.
  const atlasWidth = WIDTH * COLS, atlasHeight = HEIGHT * ROWS;
  const atlasRaw = Buffer.alloc(atlasWidth * atlasHeight * 4);
  for (let index = 0; index < FRAME_COUNT; index++) {
    const left = index % COLS * WIDTH, top = Math.floor(index / COLS) * HEIGHT;
    for (let y = 0; y < HEIGHT; y++) {
      frameRaws[index].copy(atlasRaw, ((top + y) * atlasWidth + left) * 4, y * WIDTH * 4, (y + 1) * WIDTH * 4);
    }
  }
  const atlas = await sharp(atlasRaw, { raw: { width: atlasWidth, height: atlasHeight, channels: 4 } }).png().toBuffer();
  // Verify packed regions against their frame RGBA, not only compressed PNGs.
  for (let index = 0; index < FRAME_COUNT; index++) {
    const packed = await sharp(atlas).extract({ left: index % COLS * WIDTH, top: Math.floor(index / COLS) * HEIGHT, width: WIDTH, height: HEIGHT }).raw().toBuffer();
    if (sha(packed) !== frames[index].frame_rgba_sha256) throw Error(`${direction}/${index}: atlas region does not preserve frame RGBA`);
  }
  return {
    key, group, direction, rows: ROWS, count: FRAME_COUNT, atlas, buffers,
    manifest: {
      ...inspected.summary, components: undefined, fixed_scale: scale, explicit_roots: alignment.roots,
      atlas: `${OUTPUT}/atlas_${group}_${direction}.png`, atlas_sha256: sha(atlas),
      atlas_regions_verified: FRAME_COUNT, atlas_packing: 'Direct straight RGBA scanline copies; no compositing or alpha roundtrip.', frames,
    },
  };
}

function spriteFrames(prepared, overrides = {}) {
  const blocks = [], animations = [];
  let text = `[gd_resource type="SpriteFrames" load_steps=${1 + prepared.length * 17} format=3]\n\n`;
  for (const item of prepared) text += `[ext_resource type="Texture2D" path="res://${OUTPUT}/atlas_${item.key}.png" id="${item.key}"]\n`;
  for (const item of prepared) {
    for (let i = 0; i < item.count; i++) blocks.push(`[sub_resource type="AtlasTexture" id="${item.key}_${i}"]\natlas = ExtResource("${item.key}")\nregion = Rect2(${i % COLS * WIDTH}, ${Math.floor(i / COLS) * HEIGHT}, ${WIDTH}, ${HEIGHT})\nfilter_clip = true\n`);
    for (const [name, clip] of Object.entries(GROUPS[item.group].clips)) {
      const textures = clip.indices.map((index, frame) => overrides[`${name}_${item.direction}`]?.[frame] || `${item.key}_${index}`);
      for (const ref of textures) {
        const match = /^((?:base|extra)_[NESW])_(\d+)$/.exec(ref);
        if (!match || !prepared.some(p => p.key === match[1]) || +match[2] >= 16) throw Error(`Invalid frame reference ${ref}`);
      }
      animations.push(`{\n"frames": [${textures.map(ref => `{ "duration": 1.0, "texture": SubResource("${ref}") }`).join(',\n')}],\n"loop": ${!!clip.loop},\n"name": &"${name}_${item.direction}",\n"speed": ${clip.indices.length / clip.duration}\n}`);
    }
  }
  return { text: text + '\n' + blocks.join('\n') + '\n[resource]\nanimations = [' + animations.join(',\n') + ']\n', count: animations.length };
}

async function writePreviews(prepared, output, overrides) {
  const sheets = new Map(prepared.map(item => [item.key, item]));
  for (const item of prepared) {
    await sharp(item.atlas).flatten({ background: '#303b44' }).resize({ width: 1024 }).jpeg({ quality: 85 }).toFile(path.join(output, `review_${item.key}.jpg`));
    for (const [name, clip] of Object.entries(GROUPS[item.group].clips)) {
      if (name === 'idle') continue;
      const pages = [];
      for (const [frame, index] of clip.indices.entries()) {
        const ref = overrides[`${name}_${item.direction}`]?.[frame];
        const match = ref && /^(.+)_([0-9]+)$/.exec(ref);
        const png = match ? sheets.get(match[1]).buffers[+match[2]] : item.buffers[index];
        pages.push(await sharp(png).flatten({ background: '#303b44' }).raw().toBuffer());
      }
      const delays = pages.map((_, i) => (Math.round((i + 1) * clip.duration * 100 / pages.length) - Math.round(i * clip.duration * 100 / pages.length)) * 10);
      await sharp(Buffer.concat(pages), { raw: { width: WIDTH, height: HEIGHT * pages.length, channels: 3, pageHeight: HEIGHT } }).gif({ delay: delays, loop: 0 }).toFile(path.join(output, `${name}_${item.direction}.gif`));
    }
  }
}

async function main() {
  const args = options(process.argv.slice(2));
  const available = KEYS.filter(key => fs.existsSync(path.join(ROOT, SOURCE, `source_${key}.png`)));
  if (!available.length || (available.length !== 8 && !args.allowPartial)) throw Error('Eight source sheets required; --allow-partial only for production review');
  const inspected = [];
  for (const key of available) inspected.push(await inspectDirection(key, args.minComponentPixels));
  if (args.inspect) { console.log(JSON.stringify({ valid: inspected.every(i => i.summary.valid), sheets: inspected.map(i => i.summary) }, null, 2)); return; }
  const alignmentBytes = fs.readFileSync(path.join(__dirname, 'alignment.json'));
  const alignment = JSON.parse(alignmentBytes.toString('utf8').replace(/^\uFEFF/, ''));
  const prepared = [];
  for (const item of inspected) prepared.push(await prepareDirection(item, checkedAlignment(item.key, alignment)));
  const overrides = alignment.clip_overrides || {};
  const resource = spriteFrames(prepared, overrides);
  const output = path.join(ROOT, OUTPUT); fs.mkdirSync(output, { recursive: true });
  for (const item of prepared) fs.writeFileSync(path.join(output, `atlas_${item.key}.png`), item.atlas);
  fs.writeFileSync(path.join(output, 'philosopher_sprite_frames.tres'), resource.text);
  const manifest = { schema: 1, asset: 'The Dialectician', generator: 'OpenAI built-in imagegen', complete: available.length === 8,
    canvas: [WIDTH, HEIGHT], foot_anchor: ANCHOR, animation_count: resource.count, total_authored_frames: prepared.length * 16,
    sprite_frames_sha256: sha(resource.text), alignment_sha256: sha(alignmentBytes), clips: GROUPS, clip_overrides: overrides,
    policy: 'Mechanical crop, fixed sheet scale, explicit ground anchors; genuine source RGBA; no mirroring or redraw; exact atlas scanline verification.',
    sheets: prepared.map(i => i.manifest) };
  fs.writeFileSync(path.join(output, 'manifest.json'), JSON.stringify(manifest, null, 2) + '\n');
  const portrait = alignment.portrait_region;
  if (prepared.some(i => i.key === 'base_E') && portrait) fs.writeFileSync(path.join(output, 'philosopher_portrait.tres'), `[gd_resource type="SpriteFrames" load_steps=3 format=3]\n\n[ext_resource type="Texture2D" path="res://${OUTPUT}/atlas_base_E.png" id="1"]\n\n[sub_resource type="AtlasTexture" id="Portrait"]\natlas = ExtResource("1")\nregion = Rect2(${portrait.join(', ')})\nfilter_clip = true\n\n[resource]\nanimations = [{ "frames": [{ "duration": 1.0, "texture": SubResource("Portrait") }], "loop": true, "name": &"idle_E", "speed": 1.0 }]\n`);
  await writePreviews(prepared, output, overrides);
  console.log(JSON.stringify({ complete: manifest.complete, clips: resource.count, frames: manifest.total_authored_frames, atlas_regions_verified: prepared.reduce((n, i) => n + i.manifest.atlas_regions_verified, 0) }));
}
if (require.main === module) main().catch(e => { console.error(e.stack); process.exitCode = 1; });
module.exports = { spriteFrames, checkedAlignment, extractComponents, summarizeAlpha, GROUPS };
