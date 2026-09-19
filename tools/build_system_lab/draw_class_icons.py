"""Original vector pictograms: class colour, action silhouette, cost pips."""
from pathlib import Path
import ast
root = Path(__file__).resolve().parents[2]
out = root / 'asset/ui/class_cards'
out.mkdir(parents=True, exist_ok=True)
text = (root / 'core/expedition/class_card_catalog.gd').read_text(encoding='utf-8')
rows = ast.literal_eval(text.split('const ROWS := ', 1)[1].split('\n\nstatic func', 1)[0])
colours = dict(zip(['assassin','gardien','arpenteur','thaumaturge'], ['#d69b97','#d5b866','#83c9a7','#a8a5da']))
glyph = {
'mark':'<circle cx="64" cy="62" r="22"/><circle cx="64" cy="62" r="8"/><path d="M64 27v10m0 50v10M29 62h10m50 0h10"/>',
'guard':'<path d="M34 37l30-9 30 9v25q-4 25-30 39Q38 87 34 62Z"/><path d="M64 41v43M47 60h34"/>',
'move':'<path d="M29 78h40V43m-14 9 14-14 14 14M32 59h15M26 46h15"/><circle cx="89" cy="88" r="8"/>',
'push':'<path d="M26 53h48V37l28 27-28 27V75H26M109 37v54"/>',
'pull':'<path d="M103 53H55V37L27 64l28 27V75h48M19 37v54"/>',
'slow':'<path d="M38 34l50 57M89 34 38 91M32 62h63M64 27v70"/><circle cx="64" cy="62" r="14"/>',
'bleed':'<path d="M64 27Q45 55 40 70a25 25 0 0 0 48 0Q83 55 64 27Z"/><path d="M52 70q-1 12 10 15"/>',
'weaken':'<path d="M39 90 59 62l-9-12 19-24 20 14-22 24 5 12-18 26M29 31l12 9M23 51h14"/>',
'cross':'<path d="M49 29h30v20h20v30H79v20H49V79H29V49h20Z"/><circle cx="64" cy="64" r="9"/>',
'fire':'<path d="M67 25q17 19 9 36l16-9q14 37-16 47H52q-29-13-10-42l9 11q-4-22 16-43Z"/><path d="M65 62q-18 27 0 31 19-5 0-31Z"/>',
'lightning':'<path d="M73 23 38 69h24l-8 36 38-52H66Z"/>',
'hit':'<path d="m35 88 13-16 8 8-13 16m7-24L87 29l11 3-4 12-39 37M36 65l27 27"/>',
'execute':'<path d="M32 32 95 95M94 30 34 93M27 80l19 19m35-19 18 19"/><circle cx="64" cy="63" r="14"/>',
'shadow':'<path d="M77 26a37 37 0 1 0 24 62Q55 105 77 26Z"/><circle cx="88" cy="55" r="5"/>',
}
aliases = {'frost':'slow','ice_area':'slow','burn':'fire','marked':'mark','moved':'hit','guarded':'guard','wounded':'hit','displaced':'push'}
def svg(body, colour, pips=0, secondary=''):
    dots = ''.join(f'<circle cx="{52+i*12}" cy="114" r="3" fill="{colour}"/>' for i in range(pips))
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128"><rect x="3" y="3" width="122" height="122" rx="22" fill="#161e24" stroke="{colour}" stroke-width="2"/><path d="M14 33V15h19m62 0h18v18M14 95v18h18m63 0h18V95" fill="none" stroke="{colour}" opacity=".4"/><g fill="none" stroke="{colour}" stroke-width="4" stroke-linecap="round" stroke-linejoin="round">{body}</g>{secondary}{dots}</svg>'
for r in rows:
    effect = aliases.get(r[7],r[7])
    # Range notch and school sigil distinguish families sharing a mechanic.
    index = [x[0] for x in rows if x[1] == r[1]].index(r[0])
    badge = f'<text x="112" y="27" text-anchor="end" font-family="sans-serif" font-size="13" fill="{colours[r[1]]}">{index+1}</text>'
    (out / (r[0]+'.svg')).write_text(svg(glyph.get(effect,glyph['hit']),colours[r[1]],r[3],badge))
for cls, effect in zip(colours,['hit','guard','move','fire']):
    (out / (cls+'.svg')).write_text(svg(glyph[effect],colours[cls]))
gear = [
    ['<path d="M39 92 89 29l9 8-48 62M29 81l24 19"/>','<path d="M42 98 77 49m-9-9 10-14 25 21-12 16Z"/>','<path d="M45 26q62 37 0 76l12-38ZM28 64h67m-9-8 10 8-10 8"/>','<path d="M43 102 77 40m-10-2 2-15 21 6-3 19Z"/>'],
    ['<path d="M43 29 29 49l15 13v37h40V62l15-13-14-20-21 12Z"/>'],
    ['<circle cx="64" cy="74" r="24"/><path d="m50 38 14-12 14 12-14 14Z"/>'],
    ['<path d="M29 87V57q0-35 35-35t35 35v30l-23-8V59H52v20Z"/>'],
    ['<path d="M25 47h78v32H25Z"/><rect x="49" y="40" width="30" height="47" rx="3"/><path d="M59 63h31"/>'],
    ['<path d="M43 27h33v40l25 13v17H29V81l14-14Z"/><path d="M49 41h22m-22 12h22M33 87h61"/>']]
for slot in range(6):
    for affinity, colour in enumerate(colours.values()):
        shape = gear[slot][affinity] if slot == 0 else gear[slot][0]
        badge=f'<circle cx="104" cy="104" r="{4+affinity}" fill="{colour}"/>'
        (out/f'gear_{slot}_{affinity}.svg').write_text(svg(shape,colour,secondary=badge))
print(f'{len(list(out.glob("*.svg")))} original vector assets')
