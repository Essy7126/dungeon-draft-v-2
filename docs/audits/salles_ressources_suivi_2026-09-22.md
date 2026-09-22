# Deux salles supplémentaires — 22 septembre 2026

Demande : continuer à enrichir directement la run Cartes, après les trois
salles du lot précédent. Pas de changement du moteur commun ni des packs.
Base Git contrôlée : `9af4a96a`. Les fichiers non suivis du lot précédent,
du prototype Charon et des recherches sont conservés.

## Décisions et fichiers

- Sablier, 6/Léthé : croix fixe, 32 dégâts aux deux camps ; sursis 1 PA une fois
  par croix, explosion suivante 48 ; recentrage sur le chef 2 PA ; murs protecteurs.
- Réservoirs, 13/Airain : report spatial des PA, 6 charges maximum par réserve,
  décharge 1 PA à 22 dégâts/charge, siphon ennemi passif 1 charge / 12 PV.
- `core/expedition/card_tactical_resource_rules.gd` isole les deux nouveaux
  comportements en dérivant des règles locales existantes.
- Catalogue, scène publique, affichage tactique et outil d'essai étendus.
- La décharge utilise le report d'issue du combat pendant sa résolution,
  afin qu'un coup fatal termine correctement le combat.
- Tests du catalogue : cinq destinations, packs conservés, route Classique
  inchangée, murs et connexions valides. Tests des mécaniques : coûts, plafond,
  sursis borné, déplacement, vol, boucliers, commandes invalides.

## Vérifications en cours

- Import et tests ciblés : 11 tests / 192 assertions réussis.
  `artifacts/dev/20260922-152443-test-test_unit_test_catabase_tactical_rooms.gd-b33be94d/gut-strict-report.json`.
- Suite Catabase en cours ; résultat à compléter.
- Captures réellement inspectées, cycles de combat réussis et stderr vide :
  - Sablier, 1280×720 : `artifacts/dev/20260922-152642-hourglass-runtime-1280x720-a804e5b2/room.png`.
  - Réservoirs, 1200×896 : `artifacts/dev/20260922-152800-reservoir-runtime-1200x896-5500d677/room.png`.
  - Réservoirs, 1280×720 : `artifacts/dev/20260922-153033-reservoir-runtime-1280x720-cb5e8a7b/room.png`.
- Sursis et coup fatal du sablier : marqueurs `TACTICAL_HOURGLASS_DELAY_PASS`
  et `TACTICAL_ROOM_VICTORY_PASS`, capture inspectée et stderr vide dans
  `artifacts/dev/20260922-153310-hourglass-delay-victory-1280x720-c114f467/`.
- Coup fatal par décharge réussi (`TACTICAL_ROOM_VICTORY_PASS reservoir`),
  stderr vide : `artifacts/dev/20260922-153434-reservoir-victory-1280x720-3c4522bc/`.
- La vérification du coup fatal crée délibérément un état terminal (soutiens
  éliminés, chef à 1 PV) après le cycle et la capture. Elle vérifie la fermeture
  par les commandes publiques, pas l'équilibrage ni une run gagnée.
- Les captures d'exercice utilisent le héros d'essai avec +1 000 PV explicitement
  affichés. Elles valident les tours et l'interface, pas l'équilibrage à ces étages.
- Pas de modification des échecs historiques ni de la liste d'exceptions CI.
