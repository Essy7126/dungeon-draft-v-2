#!/usr/bin/env node
'use strict';
// Mechanical extraction of authored RGBA. No keying, segmentation or drawing.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
let sharp;
try { sharp = require('sharp'); } catch {
  sharp = require(process.env.SHARP_PATH || 'C:/Users/paolo/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
}

const ROOT = path.resolve(__dirname, '../..');
const SOURCE = 'art/source/vfx/philosopher_mage/sprites_v1/source_effects.png';
const OUTPUT = 'assets/vfx/philosopher_mage/sprites_v1';
const layoutTools = require('../achilles_kit_sprite_pipeline/effects_source_layout.cjs');
const ANIMATIONS = ['bolt', 'impact', 'heal', 'control', 'shield', 'repel'];
const DURATIONS = { bolt: 0.20, impact: 0.24, heal: 0.48, control: 0.30, shield: 0.30, repel: 0.34 };
const ICON_ANIMATIONS = { axiom: 'bolt', refutation: 'repel', mending: 'heal', aporia: 'control', aegis: 'shield' };
const COLUMNS = 4, ROWS = 6, SIZE = 256, MARGIN = 12;
const sha = buffer => crypto.createHash('sha256').update(buffer).digest('hex');
const round = value => Math.round(value * 1e6) / 1e6;

function options(argv) {
  const result = { source: SOURCE, output: OUTPUT, inspect: false, help: false };
  for (let index = 0; index < argv.length; index++) {
    const arg = argv[index];
    if (arg === '--inspect') result.inspect = true;
    else if (arg === '--help' || arg === '-h') result.help = true;
    else if (arg === '--source' || arg === '--output' || arg === '--layout') {
      const value = argv[++index];
      if (!value || value.startsWith('--')) throw Error(`${arg} requires a path.`);
      result[arg.slice(2)] = value;
    } else throw Error(`Unknown option: ${arg}`);
  }
  return result;
}

function analyze(raw, width, height) {
  const histogram = new Array(256).fill(0);
  const bounds = { all: [width, height, 0, 0], core: [width, height, 0, 0] };
  let sum = 0, xWeighted = 0, yWeighted = 0;
  for (let y = 0; y < height; y++) for (let x = 0; x < width; x++) {
    const alpha = raw[(y * width + x) * 4 + 3];
    histogram[alpha]++;
    sum += alpha; xWeighted += x * alpha; yWeighted += y * alpha;
    for (const [key, threshold] of [['all', 0], ['core', 32]]) if (alpha > threshold) {
      const box = bounds[key];
      box[0] = Math.min(box[0], x); box[1] = Math.min(box[1], y);
      box[2] = Math.max(box[2], x + 1); box[3] = Math.max(box[3], y + 1);
    }
  }
  const margins = {};
  for (const key of ['all', 'core']) {
    const box = bounds[key];
    if (box[2] === 0) { bounds[key] = null; margins[key] = null; }
    else margins[key] = [box[0], box[1], width - box[2], height - box[3]];
  }
  return {
    alpha_histogram: histogram,
    transparent_pixels: histogram[0],
    partial_alpha_pixels: histogram.slice(1, 255).reduce((a, b) => a + b, 0),
    opaque_pixels: histogram[255], alpha_sum: sum,
    alpha_bounds: bounds, margins,
    alpha_centroid: sum ? [round(xWeighted / sum), round(yWeighted / sum)] : null,
  };
}

function extractRaw(raw, width, crop) {
  const output = Buffer.alloc(crop.width * crop.height * 4);
  const sourceHeight = raw.length / (width * 4);
  for (let y = 0; y < crop.height; y++) {
    const sourceY = crop.top + y;
    if (sourceY < 0 || sourceY >= sourceHeight) continue;
    const x0 = Math.max(0, crop.left), x1 = Math.min(width, crop.left + crop.width);
    if (x1 <= x0) continue;
    const start = (sourceY * width + x0) * 4;
    raw.copy(output, (y * crop.width + x0 - crop.left) * 4, start, start + (x1 - x0) * 4);
  }
  return output;
}

function verifyCell(alpha, index, cellSize, height = cellSize, minimumCoreMargin = 4) {
  const label = `${ANIMATIONS[Math.floor(index / COLUMNS)]}[${index % COLUMNS}]`;
  if (!alpha.alpha_bounds.all || !alpha.alpha_bounds.core) throw Error(`${label}: empty or almost invisible cell.`);
  if (alpha.transparent_pixels < cellSize * height * 0.05) {
    throw Error(`${label}: fewer than 5% truly transparent pixels; refuse opaque/baked background.`);
  }
  if (Math.min(...alpha.margins.all) < 1) throw Error(`${label}: nonzero alpha touches the cell boundary; clipping or grid mismatch.`);
  if (Math.min(...alpha.margins.core) < minimumCoreMargin) throw Error(`${label}: visible core lacks its required source margin.`);
}

function rowCrop(frames, cellSize) {
  const center = cellSize / 2;
  let radius = 0;
  const union = [cellSize, cellSize, 0, 0];
  for (const frame of frames) {
    const box = frame.source_alpha.alpha_bounds.all;
    union[0] = Math.min(union[0], box[0]); union[1] = Math.min(union[1], box[1]);
    union[2] = Math.max(union[2], box[2]); union[3] = Math.max(union[3], box[3]);
    radius = Math.max(radius, center - box[0], center - box[1], box[2] - center, box[3] - center);
  }
  // Keep two transparent source pixels around the union when available for
  // the resampler. Matching parity preserves the exact cell-center anchor.
  let side = Math.min(cellSize, Math.ceil(radius * 2 + 4));
  if ((side - cellSize) % 2 !== 0) side++;
  side = Math.min(cellSize, side);
  const offset = (cellSize - side) / 2;
  return { left: offset, top: offset, width: side, height: side, union_alpha_bounds: union };
}

function packRaw(frames) {
  const width = SIZE * COLUMNS;
  const atlas = Buffer.alloc(width * SIZE * ROWS * 4);
  frames.forEach((raw, index) => {
    const x = index % COLUMNS * SIZE, y = Math.floor(index / COLUMNS) * SIZE;
    for (let line = 0; line < SIZE; line++) {
      raw.copy(atlas, ((y + line) * width + x) * 4, line * SIZE * 4, (line + 1) * SIZE * 4);
    }
  });
  return atlas;
}

function resourceText(atlasResourcePath) {
  const blocks = [
    '[gd_resource type="SpriteFrames" load_steps=26 format=3]',
    `[ext_resource type="Texture2D" path="${atlasResourcePath}" id="1_atlas"]`,
  ];
  for (let row = 0; row < ROWS; row++) for (let col = 0; col < COLUMNS; col++) {
    blocks.push(`[sub_resource type="AtlasTexture" id="Frame_${ANIMATIONS[row]}_${col}"]\natlas = ExtResource("1_atlas")\nregion = Rect2(${col * SIZE}, ${row * SIZE}, ${SIZE}, ${SIZE})`);
  }
  const animations = ANIMATIONS.map(name => {
    const frames = Array.from({ length: COLUMNS }, (_, index) => `{
"duration": 1.0,
"texture": SubResource("Frame_${name}_${index}")
}`).join(', ');
    const speed = COLUMNS / DURATIONS[name];
    return `{
"frames": [${frames}],
"loop": false,
"name": &"${name}",
"speed": ${speed.toFixed(6)}
}`;
  });
  blocks.push(`[resource]\nanimations = [${animations.join(', ')}]`);
  return blocks.join('\n\n') + '\n';
}

function iconResources(atlasResourcePath) {
  const result = {};
  for (const [id, animation] of Object.entries(ICON_ANIMATIONS)) {
    const row = ANIMATIONS.indexOf(animation);
    result[id] = [
      '[gd_resource type="AtlasTexture" load_steps=2 format=3]',
      '[ext_resource type="Texture2D" path="' + atlasResourcePath + '" id="1_atlas"]',
      '[resource]\natlas = ExtResource("1_atlas")\nregion = Rect2(512, ' + row * SIZE + ', 256, 256)',
    ].join('\n\n') + '\n';
  }
  return result;
}

function outputLocation(value) {
  const output = path.resolve(ROOT, value);
  const relative = path.relative(ROOT, output);
  if (!relative || relative === '..' || relative.startsWith(`..${path.sep}`) || path.isAbsolute(relative)
      || /^(\.git|\.codex|\.agents)([\\/]|$)/i.test(relative)) {
    throw Error('--output must be a named directory inside the project, outside its metadata.');
  }
  return { absolute: output, relative: relative.split(path.sep).join('/') };
}

async function prepare(sourcePath, authoredLayout = null) {
  const bytes = fs.readFileSync(sourcePath);
  const metadata = await sharp(bytes).metadata();
  if (metadata.format !== 'png' || !metadata.hasAlpha || metadata.channels !== 4 || metadata.depth !== 'uchar') {
    throw Error('Source must be a real 8-bit RGBA PNG. No generated alpha channel or color keying is performed.');
  }
  if (metadata.orientation && metadata.orientation !== 1) throw Error('Rotated PNG metadata is unsupported; author an upright sheet.');
  if (!authoredLayout && (metadata.width % COLUMNS || metadata.height % ROWS
      || metadata.width / COLUMNS !== metadata.height / ROWS)) {
    throw Error(`Expected 4 × 6 square cells (e.g. 1024 × 1536), received ${metadata.width} × ${metadata.height}.`);
  }
  const cellSize = metadata.width / COLUMNS;
  if (cellSize < 64) throw Error('Source cells below 64 pixels are too small for this atlas.');
  const { data, info } = await sharp(bytes).raw().toBuffer({ resolveWithObject: true });
  if (info.channels !== 4) throw Error('RGBA decoding changed the channel count.');
  const checkedLayout = authoredLayout ? layoutTools.checkLayout(authoredLayout, metadata, sha(bytes)) : null;
  const frames = [];
  for (let row = 0; row < ROWS; row++) for (let col = 0; col < COLUMNS; col++) {
    const declared = checkedLayout?.cells[row * COLUMNS + col];
    const crop = declared?.crop || { left: col * cellSize, top: row * cellSize, width: cellSize, height: cellSize };
    const raw = extractRaw(data, info.width, crop);
    const originalAlpha = analyze(raw, crop.width, crop.height), originalHash = sha(raw);
    const cleaning = checkedLayout ? layoutTools.cleanBoundary(raw, crop.width, crop.height,
      checkedLayout.cleaning.maximum_alpha, `${ANIMATIONS[row]}[${col}]`) : null;
    const alpha = analyze(raw, crop.width, crop.height);
    verifyCell(alpha, frames.length, crop.width, crop.height, checkedLayout ? 1 : 4);
    if (originalAlpha.alpha_sum - alpha.alpha_sum !== (cleaning?.alpha_sum_removed || 0)
        || originalAlpha.alpha_histogram.slice(33).some((count, index) => count !== alpha.alpha_histogram[index + 33])) {
      throw Error(`${ANIMATIONS[row]}[${col}]: boundary accounting lost unapproved alpha.`);
    }
    frames.push({ animation: ANIMATIONS[row], frame: col, source_crop: crop,
      source_anchor: declared?.anchor || [cellSize / 2, cellSize / 2],
      source_anchor_global: declared?.global_anchor || [crop.left + cellSize / 2, crop.top + cellSize / 2],
      source_rgba_sha256: originalHash, source_original_alpha: originalAlpha,
      source_alpha: alpha, boundary_cleaning: cleaning, raw });
  }
  const rows = [];
  const packed = [];
  for (let row = 0; row < ROWS; row++) {
    const entries = frames.slice(row * COLUMNS, (row + 1) * COLUMNS);
    const crop = checkedLayout ? layoutTools.commonAnchoredSquare(entries) : rowCrop(entries, cellSize);
    const inner = SIZE - MARGIN * 2;
    rows.push({ animation: ANIMATIONS[row], common_local_crop: crop,
      common_scale: round(inner / crop.width), source_anchor: [cellSize / 2, cellSize / 2],
      declared_global_centers: entries.map(frame => frame.source_anchor_global),
      anchor_policy: checkedLayout ? 'Explicit source centers; one radius and scale per row.' : 'Fixed square-cell centers.',
      output_anchor: [SIZE / 2, SIZE / 2], output_content_square: [MARGIN, MARGIN, inner, inner],
      per_frame_recentering: false, mirror_or_rotation: false });
    for (const frame of entries) {
      const frameCrop = checkedLayout ? { left: frame.source_anchor[0] - crop.radius,
        top: frame.source_anchor[1] - crop.radius, width: crop.width, height: crop.height } : crop;
      const cropped = extractRaw(frame.raw, frame.source_crop.width, frameCrop);
      frame.common_anchor_crop = frameCrop;
      const croppedAlpha = analyze(cropped, crop.width, crop.height);
      // Alpha sum before resampling proves even detached one-pixel sparks
      // survived the common crop. Any approved boundary cleanup was already counted.
      if (croppedAlpha.alpha_sum !== frame.source_alpha.alpha_sum) {
        throw Error(`${frame.animation}[${frame.frame}]: common crop would discard authored alpha.`);
      }
      const resized = await sharp(cropped, { raw: { width: crop.width, height: crop.height, channels: 4 } })
        .resize(inner, inner, { kernel: 'lanczos3' }).raw().toBuffer();
      const raw = Buffer.alloc(SIZE * SIZE * 4);
      for (let y = 0; y < inner; y++) {
        resized.copy(raw, ((y + MARGIN) * SIZE + MARGIN) * 4, y * inner * 4, (y + 1) * inner * 4);
      }
      const alpha = analyze(raw, SIZE, SIZE);
      if (!alpha.alpha_bounds.all || Math.min(...alpha.margins.all) < MARGIN) {
        throw Error(`${frame.animation}[${frame.frame}]: packed frame has clipped or absent alpha.`);
      }
      frame.packed_alpha = alpha;
      frame.cropped_alpha_sum = croppedAlpha.alpha_sum;
      frame.packed_rgba_sha256 = sha(raw);
      delete frame.raw;
      packed.push(raw);
    }
  }
  const rawAtlas = packRaw(packed);
  // Verify every region as a byte copy, not alpha compositing over itself.
  for (let index = 0; index < packed.length; index++) {
    const recovered = extractRaw(rawAtlas, SIZE * COLUMNS, {
      left: index % COLUMNS * SIZE, top: Math.floor(index / COLUMNS) * SIZE, width: SIZE, height: SIZE,
    });
    if (!recovered.equals(packed[index])) throw Error(`Atlas packing changed frame ${index}.`);
  }
  const atlas = await sharp(rawAtlas, { raw: { width: SIZE * COLUMNS, height: SIZE * ROWS, channels: 4 } }).png().toBuffer();
  const relativeSource = path.relative(ROOT, sourcePath).split(path.sep).join('/');
  const manifest = {
    schema_version: 2, complete: true,
    source: { path: relativeSource, sha256: sha(bytes), size: [info.width, info.height],
      format: metadata.format, depth: metadata.depth, channels: info.channels, has_alpha: true },
    atlas: { size: [SIZE * COLUMNS, SIZE * ROWS], frame_size: [SIZE, SIZE], sha256: sha(atlas) },
    animation_order: ANIMATIONS, frames_per_animation: COLUMNS,
    authored_duration_seconds: DURATIONS,
    icon_frames: Object.fromEntries(Object.entries(ICON_ANIMATIONS).map(([name, animation]) => [name, {animation, frame: 2, region: [512, ANIMATIONS.indexOf(animation)*256, 256, 256]}])),
    explicit_source_layout: authoredLayout,
    boundary_cleaning: {
      enabled: !!checkedLayout,
      width: checkedLayout ? 1 : 0,
      allowed_maximum_alpha: checkedLayout?.cleaning.maximum_alpha || 0,
      pixels_removed: frames.reduce((sum, frame) => sum + (frame.boundary_cleaning?.pixels_removed || 0), 0),
      alpha_sum_removed: frames.reduce((sum, frame) => sum + (frame.boundary_cleaning?.alpha_sum_removed || 0), 0),
      maximum_alpha_removed: Math.max(...frames.map(frame => frame.boundary_cleaning?.maximum_alpha_removed || 0)),
      pixels_above_32_removed: 0,
      source_alpha_sum: frames.reduce((sum, frame) => sum + frame.source_original_alpha.alpha_sum, 0),
      interior_pixels_modified: 0,
    },
    processing: {
      method: 'Explicit rectangles or exact grid extraction; common declared-center square and scale per row; accounted boundary cleanup when explicitly reviewed; Lanczos3 RGBA resampling; transparent padding; byte-copy atlas packing.',
      component_segmentation: false, color_keying: false, pixel_redraw: false,
      alpha_threshold_is_measurement_only: !checkedLayout, all_nonzero_source_alpha_preserved_before_resampling: !checkedLayout,
      all_source_pixels_above_32_preserved_before_resampling: true,
      resampling_interpolates_rgba: true, frame_border_margin_pixels: MARGIN,
      bolt_orientation: 'Authored horizontal, pointing right; never flipped or rotated by this pipeline.',
    },
    rows, frames, sharp_version: sharp.versions.sharp,
  };
  return { atlas, manifest };
}

async function build(settings) {
  const sourcePath = path.resolve(ROOT, settings.source || SOURCE);
  const output = outputLocation(settings.output || OUTPUT);
  const defaultLayout = path.join(__dirname, 'effects_source_layout.json');
  const layoutPath = settings.layout ? path.resolve(ROOT, settings.layout)
    : sourcePath === path.resolve(ROOT, SOURCE) && fs.existsSync(defaultLayout) ? defaultLayout : null;
  const layoutBytes = layoutPath ? fs.readFileSync(layoutPath) : null;
  const result = await prepare(sourcePath, layoutBytes ? JSON.parse(layoutBytes.toString('utf8').replace(/^\uFEFF/, '')) : null);
  result.manifest.source_layout_file = layoutPath ? {
    path: path.relative(ROOT, layoutPath).split(path.sep).join('/'), sha256: sha(layoutBytes),
  } : null;
  result.manifest.atlas.path = `${output.relative}/effects.png`;
  if (!settings.inspect) {
    // Nothing is overwritten until all input, cropping and packing checks pass.
    fs.mkdirSync(output.absolute, { recursive: true });
    fs.writeFileSync(path.join(output.absolute, 'effects.png'), result.atlas);
    fs.writeFileSync(path.join(output.absolute, 'effects.tres'), resourceText(`res://${output.relative}/effects.png`));
    fs.mkdirSync(path.join(output.absolute, 'icons'), { recursive: true });
    for (const [name, resource] of Object.entries(iconResources('res://' + output.relative + '/effects.png'))) {
      fs.writeFileSync(path.join(output.absolute, 'icons', name + '.tres'), resource);
    }
    fs.writeFileSync(path.join(output.absolute, 'manifest.json'), JSON.stringify(result.manifest, null, 2) + '\n');
    for (const [name, background] of [['light', '#deddd6'], ['gray', '#5a616a'], ['dark', '#192127']]) {
      await sharp(result.atlas).flatten({ background }).jpeg({ quality: 94 })
        .toFile(path.join(output.absolute, `preview_effects_${name}.jpg`));
    }
  }
  return result.manifest;
}

if (require.main === module) {
  (async () => {
    const settings = options(process.argv.slice(2));
    if (settings.help) {
      console.log('node tools/philosopher_sprite_pipeline/build_effects.cjs [--inspect] [--source path.png] [--output project/directory] [--layout path.json]');
      return;
    }
    const manifest = await build(settings);
    console.log(JSON.stringify({ valid: true, inspect_only: settings.inspect,
      source: manifest.source, atlas: manifest.atlas,
      animations: manifest.animation_order, rows: manifest.rows,
      minimum_output_alpha_margin: Math.min(...manifest.frames.flatMap(frame => frame.packed_alpha.margins.all)),
    }, null, 2));
  })().catch(error => { console.error(error.message); process.exitCode = 1; });
}

module.exports = { iconResources, options, analyze, extractRaw, verifyCell, rowCrop, packRaw, resourceText, outputLocation, prepare, build };
