# Observatory Run Data V1

Le snapshot 2.0.0 ajoute sept collections obligatoires : `runs`, `rooms`, `waves`, `encounters`, `enemies`, `enemy_spells` et `ai_profiles`.

Les profils disponibles restent distincts du nombre de vagues résolu par la seed. Le roster initial reste distinct de la composition finale après invocations. Les totaux de PV et d'`attack_power` sont des calculs déterministes calés sur `Stat`; ils ne constituent ni un score de difficulté, ni une estimation de dégâts par tour.

Les IDs `first_run`, `first_run.room.NN` et `first_run.room.NN.wave.NN` sont des identifiants Observatory dérivés. Les rencontres utilisent leur chemin de Resource lorsqu'il existe. Les ennemis et sorts conservent leurs identifiants explicites de production.

Les audits V1 contrôlent la validité des quatre niveaux run/salle/vague/rencontre, les références ennemies et sorts, les budgets d'invocation, les profils d'IA et l'effet démontrable des multiplicateurs. Un audit décrit un écart ; il ne modifie jamais les Resources du jeu.
