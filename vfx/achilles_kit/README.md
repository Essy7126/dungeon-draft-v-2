# Effets sprite du kit Achille

La présentation observe le combat ; elle ne lance aucun sort, ne dépense aucun PA et ne change ni bouclier, ni dégâts, ni déplacement. L’atlas canonique est `res://assets/vfx/achilles_kit_v2/effects.tres`, avec quatre images par animation : `arrow`, `impact`, `sweep`, `guard`, `dust`, `barrier`. Les textures sont dimensionnées d’après la projection réelle de la grille, indépendamment de leur toile de 256 × 256 pixels. L’atlas est chargé à l’enregistrement de la vue de combat, avant le premier lancer.

## Chronologie

| Famille | Départ | Résolution et fin |
| --- | --- | --- |
| Tir / Ligne / Volée | Battle appelle `VFXManager.play_spell_vfx` au release ; le Tir possède un délai d’impact de 0,20 s. La flèche part de l’origine de projectile réelle, y compris Trait du destin. Volée utilise les cellules de l’éventail renvoyées par l’adaptateur ; Ligne traverse la dernière victime légale du profil. | Le temps de vol seul ne crée pas d’impact. `EventBus.spell_cast` confirme la résolution et remplace la flèche par un éclat sur les victimes réellement endommagées. Sans victime : retrait, sans faux impact. Un cast direct déjà résolu reçoit uniquement l’éclat. |
| Frappe / Fléau | Le geste est géré par le corps. | Le rapport résolu déclenche un éclat court ; Fléau ajoute un croissant orienté dans le sens du coup. |
| Garde / Rempart | Le geste est géré par le corps. | Une augmentation réelle de bouclier déclenche l’arc. La scène existante de Garde conserve son aura et son cycle de vie. Les pavois du Rempart observent les bloqueurs enregistrés et leur propriétaire via `barrier_visual_entries()` ; aucun nombre de cellules n’est supposé. `barrier_changed` retire immédiatement les pavois expirés. |
| Percée / Bastion | Le rapport de mouvement crée une poussière à l’origine et garde le contexte de l’action. | `unit_visual_movement_finished` est émis par Battle après la translation réelle. Bastion publie un fait de présentation seulement lorsque la réaction est réellement exécutée ; ce fait attend l’arrivée visuelle. Une décision de réaction prise après l’arrivée reçoit son effet à cette arrivée déjà confirmée. |
| Attaques automatiques | Aucun nouveau geste du corps ni vol tardif. | `spell_visual_resolved` est émis après le retour réel de `cast_automatic`. Un impact de 0,16 s montre les victimes réelles et conserve la chaîne d’origine. Aucun consommateur VFX ne réémet un événement gameplay. |

**Ordre de Bastion :** Battle diffère le traitement de la file de réactions jusqu’à l’arrivée réelle du corps. La consommation de Garde, les dégâts et la poussée sont alors résolus, puis cette couche en reçoit le fait de présentation. L’arrivée déjà enregistrée est acceptée, y compris pour une décision de réaction ultérieure. Les cellules des victimes sont capturées avant leur poussée ; l’effet exige la même action et la même destination. Cette couche VFX ne résout elle-même aucun effet gameplay.

Les effets transitoires utilisent leur propre horloge monotone et `Engine.time_scale`. Une reprise après pause réinitialise le point de mesure ; la durée passée en pause n’avance pas l’effet. Les pavois restent sur une image fixe. Un projectile non confirmé expire sans impact après son délai plus une seconde. Un changement de vue ou une fin de combat annule les projectiles, les marqueurs et les contextes d’arrivée.

## Observation et tests

Chaque effet appartient au groupe `achilles_spell_sprite_vfx` et expose `get_visual_runtime_state()` : `spell_id`, `family`, `variant`, `effect_variant`, `phase`, `origin`, `target`, `targets`, `elapsed`, `impact_reached`, `automatic`, `source_chain`, `cell`, `animation`, `closed`. Les phases sont `flight`, `awaiting_impact`, `impact`, `hold`, `cancelled`. Les positions sont globales. Un `impact_reached` vrai exige soit la confirmation du cast pour un projectile, soit un fait déjà résolu pour un éclat ou une barrière.

`test/unit/test_achilles_kit_sprite_vfx.gd` vérifie les horloges, l’absence d’impact inventé, le trajet entre engagement des PA et perte de PV, l’absence de projectile tardif, l’origine alternative et l’éventail légal, l’automatique sans coût, Bastion à l’arrivée, les cellules de Rempart en bordure et leur expiration, puis le nettoyage. Ces tests injectent des textures neutres uniquement pour isoler le comportement du chargement d’images ; le harness `tools/achilles_kit_sprite_validation` observe l’atlas réel et le rendu en combat.
