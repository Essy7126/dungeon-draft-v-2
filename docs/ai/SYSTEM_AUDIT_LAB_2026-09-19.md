# Audit du système et laboratoire — 19 septembre 2026

## Périmètre

Auditer le code actuel et les deux propositions de design du 19 septembre. Produire des définitions, des décisions argumentées et des expériences reproductibles. Aucune migration des sauvegardes ni remplacement de la variante Cartes publique dans cette tâche.

## État initial vérifié

README et Git relus le 19 septembre. Les changements de préparation guidée déjà présents dans `core/`, `ui/`, les tests Cartes/sélection et README appartiennent au travail en cours : les préserver.

La route R6 utilise 12 combats ; les seuils XP et les points de profondeur sont des autorités différentes. Les cartes dépendent encore d'ExpeditionBuildCatalog ; leurs drops filtrent les axes découverts. ItemDefinition possède trois emplacements, pas les six proposés dans le dossier. Les définitions de classe/maîtrise des dossiers précédents ne sont pas implémentées.

## Travail réalisé

- Laboratoire séparé : vrais Spell, SpellScalingResolver, DamageResolver et SpellCaster existants ; aucune seconde loi de dégâts.
- Export des routes, XP, budget de points et catalogue actuels depuis Godot.
- Expériences de drops distinguant quantité, diversité et compatibilité ; seuils de dégâts et de pioche.
- Recherche primaire ciblée et dossier de décisions, avec limites de chaque expérience.
- Validation ciblée des nouveaux fichiers ; pas de déclaration de réussite de la suite globale.

## Vérifications

- `./dev.ps1 test test/unit/test_build_system_lab.gd` : **10 tests, 153 assertions, PASS**, zéro erreur moteur dans le rapport strict final : `artifacts/dev/20260919-131155-test-test_unit_test_build_system_lab.gd-f6f70d72/summary.json`.
- Première exécution sandbox : import bloqué, zéro test, échec conservé. Relance autorisée hors sandbox. Premiers essais : protocole de tour et lecture de `granted` corrigés ; fermeture de `clear_combat_effect_history()` ajoutée aux fixtures. Ne pas présenter ces exécutions initiales comme réussies.
- Formateur ciblé : les deux GDScript sont conformes. Aucun fichier de production modifié par cette tâche.
- `analyze.py --validation artifacts/dev/20260919-131155-test-test_unit_test_build_system_lab.gd-f6f70d72/summary.json` : terminé, exit 0 ; empreintes des sources vérifiées ; probabilités exactes normalisées et contrôle indépendant du calcul de collision de classe.
- Sorties : `artifacts/dev/build_system_lab/engine_audit.json`, `analysis.json`. Dossier de décisions : `docs/design/catabase_system_audit_2026-09-19.md`.

## Décisions / limites

- Les définitions narratives antérieures ne sont pas des mécaniques ; séparer apparence, classe, spécialisation, affiliation, famille, copie, élément et biome.
- 24 points de profondeur dont 10 hors combat ; ne pas ajouter le nouveau budget dessus. Niveau de base 12 avant boss ; Sagesse avance fortement les seuils.
- Modèle de loot antérieur : 43,62 % de deux cartes étrangères de même classe au combat 8, mais 4,94 % de paire préparation/exploitation dans le nouveau modèle de rôles. Ce n'est pas une probabilité de build viable.
- Huit vrais Spell de laboratoire ; deuxième itération supprime la limite générale d'une attaque par activation, garde des bornes sur les contrôles. Pas de catalogue public ni de passifs de classes intégrés.
- Les spécialisations proposées remplacent le passif initial ; elles ne l'empilent pas.
- Aucun playtest humain ou combat de run complet avec ces nouvelles classes revendiqué. Les autres modifications Git du départ ont été préservées.

## Suite proposée

Intégrer les contrats de données séparés du vieil arbre, une classe avec quinze cartes réellement distinctes, puis comparer ses cartes/équipements/hybrides sur les mêmes rencontres. Passifs, migration des slots et interfaces restent des travaux d'intégration distincts de cet audit.
