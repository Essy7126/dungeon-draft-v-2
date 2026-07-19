# Correction du cycle de vie de la boule de feu

Date : 19 juillet 2026  
Verdict technique : `FIREBALL_VFX_CLEANUP_FIXED_WITH_WARNINGS`

## Ressource réellement utilisée

L'elfe utilise le troisième sort de `res://data/units/alliés/elfe.tres` :

- ressource Spell : `res://data/spells/Mage/boule_de_feu.tres` ;
- nom du sort : `feu` ;
- `vfx_scene` : UID `uid://hmp238551qj7` ;
- scène réellement résolue par cet UID : `res://battle/vfx/boule_de_feu_vfx2.tscn` ;
- script : `res://battle/vfx/boule_de_feu_vfx2.gd`.

Le chemin textuel encore inscrit dans la ressource est `res://battle/vfx/boule_de_feu.tscn`, qui n'existe plus. Godot résout néanmoins correctement l'UID vers `boule_de_feu_vfx2.tscn`. Ce chemin obsolète n'a pas été corrigé, afin de ne pas modifier la ressource Spell hors du cycle de vie demandé.

`VFXManager` instancie cette scène dans `Battle/VFXLayer`, puis appelle `initialiser(position_main_droite, position_cible)`. Il n'a pas été modifié.

## Structure inspectée

La racine est `BouleDeFeu`, de type `Node2D`.

| Nœud | Type | Rôle / état initial |
|---|---|---|
| `TailLine` | `Line2D` | traînée dessinée, largeur 5 px |
| `SmokeTrail` | `GPUParticles2D` | émission continue, durée particule 1,2 s |
| `FireTrail` | `GPUParticles2D` | émission continue, durée 0,38 s |
| `FireTrail2` | `GPUParticles2D` | émission continue, durée 0,32 s |
| `FireTrail3` | `GPUParticles2D` | émission continue, durée 0,26 s |
| `FireballCore` | `GPUParticles2D` | noyau de particules, durée 0,22 s |
| `FireballHead` | `ColorRect` + shader | noyau jaune/blanc, rectangle d'environ 97,2 x 54 px |
| `Explosion` | `GPUParticles2D` | one-shot, durée 0,55 s, désactivé avant l'impact |

La scène ne contient aucun `Sprite2D`, `AnimatedSprite2D`, `PointLight2D`, `CPUParticles2D`, `Polygon2D`, Timer enfant ou Tween propre au VFX. Le seul signal déclaré est `Explosion.finished -> _on_explosion_finished`. Les Tweens comptés globalement pendant le test appartenaient à la salle ou à l'interface, pas à la boule de feu.

## Reproduction avant correction

État normal, sans interruption :

| Temps depuis l'instanciation | Enfants de `VFXLayer` | État |
|---:|---:|---|
| avant le cast | 0 | aucun VFX |
| 0 s | 1 | projectile en vol, tête et traînées visibles |
| 0,25 s | 1 | projectile arrivé, tête et ligne masquées, traînées arrêtées, explosion active |
| 0,5 s | 1 | explosion encore active |
| 1 s | 0 | instance libérée |
| 2 s | 0 | aucun résidu |
| 5 s | 0 | aucun résidu |

La branche normale fonctionnait donc déjà. Le défaut apparaissait quand le traitement du projectile était interrompu avant `_arriver()`.

Reproduction interrompue avant correction :

- la racine restait dans l'arbre avec `is_processing = false` ;
- `VFXLayer` conservait un enfant `BouleDeFeu` à 0,25, 0,5, 1, 2 et 5 secondes ;
- `FireballHead.visible` restait `true` ;
- `SmokeTrail`, `FireTrail`, `FireTrail2`, `FireTrail3` et `FireballCore` restaient en émission ;
- `Explosion` n'était jamais déclenchée ;
- aucun Timer ou autre mécanisme indépendant ne pouvait atteindre `queue_free()`.

La durée de vie était donc **illimitée** dans cette branche.

## Nœud responsable et cause exacte

Le grand élément jaune/blanc est produit principalement par **`FireballHead`**, un `ColorRect` animé par `boule_de_feu.gdshader`. Les particules continues autour de lui renforçaient le halo, mais le losange jaune 64 x 32 sous les pieds appartient à `UnitView._draw()` et n'est pas concerné.

La cause était exclusivement le cycle de vie : `_arriver()` était le seul chemin qui masquait `FireballHead`, arrêtait les traînées et déclenchait l'explosion. Si `_process()` cessait avant l'arrivée, ni le signal `Explosion.finished` ni `queue_free()` ne pouvaient être atteints.

## Correction appliquée

Le script propre à la boule de feu possède maintenant :

- `maximum_lifetime_seconds`, exporté entre 2 et 5 secondes, valeur 3,0 s ;
- un `SceneTreeTimer` local démarré par `initialiser()` avec traitement permanent et indépendant du `_process()` du projectile ;
- `_stop_projectile_visuals()`, appelé à l'arrivée, à la fin de l'explosion et par la sécurité maximale ;
- masquage de `FireballHead` et `TailLine` ;
- arrêt de tous les `GPUParticles2D` concernés ;
- désactivation défensive d'un éventuel `PointLight2D` enfant ;
- `queue_free()` de la seule instance visuelle.

Le watchdog n'applique aucun dégât, ne joue aucun impact, n'émet aucun événement de combat et ne réinstancie aucun VFX. Le trajet et l'impact normaux restent pilotés par `_process()`, `_arriver()` puis `Explosion.finished`.

## Durées après correction

Deux casts normaux successifs ont donné :

| Cast | Arrivée détectée | Fin complète | Distance minimale à la cible |
|---|---:|---:|---:|
| 1 | 0,009 s | 0,628 s | 7,452 px |
| 2 | 0,005 s | 0,610 s | 7,415 px |

Le seuil d'arrivée existant est de 8 px. Le trajet, sa vitesse et son timing n'ont pas été modifiés. L'impact one-shot de 0,55 s termine, puis l'instance est libérée.

Une instance volontairement bloquée avec `set_process(false)` a été libérée par le watchdog en environ 2,849 s. Elle n'a produit aucun événement de dégâts et `VFXLayer` est revenu à zéro enfant.

Un troisième cast suivi immédiatement de la mort du lanceur a également rejoint la cible en 0,007 s, été libéré en 0,612 s et laissé `VFXLayer` vide.

## Validation fonctionnelle

- enfants de `VFXLayer` avant : 0 ;
- enfants après chaque cast : 0 ;
- enfants à la fin : 0 ;
- deux instances successives distinctes : oui (`110679296378` puis `142723778960`) ;
- origine main droite : écart 0 px pour chaque cast ;
- cible atteinte : oui pour les trois casts ;
- dégâts : exactement un événement par cast réel ;
- watchdog isolé : zéro événement de dégâts ;
- cast suivi de la mort : instance libérée ;
- sélection : inchangée ;
- Y-sort : inchangé ;
- pivot de l'elfe : inchangé ;
- erreur GDScript ou erreur d'exécution : aucune.

Le scénario complet historique de la salle a également été rejoué après la correction : aucune erreur fonctionnelle, origine VFX à 0 px, dégâts uniques, sélection/Y-sort inchangés et validation complète de Cast, Hit et Death.

Les diagnostics de RID affichés uniquement lors de la fermeture automatique immédiate du banc de test sont les avertissements de destruction déjà observés sur cette scène de validation. Ils ne sont pas produits par le VFX en fonctionnement. La salle laissée ouverte ne génère pas ces diagnostics de fermeture.

## Vérification de taille

Aucune échelle, taille de shader, lumière ou particule n'a été modifiée. Le grand élément observé était surtout problématique parce qu'il pouvait rester cinq secondes ou indéfiniment. En trajet normal, l'arrivée intervient en 5 à 9 ms et l'ensemble disparaît après environ 0,61 s ; il s'agit alors d'un impact très bref, pas d'un halo permanent. Une réduction artistique n'était donc pas nécessaire pour corriger le défaut demandé.

## Captures

- avant : `res://tests/characters/elf/screenshots/fireball_residue_before.png` ;
- après : `res://tests/characters/elf/screenshots/fireball_cleanup_after.png`.

La capture avant utilise l'interruption contrôlée qui reproduit la branche défectueuse. La capture après est prise après deux vrais casts, avec l'elfe sélectionnée, Idle et `VFXLayer` vide.

## Fichiers modifiés

- `res://battle/vfx/boule_de_feu_vfx2.gd` : correction de cycle de vie ;
- `res://tests/characters/elf/elf_salle1_gameplay_integration.gd` : instrumentation et validation uniquement ;
- `res://battle/vfx/FIREBALL_VFX_LIFECYCLE_FIX.md` : présent rapport ;
- les deux captures PNG listées ci-dessus.

Aucun des fichiers ou systèmes interdits n'a été modifié : `ElfVisual3D`, `ElfIsoUnitView`, `UnitView`, sélection, `cast_release_reached`, origine main droite, `SpellCaster`, `VFXManager`, dégâts, grille, Y-sort, animations et données du personnage sont inchangés.

## Git

État initial : dépôt propre, branche `main`, HEAD `3bc4b4c (intégration elfe)`.

État final attendu : le script VFX et le banc de test sont modifiés ; le rapport et les deux captures sont nouveaux. Aucun commit et aucun push n'ont été effectués.

## Avertissements

1. Le chemin textuel obsolète du `vfx_scene` reste présent dans `boule_de_feu.tres`, même si l'UID résout correctement la scène réelle.
2. Le banc automatisé signale des ressources de rendu encore vivantes lors de sa fermeture forcée ; aucune erreur fonctionnelle ne survient pendant les casts.
