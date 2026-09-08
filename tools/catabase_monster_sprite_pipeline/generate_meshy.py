"""Ancienne génération distante de spritesheets : commande retirée.

Meshy fournit uniquement les vues fixes indépendantes via generate_views.py.
Les poses et spritesheets sont ensuite créées localement avec animate.py.
L'import de ce module reste compatible pour ROOT/CREATURES, sans API Meshy.
"""
import sys

from creature_specs import ROOT, CREATURES


def main() -> int:
    print(
        "Commande retirée : aucune spritesheet animée ne doit être demandée à Meshy.\n"
        "Vues fixes : python tools/catabase_monster_sprite_pipeline/generate_views.py\n"
        "Préparation : python tools/catabase_monster_sprite_pipeline/prepare_views.py --prepare\n"
        "Animation locale : python tools/catabase_monster_sprite_pipeline/animate.py --slug all\n"
        "Consultez le README du pipeline pour la revue des sources et des articulations.",
        file=sys.stderr,
    )
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
