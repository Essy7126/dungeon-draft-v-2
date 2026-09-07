// Source-only analysis for optional, separately authored 2x2 attack replacements.
module.exports = async function loadSupplement({ fs,path,sharp,ROOT,SOURCE,dir,overrides,extractComponents,sha,median,CORE_ALPHA }) {
  const sourceRel=`${SOURCE}/attack_${dir}.png`,sourcePath=path.join(ROOT,sourceRel);
  if(overrides.enabled===false||!fs.existsSync(sourcePath)) return null;
  const original=fs.readFileSync(sourcePath),metadata=await sharp(original).metadata();
  if(!metadata.hasAlpha)throw Error(`${dir} supplemental attack needs true alpha`);
  const {data,info}=await sharp(original).ensureAlpha().raw().toBuffer({resolveWithObject:true});
  const w=info.width,h=info.height,cw=w/2,ch=h/2;
  const {components,labels,discardedCoreComponents}=extractComponents(data,w,h,4);
  const ordered=new Array(4);
  for(const c of components){
    c.col=Math.min(1,Math.floor(c.center[0]/cw));c.row=Math.min(1,Math.floor(c.center[1]/ch));
    const i=c.row*2+c.col;c.index=12+i;c.source=sourceRel;
    if(ordered[i])throw Error(`${dir}: ambiguous supplemental attack cell ${i}`);
    ordered[i]=c;
  }
  if(ordered.filter(Boolean).length!==4)throw Error(`${dir}: missing supplemental attack pose`);
  const floors=[Math.max(...ordered.slice(0,2).map(c=>c.bbox[3]-1)),Math.max(...ordered.slice(2,4).map(c=>c.bbox[3]-1))];
  const footXs=ordered.map(c=>{
    let min=w,max=0;const ymin=c.bbox[3]-(c.bbox[3]-c.bbox[1])*0.25;
    for(const p of c.pixels){if(Math.floor(p/w)<ymin)continue;const x=p%w;min=Math.min(min,x);max=Math.max(max,x);}
    return (min+max)/2-c.col*cw;
  });
  const rootLocalX=overrides.root_local_x??median(footXs);
  const c=ordered[0];
  const crestYs=c.pixels.filter(p=>Math.abs(p%w-rootLocalX)<cw*0.30&&data[p*4]>data[p*4+1]*1.4&&data[p*4]>data[p*4+2]*1.3&&data[p*4]>65&&Math.floor(p/w)<floors[0]-ch*0.35).map(p=>Math.floor(p/w));
  if(!crestYs.length&&!overrides.crest_top)throw Error(`${dir}: missing supplement crest measurement`);
  const crestTop=overrides.crest_top??Math.min(...crestYs),scale=overrides.scale??(overrides.body_target_height??205)/(floors[0]-crestTop);
  let zero=0,full=0,partial=0,removedPixels=0,maxRemovedAlpha=0,removedAlphaSum=0;
  for(let p=0;p<w*h;p++){
    const a=data[p*4+3];if(!a)zero++;else if(a===255)full++;else partial++;
    if(a&&!labels[p]){removedPixels++;maxRemovedAlpha=Math.max(maxRemovedAlpha,a);removedAlphaSum+=a;}
  }
  if(zero/(w*h)<0.35||maxRemovedAlpha>CORE_ALPHA)throw Error(`${dir}: supplemental alpha validation failed`);
  const manifest={source:sourceRel,source_sha256:sha(original),source_dimensions:[w,h],grid:[2,2],source_alpha:{zero,full,partial,transparent_fraction:zero/(w*h)},segmentation:{threshold:CORE_ALPHA,edge_preservation_radius:2,removed_pixels:removedPixels,max_removed_alpha:maxRemovedAlpha,removed_alpha_sum:removedAlphaSum,discarded_core_components:discardedCoreComponents},fixed_scale:scale,crest_top:crestTop,shared_row_ground_y:floors,source_root_local_x:rootLocalX,replaces_source_indices:[12,13,14,15]};
  return {data,labels,w,h,cw,ch,floors,scale,rootLocalX,ordered,overrides,manifest};
};
