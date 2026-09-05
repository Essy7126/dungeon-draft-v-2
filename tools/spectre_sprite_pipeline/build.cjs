#!/usr/bin/env node
'use strict';

// Mechanical extraction and packing only. All character pixels are authored
// in the source PNGs; alignment is supplied explicitly by the art review.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
let sharp;
try { sharp = require('sharp'); } catch {
  sharp = require(process.env.SHARP_PATH || 'C:/Users/paolo/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
}

const ROOT = path.resolve(__dirname, '../..');
const SOURCE = 'art/source/characters/spectre_greatsword/sprites_v1';
const OUTPUT = 'assets/characters/spectre_greatsword/sprites_v1';
const DIRECTIONS = ['N', 'E', 'S', 'W'];
const WIDTH = 512, HEIGHT = 384, ANCHOR = [256, 320];
// Crop the original E/0 hood and shoulders for readable HUD portraits.
const PORTRAIT_REGION = [204, 82, 126, 144];
const COLS = 4, ROWS = 3, FRAME_COUNT = COLS * ROWS;
const CORE_ALPHA = 32, EDGE_RADIUS = 2;
const MAPS = {
  idle: { indices: [0], speed: 1, loop: true },
  walk: { indices: [0, 1, 2, 3], speed: 6, loop: true },
  attack: { indices: [0, 4, 5, 6, 7, 8, 9, 0], speed: 10, loop: false, impact_frame: 3 },
};
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
      console.log('node tools/spectre_sprite_pipeline/build.cjs [--inspect] [--allow-partial] [--min-component-pixels 2000]');
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

async function inspectDirection(direction, minPixels) {
  const source = `${SOURCE}/source_${direction}.png`;
  const original = fs.readFileSync(path.join(ROOT, source));
  const metadata = await sharp(original).metadata();
  if (!metadata.hasAlpha) throw Error(`${direction}: source lacks a real alpha channel`);
  const { data, info } = await sharp(original).ensureAlpha().raw().toBuffer({ resolveWithObject: true });
  const { width, height } = info;
  const segmentation = extractComponents(data, width, height, minPixels);
  const ordered = Array(FRAME_COUNT).fill(null);
  const errors = [];
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
    direction, source, source_sha256: sha(original), source_dimensions: [width, height],
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
  return { direction, data, width, height, labels: segmentation.labels, ordered, summary };
}

function checkedAlignment(direction, alignment) {
  const selected = alignment[direction];
  if (!selected || !Number.isFinite(selected.scale) || selected.scale <= 0) {
    throw Error(`${direction}: alignment.json requires a positive shared scale`);
  }
  if (!Array.isArray(selected.roots) || selected.roots.length !== FRAME_COUNT || selected.roots.some(root =>
    !Array.isArray(root) || root.length !== 2 || root.some(value => !Number.isFinite(value)))) {
    throw Error(`${direction}: alignment.json requires twelve explicit [sourceGlobalX, sourceGlobalY] roots`);
  }
  return selected;
}

async function prepareDirection(inspected, alignment) {
  const { direction, data, width, height, labels, ordered } = inspected;
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
      .resize(resizedWidth, resizedHeight, { kernel: 'lanczos3' }).png().toBuffer();
    const png = await sharp({ create: { width: WIDTH, height: HEIGHT, channels: 4, background: '#00000000' } })
      .composite([{ input: resized, left, top }]).png().toBuffer();
    const raw = await sharp(png).raw().toBuffer();
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
    direction, atlas, buffers,
    manifest: {
      ...inspected.summary, components: undefined, fixed_scale: scale, explicit_roots: alignment.roots,
      atlas: `${OUTPUT}/atlas_${direction}.png`, atlas_sha256: sha(atlas),
      atlas_regions_verified: FRAME_COUNT, atlas_packing: 'Direct straight RGBA scanline copies; no compositing or alpha roundtrip.', frames,
    },
  };
}

function spriteFrames(prepared) {
  let text = `[gd_resource type="SpriteFrames" load_steps=${1 + prepared.length * (FRAME_COUNT + 1)} format=3]\n\n`;
  for (const { direction } of prepared) text += `[ext_resource type="Texture2D" path="${toResourcePath(`${OUTPUT}/atlas_${direction}.png`)}" id="${direction}"]\n`;
  text += '\n';
  for (const { direction } of prepared) for (let index = 0; index < FRAME_COUNT; index++) {
    text += `[sub_resource type="AtlasTexture" id="Atlas_${direction}_${index}"]\natlas = ExtResource("${direction}")\nregion = Rect2(${index % COLS * WIDTH}, ${Math.floor(index / COLS) * HEIGHT}, ${WIDTH}, ${HEIGHT})\nfilter_clip = true\n\n`;
  }
  const animations = [];
  for (const [stem, mapping] of Object.entries(MAPS)) for (const { direction } of prepared) {
    const frames = mapping.indices.map(index => `{\n"duration": 1.0,\n"texture": SubResource("Atlas_${direction}_${index}")\n}`);
    animations.push(`{\n"frames": [${frames.join(', ')}],\n"loop": ${mapping.loop},\n"name": &"${stem}_${direction}",\n"speed": ${mapping.speed.toFixed(1)}\n}`);
  }
  return text + `[resource]\nanimations = [${animations.join(', ')}]\n`;
}

function portraitFrames() {
  return `[gd_resource type="SpriteFrames" load_steps=3 format=3]\n\n[ext_resource type="Texture2D" path="${toResourcePath(`${OUTPUT}/atlas_E.png`)}" id="1_atlas"]\n\n[sub_resource type="AtlasTexture" id="Atlas_E_0"]\natlas = ExtResource("1_atlas")\nregion = Rect2(${PORTRAIT_REGION.join(", ")})\nfilter_clip = true\n\n[resource]\nanimations = [{\n"frames": [{\n"duration": 1.0,\n"texture": SubResource("Atlas_E_0")\n}],\n"loop": true,\n"name": &"idle_E",\n"speed": 1.0\n}]\n`;
}

function previewOverlay(direction) {
  let svg = `<svg width="${WIDTH * COLS}" height="${HEIGHT * ROWS}" xmlns="http://www.w3.org/2000/svg">`;
  for (let index = 0; index < FRAME_COUNT; index++) {
    const x = index % COLS * WIDTH, y = Math.floor(index / COLS) * HEIGHT;
    const ax = x + ANCHOR[0], ay = y + ANCHOR[1];
    svg += `<rect x="${x + 1}" y="${y + 1}" width="${WIDTH - 2}" height="${HEIGHT - 2}" fill="none" stroke="#889088" stroke-opacity="0.45"/>`;
    svg += `<path d="M${ax - 7},${ay}h14 M${ax},${ay - 7}v14" stroke="#ef52ae" stroke-width="2"/>`;
    svg += `<text x="${x + 12}" y="${y + 25}" font-family="sans-serif" font-size="20" fill="#888888">${direction} ${String(index).padStart(2, '0')}</text>`;
  }
  return Buffer.from(svg + '</svg>');
}

function gifDelays(count, fps) {
  // GIF only stores centiseconds. Distribute rounding instead of changing
  // every frame to 170 ms and accumulating that error over a 6 fps loop.
  return Array.from({ length: count }, (_, index) =>
    10 * (Math.round((index + 1) * 100 / fps) - Math.round(index * 100 / fps)));
}

async function writePreviews(prepared, outputPath) {
  for (const result of prepared) {
    const overlay = previewOverlay(result.direction);
    for (const [theme, background] of [['light', '#ddd6ba'], ['dark', '#354343']]) {
      const contact = await sharp(result.atlas).composite([{ input: overlay }]).flatten({ background }).png().toBuffer();
      await sharp(contact).resize(1024).jpeg({ quality: 92 }).toFile(path.join(outputPath, `preview_${result.direction}_${theme}.jpg`));
    }
    for (const name of ['walk', 'attack']) {
      const mapping = MAPS[name], pages = [];
      for (const index of mapping.indices) pages.push(await sharp(result.buffers[index]).flatten({ background: '#ddd6ba' }).raw().toBuffer());
      await sharp(Buffer.concat(pages), { raw: { width: WIDTH, height: HEIGHT * pages.length, channels: 3, pageHeight: HEIGHT } })
        .gif({ delay: gifDelays(pages.length, mapping.speed), loop: 0 })
        .toFile(path.join(outputPath, `${name}_${result.direction}_preview.gif`));
    }
  }
}

async function main() {
  const args = options(process.argv.slice(2));
  const available = DIRECTIONS.filter(direction => fs.existsSync(path.join(ROOT, SOURCE, `source_${direction}.png`)));
  if (!available.length) throw Error('No source_N/E/S/W.png found');
  if (available.length !== DIRECTIONS.length && !args.allowPartial) throw Error('All N/E/S/W sources are required; --allow-partial is only for development');
  const inspected = [];
  for (const direction of available) inspected.push(await inspectDirection(direction, args.minComponentPixels));
  if (args.inspect) {
    console.log(JSON.stringify({ mode: 'read_only_inspection', source_grid: [COLS, ROWS], complete: available.length === 4, valid: inspected.every(item => item.summary.valid), sheets: inspected.map(item => item.summary) }, null, 2));
    return;
  }
  const alignmentPath = path.join(__dirname, 'alignment.json');
  if (!fs.existsSync(alignmentPath)) throw Error('alignment.json is required: no automatic robe-bottom or per-pose fitting is allowed');
  const alignmentBytes = fs.readFileSync(alignmentPath);
  const alignment = JSON.parse(alignmentBytes.toString('utf8').replace(/^\uFEFF/, ''));
  const prepared = [];
  // Complete all source and placement checks before writing any runtime file.
  for (const item of inspected) prepared.push(await prepareDirection(item, checkedAlignment(item.direction, alignment)));
  const runtimeFrames = spriteFrames(prepared);
  const portrait = available.includes('E') ? portraitFrames() : null;
  const manifest = {
    schema_version: 1, asset: 'Spectre errant sprites v1', generator: 'OpenAI built-in ImageGen',
    complete: available.length === DIRECTIONS.length, canvas: [WIDTH, HEIGHT], foot_anchor: ANCHOR,
    atlas_dimensions: [WIDTH * COLS, HEIGHT * ROWS], source_grid: [COLS, ROWS], directions: available,
    alignment_source: 'tools/spectre_sprite_pipeline/alignment.json', alignment_sha256: sha(alignmentBytes),
    animation_layout: MAPS, attack_total_seconds: 0.8, attack_release_seconds: 0.3,
    idle_policy: 'One fixed canonical pose, no autoplay.',
    movement_policy: 'Continuous authored levitation phase; no foot-contact cycle and no root motion.',
    extraction_policy: 'Eight-connected source alpha > 32 components. Copy source RGBA in each core and its two-pixel edge neighborhood; refuse to discard any isolated alpha > 32. Component bounds are used only to preserve whole silhouettes, including swords crossing nominal grid cells. Each direction has one explicit scale and twelve authored global roots. Never align to a robe hem or normalize each pose.',
    sprite_frames: `${OUTPUT}/spectre_sprite_frames.tres`, sprite_frames_sha256: sha(runtimeFrames),
    portrait_frames: portrait ? `${OUTPUT}/spectre_portrait.tres` : null,
    portrait_frames_sha256: portrait ? sha(portrait) : null,
    portrait_source: portrait ? { direction: 'E', source_frame: 0, animation: 'idle_E', region: PORTRAIT_REGION, framing: 'Original hood and shoulders crop from E/0; no redraw.' } : null,
    sharp_version: sharp.versions.sharp, sheets: prepared.map(item => item.manifest),
  };
  const outputPath = path.join(ROOT, OUTPUT);
  fs.mkdirSync(outputPath, { recursive: true });
  for (const item of prepared) fs.writeFileSync(path.join(outputPath, `atlas_${item.direction}.png`), item.atlas);
  fs.writeFileSync(path.join(outputPath, 'spectre_sprite_frames.tres'), runtimeFrames);
  if (portrait) fs.writeFileSync(path.join(outputPath, 'spectre_portrait.tres'), portrait);
  fs.writeFileSync(path.join(outputPath, 'manifest.json'), JSON.stringify(manifest, null, 2) + '\n');
  await writePreviews(prepared, outputPath);
  for (const item of prepared) console.log(`${item.direction}: twelve preserved sprites; explicit scale=${item.manifest.fixed_scale}; twelve atlas regions verified`);
  console.log(`Wrote ${prepared.length * 3} runtime animations; complete=${manifest.complete}; portrait=${portrait ? 'E/0' : 'unavailable'}`);
}

main().catch(error => { console.error(error.stack || error.message); process.exitCode = 1; });
