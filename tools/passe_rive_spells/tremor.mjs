// Local runtime deformation of the painted drawing arm; this does not create new poses.
const caches=new Map();
export function tremorImage(image,definition,pixels){
 if(!definition||Math.abs(pixels)<.015)return image;
 let cache=caches.get(image);
 if(!cache){
  const [cx,cy]=definition.center,[rx,ry]=definition.radius;
  const x=Math.floor(cx-rx-4),y=Math.floor(cy-ry-4),w=Math.ceil(rx*2+8),h=Math.ceil(ry*2+8);
  const canvas=document.createElement('canvas');canvas.width=image.width;canvas.height=image.height;
  const c=canvas.getContext('2d',{willReadFrequently:true});c.drawImage(image,0,0);
  const original=c.getImageData(x,y,w,h),output=c.createImageData(w,h),weights=new Float32Array(w*h);
  for(let j=0;j<h;j++)for(let i=0;i<w;i++){const v=Math.max(0,1-Math.hypot((i+x-cx)/rx,(j+y-cy)/ry));weights[j*w+i]=v*v*(3-2*v)}
  cache={canvas,c,x,y,w,h,original,output,weights};caches.set(image,cache);
 }
 const {canvas,c,x,y,w,h,original,output,weights}=cache,src=original.data,dst=output.data;
 for(let j=0;j<h;j++)for(let i=0;i<w;i++){
  const n=j*w+i,d=weights[n]*pixels,xx=Math.max(0,Math.min(w-1.001,i+d*.35)),yy=Math.max(0,Math.min(h-1.001,j+d));
  const ix=Math.floor(xx),iy=Math.floor(yy),fx=xx-ix,fy=yy-iy,k=(iy*w+ix)*4;
  for(let channel=0;channel<4;channel++)dst[n*4+channel]=(src[k+channel]*(1-fx)+src[k+4+channel]*fx)*(1-fy)+(src[k+w*4+channel]*(1-fx)+src[k+(w+1)*4+channel]*fx)*fy;
 }
 c.putImageData(output,x,y);return canvas;
}
