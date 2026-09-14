from pathlib import Path
from PIL import Image
root=Path(__file__).resolve().parents[2]/'art/source/characters/achilles/passe_rive_walk_iso_v1'
sheet=Image.new('RGB',(2560,1920),'#ddddda')
for n,i in enumerate([1,2,4,5,7,8,10,11]):
    im=Image.open(root/'guides/E'/f'{i:02}.png').convert('RGBA')
    sheet.paste(im,(n%4*640,n//4*960),im)
sheet.save(root/'E_inbetween_guide.png')
