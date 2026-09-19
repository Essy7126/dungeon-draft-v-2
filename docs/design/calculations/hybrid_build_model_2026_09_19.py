"""Exact design arithmetic, not a combat or win-rate simulator. Stdlib only."""

from collections import defaultdict
from math import comb, isclose
import json


def foreign_drops(guarantee_first_discovery):
    # Four classes total, three possible foreign classes, one card per victory.
    # Eleven useful receipts before the final fight of a twelve-fight run.
    states = {(0, 0, 0): 1.0}
    results = []
    for fight in range(1, 12):
        nominal = 0.15 if fight <= 3 else 0.35 if fight <= 8 else 0.45
        next_states = defaultdict(float)
        for counts, probability in states.items():
            foreign = (
                1.0
                if guarantee_first_discovery and fight == 3 and sum(counts) == 0
                else nominal
            )
            next_states[counts] += probability * (1 - foreign)
            for school in range(3):
                target = list(counts)
                target[school] += 1
                next_states[tuple(target)] += probability * foreign / 3
        states = next_states
        assert isclose(sum(states.values()), 1.0, abs_tol=1e-12)
        if fight in (3, 6, 8, 11):
            results.append({
                "after_fight": fight,
                "expected_foreign": sum(sum(c) * p for c, p in states.items()),
                "prob_at_least_one": sum(p for c, p in states.items() if sum(c) >= 1),
                "prob_two_same_foreign_class": sum(p for c, p in states.items() if max(c) >= 2),
            })
    return results


def opening_hand(deck_size):
    return {
        "deck_size": deck_size,
        "prob_core_two_copies": 1 - comb(deck_size - 2, 4) / comb(deck_size, 4),
        "prob_two_distinct_singletons": comb(deck_size - 2, 2) / comb(deck_size, 4),
    }


if __name__ == "__main__":
    result = {
        "scope": "Exact independent class draws and uniform opening hands; no compatibility, combat, gear or player policy modeled",
        "baseline": foreign_drops(False),
        "one_foreign_by_third_receipt": foreign_drops(True),
        "opening_hands": [opening_hand(size) for size in (10, 12, 14)],
        "example_base_30_by_mastery": {rank: 30 * (1 + 0.1 * rank) for rank in range(5)},
    }
    print(json.dumps(result, ensure_ascii=False, indent=2))
