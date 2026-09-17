"""Descriptive, reproducible audit statistics. No inference of human win rate.

Reads only audit reports with a successful engine summary. Writes derived JSON
and CSV under artifacts, never production data. Canary runs are excluded.
"""
import csv
import hashlib
import json
import statistics
import subprocess
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / "artifacts/catabase_run_balance_validation"
OUT = BASE / "studio_analysis"
OUT.mkdir(exist_ok=True)


def mean(values):
    return round(statistics.mean(values), 3) if values else None


def median(values):
    return statistics.median(values) if values else None


def stats(runs):
    wins = [r for r in runs if r["outcome"] == "bot_completed_route"]
    combats = [c for r in runs for c in r["combats"]]
    damage = sum(c["hp_damage_received"] for c in combats)
    return {
        "n": len(runs), "wins": len(wins),
        "observed_bot_win_fraction": round(len(wins) / len(runs), 4),
        "combats_reached": len(combats),
        "deaths": dict(Counter(str(r["deepest_depth"]) for r in runs if r not in wins)),
        "mean_turns_per_combat": mean([c["turns"] for c in combats]),
        "median_turns_winning_run": median([sum(c["turns"] for c in r["combats"]) for r in wins]),
        "min_turns_winning_run": min([sum(c["turns"] for c in r["combats"]) for r in wins], default=None),
        "hp_damage_total": damage,
        "combats_zero_hp_damage": sum(c["hp_damage_received"] == 0 for c in combats),
        "combats_at_most_two_hero_activations": sum(c["turns"] <= 2 for c in combats),
        "idle_turns": sum(c["idle_turns"] for c in combats),
        "turn_caps": sum(c["termination"] in ["turn_cap", "activation_cap"] for c in combats),
    }


runs = []
included = []
rejected = []
for folder in sorted(BASE.glob("audit_*_20260916")):
    if "canary" in folder.name or folder.name.startswith("audit_ui_"):
        continue
    summary_path = folder / "summary.json"
    if not summary_path.exists():
        rejected.append({"label": folder.name, "reason": "incomplete"})
        continue
    summary = json.loads(summary_path.read_text(encoding="utf-8-sig"))
    if not summary.get("passed"):
        rejected.append({"label": folder.name, "reason": "failed", "summary": summary})
        continue
    report = json.loads((folder / "report.json").read_text(encoding="utf-8-sig"))
    included.append({"label": folder.name, "n": len(report["runs"]), "summary": str(summary_path.relative_to(ROOT))})
    for run in report["runs"]:
        run["audit_label"] = folder.name
        runs.append(run)

groups = defaultdict(list)
weapons = defaultdict(list)
depths = defaultdict(list)
for run in runs:
    mode = run.get("audit", {}).get("mode", "starter" if run["variant"] == "cards" else "classic")
    run["analysis_mode"] = mode
    key = f'{mode}/{run["policy"]}/{run["difficulty"]}'
    groups[key].append(run)
    weapons[f'{key}/{run["weapon"]}'].append(run)
    for combat in run["combats"]:
        depths[f'{key}/{combat["depth"]:02}'].append(combat)

table = []
combats_csv = []
for run in runs:
    combats = run["combats"]
    audit = run.get("audit", {})
    gold_end = combats[-1].get("reward", {}).get("gold_after") if combats else None
    table.append({
        "label": run["audit_label"], "mode": run["analysis_mode"],
        "seed": run["seed"], "difficulty": run["difficulty"], "weapon": run["weapon"],
        "policy": run["policy"], "outcome": run["outcome"], "deepest_depth": run["deepest_depth"],
        "combats": len(combats), "hero_turns": sum(c["turns"] for c in combats),
        "casts": sum(sum(c["hero_casts"].values()) for c in combats),
        "move_actions": sum(c["moves"] for c in combats),
        "damage_received": sum(c["hp_damage_received"] for c in combats),
        "combat_heal": sum(c["healing_received_in_combat"] for c in combats),
        "idle_turns": sum(c["idle_turns"] for c in combats),
        "retains": audit.get("retains"), "recomposes": audit.get("recomposes"),
        "bought": sum(len(e["bought"]) for e in audit.get("economy", [])),
        "sold": sum(len(e["sold"]) for e in audit.get("economy", [])),
        "deck_adds": sum(len(e["added"]) for e in audit.get("economy", [])),
        "last_reward_gold": gold_end, "machine_seconds_NOT_playtime": run["seconds"],
        "hp_final": combats[-1]["hp_after_combat"] if combats else None,
    })
    for combat in combats:
        combats_csv.append({"label": run["audit_label"], "mode": run["analysis_mode"], "seed": run["seed"], "difficulty": run["difficulty"], "weapon": run["weapon"], "policy": run["policy"], **{k: combat.get(k) for k in ["depth", "node_id", "won", "termination", "turns", "moves", "idle_turns", "hp_entry", "max_hp_entry", "hp_after_combat", "hp_after_level", "hp_after_provisions", "hp_after_refuge", "hp_damage_received", "healing_received_in_combat", "health_cost_paid", "fallback_path_moves"]}})

by_depth = {}
for key, combats in depths.items():
    by_depth[key] = {"reached": len(combats), "won": sum(c["won"] for c in combats), "mean_turns": mean([c["turns"] for c in combats]), "mean_damage": mean([c["hp_damage_received"] for c in combats]), "mean_damage_fraction_entry_maxhp": mean([c["hp_damage_received"] / c["max_hp_entry"] for c in combats]), "zero_hp_damage": sum(c["hp_damage_received"] == 0 for c in combats)}

paired = []
index = {(r["analysis_mode"], r["policy"], r["difficulty"], r["weapon"], r["seed"]): r for r in runs}
for left, right in [("classic", "starter"), ("pilot", "adaptive"), ("pilot", "swarm"), ("pilot", "liquidate")]:
    for key, first in index.items():
        if key[0] != left:
            continue
        second = index.get((right, *key[1:]))
        if not second:
            continue
        paired.append({"comparison": f"{left}->{right}", "policy": key[1], "difficulty": key[2], "weapon": key[3], "seed": key[4], "left_win": first["outcome"] == "bot_completed_route", "right_win": second["outcome"] == "bot_completed_route", "left_depth": first["deepest_depth"], "right_depth": second["deepest_depth"]})

telemetry = {}
for key, rr in groups.items():
    turns = [t for r in rr for t in r.get("audit", {}).get("turns", [])]
    economies = [e for r in rr for e in r.get("audit", {}).get("economy", [])]
    used = Counter()
    for r in rr:
        for combat in r["combats"]:
            used.update(combat["hero_casts"])
    telemetry[key] = {
        "sampled_turns": len(turns),
        "mean_unique_hand_families": mean([t["unique"] for t in turns]),
        "turns_no_legal_damage_at_start": sum(t["legal_damage_now"] == 0 for t in turns),
        "turns_with_unspent_ap": sum(t.get("ap_unspent", 0) > 0 for t in turns),
        "unspent_ap_sum_in_ended_sampled_turns": sum(t.get("ap_unspent", 0) for t in turns),
        "added_families": dict(Counter(f for e in economies for f in e["added"])),
        "sold_families": dict(Counter(f for e in economies for f in e["sold"])),
        "bought_families": dict(Counter(f for e in economies for f in e["bought"])),
        "casts": dict(used.most_common()),
    }

production = ["core/expedition/catabase_cards.gd", "core/expedition/expedition_session.gd", "core/expedition/catabase_preparation_catalog.gd", "core/expedition/expedition_build_catalog.gd", "core/expedition/catabase_first_six_spells.gd", "core/game_manager.gd", "core/spell_caster.gd", "battle/battle.gd", "ui/expedition/catabase_card_hand.gd", "ui/expedition/catabase_card_collection.gd"]
report = {
    "guard": "Descriptive deterministic bot sample, three paired seeds, fixed presets; not IID human trials; no win-rate confidence claim and no realtime speedrun claim.",
    "base_head": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
    "production_sha256": {p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest() for p in production},
    "included": included, "excluded": rejected,
    "total_runs": len(runs), "total_combats": sum(len(r["combats"]) for r in runs),
    "groups": {k: stats(v) for k, v in groups.items()},
    "weapons": {k: stats(v) for k, v in weapons.items()},
    "depths": by_depth, "paired": paired, "telemetry": telemetry,
    "fastest_by_hero_activations": sorted([r for r in table if r["outcome"] == "bot_completed_route"], key=lambda r: (r["hero_turns"], r["casts"] + r["move_actions"]))[:12],
}
(OUT / "analysis.json").write_text(json.dumps(report, indent=2, ensure_ascii=False), encoding="utf-8")
for name, rows in [("runs.csv", table), ("combats.csv", combats_csv), ("paired.csv", paired)]:
    if rows:
        with (OUT / name).open("w", newline="", encoding="utf-8-sig") as stream:
            writer = csv.DictWriter(stream, fieldnames=list(rows[0]))
            writer.writeheader()
            writer.writerows(rows)
print(json.dumps({"runs": len(runs), "combats": report["total_combats"], "groups": report["groups"], "excluded": rejected}, indent=2, ensure_ascii=False))
