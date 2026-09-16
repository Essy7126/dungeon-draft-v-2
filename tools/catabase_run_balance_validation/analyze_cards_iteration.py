"""Compare completed, paired bot trials without rewriting the historical audit."""
import csv
import hashlib
import json
from pathlib import Path
from statistics import mean

ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / "artifacts/catabase_run_balance_validation"
OUT = BASE / "cards_iteration_analysis"
OUT.mkdir(exist_ok=True)


def read(label):
    folder = BASE / label
    summary_path = folder / "summary.json"
    if not summary_path.exists():
        return []
    summary = json.loads(summary_path.read_text(encoding="utf-8-sig"))
    if not summary.get("passed"):
        raise RuntimeError(f"Failed batch cannot enter comparison: {label}")
    return json.loads((folder / "report.json").read_text(encoding="utf-8-sig"))["runs"]


def describe(runs):
    wins = [r for r in runs if r["outcome"] == "bot_completed_route"]
    return {"n": len(runs), "wins": len(wins), "combats": sum(len(r["combats"]) for r in runs),
            "winning_hero_turns": [sum(c["turns"] for c in r["combats"]) for r in wins],
            "mean_depth": round(mean(r["deepest_depth"] for r in runs), 2) if runs else None}


comparisons = [
    ("starter", "audit_cards_starter_20260916", "iteration_economy_starter_20260916"),
    ("curated", "audit_curated_20260916", "iteration_economy_curated_20260916"),
    ("classic", "audit_classic_paired_20260916", "iteration_classic_control_20260916"),
]
paired = []
groups = {}
missing_batches = []
classic_comparison = {"paired_runs": 0, "excluded_combat_fields": ["seconds"], "differences": []}
for name, before_label, after_label in comparisons:
    before = read(before_label)
    after = read(after_label)
    if not after:
        missing_batches.append(after_label)
        continue
    index = {(r["seed"], r["difficulty"], r["weapon"], r["policy"]): r for r in before}
    for difficulty in ("normal", "easy"):
        rows = [r for r in after if r["difficulty"] == difficulty]
        if rows:
            groups[name + "/" + difficulty] = describe(rows)
    for run in after:
        key = (run["seed"], run["difficulty"], run["weapon"], run["policy"])
        old = index.get(key)
        if old is None:
            continue
        if name == "classic":
            classic_comparison["paired_runs"] += 1
            normalize = lambda combats: [{k: v for k, v in c.items() if k != "seconds"} for c in combats]
            if normalize(old["combats"]) != normalize(run["combats"]) or old["outcome"] != run["outcome"]:
                classic_comparison["differences"].append(list(key))
        paired.append({"policy": name, "seed": key[0], "difficulty": key[1], "weapon": key[2],
                       "old_win": old["outcome"] == "bot_completed_route", "new_win": run["outcome"] == "bot_completed_route",
                       "old_depth": old["deepest_depth"], "new_depth": run["deepest_depth"],
                       "old_turns": sum(c["turns"] for c in old["combats"]), "new_turns": sum(c["turns"] for c in run["combats"]),
                       "old_final_gold": old["combats"][-1].get("reward", {}).get("gold_after"),
                       "new_final_gold": run["combats"][-1].get("reward", {}).get("gold_after")})
heldout = read("iteration_heldout_20260916")
if not heldout:
    missing_batches.append("iteration_heldout_20260916")
for difficulty in ("normal", "easy"):
    rows = [r for r in heldout if r["difficulty"] == difficulty]
    if rows:
        groups["heldout/" + difficulty] = describe(rows)
armor = {}
for mode in ("control", "mixte"):
    label = "iteration_armor_" + mode + "_20260916"
    rows = read(label)
    if not rows:
        missing_batches.append(label)
    armor[mode] = [{"seed": r["seed"], "difficulty": r["difficulty"], "preset": r["weapon"],
                    "win": r["outcome"] == "bot_completed_route", "depth": r["deepest_depth"],
                    "combats": len(r["combats"]), "turns": sum(c["turns"] for c in r["combats"])} for r in rows]
files = ["core/expedition/catabase_cards.gd", "core/expedition/expedition_session.gd", "core/spell_caster.gd",
         "core/spell_modifier.gd", "core/expedition/catabase_combat_modifier.gd", "battle/painted/painted_battle.gd",
         "ui/expedition/catabase_card_hand.gd", "ui/expedition/catabase_card_collection.gd",
         "ui/expedition/catabase_card_text.gd", "ui/expedition/expedition_screen.gd",
         "ui/expedition/expedition_reward_card.gd", "ui/player_combat_log.gd"]
regression = {}
old_path = ROOT / "artifacts/dev/20260916-113956-test-catabase-6d1f2f88/gut-strict-report.json"
new_path = ROOT / "artifacts/dev/20260916-160717-test-catabase-ad18eb93/gut-strict-report.json"
if old_path.exists() and new_path.exists():
    old = json.loads(old_path.read_text(encoding="utf-8-sig"))
    new = json.loads(new_path.read_text(encoding="utf-8-sig"))
    diagnostics = lambda report: sorted(e["text"] for e in report["errors"] if e.get("text"))
    regression = {"before": str(old_path.relative_to(ROOT)), "after": str(new_path.relative_to(ROOT)),
                  "before_sha256": hashlib.sha256(old_path.read_bytes()).hexdigest(),
                  "after_sha256": hashlib.sha256(new_path.read_bytes()).hexdigest(),
                  "strict_verdict": new["verdict"], "tests": new["junit"]["tests"],
                  "failures": new["observed_failures"],
                  "new_failure_ids": sorted(set(new["observed_failures"]) - set(old["observed_failures"])),
                  "resolved_failure_ids": sorted(set(old["observed_failures"]) - set(new["observed_failures"])),
                  "same_engine_error_texts": diagnostics(old) == diagnostics(new)}
result = {"guard": "Paired deterministic bot observations, not human win rates or optimal play. Armor comparison changes only initial armor; same informed fixed-deck pilot.",
          "missing_batches": missing_batches, "armor_experiment": armor, "classic_regression": classic_comparison,
          "broad_test_regression": regression,
          "groups": groups, "paired": paired,
          "current_production_sha256": {f: hashlib.sha256((ROOT / f).read_bytes()).hexdigest() for f in files}}
(OUT / "comparison.json").write_text(json.dumps(result, indent=2, ensure_ascii=False), encoding="utf-8")
if paired:
    with (OUT / "paired.csv").open("w", newline="", encoding="utf-8-sig") as stream:
        writer = csv.DictWriter(stream, fieldnames=list(paired[0]))
        writer.writeheader()
        writer.writerows(paired)
print(json.dumps(groups, ensure_ascii=False, indent=2))
