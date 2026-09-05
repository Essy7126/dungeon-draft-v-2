# Achille — inventaire des animations de sorts V2

Inventaire du 5 septembre 2026, actualisé après la production du kit sprite V2 et le raccordement du runtime. Il distingue les mécaniques configurées des choix de présentation de cette passe. Aucun équilibrage ni achat de maîtrise n’est modifié par cet inventaire. Le résolveur de présentation décrit plus bas est pur ; les tests et le harness de combat vérifient séparément son routage, le rendu et l’ordre réel des effets.

## Autorité et identités

La Catabase charge le [profil Champion d’Achille](C:/Users/paolo/Documents/dungeon-draft-v-2/data/runs/progression/odyssey/achilles_progression_profile.tres:17). Il fournit exactement quatre `Spell`, dans l’ordre Frappe, Percée, Tir et Garde. Le [catalogue de maîtrises](C:/Users/paolo/Documents/dungeon-draft-v-2/data/characters/achilles/doctrines/achilles_mastery_catalog.tres:14) contient trois doctrines de neuf nœuds et neuf maîtrises avancées, soit **36 nœuds**.

Les maîtrises **ne remplacent aucun Spell et ne créent aucun nouvel `effective_spell_id`**. [Spell.get_effective_spell_id()](C:/Users/paolo/Documents/dungeon-draft-v-2/data/spell.gd:188) rend `spell_id` dès qu’il est renseigné, y compris sur une copie runtime. Fléau, Ligne, Volée et Rempart sont des transformations ou effets attachés aux identifiants de base. Le [résolveur statique](C:/Users/paolo/Documents/dungeon-draft-v-2/characters/progression/mastery_static_modifier_resolver.gd:12) conserve l’identité du sort et expose sa forme, ses limites et les identifiants des nœuds ayant contribué à son profil.

| Technique et ressource d’origine | `spell_id` = `effective_spell_id` | Mécanique actuelle | Présentation décidée |
|---|---|---|---|
| [Frappe du Péléide](C:/Users/paolo/Documents/dungeon-draft-v-2/data/spells/achilles/peleid_strike.tres:14) | `achilles_peleid_strike` | 3 PA ; portée 1 ; 55 % Prouesse physiques ; une utilisation par activation. Classification `MELEE`. | `strike / attack` : estoc de lance existant, timing affiné ; impact unique à l’extension. |
| [Percée fulgurante](C:/Users/paolo/Documents/dungeon-draft-v-2/data/spells/achilles/fulminant_dash.tres:8) | `achilles_fulminant_dash` | 1 PA ; portée 1–3 cardinale vers case libre ; pas de dégâts de base ; chemin libre exigé ; une utilisation. Classification `MOVEMENT`. | `dash / dash` : nouvelle charge de quatre poses ; départ, translation réelle, réception. |
| [Tir du Pélion](C:/Users/paolo/Documents/dungeon-draft-v-2/data/spells/achilles/pelion_shot.tres:14) | `achilles_pelion_shot` | 3 PA ; portée 2–6 avec ligne de vue ; 50 % Prouesse physiques ; une utilisation. Classification `PROJECTILE`. | `shot / bow` : véritable tir à l’arc de quatre poses ; lance et bouclier rangés dans le dos pendant le geste. |
| [Garde d’airain](C:/Users/paolo/Documents/dungeon-draft-v-2/data/spells/achilles/bronze_guard.tres:17) | `achilles_bronze_guard` | 2 PA ; personnel ; bouclier = 5 % PV max + 25 % Prouesse ; une utilisation ; source portant `guard` et `achilles_guard`, durée 1 activation. Classification `SELF`. | `guard / guard` : armé de bouclier de quatre poses, puis retour stable ; effet sprite de protection déjà raccordé. |

La [classification](C:/Users/paolo/Documents/dungeon-draft-v-2/data/characters/achilles/attack_classifications.tres:8) reste celle du sort de base : Fléau ne devient pas automatiquement `AREA`, Volée reste `PROJECTILE`. Ces catégories participent aux contres et à la mitigation ; l’animation ne doit pas les redéfinir.

La fiche de conception décrit une lance et un bouclier. Les données de Frappe ne prescrivent pas à elles seules une arme graphique ; les descriptions de Chiron parlent explicitement de flèches. Le [contrat de statistiques](C:/Users/paolo/Documents/dungeon-draft-v-2/docs/design/achilles/champion_catabase_statistics_v0.md:32) précise que les équipements sont passifs et ne créent aucune arme visible. **Le nouvel arc est donc une convention graphique du Tir, pas le résultat de l’équipement d’un objet.** Conserver mains, taille d’armes, cape et ancre des pieds lors des échanges d’armes ; revenir à la pose canonique avec lance et bouclier à la fin.

## Formes évoluées qui changent le rendu

Les références `W`, `C`, `A`, `X` renvoient aux fichiers de doctrines listés dans la section suivante ; le nombre indique la ligne de `upgrade_id`.

| Évolution | Identifiant de maîtrise / référence | Sort hérité et géométrie effective | Geste et effet |
|---|---|---|---|
| Fléau de Troie | `achilles_wrath_scourge_of_troy` — W:354 | Frappe `LINE`, 2 cases consécutives, coefficients 1,20 / 0,70. La première cible reste à portée de la Frappe. | Nouvelle `sweep`, quatre poses. Effet `strike_line` dirigé sur les deux cases ; aucun cercle de dégâts autour d’Achille. |
| Flèche perforante | `achilles_chiron_piercing_arrow` — C:282 | Tir `LINE`, perforation active, 2 cibles, coefficients 1 / 0,60. Le trajet continue au-delà de la première cible dans les limites de portée et de passage projectile. | Réutiliser `bow` ; projectile `arrow_piercing` persistant jusqu’à la dernière cible réelle. |
| Ligne de mort | `achilles_chiron_death_line` — C:409 | Tir `LINE`, perforation active, 3 cibles, coefficients 1 / 0,70 / 0,40 ; ignore 25 Armure à distance ≥ 6. | Même `bow`, tir plus marqué par le traitement de l’effet `arrow_death_line`. Pas de troisième attaque du corps. |
| Volée du centaure | `achilles_chiron_centaur_volley` — C:457 | Tir `FAN`, 3 cases, coefficients 0,70 chacun, portée 2–5, perforation désactivée. Le runtime définit le centre et ses deux voisins latéraux. | Nouvelle `volley`, quatre poses ; effet `arrow_volley` vers les trois cases résolues. |
| Bastion mobile | `achilles_aeacus_mobile_bastion` — A:351 | Percée sous source de Garde restante : consommation de 20 %, dégâts de la valeur consommée plafonnés à 8 % PV max, poussée 1 des ennemis cardinaux adjacents à l’arrivée. | Même `dash` avec effet `dash_bastion` à la réception. Ni choc au départ ni changement de portée inventé. |
| Rempart des Myrmidons | `achilles_aeacus_myrmidon_rampart` — A:447 | Garde personnelle × 0,75 ; trois cases de barrière devant Achille ; blocage projectile et surcharge de traversée ennemie +1 PM ; expiration à l’activation suivante. | Même `guard` ; effet `guard_rampart` sur les trois cellules exactes de barrière, distinct du bouclier personnel. |
| Garde orientée | `achilles_aeacus_directional_guard` — A:80 | Choix de direction ; dégâts à la Garde × 0,65 de face et × 1,15 de côté ou derrière. | Même `guard` orientée vers le choix ; ne pas pivoter après coup vers une cible inexistante. |
| Tir rapproché | `achilles_chiron_close_shot` — C:173 | Tir portée 1–5 ; bonus à courte distance et poussée 1. | Même `bow` ; effet d’impact/poussée, sans feindre une frappe de mêlée. |

[La géométrie effective](C:/Users/paolo/Documents/dungeon-draft-v-2/battle/mastery_combat_adapter.gd:800) constitue l’autorité de l’effet. En particulier, une Volée garde souvent Flèche perforante parmi ses prérequis sélectionnés : lire d’abord `target_shape=FAN` et `piercing_enabled=false`, plutôt que déclencher un effet perforant parce qu’un ancien nœud figure encore dans le build.

## Carte exhaustive des 36 maîtrises

Fichiers de référence : [W — Colère du Péléide](C:/Users/paolo/Documents/dungeon-draft-v-2/data/characters/achilles/doctrines/wrath_of_peleus.tres:26), [C — Leçon de Chiron](C:/Users/paolo/Documents/dungeon-draft-v-2/data/characters/achilles/doctrines/lesson_of_chiron.tres:41), [A — Rempart d’Éaque](C:/Users/paolo/Documents/dungeon-draft-v-2/data/characters/achilles/doctrines/aegis_of_aeacus.tres:43), [X — Maîtrises avancées](C:/Users/paolo/Documents/dungeon-draft-v-2/data/characters/achilles/doctrines/advanced_masteries.tres:62).

`Même geste` signifie que les changements chiffrés et les indicateurs d’état n’exigent pas un nouveau dessin du personnage. Les nœuds ci-dessous sont disponibles dans le catalogue ; leur présence n’affirme pas qu’ils sont actuellement achetés par le joueur.

| Nom | Identifiant exact | Référence | Conséquence visuelle |
|---|---|---|---|
| Fureur lucide | `achilles_wrath_focused_fury` | W:26 | Même Frappe/Tir ; accent d’impact lors d’un bonus d’enchaînement réellement appliqué. |
| Entaille d’ouverture | `achilles_wrath_opening_slash` | W:72 | Même Frappe ; retour d’armure réduite sur la cible. |
| Élan meurtrier | `achilles_wrath_murderous_momentum` | W:122 | Même charge puis Frappe renforcée ; la charge elle-même n’inflige pas les dégâts de la Frappe. |
| Exécution | `achilles_wrath_execution` | W:155 | Même Frappe/Tir ; accent d’impact conditionnel. |
| Sang pour sang | `achilles_wrath_blood_for_blood` | W:202 | Même geste offensif ; effet de bonus consommé. |
| Pas victorieux | `achilles_wrath_victorious_step` | W:238 | Déplacement optionnel gratuit, maximum 2 cases : réutiliser la locomotion, après choix. |
| Brise-formation | `achilles_wrath_break_formation` | W:323 | Retours de collision/déplacement et armure réduite ; même Frappe suivante. |
| Fléau de Troie | `achilles_wrath_scourge_of_troy` | W:354 | Variante `sweep` + effet linéaire. |
| Colère irrépressible | `achilles_wrath_irrepressible_wrath` | W:417 | Même Frappe/Tir ; bouclier additionnel après la première élimination sous condition de PV. |
| Œil du centaure | `achilles_chiron_centaur_eye` | C:41 | Même `bow` ; bonus après déplacement. |
| Allonge du Pélion | `achilles_chiron_pelion_reach` | C:102 | Même `bow`, portée 3–8 ; durée/longueur de trajet liée à la cible. |
| Tir rapproché | `achilles_chiron_close_shot` | C:173 | Même `bow`, portée 1–5, impact avec poussée 1. |
| Angle impossible | `achilles_chiron_impossible_angle` | C:211 | Pas orthogonal optionnel d’une case après Percée ; locomotion existante. |
| Flèche d’arrêt | `achilles_chiron_stopping_arrow` | C:245 | Même `bow` ; retour de perte de PM à l’impact. |
| Flèche perforante | `achilles_chiron_piercing_arrow` | C:282 | Même `bow`, projectile traversant deux cibles. |
| Chasse mobile | `achilles_chiron_mobile_hunt` | C:357 | Même tir et déplacement ; bonus et engagement sont chiffrés. |
| Ligne de mort | `achilles_chiron_death_line` | C:409 | Même `bow`, projectile renforcé jusqu’à trois cibles. |
| Volée du centaure | `achilles_chiron_centaur_volley` | C:457 | Variante `volley`, trois branches vers les cellules résolues. |
| Garde active | `achilles_aeacus_active_guard` | A:43 | Effet d’absorption existant puis accent de la prochaine technique offensive. |
| Garde orientée | `achilles_aeacus_directional_guard` | A:80 | Même geste de bouclier ; direction conservée et retours d’impact orientés. |
| Ancrage d’airain | `achilles_aeacus_bronze_anchor` | A:114 | Maintien de protection/aura ; pas de déplacement du corps pour signaler les immunités. |
| Réplique | `achilles_aeacus_riposte` | A:192 | Même Frappe manuelle renforcée ; ce n’est pas le Contre automatique. |
| Mur aux flèches | `achilles_aeacus_arrow_wall` | A:241 | Effet projectile arrêté/réduit sur la Garde ; aucun nouveau lancer manuel. |
| Bouclier brisé | `achilles_aeacus_broken_shield` | A:316 | Dissipation de Garde, puis même charge sur une distance éventuellement supérieure. |
| Bastion mobile | `achilles_aeacus_mobile_bastion` | A:351 | Charge existante + impact de bouclier autour de l’arrivée. |
| Contre d’Éaque | `achilles_aeacus_counter` | A:392 | Frappe automatique à 70 % : feedback sprite à la résolution réelle. |
| Rempart des Myrmidons | `achilles_aeacus_myrmidon_rampart` | A:447 | Même armé de Garde + trois cases de barrière persistante. |
| Sommet Colère | `achilles_summit_wrath` | X:62 | Même gestes ; palette/intensité de doctrine ; Pas victorieux devient plus largement déclenchable. |
| Sommet Chiron | `achilles_summit_chiron` | X:113 | Même `bow`/`volley` ; +1 portée maximale, seuils de déplacement réduits. |
| Sommet Rempart | `achilles_summit_aeacus` | X:157 | Même `guard` ; effet renforcé, seuil d’absorption 8 %. |
| Prédateur du champ de bataille | `achilles_junction_battlefield_predator` | X:302 | Même Frappe/Tir ; portée effective temporaire, sans déplacement artificiel d’Achille pour toucher. |
| Vengeur d’airain | `achilles_junction_bronze_avenger` | X:393 | Même Frappe avec conversion d’absorption, puis effet de restauration de Garde. |
| Sentinelle du Pélion | `achilles_junction_pelion_sentinel` | X:441 | Tir automatique à 60 % après projectile contré ; feedback de flèche à la résolution réelle. |
| Fléau des Troyens | `achilles_apotheosis_scourge_trojans` | X:479 | Frappe automatique à 50 % après première élimination ; distinct du nœud Fléau de Troie. |
| Trait du destin | `achilles_apotheosis_fate_shot` | X:517 | Même tir ; origine du projectile choisie entre départ et arrivée de Percée. Le corps reste à sa cellule actuelle. |
| Le héros invincible | `achilles_apotheosis_invincible_hero` | X:555 | Choix à l’activation suivante : nouvelle protection à 50 % ou conversion vers prochaine Frappe ; effets distincts, jamais les deux. |

Les capstones W/C/A de niveau 10 et 13 sont exclusifs dans leur doctrine ; Allonge et Tir rapproché sont également exclusifs. Les sommets demandent le niveau 13 et les jonctions/apothéoses le niveau 14. La [progression actuelle](C:/Users/paolo/Documents/dungeon-draft-v-2/data/runs/progression/odyssey/achilles_champion_progression_v0.tres:8) autorise ces niveaux, mais la Catabase normale à trois victoires atteint seulement le niveau 4 sans bonus. Les captures de kits évolués doivent donc annoncer leurs fixtures de haut niveau, avec des achats légalement validés, sans prétendre que toute la progression est accessible lors d’une partie fraîche.

## Ordre réel des actions et raccordement

1. Le [lancement manuel](C:/Users/paolo/Documents/dungeon-draft-v-2/battle/battle.gd) attend `UnitView.prepare_spell_visual`, donc le release du geste, puis `begin_cast` valide et dépense les PA une fois. Tir du Pélion et ses variantes portent maintenant un délai d’impact de 0,20 seconde : le projectile commence au release, sa résolution réelle arrive ensuite par le scheduler.
2. [SpellCaster.resolve_cast](C:/Users/paolo/Documents/dungeon-draft-v-2/core/spell_caster.gd) conserve son ordre cibles, impacts, déplacements, fin du cast. Le [MasteryCombatAdapter](C:/Users/paolo/Documents/dungeon-draft-v-2/battle/mastery_combat_adapter.gd) réserve les réactions de mouvement à cette étape. Pour un déplacement dont Battle possède le UnitView, le contexte porte `defer_automatic_reactions=true` : la file attend la réception réelle. Battle la vide après l’attente du mouvement et le contrôle de cycle de vie, avant HUD, `action_resolved` et déverrouillage. Bastion consomme alors la Garde, applique les dégâts et la poussée, et publie son fait visuel. Les casts sans contrôleur graphique conservent leur résolution immédiate. Une annulation visuelle après release recale le corps et règle une seule fois le gameplay déjà engagé ; la fermeture détruit la file avec son adaptateur.
3. Le [VFXManager](C:/Users/paolo/Documents/dungeon-draft-v-2/core/vfx_manager.gd) anime les sprites de flèche, impact, balayage, Garde, poussière et barrière. Le vrai `spell_cast` confirme le contact d’un projectile. Pour Bastion, le couple fait résolu et `unit_visual_movement_finished` autorise le choc à la réception ; les deux ordres d’arrivée des notifications sont acceptés. Rempart suit les cellules réellement enregistrées par l’adaptateur et leur suppression.
4. Les contres automatiques utilisent `cast_automatic` et publient `spell_visual_resolved` après les dégâts. Ils déclenchent un feedback sprite de 0,16 seconde, sans rejouer le geste manuel ni émettre `spell_cast`, ni consommer PA ou quota manuel.
5. Trait du destin fournit l’origine logique mémorisée par le profil de projectile. Le gestionnaire reçoit cette origine, les cellules cibles et `action_id` : le corps reste sur sa case actuelle.
6. Le [backend sprite v2](C:/Users/paolo/Documents/dungeon-draft-v-2/characters/achilles/2d/achilles_sprite_2d_backend.gd) utilise le résolveur partagé pour les gestes `attack`, `dash`, `bow`, `guard`, `sweep` et `volley` et conserve les alias historiques. La charge reste en vol jusqu’à la réception Battle, puis montre une réception courte de 0,08 seconde sans prolonger le verrou de l’action. Les réactions `hit` et `death` sont liées aux événements réels du UnitView.

Les effets d’objets ne changent pas l’arme dessinée. Pour la couverture visuelle, traiter en plus le [Clou d’Héphaïstos](C:/Users/paolo/Documents/dungeon-draft-v-2/data/items/definitions/odyssey/hephaestus_nail.tres) (impact derrière la cible), l’[Ancre de Thétis](C:/Users/paolo/Documents/dungeon-draft-v-2/data/items/definitions/odyssey/thetis_anchor.tres) (autre conversion de Garde à l’arrivée), le [Miroir d’Athéna](C:/Users/paolo/Documents/dungeon-draft-v-2/data/items/definitions/odyssey/athena_mirror.tres) (renvoi de projectile), le [Talon de Thétis](C:/Users/paolo/Documents/dungeon-draft-v-2/data/items/definitions/odyssey/thetis_heel.tres) et le [Fil des Moires](C:/Users/paolo/Documents/dungeon-draft-v-2/data/items/definitions/odyssey/fates_thread.tres) (protection réactive). Les autres objets modifient principalement chiffres, portées ou conditions ; réutiliser les gestes et dessiner seulement l’effet réellement résolu.

## Contrat de présentation et volume de production

[AchillesSpellVisualResolver](C:/Users/paolo/Documents/dungeon-draft-v-2/data/visuals/achilles/achilles_spell_visual_resolver.gd) expose `resolve(spell, unit = null, resolved_profile = {})`. Sans profil fourni, il lit `unit.mastery_nodes` et appelle le résolveur statique existant. Un profil fourni a priorité, notamment pour les changements temporaires de portée. Il ne consomme ni indicateur réactif ni quota, ne modifie ni Resource ni unité, et n’appelle aucun événement gameplay.

Le résultat comprend :

- Identités : `spell_id` original et `inherited_spell_id` canonique ; ce dernier normalise uniquement les alias historiques `achilles_spear_thrust`, `achilles_advance`, `achilles_sweep`, `achilles_guard`.
- Choix graphique : `action_family`, `variant`, `animation_stem`, `effect_variant`, `palette_variant` et `intensity_tier`.
- Données de lecture : `target_shape`, `maximum_targets`, `piercing_enabled`, `minimum_range`, `maximum_range`, `movement`, `guard_active`.
- Provenance : `selected_mastery_ids`, `selected_doctrine_ids`, `profile_source_ids`, sous forme de copies indépendantes.

Les valeurs `effect_variant` sont des intentions de présentation. Le résolveur ne crée pas d’effet et ne valide pas à lui seul sa fréquence, son déclenchement effectif, ses victimes ou son origine. Bastion exige une source de Garde restante, pas seulement un bouclier quelconque. Rempart conserve une cible personnelle `SINGLE` ; ses trois cellules restent portées par le système de barrière.

La production comprend **sept nouvelles familles** : `dash`, `bow`, `guard`, `sweep`, `volley`, `hit` et `death`. À quatre poses dessinées dans quatre directions, elles représentent **112 dessins de poses**, regroupés dans huit planches sources et **28 nouveaux clips**. Le [manifeste de production](C:/Users/paolo/Documents/dungeon-draft-v-2/assets/characters/Achilles/sprites_kit_v2/manifest.json) conserve également les douze clips historiques `idle`, `walk` et `attack`, soit **40 clips au total**. Les gestes `bow`, `guard`, `sweep` et `volley` ajoutent aux quatre poses les mêmes images de repos canoniques à l’ouverture et à la fermeture : ces six images de lecture par clip ne constituent pas six nouveaux dessins. L’estoc existant garde ses quatre orientations, avec un rythme contrôlé par le profil V2.

Ligne de mort, Bastion, Rempart, sommets et autres renforcements partagent ces gestes ; leurs sprites d’effet, leur géométrie, leur palette et leur intensité différencient les **36 maîtrises** sans exiger autant d’animations de corps. Le kit indépendant d’effets ajoute **24 dessins** : six animations de quatre images (`arrow`, `impact`, `sweep`, `guard`, `dust`, `barrier`), extraites mécaniquement de la [planche source](C:/Users/paolo/Documents/dungeon-draft-v-2/art/source/vfx/achilles_kit_v2/source_effects.png).

La cohérence des armes est explicite : `volley_N`, image de lecture 3, réutilise le dessin de libération de l’arc `base_N[6]` afin de conserver le bouclier au dos. Cette substitution est déclarée dans `alignment.json` et tracée dans le manifeste ; elle change seulement la référence de texture du clip, sans modifier les pixels des sources ni des atlas.

[Treize tests ciblés](C:/Users/paolo/Documents/dungeon-draft-v-2/test/unit/test_achilles_spell_visual_resolver.gd) couvrent le routage des quatre bases, les alias, les copies de Spell, Fléau/perforation/Ligne/Volée, Rempart, Bastion avec sa source de Garde, les sommets, la priorité d’un profil fourni et l’absence de mutation. Ils ne constituent pas une validation visuelle en jeu ; la passe de rendu et le harness de combat restent nécessaires.
