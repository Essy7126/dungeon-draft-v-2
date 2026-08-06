# Studio des personnages et compétences

Statut : `WORKTREE_CANDIDATE`
Base : `94fcdc700cf576a15ee4134d9f3dee680626827a`, branche `main`
Vérifié le : 6 août 2026

Le Studio édite directement les `UnitData`, sorts, disciplines, rangs, améliorations et
modificateurs utilisés par le jeu. Toute saisie travaille d’abord sur une copie isolée :
aucune donnée de production n’est écrite avant la transaction de sauvegarde.

## Ouvrir et naviguer

Ouvrez **Projet > Outils > Dungeon Draft : ouvrir le Studio des compétences**, ou le
bouton **Compétences** du Dungeon Draft Studio. Le catalogue conserve Elfe, Mage et
Guerrier, y compris si un héros n’a aucune discipline.

La navigation suit `personnage > discipline > rang > nœud > effet`. **Rechercher** ou
`Ctrl+F` cherche dans les noms, identifiants, descriptions et résumés d’effets ; un
double-clic ouvre le document, la discipline et centre le nœud. Le graphe propose sa
minimap, le cadrage, l’organisation déterministe par rang et des positions personnelles
stockées sous `user://`.

## Créer et structurer un arbre

- **+ Nouvelle discipline** crée la discipline, ses rangs et son sort racine en une
  action annulable. **Dupliquer** produit des Resources indépendantes.
- **+ Rang**, **− Dernier rang**, **+ Amélioration**, clic droit et l’assistant de
  branche gèrent la structure sans édition manuelle de `.tres`.
- Tirer une connexion crée un prérequis ; tirer vers le vide crée un enfant. Les lignes
  bleues sont des prérequis. Les exclusions sont orange et pointillées, désactivables
  depuis le menu du graphe.
- La sélection multiple peut être copiée, collée, dupliquée, alignée, distribuée ou
  supprimée. Une copie multiple conserve seulement ses relations internes par défaut.
- Une suppression multiple reconnecte transitivement les descendants et produit un
  rapport d’impact.

Les déplacements de carte et la sélection ne polluent pas l’historique gameplay. Les
positions épinglées et manuelles sont des préférences, pas des données de combat.

## Modifier les personnages, sorts et effets

Le **Mode guidé** expose les champs métier et leurs conséquences. Le **Mode avancé**
ajoute identifiants, chemins, stockage, invocation, résolution différée, terrain,
statuts et opérations destructrices. Changer de mode valide d’abord la saisie visible.

L’inspecteur couvre les propriétés sérialisées atteignables : booléens, nombres,
pourcentages, textes, identifiants, enums, flags, couleurs, vecteurs, Resources,
tableaux ordonnés et dictionnaires. Les recharges d’invocation ont un éditeur clé/valeur.
Les modificateurs permanents d’un sort et ceux d’un nœud peuvent être créés, choisis,
partagés, dupliqués, réordonnés, retirés ou rendus uniques.

Un identifiant stable n’est pas un libellé. Son renommage utilise l’index de références,
refuse les collisions connues dans le projet, montre l’impact et met à jour les
références du document. Une ancienne sauvegarde de run peut conserver l’ancien ID.
`unit_id` reste une opération experte.

## Prévisualiser et analyser

**Tester** ouvre le simulateur de progression fondé sur `SkillTreeResolver` et
`DisciplineProgressState`. **Prévisualiser** compare le sort de base et le nœud ou effet
sélectionné dans une sandbox qui appelle le vrai `SpellCaster`. Le panneau affiche :

- le sort de base et le sort résultant ;
- le delta par scénario (défenses 0/25/50/100, allié, cible affaiblie, dos, plusieurs
  cibles et cellule libre) ;
- la trace des modificateurs, leur résumé et les avertissements ;
- l’autorité de chaque résultat. La sandbox ne lit ni n’écrit la progression d’une run.

**Analyse complète** sépare l’énumération bornée, l’accessibilité logique indépendante,
la dominance prudente et le lint consultatif des capstones. Un total exact est marqué
`exact`; une limite est affichée comme `au moins N`. Une énumération tronquée n’est
jamais utilisée pour déclarer un nœud inaccessible.

Le contrôle **Contrat actuel** est un profil de caractérisation facultatif, désactivé
pour un nouvel arbre. Les valeurs `0/5/12/21/30`, `0/2/4/8/4` et `16` ne sont pas des
invariants universels.

## Valider, revoir et sauvegarder

**Valider** lance les contrôles rapides. Les erreurs bloquent ; les avertissements
restent consultatifs. **Sauvegarder** valide d’abord le champ focalisé, puis ouvre
obligatoirement la vue **Changements** : propriétés avant/après, CREATE/UPDATE,
détachements, orphelins, collisions, ordre d’écriture et futur point de récupération.
Les fichiers nécessaires à la cohérence ne sont pas décochables.

La transaction comporte deux phases : staging et relecture complète, puis backups,
application ordonnée, vérification d’empreinte et rechargement du document. Une collision
disque, cache ou session n’écrase jamais implicitement un fichier. Tout échec restaure
les backups, retire seulement les nouveaux fichiers de la tentative, conserve la
récupération et laisse le document modifié. Un échec du rechargement final est un échec.

Les points de récupération sont sous
`user://dungeon_draft_studio/skill_tree/recovery/`. Le manifeste indique le statut,
l’étape fautive, le plan, les backups et la vérification du rollback.

## Brouillons et fermeture inattendue

Un document modifié produit périodiquement un brouillon versionné sous
`user://dungeon_draft_studio/skill_tree/drafts/`, et en produit un avant la fermeture du
plugin. Au prochain démarrage, le Studio propose explicitement **Restaurer**,
**Comparer** ou **Abandonner** ; il ne restaure jamais silencieusement. Une sauvegarde
réussie ou un abandon explicite supprime les brouillons concernés. Si une nouvelle
écriture échoue, le dernier brouillon valide reste intact.

## Retrait, orphelins, archive et suppression

**Supprimer** une discipline depuis le catalogue signifie d’abord **Retirer du
personnage** : le fichier est conservé et devient éventuellement orphelin. Le bouton
**Orphelins** liste type, Resource, chemin, dernier propriétaire connu, raison et
références entrantes.

- **Adopter** rattache une discipline compatible après contrôle d’identité.
- **Archiver** refuse les références entrantes, copie la Resource et un manifeste sous
  `user://`, puis retire le fichier du projet.
- **Supprimer définitivement** est avancé, exige le nom ou l’identifiant exact, vérifie
  les références et crée la même archive récupérable avant retrait.

## Raccourcis

| Raccourci | Action |
|---|---|
| `Ctrl+S` | Revoir puis sauvegarder, y compris la valeur du champ focalisé |
| `Ctrl+Z` / `Ctrl+Y` | Historique du document hors champ texte ; historique local dans le champ texte |
| `Ctrl+F` | Recherche globale |
| `Ctrl+C` / `Ctrl+V` / `Ctrl+D` | Copier, coller, dupliquer la sélection du graphe |
| `Suppr` | Demander la suppression de la sélection |
| `Échap` | Annuler une connexion ou fermer le dialogue actif |
| `Tab` / `Maj+Tab` | Parcourir les actions et champs focalisables |

Chaque raccourci principal possède aussi un bouton ou une entrée de menu visible.
