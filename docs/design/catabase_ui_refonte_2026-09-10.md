# Refonte des interfaces — 10 septembre 2026

## Direction acceptée

Références : douze captures BG3 fournies dans la conversation. L'utilisateur
souhaite remplacer la palette et l'habillage Catabase jugés trop datés.

- Noir chaud `#100f0e`, brun fumé `#211c18`.
- Texte ivoire `#eee5d2`, texte secondaire `#b7a58d`.
- Or patiné `#8b714c`, accents clairs `#d6c29a`.
- Sélections et actions principales bleu pétrole `#102d34`, focus clair distinct.
- Bordures fines, relief atténué et ornements concentrés aux contours.

Ces couleurs sont une interprétation visuelle des captures, pas une extraction
certifiée de la palette interne de BG3. Les assets distribués sont originaux.

## Premier lot livré

- 26 SVG de boutons, onglets, cases et panneaux, construits par
  `tools/ui_chrome/build_chrome.py`. Bordures extensibles en neuf zones ; textes
  et valeurs restent rendus par Godot. Aucun fichier d'asset de BG3 utilisé.
- Le thème Catabase partagé consomme ces nouveaux cadres à la place des anciens
  cadres peints. Les illustrations de contenu et les icônes existantes restent
  disponibles ; les sources historiques ne sont pas supprimées.
- Palette commune du HUD harmonisée et texture de surface atténuée ; ornements
  communs affinés. Les pages dotées d'habillages spécifiques demanderont encore
  une revue individuelle.
- Inventaire en trois zones : équipement/statistiques, sac compact, fiche d'objet.
  Cases de 64 px, six colonnes observées aux résolutions contrôlées ; nombre de
  colonnes calculé depuis la largeur disponible. Recherche et catégories sans
  mutation des emplacements, compteur de résultats et état sans résultat.
- Statistiques alignées en colonnes, sélection persistante même sous un filtre,
  actions d'équipement réelles et pied fixe dans la présentation Catabase.
- Le survol compact donne l'identité et invite à sélectionner. La refonte complète
  des infobulles n'est pas livrée dans ce lot.

## Fichiers principaux

- `ui/expedition/catabase_ui_theme.gd`
- `data/ui/hud_visual_skin_achilles_v1.tres`
- `ui/theme/premium_panel_ornament.gd`
- `ui/inventory/InventoryScreen.tscn`
- `ui/inventory/inventory_screen.gd`, `inventory_item_tile.gd`
- `assets/catabase/chrome/` et `tools/ui_chrome/`
- `test/unit/test_inventory_equipment_system.gd` : deux scénarios supplémentaires
  couvrant filtres, conservation des objets et équipement de la sélection filtrée.

## Vérification finale

Godot 4.7.1, rendu OpenGL Compatibility. Une suite globale d'une autre tâche
occupait le verrou moteur ; les dernières validations ont donc utilisé une copie
indépendante du projet et du cache, sans liens vers les fichiers originaux.
Les SHA-256 de 35 fichiers de code/scènes/assets vérifient leur identité avec
les fichiers livrés. La copie volumineuse est supprimée après archivage des preuves.

| Contrôle actuel | Résultat |
| --- | --- |
| Inventaire / équipement | 14 tests passent |
| Assets et thème Catabase | 11 tests passent |
| Contrats de palette HUD | 8 tests passent |
| Matériaux HUD | 9 tests passent |
| Pause | 21 tests passent |
| Infobulles de sorts existantes | 5 tests passent |
| Total strict | **68 tests, 27 472 assertions, aucun échec** |
| Probe inventaire 1280×720 | **76 contrôles, 6 captures, aucune erreur moteur** |
| Probe inventaire 1920×1080 | **76 contrôles, 6 captures, aucune erreur moteur** |
| Revue visuelle | Images finales de sélection examinées aux deux résolutions |

Le probe prépare le vrai héros et le catalogue Catabase, puis accorde explicitement
des objets de fixture. Il injecte des clics moteur pour sélectionner, équiper,
retirer et fermer. Il contrôle aussi recherche, absence de résultats et position
fixe de l'action pendant le défilement. Il ne joue pas une campagne complète.

Preuves locales :

- [Rapport des suites et logs archivés](../../artifacts/dev/20260910-140715-chrome-regression-6d794aaa/summary.json)
- [Empreintes des fichiers](../../artifacts/dev/20260910-140715-chrome-regression-6d794aaa/source_hashes.json)
- [Revue 720p](../../artifacts/dev/20260910-141014-chrome-1280x720-645059e9/summary.json)
- [Revue 1080p](../../artifacts/dev/20260910-141025-chrome-1920x1080-7090bd1d/summary.json)

Commandes reproductibles depuis la racine :

```powershell
python tools/ui_chrome/build_chrome.py
./tools/ui_chrome/verify_tests.ps1
./tools/ui_chrome/verify_chrome.ps1 -Resolution 1280x720
./tools/ui_chrome/verify_chrome.ps1 -Resolution 1920x1080
```

Les wrappers acceptent `-ProjectPath` pour une copie isolée. Ils conservent les
rapports datés dans `artifacts/dev/` et n'affirment pas un succès si le moteur,
le rapport, les tests ou les captures manquent. Le formateur officiel a été
appliqué uniquement au nouveau scénario `inventory_review.gd`.

## Limites et suite

Le probe global historique `CatabaseMeshyUIProbe` a produit 9 échecs sur 189
contrôles dans l'état courant : bannière de tour, navigation, récompenses et
ouverture de l'inventaire après transition. Il signale aussi des fuites à l'arrêt.
Ce résultat demeure un échec, sans attribution automatique à cette refonte ni
certification du parcours complet. Rapport conservé dans
`artifacts/dev/20260910-134506-chrome-1280x720-6093f32b/`.

Le premier lancement direct du runner strict dans la copie activait les plugins
Studio et échouait pendant l'import. Les résultats finaux ci-dessus utilisent
le lanceur officiel `dev.ps1`, avec recovery mode et données utilisateur isolées.
La CI et ses validations obligatoires ne sont pas modifiées.

Suite de la mission : revoir individuellement accueil, sélection, grimoire et
HUD à partir de cette direction ; créer les infobulles propres à Dungeon Draft
(identité, effet principal, coût/conditions, comparaison ou explication facultative).

HEAD initial : `2473c335fc11ccb8dfe1cb8257b0a4ee406d1788`. Les travaux concurrents
sur les haltes, Studio, Spine, `core/game_manager.gd` et
`ui/expedition/expedition_screen.gd` ont été préservés. Relire Git et les fichiers
avant de réutiliser cette note ; les rapports ne valent que pour leurs entrées.

## Lot 2 — accueil, sélection et grimoires

La palette est maintenant partagée par l’accueil, la sélection, le grimoire
Champion et le grimoire classique. Le matériau `SelectionAshenSurface` conserve
son nom et ses points d’entrée pour les scènes et contrôles existants, mais son
rendu devient brun fumé : grain fortement atténué, filet de bronze de 1 px,
suppression des biseaux et doubles rainures, remplissage pétrole pour les
sélections et actions principales. Les accents propres aux héros restent sur
leurs marqueurs. Les cartes acquises gardent leur état vert distinct de la
sélection bleue.

L’accueil applique le thème commun à chaque bouton et conserve le pétrole au
focus sur l’action principale. Le panneau de détail du Champion respecte la
couleur de fond qui lui est demandée ; la fonction ignorait auparavant cet
argument. Les règles, ressources de progression, portraits et sorts ne sont pas
modifiés par ce lot.

Fichiers : `ui/titre_ecran.gd`, `ui/selection/character_selection_screen.gd`,
`ui/selection/selection_ashen_surface.gd` et `.gdshader`,
`ui/progression/theme/spell_codex_style.gd`,
`ui/progression/champion/champion_codex.gd` et `champion_mastery_graph.gd`.

Le test `test_party_presentation_screen.gd` attendait encore « Disciplines »
alors que `ui/party/character_presentation_card.gd` affiche déjà dans HEAD
« Arbres de compétences ». Seule cette attente textuelle est mise à jour ;
les contrôles des véritables aperçus 3D restent intacts.

### Revue reproductible

`tools/ui_chrome/MenusReview.tscn` utilise les scènes réelles, les clics souris et
le focus natif. Il parcourt accueil → sélection → doctrine Champion → technique,
ferme le modal, sélectionne le Mage et ouvre son grimoire classique. Il contrôle
les limites des panneaux et la conservation de la progression pendant
l’inspection. Sept captures sont produites par résolution.

Le scénario d’achat utilise explicitement le profil Champion auteur
`data/runs/odyssey.tres` avec un point jetable. Ce n’est pas une victoire de
campagne simulée : la Catabase canonique possède son propre arbre et désactive
volontairement cette ancienne monnaie. Aucun profil de jeu ni sauvegarde réelle
n’est modifié pour permettre la capture.

```powershell
./tools/ui_chrome/verify_chrome.ps1 -Screen menus -Resolution 1280x720
./tools/ui_chrome/verify_chrome.ps1 -Screen menus -Resolution 1920x1080
./tools/ui_chrome/verify_tests.ps1 -Suites @('party_presentation_screen','character_selection_screen','selection_ashen_skin','classic_codex_ashen','champion_codex','champion_dynamic_codex','champion_mastery_graph','mastery_atlas_navigation','spell_codex_navigation','spell_codex_detail')
```

### Validation finale du lot 2

- **76 tests, 1 554 assertions : PASS** sur les dix suites ciblées. L'agrégat
  initial conserve son échec textuel ; le bilan final référence explicitement
  la réexécution réussie des six tests de présentation.
- **132 contrôles rendus, 14 captures : PASS** (66 contrôles et 7 captures par
  résolution), aucun diagnostic moteur. Revue visuelle des captures d'accueil,
  de sélection, du Champion et du Mage effectuée.
- Nouveau script de revue formaté avec `dev.ps1 format`; `git diff --check`
  sans erreur sur les fichiers du lot. Les fichiers de travail concurrents
  restent préservés.

Preuves :
- [Bilan final](../../artifacts/dev/20260910-151046-chrome-menus-validated-3b375f86/summary.json)
- [Empreintes des sources concernées](../../artifacts/dev/20260910-151046-chrome-menus-validated-3b375f86/source_hashes.json)
- [Revue 720p](../../artifacts/dev/20260910-145511-chrome-menus-1280x720-4cc08897/summary.json)
- [Revue 1080p](../../artifacts/dev/20260910-150751-chrome-menus-1920x1080-247d738d/summary.json)

Deux premières tentatives de sonde restent enregistrées : typage de la variable
`title`, puis attribution d'un point au profil canonique qui désactive cette
monnaie. Elles ont été corrigées dans la sonde uniquement. Une tentative 1080p
a rencontré le verrou d'une tâche de tests des haltes ; la capture finale a été
lancée après sa libération sans interrompre cette tâche.

Le HUD et les infobulles spécifiques au jeu restent les prochains écrans à
examiner ; ce lot ne certifie pas un parcours complet de campagne.

## Lot 3 — généralisation à toutes les aventures (validé)

Demande : étendre le thème validé à tous les niveaux du jeu. Le chrome pur est
extrait dans `ui/theme/game_ui_chrome.gd` pour éviter toute dépendance au mode
Catabase ; `PremiumUI` le distribue à la progression, aux récompenses, au
commerce, aux résultats et aux contrôles communs en conservant leurs marges.
Les habillages spécifiques des haltes et du sanctuaire sont harmonisés par des
modifications locales de présentation. La pause et l'inventaire utilisent cette
version dans toutes les aventures. HUD, frise, inspection et infobulles prennent
la palette colorée commune par défaut ; le skin neutre reste disponible comme
ressource de diagnostic. Aucun décor de map, coût, règle ou transaction n'est
recoloré ou remplacé au titre de cette refonte UI.

### Résultat et preuves finales

- **154 tests, 28821 assertions, 17 suites : PASS**. Le bilan fusionne les résultats par suite et remplace explicitement chaque échec par sa réexécution réussie, sans double comptage.
- **51 captures et 321 contrôles de revue : PASS**, plus les contrôles de la galerie HUD. Les 14 vues du parcours sont contrôlées en 720p et 1080p avec vérification de la taille effective de chaque image ; accueil/sélection/Champion, inventaire et galerie HUD sont revérifiés en 720p.
- Revue visuelle effectuée : compétences, récompenses, pause, infobulles, inspection, commerce, résultats, les deux haltes peintes, HUD et inventaire. La fiche d’inspection abandonne sa largeur de contenu fixe pour éviter le défilement horizontal en 720p.
- `GameUIChrome` fournit les styles natifs, boutons, focus, panneaux, saisies, barres de défilement et séparateurs. `PremiumUI` distribue ce thème ; les variations spécifiques du HUD conservent leur disposition et utilisent la palette commune.
- Les tests stricts ont identifié un MP3 de récompense encore lu à la fermeture. `AudioManager._exit_tree()` arrête et libère ses flux : les deux suites après-combat passent désormais sans fuite moteur.
- Pause : l’habillage est appliqué à l’ouverture pour conserver la réversibilité de la scène. Le test de focus compare le style de survol effectif du bouton.
- Les changements concurrents ont été conservés, notamment le nouvel accueil et la sélection publique recentrée sur les deux présentations d’Achille. La revue actuelle des menus comporte donc six images ; le Mage du lot 2 n’est plus une entrée de cette sélection.
- `git diff --check` sur les fichiers ciblés : aucune erreur. Nouveaux scripts de thème/revue formatés.

[Bilan final et références des rapports](../../artifacts/dev/20260910-161948-chrome-global-validated/summary.json) · [Empreintes des sources](../../artifacts/dev/20260910-161948-chrome-global-validated/source_hashes.json)

Les victoires d’étape et écrans de résultats utilisent des états jetables explicitement préparés, avec de vrais contrôles et services. Cette revue de présentation ne prétend pas avoir rejoué chaque combat d’une campagne. Les échecs initiaux (fuite audio, réversibilité de pause, typage de la sonde, verrou concurrent, nouvel asset non encore importé et comptage des menus devenu obsolète) restent accessibles ; aucun diagnostic n’a été masqué.
