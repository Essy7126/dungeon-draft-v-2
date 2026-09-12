// Concept preparation only: chroma extraction, lossless layer partition and review layout.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const deps='C:/Users/paolo/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/';
let sharp,JSZip;try{sharp=require('sharp')}catch{sharp=require(process.env.SHARP_PATH||deps+'sharp')}try{JSZip=require('jszip')}catch{JSZip=require(process.env.JSZIP_PATH||deps+'jszip')}
const root=path.resolve(__dirname,'../..'),src=path.join(root,'art/source/vfx/peleid_fresco_v1'),out=path.join(root,'artifacts/dev/peleid_fx_direction_v1');
const hash=b=>crypto.createHash('sha256').update(b).digest('hex'),clip=x=>Math.max(0,Math.min(255,x));
const names=['empreinte_contact','eclat_haut','eclat_milieu','eclat_bas'];
function box(data,w,h){let b=[w,h,0,0],n=0;for(let y=0;y<h;y++)for(let x=0;x<w;x++){if(data[(y*w+x)*4+3]>0){b=[Math.min(b[0],x),Math.min(b[1],y),Math.max(b[2],x+1),Math.max(b[3],y+1)];n++}}return {bounds:b,pixels:n}}
const svg=(w,h,body)=>Buffer.from(`<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}">${body}</svg>`);
async function main(){fs.mkdirSync(out,{recursive:true});fs.mkdirSync(path.join(src,'layers'),{recursive:true});
 const bytes=fs.readFileSync(path.join(src,'peak_v2.png')),im=await sharp(bytes).removeAlpha().raw().toBuffer({resolveWithObject:true}),w=im.info.width,h=im.info.height;
 assert.equal(w,1536);assert.equal(h,1024);
 const rgba=Buffer.alloc(w*h*4),layers=names.map(()=>Buffer.alloc(w*h*4));let zero=0,partial=0;
 // Same dominance/unmix/despill equations as painted-G chroma_key and guard animatic.
 for(let p=0;p<w*h;p++){const c=[...im.data.subarray(p*3,p*3+3)],d=Math.min(c[0],c[2])-c[1],a=Math.min(c[0],c[2])>60&&d>30?Math.max(0,Math.min(1,(110-d)/70)):1;
  if(a===0){zero++;continue}let v=c;if(a<1){partial++;v=c.map((x,j)=>clip((x-(1-a)*[255,0,255][j])/Math.max(a,1/255)));const r=Math.max(Math.min(v[0],v[2])-v[1]-18,0);v[0]-=r;v[2]-=r;}
  for(let j=0;j<3;j++)rgba[p*4+j]=Math.round(clip(v[j]));rgba[p*4+3]=Math.round(a*255);
 }
 // Partition whole connected painted shapes. Rectangles clip the lower main point,
 // whose bounding box overlaps the detached lower chip despite transparent space.
 const seen=new Uint8Array(w*h),components=[];
 for(let p=0;p<w*h;p++){
  if(seen[p]||!rgba[p*4+3])continue;
  const pixels=[p];seen[p]=1;
  for(let i=0;i<pixels.length;i++){
   const k=pixels[i],x=k%w,y=Math.floor(k/w);
   for(let dy=-1;dy<=1;dy++)for(let dx=-1;dx<=1;dx++){
    const nx=x+dx,ny=y+dy,n=ny*w+nx;
    if(nx>=0&&nx<w&&ny>=0&&ny<h&&!seen[n]&&rgba[n*4+3]){seen[n]=1;pixels.push(n)}
   }
  }
  components.push(pixels);
 }
 const shapes=components.filter(c=>c.length>10).sort((a,b)=>b.length-a.length);
 assert.equal(shapes.length,4,'Expected one contact and three detached painted chips; review a changed source');
 const chips=shapes.slice(1).sort((a,b)=>Math.floor(a[0]/w)-Math.floor(b[0]/w));
 for(const component of components){const index=chips.indexOf(component)+1;for(const p of component)rgba.copy(layers[index],p*4,p*4,p*4+4)}
 const merged=await sharp(rgba,{raw:{width:w,height:h,channels:4}}).png().toBuffer();fs.writeFileSync(path.join(src,'peak_rgba.png'),merged);
 const sum=Buffer.alloc(rgba.length);for(const l of layers)for(let i=0;i<l.length;i++)sum[i]+=l[i];assert.ok(sum.equals(rgba),'Layers must reconstruct every RGBA byte');
 const zip=new JSZip();zip.file('mimetype','image/openraster',{compression:'STORE'});const records=[];
 for(let i=0;i<layers.length;i++){const measurement=box(layers[i],w,h);assert.ok(measurement.pixels>10);const png=await sharp(layers[i],{raw:{width:w,height:h,channels:4}}).png().toBuffer();fs.writeFileSync(path.join(src,'layers',names[i]+'.png'),png);zip.file('data/'+names[i]+'.png',png);records.push({id:names[i],...measurement,sha256:hash(png)});}
 const stack=`<?xml version="1.0" encoding="UTF-8"?><image version="0.0.6" w="${w}" h="${h}" name="Frappe du Peleide - recherche V2"><stack>${[...names].reverse().map(n=>`<layer name="${n}" src="data/${n}.png" opacity="1.0" visibility="visible" composite-op="svg:src-over" x="0" y="0"/>`).join('')}</stack></image>`;
 zip.file('stack.xml',stack);zip.file('mergedimage.png',merged);zip.file('Thumbnails/thumbnail.png',await sharp(merged).resize({width:256,height:256,fit:'inside'}).png().toBuffer());
 const ora=await zip.generateAsync({type:'nodebuffer',compression:'DEFLATE',compressionOptions:{level:6}});fs.writeFileSync(path.join(src,'peleid_contact_master.ora'),ora);
 assert.equal(ora.readUInt16LE(8),0,'First ZIP entry must be stored');assert.equal(ora.subarray(30,38).toString(),'mimetype');
 const check=await JSZip.loadAsync(ora);assert.equal(await check.file('mimetype').async('string'),'image/openraster');assert.ok((await check.file('mergedimage.png').async('nodebuffer')).equals(merged));
 const b=box(rgba,w,h).bounds,crop={left:b[0],top:b[1],width:b[2]-b[0],height:b[3]-b[1]},trim=await sharp(merged).extract(crop).png().toBuffer();fs.writeFileSync(path.join(out,'contact_trim.png'),trim);
 const actorPath='art/source/characters/catabase_monsters/rejeton_braise/base_frame_E.png',actor=await sharp(path.join(root,actorPath)).resize(179,134).png().toBuffer();
 const mapPath='asset/map/painted/halts/emerald_sanctuary_v1/sanctuary.png',floor=await sharp(path.join(root,mapPath)).resize(1100).extract({left:350,top:320,width:380,height:245}).png().toBuffer();
 const overlays=[],panelSpecs=[['Sur fond sombre','#202b30'],['Sur pierre claire','#d5ceba'],['Dans le decor',null]];
 for(let i=0;i<3;i++){const bg=panelSpecs[i][1]?await sharp({create:{width:380,height:245,channels:4,background:panelSpecs[i][1]}}).png().toBuffer():floor;
  const fx=await sharp(trim).resize({width:72,kernel:'linear'}).png().toBuffer(),k=72/crop.width;
  const left=Math.round(206-(1195-crop.left)*k),top=Math.round(150-(518-crop.top)*k);
  const panel=await sharp(bg).composite([{input:actor,left:220-90,top:194-112},{input:fx,left,top}]).png().toBuffer();
  fs.writeFileSync(path.join(out,`scale_${i}.png`),panel);overlays.push({input:panel,left:20+i*395,top:510});
 }
 const text=`<text x="28" y="42" fill="#b48a4e" font-family="sans-serif" font-size="14" letter-spacing="2">CATABASE · RECHERCHE D'EFFET</text><text x="28" y="88" fill="#e7dfc6" font-family="serif" font-size="36">Frappe du Péléide — Éclat de fresque</text><text x="28" y="118" fill="#aebbb9" font-family="sans-serif" font-size="16">Un impact physique peint, bref et directionnel. Proposition de pic, pas encore une animation.</text><text x="720" y="191" fill="#ddd7bd" font-family="sans-serif" font-size="18">Une matière déjà présente dans le jeu</text>${[['Ivoire · contact','#DDD7BD'],['Bronze patiné · matière','#B48A4E'],['Terre cuite · force','#B5503F'],['Pétrole · contour','#24565A']].map(([n,c],i)=>`<rect x="720" y="${216+i*43}" width="26" height="26" rx="5" fill="${c}"/><text x="760" y="${236+i*43}" fill="#d8ddd5" font-family="sans-serif" font-size="16">${n}</text>`).join('')}<text x="720" y="429" fill="#aebbb9" font-family="sans-serif" font-size="14">Source editable : empreinte + 3 eclats</text><text x="28" y="487" fill="#ddd7bd" font-family="sans-serif" font-size="18">Contrôle du pic à 72 px · même cible, trois fonds</text>${panelSpecs.map(([n],i)=>`<text x="${32+i*395}" y="780" fill="#aebbb9" font-family="sans-serif" font-size="15">${n}</text>`).join('')}<text x="28" y="822" fill="#899b9c" font-family="sans-serif" font-size="13">Montages statiques avec les ressources du jeu. Cadrage d'étude ; ni scène de combat ni nouvelle apparence de héros.</text>`;
 const main=await sharp(trim).resize({width:530,kernel:'linear'}).png().toBuffer();
 await sharp({create:{width:1200,height:850,channels:4,background:'#162229'}}).composite([{input:main,left:60,top:155},...overlays,{input:svg(1200,850,text),left:0,top:0}]).png().toFile(path.join(out,'proposal.png'));
 const report={source_sha256:hash(bytes),native_alpha:false,keying:{transparent:zero,partial,method:'painted-G chroma dominance + unmix + edge despill; no component deletion'},source_dimensions:[w,h],crop,source_contact_point:[1195,518],preview_effect_width:72,layers:records,layer_reconstruction:'RGBA byte-exact after chroma extraction',ora:{mimetype_first:true,mimetype_stored:true,archive_reopened:true,mergedimage_exact:true,editor_open:'NOT_TESTED'},references:[mapPath,actorPath],status:'CONCEPT_REVIEW_ONLY'};
 fs.writeFileSync(path.join(src,'preparation_manifest.json'),JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify({layers:records.length,source_pixels:box(rgba,w,h).pixels,layer_reconstruction:report.layer_reconstruction,output:path.relative(root,out)},null,2));
}main().catch(e=>{console.error(e);process.exitCode=1});
