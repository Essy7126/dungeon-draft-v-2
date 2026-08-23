# Pool d'animations Achille V2

## Résultat intégré

Achille utilise désormais un GLB V2 qui conserve le modèle et le squelette canonique V1, puis lui ajoute les 20 animations Meshy retargetées. Le fichier contient 24 animations au total : 20 Meshy et les 4 animations natives `Anim_0.001`, `Anim_0.003`, `Anim_0.004` et `Anim_0.005`.

La V1 reste une entrée immuable. Le pipeline lit la V1 et la source Meshy, puis écrit uniquement une nouvelle sortie isolée.

| Fichier | Taille | SHA-256 |
|---|---:|---|
| `assets/characters/Achilles/3d/achilles_rig_v1.glb` | 16 136 348 octets | `CA162138B9BE6693210619C06BBDABF0FD486E3DC75460A2566CBE140B4A774F` |
| `assets/characters/Achilles/3d/achilles_rig_animation_pool_v2.glb` | 17 718 288 octets | `A2657FCE4C9B1C2B3AC424929B27D1E64B7C770FF090B0D462166FFB51B8E16E` |
| `Meshy_AI_Meshy_Merged_Animations (4).glb` (source locale, non versionnée) | 9 191 236 octets | `21DAD4EE17146F3A1430A684C7EFD14544701100307C233D4E5B27812EF58770` |

Le V2 exporté possède bien 52 os et la signature canonique `6CC796EE5D708EE1A7F884C028C457CA535A4D7B572A189B36DFE5EBAD62D65D`. Le retarget mappe 22 des 24 os Meshy. Les 30 os de doigts présents uniquement sur le squelette canonique restent en pose de repos et suivent leurs mains.

## Bibliothèque disponible

Les 20 clips Meshy sont conservés, même lorsqu'ils ne sont pas encore affectés à un sort :

| Clip exporté | Rôle proposé | État visuel |
|---|---|---|
| `achilles_v2__Alert` | alerte | disponible, non affecté |
| `achilles_v2__Archery_Shot_3` | tir | contact arc à revoir |
| `achilles_v2__Basic_Jump` | saut | root motion à revoir |
| `achilles_v2__Charged_Spell_Cast` | sort chargé | disponible, non affecté |
| `achilles_v2__Charged_Upward_Slash` | attaque lourde | contact arme à revoir |
| `achilles_v2__Chest_Pound_Taunt` | provocation/buff | disponible, non affecté |
| `achilles_v2__Double_Combo_Attack` | combo double | root et arme à revoir |
| `achilles_v2__Draw_and_Shoot_from_Back_2` | tir complet | contact arc à revoir |
| `achilles_v2__Electrocution_Reaction` | réaction électrique | disponible, non affecté |
| `achilles_v2__Hit_Reaction_1` | impact reçu | affecté |
| `achilles_v2__Idle_11` | idle alternatif | bras à polir |
| `achilles_v2__Left_Slash` | taille | contact arme à revoir |
| `achilles_v2__mage_soell_cast_7` | lancement de sort | affecté |
| `achilles_v2__run_fast_3_inplace` | course rapide | affecté |
| `achilles_v2__Running` | course alternative | disponible, non affecté |
| `achilles_v2__Simple_Kick` | coup de pied | root motion à revoir |
| `achilles_v2__Sword_Judgment` | attaque ultime | root et arme à revoir |
| `achilles_v2__Sword_Parry_Backward_2` | parade | contact arme à revoir |
| `achilles_v2__Triple_Combo_Attack` | combo triple | root et arme à revoir |
| `achilles_v2__Walking` | marche | affecté |

La liste structurée, les durées, les hashes et les statuts sont dans `assets/characters/Achilles/3d/achilles_animation_pool_v2_manifest.json`.

## Affectations actuelles

Le pool `data/characters/achilles/animations.tres` sépare les identifiants de gameplay des noms importés. Les clips restent donc réaffectables dans le Character Animation Studio sans modifier les sorts.

| Événement | Animation |
|---|---|
| repos | `Anim_0.004` |
| marche | `achilles_v2__Walking` |
| course | `achilles_v2__run_fast_3_inplace` |
| impact | `achilles_v2__Hit_Reaction_1` |
| lancement générique | `achilles_v2__mage_soell_cast_7` |
| `achilles_advance` | `achilles_v2__run_fast_3_inplace` |
| `achilles_guard` | `achilles_v2__Sword_Parry_Backward_2` |
| `achilles_spear_thrust` | `achilles_v2__Left_Slash` |
| `achilles_sweep` | `achilles_v2__Charged_Upward_Slash` |

Un sort cherche d'abord `cast:<spell_id>`, puis revient sur `cast` si aucun clip exact n'est affecté. Un nom absent ou invalide ne fait pas sortir Achille du rendu 3D : le backend utilise son fallback artistique stable.

La réaction `hit` est reliée aux impacts réellement résolus, sans émettre les signaux réservés aux sorts. `Percée` conserve son déplacement de grille autoritaire et resynchronise désormais la représentation d'Achille sur la cellule résolue ; son clip `run_fast` reste une gestuelle locale in-place.

## Marche et course par distance

La décision utilise la longueur réelle du chemin, en cases traversées :

- de 1 à 5 cases : marche ;
- à partir de 6 cases : course rapide.

Le seuil est configurable par `run_min_path_cells` dans le profil visuel V2. La grille reste la seule autorité pour la position : les translations locales du root sont neutralisées afin qu'une animation ne déplace pas l'unité hors de sa case.

Achille possède actuellement `max_mp = 3`. Une course automatique à 6 cases ne sera donc visible que lorsqu'un bonus de déplacement ou une future règle permet un chemin de cette longueur. Le comportement est déjà prêt et ne demande pas de nouveau retarget.

## Limites visuelles connues

Le résultat est un prototype structurel utilisable, pas encore une passe d'animation finale. Les courbes sont finies, les 20 clips ont été exportés, et l'erreur mesurée de transfert du root reste inférieure à `1e-5`. Les points à polir sont les bras et mains liés à l'écart A-pose/T-pose, le glissement des pieds, les boucles, et les contacts avec épée ou arc.

Les clips les plus chargés en root motion sont `Basic_Jump`, `Double_Combo_Attack`, `Simple_Kick`, `Sword_Judgment` et `Triple_Combo_Attack`. `Sword_Parry_Backward_2` reçoit aussi une neutralisation locale XYZ. Leur mouvement reste visuel : il ne modifie jamais la case de gameplay.

Les doigts n'ont pas d'animation Meshy dédiée. Pour des prises d'arme propres, il faudra créer des poses de main par clip. Il n'existe aucune animation de mort dans cette source ; la mort conserve le fallback de fondu de l'adapter.

## Reproduire l'export

Le workflow reproductible est décrit dans `tools/blender/achilles_animation_pool/README.md`. Il impose une sortie distincte et ne remplace jamais `achilles_rig_v1.glb`.
