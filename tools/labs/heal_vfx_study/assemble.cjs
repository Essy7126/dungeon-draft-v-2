// Assemble Blender exports or encode unchanged Godot viewport frames.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const sharp = require(process.env.SHARP_PATH || 'C:/Users/paolo/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const root = path.resolve(__dirname, '../../..');
const out = path.join(root, 'artifacts/dev/heal_vfx_study');
const recipe = JSON.parse(fs.readFileSync(path.join(__dirname, 'recipe.json')));
const hash = p => crypto.createHash('sha256').update(fs.readFileSync(p)).digest('hex');

async function pack() {
  const source = JSON.parse(fs.readFileSync(path.join(out, 'blender_manifest.json')));
  const target = path.join(__dirname, 'generated');
  fs.mkdirSync(target, { recursive: true });
  const report = { source, atlases: [], checks: [] };
  for (const part of ['rear', 'front']) {
    const layers = [];
    const alphaCounts = [];
    for (let i = 0; i < recipe.frames; i++) {
      const input = path.join(out, 'blender_frames', part, `${String(i).padStart(3, '0')}.png`);
      const { data, info } = await sharp(input).ensureAlpha().raw().toBuffer({ resolveWithObject: true });
      if (info.width !== recipe.frame_size || info.height !== recipe.frame_size) throw new Error('Unexpected frame dimensions');
      let occupied = 0, border = 0;
      for (let y = 0; y < info.height; y++) for (let x = 0; x < info.width; x++) {
        const a = data[(y*info.width+x)*4+3];
        if (a > 10) { occupied++; if (x===0 || y===0 || x===info.width-1 || y===info.height-1) border++; }
      }
      if (border) throw new Error(`${part}/${i}: clipped effect`);
      alphaCounts.push(occupied);
      layers.push({ input, left: (i%recipe.columns)*recipe.frame_size, top: Math.floor(i/recipe.columns)*recipe.frame_size });
    }
    if (alphaCounts[0] !== 0 || alphaCounts.at(-1) !== 0 || Math.max(...alphaCounts) < 200) throw new Error('Empty or unclosed animation');
    const atlas = path.join(target, `${part}.png`);
    await sharp({ create: { width: recipe.columns*recipe.frame_size, height: recipe.rows*recipe.frame_size, channels:4, background:'#00000000' } }).composite(layers).png().toFile(atlas);
    const resPath = `res://tools/labs/heal_vfx_study/generated/${part}.png`;
    const manifest = {
      schema_version:1, asset_id:`${recipe.id}_${part}`, source_tool:'BLENDER_SCRIPTED_GEOMETRY',
      columns:recipe.columns, rows:recipe.rows, frame_count:recipe.frames, frames_per_second:recipe.fps,
      loop:false, playback_mode:'SOURCE_FPS', blend_mode:'MIX', alpha_mode:'STRAIGHT',
      pivot_normalized:source.pivot_normalized, nominal_size_in_cells:[2,4],
      art_status:'READY_FOR_HUMAN_REVIEW', license_status:'INTERNAL_TEST',
      variants:[{ variant_id:'default', texture_low:resPath, frame_size_low:recipe.frame_size }],
      generator_checksum:hash(path.join(__dirname,'build_blender.py')), texture_checksums:{[resPath]:hash(atlas)}
    };
    fs.writeFileSync(path.join(target, `${part}.json`), JSON.stringify(manifest,null,2)+'\n');
    report.atlases.push({ part, sha256:hash(atlas), alpha_counts:alphaCounts });
  }
  report.checks = ['72 PNG frames present', 'dimensions correct', 'transparent first and last frames', 'no clipped occupied border', 'visible animation in each layer'];
  fs.writeFileSync(path.join(target,'preview.json'),JSON.stringify({ pivot:source.pivot_normalized, recipe },null,2)+'\n');
  fs.writeFileSync(path.join(out,'atlas_report.json'),JSON.stringify(report,null,2)+'\n');
  console.log(JSON.stringify({ mode:'pack', checks:report.checks, atlases:report.atlases.map(a=>({part:a.part,sha256:a.sha256})) }));
}

async function encode() {
  const report = JSON.parse(fs.readFileSync(path.join(out,'godot_report.json')));
  if (!report.ok || report.capture_frames !== 72) throw new Error('Incomplete Godot capture');
  const buffers=[];
  for(let i=0;i<72;i++) {
    const {data,info}=await sharp(path.join(out,'godot_frames',`${String(i).padStart(3,'0')}.png`)).removeAlpha().raw().toBuffer({resolveWithObject:true});
    if(info.width!==1280 || info.height!==800) throw new Error('Unexpected viewport size');
    buffers.push(data);
  }
  await sharp(Buffer.concat(buffers),{raw:{width:1280,height:800*72,channels:3,pageHeight:800}})
    .gif({loop:0,delay:Array.from({length:72},(_,i)=>i%3===2?40:30),colours:256,effort:5})
    .toFile(path.join(out,'heal_preview.gif'));
  const meta=await sharp(path.join(out,'heal_preview.gif'),{animated:true}).metadata();
  const durations=meta.delay.reduce((a,b)=>a+b,0);
  if(meta.pages!==72 || durations!==2400) throw new Error('Unexpected encoded duration');
  fs.writeFileSync(path.join(out,'encode_report.json'),JSON.stringify({frames:meta.pages,duration_ms:durations,width:meta.width,height:meta.pageHeight,source:'Unchanged Godot viewport captures; GIF palette quantization',inputs:['study.gd','recipe.json','generated/front.png','generated/rear.png'].map(p=>({path:p,sha256:hash(path.join(__dirname,p))}))},null,2)+'\n');
  console.log(JSON.stringify({gif:path.join(out,'heal_preview.gif'),frames:meta.pages,duration_ms:durations}));
}
(process.argv.includes('--encode')?encode():pack()).catch(e=>{console.error(e);process.exitCode=1;});
