# Effets de Paris

`ParisSpellVFXRouter` est appelé par `VFXManager` exclusivement pour les sorts de
`catabase_shadow_paris`. Les autres personnages gardent leur présentation.

Le fichier `assets/vfx/paris/sprites_v1/effects.tres` fournit huit animations de
quatre dessins : `arrow`, `frost`, `fire`, `vortex`, `impact`, `whip`, `hellfire`,
`transform`. Le rendu utilise ces images avec leur alpha natif ; les translations,
rotations et durées suivent les actions réelles.

Les quatre flèches voyagent pendant le délai d’impact du sort. Leurs impacts ne
sont confirmés que par le rapport de résolution. Une esquive sans autre effet,
un cast rejeté ou un projectile devenu obsolète ne fabrique pas de dégâts
visuels. La case d’impact d’une flèche du vortex est mémorisée avant l’attraction
de la cible.

Le fouet relie l’origine réelle du démon à la case frappée. Le Pas du vortex
utilise `caster_movement_from` et `caster_movement_to` du rapport canonique :
cette arrivée comprend déjà les réactions de terrain ou téléporteurs. La flèche
suivante part de la nouvelle vue, y compris l’élévation et le zoom de la map.

L’effet de transformation est attaché à la vue qui révèle la phase décidée par
`Unit`. Il suit les déplacements de cette vue et disparaît avec sa mort, son
annulation ou la fin des 0,90 s. Il n’applique ni bouclier, ni dégâts, ni soin.

Les IDs d’action empêchent de doubler une résolution. Le changement de scène et
la fin du combat annulent les effets encore présents. Le groupe de diagnostic
est `paris_spell_sprite_vfx`; `get_debug_state()` expose phase, origine, cibles,
animation et confirmation de l’impact.
