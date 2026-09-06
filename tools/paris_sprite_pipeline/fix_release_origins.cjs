const fs = require('node:fs');
function patch(file, edits) {
  const original = fs.readFileSync(file, 'utf8');
  const nl = original.includes('\r\n') ? '\r\n' : '\n';
  let source = original.replaceAll('\r\n', '\n');
  for (const [from, to] of edits) {
    if (!source.includes(from)) throw new Error(`Missing block in ${file}: ${from}`);
    source = source.replace(from, to);
  }
  fs.writeFileSync(file, source.replaceAll('\n', nl));
}
patch('data/visuals/paris/paris_sprite_visual_profile.gd', [[
`@export var infernal_cast_origins: Dictionary = {
\t"N": Vector2(10, -56), "E": Vector2(30, -48),
\t"S": Vector2(-30, -48), "W": Vector2(-10, -56),
}`, `# Measured on native release poses; see characters/paris/release_origins.md.
@export var infernal_cast_origins: Dictionary = {
\t"N": Vector2(46.90, -55.65), "E": Vector2(46.20, -58.45),
\t"S": Vector2(-46.20, -58.45), "W": Vector2(-46.90, -55.65),
}
@export var spectral_spell_origins: Dictionary = {
\t"N": Vector2(27.30, -25.90), "E": Vector2(-4.90, -48.65),
\t"S": Vector2(4.90, -48.65), "W": Vector2(-27.30, -25.90),
}
@export var infernal_spell_origins: Dictionary = {
\t"N": Vector2(34.65, -71.05), "E": Vector2(35.00, -52.50),
\t"S": Vector2(-35.00, -52.50), "W": Vector2(-34.65, -71.05),
}
@export var infernal_pull_origins: Dictionary = {
\t"N": Vector2(-28.00, -35.35), "E": Vector2(-29.05, -41.65),
\t"S": Vector2(29.05, -41.65), "W": Vector2(28.00, -35.35),
}`], [
`\t\t"N": Vector2(10, -58), "E": Vector2(29, -50),
\t\t"S": Vector2(-29, -50), "W": Vector2(-10, -58),`,
`\t\t"N": Vector2(38.85, -57.05), "E": Vector2(43.75, -45.50),
\t\t"S": Vector2(-43.75, -45.50), "W": Vector2(-38.85, -57.05),`], [
'\n\nfunc validation_error(candidate: SpriteFrames) -> StringName:\n',
`

func release_origin(form: StringName, direction: String, stem: String, action_id: StringName) -> Vector2:
\tvar origins := infernal_cast_origins if form == &"infernal" else cast_origins
\tif stem == "cast":
\t\torigins = infernal_spell_origins if form == &"infernal" else spectral_spell_origins
\t\tif form == &"infernal" and action_id == &"cast:paris_infernal_pull":
\t\t\torigins = infernal_pull_origins
\t# Profile coordinates were measured at 0.35; keep the same attachment if
\t# an intentional sprite display scale changes without moving the root.
\treturn (origins.get(direction, origins["E"]) as Vector2) * (display_scale / 0.35)


func validation_error(candidate: SpriteFrames) -> StringName:
`]]);
patch('characters/paris/paris_iso_unit_view.gd', [[
`\tif _combat_form == &"infernal" and profile != null:
\t\treturn profile.infernal_cast_origins.get(_facing, Vector2(0, -48))
\treturn super.get_default_cast_effect_origin()`,
`\tif profile != null:
\t\treturn profile.release_origin(_combat_form, _facing, _stem, _pending_action_id)
\treturn super.get_default_cast_effect_origin()`]]);
