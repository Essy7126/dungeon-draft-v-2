# Cartes — itération après audit, 2026-09-16

ITÉRATION TERMINÉE, WORKTREE_CANDIDATE, vérifiée le 2026-09-16.
Dépôt Essy7126/dungeon-draft-v-2,
`main@8d5e7b9c8e68a9699ff74f813f8630f001db4a02` + travaux locaux conservés.
Autorisation utilisateur : créer, adapter, tester et corriger après l'audit.
Aucun changement de branche, reset, stash, commit ou push autorisé/entrepris.

Objectifs : fermer les défauts de construction observés ; clarifier les cartes ;
rééquilibrer le budget de provisions sans toucher aux courbes de stats classiques.
Zones : modèle Cartes, validations de sort, UI main/réserve/butin, cadrage Cartes,
tests et probes associés, docs/ai. Pas de nouveau moteur ou méta-économie.

Verdict : défauts de construction confirmés corrigés et budget Cartes desserré,
**pas un équilibrage global certifié**. 132 runs / 1 090 combats, 23 tests Cartes
ciblés réussis et 156 contrôles UI finaux. Classique identique sur les 18 runs
appariées. Suite élargie toujours non verte : mêmes 16 échecs préexistants.
La difficulté humaine, particulièrement Disque/Hampe, reste à établir.

## Corrections conservées

- OBSERVÉ : recomposition refusée hors activation, après consommation de
  l'activation et après la mort ; rejet sans changer PA/main/pioche. Le modèle
  écoute la fin de tour, sans dépendre seulement du bouton désactivé.
- OBSERVÉ : `SpellModifier.get_preparation_failure_reason()` et l'API homonyme
  de préparation du `SpellCaster` fournissent les prérequis sans cible à la
  main. Disque déjà lancé, retour bloqué, bronze absent et oboles insuffisantes
  ne sont plus des actions présentées comme jouables. Les validations de
  portée/case/surface restent au résolveur, pas dupliquées dans l'interface.
- RÉGLAGE : provisions Cartes 20 oboles + soin 5 %, Classique toujours 40.
  Changer d'avis entre carte conservée, carte vendue et autre récompense garde
  un coût. Aucune compensation rétroactive des reçus déjà réclamés ; deux
  demandes du même butin ne donnent pas deux paiements.
- OBSERVÉ : la main occupe son propre dock à la place du HUD vide ; noms et
  PA sur plusieurs lignes, raisons d'indisponibilité au survol, commandes de
  déplacement/fin de tour et accès aux objets, sac, carte, sorts, fiche, journal.
  Les effets chiffrés indiquent leurs limites : base/brut, avant mitigation et
  bonus conditionnels. Répercussion affiche le bronze réellement disponible.
- OBSERVÉ : plateau recadré au-dessus du dock dans les scènes peintes Cartes,
  sans déformer les dalles ni changer leur logique. Le cadrage Classique reste
  dans sa branche d'origine. Compromis : marges sombres à 720p ; ce n'est pas
  encore une finition artistique ni une certification de toutes les maps.
- OBSERVÉ : réserve regroupée par famille (six Gestes = un panneau), nouvelles
  cartes en tête, remplacement local d'une copie avec comparaison, détails
  ouvrables sans survol, protection de famille et revente d'une copie éligible.
- OBSERVÉ : focus du butin corrigé par recherche du véritable ancêtre
  ScrollContainer ; le parent était codé en dur avant le regroupement. À 720p,
  les en-têtes redondants ont été retirés pour exposer le bouton d'ajout.

Fichiers de production : `core/expedition/catabase_cards.gd`,
`expedition_session.gd`, `catabase_combat_modifier.gd`, `core/spell_caster.gd`,
`core/spell_modifier.gd`, `battle/painted/painted_battle.gd`,
`ui/expedition/catabase_card_hand.gd`, `catabase_card_collection.gd`,
`catabase_card_text.gd`, `expedition_reward_card.gd`, `expedition_screen.gd`,
`ui/player_combat_log.gd`. README et quatre documents de suivi actualisés.
Les autres modifications déjà présentes de la variante ne sont pas revendiquées
comme corrections nouvelles de cette itération.

## Expériences et interprétation

Les vrais combats utilisent le banc existant (EnemyAI/SpellCaster/terrain,
continuité des PV, sauvegardes isolées) ; pas de victoire forcée dans les lots
de runs. Les captures de butin/refuge sont des fixtures de navigation, pas des
preuves que ces combats ont été gagnés à la main.

### Réglage économique, graines appariées 7201–7203

| Politique, six presets complets | Avant | Après | Combats après |
|---|---:|---:|---:|
| Deck initial, Normal | 5/18 | 6/18 | 158 |
| Deck initial, Facile | 11/18 | 11/18 | 185 |
| Adaptation `curated`, Normal | 2/18 | 3/18 | 132 |
| Adaptation `curated`, Facile | non mesuré | 3/18 | 179 |

72 nouvelles runs / 654 combats, sans erreur moteur. Le gain de victoire en
Normal est Arc/7202 pour les deux pilotes. Ce n'est pas un rééquilibrage réussi
de tous les presets. Le budget supplémentaire peut aussi déclencher un achat
mal choisi par l'heuristique : Marteau/7202 `curated` recule de XV à VI.
Les dommages et les statistiques du héros/ennemis n'ont pas été modifiés.

Meilleure victoire observée du lot initial : 46 activations héros en Normal,
44 en Facile. Ce sont des compteurs d'actions, pas des records optimaux ni des
minutes humaines. L'adaptation `curated` reste moins performante que le deck
de départ ; sa préférence statique pour les dégâts/PA ne planifie pas assez
l'ouverture, les quotas communs et la complémentarité. Ne pas déduire de son
échec que tous les drops sont inutiles.

### Contre-test d'une seule variable : protection Disque/Hampe

24 runs (2 presets × 3 graines × 2 difficultés × contrôle/variation), même
pilote informé, deck fixe. Seule la protection initiale devient `mixte` dans
le banc, jamais dans les presets de production.

- Disque : Normal 0/3 dans les deux cas, mais 7203 atteint XX au lieu de VI.
  Facile 0/3 → 1/3 ; 7202 gagne, 7203 atteint XV au lieu de XIII, 7201 recule
  de XX à XV. Le coût est notamment la perte du PM de la Tenue de traverse.
- Hampe : 0/6 dans les deux cas. Une défaite Normal passe de III à V ; toutes
  les autres profondeurs de défaite sont inchangées, dont VI sur les trois Facile.

VERDICT : hypothèse insuffisante pour imposer Lin gravé. Aucun changement de
protection ou nerf ennemi retenu. Le cas Hampe demande un pilote qui évalue
réellement surfaces, détours et exposition ; ces essais ne mesurent pas sa
maîtrise humaine ni ne prouvent sa viabilité.

## Preuves reproductibles

Racine des lots : `artifacts/catabase_run_balance_validation/`.

- `iteration_economy_starter_20260916`, `iteration_economy_curated_20260916` :
  `summary.json`, `report.json`, `process.json`, logs ; 36 runs par lot.
- `iteration_armor_control_20260916`, `iteration_armor_mixte_20260916` :
  12 runs par lot ; policies de diagnostic seulement dans `studio_audit_probe.gd`.
- `iteration_cards_ui_final_20260916` : **14 captures, 156 contrôles PASS**, zéro
  erreur moteur, tailles 1280×720 et 1920×1080. Boutons réels : conserver,
  ouvrir objets/revenir, réduire, remplacer une copie légale, acheter une fois.
  Les deux boutons d'ajout du butin fixture sont visibles sans défilement.
- Suite modèle : **16 tests / 505 assertions PASS**, rapport strict
  `artifacts/dev/20260916-153310-test-test_unit_test_catabase_cards.gd-37cbd5bf/`.
  Inclut les trois nouveaux tests (refus hors tour atomique, prérequis
  disque/bronze/PA, provisions 20/40 et absence de double récompense).
- Analyse : `tools/catabase_run_balance_validation/analyze_cards_iteration.py`
  produit `cards_iteration_analysis/comparison.json` et `paired.csv`, avec
  hashes des sources et liste des lots manquants. Ne réécrit pas l'audit initial.

Échecs intermédiaires conservés : v1 parsing d'un bool Variant (corrigé), v2
3 contrôles de focus/butin en échec, v3 152/152 mais capture encore trop chargée,
v4 156/156, puis lot final ci-dessus après précision du texte de dilution.
Les captures ont motivé un contrôle plus strict sur les vrais
boutons d'ajout ; un sélecteur visible seul ne suffisait pas.

### Contrôle Classique et graines non utilisées pour le réglage

- `iteration_classic_control_20260916` : 18 runs Normal / 137 combats,
  4 victoires comme avant. Comparaison de **tous les champs des combats sauf
  `seconds`** et de l'issue de chaque run : aucune différence sur les 18 paires.
  Pas de requalification du Facile Classique, qui n'a pas été rejoué ici.
- `iteration_heldout_20260916` : 18 runs Cartes Normal / 150 combats, graines
  7301–7303, pilote initial inchangé, 4 victoires (Arc ×3, Lame/7303).
  Disque meurt VI/V/V, Hampe V/V/III, Xiphos XX/XVII/XX. Meilleure victoire
  du lot : Arc/7302 en 44 activations ; toujours pas un chronométrage humain.
- Total de cette itération : **132 runs, 1 090 combats résolus**. Les lots
  d'ablation de protection sont séparés de la production dans l'analyse.
  Zéro erreur moteur dans ces six lots ; défaites conservées dans les rapports.

### Régression élargie : non verte, sans nouveau cas en échec

`./dev.ps1 test catabase` : **479 tests, 463 réussis, 16 échoués** ;
69 711 assertions réussies / 69 842. Aucun test supprimé/ignoré pour cette passe.
Rapport strict :
`artifacts/dev/20260916-160717-test-catabase-ad18eb93/gut-strict-report.json`.

Comparaison avec le lot du même HEAD exécuté ce matin avant l'itération :
`artifacts/dev/20260916-113956-test-catabase-6d1f2f88/gut-strict-report.json`
(463 tests, 447 réussis, mêmes 16 échecs). Identifiants d'échec et textes des
erreurs moteur strictes **identiques** ; avertissement final identique aussi
(3 973 ObjectDB, 103 ressources). Ce constat ne certifie pas l'absence de tout
défaut ; il borne la non-régression mesurée. La CI globale n'a pas été exécutée.

Les échecs restent : glyphes (2), images Meshy (2), icônes peintes (3), ancien
lancement (2), ancien seuil (3), vertical slice/formation (2), inventaire (2).
Le test `test_catabase_selection_launch.gd:82` accède toujours à une salle nulle
avant la préparation ; l'analyseur l'étiquette PARSE_ERROR, mais le diagnostic
réel est un accès invalide runtime, pas une nouvelle erreur de syntaxe.
Les fuites du lot global restent non attribuées ; les lots Cartes isolés et
les runs n'en rapportent pas. Aucun de ces défauts n'a été masqué ou déclaré réparé.

### Stress mécanique final

`./dev.ps1 test test/unit/test_cards_studio_audit.gd` : **7/7 tests,
71 690 assertions PASS**, aucun diagnostic moteur. Rapport strict :
`artifacts/dev/20260916-161425-test-test_unit_test_cards_studio_audit.gd-6cbe39f1/`.
Observations nouvelles dans `studio_mechanics_iteration/observations.json` ;
le dossier historique `studio_mechanics` n'a pas été réécrit.

180 000 tirages conditionnels, 30 000 mains, 6 000 tentatives de transactions,
60 reprises JSON et 1 000 parcours de drops sans combat : conservation des
copies, deck légal, soldes non négatifs et modèles de distribution inchangés.
L'observation `accepted_after_hero_end_turn` est maintenant `false` et vérifiée
par assertion ; le vrai payload de Répercussion reste 15/45/45 dans les trois
cas bronze 10/30/80 du profil testé. Ce sont des fixtures, pas des runs gagnées.
Comparaison JSON des autres groupes d'observations avec l'audit initial :
aucune différence. Seul le refus hors tour change comme attendu.

Contrôle final : `git diff --check` passe, HEAD et branche inchangés ; aucune
donnée sous `data/` ni preset de départ modifié. Pas de commit/push. Les profils
de test sont isolés des sauvegardes du joueur. Les empreintes de production et
comparaisons sont dans `cards_iteration_analysis/comparison.json`.

## Limites et suite utile

- INCONNU : durée/plaisir humains, apprentissage, performance GPU représentative,
  confort manette, animations Passe-rive et toutes les combinaisons de maps/cartes.
- OBSERVÉ : le pool et les règles de rareté restent ceux du prototype initial ;
  cette itération n'ajoute pas de cartes transformant radicalement le plateau.
- RECOMMANDATION : prochaine itération de gameplay = petit test contrôlé d'un
  noyau de cartes à décisions spatiales, avec mêmes graines/kit de référence,
  plutôt que hausse générale de puissance ou production massive de variantes.
- Référence technique pour les boutons multilignes :
  [Godot Button, autowrap_mode](https://docs.godotengine.org/en/stable/classes/class_button.html).

Acceptation : pas de régression Classique, pas de copie/double paiement,
précondition explicite avant ciblage, refus hors tour sans mutation, textes
d'actions lisibles à 720p/1080p, tests réellement exécutés. Les nouvelles valeurs
restent des réglages de prototype, pas une difficulté humaine certifiée.
