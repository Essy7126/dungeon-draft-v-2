"""Verify actual Krita KRA/ORA round-trip, retaining each pose's offset."""
from pathlib import Path
import sys,json,zipfile,io
import numpy as np
from PIL import Image
ROOT=Path(__file__).resolve().parents[2]
SRC=ROOT/'art/source/characters/achilles/veilleur_walk_E_v1'
OUT=ROOT/'artifacts/spine_trial/veilleur_walk_E_v1'
sys.path.insert(0,str(ROOT/'tools/character_concept'))
from ora_export import read_layers,render
source=SRC/'painted_frames.ora'
size,original=read_layers(source)
other_size,roundtrip=read_layers(SRC/'painted_roundtrip.ora')
assert size==other_size
def planes(layers):
    result={}
    for name,image,xy in layers:
        plane=Image.new('RGBA',size);plane.alpha_composite(image,xy);result[name]=np.asarray(plane)
    return result
a,b=planes(original),planes(roundtrip)
assert a.keys()==b.keys()
changes={name:int(np.count_nonzero(np.any(a[name]!=b[name],axis=2))) for name in a}
assert all(n==0 for n in changes.values()),changes
with zipfile.ZipFile(SRC/'painted_frames.kra') as archive:
    merged=Image.open(io.BytesIO(archive.read('mergedimage.png'))).convert('RGBA')
native_changes=int(np.count_nonzero(np.any(np.asarray(merged)!=np.asarray(render(source)),axis=2)))
assert native_changes==0,native_changes
report={'scope':'Krita 5.3.3 : ORA vers KRA vers ORA. Comparaison RGBA complète, calque par calque avec leurs décalages.',
        'layer_count':len(a),'changed_pixels_by_layer':changes,'kra_merged_changed_pixels':native_changes,'passed':True}
(OUT/'native_source_report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(report,ensure_ascii=True))
