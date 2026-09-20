# VFX éthérés — run Cartes

Reprise de la bibliothèque dans la direction **C — Éthéré : transparence, lumière et volutes**, demandée le 20 septembre 2026. L’intégration couvre les **112 cartes actuelles, 2 gestes de secours et 48 identifiants de sorts adverses**, formes de boss et invocations comprises. Dix sorts adverses réutilisent des cartes. Les recettes se répartissent en **21 familles**, avec taille, rythme et turbulence propres à chaque recette ; ce ne sont pas 160 animations indépendantes.

## Voir et rejouer

```powershell
./tools/class_card_vfx/preview.ps1
```

La galerie utilise le lecteur de production. Le sélecteur donne accès à toutes les cartes, aux classes, aux applications d’états, aux **états durables**, aux sorts adversaires et aux 21 familles. Pagination, pause, curseur temporel et vitesses ×0,5/×1/×1,5 permettent de regarder chaque effet. Le mannequin reste fixe pour isoler les VFX. Les déplacements, tirs et zones multi-cibles sont composés par le combat.

```powershell
./tools/class_card_vfx/preview.ps1 -Capture
node tools/class_card_vfx/encode.cjs
```

Sorties : `artifacts/dev/class_card_vfx/ethereal/gallery/`. Le GIF contient 66 captures réelles du viewport Godot, sur 2,2 secondes. Dix pages montrent les cartes, quatre les ennemis, deux les familles ; une planche montre les états. `report.json` inventorie les cartes/sorts effectivement capturés. `encode_report.json` consigne le moteur et les empreintes des sources du rendu. La seule conversion des images est la quantification de palette GIF.

Deux planches supplémentaires `durable_00.png` et `durable_01.png` montrent les 23 états explicitement associés. Pour vérifier les vrais lancers, états et zones dans la scène de combat :

```powershell
./tools/class_card_vfx/capture_combat.ps1
node tools/class_card_vfx/encode_persistence.cjs
```

Sorties : `artifacts/dev/class_card_vfx/persistence/`. Le scénario prépare la main, place deux acteurs sur des cases valides et suspend l’IA via le mode de test du Studio. Huit cartes passent par le vrai `SpellCaster`. Après une vue générale, la caméra native est agrandie ×2,4 pour inspecter les états. Le GIF de 60 images montre deux secondes de maintien ; les PNG montrent ensuite les sols feu/givre et la disparition des états. Ce scénario contrôlé ne représente pas un parcours manuel complet.

## Direction et fabrication

Les surfaces lumineuses translucides remplacent la première passe de géométrie dessinée. Feu ambré, glace cyan, garde dorée, soin jade, ombre violette et saignement carmin gardent une couleur sémantique. Chaque famille possède une silhouette : membrane pour la garde, courants ascendants pour le soin, branches pour le givre, sablier pour la stase, portail au sol pour l’invocation, traces courbes ou droites pour les attaques physiques.

Le rendu est natif Godot, avec des shaders `canvas_item` dans `vfx/class_cards/ethereal/`, une texture de bruit partagée et une nappe blanche de 256 px. Le feu reprend le pilote Éclat de braise, avec fumée légère et étincelles locales. Les couches arrière et avant passent autour de l’acteur ; leur opacité reste faible pendant le maintien d’un état. Le temps est explicite et suit la pause du jeu. Pas de service externe ni d’image générée nécessaire pour reproduire ce rendu.

Les anciens `.blend`, atlas et scripts `build_blender.py` / `assemble.cjs` restent les **sources historiques de la première passe rejetée**. Ils ne génèrent pas les VFX éthérés actuels et ne sont plus chargés par ce lecteur.

## Intégration et périmètre

- `class_card_vfx_catalog.gd` : recettes issues du catalogue vivant et correspondances explicites des sorts ennemis. Un nouveau sort inconnu fait échouer la couverture des tests.
- `class_card_vfx_player.gd` : deux couches, dissolution, maintien animé à intensité réduite (34 % pour le feu, 55–60 % pour les autres), suivi des acteurs et libération des sprites attachés. Les nappes arrière sont à la profondeur de l’acteur et avant son dessin ; une profondeur négative les masquait sous les dalles.
- `class_card_vfx_flight.gd` : trajet lumineux calé sur le délai de vol existant ; liaison brève pour les tirs instantanés confirmés.
- `class_card_vfx_router.gd` : applications, annonces de sorts différés, invocations, arrivée des déplacements, 23 identifiants de statut, ticks, soins, absorption/rupture de bouclier, critique, esquive et immunité. Les autres états d’équipement sont associés selon leurs propriétés : soin, dégâts périodiques, entrave, baisse de PA, bonus ou malus.
- `class_card_vfx_ground.gd` : courants éthérés projetés sur les quatre coins réels de chaque surface dynamique ; maintien et dissolution à la disparition du terrain.
- `core/vfx_manager.gd` : active ce routeur uniquement si une unité de la vue de combat liée appartient à une session possédant `cards`. Le lanceur et les cibles doivent appartenir au combat lié. Un identifiant de carte seul ne suffit pas à activer cette DA en run classique.

Aucun coût, dégât, statut, portée, RNG ou délai de combat n’est modifié. Un tir en vol ne fabrique pas d’impact. Les annonces interrompues sont retirées ; les coups différés ne confirment l’impact que pendant leur résolution réelle, y compris lorsqu’un bouclier absorbe les dégâts. Les impacts restent sur la case d’avant poussée. Les états expirent lorsque leur dernière source disparaît ; un retrait forcé retire immédiatement le maintien. Les états et boucliers déjà actifs sont restaurés sans rejouer leur application, y compris après une création tardive ou un remplacement de vue. La fermeture du combat arrête cette restauration et nettoie les effets.

Les surfaces persistantes conservent le socle dessiné par `DynamicSurfaceVisualAdapter`. Le routeur y ajoute une couche éthérée animée, leur application, réaction, pulse de dégâts et disparition. Les braises, le givre et les résidus suivent la durée restante réelle du terrain. Le contrat de dégâts de terrain n’expose pas le sort source : son pulse exige donc un dégât élémentaire positif sans source, sur une surface encore active et enregistrée par le routeur. Cette limite ne change pas les règles du terrain.

## Vérification

```powershell
./dev.ps1 test test/unit/test_class_card_vfx.gd
./tools/class_card_vfx/validate.ps1
```

La suite VFX passe en **PASS strict : 20 tests / 1 265 assertions**, import compris, sans erreur ni fuite. Rapport : `artifacts/dev/20260920-214934-test-test_unit_test_class_card_vfx.gd-7ca5ba5b/gut-strict-report.json`. Les quatre nouveaux scénarios vérifient les états préexistants et les vues tardives, l’animation des braises jusqu’au dernier retrait, le maintien des surfaces et les états d’équipement/réaction.

`validate.ps1` regroupe sept suites exactes avec le runner strict de la CI et son import éditeur normal. Résultat courant : **64/65 tests, FAIL strict** (snapshot de salle dans le Studio, erreurs Spine et libération de ressources). `dev.ps1` utilise un import en recovery mode. Détails et preuves : `docs/ai/CARDS_ETHEREAL_VFX_2026-09-20.md` et `artifacts/dev/class_card_vfx/persistence/verification.json`.

Le test lance réellement les 112 cartes et les 48 sorts adverses via `SpellCaster`, vérifie les cas d’échec, les impacts absorbés, les annonces annulées, les vols, les terrains et le nettoyage. Il vérifie le retour aux VFX existants en run classique, l’exclusion d’un autre combat et l’absence d’effet de la lecture des VFX sur PV/PA/boucliers.

Inventaire ennemi reproductible : `tools/class_card_vfx/audit.tscn` ; résultat dans `artifacts/dev/class_card_vfx/ethereal/inventory.json`. La collecte couvre tous les rôles et grades du catalogue d’évolution, leurs ajouts de la run Cartes, les invocations et les deux formes du boss de la route actuelle.

Régression de la **livraison précédente** : 125 tests / 7 640 assertions satisfaits dans dix suites. Sept suites passent le contrôle strict ; Paris, le kit d’Achille et le philosophe signalent des ressources non libérées à la fermeture. L’ensemble historique n’est donc pas un PASS strict. Rapport détaillé : `artifacts/dev/class_card_vfx/ethereal/verification.json`.

Captures galerie et arène vérifiées : Godot 4.7.1 / Forward+ D3D12, sans erreur de shader ni de capture. Les 26 contrôles du scénario natif passent : lancers, maintien, ordre des couches après réaction et nettoyage. La sonde consigne les indices des couches opaques lorsqu’elles existent (givre/eau) ; le feu n’a pas de dalle opaque dans ce catalogue. Une couverture technique complète ne constitue pas une approbation artistique individuelle.
