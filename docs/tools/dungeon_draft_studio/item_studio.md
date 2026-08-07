# Studio des objets et effets — guide utilisateur V1

- Date : 2026-08-07
- Branche : `main`
- HEAD de base : `29f307b5ff61822f266bbd2d14636ca8dcea2d95`
- Statut : **WORKTREE_CANDIDATE — non promu CURRENT**
- Tests exécutés : GUT Item Studio 30/30 (190 assertions) ; smoke intégré PASS ; captures réelles inspectées en 1280×720 et 1920×1080.
- Non vérifié à ce stade du document : validation humaine dans l’éditeur Godot interactif ; aucun runtime de reliques.

## Ouvrir le Studio

Ouvrir « Dungeon Draft Studio » depuis le plugin Godot, puis choisir l’onglet
**OBJETS**. Il s’agit du troisième domaine du Studio existant, aux côtés d’Arènes
et Rencontres. La barre de contexte partagée reste l’autorité pour la run, le
héros et la portée.

La portée **SHARED** permet de préparer une publication partagée. **DRAFT**
conserve le travail hors du catalogue de production. **RUN_SPECIFIC** est visible
mais sa publication est bloquée : il n’existe pas encore d’autorité de catalogue
d’objets propre à chaque run.

## Catalogue et filtres

Le panneau gauche est construit dynamiquement depuis le vrai `ItemCatalog`. Il
n’encode aucun nombre fixe d’objets. Il permet de rechercher par nom, `item_id`,
tag ou chemin, puis de filtrer par catégorie, rareté, emplacement, héros,
éligibilité aux récompenses et statut. Le tri est disponible par nom, identifiant,
rareté, catégorie ou chemin.

Les badges signalent notamment les brouillons, erreurs et objets éligibles au
pool de récompense. Cliquer un objet charge une working copy isolée. Si le
document courant est modifié, le Studio demande de l’enregistrer comme brouillon,
de l’abandonner explicitement ou d’annuler le changement de document.

## Créer et dupliquer

**Nouveau** ouvre un assistant : choisir une catégorie, un nom, l’`item_id`
proposé et la compatibilité. Aucune écriture n’a lieu à cette étape.

**Dupliquer** crée par défaut un nouveau brouillon. Le dialogue propose un
nouvel identifiant et un nouveau chemin. Les tags d’acquisition ne sont copiés
que sur demande ; le tag `first_run_equipment_reward` n’est pas copié par défaut.
Les textures restent partagées comme assets immuables, tandis que toutes les
sous-ressources d’effets mutables sont dupliquées en profondeur.

Un objet publié ne peut pas changer silencieusement d’`item_id`. Pour créer une
variante, utiliser **Dupliquer**. La V1 n’expose ni suppression physique, ni
déplacement automatique d’une ressource publiée.

## Modifier l’objet et ses effets

L’inspecteur central édite l’identité, la présentation, la catégorie,
l’emplacement, la pile, l’usage, les tags et la compatibilité. Les champs texte
forment une seule transaction d’historique par prise de focus, et non une entrée
par caractère. **Annuler** et **Rétablir** utilisent l’historique partagé du
Studio.

Le compositeur d’effets permet d’ajouter une modification de statistique fixe ou
en pourcentage, ou un modificateur de sorts `ItemSpellModifierData`. Les usages
existants de soin fixe et restauration de PA sont exposés dans les champs
d’usage. Chaque effet peut être dupliqué, retiré de la working copy, réordonné et
paramétré. La case à gauche désactive seulement l’effet dans la prévisualisation ;
elle ne change pas la donnée sauvegardée.

Une classe inconnue est affichée avec son nom exact et « Effet non pris en charge
par le Studio ». Elle est préservée, mais bloque la sauvegarde afin d’éviter une
perte silencieuse. Aucune saisie de script arbitraire n’est disponible.

## Prévisualiser, analyser et comparer

**Tester** construit un héros, un inventaire et un équipement isolés. Un
équipement passe par les vrais `EquipmentService` et `EquipmentStatService`, est
retiré, puis le snapshot final doit être strictement égal au snapshot initial.
Un consommable passe par le vrai `ItemUseService`. Aucun scénario ne touche
`GameManager`, la run active ou l’inventaire actif.

Le panneau droit affiche la carte, l’empreinte sémantique, les erreurs et
avertissements, les deltas par héros, l’EHP physique/magique estimé avec la loi
du `DamageResolver`, les breakpoints et les références entrantes.

Les menus **Héros analysé**, **Sort analysé** et **Profil cible** sélectionnent un
héros compatible, un sort de son loadout de production et un seuil de PV de
référence. La vue affiche portée, dégâts, soin, bouclier et poussée avant/après,
ainsi que l’applicabilité de chaque filtre. Les effets qui dépendent de la grille
restent explicitement présentés comme une projection nécessitant un contexte de
bataille pour leur résolution finale.

Le menu **Comparer avec…** limite la dominance aux objets de même catégorie,
emplacement, rareté et audience, sans condition ni contrepartie supplémentaire.
Les autres cas sont « incomparable » ou « comparaison partielle ». Le score de
budget éventuel est exploratoire et n’est jamais sauvegardé.

## Brouillon, publication et récompenses

**Enregistrer en brouillon** affiche d’abord le plan complet, puis écrit sous
`res://data/items/drafts`. Ce dossier est extérieur aux dossiers auto-découverts
du catalogue de production. L’écriture utilise un fichier temporaire, une
relecture et une comparaison d’empreinte ; une erreur restaure l’original.

**Publier** calcule un chemin dans un dossier auto-découvert, affiche collisions,
opération, empreintes et avertissements, puis demande confirmation. Après
écriture, le catalogue est reconstruit et l’objet doit être présent exactement
une fois.

La case **Éligible aux récompenses du premier run** contrôle uniquement le tag
autoritatif `first_run_equipment_reward`, et seulement pour un équipement. Le
plan de publication signale son changement. La mission ne modifie ni les pools
existants, ni l’inventaire initial, ni les récompenses de salles.

## Limites réelles de la V1

- `RUN_SPECIFIC` est différé faute de catalogue par run.
- Aucun runtime de reliques n’est activé ; les ressources historiques ne sont ni
  importées, ni présentées comme fonctionnelles.
- Une nouvelle famille d’effet doit être codée, testée et enregistrée avant
  d’apparaître dans le compositeur.
- Les effets nécessitant une grille de bataille sont signalés ; la projection
  pure ne prétend pas remplacer le pipeline complet.
- Il n’existe aucun éditeur libre de GDScript et aucune suppression physique.
- Les diagnostics d’équilibrage ne changent jamais automatiquement les valeurs.
