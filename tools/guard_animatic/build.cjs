/* Stage 2 only: key, register and mount authored drawings. No generated geometry. */
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
let sharp;
try { sharp = require('sharp'); } catch { sharp = require(process.env.SHARP_PATH || 'C:/Users/paolo/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp'); }
const root = path.resolve(__dirname, '../..');
const src = path.join(root, 'art/source/vfx/guard_pipeline_study_v1');
const out = path.join(root, 'artifacts/dev/guard_animatic_v1');
const hash = b => crypto.createHash('sha256').update(b).digest('hex');
const clamp = (x,a,b) => Math.min(b,Math.max(a,x));
// Manually identified midpoint of the two lower stroke tips, in source pixels.
// Translation only, one constant scale; do not fit each silhouette to its box.
const roots = [[256,440],[771,440],[1295,441],[262,909],[773,916],[1291,919]];
const scale = 0.58, size = 256, pivot = [128,210];
const times = [0,100,180,260,380,500];
const names = ['Repos','Concentration','Montée','Déploiement','Retrait','Maintien'];
function bounds(raw,w,h,threshold=32) {
  let x0=w,y0=h,x1=-1,y1=-1, count=0, soft=0, magenta=0;
  for(let y=0;y<h;y++) for(let x=0;x<w;x++) {
    const i=(y*w+x)*4,a=raw[i+3]; if(a>0&&a<255)soft++;
    if(a<=threshold)continue; count++;x0=Math.min(x0,x);x1=Math.max(x1,x);y0=Math.min(y0,y);y1=Math.max(y1,y);
    // Dark warm contours can have low green without being the key background.
    if(Math.min(raw[i],raw[i+2])>80&&Math.min(raw[i],raw[i+2])-raw[i+1]>50)magenta++;
  }
  return {bounds:count?[x0,y0,x1+1,y1+1]:null,core_pixels:count,soft_pixels:soft,magenta_core_pixels:magenta};
}
async function main(){
 fs.mkdirSync(out,{recursive:true});
 const sourcePath=path.join(src,'isolation_chroma_v2.png'), bytes=fs.readFileSync(sourcePath);
 const {data:rgb,info}=await sharp(bytes).removeAlpha().raw().toBuffer({resolveWithObject:true});
 if(info.width!==1536||info.height!==1024)throw Error('Unexpected source dimensions');
 const rgba=Buffer.alloc(info.width*info.height*4);let removed=0,partial=0;
 // Same chroma dominance, unmix and edge despill equations as the painted-G
 // pipeline chroma_key(). No connected-component removal or silhouette cleanup.
 for(let p=0;p<info.width*info.height;p++){
   const c=[rgb[p*3],rgb[p*3+1],rgb[p*3+2]], d=Math.min(c[0],c[2])-c[1];
   const a=Math.min(c[0],c[2])>60&&d>30?clamp((110-d)/70,0,1):1;
   if(a===0){removed++;continue;}
   let v=c;
   if(a<1){partial++;v=c.map((x,j)=>clamp((x-(1-a)*[255,0,255][j])/Math.max(a,1/255),0,255));const residual=Math.max(Math.min(v[0],v[2])-v[1]-18,0);v[0]-=residual;v[2]-=residual;}
   for(let j=0;j<3;j++)rgba[p*4+j]=Math.round(clamp(v[j],0,255));rgba[p*4+3]=Math.round(a*255);
 }
 await sharp(rgba,{raw:{width:1536,height:1024,channels:4}}).png().toFile(path.join(out,'isolated_rgba.png'));
 const frames=[], pngs=[], rawFrames=[];
 for(let i=0;i<6;i++){
   const col=i%3,row=Math.floor(i/3),crop={left:col*512,top:row*512,width:512,height:512};
   const cell=await sharp(rgba,{raw:{width:1536,height:1024,channels:4}}).extract(crop).raw().toBuffer();
   const measure=bounds(cell,512,512);if(i===0&&measure.core_pixels)throw Error('Empty pose contains foreground');
   const anchor=[roots[i][0]-crop.left,roots[i][1]-crop.top];
   const target=Buffer.alloc(size*size*4);
   // Crop the nonempty content with a safe gutter before uniform resampling.
   // Root coordinates still refer to the unchanged full source sheet.
   let error=[0,0],offset=[0,0];
   if(measure.bounds){
     const full=bounds(cell,512,512,0).bounds;
     const x=Math.max(0,full[0]-2), y=Math.max(0,full[1]-2), w=Math.min(512,full[2]+2)-x,h=Math.min(512,full[3]+2)-y;
     const rw=Math.round(w*scale),rh=Math.round(h*scale);
     const left=Math.round(pivot[0]-(anchor[0]-x)*rw/w),top=Math.round(pivot[1]-(anchor[1]-y)*rh/h);
     if(left<0||top<0||left+rw>size||top+rh>size)throw Error('Registered art clips its canvas');
     const resized=await sharp(cell,{raw:{width:512,height:512,channels:4}}).extract({left:x,top:y,width:w,height:h}).resize(rw,rh,{kernel:'linear'}).raw().toBuffer();
     for(let yy=0;yy<rh;yy++)resized.copy(target,((top+yy)*size+left)*4,yy*rw*4,(yy+1)*rw*4);
     error=[left+(anchor[0]-x)*rw/w-pivot[0],top+(anchor[1]-y)*rh/h-pivot[1]];offset=[left,top];
   }
   const m=bounds(target,size,size);
   if(m.magenta_core_pixels){await sharp(target,{raw:{width:size,height:size,channels:4}}).png().toFile(path.join(out,'rejected_edge.png'));throw Error(`Magenta core residue in pose ${i}: ${JSON.stringify(m)}`);}
   if(m.bounds&&Math.min(m.bounds[0],m.bounds[1],size-m.bounds[2],size-m.bounds[3])<8)throw Error('Insufficient margin');
   const png=await sharp(target,{raw:{width:size,height:size,channels:4}}).png().toBuffer();
   fs.writeFileSync(path.join(out,`pose_${i}.png`),png);pngs.push(png);rawFrames.push(target);
   frames.push({index:i,name:names[i],time_ms:times[i],source_crop:crop,source_anchor:roots[i],nominal_scale:scale,registration_error:error,offset,...m,sha256:hash(png)});
 }
 const actorPath='assets/characters/Achilles/sprites_painted_g/atlases/idle_E.png';
 const actor=await sharp(path.join(root,actorPath)).extract({left:0,top:0,width:512,height:384}).png().toBuffer();
 fs.writeFileSync(path.join(out,'actor_idle_E.png'),actor);
 const actorMeta=JSON.parse(fs.readFileSync(path.join(root,'assets/characters/Achilles/sprites_painted_g/manifest.json')));
 const manifest={stage:2,status:'ROUGH_ANIMATIC',source:{path:path.relative(root,sourcePath).replaceAll('\\','/'),sha256:hash(bytes),native_alpha:false},processing:{key:'painted-G chroma equations, no component deletion',resampling_kernel:'linear (Lanczos edge color overshoot rejected)',transparent_pixels:removed,partial_pixels:partial,per_frame_translation:true,scale,canvas:[size,size],pivot},timeline:{times_ms:times,duration_ms:500,interpolation:'none',final_pose:'held after 500 ms; no authored dissipation'},actor:{path:actorPath,sha256:hash(fs.readFileSync(path.join(root,actorPath))),frame:[0,0,512,384],foot_anchor:actorMeta.footAnchor,display_scale:actorMeta.suggestedDisplayScale},effect_display_canvas:130,frames};
 fs.writeFileSync(path.join(out,'manifest.json'),JSON.stringify(manifest,null,2)+'\n');
 const payload={manifest,frames:pngs.map(p=>'data:image/png;base64,'+p.toString('base64')),actor:'data:image/png;base64,'+actor.toString('base64')};
 const html=fs.readFileSync(path.join(__dirname,'review.template.html'),'utf8').replace('/*PAYLOAD*/',JSON.stringify(payload));
 fs.writeFileSync(path.join(out,'review.html'),html);
 // The same registered drawings, composed at source-profile scale. Enlarge the
 // entire preview 2x afterwards; actor/effect relative scale never changes.
 const contact=[],pages=[];
 for(const [bi,background] of ['#d9d1ba','#20262d'].entries()){
  for(let i=0;i<6;i++){
   const hero=await sharp(actor).resize(Math.round(512*.35),Math.round(384*.35)).png().toBuffer();
   const fx=await sharp(pngs[i]).resize(130,130).png().toBuffer();
   const panel=await sharp({create:{width:240,height:200,channels:4,background}}).composite([{input:hero,left:120-Math.round(256*.35),top:157-Math.round(320*.35)},{input:fx,left:120-65,top:157-Math.round(210*130/256)}]).png().toBuffer();
   contact.push({input:panel,left:i*240,top:bi*200});if(bi===1)pages.push(panel);
  }
 }
 await sharp({create:{width:1440,height:400,channels:4,background:'#20262d'}}).composite(contact).png().toFile(path.join(out,'contact.png'));
 const seq=[0,0,1,2,3,4,5,0],delays=[400,100,80,80,120,120,700,300];
 for(const [label,rate] of [['normal',1],['slow',.25]]){
  const raw=[];for(const i of seq)raw.push(await sharp(pages[i]).resize(480,400).removeAlpha().raw().toBuffer());
  await sharp(Buffer.concat(raw),{raw:{width:480,height:400*seq.length,channels:3,pageHeight:400}}).gif({delay:delays.map((d,i)=>i>=1&&i<=5?d/rate:d),loop:0,effort:7}).toFile(path.join(out,`animatic_${label}.gif`));
 }
 const result={frame_count:frames.length,alpha_zero_pixels:removed,partial_pixels:partial,max_registration_rounding_error:Math.max(...frames.flatMap(f=>f.registration_error.map(Math.abs))),times_ms:times,core_pixels:frames.map(f=>f.core_pixels),output:path.relative(root,out)};
 fs.writeFileSync(path.join(out,'build_report.json'),JSON.stringify(result,null,2)+'\n');console.log(JSON.stringify(result,null,2));
}
main().catch(e=>{console.error(e);process.exitCode=1;});
