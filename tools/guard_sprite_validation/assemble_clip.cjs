// Encode the actual Godot viewport captures, using their recorded wall times.
// No sprites, scene content or in-between animation frames are reconstructed.
const fs = require('node:fs');
const path = require('node:path');

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

async function main() {
  const sharp = loadSharp();
  const manifestPath = path.resolve(process.argv[2] ||
    'artifacts/guard_sprite_validation_v1/gameplay_clip/clip/clip_manifest.json');
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
  const outputPath = path.join(directory, 'garde_airain_gameplay.gif');
  await sharp(Buffer.concat(pages), {
    raw: { width, height: height * pages.length, channels: 3, pageHeight: height },
  }).gif({ delay: delays, loop: 0, effort: 6, colours: 256 }).toFile(outputPath);
  const poster = frames.find(frame => frame.phase === 'hit') || frames[0];
  await sharp(poster.path).resize(width, height).png().toFile(path.join(directory, 'poster.png'));
  const metadata = await sharp(outputPath, { animated: true }).metadata();
  if (metadata.pages !== pages.length || metadata.pageHeight !== height) {
    throw new Error('Encoded animation frame count or height is incorrect.');
  }
  const report = {
    input: manifestPath, output: outputPath, frames: pages.length,
    size: [width, height], source_duration_ms: (manifest.ended_usec - firstTime) / 1000,
    encoded_duration_ms: metadata.delay.reduce((sum, value) => sum + value, 0),
    delays_ms: metadata.delay,
    note: 'Real game capture, fixed crop enlarged 2x. Original frame timestamps rounded to GIF centiseconds. GPU capture may perturb playback; use the separate timing report for measurements.',
  };
  fs.writeFileSync(path.join(directory, 'encode_report.json'), JSON.stringify(report, null, 2) + '\n');
  console.log(JSON.stringify(report, null, 2));
}

main().catch(error => { console.error(error); process.exitCode = 1; });
