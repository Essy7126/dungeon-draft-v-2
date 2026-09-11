# Modèle de vérité Observatory

- Statut : **CURRENT**
- Branche : `feature/observatory-truth-v1-1`
- Commit de référence : HEAD contenant ce document ; snapshot rattaché par `meta.source_game_commit`.
- Date UTC : `2026-08-06T10:45:38Z`
- Validation : JSON Schema 2.1.0, tests GUT des faits runtime et validation Ajv du snapshot réel.

La nature de la preuve et la santé d’un constat sont deux axes indépendants.

## Nature de la preuve

| Valeur | Libellé | Usage |
|---|---|---|
| `observed` | OBSERVÉ | Lecture directe d’une Resource ou du code chargé. |
| `verified` | VÉRIFIÉ | Calcul déterministe ou test rejoué. |
| `design_decision` | DÉCISION DE CONCEPTION | Cible explicitement versionnée dans le contrat. |
| `recommendation` | RECOMMANDATION | Action suggérée, jamais présentée comme correction validée. |
| `non_certified` | NON CERTIFIÉ | Preuve absente ou insuffisante. |

## Santé ou impact

Les statuts `conform`, `difference`, `info`, `warning`, `blocking`, `unknown` et `not_evaluated` ne remplacent pas `truth_status`. Les audits conservent leur sévérité et qualifient séparément leur action suggérée comme `recommendation`.

## Faits runtime

`runtime_facts` contient une clé, une valeur JSON, un `truth_status`, les chemins sources, une preuve et des notes. Le +1 XP par cast effectif, la restriction par activation et le plafond par discipline y sont des faits runtime ; ils ne définissent pas le modèle XP final.
