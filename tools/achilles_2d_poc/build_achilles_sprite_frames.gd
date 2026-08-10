extends SceneTree

## Run after build_achilles_frames.gd and an editor filesystem scan.
## It assembles the imported normalized PNGs into the requested SpriteFrames.

const OUTPUT := "res://assets/characters/Achilles/achilles_sprite_frames.tres"
const CONFIG := {
	"idle_SE": {"prefix": "idle", "count": 12, "fps": 9.0, "loop": true},
	"walk_SE": {"prefix": "walk", "count": 18, "fps": 10.0, "loop": true},
	"attack_SE": {"prefix": "attack", "count": 18, "fps": 12.0, "loop": false},
}


func _initialize() -> void:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	for animation_name in CONFIG:
		var config: Dictionary = CONFIG[animation_name]
		var key := StringName(animation_name)
		frames.add_animation(key)
		frames.set_animation_speed(key, config.fps)
		frames.set_animation_loop(key, config.loop)
		for index in range(config.count):
			var path := "res://assets/characters/Achilles/processed/%s_%02d.png" % [config.prefix, index]
			var texture := load(path) as Texture2D
			if texture == null:
				push_error("Achilles SpriteFrames builder: missing imported texture %s." % path)
				quit(1)
				return
			frames.add_frame(key, texture)
	var error := ResourceSaver.save(frames, OUTPUT)
	if error != OK:
		push_error("Achilles SpriteFrames builder: cannot save %s (error %d)." % [OUTPUT, error])
		quit(1)
		return
	print("ACHILLES_SPRITE_FRAMES_OK: %s" % OUTPUT)
	quit()
