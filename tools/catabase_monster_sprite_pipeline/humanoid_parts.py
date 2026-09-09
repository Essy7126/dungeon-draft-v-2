"""Hand-authored rigid pieces for the four independent humanoid paintings.

Coordinates are source pixels on the 512x384 canvas.  No source is mirrored.
The segmentation is exclusive; circular, palette-matched joint underpainting
overlaps the cuts so rotation exposes a painted joint instead of a hole.
"""
from __future__ import annotations

import argparse
import json
import math
from pathlib import Path
import sys
from collections import deque

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'output/monster-meshy-deps'))
from PIL import Image, ImageDraw, ImageFilter
import numpy as np

CANVAS = (512, 384)
PARENTS = {'torso': 'root', 'head': 'torso',
           'upper_arm_left': 'torso', 'arm_left': 'upper_arm_left',
           'upper_arm_right': 'torso', 'arm_right': 'upper_arm_right',
           'leg_left': 'torso', 'shin_left': 'leg_left',
           'leg_right': 'torso', 'shin_right': 'leg_right', 'cloth': 'torso',
           'hand_right': 'arm_right'}
JOINT_LIMITS = {
    'sentinelle_airain': {'torso': [-18, 18], 'head': [-16, 16],
        'upper_arm_right': [-42, 42], 'arm_right': [-58, 58],
        'upper_arm_left': [-32, 32], 'arm_left': [-42, 42],
        'leg_left': [-26, 26], 'leg_right': [-26, 26],
        'shin_left': [-44, 44], 'shin_right': [-44, 44], 'hand_right': [-135,135]},
    'rejeton_braise': {'torso': [-24, 24], 'head': [-22, 22],
        'upper_arm_left': [-52, 52], 'arm_left': [-68, 68],
        'upper_arm_right': [-52, 52], 'arm_right': [-68, 68],
        'leg_left': [-36, 36], 'leg_right': [-36, 36],
        'shin_left': [-58, 58], 'shin_right': [-58, 58], 'cloth': [-24, 24]},
}


def p(pivot, polygon, z, radius=10, end=None, fill=None):
    return dict(pivot=pivot, polygon=polygon, z=z, radius=radius, end=end, fill=fill)


# E/S are separately authored front paintings; N/W are separately authored
# back paintings.  Weapon-right and shield-left remain anatomical constants.
SPECS = {
 'sentinelle_airain': {
  'E': {
   'torso': p([198,209], [], 30, 17),
   'head': p([203,88], [[168,35],[241,29],[243,83],[218,105],[181,104],[165,83]], 55, 14),
   'upper_arm_right': p([155,96], [[103,48],[161,39],[178,48],[168,75],[159,112],[149,138],[140,155],[116,156],[104,140],[110,114],[104,97]], 40, 17),
   'arm_right': p([126,154], [[41,84],[67,93],[89,145],[104,158],[113,146],[130,146],[142,160],[139,181],[119,196],[126,225],[112,235],[92,214],[82,205],[76,187],[90,172],[76,153],[52,128]], 60, 14),
   'upper_arm_left': p([244,98], [[237,46],[264,47],[291,65],[305,101],[302,136],[285,164],[263,171],[247,151],[233,119],[224,105]], 42, 18),
   'arm_left': p([264,156], [[282,92],[317,94],[345,116],[357,147],[358,190],[346,228],[325,253],[295,259],[268,249],[249,224],[237,189],[241,151],[258,118]], 70, 17),
   'leg_right': p([169,210], [[149,188],[171,188],[192,201],[186,224],[176,244],[168,260],[145,258],[134,243],[135,217]], 12, 13),
   'shin_right': p([157,242], [[143,231],[175,234],[180,265],[172,283],[144,299],[109,294],[106,284],[132,271],[139,251]], 15, 12, [145,290]),
   'leg_left': p([231,211], [[221,194],[247,195],[259,217],[266,239],[261,265],[238,272],[222,246],[213,225]], 18, 14),
   'shin_left': p([249,249], [[236,237],[261,237],[273,276],[293,299],[298,322],[253,326],[243,311],[244,290],[238,271]], 22, 13, [272,315]),
  },
  'S': {
   'torso': p([193,211], [], 30, 17),
   'head': p([197,88], [[177,33],[217,34],[229,66],[219,90],[203,104],[175,99],[167,75]], 55, 13),
   'upper_arm_right': p([150,99], [[111,64],[139,45],[161,42],[173,58],[159,83],[153,115],[143,145],[135,160],[112,157],[105,138],[114,111]], 40, 16),
   'arm_right': p([125,161], [[58,86],[79,97],[96,142],[97,170],[114,153],[132,152],[143,168],[131,195],[116,210],[125,243],[111,251],[97,220],[82,202],[84,182],[76,157],[67,134]], 60, 13),
   'upper_arm_left': p([242,99], [[226,49],[251,49],[278,66],[293,104],[284,139],[263,166],[245,156],[229,133],[220,108]], 42, 18),
   'arm_left': p([259,157], [[270,93],[298,87],[324,103],[342,132],[347,170],[338,219],[319,250],[289,260],[261,249],[243,223],[234,190],[239,145],[252,117]], 70, 17),
   'leg_right': p([167,211], [[146,188],[171,191],[185,207],[181,229],[169,247],[157,261],[136,254],[132,234],[137,210]], 12, 13),
   'shin_right': p([151,242], [[135,231],[165,232],[176,262],[168,282],[142,299],[104,298],[102,287],[127,275],[136,255]], 15, 12, [140,291]),
   'leg_left': p([222,211], [[212,192],[239,194],[253,217],[258,238],[260,259],[238,272],[220,250],[208,224]], 18, 14),
   'shin_left': p([242,249], [[229,237],[256,239],[263,270],[281,296],[295,321],[251,326],[241,309],[239,284],[233,266]], 22, 13, [269,315]),
  },
  'N': {
   'torso': p([204,201], [], 30, 17),
   'head': p([225,86], [[202,44],[243,45],[253,71],[247,99],[199,99],[194,79]], 35, 13),
   'upper_arm_left': p([167,105], [[135,69],[162,55],[192,58],[181,86],[177,118],[164,147],[151,177],[127,173],[116,158],[125,130]], 40, 17),
   'arm_left': p([142,160], [[128,87],[146,102],[141,128],[139,141],[158,151],[158,174],[145,195],[144,215],[131,235],[111,242],[89,225],[80,198],[82,167],[92,128],[109,101]], 15, 14),
   'upper_arm_right': p([276,115], [[253,75],[279,68],[306,86],[322,110],[329,137],[310,150],[312,166],[315,181],[296,199],[279,190],[270,175],[265,151],[250,145],[240,125]], 45, 18),
   'arm_right': p([297,184], [[276,171],[296,168],[313,185],[326,199],[335,191],[342,165],[347,142],[376,99],[379,130],[367,169],[350,189],[343,212],[333,233],[321,234],[313,257],[308,278],[296,276],[302,251],[311,224],[290,219],[276,203]], 60, 14),
   'leg_left': p([180,202], [[163,183],[185,180],[203,196],[201,215],[190,239],[175,249],[156,240],[149,222]], 10, 13),
   'shin_left': p([172,237], [[155,225],[184,229],[191,250],[198,273],[187,291],[148,296],[143,282],[148,262],[151,245]], 14, 12, [165,286]),
   'leg_right': p([238,208], [[221,189],[245,187],[262,208],[274,231],[270,256],[250,267],[232,251],[225,230]], 20, 14),
   'shin_right': p([254,246], [[240,235],[271,237],[274,267],[282,284],[303,291],[299,309],[264,320],[234,320],[230,306],[237,278]], 23, 13, [258,312]),
  },
  'W': {
   'torso': p([292,203], [], 30, 17),
   'head': p([290,82], [[267,37],[305,40],[315,71],[315,96],[274,101],[263,83]], 35, 13),
   'upper_arm_left': p([240,109], [[220,68],[249,59],[269,73],[281,108],[272,138],[254,153],[247,177],[224,178],[211,163],[219,146],[200,134],[194,118]], 45, 18),
   'arm_left': p([228,169], [[172,126],[200,119],[223,134],[240,159],[251,191],[248,223],[232,253],[214,277],[190,278],[169,263],[153,233],[145,197],[149,163]], 70, 16),
   'upper_arm_right': p([350,104], [[325,47],[344,49],[371,67],[386,94],[389,122],[373,136],[381,160],[379,183],[359,191],[345,177],[342,153],[331,142],[335,115]], 40, 17),
   'arm_right': p([373,174], [[352,160],[374,151],[388,174],[402,189],[411,177],[415,149],[421,123],[453,90],[449,130],[434,163],[421,177],[413,205],[406,226],[392,233],[387,258],[377,279],[366,276],[371,253],[383,222],[369,215],[357,195]], 60, 14),
   'leg_left': p([264,207], [[248,187],[272,184],[288,201],[282,226],[274,252],[254,262],[236,248],[235,228]], 18, 14),
   'shin_left': p([256,246], [[239,234],[272,235],[274,266],[269,286],[275,306],[263,322],[232,322],[210,306],[208,290],[230,279]], 23, 13, [246,315]),
   'leg_right': p([323,201], [[308,183],[331,183],[345,203],[351,227],[349,247],[326,257],[311,240],[301,217]], 10, 13),
   'shin_right': p([336,238], [[319,230],[350,229],[352,251],[364,273],[370,291],[357,301],[330,302],[316,286],[319,267]], 14, 12, [348,291]),
  },
 },
 'rejeton_braise': {
  'E': {
   'torso': p([236,219], [], 30, 13),
   'head': p([254,167], [[207,85],[260,87],[284,99],[309,121],[310,148],[298,165],[286,187],[255,190],[235,181],[228,158],[202,145]], 55, 12),
   'upper_arm_left': p([273,179], [[263,170],[277,170],[290,188],[301,203],[297,217],[279,220],[269,205],[258,194]], 16, 10),
   'arm_left': p([293,207], [[279,201],[294,196],[310,205],[321,197],[330,190],[342,190],[348,201],[341,211],[351,211],[358,204],[365,213],[363,229],[351,241],[330,237],[309,225],[291,222]], 20, 10),
   'upper_arm_right': p([221,166], [[211,145],[226,142],[239,155],[240,176],[234,192],[242,208],[233,225],[212,225],[200,212],[196,187],[200,166]], 40, 13),
   'arm_right': p([223,215], [[211,204],[237,204],[245,217],[267,218],[295,218],[308,211],[320,212],[333,208],[338,216],[331,226],[341,226],[344,235],[331,244],[309,247],[275,241],[244,241],[218,234],[208,225]], 65, 12),
   'leg_right': p([209,234], [[195,219],[213,221],[226,238],[218,258],[206,270],[195,283],[172,278],[174,261],[184,246]], 14, 11),
   'shin_right': p([189,270], [[176,261],[202,267],[194,287],[184,303],[193,313],[188,324],[167,321],[148,320],[145,309],[161,295],[166,281]], 18, 10, [171,316]),
   'leg_left': p([270,241], [[251,228],[270,229],[287,243],[292,258],[285,274],[269,282],[253,272],[254,252]], 10, 11),
   'shin_left': p([269,272], [[255,262],[279,263],[278,286],[301,293],[316,300],[320,312],[311,319],[286,315],[258,304],[249,294]], 13, 10, [288,307]),
   'cloth': p([234,220], [[191,204],[212,218],[235,229],[257,231],[259,250],[246,260],[245,282],[233,274],[223,291],[215,275],[201,273],[205,253],[193,243],[185,229]], 25, 9),
  },
  'S': {
   'torso': p([276,219], [], 30, 13),
   'head': p([255,166], [[207,119],[218,108],[245,99],[291,86],[307,86],[304,114],[295,137],[280,146],[281,166],[265,185],[238,187],[218,174],[207,150]], 55, 12),
   'upper_arm_right': p([237,180], [[234,169],[249,171],[256,192],[245,208],[229,219],[212,215],[211,203],[224,192]], 16, 10),
   'arm_right': p([218,207], [[215,194],[230,202],[222,220],[200,228],[184,238],[164,242],[149,231],[144,217],[149,203],[157,207],[159,216],[167,213],[163,202],[168,193],[181,190],[193,199],[199,207]], 20, 10),
   'upper_arm_left': p([290,166], [[276,151],[289,141],[304,149],[313,166],[318,190],[313,211],[303,227],[280,225],[270,210],[278,191],[273,173]], 40, 13),
   'arm_left': p([288,215], [[275,204],[300,207],[307,221],[296,234],[272,240],[239,241],[205,247],[183,244],[170,235],[170,225],[181,227],[173,216],[181,208],[194,211],[206,211],[220,218],[244,218],[269,215]], 65, 12),
   'leg_left': p([303,234], [[290,221],[308,219],[324,244],[335,265],[337,280],[317,286],[305,273],[292,258],[285,239]], 14, 11),
   'shin_left': p([325,274], [[310,265],[334,264],[345,284],[353,300],[365,310],[361,322],[342,321],[324,325],[315,315],[325,306],[318,291]], 18, 10, [343,316]),
   'leg_right': p([241,241], [[226,229],[249,229],[259,250],[258,271],[242,282],[228,274],[216,257],[220,242]], 10, 11),
   'shin_right': p([242,272], [[226,263],[251,263],[263,294],[253,304],[222,314],[198,319],[191,310],[197,301],[212,294],[235,286]], 13, 10, [220,307]),
   'cloth': p([280,220], [[256,230],[280,228],[300,217],[321,204],[326,229],[318,245],[307,251],[311,273],[298,275],[290,290],[280,276],[269,282],[267,260],[254,251]], 25, 9),
  },
  'N': {
   'torso': p([220,215], [], 30, 13),
   'head': p([253,135], [[205,82],[255,89],[280,99],[294,116],[291,140],[279,156],[255,156],[242,142],[228,131],[209,117]], 25, 12),
   'upper_arm_left': p([218,158], [[212,148],[231,155],[245,177],[244,190],[229,197],[214,181]], 8, 10, fill=[[212,156],[226,155],[242,180],[237,193],[225,191],[211,172]]),
   'arm_left': p([234,187], [[236,177],[249,174],[264,175],[271,185],[268,202],[253,206],[241,196]], 12, 9, fill=[[229,181],[239,178],[259,185],[267,196],[257,205],[235,197]]),
   'upper_arm_right': p([249,156], [[233,138],[251,137],[269,146],[277,170],[280,189],[268,207],[251,200],[246,182],[236,174],[226,161]], 45, 13),
   'arm_right': p([269,195], [[253,186],[271,181],[285,196],[302,198],[304,185],[311,176],[323,177],[325,185],[319,190],[329,196],[337,188],[341,196],[338,211],[325,222],[308,227],[286,220],[267,216]], 65, 11),
   'leg_left': p([190,229], [[175,218],[199,220],[210,239],[198,259],[182,274],[165,278],[156,269],[165,250]], 8, 11),
   'shin_left': p([174,269], [[160,257],[184,265],[181,281],[189,291],[180,300],[152,304],[137,299],[136,288],[149,276]], 12, 10, [157,296]),
   'leg_right': p([247,231], [[232,216],[250,216],[269,232],[283,249],[282,265],[264,279],[247,272],[244,255],[229,244]], 20, 12),
   'shin_right': p([267,269], [[253,258],[277,261],[274,283],[278,296],[296,298],[306,311],[299,322],[278,321],[249,321],[238,312],[238,300],[248,284]], 24, 11, [270,314]),
   'cloth': p([221,210], [[179,193],[199,201],[225,202],[247,203],[252,214],[241,232],[236,253],[224,264],[218,280],[208,268],[198,279],[190,267],[182,258],[182,240],[178,223]], 50, 9),
  },
  'W': {
   'torso': p([292,216], [], 30, 13),
   'head': p([258,136], [[218,110],[236,97],[260,92],[304,84],[304,107],[288,124],[284,137],[269,155],[247,155],[232,146],[220,135]], 25, 12),
   'upper_arm_right': p([295,158], [[282,151],[300,148],[301,172],[285,194],[270,191],[271,178]], 8, 10, fill=[[285,155],[298,156],[303,172],[288,192],[275,192],[269,180]]),
   'arm_right': p([278,188], [[263,174],[277,176],[277,196],[260,207],[246,203],[243,187],[251,178]], 12, 9, fill=[[273,180],[285,183],[278,198],[257,206],[245,196],[253,185]]),
   'upper_arm_left': p([263,157], [[246,138],[263,138],[278,151],[284,165],[275,179],[263,182],[257,201],[242,207],[232,188],[236,168]], 45, 13),
   'arm_left': p([243,195], [[239,181],[258,187],[247,216],[226,223],[204,227],[189,222],[175,212],[171,197],[176,188],[184,195],[194,190],[187,185],[189,177],[201,176],[208,185],[210,198],[226,197]], 65, 11),
   'leg_right': p([321,230], [[313,219],[336,219],[347,247],[357,267],[348,277],[330,274],[311,259],[301,239]], 8, 11),
   'shin_right': p([339,269], [[328,265],[350,257],[363,278],[377,289],[376,300],[361,305],[333,301],[324,292],[333,281]], 12, 10, [356,297]),
   'leg_left': p([265,232], [[263,216],[280,217],[284,240],[269,255],[265,273],[249,279],[231,267],[230,250],[244,230]], 20, 12),
   'shin_left': p([246,270], [[235,260],[258,258],[264,283],[274,300],[275,313],[263,322],[235,322],[214,320],[206,311],[216,299],[233,296],[236,283]], 24, 11, [242,315]),
   'cloth': p([291,210], [[265,204],[288,203],[315,198],[332,191],[336,220],[330,240],[330,258],[321,269],[314,279],[304,268],[296,280],[288,264],[275,253],[270,232],[261,215]], 50, 9),
  },
 },
}


HAND_ENDS = {
 'sentinelle_airain': {
    'E': {'arm_right': [99,192], 'arm_left': [281,184]},
    'S': {'arm_right': [101,202], 'arm_left': [276,184]},
    'N': {'arm_right': [330,212], 'arm_left': [128,191]},
    'W': {'arm_right': [398,208], 'arm_left': [207,197]},
 },
 'rejeton_braise': {
    'E': {'arm_right': [322,230], 'arm_left': [344,221]},
    'S': {'arm_left': [190,230], 'arm_right': [168,221]},
    'N': {'arm_right': [321,205], 'arm_left': [259,193]},
    'W': {'arm_left': [191,205], 'arm_right': [253,193]},
 },
}

WEAPON_TIPS = {'E':[47,94], 'S':[62,94], 'N':[375,107], 'W':[450,95]}
WEAPON_HANDS = {
 'E': p([99,191], [[40,83],[63,88],[84,127],[93,159],[99,171],[112,171],[118,185],[113,202],[128,230],[115,239],[103,213],[87,208],[78,197],[76,184],[88,172],[75,148],[56,129]], 72, 8),
 'S': p([101,201], [[54,86],[74,91],[96,141],[104,169],[104,184],[115,184],[117,201],[111,214],[131,246],[116,253],[102,224],[86,215],[79,201],[83,187],[88,181],[77,157],[67,136]], 72, 8),
 'N': p([328,214], [[370,99],[382,110],[375,141],[369,167],[350,178],[343,201],[347,213],[338,229],[321,235],[314,258],[309,279],[296,277],[302,255],[309,235],[314,218],[319,207],[329,203],[339,174],[344,151],[356,123]], 72, 8),
 'W': p([397,207], [[448,88],[458,101],[447,135],[437,163],[423,174],[414,195],[420,210],[409,225],[395,233],[388,258],[380,281],[366,277],[373,252],[381,232],[386,215],[389,199],[399,193],[407,172],[415,142],[431,111]], 72, 8),
}
for _direction, _hand in WEAPON_HANDS.items():
    SPECS['sentinelle_airain'][_direction]['hand_right'] = _hand
    HAND_ENDS['sentinelle_airain'][_direction]['arm_right'] = _hand['pivot']
for _direction in 'ES':
    SPECS['rejeton_braise'][_direction]['cloth']['z'] = 52

# A helmet is narrower than its neighboring shoulder guards. Keeping these
# contours tight prevents a pauldron tip from following the head rotation.
HELMETS = {
 'E': [[192,36],[212,34],[225,44],[231,60],[226,80],[218,91],[200,100],[184,94],[176,83],[174,68],[181,48]],
 'S': [[187,36],[204,34],[216,41],[222,57],[220,79],[212,90],[195,100],[180,97],[172,84],[172,64],[180,44]],
 'N': [[215,48],[235,47],[244,55],[249,71],[247,87],[229,95],[213,91],[203,83],[207,63]],
 'W': [[278,42],[295,42],[305,49],[311,65],[313,80],[303,89],[285,90],[271,84],[268,64],[272,50]],
}
for _direction, _polygon in HELMETS.items():
    SPECS['sentinelle_airain'][_direction]['head']['polygon'] = _polygon

# The source shows clasped/occluded claws. One complete visible hand owns every
# finger. The other hand is reconstructed from the same painting behind it.
CLAW_GROUPS = {
 'E': {'near':'arm_right','far':'arm_left','polygon':[[314,182],[351,182],[370,198],[371,243],[330,251],[307,241],[307,220]]},
 'S': {'near':'arm_left','far':'arm_right','polygon':[[161,182],[198,182],[205,220],[205,241],[181,251],[141,243],[141,198]]},
 'N': {'near':'arm_right','far':'arm_left','polygon':[[301,169],[344,168],[349,221],[326,231],[294,221],[294,192]]},
 'W': {'near':'arm_left','far':'arm_right','polygon':[[168,168],[211,169],[218,192],[218,221],[186,231],[163,221]]},
}
HAND_ENDS['rejeton_braise']['E']['arm_left'] = [334,218]
HAND_ENDS['rejeton_braise']['S']['arm_right'] = [178,218]
HAND_ENDS['rejeton_braise']['N']['arm_left'] = [321,205]
HAND_ENDS['rejeton_braise']['W']['arm_right'] = [191,205]
SPECS['rejeton_braise']['N']['arm_left']['pivot'] = [264,187]
SPECS['rejeton_braise']['W']['arm_right']['pivot'] = [248,187]


TORSO_CORE = {
 'sentinelle_airain': {
  'E': [[165,96],[205,92],[238,111],[253,164],[243,193],[224,219],[199,223],[169,211],[153,185],[150,145]],
  'S': [[161,96],[197,90],[232,105],[247,157],[237,195],[214,222],[186,222],[163,205],[150,178],[147,146]],
  'N': [[181,91],[220,85],[253,103],[271,140],[260,181],[235,204],[203,214],[173,198],[165,163],[170,118]],
  'W': [[265,90],[295,82],[330,99],[348,143],[342,175],[320,201],[290,214],[257,202],[238,176],[244,133]],
 },
 'rejeton_braise': {
  'E': [[218,146],[242,150],[260,173],[278,197],[278,218],[266,240],[233,246],[211,227],[201,199],[200,172]],
  'S': [[290,146],[272,149],[254,172],[235,194],[235,217],[246,240],[279,246],[304,226],[314,199],[313,173]],
  'N': [[222,127],[250,132],[269,151],[275,178],[262,198],[248,218],[210,224],[185,211],[186,180],[201,149]],
  'W': [[290,127],[263,133],[246,150],[237,179],[249,198],[264,218],[301,224],[330,212],[327,180],[311,149]],
 },
}
SKIN_SAMPLE = {'E':[250,197], 'S':[263,197], 'N':[224,173], 'W':[293,173]}


def _palette(base, xy, radius=5):
    x, y = map(int, xy)
    crop = base.crop((x-radius, y-radius, x+radius+1, y+radius+1))
    pixels = [v[:3] for v in list(crop.get_flattened_data()) if v[3] > 200]
    if not pixels:
        return (80, 83, 76, 255)
    return tuple(sorted(v[c] for v in pixels)[len(pixels)//2] for c in range(3)) + (255,)


def _joint_underpaint(image, base, pivot, radius, color=None):
    color = color or _palette(base, pivot)
    edge = tuple(int(c*.82) for c in color[:3]) + (255,)
    x, y = pivot
    draw = ImageDraw.Draw(image)
    draw.ellipse((x-radius, y-radius, x+radius, y+radius), fill=edge)
    draw.ellipse((x-radius+1, y-radius+1, x+radius-1, y+radius-1), fill=color)


def _bone_underpaint(image, base, start, end, radius, color=None):
    color = color or _palette(base, [(start[0]+end[0])/2,(start[1]+end[1])/2], 7)
    shade = tuple(int(c*.82) for c in color[:3])+(255,)
    draw = ImageDraw.Draw(image)
    draw.line([tuple(start),tuple(end)], fill=shade, width=round(radius*2))
    draw.line([tuple(start),tuple(end)], fill=color, width=max(4,round(radius*2-3)))
    _joint_underpaint(image,base,start,radius,color)
    _joint_underpaint(image,base,end,radius,color)


def _torso_underpainting(base, slug, direction):
    """Paint the whole occluded body, not merely circles at its joints."""
    points = TORSO_CORE[slug][direction]
    sample = SKIN_SAMPLE[direction] if slug == 'rejeton_braise' else SPECS[slug][direction]['torso']['pivot']
    color = _palette(base, sample, 6)
    if slug == 'sentinelle_airain':
        # Use an existing breast/back plate instead of the dark hip socket.
        center = np.mean(points, axis=0)
        color = _palette(base, [center[0], center[1]-12], 7)
    mask = Image.new('L', CANVAS)
    ImageDraw.Draw(mask).polygon(points, fill=255)
    rgba = np.zeros((384,512,4), dtype=np.uint8)
    yy, xx = np.indices((384,512))
    center = np.mean(points, axis=0)
    # Broad painterly value changes follow the existing painting's own palette.
    light = .90 + .12*np.exp(-((xx-center[0]+9)/29)**2-((yy-center[1]+8)/48)**2)
    light += .016*np.sin(xx*.71+yy*.36)*np.sin(yy*.61)
    for channel in range(3): rgba[:,:,channel] = np.clip(color[channel]*light,0,255)
    rgba[:,:,3] = np.asarray(mask)
    under = Image.fromarray(rgba)
    draw = ImageDraw.Draw(under)
    outline = tuple(int(c*.66) for c in color[:3])+(255,)
    draw.line(points+[points[0]], fill=outline, width=2, joint='curve')
    return under


def _reassign_disconnected_edges(labels, opaque, names):
    """Move mis-cut slivers to the adjacent anatomical component, never erase."""
    major = labels.copy()
    fragments = []
    for index,name in enumerate(names):
        if name in ('torso','cloth'): continue
        mask = (labels == index) & opaque
        seen = np.zeros(mask.shape,dtype=bool)
        components = []
        for sy,sx in zip(*np.nonzero(mask)):
            if seen[sy,sx]: continue
            queue = deque([(int(sy),int(sx))]); seen[sy,sx] = True
            component = []
            while queue:
                y,x = queue.popleft(); component.append((y,x))
                for dy,dx in ((-1,-1),(-1,0),(-1,1),(0,-1),(0,1),(1,-1),(1,0),(1,1)):
                    ny,nx=y+dy,x+dx
                    if 0<=ny<384 and 0<=nx<512 and mask[ny,nx] and not seen[ny,nx]:
                        seen[ny,nx]=True;queue.append((ny,nx))
            components.append(component)
        if not components: continue
        largest = max(components,key=len)
        for component in components:
            if component is largest: continue
            values=np.asarray(component,int)
            major[values[:,0],values[:,1]] = 255
            fragments.append(values)
    yy,xx=np.nonzero((major!=255)&opaque)
    for points in fragments:
        cy,cx=points.mean(axis=0)
        nearest=((yy-cy)**2+(xx-cx)**2).argmin()
        labels[points[:,0],points[:,1]]=major[yy[nearest],xx[nearest]]
    return labels


def build_parts(slug, direction, basePILRGBA512x384):
    """Return parented, depth-sorted RGBA rigid layers in original coordinates.

    Extra ``end`` and ``limits`` fields let the compositor use a shin ground
    endpoint and explicit local-angle bounds without guessing anatomy.
    """
    if slug not in SPECS or direction not in SPECS[slug]:
        raise ValueError(f'Unsupported humanoid painting: {slug}/{direction}')
    base = basePILRGBA512x384.convert('RGBA')
    if base.size != CANVAS:
        raise ValueError(f'Expected {CANVAS}, got {base.size}')
    specs = SPECS[slug][direction]
    names = list(specs)
    labels = Image.new('L', CANVAS, 0)
    draw = ImageDraw.Draw(labels)
    # Each cut is assigned in order: torso, joints, then extremities.
    # Shin cuts override their thighs. Hand+equipment remains one rigid piece.
    order = ['upper_arm_left', 'upper_arm_right', 'leg_left', 'leg_right',
             'shin_left', 'shin_right', 'cloth', 'arm_left', 'arm_right',
             'head', 'hand_right']
    for name in order:
        if name in specs:
            draw.polygon(specs[name]['polygon'], fill=names.index(name))
    if slug == 'rejeton_braise':
        claws = CLAW_GROUPS[direction]
        draw.polygon(claws['polygon'],fill=names.index(claws['near']))
    # Tiny source contour slivers outside the torso belong to the nearest cut
    # piece, not to a static torso that would leave floating spear/leg fragments.
    core_mask = Image.new('L', CANVAS)
    ImageDraw.Draw(core_mask).polygon(TORSO_CORE[slug][direction], fill=255)
    label_array = np.asarray(labels).copy()
    original = np.asarray(base)
    opaque = original[:,:,3] > 0
    orphan = (label_array == 0) & (np.asarray(core_mask) == 0) & opaque
    edges_a, edges_b, edge_labels = [], [], []
    for name in names[1:]:
        poly = specs[name]['polygon']
        for index, vertex in enumerate(poly):
            edges_a.append(vertex)
            edges_b.append(poly[(index+1)%len(poly)])
            edge_labels.append(names.index(name))
    aa, bb = np.asarray(edges_a,float), np.asarray(edges_b,float)
    vv = bb-aa
    ll = np.maximum((vv*vv).sum(axis=1),1)
    orphan_y, orphan_x = np.nonzero(orphan)
    for start in range(0,len(orphan_x),512):
        points = np.stack([orphan_x[start:start+512],orphan_y[start:start+512]],axis=1)
        delta = points[:,None,:]-aa[None,:,:]
        parameter = np.clip((delta*vv).sum(axis=2)/ll,0,1)
        residual = delta-parameter[:,:,None]*vv
        closest = (residual*residual).sum(axis=2).argmin(axis=1)
        label_array[orphan_y[start:start+512],orphan_x[start:start+512]] = np.asarray(edge_labels)[closest]
    if slug == 'rejeton_braise':
        # The cloth's orange hem is occluded by the horizontal front forearm.
        # Keep that painted hem on the cloth when the forearm rises.
        rgb = original[:,:,:3].astype(float)
        yy = np.indices((384,512))[0]
        cloth_color = (rgb[:,:,0] > rgb[:,:,1]*1.24) & (rgb[:,:,0] > rgb[:,:,2]*1.40) & (yy > 198) & opaque
        label_array[cloth_color] = names.index('cloth')
    label_array = _reassign_disconnected_edges(label_array,opaque,names)
    labels = Image.fromarray(label_array)
    result = []
    source_alpha = base.getchannel('A')
    for index, name in enumerate(names):
        spec = specs[name]
        mask = labels.point(lambda value, i=index: 255 if value == i else 0)
        piece = base.copy()
        from PIL import ImageChops
        piece.putalpha(ImageChops.multiply(mask, source_alpha))
        under = _torso_underpainting(base, slug, direction) if name == 'torso' else Image.new('RGBA', CANVAS)
        if spec['fill']:
            color = _palette(base, spec['pivot'])
            shade = tuple(int(c*.68) for c in color[:3]) + (255,)
            ImageDraw.Draw(under).polygon(spec['fill'], fill=shade)
        skin = _palette(base, SKIN_SAMPLE[direction]) if slug == 'rejeton_braise' else None
        if name.startswith('upper_arm_') or name.startswith('leg_'):
            child_name = name.replace('upper_arm_', 'arm_').replace('leg_', 'shin_')
            _bone_underpaint(under, base, spec['pivot'], specs[child_name]['pivot'],
                             min(spec['radius'],12), skin)
        if name != 'torso':
            _joint_underpaint(under, base, spec['pivot'], min(spec['radius'],8) if name == 'head' else spec['radius'], skin)
        for child_name, child in specs.items():
            if PARENTS[child_name] == name and name != 'torso':
                _joint_underpaint(under, base, child['pivot'], child['radius'], skin)
        # Reconstruction stays inside the original opaque union at rest. It
        # occupies the pixels hidden by other pieces, not empty silhouette space.
        coverage = source_alpha.point(lambda value: 255 if value > 16 else 0)
        coverage = coverage.filter(ImageFilter.MaxFilter(3)).filter(ImageFilter.MinFilter(3))
        if name != 'torso':
            under.putalpha(ImageChops.multiply(under.getchannel('A'),coverage))
        if slug == 'rejeton_braise' and name == CLAW_GROUPS[direction]['far']:
            # The rear forearm is occluded by the near arm in the painting.
            # It needs a continuous elbow-to-wrist reconstruction when their
            # poses separate; the hand alone would float above the shoulder.
            _bone_underpaint(under,base,spec['pivot'],
                HAND_ENDS[slug][direction][name],8,skin)
            claw_mask = Image.new('L',CANVAS)
            ImageDraw.Draw(claw_mask).polygon(CLAW_GROUPS[direction]['polygon'],fill=255)
            hidden_hand = base.copy()
            hidden_hand.putalpha(ImageChops.multiply(source_alpha,claw_mask))
            under.alpha_composite(hidden_hand)
        combined = under.copy()
        combined.alpha_composite(piece)
        layer = {'name': name, 'image': combined, 'source_image': piece,
                 'underpaint': under, 'pivot': list(spec['pivot']),
                 'parent': PARENTS[name], 'z': spec['z'],
                 'limits': JOINT_LIMITS[slug].get(name, [-30,30])}
        if name in HAND_ENDS[slug][direction]:
            layer['end'] = list(HAND_ENDS[slug][direction][name])
        elif spec['end'] is not None:
            layer['end'] = list(spec['end'])
        if name == 'hand_right':
            layer['weapon_tip'] = list(WEAPON_TIPS[direction])
            layer['weapon_axis'] = [WEAPON_TIPS[direction][axis]-spec['pivot'][axis] for axis in (0,1)]
        result.append(layer)
    return sorted(result, key=lambda item: item['z'])


def proof_pose(parts, angles):
    """Rigid FK review only; the production compositor supplies foot/hand IK."""
    by_name = {part['name']:part for part in parts}
    transforms = {'root':np.eye(3)}
    def world(name):
        if name in transforms: return transforms[name]
        part = by_name[name]
        theta = math.radians(angles.get(name,0))
        c,s = math.cos(theta),math.sin(theta)
        rotation = np.array([[c,-s,0],[s,c,0],[0,0,1.]])
        pivot = np.asarray(part['pivot'],float)
        rotation[:2,2] = pivot-rotation[:2,:2]@pivot
        transforms[name] = world(part['parent'])@rotation
        return transforms[name]
    result = Image.new('RGBA',CANVAS)
    for field in ['underpaint','source_image']:
        for part in parts:
            inverse = np.linalg.inv(world(part['name']))
            layer = part[field].transform(CANVAS,Image.Transform.AFFINE,
                tuple(inverse[:2,:].reshape(-1)),Image.Resampling.BICUBIC)
            result.alpha_composite(layer)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--slug', choices=list(SPECS))
    args = parser.parse_args()
    output = ROOT/'output/catabase_monsters_v2/humanoid_parts'
    output.mkdir(parents=True, exist_ok=True)
    for slug in [args.slug] if args.slug else SPECS:
        for direction in 'ESNW':
            base = Image.open(ROOT/f'art/source/characters/catabase_monsters/{slug}/base_frame_{direction}.png').convert('RGBA')
            parts = build_parts(slug, direction, base)
            assembled = proof_pose(parts,{})
            panels = [('SOURCE', base), ('ASSEMBLED', assembled)] + [(x['name'], x['image']) for x in parts]
            contact = Image.new('RGB', (4*320, ((len(panels)+3)//4)*270), '#243133')
            draw = ImageDraw.Draw(contact)
            for index, (label, picture) in enumerate(panels):
                col, row = index%4, index//4
                scaled = picture.resize((320,240), Image.Resampling.LANCZOS)
                contact.paste(scaled, (col*320,row*270+24), scaled)
                draw.text((col*320+8,row*270+5), label, fill='white')
            contact.save(output/f'{slug}_{direction}_layers.png')
            assembled.save(output/f'{slug}_{direction}_assembled.png')
            sign = -1 if direction in 'EN' else 1
            raised = {'upper_arm_right':sign*25,'arm_right':sign*45,
                      'upper_arm_left':sign*20,'arm_left':sign*45,'head':-sign*8}
            if slug == 'sentinelle_airain':
                raised = {'upper_arm_right':25 if direction in 'ES' else -25,
                          'arm_right':45 if direction in 'ES' else -45,
                          'upper_arm_left':-25 if direction in 'ES' else 25,
                          'arm_left':-35 if direction in 'ES' else 35,'head':-sign*8}
            stride = {'leg_right':20,'shin_right':-35,'leg_left':-20,'shin_left':35,
                      'torso':sign*5,'upper_arm_right':-sign*18,'arm_right':sign*25}
            proofs = [('NEUTRAL',assembled),('ARMS 25 / 45',proof_pose(parts,raised)),
                      ('THIGHS 20 / SHINS 35',proof_pose(parts,stride))]
            if slug == 'sentinelle_airain':
                proofs.append(('WRIST 90',proof_pose(parts,{'hand_right':90 if direction in 'ES' else -90})))
            proof = Image.new('RGB',(len(proofs)*512,408),'#243133')
            pen = ImageDraw.Draw(proof)
            for index,(label,picture) in enumerate(proofs):
                proof.paste(picture,(index*512,24),picture)
                pen.text((index*512+10,7),label,fill='white')
            proof.save(output/f'{slug}_{direction}_articulation.png')
            (output/f'{slug}_{direction}_joints.json').write_text(json.dumps(
                [{k:v for k,v in x.items() if k not in ('image','source_image','underpaint')} for x in parts], indent=2), encoding='utf-8')
    print(output)


if __name__ == '__main__':
    main()
