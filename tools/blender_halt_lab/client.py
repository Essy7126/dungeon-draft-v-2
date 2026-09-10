"""Use the installed Blender addon's protocol, pinned to the map lab session."""
import argparse
import json
import socket
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SESSION = ROOT / "artifacts/dev/blender-halt-profile/session.json"
TARGET = ROOT / "art/source/blender/halt_scale_lab_v1/halt_scale_lab_v1.blend"


def guarded_code(session, code):
    return (
        "import bpy, os, json\n"
        f"assert os.getpid() == {session['pid']!r}, 'Wrong Blender process'\n"
        f"assert os.path.normcase(os.path.abspath(bpy.data.filepath)) == os.path.normcase({str(TARGET)!r}), 'Wrong Blender file'\n"
        f"assert bpy.app.driver_namespace.get('halt_lab_session_token') == {session['token']!r}, 'Expired Blender session'\n"
        "assert bpy.context.scene.get('halt_lab_id') == 'dungeon_draft_halt_scale_lab_v1', 'Wrong map scene'\n"
        + code
    )


def request(session, code, timeout=30):
    if session.get("host") != "127.0.0.1" or session.get("port") != 9877:
        raise ValueError("This client only targets the private map lab port")
    if Path(session["file"]).resolve() != TARGET.resolve():
        raise ValueError("Unexpected map lab file")
    packet = {"type": "execute_code", "params": {"code": guarded_code(session, code)}}
    with socket.create_connection((session["host"], session["port"]), timeout) as stream:
        stream.settimeout(timeout)
        stream.sendall(json.dumps(packet).encode("utf-8"))
        received = bytearray()
        while len(received) <= 16 * 1024 * 1024:
            chunk = stream.recv(65536)
            if not chunk:
                raise ConnectionError("Blender closed the connection before replying")
            received.extend(chunk)
            try:
                result = json.loads(received.decode("utf-8"))
            except (json.JSONDecodeError, UnicodeDecodeError):
                continue
            if result.get("status") != "success":
                raise RuntimeError(result.get("message", str(result)))
            return result["result"]
    raise ValueError("Unexpectedly large Blender response")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("code_file", nargs="?", type=Path)
    parser.add_argument("--timeout", type=float, default=30, help="Socket timeout in seconds; use 120 for large guide exports")
    args = parser.parse_args()
    if not 1 <= args.timeout <= 180:
        parser.error("timeout must be between 1 and 180 seconds")
    code = args.code_file.read_text(encoding="utf-8") if args.code_file else (
        "print(json.dumps({'pid':os.getpid(),'file':bpy.data.filepath,"
        "'scene':bpy.context.scene.name,'objects':len(bpy.data.objects),"
        "'camera':bpy.context.scene.camera.name if bpy.context.scene.camera else None,"
        "'server':bpy.types.blendermcp_server.get_addon_info()},ensure_ascii=False))"
    )
    result = request(json.loads(SESSION.read_text(encoding="utf-8")), code, timeout=args.timeout)
    print(result.get("result", json.dumps(result)))


if __name__ == "__main__":
    main()
