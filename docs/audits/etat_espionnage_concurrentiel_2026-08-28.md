# État d'espionnage concurrentiel — Dungeon Draft

**Date :** 28 août 2026  
**Périmètre :** positionnement, gameplay, progression, génération, théorie de design, narration, direction artistique, UX, accessibilité, audio, architecture, données, outils, performance, production et mise sur le marché.  
**Méthode :** lecture statique du dépôt et de ses audits/captures, comparaison avec des références publiques 2021–2026 et quelques classiques structurants. Les chiffres de réception des boutiques évoluent ; les constats de marché sont donc datés de cet audit. Aucun code propriétaire concurrent n'a été étudié.

> Ici, « copier » signifie reprendre un principe de design, une méthode de production ou un standard de qualité. Il ne faut copier ni assets, ni textes, ni personnages, ni interface au pixel près, ni identité protégée.

## Verdict en une minute

Dungeon Draft possède déjà **plus de moteur tactique que de produit roguelite**. Ses meilleures briques sont la grille déterministe, les PA/PM, les poussées et terrains, l'évolution d'une compétence déclenchée pendant le combat, la modélisation en Resources et un Studio auteur très développé. Ses retards sont la structure de run, la lisibilité des menaces, la sauvegarde, la mémoire narrative, l'unité visuelle, l'accessibilité et l'industrialisation d'un build distribuable.

Le choix le plus important n'est donc pas une nouvelle fonctionnalité. C'est un choix d'identité :

> **Faire de Dungeon Draft une anthologie de catabases tactiques : chaque run suit un héros légendaire dans une descente courte, lisible et rejouable, où ses actions font évoluer son kit et où l'Archiviste se souvient de ce qu'il est devenu.**

La formule de référence n'est pas « copier X ». C'est :

> **La lisibilité d'Into the Breach + le droit d'expérimenter de Tactical Breach Wizards + la mémoire mythologique de Hades II/Wildermyth + votre draft de compétences en plein combat.**

Cette combinaison est nettement plus différenciante qu'un trio fantasy traversant six biomes génériques. Le chantier Catabase/Achille déjà présent dans le worktree est donc une **direction de marque à fort potentiel**, pas seulement une run secondaire.

## Scorecard actuelle

Les notes évaluent l'état observable du produit, pas la quantité de travail déjà investie.

| Secteur | Aujourd'hui | Potentiel | Diagnostic court |
|---|---:|---:|---|
| Profondeur tactique | 8/10 | 9/10 | Beaucoup de verbes systémiques déjà présents |
| Signature « évolution en combat » | 8/10 | 10/10 | Différenciation la plus rare du projet |
| Lisibilité des menaces | 5/10 | 9/10 | Télégraphes ponctuels, pas de contrat général d'intention |
| Variété des rencontres | 4/10 | 8/10 | Socle de génération solide, objectifs et rôles encore étroits |
| Structure de run / autonomie | 4/10 | 9/10 | Six salles ordonnées ; peu de décisions macro |
| Économie / récompenses | 4/10 | 8/10 | Deux choix fonctionnels, trop d'objets statistiques |
| Balance | 5/10 | 8/10 | Simulation utile, signal massif de spécialisation dominante |
| Narration et mémoire de run | 3/10 | 9/10 | Archiviste et rapports existent, mais se répondent peu |
| Identité thématique | 5/10 | 9/10 | Générique aujourd'hui ; Catabase peut devenir la marque |
| Cohérence visuelle | 4/10 | 8/10 | Beaux éléments, mais plusieurs langages artistiques concurrents |
| UX de combat | 6/10 | 8/10 | Gros progrès documentés, surcharge et arbre encore très denses |
| Accessibilité | 4/10 | 8/10 | Mode mouvement réduit ; remap, échelle texte et persistance manquent |
| Architecture data-driven | 8/10 | 9/10 | Très bonne utilisation des Resources Godot |
| Architecture runtime | 5/10 | 8/10 | Plusieurs fichiers-orchestrateurs devenus trop larges |
| Outils auteur | 9/10 | 9/10 | Avantage compétitif, avec risque de surinvestissement |
| Performance prouvée | 5/10 | 8/10 | Bon signal haut de gamme, matrice cible insuffisante |
| Préparation release | 3/10 | 8/10 | Pas d'export CI, dette de tests, sauvegarde et droits à sécuriser |

## Ce que le jeu est réellement aujourd'hui

Le cœur jouable observé est un roguelite tactique sur grille avec :

- une équipe Elfe/Mage/Guerrier sur le premier run, 6 PA et 3 PM par héros, quatre capacités chacun ;
- portées, ligne de vue, déplacement pondéré, poussées, attractions, surfaces, statuts, résistances et actions différées ;
- douze arbres de disciplines très ramifiés, avec évolution déclenchée en plein combat et effet dès le prochain cast ;
- des PV persistants entre les salles ;
- six salles ordonnées sur le premier run, formations seedées et rencontres essentiellement fondées sur la famille squelette ;
- deux offres d'équipement après les salles 1 à 5 ;
- un hub, l'Archiviste, des transitions, des rapports de combat et plusieurs prototypes de runs.

La base est largement data-driven : `RunData`, `RoomData`, `EncounterDefinition`, `UnitData`, `Spell`, terrains, statuts, objets et profils de présentation. Cela suit une bonne direction Godot : les [Resources sont conçues comme des conteneurs de données sérialisables, éditables et compatibles avec le versionnage texte](https://docs.godotengine.org/en/4.7/tutorials/scripting/resources.html).

Le dépôt possède aussi un outil auteur inhabituellement large. C'est une force si le Studio diminue réellement le temps nécessaire pour sortir des rencontres. C'est une dette s'il devient le produit principal à la place du jeu.

## Carte des références à étudier

| Référence | Année | Secteur de référence | Ce qu'il faut adapter | Ce qu'il faut éviter |
|---|---:|---|---|---|
| [Into the Breach](https://www.subsetgames.com/itb.html) | 2018 | Lisibilité tactique | Intentions, conséquences et poussées entièrement compréhensibles | Transformer toute run en puzzle sans attrition |
| [Tactical Breach Wizards](https://store.steampowered.com/app/1043810/Tactical_Breach_Wizards/) | 2024 | Expérimentation, missions | Preview, rewind, petites situations artisanales, objectifs de style | Rewind infini qui annule toute conséquence roguelite |
| [Shogun Showdown](https://store.steampowered.com/app/2084000/Shogun_Showdown/) | 2024 | Densité de décision | Petit vocabulaire, ordre des actions très visible, chaque action compte | Réduire votre grille à un rail |
| [StarVaders](https://star-vaders.com/) | 2025 | Tactique + builds | Combos lisibles, rewind thématique, ascensions/challenges après le cœur | Gonfler le catalogue avant de prouver la boucle |
| [Inkbound](https://store.steampowered.com/app/1062810/Inkbound/) | 2024 | Tempo du tour par tour | Résolution rapide quand le choix est simple, temps laissé aux menaces | Abandonner la grille pour du déplacement libre |
| [The Last Spell](https://lastspell.com/) | 2023 | Attrition et difficulté | Doctrines pré-run, difficultés modulaires, tension du soin | Empiler trop tôt les couches de méta-progression |
| [Darkest Dungeon II](https://www.darkestdungeon.com/darkest-dungeon-2/about/) | 2023 | Histoire de run | États et événements qui font émerger un récit d'expédition | RNG relationnelle qui retire l'agence |
| [Hades II](https://www.supergiantgames.com/blog/hades2-now-available/) | 2025 | Mythe, hub, échec narratif | Monde qui répond aux revers et accomplissements ; cohérence audiovisuelle | Viser son volume de doublage et de contenu |
| [Wildermyth](https://www.worldwalkergames.com/) | 2021 | Mémoire systémique | Faits saillants, transformations, héritage des héros | Génération de texte qui invente des faits |
| [Monster Train 2](https://store.steampowered.com/app/2742830/Monster_Train_2/) | 2025 | Méta et challenges | Hub, modificateurs pré-run, logbook, défis artisanaux puis quotidiens | Lancer ces modes avant une run centrale excellente |
| [Slay the Spire](https://store.steampowered.com/app/646570/Slay_the_Spire/) | 2019 | Routes et métriques | Risque/récompense, reliques qui changent les règles, métriques contextuelles | Ajouter un deck parce que le genre le fait |
| [Balatro](https://store.steampowered.com/app/2379780/Balatro/) | 2024 | Objets transformateurs | Chaque récompense doit pouvoir changer une décision ou un moteur de build | Multiplicateurs opaques et inflation numérique |
| [Sunderfolk](https://store.steampowered.com/app/2414270/Sunderfolk) | 2025 | Coopération de groupe | Ordre d'activation flexible, synergies d'équipe, village cohérent | Le téléphone-contrôleur, sans rapport avec votre promesse |
| [Metal Slug Tactics](https://store.steampowered.com/app/1590760/METAL_SLUG_TACTICS/) | 2024 | Présentation et combos | Attaques synchronisées, identité visuelle immédiate | Confondre volume de maps/mods avec variété ressentie |
| [Rogue Waters](https://store.steampowered.com/app/1691190/Rogue_Waters/) | 2024 | Décor tactique | Pousser dans des dangers, environnement comme arme | Remplissage procédural générique |
| [Knights in Tight Spaces](https://store.steampowered.com/app/2315400/Knights_in_Tight_Spaces/) | 2025 | Contre-exemple de scope | Style, positionnement et construction de build | Croire que davantage de cartes suffit à enrichir la boucle |
| [MENACE](https://store.steampowered.com/app/2432860/MENACE) | 2026 EA | Benchmark de finition 3D | Lecture moderne des unités, caméras et opérations | Son scope de production, hors d'échelle |

Le marché récent envoie un signal utile : les succès les plus nets du sous-genre ont une **grammaire étroite et immédiatement lisible**. À l'inverse, plusieurs jeux riches en contenu mais moins cohérents ont obtenu une réception plus mitigée. La quantité ne compense ni la promesse floue, ni la friction, ni la répétition.

## Doctrine produit recommandée

### Promesse

> « Descendez dans une mémoire mythologique. Manipulez les intentions ennemies, faites évoluer vos pouvoirs par vos actions, puis laissez l'Archiviste raconter ce que votre héros est devenu. »

### Trois piliers non négociables

1. **Chorégraphie tactique lisible.** Le joueur comprend la menace, prédit les conséquences et détourne le plan ennemi.
2. **Auteur de son build pendant l'action.** Le héros évolue parce que le joueur s'est comporté d'une certaine manière, pas seulement parce qu'il a ouvert un menu.
3. **Une expédition dont l'Archiviste se souvient.** Victoire comme défaite produisent une trace vérifiable et une réaction du monde.

### Le mot « Draft » doit devenir vrai à trois niveaux

- **Draft de salle :** choisir entre deux pactes ou destinations révélant risque, famille ennemie, objectif et type de récompense.
- **Draft de compétence :** l'évolution en combat reste la signature.
- **Draft d'équipement :** choisir une règle de build, du sustain ou un risque, pas seulement un meilleur chiffre.

Boucle cible :

> Archiviste → doctrine légère → choix de salle/pacte → combat lisible → évolution immédiate → choix équipement/sustain → chronique → salle suivante → épitaphe, seed et archive.

## Comparaison sectorielle et décisions à prendre

### 1. Combat et lisibilité

**État actuel.** Les systèmes savent produire des situations complexes, mais la présentation ne contracte pas encore assez cette complexité. Les télégraphes existent pour certains événements spéciaux ; les intentions ennemies futures générales sont absentes par choix historique.

**Standard à viser.** Une conséquence majeure ne doit jamais sembler arbitraire. Into the Breach affiche l'ensemble des attaques ennemies ; Tactical Breach Wizards autorise l'expérimentation ; Shogun Showdown rend l'ordre des actions central.

**À adapter.**

- Afficher pour chaque ennemi sa menace, sa portée et sa cible probable.
- Rendre exact tout télégraphe létal, grande zone, invocation ou action retardée.
- Prévisualiser dégâts, poussée, case d'arrivée, collision et réaction de terrain avant validation.
- Montrer la chaîne rendue possible par les PA restants.
- Ajouter un « Fil des Moires » : une ou deux annulations par run, uniquement avant révélation d'une information nouvelle.

**Décision de design à tester.** Un télégraphe exact de tout le tour rapproche le jeu d'un puzzle ; un simple cône de danger conserve plus d'improvisation. Tester les deux sur une même rencontre et mesurer compréhension, temps de tour et sentiment d'injustice.

### 2. Capacités, progression et builds

**Force unique.** L'évolution obligatoire d'une discipline en plein combat, appliquée au prochain sort, est la meilleure idée du projet. Aucune référence analysée ne combine exactement ce mécanisme avec PA/PM, poussées et terrains.

**Risque.** Douze arbres, seize feuilles terminales par arbre et une vue globale très dense créent plus de charge cognitive que de choix immédiat. Le backend peut rester riche sans tout exposer à la fois.

**À adapter.**

- En combat, ne montrer que le chemin courant et deux ou trois futurs réellement orthogonaux.
- Réserver l'arbre complet au codex/hub.
- Remplacer les nœuds purement numériques par des changements de verbes : zone contre contrôle, mobilité contre protection, terrain contre exécution.
- Créer des synergies de largeur afin qu'un build équilibré ne soit pas une spécialisation inachevée.
- Montrer les breakpoints concrets : cible supplémentaire, nouvelle case, interaction de surface, seuil létal.

**Signal de balance.** La simulation documentée de 60 campagnes donne 20/20 victoires au profil spécialisé, 7/20 à l'équilibré et 1/20 sans progression. L'échantillon ne remplace pas un playtest, mais la dominance est assez forte pour geler l'ajout de branches et corriger les coûts d'opportunité.

### 3. Terrains, cartes et objectifs

**Avantage latent.** Les terrains et poussées peuvent devenir votre deuxième signature. Aujourd'hui, ils risquent encore d'être perçus comme des modificateurs de décor.

**À adapter.**

- Construire chaque rencontre autour d'un verbe spatial : pousser, attirer, couper, contaminer, détourner, protéger ou sceller.
- Faire réagir eau, glace, lave, électricité, vortex et obstacles selon une grammaire constante.
- Garder les arènes peintes artisanales ; générer l'état de la rencontre, pas la géométrie complète.
- Utiliser la formule : **arène + formation seedée + objectif + mutation ennemie + état de terrain + règle de salle + récompense**.

**Objectifs à introduire avant de produire plus de biomes.**

- survivre un nombre de tours ;
- sceller des portails ;
- escorter une âme ;
- briser des ancres ;
- atteindre une sortie ;
- duel contre une Ombre ;
- choisir un sacrifice ;
- tuer une cible par collision ou terrain.

Six combats « éliminer tout le monde » ne constituent pas six expériences, même avec six fonds différents.

### 4. Ennemis, IA et difficulté

**État actuel.** L'IA, les rôles, formations, vagues et commandants sont techniquement avancés. La variété visible repose encore beaucoup sur une famille squelette et sur des écarts de statistiques.

**À adapter.**

- Six rôles orthogonaux valent mieux que vingt variantes numériques : bloqueur, pousseur, artilleur, protecteur, invocateur, prédateur de terrain.
- Les boss doivent changer une règle, pas seulement multiplier leurs PV.
- Créer une difficulté modulaire : nouvelles contraintes, timing plus serré, information réduite de façon explicite, composition plus synergique.
- Séparer cette difficulté d'un mode Assistance : PV reçus, vitesse, annulation, télégraphes et lisibilité peuvent être réglés indépendamment.

### 5. Structure de run, économie et rétention

**Retard principal.** La structure ordonnée donne peu d'autonomie macro. Le choix post-combat existe, mais il ne forme pas encore une économie.

**À adapter.**

- Entre les salles, proposer deux destinations dont on connaît risque, objectif, récompense dominante et famille ennemie.
- Si une monnaie apparaît, n'en créer qu'une : gagnée par objectifs optionnels, élites ou sacrifices ; dépensée pour soin, reroll, amélioration ou information.
- Maintenir une tension claire entre survie immédiate, puissance future et information.
- Introduire ascensions, challenges seedés et daily seulement après stabilité de la sauvegarde, du RNG et de la télémétrie.
- Préférer une progression horizontale : doctrines, variantes de héros, archives et nouveaux pactes. Éviter le grind obligatoire de statistiques.

Monster Train 2 est une bonne cible de maturité — hub, Pyre Hearts, logbook, défis artisanaux et quotidiens — mais précisément une **cible de phase 2**, pas une liste à implémenter maintenant.

### 6. Narration, univers et identité

**État actuel.** Le premier run raconte encore une fantasy générale de montagne, donjon et puissance ancienne. Les runs forêt, volcan et espace ne partagent pas une même grammaire fictionnelle. En parallèle, Catabase/Achille, l'Ombre de Paris et l'Archiviste ouvrent une direction beaucoup plus singulière.

**À adapter.**

- Faire de l'Archiviste le système central de continuité, pas un simple PNJ de menu.
- Utiliser `CombatReport` pour produire une à trois phrases fondées uniquement sur des faits : survie à 1 PV, élimination par collision, Sentence évitée, évolution décisive, salle parfaite.
- Conserver seed, build, moments remarquables et épitaphe dans une Archive.
- Faire réagir le hub après chaque run, même avec peu de texte.
- Structurer le contenu comme une anthologie : Achille, puis d'autres héros ayant chacun une Ombre, une grammaire de terrain et un dilemme.

Hades II démontre la puissance d'un récit qui se développe à travers « chaque revers et accomplissement » dans un monde mythologique cohérent ; sa version 1.0 est sortie le 25 septembre 2025 selon [Supergiant](https://www.supergiantgames.com/blog/hades2-now-available/). Il faut reprendre la relation entre boucle et récit, pas son volume de production.

**Recommandation de portefeuille.** Le trio actuel peut devenir le prologue/tutoriel ou un mode Héritage. Catabase devrait devenir le vertical slice de marque. Le biome spatial doit être retiré du slice ou réinterprété comme mémoire symbolique cohérente avec l'Archive.

### 7. Direction artistique et lisibilité visuelle

**État actuel.** Les fonds peints ont de la présence, les cartes de récompense sont déjà séduisantes et certains modèles ont une vraie personnalité. Mais quatre langages coexistent : décors peints semi-réalistes, unités 3D rendues en billboards, UI de cartes fantasy très ornementée et arbre de compétence utilitaire extrêmement dense.

**Problèmes prioritaires observés.**

- unités trop petites par rapport aux arènes ;
- beaucoup d'espace visuel sans rôle tactique ;
- contact au sol, lumière et saturation variables entre unités et fond ;
- contraste forêt/volcan/espace sans règle unificatrice ;
- hub aux personnages minuscules et aux marges noires importantes : son master carré 2048×2048 est ajusté dans un écran 16:9 sans recomposition dédiée ;
- arbre de progression qui couvre la bataille et ressemble à un outil desktop ;
- écran de récompense lisible mais proche du langage fantasy-card-game attendu ;
- certaines règles de récompense intégrées aux bitmaps, donc difficiles à localiser, redimensionner et maintenir alignées sur les `.tres`.

**À adapter.**

- Choisir une seule technique de production. L'option réaliste pour l'équipe actuelle est une 2,5D assumée : arènes peintes, personnages pré-rendus/3D, caméra et grade couleur communs.
- Produire un **styleframe autoritaire** réunissant une arène, trois unités, la grille, un ciblage, le HUD et une récompense ; toute nouvelle production doit prouver sa compatibilité avec ce cadre.
- Grossir les silhouettes jouables de 1,5 à 2 fois et recadrer l'arène sur la zone active.
- Normaliser ombre de contact, direction de lumière, contour, saturation et échelle.
- Construire trois couches : plan de jeu, éléments intermédiaires avec fade/cutaway, fond atmosphérique.
- Employer forme + couleur + animation + son pour toute information critique.
- Transformer l'ornement en langage propre à l'Archive : manuscrit funéraire, constellation mémorielle, sceaux, cire, bronze et cendre — pas une imitation de Hearthstone.
- Définir des budgets VFX : anticipation, impact, récupération, et variante mouvement réduit.

**Règle.** Une capture sans HUD doit identifier le jeu en moins de deux secondes ; une capture avec HUD doit permettre de distinguer héros, ennemis, danger et action choisie sans zoom.

### 8. UX, accessibilité et onboarding

**Bon acquis.** Les audits internes indiquent que verrouillage modal, raisons de ciblage invalide, raccourcis, redondance des marqueurs, confirmation de fin de tour et mouvement réduit ont déjà été améliorés. Il ne faut pas réouvrir ces chantiers sur la base de captures historiques.

**À faire.**

- Créer un véritable InputMap et rendre clavier/manette remappables ; plusieurs touches sont encore codées directement.
- Navigation complète sans souris et focus visible.
- Échelle de texte jusqu'à 200 %, reflow sans double scroll, option de police simple.
- Persister options visuelles, audio et accessibilité.
- Vitesse d'animation, pause sur les télégraphes, maintien/bascule, tremblement, flash et contraste configurables.
- Localiser via clés, tester pseudo-localisation et chaînes longues ; la majorité des textes restent écrits en dur en français.
- Ajouter sauvegarde/reprise, indispensable pour une run de 30–45 minutes.

Les [Xbox Accessibility Guidelines](https://learn.microsoft.com/en-us/xbox/accessibility/guidelines) recommandent notamment texte redimensionnable, remapping cohérent jusque dans les glyphes, interface opérable par entrées numériques et réglages des distractions visuelles. Le projet couvre une partie du mouvement, mais pas encore la chaîne entière.

**Onboarding recommandé.** Le tutoriel doit enseigner les trois plaisirs, pas tous les systèmes : lire une menace, détourner une conséquence avec le terrain, puis faire évoluer une compétence. Toute autre mécanique peut arriver plus tard.

### 9. Audio et sensation d'impact

**État visible dans le dépôt.** Musiques et cinématiques existent, mais l'audit ne trouve pas encore la preuve d'une grammaire de mixage aussi systématique que le gameplay.

Le gestionnaire audio actuel repose notamment sur un seul lecteur SFX global : déclencher un nouveau son peut remplacer le précédent. Cela limite les impacts superposés et la lisibilité d'une bataille riche.

**À adapter.**

- Un leitmotiv par héros/Ombre, transformé entre hub, combat et défaite.
- Catégories lisibles : sélection, menace, validation, déplacement, contrôle, rupture, mort, progression.
- Pools ou canaux concurrents par catégorie, avec limites de voix et priorités.
- Un signal sonore distinct pour toute information critique doublant le visuel.
- Ducking court sur impact et évolution ; éviter la saturation permanente.
- Variantes atténuées pour les répétitions fréquentes.
- Sous-titres/captions pour les sons nécessaires à la tactique.

L'objectif n'est pas davantage de sons : c'est que le joueur puisse reconnaître une classe d'événement sans regarder son icône.

### 10. Architecture et données

**Forces.** Grille, pathfinding, modèles de contenu et validations sont déjà bien séparés. Les Resources offrent un bon socle de catalogue. Les outils auteur, tests et rapports dépassent ce qu'on rencontre souvent à ce stade.

**Risques.**

- `battle/battle.gd`, `core/game_manager.gd`, `units/unit.gd`, `core/spell_caster.gd`, `core/enemy_ai.gd` et plusieurs écrans UI sont devenus de gros orchestrateurs ;
- runtime, addon Studio et `tools/labs` ont des dépendances croisées ;
- des `Dictionary`/`Variant` transportent encore des contrats critiques ;
- le hasard gameplay utilise parfois `randf()` ou `shuffle()` global, empêchant une reproduction exacte par seed.

**À adapter.**

- `RunSession` versionnée et indépendante des scènes ;
- `BattleSession`/simulation séparée de `BattlePresentationAdapter` ;
- `TurnSystem`, `TerrainSystem`, `EncounterSpawner`, `RewardService`, `SaveService` ;
- résultats typés (`CastResult`, `BattleOutcome`, snapshots) ;
- `CombatRng` injectable et sérialisable ;
- journal de commandes `{version_contenu, seed, actions, tirages, checksums}`.

L'intérêt n'est pas esthétique. Une simulation reproductible débloque le replay de bugs, la sauvegarde fiable, le rewind, le partage de seeds et une balance mesurable. La pratique de [Factorio](https://www.factorio.com/blog/post/fff-60) — petites intégrations déterministes avec contrôle CRC — est une référence de méthode, même pour un jeu solo.

### 11. Sauvegarde, performance et production

**Bloquants release.**

- aucun `export_presets.cfg` ni pipeline CI fabriquant et lançant un build exporté ;
- lane globale pouvant rester verte avec treize échecs historiques autorisés ;
- smoke visuel non bloquant ;
- pas de sauvegarde/reprise complète de run ;
- droits et provenance des assets non consolidés ;
- performance connue surtout sur RTX 4070 Laptop, pas sur bas/milieu de gamme ;
- gros binaires dupliqués et Git LFS partiel.

**Risque GPU spécifique.** Plusieurs unités utilisent un `SubViewport` 768×512 en `UPDATE_ALWAYS`. Treize unités peuvent représenter plus de cinq millions de pixels hors écran à rafraîchir avant le rendu principal. Ce n'est pas une preuve de bottleneck, mais un risque à profiler sur GPU intégré et Steam Deck.

**À adapter.**

- Export Windows/Linux reproductible depuis un clone propre, smoke du binaire et artefact CI.
- Lane release à zéro échec ; quarantaine explicite, propriétaire et échéance pour toute dette.
- `RunSnapshot` versionné, écriture atomique, backup, checksum et migrations.
- `UPDATE_WHEN_VISIBLE`, résolution adaptative ou cache des rendus d'unités ; comparer renderer Compatibility/Mobile.
- Registre de provenance à 100 % : source, auteur, licence, droit commercial, attribution, hash.
- Dédupliquer, généraliser Git LFS, exclure captures/labs du build.

### 12. Positionnement, store et démonstration

**Problème actuel.** « Roguelite tactique fantasy sur grille » décrit une catégorie, pas une raison de choisir ce jeu. Une galerie mélangeant forêt, volcan et espace masque davantage la proposition qu'elle ne la renforce.

**Positionnement recommandé.**

- Genre : **roguelite tactique mythologique à évolution en combat**.
- Hook mécanique : **vos actions font muter votre kit pendant le combat**.
- Hook émotionnel : **l'Archiviste se souvient de votre descente**.
- Hook visuel : **catabases peintes, bronze, cendre et mémoire**.

**Vertical slice à montrer.** Une Catabase d'Achille de 18–25 minutes, trois salles et un boss Ombre de Paris :

1. salle enseignant intention + poussée ;
2. salle combinant terrain + premier choix d'évolution ;
3. duel qui retourne une règle apprise ;
4. retour à l'Archiviste avec chronique et épitaphe.

Une démo réussie doit rendre les trois piliers compréhensibles en quinze minutes. Ne montrer ni les douze arbres complets, ni le Studio, ni plusieurs biomes avant que ce slice soit excellent.

## Théorie de design à appliquer

### MDA : partir de l'émotion

Le cadre [MDA](https://www.cs.northwestern.edu/~hunicke/MDA.pdf) invite à relier mécaniques, dynamiques et esthétique vécue.

| Émotion recherchée | Dynamique | Mécaniques nécessaires |
|---|---|---|
| « J'ai retourné son plan » | Lecture puis manipulation | intentions, preview, poussées, terrains |
| « C'est mon build » | Comportement qui façonne le héros | XP utile, draft en combat, choix orthogonaux |
| « Cette run avait une histoire » | Faits mémorisés et reconnus | rapport, chronique, archive, hub réactif |

### Cinq tests avant d'ajouter une mécanique

Une fonctionnalité ne mérite la production que si elle :

1. change une décision ;
2. crée du contre-jeu ;
3. est visible avant sa conséquence majeure ;
4. se réutilise dans plusieurs rencontres ;
5. peut être mesurée ou testée.

Si elle échoue à trois de ces cinq tests, elle est probablement du scope, pas de la profondeur.

### Principes d'équilibrage

- Une option populaire n'est pas forcément trop forte ; mesurer par contexte, offre concurrente, salle et niveau de maîtrise.
- Une stratégie est dominante si elle réduit durablement les raisons d'en choisir une autre.
- La variance doit changer le problème, pas décider arbitrairement du résultat.
- Le joueur accepte l'incertitude de contenu mieux que l'incertitude de règle.
- Les récompenses fortes créent des lignes de jeu ; les récompenses faibles ajoutent des pourcentages.

La conférence GDC sur les [métriques de Slay the Spire](https://www.gdcvault.com/play/1025731/-Slay-the-Spire-Metrics%EF%BB%BF) est la bonne référence de méthode : instrumenter tôt, puis interpréter les choix dans leur contexte plutôt qu'avec un taux global.

## Matrice « adapter / tester / éviter »

### Adapter maintenant

- intention et preview des conséquences critiques ;
- évolution en combat à divulgation progressive ;
- terrains comme verbes offensifs ;
- objectifs autres que l'élimination ;
- Catabase/Archiviste comme identité centrale ;
- récompenses modifiant une règle ;
- sauvegarde/reprise, InputMap, localisation et export ;
- RNG injecté et journal de commandes ;
- cohérence d'échelle, lumière et contact des unités.

### Tester avant généralisation

- télégraphe exact contre télégraphe partiel ;
- un ou deux rewinds thématiques par run ;
- draft de deux salles entre combats ;
- XP fondée sur exploits tactiques plutôt que répétition utile ;
- ordre d'activation flexible du trio ;
- chronique automatique de l'Archiviste ;
- résolution/caching des `SubViewport`.

### Éviter

- davantage d'arbres, biomes ou objets génériques avant validation du slice ;
- deckbuilding ajouté par convention ;
- métaprogression verticale obligatoire ;
- plusieurs monnaies ;
- boss sacs à PV ;
- difficulté limitée à PV/dégâts ;
- narration générée qui invente des faits ;
- daily challenge avant déterminisme et télémétrie ;
- refonte totale du moteur ou du HUD ;
- poursuite du Studio sans objectif de débit de contenu ;
- mélange visuel « tout ce qui est beau séparément ».

## Feuille de route recommandée

### P0 — Verrouiller la promesse et rendre un slice fiable

1. Écrire une page de vision avec les trois piliers et choisir Catabase comme slice de marque.
2. Produire une rencontre verticale d'Achille fondée sur intention, poussée et évolution.
3. Définir le contrat de lisibilité et preview ; faire un test A/B télégraphe exact/partiel.
4. Rééquilibrer spécialisation contre largeur avant tout nouvel arbre.
5. Ajouter `CombatRng`, seed complète et télémétrie minimale.
6. Sauvegarder/reprendre au moins à chaque frontière de salle.
7. Créer export CI bootable et lane release à zéro échec.
8. Profiler une salle stress sur bas/milieu/haut de gamme.
9. Consolider droits des assets du slice.
10. Recaler échelle, lumière, contact et cadrage des unités sur une seule arène.

### P1 — Construire une vraie mini-run

1. Trois salles, trois objectifs distincts, six rôles ennemis et un boss transformateur.
2. Draft entre deux salles/pactes, avec risque et récompense annoncés.
3. Récompenses orientées règles/sustain/risque ; une monnaie au maximum si nécessaire.
4. Progression en combat compacte ; arbre complet hors combat.
5. Chronique de l'Archiviste, écran final riche, archive seed/build/faits.
6. Manette, remapping, navigation focus, échelle de texte, pseudo-localisation.
7. Découpage progressif de `Battle`/`GameManager`, sans big-bang.
8. Séparation runtime/Studio/labs et validation récursive des Resources.

### P2 — Étendre seulement après preuve

1. Deuxième Catabase démontrant que la formule se décline.
2. Doctrines horizontales et difficulté modulaire.
3. Challenges artisanaux, seeds partageables, puis daily/hebdomadaire.
4. Legacy léger ou rival récurrent fondé sur des faits.
5. Localisations supplémentaires, matrice matérielle élargie et packaging store.

### À geler pendant le P0

- nouveaux domaines du Studio ;
- nouvelles grandes branches de compétences ;
- nouveaux biomes non liés à Catabase ;
- objets purement statistiques ;
- modes secondaires ;
- refonte intégrale des systèmes déjà fonctionnels.

## Mesures de validation

### Compréhension et UX

- pourcentage de dégâts reçus dont la cause était comprise avant validation ;
- taux de ciblage invalide et raison ;
- temps médian/p95 d'un tour ;
- taux d'annulation et moment de l'annulation ;
- réussite du tutoriel sans aide externe ;
- taille de texte et méthode d'entrée utilisées.

### Combat et balance

- victoire par profil de build et niveau de maîtrise ;
- taux de choix de chaque nœud conditionné par offre, salle, héros et seed ;
- PA/PM inutilisés ;
- dégâts venant du terrain, des collisions et des attaques directes ;
- fréquence des séquences dominantes ;
- diversité réelle des causes de victoire/défaite.

### Run et rétention

- abandon, reprise et complétion par salle ;
- durée médiane de run ;
- distribution des routes/pactes ;
- pourcentage d'offres où les deux options reçoivent au moins 30 % de choix ;
- nouvelle run commencée après victoire et après défaite ;
- capacité d'un joueur à raconter ce qui rendait sa run différente.

### Production

- temps médian pour créer et valider une rencontre ;
- nombre de bugs par encounter ;
- durée d'import/export ;
- taux de réussite du build propre ;
- FPS/frame time GPU et CPU par classe de matériel ;
- couverture de licence des assets ;
- dette de tests et âge de chaque quarantaine.

## Décision synthétique

Le projet ne doit pas chercher son avantage dans **davantage de systèmes**. Il doit convertir son socle actuel en une promesse courte et mémorable :

> **Je lis le destin de l'ennemi, je le détourne avec le terrain, mes actions transforment mon héros, et l'Archiviste garde la trace de ma descente.**

Si ce cycle est excellent sur une Catabase de trois salles, le projet aura une identité exportable à d'autres héros, une démonstration claire pour les joueurs et une architecture de contenu justifiée. Tant qu'il ne l'est pas, davantage de biomes, d'arbres ou de modes dilueront le meilleur du jeu.

## Preuves locales principales

- `README.md` — promesse actuelle et première run ;
- `project.godot` — autoloads et absence d'InputMap métier complet ;
- `data/runs/run_data.gd`, `data/runs/first_run.tres`, `data/runs/odyssey.tres` — structure, durée, profils et Catabase ;
- `data/rooms/room_data.gd`, `data/encounters/encounter_definition.gd` — modèles de rencontre ;
- `battle/battle.gd`, `core/game_manager.gd`, `core/enemy_ai.gd`, `core/damage_resolver.gd` — orchestration et déterminisme ;
- `docs/design/first_run_v2_validation.md` — rencontres, balance et performance documentée ;
- `docs/design/skill_trees/in_combat_skill_evolution_report.md` — signature de progression ;
- `docs/design/equipment_reward_presentation_report.md` — flux de récompense actif ;
- `docs/design/inventory_equipment_system.md` — persistance et dette de sauvegarde ;
- `docs/audits/hud_reference_audit_2026-08-23/IMPLEMENTATION_STATUS.md` et statuts associés — acquis UX récents ;
- `artifacts/maps/unit_presence_audit/all_rooms_final_comparison.png` — échelle et cohérence des arènes ;
- `artifacts/skill_trees/captures/resolution_1920x1080.png` — densité de l'arbre ;
- `.github/workflows/godot-validation.yml`, `tools/gut_historical_allowlist.json` — gates de production.

## Sources externes structurantes

- [Into the Breach — GDC Design Postmortem](https://gdcvault.com/play/1025772/-Into-the-Breach-Design)
- [Tactical Breach Wizards — Steam](https://store.steampowered.com/app/1043810/Tactical_Breach_Wizards/)
- [Shogun Showdown — Steam](https://store.steampowered.com/app/2084000/Shogun_Showdown/)
- [StarVaders — site officiel](https://star-vaders.com/)
- [Hades II — lancement 1.0](https://www.supergiantgames.com/blog/hades2-now-available/)
- [Darkest Dungeon II — site officiel](https://www.darkestdungeon.com/darkest-dungeon-2/about/)
- [Monster Train 2 — Steam](https://store.steampowered.com/app/2742830/Monster_Train_2/)
- [Slay the Spire — métriques GDC](https://www.gdcvault.com/play/1025731/-Slay-the-Spire-Metrics%EF%BB%BF)
- [Godot 4.7 — Resources](https://docs.godotengine.org/en/4.7/tutorials/scripting/resources.html)
- [Factorio — tests et déterminisme](https://www.factorio.com/blog/post/fff-60)
- [Xbox Accessibility Guidelines](https://learn.microsoft.com/en-us/xbox/accessibility/guidelines)
- [MDA: A Formal Approach to Game Design and Game Research](https://www.cs.northwestern.edu/~hunicke/MDA.pdf)

### Limites de l'audit

- Analyse principalement statique : aucun playtest utilisateur n'a été mené pour ce rapport.
- La suite Godot complète n'a pas été relancée ; les résultats de tests et performance cités proviennent des rapports du dépôt.
- Les références comparent des produits et pratiques observables, pas leurs architectures internes propriétaires.
- Les modifications Catabase actuellement non commitées ont été lues comme une direction en cours, sans être modifiées.
