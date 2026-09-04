# Première run v2 — architecture et validation

## Run et rencontres

`data/runs/first_run.tres` et `run_default.tres` chargent les six salles dans
l'ordre. Chaque `RoomData` référence une `EncounterDefinition`; aucun roster ni
placement n'est codé dans la scène de bataille.

| Salle | Composition initiale | Plafond vivant | Budget normal | Budget chef | Formations essayées |
|---|---:|---:|---:|---:|---|
| 1 | 4 normaux | 4 | 0 | 0 | ligne, double ligne, flancs, divisée |
| 2 | 3 normaux + 1 chef | 4 | 0 | 0 | chef en avant, ligne, double ligne, flancs |
| 3 | 4 normaux + 2 chefs | 6 | 0 | 0 | double ligne, chef en avant, divisée, ligne |
| 4 | 3 chefs + 1 centurion | 6 | 2 | 0 | centurion arrière, chef en avant, double ligne, divisée |
| 5 | 4 normaux + 2 chefs + 2 centurions | 10 | 2 | 1 | centurion arrière, double ligne, chef en avant, divisée, flancs |
| 6 | 4 chefs + 4 centurions | 10 | 2 | 1 | centurion arrière, chef en avant, double ligne, divisée, flancs |

`EncounterFormationPlanner` ordonne les candidats par rôle, zone et distance de
chemin, mélange les variantes avec le seed de run, valide l'occupation, la
navigabilité et les distances, puis essaie la formation suivante en cas
d'échec. Le plan n'accepte jamais un roster partiel. Les cases entièrement
masquées par le décor de premier plan sont exclues par les ressources des salles
1, 5 et 6; les tests couvrent vingt seeds par map.

`EncounterRuntimeState` appartient au combat. Il partage les compteurs entre
tous les centurions, réserve et libère les invocations télégraphiées, respecte
le plafond vivant, limite chaque lanceur à une attente et empêche `Lever le
chef` tant qu'un chef vivant ou en attente existe.

## Activation et priorités ennemies

`EnemyAI` produit un `EnemyActionPlan` borné, composé de déplacement, capacité
ou attaque et repositionnement. `EnemyTurnRunner` exécute ces étapes une seule
fois, dépense séparément PA et PM et revalide cible, portée, ligne de vue,
occupation et état de mort après chaque mouvement.

- Normal : cible marquée, puis cible atteignable prioritaire; déplacement puis
  `Lame osseuse` (18, ou 24 uniquement sur la cible marquée).
- Chef : résolution d'une Sentence déjà préparée; cible marquée atteignable
  pour Sentence; héros sous 60 %; attaque létale; cible marquée; plus faible
  pourcentage de PV; poursuite; protection du centurion. Sentence reste à 56,
  poussée 1, résolution à l'activation suivante et recharge 3.
- Centurion : première marque de faction; capacité disponible depuis la case
  actuelle puis repositionnement; sinon déplacement vers une case de lancement
  puis capacité. Les priorités suivantes restent Lance de givre, Égide et
  invocations selon leurs contrats et le budget de salle.

La marque coûte 2 PA, porte à 99, ignore la ligne de vue, dure deux activations
complètes de la cible et a une recharge de deux activations. Une seule marque
de faction est valide : initiative décroissante puis identifiant stable
croissant départagent les centurions.

## Cast utile, XP et progression

Le rapport central de résolution expose `did_change_combat_state`. Un cast ne
vaut 1 XP que s'il change réellement le combat : dégâts de PV ou de bouclier,
soin non perdu, hausse de bouclier, ajout/rafraîchissement réel de statut,
déplacement forcé, terrain créé/modifié ou invocation résolue. Échec, esquive,
soin plein, bouclier inchangé, statut identique, terrain identique et invocation
annulée valent 0. Plusieurs cibles ne donnent toujours qu'un point.

La déduplication se fait par discipline et activation; le plafond est de 5 XP
par discipline et combat, remis à zéro au combat suivant. Les seuils cumulés
communs aux douze arbres sont `0 / 5 / 12 / 21 / 30`. Le tableau avant/après et
l'audit des 192 feuilles sont dans `docs/design/skill_tree_balance_v2.md`.

## Équipements et récompenses

Le catalogue actif est `data/items/catalogs/default_item_catalog.tres` (les cinq
items historiques valides et les quatorze items ci-dessous). Le pool de la
première run est le tag `first_run_equipment_reward`.

| Item | Compatibilité | Effet runtime |
|---|---|---|
| Anneau de la faille | tous | +1 portée; −10 armure |
| Arc maudit | Elfe | +20 % dégâts offensifs; −10 PV max |
| Broche | tous | +25 PV max; +10 armure |
| Caillou | tous | +15 PV max; +10 armure; +10 résistance magique |
| Cape de brume | tous | +1 PM; +8 % esquive |
| Collier des sages | tous | +25 résistance magique; +15 % soins et boucliers |
| Couronne | tous | +1 PA; −15 PV max |
| Excalibur | Guerrier | +15 % dégâts physiques; +20 armure |
| Hache de l'exécuteur | Guerrier | +15 % dégâts physiques; +25 % sous 35 % PV cible |
| Harnois | Guerrier | +40 PV max; +40 armure |
| Manteau de givre | tous | +35 résistance magique; +25 % résistance glace |
| Matraque du troll | Guerrier | +10 % dégâts physiques; +1 poussée |
| Prisme élémentaire | Mage | +18 % dégâts élémentaires |
| Sceau | tous | +20 armure; +20 résistance magique |

`FirstRunEquipmentRewardService` mélange une pioche déterministe au démarrage,
propose deux IDs distincts sans remplacement après les salles 1 à 5, écarte le
choix refusé et les objets possédés, puis verrouille l'attribution. La salle 6
va directement au résultat. L'écran post-combat affiche les deux illustrations,
les compatibilités et comparaisons, le destinataire, la confirmation et le
remplacement via les services d'inventaire existants.

## Simulations, captures et performance

La simulation déterministe de 60 campagnes utilise par défaut les vraies
grilles, `EnemyAI`, `SpellCaster`, `DamageResolver`, progression, inventaire et
équipement. Elle est écrite dans
`artifacts/first_run_v2/simulation_runtime_all.json`. Résultat de clôture :
spécialisé 20/20, équilibré 7/20, sans progression 1/20. Les profils avec progression
attribuent cinq équipements sur toute victoire; aucun profil n'atteint tous les
rangs 5 avant la salle 6. Sur l'ensemble : 154 invocations normales, 1 chef et
un pic de 10 ennemis vivants. La validation dédiée force en plus les deux types
d'invocation et contrôle exactement leurs événements de télégraphe/résolution.

Les six compositions historiques sont dans
`artifacts/first_run_v2/captures/rooms/`. Le runner actuel
`tools/capture_post_combat_flow.gd` cible la véritable Odyssée avec Achille seul
et écrit le rapport, la progression ainsi que les états de sélection et
d'acquisition des reliques dans
`artifacts/odyssey_ui/captures/post_combat/`. Les actions tactiques historiques
sont dans `artifacts/skeleton_faction_audit/`.

Le stress réel de la salle 6 est écrit dans
`artifacts/first_run_v2/room_six_performance.json` : 8 ennemis initiaux, 2
invocations résolues, pic 10, 40 animations, un télégraphe actif, 165,234 FPS de
moyenne et 162,502 FPS minimum à 1920×1080 sur RTX 4070 Laptop. Les Nodes sont
restés à 706 (croissance 0); la mémoire finale a augmenté de 75 532 octets sans
croissance continue observée pendant l'échantillon.

Les processus de rendu Godot signalent encore à la fermeture des RIDs et
ressources orphelins liés aux sous-vues/ressources du renderer. Les compteurs
runtime du stress restent stables; ce signal de fermeture est donc documenté
séparément et n'est pas présenté comme une fuite croissante de la salle 6.
