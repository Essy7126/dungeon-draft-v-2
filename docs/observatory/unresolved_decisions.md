# Décisions non résolues

- Statut : **CURRENT**
- Branche : `feature/observatory-truth-v1-1`
- Commit de référence : HEAD contenant ce document et contrat 1.1.0.
- Date UTC : `2026-08-06T10:45:38Z`
- Validation : comparaison du contrat, des faits runtime et des sources de production.

- Le modèle XP final reste inconnu. Le +1 par cast effectif, la restriction au même sort par activation et le plafond de 5 sont des faits runtime, pas des cibles validées.
- Le modèle « preuves de maîtrise » reste une recommandation jusqu’à décision explicite.
- Les Resources exportées ne portent pas de classification explicite `DEBUG`, `PLACEHOLDER`, `CHEAT` ou `TOOL`; toute classification automatique reste non certifiée.

- Run, salles et vagues ne possèdent pas d'identifiant métier explicite : leurs IDs Observatory restent dérivés de l'alias de manifeste et de l'ordre parent.
- La formation finale et les placements sont choisis au runtime ; seules les possibilités et contraintes statiques sont exportées.
- Le nombre et le moment réels des invocations dépendent du combat, des budgets, du plafond vivant, des cooldowns et de l'IA.
- Les dimensions de grille restent `runtime_only` lorsqu'aucune `RoomGridLayout` ne les expose de manière statique.
- Le multiplicateur d'attaque cible exclusivement `Unit.attack_power`. Son efficacité dépend de la présence d'une attaque de base active ; les dégâts de `Spell` ne lisent pas cette statistique.
- La persistance exacte des PV entre salles doit être exposée par une source statique dédiée avant d'être marquée comme observée automatiquement.
- Le choix « continuer ou sécuriser » reste non évalué tant qu'une définition statique stable n'est pas exportée.
- Les systèmes énergie, ferveur et éveil restent des cibles désactivées ; l'absence de symbole n'est pas une preuve suffisante de comportement.
- Les probabilités de récompense ne sont pas publiées sans poids explicites et autoritaires.
- L'architecture complète et le theorycraft avancé restent hors périmètre.
