/* Assemble existing Blender renders as a single guide; no new poses are invented. */
const fs=require('node:fs'),path=require('node:path');
const sharp=require('C:/Users/paolo/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const root=path.resolve(__dirname,'../..');
const out=path.join(root,'art/source/characters/achilles/passe_rive_walk_v3');
async function main(){
 fs.mkdirSync(out,{recursive:true});
 const dst=path.join(out,'blender_12_pose_guide.png');
 if(fs.existsSync(dst))throw Error('Preserve existing guide');
 const indices=Array.from({length:12},(_,i)=>i*3);
 await sharp({create:{width:2560,height:2880,channels:4,background:'#dce1df'}}).composite(indices.map((frame,i)=>({input:path.join(root,'artifacts/spine_trial/passe_rive_walk_v2/frames/walk_'+String(frame).padStart(2,'0')+'.png'),left:i%4*640,top:Math.floor(i/4)*960}))).png().toFile(dst);
 fs.writeFileSync(path.join(out,'guide_manifest.json'),JSON.stringify({source:'art/source/blender/passe_rive_walk_v2/passe_rive_walk_v2_contacts.blend',frame_indices:indices,columns:4,rows:3,cell_size:[640,960],cycle_seconds:1.2,reference:'art/source/characters/achilles/passe_rive_v1/reference_choisie.png',status:'pose_guide_only'},null,2));
 console.log(JSON.stringify({guide:dst,poses:indices.length}));
}
main().catch(e=>{console.error(e.message);process.exitCode=1});
