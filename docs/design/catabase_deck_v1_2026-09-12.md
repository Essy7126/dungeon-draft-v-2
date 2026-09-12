# Catabase — prototype jouable de deck V1

**Prototype retiré à la demande du joueur le 12 septembre 2026.** Ce document est
un historique d'essai, pas le fonctionnement actuel. Le jeu a retrouvé ses sorts,
sa progression et ses récompenses habituels. Seuls les défis ont été conservés :
voir [la décision actuelle](catabase_challenges_without_deck_2026-09-12.md).

Implémentation du 12 septembre 2026, à la demande du joueur. Première expérience de gameplay, pas un équilibrage définitif.

## Lancer et jouer

Depuis **Nouvelle partie**, choisir Achille et suivre l'entrée habituelle. Après le placement d'Achille dans la première arène, choisir deux familles parmi Bronze, Chasse, Garde, Braise, Courant et Serment. Les quatre cartes de chaque famille s'ajoutent à quatre fondamentaux : douze exemplaires distincts au départ. Aucune condition de déblocage et aucun nouveau personnage.

- Main de cinq cartes. Les cartes jouées quittent la main dès que leur coût est engagé.
- 6 PA pour jouer ; 3 PM pour les déplacements ordinaires. Une frappe de secours de 3 PA reste disponible une fois par activation.
- Bouton **Conserver** : retenir une carte pour le prochain tour. Les autres sont défaussées. La pioche se remélange avec la défausse quand elle est vide.
- **Échanger la main initiale** : une seule fois, avant toute action ou déplacement. Les cartes échangées ne peuvent pas être immédiatement repiochées comme remplaçantes.
- **Renforcer avec Ferveur** : active la dépense optionnelle indiquée dans certaines cartes. Si la réserve ne suffit pas, l'effet de base reste jouable. Réserve limitée à trois ; gain au plus une fois par fenêtre de tour par déplacement ennemi effectif, réaction élémentaire ou blocage complet d'une attaque ennemie.
- Les cartes de Dette de sang et Dernier mot sont épuisées pour le combat après usage.
- Après une victoire : trois cartes proposées, ou les provisions. La carte choisie rejoint la collection et le deck s'il compte moins de seize cartes.
- Entre les combats : onglet **Deck**, activer/retirer les exemplaires pour rester entre douze et seize cartes. Pour remplacer dans un deck de douze, ajouter d'abord le nouvel exemplaire puis retirer l'ancien.

La barre habituelle conserve les raccourcis de lancement et la frappe de secours ; la main au-dessus affiche les noms et les boutons de conservation. Survoler une carte donne ses règles. Les PM ne nécessitent aucune carte.

## Contenu et variations par rapport à l'esquisse

24 techniques + 4 fondamentaux sont réellement résolus par SpellCaster. La collection comprend déplacements, boucliers, conversion en dégâts, états consommables, vision, terrain, préparation de zone, pioche et paiement de PV.

Pour garder une V1 cohérente avec les primitives du moteur, certains effets diffèrent de l'esquisse :

- Brèche retire 10 d'armure pour deux activations de la cible.
- Percussion renforcée augmente ses dégâts et pousse sa cible ; pas d'onde secondaire dans cette version.
- Tir de traverse touche les ennemis de la ligne avec le même coefficient.
- Prévoir pioche deux cartes puis exige d'en remettre une sous la pioche avant de poursuivre ses actions.
- Préparation pioche une carte puis défausse la plus ancienne de la main.
- Rappel des eaux attire davantage une cible Mouillée ; il n'offre pas encore de déplacement latéral libre.
- Ancrage résiste à deux cases du premier déplacement forcé ; les PM sont terminés.
- Cendre fertile pose une case appliquant une réduction de PM à l'entrée ; elle ne change pas directement le coût de chaque pas.
- Vapeur occupe une case et coupe la vue pendant deux rounds.

Les descriptions affichées sont celles de ces effets implémentés. Les paramètres détaillés sont dans `core/expedition/catabase_deck_catalog.gd`.

Fournaise marque une croix fixe puis explose au début de la prochaine activation d'Achille. Elle touche aussi Achille et les alliés présents. Les marques orange montrent les cases. Les états Chauffé/Mouillé et la foudre permettent consommation, vapeur et rebond ; une carte ne lance pas une boucle infinie de réactions.

## Menace et chemins

Dans les nouvelles parties avec deck, les ennemis II–VI utilisent des valeurs plus fortes : ordre de grandeur à II, 38–50 PV pour les soutiens/attaquants, 78 pour le garde, 11–16 de puissance d'attaque. Les groupes de trois bénéficient d'une réduction de budget individuelle ; la progression reste fixée par la profondeur, jamais ajustée au deck ou aux blessures du joueur. Les molosses de cette version ont 4 PM.

Une menace de salle est annoncée aux tours 2 et 5, puis résolue à l'activation suivante :

- Puits/confluence : un impact de feu sur une case fixe.
- Porte : une salve physique sur une petite ligne fixe.
- Barque : un ressac physique sur une petite ligne fixe.

Les marques rouges sont dangereuses pour tous les occupants. Ce premier ressac inflige des dégâts ; la poussée générale du courant, le convoi qui fuit et les renforts de la proposition restent des scénarios ultérieurs. Les attaques ordinaires des monstres gardent leur IA ; seules les préparations existantes et les zones spéciales constituent des intentions engagées. Il n'y a pas encore d'annonce exhaustive de toutes leurs actions ordinaires.

Un sceau turquoise est placé à quelques pas accessibles d'Achille. À une case maximum, **Éteindre le sceau** coûte 2 PA avant la fin du tour 4. Il empêche les prochaines menaces normales de cette salle. Une menace déjà annoncée se résout toujours : on n'efface pas rétrospectivement un impact en préparation.

## Défis et Alerte

Avant le combat, choisir une victoire en cinq/six tours, un sabotage de sceau (ou deux déplacements ennemis lorsque le sceau n'est pas disponible), ou refuser. Les conséquences sont affichées avant le choix :

- Réussite : conserver une carte supplémentaire à la première fin de tour du combat suivant.
- Échec : +1 Alerte pour le prochain combat.
- Alerte 1 : premier adversaire doté d'un bouclier temporaire de 10 % de ses PV.
- Alerte 2 : ce bouclier et une zone dangereuse supplémentaire, annoncée au tour 2 et résolue au tour 3.

L'option **Alerte liée à la durée**, proposée au choix initial du deck, reste désactivée par défaut. Lorsqu'elle est activée, chaque tranche de deux tours au-delà du budget ajoute un niveau ; le sabotage en retire un. Le calcul inclut l'échec du défi mais reste plafonné à deux. L'effet concerne uniquement le combat suivant : aucune augmentation multiplicative permanente.

Cette V1 compte les activations jouées d'Achille depuis le début du combat. Elle ne possède pas encore le démarrage d'horloge conditionné à l'entrée dans la phase de menace décrit dans la proposition. Le budget est visible ; l'option peut être laissée désactivée pour comparer les contrats seuls.

## Sauvegarde et compatibilité

La collection, les exemplaires équipés, les récompenses déjà reçues, les familles et les conséquences suivantes sont sauvegardés avec la session. Comme le reste du jeu, quitter pendant le combat reprend à son entrée engagée ; la même rencontre reproduit la même pioche initiale. Il ne s'agit pas d'une sauvegarde au milieu d'une action.

Les sauvegardes sans données de deck conservent les anciennes règles. Les outils historiques peuvent toujours démarrer `start_expedition(seed)` sans deck ; un laboratoire active explicitement `start_expedition(seed, {}, true)`. La nouvelle partie publique active le prototype.

## Vérifications et limites observées

- Tests ciblés : `artifacts/catabase_monsters/checks/deck_integration_20260912/gut-strict-report.json` — 44 tests, 3 956 assertions, PASS. Cartes, coûts, consommation unique, défausse/épuisement, réactions, sauvegarde, récompenses et régressions du parcours guidé.
- Vérification finale élargie : `artifacts/dev/deck_final/checks/gut-strict-report.json` — 85/85 tests, 4 138 assertions réussies, aucune assertion échouée. Le verdict strict reste FAIL : erreurs de ressources/RID à la fermeture et vérification de version GUT à l'import normal. Ce résultat fonctionnel ne constitue donc pas un succès technique intégral.
- Isolation des dernières corrections : `artifacts/dev/deck_probe/unit_final.log` — 12/12 tests, 104 assertions, sortie 0 et aucune erreur moteur. Couverture ajoutée : renouvellement de main avec conservation, sauvegardes malformées, statistiques de tous les ennemis malgré l'Alerte, sceau accessible, zones fixes incluant les occupants ennemis et distinction armure/résistance magique.
- Suite générale : `artifacts/dev/20260912-164057-test-all-98828525/gut-strict-report.json` — FAIL, arrêt automatique après 900 secondes, bilan GUT/JUnit incomplet. Des erreurs concernent notamment les tests du backend 3D d'Achille, les contrats d'art des haltes et Studio (`uses_compact_title()` absent dans `test_encounter_g6_closure.gd`). Aucun succès global n'est revendiqué ; ces modules n'ont pas été remaniés pour masquer leurs échecs.
- Le formateur 0.25.0 refuse la transformation du catalogue pour différence de structure ; ce garde-fou n'a pas été contourné. Les scripts de l'état, de l'adaptateur et des tests ont été formatés avec vérification de structure.
- Captures dans `artifacts/dev/deck_capture/` : choix des familles, contrat, main, conservation. La première capture a révélé une main coupée ; marges corrigées, puis cadrage de caméra adapté pour dégager le plateau. Recapture finale inspectée à 1280×720 : quatre étapes enregistrées, douze cartes, cinq en main ; `artifacts/dev/deck_probe/capture_final.log`, sortie 0 sans erreur moteur.
- Pilote répétitif, Bronze–Braise/puits : victoire I, II et III, défaite V. Après II : 38/143 PV à la récompense.
- Pilote sensible aux cartes et aux zones, Bronze–Braise/puits : défaite III. Ce pilote utilise notamment Fournaise sans toujours prévoir correctement le déplacement ennemi ; il ne constitue pas une preuve d'optimalité.
- Pilote Chasse–Garde/barque : victoire II avec 107/143 PV à la récompense, défaite III.

Ces trois parcours utilisent les scènes réelles et des actions normales, sans PV injectés ni victoires forcées. Ils montrent que la pression existe maintenant ; ils ne démontrent pas que chaque deck soit équilibré ni que toute la run soit raisonnablement gagnable. Les PV des récompenses incluent les effets des passages de niveau. Le retour humain suivant doit porter sur les décisions compréhensibles, les cartes inutiles, les tours contraints et les écarts entre familles.

Commandes :

```powershell
./dev.ps1 test test/unit/test_catabase_deck.gd
./dev.ps1 test test/unit/test_catabase_deck_integration.gd
& 'C:/Godot/4.7.1/Godot_v4.7.1-stable_win64_console.exe' --headless --path . res://tools/catabase_monster_validation/DeckLiveProbe.tscn -- route=barque kit=airain families=chasse,garde
```

Les sondes utilisent des sauvegardes isolées sous `artifacts/dev`, et peuvent remplacer leur propre checkpoint lors d'une nouvelle exécution. Un échec de combat dans un rapport de playtest n'est pas un test technique réussi ni une preuve de bug : examiner le journal et le motif de sortie séparément.
