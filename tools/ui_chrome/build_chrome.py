"""Original scalable chrome, inspired by reference screenshots; no game assets."""
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2] / 'assets/catabase/chrome'
ROOT.mkdir(parents=True, exist_ok=True)
def export(name, w, h, body, top='#211c18', bottom='#100f0e'):
    svg = f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}"><defs><linearGradient id="surface" x2="0" y2="1"><stop stop-color="{top}"/><stop offset="1" stop-color="{bottom}"/></linearGradient></defs>{body}</svg>'
    (ROOT / f'{name}.svg').write_text(svg, encoding='utf-8')
for kind in ('button', 'tab', 'slot'):
    for state in ('normal', 'hover', 'pressed', 'primary', 'selected', 'disabled', 'locked'):
        selected = state in ('primary', 'selected')
        muted = state in ('disabled', 'locked')
        top, bottom = ('#163a43', '#09212a') if selected else ('#29211b', '#14110f')
        if muted: top, bottom = '#181614', '#100f0e'
        if state == 'hover': top, bottom = '#3b3025', '#211b16'
        if state == 'pressed': top, bottom = '#09212a', '#102d34'
        border = '#dcc69a' if selected or state == 'hover' else '#40382d' if muted else '#8b714c'
        if kind == 'slot':
            export(f'{kind}_{state}', 80, 80, f'<rect x="1" y="1" width="78" height="78" rx="3" fill="url(#surface)" stroke="{border}"/><rect x="4" y="4" width="72" height="72" rx="1" fill="none" stroke="#b99a65" stroke-opacity=".12"/>', top, bottom)
        else:
            marker = '<path d="M80 2l3 3-3 3-3-3z" fill="#ecdcb6"/>' if kind == 'tab' and selected else ''
            export(f'{kind}_{state}', 160, 56, f'<path d="M11 2H149L158 12V44L149 54H11L2 44V12Z" fill="url(#surface)" stroke="{border}" stroke-width="1.5"/><path d="M13 5H147M13 51H147" fill="none" stroke="#dec9a0" stroke-opacity=".16"/>{marker}', top, bottom)
for kind in ('panel', 'card', 'tooltip', 'portrait_frame'):
    ornament = ''
    if kind in ('panel', 'portrait_frame'):
        for transform in ('', 'translate(320 0) scale(-1 1)', 'translate(0 160) scale(1 -1)', 'translate(320 160) scale(-1 -1)'):
            ornament += f'<path transform="{transform}" d="M7 24V12Q7 7 12 7H24M12 20V12H20" fill="none" stroke="#af8d55" stroke-opacity=".7"/>'
    export(kind, 320, 160, '<rect x="1" y="1" width="318" height="158" rx="7" fill="url(#surface)" stroke="#7d6545"/><rect x="4" y="4" width="312" height="152" rx="5" fill="none" stroke="#c4a575" stroke-opacity=".08"/>' + ornament)
export('banner', 320, 56, '<rect width="320" height="56" fill="url(#surface)"/><path d="M0 54H150M170 54H320" stroke="#876c46"/><path d="M160 50l4 4-4 2-4-2z" fill="#bfa273"/>')
print('Built 26 original SVG controls')
