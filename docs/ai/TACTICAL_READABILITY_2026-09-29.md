# Lisibilité tactique — 29 septembre 2026

Demande : déplacement au survol des champions/ennemis, portée réelle des sorts,
palette et ressources PV/PA/PM immédiatement lisibles. Références visuelles Dofus.

Le worktree contenait déjà de nombreuses modifications Cartes/Prototype v1 :
les conserver. Aucun agent délégué. Ne pas réutiliser les rapports sans relire Git.

Décisions : calculs partagés avec Pathfinder/SpellCaster ; portée spatiale bleue,
cibles valides marquées, zone d'effet ambre ; déplacement jade, engagement ambre.
Le survol cède toujours la priorité au ciblage et aux modales.

Fichiers : core/spell_caster.gd, battle/battle.gd, battle/tactical_hover_preview.gd,
les trois vues de grille et marqueurs, composants HUD de ressources.

Livré : survol de la case, du corps et de la tête des sprites, avec leurs marges
transparentes ; zones calculées sur les PM restants, coûts et engagement réels.
Le ciblage partage les contrôles de portée, ligne de vue et projectile avec le
lancement du sort. PV rubis avec cœur, PA bleu avec étoile, PM vert avec losange ;
compteurs agrandis et segments pour les points restants. Icônes réutilisées de
`asset/ui/player_symbols/`, déjà présentes dans le travail parallèle.

Validation finale, rapports complets sous `artifacts/dev/` :
- `20260929-230407-test-tactical-readability-b15e8d6d/gut-strict-report.json` :
  PASS strict, 85 tests / 796 assertions, import propre et aucune erreur moteur,
  y compris à la fermeture. Les grilles du test d'engagement sont libérées.
- `20260929-223820-tactical-readability-visual-2c4ecf53/report.json` : PASS aux
  deux résolutions 1280×720 et 1920×1080, 25 captures, aucun diagnostic moteur.
  Vrais événements souris sur corps/tête, sortie vers HUD, sélection/annulation,
  ressources à zéro ; parcours public et consommation réelle d'une carte testés.
  Survol allié/ennemi, portée et cible de sort, ressources vides inspectés.
- `20260929-230505-capture-hud-036962d2/summary.json` : PASS, 11/11 captures.
  Galerie et planche des onze états inspectées, sans chevauchement observé.
- `tactical-ci-checks/` : 7 tests Python d'audit PASS ; audit des ressources PASS
  (13 105 fichiers, aucune référence externe manquante). Contraste du texte PV :
  5,98:1 normal, 4,62:1 en état faible. Détails dans les JSON et logs conservés.
- Formateur 0.25.0 : quatre nouveaux scripts vérifiés avec contrôle structurel.
  `git diff --check` ciblé passe. Aucun reformatage global.

Limites globales, à conserver explicitement :
- `20260929-223330-test-all-e20f0c15/gut-strict-report.json` : FAIL, rapport de
  3396 tests (3223 réussis, 165 échecs, 7 en attente, 1 risqué), 38 erreurs de
  parse, puis crash à la fermeture (-1073741819). Aucun timeout, mais absence du
  marqueur final GUT : l'exécution globale ne peut pas être déclarée complète.
  Échecs dans des contrats de backend 3D, contenu, sauvegardes Studio et autres
  domaines. Pas de baseline propre isolée permettant de tous les attribuer.
  L'allowlist historique échoue également ; elle n'a pas été modifiée.
- `20260929-230927-tactical-ci-visual-smokes-1c008007/report.json` : FAIL strict.
  Terrain headless ne fournit pas d'image de viewport (5 captures échouées).
  Rencontre atteint `ok:true`, code 0, mais laisse une ressource à la fermeture.
  Objets échoue sur une conversion Dictionary et son contrôle de persistance.
  Les commandes CI et leurs exigences restent inchangées.

Les deux horodatages de rapports Arena modifiés par la suite globale ont été
restaurés, après vérification du diff. Les modifications des autres tâches sont
préservées. Aucune exécution de cette tâche ne reste en cours. Avant toute reprise,
relire Git et ces rapports ; ne pas confondre le succès ciblé avec une CI verte.
