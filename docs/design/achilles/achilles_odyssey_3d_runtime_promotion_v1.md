# Achille — promotion 3D dans L’Odyssée V1

## Décision

Le 20 août 2026, le propriétaire a validé l’option **B : SubViewport 384 × 384**
et demandé de remplacer le corps de combat 2D d’Achille dans sa run Odyssée.
Le commit d’implémentation est
`0d0eeaf96acc35b9cc40fe5c2c1ba52cedd0c852` sur la branche locale
`integration/achilles-3d-character-theorycraft-v1`.

Cette décision promeut le personnage canonique 3D sans arme dans les trois
salles de L’Odyssée. Elle ne fusionne pas la branche dans `main`, ne pousse
aucune ref distante et ne sélectionne aucun concept du laboratoire d’arme ou
de theorycraft.

## Contrat runtime

- `data/units/allies/achilles.tres` conserve son chemin existant vers
  `characters/achilles/AchillesIsoUnitView.tscn` ; ni ses statistiques, ni ses
  sorts, ni sa progression ne sont modifiés.
- `AchillesIsoUnitView` ne charge comme backend de rendu visible que le
  `SubViewport` 3D choisi.
  L’ancien `AchillesVisual2D` armé n’est plus instancié, même pendant le
  warm-up et même en cas d’échec de chargement.
- Le secours est `NO_VISUAL_ACTION_CONTRACT` : il reste invisible mais garantit
  les signaux release/fin exact-once afin d’éviter un soft-lock de combat.
- Le profil reste strictement `character-only`, avec
  `equipment_enabled = false` et `weapon_profile = null`.
- La présentation 3D conserve l’ombre de contact des salles peintes et reçoit
  les flashes de dégâts, soins et bouclier sans altérer sa teinte de base.
- La carte d’initiative réutilise le portrait HUD raffiné d’Achille. Ce portrait
  2D est une icône d’interface volontaire ; ce n’est pas le corps rendu sur la
  grille. Le HUD et le post-combat peuvent donc encore afficher cette icône.

## Validation

Le runner graphique dédié
`test/achilles/achilles_odyssey_3d_runtime_promotion_smoke.tscn` :

- sélectionne L’Odyssée par les contrôles du vrai Hub ;
- charge et déploie les trois vraies scènes `Battle` ;
- vérifie dans chaque salle : backend 3D actif, résolution 384, un
  `SubViewport`, un `Skeleton3D`, aucun ancien visuel 2D, aucune arme ou
  instance d’équipement, ombre lisible et portrait d’initiative non vide ;
- exécute un déplacement réel puis `Garde d’airain` via les handlers Battle et
  `SpellCaster` : PM/PA consommés, bouclier appliqué, release et fin une fois ;
- recrée la vue en salle II sans doublon et vérifie les `WeakRef` de nettoyage ;
- traverse séparément les états du manager jusqu’au résultat Victoire.

La preuve durable est stockée hors dépôt dans
`C:\Dungeon_Draft_Production\Achilles\Integration\ACHILLES_3D_ODYSSEY_RUNTIME_PROMOTION_V1_20260820`.
Le JSON contient les SHA-256 des sept captures 1600 × 1000. Le log graphique
final ne contient ni `ERROR` ni `SCRIPT ERROR` pendant le runtime.

Suites ciblées observées avant le gel final :

- secours invisible : 4/4, 39 assertions ;
- personnage 3D : 5/5, 43 assertions ;
- SubViewport/adaptateur : 8/8, 60 assertions ;
- feedback UnitView : 4/4, 41 assertions ;
- timeline/portrait : 2/2, 20 assertions ;
- sources et isolation : 12/12, 1 477 assertions ;
- couverture du mandat : 42 PASS / 7 PENDING bornés, 258 assertions.

La suite historique `test_odyssey_achilles_solo_run.gd` conserve 14/19 : les
cinq échecs sont exclusivement le warning déjà connu sur l’UID invalide de
`Guerrier.tres`, traité par GUT comme erreur inattendue. Le test de l’adaptateur
3D et les assertions métier d’Achille passent.

## Bornes honnêtes

- La sélection Hub, le déplacement, le ciblage et le sort utilisent les vrais
  handlers mais sont déclenchés programmatiquement, pas par une souris humaine.
- Les trois combats ne sont pas joués jusqu’à la défaite réelle des ennemis :
  la traversée du manager et le résultat final sont explicitement synthétiques.
- Le root motion source reste `ROOT_MOTION_UNCLASSIFIED` ; X/Z sont neutralisés
  localement pour la présentation.
- Les temps GPU restent `NOT_MEASURED`.
- Godot/OpenGL signale encore au teardown des RID/ObjectDB/resources globaux,
  alors que les `WeakRef` ciblés Battle, adaptateur et SubViewport sont libérés.
- Le warning UID historique de `Guerrier.tres` demeure hors de cette promotion.
