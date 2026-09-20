# Audit de profondeur — run Cartes, 20 septembre 2026

> Orientation précisée ensuite : les annonces et télégraphes ne sont pas un
> fondement du gameplay recherché. Voir le [complément consacré aux systèmes et
> synergies de groupe](card_systems_and_enemy_synergies_2026-09-20.md), qui remplace
> cette orientation des propositions ; les mesures ci-dessous restent historiques.

## Verdict

La base tactique existe réellement : placement, poussée/attraction, dégâts différés,
protection, contrôle des PA/PM, dalles persistantes et préparations interruptibles.
Mais le deckbuilding reste surtout un remplacement de cartes faibles par des cartes
plus efficaces. Les boucles propres aux classes et les interactions entre cartes
ne structurent pas encore suffisamment la run. Ajouter des PV aux ennemis ou
encore beaucoup de variantes de dégâts ne résoudrait pas ce problème.

Priorité : rendre les synergies cohérentes et accessibles tôt, puis concevoir des
rencontres qui obligent à choisir entre plusieurs réponses. Les cartes restent des
drops aléatoires affichés avec les objets, conformément à la direction retenue.

## Protocole et preuves

- Version locale avec `rules_revision=3`, `ecosystem_revision=2`, drops Résonance.
- 5 graines : 2401–2405 ; 4 classes et 2 anciens départs Cartes (marteau/arc).
- 30 runs continues terminées, 196 combats réellement résolus, dont 99 combats
  et 424 activations du héros pour les nouvelles classes. Aucune victoire injectée.
- Processus Godot terminé avec code 0 ; 30 cas présents ; tableau d'erreurs vide ;
  journal sans `SCRIPT ERROR`, `ERROR:` ni `WARNING:`.
- En complément : 20 tests tactiques, 203 assertions, PASS strict.
- La sonde enregistre maintenant les familles actives et le nombre de copies
  possédées avant chaque combat et après chaque récompense.

Preuves locales :

- [Rapport des runs](../../artifacts/dev/card_depth_audit_20260920/report.json)
- [Agrégation et empreinte du rapport](../../artifacts/dev/card_depth_audit_20260920/analysis.json)
- [Journal moteur](../../artifacts/dev/card_depth_audit_20260920/engine.log)
- [Tests tactiques](../../artifacts/dev/20260920-195839-test-test_unit_test_catabase_monster_tactics.gd-ce400f5e/summary.json)
- [Sonde](../../tools/build_system_lab/class_balance_probe.gd)
- [Analyse reproductible](../../tools/build_system_lab/analyze_card_depth.ps1)

Les résultats concernent cet état local, comprenant des modifications non
commitées. Ils ne décrivent pas nécessairement une version publiée.

### Limites importantes

Le pilote est glouton : dégâts immédiats/PA, toutes les caractéristiques en
Prouesse, maîtrise native et première spécialisation, équipement automatique,
un achat abordable par halte. Il ne planifie pas les combos sur plusieurs tours,
n'utilise pas rétention/recomposition et sous-évalue les contrôles sans dégâts.
Il améliore les copies avant de remplacer les moins efficaces : cette politique
peut gaspiller des points sur les cartes d'initiation. La sélection du deck ignore
aussi certains effets et améliorations des copies.

Il s'agit donc d'un test d'exposition au contenu et d'un détecteur de difficultés,
pas d'un taux de victoire humain ni d'une recherche du meilleur build. Les anciens
départs ont un autre kit et d'autres règles : comparaison indicative, pas mesure
causale de la seule modification des drops. Cette passe ne valide pas visuellement
la lisibilité du HUD. Les chiffres de sorts comptent les lancements, pas les dégâts
produits ou les activations différées résolues.

## Résultats

Profondeur du dernier combat, dans l'ordre des graines ; ✓ signifie victoire finale.

| Départ | Profondeurs | Runs gagnées |
|---|---|---:|
| Assassin | 5 / 5 / 3 / 5 / 6 | 0/5 |
| Gardien | 3 / 3 / 3 / 5 / 6 | 0/5 |
| Arpenteur | 6 / 6 / 8 / 6 / 5 | 0/5 |
| Thaumaturge | 6 / 20✓ / 5 / 3 / 20 | 1/5 |
| Ancien marteau | 15 / 20 / 6 / 6 / 6 | 0/5 |
| Ancien arc | 20✓ / 20✓ / 20✓ / 20✓ / 20✓ | 5/5 |

18 des 20 nouvelles runs s'arrêtent avant la profondeur 10. L'Assassin et le Gardien
sont particulièrement exposés. Cela justifie de tester les départs et le coût
d'accès au contact avec des pilotes défensifs et humains avant tout nerf global.

### Le deck évolue, mais souvent trop tard pour cet échantillon

Dans les 9 runs atteignant le combat de profondeur 6, le deck contient encore
6 ou 7 cartes d'initiation sur 10. Les deux Thaumaturges atteignant Paris n'en ont
plus qu'une, avec respectivement 26 et 25 copies possédées au début du combat final.
Le renouvellement fonctionne donc sur une longue run ; le début de parcours reste
largement dominé par le kit initial.

Sur 1 013 lancements du héros dans les nouvelles classes :

- 428 gestes hors deck : **42,3 %** ;
- 442 cartes d'initiation : **43,6 %** ;
- 143 cartes acquises : **14,1 %**.

Cela ne prouve pas que les gestes sont trop forts : ils servent aussi à dépenser
les PA restants. Mais le poids combiné de l'initiation et des gestes montre que
le nouveau catalogue façonne encore peu les actions observées. La politique du
bot et la mortalité précoce accentuent ce résultat.

### Les ennemis utilisent déjà les nouveautés

475 lancements ennemis, 35 identifiants distincts ; 58 utilisent les nouvelles
techniques de cartes, soit **12,2 %**. Exemples : Entrave de bronze 25 fois,
Bûcher des ombres 8, Chant du Léthé 6, Chaînes du Tartare 5, Venin du Styx 5.

Aucun lancement d'`ecosystem_call_servant` dans ces runs. L'invocation fonctionne
dans le test tactique dédié, mais son exposition spontanée n'est pas démontrée
ici. Il faudra distinguer absence d'officiants adaptés, concurrence des autres
sorts et valeur de décision de l'IA. Les 13 préparations bloquées agrègent plusieurs
capacités : elles ne prouvent pas que le bot a interrompu 13 invocations.

## Ce qui donne déjà de la profondeur

1. **Placement utile.** L'IA valorise une attraction vers un allié de mêlée, une
   attaque après attraction et une poussée dans une dalle dangereuse.
2. **Rôles de groupe.** Soin limité, protection d'alliés menacés, marque consommée
   par des poursuivants, relation collecteur/porteur et repositionnement d'archer.
3. **Réponses aux préparations.** Sortir de portée/ligne de vue peut annuler une
   frappe différée ; occuper la dalle annoncée peut bloquer une invocation.
4. **Grammaire de cartes exploitable.** Marque/exécution, garde/riposte,
   déplacement/bonus, terrain/poussée, dégâts sur la durée.
5. **Limites aux contrôles forts.** Stase conditionnée à une marque, recharge et
   immunité temporaire ; Paris ne perd qu'un PA. Le « charme » actuel est une
   attraction avec retrait de PA, pas un changement de camp.

Ces mécanismes sont étayés par le code et les tests tactiques, pas tous par une
utilisation réussie du bot au cours des 99 combats.

## Freins et ajouts prioritaires

### P0 — Cohérence des synergies et accès aux builds

**Incohérence vérifiée dans le code.** `class_card_modifier.gd:38` reconnaît
uniquement `class_slow` comme ralentissement. Or Entrave/Filet appliquent
`class_root` et les dalles de givre `ecosystem_ice`. Les bonus Chasseur/Cryomancien
et le passif Thaumaturge ne reconnaissent donc pas ces retraits de PM comme
« ralenti » lorsque la cible n'a pas aussi l'ancien statut. Remplacer cette
convention implicite par un prédicat/tag partagé, ou distinguer explicitement
les conditions dans les textes. Ajouter ensuite un scénario de chaque interaction.

**Départs trop similaires.** Les 28 cartes d'initiation déclinent sept fonctions
sur quatre classes. Le preset retient les mêmes cinq fonctions et omet mobilité
et poussée. Il affaiblit donc précisément la démonstration du jeu de placement.
Proposer des départs réellement différents : Assassin mobile avec ouverture,
Gardien avec déplacement et protection, Arpenteur avec recul/piège, Thaumaturge
avec préparation et zone. Leur faiblesse doit venir de leur spécialisation ou
de leur coût, pas de l'absence d'une boucle tactique complète.

**Conserver les drops, donner une prise au joueur.** La Résonance actuelle dépend
de la profondeur, du danger et des victoires sans carte ; elle n'est pas une
caractéristique que le joueur construit. À la profondeur 1, sans sécheresse, les
deux tirages ont 49 % et 16 % de réussite : 42,84 % de zéro carte et une espérance
de 0,65 carte. Ce n'est pas un bug, mais un départ faible ne doit pas nécessiter
un premier drop chanceux pour être jouable.

Ajouter des familles de butin annoncées par rencontre, un marchand à stock
partiellement ciblé et une conversion de doublons vers une famille choisie.
Le risque de route peut modifier la Résonance ; éviter les bonus de vitesse ou
de combat sans dégâts qui avantageraient artificiellement certains archétypes.
Les cartes obtenues restent de vrais objets de butin, sans retour au choix
systématique parmi trois cartes après chaque combat.

### P1 — Quatre petites boucles de build, plutôt qu'un nouveau gros catalogue

| Archétype proposé | Boucle | Décision et limite |
|---|---|---|
| Assassin — Traque | poser une marque, isoler, consommer pour un déplacement ou une pioche | dépenser maintenant ou conserver ; déclenchement limité par tour |
| Gardien — Rempart | stocker une partie de la garde, la dépenser pour pousser ou couvrir une dalle | attaquer expose ; plafond de garde, pas de stockage infini |
| Arpenteur — Piégeur | poser un piège, détourner/pousser une cible, récupérer une ressource au déclenchement | emplacement contre dégâts immédiats ; pièges limités |
| Thaumaturge — Catalyse | préparer une surface, déplacer la cible, transformer/consommer la surface | contrôle durable contre explosion immédiate ; réaction explicite et bornée |

Prévoir pour chaque boucle un déclencheur accessible, deux cartes de soutien,
une récompense de combo et au moins deux contre-jeux ennemis. La rétention et
la recomposition existent déjà ; ajouter des cartes qui interagissent avec
elles plutôt qu'un second système de main. Les douze spécialisations actuelles
sont principalement des multiplicateurs conditionnels : faire évoluer les
choix d'action avant d'augmenter leurs pourcentages.

### P1 — Rencontres construites autour d'un dilemme

- **Geôlier + artilleur** : une zone annoncée, un ennemi qui attire ; choisir
  interrompre, déplacer ou encaisser. Au moins deux réponses accessibles.
- **Porteur + collecteur** : exploiter le lien de soutien déjà présent ; couper
  le lien ou abattre une cible prioritaire. Rendre le lien et sa rupture lisibles.
- **Officiant + escorte** : sécuriser une dalle d'invocation ou tuer l'officiant.
  Mesurer que l'invocation survient réellement et peut être empêchée.
- **Rituel de trois tours** : détourner des PA de dégâts pour neutraliser deux
  dalles. Premier objectif additionnel ciblé, avant d'enrichir toutes les salles.

Les combats standards se terminent actuellement par élimination d'un camp.
Un objectif de salle donnerait une valeur au contrôle même quand tuer vite est
possible. L'IA évalue déjà terrain, protection et quelques combos ; cependant,
hors invocation, ses candidats de sorts partent des positions des unités.
Elle ne planifie pas véritablement une surface sur un passage vide. Ajouter
quelques candidats tactiques de dalles et une courte anticipation, pas une IA
omnisciente qui connaît la main future.

### P2 — Information et instrumentation

La couche `TacticalTelegraphLayer` existe : ne pas refaire les annonces de zéro.
Étendre les capacités dangereuses avec cible/zone, moment de résolution et
condition d'annulation. Pour les attaques réactives ordinaires, montrer une zone
de menace ; ne pas promettre une action exacte que l'IA replanifiera ensuite.

Mesurer prochainement : dégâts évités par contrôle, bonus de combo déclenchés,
réactions de terrain, invocations tentées/réussies/annulées, rétention utilisée,
coût payé pour accéder au contact, cartes acquises puis effectivement jouées.
Le présent rapport ne possède pas ces mesures : les compteurs de lancements
ne doivent pas servir de substitut.

## Recherche et application au projet

**Into the Breach — Matthew Davis, GDC 2019.** Le postmortem relie annonces des
attaques, déterminisme pendant le tour du joueur, défense d'objectifs et intérêt
des armes non létales. Il montre aussi que complexifier les règles ne suffit pas
à approfondir les décisions. Application proposée ici : des menaces annoncées
et manipulables, avec une raison de contrôler autre que gagner des dégâts.
[Présentation originale, diapositives 13–21 et 30–34](https://media.gdcvault.com/gdc2019/presentations/Into%20the%20Breach%20Postmortem%20Final.pdf).

**Slay the Spire — Anthony Giovannetti, entretien IGF 2020.** Le concepteur insiste
sur les synergies, des ennemis qui éprouvent différentes stratégies, les choix
de route risque/récompense et l'expérimentation tôt dans la partie. Application
proposée : des boucles de build accessibles avant le milieu de run et des
rencontres qui ne favorisent pas toutes la même réponse.
[Entretien du concepteur](https://www.gamedeveloper.com/game-platforms/road-to-the-igf-mega-crit-games-i-slay-the-spire-i-).

**Slay the Spire — guide de Mega Crit, 2019.** Les exemples opposent des approches
agressives, défensives et fondées sur la pioche/les combos. Application proposée :
faire varier l'économie des actions et des cartes, au-delà des coefficients.
Leur acquisition après combat n'est pas à copier : notre contrainte reste le
drop aléatoire avec les objets.
[Article du designer sur PlayStation Blog](https://blog.playstation.com/?p=211260).

Ces références motivent les propositions ; elles ne prouvent pas leur équilibre
dans Dungeon Draft. Les réglages restent à tester dans notre moteur.

## Prochaine validation conseillée

1. Corriger la compatibilité des statuts et tester chaque paire carte/passif.
2. Tester des départs complets sur les mêmes graines avec trois politiques
   (dégâts, survie, combos), puis quelques sessions humaines commentées.
3. Introduire une boucle complète et trois rencontres qui l'éprouvent ; vérifier
   que chaque menace a deux réponses et que la même action n'est pas toujours optimale.
4. Comparer renouvellement et usage du deck aux profondeurs 3/6/10/15, sans fixer
   un taux de victoire cible à partir des cinq graines de cet audit.

Cette passe ajoute uniquement de la télémétrie et un analyseur au laboratoire.
Aucun réglage de gameplay n'a été appliqué pendant l'audit.
