# Dungeon Draft VFX Lab

Laboratoire isole de six prototypes visuels 2D isometriques construits uniquement
avec GDScript, primitives CanvasItem, shaders proceduraux et composants de
particules calcules. Aucun asset externe et aucune logique de gameplay ne sont
charges par le Lab.

## Ouvrir

Ouvrir puis executer `res://tools/labs/vfx_lab/VFXLab.tscn` (F6 dans Godot).

- `1` a `6` selectionnent et jouent un effet ;
- `Espace` joue ; `R` rejoue ; `Echap` nettoie ;
- l'interface expose 0.25x, 0.5x, 1x, 2x et un seed reproductible.

## Architecture

- `components/vfx_lab_effect.gd` possede le contrat de cycle de vie et cleanup ;
- `procedural_particle_burst.gd`, `procedural_pulse_ring.gd`,
  `procedural_trail_ribbon.gd` et `procedural_lightning_bolt.gd` sont composes
  par les six effets ;
- `shaders/` contient les surfaces d'energie, de bouclier et de residu ;
- chaque effet recoit ses positions, sa trajectoire ou sa liste de cibles depuis
  le Lab. Il ne calcule aucune portee, zone, collision, statistique ou degat.

Les scenes de production, `VFXManager`, `SpellCaster`, `Battle`, `Unit` et les
ressources de sorts ne sont pas modifies. Le Lab est un candidat de revue
visuelle, pas une integration runtime.
