# Achille — modèle et pool d’animations Meshy V3

Date : 2026-08-23
Statut : **CURRENT — VALIDATION_GRAPHIQUE_PASS**

## Objectif

La V3 remplace, dans le candidat runtime de L’Odyssée, l’ancien corps canonique
animé par retarget. Elle utilise directement le modèle Meshy avec son skin, son
rig de 24 os et ses 20 animations natives. Aucun transfert d’animation vers le
rig V1/V2 n’est effectué.

Les assets V1 et V2 ne sont ni écrasés ni supprimés. Ils restent versionnés
comme jalons historiques et solutions de comparaison.

## Asset livré

| Élément | Valeur |
|---|---|
| Asset runtime | `res://assets/characters/Achilles/3d/achilles_meshy_animation_pool_v3.glb` |
| SHA-256 | `95F634EF49B04F8A01FC4B13D223F75DC3B2C7AA01CB2319194D078BF1D02FEE` |
| Taille | 9 191 356 octets |
| Type | modèle Meshy direct, sans retarget |
| Mesh | 1 mesh skinné, 34 847 sommets, 49 998 polygones |
| Rig | 24 os, racine de mouvement `Hips` |
| Matériaux/textures | 1 matériau, 1 texture 2 048 × 2 048 |
| Animations | 20 clips Meshy natifs |
| Équipement intégré | aucun |

La source Meshy immuable porte le SHA-256
`21DAD4EE17146F3A1430A684C7EFD14544701100307C233D4E5B27812EF58770`.
Le manifeste versionné décrit l’export reproductible et la signature exacte du
squelette :
`res://assets/characters/Achilles/3d/achilles_meshy_animation_pool_v3_manifest.json`.

## Affectations runtime

| Événement | Clip V3 |
|---|---|
| Repos | `Idle_11` |
| Marche, chemin de 1 à 5 cases | `Walking` à 75 %, 0,40 s par case |
| Course, chemin de 6 cases ou plus | `run_fast_3_inplace`, 0,20 s par case |
| Impact | `Hit_Reaction_1` |
| Lancement générique | `mage_soell_cast_7` |
| Frappe de lance | `Left_Slash` |
| Percée | `run_fast_3_inplace` |
| Balayage | `Charged_Upward_Slash` |
| Garde d’airain | `Sword_Parry_Backward_2` |
| Mort | fondu de l’adaptateur, aucun clip source |

La Resource courante est
`res://data/characters/achilles/animations_meshy_v3.tres`. Elle reste l’unique
table événement → clip utilisée par le personnage.

## Inventaire des 20 clips

| Clip | Rôle principal | Boucle attendue |
|---|---|---|
| `Alert` | alerte | oui |
| `Archery_Shot_3` | tir à distance | non |
| `Basic_Jump` | saut | non |
| `Charged_Spell_Cast` | sort chargé | non |
| `Charged_Upward_Slash` | attaque lourde | non |
| `Chest_Pound_Taunt` | provocation/amélioration | non |
| `Double_Combo_Attack` | combo double | non |
| `Draw_and_Shoot_from_Back_2` | préparation et tir | non |
| `Electrocution_Reaction` | réaction d’état | non |
| `Hit_Reaction_1` | impact | non |
| `Idle_11` | repos | oui |
| `Left_Slash` | taille gauche | non |
| `mage_soell_cast_7` | lancement de sort | non |
| `run_fast_3_inplace` | course rapide | oui |
| `Running` | course alternative | oui |
| `Simple_Kick` | coup de pied | non |
| `Sword_Judgment` | ultime | non |
| `Sword_Parry_Backward_2` | garde/parade | non |
| `Triple_Combo_Attack` | combo triple | non |
| `Walking` | marche | oui |

Le pool complet reste disponible pour de futures affectations de sorts. Une
animation non affectée n’est pas supprimée du GLB.

## Échelle dans les cartes peintes

Le profil `res://data/maps/painted/unit_profile_achilles.tres` impose :

- base : 1,72 ;
- minimum : 1,50 ;
- maximum : 1,90 ;
- forêt : 1,806 ;
- volcan : 1,8576 ;
- espace : 1,892.

Le profil V3 conserve une caméra orthographique 2,6 et emploie un billboard de
96 pixels avant la mise à l'échelle peinte. Le calibrage est comparé aux vraies
UnitView de l'Elfe, du Mage et du Guerrier. Les vrais identifiants ennemis de
L'Odyssée sont aussi reliés aux profils peints ; les billboards standard et
champion compensent leurs cadrages natifs afin de rester à ±5 % de la hauteur
rendue d'Achille.

## Root motion et autorité de la grille

La grille reste l’autorité de position. Le runtime neutralise localement les
translations de squelette indiquées par le profil sans réécrire les animations
Meshy. Les clips `Basic_Jump`, `Double_Combo_Attack`, `Simple_Kick`,
`Sword_Judgment`, `Sword_Parry_Backward_2` et `Triple_Combo_Attack` demandent une
attention particulière lors de la revue visuelle à cause de leur déplacement
de hanche important.

## Limites connues

- La source ne fournit aucune animation de mort ; le personnage disparaît par
  fondu.
- Le modèle Meshy n’embarque aucun équipement. Les contacts d’épée, de bouclier
  ou d’arc restent une future passe de sockets et d’équipement.
- Le portrait du grand HUD reste l’illustration 2D historique.
- Les cadrages et silhouettes ont été revus dans les trois cartes. Les appuis
  et transitions pourront encore bénéficier d'une passe vidéo dédiée.

## Validation

- Tests ciblés proportions/V3/locomotion/Odyssée : 35/35 tests,
  855 assertions.
- Studio d'animations : 19/19 tests, 208 assertions.
- Binding SHA-exact : 34/34 tests, 643 assertions.
- Full-flow graphique post-calibrage : à rejouer sur le prochain commit propre.

La V3, sa cadence et ses proportions unitaires sont validées ; la dernière
revue des trois salles reste à resceller.
