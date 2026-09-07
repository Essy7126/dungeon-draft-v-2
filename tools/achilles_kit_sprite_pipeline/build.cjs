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
const SOURCE = 'art/source/characters/achilles/sprites_kit_v2';
const OUTPUT = 'assets/characters/Achilles/sprites_kit_v2';
const LEGACY = 'assets/characters/Achilles/sprites_cour_des_sources_v1/achilles_sprite_frames.tres';
const DIRECTIONS = ['N', 'E', 'S', 'W'];
const WIDTH = 512, HEIGHT = 384, ANCHOR = [256, 320], COLS = 4;
const CORE_ALPHA = 32, EDGE_RADIUS = 2;
const DASH_PREVIEW_DELAYS_MS = [50, 50, 400, 80];
const GROUPS = {
  base: { rows: 3, count: 12, clips: {
    dash: { indices: [0,1,2,3], speed: 20, bookend: false, release_seconds: 0.10, controller_owned: true },
    bow: { indices: [4,5,6,7], speed: 6 / 0.72, bookend: true, release_seconds: 0.36 },
    guard: { indices: [8,9,10,11], speed: 6 / 0.48, bookend: true, release_seconds: 0.24 },
  } },
  extra: { rows: 4, count: 16, clips: {
    sweep: { indices: [0,1,2,3], speed: 6 / 0.72, bookend: true, release_seconds: 0.36 },
    volley: { indices: [4,5,6,7], speed: 6 / 0.72, bookend: true, release_seconds: 0.36 },
    hit: { indices: [8,9,10,11], speed: 4 / 0.24, bookend: false },
    death: { indices: [12,13,14,15], speed: 4 / 0.48, bookend: false },
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
      console.log('node tools/achilles_kit_sprite_pipeline/build.cjs [--inspect] [--allow-partial] [--min-component-pixels 2000]');
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
  if (segmentation.components.length !== FRAME_COUNT) errors.push(`Expected ${FRAME_COUNT} full sprites, found ${segmentation.components.length}`);
  for (const component of segmentation.components) {
    const col = Math.min(COLS - 1, Math.floor(component.center[0] / (width / COLS)));
    const row = Math.min(ROWS - 1, Math.floor(component.center[1] / (height / ROWS)));
    const index = row * COLS + col;
    Object.assign(component, { col, row, index });
    if (ordered[index]) errors.push(`Ambiguous source cell ${index}`);
    else ordered[index] = component;
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
    components: segmentation.components.map(component => ({
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

function splitAnimationObjects(value) {
  const result = [];
  let quoted = false, escaped = false, depth = 0, start = -1;
  for (let index = 0; index < value.length; index++) {
    const char = value[index];
    if (quoted) {
      if (escaped) escaped = false;
      else if (char === '\\') escaped = true;
      else if (char === '"') quoted = false;
      continue;
    }
    if (char === '"') { quoted = true; continue; }
    if (char === '{') { if (depth++ === 0) start = index; }
    else if (char === '}' && --depth === 0) result.push(value.slice(start, index + 1));
  }
  if (quoted || depth !== 0) throw Error('Unbalanced legacy SpriteFrames animation data');
  return result;
}

function prefixLegacyIds(text) {
  return text.replace(/id="([^"]+)"/g, 'id="Legacy_$1"')
    .replace(/ExtResource\("([^"]+)"\)/g, 'ExtResource("Legacy_$1")')
    .replace(/SubResource\("([^"]+)"\)/g, 'SubResource("Legacy_$1")');
}

async function loadLegacy() {
  const bytes = fs.readFileSync(path.join(ROOT, LEGACY));
  const text = bytes.toString('utf8').replace(/^\uFEFF/, '');
  const resourceAt = text.indexOf('[resource]');
  const animationAt = text.indexOf('animations = [', resourceAt);
  if (resourceAt < 0 || animationAt < 0) throw Error('Legacy SpriteFrames resource layout is unsupported');
  const blocks = splitAnimationObjects(text.slice(animationAt + 'animations = ['.length, text.lastIndexOf(']')));
  const animations = new Map();
  for (const block of blocks) {
    const name = block.match(/"name"\s*:\s*&"([^"]+)"/)?.[1];
    if (!name || animations.has(name)) throw Error('Ambiguous legacy animation name');
    animations.set(name, block);
  }
  if (animations.size !== 12) throw Error(`Expected exactly twelve legacy animations, found ${animations.size}`);
  const extResources = new Map();
  for (const match of text.matchAll(/\[ext_resource[^\n]*path="([^"]+)"[^\n]*id="([^"]+)"\]/g)) extResources.set(match[2], match[1]);
  const atlasBlocks = new Map();
  for (const match of text.matchAll(/\[sub_resource type="AtlasTexture" id="([^"]+)"\]([\s\S]*?)(?=\n\[|$)/g)) atlasBlocks.set(match[1], match[2]);
  const idle = {};
  for (const direction of DIRECTIONS) {
    for (const stem of ['idle','walk','attack']) if (!animations.has(`${stem}_${direction}`)) throw Error(`Legacy ${stem}_${direction} missing`);
    const block = animations.get(`idle_${direction}`);
    const frameId = block.match(/SubResource\("([^"]+)"\)/)?.[1];
    const frameBlock = atlasBlocks.get(frameId);
    const atlasId = frameBlock?.match(/ExtResource\("([^"]+)"\)/)?.[1];
    const region = frameBlock?.match(/region\s*=\s*Rect2\(([^)]+)\)/)?.[1].split(',').map(Number);
    const atlasPath = extResources.get(atlasId);
    if (!atlasPath || !region || region.length !== 4 || region.some(number => !Number.isFinite(number)) || region[2] !== WIDTH || region[3] !== HEIGHT) {
      throw Error(`Legacy idle_${direction} must reference one full 512x384 AtlasTexture`);
    }
    const png = await sharp(path.join(ROOT, atlasPath.replace(/^res:\/\//, '')))
      .extract({ left: region[0], top: region[1], width: region[2], height: region[3] }).png().toBuffer();
    idle[direction] = { id: `Legacy_${frameId}`, png, atlas: atlasPath, region, png_sha256: sha(png) };
  }
  const header = text.slice(0, resourceAt).replace(/^\[gd_resource[^\n]*\]\s*/, '');
  return {
    source: LEGACY, source_sha256: sha(bytes), text, header: prefixLegacyIds(header),
    blocks: blocks.map(prefixLegacyIds), originalBlocks: blocks, animations, idle,
    resourceCount: (header.match(/\[(?:ext_resource|sub_resource)\b/g) || []).length,
  };
}

function checkedClipOverrides(prepared, definitions = {}) {
  if (definitions === null || typeof definitions !== 'object' || Array.isArray(definitions)) {
    throw Error('alignment.clip_overrides must be an object keyed by new clip name.');
  }
  const sheets = new Map(prepared.map(item => [item.key, item]));
  const clips = new Map();
  for (const item of prepared) for (const [stem, mapping] of Object.entries(GROUPS[item.group].clips)) {
    clips.set(`${stem}_${item.direction}`, { item, mapping });
  }
  const result = [];
  for (const clipName of Object.keys(definitions).sort()) {
    const clip = clips.get(clipName);
    if (!clip) throw Error(`clip_overrides.${clipName}: unknown or unavailable new clip; legacy clips cannot be overridden.`);
    const entries = definitions[clipName];
    if (entries === null || typeof entries !== 'object' || Array.isArray(entries)) {
      throw Error(`clip_overrides.${clipName} must be an object keyed by zero-based final clip frame.`);
    }
    for (const frameKey of Object.keys(entries).sort((a, b) => Number(a) - Number(b))) {
      if (!/^(0|[1-9][0-9]*)$/.test(frameKey)) throw Error(`${clipName}/${frameKey}: frame must be a canonical non-negative integer.`);
      const frameIndex = Number(frameKey);
      const bookends = clip.mapping.bookend ? 1 : 0;
      const count = clip.mapping.indices.length + bookends * 2;
      if (!Number.isSafeInteger(frameIndex) || frameIndex >= count) throw Error(`${clipName}/${frameKey}: frame is outside the final ${count}-frame clip.`);
      if (bookends && (frameIndex === 0 || frameIndex === count - 1)) throw Error(`${clipName}/${frameKey}: canonical idle bookends are immutable.`);
      const replacement = entries[frameKey];
      if (replacement === null || typeof replacement !== 'object' || Array.isArray(replacement)) {
        throw Error(`${clipName}/${frameKey}: replacement requires group, direction and source index.`);
      }
      for (const key of Object.keys(replacement)) {
        if (!['group', 'direction', 'index', 'reason'].includes(key)) throw Error(`${clipName}/${frameKey}: unknown replacement field ${key}.`);
      }
      if (!Object.hasOwn(GROUPS, replacement.group) || !DIRECTIONS.includes(replacement.direction)) {
        throw Error(`${clipName}/${frameKey}: invalid source group or direction.`);
      }
      const sourceKey = `${replacement.group}_${replacement.direction}`;
      const source = sheets.get(sourceKey);
      if (!source) throw Error(`${clipName}/${frameKey}: source sheet ${sourceKey} is unavailable in this build.`);
      if (!Number.isInteger(replacement.index) || replacement.index < 0 || replacement.index >= source.count) {
        throw Error(`${clipName}/${frameKey}: source index must be inside ${sourceKey} [0, ${source.count - 1}].`);
      }
      if (replacement.reason !== undefined && typeof replacement.reason !== 'string') {
        throw Error(`${clipName}/${frameKey}: optional reason must be a string.`);
      }
      const originalIndex = clip.mapping.indices[frameIndex - bookends];
      result.push({
        clip: clipName, frame_index: frameIndex,
        original: { group: clip.item.group, direction: clip.item.direction, index: originalIndex,
          resource_id: `Kit_${clip.item.key}_${originalIndex}` },
        replacement: { group: replacement.group, direction: replacement.direction, index: replacement.index,
          resource_id: `Kit_${sourceKey}_${replacement.index}`,
          atlas: `${OUTPUT}/atlas_${sourceKey}.png` },
        ...(replacement.reason === undefined ? {} : { reason: replacement.reason }),
        operation: 'SpriteFrames texture reference only; source pixels and atlas regions unchanged.',
      });
    }
  }
  return result;
}

function spriteFrames(prepared, legacy, overrides = {}) {
  const substitutions = checkedClipOverrides(prepared, overrides);
  const extraResourceCount = prepared.reduce((total, item) => total + item.count + 1, 0);
  const legacySubresourcesAt = legacy.header.indexOf('[sub_resource');
  if (legacySubresourcesAt < 0) throw Error('Legacy AtlasTexture declarations missing');
  let text = `[gd_resource type="SpriteFrames" load_steps=${1 + legacy.resourceCount + extraResourceCount} format=3]\n\n`
    + legacy.header.slice(0, legacySubresourcesAt);
  for (const item of prepared) text += `[ext_resource type="Texture2D" path="${toResourcePath(`${OUTPUT}/atlas_${item.key}.png`)}" id="Kit_${item.key}"]\n`;
  text += '\n' + legacy.header.slice(legacySubresourcesAt);
  for (const item of prepared) for (let index = 0; index < item.count; index++) {
    text += `[sub_resource type="AtlasTexture" id="Kit_${item.key}_${index}"]\natlas = ExtResource("Kit_${item.key}")\nregion = Rect2(${index % COLS * WIDTH}, ${Math.floor(index / COLS) * HEIGHT}, ${WIDTH}, ${HEIGHT})\nfilter_clip = true\n\n`;
  }
  const animations = legacy.blocks.slice();
  for (const item of prepared) for (const [stem, mapping] of Object.entries(GROUPS[item.group].clips)) {
    const ids = mapping.indices.map(index => `Kit_${item.key}_${index}`);
    if (mapping.bookend) { ids.unshift(legacy.idle[item.direction].id); ids.push(legacy.idle[item.direction].id); }
    for (const substitution of substitutions) {
      if (substitution.clip === `${stem}_${item.direction}`) ids[substitution.frame_index] = substitution.replacement.resource_id;
    }
    const frames = ids.map(id => `{\n"duration": 1.0,\n"texture": SubResource("${id}")\n}`);
    animations.push(`{\n"frames": [${frames.join(', ')}],\n"loop": false,\n"name": &"${stem}_${item.direction}",\n"speed": ${mapping.speed}\n}`);
  }
  // Compare all original declarations with only the necessary id namespace
  // transform. No old frame, duration, speed or loop property is rewritten.
  for (let index = 0; index < legacy.originalBlocks.length; index++) {
    if (animations[index] !== prefixLegacyIds(legacy.originalBlocks[index])) throw Error('Legacy animation definition changed');
  }
  return { text: text + `[resource]\nanimations = [${animations.join(', ')}]\n`, count: animations.length, clip_overrides: substitutions };
}

function previewOverlay(item) {
  let svg = `<svg width="${WIDTH * COLS}" height="${HEIGHT * item.rows}" xmlns="http://www.w3.org/2000/svg">`;
  for (let index = 0; index < item.count; index++) {
    const x = index % COLS * WIDTH, y = Math.floor(index / COLS) * HEIGHT;
    const ax = x + ANCHOR[0], ay = y + ANCHOR[1];
    svg += `<rect x="${x + 1}" y="${y + 1}" width="${WIDTH - 2}" height="${HEIGHT - 2}" fill="none" stroke="#889088" stroke-opacity="0.45"/>`;
    svg += `<path d="M${ax - 7},${ay}h14 M${ax},${ay - 7}v14" stroke="#ef52ae" stroke-width="2"/>`;
    svg += `<text x="${x + 12}" y="${y + 25}" font-family="sans-serif" font-size="20" fill="#888888">${item.key} ${index}</text>`;
  }
  return Buffer.from(svg + '</svg>');
}

function gifDelays(count, fps) {
  return Array.from({ length: count }, (_, index) =>
    10 * (Math.round((index + 1) * 100 / fps) - Math.round(index * 100 / fps)));
}

async function writePreviews(prepared, legacy, outputPath) {
  for (const item of prepared) {
    for (const [theme, background] of [['light', '#ddd6ba'], ['dark', '#354343']]) {
      const marked = await sharp(item.atlas).composite([{ input: previewOverlay(item) }]).flatten({ background }).png().toBuffer();
      await sharp(marked).resize(1024).jpeg({ quality: 92 }).toFile(path.join(outputPath, `preview_${item.key}_${theme}.jpg`));
    }
    for (const [stem, mapping] of Object.entries(GROUPS[item.group].clips)) {
      const frames = mapping.indices.map(index => item.buffers[index]);
      if (mapping.bookend) { frames.unshift(legacy.idle[item.direction].png); frames.push(legacy.idle[item.direction].png); }
      const pages = [];
      for (const png of frames) pages.push(await sharp(png).flatten({ background: '#ddd6ba' }).raw().toBuffer());
      // Illustrate a three-cell dash: frame 2 stays airborne through travel,
      // then frame 3 lands for 80 ms. Battle still owns the real arrival time.
      const delays = stem === 'dash' ? DASH_PREVIEW_DELAYS_MS : gifDelays(frames.length, mapping.speed);
      await sharp(Buffer.concat(pages), { raw: { width: WIDTH, height: HEIGHT * pages.length, channels: 3, pageHeight: HEIGHT } })
        .gif({ delay: delays, loop: 0 }).toFile(path.join(outputPath, `${stem}_${item.direction}_preview.gif`));
    }
  }
}

async function main() {
  const args = options(process.argv.slice(2));
  const available = KEYS.filter(key => fs.existsSync(path.join(ROOT, SOURCE, `source_${key}.png`)));
  if (!available.length) throw Error('No source_base_DIR.png or source_extra_DIR.png found');
  if (available.length !== KEYS.length && !args.allowPartial) throw Error('All eight base/extra N/E/S/W sources required; --allow-partial is development only');
  const inspected = [];
  for (const key of available) inspected.push(await inspectDirection(key, args.minComponentPixels));
  if (args.inspect) {
    console.log(JSON.stringify({ mode: 'read_only_inspection', complete: available.length === KEYS.length,
      valid: inspected.every(item => item.summary.valid), sheets: inspected.map(item => item.summary) }, null, 2));
    return;
  }
  const alignmentPath = path.join(__dirname, 'alignment.json');
  if (!fs.existsSync(alignmentPath)) throw Error('Explicit alignment.json is required; never fit to robe, foot or weapon bounds automatically');
  const alignmentBytes = fs.readFileSync(alignmentPath);
  const alignment = JSON.parse(alignmentBytes.toString('utf8').replace(/^\uFEFF/, ''));
  const legacy = await loadLegacy();
  const prepared = [];
  for (const item of inspected) prepared.push(await prepareDirection(item, checkedAlignment(item.key, alignment)));
  const resource = spriteFrames(prepared, legacy, alignment.clip_overrides);
  const complete = available.length === KEYS.length;
  if (complete && resource.count !== 40) throw Error(`Full kit must export 40 animations, found ${resource.count}`);
  const manifest = {
    schema_version: 2, asset: 'Achilles full sprite kit v2', generator: 'OpenAI built-in ImageGen', complete,
    canvas: [WIDTH, HEIGHT], foot_anchor: ANCHOR, atlas_columns: COLS,
    source_layout: GROUPS, source_keys: available, total_authored_frames: prepared.reduce((total, item) => total + item.count, 0),
    alignment_source: 'tools/achilles_kit_sprite_pipeline/alignment.json', alignment_sha256: sha(alignmentBytes),
    legacy_sprite_frames: legacy.source, legacy_sprite_frames_sha256: legacy.source_sha256,
    legacy_animation_count: 12, legacy_animation_definitions_preserved: true,
    legacy_texture_policy: 'Original atlas paths and AtlasTexture regions retained; only resource ids are namespaced.',
    canonical_idle_sources: Object.fromEntries(DIRECTIONS.map(direction => [direction, {
      atlas: legacy.idle[direction].atlas, region: legacy.idle[direction].region,
      png_sha256: legacy.idle[direction].png_sha256,
    }])),
    clip_overrides: resource.clip_overrides,
    animation_count: resource.count, sprite_frames: `${OUTPUT}/achilles_sprite_frames.tres`, sprite_frames_sha256: sha(resource.text),
    production_policy: 'Genuine source RGBA only. Alpha >32 connected components plus two-pixel edge preservation. Reject any discarded alpha >32, including detached bow strings or arrows. One explicit scale per source, explicit ground roots for every pose, no per-pose fitting or mirroring. Atlas scanlines copied in straight RGBA and encoded once, each packed region verified byte-for-byte.',
    dash_timing: { release_seconds: 0.10, controller_owned_arrival: true, fallback_budget_seconds: 1.2,
      hold_frame: 2, landing_frame: 3, landing_seconds: 0.08,
      resource_fps_is_metadata: true, gif_preview_delays_ms: DASH_PREVIEW_DELAYS_MS },
    death_timing: { authored_seconds: 0.48, runtime_fade_seconds: 0.12 },
    sharp_version: sharp.versions.sharp, sheets: prepared.map(item => item.manifest),
  };
  const outputPath = path.join(ROOT, OUTPUT);
  fs.mkdirSync(outputPath, { recursive: true });
  for (const item of prepared) fs.writeFileSync(path.join(outputPath, `atlas_${item.key}.png`), item.atlas);
  fs.writeFileSync(path.join(outputPath, 'achilles_sprite_frames.tres'), resource.text);
  fs.writeFileSync(path.join(outputPath, 'manifest.json'), JSON.stringify(manifest, null, 2) + '\n');
  await writePreviews(prepared, legacy, outputPath);
  for (const item of prepared) console.log(`${item.key}: ${item.count} exact atlas regions verified, fixed scale ${item.manifest.fixed_scale}`);
  console.log(`Wrote ${resource.count} animations; old twelve preserved; new frames=${manifest.total_authored_frames}; complete=${complete}`);
}

if (require.main === module) main().catch(error => { console.error(error.stack || error.message); process.exitCode = 1; });

module.exports = { checkedClipOverrides, spriteFrames, splitAnimationObjects, GROUPS, DIRECTIONS, DASH_PREVIEW_DELAYS_MS };
