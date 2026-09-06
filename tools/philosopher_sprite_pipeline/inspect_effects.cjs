const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const sharp = require('C:/Users/paolo/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const source = path.resolve(__dirname, '../../art/source/vfx/philosopher_mage/sprites_v1/source_effects.png');
(async () => {
  const bytes = fs.readFileSync(source);
  const {data, info} = await sharp(bytes).raw().toBuffer({resolveWithObject: true});
  const width = info.width, height = info.height;
  const rows = [], cols = [];
  for (let y=0; y<height; y++) {
    let count=0, max=0, low=0;
    for(let x=0;x<width;x++){const a=data[(y*width+x)*4+3];max=Math.max(max,a);if(a>32)count++;if(a>0)low++;}
    rows.push({y,count,max,nonzero:low});
  }
  for(let row=0;row<6;row++){
    const cuts=[];
    for(const nominal of [0,256,512,768,1024]){
      const candidates=[];
      for(let x=Math.max(0,nominal-30);x<Math.min(width,nominal+31);x++){
        let count=0,max=0,low=0;
        for(let y=row*256;y<(row+1)*256;y++){const a=data[(y*width+x)*4+3];max=Math.max(max,a);if(a>32)count++;if(a>0)low++;}
        candidates.push({x,count,max,nonzero:low});
      }
      candidates.sort((a,b)=>a.max-b.max||a.nonzero-b.nonzero||Math.abs(a.x-nominal)-Math.abs(b.x-nominal));
      cuts.push({nominal,best:candidates.slice(0,6)});
    }
    cols.push({row,cuts});
  }
  const bands=[];
  for(const nominal of [0,256,512,768,1024,1280,1536]) {
    const candidates=rows.filter(r=>Math.abs(r.y-nominal)<=48);
    candidates.sort((a,b)=>a.max-b.max||a.nonzero-b.nonzero||Math.abs(a.y-nominal)-Math.abs(b.y-nominal));
    bands.push({nominal,best:candidates.slice(0,10)});
  }
  const report={sha256:crypto.createHash('sha256').update(bytes).digest('hex'),size:[width,height],bands,columns:cols};
  const output=path.resolve(__dirname,'../../artifacts/philosopher_effects_review');
  fs.mkdirSync(output,{recursive:true});
  fs.writeFileSync(path.join(output,'alpha_lanes.json'),JSON.stringify(report,null,2));
  console.log(JSON.stringify(report,null,2));
})().catch(error=>{console.error(error);process.exitCode=1;});
