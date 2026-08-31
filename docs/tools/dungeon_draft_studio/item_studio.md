# Studio des objets et effets — guide utilisateur V1

- Date : 2026-08-28
- Branche : `main`
- HEAD de base : `b642e905f851d9444a22b76cad18da14e19b34d1`
- Statut : **WORKTREE_CANDIDATE — non promu CURRENT**
- Dernière preuve historique : GUT Item Studio 30/30 (190 assertions) ; smoke intégré PASS ; captures réelles inspectées en 1280×720 et 1920×1080. Les tests ciblés du durcissement du 28 août sont ajoutés mais restent à exécuter sur le worktree consolidé.
- Non vérifié à ce stade du document : validation humaine dans l’éditeur Godot interactif.

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

Les héros compatibles ne sont pas une liste UI. Le Studio découvre récursivement
les `UnitData` de l’équipe joueur sous `data/units/alliés` et
`data/units/allies`, écarte les dépendances cassées et les identifiants dupliqués,
puis résout l’unique profil de progression disponible pour retrouver le loadout
réel. Ce catalogue alimente création, filtres, validation et test. Achille est
donc disponible sans branche spéciale dans l’éditeur.

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

Le résultat du bouton est conservé avec l’empreinte du document, affiché dans le
panneau d’analyse et résumé dans la barre d’état. Toute modification ultérieure
invalide ce résultat afin qu’un succès ancien ne soit pas présenté comme actuel.

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
`user://dungeon_draft_studio/item_studio/drafts`. Ce dossier personnel est
extérieur au dépôt et aux dossiers auto-découverts du catalogue de production.
Les anciens brouillons sous `res://data/items/drafts` restent découvrables afin
d’être ouverts puis migrés, mais toute nouvelle sauvegarde cible `user://`.
Le nom de fichier d’un nouveau brouillon est normalisé depuis l’`item_id` et ne
peut pas sortir de ce dossier, même si le document en cours contient encore un
identifiant invalide.
L’écriture utilise un fichier temporaire, une
relecture et une comparaison d’empreinte ; une erreur restaure l’original.
Un brouillon peut conserver un document encore invalide : ses erreurs restent
des avertissements de non-publication, sans empêcher la récupération du travail.

Juste avant le remplacement, le Studio relit la cible sans cache. Une création,
modification ou suppression externe depuis la revue du plan bloque l’écriture et
demande un rechargement. Fermer le plugin avec un document modifié déclenche la
même sauvegarde de brouillon vérifiée ; le document n’est pas abandonné
silencieusement. Si le chemin principal existe déjà sans être le document
ouvert — même avec le même `item_id` — ou apparaît pendant la fermeture, une
copie de récupération horodatée est écrite à côté. L’ancien brouillon reste
intact ; seul un brouillon effectivement ouvert est mis à jour directement.

**Publier** calcule un chemin dans un dossier auto-découvert, affiche collisions,
opération, empreintes et avertissements, puis demande confirmation. Après
écriture, le catalogue est reconstruit et l’objet doit être présent exactement
une fois. Un brouillon issu d’un objet de production peut mettre à jour ce même
objet : la cible canonique est photographiée lors de la revue du plan, contrôlée
à nouveau avant remplacement, puis ce seul brouillon effectivement publié est
retiré. Les autres copies de récupération du même objet restent disponibles.

La case **Éligible aux récompenses du premier run** contrôle uniquement le tag
autoritatif `first_run_equipment_reward`, et seulement pour un équipement. Le
plan de publication signale son changement. La mission ne modifie ni les pools
existants, ni l’inventaire initial, ni les récompenses de salles.

## Limites réelles de la V1

- `RUN_SPECIFIC` est différé faute de catalogue par run.
- Les reliques actives restent des `ItemDefinition`. `RelicEffectRegistry`
  décrit leurs effets et `RelicRuntimeService` est leur unique exécuteur,
  y compris pour l’activation manuelle. L’ancien format `RelicDefinition`
  n’est ni importé ni utilisé comme seconde autorité.
- Une nouvelle famille d’effet doit être codée, testée et enregistrée avant
  d’apparaître dans le compositeur.
- Les effets nécessitant une grille de bataille sont signalés ; la projection
  pure ne prétend pas remplacer le pipeline complet.
- Il n’existe aucun éditeur libre de GDScript et aucune suppression physique.
- Les diagnostics d’équilibrage ne changent jamais automatiquement les valeurs.
