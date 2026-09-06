# Le Dialecticien — kit de combat

Ennemi philosopher_mage, mage grec de soutien : 76 PV, 4 PA, 3 PM, initiative 12. Il possède cinq sorts et aucune attaque de base invisible. Sa menace vient de ses deux actions possibles par activation et de la protection de son partenaire.

| Sort | PA | Portée | Résultat | Disponibilité | Geste |
| --- | ---: | --- | --- | --- | --- |
| Axiome | 2 | 2–5, ligne de vue | 16 dégâts magiques sacrés | Deux lancers possibles avec 4 PA | Attaque |
| Réfutation | 2 | Adjacent | 8 dégâts magiques et repousse d’une case | Une fois par activation | Contrôle, paume de refus |
| Maïeutique | 2 | Soi ou allié à 0–4, ligne de vue | 22 PV rendus | Une activation sur deux | Soin |
| Aporie | 2 | Ennemi à 2–4, ligne de vue | −2 PM à la prochaine activation, durée un tour | Une activation sur deux | Contrôle |
| Égide du Logos | 2 | Soi ou allié à 0–4, ligne de vue | 20 bouclier, expire au début de la deuxième activation suivante du bénéficiaire | Une activation sur deux | Bouclier |

Les PA, dégâts, soins, réductions de PM, collisions et résistances passent par SpellCaster et Unit. Aporie laisse les PA et les attaques disponibles. Les boucliers de sources différentes coexistent ; Égide ne s’additionne pas indéfiniment à sa propre source.

## Décisions du mage

La stratégie SUPPORT_MAGE ne change pas les IA antérieures. Elle privilégie un soin utile sous 70 % de PV, puis une Réfutation contre un adversaire adjacent, une Égide sur un allié menacé à trois cases d’un adversaire, un contrôle absent, enfin une attaque. Elle ignore les morts, les mauvais camps, les sorts indisponibles et les boucliers déjà suffisants.

Le plan réserve les PA et les usages sans modifier les unités. Une Égide, un soin ou un contrôle ne se répète pas dans le même plan. Après une poussée, le plan ne devine pas la destination de la cible : le moteur résout collisions et vortex, et le mage peut encore protéger un allié. S’il ne peut rien lancer depuis sa case, il cherche un déplacement légal, tient compte du danger du chemin et préfère une distance de quatre cases. Chaque action est revalidée par EnemyTurnRunner au moment où elle est exécutée.

Le projectile Axiome part à la libération du geste ; ses dégâts arrivent 0,20 seconde après. Les autres effets sont résolus à la libération du geste. Les sprites n’appliquent aucun dégât eux-mêmes.

## Accès et données

La sélection d’aventure propose **L’Épreuve du Dialecticien**, un combat d’Achille contre le mage et un spectre au Gué du Léthé. La salle, la rencontre et la RunData sont distinctes de Catabase. Cette épreuve réutilise explicitement les définitions immuables du kit et de l’économie d’Achille ; les copies de combat et la progression de partie restent isolées par le pipeline habituel.

Les ressources sont découvertes par le catalogue d’ennemis du Studio :

- Unité : data/units/enemies/philosopher_mage.tres.
- Sorts : data/spells/enemies/philosopher_*.tres.
- Rencontre : data/encounters/philosopher_trial_encounter.tres.
- Partie : data/runs/philosopher_trial.tres.
- IA : data/ai/profiles/philosopher_support_ai.tres et core/ai/support_mage_decision.gd.
- Animations : data/characters/philosopher_mage/animations.tres.

## Vérification

test_philosopher_gameplay.gd couvre le plan complet, la dépense réelle des PA et PM, les soins de soi et d’alliés, le refus des soins inutiles, les ciblages légaux, les collisions, le contrôle temporaire, les cooldowns, le déplacement suivi de deux sorts, l’accès à la rencontre et les événements d’animation.

test_philosopher_shield_lifetime.gd vérifie le calendrier du bénéficiaire, les sources parallèles, la sauvegarde/restauration de l’échéance et la lecture des anciens snapshots. Régressions associées : test_sourced_shields.gd, test_spectre_gameplay.gd, test_character_selection_screen.gd.

Ces tests sont conçus pour être exécutés ensemble après import des sprites définitifs. Le rapport d’intégration réunit les résultats exécutés et les captures du combat réel.


## Dalles et placement tactique

Le Dialecticien lit la couche de terrain effective, permanente ou temporaire. Il peut quitter une dalle nocive avant de lancer, même s’il avait déjà une cible à portée, et compare les chemins selon leur coût PM réel, les dégâts d’entrée, les pénalités de statut et le risque de la case finale. L’eau reste franchissable et coûte le PM défini par la carte ; Mouillé et Gelé diminuent les PM à leur échéance canonique, sans glissade inventée. Le mage évite les traversées létales et l’eau électrifiée volontaire qui consommerait son activation.

Réfutation privilégie une cible ou un angle qui pousse réellement dans l’eau, la glace, la lave, le poison ou l’eau électrifiée. Le calcul respecte les obstacles et la résistance au déplacement sans consommer cette résistance pendant la décision. Le moteur applique ensuite les vrais dégâts, statuts et éventuels déplacements ; aucune cible n’est attaquée à son ancienne case après la poussée. Axiome et Réfutation conservent leur élément sacré : ils ne créent pas de réaction de foudre, de fonte ou de vapeur.

Un vortex en paire est évalué depuis sa sortie réelle avec le coût de sa dalle d’entrée. Pour un réseau à plusieurs sorties, chaque destination possible doit être sûre ; un sort ne peut être programmé que s’il est légal depuis toutes les sorties. Les sorts sur soi attendent une position connue. Aucun tirage aléatoire n’est consulté ou avancé par la décision. Une seule sortie valide est déterministe ; un vortex solitaire applique son bonus PM uniquement lorsque le déplacement y entre réellement.

Validation logique dédiée : test/unit/test_philosopher_terrain_ai.gd. Elle projette des ArenaDefinition avec leurs dalles enregistrées et exécute les plans via GridData, TerrainEffects et SpellCaster ; le scénario graphique terrain complète ces assertions dans le véritable EnemyTurnRunner.

La room jouable de l’épreuve est désormais une copie autonome du Gué du Léthé avec huit dalles permanentes et une paire de vortex. Sa disposition et sa régénération sont décrites dans tools/philosopher_sprite_pipeline/README_trial_terrain.md. Les sources de la campagne restent intactes.
