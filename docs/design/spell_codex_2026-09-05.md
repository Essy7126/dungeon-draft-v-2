# Sorts & maîtrises — 5 septembre 2026

> **Mise à jour — progression Champion de Catabase.** Pour Achille, la version décrite ci-dessous est désormais historique : les quatre techniques ne gagnent plus d’XP et n’ont plus de rangs par lancement. Le codex actif affiche les caractéristiques, les trois doctrines transversales et les techniques calculées à partir de la Prouesse. Les choix sont investis entre les combats, avec aperçu des effets. La recherche et les arbres par sort restent utilisés par le trio historique. Voir [le contrat chiffré actuel](achilles/champion_catabase_statistics_v0.md).

L’écran existant de progression devient un grimoire à trois zones : catalogue des sorts à gauche, arbre du sort sélectionné au centre, fiche d’inspection à droite. Accessible depuis le HUD de run et depuis **Explorer les maîtrises** dans la sélection de personnage.

## Observation de Dofus

Référence observée directement dans la fenêtre du jeu, capture locale `artifacts/reference_capture/dofus_spells_20260905.png` du 5 septembre à 13:43 UTC. La fenêtre « Sorts » montre des onglets de classe, une recherche, des filtres iconographiques, des paires de variantes, des icônes carrées régulières, des lignes contrastées et un défilement interne. Le panneau sombre sépare efficacement les informations du décor coloré.

Transposition : recherche et catalogue compact ; état actif visible sur toute la ligne ; icône, nom et progression regroupés ; alternatives comparables ; effets détaillés dans une zone stable. Palette propre au projet : vert encre, sauge, crème et accent bronze. Les illustrations proviennent des assets du projet. Aucun asset Dofus n’est intégré.

La fiche détaillée Dofus n’a pas été observée. La seconde capture à 14:06 UTC (`dofus_spells_detail_check.png`) montrait la même liste sous un avertissement d’inactivité. La fiche du projet est donc une proposition fondée sur ses propres données, pas une reproduction d’une infobulle prétendument inspectée.

## Comportement

- La liste affiche les véritables noms des sorts, leur rang, l’XP et les choix en attente. Recherche sur le nom du sort ou de la discipline, sans sensibilité à la casse. Le filtre **Choix prêts** se combine avec la recherche.
- Filtrer ne change ni la progression ni le sort inspecté. Un résultat vide est explicite. Les noms d’évolutions cachées ne sont jamais indexés.
- Le bandeau central identifie le sort et son prochain seuil. Achille conserve ses arbres réels à deux rangs, avec deux alternatives au rang 2. Aucun rang supplémentaire n’est inventé.
- Les cartes montrent des états distincts. Le clic et le focus clavier changent la fiche ; un simple survol ne remplace pas la sélection. Les chemins du sort initial vers les deux alternatives d’Achille sont tracés même sans prérequis explicite dans la ressource ; cela ne modifie pas les règles de déblocage.
- La fiche présente le coût en PA, la portée, la forme de zone, les valeurs de base et les contraintes de lancement réellement définies. L’effet écrit de l’évolution reste séparé des valeurs de base. Exemple : Pointe inexorable décrit son bonus de +4 ; la ligne des dégâts de base de Frappe de lance reste à 9.
- La révélation progressive est conservée. Une évolution masquée efface la fiche précédente et ses métriques. Les titres de branches futures restent génériques.
- Le bouton d’action reste au bas de la fiche pendant son défilement. En consultation, l’inspection ne dépense rien. En mode de choix obligatoire, seul le contrôleur de progression peut confirmer une évolution ; la fermeture reste bloquée jusqu’à résolution.
- Depuis la sélection, un état local est créé à partir du héros résolu et le grimoire s’ouvre sur le sort sélectionné. Le héros animé est suspendu pendant le modal. Fermer restaure l’aperçu et libère l’état local sans créer de run.

## Adaptation à la fenêtre

À 1280 × 720, les quatre sorts d’Achille et les deux alternatives de l’arbre court sont visibles sans défilement du graphe. Les arbres historiques plus longs gardent leur défilement et la commande Recentrer. Les marges et tailles de caractères s’adaptent aux profils compact, moyen et grand.

Le thème commun `PremiumUI` n’est pas modifié : les surfaces du grimoire utilisent des overrides locaux. Les points d’entrée et signaux publics de `SkillTreeScreen` sont conservés.

## Revue reproductible

Lancer avec Godot 4.7.1 :

```powershell
& 'C:\Godot\4.7.1\Godot_v4.7.1-stable_win64_console.exe' --path . --resolution 1440x900 --script res://tools/spell_codex/review_spell_codex.gd
```

Le script utilise des états isolés, simule la souris et le clavier, capture le sort initial, une évolution disponible, un choix acquis, le Mage, les petits formats, l’accès depuis la sélection et le grand format. Il vérifie les limites des panneaux et la visibilité intégrale de l’arbre court en 720p. Rapport dans `artifacts/spell_codex/review.json` et images dans le même dossier ; aucune sauvegarde de progression n’est changée.

Les captures montrant une évolution disponible ou acquise utilisent 3 XP de démonstration dans cet état local. Le jeu conserve ses seuils et règles réels.

Suites ciblées : `test_character_selection_screen.gd`, `test_spell_codex_navigation.gd`, `test_spell_codex_detail.gd`, `test_skill_tree_screen_complete_ui.gd`, `test_in_combat_skill_evolution.gd`. Elles couvrent les quatre héros, la navigation, les métriques, la confidentialité des choix futurs, les dimensions et les choix obligatoires en combat.

Résultat : **39 tests, 708 assertions, tous réussis**. Parcours rendu souris/clavier réussi en 1440 × 900, 1200 × 896, 1280 × 720 et 2560 × 1440. Aucun script ignoré et aucune erreur de parsing dans le journal final. Les avertissements de cartes Mage absentes viennent de l’overlay de choix préexistant ; son mécanisme de secours reste testé.
