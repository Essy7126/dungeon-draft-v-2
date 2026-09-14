# Passe-rive — six gestes jouables, V1

**Palette courante : [Fauche](../passe_rive_fauche_v1/README.md) ajoutée sur 0.** Huit poses, lance tenue au talon, balayage circulaire et traînée en deux profondeurs. **Dix gestes, 50 poses peintes et 63 images chargées**, navigateur et Godot vérifiés. Cadre propre à Fauche : 1152×768 / pivot (576,662). Les notes suivantes conservent l’historique des lots précédents.

**Ajout courant : [Moisson vitale](../passe_rive_vital_harvest_v1/README.md), touche 9.** Animation sans arme, légère lévitation, paumes vertes et petite explosion/traînée rouge vers l’adversaire. La palette compte **neuf gestes, 42 poses et 55 images chargées**. Les notes ci-dessous sont l’historique des lots précédents.

**Dernier ajout : [Trait d’ivoire](../passe_rive_ivory_bow_v1/README.md), touche 8.** Charge longue, appui arrière, transformation ivoire et tremblement du bras. La palette compte maintenant **huit gestes, 36 dessins, 49 images chargées**. Les notes suivantes conservent l’historique des lots précédents.

**Ajout du 11 septembre : [Tir céleste à l’arc](../passe_rive_bow_v1/README.md), touche 7.** Six nouvelles poses, pleine tension tenue, trajectoire courbe et repos à l’arc. La palette étendue contient désormais sept gestes / 30 dessins, et les contrôles couvrent 43 images. Les sections ci-dessous décrivent le socle initial.

10 septembre 2026. **Essai artistique jouable, une direction trois-quarts droite.**

[Ouvrir le terrain d’essai](http://127.0.0.1:8734/files/passe_rive_spells_v1/review.html) · [24 poses](../../../../../artifacts/spine_trial/passe_rive_spells_v1/poses_contact.png) · [Kit ZIP](../../../../../artifacts/spine_trial/passe_rive_spells_v1/passe_rive_spells_v1.zip).

## Palette

| Touche | Action | Geste | Durée / déclenchement |
| --- | --- | --- | --- |
| 1 | Frappe du Péléide | Armer au bassin, estoc, retrait, garde | 400 / 100 ms |
| 2 | Percée fulgurante | Comprimer, pousser, amortir, se relever | 430 / 100 ms |
| 3 | Tir du Pélion | Préparation haute, tension, projection, accompagnement | 510 / 250 ms |
| 4 | Garde d’airain | Lever le bouclier, ancrer les jambes, maintenir | 600 / 200 ms |
| 5 | Moisson des rives | Armer haut, traverser en arc, accompagner bas | 515 / 150 ms |
| 6 | Heurt du passeur | Charger, avancer l’épaule, percuter au bouclier, revenir | 455 / 195 ms |

Les quatre premières familles viennent du catalogue actuel. Le Tir **propose une projection de lance spectrale** : cette interprétation visuelle reste à valider. Moisson reprend la famille Balayage ; Heurt propose un geste supplémentaire. Le laboratoire applique des chiffres de test ; aucune ressource Spell ou règle de campagne n’a été modifiée.

Le navigateur permet de bouger avec les flèches/ZQSD ou par clic au sol, lancer par touches 1–6 ou boutons, réinitialiser avec R, ralentir, couper les effets/la secousse, examiner chaque pose et activer un son facultatif. La direction du personnage reste fixe : le déplacement libre sert à placer les essais et ne représente pas un jeu complet de directions.

## Fichiers utilisables

- [delivery/manifest.json](delivery/manifest.json) : quatre poses par action, durées, pivot, instant de déclenchement, portées du laboratoire.
- [delivery/sprite_frames.tres](delivery/sprite_frames.tres) : six animations de sorts + garde au repos + marche V3. Les événements d’impact sont dans le manifeste ; SpriteFrames ne les porte pas seul.
- `delivery/frames/` : 24 PNG RGBA de sorts, 12 de marche réenregistrés, une pose idle ; `*_atlas.png` : atlas 2×2 par action ; `*.apng` : boucles de présentation avec garde commune.
- [Scène F6 du dépôt](../../../../../tools/labs/passe_rive_spells_v1/PasseRiveSpellsLab.tscn).
- [Projet Godot autonome](../../../../../artifacts/spine_trial/passe_rive_spells_v1/godot/project.godot), également dans le ZIP.

Cellules 768×768, pivot `(320,662)`, atlas 1536×1536. Ce sont des cellules avec marge pour les armes : le personnage debout occupe environ 450–460 pixels de hauteur. Les feuilles originales mesurent 1254×1254. Réduction uniforme par action, puis translations des poses ; aucun upscale IA ou déformation des membres.

## Méthode et corrections

Sept appels à **ImageGen intégré** : six feuilles de quatre poses, puis correction ciblée de la lance sur la deuxième pose de Garde. Le canon est [la référence choisie](../passe_rive_v1/reference_choisie.png). Aucun rig 3D n’a produit ces gestes. L’idée reprise de la recherche est de privilégier des poses décisives et des durées contrastées, avec effets séparés.

Les feuilles RGB originales, [prompts exacts](generation_prompts.json), [prompt correctif](guard_fix_prompt.txt), [coordonnées et timings](../../../../../tools/passe_rive_spells/layout.json) sont conservés. Le détourage par seuil de blanc a été rejeté : il abîmait le masque et le tissu ivoire. Le détourage final utilise **rembg / birefnet-general-lite**, avec décontamination et suppression des fragments déconnectés d’une pose voisine. L’autorisation logicielle venait déjà de l’utilisateur.

Le test a également révélé un raccord numérique : à la frontière de deux poses, un impact pouvait partir pendant la préparation. La sélection de pose et le déclenchement emploient désormais une tolérance cohérente. Un contrôle spécifique conserve ce cas.

## Vérifications

- Atlas comparés pixel par pixel à chaque PNG, dimensions et marges contrôlées : [rapport d’assets](cutout_report.json).
- Six entrées clavier, déclenchement unique, fin de récupération, coup hors de portée, ruée bloquée devant une cible, file d’entrée tardive, remise à zéro des projectiles : [rapport navigateur](../../../../../artifacts/spine_trial/passe_rive_spells_v1/verification.json).
- Images chargées, contrôle des effets/ralenti/fond, déplacement, captures à largeur 390 px sans débordement, aucune erreur JS ou requête échouée.
- Import natif Godot 4.7.1 et six exécutions dans la scène autonome : [log d’import](../../../../../artifacts/spine_trial/passe_rive_spells_v1/godot_import.log), [log d’exécution](../../../../../artifacts/spine_trial/passe_rive_spells_v1/godot_smoke.log).
- Formatage des deux scripts Godot vérifié avec le formateur du projet.

L’essai natif ne prouve pas l’intégration en campagne, et ces contrôles ne valent pas approbation artistique. Les effets du laboratoire Godot sont une version simple de ceux du navigateur.

## Limites à juger en jouant

Quatre dessins par geste : rythme volontairement tenu, pas animation continue à 24 dessins/seconde. Certains retours en garde restent abrupts ; costume, tête et prise de lance varient légèrement. La Garde au repos est une pose de récupération, pas un nouvel idle animé. La marche V3 est conservée avec ses limites précédentes. **Aucune validation de perfection, des appuis peints ou des autres directions n’est revendiquée.**

## Reproduction

Depuis la racine : `tools/passe_rive_spells/cutout.py`, puis `build_assets.py`, puis `package.py`, avec le Python du projet. Les mattes déjà calculées sont conservées en cache ; changer les feuilles/rectangles demande de versionner ou régénérer le cache concerné. `verify.mjs` utilise le serveur local 8734 et Chrome. `smoke.gd` est exécuté dans le projet autonome après import. Les scripts et la scène restent isolés dans ce lot.
