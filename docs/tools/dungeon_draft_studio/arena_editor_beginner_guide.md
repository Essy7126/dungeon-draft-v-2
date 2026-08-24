# Studio Terrain — guide débutant

Statut : **WORKTREE_CANDIDATE**.
Contrat détaillé : `terrain_studio_refonte_contract.md`.

Ce guide décrit le parcours après la refonte du 24/08/2026. Il ne demande
aucune connaissance de Godot, aucun fichier `.tres` et aucun terme technique.

## 1. Ouvrir l'onglet TERRAINS

L'onglet s'ouvre sur l'**accueil**. Quatre entrées :

- **Modifier le terrain de la salle active** — reprend la salle sélectionnée
  dans la partie en cours ;
- **Créer un nouveau terrain** ;
- **Ouvrir un terrain existant** ;
- **Faire l'exercice d'entraînement** — un terrain d'essai complet dans votre
  dossier personnel ; aucune partie officielle n'est touchée.

Le bouton **Que veulent dire ces mots ?** ouvre le glossaire : salle, terrain,
décor, point de départ, surface temporaire, brouillon, tester, intégrer.

## 2. Créer un terrain

Trois façons, présentées comme trois cartes :

1. **Depuis une illustration** — vous importez une image peinte, puis vous
   posez la grille dessus en trois clics ;
2. **Avec des tuiles** — le Studio dessine le sol ; c'est le plus simple pour
   un premier terrain ;
3. **Illustration avec tuiles spéciales** — le décor reste au fond, seules les
   cases spéciales (eau, glace, lave…) sont dessinées par-dessus.

On vous demande ensuite seulement le **nom visible**, la **taille en cases**,
**de quel côté arrivent les héros**, et l'illustration si votre choix en
demande une. Le bouton final s'adapte : *Créer et peindre* ou
*Créer et aligner l'illustration*.

## 3. Suivre le parcours

La colonne de gauche affiche les sept étapes, chacune avec son état
(`○ à faire`, `◐ en cours`, `✓ terminé`, `! erreur`) :

1. **Départ** — choisir ou créer le terrain ;
2. **Forme** — quelles cases composent la zone jouable ;
3. **Sols** — peindre le type de sol de chaque case ;
4. **Obstacles et départs** — murs, points de départ, objectifs ;
5. **Décor** — illustration et premier plan ;
6. **Vérifier** — corriger ce qui empêcherait la salle de fonctionner ;
7. **Tester et intégrer** — lancer un vrai combat, puis publier.

Vous pouvez cliquer directement n'importe quelle étape : rien n'est verrouillé.
Le bandeau au-dessus de la carte rappelle la consigne de l'étape ouverte et se
met à jour tout seul quand l'action est faite. **Masquer** l'efface ; le rail
continue d'indiquer la suite.

Raccourcis clavier des outils : `1` Sélection, `2` Déplacer la vue,
`3` Ajouter des cases, `4` Retirer des cases, `5` Bordure,
`6` Murs et obstacles, `7` Sols, `8` Points de départ, `9` Vérification.
`0` et `A` (grille et ancres) n'existent qu'en mode avancé.

## 4. Peindre les sols

La palette montre chaque sol avec son image et son nom. Un pictogramme `⚠`
signale un sol qui applique un effet ; l'infobulle décrit ce qu'il fait.

La palette sépare deux familles :

- les **sols permanents**, enregistrés dans le terrain ;
- les **surfaces temporaires**, créées pendant le combat par un sort. Elles ne
  se peignent pas ici.

## 5. Corriger les problèmes

**Vérifier** remplit le tiroir du bas avec une carte par problème : ce qui ne va
pas, pourquoi c'est important, l'emplacement, puis **Me montrer**,
**Sélectionner la case** et, quand la correction est sûre et annulable,
**Corriger automatiquement**. Toute correction automatique s'annule avec
`Ctrl + Z`.

L'état affiché passe de `Terrain incomplet` à `Prêt à tester`, puis
`Prêt à intégrer`.

## 6. Brouillon, test, intégration

Trois actions distinctes, expliquées en permanence dans l'étape 7 :

- **Enregistrer le brouillon** garde votre travail dans votre dossier
  personnel. La partie n'est pas modifiée.
- **Tester** lance un vrai combat sur la version en cours. Rien n'est publié.
- **Intégrer à la partie** publie le terrain dans une salle. Un résumé
  (partie, salle, action, données conservées, données remplacées,
  avertissements, fichiers) s'affiche avant toute écriture.

`Mettre à jour l'arène` est l'action recommandée : la rencontre, les vagues et
les récompenses de la salle sont conservées. `Remplacer toute la salle` est un
choix avancé qui demande une confirmation supplémentaire.

Vous pouvez abandonner à tout moment : tant que vous n'avez pas intégré, la
salle officielle n'est pas modifiée.

## 7. Mode avancé

L'interrupteur **Mode guidé** de l'en-tête donne accès, une fois désactivé, à la
calibration numérique, aux ancres multipoints, aux calques et opacités, aux
chemins et identifiants, aux manifestes artistiques, aux dossiers de production,
au remplacement complet d'une salle, au laboratoire autonome et aux simulations
techniques de surfaces. Aucune de ces fonctions n'a été supprimée ; elles sont
seulement rangées.

Passer de guidé à avancé et revenir ne perd ni la version en cours, ni la
sélection, ni le zoom, ni l'historique.
