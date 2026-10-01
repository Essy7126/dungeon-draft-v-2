# Progression de personnage — reprise du 30 septembre 2026

Objectif : prolonger la tâche locale « Auditer les idées de gameplay » par des
calculs reproductibles, des validations actuelles et une proposition complète.

- Références lues : conversation locale `01a0da79-a53b-7992-accd-1fc41b9cd305`,
  contrat courant Prototype v1, fondations du 28 septembre, progression et
  épreuve Passe-rive du 29 septembre. Les preuves anciennes restent historiques.
- Contraintes reprises : toutes classes/tous éléments ; pas de couples de builds
  imposés ni de transformations conditionnées par des seuils élémentaires ;
  investissement par composante ; copies finies ; PA/PM/main sans croissance
  automatique ; préserver le travail concurrent.
- Périmètre prévu : dossier `docs/design/progression_systeme_2026-09-30/`,
  analyse indépendante et candidats non chargés. Aucun changement du moteur actif.
- État Git initial : aucun changement suivi ou non suivi signalé ; HEAD sera
  enregistré avec les empreintes des entrées dans le rapport de calcul.
- Diagnostic `dev.ps1 doctor` : Godot 4.7.1 et GUT 9.7.1 disponibles.
- Premier `dev.ps1 test cards` : FAIL à l'import, zéro test ; accès sandbox aux
  certificats et à trois dossiers refusés. Rapport conservé dans
  `artifacts/dev/20260930-195046-test-cards-976f9389/`.
- Nouvelle exécution avec accès Windows normaux : PASS, 359 tests / 34 630
  assertions, zéro erreur moteur, dans
  `artifacts/dev/20260930-195411-test-cards-5380453a/`.

État final : dossier terminé, sans modification du gameplay actif.

- HEAD initial et final : `a3b0c7dc4c6841c722e5db3d90c6151696dec7b9`.
- Fichiers : README, CONTRAT, RECHERCHE, candidats.json et analyse.py dans
  `docs/design/progression_systeme_2026-09-30/`, plus cette fiche.
- 169 911 allocations exhaustives × cinq répertoires ; gains arrondis, comparaison
  Vitalité/Protection, accès aux fonctions et tirages normaux, six formes et trois
  cartes candidates. Une Braise lente à total égal a été rejetée comme dominée.
- `verify_prototype_v1.ps1 -Class thaumaturge -TimeoutSeconds 480` : six essais
  réels Passe-rive, 59 casts joueur / 27 ennemis, aucun cast joueur échoué,
  quatre victoires et deux essais bornés ; aucune erreur moteur. Rapport dans
  `artifacts/dev/20260930-200422-prototype-v1-passe-rive-c8e6a567/`.
- Analyse finale avec `--runtime` sur ces observations : PASS, 3 607 contrôles,
  1 728 impacts Godot/Python concordants. Rapport et empreintes dans
  `artifacts/dev/20260930-progression-systeme-final/resultats.json`.
- Les analyses `-01` et `-02` restent intermédiaires ; ne pas réutiliser leurs
  empreintes comme validation du dernier script/candidat.
- Deux captures de Battle inspectées : départ élite et victoire. Passe-rive et
  sa main présents ; bannière de début de tour recouvrant une partie du plateau.
- Comparaison interactive Eau/Soleil ou Eau/Nuit : valeurs et interactions
  vérifiées par Playwright, zéro erreur et zéro débordement à 320/736 pixels ;
  les deux captures sont inspectées. Fichier source dans le dossier de
  visualisation propre au chat ; preuves dans le rapport final.
- Liens locaux et empreintes des sources du rapport final vérifiés ; diff propre.
  Git ne signale que les nouveaux fichiers de cette étude.

Décision : conserver les budgets v1 ; compléter le contenu normal, éprouver
inflexion/offres séparément, puis versionner les formes et les paquets de statut.
Les aptitudes Soin/Persistance restent candidates tant que leur contenu manque.
Les résistances constituent un lot ultérieur, pas un changement associé automatique.

Prochain travail : intégrer un lot choisi selon le contrat, avec tests ciblés,
campagne continue à graines identiques, contrôles humains et gates CI pour tout
changement du moteur commun. Aucune nouvelle règle ou forme n'est déjà jouable.
Relire Git et vérifier les empreintes avant de réutiliser les preuves.
