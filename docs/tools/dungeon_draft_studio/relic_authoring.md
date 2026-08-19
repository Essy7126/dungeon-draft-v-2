# Créer et publier une relique

Les reliques sont des bonus partagés de la run. Elles occupent une place du Sac partagé, sont uniques, non empilables et deviennent actives dès leur acquisition. Elles ne sont ni équipées, ni utilisées, ni consommées.

## Création dans le Studio

1. Ouvrir le Dungeon Draft Studio, puis choisir **Nouvel objet**.
2. Sélectionner le modèle **Relique**, renseigner le nom et l’`item_id`, puis créer la working copy.
3. Compléter l’icône, la rareté et la description. Une relique ne doit pas avoir d’emplacement d’équipement, d’effet d’usage ou de héros compatible.
4. Dans le compositeur, ajouter un ou plusieurs **Blocs réactifs**.

Chaque bloc se lit ainsi : « Quand [déclencheur], si [conditions], appliquer [résultat] à [cible], avec [fréquence]. » Le bloc peut être dupliqué, supprimé ou déplacé. Toutes ces opérations participent à **Annuler/Rétablir** et une duplication crée des sous-ressources indépendantes.

Les listes sont filtrées par contexte. Par exemple, **Source ennemie des dégâts** n’est proposée comme cible que si le déclencheur fournit une source de dégâts. La valeur est l’intensité principale du résultat ; le seuil sert aux comparaisons de PV ; le maximum d’activations et la fréquence définissent la recharge. Une recharge en tours utilise aussi le nombre de tours configuré.

## Validation et prévisualisation

Une erreur de validation indique le bloc concerné et la combinaison incohérente. Corriger d’abord le déclencheur : il détermine les contextes disponibles, puis choisir une cible, des conditions et un résultat compatibles. Les avertissements d’équilibrage signalent notamment les changements de PA/PM et de coût de déplacement.

Le bouton **Tester** exécute une copie isolée de la relique sur plusieurs scénarios : combat, tours, action, PA, déplacement, dégâts, seuil de PV et élimination. Le rapport précise le déclenchement ou son refus, la cible, les valeurs avant/après et les activations restantes. Un bloc peut être désactivé uniquement pour cette prévisualisation ; la définition canonique reste inchangée.

Quand la validation est verte, enregistrer le brouillon puis utiliser **Publier**. L’éligibilité aux récompenses peut être activée pour une relique, mais aucun personnage cible n’est demandé. La publication reste transactionnelle comme pour les autres objets.

## Étendre le vocabulaire générique

Les descripteurs sont centralisés dans `res://items/relic_effect_registry.gd`. Pour ajouter une famille réutilisable :

1. ajouter son identifiant stable et l’enregistrer une seule fois avec `register_descriptor`, ses contextes requis et ses compatibilités ;
2. si nécessaire, ajouter le fait métier sous forme d’un signal typé et nommé dans `EventBus`, puis le produire à la source ;
3. implémenter une seule fois son évaluation générique dans `RelicRuntimeService` ;
4. ajouter un scénario de prévisualisation et des tests de registre/runtime.

Les futures ressources `.tres` peuvent ensuite réutiliser ce type sans script propre à la relique. Aucun comportement ne doit dépendre du nom affiché ou de l’`item_id`.
