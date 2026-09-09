"""Reviewed cutout anatomy for eight independent quadruped/serpent paintings.

Source pixels are assigned once. Reconstructed joints are separate underpaint
layers: the compositor must draw *all* underpaint before *any* source_image.
"""
from copy import deepcopy
from PIL import Image, ImageDraw, ImageChops, ImageFilter
import numpy as np

CANVAS = (512, 384)


def spec(pivot, polygon, parent, z, radius=7, end=None, fill=None):
    return dict(pivot=pivot, polygon=polygon, parent=parent, z=z,
                radius=radius, end=end, fill=fill)


DOG = {
 'E': {
  'torso': spec([230,213], [], 'root', 30, 12, fill=[[171,209],[209,194],[261,184],[286,207],[280,234],[247,247],[218,232],[187,234],[166,230]]),
  'head': spec([287,195], [[278,151],[321,146],[344,167],[359,184],[363,204],[346,220],[313,216],[294,225],[278,214],[278,191]], 'torso', 60, 11),
  'jaw': spec([320,202], [[309,201],[329,202],[343,209],[351,204],[351,216],[333,219],[315,214]], 'head', 65, 4),
  'tail': spec([173,221], [[126,178],[146,176],[139,199],[144,209],[153,213],[171,211],[180,221],[171,232],[151,237],[127,227],[119,207]], 'torso', 25, 7),
  'leg_hind_far': spec([207,227], [[203,216],[217,228],[213,245],[203,260],[207,273],[198,280],[188,264],[187,249]], 'torso', 8, 8),
  'shin_hind_far': spec([198,264], [[190,252],[208,256],[210,272],[219,282],[231,289],[231,296],[211,300],[201,290],[195,273]], 'leg_hind_far', 9, 6, [220,291]),
  'leg_fore_far': spec([285,229], [[281,219],[299,225],[300,244],[311,261],[316,275],[304,280],[288,259],[275,244]], 'torso', 10, 8),
  'shin_fore_far': spec([308,271], [[299,257],[316,265],[329,286],[344,296],[348,308],[328,309],[313,298],[306,281]], 'leg_fore_far', 11, 6, [336,302]),
  'leg_left': spec([183,226], [[167,207],[194,214],[197,233],[181,255],[165,265],[150,280],[139,274],[148,251],[160,238]], 'torso', 35, 10),
  'shin_left': spec([153,268], [[142,256],[169,259],[165,277],[153,291],[150,300],[156,306],[148,310],[130,309],[130,298],[136,280]], 'leg_left', 40, 6, [143,304]),
  'leg_right': spec([247,230], [[233,215],[261,218],[267,237],[251,257],[250,278],[236,283],[230,261],[225,247]], 'torso', 42, 10),
  'shin_right': spec([244,272], [[233,259],[255,264],[259,291],[264,302],[274,309],[276,320],[253,325],[244,316],[241,296]], 'leg_right', 45, 7, [262,316]),
 },
 'N': {
  'torso': spec([285,211], [], 'root', 30, 12, fill=[[233,204],[266,175],[308,157],[337,160],[350,188],[344,219],[319,235],[279,242],[246,243]]),
  'head': spec([352,159], [[335,123],[371,118],[387,130],[387,145],[400,144],[402,162],[387,176],[366,182],[350,176],[339,161]], 'torso', 20, 10),
  'jaw': spec([382,163], [[374,161],[390,157],[398,163],[391,177],[376,181]], 'head', 22, 4),
  'tail': spec([246,216], [[187,199],[197,210],[190,224],[195,233],[210,237],[227,228],[239,213],[253,215],[249,234],[230,253],[207,260],[188,254],[174,239],[170,219]], 'torso', 25, 8),
  'leg_hind_far': spec([237,229], [[225,218],[249,218],[252,239],[239,257],[232,267],[217,266],[217,247]], 'torso', 8, 9),
  'shin_hind_far': spec([226,261], [[215,250],[240,253],[236,272],[234,282],[242,287],[240,297],[218,297],[212,286]], 'leg_hind_far', 9, 7, [225,291]),
  'leg_fore_far': spec([305,222], [[294,212],[313,214],[319,233],[315,248],[313,257],[302,260],[294,244]], 'torso', 10, 8),
  'shin_fore_far': spec([306,251], [[297,240],[315,242],[317,255],[325,260],[329,268],[316,271],[302,267]], 'leg_fore_far', 11, 5, [318,265]),
  'leg_left': spec([270,231], [[254,214],[281,218],[287,239],[275,263],[262,275],[246,281],[241,264],[245,243]], 'torso', 40, 11),
  'shin_left': spec([254,272], [[242,259],[271,262],[268,286],[267,302],[278,308],[277,320],[256,325],[245,315],[243,291]], 'leg_left', 45, 7, [261,314]),
  'leg_right': spec([343,211], [[333,192],[355,197],[362,219],[355,235],[357,249],[347,256],[330,231]], 'torso', 35, 10),
  'shin_right': spec([349,245], [[337,232],[359,234],[365,253],[371,264],[384,269],[385,279],[367,284],[357,276],[350,259]], 'leg_right', 38, 6, [373,276]),
 },
}

LAMIA = {
 'E': {
  'torso': spec([277,229], [], 'root', 35, 12, fill=[[260,111],[289,110],[299,130],[289,164],[300,194],[294,229],[277,239],[258,222],[251,202],[250,174],[262,146]]),
  'head': spec([277,105], [[224,33],[312,33],[312,85],[298,92],[293,111],[273,116],[260,101],[257,90],[224,91]], 'torso', 65, 7),
  'tail': spec([279,245], [[144,222],[240,216],[253,202],[269,220],[293,244],[323,247],[342,241],[353,202],[387,204],[398,322],[149,330]], 'root', 20, 10, fill=[[256,195],[273,213],[294,241],[321,259],[317,291],[286,278],[275,245],[255,221]]),
  'upper_arm_right': spec([253,126], [[247,108],[263,108],[269,125],[257,148],[250,165],[234,169],[235,146]], 'torso', 43, 7),
  'arm_right': spec([242,157], [[233,147],[253,151],[250,166],[234,178],[230,190],[209,196],[199,185],[204,172],[220,171]], 'upper_arm_right', 55, 6, [217,181]),
  'upper_arm_left': spec([299,124], [[289,110],[302,110],[312,128],[322,139],[318,150],[304,147],[295,135]], 'torso', 40, 7),
  'arm_left': spec([315,141], [[306,133],[321,134],[337,145],[349,144],[354,152],[366,102],[349,89],[350,70],[365,60],[384,62],[393,79],[385,95],[375,115],[333,244],[320,244],[346,160],[334,161],[314,153],[307,147]], 'upper_arm_left', 60, 6, [346,153]),
 },
 'S': {
  'torso': spec([263,229], [], 'root', 35, 12, fill=[[244,104],[277,107],[286,128],[277,156],[289,197],[281,228],[263,240],[244,221],[235,195],[234,172],[246,145]]),
  'head': spec([256,101], [[229,30],[310,25],[314,80],[279,83],[272,102],[263,112],[246,111],[235,92],[228,79]], 'torso', 65, 7),
  'tail': spec([268,245], [[164,225],[232,217],[247,201],[264,221],[288,245],[318,253],[337,242],[347,214],[371,214],[379,320],[163,330]], 'root', 20, 10, fill=[[240,193],[262,206],[279,237],[303,256],[301,288],[278,278],[255,238],[236,217]]),
  'upper_arm_right': spec([236,123], [[225,103],[244,101],[246,123],[236,142],[230,156],[211,160],[216,142]], 'torso', 43, 7),
  'arm_right': spec([219,152], [[208,140],[227,145],[229,158],[211,172],[206,184],[185,191],[170,181],[176,166],[196,160]], 'upper_arm_right', 55, 6, [193,174]),
  'upper_arm_left': spec([281,124], [[272,107],[287,108],[299,125],[312,138],[308,149],[293,146],[283,134]], 'torso', 40, 7),
  'arm_left': spec([304,141], [[295,133],[310,133],[326,148],[338,147],[344,153],[354,108],[343,91],[340,77],[351,65],[366,62],[382,72],[384,87],[372,101],[366,119],[321,254],[307,254],[334,168],[321,169],[301,155],[295,146]], 'upper_arm_left', 60, 6, [337,157]),
 },
 'N': {
  'torso': spec([250,225], [], 'root', 38, 12, fill=[[261,103],[290,104],[299,125],[285,158],[292,189],[274,211],[267,232],[250,237],[237,225],[245,196],[247,168],[259,145]]),
  'head': spec([277,106], [[246,42],[321,37],[327,85],[304,94],[291,115],[265,115],[252,93],[243,84]], 'torso', 25, 7),
  'tail': spec([270,248], [[143,221],[178,216],[208,234],[226,229],[241,198],[258,213],[285,226],[332,212],[375,226],[387,329],[145,330]], 'root', 20, 11, fill=[[243,185],[263,199],[249,233],[258,263],[291,280],[273,294],[239,274],[221,247],[229,214]]),
  'upper_arm_left': spec([257,122], [[247,104],[266,102],[274,120],[260,137],[246,150],[232,148],[238,130]], 'torso', 43, 7),
  'arm_left': spec([241,142], [[226,134],[242,130],[252,139],[246,150],[228,153],[212,151],[242,290],[230,292],[199,152],[193,144],[191,128],[179,87],[169,77],[172,61],[186,51],[200,55],[209,67],[204,81],[196,88],[204,130],[216,135]], 'upper_arm_left', 55, 6, [204,142]),
  'upper_arm_right': spec([298,126], [[290,108],[306,111],[315,132],[317,143],[307,151],[297,139]], 'torso', 43, 7),
  'arm_right': spec([310,143], [[302,133],[317,136],[324,150],[338,151],[341,165],[330,172],[311,157]], 'upper_arm_right', 60, 5, [328,156]),
 },
 'W': {
  'torso': spec([236,232], [], 'root', 38, 12, fill=[[232,110],[266,111],[277,131],[263,163],[272,198],[253,222],[250,238],[236,244],[223,232],[217,194],[224,165],[238,142]]),
  'head': spec([253,109], [[220,36],[304,35],[311,81],[279,91],[265,116],[245,118],[230,96],[217,86]], 'torso', 25, 7),
  'tail': spec([253,257], [[150,245],[178,244],[196,251],[209,232],[220,202],[235,207],[239,231],[271,244],[309,243],[338,274],[340,326],[149,330]], 'root', 20, 11, fill=[[223,188],[244,201],[229,238],[232,267],[272,288],[252,301],[216,283],[202,251],[212,219]]),
  'upper_arm_left': spec([231,128], [[221,111],[242,108],[248,124],[233,144],[216,159],[202,159],[209,141]], 'torso', 43, 7),
  'arm_left': spec([212,151], [[202,141],[220,140],[225,151],[218,161],[201,167],[184,167],[214,294],[201,297],[171,168],[162,158],[159,132],[149,104],[140,93],[141,78],[153,68],[169,73],[178,87],[170,101],[165,108],[175,147],[188,154]], 'upper_arm_left', 55, 6, [180,160]),
  'upper_arm_right': spec([272,129], [[265,111],[281,114],[292,140],[291,151],[279,153],[270,139]], 'torso', 43, 7),
  'arm_right': spec([285,148], [[276,141],[292,141],[301,159],[318,162],[325,175],[312,182],[297,173],[284,161]], 'upper_arm_right', 60, 5, [313,171]),
 },
}


# Opposite-view coordinates were initially estimated from the source extents;
# these are geometry coordinates only, never a texture reflection. Retain that
# useful starting point, then author the real differences in each painting.
def _opposite_coordinates(source, source_bounds, target_bounds):
    result = deepcopy(source)
    a, b = source_bounds
    c, d = target_bounds
    def opposite(point):
        return [round(c+(b-point[0])*(d-c)/(b-a), 2), point[1]]
    for part in result.values():
        part['pivot'] = opposite(part['pivot'])
        part['polygon'] = [opposite(point) for point in part['polygon']]
        if part['end'] is not None:
            part['end'] = opposite(part['end'])
        if part['fill'] is not None:
            part['fill'] = [opposite(point) for point in part['fill']]
    return result


DOG['S'] = _opposite_coordinates(DOG['E'], (127,355), (158,381))
DOG['W'] = _opposite_coordinates(DOG['N'], (176,394), (118,336))
# The painted front-left view has its near forepaw under x252 and its hindpaw
# at x369; the other forepaw stretches to x181. Do not fit them to E's stride.
DOG['S']['shin_left']['end'] = [369,301]
DOG['S']['shin_right']['end'] = [253,313]
DOG['S']['shin_fore_far']['end'] = [181,302]
DOG['S']['shin_hind_far']['end'] = [292,289]
DOG['S']['leg_left']['pivot'] = [329,225]
DOG['S']['shin_left']['pivot'] = [357,269]
DOG['S']['leg_right']['pivot'] = [267,230]
DOG['S']['shin_right']['pivot'] = [263,270]
# W's occluded front leg ends well above the foreground paws. The estimate
# from N erroneously reached y265 and moved a fragment of the empty gap.
DOG['W']['leg_fore_far'] = spec([209,218],
    [[198,209],[216,209],[219,224],[214,236],[207,245],[194,243],[198,229]],
    'torso', 10, 7)
DOG['W']['shin_fore_far'] = spec([204,238],
    [[197,229],[216,231],[212,244],[209,253],[196,258],[186,254],[189,246],[199,245]],
    'leg_fore_far', 11, 5, [198,252])
DOG['W']['shin_hind_far']['pivot'] = [289,264]
DOG['W']['shin_hind_far']['end'] = [288,286]
DOG['W']['leg_left']['pivot'] = [243,224]
DOG['W']['shin_left']['pivot'] = [258,270]
DOG['W']['shin_left']['end'] = [252,312]
DOG['W']['shin_right']['end'] = [144,272]
DOG['W']['jaw'] = spec([133,155],
    [[120,147],[132,149],[141,154],[135,164],[125,164],[119,157]], 'head', 22, 4)

# Keep the whole tabard on the torso as it tips around the coil junction. The
# tail mask used to keep these lower cloth panels upright during the death.
LAMIA_CLOTH = {
 'E': [[253,149],[287,153],[296,176],[297,196],[305,216],[315,239],
       [300,244],[284,231],[274,208],[260,215],[242,219],[243,195],[247,173]],
 'S': [[238,150],[275,151],[288,174],[289,196],[299,220],[305,239],
       [288,247],[273,230],[261,206],[244,212],[224,217],[225,190],[231,169]],
 'N': [[250,145],[285,146],[299,164],[299,189],[288,211],[278,224],
       [266,220],[267,191],[257,196],[241,205],[242,182]],
 'W': [[226,151],[265,151],[279,173],[275,196],[264,218],[252,232],
       [239,226],[242,199],[230,205],[211,210],[213,185]],
}

LAMIA_FOREARMS = {
 'E': [[306,133],[321,134],[338,145],[349,143],[357,149],[357,161],[344,163],[329,160],[314,153],[307,147]],
 'S': [[295,133],[311,133],[328,148],[339,146],[348,152],[347,165],[334,168],[321,169],[301,155],[295,146]],
 'N': [[227,132],[244,130],[253,139],[248,149],[230,153],[213,149],[204,151],[196,148],[194,136],[204,133],[217,135]],
 'W': [[202,141],[220,140],[227,150],[218,162],[201,167],[185,168],[173,168],[166,163],[165,152],[176,149],[188,154]],
}
LAMIA_CLOTH_REGIONS = {'E':[237,153,321,248], 'S':[220,151,311,249],
                      'N':[239,145,305,227], 'W':[209,153,282,237]}
LAMIA_PELVIS_END = {'E':[306,235], 'S':[290,238], 'N':[282,210], 'W':[252,224]}
LAMIA_SKIN_SAMPLE = {'E':[290,250], 'S':[267,242], 'N':[250,225], 'W':[229,236]}
LAMIA_UPPER_NECK = {
 'E': [[250,166],[289,164],[300,187],[317,232],[309,239],[281,244],[259,232],[248,210],[245,194]],
 'S': [[231,163],[274,162],[288,184],[307,232],[295,243],[269,244],[246,232],[232,211],[226,193]],
 'N': [[248,159],[289,158],[298,185],[278,218],[268,230],[246,233],[232,218],[240,196]],
 'W': [[223,165],[270,166],[279,188],[259,222],[250,237],[224,238],[210,224],[213,201]],
}
LAMIA_RIGHT_PAULDRON = {'E':[241,102,268,135], 'S':[221,98,246,132],
                        'N':[290,103,315,131], 'W':[264,108,286,137]}
LAMIA_RIGHT_BRACER = {'E':[222,158,243,176], 'S':[198,150,221,175],
                      'N':[311,143,332,161], 'W':[293,151,312,172]}
LAMIA_STAFF = {
 'E': {'crook': [346,56,393,109], 'shaft': [[365,103],[350,158],[324,245]]},
 'S': {'crook': [338,59,386,111], 'shaft': [[360,105],[339,163],[312,255]]},
 'N': {'crook': [169,47,215,93], 'shaft': [[191,86],[205,144],[235,292]]},
 'W': {'crook': [138,64,181,112], 'shaft': [[161,101],[175,159],[205,294]]},
}
for _direction, _polygon in LAMIA_FOREARMS.items():
    LAMIA[_direction]['arm_left']['polygon'] = _polygon

DOG_FUR_SAMPLE = {'E':[230,205], 'S':[284,203], 'N':[288,198], 'W':[235,196]}
DOG_SPINE_REGION = {'E':[190,136,288,192], 'S':[239,135,330,192],
                    'N':[240,135,342,202], 'W':[180,132,242,183]}

# A generous torso envelope includes the painted back spines/collar. Opaque
# pixels outside this envelope and every named cut are limb contour slivers;
# attach them to their nearest cut instead of leaving a static torso fragment.
DOG_TORSO_ENVELOPE = {
 'E': [[157,190],[206,173],[240,142],[305,160],[315,210],[282,250],[221,250],[163,242]],
 'S': [[231,169],[264,140],[322,167],[354,207],[346,245],[293,253],[260,253],[219,230]],
 'N': [[221,201],[268,153],[329,142],[355,156],[356,227],[281,254],[227,250]],
 'W': [[146,153],[188,136],[246,166],[284,209],[286,250],[231,257],[166,232]],
}


def _color(base, pivot):
    x,y=map(round,pivot)
    sample=base.crop((x-4,y-4,x+5,y+5))
    pixels=np.asarray(sample)
    visible=pixels[pixels[:,:,3]>200,:3]
    if not len(visible):
        return (75,91,91,255)
    return tuple(map(int,np.median(visible,axis=0)))+(255,)


def _cap(image, base, point, radius, color=None):
    x,y=point
    c=color or _color(base,point)
    draw=ImageDraw.Draw(image)
    draw.ellipse((x-radius,y-radius,x+radius,y+radius),fill=c)


def _assign_contour_slivers(labels, base, specs, envelopes):
    core=Image.new('L',CANVAS)
    for envelope in envelopes:
        ImageDraw.Draw(core).polygon([tuple(p) for p in envelope],fill=255)
    result=np.asarray(labels).copy()
    opaque=np.asarray(base)[:,:,3]>0
    orphan=(result==0)&(np.asarray(core)==0)&opaque
    ys,xs=np.nonzero(orphan)
    names=list(specs)
    starts,ends,owners=[],[],[]
    for name in names[1:]:
        polygon=specs[name]['polygon']
        for index,vertex in enumerate(polygon):
            starts.append(vertex)
            ends.append(polygon[(index+1)%len(polygon)])
            owners.append(names.index(name))
    starts=np.asarray(starts,float)
    vectors=np.asarray(ends,float)-starts
    lengths=np.maximum((vectors*vectors).sum(axis=1),1.)
    owners=np.asarray(owners)
    for offset in range(0,len(xs),512):
        points=np.stack([xs[offset:offset+512],ys[offset:offset+512]],axis=1)
        delta=points[:,None,:]-starts[None,:,:]
        parameter=np.clip((delta*vectors).sum(axis=2)/lengths,0.,1.)
        residual=delta-parameter[:,:,None]*vectors
        closest=(residual*residual).sum(axis=2).argmin(axis=1)
        result[ys[offset:offset+512],xs[offset:offset+512]]=owners[closest]
    return Image.fromarray(result)


def _staff_mask(base,direction):
    """The crook and every brown shaft pixel belong to the carrying forearm.

    The shaft crosses the coil in the back views. A broad polygon would steal
    the green snake skin beside it; colour eligibility in the measured tube
    preserves the painted staff outline without taking that background with it.
    """
    measure=LAMIA_STAFF[direction]
    tube=Image.new('L',CANVAS)
    ImageDraw.Draw(tube).line([tuple(point) for point in measure['shaft']],fill=255,width=13)
    rgba=np.asarray(base)
    rgb=rgba[:,:,:3].astype(float)
    brown=(rgb[:,:,0]>=rgb[:,:,1]*.95)&(rgb[:,:,0]>=rgb[:,:,2]*.99)
    mask=(np.asarray(tube)>0)&brown&(rgba[:,:,3]>0)
    crook=Image.new('L',CANVAS)
    ImageDraw.Draw(crook).rectangle(measure['crook'],fill=255)
    mask|=(np.asarray(crook)>0)&(rgba[:,:,3]>0)
    return mask


def _warm_painted_mask(base,region,dilation=1):
    """Ivory cloth/spines plus their immediate dark outlines, inside a region."""
    rgb=np.asarray(base)[:,:,:3].astype(float)
    warm=(rgb[:,:,0]>=rgb[:,:,1]*1.02)&(rgb[:,:,1]>=rgb[:,:,2]*1.08)
    mask=Image.fromarray((warm*255).astype('uint8'))
    if dilation:
        mask=mask.filter(ImageFilter.MaxFilter(2*dilation+1))
    return (np.asarray(mask)>0)&(np.asarray(region)>0)&(np.asarray(base)[:,:,3]>0)


def build_parts(slug,direction,base):
    base=base.convert('RGBA')
    if base.size!=CANVAS:
        raise ValueError(f'Expected {CANVAS}, got {base.size}')
    if direction not in 'NESW' or len(direction)!=1:
        raise ValueError(f'Unsupported direction: {direction}')
    if slug=='lamie_lethe':
        specs=deepcopy(LAMIA[direction])
    elif slug=='molosse_styx':
        specs=deepcopy(DOG[direction])
    else:
        raise ValueError(slug)
    names=list(specs)
    labels=Image.new('L',CANVAS)
    draw=ImageDraw.Draw(labels)
    for name in names:
        if specs[name]['polygon']:draw.polygon([tuple(p) for p in specs[name]['polygon']],fill=names.index(name))
    if slug=='lamie_lethe':
        # Cloth ownership is deliberately independent of draw depth: it must
        # follow the upper body, without taking green coil skin beside it.
        cloth=Image.new('L',CANVAS)
        ImageDraw.Draw(cloth).rectangle(LAMIA_CLOTH_REGIONS[direction],fill=255)
        assigned=np.asarray(labels).copy()
        # A brass bracer can overlap this screen-space rectangle. Preserve
        # every already segmented arm pixel instead of gluing it to the waist.
        cloth_pixels=_warm_painted_mask(base,cloth)&((assigned==0)|(assigned==names.index('tail')))
        assigned[cloth_pixels]=0
        labels=Image.fromarray(assigned)
    envelopes=[DOG_TORSO_ENVELOPE[direction]] if slug=='molosse_styx' else [specs['torso']['fill'],LAMIA_CLOTH[direction]]
    labels=_assign_contour_slivers(labels,base,specs,envelopes)
    if slug=='lamie_lethe':
        assigned=np.asarray(labels).copy()
        # Reassert the full cream/gold tabard after contour allocation: tiny
        # painted side hems extend beyond its initial geometric approximation.
        assigned[cloth_pixels]=0
        neck=Image.new('L',CANVAS)
        ImageDraw.Draw(neck).polygon([tuple(p) for p in LAMIA_UPPER_NECK[direction]],fill=255)
        assigned[(np.asarray(neck)>0)&(assigned==names.index('tail'))]=0
        # Whole rigid armor plates follow the arm that actually carries them.
        for region,owner in [(LAMIA_RIGHT_PAULDRON[direction],'upper_arm_right'),
                             (LAMIA_RIGHT_BRACER[direction],'arm_right')]:
            plate=Image.new('L',CANVAS)
            ImageDraw.Draw(plate).rectangle(region,fill=255)
            assigned[_warm_painted_mask(base,plate)]=names.index(owner)
        assigned[_staff_mask(base,direction)]=names.index('arm_left')
        labels=Image.fromarray(assigned)
    else:
        # Back-view spines sit above the torso outline and must never end up
        # on the head through the nearest-contour fallback.
        spine=Image.new('L',CANVAS)
        ImageDraw.Draw(spine).rectangle(DOG_SPINE_REGION[direction],fill=255)
        assigned=np.asarray(labels).copy()
        assigned[_warm_painted_mask(base,spine)]=0
        labels=Image.fromarray(assigned)
    coverage=base.getchannel('A').point(lambda alpha:255 if alpha==255 else 0)
    fur=_color(base,DOG_FUR_SAMPLE[direction]) if slug=='molosse_styx' else None
    snake=_color(base,LAMIA_SKIN_SAMPLE[direction]) if slug=='lamie_lethe' else None
    parts=[]
    for i,name in enumerate(names):
        s=specs[name]
        under=Image.new('RGBA',CANVAS)
        if s['fill']:
            color=fur or snake or _color(base,s['pivot'])
            ImageDraw.Draw(under).polygon([tuple(p) for p in s['fill']],fill=color)
        _cap(under,base,s['pivot'],s['radius'],fur)
        if slug=='lamie_lethe' and name in ('torso','tail'):
            # Shared hidden pelvis socket spans the seam while the upper body
            # breathes, bends or falls around the lower coil junction.
            pelvis_color=snake
            _cap(under,base,specs['torso']['pivot'],24,pelvis_color)
            _cap(under,base,LAMIA_PELVIS_END[direction],18,pelvis_color)
            ImageDraw.Draw(under).line([tuple(specs['torso']['pivot']),tuple(LAMIA_PELVIS_END[direction])],
                fill=pelvis_color,width=36)
        for child in specs.values():
            if child['parent']==name:_cap(under,base,child['pivot'],child['radius']+2,fur)
        # Complete the hidden limb between joints instead of exposing two
        # detached circles. The source painting always renders above this.
        for child in specs.values():
            if child['parent']==name and (name.startswith('leg_') or name.startswith('upper_arm_')):
                ImageDraw.Draw(under).line([tuple(s['pivot']),tuple(child['pivot'])],
                    fill=fur or _color(base,s['pivot']),width=2*min(s['radius'],8))
        if slug=='lamie_lethe' and name=='tail':
            # The upper neck bends with the torso. A fixed reconstruction above
            # its hinge would leave an upright green stump after the fall.
            lower=Image.new('L',CANVAS)
            ImageDraw.Draw(lower).rectangle((0,specs['torso']['pivot'][1]-8,512,384),fill=255)
            under.putalpha(ImageChops.multiply(under.getchannel('A'),lower))
        under.putalpha(ImageChops.multiply(under.getchannel('A'),coverage))
        mask=labels.point(lambda v,index=i:255 if v==index else 0)
        piece=base.copy()
        piece.putalpha(ImageChops.multiply(mask,base.getchannel('A')))
        combined=under.copy()
        combined.alpha_composite(piece)
        part={'name':name,'image':combined,'source_image':piece,'underpaint':under,
              'pivot':list(s['pivot']),'parent':s['parent'],'z':s['z']}
        if s['end']:part['end']=s['end']
        parts.append(part)
    return sorted(parts,key=lambda p:p['z'])
