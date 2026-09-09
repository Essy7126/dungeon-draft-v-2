# Sources des effets d'Achille V3

Ces sources accompagnent les corps classiques harmonisés sur le repos original. Les dessins ne changent ni les maîtrises acquises ni leurs règles.

- `source_projectiles.png` : bronze, allonge, flèche lourde, perforation, ligne de mort, volée ; quatre phases chacune. Génération `exec-6bf49fac-c74c-40d6-b3c3-0a196a9e3040`, alpha natif.
- `source_impacts.png` : les six impacts correspondants, quatre phases chacun. Génération `exec-1361bf6d-4cfd-4ddb-a8d7-182d81f4bf7c`, fond magenta explicitement détouré.
- `source_lightning.png` : quatre phases de flèche de foudre et quatre d'impact pour le véritable sort élémentaire d'expédition. Génération `exec-28ac622d-2f67-42af-bd9c-ca0931d2ceca`, alpha natif.

La variante physique lourde correspond à `push_distance > 0` dans le profil résolu, notamment Tir rapproché ou Trait de rupture. Flèche d'arrêt (`stopping_arrow`) ne déclenche pas cette variante à elle seule : avec Allonge, elle conserve `arrow_reach`. Les formes Perforante, Ligne de mort et Volée ont priorité sur leur posture inférieure.

Les prompts dans `generation_prompts.json` sont archivés verbatim. Leur ancien libellé artistique « HEAVY STOPPING » décrit la troisième ligne ; `runtime_semantics` précise son usage réel. La provenance de la foudre est dans `lightning_provenance.json`.

Le catalogue d'expédition possède de vrais sorts Feu, Glace et Foudre. Feu et Glace réemploient les sprites déjà disponibles dans l'atlas de Paris ; les soins confirmés réemploient le sprite du philosophe. Aucun pixel de corps n'est recoloré pour simuler ces éléments. Les couleurs des flèches physiques ne leur confèrent aucun élément. Les impacts et contrôles attendent les faits de combat.

Tous les originaux restent archivés sans modification. Les SHA-256, fenêtres, ancres et opérations sont enregistrés dans `assets/vfx/achilles_polish_v3/manifest.json` (48 régions physiques) et `lightning_manifest.json` (8 régions de foudre). Le détourage par script a été autorisé par l'utilisateur ; les sources à alpha natif conservent celui-ci.

Voir `tools/achilles_polish_v3_pipeline/README_effects.md` pour reconstruire les deux ressources. Les quatre anciens effets de charge/défense restent dans leur atlas V2.
