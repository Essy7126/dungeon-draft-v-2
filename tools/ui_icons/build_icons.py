"""Original Catabase vector glyphs. Run from repository root; no external dependencies.
64-unit optical grid, readable silhouettes, shared ivory/patinated gold/teal palette.
Gameplay families retain their motif; upgraded forms add geometric rank marks.
"""
from pathlib import Path
import re, json
ROOT = Path('assets/catabase/icons')
INK='#121615'; GOLD='#d6c29a'; IVORY='#eee5d2'; TEAL='#8fb9bf'; RED='#e29b85'; GREEN='#9ec9b1'; BLUE='#a2c7e0'
def path(d, fill='none', stroke='currentColor', width=2.6):
    return f'<path d="{d}" fill="{fill}" stroke="{stroke}" stroke-width="{width}"/>'
def circle(x,y,r,fill='none',stroke='currentColor',width=2.6):
    return f'<circle cx="{x}" cy="{y}" r="{r}" fill="{fill}" stroke="{stroke}" stroke-width="{width}"/>'
def group(s, transform): return f'<g transform="{transform}">{s}</g>'
# All motifs are authored here, not traced from third-party game artwork.
spear=path('M15 51 43 23 M37 22 53 11 47 29Z', GOLD)+path('M17 43 23 49')
sword=path('M19 46 43 15 51 11 51 21 26 48Z', '#324440')+path('M20 38 32 48 M15 52 22 44 M12 49 19 55')
shield=path('M32 9 51 17 49 35Q46 46 32 55Q18 46 15 35L13 17Z', '#233a38')+path('M32 16V46 M22 25 32 19 42 25', 'none', GOLD)
boot=path('M21 10H37L35 35 51 43V50H16V40L20 32Z', '#263734')+path('M22 21H35 M22 28H34 M17 44H48')
heart=path('M32 51 13 32C0 17 22 7 32 23C42 7 64 17 51 32Z', '#493131')
flame=path('M33 8C39 22 23 21 38 33L45 22C62 48 37 60 23 51C10 43 15 31 24 24C21 36 28 37 29 31C34 23 28 18 33 8Z', '#51352b')
bolt=path('M38 7 15 36H29L24 57 49 26H34Z', '#334a4b')
bow=path('M20 11Q57 32 20 53L31 32Z')+path('M13 32H53 M45 25 53 32 45 39')
eye=path('M8 32Q32 7 56 32Q32 57 8 32Z')+circle(32,32,8)
star=path('M32 9 37 26 55 32 37 38 32 55 26 38 9 32 26 26Z', '#293b3c')
helmet=path('M16 47V28C16 9 46 7 48 27V44L38 51V34H28V50L20 46 M17 29H47 M29 35V51', '#303a34')+path('M22 14Q32 2 44 10 M24 17Q32 9 40 14','none',GOLD)
bag=path('M14 22H50L46 54H18Z', '#273632')+path('M23 22V16C23 5 41 5 41 16V22 M16 34H48 M28 34V43H36V34')
book=path('M32 17Q18 10 9 15V49Q23 45 32 51Q41 45 55 49V15Q45 10 32 17Z', '#223432')+path('M32 17V50 M16 24 25 25 M16 32 25 33 M39 25 48 24 M39 33 48 32')
scroll=path('M18 10H48Q58 16 48 23H41V47Q42 57 31 55H14Q6 51 13 44H22V17Q22 10 18 10Z', '#2e352e')+path('M29 24H38 M29 32H37 M23 44V49 M41 23V16')
mapglyph=path('M9 16 24 11 40 17 55 11V48L40 54 24 48 9 53Z', '#223432')+path('M24 11V48 M40 17V54 M15 36 20 29 31 35 47 23','none',IVORY)
gear=path('M27 9H37L39 17 46 21 54 20 58 29 52 35 50 43 51 50 41 55 34 49 27 49 19 53 12 46 16 39 14 31 8 26 12 17 21 18Z')+circle(33,32,9)
lock=path('M17 28H47V53H17Z', '#263330')+path('M22 28V19C22 5 42 5 42 19V28 M32 38V45')
check=path('M13 33 26 46 53 17',width=4)
close=path('M18 18 46 46 M46 18 18 46',width=3.5)
arrow=path('M10 32H52 M36 16 52 32 36 48')
hourglass=path('M17 10H47 M17 54H47 M21 10C21 27 43 37 43 54 M43 10C43 27 21 37 21 54 M23 47H41')
coin=circle(32,32,22, '#34362b')+circle(32,32,16,stroke=GOLD,width=1.4)+path('M27 21 38 24 25 39 37 42')
skull=path('M19 44C2 24 16 9 32 10C50 9 62 27 45 44V53H19Z', '#29302b')+path('M25 44V53 M32 44V53 M39 44V53 M29 39 32 34 35 39')+circle(22,30,5,INK)+circle(42,30,5,INK)
laurel=path('M27 53C6 43 8 23 20 12 M37 53C58 43 56 23 44 12 M17 39 10 36 M16 29 10 25 M20 20 15 16 M47 39 54 36 M48 29 54 25 M44 20 49 16')
crown=path('M15 45 9 20 23 29 32 12 41 29 55 20 49 45Z', '#38382c')+path('M17 51H47')
feather=path('M15 53 46 13 M17 43C10 21 34 7 50 10C55 27 36 48 17 43Z', '#233b37')+path('M28 35 27 23 M34 28H45')
wave=path('M10 24Q19 15 28 24T46 24T57 24 M7 36Q16 27 25 36T43 36T56 36 M12 48Q21 39 30 48T48 48')
snow=path('M32 8V56 M11 20 53 44 M11 44 53 20 M26 13 32 19 38 13 M26 51 32 45 38 51 M13 28 20 26 20 18 M44 46 44 38 52 36 M13 36 20 38 20 46 M44 18 44 26 52 28')
cross=path('M26 13H38V26H51V38H38V51H26V38H13V26H26Z', '#28483e')
drop=path('M32 10C28 20 15 31 15 40A17 17 0 0 0 49 40C49 30 36 20 32 10Z', '#4e3030')+path('M23 38Q20 46 29 48','none',IVORY)
prism=path('M32 8 52 28 44 48 32 56 12 33Z', '#284247')+path('M32 8 27 31 44 48 M12 33 27 31 32 56 M27 31 52 28','none',GOLD)
chest=path('M10 29Q10 13 24 13H40Q54 13 54 29V51H10Z', '#37352b')+path('M10 29H54 M28 29V39H36V29 M19 16V27 M45 16V27')
portal=path('M12 54V28A20 20 0 0 1 52 28V54 M21 54V29A11 11 0 0 1 43 29V54 M8 54H56','none',GOLD)+path('M28 39 33 44 40 34')
pillar=path('M12 17 32 7 52 17Z M13 22H51 M17 23V49 M26 23V49 M38 23V49 M47 23V49 M12 54H52')
question=path('M23 21C23 7 46 8 44 23C43 30 32 30 32 39')+circle(32,49,2,IVORY)
move=path('M13 49 49 13 M29 13H49V33 M11 33 20 24 M30 53 39 44')
sliders=path('M12 17H52 M12 32H52 M12 47H52')+circle(25,17,4,INK)+circle(41,32,4,INK)+circle(22,47,4,INK)
fist=path('M17 30V22Q17 16 23 19V15Q25 10 30 14Q35 8 39 15Q47 12 47 21V36L39 51H23L14 36Q8 22 17 30Z', '#34382e')+path('M23 20V29 M31 16V28 M39 18V29 M17 30 30 33 31 40')
# Family-specific narratives occupy the large tile; no ornament surrounding small UI glyphs.
SPELLS={
'peleid_strike':(spear+path('M37 9 39 4 M54 31 59 32 M56 13 61 9'),GOLD),
'fulminant_dash':(group(boot,'translate(5 0)')+path('M5 21H18 M3 31H16 M6 42H14'),TEAL),
'pelion_shot':(bow,TEAL), 'bronze_guard':(shield,GOLD),
'crochet':(path('M16 51 37 30Q56 10 46 9Q38 8 36 18 M14 19H29 M21 12 14 19 21 26')+path('M16 44 23 51'),GOLD),
'fauchage':(spear+path('M9 30Q19 7 42 10 M9 30 8 17 M9 30 22 29'),GOLD),
'entaille':(sword+group(drop,'translate(35 32) scale(.38)'),RED),
'moisson':(path('M17 54 37 13Q49 13 55 27Q41 19 30 26 M31 14Q22 15 17 23')+group(drop,'translate(10 23) scale(.5)'),RED),
'rupture':(path('M8 45 48 17 M35 14 50 15 46 30 M42 42 47 35 43 30 M52 39 57 32 53 27'),TEAL),
'marque':(circle(32,32,17)+circle(32,32,5)+path('M32 6V19 M32 45V58 M6 32H19 M45 32H58'),TEAL),
'feinte':(group(boot,'translate(12 0) scale(.85)')+path('M11 48V24H24 M17 17 24 24 17 31'),TEAL),
'contretemps':(group(sword,'translate(10 3) scale(.8)')+path('M18 46C-1 31 9 8 28 9 M19 4 28 9 20 16'),TEAL),
'heurt':(group(shield,'translate(-4 2) scale(.9)')+path('M45 17 54 11 M49 31H60 M45 43 54 49'),GOLD),
'posture':(group(shield,'translate(5 0) scale(.85)')+path('M9 54H55 M15 48 15 54 M49 48 49 54'),GOLD),
'souffle':(group(heart,'translate(9 5) scale(.73)')+path('M7 40Q15 31 23 40 M12 49Q20 40 28 49'),GREEN),
'marche':(group(boot,'translate(-5 0) scale(.88)')+group(cross,'translate(31 28) scale(.43)'),GREEN),
'braise':(flame,RED), 'givre':(snow,BLUE), 'foudre':(bolt,BLUE),
'serment_rempart':(shield+group(drop,'translate(20 23) scale(.38)'),TEAL),
'serment_brasier':(flame+path('M8 50Q32 66 56 50 M8 50 9 42 M56 50 55 42'),RED),
'exp_tempest':(path('M13 32A20 20 0 1 1 32 52 M13 32 7 22 M13 32 24 26 M25 51 32 52 29 44')+path('M22 36 42 20 M32 20H42V30'),TEAL),
}
GEAR={
'levier':(path('M15 53 45 17 48 9 55 15 50 22 20 57 M36 25 44 31'),GOLD),
'lame_sang':(sword+group(drop,'translate(36 32) scale(.35)'),RED),
'javeline':(spear+path('M11 42 18 49 M30 18 40 28'),TEAL),
'xiphos_danse':(path('M23 43 40 12 48 8 49 21 29 47Z','#364438')+path('M17 40 34 50 M22 47 17 56 M13 52 21 58'),TEAL),
'masse_airain':(path('M17 53 34 32 M23 19 38 9 53 23 42 40 30 34Z','#343b35')+path('M31 15 47 30 M23 24 39 38 M15 48 22 55'),GOLD),
'fer_braise':(group(spear,'translate(-4 4) scale(.9)')+group(flame,'translate(27 2) scale(.5)'),RED),
'cuirasse':(path('M21 11 26 17H38L43 11 52 22 46 31 48 51Q32 58 16 51L18 31 12 22Z','#2f413b')+path('M32 20V49 M22 30 32 34 42 30 M22 43 32 46 42 43'),GOLD),
'lin_survivant':(path('M22 11Q32 20 42 11L54 24 46 31 43 26 46 53H18L21 26 17 31 10 24Z','#344039')+path('M22 36H43 M26 37 24 49 M35 37 38 50'),GREEN),
'sandales':(boot+path('M21 14 35 21 M21 21 35 28 M21 28 34 35'),TEAL),
'sceau_chasse':(circle(32,36,17,'#343b31')+path('M24 19 22 9H42L40 19 M22 38 32 26 42 38 32 46Z'),GOLD),
'prisme':(prism,TEAL),
'agrafe':(circle(32,32,21,'#333b33')+circle(32,32,13)+path('M23 17 41 48 M19 15 27 14 M37 49 44 50'),GOLD),
}
STATS={'force':fist,'attack_power':sword,'max_hp':heart,'initiative':bolt,'max_mp':boot,'esquive':feather,'armure':shield,'resist_magique':prism,'heal_budget':cross}
NAV={'equipment':bag,'map':mapglyph,'tree':book,'journal':scroll,'halt':flame,'home':portal,'close':close,'settings':gear,'save':path('M13 10H44L53 19V54H11V10Z')+path('M21 10V26H43V10 M20 54V37H44V54 M35 14V21'),'continue':arrow,'lock':lock,'check':check,'attributes':sliders,'search':circle(27,27,16)+path('M39 39 55 55'),'sort':path('M20 12V53 M11 43 20 53 29 43 M34 17H55 M34 29H50 M34 41H44'),'back':group(arrow,'translate(64 0) scale(-1 1)')}
RES={'oboles':coin,'destiny':star,'health':heart,'level':path('M14 32 32 13 50 32 M22 31V51H42V31'),'victory':laurel+group(star,'translate(14 14) scale(.56)'),'defeat':skull,'action_points':bolt,'movement_points':boot}
EMBLEMS={'colere':flame+group(sword,'translate(17 18) scale(.5)'),'chiron':bow+group(star,'translate(20 10) scale(.35)'),'eaque':shield+group(laurel,'translate(2 5) scale(.92)'),'elements':group(flame,'translate(17 0) scale(.75)')+path('M8 47H53 M10 54H49'),'serment':path('M14 20 27 11 38 23 50 18 55 30 39 47 28 43 15 34 8 31Z')+path('M22 22 35 35 43 29 M28 43 36 35'),'achilles':helmet}
ROUTE={'normal':sword,'elite':sword+group(star,'translate(3 1) scale(.4)'),'boss':skull+crown.replace('currentColor',GOLD),'hub':portal,'merchant':bag+group(coin,'translate(29 31) scale(.36)'),'sanctuary':pillar,'lore':scroll,'event':star,'cache':chest,'unknown':question,'hidden':eye+path('M9 55 55 9'),'current':path('M32 8 50 31 32 55 14 31Z','#285252')+circle(32,31,5,IVORY)}
STATES={'cooldown':hourglass,'locked':lock,'unavailable':circle(32,32,23)+path('M16 16 48 48'),'resolving':path('M13 26A20 20 0 0 1 50 20 M50 20V9 M50 20H39 M51 38A20 20 0 0 1 14 44 M14 44V55 M14 44H25'),'target_valid':circle(32,32,23)+group(check,'translate(8 8) scale(.75)'),'target_invalid':circle(32,32,23)+group(close,'translate(6 6) scale(.8)')}
EFFECTS={'upgrade':RES['level'],'hidden':question,'damage':sword,'range':bow,'push':arrow,'movement':boot,'bleed':drop,'vulnerability':path('M15 12 30 18 26 30 36 36 31 55 M36 11 51 17 49 36 38 51'), 'collision':path('M10 32H37 M28 21 39 32 28 43 M49 12V52'),'duration':hourglass,'pierce':spear,'terrain':path('M7 42 22 20 33 34 44 14 57 43 M11 51H53'),'heal':cross,'defense':shield,'state_check':check,'state_excluded':close,'state_pending':hourglass,'poison':path('M23 9H41 M26 9V23L13 45Q9 54 19 54H45Q55 54 51 45L38 23V9 M20 38H44')+circle(28,45,2)+circle(37,40,2)}
manifest=[]
def emit(folder,name,motif,accent=IVORY,tile=False,rank=''):
    size=256 if tile else 64
    defs=f'<defs><linearGradient id="field" x2="0.8" y2="1"><stop stop-color="#293936"/><stop offset="1" stop-color="#101412"/></linearGradient><linearGradient id="metal" x2="0.8" y2="1"><stop stop-color="#f1e9d9"/><stop offset="0.5" stop-color="{accent}"/><stop offset="1" stop-color="#bba57a"/></linearGradient></defs>'
    bg=''
    if tile:
        bg=f'<rect x="1" y="1" width="62" height="62" rx="5" fill="url(#field)"/><path d="M10 2H54 M2 10V54 M10 62H54 M62 10V54" stroke="#786b50" stroke-width=".7" fill="none"/><path d="M9 59H25 M39 59H55" stroke="{accent}" stroke-width=".8" opacity=".55"/>'
        motif=group(motif,'translate(4 3) scale(.87)')
    badge=''
    if rank:
        shapes={'mutation':'M45 54 49 48 53 54 49 60Z','legend':'M41 53 45 49 49 53 45 57Z M50 53 54 49 58 53 54 57Z','signature':'M50 47 52 51 57 52 53 55 54 60 50 57 46 60 47 55 43 52 48 51Z'}
        badge=f'<circle cx="50" cy="54" r="10" fill="{INK}"/>'+path(shapes[rank],accent,accent,1)
    color='url(#metal)' if tile else accent
    svg=f'<svg xmlns="http://www.w3.org/2000/svg" width="{size}" height="{size}" viewBox="0 0 64 64">{defs}{bg}<g color="{accent}" stroke-linecap="round" stroke-linejoin="round">{motif.replace("currentColor",color)}{badge}</g></svg>\n'
    target=ROOT/folder/(name+'.svg'); target.parent.mkdir(parents=True,exist_ok=True);target.write_text(svg,encoding='utf-8')
    manifest.append({'group':folder,'id':name,'path':str(target).replace('\\','/'),'size':size,'accent':accent,'rank':rank})
for name,(motif,accent) in SPELLS.items(): emit('spells',name,motif,accent,True)
source=Path('core/expedition/catabase_painted_icon_catalog.gd').read_text(encoding='utf-8')
for family,members in re.findall(r'"([a-z_]+)": \[([^\]]+)\]',source.split('const ITEM_IDS')[0]):
    for ident in re.findall(r'"([a-z_]+)"',members):
        if ident=='exp_tempest':continue
        rank=next((r for r in ['mutation','legend','signature'] if ident.endswith('_'+r)),'')
        if rank:emit('spells',ident,*SPELLS[family],True,rank)
for name,(motif,accent) in GEAR.items():emit('equipment','catabase_'+name,motif,accent,True)
for folder,motifs in [('stats',STATS),('nav',NAV),('resources',RES),('emblems',EMBLEMS),('route',ROUTE),('states',STATES),('effects',EFFECTS)]:
    for name,motif in motifs.items():
        accent=RED if name in ['defeat','bleed','poison','target_invalid','unavailable'] else GREEN if name in ['heal','heal_budget','target_valid'] else GOLD if folder in ['emblems','route'] or name in ['oboles','destiny','victory'] else IVORY
        emit(folder,name,motif,accent)
emit('nav','move',move)
# The consultative champion grimoire shares the same language, including all 36 masteries.
MASTERY_MOTIFS = {
'wrath': [flame, sword, bolt, sword+group(skull,'translate(31 33) scale(.35)'), drop, boot+group(laurel,'translate(25 22) scale(.5)'), EFFECTS['collision'], sword+group(flame,'translate(26 24) scale(.5)'), flame+group(crown,'translate(16 2) scale(.5)')],
'chiron': [eye, bow+path('M10 54H54'), group(bow,'translate(6 0) scale(.85)')+circle(16,32,7), path('M10 45H35V16 M25 24 35 14 45 24'), bow+path('M52 13V51'), spear, bow+group(boot,'translate(23 24) scale(.5)'), path('M8 45 49 13 M8 53 55 18 M41 12H51V23'), group(bow,'translate(-7 0)')+path('M37 15H55 M47 9 55 15 47 21')],
'aeacus': [shield, shield+path('M7 16V47'), shield+path('M8 54H56'), shield+group(sword,'translate(26 24) scale(.5)'), shield+path('M48 11 58 21 M51 8 51 17 59 17'), EFFECTS['vulnerability'], shield+group(boot,'translate(28 28) scale(.5)'), shield+path('M9 9H24 M9 9V24 M9 9 22 22'), group(shield,'translate(-5 9) scale(.75)')+group(shield,'translate(23 1) scale(.75)')],
'heroic': [EMBLEMS['colere'], EMBLEMS['chiron'], EMBLEMS['eaque'], eye+group(sword,'translate(27 28) scale(.48)'), shield+group(flame,'translate(20 20) scale(.55)'), bow+group(shield,'translate(27 25) scale(.5)'), flame+laurel, bow+group(star,'translate(24 22) scale(.6)'), helmet+laurel],
}
mastery_source = Path('ui/progression/champion/mastery_atlas_art.gd').read_text(encoding='utf-8')
for ident,family,x,y in re.findall(r'&"(achilles_[a-z_]+)": \[\s*"([a-z]+)",\s*(\d+),\s*(\d+)',mastery_source):
    accent={'wrath':RED,'chiron':TEAL,'aeacus':GOLD,'heroic':GOLD}[family]
    emit('masteries',ident,MASTERY_MOTIFS[family][int(y)*3+int(x)],accent,True)
for name,motif in {'vitality':heart,'power':fist,'resolve':shield,'wisdom':book}.items():emit('attributes',name,motif,GOLD)
# Items from the canonical run economy, including both starting consumables.
RUN_ITEMS = {
'xiphos_of_peleus':sword,
'line_breaker_kopis':path('M17 54 43 16Q51 8 54 9L49 25 23 48Z','#334038')+path('M15 44 29 52'),
'pelion_bow':bow,
'scyros_short_bow':group(bow,'translate(6 6) scale(.8)')+path('M16 17 21 23 M16 47 21 41'),
'aeacus_shield_blade':shield+group(sword,'translate(24 19) scale(.6)'),
'phthia_cuirass':GEAR['cuirasse'][0],
'myrmidon_linothorax':GEAR['lin_survivant'][0]+path('M25 20 32 28 39 20'),
'duelist_breastplate':GEAR['cuirasse'][0]+path('M21 20 42 48'),
'hunter_mantle':path('M24 10Q32 17 40 10L51 53 32 47 13 53Z','#2b3d35')+path('M24 10 20 40 M40 10 44 40'),
'wave_cuirass':GEAR['cuirasse'][0]+group(wave,'translate(16 24) scale(.5)'),
'peleus_seal':GEAR['sceau_chasse'][0],
'phthia_knot':path('M32 32C3 4 2 53 32 32C62 5 62 60 32 32 M25 36 17 54 M38 35 47 54'),
'chiron_ferret':path('M25 9H39L43 42 32 55 21 42Z','#334337')+path('M25 19H39 M25 27H39 M25 35H39'),
'patroclus_brooch':GEAR['agrafe'][0]+group(heart,'translate(19 18) scale(.4)'),
'myrmidon_crest':helmet+path('M12 17Q32 -1 52 17'),
'patroclus_ashes':path('M20 16H44 M23 10H41 M24 16V23Q6 40 23 53H41Q58 40 40 23V16Z','#35423b')+group(flame,'translate(20 26) scale(.37)'),
'hephaestus_nail':path('M20 13 29 8 45 18 38 26Z','#444233')+path('M30 22 15 55 22 51 37 25'),
'centaur_step':boot+group(feather,'translate(25 2) scale(.55)'),
'athena_mirror':circle(32,25,17,'#264944')+path('M27 43V55H37V43 M24 20 35 13 M29 31 43 17'),
'pelion_shard':prism+path('M7 13 13 16 M48 53 56 55'),
'thetis_anchor':circle(32,14,6)+path('M32 20V51 M18 28H46 M11 36Q13 50 32 55Q51 50 53 36 M11 36 9 47 M11 36 21 39 M53 36 55 47 M53 36 43 39'),
'thetis_bracelet':circle(32,32,21)+circle(32,32,15)+group(wave,'translate(18 21) scale(.45)'),
'thetis_heel':boot+group(wave,'translate(25 32) scale(.45)'),
'fates_thread':path('M14 17H50 M14 49H50 M21 17V49 M43 17V49 M22 20 42 26 22 32 42 38 22 44 M44 42Q60 42 55 56'),
}
for name,motif in RUN_ITEMS.items():emit('equipment','odyssey_'+name,motif,TEAL if name.startswith(('thetis','pelion','chiron')) else GOLD,True)
emit('equipment','minor_healing_potion',path('M24 8H40V19L47 30Q60 55 32 56Q4 55 17 30L24 19Z','#27483a')+path('M22 33H42 M24 13H40')+group(cross,'translate(22 29) scale(.3)'),GREEN,True)
emit('equipment','minor_action_scroll',scroll+group(bolt,'translate(21 23) scale(.38)'),TEAL,True)
(ROOT/'manifest.json').write_text(json.dumps({'style':'Catabase · glyphes ivoire / bronze / sarcelle','provenance':'Original vector artwork authored in tools/ui_icons/build_icons.py; no third-party assets.','icons':manifest},ensure_ascii=False,indent=2),encoding='utf-8')
print(f'{len(manifest)} original SVG icons generated')
