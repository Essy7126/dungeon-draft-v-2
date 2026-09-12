"""Authored normalized contours for the immutable 1672x941 memorial painting.

Pixels provide visible surface references, never automatic collision inference.
Regenerate masks through the shared halt workshop after changing calibration.
"""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4]
PATH = ROOT / 'data/halts/stele_names_v1.json'
W, H = 1672, 941


def point(xy):
    return [round(xy[0] / W, 7), round(xy[1] / H, 7)]


def poly(points):
    return [point(p) for p in points]


def main():
    m = json.loads(PATH.read_text(encoding='utf-8-sig'))
    source = ROOT / m['source']['image'].removeprefix('res://')
    assert m['source']['size'] == [W, H]
    assert hashlib.sha256(source.read_bytes()).hexdigest() == m['source']['sha256']
    m.update(title='La stèle des noms', subtitle='LES NOMS DEMEURENT · LE FLEUVE EMPORTE', stage='playable_study')
    m['source'].update(provider='image_gen built-in', generated_on='2026-09-12',
        provider_source_basename='exec-70f99430-631d-426b-82dd-eef4a8abd44b.png')
    m['world'] = {'width':2400, 'player_height_ratio':0.18, 'speed':210,
                  'foot_clearance':18, 'spawn':point([553,649])}
    m['navigation'] = {'outline':poly([
        [504,610],[588,574],[679,540],[730,464],[819,435],[902,413],[973,386],
        [1020,402],[1031,443],[1168,463],[1306,482],[1385,526],[1403,566],
        [1510,604],[1619,654],[1630,694],[1600,758],[1520,786],[1400,765],
        [1352,718],[1317,672],[1210,620],[1136,585],[1067,571],[1005,572],
        [921,600],[826,615],[758,645],[682,692],[617,729],[565,723],[529,691],[503,663]
    ]), 'obstacles':[]}
    m['landmarks'] = [
        {'id':'names_stele','title':'Lire les noms','action':'dialogue',
         'point':point([1060,505]),'focus':point([1180,282]),'radius':0.095,
         'description':"Une rame, un visage sous une capuche, des noms presque effacés : le relief garde la mémoire de Charon. Les voyageurs confient au passeur une obole pour la traversée, et à cette pierre ce qu’ils craignent de perdre.\n\nLe Léthé emporte les souvenirs ; le Styx marque la séparation. Ici, avant de reprendre la barque, Achille s’arrête auprès de ceux dont personne ne prononce plus le nom. Sous les marques usées, une ancienne piste demeure lisible."},
        {'id':'ferryman_boat','title':'Reprendre la barque','action':'exit',
         'point':point([535,649]),'focus':point([264,650]),'radius':0.115,
         'description':'La lanterne reste allumée à la proue. La même barque attend Achille pour la prochaine escale.'}
    ]
    water = poly([[0,170],[590,170],[615,260],[689,309],[772,336],[792,392],
        [701,430],[646,498],[589,535],[515,557],[450,560],[375,573],
        [351,653],[422,758],[566,799],[631,800],[705,748],[785,700],
        [875,670],[958,653],[1017,668],[1075,718],[1175,766],[1285,807],
        [1310,870],[1260,941],[0,941]])
    m['water'] = {'tint':'#3bada8','polygons':[water],
        'caustic_strength':0.16,'distortion_strength':0.68,'far_fade':[0.18,0.46],
        'regions':[{'polygon':water,'direction':[0.78,0.22],'speed':0.52}],
        'exclusions':[
            poly([[75,552],[115,541],[154,576],[390,618],[468,640],[474,703],
                  [434,771],[316,790],[161,730],[95,653],[75,610]]),
            poly([[141,104],[186,101],[206,127],[209,230],[139,243]]),
            poly([[285,144],[327,138],[353,163],[357,285],[280,292]]),
            poly([[489,198],[535,185],[559,207],[563,305],[488,314]])
        ]}
    m['torches'] = [
        {'id':name,'point':point(center),'radius':point(radius),
         'enclosed':True,'flame_strength':1.0,'light_strength':1.15,
         'steady_light':0.3,'smoke_strength':0.06,'ember_count':0}
        for name, center, radius in [
            ('boat_lantern',[102,630],[13,16]),
            ('memorial_lantern',[1053,366],[12,15]),
            ('shore_lantern',[1575,559],[13,16])]
    ]
    m['cascades'] = []
    m['foliage_motion'] = {'strength':2.0,'speed':0.85}
    # Separate hanging curtains and reed clusters; the trunk, roots and paving
    # are excluded. Motion stays in the material mask, without moving colliders.
    leaves = json.loads(Path(__file__).with_name('foliage_contours.json').read_text(encoding='utf-8'))
    assert leaves['source_size'] == [W, H] and leaves['source_sha256'] == m['source']['sha256']
    m['foliage'] = [poly(points) for points in leaves['polygons']]
    m['bounce'] = [poly([[720,512],[805,488],[875,510],[848,553],[759,584],[716,570]])]
    m['mist'] = [
        {'rect':[0.025,0.15,0.31,0.15],'color':'#97b7bd','alpha':0.08},
        {'rect':[0.18,0.28,0.27,0.14],'color':'#8db7be','alpha':0.055},
        {'rect':[0.24,0.85,0.34,0.10],'color':'#759eac','alpha':0.045}
    ]
    # Walking remains on the near side of the stele and mooring post; no hidden
    # passage or painted object needs a duplicate foreground cutout.
    m['foreground'] = []
    m['ambience'] = {'footsteps':'stone','sources':[
        {'id':'river','kind':'water','point':point([832,738]),'radius':0.45,'gain_db':-22},
        {'id':'memorial_light','kind':'fire','point':point([1054,359]),'radius':0.2,'gain_db':-27}
    ]}
    m['review'] = {
        'forbidden_points':poly([[275,360],[265,671],[1180,361],[1420,417],[988,759]]),
        'stable_pixel':point([1040,499]),'water_pixel':point([751,797]),
        'fire_pixel':point([1053,366]),'foliage_pixel':point([857,200]),
        'loop_waypoints':poly([[650,601],[874,510],[1060,505],[1260,553],[1450,676],[1190,581],[900,546],[553,649]])
    }
    PATH.write_text(json.dumps(m,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
    print(PATH)


if __name__ == '__main__':
    main()
