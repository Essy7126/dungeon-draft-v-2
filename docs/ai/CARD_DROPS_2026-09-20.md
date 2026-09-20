# Cartes comme butin — Résonance des échos

Les cartes deviennent des drops réels : elles arrivent dans le bilan avec les
objets et sont acquises en réserve. Le deck actif n'est jamais changé automatiquement.
Les doublons sont regroupés dans le bilan ; vendre une carte n'efface pas le reçu.
Aucune étape de choix parmi trois cartes dans les nouveaux combats.

## Première règle de découverte

Résonance = min(100, 10 + profondeur plafonnée à 20 + danger + mémoire).

- Danger : 0 en normal, +20 en élite, +35 sur le boss.
- Mémoire : +15 par victoire précédente sans carte, maximum +45. Une victoire
  avec carte remet la série à zéro, même si la carte est ensuite vendue.
- Ni vitesse de combat ni PV perdus n'entrent dans le calcul : aucune incitation
  à prolonger un combat ou à prendre des dégâts pour augmenter le butin.

Chaque victoire effectue des jets indépendants, avec chances entières :

| Jet | Rencontres | Probabilité en % |
|---|---|---|
| 1 | Toutes | min(85, 45 + floor(0,4 × Résonance)) |
| 2 | Toutes | min(65, 12 + floor(0,4 × Résonance)) |
| 3 | Élite et boss | min(50, 10 + floor(Résonance / 4)) |
| 4 | Boss | min(40, 5 + floor(Résonance / 4)) |

Un succès donne une carte. Normal : 0–2 ; élite : 0–3 ; boss : 0–4.
Exemple au premier combat : Résonance 11, jets à 49 % et 16 %, soit 42,84 %
de ne trouver aucune carte, 49,32 % d'en trouver une et 7,84 % d'en trouver deux.
Ce sont des paramètres initiaux, pas une promesse d'équilibrage définitif.

Chaque carte a 70 % de chances d'appartenir à la classe principale, 30 % aux
trois autres classes à parts égales. Les starters sont toujours exclus.
Raretés possibles : usuelle dès le départ, rare dès profondeur 4, épique dès 10.
Les poids par rareté sont 100 / (10 + 0,3 R) / (2 + 0,15 R), normalisés sur
les paliers disponibles. Le nombre de techniques dans un palier ne dilue pas
ses chances. La famille est uniforme au sein de la classe et du palier retenus.

## Sauvegarde et interface

Tirage déterministe par graine et rencontre. Le reçu empêche une deuxième
attribution ; un rechargement ne relance pas le hasard. Les facteurs au moment
de la victoire sont enregistrés dans `battle_results.card_discovery` et affichés
dans le bilan (explication et chances au survol).

`ecosystem_revision = 2`. Une sauvegarde de révision 1 adopte les drops. Si son
ancien choix de trois cartes est encore ouvert, il est converti de façon
déterministe en butin et le bilan est rouvert pour le montrer. Objets, or, XP et
deck actif restent acquis. Une récompense déjà choisie n'est pas rejouée.
Les sauvegardes sans révision d'écosystème gardent leur économie antérieure.

La sonde de simulation équipe maintenant aussi les cartes déjà présentes en
réserve ; les anciennes mesures de difficulté du draft ne valident pas ces drops.

## Vérifications

- Parcours UI : `artifacts/dev/card_drops_ui_final_20260920/report.json`,
  **372 contrôles réussis, 52 captures**, 1280×720 et 1920×1080. Captures inspectées :
  combat sans carte, élite avec deux cartes et trois objets, explication de la
  Résonance au survol. Aucun écran de draft après les montées de niveau.
  Processus terminé à 0 ; aucun diagnostic d'erreur dans le journal moteur.
- Formateur du nouveau catalogue : succès avec vérification structurelle,
  `artifacts/dev/20260920-190809-format-core_expedition_card_drop_catalog.gd-576c7547/`.
- `./dev.ps1 test test/unit/test_catabase_class_run.gd` : **25/25**, 4086 assertions,
  import et analyse stricte réussis, sortie 0. Rapport :
  `artifacts/dev/20260920-191020-test-test_unit_test_catabase_class_run.gd-f94e207c/`.
  Couvre distributions sur 180 graines par type de rencontre, répétabilité,
  absence de starter, sauvegardes des quatre classes sur toute la route, reçus
  après vente, réserve sans changement du deck, mémoire et conversion d'un draft
  ancien sans double attribution. Les premiers passages ont permis de corriger
  les fixtures supposant un drop garanti et la normalisation des nombres JSON.
- `git diff --check` : aucun défaut d'espacement. La suite globale n'a pas été
  relancée pour cette modification ; son dernier relevé de 16 échecs, consigné
  dans la note précédente, n'est pas présenté comme résolu.

Fichiers : `core/expedition/card_drop_catalog.gd`, `class_cards.gd`,
`ui/expedition/class_combat_results.gd`, tests de la run Classes et sondes UI/balance.
Les règles de combat et kits ennemis ne changent pas dans cette itération.
Les résultats de difficulté de la révision 1 restent historiques ; aucun nouveau
taux de victoire humain n'est revendiqué.
