# Studio des personnages et compétences

Le Studio permet de modifier les trois personnages jouables, leurs caractéristiques,
leurs disciplines, leurs rangs, leurs améliorations et les effets appliqués aux sorts.
Il utilise directement les mêmes Resources que le jeu.

## Ouvrir le Studio

Dans Godot, utilisez l’une de ces deux entrées :

- **Projet > Outils > Dungeon Draft : ouvrir le Studio des compétences** ;
- le bouton **Compétences** de la barre du Dungeon Draft Studio.

Le Studio s’ouvre dans une fenêtre séparée. Il n’est créé qu’à la demande et il est
libéré à sa fermeture. L’éditeur de cartes et l’éditeur de rencontres continuent donc
de fonctionner comme avant et ne supportent aucun coût permanent supplémentaire.

## Comprendre les mots employés

- **Personnage** : le héros et ses valeurs de base, par exemple ses PV ou ses PA.
- **Sort de base** : la capacité disponible avant toute amélioration.
- **Discipline** : le chemin de progression associé à un sort de base.
- **Rang** : une étape atteinte lorsque le personnage possède assez d’XP cumulée.
- **Amélioration** : un choix proposé au joueur à un rang donné.
- **Prérequis** : une amélioration qui doit déjà avoir été acquise. Si un choix possède
  plusieurs prérequis, ils sont tous obligatoires.
- **Exclusion** : deux améliorations qui ne peuvent pas être acquises ensemble.
- **Effet** : la transformation concrète appliquée au sort, par exemple davantage de
  dégâts, une portée différente ou un nouvel état.

## Quand une modification affecte-t-elle le jeu ?

Les champs modifiés dans le Studio agissent d’abord sur une copie de travail isolée.
Une partie en cours n’est jamais changée pendant la saisie ni pendant la simulation.

Lorsque vous cliquez sur **Sauvegarder**, le Studio valide puis écrit les vraies
Resources du projet. Les nouvelles valeurs seront utilisées au prochain chargement du
personnage, donc normalement lors de la prochaine run. Une unité déjà instanciée dans
une partie conserve les valeurs avec lesquelles elle a été créée.

## Parcours recommandé

1. Choisissez un personnage dans le catalogue de gauche.
2. Vérifiez ses caractéristiques de base dans l’inspecteur de droite.
3. Sélectionnez une discipline.
4. Vérifiez son sort de base et ses seuils d’XP.
5. Ajoutez ou sélectionnez une amélioration dans le graphe.
6. Reliez ses prérequis depuis un rang inférieur.
7. Décrivez ses effets dans l’onglet **Effets**.
8. Cliquez sur **Valider**, puis corrigez les messages expliqués en bas.
9. Ouvrez **Tester** pour simuler l’XP et les choix sans toucher à une run.
10. Cliquez sur **Sauvegarder** lorsque le résultat est prêt.

Le bouton **Visite guidée** reprend ces notions directement dans l’interface. Le
**Mode guidé** masque les réglages techniques secondaires et conserve des descriptions
et exemples à côté des champs importants.

## Manipulations courantes

### Changer l’XP d’un rang

Cliquez sur le badge `R2`, `R3`, etc. au-dessus du graphe, puis modifiez **Seuil total
d’XP** à droite. La valeur est cumulative : si le rang 2 demande 5 XP et le rang 3 en
demande 12, le passage entre les deux demande 7 XP supplémentaires. Le bouton
**Répartir l’XP** régularise la courbe ; **Preset 0/5/12/21/30** restaure les seuils du
contrat actuel pour une discipline de cinq rangs.

### Ajouter une amélioration ou une branche

Utilisez **+ Amélioration** ou le clic droit dans la colonne du rang souhaité. Donnez un
nom compris par le joueur ; l’identifiant stable est généré séparément et ne changera
pas lorsque le nom sera corrigé.

Pour créer un enfant, tirez le connecteur droit d’un nœud vers le vide : le nouveau
nœud recevra automatiquement le parent comme prérequis. **Créer une branche complète**
ajoute une étape dans chaque rang restant et relie toute la suite en une action
annulable. Une branche peut rester linéaire, se scinder avec plusieurs enfants ou
fusionner lorsqu’un nœud reçoit plusieurs prérequis.

### Comprendre les prérequis et exclusions

Une liaison bleue représente un prérequis. Plusieurs liaisons entrantes signifient
**ET** : tous les parents doivent avoir été acquis. Un nœud de rang 2 est relié
implicitement au sort de base.

Dans l’onglet **Relations** d’une amélioration, cochez les choix incompatibles. Le
Studio inscrit automatiquement l’exclusion dans les deux sens. Une exclusion ne
remplace jamais un prérequis : elle interdit seulement une combinaison.

### Associer et régler un sort

Sélectionnez la discipline puis **Modifier le sort de base**. Les champs essentiels
sont classés entre **Sort**, **Effets** et **Apparence**. Le mode Avancé expose aussi la
zone, le terrain, les statuts, les déplacements forcés, la résolution différée et
l’invocation. Une nouvelle discipline reçoit automatiquement un sort de base minimal.

### Créer un effet

Sélectionnez une amélioration et ouvrez l’onglet **Effets**. **+ Ajouter un effet** crée
un `SpellModSkillTreeEffect` générique. Choisissez son type, sa cible et sa quantité ;
les champs pertinents, comme la durée d’un statut, apparaissent en mode guidé. La phrase
affichée au-dessus résume le résultat. Plusieurs effets peuvent être réordonnés,
dupliqués, partagés ou rendus uniques.

### Tester un chemin et corriger les erreurs

Le bouton **Tester** ouvre le simulateur. Réglez l’XP, puis cliquez uniquement sur les
choix marqués **DISPONIBLE**. L’infobulle d’un choix verrouillé explique son motif.
**Essayer un chemin valide** charge un exemple et **Tester automatiquement tous les
chemins** rejoue les configurations avec les règles runtime.

Dans l’onglet inférieur **Erreurs et avertissements**, double-cliquez sur un diagnostic
pour sélectionner son rang ou son nœud. Une erreur rouge bloque la sauvegarde ; un
avertissement orange attire l’attention sans interdire un choix volontaire.

## Sécurité de la sauvegarde

La sauvegarde est refusée tant qu’une erreur structurelle existe. Les avertissements
restent autorisés lorsqu’ils décrivent un choix potentiellement volontaire.

Avant d’écrire, le Studio vérifie aussi que les fichiers n’ont pas été modifiés ailleurs.
Il construit un point de récupération et sauvegarde les sous-ressources dans l’ordre de
leurs dépendances. En cas d’échec, les fichiers déjà écrits sont restaurés.

Les identifiants sont des références stables utilisées par le jeu et les sauvegardes de
runs. Leur renommage demande donc une confirmation et met à jour les références connues
en une seule action. Une ancienne sauvegarde de run peut néanmoins conserver l’ancien
identifiant.

### Restaurer une récupération

Chaque sauvegarde crée un dossier sous
`user://dungeon_draft_studio/skill_tree/recovery/save_<date>/`. Son `manifest.json`
indique le personnage, les fichiers écrits et les copies `.bak`. La Resource
`working_character.tres` conserve aussi la copie de travail complète.

En cas d’échec pendant l’écriture, le Studio restaure automatiquement les fichiers
précédents. Pour une restauration manuelle ultérieure, fermez Godot, consultez le
manifeste du point choisi, puis replacez chaque `.bak` à l’emplacement `source` indiqué.
Conservez d’abord une copie des fichiers actuels. Cette opération manuelle n’est utile
que si vous souhaitez revenir volontairement à une ancienne sauvegarde réussie.

## Profil « Contrat actuel »

Ce contrôle facultatif vérifie la structure de production actuelle : cinq rangs,
seuils `0 / 5 / 12 / 21 / 30`, répartition `0 / 2 / 4 / 8 / 4` et seize chemins finaux.
Il sert à maintenir les douze arbres existants. Il peut être désactivé pour concevoir
une discipline avec une autre structure, sans désactiver les validations indispensables
au fonctionnement du jeu.
