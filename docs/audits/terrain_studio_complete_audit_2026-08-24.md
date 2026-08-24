# Audit complet du Studio Terrain

Date : 24 août 2026  
Branche observée : `main`  
Commit observé : `d566b4480e928c16ce6d5dd924d3e4031fca4bb2`  
Périmètre : onglet **ARÈNES**, création et édition du terrain, validation, test, sauvegarde, production et intégration à une partie.  
Statut du document : **AUDIT — aucune refonte implémentée**.

## 1. Verdict exécutif

Le Studio Terrain possède un socle métier nettement plus robuste que son interface ne le laisse comprendre. La working copy, l'historique, le routeur d'entrées, la validation, le test réel, les récupérations et l'intégration transactionnelle constituent de bonnes fondations à conserver.

Le problème principal est l'absence d'un modèle mental visible. L'interface présente simultanément des outils de dessin, des modes d'affichage, des opérations de calibration, des outils de test, des actions de laboratoire, des commandes de production et une destination de salle. Elle ne montre pas clairement le chemin nominal : **choisir ou créer → construire → configurer → vérifier → tester → intégrer**.

Le constat le plus bloquant est concret :

- **PROUVÉ** — l'hôte courant `StudioWorkspace` masque la barre propre à `ArenaStudioMain` dans `addons/dungeon_draft_arena_studio/ui/studio_workspace.gd:18` ;
- **PROUVÉ** — les seules actions **Nouvelle**, **Ouvrir** et le sélecteur **Création / Vérification / Avancé** sont construits dans cette barre masquée, dans `addons/dungeon_draft_arena_studio/ui/arena_studio_main.gd:397` ;
- **PROUVÉ** — aucune autre connexion de l'interface Arena n'appelle `_show_new_dialog()` ou `_show_open_dialog()`.

Dans l'usage normal du plugin, un novice peut donc modifier la salle déjà ouverte, mais il ne dispose pas d'un point d'entrée visible pour créer ou ouvrir librement un terrain. Ce défaut suffit à expliquer une grande partie du sentiment « je ne sais pas utiliser le Studio Terrain ».

### Évaluation synthétique

| Axe | Évaluation | Conclusion |
|---|---:|---|
| Découvrabilité | 1/5 | Les entrées essentielles de création sont masquées dans l'hôte courant. |
| Parcours débutant | 1/5 | La visite explique, mais ne guide pas les actions dans l'interface. |
| Hiérarchie visuelle | 2/5 | Le canvas est central, mais plusieurs autorités visuelles se disputent l'attention. |
| Vocabulaire | 2/5 | Salle, arène, terrain, construction dynamique, laboratoire et production coexistent sans glossaire permanent. |
| Retours et validation | 4/5 | Les statuts, erreurs localisables et plans d'intégration sont substantiels. |
| Sécurité de production | 4/5 | La production/intégration est planifiée et transactionnelle. |
| Sécurité de la sauvegarde simple | 2/5 | Le chemin « Sauvegarder » ne suit pas le même niveau de transaction ni de présentation préalable. |
| Accessibilité clavier | 1/5 | Des raccourcis sont annoncés sans être raccordés et aucun test de parcours clavier Arena n'a été trouvé. |
| Responsive | 2/5 | Le format 1280 est prévu, mais la solution consiste parfois à masquer un panneau essentiel. |
| Cohérence avec Personnage/Objet | 2/5 | Les refontes récentes ont une divulgation progressive que Terrain n'applique pas réellement. |

Ces notes sont une évaluation UX issue des preuves détaillées ci-dessous ; elles ne constituent pas une mesure issue d'un test utilisateur.

## 2. Méthode et limites

### Sources examinées

- **PROUVÉ** — code courant du plugin sous `addons/dungeon_draft_arena_studio/` ;
- **PROUVÉ** — tests courants sous `test/unit/` et runners sous `addons/dungeon_draft_arena_studio/test/` ;
- **RAPPORTÉ** — contrats et guides sous `docs/tools/dungeon_draft_studio/` ;
- **RAPPORTÉ** — décisions et problèmes connus dans `docs/ai/DECISIONS.md`, `CURRENT_STATE.md` et `KNOWN_ISSUES.md` ;
- **PROUVÉ** — comparaison directe du code et des captures existantes des Studios Personnage et Objet.

### Limite graphique

- **PROUVÉ** — deux tentatives de génération des captures courantes avec Godot 4.7 ont planté nativement avant `_ready()` avec le signal 11, en rendu OpenGL puis avec le rendu par défaut.
- **RAPPORTÉ** — `docs/ai/KNOWN_ISSUES.md` mentionne déjà un crash natif du runner de captures avant `_ready()` sur cette famille de tests.
- **PROUVÉ** — la capture Arena récente présente dans `artifacts/arena_studio/screenshots/` provient d'un runner qui instancie `DungeonDraftStudioMain`, alors que le plugin instancie `StudioWorkspace`. Elle affiche donc une barre interne que l'hôte réel masque.
- **À CONFIRMER** — l'apparence pixel-perfect de l'hôte courant doit être revue dans Godot dès que le runner graphique peut être exécuté. Les conclusions qui dépendent uniquement du visuel sont donc formulées comme recommandations et non comme état graphique certifié.

Aucun test n'a été déclaré vert pendant cet audit : le lancement headless ciblé rencontre le même crash natif avant l'exécution de GUT.

## 3. Ce que le Studio sait déjà faire

### Fondations à préserver

- **PROUVÉ** — une `ArenaEditSession` clone l'arène source dans une working copy et calcule l'état modifié par empreinte de contenu dans `domain/arena_edit_session.gd`.
- **PROUVÉ** — l'historique regroupe un geste continu en une action et sait restaurer un instantané.
- **PROUVÉ** — `ArenaInputRouter` impose un consommateur unique aux événements du canvas.
- **PROUVÉ** — le Studio sépare le terrain permanent des surfaces temporaires de sorts dans ses services et sa prévisualisation.
- **PROUVÉ** — les terrains, murs, surfaces et interactifs passent par des registres data-driven.
- **PROUVÉ** — la validation expose des messages sélectionnables qui peuvent recentrer la vue sur le problème.
- **PROUVÉ** — `Tester` prépare une copie temporaire de la working copy et lance la vraie scène sans sauvegarder préalablement la salle officielle.
- **PROUVÉ** — le plan de production annonce créations, modifications et conflits ; l'intégration protège les données de rencontre et recharge la partie pour vérifier l'index final.
- **PROUVÉ** — les transitions de contexte sale proposent sauvegarder, brouillon, abandonner ou annuler.
- **PROUVÉ** — le mode Focus conserve puis restaure la disposition précédente.

Le chantier de refonte ne doit pas reconstruire ces systèmes. Il doit les rendre visibles dans un parcours compréhensible.

### Étendue fonctionnelle actuelle

L'onglet couvre aujourd'hui au moins :

- création depuis une image, une carte vide ou une ancienne calibration ;
- modes visuels peinte, modulaire et hybride ;
- ajout/retrait de cases, bordures, terrains, murs, obstacles, départs, objectifs, décorations et vortex ;
- calibration affine, ancres multipoints, calques, opacité et comparaison à la sauvegarde ;
- validation de déplacement et ligne de vue ;
- simulation de surfaces temporaires et test runtime ;
- points de restauration, récupération automatique et historique ;
- décor, kit artistique, réimport et comparaison ;
- production, résolution de conflits de bundle et intégration à une partie.

**PROUVÉ** — cette richesse est principalement concentrée dans `ArenaStudioMain`, qui compte 5 691 lignes et construit la quasi-totalité de l'interface, des dialogues et de l'orchestration.

## 4. Parcours courant reconstitué

### Ouverture

1. Le plugin crée un contexte partagé et un `StudioWorkspace`.
2. Le contexte restaure une partie/salle précédente ou initialise une sélection.
3. Arena ouvre la salle active ; sans contexte utilisable, il tente la forêt historique.
4. L'utilisateur arrive directement sur un terrain chargé, sans écran d'accueil ni choix explicite entre « créer » et « modifier ».

**PROUVÉ** — `ensure_initial_arena_loaded()` privilégie la salle active puis charge `room_01_forest` en fallback.

### Édition

1. L'utilisateur choisit l'un des onze outils dans une liste plate.
2. Les paramètres de l'outil apparaissent principalement dans le panneau droit.
3. Une palette rapide de huit terrains est aussi placée au-dessus du canvas.
4. « Construction dynamique » constitue encore un mode supplémentaire activé par un bouton ne contenant que le pictogramme `▦`.

### Vérification et finalisation

1. `Valider` remplit le tiroir de validation.
2. `Tester` prépare et lance la scène réelle.
3. La destination d'intégration est néanmoins affichée en permanence, avant même que le terrain soit prêt.
4. `Sauver` et `Intégrer à la partie` sont deux actions distinctes, sans résumé permanent de leur différence.

Ce parcours est techniquement possible, mais son ordre doit être déduit par l'utilisateur.

## 5. Registre des constats

### TERRAIN-01 — Les entrées de création sont masquées dans l'hôte réel

Priorité : **P0 — bloquant pour la refonte**

- **PROUVÉ** — `StudioWorkspace._ready()` appelle `arena_studio.set_shell_toolbar_visible(false)`.
- **PROUVÉ** — cette méthode masque entièrement `top_bar`.
- **PROUVÉ** — `+ Nouvelle`, `Ouvrir`, `Préparer`, `? Visite guidée` et le sélecteur `Création / Vérification / Avancé` appartiennent à cette barre.
- **PROUVÉ** — le shell partagé remplace Sauver/Valider/Tester/Intégrer, mais pas Nouvelle/Ouvrir ni le sélecteur de niveau.

Impact : impossible de découvrir la création d'un terrain depuis l'usage normal ; la documentation décrit un bouton que l'utilisateur ne voit pas.

Recommandation : restaurer immédiatement un point d'entrée permanent **Nouveau terrain** et **Ouvrir**, puis supprimer la double responsabilité entre barre Arena et barre du shell.

### TERRAIN-02 — Le « mode Création » n'est pas un mode guidé

Priorité : **P0 — cause principale de l'incompréhension**

- **PROUVÉ** — `_on_mode_selected(0)` masque seulement le panneau de valeurs avancées, désactive `canvas.show_technical` et efface les overlays.
- **PROUVÉ** — il ne réduit pas la liste des onze outils, ne masque pas la destination, ne change pas le vocabulaire, n'indique pas une prochaine étape et ne réorganise pas le workflow.
- **PROUVÉ** — le sélecteur lui-même est masqué dans `StudioWorkspace`.

Impact : le mode porte une promesse de simplicité qu'il ne tient pas.

Recommandation : remplacer les trois valeurs par un vrai interrupteur **Mode guidé / Mode avancé**, cohérent avec Personnage. En guidé, masquer calibration fine, calques, laboratoire, résolution de bundles et options de production avancées jusqu'au moment utile.

### TERRAIN-03 — La visite est un manuel de 22 pages, pas une assistance contextuelle

Priorité : **P0**

- **PROUVÉ** — `ArenaStudioGuidedTour.PAGES` contient 22 pages textuelles.
- **PROUVÉ** — `start()` ouvre un `AcceptDialog` et `_next()` change seulement de page.
- **PROUVÉ** — les cibles déclarées (`grid`, `tiles`, `validate`, etc.) ne servent pas à focaliser, mettre en évidence ou piloter les contrôles correspondants.
- **PROUVÉ** — aucune étape ne vérifie qu'une action a été réalisée.
- **PROUVÉ** — l'exercice sandbox existe, mais son bouton est enfoui dans l'onglet 5 du dialogue de production.

Impact : charge de lecture élevée, mémorisation obligatoire, absence de transfert immédiat entre explication et action.

Recommandation : conserver un glossaire consultable, mais remplacer la visite nominale par une checklist interactive de 5 à 7 étapes maximum, directement attachée à l'écran et désactivable.

### TERRAIN-04 — Quatre systèmes de modes se superposent

Priorité : **P1 — architecture d'interaction**

- **PROUVÉ** — `mode_option` : Création, Vérification, Avancé.
- **PROUVÉ** — `workspace_preset_option` : Construction, Calibration, Gameplay, Aperçu final.
- **PROUVÉ** — `WorkspaceMode` : Editor, Dynamic construction, Preview.
- **PROUVÉ** — `preview_view` : Logique, Art, Jeu.

Impact : un utilisateur doit comprendre la différence entre un niveau de détail, une disposition, un mode d'édition et une vue. Le code autorise des combinaisons dont le sens visible n'est pas expliqué.

Recommandation : une seule navigation de workflow, un seul interrupteur guidé/avancé et un seul sélecteur d'aperçu. Les presets de disposition deviennent une préférence avancée, pas une étape métier.

### TERRAIN-05 — La destination de salle est présentée trop tôt et occupe l'inspecteur

Priorité : **P1 — hiérarchie visuelle**

- **PROUVÉ** — `_build_right_panel()` place `DESTINATION DE LA SALLE` avant le scroll de l'inspecteur.
- **PROUVÉ** — le panneau calcule et affiche partie, action, salle, portée, chemins, index, fichiers, readiness et conflits à chaque rafraîchissement.
- **PROUVÉ** — il reste visible pendant la construction ordinaire.

Impact : une décision de publication complexe concurrence la tâche immédiate de peinture et réduit la place de l'inspecteur contextuel.

Recommandation : déplacer la destination dans une étape finale **Tester et intégrer**. Pendant la construction, ne montrer qu'un résumé compact de la salle active.

### TERRAIN-06 — Les outils sont une liste technique plate

Priorité : **P1**

- **PROUVÉ** — onze outils sont affichés dans un unique `ItemList` : Sélection, déplacement, ajout/retrait, bordure, murs, terrains, spawns, vérification, transformation et ancres.
- **PROUVÉ** — les paramètres sont répartis entre la liste gauche, une palette au-dessus du canvas et le panneau droit.
- **PROUVÉ** — `Spawn`, `Ancres`, `Calibration`, `Vortex` et `Construction dynamique` restent des concepts à apprendre avant l'action.

Impact : le novice choisit un outil avant de comprendre la tâche qu'il veut accomplir.

Recommandation : organiser par intentions : **Forme**, **Sols**, **Obstacles**, **Points de départ**, **Décor**, **Vérifier**. Les outils précis deviennent une palette contextuelle du groupe choisi.

### TERRAIN-07 — Les raccourcis affichés ne sont pas implémentés

Priorité : **P1 — accessibilité et confiance**

- **PROUVÉ** — `TOOL_HELP` annonce les raccourcis `1` à `0` et `A`.
- **PROUVÉ** — `_refresh_active_tool_contract()` les affiche comme contrat permanent.
- **PROUVÉ** — le canvas ne traite que Espace, Échap et les flèches ; le shell traite Tab, Annuler/Rétablir et le détachement.
- **PROUVÉ** — aucun handler Arena trouvé ne sélectionne les outils avec `1…0` ou `A`.

Impact : l'interface enseigne un comportement faux et empêche un workflow clavier fiable.

Recommandation : implémenter et tester les raccourcis annoncés, ou les retirer jusqu'à leur disponibilité. Ajouter un test de parcours clavier comparable à celui du Studio Personnage.

### TERRAIN-08 — Le vocabulaire nominal reste trop technique

Priorité : **P1 — accessibilité novice**

- **PROUVÉ** — la visite emploie directement PAINTED, MODULAR, HYBRID, background, foreground, occlusion, runtime, bundle et index.
- **PROUVÉ** — l'interface expose notamment Spawns, calibration, axes, RMS, px, manifeste, bundle et Arena.
- **PROUVÉ** — le dialogue de création offre « Type : Peinte / Modulaire / Hybride », avec une aide uniquement sur le mode modulaire.

Impact : le vocabulaire décrit l'implémentation avant l'intention utilisateur.

Recommandation : employer par défaut :

- **Depuis une illustration** — le décor est une image ;
- **Construite avec des tuiles** — le Studio dessine le sol ;
- **Illustration + tuiles spéciales** — combinaison des deux ;
- **Points de départ** au lieu de Spawns ;
- **Premier plan** et **zones masquées** au lieu de foreground/occlusion.

Les termes techniques restent dans **Détails avancés** avec leur correspondance.

### TERRAIN-09 — Le dialogue « Nouvelle arène » suppose déjà la solution

Priorité : **P1**

- **PROUVÉ** — le dialogue présente en même temps nom, identifiant, image, type visuel, dimensions, orientation, template et calibration en trois clics.
- **PROUVÉ** — le mode par défaut est Peinte.
- **PROUVÉ** — le bouton principal dit toujours « Continuer vers la calibration », y compris pour une carte modulaire qui n'a pas besoin du même parcours.

Impact : l'utilisateur doit décider des paramètres structurants avant d'avoir vu ou compris leurs conséquences ; le libellé final n'est pas adapté à tous les choix.

Recommandation : assistant court en trois écrans : objectif visuel, taille/point de départ, résumé. Le bouton final s'adapte : **Créer et peindre** ou **Créer et aligner l'illustration**.

### TERRAIN-10 — « Sauver » et « Intégrer » n'ont pas un contrat utilisateur assez clair

Priorité : **P1 — compréhension et sécurité**

- **PROUVÉ** — le shell expose `Sauver` et `Intégrer à la partie` comme actions voisines.
- **PROUVÉ** — `Sauver` appelle directement `save_arena()` ; `Intégrer` ouvre un plan de production beaucoup plus complet.
- **PROUVÉ** — la différence est expliquée dans la visite, mais pas dans la barre permanente.

Impact : le novice ne sait pas quelle action rend son travail réellement disponible dans le jeu.

Recommandation : renommer selon l'effet : **Enregistrer le brouillon** / **Mettre à jour la salle dans la partie**, avec un statut permanent « Brouillon local » ou « Publié dans Principale · salle 2 ».

### TERRAIN-11 — La sauvegarde simple n'atteint pas le niveau transactionnel de la production

Priorité : **P1 — dette de sécurité**

- **PROUVÉ** — `save_arena()` valide et vérifie un conflit externe avant l'écriture.
- **PROUVÉ** — il crée une récupération, écrit, recharge et compare une empreinte.
- **PROUVÉ** — il ne présente pas de plan préalable des chemins créés/modifiés.
- **PROUVÉ** — `ArenaSerializer._materialize_staged_visual_assets()` copie les assets et modifie les chemins de la working copy avant `ResourceSaver.save()`.
- **PROUVÉ** — si une copie ou la sauvegarde finale échoue après une écriture partielle, ce chemin ne contient pas de rollback de tous les fichiers déjà touchés.

Impact : le bouton le plus simple possède un contrat moins fort que le pipeline final et peut laisser une working copy ou des assets partiellement matérialisés après échec.

Recommandation : faire passer toute sauvegarde persistante par un plan et une transaction partagés avec la production. Le brouillon `user://` peut rester une voie légère et explicitement locale.

### TERRAIN-12 — La projection runtime continue de muter la working copy

Priorité : **P1 — divergence architecturale**

- **PROUVÉ** — `ArenaRuntimeBridge.sync_runtime_resources(arena)` assigne directement `grid_layout`, `painted_map_visual_data`, `arena_visual_profile`, zones de départ, ennemis et scène de combat sur l'objet reçu.
- **PROUVÉ** — `ArenaEditSession.open()`, `_activate_session()` et de nombreux rafraîchissements appellent ce sync sur `working_arena`.
- **RAPPORTÉ** — la décision Studio 2.0 exige une projection runtime séparée qui ne mute pas `ArenaDefinition`.
- **PROUVÉ** — plusieurs méthodes de lecture (`build_grid`, `runtime_signature`, validation) utilisent déjà une copie de projection, ce qui montre que la séparation existe partiellement.

Impact : la working copy mélange encore données d'auteur et dérivés runtime. Cela complique les empreintes, l'Undo et la future séparation UI/métier.

Recommandation : terminer la migration : les champs dérivés restent dans `ArenaRuntimeState` ou une projection, jamais dans le document édité.

### TERRAIN-13 — Le responsive masque l'inspecteur sans voie de retour locale

Priorité : **P1**

- **PROUVÉ** — sous 1 180 px, `_apply_responsive_layout()` appelle `right_panel.hide()`.
- **PROUVÉ** — ce panneau contient les propriétés actives, l'inspecteur, la construction dynamique, les tests directs, la transformation, les calques, les actions et les restaurations.
- **PROUVÉ** — aucun bouton Arena local ne permet d'ouvrir ce panneau en tiroir lorsqu'il est masqué.

Impact : dans une zone centrale Godot étroite, l'interface peut supprimer les contrôles nécessaires à l'outil sélectionné.

Recommandation : transformer l'inspecteur en tiroir superposé ou panneau bascule au format compact. Ne jamais cacher une fonction essentielle sans point d'accès de remplacement.

### TERRAIN-14 — Le dialogue de production ressemble à un assistant sans imposer un parcours

Priorité : **P2**

- **PROUVÉ** — le dialogue utilise six onglets : Identité, Validation, Aperçu, Production, Productions et récupérations, Résultat.
- **PROUVÉ** — le dernier onglet s'appelle « 6 — Résultat », mais son titre interne est « ÉTAPE 5 — RÉSULTAT ».
- **PROUVÉ** — le bouton de confirmation reste dans le footer global et peut être activé dès que les blockers techniques sont absents, indépendamment de l'onglet lu.

Impact : la numérotation et l'apparence promettent un assistant séquentiel, mais le comportement est celui d'un formulaire à onglets.

Recommandation : choisir un seul modèle. Pour le mode guidé : étapes séquentielles avec résumé final obligatoire. Pour le mode avancé : onglets libres sans numérotation trompeuse.

### TERRAIN-15 — Le composant principal est trop monolithique pour une refonte sûre

Priorité : **P2 — maintenabilité**

- **PROUVÉ** — `arena_studio_main.gd` contient 5 691 lignes.
- **PROUVÉ** — il construit l'interface, orchestre les sessions, copie des fichiers, pilote les dialogues, valide, teste, simule les surfaces, produit et intègre.
- **PROUVÉ** — des services métier existent déjà, mais la composition visuelle et les workflows restent fortement couplés dans cette classe.

Impact : chaque changement de disposition risque d'affecter un workflow métier éloigné ; les tests ciblent plus facilement la présence de chaînes que l'expérience réelle.

Recommandation : extraire au minimum `TerrainCatalogPanel`, `TerrainToolRail`, `TerrainInspectorPanel`, `TerrainGuidancePanel`, `TerrainFinalizePanel` et leurs contrôleurs d'orchestration.

### TERRAIN-16 — Les tests UX prouvent surtout la présence, pas l'utilisabilité

Priorité : **P1 — qualité de livraison**

- **PROUVÉ** — le test du contrat débutant vérifie que certaines cibles existent dans les 22 pages et que des chaînes sont présentes dans le source.
- **PROUVÉ** — le test responsive historique vérifie principalement que le bouton Détacher reste dans les limites et que le canvas occupe 75 % en Focus.
- **PROUVÉ** — aucun test Arena trouvé ne vérifie que Nouvelle/Ouvrir sont accessibles dans `StudioWorkspace`.
- **PROUVÉ** — aucun test Arena trouvé ne parcourt toutes les actions principales au clavier.
- **PROUVÉ** — l'ancien runner de captures peut montrer une barre masquée dans l'hôte réel.

Impact : une interface peut satisfaire la suite actuelle tout en restant inutilisable pour un novice.

Recommandation : ajouter des tests de tâches et des assertions sur l'hôte exact du plugin, puis une revue humaine enregistrée.

## 6. Comparaison avec les refontes Personnage et Objet

### Studio Personnage

- **PROUVÉ** — le mode guidé est un état réel, actif par défaut dans plusieurs écrans.
- **PROUVÉ** — il masque l'onglet Avancé et les champs non guidés, tout en affichant des explications contextuelles.
- **PROUVÉ** — l'écran commence par une liste nommée de personnages et une consigne « Choisissez le personnage… ».
- **PROUVÉ** — les onglets correspondent à des intentions compréhensibles : Identité, Combat, Défenses, Sorts, Pilotage, Présentation.
- **PROUVÉ** — des tests vérifient le focus clavier et la mise au point automatique du champ nouvellement créé.

### Studio Objet

- **PROUVÉ** — la structure visuelle distingue catalogue, document actif, onglets de propriétés, aperçu et tiroir d'analyse.
- **PROUVÉ** — les réglages avancés sont isolés dans un onglet dédié.
- **PROUVÉ** — les effets sont présentés comme des cartes résumées avec actions contextuelles.
- **PROUVÉ** — l'assistant de création peut guider une famille d'objet tout en permettant de quitter vers l'accès libre.

### Écart Terrain

Terrain a davantage de manipulation spatiale, donc il ne doit pas copier littéralement un formulaire Objet. En revanche, il doit reprendre leurs invariants réussis :

1. point d'entrée évident ;
2. objet courant clairement nommé ;
3. mode guidé réellement différent ;
4. avancé isolé ;
5. aide placée au moment de l'action ;
6. aperçu et analyse secondaires repliables ;
7. test clavier et captures de l'hôte réel.

## 7. Cible de refonte recommandée

### 7.1 Nom et modèle mental

Nom d'onglet recommandé : **TERRAINS**.  
Sous-titre permanent : **Construire la zone tactique d'une salle**.

Glossaire nominal :

- **Salle** : étape d'une partie, avec rencontre et récompenses ;
- **Terrain** : zone tactique de la salle ;
- **Décor** : illustration et premier plan ;
- **Surface temporaire** : effet produit pendant le combat ;
- **Intégrer** : rendre le terrain disponible dans une salle de la partie.

Le terme interne `ArenaDefinition` peut rester inchangé dans le code.

### 7.2 Écran d'accueil

À l'entrée de l'onglet :

- carte principale **Modifier le terrain de la salle active** ;
- carte **Créer un nouveau terrain** ;
- carte secondaire **Ouvrir un terrain existant** ;
- accès discret **Exercice d'entraînement** ;
- liste des terrains récents.

L'ouverture automatique d'une salle peut rester une préférence, mais ne doit plus supprimer l'accueil au premier usage.

### 7.3 Parcours guidé nominal

Une colonne de progression compacte :

1. **Départ** — choisir l'origine du terrain ;
2. **Forme** — taille et cases jouables ;
3. **Contenu** — sols, obstacles, points de départ et objectifs ;
4. **Décor** — illustration et alignement si nécessaire ;
5. **Vérifier** — erreurs, chemins et ligne de vue ;
6. **Tester** — vraie scène de combat ;
7. **Intégrer** — destination et résumé des changements.

Chaque étape doit fournir : objectif en une phrase, action principale, état terminé, erreurs locales et bouton « Continuer ». L'utilisateur expérimenté peut cliquer directement une autre étape ou désactiver le mode guidé.

### 7.4 Disposition d'édition

- Barre globale : Annuler, Rétablir, Brouillon, Tester, Intégrer.
- Rail gauche : les six intentions du workflow, avec texte et icône.
- Zone centrale : canvas maximal et palette contextuelle immédiatement au-dessus.
- Inspecteur droit : uniquement la sélection ou l'outil actif.
- Tiroir bas : validation, historique, rapport et console, fermé par défaut.
- Destination et fichiers : absents de l'édition courante, présents dans Finaliser.

### 7.5 Divulgation progressive

Masqué en mode guidé :

- origine/axes numériques, RMS et paramètres d'aimantation ;
- gestion manuelle des calques et de leur opacité ;
- chemins, index et empreintes ;
- laboratoire autonome et transfert ;
- actions de bundle ;
- remplacement complet de salle ;
- simulations techniques de surfaces.

Toujours visible :

- nom et état du terrain ;
- outil courant et action souris ;
- Annuler/Rétablir ;
- validation compréhensible ;
- sauvegarde du brouillon ;
- Tester ;
- étape suivante.

### 7.6 Création

Premier choix sous forme de trois cartes illustrées :

1. **Depuis une illustration** — importer un décor puis aligner la grille ;
2. **Avec des tuiles** — choisir taille et thème, terrain immédiatement prêt à peindre ;
3. **Illustration + tuiles spéciales** — avancé, avec explication de l'usage.

Ne demander l'identifiant stable, le chemin et le profil visuel qu'en mode avancé ou au moment de l'intégration.

### 7.7 Validation et erreurs

Transformer les messages en cartes actionnables :

- ce qui manque ;
- pourquoi c'est important ;
- bouton **Me montrer** ;
- bouton **Corriger automatiquement** uniquement lorsqu'une correction déterministe et annulable existe ;
- état « prêt à tester » puis « prêt à intégrer » distinct.

### 7.8 Sauvegarde et publication

Contrat recommandé :

- **Enregistrer le brouillon** : `user://`, sans effet sur les parties ;
- **Tester** : copie temporaire de la working copy ;
- **Intégrer à la partie** : plan transactionnel complet, avec destination ;
- **Exporter/Importer l'art** : sous-menu de Décor ;
- **Outils de récupération** : menu secondaire permanent, non dans le parcours nominal.

La sauvegarde canonique directe doit soit disparaître du parcours nominal, soit adopter exactement le plan et le rollback de la transaction de production.

## 8. Roadmap proposée

### Phase 0 — Corriger les blocages d'accès

1. Rendre Nouvelle et Ouvrir accessibles dans `StudioWorkspace`.
2. Retirer ou raccorder les raccourcis annoncés.
3. Ajouter un bouton d'accès à l'inspecteur lorsque le panneau droit est replié.
4. Faire capturer le vrai `StudioWorkspace` par tous les runners Arena.

Critère de sortie : un utilisateur peut créer une carte modulaire vide depuis l'onglet réel sans connaître un chemin de fichier.

### Phase 1 — Nouvelle architecture visuelle

1. Extraire les panneaux du monolithe.
2. Introduire accueil, rail d'étapes et inspecteur contextuel.
3. Déplacer Destination vers Finaliser.
4. Unifier les quatre systèmes de modes.

### Phase 2 — Parcours guidé et vocabulaire

1. Assistant de création par intentions.
2. Checklist interactive et état de progression.
3. Glossaire partagé Salle/Terrain/Décor/Surface.
4. Mode avancé persistant et réversible.

### Phase 3 — Édition et validation

1. Palettes contextuelles par tâche.
2. Messages de validation actionnables.
3. Prévisualisations Logique/Art/Jeu dans un seul sélecteur.
4. Parcours clavier complet et aides non dépendantes de la couleur.

### Phase 4 — Finalisation et sécurité

1. Clarifier Brouillon/Test/Intégration.
2. Transactionnaliser la sauvegarde persistante.
3. Finir la projection runtime non mutante.
4. Simplifier l'assistant de production et sa numérotation.

### Phase 5 — Vérification humaine

1. Captures réelles à 1280 × 720 et 1920 × 1080 depuis le vrai plugin.
2. Test clavier de toutes les actions principales.
3. Test novice sans documentation externe.
4. Test expert avec mode avancé et conservation des raccourcis.
5. Comparaison aux baselines Personnage et Objet.

## 9. Scénario d'acceptation novice

Une personne ne connaissant ni Godot ni les Resources doit pouvoir, sans guide externe :

1. créer un terrain de 10 × 8 cases avec des tuiles ;
2. peindre deux types de sol ;
3. placer une bordure, trois départs héros et un groupe ennemi ;
4. annuler puis rétablir une action ;
5. comprendre et corriger une erreur de validation ;
6. lancer le combat de test ;
7. intégrer le terrain à une salle d'essai ;
8. expliquer avec ses mots la différence entre brouillon, test et intégration.

Critères proposés :

- aucune ouverture de fichier `.tres` ;
- aucun recours obligatoire à un tooltip pour l'action suivante ;
- aucun terme anglais ou identifiant technique dans le parcours nominal ;
- aucune action primaire masquée à 1280 × 720 ;
- toutes les actions primaires accessibles au clavier ;
- abandon à tout moment sans mutation de la source canonique ;
- intégration impossible sans résumé explicite de la destination et des données conservées.

## 10. Décision recommandée

La refonte doit être engagée, mais elle doit commencer par l'architecture de l'information et non par une simple passe de couleurs ou de composants.

Ordre recommandé :

1. réparer l'accès Nouvelle/Ouvrir ;
2. définir le vocabulaire et le workflow unique ;
3. construire l'accueil et le rail d'étapes ;
4. déplacer les outils existants dans des panneaux contextuels ;
5. seulement ensuite réaliser la direction visuelle ;
6. terminer par la consolidation transactionnelle et la projection runtime.

Verdict : **REFONTE UX ET VISUELLE MAJEURE RECOMMANDÉE, AVEC DEUX CORRECTIONS ARCHITECTURALES DE SÉCURITÉ À INTÉGRER AU CHANTIER**.
