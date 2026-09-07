#!/usr/bin/env node
/** Mechanical packing of authored RGBA only; never paints, keys or recolors pixels. */
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
let sharp;
try { sharp = require('sharp'); } catch {
  sharp = require(process.env.SHARP_PATH || 'C:/Users/paolo/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
}
const ROOT = path.resolve(__dirname, '../..');
const SOURCE = 'art/source/vfx/achilles_guard_bronze_v1/guard_source_v2.png';
const OUTPUT = 'vfx/assets/flipbooks/achilles_guard_bronze_v1';
const SIZE = 256, SCALE = 0.78, ANCHOR = [128, 210];
// One source-space ground center per entire row, measured at the ellipse center.
// No per-frame normalization: growth, recoil and dissipating particles are authored.
const ROW_ANCHOR_Y = [263, 577, 891, 1205];
const CLIPS = {
  activation: { indices: [0,1,2,3,4,5,6,7], columns: 4, rows: 2, fps: 16, loop: false },
  hold: { indices: [7], columns: 1, rows: 1, fps: 1, loop: false, fixed_pose: true },
  hit: { indices: [8,9,10,11], columns: 4, rows: 1, fps: 16, loop: false },
  end: { indices: [12,13,14,15], columns: 4, rows: 1, fps: 4 / 0.30, loop: false, runtime_fade_out_seconds: 0.05 },
};
const hash = value => crypto.createHash('sha256').update(value).digest('hex');

function analyze(data, width, height) {
  const histogram = new Array(256).fill(0);
  const boxes = Object.fromEntries([0,8,32,128].map(a => [a, [width,height,0,0]]));
  let sum = 0;
  for (let y=0; y<height; y++) for (let x=0; x<width; x++) {
    const a=data[(y*width+x)*4+3]; histogram[a]++; sum+=a;
    for (const threshold of [0,8,32,128]) if(a>threshold) {
      const b=boxes[threshold]; b[0]=Math.min(b[0],x);b[1]=Math.min(b[1],y);b[2]=Math.max(b[2],x+1);b[3]=Math.max(b[3],y+1);
    }
  }
  const margins={};
  for (const key of Object.keys(boxes)) {
    const b=boxes[key];
    if(b[2]===0) { boxes[key]=null; margins[key]=null; }
    else margins[key]=[b[0],b[1],width-b[2],height-b[3]];
  }
  return { alpha_histogram:histogram, alpha_sum:sum, alpha_bounds_by_threshold:boxes, margins_by_alpha_threshold:margins };
}

function packRaw(frames, columns, rows) {
  const width=SIZE*columns, pixels=Buffer.alloc(width*SIZE*rows*4);
  frames.forEach((raw,i)=>{
    const x=(i%columns)*SIZE,y=Math.floor(i/columns)*SIZE;
    for(let r=0;r<SIZE;r++) raw.copy(pixels,((y+r)*width+x)*4,r*SIZE*4,(r+1)*SIZE*4);
  });
  return pixels;
}

async function main() {
  const out=path.join(ROOT,OUTPUT); fs.mkdirSync(out,{recursive:true});
  const bytes=fs.readFileSync(path.join(ROOT,SOURCE));
  const meta=await sharp(bytes).metadata();
  if(meta.width!==1254 || meta.height!==1254 || !meta.hasAlpha) throw Error('Expected the selected transparent 1254 × 1254 source sheet.');
  const frames=[], buffers=[], rawBuffers=[];
  for(let i=0;i<16;i++) {
    const col=i%4,row=Math.floor(i/4);
    const x0=Math.round(col*meta.width/4),x1=Math.round((col+1)*meta.width/4);
    const y0=Math.round(row*meta.height/4),y1=Math.round((row+1)*meta.height/4);
    const crop={left:x0,top:y0,width:x1-x0,height:y1-y0};
    const cropped=await sharp(bytes).extract(crop).raw().toBuffer();
    const original=analyze(cropped,crop.width,crop.height);
    if(original.margins_by_alpha_threshold[32].some(m=>m<5)) throw Error(`Frame ${i}: authored core crosses a cell boundary; inspect before packing.`);
    // Rounded raster size differs by at most one pixel between 313/314px source cells.
    // The nominal scale is constant for all source frames; no content-fit scaling.
    const width=Math.round(crop.width*SCALE),height=Math.round(crop.height*SCALE);
    const sourceAnchor=[(col+.5)*meta.width/4,ROW_ANCHOR_Y[row]];
    const localAnchor=[sourceAnchor[0]-x0,sourceAnchor[1]-y0];
    const left=Math.round(ANCHOR[0]-localAnchor[0]*width/crop.width);
    const top=Math.round(ANCHOR[1]-localAnchor[1]*height/crop.height);
    if(left<0 || top<0 || left+width>SIZE || top+height>SIZE) throw Error(`Frame ${i}: source crop does not fit output canvas.`);
    const resized=await sharp(cropped,{raw:{width:crop.width,height:crop.height,channels:4}}).resize(width,height,{kernel:'lanczos3'}).raw().toBuffer();
    // Byte copies prevent repeated alpha premultiplication during padding/packing.
    const raw=Buffer.alloc(SIZE*SIZE*4);
    for(let y=0;y<height;y++) resized.copy(raw,((top+y)*SIZE+left)*4,y*width*4,(y+1)*width*4);
    const png=await sharp(raw,{raw:{width:SIZE,height:SIZE,channels:4}}).png().toBuffer();
    const packed=analyze(raw,SIZE,SIZE);
    if(packed.margins_by_alpha_threshold[32].some(m=>m<8)) throw Error(`Frame ${i}: packed core lacks a safe margin.`);
    frames.push({source_index:i, source_crop:crop, source_anchor:sourceAnchor, nominal_scale:SCALE, raster_size:[width,height], canvas_offset:[left,top], anchor_error:[left+localAnchor[0]*width/crop.width-ANCHOR[0],top+localAnchor[1]*height/crop.height-ANCHOR[1]], source_crop_rgba_sha256:hash(cropped), packed_rgba_sha256:hash(raw), source_alpha:original, packed_alpha:packed});
    buffers.push(png); rawBuffers.push(raw);
  }
  const atlases={};
  for(const [name,clip] of Object.entries(CLIPS)) {
    const atlasRaw=packRaw(clip.indices.map(i=>rawBuffers[i]),clip.columns,clip.rows);
    const png=await sharp(atlasRaw,{raw:{width:SIZE*clip.columns,height:SIZE*clip.rows,channels:4}}).png().toBuffer();
    fs.writeFileSync(path.join(out,`${name}.png`),png);
    atlases[name]={...clip,path:`${OUTPUT}/${name}.png`,size:[SIZE*clip.columns,SIZE*clip.rows],sha256:hash(png),duration_seconds:clip.fixed_pose?null:clip.indices.length/clip.fps};
  }
  const contact=await sharp(packRaw(rawBuffers,4,4),{raw:{width:SIZE*4,height:SIZE*4,channels:4}}).png().toBuffer();
  for(const [name,background] of [['light','#ddd6ba'],['dark','#192127']]) {
    await sharp(contact).flatten({background}).jpeg({quality:94}).toFile(path.join(out,`preview_${name}.jpg`));
  }
  // Preview only: show the shared ground origin as a small cross, outside runtime art.
  const crosses=Array.from({length:16},(_,i)=>{
    const x=(i%4)*SIZE+ANCHOR[0],y=Math.floor(i/4)*SIZE+ANCHOR[1];
    return `<path d="M ${x-6} ${y} h 12 M ${x} ${y-6} v 12" fill="none" stroke="#e84cff" stroke-width="1" opacity="0.7"/>`;
  }).join('');
  await sharp(contact).flatten({background:'#333a3a'}).composite([{input:Buffer.from(`<svg width="1024" height="1024" xmlns="http://www.w3.org/2000/svg">${crosses}</svg>`)}]).jpeg({quality:94}).toFile(path.join(out,'preview_contact.jpg'));
  const sequence=[0,1,2,3,4,5,6,7,7,8,9,10,11,7,12,13,14,15,-1];
  const delays=[60,60,70,60,60,60,70,60,600,60,60,70,60,600,80,70,80,70,450];
  for(const [name,background] of [['dark','#192127'],['light','#ddd6ba']]) {
    const pages=[];
    for(const i of sequence) {
      const png=i<0?await sharp({create:{width:SIZE,height:SIZE,channels:4,background:{r:0,g:0,b:0,alpha:0}}}).png().toBuffer():buffers[i];
      pages.push(await sharp(png).flatten({background}).raw().toBuffer());
    }
    await sharp(Buffer.concat(pages),{raw:{width:SIZE,height:SIZE*pages.length,channels:3,pageHeight:SIZE}}).gif({delay:delays,loop:0,effort:7}).toFile(path.join(out,`sequence_${name}_preview.gif`));
  }
  const manifest={schema_version:1,source:{path:SOURCE,sha256:hash(bytes),size:[meta.width,meta.height],has_alpha:meta.hasAlpha},frame_size:[SIZE,SIZE],ground_anchor:ANCHOR,source_ground_y_by_row:ROW_ANCHOR_Y,nominal_scale:SCALE,processing:{method:'Mechanical RGBA crop, uniform Lanczos3 downsample, transparent padding and atlas packing.',alpha:'Original straight RGBA and all authored partial alpha retained before resampling. No thresholding, background keying, color replacement, glow painting or edge erasure. Lanczos3 resampling necessarily interpolates RGBA/alpha.',core_threshold_is_measurement_only:32,source_cell_rounding:'nearest integer on four equal divisions',per_frame_fit_or_stabilization:false},atlases,frames,preview:{sequence,delays_ms:delays,backgrounds:['#192127','#ddd6ba'],contact_marker:'Magenta cross marks the logical ground origin, preview only.'}};
  fs.writeFileSync(path.join(out,'manifest.json'),JSON.stringify(manifest,null,2)+'\n');
  console.log(JSON.stringify({output:OUTPUT,frames:frames.length,atlases:Object.keys(atlases),minimum_core_margin:Math.min(...frames.flatMap(f=>f.packed_alpha.margins_by_alpha_threshold[32])),maximum_anchor_rounding_error:Math.max(...frames.flatMap(f=>f.anchor_error.map(Math.abs)))},null,2));
}
main().catch(error=>{console.error(error);process.exitCode=1;});
