# Production cel — run Cartes, 22 septembre 2026

Demande : créer les animations de toutes les cartes après le choix explicite de
l’animation cel. Pas de délégation. Les deux documents de recherche de personnages
d’une autre tâche sont préservés.

## Livraison

- 17 atlas originaux imagegen, six poses chacun : 102 dessins, PNG inchangés,
  prompts complets dans `vfx/class_cards/cel/art/provenance.json`.
- 112 compositions explicites, initiations incluses ; les 48 sorts adverses
  utilisent les correspondances sémantiques du catalogue.
- Lecteur cel, vols, terrain, poses de puissance et couleurs propres aux cartes.
  Archive éthérée conservée uniquement dans l’atelier de références.
- États compacts, priorité stable, cinq signes et +N au-delà de six. Ticks réduits,
  bouclier intact sur absorption partielle, une seule petite sortie lors d’une
  purge simultanée. Durées, dégâts, coûts, RNG et périmètre de run inchangés.
- Textes génériques d’état supprimés seulement dans le combat Cartes lié ; les
  retours chiffrés et ceux de la run Classique restent disponibles.

## Vérifications acquises

- Suite Cartes complète : **93 tests / 8882 assertions, PASS strict**,
  `artifacts/dev/20260922-214845-test-cards-6bc97d7d/gut-strict-report.json`.
- Après le dernier ajustement de couleurs (sceaux violets, protections de suie) :
  **32 tests / 3024 assertions, PASS strict**,
  `artifacts/dev/20260922-220209-test-test_unit_test_class_card_vfx.gd-7091bd7d/`.
- Retours de combat partagés : **6 tests / 47 assertions, PASS strict**,
  `artifacts/dev/20260922-220904-test-test_unit_test_combat_feedback_contract.gd-365813c8/`.
  Nettoyage des historiques des fixtures ajouté, assertions inchangées.
- Audit PNG : 17 atlas / 102 poses, transparence et bordures validées dans
  `artifacts/dev/class_card_vfx/cel/asset_audit.json`.
- Galerie finale : 112 cartes, 48 sorts ennemis, 66 images natives / 2,2 s,
  `artifacts/dev/class_card_vfx/cel/gallery/`. GIF encodé, empreintes vérifiées.
  Les 14 pages de cartes ont été inspectées, dont les couleurs finales.
- Format des GDScripts de production sélectionnés et `git diff --check` : PASS.

## Historique des corrections

Les passages intermédiaires ont révélé un `Label.global_scale` invalide, une
priorité de sortie de stase incorrecte et une fuite d’historique dans les fixtures
du contrat de feedback. Tous sont corrigés, sans retirer d’assertion. Les anciennes
captures des dossiers éthérés ne constituent pas des preuves de cette version.

## Captures natives validées

Capture finale `capture_combat.ps1 -Cel` : **184 contrôles réussis, 17 lancers,
960 images**. Seize sorts filmés, Brûlure et son tick réel, huit états simultanés,
terrains, bilan et reprise réelle. Rapport :
`artifacts/dev/class_card_vfx/cel/combat/report.json`.
Inspection terminée : volée, faux, rempart, sablier, comparaison impact/tick,
rangée de huit états, maintien des terrains et écran de reprise.

Finalisation du 24 septembre : aucune différence d’empreinte entre les sources
VFX, le catalogue courant et les captures. Encodage terminé : seize GIF de deux
secondes, 960 images natives, empreintes des sorties vérifiées. Rapport complet :
`artifacts/dev/class_card_vfx/cel/combat/encode_report.json`.
La galerie et les GIF sont prêts à être revus ; aucune validation requise ne reste
en attente. `git diff --check` est passé après la mise à jour de cette fiche.
Le bilan emploie une victoire de fixture après les lancers : ce n’est pas une
victoire jouée. Les contrôles techniques ne valent pas approbation artistique.
