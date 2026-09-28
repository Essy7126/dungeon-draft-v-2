# Audit du parcours joueur — sélection et interfaces

Date : 27 septembre 2026. Périmètre : parcours public Catabase, principalement
Cartes V2 ; compatibilité de la sélection Classique. DA : marron sobre, ivoire,
cuivre discret, illustrations existantes. Les propositions ci-dessous ne sont pas
des fonctionnalités livrées, sauf la section « Corrections réalisées ».

## Conclusion

Nous disposons des principales fenêtres. Le manque essentiel est la continuité
entre les décisions : comprendre son départ, retrouver un gain, mesurer un changement,
puis reprendre la route. Ajouter des écrans sans résoudre ces transitions alourdirait
le jeu. La priorité est une information fiable, au bon endroit, avec une action claire.

La sélection comportait deux défauts concrets : les cartes communes étaient étiquetées
comme appartenant à la classe choisie ; la puissance « P » apparaissait dans les
effets sans définition ni valeur initiale. Son récapitulatif répétait également les
quinze copies au lieu de montrer la composition. Ces points sont corrigés.

## Recherche : ce que Dofus 3 nous apprend réellement

Les captures fournies par le joueur servent de références visuelles : personnage
central, équipements autour de lui, inventaire en grille, statistiques alignées,
butin dans un tableau distinct. Une capture ne prouve toutefois ni le comportement
clavier, ni la sauvegarde d'un agencement, ni l'accessibilité d'une interface.

### Sources primaires consultées

1. [Ankama — interface de cosmétique et d'apparence](https://support.ankama.com/hc/fr/articles/47823763118097--DOFUS-L-interface-de-cosm%C3%A9tique-et-d-apparence),
   mise à jour le 17 juin 2026. Le support distingue l'inventaire cosmétique,
   l'équipement et la modification de l'apparence ; il documente l'accès Maj+C,
   le double-clic/menu contextuel et des états d'erreur différents.
   **Application chez nous :** nommer distinctement Possédé, Préparé, Équipé et
   Actif ; expliquer pourquoi une action est indisponible. Séparer apparence et
   classe est pertinent, mais copier le commerce cosmétique ne l'est pas.
2. [Ankama — problèmes liés à un achat dans DOFUS 3.0](https://support.ankama.com/hc/fr/articles/30832022825489--DOFUS-DOFUS-3-0-Probl%C3%A8mes-li%C3%A9s-%C3%A0-un-achat),
   mise à jour le 21 janvier 2025. L'article explique notamment le passage d'un
   cosmétique de l'inventaire à la collection après apprentissage.
   **Notre déduction :** une acquisition qui change de destination doit rester
   retrouvable. Pour nous, « Carte obtenue → Réserve » doit être annoncé et relié
   à la bonne famille. Ce n'est pas une preuve de la présence d'un badge Nouveau
   dans Dofus ; c'est une proposition pour Catabase.
3. [Angélique Delporte — retour de production sur les interfaces Dofus 3](https://fr.linkedin.com/posts/ang%C3%A9lique-delporte-6abb3115_dofus-3-est-sorti-le-3-d%C3%A9cembre-activity-7270009108831834112-qh9y),
   témoignage de la designer lors du lancement de décembre 2024. Elle décrit le
   travail avec Figs sur la direction artistique et le système de composants,
   puis l'implémentation et la bêta.
   **Application chez nous :** mêmes composants de fiche, vocabulaire, fermeture,
   focus et états dans toutes les fenêtres. La cohérence doit être construite
   dans les composants, pas reprise manuellement écran par écran.

### Limites de la comparaison

Le [devblog officiel sur les améliorations d'interfaces](https://www.dofus.com/fr/forum/1971-devblog/2435776-ameliorations-elements-interfaces)
renvoie une vérification JavaScript : son contenu n'a pas été exploité comme preuve.
Les synthèses communautaires des versions 3.1 et 3.6 ont servi à identifier des pistes
et dates, pas à attribuer des comportements non vérifiés à Dofus 3. Les anciens guides
Dofus 2 ont été écartés des affirmations sur la version 3. Le projet Figs consacré à
Wakfu est une référence complémentaire, pas une description de Dofus.
Il n'y a pas eu de session de test dans le client Dofus pendant cet audit.

## Inventaire des interfaces et écarts

P1 : prochaine amélioration utile au parcours ; P2 : préparation à l'extension du
contenu. « Présent » décrit le code inspecté ; la campagne visuelle de ce tour porte
sur la sélection, pas sur l'ensemble des écrans de la run.

| Écran | Déjà présent | Manque ou amélioration à prévoir | Priorité |
|---|---|---|---|
| Titre / reprise | Profils Classique et Cartes séparés ; continuer ; protection du remplacement | Résumé de sauvegarde avant ouverture : personnage, classe, niveau, salle, état de la run | P1 |
| Apparence | Trois apparences, aperçu animé, rotation et poses disponibles ; impact purement visuel expliqué | Hiérarchiser davantage Apparence / Classe ; garder ce principe lors de l'ajout de personnages ayant de vraies différences mécaniques | P2 |
| Classe | Rôle, passif, précaution de jeu, deck proposé et spécialisations du niveau 4 | Exemple concret de premier tour ; comparaison lisible des quatre styles, sans prétendre classer leur puissance | P1 |
| Deck initial | Quinze copies, limite par famille, consultation des portées/effets, brouillon conservé par classe | Réinitialiser au deck conseillé ; préparer explicitement les choix d'ouverture avant le premier combat, si retenu par le contrat de règles | P1 |
| Inventaire | Personnage, six emplacements, deux reliques, objets avec fiches/actions | Comparaison chiffrée avant/après ; filtre par emplacement ; nouveaux gains ; protection des objets conservés | P1 |
| Collection de cartes | Recherche et filtres, quantités préparées/réserve, favoris de familles, actions hors combat | Retrouver directement la famille gagnée depuis le bilan ; conserver filtre et position après fermeture | P1 |
| Caractéristiques | PV, PA, PM, puissance, résistances, taille de main, bonus d'équipement | Décomposer base / attributs / équipement ; afficher plafonds et perte éventuelle de bonus au plafond ; ne pas mélanger bonus conditionnels et permanents | P1 |
| Progression | Décisions d'attributs, améliorations de familles, spécialisation | Frise des prochains paliers ; distribution d'attributs préparée puis validée, avec annulation avant confirmation | P1 |
| Combat | Main illustrée, portées, fiches, compteurs de piles ; inspection du personnage sans modification | Pioche/défausse consultables avec les mêmes cartes et fiches, au lieu d'une liste textuelle ; aucune révélation de l'ordre aléatoire | P1 |
| Bilan et niveau | Reçu de butin stable ; séparation bilan puis niveau ; décisions persistées | Signal durable des gains non consultés et accès à leur destination ; maintenir le reçu indépendant des ventes/équipements ultérieurs | P1 |
| Carte | Vue complète, légende, recentrage, destination inspectée puis confirmée, explication d'indisponibilité | Vérifier l'uniformité des termes récompense/risque entre les variantes ; éviter toute promesse chiffrée périmée | P2 |
| Navigation / aide | Fenêtres fermables, arbitrage des modales, raccourcis, animations réduites ; contrôle musical au titre | Noms identiques dans HUD et fenêtres ; aide des raccourcis ; glossaire réellement consultable ; réglages de texte et d'infobulles | P1 |

### Preuves dans le code

- `ui/titre_ecran.gd::_refresh_run_choice` : reprise surtout identifiée par variante.
- `ui/selection/cards_character_setup.gd` : cinq étapes et récapitulatif.
- `ui/selection/consumable_departure_catalog.gd` : quatre classes et définitions du départ.
- `ui/expedition/consumable_player_dossier.gd::_progression` : statistiques actuelles
  et bonus d'équipement ; absence de ventilation par source dans cette présentation.
- Même fichier : comparaison « Remplace » descriptive, attributs appliqués
  immédiatement, filtres d'équipement limités ; favoris de cartes déjà présents.
- `ui/run/persistent_run_ui.gd::_show_expedition_inspection` : fenêtre reconstruite
  à l'ouverture ; état de consultation à préserver au niveau du propriétaire UI.
- `ui/recraft_hud_v1/combat/combat_hud_recraft_v1.gd` : raccourcis existants et
  intitulés dont « Compétences », à harmoniser avec la progression réellement ouverte.
- `ui/expedition/catabase_card_hand.gd` : consultation des piles via `AcceptDialog`.
- `ui/expedition/expedition_route_view.gd` et `expedition_route_overview.gd` :
  carte détaillée, légende, inspection, validation séparée et retour du focus.
- `ui/menus/dark_pause_menu.gd` : animations réduites, sorties protégées et
  compendium indisponible ; `title_music_controls.gd` : réglage musical au titre.

## Agencement proposé

### Avant la run

Conserver le personnage à droite et une décision principale à gauche. Toujours
afficher apparence, classe, difficulté, statistiques et état du deck. La fiche de
classe répond à quatre questions : comment je joue, ce qui déclenche mon bonus,
ce qui me met en difficulté, ce que je pourrai choisir au niveau 4.

L'exemple de tour doit utiliser le vrai coût des cartes et le vrai passif, sur une
situation décrite. Il ne doit pas devenir une promesse de dégâts garantis. Au départ,
le joueur contrôle sa composition et peut modifier une famille sans refaire le parcours.
Ne pas ajouter une sélection de serveur, de compte ou une liste de héros sauvegardés
tant que notre modèle de run n'en a pas besoin.

### Entre les combats

Conserver l'ordre Bilan → Notification de niveau → Décisions → Route. Le bilan
montre ce qui a été gagné, pas un choix exclusif entre tous les objets. Dans la
fiche du loot, afficher « Rejoint la réserve » ou « Rejoint le sac ». Après le bilan,
un accès « Voir mes nouveaux objets » ouvre la bonne section, sans appliquer
automatiquement un équipement ni consommer une carte.

Dans l'inventaire, garder trois zones stables : personnage équipé, grille des
objets, fiche de comparaison. La fiche donne les effets de l'objet, son remplacement
et les variations calculées sur le personnage réel. Exemple de présentation :
PV maximum 110 → 117 ; résistance physique 38 % → 40 %, plafond atteint.
Ces nombres illustrent la présentation, pas une nouvelle définition d'objet.
La règle existante de conservation des PV lors d'un équipement doit être préservée.

Les caractéristiques détaillent chaque source au clic. Les effets conditionnels
restent dans une section séparée avec leur déclencheur. Un bonus de dégâts contre
une cible marquée ne doit jamais gonfler artificiellement la puissance permanente.

### Cohérence visuelle et navigation

Employer partout les mêmes noms : Personnage, Équipement, Cartes, Progression,
Carte de la run. Afficher les raccourcis existants dans une aide avant d'en ajouter.
Le menu actif, la sélection, le focus clavier et l'indisponibilité doivent être
distinguables sans dépendre uniquement d'une couleur. Garder l'ivoire pour les
valeurs, le cuivre pour les actions/choix, les couleurs de classe en accent.

Prévoir le réglage de taille de texte avec de vrais essais de débordement et de
défilement. La personnalisation totale de placement des fenêtres n'est pas une
priorité : un agencement par défaut solide et réinitialisable doit précéder cela.
Éviter les shaders décoratifs derrière les petits textes et les effets permanents
qui attirent davantage le regard que les décisions.

## Mise en œuvre technique proposée

1. **Comparaison et traçabilité des gains.** Vue de comparaison pure fondée sur
   `consumable_card_math.gd`, état « non consulté » séparé du reçu immuable,
   navigation par identifiant d'objet/famille. Vérifier vente, équipement, reload
   et verrouillage en combat. Ne pas modifier le reçu pour y stocker l'état UI.
2. **Navigation et compréhension.** Intitulés communs, conservation de l'inspection,
   glossaire issu des définitions de règles, visualisation des piles avec ordre
   masqué. Un seul composant de fiche de carte, avec contexte départ/run/combat.
3. **Préparation et reprise.** Aperçu de sauvegarde en lecture seule, exemple de
   tour, remise au deck conseillé. L'ouverture préparée exige un contrat de
   données jusqu'à l'initialisation du combat : un bouton seul serait trompeur.
4. **Réglages.** Texte, délai d'infobulle, animations et volumes regroupés ; appliquer
   les changements immédiatement, avec remise par défaut et persistance contrôlée.

Pas de nouveaux attributs décoratifs, de boutons vides, ni de catalogue d'états
inventés pour remplir les fenêtres. Le glossaire et les prévisualisations doivent
suivre les mêmes définitions que le combat. Toute nouvelle mécanique passe ensuite
par son propre audit d'équilibrage.

## Corrections réalisées dans ce tour

- Statistiques de niveau 1 calculées depuis les règles courantes, visibles dans le
  résumé permanent et au départ ; définition de P avec exemple numérique.
- Distinction entre cartes communes et cartes de classe dans la fiche initiale.
- Quantités regroupées par famille, distribution des coûts en PA et retour direct
  à la famille pour modifier ses copies depuis le récapitulatif.
- Surfaces et boutons de sélection harmonisés avec le dossier marron ; accent de
  classe éclairci pour les textes et filtrage des icônes de boutons.
- Scénario de sélection corrigé : il utilisait encore l'ancien choix de cinq
  techniques. Il vérifie désormais les quinze copies V2, la catégorie commune,
  l'édition depuis le résumé et la transmission réelle de la préparation.

Fichiers : `ui/selection/cards_character_setup.gd`, nouveau
`ui/selection/departure_readability.gd`,
`tools/character_selection/selection_cards_review.gd`, `docs/current/product.md`.
Aucune règle de combat, table de drop ou sauvegarde n'a été modifiée.

## Validation et limites

- Suite `./dev.ps1 test selection` sur l'hôte : **50 tests, 1 138 assertions,
  aucun échec**, rapport `artifacts/dev/20260927-230149-test-selection-04f1e596/gut-strict-report.json`.
- La première exécution sandbox s'était arrêtée à l'import sur des accès système
  Godot, avant tout test : elle ne constitue pas une validation.
- Captures natives avant/après : trois formats (1280×720, 1920×1080, 1200×896),
  trois apparences, quatre classes, édition de deck, difficulté, départ et Classique.
  Rapport intermédiaire après : `artifacts/dev/20260927-225449-selection-audit-after-aa0795db/report.json`.
  Trente-trois captures et interactions par pointeur ; inspection visuelle des
  apparences, classe, deck et récapitulatif.
- Campagne finale après correction du contraste et du filtrage : **339 contrôles
  réussis, 33 captures, sortie moteur 0, aucune erreur moteur détectée**.
  Rapport : `artifacts/dev/20260927-230825-selection-audit-final-13c229b1/report.json`.
  Inspection visuelle finale : classe Assassin et récapitulatif en 1280×720,
  deck en 1200×896. Le récapitulatif garde un défilement pour ses familles ;
  le bouton de départ reste fixe et accessible.
- Vérification de format du nouveau présentateur et du scénario, et `git diff
  --check` sur les fichiers de ce travail : réussies. Les changements VFX présents
  simultanément dans le dépôt appartiennent à un autre travail et sont préservés.

À valider pour les prochains lots : gagner une carte puis la retrouver en réserve ;
comparer/équiper sans gain abusif de PV ; reprendre une run après une décision ;
fermer/réouvrir en conservant la consultation ; parcourir au clavier ; utiliser
les textes agrandis sans perdre les boutons. Les tests de sélection ne démontrent
ni l'équilibrage complet d'une run, ni un test utilisateur de compréhension.
