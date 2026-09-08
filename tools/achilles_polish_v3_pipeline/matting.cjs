'use strict';
/** User-authorized background removal; optional declared magenta-edge RGB recovery. */
function backgroundCandidate(r, g, b, key) {
  if (key.mode === 'native') return false;
  if (key.mode === 'magenta') return r >= (key.min_red ?? 125) && b >= (key.min_blue ?? 100)
    && Math.min(r, b) - g >= (key.dominance ?? 45);
  const lo = Math.min(r, g, b), hi = Math.max(r, g, b);
  return lo >= (key.minimum ?? 100) && hi <= (key.maximum ?? 255)
    && hi - lo <= (key.chroma ?? 24) && b - r >= (key.blue_bias ?? -4);
}
function matteBackground(input, width, height, key) {
  if (!Buffer.isBuffer(input) || input.length !== width * height * 4) throw Error('Expected RGBA source');
  const output = Buffer.from(input), candidate = new Uint8Array(width * height);
  const visited = new Uint8Array(candidate.length), queue = new Int32Array(candidate.length);
  let changed = 0, exterior = 0, enclosed = 0;
  const components = [];
  for (let p=0;p<candidate.length;p++) candidate[p] = input[p*4+3] > 0
    && backgroundCandidate(input[p*4],input[p*4+1],input[p*4+2],key) ? 1 : 0;
  for(let start=0;start<candidate.length;start++) {
    if (!candidate[start] || visited[start]) continue;
    let head=0,tail=0,touches=false,low=0,high=0;
    queue[tail++]=start;visited[start]=1;
    while(head<tail) {
      const p=queue[head++],x=p%width,y=Math.floor(p/width),v=input[p*4];
      touches ||= x===0||y===0||x===width-1||y===height-1;
      if(v <= (key.hole_dark_max ?? 160))low++;
      if(v >= (key.hole_light_min ?? 185))high++;
      for(const [dx,dy]of [[-1,0],[1,0],[0,-1],[0,1]]) {
        const xx=x+dx,yy=y+dy,n=yy*width+xx;
        if(xx<0||yy<0||xx>=width||yy>=height||visited[n]||!candidate[n])continue;
        visited[n]=1;queue[tail++]=n;
      }
    }
    const twoTone = tail >= (key.minimum_hole_pixels ?? 16)
      && low >= Math.max(2,tail*0.04) && high >= Math.max(2,tail*0.04);
    const remove = key.mode==='magenta' || touches || twoTone;
    if(remove) {
      for(let i=0;i<tail;i++)output[queue[i]*4+3]=0;
      changed+=tail;
      if(touches)exterior+=tail;else enclosed+=tail;
    }
    if(tail>=16)components.push({pixels:tail,touches_border:touches,dark:low,light:high,removed:remove});
  }
  const edge = key.mode==='magenta' ? despillMagentaEdges(input,output,width,height,key.edge_despill) : {corrected:new Uint8Array(width*height),report:null};
  return {data:output,edgeCorrections:edge.corrected,report:{edge_despill:edge.report,mode:key.mode,removed_pixels:changed,exterior_pixels:exterior,
    enclosed_checker_or_key_pixels:enclosed,retained_pixels:candidate.length-changed,
    kept_pixel_policy:edge.report ? 'Alpha is unchanged for every retained pixel. RGB changes only in the declared magenta-contaminated edge mask; all other retained RGBA is byte-identical.' : 'RGB and alpha of all kept source pixels remain byte-identical.',
    component_summary:components.sort((a,b)=>b.pixels-a.pixels).slice(0,32)}};
}

/** Optional correction authorized only for keyed edge pixels contaminated by magenta.
 * The estimated foreground is recovered from C = coverage*F + (1-coverage)*B.
 * Alpha/support is intentionally unchanged: a thin cord and its footprint cannot erode.
 * Warm red, ivory, skin and petrol pixels fail the magenta-excess predicate.
 */
function despillMagentaEdges(input, output, width, height, options) {
  const corrected = new Uint8Array(width * height);
  if (!options) return {corrected, report:null};
  const radius = Math.max(1, Math.min(2, options.radius ?? 2));
  const threshold = Math.max(1, options.minimum_excess ?? 12);
  const background = options.background ?? [255, 0, 255];
  if (background[0] !== 255 || background[1] !== 0 || background[2] !== 255)
    throw Error('Edge recovery currently requires the authored solid magenta background');
  const distance = new Uint8Array(width * height);distance.fill(255);
  const queue = new Int32Array(width * height);let head=0,tail=0;
  for(let p=0;p<distance.length;p++)if(input[p*4+3]>0&&output[p*4+3]===0){distance[p]=0;queue[tail++]=p;}
  while(head<tail){
    const p=queue[head++],d=distance[p];if(d>=radius)continue;
    const x=p%width,y=Math.floor(p/width);
    for(let dy=-1;dy<=1;dy++)for(let dx=-1;dx<=1;dx++){
      const xx=x+dx,yy=y+dy,n=yy*width+xx;
      if(xx<0||yy<0||xx>=width||yy>=height||distance[n]!==255)continue;
      distance[n]=d+1;queue[tail++]=n;
    }
  }
  let count=0,minCoverage=1,maxRoundtripError=0;
  for(let p=0;p<distance.length;p++){
    if(!output[p*4+3]||distance[p]===0||distance[p]>radius)continue;
    const i=p*4,r=input[i],g=input[i+1],b=input[i+2],excess=Math.min(r,b)-g;
    if(excess<threshold || r>=2*b)continue;
    const coverage=1-excess/255;
    if(coverage<=0)continue;
    for(let c=0;c<3;c++){
      const recovered=(input[i+c]-(1-coverage)*background[c])/coverage;
      output[i+c]=Math.max(0,Math.min(255,Math.round(recovered)));
      const recomposed=coverage*output[i+c]+(1-coverage)*background[c];
      maxRoundtripError=Math.max(maxRoundtripError,Math.abs(recomposed-input[i+c]));
    }
    corrected[p]=1;count++;minCoverage=Math.min(minCoverage,coverage);
  }
  return {corrected,report:{mode:'magenta_edge_rgb_unmix_preserve_alpha',
    radius,minimum_excess:threshold,protected_red_ratio:2,background,corrected_pixels:count,
    minimum_estimated_coverage:minCoverage,maximum_recomposition_error:maxRoundtripError,
    alpha_unchanged:true,interior_outside_edge_band_unchanged:true}};
}

function connectedComponents(rgba,width,height,minAlpha=1) {
  const labels=new Int32Array(width*height),queue=new Int32Array(width*height),out=[];
  for(let start=0;start<labels.length;start++) {
    if(labels[start]||rgba[start*4+3]<minAlpha)continue;
    const id=out.length+1;let head=0,tail=0,bbox=[width,height,0,0],sx=0,sy=0;
    labels[start]=id;queue[tail++]=start;
    while(head<tail) {
      const p=queue[head++],x=p%width,y=Math.floor(p/width);sx+=x;sy+=y;
      bbox[0]=Math.min(bbox[0],x);bbox[1]=Math.min(bbox[1],y);bbox[2]=Math.max(bbox[2],x+1);bbox[3]=Math.max(bbox[3],y+1);
      for(let dy=-1;dy<=1;dy++)for(let dx=-1;dx<=1;dx++) {
        const xx=x+dx,yy=y+dy,n=yy*width+xx;
        if(xx<0||yy<0||xx>=width||yy>=height||labels[n]||rgba[n*4+3]<minAlpha)continue;
        labels[n]=id;queue[tail++]=n;
      }
    }
    out.push({id,count:tail,bbox,center:[sx/tail,sy/tail]});
  }
  return {labels,components:out};
}
module.exports={backgroundCandidate,matteBackground,connectedComponents};
