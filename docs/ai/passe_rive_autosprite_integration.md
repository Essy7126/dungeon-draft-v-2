# Passe-rive — intégration du 13 septembre 2026

Intégration terminée dans l'arbre de travail, sans commit. HEAD vérifié :
`c98436df9339099076e683979f79c7cefd7ae5ea`. Arbre partagé déjà modifié
(Achille AutoSprite, six départs, audio, Studio) : ces travaux sont conservés.

## Comportement

- Nouvelle partie → troisième apparence, Passe-rive. Même aventure et mêmes
  statistiques qu'Achille ; sélection conservée dans la sauvegarde, le Seuil,
  les haltes, les combats et le portrait du HUD.
- 66 PNG originaux intégrés sans modification ; alpha déjà transparent.
  Le second hit/down est identique et n'est pas dupliqué. Atlas de 120 clips,
  neuf familles, huit orientations, sans miroir.
- Combat : marche pour 1–2 cases, course dès 3 cases. Durée par segment :
  0,72 s / 0,36 s. Au Seuil et dans les haltes, choix selon la longueur réelle
  du trajet (seuil de 300 pixels source × échelle), fixé jusqu'à l'arrivée.
- Phase des pas calculée à partir de la distance réellement parcourue,
  conservée aux virages et immobile quand le personnage s'arrête.
- Arc pour les tirs/frappes ordinaires ; dash pour la mobilité ; dodge pour
  la garde et les esquives reçues ; jump pour les frappes de zone utilisant
  sweep, Moisson ou Fauchage. Réaction aux coups et mort dédiées.
- Saut fourni uniquement vers W et SW : ces deux clips sont utilisés ; les
  six autres orientations emploient l'esquive de leur propre direction.
  Aucun sprite de saut supplémentaire n'est inventé.

## Ancrage

Le générateur mesure le milieu des semelles sur une pose neutre par clip,
en excluant l'arc et le carquois. Pivot et échelle restent constants pendant
le clip. Pour marche/course, axe X à 128 et sol au maximum du cycle complet :
l'envol reste visible, sans recentrage de chaque image. L'ombre reste au sol.
Les cadres neutres sont normalisés sur une hauteur de référence de 214 pixels.
Les cycles de marche/course éliminent la répétition du même cycle dans la planche.

Il s'agit d'un calage de sprites raster, sans verrouillage IK des pieds.
La recherche sur l'ancien devblog Ankama n'a pas permis de consulter une source
directe exploitable sur l'algorithme de Dofus ; aucune reproduction de cet
algorithme n'est revendiquée. La documentation Godot confirme l'usage de
[offset et set_frame_and_progress](https://docs.godotengine.org/en/stable/classes/class_animatedsprite2d.html)
pour le placement du dessin et la conservation de phase.

## Fichiers

- `tools/passe_rive_autosprite/` : générateur, tests stricts et captures réelles.
- `assets/characters/PasseRive/autosprite_v1/` : originaux, atlas, portrait,
  manifeste avec SHA-256, séquences et géométrie de chaque clip.
- `characters/achilles/2d/passe_rive_autosprite_backend.gd`,
  `characters/achilles/passe_rive_autosprite_view.gd`, scène PasseRive et profil
  `data/visuals/achilles/passe_rive_autosprite_profile_v1.tres`.
- Catalogue de sélection, `RunHeroVisualVariants`, déplacements du Seuil et
  des haltes ; sondes de validation communes adaptées aux clips Passe-rive.
- `test/unit/test_passe_rive_autosprite.gd` et indices de sélection historique
  rendus indépendants de l'ajout de la troisième apparence.

## Preuves

- Import et GUT strict : **9 tests, 447 assertions, PASS**, zéro erreur moteur.
  `artifacts/dev/20260913-142320-passe-rive-autosprite-34958094/gut-strict-report.json`.
  Vérifie hash/alpha, variantes et sauvegarde JSON, pivots, marqueurs uniques
  sur 8 directions, interruptions, arrivée du dash, réactions, mort et allures.
- Parcours public réel : sélection → Seuil → marche proche → course lointaine
  → arrivées : **16 contrôles PASS** après le réglage final de cadence.
  `artifacts/dev/passe_rive_autosprite/entry/report.json`.
- Scénarios de combat réels (coûts, marqueurs, dégâts, VFX, arrivée et repos) :
  rapports et images dans `artifacts/dev/passe_rive_autosprite/`, sous-dossiers
  `combo_E_timing`, `shot_N_visual`, `wrath_combo_S_visual` (saut SW natif),
  `hit_death_W_visual` (coups, mort et disparition).
- Vérification élargie : **161 / 164 tests passent**, verdict strict **FAIL**.
  `artifacts/dev/20260913-141904-passe-rive-autosprite-2ff4d2f6/gut-strict-report.json`.
  Trois tests de `test_catabase_threshold.gd` attendent encore le combat
  immédiatement après la porte, alors que le parcours de préparation des six
  départs présent dans l'arbre diffère. Cette suite rapporte aussi 8 textures
  RID et 177 ressources encore en usage à la fermeture. Ne pas la présenter
  comme verte et ne pas modifier l'autre chantier pour contourner ces échecs.

La capture graphique utilise désormais un APPDATA neuf et court par lancement
pour les longs chemins du cache de shaders sous Windows. Une première erreur
de création de cache du tir reste archivée dans `shot_N_visual/cache_failure*`.

Suite éventuelle : fournir les six orientations manquantes de jump pour
remplacer les replis ; réconcilier les tests du Seuil avec le chantier des
six départs et traiter les ressources retenues dans sa suite élargie.
