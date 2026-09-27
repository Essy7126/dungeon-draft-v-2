extends RefCounted
## Screen directions after the battlefield's isometric projection.
const Art := preload("passe_rive_s20_data.gd")
const CANONICAL := {
	"E": "E",
	"SE": "SE",
	"S": "S",
	"SW": "SE",
	"W": "E",
	"NW": "NE",
	"N": "N",
	"NE": "NE",
}
const AXES := {
	"E": Vector2(1, 0),
	"SE": Vector2(2, 1),
	"S": Vector2(0, 1),
	"SW": Vector2(-2, 1),
	"W": Vector2(-1, 0),
	"NW": Vector2(-2, -1),
	"N": Vector2(0, -1),
	"NE": Vector2(2, -1),
}


static func source(clip: String, facing: String) -> String:
	var key := clip + "_" + str(CANONICAL.get(facing, "E"))
	return key if Art.REGIONS.has(key) else ""


static func axis(facing: String) -> Vector2:
	var vector: Vector2 = AXES.get(facing, Vector2.RIGHT)
	return vector.normalized()


static func local_axis(facing: String) -> Vector2:
	return axis(str(CANONICAL.get(facing, "E")))


static func pose_index(clip: String, facing: String, logical_frame: int) -> int:
	# This painted angle opens the string hand one drawing early. Keep full draw
	# until the existing gameplay release at frame 7, including the SW mirror.
	if clip == "PR_VOLLEY" and CANONICAL.get(facing, "E") == "SE" and logical_frame == 6:
		return 5
	return logical_frame
