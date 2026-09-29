# Passe-Rive — Incantation intégrée S26

> Historique SE du 27 septembre. Depuis S31, les huit directions sont dessinées et Grâce du bronze utilise S30 : [état actuel et preuves](../passe_rive_s31/incantation/README.md).

Le prototype approuvé est branché dans le backend public de Passe-Rive en mode Cartes. Sept liaisons explicites : `cc2_g01` Garde ferme, `cc2_g08` Bastion vivant, `cc2_l02` Grâce du bronze, `cc2_a09` Sommeil marqué, `cc2_t03` Sceau ombreux, `cc2_t06` Jardin de givre et `cc2_t09` Résonance du sceau. Les versions améliorées ont les mêmes identifiants de geste.

## Comportement

- SE : atlas [incantation.png](../../../assets/characters/PasseRive/sprites_s26/incantation.png), 12 dessins en 1,15 s, ouverture des paumes et effet réel à 590 ms (index 6).
- Autres directions : ancien geste magique `t_mark` avec sa source directionnelle existante et son timing propre. Le diagnostic conserve `pending_direction` et `fallback_reference=t_mark`. Aucune fausse rotation de la planche SE.
- Les recettes VFX des cartes restent distinctes et sont jouées par le routeur de production après résolution. Les trois esquisses de VFX du prototype ne sont pas importées dans les règles du jeu.
- Marche, ruée, repos natif, attaques à l'arc, lames, coup de talon et crochet conservent leurs propres animations.
- Annulation, changement de mode et extinction du backend masquent le nouveau corps ; un seul corps est visible à la fois.

## Cohérence visuelle

Hauteur de référence partagée : 214 px × échelle du profil. L'atlas source a une hauteur neutre de 330 px. La projection peinte initiale était trop large ; une correction **X = 0,80 / Y = 1,00**, identique pour toutes les poses, rapproche la silhouette du repos sans repeindre le source approuvé. Les mains et le point d'appui utilisent la même transformation. Aucun calcul de taille par pose ou mélange transparent de deux silhouettes.

Palette par matière avec les mêmes paramètres pendant toute l'action. Point d'appui enregistré sur le pied du repos SE. Le banc montre le raccord repos → incantation → repos en vraie scène de combat. Des différences de dessin de capuche et de tissu subsistent : ce réglage ne transforme pas la source en une reconstruction anatomique parfaite du repos.

## Provenance

Outil graphique : **imagegen intégré**, génération avec fond transparent. Prompt exact conservé dans [prompt_v01.txt](prompt_v01.txt). Références : dessin précédent de Passe-Rive S25 et vue trois-quarts du modèle 3D. Références de gestes consultées : [Féca 1.29](https://www.youtube.com/watch?v=2yPRE9r9x-s) et [Sram 1.29](https://www.youtube.com/watch?v=zKkve2aJRIk), démonstrations Modus. Ce sont des dessins originaux de Passe-Rive, pas des assets extraits de Dofus.

SHA-256 PNG : `bd263d169b46a1f1be625debc78b6b8a6b7a27c684361137c69f101ee904debf`. Les métadonnées de découpe, contacts et palette sont dans `assets/characters/PasseRive/sprites_s26/incantation.json`. Le statut prototype présent dans ce JSON décrit sa génération d'origine ; les attributions runtime sont exclusivement définies dans `passe_rive_card_bindings.gd`.

## Rejouer et vérifier

```powershell
./tools/class_card_vfx/passe_rive_s26/play.ps1
./tools/class_card_vfx/passe_rive_s26/play.ps1 -Capture
./dev.ps1 test passe-rive
```

Le banc utilise le vrai profil public, sans remplacement de backend. La main et les positions sont préparées, l'IA est suspendue et la caméra agrandie 2,4×. Sommeil marqué/Résonance reçoivent une marque préalable dans la fixture ; Grâce du bronze part avec des PV manquants. Les règles, PA et consommations sont ceux des vraies cartes.

Validation du 27 septembre 2026 :

- **26 tests / 3 547 assertions PASS**, aucune erreur : `artifacts/dev/20260927-201232-test-passe-rive-2af44e6b/gut-strict-report.json`.
- **14 lancers / 362 contrôles PASS** : `artifacts/dev/passe-rive-incantation-20260927-201405/report.json`. 154 captures, dont 111 images du film. Log sans erreur.
- Déclenchement unique sur pose 6 à 590 ms, y compris après un saut temporel ; pas d'effet anticipé, échelle constante sur les 12 poses et plusieurs tailles de profil, annulation sans effet tardif, retour au repos, conservation des armes et orientations de repli.
- Les captures montrent coûts réels, copies consommées, dégâts, boucliers, soin, marque consommée pour la stase et terrain de glace.
- GIF documentaire : horloge cumulée quantifiée à 10 ms, écart de −1 ms hors pause de fin volontaire.

Les suites globales Cartes ne sont pas déclarées validées ici. Le changement porte sur les gestes et leur intégration ; les règles n'ont pas été modifiées.

Incidents conservés : premier import avant disponibilité du PNG dans le cache ; premier test directionnel supposant à tort une clé spéciale pour E/W (ces vues utilisent l'atlas de base existant) ; import ensuite bloqué par une inférence de type dans un nouveau contrôleur de Permutation partagé. Ce dernier a reçu uniquement `var swapped: bool = (...)`, puis import et validation Passe-Rive ont réussi. Aucun comportement de Permutation n'a été changé.
