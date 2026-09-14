"""Explicit art attachment corrections after visually inspecting each atlas."""
import json,copy
from pathlib import Path
from build_walk import DEFAULT,SRC

def write(d,changes):
    p=copy.deepcopy(DEFAULT)
    for key,val in changes.items():p[key].update(val)
    (SRC/f'{d}_attachments.json').write_text(json.dumps(p,indent=2))

write('S',{
 '4':{'a':[.36,.11],'b':[.77,.93]},
 '6':{'a':[.35,.14],'b':[.73,.94]},
 '8':{'a':[.28,.09],'b':[.72,.90]},
 '12':{'a':[.30,.1],'b':[.72,.91]},
 '13':{'a':[.63,.08],'b':[.36,.92]},
 '10':{'ankle':[.74,.20],'heel':[.92,.70],'toe':[.10,.92]},
 '14':{'ankle':[.72,.20],'heel':[.92,.70],'toe':[.10,.92]},
 'head':{'anchor':[.48,.80]},
 'cape':{'anchor':[.75,.05]},
 'sash':{'anchor':[.55,.035]}})

write('N',{
 '4':{'a':[.30,.14],'b':[.75,.94]},
 '5':{'a':[.31,.09],'b':[.73,.78]},
 '6':{'a':[.50,.14],'b':[.47,.94]},
 '7':{'a':[.67,.09],'b':[.30,.78]},
 '8':{'a':[.64,.10],'b':[.34,.91]},
 '9':{'a':[.62,.09],'b':[.37,.92]},
 '12':{'a':[.30,.10],'b':[.65,.91]},
 '13':{'a':[.47,.08],'b':[.50,.92]},
 '10':{'ankle':[.28,.20],'heel':[.13,.92],'toe':[.92,.53]},
 '14':{'ankle':[.28,.20],'heel':[.13,.92],'toe':[.92,.53]},
 'head':{'anchor':[.53,.80]},
 'cape':{'anchor':[.75,.05]}})
write('W',{
 '4':{'a':[.53,.14],'b':[.48,.94]},
 '5':{'a':[.27,.09],'b':[.70,.78]},
 '6':{'a':[.47,.14],'b':[.46,.94]},
 '7':{'a':[.29,.09],'b':[.71,.78]},
 '8':{'a':[.33,.10],'b':[.73,.91]},
 '9':{'a':[.32,.09],'b':[.65,.92]},
 '12':{'a':[.60,.10],'b':[.27,.91]},
 '13':{'a':[.66,.08],'b':[.25,.92]},
 '10':{'ankle':[.64,.19],'heel':[.82,.92],'toe':[.14,.17]},
 '14':{'ankle':[.67,.20],'heel':[.85,.92],'toe':[.13,.18]},
 'head':{'anchor':[.48,.80]},
 'cape':{'anchor':[.24,.05]}})
print('S / N / W art attachments written; N back feet use the correctly oriented drawing.')
