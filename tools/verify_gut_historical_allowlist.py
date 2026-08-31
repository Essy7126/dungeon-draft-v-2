#!/usr/bin/env python3
"""Compare l'identité exacte des échecs GUT à la baseline historique."""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ANSI = re.compile(r"\x1b\[[0-9;]*[A-Za-z]")
SCRIPT = re.compile(
    r"^(?:res://)?(?:.*/)?(test_[^/\\\s]+\.gd)(?:\[[^]]+\])?\s*$"
)
FAILED_TEST = re.compile(r"^-\s+(test_[A-Za-z0-9_]+)\s*$")
INTEGER_TOTAL = re.compile(
    r"^(Errors|Scripts|Tests|Passing Tests|Failing Tests|Risky/Pending)"
    r"\s+(none|[0-9]+)\s*$"
)
FAILED_FINAL = re.compile(r"^----\s+([0-9]+)\s+failing tests\s+----$")
PASSED_FINAL = "---- All tests passed! ----"
EXIT_CODE = re.compile(r"^(?:\[INFO\]\s*)?Exiting with code\s+(-?[0-9]+)\s*$")
SUITE_FAILURE_MARKERS = (
    "before_all/after_all assert failed",
    "could not be loaded",
    "invalid gutconfig",
    "nothing was run.",
    "unknown arguments:",
)


def normalized_lines(text: str) -> list[str]:
    return [line.strip() for line in ANSI.sub("", text).splitlines()]


def parse_failures(
    lines: list[str], start: int, end: int
) -> tuple[set[str], list[str]]:
    current = ""
    candidate = ""
    failures: set[str] = set()
    malformed: list[str] = []
    for line in lines[start:end]:
        match = SCRIPT.search(line.replace("\\", "/"))
        if match:
            current = match.group(1)
            candidate = ""
            continue
        match = FAILED_TEST.match(line)
        if match:
            if current:
                candidate = f"{current}::{match.group(1)}"
            else:
                malformed.append(
                    f"Échec sans script associé dans le résumé : {match.group(1)}"
                )
            continue
        # Le résumé GUT préfixe pareillement les tests en échec, pending
        # et risky. Seul le détail typé qui suit permet de les distinguer.
        if line.startswith("[Failed]"):
            if candidate:
                failures.add(candidate)
            else:
                malformed.append(f"Échec de suite non associé : {line}")
        elif line.startswith("[Pending]") or line.startswith("[Risky]"):
            candidate = ""
    return failures, malformed


def parse_totals(lines: list[str], start: int) -> dict[str, int]:
    totals: dict[str, int] = {}
    for line in lines[start:]:
        match = INTEGER_TOTAL.match(line)
        if not match:
            continue
        totals[match.group(1)] = (
            0 if match.group(2) == "none" else int(match.group(2))
        )
    return totals


def analyze_run(text: str, process_status: int) -> tuple[set[str], list[str]]:
    lines = normalized_lines(text)
    issues: list[str] = []

    try:
        summary_start = lines.index("= Run Summary") + 1
    except ValueError:
        summary_start = -1
        issues.append("Résumé final GUT absent : exécution interrompue ou invalide.")

    totals_start = -1
    if summary_start >= 0:
        try:
            totals_start = lines.index("Totals", summary_start)
        except ValueError:
            issues.append("Bloc Totals GUT absent : exécution tronquée.")

    failures: set[str] = set()
    if summary_start >= 0 and totals_start >= 0:
        failures, malformed = parse_failures(lines, summary_start, totals_start)
        issues.extend(malformed)

    totals = parse_totals(lines, totals_start + 1) if totals_start >= 0 else {}
    for required_total in ("Scripts", "Tests", "Passing Tests"):
        if required_total not in totals:
            issues.append(f"Total GUT obligatoire absent : {required_total}.")
    if totals.get("Scripts", 0) <= 0 or totals.get("Tests", 0) <= 0:
        issues.append("GUT n'a pas exécuté de suite ou de test.")
    if totals.get("Errors", 0) != 0:
        issues.append(f"GUT signale {totals['Errors']} erreur(s) de suite non allowlistée(s).")

    failing_total = totals.get("Failing Tests", 0)
    if failing_total != len(failures):
        issues.append(
            "Le total des tests en échec (%d) ne correspond pas aux identités "
            "collectées (%d)." % (failing_total, len(failures))
        )

    failed_final = next(
        (int(match.group(1)) for line in lines if (match := FAILED_FINAL.match(line))),
        None,
    )
    passed_final = PASSED_FINAL in lines
    if failed_final is None and not passed_final:
        issues.append("Marqueur final GUT absent : exécution tronquée.")
    elif failed_final is not None and failed_final != failing_total:
        issues.append(
            "Le marqueur final GUT annonce %d échec(s), contre %d dans Totals."
            % (failed_final, failing_total)
        )

    logged_exit_codes = [
        int(match.group(1)) for line in lines if (match := EXIT_CODE.match(line))
    ]
    if not logged_exit_codes:
        issues.append("Marqueur de sortie GUT absent : exécution tronquée.")
    elif logged_exit_codes[-1] != process_status:
        issues.append(
            "Le statut du processus (%d) diffère du statut GUT journalisé (%d)."
            % (process_status, logged_exit_codes[-1])
        )

    lowered = "\n".join(lines).lower()
    for marker in SUITE_FAILURE_MARKERS:
        if marker in lowered:
            issues.append(f"Échec de suite non allowlistable détecté : {marker}")

    return failures, issues


def main() -> int:
    if len(sys.argv) != 4:
        print(
            "usage: verify_gut_historical_allowlist.py "
            "GLOBAL_LOG ALLOWLIST_JSON GUT_PROCESS_STATUS"
        )
        return 2
    try:
        process_status = int(sys.argv[3])
        text = Path(sys.argv[1]).read_text(encoding="utf-8", errors="replace")
        expected_entries = json.loads(Path(sys.argv[2]).read_text(encoding="utf-8"))
    except (OSError, ValueError, json.JSONDecodeError) as error:
        print(f"Invalidation de la baseline : {error}")
        return 2
    if not isinstance(expected_entries, list) or not all(
        isinstance(entry, str) and entry for entry in expected_entries
    ):
        print("L'allowlist doit être une liste JSON de chaînes non vides.")
        return 2
    expected = set(expected_entries)
    if len(expected) != len(expected_entries):
        print("L'allowlist contient des identités dupliquées.")
        return 2

    observed, infrastructure_issues = analyze_run(text, process_status)
    expected_status = 1 if expected else 0
    if process_status != expected_status:
        infrastructure_issues.append(
            "Statut Godot/GUT inattendu : %d (attendu : %d)."
            % (process_status, expected_status)
        )
    if expected and PASSED_FINAL in normalized_lines(text):
        infrastructure_issues.append(
            "GUT annonce un succès alors que l'allowlist attend des échecs historiques."
        )

    added = sorted(observed - expected)
    missing = sorted(expected - observed)
    print(f"Observed failures: {len(observed)}; expected: {len(expected)}")
    if infrastructure_issues:
        print("Invalid or incomplete GUT run:")
        print("\n".join(f"  ! {item}" for item in infrastructure_issues))
    if added:
        print("New failures:")
        print("\n".join(f"  + {item}" for item in added))
    if missing:
        print("Historical failures missing (baseline update required):")
        print("\n".join(f"  - {item}" for item in missing))
    if infrastructure_issues or added or missing:
        return 1
    print("Exact historical allowlist matched.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
