"""Bounded image comparison using the Meshy plugin's bundled task helpers.

The API key is read without echo and kept only in this process environment.
Commands on stdin: balance, run, quit. A run creates exactly two image tasks.
"""
import contextlib
import getpass
import io
import json
import os
from pathlib import Path
import sys

import pip._vendor.requests as requests

sys.modules["requests"] = requests
SKILL_SCRIPTS = Path.home() / ".codex/plugins/cache/openai-curated-remote/meshy-openai-plugin/0.4.1/skills/meshy-3d-generation/scripts"
sys.path.insert(0, str(SKILL_SCRIPTS))
import meshy_task as meshy

ROOT = Path(__file__).resolve().parent.parent
os.chdir(ROOT)
ENDPOINT = "/openapi/v1/text-to-image"
MODEL = sys.argv[1] if len(sys.argv) > 1 else "nano-banana-2"
if MODEL not in ("nano-banana-2", "nano-banana-pro"):
    raise ValueError("Only the two comparison models are allowed.")
ESTIMATED_CREDITS = 18 if MODEL == "nano-banana-pro" else 12


def cli(*args):
    previous = sys.argv
    sys.argv = ["meshy_task", *args]
    output = io.StringIO()
    try:
        with contextlib.redirect_stdout(output), contextlib.redirect_stderr(output):
            try:
                meshy.main()
            except SystemExit as exc:
                if exc.code not in (None, 0):
                    raise
    finally:
        sys.argv = previous
    return output.getvalue()


def balance():
    raw = cli("balance")
    result = json.loads(raw[raw.index("{"):])
    print("BALANCE " + json.dumps(result), flush=True)
    return result


def save(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2), encoding="utf-8")


def run_comparison():
    starting_balance = balance()
    available = starting_balance.get("balance")
    if available is not None and float(available) < ESTIMATED_CREDITS:
        raise RuntimeError(f"At least {ESTIMATED_CREDITS} Meshy credits are needed for the two-image test.")
    manifest = json.loads((ROOT / "art/source/catabase/painted/manifest.json").read_text(encoding="utf-8"))
    references = manifest["references"]
    cases = []
    for ref in references:
        if ref["id"] not in ("higgsfield_inventory_icons", "higgsfield_flooded_library"):
            continue
        ratio = "1:1" if ref["id"] == "higgsfield_inventory_icons" else "16:9"
        payload = {"ai_model": MODEL, "prompt": ref["prompt"], "aspect_ratio": ratio}
        task_id = meshy.create_task(ENDPOINT, payload)
        project_dir = Path(meshy.get_project_dir(task_id, prompt="compare-" + ref["id"]))
        case = {"task_id": task_id, "project_dir": str(project_dir), "reference": ref, "payload": payload, "endpoint": ENDPOINT, "status": "SUBMITTED"}
        save(project_dir / "comparison_request.json", case)
        meshy.record_task(str(project_dir), task_id, "text-to-image", "submitted", prompt=ref["prompt"])
        cases.append(case)
        print("CASE_SUBMITTED " + json.dumps({"task_id": task_id, "project_dir": str(project_dir), "reference_id": ref["id"]}), flush=True)
    if len(cases) != 2:
        raise RuntimeError("Expected two known comparison references.")
    for case in cases:
        project_dir = Path(case["project_dir"])
        task = meshy.poll_task(ENDPOINT, case["task_id"], timeout=900)
        save(project_dir / ("task_" + case["task_id"] + ".json"), task)
        urls = task.get("image_urls", [])
        if not urls:
            raise RuntimeError("Succeeded task returned no image URLs.")
        files = []
        for i, url in enumerate(urls, 1):
            filename = "image.png" if len(urls) == 1 else f"image_{i}.png"
            meshy.download(url, str(project_dir / filename))
            files.append(filename)
        thumbnail_url = task.get("thumbnail_url")
        if thumbnail_url:
            meshy.save_thumbnail(str(project_dir), thumbnail_url)
        meshy.record_task(str(project_dir), case["task_id"], "text-to-image", "complete", prompt=case["payload"]["prompt"], files=files)
        case.update(status=task["status"], consumed_credits=task.get("consumed_credits"), reported_model=task.get("ai_model"), files=files)
        save(project_dir / "comparison_result.json", case)
        print("CASE_COMPLETED " + json.dumps({"task_id": case["task_id"], "files": files, "consumed_credits": case["consumed_credits"], "project_dir": str(project_dir)}), flush=True)
    summary = {"starting_balance": starting_balance, "ending_balance": balance(), "cases": cases, "method": "Identical original Higgsfield prompts and matched aspect ratios; no reference-image conditioning. Meshy model explicitly selected: " + MODEL + ". Meshy resolution is not specified by this endpoint."}
    save(Path(cases[0]["project_dir"]) / "comparison_summary.json", summary)
    print("COMPARISON_COMPLETE " + str(Path(cases[0]["project_dir"]) / "comparison_summary.json"), flush=True)


try:
    os.environ["MESHY_API_KEY"] = getpass.getpass("MESHY_API_KEY (session only): ").strip().replace("\\_", "_")
    readiness = cli("check-env")
    key = os.environ["MESHY_API_KEY"]
    print(readiness.replace(key, "[redacted]").replace(key[:8] + "...", "[redacted]"), flush=True)
    started = False
    for line in sys.stdin:
        command = line.strip()
        try:
            if command == "balance":
                balance()
            elif command == "run":
                if started:
                    raise RuntimeError("This process has already submitted its bounded test; no duplicate generation.")
                started = True
                run_comparison()
            elif command == "quit":
                break
            else:
                print("Commands: balance, run, quit", flush=True)
        except BaseException as exc:
            print("ERROR " + type(exc).__name__ + ": " + str(exc), flush=True)
finally:
    os.environ.pop("MESHY_API_KEY", None)
