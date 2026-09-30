# Épreuve Prototype v1 — Passe-rive

Demande : éprouver le système installé, rechercher les alternatives et codifier
des propositions de statistiques, cartes, équipement, reliques et défenses.

- Base : HEAD initial 86018f9c, puis 0cde78b2 créé par le travail concurrent ; worktree déjà très modifié, dont combat,
  HUD et outils de lisibilité par d'autres travaux. Ne rien réinitialiser.
- Passe-rive est une apparence publique ; les quatre classes restent les classes
  mécaniques. Comparer plusieurs investissements sous cette apparence.
- Livrables : harnais Godot sur la vraie Battle, calculs reproductibles sur tout
  le catalogue, recherche sourcée et catalogue candidat distinct du contenu actif.
- Distinguer lancement réel de sort, politique automatique limitée, fixture de
  laboratoire, prévision arithmétique et équilibre démontré en partie humaine.
- La recherche n'autorise pas à annoncer des propositions comme déjà jouables.

État : étude et matrice runtime terminées. Dossier :
`docs/design/prototype_v1_epreuve_2026-09-29/README.md`, recherche, contrat,
9 cartes / 6 équipements / 3 reliques / 4 traits candidats, analyse Python et résultats.
Les candidats ne sont pas chargés ; aucune modification de balance active.

Harnais : `tools/consumable_cards/prototype_v1_probe.gd/.tscn` et
`verify_prototype_v1.ps1`. Quatre classes avec Passe-rive, trois allocations,
profondeurs 1 et 6, scènes/IA/casts réels ; essais indépendants, transit déclaré
pour la profondeur 6. Pas de mesure de campagne continue ni de win-rate humain.

Preuve finale : `artifacts/dev/20260929-233559-prototype-v1-passe-rive-3ea96521`.
PASS strict : 24 essais, 202 casts joueur sans échec, 100 casts ennemis,
19 victoires + 5 observations tronquées à six tours ; aucune erreur moteur.
1 728 impacts directs du moteur concordent avec Python ; 246 contrôles candidats.
Deux des 16 captures inspectées ; bannière de tour visible sur la capture initiale.

Défaut runtime corrigé : `battle/tactical_hover_preview.gd` vérifie la vue avant
affectation typée, évitant l'accès à une instance libérée. Régression ajoutée à
`test/unit/test_tactical_readability.gd` : suite 10 tests / 37 assertions PASS,
rapport `artifacts/dev/20260929-232932-test-test_unit_test_tactical_readability.gd-827d5ce9`.
Format des trois GDScript concernés PASS. Suite `cards` complémentaire PASS :
356 tests / 34 593 assertions, zéro échec / erreur moteur,
rapport dans `artifacts/dev/20260929-234438-test-cards-b2d3418b`.
La suite globale et les autres gates CI n'ont pas été rejouées pour cette étude.

Constats : optimum 80/20 = 26/0 ; Soleil peu couvert en cartes normales ;
6/14 équipements précoces sont des amulettes ; garde de secours .25P neutre,
garde brève .45P Soleil ; éviter d'inférer une dominance depuis une seule salle
(100/264 PV ennemis retirés par le terrain dans l'essai Arpenteur Vent).
Proposition importante : inflexion explicite de l'élément de l'attaque permanente,
afin que l'investissement subsiste après consommation ; à tester avant intégration.

Préserver les autres modifications en cours, notamment UI et Passe-rive. Les
SHA-256 initiaux et la comparaison finale sont dans `artifacts/dev/prototype-v1-passe-rive-*.json`.
Étude terminée. Le README du dossier a été demandé dans le panneau Codex (ouverture
mise en file par l'application). Les propositions sont prêtes à discuter et à
intégrer par lots ; aucune nouvelle règle de gameplay n'est annoncée comme active.
