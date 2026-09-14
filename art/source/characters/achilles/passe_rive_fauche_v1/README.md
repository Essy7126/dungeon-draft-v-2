# Passe-rive — Fauche V1

11 septembre 2026. Huit nouvelles poses peintes, essai jouable sur **0**, en complément des neuf gestes précédents. Une direction, revue artistique attendue.

[Jouer Fauche](http://127.0.0.1:8734/files/passe_rive_spells_v1/review.html?spell=fauche) · [Animation en jeu](../../../../../artifacts/spine_trial/passe_rive_spells_v1/fauche_live.gif) · [Planche sur fond clair](../../../../../artifacts/spine_trial/passe_rive_spells_v1/fauche_contact.png).

La main droite tient le manche près du talon ; le bouclier reste dans le dos. La lance passe derrière le personnage, coupe vers la droite, traverse le premier plan puis finit à gauche avant le retour en garde. Le bassin et les genoux accompagnent le transfert d’appui.

## Chronologie

| Étape | Durée | Début |
| --- | ---: | ---: |
| Charger l’appui arrière | 140 ms | 0 ms |
| Passer derrière le corps | 95 ms | 140 ms |
| Engager le bassin | 65 ms | 235 ms |
| Faucher | 65 ms | 300 ms |
| Traverser devant | 70 ms | 365 ms |
| Amortir sur l’autre jambe | 100 ms | 435 ms |
| Freiner la lance | 110 ms | 535 ms |
| Revenir en garde | 155 ms | 645 ms |

Geste de 800 ms, impact à 300 ms, arrêt de 42 ms si une cible est touchée. Le laboratoire applique 26 dégâts, portée 260, une fois par cible dans la zone. La campagne conserve ses règles. Le dernier dessin sert aussi d’idle.

## Sources et montage

- **ImageGen intégré**, deux appels : [prompt initial](generation_prompt.txt), puis [correction du balayage](sweep_fix_prompt.txt). Pas de CLI/API payante ni d’animation 3D.
- [Première sortie](fauche_raw.png) conservée : armé trop haut et accent d’estoc. [Planche retenue](fauche_rgb.png), 1086×1448, après correction du passage derrière la taille et de la pose en raccourci vers la caméra.
- Fond en damier peint dans le RGB : détourage logiciel autorisé avec Birefnet, vérification sur fonds clair et sombre. Masques et rapport dans le dossier commun des sorts.
- [Paramètres](layout.json) : même échelle 1,45 pour les huit dessins, recalage de la pose entière au sol ; aucun remplacement, déformation ou interpolation des membres.
- Cellules **1152×768**, pivot **(576,662)**, atlas 2304×3072. Ce cadre élargi conserve la lance sans réduire le corps. Les consommateurs lisent dimensions et pivot du geste ; les autres gestes conservent leur cadrage.
- [Fichiers livrés](../passe_rive_spells_v1/delivery/) : `frames/fauche_00.png` à `fauche_07.png`, `fauche_atlas.png`, `fauche.apng`, `sprite_frames.tres`. L’APNG expose les dessins seuls.
- Traînée séparée : rubans jade/ivoire terminant sur les pointes peintes, derrière le corps puis devant ; les positions précédentes s’effacent en 150 ms. Les scripts `fauche_fx.mjs` et `fauche_effect_layer.gd` produisent ces effets, qui ne sont pas intégrés au SpriteFrames seul.
- [Projet Godot autonome](../../../../../artifacts/spine_trial/passe_rive_spells_v1/godot/project.godot) · [Kit ZIP](../../../../../artifacts/spine_trial/passe_rive_spells_v1/passe_rive_spells_v1.zip).

## Contrôles réalisés

- Dix actions, **50 poses peintes + 12 images de marche + 1 idle = 63 images** ; atlas comparés pixel par pixel, aucune pose coupée au bord de sa cellule.
- [Navigateur](../../../../../artifacts/spine_trial/passe_rive_spells_v1/verification.json) : touche 0, huit poses, impact à 300 ms, nœud fixe, une seule touche par cible avant/arrière, retour à la bonne garde, dix commandes et régressions arc/Moisson vitale. Aucune erreur de console ou requête manquante ; mobile sans débordement.
- [Visuel navigateur](../../../../../artifacts/spine_trial/passe_rive_spells_v1/fauche_visual_checks.json) : 4286 pixels de traînée arrière et 8436 pixels de traînée avant visibles par rapport au même dessin sans effets. Captures sur décor et planche claire inspectées.
- [Import Godot](../../../../../artifacts/spine_trial/passe_rive_spells_v1/godot_import.log) et [test des dix actions](../../../../../artifacts/spine_trial/passe_rive_spells_v1/godot_smoke.log) réussis ; ordre des couches et pivot de récupération vérifiés.
- [Rendu GPU Godot](../../../../../artifacts/spine_trial/passe_rive_spells_v1/fauche_gpu.log) : deux couches visibles (4221 et 8841 pixels modifiés), aucune erreur ; captures inspectées.
- GIF en jeu : 75 captures à 50 Hz, 1500 ms, 559035 octets ; images identiques regroupées sans modifier la durée.

Le contrôle du nœud et des cadres ne prouve pas des contacts biomécaniques parfaits dans chaque dessin généré. Volumes, prise en raccourci et rythme restent à juger en jouant. Le laboratoire change instantanément d’équipement entre familles.
