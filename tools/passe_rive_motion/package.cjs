/* Preserve native files; assemble a review and a separate, non-production Godot sample. */
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const sharp=require('C:/Users/paolo/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const root=path.resolve(__dirname,'../..'),source=path.join(root,'art/source/characters/achilles/passe_rive_motion_v1'),out=path.join(root,'artifacts/spine_trial/passe_rive_motion_v1');
const sha=file=>crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
async function main(){
 for(const dir of ['images','guides','godot/images'])fs.mkdirSync(path.join(out,dir),{recursive:true});
 const frames=[],atlas=Buffer.alloc(4096*3072*4);
 for(let i=0;i<8;i++){
  const name='walk_'+String(i).padStart(2,'0'),file=path.join(source,name+'_rgba_v2.png'),meta=await sharp(file).metadata();
  if(!meta.hasAlpha||meta.width!==1024||meta.height!==1536)throw Error(`Unexpected frame format: ${name}`);
  const pixels=await sharp(file).ensureAlpha().raw().toBuffer();let transparent=0,opaque=0,foreground=0;
  for(let p=3;p<pixels.length;p+=4){if(pixels[p]===0)transparent++;if(pixels[p]===255)opaque++;if(pixels[p]>=240)foreground++;}
  if(transparent/(1024*1536)<.5||foreground<150000)throw Error(`Unexpected transparency: ${name}`);
  fs.copyFileSync(file,path.join(out,'images',name+'.png'));fs.copyFileSync(file,path.join(out,'godot/images',name+'.png'));
  fs.copyFileSync(path.join(source,'guide_'+String(i).padStart(2,'0')+'.png'),path.join(out,'guides','guide_'+String(i).padStart(2,'0')+'.png'));
  for(let y=0;y<1536;y++)pixels.copy(atlas,((Math.floor(i/4)*1536+y)*4096+(i%4)*1024)*4,y*1024*4,(y+1)*1024*4);
  frames.push({index:i,file:'images/'+name+'.png',source:path.relative(root,file).replaceAll('\\','/'),sha256:sha(file),transparent_fraction:transparent/(1024*1536),opaque_pixels:opaque,alpha_at_least_240_pixels:foreground});
 }
 const reference=path.join(root,'art/source/characters/achilles/passe_rive_v1/reference_choisie.png');
 for(const dest of ['images/idle.png','godot/images/idle.png'])fs.copyFileSync(reference,path.join(out,dest));
 await sharp(atlas,{raw:{width:4096,height:3072,channels:4}}).png().toFile(path.join(out,'walk_atlas_native.png'));
 // Verify the atlas does not introduce clipping or another resampling pass.
 for(let i=0;i<8;i++){
  const a=await sharp(path.join(out,'walk_atlas_native.png')).extract({left:(i%4)*1024,top:Math.floor(i/4)*1536,width:1024,height:1536}).raw().toBuffer();
  const b=await sharp(path.join(out,frames[i].file)).raw().toBuffer();if(!a.equals(b))throw Error('Atlas pixel mismatch '+i);
 }
 fs.copyFileSync(path.join(root,'asset/map/painted/halts/emerald_sanctuary_v1/sanctuary.png'),path.join(out,'map.png'));
 fs.copyFileSync(path.join(source,'walk_guide.json'),path.join(out,'walk_guide.json'));
 fs.copyFileSync(path.join(__dirname,'review.html'),path.join(out,'review.html'));
 for(const f of ['idle.gdshader','Preview.gd'])fs.copyFileSync(path.join(__dirname,f),path.join(out,'godot',f));
 const guide=JSON.parse(fs.readFileSync(path.join(source,'walk_guide.json')));
 const manifest={schema:1,status:'art_review_required',direction:'E',walk_seconds:1.12,walk_fps:8/1.12,idle_seconds:3.2,idle_method:'original texture with local shader deformation; face, feet and spear pinned',walk_anchor:[550,1390],idle_anchor:[515,1390],native_frame_size:[1024,1536],guide_speed_m_s:guide.speed_m_s,projected_forward_pixels_per_meter:1340/(1.95*Math.cos(Math.PI/6))*Math.SQRT1_2,reference_sha256:sha(reference),frames,checks:{atlas_native_pixels_exact:true,guide:guide.checks},limitations:['Artwork has not passed planted-foot tracking during translation','Some heel marks differ between poses; compare at native size','Eight generated drawings do not prove a physically consistent walk','Map preview scale and grounding are illustrative; no main game integration','Idle shader does not include an idle-to-walk transition']};
 manifest.status='art_rebuild_required';
 manifest.audit={report:'docs/design/achilles/passe_rive_walk_audit_2026-09-10.md',review:'../passe_rive_walk_audit/review.html',findings:['First planted-foot patch barely moves between drawings 1 and 2','Guide passing labels precede actual leg crossing','Guide lateral pelvis oscillation opposes the intended support side']};
 fs.writeFileSync(path.join(out,'manifest.json'),JSON.stringify(manifest,null,2));fs.writeFileSync(path.join(source,'delivery_manifest.json'),JSON.stringify(manifest,null,2));
 let resource='[gd_resource type="SpriteFrames" load_steps=10 format=3]\n\n';
 for(let i=0;i<8;i++)resource+=`[ext_resource type="Texture2D" path="res://images/walk_${String(i).padStart(2,'0')}.png" id="${i+1}"]\n`;
 resource+='[ext_resource type="Texture2D" path="res://images/idle.png" id="9"]\n\n[resource]\nanimations = [{\n"frames": [{"duration": 1.0, "texture": ExtResource("9")}],\n"loop": true, "name": &"idle_E", "speed": 1.0\n}, {\n"frames": [\n';
 resource+=frames.map((_,i)=>`{"duration": 1.0, "texture": ExtResource("${i+1}")}`).join(',\n');
 resource+='\n], "loop": true, "name": &"walk_E", "speed": '+(8/1.12)+'\n}]\n';
 fs.writeFileSync(path.join(out,'godot/passe_rive_sprite_frames.tres'),resource);
 fs.writeFileSync(path.join(out,'godot/Preview.tscn'),'[gd_scene load_steps=2 format=3]\n\n[ext_resource type="Script" path="res://Preview.gd" id="1"]\n\n[node name="PasseRivePreview" type="Node2D"]\nscript = ExtResource("1")\n');
 fs.writeFileSync(path.join(out,'godot/project.godot'),'config_version=5\n\n[application]\nconfig/name="Passe-rive — revue de mouvement"\nrun/main_scene="res://Preview.tscn"\n\n[display]\nwindow/size/viewport_width=1280\nwindow/size/viewport_height=720\n\n[rendering]\nrenderer/rendering_method="gl_compatibility"\ntextures/default_filters/use_nearest_mipmap_filter=false\n');
 console.log(JSON.stringify({review:out,frames:8,native_alpha:true,atlas_pixels_exact:true}));
}
main().catch(e=>{console.error(e);process.exitCode=1});
