"""Author a spatial/scale diagram before generating the camp painting."""
import json
import sys
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools/halt_workshop'))
import halt_workshop as workshop

IDENTIFIER = 'companions_quarry_v1'
BRIEF = '''A makeshift camp left by the ancient Greek workers who excavated the underworld rock. Continue the basalt, bronze, lava and painted visual language of the preceding magma-springs room. A patched russet linen lean-to, rolled wool bedding, hand picks, wedges, chisels, wicker spoil baskets and a wooden drag-sled testify to manual excavation. A small sheltered hearth provides the rest interaction. A modest worn votive relief of bearded Hades with a TWO-pronged bident and a three-headed Cerberus, with a small bowl of pomegranate and coins, gives the place its Greek-underworld identity. Quarry chisel marks and half-extracted blocks appear in the rock. No industrial mine rails, electric lamps, modern gear, living characters or interface. Sparse old bones near the edge, warm lamps and one distant thin magma fissure. This is an intimate refuge, not a combat arena or monumental palace.'''


def main():
    folder = workshop.new_brief(IDENTIFIER, 'hub', BRIEF)
    plan = workshop.read(folder / 'spatial_plan.json')
    plan['world'] = {'width':2200, 'player_height_ratio':0.18, 'speed':210,
                     'foot_clearance':16, 'spawn':[0.29,0.76]}
    plan['navigation'] = {'outline':[[.18,.72],[.31,.57],[.44,.53],[.56,.45],
        [.66,.45],[.73,.53],[.87,.56],[.88,.70],[.77,.79],[.59,.86],[.39,.85],[.25,.82]],
        'obstacles':[[[.40,.56],[.49,.54],[.54,.61],[.48,.68],[.40,.64]]]}
    plan['landmarks'] = [
        {'id':'quarry_hearth','title':'Le feu des compagnons','action':'rest',
         'point':[.55,.67],'focus':[.47,.60],'radius':.07,'description':BRIEF},
        {'id':'deeper_gallery','title':'Reprendre la descente','action':'exit',
         'point':[.82,.60],'focus':[.87,.47],'radius':.07,'description':'Le sentier continue sous la roche.'}]
    workshop.write(folder/'spatial_plan.json', plan)
    im=Image.new('RGB',(1672,941),'#202d39'); d=ImageDraw.Draw(im)
    def points(poly): return [(int(x*1672),int(y*941)) for x,y in poly]
    d.polygon(points(plan['navigation']['outline']),fill='#727e78',outline='#d1d3b2')
    d.polygon(points(plan['navigation']['obstacles'][0]),fill='#a55530')
    boxes=[((100,130,380,380),'Arrival arch','#596a76'),
           ((380,230,850,460),'Patched lean-to / bedding','#80513f'),
           ((1010,170,1320,430),'Hades / bident / Cerberus relief','#7c827a'),
           ((1400,280,1640,500),'Exit gallery','#465b67'),
           ((220,495,495,635),'Picks / baskets / sled','#72604c')]
    for box,label,color in boxes:
        d.rectangle(box,fill=color,outline='#c7b68a',width=3);d.text((box[0]+6,box[1]+6),label,fill='white')
    # Equal standing references H=18% image; body B=202/257 H.
    for x,y in [(480,700),(960,650),(1370,605)]:
        h=169;b=round(h*202/257)
        d.line([(x+21,y),(x+21,y-h)],fill='#f5de96',width=3)
        d.ellipse((x-11,y-b,x+11,y-b+24),fill='#f5de96')
        d.rectangle((x-12,y-b+25,x+12,y-44),fill='#f5de96')
        d.line([(x-6,y-48),(x-12,y)],fill='#f5de96',width=9)
        d.line([(x+6,y-48),(x+12,y)],fill='#f5de96',width=9)
        d.text((x+29,y-h),'H=0.18 image; B=202/257 H',fill='white')
    d.text((35,890),'Schematic only. Gray = clear paths; orange = small hearth. Remove all marks and silhouettes in final art.',fill='white')
    im.save(folder/'spatial_plan_reference.png')
    request=workshop.read(folder/'request.json')
    request['references']=['res://'+(folder.relative_to(ROOT)/'spatial_plan_reference.png').as_posix(),
        'res://asset/map/painted/merchant/hall_v1/hall.png',
        'res://assets/catabase/combat/puits_sources_v1/land.png']
    request['prompt']=request['prompt'].replace('player_height_ratio=0.22','player_height_ratio=0.18').replace('22%','18%')
    request['prompt']+='''\nCOMPOSITION: image 1 is the spatial and human-scale diagram, image 2 the original master style, image 3 the preceding room for continuity only. Landscape 16:9, 1672x941 or higher equivalent. Follow the diagram with connected clear paths around the small central-left hearth. Keep the majority of props behind the walking area, so a standing player does not need to pass behind painted furniture. Arrival left, shelter upper-left, small votive relief upper-right, departure right, quiet wide sweep of open floor in the lower half. Campfire flame about 0.3 body-height; low ring of loose stones, two simple low stools. Bedroll length one body height; small baskets 0.2 body-height. Tent height 1.4 body-height. Normal doors 1.5 body-height. Hades is a carved RELIEF in a roughly two-body-height slab, not an NPC: a bearded ruler with a modest ancient crown, a clearly forked two-pronged staff, Cerberus with THREE distinct canine heads at his feet. No Christian devil horns, pitchfork with three prongs or pentagrams. A rough cloth awning is tied to pick handles and cracks in the wall, not an elaborate structure. A few clay oil lamps, bronze lanterns, split amphorae and a tally scratched as abstract cuts make the camp personal. Two bundles and three bedrolls imply former companions. Uneven quarried blue-gray rock floor, large quiet forms. No elevated octagonal combat platform, no grid. No labels, writing, characters, silhouettes or user interface in the final painting. Do not copy the merchant shop, water or well. Preserve the painted material clarity and cool/warm balance. Lava is only a thin distant orange fissure beyond the right exit; the campsite is dry and sheltered.'''
    workshop.write(folder/'request.json',request)
    (folder/'generation_prompt.txt').write_text(request['prompt']+'\n',encoding='utf-8')
    print(folder)


if __name__=='__main__':main()
