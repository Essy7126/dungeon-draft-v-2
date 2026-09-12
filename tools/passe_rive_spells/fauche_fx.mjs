// Each ribbon ends at a painted blade tip. Drawing poses stay discrete;
// only the opacity/width of the trailing wake decays between drawings.
export function faucheRibbons(spell,time){
 const cfg=spell?.sweep_trail;if(!cfg)return [];
 const ms=time*1000,starts=[];let total=0;
 for(const frame of spell.frames){starts.push(total);total+=frame.duration_ms}
 const ribbons=[];
 for(let i=1;i<6;i++){
  const age=ms-starts[i];if(age<0||age>=cfg.tail_ms)continue;
  const a=cfg.tips[i-1],b=cfg.tips[i];
  const control=i===1?[(a[0]+b[0])*.5,Math.min(a[1],b[1])-155]:i===4?[a[0]+35,b[1]+70]:i===5?[(a[0]+b[0])*.5,Math.max(a[1],b[1])+85]:[(a[0]+b[0])*.5+18,(a[1]+b[1])*.5-15];
  const fade=(1-age/cfg.tail_ms)**1.4;
  ribbons.push({a,b,control,fade,front:i>=4,headFrame:i,width:i>=3?26:16});
 }
 return ribbons;
}
export function faucheTrail(ctx,spell,time,x,y,scale=.55,front=true){
 const ribbons=faucheRibbons(spell,time).filter(r=>r.front===front);if(!ribbons.length)return;
 const pivot=spell.pivot;
 ctx.save();ctx.translate(x-pivot[0]*scale,y-pivot[1]*scale);ctx.scale(scale,scale);ctx.globalCompositeOperation='screen';
 for(const r of ribbons){
  const points=[];for(let i=0;i<=28;i++){const u=i/28,v=1-u;points.push([r.a[0]*v*v+2*r.control[0]*u*v+r.b[0]*u*u,r.a[1]*v*v+2*r.control[1]*u*v+r.b[1]*u*u])}
  for(const [size,opacity,color] of [[1.6,.12,'#66cbae'],[1,.42,'#9fe4c7'],[.22,.8,'#eef7d3']]){
   const left=[],right=[];
   for(let i=0;i<points.length;i++){const prev=points[Math.max(0,i-1)],next=points[Math.min(points.length-1,i+1)],dx=next[0]-prev[0],dy=next[1]-prev[1],len=Math.hypot(dx,dy)||1,u=i/(points.length-1),w=Math.sin(Math.PI*u)*r.width*size*r.fade;left.push([points[i][0]-dy/len*w,points[i][1]+dx/len*w]);right.push([points[i][0]+dy/len*w,points[i][1]-dx/len*w])}
   ctx.globalAlpha=opacity*r.fade;ctx.fillStyle=color;ctx.beginPath();ctx.moveTo(...left[0]);for(const p of [...left.slice(1),...right.reverse()])ctx.lineTo(...p);ctx.closePath();ctx.fill();
  }
 }
 ctx.restore();
}
