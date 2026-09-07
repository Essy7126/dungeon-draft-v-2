'use strict';

function checkLayout(layout, metadata, sourceHash) {
  if (!layout || typeof layout !== 'object' || Array.isArray(layout)) throw Error('Explicit source layout must be an object.');
  if (layout.source_sha256 !== sourceHash) throw Error('source_layout.json belongs to another source SHA-256; remeasure before use.');
  if (!Array.isArray(layout.source_size) || layout.source_size[0] !== metadata.width || layout.source_size[1] !== metadata.height) {
    throw Error('Source layout dimensions do not match the PNG.');
  }
  if (!Array.isArray(layout.bands) || layout.bands.length !== 6 || !Array.isArray(layout.columns)
      || layout.columns.length !== 6 || !Array.isArray(layout.centers) || layout.centers.length !== 6) {
    throw Error('Layout requires six bands, six column-boundary arrays and six center arrays.');
  }
  const cleaning = layout.boundary_cleaning;
  if (!cleaning || cleaning.width !== 1 || !Number.isInteger(cleaning.maximum_alpha)
      || cleaning.maximum_alpha < 0 || cleaning.maximum_alpha > 32) {
    throw Error('Boundary cleaning is limited to one pixel and an explicit alpha ceiling between 0 and 32.');
  }
  const cells = [];
  let previousY = 0;
  for (let row = 0; row < 6; row++) {
    const band = layout.bands[row], edges = layout.columns[row], centers = layout.centers[row];
    if (!Array.isArray(band) || band.length !== 2 || !band.every(Number.isInteger)
        || band[0] !== previousY || band[1] <= band[0] || band[1] > metadata.height) throw Error(`Invalid contiguous band ${row}.`);
    previousY = band[1];
    if (!Array.isArray(edges) || edges.length !== 5 || !edges.every(Number.isInteger)
        || edges[0] !== 0 || edges[4] !== metadata.width || edges.some((value, index) => index && value <= edges[index - 1])) {
      throw Error(`Invalid complete column partition in row ${row}.`);
    }
    if (!Array.isArray(centers) || centers.length !== 4) throw Error(`Four explicit centers required for row ${row}.`);
    for (let col = 0; col < 4; col++) {
      const center = centers[col];
      if (!Array.isArray(center) || center.length !== 2 || !center.every(Number.isInteger)
          || center[0] < edges[col] || center[0] >= edges[col + 1] || center[1] < band[0] || center[1] >= band[1]) {
        throw Error(`Invalid declared center for row ${row}, column ${col}.`);
      }
      cells.push({ crop: { left: edges[col], top: band[0], width: edges[col + 1] - edges[col], height: band[1] - band[0] },
        anchor: [center[0] - edges[col], center[1] - band[0]], global_anchor: center.slice() });
    }
  }
  if (previousY !== metadata.height) throw Error('Bands must partition the entire source height.');
  return { cells, cleaning: { ...cleaning } };
}

function cleanBoundary(raw, width, height, ceiling, label) {
  const stats = { width: 1, allowed_maximum_alpha: ceiling, pixels_removed: 0, alpha_sum_removed: 0,
    maximum_alpha_removed: 0, pixels_above_32_removed: 0 };
  // Inspect first; never partly clean a cell that contains a cut strong pixel.
  for (let y = 0; y < height; y++) for (let x = 0; x < width; x++) {
    if (x && y && x !== width - 1 && y !== height - 1) continue;
    const alpha = raw[(y * width + x) * 4 + 3];
    if (alpha > ceiling) throw Error(`${label}: measured cut crosses alpha ${alpha} at local ${x},${y}; allowed boundary alpha is ${ceiling}.`);
  }
  for (let y = 0; y < height; y++) for (let x = 0; x < width; x++) {
    if (x && y && x !== width - 1 && y !== height - 1) continue;
    const index = (y * width + x) * 4 + 3, alpha = raw[index];
    if (!alpha) continue;
    stats.pixels_removed++;
    stats.alpha_sum_removed += alpha;
    stats.maximum_alpha_removed = Math.max(stats.maximum_alpha_removed, alpha);
    raw[index] = 0;
  }
  return stats;
}

function commonAnchoredSquare(frames) {
  let radius = 0;
  for (const frame of frames) {
    const box = frame.source_alpha.alpha_bounds.all, [x, y] = frame.source_anchor;
    radius = Math.max(radius, x - box[0], y - box[1], box[2] - x, box[3] - y);
  }
  const side = Math.ceil(radius + 2) * 2;
  return { width: side, height: side, radius: side / 2 };
}

module.exports = { checkLayout, cleanBoundary, commonAnchoredSquare };
