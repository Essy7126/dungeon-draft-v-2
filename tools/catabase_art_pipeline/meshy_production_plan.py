"""Build the bounded Catabase UI production plan; no network or credentials."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
manifest = json.loads((ROOT / 'art/source/catabase/painted/manifest.json').read_text(encoding='utf-8'))
REF = manifest['references'][0]['url']
LIBRARY = manifest['references'][1]['url']
STYLE = ('Match the reference image painting and material finish: premium hand-painted fantasy RPG art, generous sculpted forms, warm aged bronze, dark petrol stone, restrained turquoise, amber highlights from upper left, soft colored outlines and graduated shadows. Greek mythic underworld Catabase. Strong readable silhouettes and calm broad forms. No modern objects, no text, no lettering, no digits, no labels, no watermark. ')
ROOT_EXPORT = 'assets/catabase/painted/'
jobs = []


def sheet(job_id, group, cols, rows, entries, ratio='1:1', matte=False, treatment='icons'):
    descriptions = '; '.join(f'cell {i+1}: {description}' for i, (_, description) in enumerate(entries))
    background = ('Every pixel outside the isolated assets must be pure flat vivid magenta #FF00FF, as a chroma matte. No magenta anywhere inside an asset. ' if matte else 'Every pixel of the empty background must be uniform midnight blue #141D2E. No paper, no scene, no background texture or cast shadows beyond each object. ')
    if treatment == 'icons':
        shape = 'Each object fills about 68 percent of its cell, centered, equally scaled, generous empty margins, no overlap between cells. Three-quarter object view, front-readable glyphs where appropriate. '
    elif treatment == 'buttons':
        shape = 'Each cell contains one wide horizontal rectangular UI plate, width 84 percent of the cell and height 40 percent of the cell. Exact front orthographic view, completely straight parallel edges, no perspective, rounded beveled corners, no drop shadows. All plates have identical external dimensions, corner geometry and edge thickness. Their centers are empty dark petrol surfaces suitable for a text label added by the game. Edge decoration must be restrained, keeping the central 75 percent empty and near uniform. '
    else:
        shape = 'Each cell contains one front-facing square UI panel, occupying 82 percent of the cell width and height. Exact orthographic front view, straight parallel edges, no perspective, restrained beveled bronze corners. The central 80 percent is a near-uniform dark petrol blank surface with no objects, ornaments or text. Make the edges straight and uninterrupted at their midpoints for nine-slice stretching. No ornament protrudes outside its own rectangle. '
    prompt = STYLE + f'Create one production atlas of EXACTLY {len(entries)} separate {treatment} in a regular {cols} columns by {rows} rows grid. Read order is left to right, then top to bottom. ' + shape + background + 'No visible grid lines or frames around atlas cells. DO NOT repeat the reference objects; paint the requested new subjects. Exact contents: ' + descriptions + '.'
    jobs.append({'id': job_id, 'kind': 'sheet', 'cols': cols, 'rows': rows, 'matte': 'magenta' if matte else 'navy', 'treatment': treatment, 'entries': [{'id': k, 'path': ROOT_EXPORT+group+'/'+k+'.png', 'description': d} for k,d in entries], 'endpoint':'/openapi/v1/image-to-image', 'payload':{'ai_model':'nano-banana-pro','reference_image_urls':[REF],'prompt':prompt,'aspect_ratio':ratio}, 'estimated_credits':9})


sheet('spells_remaining','icons',3,2,[
 ('braise','a bronze arrowhead with a compact curling orange flame and glowing embers'),
 ('givre','two chunky icy blue crystal shackles connected by one short frosted chain'),
 ('foudre','a strong angular cyan lightning bolt striking a small bronze spearhead'),
 ('serment_rempart','a thick bronze shield with a tiny sealed jade oath gem and a single protective arch'),
 ('serment_brasier','a bronze oath seal enclosing a luminous ruby flame, compact circular silhouette'),
 ('exp_tempest','a powerful circular ivory and turquoise whirlwind around three bronze spearheads pointing tangentially, visibly circular area attack')], '4:3')
sheet('equipment_weapons','equipment',3,2,[
 ('catabase_levier','a hefty Myrmidon bronze spear with hooked levering tip and leather grip'),
 ('catabase_lame_sang','a short sacrificial bronze dagger with ruby edge fissure and dark red wrapped grip'),
 ('catabase_javeline','an elegant long bronze throwing javelin with ivory fletching and a focused teal sight gem'),
 ('catabase_xiphos_danse','a graceful short Greek xiphos sword with leaf-shaped blade and teal cloth grip'),
 ('catabase_masse_airain','a heavy square-headed ancient bronze war mace with thick geometric flanges'),
 ('catabase_fer_braise','a forged dark bronze spearhead with orange-hot rune-free furnace core')], '4:3')
sheet('equipment_armor','equipment',3,2,[
 ('catabase_cuirasse','a handsome ancient Greek bronze muscle cuirass with teal shoulder insets'),
 ('catabase_lin_survivant','a carefully folded ivory linen tunic with worn leather straps and restrained jade stitching'),
 ('catabase_sandales','a pair of wingless ancient Greek brown leather sandals with small bronze buckles'),
 ('catabase_sceau_chasse','a gold and bronze hunter seal with a carved eye and deep ruby pupil'),
 ('catabase_prisme','a triangular turquoise and icy blue crystal prism seated in an elegant bronze cradle'),
 ('catabase_agrafe','a circular aged bronze oath brooch clasp with interlocking arms and a small jade shield gem')], '4:3')
sheet('stats','tree/stats',3,3,[
 ('force','a compact muscular bronze gauntlet clenched into a fist'),
 ('attack_power','two crossing bronze spearheads with one ivory impact star'),
 ('max_hp','a plump polished ruby heart held in a restrained bronze clasp'),
 ('initiative','a small bronze hourglass with bright turquoise sand and one winglike speed sweep'),
 ('max_mp','one ancient Greek sandal footprint with a strong turquoise forward arrow-shaped trail'),
 ('esquive','a small silver curved arrow elegantly avoiding a single bronze arrowhead'),
 ('armure','a solid broad bronze breastplate with thick beveled surfaces'),
 ('resist_magique','a violet crystal protected by a simple bronze circular ward'),
 ('heal_budget','a small golden laurel cup containing three luminous jade drops')])
sheet('emblems','tree/emblems',3,2,[
 ('colere','a bold bronze round emblem showing a roaring lion face and a short ruby flame crest'),
 ('chiron','a refined bronze laurel medallion with a curved bow and turquoise arrow'),
 ('eaque','a heavy bronze medallion with a strong classical shield and ivory central boss'),
 ('elements','a bronze ring embracing three clearly separated orange flame, blue ice shard and cyan lightning symbols'),
 ('serment','a bronze ring embracing two clasped armored hands above a small jade oath gem'),
 ('achilles','an ancient Greek heroic profile helmet medallion in warm bronze with an ivory crest')], '4:3')
sheet('resources','ui/resources',3,2,[
 ('oboles','three chunky ancient gold obol coins with abstract relief, no digits or letters'),
 ('destiny','a luminous turquoise destiny crystal inside a small open gold laurel'),
 ('health','one luminous ruby heart with two restrained golden wings of light'),
 ('level','a golden starburst medallion framed by a compact laurel crown'),
 ('victory','a triumphant golden laurel wreath surrounding a raised ivory spearhead'),
 ('defeat','a cracked bronze helmet with a dim ruby fissure resting on a single dark stone')], '4:3')
sheet('route','route',4,3,[
 ('normal','two crossed short bronze swords in a compact round icon'),
 ('elite','a bronze hornless warrior helm above two crossed spears and one ruby star'),
 ('boss','a large imposing dark bronze crowned guardian helm with cyan eye slits'),
 ('hub','a low circular bronze brazier with warm amber campfire'),
 ('merchant','a gold balance scale and one small leather coin pouch'),
 ('sanctuary','a small ancient Greek stone altar holding a jade offering bowl'),
 ('lore','an open ivory book and a small turquoise crystal bookmark'),
 ('event','a bronze theatrical mask with a tiny amber spark'),
 ('cache','a small closed honey wood treasure chest with bronze fittings'),
 ('unknown','a sealed dark bronze medallion with an abstract swirling mist, no question mark or letters'),
 ('hidden','a small partly open stone doorway behind a curling teal mist veil'),
 ('current','a bright ivory downward-pointing spearhead surrounded by a compact golden laurel')], '4:3')
sheet('navigation','ui/nav',4,3,[
 ('map','a folded ivory parchment route map with a simple winding turquoise path'),
 ('tree','a stylized golden branching laurel with three large turquoise buds'),
 ('equipment','a compact ancient Greek bronze helmet and short sword'),
 ('halt','a small bronze brazier with a warm sheltered amber flame'),
 ('journal','a handsome closed leather journal with bronze clasp and ivory page edges'),
 ('home','a simple Greek temple pediment on two short bronze columns'),
 ('close','a clear simple bronze X cross made of two short beveled bars'),
 ('settings','a chunky simple bronze cog with six teeth and turquoise hub'),
 ('save','a bronze seal stamp beside one folded ivory scroll'),
 ('continue','a clear thick right-pointing bronze chevron with warm ivory edge'),
 ('lock','a small closed antique bronze padlock with a round keyhole'),
 ('check','a clear thick jade check mark with restrained bronze edging')], '4:3')
sheet('buttons','ui',2,3,[
 ('button_normal','secondary button, aged bronze thin rim and near-uniform dark petrol center'),
 ('button_primary','primary action button, warmer polished gold rim, dark bronze center, small amber corner highlights'),
 ('button_selected','selected button, aged bronze rim with restrained turquoise inlay, dark petrol center'),
 ('button_disabled','disabled button, muted worn bronze rim, subdued graphite blue center'),
 ('tab_normal','navigation tab, thin bronze edges and a shallow dark petrol center'),
 ('tab_selected','selected navigation tab, small jade edge accents and a narrow warm golden bottom edge, dark petrol center')], matte=True,treatment='buttons')
sheet('panels','ui',2,2,[
 ('panel','main window panel, dark petrol stone center, restrained aged bronze rectangular border and small carved Greek corner details'),
 ('card','compact content card, thin aged brass rectangular rim, clean dark blue-black stone center'),
 ('tooltip','quiet tooltip panel, very thin warm bronze rim with clipped corners, near-black petrol center'),
 ('banner','title banner panel, refined aged bronze top and bottom rails, tiny laurel corner motifs, empty dark petrol center')], matte=True,treatment='panels')
sheet('frames','ui',2,2,[
 ('slot_normal','square inventory slot frame, thin warm bronze bevel and dark petrol center'),
 ('slot_selected','same square inventory slot frame with small turquoise active edge glints, dark petrol center'),
 ('slot_locked','same square inventory slot frame in desaturated aged bronze, dark graphite center, no lock object'),
 ('portrait_frame','square heroic portrait frame with handsome bronze corner laurel ornaments and dark petrol center')], matte=True,treatment='frames')


def background(job_id, prompt, ratio, reference):
    jobs.append({'id':job_id,'kind':'background','entries':[{'id':job_id,'path':ROOT_EXPORT+'ui/'+job_id+'.png'}], 'endpoint':'/openapi/v1/image-to-image', 'payload':{'ai_model':'nano-banana-pro','reference_image_urls':[reference],'prompt':STYLE+prompt,'aspect_ratio':ratio},'estimated_credits':9})


background('background','Paint a full-frame subtle game-menu background material. Very dark petrol blue slate stone, broad smooth low-contrast areas, extremely restrained mottling. Sparse ancient Greek bronze engraving and olive traces only at outer corners. Center 85 percent must remain quiet and nearly uniform for readable interface panels layered above. No scene, no objects, no glowing focal points, no border, no perspective, no vignette to white, no text. Edge-to-edge dark material.', '16:9', LIBRARY)
background('tree_fresco','Paint a full-frame very dark petrol ancient Greek underworld wall fresco, designed behind a skill tree. Extremely subtle low-contrast relief of roots, laurel branches and a distant broken Greek portico, mostly around the outer 15 percent. Center is calm dark slate with barely visible stone texture. Muted bronze patina, no characters, no objects in the center, no bright lights, no UI, no drawn skill nodes or connectors. Decorative background only, broad quiet surfaces, edge-to-edge landscape.', '16:9', LIBRARY)
background('route_parchment','Create a flat full-frame aged warm ivory and honey parchment background for a vertical game route map. Fine genuine paper grain, soft warm edges, tiny very low-contrast Greek meander corner flourishes. Center 85 percent is clean unobstructed paper, without any lines, paths, icons, symbols or text. No rolled edges, no folds, no perspective, no desk, no isolated sheet floating on another background. Fill the entire portrait canvas with the paper material.', '3:4', REF)

sheet('movement_glyph_revision','tree/stats',1,1,[('max_mp','ONE isolated wingless ancient Greek sandal footprint made of aged bronze, with a short bright turquoise directional ribbon beneath it. Floating icon only. Absolutely no floor, no pavement, no square backing plate, no tile, no environment, no surface, no framed vignette. Large clean silhouette.')])
jobs[-1]['revision_of'] = 'stats:max_mp'
jobs[-1]['revision_reason'] = 'Initial glyph included a stone floor tile; replace with an isolated readable movement symbol.'
assert len(jobs) == 15
out = ROOT / 'meshy_output/catabase_ui_production_plan.json'
out.parent.mkdir(exist_ok=True)
out.write_text(json.dumps({'phase':'catabase_ui_v1','provider':'Meshy','model':'nano-banana-pro','estimated_credits':sum(j['estimated_credits'] for j in jobs),'jobs':jobs},ensure_ascii=False,indent=2),encoding='utf-8')
print(out)
print('Jobs:',len(jobs),'exports:',sum(len(j['entries']) for j in jobs),'estimated credits:',sum(j['estimated_credits'] for j in jobs))
