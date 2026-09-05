/** Mechanical comparisons: original idle, original anticipation, new anticipation, new impact. */
const fs=require('node:fs'),path=require('node:path');
const sharp=require(process.env.SHARP_PATH||'C:/Users/paolo/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const root=path.resolve(__dirname,'../..'),out=path.join(root,'assets/characters/Achilles/sprites_cour_des_sources_v1');
(async()=>{
const direction=process.argv[2]||'E',manifest=JSON.parse(fs.readFileSync(path.join(out,'manifest.json'))),sheet=manifest.sheets.find(s=>s.direction===direction);
const [width,height]=manifest.canvas,[anchorX,anchorY]=manifest.foot_anchor;
const atlas=path.join(out,`atlas_${direction}.png`),source=path.join(root,sheet.source);
const extract=async index=>sharp(atlas).extract({left:index%4*width,top:Math.floor(index/4)*height,width,height}).png().toBuffer();
const original=async()=>{
const bounds={E:[63,942,196,282],W:[53,937,260,284]}[direction];if(!bounds)throw Error('Comparison supports E/W');
const [left,top,w,h]=bounds,scale=sheet.fixed_scale;
const sprite=await sharp(source).extract({left,top,width:w,height:h}).resize(Math.round(w*scale),Math.round(h*scale)).png().toBuffer();
return sharp({create:{width,height,channels:4,background:'#00000000'}}).composite([{input:sprite,left:Math.round(anchorX+(left-sheet.source_root_local_x)*scale),top:Math.round(anchorY+(top-sheet.shared_row_ground_y[3])*scale)}]).png().toBuffer();};
const frames=[await extract(0),await original(),await extract(12),await extract(14)],labels=['Idle original','Anticipation originale','Nouvelle anticipation','Nouvel impact'];
const panelWidth=320,montageWidth=panelWidth*4,items=[];
for(let i=0;i<frames.length;i++){
items.push({input:await sharp(frames[i]).resize({height:240}).png().toBuffer(),left:i*panelWidth,top:25});
items.push({input:await sharp(frames[i]).resize({height:206}).png().toBuffer(),left:i*panelWidth+22,top:280});
}
const svg=Buffer.from(`<svg width="${montageWidth}" height="520"><g font-family="Arial" font-size="17" fill="#352f21">${labels.map((v,i)=>`<text x="${i*panelWidth+10}" y="23">${v} ${direction}</text>`).join('')}<text x="10" y="515">Sources sans retouche de dessin. Rangée basse : échelle du jeu ; corps au repos ~118 px.</text></g></svg>`);
items.push({input:svg,left:0,top:0});
await sharp({create:{width:montageWidth,height:520,channels:3,background:'#ddd6ba'}}).composite(items).jpeg({quality:92}).toFile(path.join(out,`preview_model_comparison_${direction}.jpg`));
})().catch(e=>{console.error(e);process.exitCode=1;});
