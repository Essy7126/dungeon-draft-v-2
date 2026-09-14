# Intégration AutoSprite Achille — 13 septembre 2026

Objectif : utiliser les 56 planches fournies dans le jeu (apparence classique,
sélection, Seuil des Ombres et combat). Les variantes peintes restent distinctes.

Décisions : PNG originaux conservés sans retouche ; transparence PNG vérifiée ;
grille 5 × 5 de 256 px ; priorité aux attaques v2 et aux autres animations v1.
Réutiliser le backend 2D et son contrat de release/annulation, avec un adaptateur
pour les huit directions écran, le repos animé et la course native.
Crochet utilise le geste fourni ; garde, réaction et mort ont des replis explicites
dans la même apparence, car leurs planches ne sont pas fournies.

## Livraison

Les 56 PNG sont intégrés, sans retouche, avec 112 clips et 1 400 régions d’atlas.
Le profil `data/visuals/achilles/achilles_autosprite_profile_v1.tres` est branché
sur la scène classique, son aperçu et le joueur du seuil/des haltes.
Le backend `characters/achilles/2d/achilles_autosprite_backend.gd` gère le repos
animé, les cycles natifs et les huit orientations. La façade projette les axes
de grille sur la vraie grille de combat, avec un repli pendant l’initialisation.
Le joueur des haltes anime le repos sans interférer avec sa marche par distance.
Les marqueurs de combat, l’arrivée de Percée et l’annulation restent sous le
contrôle du backend et des contrôleurs existants.

Le constructeur, les commandes reproductibles, les cadences et les limites des
planches sont décrits dans `tools/achilles_autosprite/README.md`.
Pour essayer : F5 → Nouvelle partie → Achille classique.

## Preuves de validation

Godot 4.7.1 officiel `a13da4feb`, GUT 9.7.1. Doctor puis import Godot validés.
Le premier import dans le bac à sable échouait sur les accès à l’environnement ;
les exécutions suivantes utilisent le moteur en contexte utilisateur normal,
avec APPDATA/LOCALAPPDATA isolés. Aucune sauvegarde utilisateur modifiée.

- Nouveaux contrats : **7 tests, 788 assertions, PASS strict**, rapport
  `artifacts/dev/20260913-095103-achilles-autosprite-61205507/gut-strict-report.json`.
  Contrôlent les hashes des 56 images, la transparence, les huit directions,
  le repos, les cycles, les marqueurs, l’annulation et la mort. Exécution finale
  après formatage, avec le moteur résolu depuis `tools/dev`.
- Intégration élargie : **129 tests / 9 897 assertions réussis**, mais **FAIL
  strict à l’arrêt** : huit textures RID et 177 ressources non libérées.
  Rapport et diagnostic détaillé :
  `artifacts/dev/20260913-094305-achilles-autosprite-337c673c/`.
  La liste contient des ressources de sorts/doctrines/VFX ; cette fuite du lot
  élargi n’est pas résolue. Ne pas annoncer cette exécution comme PASS strict.
- Sélection et navigation du vrai seuil : **11 contrôles PASS**, captures
  `artifacts/dev/achilles_autosprite/entry/` inspectées visuellement.
- Combat réel sans coût des captures : **PASS**, scénario marche, garde,
  Percée, attaque ; `artifacts/dev/achilles_autosprite/combo_E_timing/`.
- Tir en combat : **PASS**, orientation NE et pose de lâcher inspectées ;
  `artifacts/dev/achilles_autosprite/shot_N_visual/`.
- Dégâts et mort par tours ennemis : **PASS**, six réactions non létales,
  une seule fin de mort, alpha final nul, vue retirée, déplacement d’ancrage
  nul ; `artifacts/dev/achilles_autosprite/hit_death_W_visual/`.
  Le dernier photogramme confirme visuellement la disparition.
- Format des quatre nouveaux scripts GDScript vérifié avec le formateur fixé
  du dépôt ; `git diff --check` ciblé sans erreur.

Les sondes existantes ont été adaptées pour le repos animé, la course de Percée
et les directions projetées. Le chemin VFX attendu vient maintenant de la
constante du gestionnaire réel. Les assertions de dégâts, d’ancrage, de fin
d’action et d’annulation sont conservées.

L’import intermédiaire `20260913-094808-achilles-autosprite-1ef9da96` a échoué
sur la lecture de dépendances, sans exécuter GUT. Il est conservé comme échec ;
l’import et les tests de l’exécution finale citée ci-dessus sont propres.

## État partagé et limites de la suite complète

HEAD vérifié le 13 septembre : `c98436df9339099076e683979f79c7cefd7ae5ea`.
État initial : arbre propre sauf `docs/ai/theorycraft_first_six_work.md`.
Pendant cette tâche, d’autres travaux ont modifié le combat, les sorts, le flux
d’expédition, le son et l’UI. Ces modifications ont été conservées. Ne pas
attribuer le diff complet de l’arbre à cette intégration.

La tentative `-Full` a exécuté 408 tests ; son rapport est sous
`artifacts/dev/20260913-092109-achilles-autosprite-967861b2/`. Elle contient des
contrats anciens imposant une présentation 3D et des attentes de catalogue à
42 sorts alors que le travail simultané ajoute les sorts `exp_ct_*` (80 sorts
au moment du contrôle). Elle n’est pas verte. Les erreurs d’initialisation de
grille et les attentes de profil/direction directement concernées ont été
corrigées, puis les scénarios réels ont été rejoués. Les catalogues et règles
des autres tâches n’ont pas été remaniés pour masquer les échecs.

Reste à juger par l’utilisateur : rythme et taille perçue en jeu. Pour remplacer
les replis de garde/réaction/mort par des gestes dédiés, il faudra des planches
correspondantes. Aucun autre travail d’intégration des planches reçues n’est
en attente.
