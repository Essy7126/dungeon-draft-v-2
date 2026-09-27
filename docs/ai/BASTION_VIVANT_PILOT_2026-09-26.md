# Bastion vivant — second pilote Blender / Cartes

État final vérifié le 26 septembre 2026 vers 22:26. L'utilisateur conserve
Sentence du rempart et demande un autre sort. Seul `g_bastion` est retravaillé.

## Décisions et intégration

- Trois plaques originales à créneaux, bronze et bleu-vert, centre ouvert :
  deux plans avant/arrière autour du porteur. Verrouillages décalés à
  0,267 / 0,333 / 0,400 s après attribution réelle. Retrait avant 1,5 s.
- La garde est immédiate, coûte les 3 PA réels et expire selon les activations.
  Le VFX ne crée aucun mur tactique et ne modifie aucune règle.
- Un seul signe dans la rangée existante. Son style dépend exclusivement de
  `class_g_bastion`. Si une autre garde survit, remplacement direct par le signe
  générique ; si toute la garde expire, petite sortie. Absorption et rupture
  suivent les contributions de sources du vrai coup. Les retours rapprochés
  se remplacent, et un rafraîchissement ne superpose pas plusieurs déploiements.
- Sons existants conservés. Le mode Classique est exclu.
- Rejeu du laboratoire = nouvelle activation réelle, pour respecter la limite
  d'une utilisation de Bastion par activation. Survol souris désactivé uniquement
  pendant les captures. Les cinq états sont lancés à portée puis appliqués au
  porteur par l'API d'états pour vérifier le cumul sur une seule cible.

## Fichiers

- Source : `art/source/vfx/bastion_vivant/bastion_vivant.blend` ; 43 objets,
  neuf matériaux, 48 poses à 30 Hz, 384 × 384, pivot [192, 246.0192].
- Construction/rendu/atlas : `tools/class_card_vfx/bastion/build_bastion.py`,
  `pack.py` ; deux atlas 3072 × 2304 et provenance sous `vfx/class_cards/bastion/`.
- Lecteur : `vfx/class_cards/bastion/bastion_player.gd` ; raccords localisés dans
  `vfx/class_cards/class_card_vfx_router.gd` (fichier également modifié auparavant).
- Contrats : `test/unit/test_bastion_vivant_vfx.gd`, inclus dans les suites
  `cards` et `catabase` de `tools/dev/test-suites.json`.
- Comparateur : `tools/class_card_vfx/bastion/run.ps1`, `comparison.gd/.tscn`.
  Sans option = fenêtre interactive ; `-Capture` = contrôles et images natives ;
  `-Workshop` = export par le service Sprite Studio du dépôt. Guide local : README.
- Clips source Studio : `art/source/sprite_workshop/bastion_vivant_back.json`
  et `bastion_vivant_front.json`. Aucun indicateur d'approbation humaine forcé.

## Vérifications finales

- Suite Cartes `artifacts/dev/20260926-221936-test-cards-f1d0ddac/` :
  **161 tests, 13 886 assertions ; 158 passent, 3 échouent**. Les échecs sont les
  mêmes que lors du passage de 16:21, dans les travaux consommables distincts :
  `test_all_96_card_forms_cast_legally_and_consume_exactly_one_uid`,
  `test_third_surface_group_removes_oldest_cells_and_survives_restore`,
  `test_chronicle_survives_new_run_without_transferring_power`.
  Ne pas annoncer la suite Cartes entièrement verte.
- Sous-ensemble VFX exécuté dans cette suite : **44 tests / 3 111 assertions PASS**,
  dont Bastion 5/34, Sentence 6/35, ClassCardVFX 33/3 042.
- Capture finale `artifacts/dev/class_card_vfx/bastion/combat/report.json` :
  **260 contrôles PASS, 180 images, sortie moteur 0**, sans erreur de script.
  Coût, attribution, durée, absorption, rupture, expiration avec garde restante,
  cinq états, restauration, rejet, commande publique Battle, fermeture et
  bilan/sauvegarde/reprise couverts. La victoire est provoquée par la fixture.
- Inspection effective : déploiement à distance normale et rapprochée, absorption,
  rupture, disparition finale, six signes séparés, remplacement de garde lisible.
- Reconstruction Blender séparée : les deux plans à l'image 17 sont identiques
  en pixels (`artifacts/dev/class_card_vfx/bastion/rebuild_report.json`).
- Studio : deux exports de 48 images, contrôle des pixels aller-retour PASS.
  L'export Studio seul ne certifie pas l'intégration du lecteur dans le jeu.
- Aucun écart entre les sources sélectionnées et la capture finale ; aucun écart
  sur les trois empreintes acceptées de Sentence (source, atlas, lecteur).
- GIF natifs de 3 s, sans son, palette quantifiée seulement, dans le dossier combat.
  `bastion_v2.gif` SHA-256 :
  `c96b38d5d5a73f3b9f29046a75a95d65bc15dc38d0ff99d903e521f6b3d79041`.
- Comparateur final rouvert, session d'exécution 92264 ; premier lancement réel
  32 de garde, deux coups de 8 puis 24, journal sans erreur.

Travail demandé terminé ; appréciation artistique laissée à l'utilisateur.
Pas de validation globale verte ni de mesure de performance GPU revendiquée.
Les travaux parallèles et Sentence ont été préservés ; aucun commit créé.
