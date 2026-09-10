"""Deterministic black smoke particles, embedded in the Spine skeleton itself."""
import math
import numpy as np
from PIL import Image


def smoke_texture(size=128):
    y, x = np.mgrid[-1:1:complex(size), -1:1:complex(size)]
    radius = np.hypot(x, y)
    angle = np.arctan2(y, x)
    edge = .69+.07*np.sin(5*angle+.4)+.055*np.sin(9*angle)+.025*np.sin(17*angle-1)
    alpha = np.clip((edge-radius)/.15, 0, 1)
    # Faint internal variation, with no bright rim or coloured flash.
    shade = 6+4*np.sin(x*9+y*4)*np.cos(y*8-x*3)
    rgba = np.empty((size, size, 4), dtype=np.uint8)
    rgba[:, :, :3] = np.clip(shade[:, :, None], 2, 10)
    rgba[:, :, 3] = np.round(alpha*255)
    return Image.fromarray(rgba)


def add_black_burst(data, directory, torso_pivot):
    texture = smoke_texture()
    texture.save(directory/'images'/'vanish_smoke.png')
    atlas_path = directory/'sentinelle.png'
    previous = Image.open(atlas_path).convert('RGBA')
    atlas = Image.new('RGBA', (previous.width, previous.height+texture.height+4))
    atlas.paste(previous, (0, 0))
    atlas.paste(texture, (2, previous.height+2))
    atlas.save(atlas_path)
    text = (directory/'sentinelle.atlas').read_text(encoding='utf-8')
    text = text.replace(f'size: {previous.width}, {previous.height}', f'size: {atlas.width}, {atlas.height}')
    text += f'vanish_smoke\n  bounds: 2, {previous.height+2}, {texture.width}, {texture.height}\n'
    (directory/'sentinelle.atlas').write_text(text, encoding='utf-8')
    base_slots = list(data['slots'])
    center = [float(torso_pivot[0])-256, 320-float(torso_pivot[1])+44]
    data['bones'].append({'name': 'vanish_origin', 'parent': 'root', 'x': center[0], 'y': center[1]})
    death = data['animations']['death']
    slots = death.setdefault('slots', {})
    for slot in base_slots:
        slots[slot['name']] = {'rgba': [{'time': 0, 'color': 'ffffffff'}, {'time': .04, 'color': 'b3b5b8ff'},
                                      {'time': .10, 'color': '15181bdd'}, {'time': .16, 'color': '00000000'},
                                      {'time': .8, 'color': '00000000'}]}
    attachments = data['skins'][0]['attachments']
    # A dense core with smaller peripheral puffs and rapidly dispersing flecks.
    for i in range(17):
        name = f'vanish_puff_{i:02}'
        theta = i*math.tau/11+.31
        fleck = i >= 11
        distance = (70+(i%4)*13) if fleck else (18+(i%4)*13)
        start = .045+(i%3)*.009
        peak = .12+(i%3)*.015
        end = .46+(i%4)*.05
        scale = (.12+(i%3)*.025) if fleck else (.75+(i%4)*.17)
        dx, dy = math.cos(theta)*distance, math.sin(theta)*distance*.83
        data['bones'].append({'name': name, 'parent': 'vanish_origin', 'rotation': i*37})
        data['slots'].append({'name': name, 'bone': name, 'attachment': 'vanish_smoke', 'color': 'ffffff00'})
        attachments[name] = {'vanish_smoke': {'width': 128, 'height': 128}}
        death['bones'][name] = {
            'translate': [{'time': 0, 'x': 0, 'y': 0}, {'time': start, 'x': 0, 'y': 0},
                          {'time': peak, 'x': dx*.5, 'y': dy*.5}, {'time': end, 'x': dx, 'y': dy+12}],
            'scale': [{'time': 0, 'x': .01, 'y': .01}, {'time': start, 'x': .08, 'y': .08},
                      {'time': peak, 'x': scale, 'y': scale*(.8 if fleck else 1)},
                      {'time': end, 'x': scale*1.3, 'y': scale*1.1}],
            'rotate': [{'time': start, 'value': 0}, {'time': end, 'value': (-1 if i%2 else 1)*35}]}
        slots[name] = {'rgba': [{'time': 0, 'color': 'ffffff00'}, {'time': start, 'color': 'ffffff00'},
                                {'time': peak, 'color': 'ffffffff'}, {'time': peak+.09, 'color': 'ffffffcc'},
                                {'time': end, 'color': 'ffffff00'}, {'time': .8, 'color': 'ffffff00'}]}
    return {'type': 'black_particle_disappearance', 'particles': 17, 'body_hidden_at': .16,
            'fully_clear_at': .61, 'embedded_in_spine': True}
