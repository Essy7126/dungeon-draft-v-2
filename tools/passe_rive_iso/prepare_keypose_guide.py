from pathlib import Path
from PIL import Image
root=Path(__file__).resolve().parents[2]/'art/source/characters/achilles/passe_rive_walk_iso_v1'
sheet=Image.new('RGB',(1280,1920),'#ddddda')
for n,i in enumerate([0,3,6,9]):
    im=Image.open(root/'guides/E'/f'{i:02}.png').convert('RGBA')
    sheet.paste(im,(n%2*640,n//2*960),im)
sheet.save(root/'E_keypose_guide.png')
