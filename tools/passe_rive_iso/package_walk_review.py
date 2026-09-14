from pathlib import Path
import json,shutil
ROOT=Path(__file__).resolve().parents[2];SRC=ROOT/'art/source/characters/achilles/passe_rive_walk_iso_v1';OUT=ROOT/'artifacts/spine_trial/passe_rive_walk_iso_v1'
views={}
for d,label,stride in [('E','Face · bas droite',[160,80]),('S','Face · bas gauche',[-160,80]),('N','Dos · haut droite',[160,-80]),('W','Dos · haut gauche',[-160,-80])]:
 if not (OUT/f'{d}_v1_audit.json').exists():continue
 frames=[f'frames/{d}_v1_{i:02}.png' for i in range(12)]
 if d=='E' and (OUT/'E_half_audit.json').exists():frames=frames[:6]+[f'frames/E_half_{i:02}.png' for i in range(6)]
 if d=='E' and (OUT/'E_inbet_audit.json').exists():
  mapping=[('keys',0),('inbet',0),('inbet',1),('keys',1),('inbet',2),('inbet',3),('keys',2),('inbet',4),('inbet',5),('keys',3),('inbet',6),('inbet',7)]
  frames=[f'frames/E_{key}_{index:02}.png' for key,index in mapping]
 views[d]={'label':label,'stride':stride,'frames':frames,'status':'Marche en contrôle — cette vue ne vaut pas encore validation finale.','notes':'Dessins et raccords examinés séparément des contrôles techniques. Distance provisoire : 160 × 80 pixels source par cycle ; à mesurer sur les appuis peints.'}
 if d=='E':
  views[d]['status']='À corriger : dérive verticale du pied sur la grille et variations entre poses clés et intermédiaires.'
  views[d]['notes']='Suivi local : quatre repères du même pied sur les images 1 à 4, environ 7 pixels de dérive à l’échelle du jeu. Suivi perdu à l’image 5 ; aucune extrapolation au reste du cycle. Un réglage de vitesse seul ne suffit pas.'
 else:
  views[d]['notes']='Cadrage, alpha et équipement examinés ; trajectoire exacte des appuis peints encore à mesurer. Le nombre d’images chargées ne vaut pas validation du mouvement.'
 folder=OUT/'guides'/d;folder.mkdir(parents=True,exist_ok=True)
 for i in range(12):shutil.copy2(SRC/'guides'/d/f'{i:02}.png',folder/f'{i:02}.png')
(OUT/'walk_review.json').write_text(json.dumps({'order':list(views),'views':views},indent=2,ensure_ascii=False),encoding='utf8')
shutil.copy2(ROOT/'tools/passe_rive_iso/walk_review.html',OUT/'review.html')
shutil.copy2(ROOT/'asset/map/painted/room_01_forest/forest_background_v2.webp',OUT/'map.webp')
print('REVIEW '+','.join(views))
