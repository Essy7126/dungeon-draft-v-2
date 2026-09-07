# Sources d’Achille peint G

Version peinte approuvée pour un second choix d’apparence dans Catabase. Le gameplay reste celui d’Achille classique.

- `generation_history.json` conserve le lot initial, les références, les corrections et le coût total.
- `directional_corrections.json` documente les dernières corrections arrière N.
- `build_config.json` fige les douze sources effectivement utilisées, les clés de fond, l’attribution de la flèche S, les cinq points de fond dans les arcs E, les échelles et les racines.
- `sources/` conserve les douze planches retenues et les rapports de segmentation. Les deux fichiers `hf_...png` sont les sources originales de l’assemblage de la planche `base_N.png` : première rangée de dash corrigée, deux rangées suivantes conservées de l’original.

Le script `tools/achilles_painted_g_pipeline/build.py` s’exécute dans le sandbox Higgsfield. Remplacer `outDir` dans la configuration par le répertoire de sortie désiré. Le résultat runtime est installé dans `assets/characters/Achilles/sprites_painted_g/` ; les contacts et GIF de validation sont dans `artifacts/achilles_painted_g_validation/final/`.

Les sources sont exclues de l’import Godot par `.gdignore`. Les 40 atlas runtime possèdent leurs réglages d’import Godot et utilisent une compression sans perte.

Contrat, branchement et vérifications : `docs/design/achilles/achilles_painted_g_integration.md`.
