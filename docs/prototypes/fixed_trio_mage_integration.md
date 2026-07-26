# Trio fixe et intégration technique du Mage

## Portée

Le prototype principal présente puis lance une équipe ordonnée :

1. Elfe ;
2. Mage ;
3. Gardien historique temporaire.

La run `res://data/runs/fixed_trio_prototype_run.tres` reprend exactement les
trois salles du prototype Elfe : Le Gué, La Forge et l’Élite Brute. Tous les
pools de récompenses, reliques, équipements, événements, malus et nœuds de run
restent vides. La progression existante de l’Elfe, ses transitions et son écran
terminal restent ceux du cycle de run partagé.

Le Mage est intégré techniquement comme lanceur de sorts pur. Son système de disciplines et sa progression ne sont pas encore conçus.

Le Gardien occupe seulement le troisième emplacement du prototype. Il conserve
ses données et son rendu historiques ; aucune fausse représentation 3D ne lui
est attribuée.

## Provenance du laboratoire

La référence validée est le commit
`028c4f0f68ac9b778acdad4d2b59c18a2e471884`,
`test(mage): add isolated Godot animation baseline`. Le commit n’a pas été
cherry-pické : chaque fichier a d’abord été audité face au pipeline de
production actuel.

| Fichier du commit laboratoire | Classification | Décision |
| --- | --- | --- |
| `assets/characters/mage/mage_godot_baseline.glb` | `IMPORT_AS_IS` | Modèle, rig, skin et six clips validés repris sans régénération. |
| `assets/characters/mage/mage_godot_baseline.glb.import` | `IMPORT_AS_IS` | Recette d’import et UID validés conservés. |
| `assets/characters/mage/mage_godot_baseline_texture_0.png` | `IMPORT_AS_IS` | Texture validée reprise sans conversion. |
| `assets/characters/mage/mage_godot_baseline_texture_0.png.import` | `ADAPT_TO_CURRENT_ARCHITECTURE` | UID, source et MD5 conservés ; la recette de production utilise la compression VRAM/S3TC (`compress/mode=2`) au lieu du mode non-VRAM du laboratoire (`compress/mode=0`). |
| `tests/characters/mage/MageAnimationValidation.tscn` | `LAB_ONLY` | Scène de métrique, boutons et captures exclue du jeu. |
| `tests/characters/mage/mage_animation_validation.gd` | `LAB_ONLY` | Contrats réécrits dans le profil et les tests GUT de production. |
| `tests/characters/mage/mage_animation_validation.gd.uid` | `LAB_ONLY` | UID du runner de laboratoire exclu. |
| `tests/characters/mage/mage_import_audit.gd` | `LAB_ONLY` | Audit isolé remplacé par les tests de provenance/profil. |
| `tests/characters/mage/mage_import_audit.gd.uid` | `LAB_ONLY` | UID de l’audit isolé exclu. |
| `tests/characters/mage/screenshots/mage_cast_release_iso.png` | `LAB_ONLY` | Capture de revue exclue. |
| `tests/characters/mage/screenshots/mage_death_2667_iso.png` | `LAB_ONLY` | Capture de revue exclue. |
| `tests/characters/mage/screenshots/mage_death_final_side.png` | `LAB_ONLY` | Capture de revue exclue. |
| `tests/characters/mage/screenshots/mage_hit_iso.png` | `LAB_ONLY` | Capture de revue exclue. |
| `tests/characters/mage/screenshots/mage_idle_iso.png` | `LAB_ONLY` | Capture de revue exclue. |
| `tests/characters/mage/screenshots/mage_run_iso.png` | `LAB_ONLY` | Capture de revue exclue. |
| `tests/characters/mage/screenshots/mage_sockets_iso.png` | `LAB_ONLY` | Capture de revue exclue. |
| `tests/characters/mage/screenshots/mage_walk_iso.png` | `LAB_ONLY` | Capture de revue exclue. |

Il n’existe aucun fichier `UNKNOWN` ou `OBSOLETE` à importer physiquement. La
seule adaptation de fichier est la recette d’import de texture décrite
ci-dessus. Les contrats observés dans les scripts `LAB_ONLY` ont aussi été
adaptés aux abstractions actuelles au lieu de copier leur runner, leur UI et
leurs chemins de sortie.

## Pipeline visuel partagé

Le comportement commun vit désormais dans deux composants :

```text
CharacterVisual3D
├── ElfVisual3D
└── MageVisual3D

CharacterIsoUnitView
├── ElfIsoUnitView
└── MageIsoUnitView
```

`CharacterVisual3D` possède la découverte du modèle, le pilotage de
l’`AnimationPlayer`, les signaux, les retours vers Idle, l’interruption par la
mort, le release de cast et les mounts génériques. `ElfVisual3D` conserve ses
constantes et son API publique historique. `MageVisual3D` contient uniquement
le mapping de clips, le temps de release absolu et la création des deux mounts
dictés par son rig.

`CharacterIsoUnitView` concentre le `SubViewport`, le `World3D` isolé, la caméra
orthographique, les lumières, l’alignement du pied, l’ombre, l’orientation, les
priorités Idle/Movement/Cast/Hit/Death et les connexions au `Unit`. Les scènes
Elfe et Mage instancient chacune leur vrai profil 3D dans ce même pipeline. Le
`UnitView` logique reste l’unique objet déplacé et trié dans la salle.

Chaque vue et chaque aperçu :

- possède son propre monde 3D ;
- désactive les entrées GUI du viewport de combat ;
- coupe la mise à jour du viewport lors de sa sortie ;
- libère son instance visuelle lors d’un remplacement ;
- déconnecte les signaux de l’unité et de dégâts à la destruction.

## Contrat d’animation du Mage

| Action sémantique | Clip importé |
| --- | --- |
| Idle | `DD_Mage_Idle` |
| Walk | `DD_Mage_Walk` |
| Run | `DD_Mage_Run` |
| Cast | `DD_Mage_Cast` |
| Hit | `DD_Mage_Hit` |
| Death | `DD_Mage_Death` |

Le modèle ne contient pas d’animation Attack. Aucune méthode `play_attack`
n’existe sur son profil et aucune résolution globale ne convertit Attack vers
Cast. Un sort appelle explicitement `play_cast`, tandis que l’attaque de base
est désactivée par `UnitData.basic_attack_enabled = false`. Ce drapeau est
propagé au `Unit`, lu génériquement par la barre d’action et vérifié par
`Battle`, sans branche sur le nom ou l’identifiant du Mage.

Walk est déclenché par les déplacements normaux. Run n’est joué que lorsque le
pipeline existant demande explicitement son retour visuel de course. La fin de
Walk/Run revient à Idle après stabilisation du déplacement 2D. Hit revient à
Idle si l’unité vit encore. Death verrouille le profil et ne revient jamais à
Idle.

## Release et origine du projectile

Le release de `DD_Mage_Cast` est absolu : `0.933333 s`, indépendamment de la
durée normalisée du clip. Il est émis exactement une fois par cast. Une
interruption avant ce temps, la mort, la destruction de la vue ou une nouvelle
génération de cast invalident le release précédent.

`MageVisual3D` crée au runtime :

- `RightHandAttachment/ProjectileMount` sur le bone `RightHand` ;
- `LeftHandAttachment/CastSupportMount` sur le bone `LeftHand`.

`ProjectileMount` est le mount de cast par défaut. Après
`cast_release_reached`, le pipeline de sort existant émet `EventBus.spell_cast`.
`VFXManager` demande alors l’origine projetée au vrai `UnitView`, qui la calcule
depuis la position courante de `ProjectileMount`. Le visuel ne calcule ni dégâts
ni ciblage.

## Données et sorts

`res://data/units/alliés/mage.tres` définit :

- `unit_id = &"mage"` ;
- les statistiques historiques explicites du Mage : 100 PV, 10 initiative,
  6 PA, 3 PM et 20 puissance ;
- `MageIsoUnitView.tscn` pour le combat ;
- `MageVisual3D.tscn` pour les aperçus ;
- aucune énergie, aucun trait de draft, aucune discipline ;
- `basic_attack_enabled = false` ;
- deux sorts équipés sur les quatre emplacements disponibles.

Les sorts sont `mage_fireball` et le Mur de glace existant. La boule de feu du
Mage est une ressource distincte de `elf_fireball`, utilise le VFX actif et ne
porte aucun `discipline_id`. Le Mage ne gagne donc aucun XP. Le sort de frappe
historique a été retiré de son loadout : il ne sert pas de fausse attaque au
bâton.

L’Elfe conserve ses quatre sorts, ses quatre disciplines, ses rangs, ses
améliorations et son identifiant `elf_fireball` sans modification.

## Présentation du groupe

Le bouton primaire `Trio fixe — prototype` du titre ouvre
`PartyPresentationScreen.tscn`. Il ne lance pas le run directement. Les entrées
Prototype Elfe, validation technique à trois et draft historique restent
disponibles.

L’écran affiche `Votre groupe`, trois cartes ordonnées et les boutons
`Commencer la run` / `Retour`. Les cartes lisent uniquement `UnitData` :
nom, rôle, résumé, nombre de sorts, disciplines/progression, scène d’aperçu et
badge optionnel. Elles ne testent aucun nom ni identifiant de héros.

`CharacterPreview3D` accepte un `UnitData` ou une `PackedScene`. Il instancie le
vrai `ElfVisual3D` ou `MageVisual3D` en Idle dans son propre monde. En l’absence
de scène, le Gardien affiche explicitement `Aperçu 3D indisponible`, sans faux
modèle. Son badge `Troisième héros provisoire` vient de ses données.

Le démarrage appelle l’API existante
`GameManager.start_preconfigured_run(run_data, party_members)`. Aucun chemin de
démarrage propre au trio n’a été ajouté.

## Persistance et nettoyage

`GameManager` construit une seule fois les trois `Unit` et leurs trois
`CharacterRunState`. Entre Le Gué, La Forge et l’Élite, le même Mage conserve :

- son instance `Unit` et ses PV ;
- son `CharacterRunState` ;
- son `SpellLoadoutState`, ses sorts connus et équipés ;
- ses scènes de combat et d’aperçu ;
- le même profil, les mêmes mounts et le même contrat de release.

Une nouvelle run ou `cleanup_run_state` dispose les états et déconnecte les
loadouts. La reconstruction du HUD supprime immédiatement les anciens boutons
et leurs lambdas. Les vues libérées déconnectent leurs signaux et un cast
appartient à une génération de vue précise : un ancien Mage ne peut donc plus
émettre de release, créer un VFX, recevoir Hit ou modifier la nouvelle run.

## Défauts connus et suivi Cascadeur

Le défaut validé du laboratoire est conservé volontairement :

- Walk pénètre le sol d’environ 4 cm selon la pose ;
- Death descend davantage en fin de clip.

Ces défauts n’empêchent ni ciblage, ni grille, ni release, ni lecture du
personnage. Ils ne sont pas compensés par un offset runtime spécifique qui
risquerait de casser le pivot ou les autres clips. Une correction future doit
être faite dans la source d’animation Cascadeur, puis repasser l’audit
d’import complet avant de remplacer le GLB.

## Validation automatisée

Les suites ciblées ajoutées couvrent :

- provenance et exclusion des fichiers `LAB_ONLY` ;
- six animations exactes, absence d’Attack et release unique à `0.933333 s` ;
- `ProjectileMount`, interruption, mort et destruction ;
- données Mage, sorts sans discipline et absence d’XP ;
- composition, ordre, états, loadouts et persistance sur trois salles ;
- cycle HUD Elfe → Mage → Gardien → Elfe ;
- présentation, vrais aperçus, fallback, démarrage, retour et libération ;
- remplacement de run, signaux et releases obsolètes.

Résultats ciblés obtenus sous Godot 4.6.3 :

- profil visuel Mage : 8/8 ;
- contrat trio/HUD/persistance : 6/6 ;
- présentation et aperçus : 6/6 ;
- cycle de vie et nettoyage : 5/5.

Les diagnostics de compatibilité GUT 9.7.1 avec Godot 4.6.3
(`AccessibilityServer` et le retour `null` vers `StringName`) restent ceux de
la base de tests existante ; ils apparaissent après un verdict GUT réussi et
ne sont pas masqués.

## Limites et prochaines étapes

- Concevoir les disciplines, l’XP, les rangs et les améliorations du Mage.
- Remplacer le Gardien provisoire par le troisième héros final et lui fournir
  un vrai profil d’aperçu.
- Corriger Walk/Death dans Cascadeur, puis revalider l’import.
- Mesurer le coût de plusieurs `SubViewport` simultanés sur la cible matérielle.
