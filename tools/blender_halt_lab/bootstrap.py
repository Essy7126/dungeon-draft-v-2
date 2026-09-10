"""Start the map lab in its own Blender process and user profile."""
import json
import os
import sys
import uuid
from pathlib import Path

import addon_utils
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "art/source/blender/halt_scale_lab_v1"
PROFILE = ROOT / "artifacts/dev/blender-halt-profile"
TARGET = OUTPUT / "halt_scale_lab_v1.blend"
PORT = 9877
LAB_ID = "dungeon_draft_halt_scale_lab_v1"


def create_initial_scene():
    # This script only runs after --factory-startup in a newly launched process.
    if bpy.data.filepath:
        raise RuntimeError("Refusing to initialize an already opened Blender file")
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    scene = bpy.context.scene
    scene.name = "Atelier des maps - Maquette"
    scene["halt_lab_id"] = LAB_ID
    scene.unit_settings.system = "METRIC"
    scene.unit_settings.scale_length = 1.0

    def block(name, location, dimensions, color):
        bpy.ops.mesh.primitive_cube_add(size=1, location=location)
        obj = bpy.context.object
        obj.name = name
        obj.dimensions = dimensions
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        obj.color = (*color, 1)
        obj["purpose"] = "scale_reference"
        bevel = obj.modifiers.new("Arêtes lisibles", "BEVEL")
        bevel.width = 0.025
        bevel.segments = 2
        return obj

    stone = (0.29, 0.39, 0.43)
    wood = (0.48, 0.30, 0.15)
    block("Sol - 8 x 6 m", (0, 0, -0.1), (8, 6, 0.2), stone)
    block("Mur arrière", (0, 2.9, 1.5), (8, 0.2, 3), stone)
    block("Porte - montant gauche", (2.1, 1.5, 1.25), (0.18, 0.3, 2.5), stone)
    block("Porte - montant droit", (3.5, 1.5, 1.25), (0.18, 0.3, 2.5), stone)
    block("Porte - linteau", (2.8, 1.5, 2.5), (1.58, 0.3, 0.2), stone)
    block("Établi - plateau à 0.90 m", (-1.5, 1.4, 0.84), (1.8, 0.8, 0.12), wood)
    for x in [-2.2, -0.8]:
        for y in [1.1, 1.7]:
            block("Pied établi", (x, y, 0.39), (0.12, 0.12, 0.78), wood)
    block("Seau - gabarit 0.35 m", (-0.15, 1.2, 0.175), (0.3, 0.3, 0.35), wood)
    block("Pilier - contrôle occultation", (1.25, -0.2, 0.75), (0.6, 0.6, 1.5), stone)
    body = block("Humain - référence corporelle 1.80 m", (-1.1, -0.4, 0.90), (0.48, 0.28, 1.80), (0.86, 0.61, 0.21))
    body["note"] = "Gabarit de conception proposé, sans armes ; ce n’est pas encore le sprite d’Achille."

    bpy.ops.object.camera_add(location=(9, -12, 11))
    camera = bpy.context.object
    camera.name = "Caméra maquette - à caler sur Achille"
    camera.rotation_euler = (Vector((0, 0.5, 0.7)) - camera.location).to_track_quat("-Z", "Y").to_euler()
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 11.8
    scene.camera = camera
    scene.render.resolution_x = 1280
    scene.render.resolution_y = 720
    scene.render.resolution_percentage = 100
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.color_type = "OBJECT"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.show_shadows = True
    scene.display.shading.show_cavity = True
    for screen in bpy.data.screens:
        for area in screen.areas:
            if area.type == "VIEW_3D":
                area.spaces.active.shading.color_type = "OBJECT"
                area.spaces.active.region_3d.view_perspective = "CAMERA"
    bpy.ops.object.select_all(action="DESELECT")


def main():
    OUTPUT.mkdir(parents=True, exist_ok=True)
    (OUTPUT / ".gdignore").write_text("", encoding="utf-8")
    expected_config = (PROFILE / "config").resolve()
    if Path(os.environ.get("BLENDER_USER_CONFIG", "")).resolve() != expected_config:
        raise RuntimeError("Map lab requires its isolated configuration directory")
    if TARGET.exists():
        bpy.ops.wm.open_mainfile(filepath=str(TARGET))
        if bpy.context.scene.get("halt_lab_id") != LAB_ID:
            raise RuntimeError("The existing file does not belong to the map lab")
    else:
        create_initial_scene()

    # Instantiate the server on the private port BEFORE registration. The installed
    # addon reuses this server, so its default port 9876 is never attempted.
    sys.path.insert(0, str(PROFILE / "scripts/addons"))
    import blender_mcp
    bpy.types.blendermcp_server = blender_mcp.BlenderMCPServer(host="127.0.0.1", port=PORT)
    addon_utils.enable("blender_mcp", default_set=False, persistent=False)
    server = bpy.types.blendermcp_server
    if not server.running or server.port != PORT:
        raise RuntimeError("Private Blender connection could not start")
    scene = bpy.context.scene
    scene.blendermcp_port = PORT
    scene.blendermcp_auto_start_server = False
    scene.blendermcp_server_running = True
    bpy.ops.wm.save_as_mainfile(filepath=str(TARGET))
    token = uuid.uuid4().hex
    bpy.app.driver_namespace["halt_lab_session_token"] = token
    session = {
        "pid": os.getpid(), "host": "127.0.0.1", "port": PORT,
        "file": str(TARGET), "token": token, "lab_id": LAB_ID,
        "blender": bpy.app.version_string,
        "addon": server.get_addon_info(),
        "telemetry": server.get_telemetry_consent(),
        "state": "connection_ready_initial_blockout_only",
    }
    (PROFILE / "session.json").write_text(json.dumps(session, indent=2), encoding="utf-8")
    print("HALT_LAB_READY=" + json.dumps(session), flush=True)


if __name__ == "__main__":
    main()
