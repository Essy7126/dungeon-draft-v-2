'use strict';

const crypto = require('node:crypto');
const CORE_ALPHA = 32;
const MIN_PRINCIPAL_PIXELS = 1500;
const sha = data => crypto.createHash('sha256').update(data).digest('hex');

function coreComponents(data, width, height) {
  const ids = new Int32Array(width * height), stack = new Uint32Array(ids.length);
  const components = [];
  for (let start = 0; start < ids.length; start++) {
    if (ids[start] || data[start * 4 + 3] <= CORE_ALPHA) continue;
    const id = components.length + 1;
    const part = {id, count: 0, bbox: [width, height, 0, 0], sum_x: 0, sum_y: 0};
    let pending = 0;
    ids[start] = id; stack[pending++] = start;
    while (pending) {
      const pixel = stack[--pending], x = pixel % width, y = Math.floor(pixel / width);
      part.count++; part.sum_x += x; part.sum_y += y;
      part.bbox[0] = Math.min(part.bbox[0], x); part.bbox[1] = Math.min(part.bbox[1], y);
      part.bbox[2] = Math.max(part.bbox[2], x + 1); part.bbox[3] = Math.max(part.bbox[3], y + 1);
      for (let dy = -1; dy <= 1; dy++) for (let dx = -1; dx <= 1; dx++) {
        if (!dx && !dy) continue;
        const nx = x + dx, ny = y + dy;
        if (nx < 0 || ny < 0 || nx >= width || ny >= height) continue;
        const next = ny * width + nx;
        if (ids[next] || data[next * 4 + 3] <= CORE_ALPHA) continue;
        ids[next] = id; stack[pending++] = next;
      }
    }
    part.center = [part.sum_x / part.count, part.sum_y / part.count];
    delete part.sum_x; delete part.sum_y;
    components.push(part);
  }
  return {ids, components};
}

function nominalIndex(center, width, height, count) {
  const columns = 4, rows = count / columns;
  return Math.min(rows - 1, Math.floor(center[1] * rows / height)) * columns
    + Math.min(columns - 1, Math.floor(center[0] * columns / width));
}

function nearestPrincipal(part, principals) {
  let best = null, bestDistance = Infinity, bestCenterDistance = Infinity;
  for (const principal of principals) {
    const [x, y] = part.center, [left, top, right, bottom] = principal.bbox;
    const dx = Math.max(left - x, 0, x - (right - 1));
    const dy = Math.max(top - y, 0, y - (bottom - 1));
    const distance = dx * dx + dy * dy;
    const centerDistance = (x - principal.center[0]) ** 2 + (y - principal.center[1]) ** 2;
    if (distance < bestDistance || (distance === bestDistance && centerDistance < bestCenterDistance)) {
      best = principal; bestDistance = distance; bestCenterDistance = centerDistance;
    }
  }
  return best;
}

// Multi-source breadth-first propagation deliberately traverses transparent
// pixels too. Isolated alpha=1 wisps therefore retain the nearest core's owner,
// even when they are not connected to an opaque silhouette. Ties are stable in
// source scan order; no already labelled core or pixel can be reassigned.
function propagateOwners(componentIds, componentOwners, width, height) {
  const labels = new Uint8Array(width * height), queue = new Uint32Array(labels.length);
  let head = 0, tail = 0;
  for (let pixel = 0; pixel < labels.length; pixel++) {
    if (!componentIds[pixel]) continue;
    labels[pixel] = componentOwners[componentIds[pixel]] + 1;
    queue[tail++] = pixel;
  }
  while (head < tail) {
    const pixel = queue[head++], x = pixel % width, y = Math.floor(pixel / width);
    for (let dy = -1; dy <= 1; dy++) for (let dx = -1; dx <= 1; dx++) {
      if (!dx && !dy) continue;
      const nx = x + dx, ny = y + dy;
      if (nx < 0 || ny < 0 || nx >= width || ny >= height) continue;
      const next = ny * width + nx;
      if (labels[next]) continue;
      labels[next] = labels[pixel]; queue[tail++] = next;
    }
  }
  return labels;
}

function segmentSource(data, width, height, count = 16) {
  if (!Number.isInteger(width) || !Number.isInteger(height) || width < 1 || height < 1
      || data.length !== width * height * 4 || ![8, 16].includes(count)) {
    throw Error('Segmentation requires valid RGBA dimensions and 8 or 16 poses');
  }
  const {ids, components} = coreComponents(data, width, height);
  const principals = components.filter(part => part.count >= MIN_PRINCIPAL_PIXELS);
  const groups = Array.from({length: count}, () => []);
  const owners = new Int16Array(components.length + 1); owners.fill(-1);
  for (const part of principals) {
    const index = nominalIndex(part.center, width, height, count);
    part.frame_index = index; owners[part.id] = index; groups[index].push(part);
  }
  const missing = groups.map((group, index) => group.length ? -1 : index).filter(index => index >= 0);
  if (missing.length) throw Error('Segmentation missing principal core for source poses: ' + missing.join(', '));
  const attached = [];
  for (const part of components) {
    if (owners[part.id] >= 0) continue;
    const principal = nearestPrincipal(part, principals);
    owners[part.id] = principal.frame_index;
    attached.push({id: part.id, count: part.count, bbox: part.bbox,
      frame_index: principal.frame_index, attached_to_core: principal.id});
  }
  const labels = propagateOwners(ids, owners, width, height);
  const boxes = Array.from({length: count}, () => [width, height, 0, 0]);
  const counts = Array(count).fill(0);
  let nonzero = 0, alphaOne = 0, unassigned = 0;
  const visible = Buffer.alloc(data.length);
  for (let pixel = 0; pixel < labels.length; pixel++) {
    if (!data[pixel * 4 + 3]) continue;
    nonzero++; alphaOne += data[pixel * 4 + 3] === 1;
    const index = labels[pixel] - 1;
    if (index < 0 || index >= count) {unassigned++; continue;}
    const x = pixel % width, y = Math.floor(pixel / width), box = boxes[index];
    box[0] = Math.min(box[0], x); box[1] = Math.min(box[1], y);
    box[2] = Math.max(box[2], x + 1); box[3] = Math.max(box[3], y + 1);
    counts[index]++;
    data.copy(visible, pixel * 4, pixel * 4, pixel * 4 + 4);
  }
  if (unassigned) throw Error('Segmentation omitted ' + unassigned + ' nonzero-alpha pixels');
  const layout = boxes.map(box => {
    const left = Math.max(0, box[0] - 1), top = Math.max(0, box[1] - 1);
    return [left, top, Math.min(width, box[2] + 1) - left, Math.min(height, box[3] + 1) - top];
  });
  const reconstructed = Buffer.alloc(data.length), coverage = new Uint8Array(labels.length);
  for (let index = 0; index < count; index++) {
    const [left, top, w, h] = layout[index];
    const pixels = maskedFramePixels(data, labels, width, layout[index], index);
    for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
      const sourcePixel = (top + y) * width + left + x, offset = (y * w + x) * 4;
      if (!pixels[offset + 3]) continue;
      coverage[sourcePixel]++;
      pixels.copy(reconstructed, sourcePixel * 4, offset, offset + 4);
    }
  }
  let omitted = 0, duplicated = 0;
  for (let pixel = 0; pixel < labels.length; pixel++) {
    if (!data[pixel * 4 + 3]) continue;
    omitted += coverage[pixel] === 0; duplicated += coverage[pixel] > 1;
  }
  if (omitted || duplicated || !reconstructed.equals(visible)) {
    throw Error('Segmented RGBA reconstruction lost, duplicated or changed source pixels');
  }
  return {
    labels, layout,
    coverage: {nonzero_source_pixels: nonzero, omitted_nonzero_pixels: omitted,
      duplicated_nonzero_pixels: duplicated, preserved_alpha_one_pixels: alphaOne,
      source_visible_rgba_sha256: sha(visible), reconstructed_visible_rgba_sha256: sha(reconstructed)},
    summary: {method: 'core_components_and_multisource_8_neighbor_bfs', core_alpha_greater_than: CORE_ALPHA,
      minimum_principal_pixels: MIN_PRINCIPAL_PIXELS, source_grid: [4, count / 4],
      principal_component_count: principals.length, core_component_count: components.length,
      discarded_core_components: 0, discarded_nonzero_alpha_pixels: 0,
      principal_groups: groups.map((parts, index) => ({index, core_components: parts,
        assigned_nonzero_pixels: counts[index]})), attached_small_components: attached},
  };
}

function maskedFramePixels(data, labels, width, window, index) {
  const [left, top, w, h] = window, result = Buffer.alloc(w * h * 4);
  for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
    const sourcePixel = (top + y) * width + left + x;
    if (labels[sourcePixel] !== index + 1 || !data[sourcePixel * 4 + 3]) continue;
    data.copy(result, (y * w + x) * 4, sourcePixel * 4, sourcePixel * 4 + 4);
  }
  return result;
}

module.exports = {segmentSource, maskedFramePixels, CORE_ALPHA, MIN_PRINCIPAL_PIXELS};
