# Étude complète des cartes de Slay the Spire 1

**370 fiches : 367 entrées de cartes et les 3 choix de Wish**, avec effets normaux et améliorés, coûts, fonctions, synergies et limites. Étude du 25 septembre 2026, destinée à la conception de Catabase et de sa run à cartes consommables. Hors suite, mods et jeu de plateau.

Le résultat principal : la profondeur vient des **conversions, des conditions d’accès et du moment où l’on dépense une ressource**. Les quatre personnages ne se distinguent pas seulement par leurs dégâts : Ironclad transforme les sacrifices ; Silent fait circuler et prépare une fenêtre ; Defect organise une production par orbes ; Watcher agence les postures, les risques et les cartes conservées.

## Lire les cartes

Complément demandé avant clôture : [les 18 personnages WAKFU, leurs passifs et leurs directions de build](../wakfu_character_builds_2026-09-25/README.md). Il ajoute 36 identifiants au corpus précédent, deux relectures et 15 calculs de ressources, de seuils et de temporalité.

Chaque fiche précise le contrat base → amélioration, le coût imprimé, le type et la rareté, puis une analyse originale de son rôle et de ses limites. Les noms anglais et identifiants internes facilitent la recherche. D signifie dégâts, B blocage.

| Catalogue | Contenu |
|---|---|
| [Ironclad](CATALOGUE_IRONCLAD.md) | 75 cartes ; Force, sacrifices, épuisement, réserve de blocage. |
| [Silent](CATALOGUE_SILENT.md) | 75 cartes ; poison, défausse, Shiv, préparation de tours. |
| [Defect](CATALOGUE_DEFECT.md) | 75 cartes ; orbes, Focus, capacité, récupération et coûts. |
| [Watcher](CATALOGUE_WATCHER.md) | 75 cartes ; postures, Mantra, rétention, Scry et génération. |
| [Incolores et autres](CATALOGUE_NEUTRES.md) | 35 incolores ordinaires, 13 spéciales, 5 statuts, 14 malédictions, 3 choix de Wish. |

Pour une reprise par un outil : [catalogue.json](catalogue.json) contient les mêmes 370 fiches structurées ; les cinq fichiers `lectures_*.tsv` sont les sources éditables.

## Comprendre les systèmes

- [Effets et règles](EFFETS_ET_REGLES.md) : pioche, défausse, épuisement, création, copie, énergie, dégâts, blocage, orbes, postures, dettes et contre-jeu.
- [Analyse des builds](ANALYSE_DES_BUILDS.md) : douze moteurs détaillés, pièces de liaison, points de rupture, améliorations qualitatives, évolution de l’équilibrage et retours de joueurs.
- [Calculs](CALCULS.md) : 47 scénarios déterministes, 50 assertions, 3 003 mains énumérées pour recouper les probabilités.
- [Application à Catabase](APPLICATION_CATABASE.md) : comparaison avec le code et la V1 théorique, priorités et six prototypes de règles à éprouver.
- [Sources et vérification](SOURCES_ET_VERIFICATION.md) : inventaire fixé à un commit, anomalies corrigées, périmètre et limites de preuve.

## Les enseignements prioritaires pour notre jeu

**La consommation change les moteurs.** Épuiser dans StS retire une carte pour un combat ; chez nous, la copie jouée disparaît de la run. Les moteurs fondés sur son rejouage doivent donc être repensés autour de la famille, d’un effet installé ou d’une autre conversion. Le drop de sacs sur les monstres reste le cœur du ravitaillement.

**Le contrôle d’accès mérite autant de travail que les dégâts.** Dans un tirage initial de 5, réunir deux familles à trois exemplaires chacune passe de 51,45 % avec 15 cartes à 16,53 % avec 30. Remplir systématiquement le plafond peut rendre les combinaisons bien moins fiables.

**Nos améliorations peuvent mieux exprimer les builds.** Dans la V1 théorique actuelle, 33 familles sur 48 améliorent uniquement leurs dégâts. True Grit, Fission ou Eruption montrent l’intérêt de modifier un choix, une conversion ou le budget d’une séquence. Ce sont des inspirations de conception, pas des valeurs à copier.

**Les générateurs demandent un contrat économique.** Une rafale dans une seule carte et trois jetons jouables séparément n’ont ni les mêmes déclencheurs ni les mêmes coûts. La limite d’une famille par tour, la provenance des copies et leur éventuelle valeur marchande doivent être définies ensemble.

## Ce qui a été vérifié

Les 370 contrats ont été lus et reformulés ; les anomalies et interactions structurantes ont fait l’objet de recoupements ciblés. Treize erreurs explicites de descriptions améliorées du jeu de données ont été corrigées. Les intentions d’équilibrage s’appuient notamment sur la [présentation originale de Mega Crit à la GDC 2019](https://media.gdcvault.com/gdc2019/presentations/Giovannetti_Anthony_SlayTheSpire.pdf), en distinguant ses propos de nos interprétations.

Les scripts contrôlent la couverture, les fichiers générés et les calculs annoncés. **Ils ne constituent pas 370 tests dans le client StS**, une simulation complète de run ou une validation du plaisir de jeu. Les cas limites encore à reproduire sont identifiés dans le document de règles. Le catalogue complet des reliques, potions et IA ennemies reste hors de cette livraison centrée sur les cartes.

Commandes et résultats : [méthode reproductible](SOURCES_ET_VERIFICATION.md), [rapport de vérification](VERIFICATION.json). Aucun changement du gameplay Godot. Le dossier rejoint les études précédentes sur `main` à la demande de l’utilisateur ; sur l’autre ordinateur, récupérer cette branche puis ouvrir ce README. Pour reprendre le travail : [journal et suite](WORKLOG.md).
