"""Mechanical atlas extraction and uniform resizing of reviewed Meshy images.

No creative redrawing. Sources remain immutable in meshy_output project folders.
"""
import argparse
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageOps

ROOT = Path(__file__).resolve().parents[2]
RECEIPT = ROOT / 'meshy_output/catabase_ui_production_receipt.json'
EXPORT_RECEIPT = ROOT / 'art/source/catabase/meshy_ui/exports.json'
NAVY = (20, 29, 46)


def hash_file(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def isolate(cell, matte):
    rgb = np.asarray(cell.convert('RGB')).astype(np.int16)
    if matte == 'magenta':
        r,g,b = rgb[:,:,0],rgb[:,:,1],rgb[:,:,2]
        chroma = (r > 80) & (b > 80) & (np.minimum(r,b)-g > 50) & (np.abs(r-b) < 100)
        solid = ~chroma
        alpha_image = Image.fromarray(np.uint8(solid)*255).filter(ImageFilter.GaussianBlur(0.35))
        alpha = np.asarray(alpha_image)
    else:
        corners = np.concatenate([rgb[:8,:8].reshape(-1,3),rgb[:8,-8:].reshape(-1,3),rgb[-8:,:8].reshape(-1,3),rgb[-8:,-8:].reshape(-1,3)])
        background = np.median(corners,axis=0)
        distance = np.max(np.abs(rgb-background),axis=2)
        solid = distance > 30
        # Chroma matte also clears gaps in rings/chains; preserve colored glows.
        alpha = np.uint8(np.clip((distance-16)/14,0,1)*255)
    bounds = Image.fromarray(np.uint8(solid)*255).getbbox()
    if bounds is None:
        raise RuntimeError('No painted foreground in atlas cell')
    apron = 2 if matte == 'magenta' else 10
    bounds = (max(0,bounds[0]-apron),max(0,bounds[1]-apron),min(cell.width,bounds[2]+apron),min(cell.height,bounds[3]+apron))
    rgba = cell.convert('RGBA')
    rgba.putalpha(Image.fromarray(alpha))
    return rgba.crop(bounds), bounds


def export_job(job):
    source = Path(job['source_path'])
    with Image.open(source) as check:
        check.verify()
    image = Image.open(source).convert('RGB')
    records = []
    previews = []
    if job['kind'] == 'background':
        entry = job['entries'][0]
        output = ROOT / entry['path']
        output.parent.mkdir(parents=True,exist_ok=True)
        image.save(output,optimize=True)
        records.append({'id':entry['id'],'path':entry['path'],'source_box':[0,0,image.width,image.height],'dimensions':list(image.size),'processing':'original pixels, RGB PNG','sha256':hash_file(output)})
        previews.append((entry['id'],image))
    else:
        cols,rows = job['cols'],job['rows']
        # Reviewed source: Meshy supplied a fourth row of spare button plates.
        # The six requested states occupy rows 1-3 in the correct order.
        if job['id'] == 'buttons':
            cols, rows = 2, 4
        for i,entry in enumerate(job['entries']):
            col,row = i%cols,i//cols
            # A narrow blank gutter excludes occasional AI-drawn grid lines.
            inset = 8
            cell_box = (round(col*image.width/cols)+inset,round(row*image.height/rows)+inset,round((col+1)*image.width/cols)-inset,round((row+1)*image.height/rows)-inset)
            cell = image.crop(cell_box)
            isolated,bounds = isolate(cell,job['matte'])
            if job['treatment'] == 'icons':
                fitted = ImageOps.contain(isolated,(232,232),Image.Resampling.LANCZOS)
                output_image = Image.new('RGBA',(256,256),(0,0,0,0))
                output_image.alpha_composite(fitted,((256-fitted.width)//2,(256-fitted.height)//2))
            else:
                # Retain native aspect ratio so border artwork is never stretched.
                limit = (512,160) if job['treatment'] == 'buttons' else ((128,128) if job['treatment'] == 'frames' else (448,448))
                output_image = ImageOps.contain(isolated,limit,Image.Resampling.LANCZOS)
            output = ROOT / entry['path']
            output.parent.mkdir(parents=True,exist_ok=True)
            output_image.save(output,optimize=True)
            source_box = [cell_box[0]+bounds[0],cell_box[1]+bounds[1],cell_box[0]+bounds[2],cell_box[1]+bounds[3]]
            records.append({'id':entry['id'],'path':entry['path'],'cell_index':i,'reviewed_grid':[cols,rows],'cell_box':list(cell_box),'source_box':source_box,'source_content_dimensions':list(isolated.size),'dimensions':list(output_image.size),'processing':'cell extraction, exterior matte removal, uniform fit; no creative repainting','sha256':hash_file(output)})
            previews.append((entry['id'],output_image))
    for record in records:
        record.update(provider='Meshy',model=job['reported_model'],task_id=job['task_id'],source_path=str(source.relative_to(ROOT)).replace('\\','/'),source_sha256=hash_file(source),review_status='pending',runtime_validation='pending')
    review = ROOT / 'meshy_output/review'
    review.mkdir(exist_ok=True)
    columns = 3
    sheet = Image.new('RGB',(columns*340,((len(previews)+columns-1)//columns)*252),NAVY)
    draw = ImageDraw.Draw(sheet)
    for i,(name,im) in enumerate(previews):
        x,y = (i%columns)*340,(i//columns)*252
        thumb = ImageOps.contain(im,(202,190),Image.Resampling.LANCZOS)
        sheet.paste(thumb,(x+8,y+8),thumb if thumb.mode == 'RGBA' else None)
        if job.get('treatment') == 'icons':
            for j,size in enumerate([64,48,34]):
                tiny = im.resize((size,size),Image.Resampling.LANCZOS)
                sheet.paste(tiny,(x+250,y+8+j*66),tiny)
        draw.text((x+8,y+208),name,fill=(225,210,178))
    sheet.save(review / (job['id']+'.jpg'),quality=90)
    return records


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('ids',nargs='*')
    args=parser.parse_args()
    receipt=json.loads(RECEIPT.read_text(encoding='utf-8'))
    document=json.loads(EXPORT_RECEIPT.read_text(encoding='utf-8')) if EXPORT_RECEIPT.exists() else {'phase':'catabase_ui_v1','provider':'Meshy','exports':[]}
    for job in receipt['jobs']:
        if job.get('status') != 'SUCCEEDED' or (args.ids and job['id'] not in args.ids):
            continue
        records=export_job(job)
        replaced={r['path'] for r in records}
        document['exports']=[r for r in document['exports'] if r['path'] not in replaced]+records
        print('EXPORTED',job['id'],len(records))
    EXPORT_RECEIPT.parent.mkdir(parents=True,exist_ok=True)
    (EXPORT_RECEIPT.parent/'.gdignore').write_text('')
    EXPORT_RECEIPT.write_text(json.dumps(document,ensure_ascii=False,indent=2),encoding='utf-8')
    print('TOTAL EXPORTS',len(document['exports']))


if __name__ == '__main__':
    main()
