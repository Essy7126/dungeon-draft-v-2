"""Hand-authored walkable ground and light regions on the selected camp image."""
import hashlib
import json
from pathlib import Path
from PIL import Image

ROOT=Path(__file__).resolve().parents[4]
PATH=ROOT/'data/halts/companions_quarry_v1.json'
W,H=1672,941
def point(p):return [round(p[0]/W,7),round(p[1]/H,7)]
def poly(p):return [point(v) for v in p]

def main():
    m=json.loads(PATH.read_text(encoding='utf-8-sig'))
    source=ROOT/'asset/map/painted/halts/companions_quarry_v1/source-v3.png'
    assert Image.open(source).size==(W,H)
    assert hashlib.sha256(source.read_bytes()).hexdigest()=='5622136e23ae6a2b559b39f79d5f2edee212111b55540fea6bcc087af2d4ac14', 'A different image requires a new calibration'
    m.update(title='Le camp des compagnons',subtitle='LES TAILLEURS DE L’OMBRE · UNE BRAISE DEMEURE',stage='playable_study')
    m['source'].update(image='res://'+source.relative_to(ROOT).as_posix(),size=[W,H],
        sha256=hashlib.sha256(source.read_bytes()).hexdigest(),provider='image_gen built-in',
        generated_on='2026-09-12',provider_source_basename='exec-0cd01de4-b87a-41bc-89df-9b812c7339af.png',
        revision_prompts=['res://art/source/halts/companions_quarry_v1/PROMPT-v2.md','res://art/source/halts/companions_quarry_v1/PROMPT-v3.md'])
    m['world']={'width':2200,'player_height_ratio':0.18,'speed':210,'foot_clearance':16,'spawn':point([440,572])}
    m['navigation']={'outline':poly([[155,478],[310,450],[400,429],[440,390],[530,373],
        [675,364],[810,373],[960,400],[1090,438],[1210,460],[1380,480],[1490,507],
        [1555,517],[1550,554],[1480,580],[1430,608],[1360,660],[1320,710],
        [1270,736],[1140,761],[1095,800],[995,837],[850,839],[694,802],[636,760],
        [595,722],[526,693],[493,650],[409,603],[328,581],[244,566],[173,529]]),
        'obstacles':[poly([[498,407],[545,384],[665,399],[712,428],[792,420],
            [811,491],[713,531],[572,546],[451,518],[428,478],[434,426]])]}
    m['landmarks']=[
        {'id':'quarry_hearth','title':'Le feu des compagnons','action':'rest',
         'point':point([704,596]),'focus':point([612,455]),'radius':0.075,
         'description':'La toile tient encore sur des manches de pioche. Autour du foyer, trois couchettes, des paniers de déblais et des coins fichés dans la pierre racontent le camp de ceux qui ont ouvert ces galeries. Ils travaillaient par relais, loin du jour.\n\nDans la niche, Hadès tient son sceptre ; Cerbère veille à ses pieds. Quelques oboles et des grenades ont été déposées avant la dernière descente. Les tailleurs demandaient au maître des profondeurs de laisser leurs compagnons revenir.\n\nUne braise subsiste. Achille peut se reposer ici avant de reprendre le chemin.'},
        {'id':'deeper_gallery','title':'Reprendre la descente','action':'exit',
         'point':point([1420,550]),'focus':point([1532,442]),'radius':0.065,
         'description':'Les coups de pic se prolongent sous cette arcade. La lueur du magma indique la suite du chemin.'}]
    m['water']={'tint':'#48d896','polygons':[],'regions':[],'exclusions':[]}
    m['cascades']=[];m['foliage']=[];m['bounce']=[];m['foreground']=[]
    m['torches']=[{'id':'hearth','point':point([610,419]),'radius':point([27,43]),
        'flame_strength':0.5,'light_strength':0.55,'steady_light':0.15,'smoke_strength':0.18,'ember_count':12}]
    for name,center,radius in [('arrival_outer',[43,354],[12,17]),('arrival_inner',[220,306],[12,17]),
        ('shelter_lamp',[648,224],[11,16]),('hades_lamp',[1151,171],[12,17]),('exit_lamp',[1508,339],[12,17])]:
        m['torches'].append({'id':name,'point':point(center),'radius':point(radius),
            'enclosed':True,'flame_strength':0.65,'light_strength':0.6,'steady_light':0.2,'smoke_strength':0,'ember_count':0})
    for name,center in [('offering_left',[1170,299]),('offering_right',[1322,334])]:
        m['torches'].append({'id':name,'point':point(center),'radius':point([6,10]),
            'flame_strength':0.3,'light_strength':0.3,'smoke_strength':0.01,'ember_count':0})
    m['mist']=[{'rect':[.935,.25,.06,.22],'color':'#97775e','alpha':.025}]
    m['ambience']={'footsteps':'stone','sources':[{'id':'campfire','kind':'fire','point':point([610,437]),'radius':.42,'gain_db':-22}]}
    m['review']={'forbidden_points':poly([[610,470],[474,300],[970,220],[1270,320],[1530,780],[250,725]]),
        'stable_pixel':point([1040,660]),'fire_pixel':point([609,416]),
        'loop_waypoints':poly([[345,500],[421,558],[540,590],[710,594],[920,539],[1120,532],
            [1320,539],[1420,550],[1260,648],[1100,706],[877,729],[650,653],[440,572]])}
    PATH.write_text(json.dumps(m,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
    print(PATH)

if __name__=='__main__':main()
