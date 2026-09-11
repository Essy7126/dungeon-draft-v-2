# Audit des parcours Catabase — 11 septembre 2026

Instantané du commit `e3ad3060` ; catalogue v4, graine 2401. Vue de conception, sans brouillard : les secrets sont exposés.

## Périmètre

Parcours public : sélection → cinématique → Seuil des Ombres → vingt étapes de Catabase. Le Seuil est hors des vingt étapes. Les quinze ressources de salle constituent un catalogue, pas un ordre de visite. Les deux apparences d’Achille partagent ce parcours. Le refuge et les laboratoires ne sont pas des destinations du graphe ci-dessous.

## Affectation des décors

| Étape | Décor des combats | Autres possibilités |
|---|---|---|
| 1 | Caverne des brumes | — |
| 2 | La Porte des Porteurs | — |
| 3 | Galerie des piliers brisés | — |
| 4 | — | La Halle sous les racines — marchand ; Écran de halte générique — mémoire ; Écran de halte générique — repos |
| 5 | La Citerne des Échos | — |
| 6 | La Galerie des Braises | — |
| 7 | Crypte du courant | — |
| 8 | — | La Forge des Racines — marchand ; Le Sanctuaire des Sources Émeraude — sanctuaire ; Écran de halte générique — mémoire ; Écran de halte générique — sanctuaire (secret) |
| 9 | Le Péristyle Brisé | — |
| 10 | La Digue du Léthé | — |
| 11 | Gué souterrain | Bibliothèque : mémoire ou combat selon le tirage initial ; mémoire sur écran générique |
| 12 | — | Écran de halte générique — marchand ; Écran de halte générique — repos ; Écran de halte générique — sanctuaire |
| 13 | La Cour des Mesures | — |
| 14 | La Nécropole des Vœux | — |
| 15 | Le Carrefour des Offrandes | — |
| 16 | Les Degrés de Cendre (combat optionnel) | Écran générique : marchand, repos, mémoire secrète ; le défi peut devenir un sanctuaire selon le tirage initial |
| 17 | Les Degrés de Cendre | — |
| 18 | L'Atrium des Moires | — |
| 19 | — | Écran de halte générique — repos ; Écran de halte générique — sanctuaire |
| 20 | Temple du Serment Noir | — |

## Points de cohérence à arbitrer

- **Continuité visuelle :** les cavernes occupent I, III, VII et XI. Les étapes intermédiaires utilisent des arènes modulaires. Les noms historiques « salles I–IV » ne décrivent pas leur place dans la descente.
- **Identité des embranchements :** à une profondeur donnée, les combats partagent la même map ; les différences portent sur les rencontres, récompenses, services et connexions. Des chemins à biomes distincts demanderaient une affectation de map par destination.
- **Répétition possible :** le défi de XVI et le combat de XVII partagent Les Degrés de Cendre ; certains parcours peuvent donc répéter ce décor immédiatement.
- **Couverture des haltes :** Halle au marchand IV, Émeraude au sanctuaire VIII, Forge au marchand VIII. Les autres destinations utilisent l’écran générique ; le secret VIII n’hérite pas du décor Émeraude (lane 3 exclue par le catalogue). Les choix de progression obligatoires passent d’abord par l’écran d’expédition.
- **Pilotes hors parcours :** Atelier du Bronze ne figure pas dans les affectations de route. Son existence jouable ne vaut pas intégration à la descente.
- **Variété des rencontres :** les trois branches de II demandent healing/armor/control, mais le catalogue n’offre une composition alternative que pour ranged. Elles utilisent donc toutes « Les porteurs de bronze ». À XVIII, la variante melee existe dans le catalogue mais les destinations v4 demandent ranged/healing/control : la phalange n’y est pas sélectionnée. Récompenses et connexions restent différentes.
- **Niveau :** l’étape mesure la profondeur de descente, pas le niveau du héros. Celui-ci dépend des victoires/XP et des détours ; aucun niveau fixe n’a été inventé.

## Détail des destinations — graine 2401

| ID | Étape | Destination | Type réel | Décor | Rencontre / service | Sorties |
|---|---|---|---|---|---|---|
| `d01_0` | 1 | Le seuil de Catabase | combat | Caverne des brumes | Rencontre canonique conservée | d02_0, d02_1, d02_2 |
| `d02_0` | 2 | La sente des oliviers | combat | La Porte des Porteurs | Les porteurs de bronze | d03_0, d03_1 |
| `d02_1` | 2 | Le portique des oboles | combat | La Porte des Porteurs | Les porteurs de bronze | d03_2 |
| `d02_2` | 2 | Les traces du LÃ©thÃ© | combat | La Porte des Porteurs | Les porteurs de bronze | d03_3 |
| `d03_0` | 3 | Les guetteurs du bosquet | combat | Galerie des piliers brisés | La premiÃ¨re chasse | d04_0 |
| `d03_1` | 3 | La garde des sources | combat | Galerie des piliers brisés | Le tribut de bronze | d04_0 |
| `d03_2` | 3 | Les percepteurs d'airain | élite | Galerie des piliers brisés | Le tribut de bronze | d04_1 |
| `d03_3` | 3 | Les lances oubliÃ©es | combat | Galerie des piliers brisés | Le tribut de bronze | d04_2 |
| `d04_0` | 4 | Le camp des compagnons | repos | Écran de halte générique | Repos offert Â· rÃ©cupÃ©rer 30 % des PV maximum, une fois. Aucun Ã©tal. | d05_0 |
| `d04_1` | 4 | L'Ã©tal du passeur | marchand | La Halle sous les racines | Trois Ã©quipements Ã  acheter. Aucun soin ni passage rÃ©vÃ©lÃ© ici. | d05_0 |
| `d04_2` | 4 | La stÃ¨le des noms | mémoire | Écran de halte générique | RÃ©vÃ©ler un passage secret Ã  venir et recevoir 20 oboles. Aucun soin. | d05_1 |
| `d05_0` | 5 | Le guÃ© des serments | combat | La Citerne des Échos | La gardienne du guÃ© | d06_0, d06_1 |
| `d05_1` | 5 | Les roseaux du tireur | combat | La Citerne des Échos | Les roseaux sifflants | d06_2 |
| `d06_0` | 6 | L'atrium des cendres | combat | La Galerie des Braises | La procession des cinq | d07_0 |
| `d06_1` | 6 | Les gardiens du foyer | combat · ? tiré à la création | La Galerie des Braises | La meute des braises | d07_0 |
| `d06_2` | 6 | Les duellistes du guÃ© | élite | La Galerie des Braises | La procession des cinq | d07_0 |
| `d07_0` | 7 | L'Ã©preuve du bronze | élite | Crypte du courant | Rencontre canonique conservée | d08_0, d08_1, d08_2, d08_secret |
| `d08_0` | 8 | L'autel des serments | sanctuaire | Le Sanctuaire des Sources Émeraude | DÃ©couvrir une branche (70 ou 110 oboles), ou accepter un tribut. | d09_0, d09_1 |
| `d08_1` | 8 | La forge des cuirasses | marchand | La Forge des Racines | Trois Ã©quipements Ã  acheter. Aucun soin ni passage rÃ©vÃ©lÃ© ici. | d09_2 |
| `d08_2` | 8 | La mÃ©moire de Chiron | mémoire | Écran de halte générique | RÃ©vÃ©ler un passage secret Ã  venir et recevoir 20 oboles. Aucun soin. | d09_3 |
| `d08_secret` | 8 | L'atelier sous la racine | sanctuaire · secret | Écran de halte générique | DÃ©couvrir une branche (70 ou 110 oboles), ou accepter un tribut. | d09_3 |
| `d09_0` | 9 | Les braises du cloÃ®tre | combat | Le Péristyle Brisé | Le premier officiant | d10_0 |
| `d09_1` | 9 | Les gardes du pacte | élite | Le Péristyle Brisé | Le premier officiant | d10_0 |
| `d09_2` | 9 | Les porteurs d'airain | combat | Le Péristyle Brisé | Le premier officiant | d10_1 |
| `d09_3` | 9 | Les pas sans retour | combat | Le Péristyle Brisé | La nuÃ©e du Styx | d10_2 |
| `d10_0` | 10 | Les arches du poursuivant | combat | La Digue du Léthé | Les lignes de chasse | d11_0 |
| `d10_1` | 10 | Les chaÃ®nes sous les arches | élite | La Digue du Léthé | L'aimant et l'enclume | d11_0 |
| `d10_2` | 10 | Les veilleurs des stÃ¨les | combat | La Digue du Léthé | Les lignes de chasse | d11_1 |
| `d11_0` | 11 | La fosse des revenants | combat | Gué souterrain | Les deux piliers | d12_0, d12_1 |
| `d11_1` | 11 | La bibliothÃ¨que engloutie | mémoire · ? tiré à la création | Écran de halte générique | Nature inconnue Â· combat ou halte possible | d12_2 |
| `d12_0` | 12 | Le bivouac des six mÃ©moires | repos | Écran de halte générique | Repos offert Â· rÃ©cupÃ©rer 30 % des PV maximum, une fois. Aucun Ã©tal. | d13_0 |
| `d12_1` | 12 | Le pacte du sixiÃ¨me geste | sanctuaire | Écran de halte générique | DÃ©couvrir une branche (70 ou 110 oboles), ou accepter un tribut. | d13_1 |
| `d12_2` | 12 | Le comptoir des offrandes | marchand | Écran de halte générique | Trois Ã©quipements Ã  acheter. Aucun soin ni passage rÃ©vÃ©lÃ© ici. | d13_2 |
| `d13_0` | 13 | La sente des derniers souffles | combat | La Cour des Mesures | La fournaise vivante | d14_0, d14_1 |
| `d13_1` | 13 | Les terrasses de l'orage | combat | La Cour des Mesures | La fournaise vivante | d14_2 |
| `d13_2` | 13 | Le rempart des terrasses | combat | La Cour des Mesures | La batterie d'airain | d14_3 |
| `d14_0` | 14 | Le pont des longs traits | combat | La Nécropole des Vœux | La chasse blanche | d15_0 |
| `d14_1` | 14 | Les fers de la terrasse | combat | La Nécropole des Vœux | Les cinq colosses | d15_0 |
| `d14_2` | 14 | Les gardes de la foudre | élite | La Nécropole des Vœux | La chasse blanche | d15_0 |
| `d14_3` | 14 | Le pÃ©age du dernier bronze | élite | La Nécropole des Vœux | La chasse blanche | d15_0 |
| `d15_0` | 15 | L'Ã©preuve des obÃ©lisques | élite | Le Carrefour des Offrandes | Le serment de l'enclume | d16_0, d16_1, d16_2, d16_secret |
| `d16_0` | 16 | Le marchÃ© du dernier feu | marchand | Écran de halte générique | Trois Ã©quipements Ã  acheter. Aucun soin ni passage rÃ©vÃ©lÃ© ici. | d17_0, d17_1 |
| `d16_1` | 16 | Le foyer des revenants | repos | Écran de halte générique | Repos offert Â· rÃ©cupÃ©rer 30 % des PV maximum, une fois. Aucun Ã©tal. | d17_2 |
| `d16_2` | 16 | Le dÃ©fi sans repos | élite · ? tiré à la création | Les Degrés de Cendre | Le champion sans repos | d17_3 |
| `d16_secret` | 16 | Le tombeau du serment intact | mémoire · secret | Écran de halte générique | RÃ©vÃ©ler un passage secret Ã  venir et recevoir 20 oboles. Aucun soin. | d17_3 |
| `d17_0` | 17 | Les porteurs du jardin | combat | Les Degrés de Cendre | Le dernier rempart | d18_0 |
| `d17_1` | 17 | Les lances du dernier tribut | élite | Les Degrés de Cendre | Le hurlement du jardin | d18_0 |
| `d17_2` | 17 | Le jardin des dalles fendues | combat | Les Degrés de Cendre | Le hurlement du jardin | d18_1 |
| `d17_3` | 17 | Les ombres du serment | combat | Les Degrés de Cendre | Le hurlement du jardin | d18_2 |
| `d18_0` | 18 | Le vestibule des lances noires | élite | L'Atrium des Moires | Le convoi des Ã¢mes | d19_0 |
| `d18_1` | 18 | Les gardiens du souffle | combat | L'Atrium des Moires | Le convoi des Ã¢mes | d19_0 |
| `d18_2` | 18 | Le vestibule des derniers noms | combat | L'Atrium des Moires | Le convoi des Ã¢mes | d19_1 |
| `d19_0` | 19 | Le feu avant PÃ¢ris | repos | Écran de halte générique | Repos offert Â· rÃ©cupÃ©rer 30 % des PV maximum, une fois. Aucun Ã©tal. | d20_0 |
| `d19_1` | 19 | L'ultime offrande | sanctuaire | Écran de halte générique | DÃ©couvrir une branche (70 ou 110 oboles), ou accepter un tribut. | d20_0 |
| `d20_0` | 20 | PÃ¢ris â€” le seuil de la Catabase | boss | Temple du Serment Noir | Rencontre canonique conservée | Fin |

## Sources et vérifications exécutées

- 17 graphes générés par Godot 4.7.1 avec les deux scripts de route copiés à l’identique dans un projet isolé. Les fonctions pures de prévisualisation des rencontres sont extraites textuellement du catalogue courant ; aucune instanciation de combat.
- Graine 2401 : 55 destinations, 385 chemins structurels complets, 14–16 combats. Les chemins incluant un secret supposent sa découverte ; ces comptes ne garantissent pas l’accessibilité économique ou narrative de chaque choix.
- Vérifiés par script : unicité des destinations, références de sorties, avancement d’une étape, atteignabilité structurelle de tous les nœuds, fin à XX, enveloppe 14–16 combats, lecture des quinze plans et de leurs manifestes géométriques.
- Le processus Godot termine avec code 0 et produit les exports, mais signale une erreur d’accès au magasin de certificats Windows. Il ne s’agit donc pas d’une exécution sans diagnostic moteur. Aucun accès réseau n’est utilisé pour cet export.
- Aucun import du projet principal, test de gameplay, playtest, contrôle visuel des décors ou test CI relancé. Cet audit ne valide ni l’équilibrage ni les rendus.

Sources d’autorité :

Exports et scripts de cette passe : [données enrichies](../../artifacts/dev/20260911-route-audit/audit.json), [empreintes des sources](../../artifacts/dev/20260911-route-audit/provenance.json), [journal Godot](../../artifacts/dev/20260911-route-audit/export.log). Ces fichiers de preuve sont locaux et ignorés par Git. Le rapport Markdown est un nouveau fichier à versionner ; le README le référence.

- [expedition_route_catalog.gd](../../core/expedition/expedition_route_catalog.gd)
- [expedition_route_itineraries.gd](../../core/expedition/expedition_route_itineraries.gd)
- [expedition_map_catalog.gd](../../core/expedition/expedition_map_catalog.gd)
- [catabase_monster_encounter_catalog.gd](../../core/expedition/catabase_monster_encounter_catalog.gd)
- [expedition_run_factory.gd](../../core/expedition/expedition_run_factory.gd)
- [painted_halt_catalog.gd](../../core/expedition/painted_halt_catalog.gd)
- [game_manager.gd](../../core/game_manager.gd)
- [route_bindings.json](../../data/halts/route_bindings.json)
- [blueprints.json](../../data/rooms/catabase_expansion/blueprints.json)

## Usage pour les prochaines constructions

Avant de produire une map : fixer ses étapes et destinations, son rôle tactique, sa famille visuelle, la transition depuis les lieux précédents, les rencontres visées et les possibilités abandonnées au prochain embranchement. Une vue éditeur devrait exposer ces mêmes liens, les ressources sources et les réutilisations. Les affectations restent actuellement dans les catalogues GDScript et JSON ; cet audit ne les édite pas.
