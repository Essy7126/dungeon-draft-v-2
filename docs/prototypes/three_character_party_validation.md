# Validation technique d’une équipe de trois personnages

## Périmètre

La run `three_character_validation_run.tres` est un outil temporaire de
développement. Elle réutilise les trois salles du Prototype Elfe, sans
récompense ni pool étendu, et lance cette composition déterministe :

1. Elfe ;
2. Gardien historique ;
3. Guerrier historique.

L’entrée **Validation technique — équipe de 3** n’est visible que dans un
exécutable Godot de développement ou de debug. Le Prototype Elfe solo et le
draft historique restent deux entrées distinctes.

Le Gardien et le Guerrier utilisés ici ne constituent pas une validation de
leur game design final. Ils servent uniquement à tester l’architecture
d’équipe. Ils ne préfigurent ni les deux futurs personnages définitifs, ni une
composition finale imposée au joueur.

## Identité, ordre et construction atomique

`GameManager.heroes` conserve l’ordre de la composition. Les vues défensives
`get_ordered_heroes()` et `get_ordered_character_states()` exposent cet ordre ;
`get_character_state_for_unit()` retrouve un état uniquement par l’identité
runtime exacte de sa `Unit`, jamais par son nom affiché.

`character_states` reste indexé par `character_id`. Avant toute mutation de la
run courante, le manager résout toutes les sources, refuse un identifiant
effectif vide ou non assigné et refuse deux clés identiques. La future équipe
et ses états sont ensuite construits hors du manager. Elle ne remplace
atomiquement l’ancienne équipe qu’une fois la construction complète. Un échec
préserve donc la run précédente et libère toute préparation partielle.

Pour cette étape, une composition contient uniquement des héros uniques. Aucun
`character_instance_id` n’est ajouté. Une identité d’instance dédiée ne
deviendrait nécessaire que si le game design autorisait plus tard plusieurs
exemplaires du même héros.

## Loadouts à quatre emplacements

Chaque héros préconfiguré possède son propre `CharacterRunState` et son propre
`SpellLoadoutState`. Tous les sorts initiaux valides et dotés d’un identifiant
effectif unique deviennent connus. Les quatre premiers sont équipés dans
l’ordre de la `UnitData`; les emplacements manquants restent vides et les sorts
suivants restent connus. `Unit.spells` est uniquement la vue des sorts équipés.

- Elfe : 4 connus, 4 équipés ;
- Gardien : 5 connus, 4 équipés ;
- Guerrier : 8 connus, 4 équipés.

Le draft historique ne crée toujours pas ce loadout plafonné : son Guerrier
conserve ses huit sorts.

## HUD et tours

À chaque nouveau tour, `Battle` annule le déplacement, l’attaque ou le sort
encore ciblé avant de reconstruire `ActionBar`. La barre déconnecte les signaux
de tous les anciens boutons, les retire immédiatement de l’arbre et recrée les
boutons dans l’ordre du loadout actif.

Il existe un bouton de base par sort équipé. Les variantes Empreinte historiques
restent des boutons supplémentaires lorsque le sort et l’énergie active les
autorisent. L’Elfe, sans énergie, n’affiche aucune Empreinte. Ferveur, Éveil,
Garde et leurs séparateurs sont recalculés à chaque changement : cachés pour
l’Elfe, visibles pour le Gardien et le Guerrier, puis de nouveau cachés au
retour à l’Elfe.

Le déploiement emprunte `get_living_heroes()` dans l’ordre de composition et
place trois références déjà possédées par le run. `TurnQueue` reçoit les trois
alliés et conserve l’ordre d’ajout comme départage stable à initiative égale.
Chaque `Unit` garde ses propres PA, PM, PV, bouclier, statuts, sorts, traits et
modificateurs.

## Progression et file multi-héros

L’Elfe conserve ses quatre disciplines et ses huit choix de rang 2. Le Gardien
et le Guerrier historiques n’ont ici aucune discipline : leurs sorts sans
`discipline_id` ne donnent pas d’XP et ne produisent pas d’erreur.

Le service de progression compare l’instance exacte du lanceur à la `Unit` de
chaque état. Des personnages synthétiques peuvent donc partager un
`discipline_id` ou un `spell_id` sans partager XP, rangs, attentes ou choix. Un
lanceur retiré de la run n’est plus reconnu.

La file post-combat est reconstruite depuis les états ordonnés :

1. ordre des héros ;
2. ordre des disciplines de chaque `UnitData` ;
3. rang croissant.

L’unique `ProgressionChoiceScreen` remplace complètement ses données après
chaque confirmation et applique le choix au `character_id` de l’entrée
courante. Le flux ne reprend qu’après le dernier choix.

## Persistance et cycle de vie

Les scènes de combat empruntent les mêmes références `Unit` au manager entre
les salles ; aucun rattachement à une nouvelle instance n’est nécessaire.
`CharacterRunState`, loadout, sorts connus, PV, XP et modificateurs persistent
donc avec l’équipe. Les ressources de combat suivent la règle existante :
`Battle._reset_combat_resources()` réinitialise PA et énergie au début de
chaque combat, sans remplacer les `Unit` ni leurs états de progression.

`cleanup_run_state()` dispose les trois états, déconnecte chaque
`loadout.changed`, retire les modificateurs et traits des trois unités, ferme
l’écran de progression, annule la continuation post-combat, puis efface héros,
clés, salles, récompenses proposées et résultat terminal. Une run suivante,
solo ou à trois, repart avec de nouvelles instances ; un ancien héros ne peut
plus recevoir d’XP.

## Compatibilité et limites

Le Prototype Elfe solo, les quatre disciplines, Mage, les six évolutions
Archer/Assassin/Soigneur, les choix multiples, le draft, `RewardScreen`, les
énergies, traits, Empreintes et tout le contenu historique restent inchangés.
Aucune `UnitData`, `Spell`, `SkillUpgradeData` ou `RoomData` ne reçoit d’état
runtime partagé.

Cette validation ne couvre pas les personnages définitifs, de nouvelles
disciplines, les rangs 3+, un grimoire complet, l’équipement, la sélection
finale de l’équipe, la sauvegarde disque ou la direction artistique.

La validation de ce lot a été exécutée dans l’environnement headless Godot
4.6.3, sans possibilité de piloter graphiquement un combat complet. Les
contrats de composition, déploiement, tours, remplacement du HUD, visibilité
énergétique, XP, file post-combat, transitions de salle et nettoyage sont donc
couverts par des tests ciblés et par la suite complète. Une passe interactive
reste recommandée pour apprécier uniquement le rendu et l’ergonomie.

La prochaine étape pourra faire tester cette architecture par de futurs
personnages conçus pour elle, puis décider si le game design impose une
identité d’instance capable d’autoriser les doublons de héros.
