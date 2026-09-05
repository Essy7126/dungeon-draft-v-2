const sharp = require(process.env.SHARP_PATH || 'C:/Users/paolo/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
async function components(file, threshold = 0) {
  const { data, info } = await sharp(file).ensureAlpha().raw().toBuffer({ resolveWithObject: true });
  const { width: w, height: h } = info;
  const visited = new Uint8Array(w*h), stack = new Int32Array(w*h), groups = [];
  for (let index=0; index<w*h; index++) {
    if (visited[index] || data[index*4+3]<=threshold) continue;
    let n=0, size=0, minX=w, maxX=0, minY=h, maxY=0, sx=0, sy=0;
    stack[n++]=index; visited[index]=1;
    while(n) {
      const p=stack[--n], x=p%w, y=Math.floor(p/w);
      size++; sx+=x; sy+=y; minX=Math.min(minX,x); maxX=Math.max(maxX,x); minY=Math.min(minY,y); maxY=Math.max(maxY,y);
      for (let dy=-1;dy<=1;dy++) for(let dx=-1;dx<=1;dx++) {
        if(!dx&&!dy) continue;
        const nx=x+dx,ny=y+dy,q=ny*w+nx;
        if(nx<0||ny<0||nx>=w||ny>=h||visited[q]||data[q*4+3]<=threshold) continue;
        visited[q]=1; stack[n++]=q;
      }
    }
    groups.push({size,bbox:[minX,minY,maxX+1,maxY+1],center:[+(sx/size).toFixed(1),+(sy/size).toFixed(1)]});
  }
  console.log(JSON.stringify({info,threshold,total:groups.length,groups:groups.filter(g=>g.size>=16).sort((a,b)=>b.size-a.size)},null,2));
}
components(process.argv[2], +(process.argv[3]||0));
