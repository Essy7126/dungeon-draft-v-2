# Études de références VFX — 22 septembre 2026

## Demande et périmètre

La passe éthérée précédente est rejetée artistiquement. Étudier des animations
identifiables de DOFUS, WAVEN et WAKFU, les reconstruire, comparer plusieurs DA.
Atelier natif destiné à la run Cartes ; aucune nouvelle DA imposée au combat.
Git était propre au début de cette passe. Pas de délégation.

## Observations vérifiées

- DOFUS Unity, Épée céleste : vidéo Coverer Dofus `Dw2tuzw_CJk`, chapitre
  00:33 ; images de lancement examinées par avance image à image vers 00:39–41.
  Épée suspendue cyan, blanchiment, chute très rapide, colonne blanche au contact,
  débris sombres, anneau cyan au sol, puis extinction. Vidéo du 24/09/2024,
  pas une attestation de la version actuelle.
- WAVEN, Deux Doigts : GIF publié par ToT dans sa note du 13/09/2018.
  Main bleue à deux doigts surgissant sous la cible, contour blanc, petites pierres,
  effondrement en éclaboussure puis flaque. Prototype historique, pas un classement
  d'utilisation actuel. Les phases ont été observées dans le navigateur.
- WAKFU, étendard du Iop : vidéo officielle `DoTwvemkBYE`, vers 00:38–39,
  grande épée acier à garde rouge/orange plantée et emblèmes au sol autour.
  Comparaison utile pour un effet durable localisé. Vidéo historique de 2015.
- Portfolio primaire Deeamo : vidéo Iop `512076596` effectivement lue ; pas
  d'attribution de noms individuels à ses quatre effets non légendés.
- Aucun chiffre public de fréquence de lancement trouvé. Le guide Iop de
  Guidactik (17/02/2026) documente l'usage de sorts WAKFU, pas leur popularité
  visuelle. Les commentaires DOFUS sont partagés, particulièrement sur Colère.

## Réalisation décidée

Trois études nommées, trois rendus comparables du même mouvement, chronologie
explicite et revue à taille de jeu. Six PNG originaux générés avec image_gen,
copiés sans retouche dans l’atelier ; géométrie secondaire animée dans Godot.
Aucun asset Ankama importé. Les délais sont des réglages de reconstruction,
pas des mesures prétendues des fichiers source. Comparaison du cumul des états
dans l'atelier, sans changer les règles ni migrer les 112 cartes à l'aveugle.

## Fichiers et décisions finales

- Choix utilisateur confirmé : **A — Animation cel**, 22 septembre 2026.
  Référence désormais dans `docs/design/achilles/cards_vfx_cel_2026-09-22.md` et
  `docs/current/content.md`. A est indiquée comme retenue dans l’atelier.

- Atelier : `tools/class_card_vfx/reference_study/` (README, scène, deux scripts,
  lanceur/capture PowerShell, encodeur GIF, six PNG et prompts exacts).
- Recherche : `docs/design/vfx_reference_studies_2026-09-22.md` ; versions et
  timecodes, phases observées, avis limités de joueurs, écarts de reconstruction.
- Trois DA : cel, volume sculpté en sprite 2D, encre/pigments. La troisième main
  paraît minérale : une différence à évaluer, pas une réussite décrétée.
- États : vrai Player de production à gauche, signes localisés au milieu,
  étiquettes seules à droite. Durées de fixture 1/2/1/2/1, avancées manuellement.
- Maintien de l’étendard jusqu’au retrait explicite ; sol centré sur son objet.
- Cadrage corrigé après inspection ; les empreintes au sol restent visibles.
- Aucun changement dans le combat, les données ou le catalogue. Les documents
  CHARACTER_GAMEPLAY_RESEARCH et character_creation_gameplay_research préexistent
  aux dernières vérifications : ils appartiennent à une autre tâche.

## Vérifications

- `./dev.ps1 test cards` : PASS, 89 tests, 8 273 assertions ; rapport frais
  `artifacts/dev/20260922-194251-test-cards-5fb4c0f5/gut-strict-report.json`.
- Atelier natif Godot 4.7.1/D3D12/RTX 4070 Laptop : 216 captures, 23 contrôles.
  Voir le rapport et le manifeste frais dans
  `artifacts/dev/class_card_vfx/reference_study/`. Le lanceur refuse les erreurs
  de journal, rapports périmés et sources modifiées pendant la capture.
- Format des deux GDScript vérifié avec le formatter du dépôt.
- Images inspectées : suspension et contact de la lame, main haute et retombée,
  étendard maintenu, cinq/deux états, fond clair. Pas de certification esthétique.
- Encodage final réussi : `encoded.json`, trois GIF de 2 400 ms issus chacun de
  72 captures ; 47/48/21 pages encodées après fusion des images identiques.

## Suite et limites

Atelier silencieux, recul du sprite seulement, main écrasée par déformation sans
dessins de transition. Pas de parcours manuel préparation/combat/bilan/reprise
pour cette scène isolée ; il sera nécessaire après branchement d’une piste en
combat réel. DA cel retenue ; migration des cartes et choix de présentation
des états encore à réaliser.
