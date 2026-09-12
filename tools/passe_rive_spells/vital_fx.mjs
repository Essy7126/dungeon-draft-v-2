import {spellLift} from './engine.mjs';
const TAU=Math.PI*2;
function halo(c,x,y,r,color,alpha=1){c.save();c.globalAlpha=alpha;const g=c.createRadialGradient(x,y,0,x,y,r);g.addColorStop(0,color);g.addColorStop(.28,color);g.addColorStop(1,color.slice(0,7)+'00');c.fillStyle=g;c.beginPath();c.arc(x,y,r,0,TAU);c.fill();c.restore()}
export function vitalBody(c,spell,phase,time,x,y,scale=.55){
 if(!spell?.vfx)return;
 const v=spell.vfx,intensity=v.palm_strength[phase],lift=spellLift(spell,time);
 const point=p=>[x+(p[0]-320)*scale,y+(p[1]-662-lift)*scale];
 c.save();c.globalCompositeOperation='lighter';
 for(const p of v.palms[phase]){const [px,py]=point(p);halo(c,px,py,(16+Math.sin(time*11)*1.4)*scale,'#64dc89',intensity*.48);halo(c,px,py,4*scale,'#c4ffc0',intensity*.7)}
 if(time>.18&&time<.9){const [cx,cy]=point(v.chest[phase]);const build=time<.62?Math.min(1,(time-.18)/.44):Math.max(0,1-(time-.62)/.28);halo(c,cx,cy,(15+build*18)*scale,'#d43e53',build*.55);halo(c,cx,cy,6*scale,'#ffd0b4',build*.7)}
 c.restore();
}
function bezier(b,t){const v=1-t;return {x:v*v*b.start.x+2*v*t*b.control.x+t*t*b.end.x,y:v*v*b.start.y+2*v*t*b.control.y+t*t*b.end.y}}
export function vitalTrail(c,b){
 const t=Math.min(1,b.age/b.duration),tail=Math.max(0,t-.58);c.save();c.lineCap='round';c.lineJoin='round';
 // Three tapering ribbons follow the chest-to-opponent trajectory, never the reverse.
 for(let ribbon=0;ribbon<3;ribbon++){
  const points=[];for(let i=0;i<=20;i++){const u=tail+(t-tail)*i/20,p=bezier(b,u);p.y+=Math.sin(u*18-b.age*9+ribbon*2.1)*(1-i/20)*(3+ribbon*3);points.push(p)}
  for(let i=1;i<points.length;i++){const f=i/20;c.strokeStyle=ribbon===0?`rgba(199,36,65,${.15+f*.5})`:`rgba(240,${77+ribbon*20},${86+ribbon*20},${f*.65})`;c.lineWidth=(ribbon===0?16:4)*f+1;c.beginPath();c.moveTo(points[i-1].x,points[i-1].y);c.lineTo(points[i].x,points[i].y);c.stroke()}
 }
 const head=bezier(b,t);c.globalCompositeOperation='lighter';halo(c,head.x,head.y,17,'#d43952',.5);halo(c,head.x,head.y,6,'#ffc3a0',.95);c.restore();
}
export function vitalBurst(c,e){
 const u=e.age/e.life,fade=1-u,impact=e.kind==='vital_impact';c.save();c.globalCompositeOperation='lighter';halo(c,e.x,e.y,12+u*(impact?48:35),'#d13851',fade*.65);
 c.strokeStyle=`rgba(243,102,112,${fade*.8})`;c.lineWidth=2.5*fade+1;
 for(let i=0;i<7;i++){const angle=i*2.399+(impact?0:.3),r=6+u*38;c.beginPath();c.moveTo(e.x+Math.cos(angle)*r*.35,e.y+Math.sin(angle)*r*.35);c.quadraticCurveTo(e.x+Math.cos(angle+.24)*r,e.y+Math.sin(angle+.24)*r,e.x+Math.cos(angle+.4)*r*.9,e.y+Math.sin(angle+.4)*r*.9);c.stroke()}
 halo(c,e.x,e.y,9*fade+1,'#ffb9a2',fade);c.restore();
}
