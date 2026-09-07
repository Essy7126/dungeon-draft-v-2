"""Merge the reviewed Meshy pass into the existing art manifest without hiding its history."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "art/source/catabase/painted/manifest.json"
EXPORTS = ROOT / "art/source/catabase/meshy_ui/exports.json"
RECEIPT = ROOT / "meshy_output/catabase_ui_production_receipt.json"


def main():
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    exports = json.loads(EXPORTS.read_text(encoding="utf-8"))
    receipt = json.loads(RECEIPT.read_text(encoding="utf-8"))
    by_path = {entry["path"]: entry for entry in exports["exports"]}
    jobs = {entry["task_id"]: entry for entry in receipt["jobs"]}
    aliases = {
        "assets/catabase/painted/route/secret.png": "assets/catabase/painted/route/hidden.png",
        "assets/catabase/painted/route/paper.png": "assets/catabase/painted/ui/route_parchment.png",
        "assets/catabase/painted/tree/fresco.png": "assets/catabase/painted/ui/tree_fresco.png",
    }
    updated = 0
    records = []
    for name in ["spell_families", "stat_glyphs", "emblems", "equipment", "route_markers"]:
        records.extend(manifest[name])
    records.extend([manifest["paper"], manifest["fresco"]])
    for item in records:
        old_path = item.get("export_path")
        path = aliases.get(old_path, old_path)
        export = by_path.get(path)
        if export is None:
            continue
        if path != old_path:
            item["original_planned_export_path"] = old_path
        job = jobs[export["task_id"]]
        item.update(
            export_path=path,
            status="integrated_tested" if export.get("runtime_validation") == "passed" else "integrated_validation_pending",
            provider="Meshy",
            requested_model=job["payload"]["ai_model"],
            reported_model=job["reported_model"],
            generation_job_id=job["task_id"],
            generation_prompt=job["payload"]["prompt"],
            source_path=export["source_path"],
            sha256=export["sha256"],
            review_status=export["review_status"],
            runtime_validation=export["runtime_validation"],
            export_receipt="art/source/catabase/meshy_ui/exports.json",
        )
        updated += 1
    manifest["title"] = "Catabase — production artistique Higgsfield et Meshy"
    manifest["status"] = "partial_advanced_art_pending"
    provenance = manifest["provenance"]
    if "higgsfield_pilot_notes" not in provenance:
        provenance["higgsfield_pilot_notes"] = provenance["notes"]
    provenance["notes"] = (
        "Pilote Higgsfield conservé : 16 maîtres de sorts et deux haltes. "
        "La passe Meshy ajoute 80 assets de techniques, équipement et interface ; "
        "les décors supplémentaires, arènes et VFX restent en attente. "
        "Le budget Higgsfield ci-dessous est un instantané historique."
    )
    manifest["meshy_ui_pass"] = {
        "date": "2026-09-07",
        "status": exports.get("status", "integrated_validation_pending"),
        "model": "nano-banana-pro",
        "generation_count": len(receipt["jobs"]),
        "unique_exports": len(exports["exports"]),
        "consumed_credits": receipt["consumed_credits"],
        "balance_before": receipt["initial_balance"],
        "balance_after": receipt["latest_balance"],
        "generation_receipt": "meshy_output/catabase_ui_production_receipt.json",
        "exports_receipt": "art/source/catabase/meshy_ui/exports.json",
        "documentation": "docs/design/achilles/catabase_meshy_ui_v1.md",
        "distinct_tempest_export": "assets/catabase/painted/icons/exp_tempest.png",
        "preserved_higgsfield_exports": 18,
        "scope": "Small assets and UI for the existing run; additional arena/halt paintings and VFX are deferred.",
    }
    manifest["nondestructive_variants"]["meshy_update"] = (
        "User-authorized provider change for this UI pass: Meshy Nano Banana Pro. "
        "Tempest now has a distinct composition. Runtime families cover all 46 spell IDs; "
        "this does not mean 46 independently generated icons or completion of optional variants."
    )
    for batch in manifest["batches"]:
        if batch["id"] in ["02_small_assets", "03_fresco_vfx"]:
            batch["meshy_fulfillment_receipt"] = "art/source/catabase/meshy_ui/exports.json"
            batch["note_on_original_plan"] = (
                "Small assets and fresco/paper supplied by the Meshy UI pass. "
                "Original Higgsfield batch retained for historical budgeting; VFX still pending."
            )
    MANIFEST.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Updated {updated} originally planned entries; {len(by_path)} unique Meshy exports recorded.")


if __name__ == "__main__":
    main()
