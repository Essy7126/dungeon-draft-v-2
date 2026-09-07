# Spectre errant — intégration en sprites V1

**Statut : intégré et vérifié en combat réel dans la Cour des Sources et Catabase II, le 5 septembre 2026.**

Le [master visuel](spectre_greatsword_concept_v1.md) est décliné en quatre orientations
dessinées séparément. Le visage reste obscurci par la capuche ; les vêtements gris
et noirs sont suspendus, sans pieds visibles. Le personnage conserve une épée à
deux mains. Aucun miroir, rig 3D, déplacement du cutout ou déformation artificielle
n'est utilisé pour simuler une pose.

## Animation et ancrage

| Animation | Images par direction | Cadence et comportement |
| --- | ---: | --- |
| Garde | 1 | Pose canonique arrêtée. Le 1 fps du SpriteFrames est une métadonnée ; le repos ne tourne pas. |
| Glissement | 4 | 6 images/s ; la phase continue entre les cases et les changements de direction. Translation de 0,28 s/case portée par Battle. |
| Coupe lourde | 8 | 10 images/s, 0,8 s au total. Impact unique à l'entrée de l'image 3, soit 0,3 s. Retour à la pose canonique. |

La toile commune mesure **512 × 384**, avec une ancre **(256, 320)** correspondant
au sol sous le corps. Le bas de robe et la pointe de l'épée ne servent pas à
recaler les poses. Les quatre directions logiques sont `+X = E`, `+Y = S`,
`-X = W`, `-Y = N` ; E/S sont les vues de face et N/W les vues de dos.

Le [profil visuel](../../data/visuals/spectre_greatsword/spectre_greatsword_sprite_profile_v1.tres)
applique `0,35 × 1,05` au sprite, avant le facteur de présentation peinte de 1,58.
L'ombre reste celle du moteur, indépendante de la robe. Le runtime n'en ajoute pas
une seconde.

La [vue dédiée](../../characters/enemies/spectre_greatsword/SpectreGreatswordIsoUnitView.tscn)
échantillonne son unique AnimatedSprite2D avec une horloge monotone respectant
la pause et `Engine.time_scale`. Un changement de direction pendant la frappe
attend la récupération. Une annulation ou une mort reçue lors de l'impact empêche
toute fin d'action devenue obsolète. La mort utilise une disparition douce de
**0,32 s**, sans translation ni rotation. Le [contrat public](../../characters/enemies/spectre_greatsword/README.md)
reste compatible avec UnitView.

## Présence dans le jeu

La [fiche Spectre errant](../../data/units/enemies/spectre_greatsword.tres) définit
64 PV, 2 PA, 3 PM et une IA de mêlée. Son sort
[Coupe lourde](../../data/spells/enemies/spectre_heavy_cleave.tres) coûte 2 PA et
inflige 18 dégâts physiques à une cible ennemie adjacente. Un spectre rejoint
deux escarmoucheurs dans la [rencontre de salle 2](../../data/encounters/odyssey_room_02_encounter.tres).

Le [portrait](../../assets/characters/spectre_greatsword/sprites_v1/spectre_portrait.tres)
réutilise la garde E, cadrée sur la capuche et les épaules dans la région
`Rect2(204, 82, 126, 144)` du même atlas. Il n'introduit pas un second modèle.

## Production et contrôles

Les quatre sources PNG avec alpha réel proviennent d'ImageGen intégré. Les prompts
exacts sont conservés pour [N](../../art/source/characters/spectre_greatsword/sprites_v1/generation_N_prompt.txt),
[E](../../art/source/characters/spectre_greatsword/sprites_v1/generation_E_prompt.txt),
[S](../../art/source/characters/spectre_greatsword/sprites_v1/generation_S_prompt.txt) et
[W](../../art/source/characters/spectre_greatsword/sprites_v1/generation_W_prompt.txt).

Le [pipeline mécanique](../../tools/spectre_sprite_pipeline/README.md) extrait les
douze silhouettes complètes de chaque source, conserve leurs bords RGBA et refuse
la perte d'un élément opaque. L'[alignement explicite](../../tools/spectre_sprite_pipeline/alignment.json)
fournit douze ancres et une échelle fixe de 0,7 par direction, sans normalisation
de taille par pose. Les quatre atlas de 2 048 × 1 152 sont assemblés par copie
brute des lignes RGBA, puis encodés une seule fois pour éviter les arrondis dus à
une seconde composition alpha.

Le [manifeste](../../assets/characters/spectre_greatsword/sprites_v1/manifest.json)
contient les SHA-256 des sources, alignements, atlas et ressources Godot.
**Les 48 régions d'atlas ont été relues et comparées aux RGBA préparés sans différence.**
Des contacts sur fonds clair et sombre et des GIF de glissement/coupe sont fournis
dans le même répertoire pour la revue graphique.

Les tests ciblés confirmés passent :

- [Assets](../../test/unit/test_spectre_sprite_assets.gd) : 2 tests.
- [Runtime](../../test/unit/test_spectre_sprite_runtime.gd) : 10 tests, dont repos fixe,
  continuité du glissement, impact/fin uniques, annulation, mort et pause.
- [Gameplay](../../test/unit/test_spectre_gameplay.gd) : 11 tests.

## Vérification en jeu — 5 septembre 2026

Le [harness](../../tools/spectre_sprite_validation/README.md) utilise la rencontre,
le déploiement autorisé, les déplacements payés en PM et le contrôleur de fin de
tour du jeu. Les actions ennemies viennent de l'IA : aucun déplacement du spectre,
appel de lecture d'animation ou dégât n'est injecté par le scénario de contrôle.

Trois passes graphiques Godot 4.7.1 / Forward+ se terminent avec `ok: true`,
aucune erreur de validation et un code de sortie 0 :

| Passe | Résultat |
| --- | --- |
| [Cour des Sources sans capture](../../artifacts/spectre_sprite_validation_v1/timing/runtime_validation.json) | Trois cases en 855,5 ms puis une coupe ; release à 302,3 ms, fin à 805,3 ms ; 18 dégâts, 2 PA. |
| [Cour des Sources avec capture](../../artifacts/spectre_sprite_validation_v1/gameplay_clip/runtime_validation.json) | Glissement E puis S, attaque S, retour à idle S. 49 images du viewport réel. |
| [Catabase II avec capture](../../artifacts/spectre_sprite_validation_v1/catabase_ii_clip/runtime_validation.json) | Rencontre `catabase_room_02`, scène RegisteredTerrainBattle et terrain Ashen de production ; trois cases puis attaque W, un impact de 18 dégâts et retour à idle W. 48 images du viewport réel. |

À chaque passe : un seul signal de release, un seul événement de dégâts, une seule
fin d'attaque, PV intacts jusqu'au release, ancre locale inchangée. Les contrôles du
repos avant/après observent 0 px de dérive et aucune pose inattendue. La passe sans
capture fournit la mesure de cadence ; les lectures GPU des passes visuelles ne
servent pas de référence de performance.

La revue visuelle confirme l'échelle à côté d'Achille, la lecture du col gris et de
la capuche sur les deux terrains, la continuité des quatre gardes, les vues avant
et arrière pendant les actions, le portrait et l'absence de lame coupée au bord
des atlas. Elle ne constitue pas un audit de tous les cas d'occultation de la carte.

Aperçus issus exclusivement du vrai viewport, recadrage fixe agrandi 2× :

- [Déplacement et coupe dans la Cour des Sources](../../artifacts/spectre_sprite_validation_v1/gameplay_clip/clip/spectre_gameplay.gif), 2,110 s encodées pour 2,108 s enregistrées.
- [Déplacement et coupe dans Catabase II](../../artifacts/spectre_sprite_validation_v1/catabase_ii_clip/clip/spectre_gameplay.gif), 2,120 s encodées pour 2,117 s enregistrées.

## État des vérifications élargies

Le [rapport GUT](../../artifacts/spectre_sprite_validation_v1/gut/gut.junit.xml)
contient 62 tests : 51 passent, 11 échouent. Les six suites courantes passent
entièrement, soit **42/42 tests** : les 23 tests du spectre, les 10 tests de sprites
d'Achille, les 4 tests d'audit des ennemis Catabase et les 5 tests de contenu Catabase.

Les 11 échecs sont tous dans `test_odyssey_achilles_solo_run.gd` (9/20 passent).
L'audit en lecture seule les rattache à des attentes anciennes : 6 tests de l'ancien
kit lance/avance/balayage/garde, 3 tests d'économie (8 objets au lieu du catalogue
actuel de 24, pool et destinataire de récompense), 1 test d'anciennes disciplines,
1 test imposant encore le backend 3D d'Achille. Le test de roster actualisé pour le
spectre passe. Ces anciennes attentes ne sont pas réécrites dans cette intégration.

Godot signale encore des ressources et RID non libérés à la fermeture des scènes,
comme lors des contrôles précédents du projet. Les trois passes fonctionnelles
n'ont aucune erreur de script ; leurs codes de sortie sont 0. La fermeture n'est
pas présentée comme exempte d'avertissements.
