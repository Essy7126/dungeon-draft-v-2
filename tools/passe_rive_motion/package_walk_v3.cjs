/* Package actual generated PNGs, preserving their native scale and source variants. */
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const sharp=require('C:/Users/paolo/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const root=path.resolve(__dirname,'../..'),source=path.join(root,'art/source/characters/achilles/passe_rive_walk_v3');
const out=path.join(root,'artifacts/spine_trial/passe_rive_walk_v3'),delivery=path.join(source,'delivery');
const hash=p=>crypto.createHash('sha256').update(fs.readFileSync(p)).digest('hex');
function resource(atlasPath){
 let s='[gd_resource type="SpriteFrames" load_steps=14 format=3]\n\n[ext_resource type="Texture2D" path="'+atlasPath+'" id="1"]\n\n';
 for(let i=0;i<12;i++)s+=`[sub_resource type="AtlasTexture" id="Atlas_${i}"]\natlas = ExtResource("1")\nregion = Rect2(${i%4*320}, ${Math.floor(i/4)*480}, 320, 480)\n\n`;
 s+='[resource]\nanimations = [{\n"frames": [\n'+Array.from({length:12},(_,i)=>`{"duration": 1.0, "texture": SubResource("Atlas_${i}")}`).join(',\n')+'\n],\n"loop": true,\n"name": &"walk_E",\n"speed": 10.0\n}]\n';return s;
}
async function main(){
 for(const p of [out,path.join(out,'frames'),path.join(out,'godot'),delivery,path.join(delivery,'frames')])fs.mkdirSync(p,{recursive:true});
 const tiles=[],frames=[],footTiles=[],atlasPixels=Buffer.alloc(1280*1440*4);
 for(let i=0;i<12;i++){
  // The generator shifted entire sheet rows. Integer translations restore the grid;
  // no per-pose scaling or deformation, no replacement of foot shapes.
  const shift=[0,6,22][Math.floor(i/4)],name=`walk_${String(i).padStart(2,'0')}.png`;
  const file=path.join(source,'rgba_frames',name),dst=path.join(delivery,'frames',name);
  const cut=await sharp(file).extract({left:0,top:0,width:320,height:480-shift}).png().toBuffer();
  await sharp({create:{width:320,height:480,channels:4,background:'#00000000'}}).composite([{input:cut,left:0,top:shift}]).png().toFile(dst);
  fs.copyFileSync(dst,path.join(out,'frames',name));
  const nativePixels=await sharp(dst).ensureAlpha().raw().toBuffer();
  for(let y=0;y<480;y++)nativePixels.copy(atlasPixels,((Math.floor(i/4)*480+y)*1280+i%4*320)*4,y*320*4,(y+1)*320*4);
  tiles.push({input:dst,left:i%4*320,top:Math.floor(i/4)*480});
  frames.push({index:i,file:'frames/'+name,duration_ms:100,source:'rgba_frames/'+name,alignment_y:shift,sha256:hash(dst)});
  const foot=await sharp(dst).extract({left:50,top:280,width:240,height:180}).flatten({background:'#d5dcd7'}).png().toBuffer();
  const label=Buffer.from(`<svg width="240" height="200"><rect width="240" height="20" fill="#253b36"/><text x="8" y="15" fill="#fff" font-size="13" font-family="Arial">Image ${i+1} / 12 — x:50…290, y:280…460</text></svg>`);
  const panel=await sharp({create:{width:240,height:200,channels:4,background:'#d5dcd7'}}).composite([{input:label,left:0,top:0},{input:foot,left:0,top:20}]).png().toBuffer();
  footTiles.push({input:panel,left:i%4*240,top:Math.floor(i/4)*200});
 }
 const atlas=path.join(delivery,'walk_atlas.png');
 await sharp(atlasPixels,{raw:{width:1280,height:1440,channels:4}}).png().toFile(atlas);
 for(const dest of [path.join(out,'walk_atlas.png'),path.join(out,'godot/walk_atlas.png')])fs.copyFileSync(atlas,dest);
 await sharp({create:{width:960,height:600,channels:4,background:'#d5dcd7'}}).composite(footTiles).png().toFile(path.join(out,'feet_contact_sheet.png'));
 for(let i=0;i<12;i++){
  const a=await sharp(atlas).extract({left:i%4*320,top:Math.floor(i/4)*480,width:320,height:480}).raw().toBuffer();
  const b=await sharp(path.join(delivery,frames[i].file)).raw().toBuffer();if(!a.equals(b))throw Error('Atlas mismatch '+i);
 }
 const manifest={schema:1,name:'Passe-rive',animation:'walk_E',direction:'three-quarter facing right, anatomical sides preserved',frame_count:12,frame_size:[320,480],atlas_size:[1280,1440],columns:4,rows:3,fps:10,cycle_seconds:1.2,pivot:[176,428],preview_stride_pixels:[122,61],frames,
   source_sheet_size:[1182,1330],generation:'built-in ImageGen, guide-first paint-over, candidate B',
   transparency:'software cutout authorized by user; rembg birefnet-general-lite',
   status:'painted_walk_for_art_review',checks:{atlas_pixels_exact:true,uniform_native_scale:true},
   limitations:['Generated poses approximate the Blender guide; native Blender submillimetre contact measurements do not apply to these drawings.','Spear tip, cloth shapes and mask vary slightly between drawings.','Native frame is 320x480, including padding; no AI upscaling or invented high-resolution claim.','Only this direction and walking clip are delivered; no idle transition or main-game character replacement.']};
 for(const folder of [delivery,out])fs.writeFileSync(path.join(folder,'manifest.json'),JSON.stringify(manifest,null,2));
 fs.copyFileSync(path.join(root,'asset/map/painted/halts/emerald_sanctuary_v1/sanctuary.png'),path.join(out,'map.png'));
 fs.copyFileSync(path.join(root,'art/source/characters/achilles/passe_rive_v1/reference_choisie.png'),path.join(out,'reference.png'));
 fs.copyFileSync(path.join(__dirname,'walk_v3_review.html'),path.join(out,'review.html'));
 fs.writeFileSync(path.join(delivery,'walk_E.tres'),resource('res://art/source/characters/achilles/passe_rive_walk_v3/delivery/walk_atlas.png'));
 fs.writeFileSync(path.join(out,'godot/walk_E.tres'),resource('res://walk_atlas.png'));
 fs.writeFileSync(path.join(out,'godot/project.godot'),'config_version=5\n\n[application]\nconfig/name="Passe-rive — marche peinte"\nrun/main_scene="res://Preview.tscn"\n\n[display]\nwindow/size/viewport_width=1000\nwindow/size/viewport_height=700\n\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n');
 fs.writeFileSync(path.join(out,'godot/Preview.tscn'),'[gd_scene load_steps=3 format=3]\n\n[ext_resource type="SpriteFrames" path="res://walk_E.tres" id="1"]\n[ext_resource type="Script" path="res://Preview.gd" id="2"]\n\n[node name="Preview" type="Node2D"]\nscript = ExtResource("2")\n\n[node name="PasseRive" type="AnimatedSprite2D" parent="."]\nposition = Vector2(500, 350)\nsprite_frames = ExtResource("1")\nanimation = &"walk_E"\nautoplay = "walk_E"\n');
 fs.writeFileSync(path.join(out,'godot/Preview.gd'),'extends Node2D\n\nvar elapsed: float = 0.0\n\nfunc _process(delta: float) -> void:\n\telapsed += delta\n\t$PasseRive.position = Vector2(280, 260) + Vector2(122, 61) * fmod(elapsed / 1.2, 3.0)\n\tqueue_redraw()\n\nfunc _draw() -> void:\n\tdraw_rect(Rect2(0, 0, 1000, 700), Color("1e302d"))\n\tfor i in range(-15, 25):\n\t\tvar x := float(i) * 50.0\n\t\tdraw_line(Vector2(x, 0), Vector2(x + 1400, 700), Color("344b43"))\n\t\tdraw_line(Vector2(x, 0), Vector2(x - 1400, 700), Color("344b43"))\n');
 console.log(JSON.stringify({review:out,delivery,frames:12,atlas_pixels_exact:true}));
}
main().catch(e=>{console.error(e.message);process.exitCode=1});
