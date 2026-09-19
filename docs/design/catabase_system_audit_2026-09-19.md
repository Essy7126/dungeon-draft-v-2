# Catabase — audit du système, décisions et laboratoire

19 septembre 2026. Ce document révise les propositions `catabase_classes_loot_research_2026-09-19.md` et `catabase_hybrid_mastery_2026-09-19.md`. Leurs nombres de constructions étaient des possibilités combinatoires, pas des builds validés.

**Conclusion : conserver le combat sur grille, l'identité initiale et le butin de run ; remplacer l'empilement des progressions par des responsabilités séparées.** Une carte étrangère doit pouvoir rendre un service immédiatement. Deux drops appartenant à une classe ne constituent pas automatiquement une hybridation.

Trois statuts sont employés ici : **observé** dans le code/export ; **exécuté** dans les essais isolés ; **proposé** pour une future intégration. Les huit cartes du laboratoire existent comme `Spell` et passent par le moteur commun. Les quatre classes, leurs passifs et la nouvelle distribution de butin ne sont pas activés dans la run publique.

## 1. Audit : ce qui existe réellement

| Sujet | Fait vérifié | Conséquence |
|---|---|---|
| Parcours R6 | 12 combats, 20 profondeurs ; 81 parcours sans passages secrets, 324 en incluant leurs entrées potentielles, par graine étudiée | Tous ont 2 785 XP de base. La topologie préserve déjà un budget comparable ; cela ne prouve pas une difficulté identique |
| Avant Pâris | 2 440 XP sans Sagesse ni bonus de défi | Niveau 12 à l'entrée du boss, pas 14. Un système exigeant le niveau 13 pour fonctionner arrive trop tard pour ce parcours |
| Progression ancienne | 24 points de profondeur, dont 10 sur des étapes sans combat | Ce budget doit être remplacé si les décisions sont déplacées aux niveaux ; ne pas lui ajouter 12 points de spécialisation |
| Cartes | Catalogue de 23 familles enregistrées dans sept axes, puis filtres de rareté, branche découverte, serment connu, relique requise | Un pool ouvert d'autres classes n'existe pas encore. Le filtre actuel entretient la répétition |
| Butin Cartes | 11 combats avant le boss, trois élites avec un tirage supplémentaire, 25 % de tirage supplémentaire par combat | Espérance de 16,75 cartes, si les pools permettent tous les tirages. Les anciennes simulations à 11 drops ne décrivent pas la production |
| Équipement | `ItemDefinition.EquipmentSlot` : arme, armure, accessoire | Tête/torse/ceinture/pieds/bijou demandent une migration du modèle et de l'interface, pas seulement de nouvelles icônes |
| Stats | Une Prouesse commune ; armure et résistance magique distinctes ; résistances élémentaires séparées | Une classe magique peut réutiliser Prouesse. Inutile de créer immédiatement Intelligence, Dextérité et Force offensive en plus |
| Dégâts | `SpellScalingResolver` puis `DamageResolver`, statuts multiplicatifs, critique, absorption et perte réelle de PV | Les bonus doivent déclarer leur étape de calcul ; multiplier les systèmes de bonus sans ordre formel produit des écarts incontrôlables |
| Boucliers | Sources distinctes, remplacement, expiration et faits de combat présents | Une garde temporaire est réalisable sans nouveau système de « vestige » |
| Durée | `start_turn`, `process_statuses`, `tick_statuses` ont des responsabilités différentes | « Pendant un tour » n'est pas une définition suffisante ; préciser le propriétaire de l'activation et la phase |

Sources de code : `core/expedition/catabase_route_v6.gd`, `expedition_session.gd`, `expedition_build_state.gd`, `catabase_cards.gd`, `data/items/item_definition.gd`, `units/unit.gd`. L'export contient les trois graines 2401, 7126, 19073. Les passages secrets comptés sont des possibilités du graphe ; leurs conditions de découverte ne sont pas simulées.

Deux détails techniques empêchent de promettre une sécurité qui n'existe pas :

- `HitContext.damage_effectiveness` est déclaré, mais n'est pas utilisé par `DamageResolver.compute`. Il ne protège donc pas actuellement un futur bonus plat contre sa multiplication par le nombre d'impacts.
- `SpellScalingData` accepte une courbe de niveau, mais les appels de dégâts de `SpellCaster` observés utilisent `spell.get_scaled_damage(caster)` avec le niveau implicite 1. Le laboratoire utilise Prouesse et PV maximum, déjà calculés au niveau du personnage. Une courbe additionnelle de carte exigerait un raccord explicite.

Les valeurs brutes exportées du catalogue sont celles des définitions avant les modificateurs de session/équipement. Elles ne sont pas présentées comme des dégâts effectifs de la run.

## 2. Vocabulaire : un terme, une responsabilité

| Terme | Définition proposée | Stockage / exemple | Ce qu'il ne doit pas faire |
|---|---|---|---|
| Apparence | Présentation d'Achille | `appearance_id = passe_rive` | Modifier implicitement la classe ou le drop |
| Classe principale | Identité de combat de la run : pool de départ, passif propre, plafond de maîtrise | `primary_class_id = assassin` | Interdire toute carte étrangère ou imposer une arme |
| Spécialisation | Un passif choisi parmi ceux de sa classe ; change une façon de rentabiliser ses actions | `specialization_id = execution` | Créer une seconde jauge d'XP ou un catalogue entièrement dupliqué |
| Maîtrise | Rang d'investissement dans UNE classe, partagé par ses cartes | `mastery_by_class[assassin] = 3` | Augmenter PA, PM, durée ou pioche par un pourcentage générique |
| Catégorie d'objet | Nature de l'objet et commandes disponibles | Carte, équipement, rune, relique, consommable | Remplacer les règles de combat |
| Classe de carte | Origine mécanique, référence pour maîtrise et distribution | `class_id = gardien` | Être déduite du nom, du dessin ou de l'élément |
| Famille de carte | Action de base et ses formes alternatives | `family_id = garde_breve` | Se confondre avec Assassin ou Hadès |
| Copie de carte | Exemplaire possédé, avec identité et éventuelle transformation | `instance_id`, `definition_id`, `upgrade_id` | Modifier la définition partagée ou enseigner gratuitement toutes ses copies |
| Type d'action | Manière dont un impact interagit avec les règles | mêlée, projectile, zone, déplacement, personnel | Être déduit de la position graphique du VFX |
| Type de dégâts | Défense qui réduit le coup | physique / magique | Être la classe du personnage |
| Élément | Résistance élémentaire supplémentaire | feu, glace, ombre… | Porter automatiquement une règle d'effet de statut |
| Rôle de carte | Rôle analysable dans une combinaison | autonome, préparation, exploitation, réponse | Garantir à lui seul une compatibilité |
| Affiliation | Appartenance narrative à un dieu ou à un culte | Hadès, Styx | Introduire automatiquement une monnaie, un arbre et des objets de terrain |
| Biome | Contrat de salle : géométrie, ennemis, dangers, tables de butin | porte, puits, barque | Verrouiller la classe autorisée |

**La hiérarchie de fiction n'est pas obligatoirement une hiérarchie de calcul.** « Passe-rive, Assassin, adepte d'Hadès, culte du Styx » peut rester une identité lisible. En données : une apparence, une classe, une spécialisation, une affiliation et un itinéraire. Les mélanger créerait des effets cachés et des pools impossibles à maintenir.

Je retire « germes », « traces » et « supports actifs » du noyau proposé. Aucun contenu ne devrait réclamer ces mots comme conditions tant que la création, le cumul, la consommation, la durée, la sauvegarde et le ciblage de leur objet n'ont pas été implémentés et testés. Hadès et les cultes pourront avoir des règles propres ensuite ; ce dossier ne prétend pas les avoir validées.

## 3. Décisions éclairées par des jeux précis

Ce sont des références pour répondre à une question, pas des modèles à reproduire. Les décisions Catabase et leurs chiffres restent nos hypothèses.

### D1 — Pourquoi une classe si l'on peut emprunter des cartes ?

**Référence.** La répartition des capacités dans Magic protège des forces et des faiblesses ; Mark Rosewater distingue une évolution justifiée de cette répartition d'une transgression uniquement spectaculaire. [The Bleed Story, Wizards](https://magic.wizards.com/en/news/making-magic/the-bleed-story).

**Décision proposée.** La classe donne un passif exclusif, une maîtrise initiale et un accès aux transformations avancées. Les cartes ordinaires restent empruntables. On protège le fonctionnement complet de la classe, pas chaque petit service.

**Conséquence.** L'Assassin peut obtenir une garde aussi fonctionnelle en durée que celle d'un Gardien. Il n'obtient pas pour autant le passif de Gardien, sa maîtrise maximale ni sa conversion avancée du bouclier en attaque.

**Vérification exigée.** Comparer le kit complet à coût d'investissement égal. Une carte utilitaire étrangère excellente n'est pas à elle seule un problème ; une carte présente dans tous les meilleurs decks le serait.

### D2 — Comment permettre un changement de direction dans la run ?

**Référence.** Grim Dawn introduit une seconde maîtrise à un niveau ultérieur et permet de retirer certains points contre paiement, avec des dépendances et des restrictions. [Guide officiel des maîtrises](https://www.grimdawn.com/guide/character/masteries/).

**Décision proposée.** Une seule réserve de points de perfectionnement. Investir dans une autre classe retarde les transformations de la principale. Les points non dépensés restent disponibles ; une correction gratuite au premier refuge permet de réagir aux drops des cinq premiers combats.

**Limite de transposition.** Notre run est courte. Imposer la durée d'apprentissage d'un ARPG rendrait les cartes tardives inutilisables. Une carte étrangère est donc jouable au rang 0, sans attendre de l'entraîner.

### D3 — Doit-on choisir deux classes au départ ?

**Référence.** Monster Train donne accès aux cartes de deux clans choisis et fait intervenir le parcours dans l'amélioration et la duplication. [Présentation officielle](https://store.steampowered.com/app/1102190/Monster_Train/).

**Décision proposée.** Départ avec une seule classe principale ; les objets trouvés peuvent proposer la seconde direction. Choisir obligatoirement deux classes avant la première salle retirerait précisément la surprise recherchée. Un filtre de recherche de butin peut être choisi au refuge, après observation du loot, sans supprimer les autres classes du monde.

**Résultat expérimental.** Le biais de classe améliore les chances de paires, mais reste insuffisant quand les cartes ne se connectent pas. Voir section 7. On ne l'adopte pas comme solution complète.

### D4 — Faut-il entraîner chaque carte à force de la jouer ?

**Référence.** Les notes de développement de Griftlands exposent des cartes instanciées avec XP, la fatigue et des corrections d'ordre de déclenchement ; elles signalent également des boucles de duplication corrigées. Il s'agit d'un état historique de 2020. [Notes Klei 409619](https://forums.kleientertainment.com/game-updates/griftlands/409619-r1127/).

**Décision proposée.** Pas d'XP par lancement. L'XP vient de la victoire ; les transformations viennent d'un choix limité. Maintenir un ennemi vivant pour entraîner sa nouvelle carte ne doit pas être profitable.

**Conséquence technique.** La copie possède une transformation, pas un niveau qui croît à chaque utilisation. Réserve et main n'altèrent pas l'XP. Le niveau du personnage rend une carte tardive immédiatement pertinente.

### D5 — Une arme doit-elle définir tous les sorts ?

**Référence.** The Last Spell adopte des héros sans classe dont les compétences changent avec les armes. [Présentation par le directeur créatif](https://blog.playstation.com/2022/12/13/tactical-roguelite-the-last-spell-is-coming-to-playstation/).

**Décision proposée.** Dans notre direction, le deck et la classe constituent le corps du build. L'arme peut modifier un geste de secours et quelques paramètres explicites. Elle ne remplace pas le deck et n'est pas un prérequis pour la majorité des cartes.

**Conséquence.** Un départ sans équipement reste jouable. Une première dague ouvre une option ; l'absence de dague ne rend pas les cartes d'Assassin grisées. Les rares cartes exigeant un type d'arme doivent être identifiées comme spécialisées, et ne pas remplir le pool de départ.

### D6 — Pourquoi pousser ou ralentir serait-il aussi important que frapper ?

**Référence.** Le postmortem d'Into the Breach montre comment les attaques annoncées conduisent à repenser les armes non létales, l'interface et les conditions de victoire. [Matthew Davis, GDC 2019](https://media.gdcvault.com/gdc2019/presentations/Into%20the%20Breach%20Postmortem%20Final.pdf).

**Décision proposée.** Mesurer les attaques ennemies empêchées, les lignes de tir cassées et les cases dangereuses évitées. Une réduction de dégâts n'équilibre pas à elle seule un contrôle. Ne pas ajouter un bonus global aux durées ou aux cases de poussée.

**Conséquence.** Les ennemis doivent annoncer clairement si leur attaque suit la cible, vise une case fixe ou exige encore une ligne de vue. Autrement une même poussée est tantôt forte, tantôt inutile sans explication.

### D7 — Comment décider qu'une carte a sa place ?

**Référence.** Mega Crit décrit une recherche de rôle pour chaque carte et met en garde contre une conclusion tirée uniquement des métriques. [Anthony Giovannetti, GDC 2019](https://media.gdcvault.com/gdc2019/presentations/Giovannetti_Anthony_SlayTheSpire.pdf).

**Décision proposée.** Une nouvelle carte doit apporter un changement observable de cible, position, ordre d'action, délai, risque ou économie. Sa fiche précise le scénario où elle est choisie et celui où une alternative la bat. Une hausse de dégâts isolée est une amélioration numérique, pas une nouvelle mécanique.

**Contrôle.** Comparaisons appariées sur mêmes cartes tirées, ennemis, terrain et équipement ; retours humains séparés des bots. Le taux d'utilisation dépend de la disponibilité et de la difficulté : il n'est pas une note absolue de qualité.

### D8 — Comment ajouter beaucoup de contenu sans multiplier les bugs ?

**Référence.** Godot charge et partage les Resources ; elles servent de conteneurs de données, distincts des objets qui exécutent le comportement. [Documentation officielle](https://docs.godotengine.org/en/stable/tutorials/scripting/resources.html).

**Décision proposée.** Définition immuable, copie possédée, état de combat et résolution sont quatre responsabilités séparées. Réutiliser les services du Studio et le moteur commun. Ne pas construire un deuxième interpréteur de dégâts en parallèle.

**Vérification effectuée.** Les exemplaires du laboratoire sont indépendants ; modifier le statut d'un exemplaire ne modifie pas celui d'un autre. Les tests ferment aussi les historiques de faits de combat qui conservent des références aux unités.

## 4. Classes et spécialisations : frontières précises

### Quatre classes initiales proposées

Le tableau décrit des contrats de contenu, **pas quatre personnages déjà jouables**. La Prouesse sert aux quatre ; le choix de dégâts physiques ou magiques appartient au sort.

| Classe | Manière principale de gagner | Passif de base candidat, à tester | Faiblesse de son catalogue |
|---|---|---|---|
| Assassin | Concentrer les actions sur une cible exposée | Premier impact direct de mêlée par activation : +20 % si la cible n'a aucun allié vivant orthogonalement adjacent ; bonus consommé par cet impact seulement | Peu de protection durable et de dégâts de zone |
| Gardien | Réduire une pression annoncée, puis utiliser la position gagnée | Première garde créée par activation : +20 % de valeur ; aucun allongement de durée | Coût offensif de la protection, faiblesse contre les menaces qui contournent sa garde |
| Arpenteur | Créer une ligne de tir et empêcher le retour au contact | Premier projectile direct lancé à distance de grille au moins 3 : +20 % ; une fois par activation | Portées minimales et espace de recul nécessaire |
| Thaumaturge | Préparer une zone ou altérer une cible avant son attaque | Premier impact direct magique sur une cible déjà affectée par une altération négative admissible : +20 % ; une fois par activation | Préparation, résistances et ennemis qui peuvent quitter les zones |

Les bonus sont des paramètres d'essai ; ils ne sont pas inclus dans les résultats des huit cartes. À l'intégration, leur consommation s'effectue sur l'impact identifié, après validation de l'action ; pas une fois pour chaque cible d'une zone. Le déclencheur Thaumaturge doit utiliser une liste d'effets négatifs, pas « n'importe quel statut », sinon une bénédiction ennemie devient une faiblesse.

### Douze spécialisations candidates, un choix à la fois

Choix proposé au niveau 4 : une des trois spécialisations de sa classe, plutôt que trois niveaux supplémentaires de menus au départ. Son passif **remplace** celui de base ; il ne s'y additionne pas. Les constantes ci-dessous sont des valeurs de travail ; leur plafond est volontairement décrit.

| Classe | Spécialisation | Règle candidate | Ce qu'il faut observer |
|---|---|---|---|
| Assassin | Exécution | Premier impact direct sur cible sous 35 % de ses PV : +25 % de dégâts, une fois/activation | Nombre de mises à mort gagnées ; ne pas encourager un seuil systématiquement trivial |
| Assassin | Saignement | Premier saignement appliqué : +1 activation, une fois/activation ; aucun tick immédiat supplémentaire | Dégâts réellement subis avant la mort de la cible, pas somme théorique des ticks |
| Assassin | Embuscade | Après au moins deux cases de déplacement volontaire, première mêlée : ignore 20 % de l'armure | Cases parcourues, PA restant, coût du détour ; exclure les déplacements forcés subis |
| Gardien | Rempart | Première garde : +40 %, mais prochain déplacement volontaire coûte 1 PM de plus dans l'activation | Attaques absorbées et sorties du danger perdues |
| Gardien | Riposte | Première destruction complète d'une source de garde : prochain impact de mêlée +25 % avant fin de la prochaine activation, une charge | Déclenchement par vraie destruction, pas expiration ou remplacement |
| Gardien | Percussion | Première collision provoquée : +30 % de dégâts de collision, une fois/activation | Terrain nécessaire ; pas de multiplication sur tous les éléments d'une chaîne |
| Arpenteur | Tireur | Premier projectile après avoir dépensé au plus 1 PM : +20 % | Choix entre rester et se replacer ; téléportations comptées séparément |
| Arpenteur | Escarmouche | Premier projectile direct ayant retiré des PV rend 1 PM, une fois/activation | Permettre le repli sans générer de boucle de PA |
| Arpenteur | Traque | Premier projectile sur ennemi déjà ralenti ignore 20 % de sa défense de catégorie | Alternative « givre emprunté puis tir » ; coût de pioche de la préparation |
| Thaumaturge | Affliction | Première application d'un statut périodique offensif : +20 % à ses ticks, valeur figée à l'application | Pas de double bonus à l'application puis au tick |
| Thaumaturge | Entrave | Premier impact magique sur une cible ayant perdu au moins 1 PM par un effet actif : +25 %, une fois/activation | Ne pas confondre PM dépensés et PM retirés |
| Thaumaturge | Déflagration | Première zone touchant au moins deux ennemis : +15 % à cet effet, une fois/activation | Les cibles sont fixées avant le premier dégât ; pas de croissance avec chaque mort |

Ces douze lignes sont des fiches de travail vérifiables, pas douze promesses d'équilibre. Le nombre de spécialisations n'est pas multiplié par le nombre de dieux et de cultes pour annoncer artificiellement des centaines de builds.

## 5. XP, maîtrise et caractéristiques : un seul budget par fonction

### Mesure sur la courbe actuelle

Deux politiques d'attributs légales, victoires supposées, sans équipement ni Gloire : tout en Puissance ; ou cinq points de Sagesse dès que possible, puis Puissance. Ce ne sont pas des runs de combat gagnées par un bot.

| Après le combat situé à la profondeur… | Puissance : niveau / PV max / Prouesse | Sagesse puis Puissance : niveau / PV max / Prouesse |
|---|---|---|
| 3, troisième combat | 4 / 200 / 38 | 4 / 200 / 33 |
| 6, cinquième combat | 6 / 290 / 60 | 7 / 350 / 60 |
| 12, huitième combat | 9 / 500 / 115 | 11 / 635 / 127 |
| 17, avant le boss | 12 / 675 / 162 | 14 / 770 / 152 |

**Enseignement.** La Sagesse peut avancer simultanément le niveau, les PV, la Prouesse et les choix de progression. Elle n'est pas uniquement un investissement qui sacrifie de la puissance immédiate. Ce tableau ne prouve pas sa domination dans tous les combats : le début plus faible et l'attrition ne sont pas simulés.

**Décision proposée pour la variante de classes.** XP commune, fixée par le contrat de rencontre et reçue une seule fois à la victoire. Retirer la Sagesse modifiant l'XP de cette première variante expérimentale. Garder Vitalité, Puissance et Résolution comme choix d'attributs, puis vérifier leurs coûts d'opportunité. Les défis modifient la prochaine rencontre et son butin annoncé ; ne pas cumuler dès le départ bonus XP, bonus stats et bonus drops sur le même succès.

### Contrat de progression proposé

- **Niveau du héros** : détermine PV et Prouesse de référence via la courbe du personnage. Une carte tardive profite immédiatement de ces stats.
- **Attributs** : modifient les statistiques du personnage, jamais directement les probabilités de carte ou la taille du deck.
- **Perfectionnement** : 2 points aux niveaux 2, 4, 6, 8, 10, 12, donc 12 avant le boss sur le parcours de base. Remplace les 24 points de profondeur dans cette variante ; ne s'y additionne pas.
- **Classe principale** : maîtrise 2 au départ, plafond 4. Autres classes : rang 0, plafond 2. Coûts proposés : principal 2→3 = 3, 3→4 = 4 ; secondaire 0→1 = 2, 1→2 = 3.
- **Transformation de copie** : 2 points, une transformation active par exemplaire. Elle change une règle ; elle ne débloque pas de copie gratuite. Les transformations avancées nécessitant maîtrise 3 ou 4 restent inaccessibles à l'emprunt ordinaire.
- **Correction** : première correction gratuite au premier refuge ; restauration atomique des points et transformations dépendantes. Les drops vendus ne sont pas recréés. Corrections ultérieures à prix fixe à définir après test de l'économie.

Répartitions avant le boss : spécialiste rang 4 (7 points) + deux transformations (4) + 1 conservé ; hybride principal rang 3 (3) + secondaire rang 2 (5) + deux transformations (4). Ces allocations ont le même budget. Leur valeur en combat reste à comparer.

### Formule de travail et ordre

Pour un effet continu du laboratoire :

`brut = arrondi((a × Prouesse + b × PVmax) × (1 + 0,10 × maîtrise_de_la_carte))`

Puis le `DamageResolver` commun applique les défenses et les autres règles déjà existantes. La maîtrise ne se remet pas une seconde fois dans les stats du héros. Une carte physique de Thaumaturge reste physique ; une carte magique d'Assassin reste magique.

Rang 0 / 2 / 4 : multiplicateur 1 / 1,2 / 1,4. Un natif au rang 4 n'a que 16,7 % de dégâts bruts de plus qu'un emprunteur au rang 2, avant son passif. Cette marge n'est pas une preuve suffisante d'identité ; les transformations et le coût d'investissement comptent aussi.

Le passif actif constitue une seule étape conditionnelle supplémentaire : un natif rang 4 avec Exécution active atteint `1,4 × 1,25 = 1,75`, contre `1,2` pour l'emprunteur rang 2, soit 45,8 % de plus sur ce coup. Hors condition, il retrouve la marge de 16,7 %. Empiler en plus le passif initial de 20 % aurait porté cette marge conditionnelle à 75 % : c'est pourquoi la spécialisation le remplace. Les futurs bonus d'équipement doivent être testés sur cette valeur totale, pas équilibrés chacun séparément.

PA, PM, portée, durée, nombre de cibles, pioche et nombre d'utilisations sont **discrets**. Ils exigent une décision de contenu explicite. Faire passer arbitrairement une carte de 2 à 3 PA fait passer un budget théorique de 6 PA de trois actions à deux : ce n'est pas une petite réduction de 10 %.

## 6. Création effective : huit cartes et une révision

Fichier : `tools/build_system_lab/card_experiments.gd`. Objets `Spell` frais, pas d'inscription dans le catalogue public. Pas d'assets finaux ou de nouvelle interface dans cet essai.

Valeurs ci-dessous : maîtrise 0, Prouesse 100, PVmax 600, aucune défense. Toutes les portées utilisent les règles de grille existantes.

| Carte | Origine | Coût / ciblage | Effet réellement exécuté |
|---|---|---|---|
| Ouvrir la garde | Assassin | 1 PA, portée 1–3, ligne de vue | 35 dégâts physiques ; statut Ouverture pendant une activation de la cible |
| Frapper l'ouverture | Assassin | 2 PA, mêlée | 80 dégâts ; +55 si Ouverture est présente. Le statut n'est pas consommé |
| Garde brève | Gardien | 2 PA, soi | 89 garde : 65 % Prouesse + 4 % PVmax ; expire au début de la prochaine activation du porteur |
| Repousser | Gardien | 2 PA, mêlée | 75 dégâts physiques, poussée d'une case |
| Trait tendu | Arpenteur | 2 PA, portée 2–4 | 100 dégâts physiques ; impossible au contact |
| Pas latéral | Arpenteur | 1 PA, case libre à 1–2 | Déplace le lanceur si le trajet est libre |
| Trait de givre | Thaumaturge | 2 PA, portée 1–3 | 70 dégâts magiques de glace ; retire 1 PM à la prochaine activation de la cible, puis expire à sa fin |
| Éclat de braise | Thaumaturge | 3 PA, portée 1–3, croix de rayon 1 | 80 dégâts magiques de feu par ennemi ; n'inflige pas de dégâts aux alliés |

### Résultats des micro-scénarios

- Ouverture puis frappe : **170 dégâts pour 3 PA** sur la cible exposée. Une frappe seule vaut 80. La préparation existe dès la version de base.
- Tir refusé au contact : aucun PA perdu ; déplacement d'une case en arrière puis tir : **100 dégâts pour 3 PA**, placement effectivement modifié.
- Garde : **89**, second lancement refusé dans la même activation, aucune garde résiduelle à l'activation suivante.
- Poussée : ennemi déplacé de `(3,2)` à `(4,2)` ; **75 PV** retirés.
- Givre : une activation à **2 PM**, puis retour à **3 PM**.
- Braise sur deux ennemis : **160 dégâts cumulés pour 3 PA**, lanceur adjacent indemne. Sur une seule cible elle perd cet avantage.
- Même tir, même cible à **90 PV et 50 armure** : au rang 2, **80 dégâts**, la cible survit avec 10 PV ; au rang 4, **93 dégâts résolus**, la cible meurt. Coût identique de 2 PA. Les PV réellement retirés par le dernier coup sont plafonnés à ceux qui restent.

Ces tests valident les effets, les coûts et des interactions précises. Ils ne mesurent ni la victoire sur une salle, ni le plaisir, ni la qualité d'un deck complet.

### Itération 1 → 2 : doublons et disponibilité

Première version : toutes les cartes limitées à un usage par activation. Calcul exact avec cinq paires et quatre cartes tirées : **61,9 %** des mains contiennent au moins une famille en double ; **3,33 familles distinctes** en moyenne. Une limitation générale retire donc de la valeur aux copies du deck de départ.

Révision effectuée : attaques ordinaires répétables ; Garde, Repousser, Pas et Givre restent limités à un usage par activation par identifiant de capacité. Deux lancements de Trait tendu coûtent bien 4 PA et infligent 200 dégâts à la cible sans défense. Le test porte sur la légalité des actions ; la possession des deux cartes demeure la responsabilité de `CatabaseCards`.

Limite du prototype : le bonus conditionnel de Frapper l'ouverture est converti en valeur plate lors de la construction de la carte. Il faut reconstruire ce spécimen si la Prouesse change ; l'intégration devra évaluer ce bonus au lancement via le pipeline commun. Ce raccourci de laboratoire n'est pas un contrat de production.

## 7. Drops : trois modèles, une erreur de raisonnement corrigée

Le modèle précédent mesurait « deux cartes de la même classe ». Nouveau calcul exact : chaque classe étrangère possède 15 cartes hypothétiques, dont 3 préparations, 3 exploitations compatibles et 9 autres. Toutes les préparations d'une classe peuvent alimenter toutes ses exploitations : c'est déjà une hypothèse favorable. On simule la distribution de **11 récompenses d'une carte**, pas les 16,75 cartes moyennes du code actuel.

Probabilité de carte étrangère : 15 % aux combats 1–3, 35 % aux combats 4–8, 45 % aux combats 9–11 ; trois classes étrangères équiprobables, sauf biais indiqué.

| Modèle | Deux cartes même classe, combat 8 | Préparation + exploitation, combat 8 | Préparation + exploitation, combat 11 |
|---|---:|---:|---:|
| A : tirages indépendants | 43,62 % | **4,94 %** | **12,15 %** |
| B : première étrangère garantie au combat 3 si aucune reçue | 61,67 % | **7,40 %** | **15,80 %** |
| C : B + biais 60/20/20 vers la première classe étrangère après le refuge | 69,49 % | **9,19 %** | **19,33 %** |

**Conclusion de l'expérience : rejeter le biais de drop comme remède principal.** Il améliore la quantité cohérente, mais ne crée pas assez de connexions. Augmenter brutalement les drops remplirait surtout l'inventaire.

### Ce que la prochaine création de cartes doit changer

1. Chaque classe offre des réponses autonomes. Garde protège sans autre carte Gardien ; Pas crée un angle sans autre carte Arpenteur ; Givre réduit une menace sans carte magique supplémentaire.
2. Les préparations servent plusieurs exploitations et les exploitations acceptent plusieurs préparations. Une cible ralentie peut être exploitée par un projectile, une mêlée ou un effet de zone ; ne pas exiger partout « le statut posé uniquement par carte X ».
3. Une carte de combo a une valeur de base honnête. Frapper l'ouverture inflige encore 80 sans préparation ; une carte totalement inerte doit annoncer un potentiel exceptionnel et rester rare dans les premiers tirages.
4. Les cartes très dépendantes sont présentées comme telles. Leur infobulle montre les moyens actuellement possédés de remplir leur condition, sans annoncer « compatible » uniquement parce que les classes sont identiques.
5. Une offre commerciale ou un choix de récompense peut montrer plusieurs objets existants. Le monde conserve de l'aléatoire ; le joueur a une occasion concrète de le diriger, plutôt qu'un ajustement caché après chaque résultat.

### Résister à l'agrandissement du catalogue

Avec 15 cartes par classe et un tirage uniforme sur tout le catalogue, la part de sa classe tombe de 25 % à 12,5 % puis 8,3 % lorsque le jeu passe de 4 à 8 puis 12 classes.

Tirer d'abord le groupe « principale / étrangères / communes », puis la classe, puis le rôle, puis la rareté, puis une définition compatible avec le niveau, maintient le budget voulu. Cependant, même avec 35 % d'étrangères, une classe étrangère précise passe de 11,67 % à 5 % puis 3,18 % par tirage : la seconde direction doit avoir un mécanisme de sélection explicite ou accepter d'être beaucoup plus rare.

À proposer au premier refuge : **une classe secondaire recherchée**, après avoir vu les premiers objets. Cela pondère les offres futures, pas les stats ennemies. Le choix et les probabilités effectives sont sauvegardés et affichables. Ce paramètre n'est pas activé dans le jeu par cet audit.

Les groupes vides doivent avoir un repli déclaré et tracé. Pas de tirage récursif jusqu'à obtenir une rareté « assez bonne », pas de récompense qui disparaît silencieusement. Une table doit indiquer distribution demandée et distribution effective après filtrage.

## 8. Deck : l'inventaire ne doit pas imposer la pioche

| Taille du deck, main de 4 | Au moins une copie d'une famille possédée en double | Deux cartes précises en exemplaire unique ensemble |
|---:|---:|---:|
| 8 | 78,57 % | 21,43 % |
| 10 | 66,67 % | 13,33 % |
| 12 | 57,58 % | 9,09 % |
| 14 | 50,55 % | 6,59 % |

Calcul de la première main, sans conservation, mulligan, recomposition ni carte de pioche. Ces fonctions existent partiellement dans Cartes ; elles demandent une analyse séparée de séquence et de coût.

**Proposition de première comparaison :** deck actif de 10 cartes, réserve séparée, maximum deux copies par famille. Recevoir une carte l'ajoute à l'inventaire, jamais automatiquement au deck. Remplacer gratuitement hors combat préserve l'expérimentation. Garder 8 cartes comme référence de comparaison, pas comme minimum implicitement optimal. Un deck plus grand doit recevoir un bénéfice défini et testé ; augmenter sa taille n'est pas intrinsèquement une récompense.

Départ cible : choisir cinq familles en deux copies parmi quinze de la classe. Parmi ces quinze, garantir plusieurs options de mobilité, de défense et d'attaque jouables sans objet. Ne pas confondre quinze cartes de départ avec quinze formes évoluées de trois actions. Le laboratoire de huit cartes ne constitue pas ce catalogue final.

## 9. Équipements, runes, reliques : contrats de contenu

**Équipement proposé.** Six emplacements nommés : arme, tête, torse, ceinture, pieds, bijou. Pas d'équipement obligatoire au départ ; gestes de secours indépendants d'un drop. Un objet simple de début de run apporte un bonus principal et au plus un effet conditionnel. Les niveaux d'objet contrôlent un budget ; la rareté contrôle surtout la spécialisation de ses propriétés, pas un multiplicateur automatique sur tout.

Exemples de fiches, à construire et tester après la migration des emplacements :

| Objet | Budget de travail | Usage / coût d'opportunité |
|---|---|---|
| Sandales souples I | +8 % PVmax ; pas de bonus PA/PM permanent | Universelles, remplacées si l'on veut investir davantage dans un effet de mobilité |
| Ceinture de garde I | +8 armure ; −4 résistance magique | Prépare la porte, expose davantage aux attaques magiques du puits |
| Dague d'angle I | +5 % Prouesse ; premier coup de mêlée isolé +8 % | Utile à l'Assassin, mais pas réservée à sa classe ; observer l'empilement avec ses passifs |
| Bague de givre I | Premier ralentissement appliqué par activation : +15 % aux seuls dégâts directs de cette action | Ni durée supplémentaire ni ralentissement créé par un sort qui n'en possède pas |

**Rune proposée.** Un modificateur attaché à un objet, avec compatibilité déclarée et un seul emplacement dans le premier lot. Retrait hors combat ; aucune destruction obligatoire pendant l'apprentissage. Exemple : convertir un bonus de défense physique en défense magique de même budget. Une rune qui ajoute une nouvelle réaction exige les mêmes tests qu'une relique.

**Relique permanente.** Une règle équipée pendant la run. Exemple expérimental à venir : une fois par combat, conserver une seconde carte à la fin du tour, annoncée avant la défausse. Le choix crée de la planification, pas seulement +5 % partout.

**Relique éphémère / consommable.** Une instance avec charges, coût d'utilisation, fenêtre légale et fin d'effet explicites. Exemple : obtenir une garde immédiate puis un malus de mobilité à la prochaine activation. La durée et les charges ne sont jamais stockées dans la définition partagée.

**Économie.** Tous les objets de butin sont reçus, utilisables ou vendables ; une carte équipée doit d'abord quitter le deck avant vente. Un objet vendu retire son instance et ses effets. La récompense d'un combat possède un reçu immuable : recharger ne retire pas un nouvel objet et n'en ajoute pas un second.

Le modèle de prix antérieur n'est pas validé par cet audit. Mesurer séparément : revenus garantis, valeur de revente réellement encaissable, coût des services, achats possibles avant chaque combat et stock invendu. « Tout est vendable » n'a pas de valeur de gameplay sans accès suffisamment tôt à un marchand et sans usage intéressant de l'or.

## 10. Salles : construire des questions tactiques vérifiables

Le graphe R6 égalise le nombre de combats. Il faut maintenant égaliser les budgets de menace sans rendre les salles identiques. Le premier refuge arrive après cinq combats ; les suivants après sept et dix. Le lieu de préparation devant Pâris n'est pas un quatrième soin garanti.

| Chemin artistique voulu | Question de combat | Composition à essayer avec les ennemis existants | Variables à mesurer |
|---|---|---|---|
| Porte / brume | Contourner la garde, couper le tir ou encaisser pour tuer le soutien ? | Un garde devant, un tireur derrière, positions qui permettent deux angles d'approche | Tours nécessaires pour atteindre le tireur, dégâts évitables, rôle d'une poussée |
| Puits / profondeurs | Éliminer le lanceur, quitter la zone ou supporter l'altération ? | Un poseur de danger et un poursuivant ; premier danger différé, sortie toujours lisible | Coût en PM de la sortie, durée réellement subie des malus, résistance utile |
| Barque / eau | Conserver l'espace de recul ou pousser pour ouvrir une rive ? | Un ennemi qui déplace, un ennemi dont la portée profite du déplacement | Cases sûres restantes, attaques empêchées, dépendance à une mobilité spécifique |

Il s'agit de scénarios à comparer, pas de nouveaux ennemis créés. Le catalogue actuel utilise les familles `airain`, `styx`, `lethe` ; leur correspondance à porte/puits/barque doit être explicite. Ne pas appliquer des bonus « eau » en se fondant sur un nom contenant Styx.

Pour la difficulté, regarder **la première menace qu'un joueur peut empêcher**. Exemple : si un tireur tue automatiquement Achille avant qu'aucun déplacement ou contrôle légal ne puisse l'affecter, augmenter sa visibilité ne suffit pas. Inversement, si une poussée annule chaque ennemi sans coût d'opportunité, augmenter seulement leurs PV prolonge un combat déjà résolu.

Les défis doivent avoir un contrat local : condition observable, récompense précise, conséquence annoncée sur la prochaine salle et remise à zéro ensuite. Éviter une accumulation illimitée « plus lent → prochain combat plus fort → encore plus lent » : elle favorise structurellement les builds d'explosion et peut rendre les builds défensifs inviables. Comparer les effets sur chaque classe avant d'en faire une loi de la run.

## 11. Architecture qui peut accueillir beaucoup de contenu

### Objets de données à distinguer

| Contrat | Champs minimaux | Validations indispensables |
|---|---|---|
| Définition de classe | ID, passif, pool de départ, spécialisations, caps | Références existantes ; aucun ID dupliqué ; assez d'options sans équipement |
| Définition de carte | ID, famille, classe, `Spell`, rôle, contraintes, rareté, transformations | Ciblage légal, coût valide, ressource d'effet supportée, identifiants stables |
| Copie possédée | ID d'instance, définition, transformation, provenance, verrou de départ éventuel | Vente et transfert atomiques ; pas d'exemplaire fantôme |
| État de build | classe principale, spécialisation, maîtrises, points et historique | Budget conservé, caps respectés, remboursement des dépendances |
| État de combat | main/pioche/défausse, PA/PM, compteurs par activation, statuts | Aucune mutation de la définition ; réinitialisation aux bonnes frontières |
| Table de butin | groupes, poids, niveaux, garanties, replis | Masse de probabilité, groupes non vides ou repli déclaré, graine et reçus |
| Contrat de rencontre | composition, positions, XP, menace, loot, règles de défi | Entrées et sorties jouables ; budget XP du segment ; test du chemin |
| Sauvegarde de run | versions du contenu et des règles, IDs, états, RNG et reçus | Migration explicite ; rejeter ou convertir les références inconnues sans les perdre silencieusement |

Ces contrats peuvent être des Resources ou des objets runtime existants étendus. Il ne s'agit pas de créer huit gestionnaires globaux supplémentaires. `Spell`, `StatusData`, `ItemDefinition`, `CatabaseCards`, `ChampionProgressionState`, `SpellCaster` et les services du Studio restent les points d'appui.

### Effets et événements

Avant d'ajouter une règle réactive, écrire :

1. Événement exact : carte jouée, impact résolu, PV retirés, bouclier absorbé, mort, déplacement volontaire, début/fin d'activation.
2. Source et cible : qui possède la réaction, qui reçoit l'effet ; appartenance à une équipe.
3. Conditions : tags de mécanique, dégâts directs/périodiques, portée, état avant ou après l'impact.
4. Fréquence : par carte, lancement, impact, cible, activation ou combat. Un sort de zone ne doit pas multiplier par accident un gain « une fois par lancement ».
5. Calcul : snapshot ou lecture dynamique ; ordre des arrondis, résistances, critique et absorption.
6. Durée, cumul, remplacement, consommation ; comportement si la cible ou la source meurt.
7. Idempotence : `cast_id`, `impact_id`, `trigger_id` ; un événement rejoué ne recrée pas sa récompense.
8. Prévisualisation et trace : la même résolution alimente l'UI et les contrôles, les limites doivent être visibles.

Limiter les réactions génératrices : une même réaction ne peut se redéclencher elle-même dans la chaîne du même lancement ; une génération de PA doit déclarer une limite par activation. Un plafond technique de sécurité signale un défaut et fait échouer le test, il ne sert pas à couper silencieusement une combinaison légale.

### Vérifier la compatibilité au lieu de compter des mots

Une carte productrice déclare les faits qu'elle peut créer (`slow`, `guard`, `forced_move`, `opening`). Une carte consommatrice déclare ses conditions et ses alternatives. La validation construit un graphe des dépendances ; elle détecte une exploitation sans moyen d'activation dans son pool et une boucle de génération gratuite.

Le graphe n'est qu'un premier filtre : deux cartes compatibles peuvent demander trop de PA, des positions incompatibles ou des durées qui ne se recouvrent pas. Les micro-scénarios exécutent ensuite la séquence sur une grille. C'est cette séparation qui permet d'ajouter du contenu sans tenter manuellement toutes les paires de milliers de cartes.

### Plan de migration contrôlé

1. Catalogues de classes/cartes versionnés, sélection de départ et validations ; garder la production actuelle comme référence de comparaison.
2. État de build séparé de l'arbre ; progression aux niveaux, reçus et reprise après plusieurs niveaux d'un coup.
3. Migration des emplacements d'équipement ; inventaire et comparaison, vente, déséquipement, sauvegarde.
4. Tables de loot par groupes indépendantes des axes historiques ; dépôts réels dans la réserve, aucun ajout silencieux au deck.
5. Une classe complète avec quinze cartes de départ, trois spécialisations et les objets nécessaires aux essais ; puis les autres, en réutilisant les primitives validées.
6. Combats et parcours comparés avec le vrai moteur, puis essais humains guidés ; seulement ensuite affiliations à mécaniques nouvelles.

## 12. Boucle de création et critères d'arrêt

Pour chaque carte : **problème tactique → contrat → exemplaire → test de résolution → scénarios favorables/défavorables → run appariée → essai humain → révision ou retrait**.

Le prochain lot ne devrait pas être validé parce qu'il compile ou parce qu'un bot gagne. Conditions :

- Chaque carte de départ fonctionne sans équipement et possède au moins un emploi favorable et une alternative meilleure dans un autre contexte.
- Chaque classe garde une réponse de base aux premières menaces, avec un coût d'opportunité ; un mauvais set peut perdre, mais la menace et la possibilité de préparation doivent être lisibles.
- Une majorité d'emprunts de début de run sont évaluables immédiatement ; les cartes très spécialisées restent explicitement dépendantes.
- Prévisualisation et impact exécuté concordent, notamment pour les cibles de zone, les coûts et les contrôles.
- Niveaux multiples, récompenses, vente, changement de deck et reprise sont transactionnels.
- Aucune boucle gratuite de PA/pioche/soin ; aucune récompense répétable par chargement.
- Les comparaisons couvrent les trois segments d'entrée et les trois grades d'ennemis ; les décisions de nerf ne reposent pas sur une seule graine ou une seule politique de bot.

Mesures à conserver : offres vues / cartes reçues / cartes équipées / cartes réellement jouées ; PA dépensés, cartes mortes en main, dégâts bruts/résolus/PV, overkill, garde créée/absorbée/expirée, menaces annulées, durée et coût d'entretien des statuts, argent encaissé/dépensé, combats restants au moment d'un drop.

**Contre l'explosion incontrôlée du contenu :** augmenter d'abord le nombre de combinaisons utiles d'effets fiables. Une primitive nouvelle doit justifier plusieurs cartes ou rencontres intéressantes et avoir un propriétaire technique. Ajouter dix mots-clés sans contrat multiplie les cas particuliers ; ce n'est pas une progression de la profondeur du jeu.

## 13. Reproduction et limites des preuves

Exécuter depuis la racine :

```powershell
./dev.ps1 test test/unit/test_build_system_lab.gd
python tools/build_system_lab/analyze.py --validation artifacts/dev/<dossier-du-test>/summary.json
```

Le script d'analyse refuse une validation échouée ou incomplète et vérifie les empreintes des principales sources de l'export. Une modification des entrées impose un nouvel export. Les sorties sont `artifacts/dev/build_system_lab/engine_audit.json` et `analysis.json`.

La suite ciblée couvre dix tests : indépendance des cartes, préparation/frappe, garde, poussée, déplacement/tir, givre, zone, seuil de mise à mort, répétition des attaques, export du système. Les premières exécutions ont révélé des erreurs dans le protocole du harnais et un historique de faits de bouclier non libéré ; le harnais a été corrigé. Elles ne sont pas présentées comme des preuves de réussite.

**Validation finale : 10 tests, 153 assertions, PASS**, sans erreur moteur dans `artifacts/dev/20260919-131155-test-test_unit_test_build_system_lab.gd-f6f70d72/summary.json`. Analyse exacte exécutée ensuite avec cette validation, sortie 0 et empreintes concordantes.

Le laboratoire ne couvre pas encore : run complète avec ces classes, passifs proposés, affinage des quinze cartes par classe, UI de ces cartes, économie d'objets à six emplacements, assets et migration des sauvegardes. Les résultats de probabilités ne sont ni des taux de victoire ni des validations de plaisir. Les tests généraux du dépôt n'ont pas été déclarés verts par cette tâche.
