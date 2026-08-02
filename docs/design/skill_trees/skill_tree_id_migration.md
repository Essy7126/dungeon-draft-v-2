# Manifeste de migration des identifiants d’arbres

Convention canonique : `<character>_<discipline>_<node_slug>`. Les noms affichés ne sont jamais utilisés comme clés logiques. Aucun alias temporaire n’est conservé : aucune sauvegarde de production ni ressource active ne dépendait des identifiants retirés.

## Règles appliquées à la preview

| Famille preview | Préfixe runtime | Ressource active |
|---|---|---|
| `elfe.archer.*` | `elf_archer_*` | `res://data/characters/elf/disciplines/archer.tres` |
| `elfe.assassin.*` | `elf_assassin_*` | `res://data/characters/elf/disciplines/assassin.tres` |
| `elfe.mage.*` | `elf_mage_*` | `res://data/characters/elf/disciplines/mage.tres` |
| `elfe.soigneur.*` | `elf_healer_*` | `res://data/characters/elf/disciplines/healer.tres` |
| `mage.pyromancie.*` | `mage_pyromancy_*` | `res://data/characters/mage/disciplines/fire.tres` |
| `mage.cryomancie.*` | `mage_cryomancy_*` | `res://data/characters/mage/disciplines/ice.tres` |
| `mage.foudromancie.*` | `mage_fulguromancy_*` | `res://data/characters/mage/disciplines/lightning.tres` |
| `mage.geomancie.*` | `mage_geomancy_*` | `res://data/characters/mage/disciplines/earth.tres` |
| `guerrier.brutalite.*` | `warrior_breaker_*` | `res://data/characters/warrior/disciplines/breaker.tres` |
| `guerrier.assaut.*` | `warrior_assault_*` | `res://data/characters/warrior/disciplines/assault.tres` |
| `guerrier.furie.*` | `warrior_fury_*` | `res://data/characters/warrior/disciplines/fury.tres` |
| `guerrier.rempart.*` | `warrior_bulwark_*` | `res://data/characters/warrior/disciplines/bulwark.tres` |

Pour les onze arbres générés depuis la preview, le dernier segment de l’identifiant preview devient le `node_slug`. L’identifiant preview comporte lui-même la coquille `cur_incandescent`; elle est conservée sous `elf_mage_cur_incandescent` afin de ne pas inventer une autre clé. L’Archer garde ses identifiants runtime stables déjà testés, tous préfixés `elf_archer_`.

## Migrations de données actives

| Ancien identifiant | Nouvel identifiant | Ressource concernée | Raison |
|---|---|---|---|
| `elf_assassin_backstab` | `elf_assassin_dans_le_dos` | `res://data/characters/elf/disciplines/assassin.tres` | Alignement sur le nœud R2 de la preview. |
| `elf_assassin_venomous_blade` | `elf_assassin_lame_venimeuse` | même ressource | Alignement sur le slug preview et remplacement de l’arbre partiel. |
| `elf_mage_incandescent_core` | `elf_mage_cur_incandescent` | `res://data/characters/elf/disciplines/mage.tres` | Alignement exact sur l’identifiant preview. |
| `elf_mage_persistent_embers` | `elf_mage_braises_persistantes` | même ressource | Alignement preview ; l’effet devient bien un delta de durée. |
| `elf_healer_abundant_sap` | `elf_healer_seve_abondante` | `res://data/characters/elf/disciplines/healer.tres` | Alignement preview. |
| `elf_healer_protective_bark` | `elf_healer_ecorce_protectrice` | même ressource | Alignement preview. |
| `mage_fire` | `mage_pyromancy` | sort Mage, arbre Pyromancie, thème HUD | Une discipline distincte et canonique par sort. |
| `mage_ice` | `mage_cryomancy` | sort Mage, arbre Cryomancie | Idem. |
| `mage_lightning` | `mage_fulguromancy` | sort Mage, arbre Foudromancie | Idem. |
| `mage_earth` | `mage_geomancy` | sort Mage, arbre Géomancie | Idem. |
| `warrior_shove` | `warrior_heavy_strike` | `res://data/spells/Guerrier/frappe_lourde.tres` | L’ancien sort ne figure plus dans la preview ; remplacement par la racine Brutalité. |
| `warrior_war_mark` | `warrior_charge` | `res://data/spells/Guerrier/charge.tres` | Remplacement par la racine Assaut ; aucune logique de marque conservée. |
| `warrior_execution` | `warrior_whirlwind` | `res://data/spells/Guerrier/tourbillon.tres` | Remplacement par la racine Furie. |
| `warrior_stomp` | `warrior_guard` | `res://data/spells/Guerrier/garde.tres` | Remplacement par la racine Rempart. |
| `warrior_executioner` | supprimé | anciennes disciplines Bourreau | Discipline et capacités absentes de la preview. |
| `warrior_ravager` | supprimé | anciennes disciplines Saccageur | Discipline et capacités absentes de la preview. |
| `warrior_breaker_long_hook` | supprimé, sans alias | ancien modificateur `driving_shove` | Aucun nœud ou branche visuelle correspondant n’existe dans la preview ; la référence pendante ne représentait donc aucune exclusion valide. |
| `guardian` / `Gardien.tres` | supprimé | `res://data/units/alliés/Gardien.tres` | Aucun référencement actif ; le trio de production est Elfe, Mage, Guerrier. |

## Ressources partielles retirées

Les rangs R1–R2 externes d’Assassin, Mage elfe et Soigneur, leurs six upgrades et leurs six modifiers ont été supprimés après intégration dans les arbres complets. Le statut dédié `elf_venomous_blade_poison.tres` est remplacé par un `StatusData` construit depuis les champs du modificateur générique. Les ressources Archer externes restent actives et inchangées dans leur organisation.

## Garanties

- Les 216 identifiants de choix sont uniques.
- Tous les prérequis et exclusions pointent vers un identifiant du même arbre.
- Les exclusions R2 sont symétriques et définitives.
- Aucune clé logique ne dépend d’un chemin de fichier ou d’un libellé localisé.
- Le test structurel énumère les 16 configurations finales valides de chacun des douze arbres.
