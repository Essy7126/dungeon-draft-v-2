# Atlas dynamique des maîtrises

L’explorateur d’Achille remplace ses rangées de cartes par un graphe de progression navigable. Les autres personnages conservent leur système de branches et reçoivent le même habillage cendré, une navigation clavier améliorée et un recentrage animé.

## Parcours d’Achille

Le bandeau affiche le niveau du champion, ses statistiques actuelles, ses points disponibles et la progression d’XP vers le niveau suivant. Les quatre techniques utilisent les mêmes icônes que le HUD et présentent leurs valeurs calculées. Les sorts d’Achille ne gagnent pas d’XP individuelle.

À gauche, les trois doctrines montrent leur emblème, le coût déjà investi et le nombre de maîtrises accessibles selon l’évaluateur réel. Les sections Destin héroïque et Caractéristiques restent disponibles. Le retour dans une doctrine retrouve la maîtrise précédemment inspectée et la replace dans le cadre.

Au centre, l’arbre permet de glisser, zoomer à la molette ou au pavé tactile, utiliser les boutons de zoom et recentrer la vue. La recherche porte sur les maîtrises ; les éléments non correspondants restent en contexte mais sortent de la navigation active. Un résultat unique est centré automatiquement. Le bouton Accessibles parcourt les choix légalement achetables avec les points et prérequis actuels. Le recentrage conserve au minimum une échelle de 78 % : en 720p, les derniers paliers se rejoignent par déplacement. La molette permet une vue d’ensemble plus petite, jusqu’à 50 %, ou un agrandissement jusqu’à 175 %.

À droite, une fiche séparée montre la description, les conditions remplies/manquantes, le coût et les effets calculés avant/après. Les prérequis de nœud disposent d’un bouton pour les afficher dans l’arbre, y compris dans une autre doctrine. Les textes longs défilent et une nouvelle inspection revient en haut de la fiche.

## Fidélité aux règles

Les liens du graphe sont construits depuis `prerequisite_node_ids` et `requires_any_node_ids`. Les liaisons alternatives sont marquées OU. Les sommets, apothéoses et jonctions affichent leurs conditions propres ; leur disposition ne transforme pas un seuil de points en prérequis de nœud fictif.

Les états acquis, disponible, verrouillé et exclu sont distincts. Les achats sont toujours effectués par `CharacterRunState.purchase_mastery_node`, et les caractéristiques par `spend_champion_attribute`. Le codex consultatif reste sans mutation, même si l’état temporaire possède des points. Il n’ajoute ni points de démonstration au joueur ni nouvelle règle de progression.

L’acquisition confirme le nom de la maîtrise acquise, réactualise les valeurs et produit une impulsion sur le nœud. Les liens acquis peuvent porter un mouvement lumineux discret. Le mode de mouvements réduits supprime les impulsions et rend le cadrage immédiat. Le graphe conserve son zoom après un achat.

## Fabrication visuelle

- Deux images originales générées avec l’outil intégré `image_gen` : fond d’atlas cendré et triptyque des trois doctrines.
- Trois `AtlasTexture` pour les emblèmes ; mipmaps et filtrage linéaire pour leur réduction et le zoom du graphe.
- Matière noir/brun et shader réutilisés depuis la sélection ; cadres, textes et interactions restent natifs à Godot.
- Icônes sémantiques du catalogue existant pour les maîtrises et icônes HUD pour les techniques.

[Sources artistiques et prompts exacts](../../art/source/mastery_atlas/art_direction_v1.md).

## Fichiers principaux

- `ui/progression/champion/champion_codex.gd` : atlas, navigation, inspection, actions et projections.
- `ui/progression/champion/champion_mastery_graph.gd` : graphe, liens, cadrage, focus et effets.
- `ui/progression/theme/spell_codex_style.gd` : habillage partagé et décor hors calcul des Containers.
- `ui/progression/screens/skill_tree_screen.gd` : hôte et ergonomie du codex classique.
- `tools/champion_progression/review_dynamic_mastery.gd` : revue native avec états de champion isolés, sans sauvegarde ni lancement d’aventure.
- `tools/spell_codex/review_classic_ashen.gd` : revue native du trio classique, en consultation et progression isolée.

## Reproduire la revue

```powershell
& "C:\Godot\4.7.1\Godot_v4.7.1-stable_win64_console.exe" --path . --rendering-method gl_compatibility --resolution 1280x720 --script res://tools/champion_progression/review_dynamic_mastery.gd
```

Le runner utilise des événements souris pour ouvrir les nœuds, zoomer, déplacer le graphe, utiliser les outils et acquérir une maîtrise sur un héros temporaire. Il inspecte aussi la consultation des techniques et caractéristiques, le mode sans achat, le cadrage conservé et les captures en 720p/1080p.

Les journaux et captures de cette passe sont conservés dans `artifacts/dynamic_mastery/`. Les scénarios de validation utilisent des héros temporaires issus du profil de roster de Catabase : ils n’écrivent pas dans la run active, les ressources de progression ou la sauvegarde du joueur.


## Validation de cette passe

- Codex d’Achille : 21 tests réussis, 364 assertions (codex, graphe et intégration dynamique). Après la correction finale du retour à la ligne : 9/9 tests du graphe réussis, 188 assertions, dont le nom sur deux lignes visibles sans recouvrir le statut. Cela représente 22 tests distincts pour le codex et son graphe.
- Revue native d’Achille : 14 captures, 160 contrôles réussis ; rapport `artifacts/dynamic_mastery/review.json`, journal d’erreur vide.
- Explorateur classique : 25 tests réussis, 366 assertions (`test_classic_codex_ashen`, `test_spell_codex_navigation`, `test_spell_codex_detail`, `test_skill_tree_screen_complete_ui`).
- Revue native classique : 6 captures, 66 contrôles réussis ; rapport `artifacts/mastery_atlas/classic_review.json`, journal d’erreur vide. Trois personnages, consultation, progression isolée et cadrages 720p/900p/1080p.
- Intégration depuis la sélection : 8 tests passent et 6 échouent sur 14. La ressource Catabase ne se charge pas pendant cette passe, à cause de portraits Paris manquants dans des modifications parallèles (`assets/characters/paris/sprites_v1/paris_portrait.tres` et `assets/characters/paris/sprites_v1/paris_infernal_portrait.tres`). Le roster de secours a quatre entrées au lieu de cinq. Dans le test du matériau, le clic atteint bien l’index 2 et tous les états de surface sont corrects ; cet index contient Guerrier au lieu de Mage après omission de Catabase. Le journal est `artifacts/dynamic_mastery/selection_host_tests.log`. Aucun asset Paris n’est modifié par cette refonte.

La validation native d’Achille charge le profil de roster officiel dans un état temporaire, sans dépendre des salles en cours de modification. Elle vérifie l’absence de mutation du profil, de la progression consultée, de l’état du gestionnaire et de la sauvegarde préexistante. Cette passe ne prétend pas remplacer une validation complète de Catabase tant que ses ressources parallèles ne sont pas disponibles.


## Correctif de sélection de Catabase — 6 septembre 2026

Le blocage décrit dans la passe initiale est corrigé. Les portraits de Paris sont maintenant référencés par `preview_sprite_frames_path`, chargé uniquement si la ressource existe. `UnitData` et `CombatFormChangeData` conservent la priorité des `SpriteFrames` directement assignés et l’API déjà utilisée par les aperçus. L’absence d’une illustration ne fait plus échouer le chargement de Paris, de sa salle puis de la run entière. Les sorts, la transformation, les scènes et les salles restent en place.

La sélection retrouve cinq entrées : Achille (Catabase), Elfe, Mage, Guerrier, Achille (Épreuve du dialecticien). Les deux aventures d’Achille restent distinctes.

- `test_optional_preview_frames.gd` : 4 tests, 29 assertions ; ressource absente, ressource disponible, priorité d’un portrait explicite et transformation réelle de Paris.
- `test_catabase_selection_launch.gd`, `test_selection_quality_v2.gd`, `test_selection_ashen_skin.gd` : 16 tests, 1 363 assertions ; les six échecs initiaux de la sélection sont résolus. Catabase est chargée avec toutes ses vraies salles.
- Journaux : `artifacts/achilles_selection_repair/optional_portraits_tests.log` et `artifacts/catabase_selection_launch/tests.log`.
- Revue native : `tools/character_selection/review_catabase_launch.gd`, avec la sélection, l’introduction de Catabase, la transition vers la première salle et son déploiement réel. Elle s’exécute dans un processus de validation séparé et vérifie l’empreinte de la sauvegarde préexistante.

Résultat de la revue native du correctif : **5 captures et 43 contrôles réussis**, jusqu’à la phase de déploiement de la première bataille. Aucune erreur de chargement ou de script ; le journal conserve des avertissements de ressources/RID non libérés à la fermeture du processus de rendu de combat. L’empreinte de la sauvegarde est inchangée.
