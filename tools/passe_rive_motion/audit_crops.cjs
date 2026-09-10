// Analysis crops only. Never modifies the character source images.
const fs=require('node:fs'),path=require('node:path');
const sharp=require('C:/Users/paolo/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const root=path.resolve(__dirname,'../..'),out=path.join(root,'artifacts/spine_trial/passe_rive_walk_audit');
async function main(){
 fs.mkdirSync(out,{recursive:true});
 for(let start=0;start<8;start+=4){
  const layers=[];
  for(let j=0;j<4;j++){
   const i=start+j,source=path.join(root,'art/source/characters/achilles/passe_rive_motion_v1/walk_'+String(i).padStart(2,'0')+'_rgba_v2.png');
   const crop=await sharp(source).extract({left:250,top:1050,width:650,height:450}).flatten({background:'#263536'}).png().toBuffer();
   const grid=Array.from({length:13},(_,k)=>`<path d="M${k*50} 0V450" stroke="#b3cbc830"/><text x="${k*50+2}" y="28">${250+k*50}</text>`).join('')+Array.from({length:9},(_,k)=>`<path d="M0 ${k*50}H650" stroke="#b3cbc830"/><text x="3" y="${k*50+45}">${1050+k*50}</text>`).join('');
   const overlay=Buffer.from(`<svg width="650" height="450" xmlns="http://www.w3.org/2000/svg"><g fill="#fff" font-family="Arial" font-size="12">${grid}<rect x="235" width="175" height="22" fill="#101a1e"/><text x="242" y="16">Dessin ${i+1} · source native</text></g></svg>`);
   layers.push({input:await sharp(crop).composite([{input:overlay}]).png().toBuffer(),left:(j%2)*650,top:Math.floor(j/2)*450});
  }
  await sharp({create:{width:1300,height:900,channels:3,background:'#263536'}}).composite(layers).png().toFile(path.join(out,'feet_'+start+'_'+(start+3)+'.png'));
 }
 console.log(out);
}
main().catch(e=>{console.error(e);process.exitCode=1});
