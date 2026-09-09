# Parcours guidé de Catabase

L’écran d’expédition présente une décision à la fois. La carte parchemin dispose de sa propre page, sur toute la largeur de la fenêtre, avec les ressources utiles, la destination sélectionnée et une confirmation fixe en bas.

## Ordre du parcours

1. **Caractéristiques** : distribuer les points disponibles ; l’effet exact avant/après inclut l’équipement. Le dernier changement reste affiché jusqu’à « Continuer ».
2. **Choix de l’étape** : choix exclusif à la profondeur XII si nécessaire, puis carte récompense à sélectionner et confirmer. Les haltes conservent leurs services multiples.
3. **Préparation** : consulter inventaire, compétences et caractéristiques. Les points de destin peuvent être conservés. Les objets gagnés restent à équiper depuis l’inventaire.
4. **Chemin** : consulter les destinations visibles sur le parchemin, puis confirmer l’engagement. La sélection seule ne lance jamais un combat.

Les étapes obligatoires sont dérivées de la session sauvegardée par `core/expedition/expedition_flow.gd`. Aucun nouveau schéma de sauvegarde. La consultation en combat reste en lecture seule. Les pages auxiliaires ramènent à la page d’origine ; Échap suit la même règle que la fermeture placée en haut à droite.

## Trois interfaces de gestion

- **Inventaire** ouvre directement le sac et l’équipement. Le panneau de détail explique l’objet sélectionné et son remplacement. Les objets sans illustration reçoivent un pictogramme de catégorie ; les emplacements libres restent visuellement vides.
- **Compétences** commence par les actions actuellement équipées : coût, portée et effet. Un second onglet permet d’apprendre avec les points de destin. Le changement d’emplacement reste séparé de l’apprentissage.
- **Caractéristiques** est accessible même sans point à dépenser, depuis le bandeau ou le bouton dédié du HUD (P). Les quatre choix restent visibles en 720p. Les détails supplémentaires et exemples de techniques améliorées restent accessibles en infobulles.

La fermeture d’une consultation de combat restitue les commandes du combat. L’ouverture depuis une récompense ou la carte conserve la décision et le défilement utiles.

## Récompenses et mouvement

Les cartes réutilisent les illustrations existantes et la présentation des objets. Les textes d’effet et de destination proviennent des données courantes. Une sélection visible précède toujours la confirmation : consulter ou changer de carte ne réclame rien. Une technique déjà apprise annonce sa compensation réelle de 40 oboles.

Survol, léger soulèvement, lumière de sélection et retour visuel sur les valeurs modifiées mettent en évidence les actions. L’option de mouvements réduits s’applique immédiatement aux cartes et aux caractéristiques déjà ouvertes.

## Vérification du 8 septembre 2026

Moteur : Godot 4.7.1. Les victoires des fixtures sont simulées ; les sauvegardes de test sont isolées de celle du joueur.

- `test/unit/test_expedition_guided_flow.gd` : **15 tests, 394 assertions**. Ordre des décisions, sauvegarde/reprise, consultation, retours, aperçus exacts, cartes, mouvement réduit et compensation de technique connue.
- `test/unit/test_run_interface_access.gd` : **4 tests, 83 assertions**. Modal et commandes de combat, inventaire à petite résolution, quatre raccourcis sans chevauchement et pictogrammes de secours.
- Suites existantes `test_persistent_run_combat_hud.gd` et `test_inventory_equipment_system.gd` également réussies.
- `tests/expedition/GuidedFlowProbe.tscn` : parcours des écrans réels, captures GPU avec animations, actions fixes dans le viewport, quatre choix de caractéristiques immédiatement visibles, conservation du défilement, carte profonde et consultation de combat.
- Captures : `artifacts/run_interface_v2/`, aux résolutions 960×720, 1280×720 et 1920×1080.

Commandes (remplacer `godot` par le chemin du moteur local) :

```text
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir= -gtest=res://test/unit/test_expedition_guided_flow.gd,res://test/unit/test_run_interface_access.gd -gexit -gdisable_colors
godot --path . --rendering-method gl_compatibility res://tests/expedition/GuidedFlowProbe.tscn -- resolution=960x720 motion=true
```
