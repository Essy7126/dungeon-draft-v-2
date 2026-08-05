# Rapport de régression Encounter Studio V1

## Environnement

- Projet utilisé : `C:\Users\p.montebello\Documents\GitHub\dungeon-draft-v-2`
- Godot demandé : 4.7
- Godot exécuté : 4.7.1.stable.official.a13da4feb
- Intégration : module `RENCONTRES` du plugin Dungeon Draft Studio existant

Le baseline global avant implémentation comptait 620 tests : 617 réussites et 3 échecs préexistants. Les échecs reproduits concernaient le thème du menu pause sombre, des captures attendues de présence d’unités peintes, et une comparaison flottante de timeline (`4.0` contre `4.000000476`).

## Preuves de parité

- Contrat des vagues : 9/9.
- Toutes les 60 vagues de production lançables : 1/1.
- Flux post-combat et récompenses : 18/18 après conservation du cas historique de salle vide.
- Total de la passe corrective runtime : 28/28.
- Une passe plus large avait déjà validé squelette tactique 22/22, run peinte 11/11, arène forêt 12/12 et Arena Studio 15/15. Les 7 échecs alors observés venaient du garde incorrect du resolver de salle vide; ils ont été corrigés et la passe corrective 28/28 le démontre.

## Suite Encounter Studio

`test_encounter_studio_v1.gd` couvre 15 scénarios et 166 assertions : session, conflit, copie, partage, timeline, Undo/Redo, registre de formations, validation, contraintes strictes/souples, déterminisme/RNG, 100 seeds, annulation 1 000 seeds, projection/GameManager, sauvegarde/rechargement/récupération, migration, contexte direct, lifecycle du plugin et rapports.

Résultat final de la suite dédiée : **15/15, 166 assertions** en 31,196 s.

## Suite globale finale

- 66 scripts et 641 tests exécutés.
- 638 réussites et 3 échecs, soit exactement les trois familles d’échecs du baseline.
- 48 274 assertions réussies sur 48 382 en 100,373 s.
- Les suites `test_encounter_studio_v1.gd` et `test_arena_studio_v1.gd` passent intégralement dans cette exécution globale.
- Un premier passage final avait exposé une récupération choisie à la seconde lorsque deux sauvegardes étaient simultanées. L’ordre est maintenant fondé sur l’heure système en microsecondes, puis les ticks; la suite globale rejouée revient aux trois seuls échecs du baseline.

## Smoke et visuel

- Import/activation éditeur : succès.
- Test direct : succès sur `res://data/rooms/maps/painted_battle.tscn`, grille 14×14, seed 424242, formation valide, canonique inchangé.
- Captures : 30 fichiers, dix cas à 1280×720, 1920×1080 et 2560×1440.
- Le rendu final 1280×720 termine sans erreur de script après report différé du rafraîchissement de l’arbre pendant son signal de sélection.
- Le pilote headless dummy ne fournit pas de framebuffer; les captures ont donc été produites par le vrai renderer OpenGL Compatibility local, sans modifier le gameplay.

## Alertes restantes

- Godot signale des UID externes invalides mais récupérables par chemin texte dans trois GLB squelettes. Ces ressources préexistaient et restent chargeables.
- La fermeture de l’éditeur/capture signale 1 à 2 instances `ObjectDB` préexistantes. Les exécutions GUT ou bataille complète affichent aussi les fuites RID/Resource déjà observées dans le projet. Aucun orphan spécifique au Control du Studio n’est rapporté par la suite dédiée après correction du nettoyage des panneaux.
- Un processus du renderer local est resté actif après le lot de captures malgré un code de sortie 0; il a été identifié précisément puis arrêté. Aucun processus Godot de validation n’est volontairement laissé en arrière-plan.
- Les 30 captures existent localement sous `res://artifacts/encounter_studio/captures/`, mais la règle actuelle `artifacts/*` de `.gitignore` les laisse ignorées. Le changement externe de `.gitignore` observé pendant la mission a été préservé sans élargissement automatique.
