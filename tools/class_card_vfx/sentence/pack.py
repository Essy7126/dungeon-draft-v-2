"""Pack unchanged Blender render pixels; synthesize an original short bronze cue."""
import hashlib
import json
import math
import random
import struct
import wave
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[3]
SOURCE = ROOT / "art/source/vfx/sentence_rempart"
OUT = ROOT / "vfx/class_cards/sentence"
RENDER = ROOT / "artifacts/dev/class_card_vfx/sentence/hammer"
meta = json.loads((SOURCE / "manifest.json").read_text())
size = meta["size"]
atlas = Image.new("RGBA", (size * 8, size * 6))
frames = []
for index in range(meta["frames"]):
    path = RENDER / f"frame_{index + 1:04d}.png"
    frame = Image.open(path).convert("RGBA")
    assert frame.size == (size, size), path
    assert frame.getchannel("A").getextrema()[0] == 0, path
    box = frame.getbbox()
    if box and index < 43:
        assert box[0] > 0 and box[1] > 0 and box[2] < size and box[3] < size, (index, box)
    atlas.paste(frame, ((index % 8) * size, (index // 8) * size))
    frames.append({"path": str(path.relative_to(ROOT)).replace("\\", "/"),
                   "sha256": hashlib.sha256(path.read_bytes()).hexdigest(), "bounds": box})
OUT.mkdir(parents=True, exist_ok=True)
atlas.save(OUT / "hammer.png")
# Independent local seed. Audio samples have no access to the game's RNG.
rng = random.Random(260926)
rate, seconds = 44100, .8
samples = []
low_noise = 0.0
for i in range(int(rate * seconds)):
    t = i / rate
    low_noise = low_noise * .72 + rng.uniform(-1, 1) * .28
    thump = math.sin(2 * math.pi * (79 * t + 12 * (1 - math.exp(-t * 20)))) * math.exp(-t * 23)
    clang = sum(math.sin(2 * math.pi * f * t) * a * math.exp(-t * decay)
                for f, a, decay in [(271, .27, 8), (503, .17, 11), (891, .10, 15), (1397, .055, 20)])
    grit = low_noise * .9 * math.exp(-t * 55)
    samples.append((thump * .44 + clang + grit) * min(1.0, t / .002))
peak = max(abs(v) for v in samples)
with wave.open(str(OUT / "bronze_contact.wav"), "wb") as stream:
    stream.setnchannels(1)
    stream.setsampwidth(2)
    stream.setframerate(rate)
    stream.writeframes(b"".join(struct.pack("<h", round(v / peak * 25000)) for v in samples))
meta["rendered_frames"] = frames
meta["atlas_sha256"] = hashlib.sha256((OUT / "hammer.png").read_bytes()).hexdigest()
meta["audio"] = "Original synthesized bronze thump/inharmonic clang, pack.py, local seed 260926"
(OUT / "provenance.json").write_text(json.dumps(meta, indent=2) + "\n", encoding="utf-8")
print(json.dumps({"frames": len(frames), "atlas": str(OUT / "hammer.png"), "pixels_preserved": True}))
