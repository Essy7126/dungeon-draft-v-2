/* Mechanical pose reference only. This script does not paint or alter character art. */
const fs = require('node:fs');
const path = require('node:path');
const sharp = require('C:/Users/paolo/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const root = path.resolve(__dirname, '../..');
const out = path.join(root, 'art/source/characters/achilles/passe_rive_motion_v1');
const add=(a,b)=>a.map((v,i)=>v+b[i]), sub=(a,b)=>a.map((v,i)=>v-b[i]);
const mul=(a,s)=>a.map(v=>v*s), dot=(a,b)=>a.reduce((s,v,i)=>s+v*b[i],0);
const len=a=>Math.sqrt(dot(a,a)), unit=a=>mul(a,1/len(a));
const TAU=Math.PI*2, duration=1.12, stride=.8, stance=.625;
function ik(a,b,l1,l2,bend){
  const d=len(sub(b,a));
  if(d>=l1+l2 || d<=Math.abs(l1-l2)) throw Error(`Unreachable limb: ${d}`);
  const axis=unit(sub(b,a)), normal=unit(sub(bend,mul(axis,dot(bend,axis))));
  const along=(l1*l1-l2*l2+d*d)/(2*d), height=Math.sqrt(l1*l1-along*along);
  return add(a,add(mul(axis,along),mul(normal,height)));
}
function foot(u,x){
  u=((u%1)+1)%1;
  let y,z,pitch=0;
  if(u<=stance){
    y=.25-stride*u;z=0;
    // Toe-off rotates the foot about the grounded toe, never through the floor.
    pitch=u>.52 ? -.23*((u-.52)/(stance-.52)) : 0;
  } else {
    const s=(u-stance)/(1-stance), h00=2*s**3-3*s*s+1, h10=s**3-2*s*s+s;
    const h01=-2*s**3+3*s*s, h11=s**3-s*s;
    y=h00*(-.25)+h10*(-stride*(1-stance))+h01*.25+h11*(-stride*(1-stance));
    z=.105*Math.sin(Math.PI*s)**1.35;
    pitch=-.23*(1-s)+.08*Math.sin(Math.PI*s);
  }
  const toe=[x,y+.15,z], heel=[x,y-.08,z+.23*Math.sin(-pitch)];
  const ankle=[x,y,z+.085+.15*Math.sin(-pitch)];
  return {ankle,toe,heel,stance:u<=stance,phase:u,plant:[x,y,0],pitch};
}
function pose(t){
  const a=TAU*t, shift=.018*Math.sin(a), pelvisZ=1.01-.015*Math.sin(2*a);
  const p={root:[0,0,0],pelvis:[shift,0,pelvisZ],chest:[shift*.45,.025,pelvisZ+.355],neck:[shift*.2,.026,pelvisZ+.665],head:[shift*.15,.03,pelvisZ+.80],crown:[shift*.15,.03,pelvisZ+.94]};
  const feet={};
  for(const side of ['L','R']){
    const s=side==='R'?1:-1, f=foot(t+(side==='R'?.5:0),s*.115);feet[side]=f;
    p['hip.'+side]=[shift+s*.105,s*.012*Math.sin(a),pelvisZ];
    p['ankle.'+side]=f.ankle;p['toe.'+side]=f.toe;p['heel.'+side]=f.heel;
    p['knee.'+side]=ik(p['hip.'+side],f.ankle,.49,.47,[0,1,0]);
    p['shoulder.'+side]=[shift*.45+s*.215,.025-s*.018*Math.sin(a),pelvisZ+.60];
    p['wrist.'+side]=side==='R'?[.335+shift*.3,.15-.022*Math.sin(a),pelvisZ+.31]:[-.285+shift*.3,.18+.015*Math.sin(a),pelvisZ+.10];
    p['elbow.'+side]=ik(p['shoulder.'+side],p['wrist.'+side],.31,.29,[s,-.35,-.3]);
  }
  const hand=p['wrist.R'];
  p.spearBase=add(hand,[0,-.035,-1.16]);p.spearTip=add(hand,[0,.025,.82]);
  return {phase:t,joints:p,feet};
}
// E camera: +X,+Y, elevation 30 degrees. +Y projects down-right, as in the existing study.
const project=p=>[256+(-p[0]+p[1])*.70710678*218,553-(p[2]*.8660254-(p[0]+p[1])*.35355339)*218];
const links=[['pelvis','chest'],['chest','neck'],['neck','head']];
for(const s of ['L','R']) for(const pair of [['pelvis','hip'],['hip','knee'],['knee','ankle'],['chest','shoulder'],['shoulder','elbow'],['elbow','wrist']]) links.push(pair.map(n=>['pelvis','chest'].includes(n)?n:n+'.'+s));
const names=['CONTACT G','APPUI G','PASSAGE D','AVANCE D','CONTACT D','APPUI D','PASSAGE G','AVANCE G'];
const poses=Array.from({length:8},(_,i)=>({...pose(i/8),label:names[i]}));
function cell(q,i){
  const x=(i%4)*512,y=Math.floor(i/4)*640, p=q.joints;
  const line=(a,b,color,width=5)=>{const A=project(a),B=project(b);return `<line x1="${A[0]}" y1="${A[1]}" x2="${B[0]}" y2="${B[1]}" stroke="${color}" stroke-width="${width}" stroke-linecap="round"/>`};
  let s=`<g transform="translate(${x} ${y})"><rect x="5" y="5" width="502" height="630" rx="14" fill="#182526"/><text x="24" y="39" fill="#e5dac0" font-size="21">${i+1} · ${q.label}</text>`;
  for(let n=-2;n<=2;n++) {s+=line([n*.2,-.5,0],[n*.2,.5,0],'#304341',1);s+=line([-.45,n*.2,0],[.45,n*.2,0],'#304341',1);}
  for(const [a,b] of links) s+=line(p[a],p[b],b.endsWith('.L')?'#77d3b3':b.endsWith('.R')?'#e4af79':'#ded9c4',10);
  for(const side of ['L','R']){
    const f=q.feet[side],col=side==='L'?'#77d3b3':'#e4af79';s+=line(f.heel,f.toe,col,12);
    const [tx,ty]=project(f.plant);if(f.stance)s+=`<ellipse cx="${tx}" cy="${ty+6}" rx="19" ry="5" fill="none" stroke="${col}" stroke-width="2"/>`;
  }
  for(const [name,v] of Object.entries(p))if(!name.startsWith('spear')){const [a,b]=project(v);s+=`<circle cx="${a}" cy="${b}" r="5" fill="#172122" stroke="#e8dfc4" stroke-width="1.5"/>`;}
  let h=project(p.head);s+=`<ellipse cx="${h[0]}" cy="${h[1]-4}" rx="19" ry="28" fill="#d6d2bc"/>`;
  s+=line(p.spearBase,p.spearTip,'#bfa778',5);
  const sh=project(add(p['wrist.L'],[-.04,.10,.14]));s+=`<ellipse cx="${sh[0]}" cy="${sh[1]}" rx="30" ry="62" transform="rotate(-18 ${sh[0]} ${sh[1]})" fill="#385550" stroke="#bfa778" stroke-width="4" opacity=".85"/>`;
  s+=`<text x="24" y="609" fill="#92a7a1" font-size="15">G jade · D cuivre · cercles = appuis</text></g>`;return s;
}
async function main(){
  fs.mkdirSync(out,{recursive:true});fs.writeFileSync(path.join(out,'.gdignore'),'');
  const errors=[],stanceDrift=[];
  for(let i=0;i<=112;i++){
    const q=pose(i/112);
    for(const side of ['L','R']){
      const p=q.joints;
      for(const [a,b,l] of [['hip','knee',.49],['knee','ankle',.47],['shoulder','elbow',.31],['elbow','wrist',.29]])errors.push(Math.abs(len(sub(p[a+'.'+side],p[b+'.'+side]))-l));
      if(Math.min(q.feet[side].heel[2],q.feet[side].toe[2])< -1e-8)throw Error('Foot penetrates floor');
      const dt=1e-5, next=pose(i/112+dt).feet[side], current=q.feet[side];
      if(current.stance && next.stance && next.phase>current.phase){
        const relativeSpeed=(next.toe[1]-current.toe[1])/(dt*duration);
        stanceDrift.push(Math.abs(relativeSpeed+stride/duration));
      }
    }
    if(!q.feet.L.stance&&!q.feet.R.stance)throw Error('Walk contains a flight phase');
  }
  const cycleError=Math.max(...Object.keys(pose(0).joints).map(k=>len(sub(pose(0).joints[k],pose(1).joints[k]))));
  const report={direction:'E',cycle_seconds:duration,stride_m:stride,speed_m_s:stride/duration,stance_fraction:stance,frame_count:8,camera:{azimuth_degrees:45,elevation_degrees:30},canvas_cell:[512,640],projected_root:project([0,0,0]),links,poses,checks:{samples:113,max_segment_length_error_m:Math.max(...errors),loop_joint_error_m:cycleError,no_flight:true,no_floor_penetration:true,stance_world_speed_error_m_s:Math.max(...stanceDrift)},limitations:['Designed mechanical reference, not motion capture or artist approval','Planted foot point advances backward at constant speed in-place; world root must move at stride/cycle speed','Image generation must be measured independently; guide correctness does not validate artwork']};
  fs.writeFileSync(path.join(out,'walk_guide.json'),JSON.stringify(report,null,2));
  const svg=`<svg xmlns="http://www.w3.org/2000/svg" width="2048" height="1280" viewBox="0 0 2048 1280" font-family="Arial"><rect width="2048" height="1280" fill="#10191b"/>${poses.map(cell).join('')}</svg>`;
  fs.writeFileSync(path.join(out,'walk_guide.svg'),svg);await sharp(Buffer.from(svg)).png().toFile(path.join(out,'walk_guide.png'));
  console.log(JSON.stringify({output:out,checks:report.checks}));
}
main().catch(e=>{console.error(e);process.exitCode=1});
