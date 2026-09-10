# Sanctuaire émeraude — fiche de travail

10 septembre 2026 · contenu présent dans `202b2a21`, contrôles finaux effectués sur cette base avec les quatre scripts formatés. Recontrôler Git avant reprise.

Objectif : nouveau sanctuaire plus vaste dans le style de la Halle, eau émeraude et torches animées, chaîne de fabrication réutilisable pour les haltes.

Décisions : illustration nouvelle, référence Halle inchangée ; génération native image_gen ; aucun PNJ. Nouveau prototype autonome avant affectation à une halte existante. Séparer manifeste de carte (image, navigation, matières, lumières, zones) et rendu commun. Les sauvegardes et le graphe de Catabase restent inchangés.

Réalisé : nouvelle source `asset/map/painted/halts/emerald_sanctuary_v1/sanctuary.png` (1 672 × 941), monde large de 2 200 unités, boucle parcourable et trois destinations. Huit torches, six cascades, caustiques, projections, brume, braises, feuillage, reflets sur pierre et lumière sur Achille. Clic sur l'eau, pause, comparaison à l'original, couches séparées, mouvement réduit et zoom. Aucun son ni PNJ ajouté.

Pipeline : [guide de l'atelier](../../tools/halt_workshop/README.md), profil commun `data/halts/styles/roots_bronze_v1.json`, manifeste `data/halts/emerald_sanctuary_v1.json`, scène `hub/painted_halt/LivingHalt.tscn`. Commandes `new → attach → calibration du manifeste → prepare → verify → revue`. L'inspection d'image utilise le service existant du Studio ; navigation et acteur réutilisent les composants de la Halle. Le prompt image_gen original est conservé dans `art/source/halts/emerald_sanctuary_v1/generation_prompt.txt`.

## Vérifications exécutées

Le dernier passage rendu, après formatage, est dans `artifacts/dev/20260910-122216-halt-verify-842b8672/` : `summary.json`, `verification.json`, journaux d'import/rendu et captures. Godot `4.7.1.stable.official.a13da4feb`, OpenGL Compatibility. Import et exécution terminés avec code 0 ; aucune erreur moteur détectée par l'analyse stricte de DevTools. **97 contrôles, 20 captures, 3 922 échantillons de déplacement, 0 échantillon hors navigation.**

Commandes exécutées depuis la racine :

```powershell
./tools/halt_workshop/halt.ps1 prepare -PythonPath 'C:/Users/p.montebello/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe'
./tools/halt_workshop/halt.ps1 test -PythonPath 'C:/Users/p.montebello/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe'
./tools/halt_workshop/halt.ps1 verify -GodotPath 'C:/Users/p.montebello/Desktop/Utile/G/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe'
./dev.ps1 format
git diff --check
```

Les **9 tests Python passent** (`artifacts/dev/20260910-115454-halt-test-016ddae5/prepare.stderr.log`) : changements de source/dimensions, chemins hors projet, polygones invalides, canaux du masque, exclusions, reproductibilité, référence artistique, protection des versions et calibration obligatoire. Le formateur GDQuest 0.25.0 vérifie les quatre scripts modifiés (`artifacts/dev/20260910-122019-format--88779a9a/`). Un ternaire de la sonde a été développé en condition explicite pour éviter un changement de structure par le formateur ; le contrôle de structure reste activé.

Navigation : trois destinations et retour au pont, obstacles, redirection sans téléportation, arrêt, pause de la marche et des effets, transformation du zoom. Rendu : eau, cascade, torche, feuillage et projections évoluent ; la pierre sèche reste stable avec l'eau seule ; la pause fige l'image ; l'original est stable ; les ondes ne répondent que dans l'eau. Chargement et dimensions contrôlés via l'inspection des décors du Studio.

Revue visuelle effectuée sur captures **1 280 × 720 et 1 920 × 1 080** : interface accentuée lisible, personnage et allées, bassin central et contour de navigation. Vidéo de 14 secondes assemblée depuis 336 captures Godot réelles : `artifacts/emerald_sanctuary/sanctuaire_vivant.mp4`. Ce média de contrôle et les journaux sont des artefacts locaux, pas des dépendances du jeu. Les 33 références statiques transitives du runtime ont été contrôlées : aucune absente de Git.

Empreinte SHA-256 de la source : `e97a9650c05defbb0dd0094199d3991c0aa2bd4399f4d6bfbe23c6273450b31f`.

## Portée restante

Prototype jouable autonome ; affectation à un nœud Catabase, transactions de halte, son spatialisé et export exécutable non réalisés. La suite GUT globale et la CI distante ne sont pas déclarées validées par ces contrôles ciblés. La définition de l'image n'est pas de la 4K ; toute nouvelle source exige sa propre calibration. Les réglages et tests présents ciblent la famille de haltes avec eau, cascades et torches. Un éditeur visuel de calibration et des profils de vérification pour les lieux sans ces matières restent à développer.
