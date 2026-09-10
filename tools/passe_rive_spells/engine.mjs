// Deterministic preview rules, deliberately independent of campaign balance.
export class SpellLab {
 constructor(manifest){this.data=manifest;this.reset()}
 reset(){this.time=0;this.player={x:325,y:422,walk:0,shield:0};this.targets=[{x:505,y:425},{x:685,y:430},{x:860,y:365}].map((p,i)=>({...p,id:i,hp:100,flash:0,respawn:0}));this.active=null;this.cooldowns={};this.buffer=null;this.projectiles=[];this.effects=[];this.events=[];this.freeze=0;this.hits=0;this.casts=0;this.message='Choisis un geste. Les cibles se régénèrent.';this.serial=0;this.move=null}
 get phase(){if(!this.active)return -1;let t=this.active.t;for(let i=0;i<4;i++){t-=this.active.spell.frames[i].duration_ms/1000;if(t < -1e-8)return i}return 3}
 cast(id){const spell=this.data.actions.find(a=>a.id===id);if(!spell)return false;if(this.active){const left=this.active.spell.total_ms/1000-this.active.t;if(left<=this.data.input_buffer_ms/1000){this.buffer={id,until:this.time+.2};this.message='Geste suivant mémorisé';return true}return false}if((this.cooldowns[id]||0)>0){this.message='Ce geste récupère encore';return false}this.active={spell,t:0,fired:false,serial:++this.serial,startX:this.player.x,startY:this.player.y};this.cooldowns[id]=spell.cooldown_ms/1000;this.casts++;this.move=null;this.message=spell.name;this.events.push({type:'cast',id,time:this.time,serial:this.serial});return true}
 hit(target,spell,serial){if(target.hp<=0)return;target.hp=Math.max(0,target.hp-spell.damage);target.flash=.18;this.hits++;this.events.push({type:'hit',id:spell.id,target:target.id,serial,time:this.time});this.effects.push({kind:'hit',x:target.x,y:target.y-74,age:0,life:.5,color:spell.color,text:String(spell.damage)});if(spell.mode==='bash')target.x=Math.min(1110,target.x+70);if(target.hp===0){target.respawn=1.7;this.effects.push({kind:'dissolve',x:target.x,y:target.y-50,age:0,life:.8,color:'#859589'})}}
 fire(a){a.fired=true;const s=a.spell,p=this.player;this.events.push({type:'release',id:s.id,serial:a.serial,time:this.time});this.effects.push({kind:s.mode,x:p.x,y:p.y,age:0,life:s.mode==='guard'?1.2:.52,color:s.color});
  if(s.mode==='guard'){p.shield=2.0;this.message='Protection dressée';this.freeze=s.hitstop_ms/1000;return}
  if(s.mode==='dash')return;
  if(s.mode==='shot'){this.projectiles.push({x:p.x+130,y:p.y-125,originX:p.x,spell:s,serial:a.serial,age:0});return}
  let hits=0;for(const target of this.targets){const dx=target.x-p.x,dy=target.y-p.y;const inRange=s.mode==='sweep'?Math.hypot(dx,dy*1.5)<=s.range:dx>30&&dx<s.range&&Math.abs(dy)<72;if(inRange&&target.hp>0){this.hit(target,s,a.serial);hits++;if(s.mode!=='sweep')break}}
  if(hits){this.freeze=s.hitstop_ms/1000;this.message=hits>1?`${hits} cibles touchées`:'Impact'}else this.message='Hors de portée';
 }
 step(dt,keys={}){dt=Math.min(Math.max(dt,0),.05);this.time+=dt;for(const id in this.cooldowns)this.cooldowns[id]=Math.max(0,this.cooldowns[id]-dt);this.player.shield=Math.max(0,this.player.shield-dt);for(const t of this.targets){t.flash=Math.max(0,t.flash-dt);if(t.hp===0){t.respawn-=dt;if(t.respawn<=0)t.hp=100}}
  for(const e of this.effects)e.age+=dt;this.effects=this.effects.filter(e=>e.age<e.life);
  const frozen=this.freeze>0;this.freeze=Math.max(0,this.freeze-dt);
  if(this.active&&!frozen){const a=this.active;a.t+=dt;if(!a.fired&&a.t+1e-8>=a.spell.event_ms/1000)this.fire(a);
   if(a.spell.mode==='dash'){const u=Math.max(0,Math.min(1,(a.t-.1)/.2));const desired=a.startX+220*(1-Math.pow(1-u,3));const obstacle=this.targets.filter(t=>t.hp>0&&t.x>a.startX&&Math.abs(t.y-a.startY)<65).sort((a,b)=>a.x-b.x)[0];this.player.x=Math.min(1100,desired,obstacle?obstacle.x-85:1100);}
   if(a.t>=a.spell.total_ms/1000){this.active=null;const queued=this.buffer;this.buffer=null;if(queued&&queued.until>=this.time)this.cast(queued.id)}
  }
  if(!this.active&&!frozen){let dx=(keys.right?1:0)-(keys.left?1:0),dy=(keys.down?1:0)-(keys.up?1:0);if(this.move&&!dx&&!dy){const tx=this.move.x-this.player.x,ty=this.move.y-this.player.y,l=Math.hypot(tx,ty);if(l<5)this.move=null;else{dx=tx/l;dy=ty/l}}
   if(dx||dy){const n=Math.hypot(dx,dy);const px=this.player.x+dx/n*114*dt,py=this.player.y+dy/n*80*dt;if(!this.targets.some(t=>t.hp>0&&Math.hypot((t.x-px)/1.4,t.y-py)<37)){this.player.x=Math.max(180,Math.min(1080,px));this.player.y=Math.max(330,Math.min(555,py));this.player.walk+=dt}else this.move=null;this.walking=true}else this.walking=false;
  }else this.walking=false;
  for(const p of this.projectiles){if(frozen)continue;p.x+=1000*dt;p.age+=dt;const target=this.targets.filter(t=>t.hp>0&&t.x>=p.x-70&&t.x<=p.x+15&&Math.abs((t.y-95)-p.y)<80).sort((a,b)=>a.x-b.x)[0];if(target){this.hit(target,p.spell,p.serial);this.freeze=p.spell.hitstop_ms/1000;p.dead=true}if(p.x-p.originX>p.spell.range)p.dead=true}this.projectiles=this.projectiles.filter(p=>!p.dead);
 }
 snapshot(){return {active:this.active?.spell.id||null,phase:this.phase,hits:this.hits,casts:this.casts,player:{...this.player},targets:this.targets.map(t=>({...t})),events:this.events.map(e=>({...e})),buffer:this.buffer,cooldowns:{...this.cooldowns}}}
}
