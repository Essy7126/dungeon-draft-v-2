const fs=require('node:fs'), path=require('node:path'), crypto=require('node:crypto');
const sharp=require(process.env.SHARP_PATH || 'C:/Users/paolo/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const root=path.resolve(__dirname,'../..'), output=path.join(root,'assets/vfx/class_cards');
const source=path.join(root,'artifacts/dev/class_card_vfx/render');
const hash=p=>crypto.createHash('sha256').update(fs.readFileSync(p)).digest('hex');
async function main(){
 fs.mkdirSync(output,{recursive:true});
 const report=[];
 const recipes=JSON.parse(fs.readFileSync(path.join(source,'manifest.json')));
 for(const recipe of recipes){
  for(const part of ['rear','front']){
   const layers=[], counts=[];
   for(let i=0;i<recipe.frames;i++){
    const input=path.join(source,recipe.family,part,`${String(i).padStart(2,'0')}.png`);
    const {data,info}=await sharp(input).ensureAlpha().raw().toBuffer({resolveWithObject:true});
    if(info.width!==recipe.size || info.height!==recipe.size) throw Error('Frame size');
    let count=0;
    for(let y=0;y<info.height;y++)for(let x=0;x<info.width;x++)if(data[(y*info.width+x)*4+3]>10){
     count++;
     if(x===0||y===0||x===info.width-1||y===info.height-1)throw Error(`Clipped ${recipe.family}/${part}/${i}`);
    }
    counts.push(count); layers.push({input,left:i%6*recipe.size,top:Math.floor(i/6)*recipe.size});
   }
   if(counts[0]||counts.at(-1)||Math.max(...counts)<10)throw Error(`Empty/unclosed ${recipe.family}/${part}`);
   const name=recipe.family+'_'+part, dest=path.join(output,name+'.png');
   await sharp({create:{width:recipe.size*6,height:recipe.size*4,channels:4,background:'#00000000'}}).composite(layers).png().toFile(dest);
   const res='res://assets/vfx/class_cards/'+name+'.png';
   fs.writeFileSync(path.join(output,name+'.json'),JSON.stringify({schema_version:1,asset_id:'class_cards_'+name,source_tool:'BLENDER_SCRIPTED_GEOMETRY',columns:6,rows:4,frame_count:24,frames_per_second:30,loop:false,playback_mode:'FIT_MODULE_DURATION',blend_mode:'MIX',alpha_mode:'STRAIGHT',pivot_normalized:recipe.pivot,nominal_size_in_cells:[1.5,3],art_status:'READY_FOR_HUMAN_REVIEW',license_status:'COMMERCIAL_CLEARED',variants:[{variant_id:'default',texture_low:res,frame_size_low:recipe.size}],generator_checksum:hash(path.join(__dirname,'build_blender.py')),texture_checksums:{[res]:hash(dest)}},null,2)+'\n');
   report.push({name,sha256:hash(dest),occupied_pixels:counts});
  }
 }
 // Promote the approved original heal to a production-owned path.
 for(const part of ['rear','front']){
  const original=path.join(root,'tools/labs/heal_vfx_study/generated',part);
  const name='heal_'+part, dest=path.join(output,name+'.png');
  fs.copyFileSync(original+'.png',dest);
  const manifest=JSON.parse(fs.readFileSync(original+'.json'));
  const res='res://assets/vfx/class_cards/'+name+'.png';
  Object.assign(manifest,{asset_id:'class_cards_'+name,art_status:'ART_APPROVED',license_status:'COMMERCIAL_CLEARED',variants:[{variant_id:'default',texture_low:res,frame_size_low:384}],texture_checksums:{[res]:hash(dest)}});
  fs.writeFileSync(path.join(output,name+'.json'),JSON.stringify(manifest,null,2)+'\n');
 }
 fs.writeFileSync(path.join(root,'artifacts/dev/class_card_vfx/atlas_report.json'),JSON.stringify({families:recipes.length+1,atlases:report,checks:['dimensions','unclipped borders','transparent endpoints','visible layers']},null,2));
 console.log(JSON.stringify({families:recipes.length+1,atlases:report.length+2,ok:true}));
}
main().catch(e=>{console.error(e);process.exitCode=1;});
