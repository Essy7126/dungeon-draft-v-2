// Measure existing artwork; this does not regenerate, retime, or alter animation frames.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const sharp=require('C:/Users/paolo/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const root=path.resolve(__dirname,'../..');
const source=path.join(root,'art/source/characters/achilles/passe_rive_motion_v1');
const out=path.join(root,'artifacts/spine_trial/passe_rive_walk_audit');
const hash=p=>crypto.createHash('sha256').update(fs.readFileSync(p)).digest('hex');
const roi={x:647,y:1370,width:92,height:65};
function templateMatch(a,b){
 const samples=[];
 for(let y=roi.y;y<roi.y+roi.height;y+=3)for(let x=roi.x;x<roi.x+roi.width;x+=3){
  const p=(y*1024+x)*4;if(a[p+3]<240)continue;
  samples.push({x,y,v:[a[p],a[p+1],a[p+2]]});
 }
 function score(dx,dy){let err=0;
  for(const s of samples){const p=((s.y+dy)*1024+s.x+dx)*4;
   for(let c=0;c<3;c++)err+=(s.v[c]-b[p+c])**2;
   err+=(a[(s.y*1024+s.x)*4+3]-b[p+3])**2;
  }return Math.sqrt(err/(4*samples.length));
 }
 let best={rmse:Infinity};
 for(let dy=-85;dy<=85;dy+=2)for(let dx=-145;dx<=95;dx+=2){const e=score(dx,dy);if(e<best.rmse)best={dx,dy,rmse:e};}
 const coarse={...best};
 for(let dy=coarse.dy-2;dy<=coarse.dy+2;dy++)for(let dx=coarse.dx-2;dx<=coarse.dx+2;dx++){const e=score(dx,dy);if(e<best.rmse)best={dx,dy,rmse:e};}
 return {...best,sample_count:samples.length,search_pixels:{dx:[-145,95],dy:[-85,85]},assumption:'Translation-only patch comparison; not a pose detector or whole-cycle anatomical tracker'};
}
async function main(){
 fs.mkdirSync(out,{recursive:true});
 const files=[0,1,2].map(i=>path.join(source,'walk_'+String(i).padStart(2,'0')+'_rgba_v2.png'));
 const raw=await Promise.all(files.map(p=>sharp(p).ensureAlpha().raw().toBuffer()));
 const manifest=JSON.parse(fs.readFileSync(path.join(source,'delivery_manifest.json')));
 const guide=JSON.parse(fs.readFileSync(path.join(source,'walk_guide.json')));
 const perFrame=manifest.guide_speed_m_s*(manifest.walk_seconds/8)*manifest.projected_forward_pixels_per_meter;
 const matches=[1,2].map(i=>{
  const m=templateMatch(raw[0],raw[i]),expected=[-perFrame*i,-perFrame*.5*i];
  const residual=[m.dx-expected[0],m.dy-expected[1]];
  return {from:0,to:i,...m,expected_translation_px:expected,world_residual_px:residual,world_residual_magnitude_px:Math.hypot(...residual),at_220px_body_height:Math.hypot(...residual)*220/1340};
 });
 const passages=[2,6].map(i=>{const p=guide.poses[i],swing=i===2?'R':'L',support=i===2?'L':'R';return {index:i,label:p.label,swing_y:p.feet[swing].ankle[1],support_y:p.feet[support].ankle[1],swing_behind_support_m:p.feet[support].ankle[1]-p.feet[swing].ankle[1],pelvis_x:p.joints.pelvis[0],support_x:p.feet[support].ankle[0],pelvis_shift_opposes_support:Math.sign(p.joints.pelvis[0])!==Math.sign(p.feet[support].ankle[0])};});
 const results={schema:1,source_files:files.map(p=>({file:path.relative(root,p).replaceAll('\\','/'),sha256:hash(p)})),template_region:roi,matches,guide_passages:passages,discrete_hold:{seconds:manifest.walk_seconds/8,root_travel_per_hold_at_220_px:Math.hypot(perFrame,perFrame*.5)*220/1340},limits:['Patch matching is evidence for frames 1 to 3 only, under a translation approximation','Expected drift uses the existing review calibration, not a measured game speed','Uniform sprite holds necessarily produce some within-frame slide with continuous root motion; judge at intended size and cadence','Pelvis position is not the center of mass; opposing lateral shift is a construction flaw, not a physical stability proof']};
 fs.writeFileSync(path.join(out,'audit.json'),JSON.stringify(results,null,2));
 console.log(JSON.stringify(results));
}
main().catch(e=>{console.error(e);process.exitCode=1});
