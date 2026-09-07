# Achille : kit sprite de combat v2

Achille utilise désormais des gestes adaptés aux quatre sorts actuels et à leurs évolutions. La Percée déplace réellement sa vue jusqu'à la case résolue ; sa pose aérienne est maintenue pendant le trajet, puis la réception se joue au contact du sol. Bastion attend cette arrivée pour régler sa consommation de Garde, ses dégâts et sa poussée.

Le kit contient **40 clips dans les quatre orientations** : les 12 clips historiques de repos, marche et attaque sont conservés, et 28 clips ajoutent charge, arc, garde, frappe étendue, volée, réaction et chute. Les sources comprennent 112 nouveaux dessins de personnage et 24 dessins d'effets. Un relâchement d'arc est partagé avec la Volée nord pour conserver le bouclier au dos : 111 nouveaux dessins distincts sont effectivement référencés dans les clips.

## Gestes et cadence

| Action | Lecture du corps | Cadence du profil |
| --- | --- | --- |
| Repos | Pose canonique fixe, sans autoplay | Aucune oscillation ni translation |
| Marche / course | Cycle historique de huit poses, lié à la progression du déplacement | Les appuis suivent le déplacement réel |
| Frappe du Péléide | Estoc historique | 0,60 s ; impact à 0,30 s |
| Percée fulgurante | Préparation, lancement, pose aérienne maintenue, réception | Départ à 0,10 s ; trajet selon la distance, réception de 0,08 s |
| Tir du Pélion | Sortie de l'arc, armé, relâchement, récupération | 0,72 s ; départ de flèche à 0,36 s, vol de 0,20 s |
| Garde d'airain | Levée, mise en garde, appui fort, récupération | 0,48 s ; Garde à 0,24 s |
| Fléau de Troie | Frappe de lance étendue avec arc d'effet | 0,72 s ; impact à 0,36 s |
| Volée du centaure | Armé de plusieurs flèches puis relâchement | 0,72 s ; trois trajectoires vers les cases légales |
| Coup reçu | Réaction brève sans déplacer l'ancre au sol | 0,24 s |
| Défaite | Fléchissement, genou, chute, pose couchée | 0,48 s puis fondu de 0,12 s |

Les horloges de présentation sont contrôlées explicitement, respectent la pause et empêchent une grosse frame de perdre ou de doubler un marqueur. Une réception ne bloque pas une nouvelle action. Les annulations et la destruction d'une vue terminent leurs attentes avant de libérer l'objet.

## Évolutions et effets

Le résolveur lit le profil réel du sort et les maîtrises sélectionnées, y compris lorsque l'identifiant du sort n'a pas changé. Ligne de mort et perforation partagent le geste d'arc ; Fléau et Volée possèdent leurs propres poses. Rempart dessine trois pavois sur les cellules réellement enregistrées et les retire à expiration. Les accents de doctrine et d'intensité changent le rendu, jamais la surface des dégâts.

Les flèches commencent leur vol avant la résolution. Les impacts confirment uniquement les victimes réellement touchées, en conservant la cellule d'impact avant une poussée ou une mort. Les réactions automatiques produisent un impact bref au moment de leur résolution, sans rejouer une longue attaque après les dégâts ni dépenser un usage manuel.

Le raccord des catalogues de classification est également corrigé dans Battle. La Coupe lourde du spectre est explicitement une attaque de mêlée : elle peut maintenant déclencher le Contre d'Éaque. Les classifications proviennent des données ; aucune déduction depuis la portée ou le dessin de l'arme n'est utilisée.

## Cohérence et fabrication

Le casque ouvert, le visage blond découvert, la crête rouge, le plastron ivoire, la jupe bleu pétrole et le bouclier à chevron restent les repères du modèle. Les armes sont rangées au dos pendant le tir. Les sources et les prompts exacts sont conservés, ainsi que les raisons des rejets artistiques.

Les dessins sont découpés et assemblés mécaniquement. Chaque feuille utilise une seule échelle ; chaque pose possède une racine au sol revue. Le bas d'une lance ne sert jamais d'ancre. Les régions d'atlas sont vérifiées octet pour octet, avec SHA des sources et des sorties. Les effets disposent de fenêtres de découpe explicitement mesurées ; le nettoyage ne touche que des résidus d'alpha faible sur leurs frontières, avec bilan consigné.

Points d'entrée :

- [Profil du personnage](../../../data/visuals/achilles/achilles_kit_sprite_profile_v2.tres).
- [Inventaire des quatre sorts et des 36 maîtrises](achilles_spell_animation_inventory_v2.md).
- [Sources et prompts du personnage](../../../art/source/characters/achilles/sprites_kit_v2/README.md).
- [Pipeline de personnage](../../../tools/achilles_kit_sprite_pipeline/README.md) et [pipeline d'effets](../../../tools/achilles_kit_sprite_pipeline/README_effects.md).
- [Harness de combat reproductible](../../../tools/achilles_kit_sprite_validation/README.md).

## Validation effectuée

- **148 tests GUT ciblés réussis ensemble**, 16 scripts, 3 315 assertions.
- **17 tests Node réussis** sur le découpage, l'alpha, les références et les substitutions explicites.
- **28 combats réussis** : sept scénarios de kits dans chacune des quatre directions, avec contrôles des sprites effectivement affichés et des erreurs de script.
- Dans cette matrice, erreur mesurée de l'ancre au repos : **0 pixel**. La Percée conserve son clip de charge pendant tout le trajet et rejoint exactement sa destination.
- Combat de défaite réel : six réactions non létales complètes, 110 PV perdus par les coups des spectres, une seule chute et une seule fin après fondu ; aucune translation de l'ancre. Durée mesurée de la chute avec fondu : environ **608 ms**.

Le [rapport compact](achilles_kit_validation_v2.json) conserve les mesures et les chemins des journaux. Les tests de cadence sont distincts des captures, car la lecture GPU peut ralentir une capture. Les GIF utilisent leurs timestamps originaux et n'ajoutent aucun ralenti.

Les configurations de niveau élevé utilisent une fixture XP annoncée, puis les achats légaux de maîtrises. Elles ne prétendent pas rejouer une campagne complète jusqu'au niveau 13. Godot signale encore des objets, RID, ressources et pages d'allocateur en usage lors de l'extinction ; ces diagnostics de fermeture sont conservés et ne sont pas présentés comme corrigés.

## Captures de jeu

[Tir du Pélion](media/achilles_shot_v2.gif) · [Bastion et Rempart](media/achilles_bastion_v2.gif) · [Volée](media/achilles_volley_v2.gif) · [Réaction et défaite](media/achilles_defeat_v2.gif).

Chaque média est accompagné de son manifeste de capture et de son rapport d'encodage : images source, timestamps, dimensions, durée et ordre vérifiés après décodage.
