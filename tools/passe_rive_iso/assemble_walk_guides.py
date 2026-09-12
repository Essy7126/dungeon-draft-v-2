from PIL import Image
from pathlib import Path
p=Path(__file__).resolve().parents[2]/'art/source/characters/achilles/passe_rive_walk_iso_v1'
for d in ['E','S','N','W']:
 a=Image.new('RGB',(2560,2880),'#e3e6e4')
 for i in range(12):
  im=Image.open(p/'guides'/d/f'{i:02}.png');a.paste(im,(i%4*640,i//4*960),im)
 a.save(p/(d+'_guide.png'))
