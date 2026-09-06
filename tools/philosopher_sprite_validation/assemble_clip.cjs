// Encode the actual Godot viewport captures, using their recorded wall times.
// No sprites, scene content or in-between animation frames are reconstructed.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');

function loadSharp() {
  for (const candidate of [
    process.env.SHARP_PATH, 'sharp',
    'C:/Users/paolo/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp',
  ].filter(Boolean)) {
    try { return require(candidate); } catch (error) {
      if (error.code !== 'MODULE_NOT_FOUND') throw error;
    }
  }
  throw new Error('Install sharp locally or set SHARP_PATH.');
}

function meanAbsoluteError(first, second) {
  if (first.length !== second.length) throw new Error('Image signature size mismatch.');
  let sum = 0;
  for (let index = 0; index < first.length; index++) sum += Math.abs(first[index] - second[index]);
  return sum / first.length;
}

async function verifyEncodedAnimation(sharp, outputPath, sourcePages, sourceDelays, width, height) {
  const metadata = await sharp(outputPath, { animated: true }).metadata();
  const encodedFrames = metadata.pages || 1;
  if (metadata.width !== width || (metadata.pageHeight || metadata.height) !== height) {
    throw new Error('Encoded animation dimensions are incorrect.');
  }
  if (!Array.isArray(metadata.delay) || metadata.delay.length !== encodedFrames ||
      metadata.delay.some(delay => !Number.isInteger(delay) || delay <= 0)) {
    throw new Error('Encoded animation has missing or invalid frame delays.');
  }
  const expectedDuration = sourceDelays.reduce((sum, delay) => sum + delay, 0);
  const encodedDuration = metadata.delay.reduce((sum, delay) => sum + delay, 0);
  if (encodedDuration !== expectedDuration) {
    throw new Error('GIF duration changed: expected ' + expectedDuration + ' ms, encoded ' + encodedDuration + ' ms.');
  }
  // GIF can coalesce consecutive identical viewport captures. Validate the
  // original timeline rather than requiring one GIF page per capture. Every
  // encoded boundary must still coincide with an original rounded timestamp.
  const boundaries = [0];
  for (const delay of sourceDelays) boundaries.push(boundaries.at(-1) + delay);
  const boundarySet = new Set(boundaries);
  const signatureWidth = Math.min(width, 96);
  const signatureHeight = Math.max(1, Math.round(height * signatureWidth / width));
  const signatures = [];
  let distinctStates = 0, previousHash = '';
  for (const page of sourcePages) {
    const hash = crypto.createHash('sha256').update(page).digest('hex');
    if (hash !== previousHash) distinctStates++;
    previousHash = hash;
    signatures.push(await sharp(page, { raw: { width, height, channels: 3 } })
      .resize(signatureWidth, signatureHeight).raw().toBuffer());
  }
  const timeline = [];
  let sourceIndex = 0, start = 0, maximumMatchError = 0;
  for (let encodedIndex = 0; encodedIndex < encodedFrames; encodedIndex++) {
    const end = start + metadata.delay[encodedIndex];
    if (!boundarySet.has(end)) throw new Error('GIF changed a captured image transition at ' + end + ' ms.');
    const decoded = await sharp(outputPath, { page: encodedIndex, pages: 1 })
      .removeAlpha().resize(signatureWidth, signatureHeight).raw().toBuffer();
    const errors = signatures.map(signature => meanAbsoluteError(signature, decoded));
    const nearestError = Math.min(...errors);
    const nearestIndex = errors.indexOf(nearestError);
    const firstSource = sourceIndex;
    while (sourceIndex < sourcePages.length && boundaries[sourceIndex] < end) {
      // Palette quantization precludes byte-identical RGB comparisons. The
      // image decoded for each original time interval must be closest to its
      // expected capture, among every captured image; identical states tie.
      if (errors[sourceIndex] > nearestError + 1e-9) {
        throw new Error('GIF image order mismatch at ' + boundaries[sourceIndex] +
          ' ms: encoded page ' + encodedIndex + ' matches capture ' + nearestIndex +
          ' instead of capture ' + sourceIndex + '.');
      }
      maximumMatchError = Math.max(maximumMatchError, errors[sourceIndex]);
      sourceIndex++;
    }
    if (sourceIndex === firstSource) throw new Error('GIF contains an extra untimed image.');
    timeline.push({ encoded_frame: encodedIndex, first_source_frame: firstSource,
      last_source_frame: sourceIndex - 1, start_ms: start, end_ms: end });
    start = end;
  }
  if (sourceIndex !== sourcePages.length) throw new Error('GIF omits captured images at the end.');
  return { metadata, encoded_frames: encodedFrames, distinct_source_states: distinctStates,
    source_images_checked_in_order: sourceIndex, signature_size: [signatureWidth, signatureHeight],
    maximum_palette_mean_error: maximumMatchError, timeline };
}

async function main() {
  const sharp = loadSharp();
  const manifestPath = path.resolve(process.argv[2] ||
    'artifacts/philosopher_sprite_validation_v1/clip/clip_manifest.json');
  const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
  const frames = manifest.frames;
  if (!Array.isArray(frames) || frames.length < 2 || manifest.frame_limit_reached) {
    throw new Error('A complete capture of at least two frames is required.');
  }
  const directory = path.dirname(manifestPath);
  const firstTime = frames[0].capture_usec;
  const width = manifest.rectangle_px[2] * 2;
  const height = manifest.rectangle_px[3] * 2;
  const pages = [];
  const delays = [];
  for (let index = 0; index < frames.length; index++) {
    const frame = frames[index];
    const startCs = Math.round((frame.capture_usec - firstTime) / 10000);
    const nextTime = index + 1 < frames.length
      ? frames[index + 1].capture_usec : manifest.ended_usec;
    const endCs = Math.round((nextTime - firstTime) / 10000);
    if (endCs <= startCs) throw new Error(`Invalid frame timing at ${index}.`);
    delays.push((endCs - startCs) * 10);
    const imagePath = path.resolve(frame.path);
    if (path.dirname(imagePath) !== directory) throw new Error('Frame outside capture directory.');
    pages.push(await sharp(imagePath).removeAlpha().resize(width, height).raw().toBuffer());
  }
  const outputPath = path.resolve(process.argv[3] || path.join(directory, 'philosopher_gameplay.gif'));
  fs.mkdirSync(path.dirname(outputPath), { recursive: true });
  await sharp(Buffer.concat(pages), {
    raw: { width, height: height * pages.length, channels: 3, pageHeight: height },
  }).gif({ delay: delays, loop: 0, effort: 6, colours: 256 }).toFile(outputPath);
  const poster = frames.find(frame => ['attack_', 'heal_', 'shield_', 'control_'].some(prefix => String(frame.animation).startsWith(prefix))) || frames[0];
  await sharp(poster.path).resize(width, height).png().toFile(outputPath.replace(/\.gif$/i, '.poster.png'));
  const validation = await verifyEncodedAnimation(sharp, outputPath, pages, delays, width, height);
  const metadata = validation.metadata;
  const report = {
    input: manifestPath, output: outputPath, frames: pages.length,
    source_manifest_sha256: crypto.createHash('sha256').update(fs.readFileSync(manifestPath)).digest('hex'),
    gif_sha256: crypto.createHash('sha256').update(fs.readFileSync(outputPath)).digest('hex'),
    encoded_frames: validation.encoded_frames, distinct_source_states: validation.distinct_source_states,
    merged_capture_frames: pages.length - validation.encoded_frames,
    source_images_checked_in_order: validation.source_images_checked_in_order,
    image_order_signature_size: validation.signature_size,
    maximum_palette_mean_error: validation.maximum_palette_mean_error,
    encoded_timeline: validation.timeline,
    size: [width, height], source_duration_ms: (manifest.ended_usec - firstTime) / 1000,
    encoded_duration_ms: metadata.delay.reduce((sum, value) => sum + value, 0),
    delays_ms: metadata.delay,
    note: 'Real game capture, fixed crop enlarged 2x. Original timestamps rounded to GIF centiseconds; identical holds may merge without changing duration. Dimensions, total duration, transition timestamps and nearest captured image in chronological order are checked after decoding. GPU capture may perturb playback; use the separate timing report for measurements.',
  };
  fs.writeFileSync(outputPath.replace(/\.gif$/i, '.encode_report.json'), JSON.stringify(report, null, 2) + '\n');
  console.log(JSON.stringify(report, null, 2));
}

main().catch(error => { console.error(error); process.exitCode = 1; });
