# Prompts Passe-rive combat v2

Outil : image_gen.imagegen intégré. Références : exports originaux PasseRive attack/jump SW. Pas de CLI de génération.

Les prompts complets des huit directions et des corrections retenues figurent
dans `art/source/passe_rive/combat_v2/generation.json`. Les deux essais de damier
ci-dessous décrivent le démarrage du travail ; les planches finales utilisent un
fond magenta retiré par script après l’accord explicite de l’utilisateur.

## SW initial

Use case: stylized-concept. Asset type: production 2D isometric game character sprite sheet, new combat poses.
Input image 1 is the definitive Passe-rive archer identity, costume, bow, SOUTHWEST orientation and rendering reference. Input image 2 demonstrates the same character jumping and the correct camera. Create NEW poses for THIS EXACT character, matching its small understated dark painted game-sprite rendering, proportions and elevated orthographic camera, not a redesign.
Deliver a square 1024x1024 PNG with TRUE TRANSPARENT alpha background. Exactly FOUR columns and FOUR rows, 16 isolated full-body sprites in 256x256 equal cells, no grid lines, labels, text, glow, shadows or scenery. Every sprite faces SOUTHWEST (toward lower left), same orientation as both references. Identical scale throughout: standing body about 185 pixels tall, root center at x=128 in each cell, grounded boot soles around y=232. All bow limbs/arrows fully within each cell. Leave clear gaps between sprites.
Identity invariants: slim adult pale masked face under dark navy teal pointed hood, muted sage grey scarf and asymmetrical short shoulder cape, deep teal tunic, off-white narrow sash, charcoal fitted trousers, black gloves and boots, ochre bronze wrist/ankle cuffs, wooden curved bow, long brown quiver behind. Keep exact costume cut, head/body ratio, handedness and lighting from reference. Anatomically correct hands with ONE bow held by forward arm, rear hand draws string; one arrow when aiming. Never mirror costume or change weapon. Scarf secondary motion only.
Reading row-major:
0 combat ready: standing balanced, bow lowered across hips, relaxed string hand close to chest.
1 quick draw start: lifts bow to chest, nocks arrow, rear elbow begins pulling.
2 quick aim: bow extended southwest at shoulder height, string drawn to cheek.
3 quick release: arrow has departed, string straight, rear hand recoils a little, both feet planted.
4 charged preparation: stance widens, front knee bent, bow rising.
5 charged draw: deep stable low stance, strong torso counter-rotation, string partially drawn.
6 charged held aim: deep grounded half-kneeling archer lunge, one knee low but feet credible, full bow draw southwest, firm aim.
7 charged release: same low stance, arrow gone, string straight, chest and rear shoulder recoil.
8 aerial anticipation: balanced crouch, bow held forward angled upward.
9 aerial takeoff: rising, legs extend from ground, bow lifts toward sky southwest.
10 aerial aim at apex: both boots clearly about 28px above their resting ground, knees bent, bow drawn diagonally upward toward southwest sky.
11 aerial release at apex: same airborne position, arrow gone, bowstring straight, rear arm recoils.
12 descending: knees prepare to land, bow lowers, boots about 12px above ground.
13 landing: boots back at EXACT ground baseline, knees deeply compress, scarf settles.
14 recovery: rises from landing, bow lowers toward hips.
15 return to ready: same grounded resting armed pose as sprite 0.
The result is a precise sprite animation production asset. Preserve one character throughout, consistent camera and size, clear meaningful motion, no cinematic effects. Actual transparent background, not a rendered checkerboard.

## Correction SW

Edit this exact 4x4 character sprite sheet. Keep the character's identity, style, all16positions and same framing. Two surgical corrections: (1) Remove the entire gray-white checkerboard backdrop and export actual PNG transparency (alpha=0 in every background pixel), NOT painted checker squares, NOT white opaque background. Transparent spaces inside the bow must also be transparent. (2) In row3 columns2,3,4 only, make the character raise BOTH arms and tilt the entire bow and arrow aim about60degrees UPWARD into the sky toward upper left. This is an airborne skyward archery shot: the arrow tip should be high above the hood, the bow grip above face height; bow extended, string pulled from grip down toward cheek. At row3 column3 keep arrow fully drawn, at column4 arrow departed and string straight. Keep the jumping body/legs unchanged. All other poses unchanged. No VFX, captions, ground shadow or extra objects. Output actual alpha transparency.
