# Sources, couverture et limites de vérification

Étude documentaire du **premier Slay the Spire**, le 25 septembre 2026. Hors Slay the Spire 2, mods et jeu de plateau. Les règles retenues incorporent l’équilibrage 2.2 ; cette mention n’est pas une certification binaire d’une version de client. Aucun exécutable, JAR, sauvegarde ou moteur StS n’a été lancé ou vérifié par empreinte.

## 1. Définir « toutes les cartes » avant de compter

| Ensemble couvert | Nombre | Traitement |
|---|---:|---|
| Ironclad | 75 | Contrat normal, amélioration, coût et analyse individuelle. |
| Silent | 75 | Même traitement. |
| Defect | 75 | Même traitement, orbes expliqués séparément. |
| Watcher | 75 | Même traitement, postures et générations distinguées. |
| Incolores ordinaires | 35 | Hors jetons, statuts et choix de Wish. |
| Spéciales | 13 | 4 cartes d’événement et 9 cartes générées. |
| Statuts | 5 | Dont Burn et sa version améliorée particulière. |
| Malédictions | 14 | Y compris Pride, Curse of the Bell et Ascender’s Bane. |
| Choix de Wish | 3 | Pseudo-cartes de sélection, pas trois drops indépendants. |
| **Total** | **370** | **367 entrées de cartes + 3 choix de Wish.** |

Une amélioration n’est pas comptée comme une nouvelle entrée. Les Strike et Defend des quatre couleurs restent des entrées distinctes, même si leur texte de base se ressemble. Le JSON conserve les identifiants internes : par exemple `GASH` est Claw, `REDO` est Recursion, `NIGHT_TERROR` est Nightmare. Ce ne sont pas des cartes supplémentaires.

La couverture exhaustive porte sur **les contrats des cartes et leurs effets associés**. Les effets de reliques et d’ennemis sont examinés quand ils expliquent ces interactions ; leurs catalogues complets, les potions, les tables de récompenses et les IA ne sont pas certifiés exhaustifs par ce dossier.

## 2. Inventaire de départ et réconciliation

Source principale : [Spire Archive, `data/sts1/cards.json`, commit fixé](https://github.com/nkhoit/spire-archive/blob/687e6dce1f325234425e1b75f09d13ddd6ce7000/data/sts1/cards.json). Commit `687e6dce1f325234425e1b75f09d13ddd6ce7000`, daté du 9 septembre 2026 dans l’historique GitHub consulté. C’est un inventaire communautaire, pas une API officielle Mega Crit.

Son README annonce 361 cartes, mais son fichier contient **360 entrées**. Deux cartes retirées, `IMPULSE` et `UNRAVELING`, ne sont pas conservées dans le catalogue jouable étudié : **358**. L’ajout des neuf cartes générées absentes donne **367**, puis les trois choix de Wish donnent **370**. Les métadonnées factuelles conservées sont dans [inventaire_reference.json](inventaire_reference.json) et [supplements_reference.json](supplements_reference.json).

Les neuf compléments sont Beta, Expunger, Insight, Miracle, Omega, Safety, Shiv, Smite et Through Violence. Recoupement par la [liste des incolores et spéciales](https://slay-the-spire.fandom.com/wiki/Colorless_Cards), la [fiche Beta](https://slay-the-spire.fandom.com/wiki/Beta) et le [module de cartes wiki.gg](https://slaythespire.wiki.gg/wiki/Module%3ACards/data) pour les choix de Wish. La [fiche Wish](https://slay-the-spire.fandom.com/wiki/Wish) confirme leurs trois valeurs et leurs améliorations.

Les listes [Ironclad](https://slaythespire.gg/cards/ironclad), [Silent](https://slaythespire.gg/cards/silent), [Defect](https://slaythespire.gg/cards/defect) et [Watcher](https://slaythespire.gg/cards/watcher) ont servi de recoupement de couverture. Une autre liste rencontrée à 333 cartes n’a pas été retenue comme preuve d’exhaustivité. Les totaux affichés sur une page ne suffisent pas : il faut examiner ce qu’elle inclut et exclut.

Les fiches locales sont une reformulation française des faits de règles avec une analyse originale. Elles ne reproduisent ni illustrations, ni longs textes éditoriaux, ni traductions officielles complètes. Les noms anglais permettent de retrouver sans ambiguïté les sources.

## 3. Anomalies de données corrigées

La reconstruction automatique des améliorations dans le jeu de données peut modifier la mauvaise valeur ou seulement sa première occurrence. Nous avons donc conservé l’inventaire mais réécrit les contrats, avec recoupement ciblé des anomalies. Treize cas explicites :

| Carte | Anomalie rencontrée | Contrat retenu | Recoupement |
|---|---|---|---|
| Flex | Dette de Force non mise à jour avec le gain. | +4 Force puis −4 en fin de tour. | [Fiche](https://slaythespire.gg/cards/ironclad/Flex) |
| Sword Boomerang | Dégâts et nombre de frappes confondus. | 3 dégâts, 4 impacts en version +. | [Fiche](https://slaythespire.gg/cards/ironclad/Sword_Boomerang) |
| Uppercut | Deuxième durée non mise à jour. | Faible 2 et Vulnérable 2 en version +. | [Fiche](https://slaythespire.gg/cards/ironclad/Uppercut) |
| Searing Blow | Première amélioration incomplète. | 16, puis gains successifs +5, +6, etc. | [Fiche](https://slaythespire.gg/cards/ironclad/Searing_Blow) |
| Bane | Deuxième impact resté à l’ancienne valeur. | 10 + 10 si la condition est vraie. | [Fiche](https://slaythespire.gg/cards/silent/Bane) |
| Bouncing Flask | Intensité et répétitions confondues. | 3 Poison, 4 applications en version +. | [Fiche](https://slaythespire.gg/cards/silent/Bouncing_Flask) |
| Dodge and Roll | Blocage différé non mis à jour. | 6 maintenant et 6 au prochain tour. | [Fiche](https://slaythespire.gg/cards/silent/Dodge_and_Roll) |
| Grand Finale | Description améliorée invalide. | 60 dégâts à tous, sous condition de pioche vide. | [Fiche](https://slaythespire.gg/cards/silent/Grand_Finale) |
| Reprogram | Gains de Force et Dextérité non mis à jour. | −2 Focus, +2 Force, +2 Dextérité. | [Fiche](https://slaythespire.gg/cards/defect/Reprogram) |
| Genetic Algorithm | Valeur initiale de blocage manquante. | Départ 1 ; croissance par usage +2 ou +3. | [Fiche](https://slaythespire.gg/cards/defect/Genetic_Algorithm) |
| Fasting | Deuxième statistique non mise à jour. | +4 Force et +4 Dextérité en version +. | [Fiche](https://slaythespire.gg/cards/watcher/Fasting) |
| Halt | Gain conditionnel non mis à jour. | 4, puis 14 supplémentaires en Wrath. | [Fiche](https://slaythespire.gg/cards/watcher/Halt) |
| Tantrum | Dégâts et répétitions confondus. | 3 dégâts, 4 impacts en version +. | [Fiche](https://slaythespire.gg/cards/watcher/Tantrum) |

D’autres textes bruts contiennent des variables ou icônes manquantes : Body Slam doit exprimer la garde actuelle, Genetic Algorithm et Ritual Dagger leur valeur initiale, Deva Form sa progression d’énergie. Les contrats locaux explicitent ces valeurs au lieu de conserver un `0`, un blanc ou un marqueur technique.

Une relecture a aussi précisé le +50 % de Lock-On, la distinction Armure plaquée/Metallicize pour Wish et la possibilité qu’Envenom active le second coup de Bane après le premier. [Bullseye](https://slay-the-spire.fandom.com/wiki/Bullseye), [Wish](https://slay-the-spire.fandom.com/wiki/Wish), [Envenom](https://slay-the-spire.fandom.com/wiki/Envenom).

**Limite importante :** les 370 fiches ont été lues et reformulées, mais n’ont pas chacune fait l’objet de plusieurs vérifications indépendantes ni d’un test dans le client. Le recoupement est ciblé sur les valeurs douteuses, les changements de règles et les interactions structurantes. Une couverture complète n’est pas une garantie d’absence d’erreur résiduelle.

## 4. Hiérarchie de preuve

| Niveau | Sources utilisées | Ce qu’on leur demande |
|---|---|---|
| Créateur | Présentation GDC d’Anthony Giovannetti ; notes de mise à jour Mega Crit sur Steam. | Intentions générales documentées, méthode de travail, changements annoncés ; pas des intentions supposées pour chaque carte. |
| Données communautaires | Spire Archive fixé à un commit, listes et fiches Spire.gg, modules des wikis. | Inventaire et chiffres ; recouper les valeurs ambiguës, ne pas traiter un parseur comme le client. |
| Documentation d’interactions | Pages des wikis sur pioche, Retain, Burst, Recycle, Artifact, postures, orbes, etc. | Règles précises et exceptions ; les cas délicats restent à reproduire si notre implémentation en dépend. |
| Retours de joueurs | Discussions datées sur True Grit, Uppercut, Accuracy, Wallop et les coûts cachés. | Comprendre des expériences et hypothèses de plaisir ; aucun taux de popularité ou de victoire déduit des votes. |
| Notre travail | Contrats en français, analyses, comparaison locale, calculs déterministes. | Raisonnements explicites et reproductibles, distingués des faits attribués aux sources. |

Certaines pages Fandom/wiki.gg ont refusé l’ouverture directe ; leurs extraits indexés par la recherche ont permis de lire les passages concernés. Cela n’équivaut pas à une visite interactive du jeu ou à l’examen de tout leur historique. Les pages citées dans les documents fournissent les points de reprise.

Les 146 entrées de pouvoirs et 48 mots-clés trouvés dans les fichiers bruts ont été parcourus, mais contiennent des éléments anciens, incomplets ou redondants. Le dossier ne présente donc pas « 146 effets certifiés » à partir de ce seul décompte. Les règles partagées utiles sont consolidées dans [EFFETS_ET_REGLES.md](EFFETS_ET_REGLES.md).

Sources créateur : [GDC 2019, document original](https://media.gdcvault.com/gdc2019/presentations/Giovannetti_Anthony_SlayTheSpire.pdf), [annonce Steam 2.2](https://store.steampowered.com/news/posts/?appids=646570&enddate=1607901864&feed=steam_community_announcements). La vidéo de conférence a été repérée ; ce dossier ne prétend pas en avoir visionné intégralement le contenu.

## 5. Vérification locale reproductible

Depuis la racine du dépôt, avec Node :

```powershell
node docs/design/slay_the_spire_complete_2026-09-25/construire_catalogue.mjs
node docs/design/slay_the_spire_complete_2026-09-25/calculs.mjs
node docs/design/slay_the_spire_complete_2026-09-25/verifier_dossier.mjs
```

Le premier script contrôle les identifiants, la correspondance avec les métadonnées et les cinq groupes, puis génère les catalogues Markdown et JSON. Le deuxième calcule 47 scénarios avec 50 assertions ; 3 003 mains distinctes recoupent indépendamment les formules de tirage. Le troisième vérifie la couverture, la fraîcheur des fichiers générés, les cibles de liens locaux, les formes d’URL et les invariants du dossier. Il ne certifie pas que toutes les URL distantes répondent aujourd’hui ni que le jeu original exécute chaque interaction exactement ainsi.

Résultats et limites sont dans [CALCULS.md](CALCULS.md), [resultats_calcules.json](resultats_calcules.json) et [VERIFICATION.json](VERIFICATION.json). Les formules annoncent leur horizon, les bonus supposés et les absences de purge/protection. Elles ne simulent ni une run complète ni une IA de joueur.

Pas d’import Godot, de tests moteur, de capture visuelle ni de partie humaine exécutés pour cette livraison documentaire. Aucune carte jouable, règle de drop ou sauvegarde du jeu n’a été modifiée. Le fichier de travail conserve l’état de reprise : [WORKLOG.md](WORKLOG.md).

## 6. Comment poursuivre sans perdre la traçabilité

Pour corriger une carte : modifier sa ligne dans `lectures_*.tsv`, ajouter le recoupement utile, régénérer et vérifier. Modifier les métadonnées uniquement si l’identifiant, le coût, le type ou la rareté sont effectivement erronés. Ne pas remplacer aveuglément les contrats par le texte d’une nouvelle extraction.

Avant une transposition : préciser le timing, le cumul, la cible, la provenance des cartes produites, les conditions de paiement et de remboursement, puis ajouter un cas de calcul ou de moteur pertinent. Les scénarios de file d’actions, de copies imbriquées et de morts simultanées demandent une vérification d’exécution distincte.

Pour une reprise sur un autre ordinateur, récupérer `main` puis ouvrir le README du dossier. L’utilisateur a demandé le commit et le push de l’ensemble des recherches. Les dossiers antérieurs sont déjà versionnés dans `main` au moment de la préparation finale, sur la base `24053adbb4a41f9442f14a6c23ca721b8c413c8b`. Les catalogues Godot et règles de salles cités ne présentent pas de différence entre la référence d’analyse initiale `6a500c54` et cette base. L’état de validation avant publication est conservé dans le journal ; aucun succès de CI distante n’est présumé.
