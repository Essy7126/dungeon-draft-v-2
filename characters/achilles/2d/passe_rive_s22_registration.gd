extends RefCounted
## Pose-zero registration against exploration's 214 px neutral stature.
## These constant stance corrections preserve authored crouching and recoil.
## They never fit a frame's bounds, weapon reach, or VFX to a target rectangle.
const STANCE := {
	"PR_BLADES": 0.90,
	"PR_DAGGER": 0.94,
	"PR_EMBER": 1.0,
	"PR_RIPOSTE": 0.90,
	"PR_SEAL": 1.0,
	"PR_SHOT": 1.0,
	"PR_VOLLEY": 0.96,
}


static func stance_scale(clip: String) -> float:
	return float(STANCE.get(clip, 1.0))
