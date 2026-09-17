# Catabase Cartes — variante parallèle

> État historique du 16 septembre. Le modèle hybride décrit ci-dessous est
> remplacé par la [correction du 17 septembre](CARDS_INTENT_REPAIR_2026-09-17.md) :
> gestes fixes, deck de manœuvres, préparation et progression dédiées.

Statut : WORKTREE_CANDIDATE, 2026-09-16. Dépôt
`https://github.com/Essy7126/dungeon-draft-v-2.git`, branche `main`, base
`8d5e7b9c8e68a9699ff74f813f8630f001db4a02`. Arbre initial propre ; aucun
changement de branche, commit, push ou modification de sauvegarde joueur.

## Demande et périmètre

DÉCISION VALIDÉE : ajouter la proposition de run deckbuilding avec cartes
acquises, réserve et revente, en parallèle de Catabase ; choisir les deux
depuis le titre. Achille et Passe-rive restent les deux apparences publiques.
Les chiffres sont un réglage de prototype, pas un équilibrage humain certifié.

La variante utilise les véritables PA/PM, dégâts, soins, IA, terrains, route,
XP, attributs et équipements existants. Aucun deuxième résolveur de combat.
Aucune augmentation des PV ennemis, modification des courbes classiques,
méta-économie, marché multijoueur ou transfert de puissance entre tentatives.

## Comportement implémenté

- Titre : sélecteur Classique/Cartes ; nouvelle partie et reprise concernent
  seulement la variante sélectionnée. Sauvegardes `catabase_route_v2.json`
  et `catabase_cards_v1.json`, dans le répertoire utilisateur Godot existant.
  Une mort efface le checkpoint de sa variante, pas celui de l'autre.
- Préparation existante conservée. 12 copies liées : 6 Gestes d'arme
  (deux choix, une seule action par copie), 3 copies de chaque technique choisie.
- Deck actif 12–18 ; maximum 3 copies par famille de technique, 6 Gestes ;
  minimum 2 Gestes et 2 techniques. Remplacement atomique, jamais un deck
  provisoirement invalide pour pouvoir remplacer une carte à la taille minimale.
- Ouverture choisie : 2 Gestes + 2 techniques. Capacité 4 puis 5 au niveau 5,
  éventuellement 6 par le choix XII. Une carte conservable ; reste défaussé.
  Recyclage de la défausse lorsque la pioche est vide. Recomposer coûte 1 PA,
  au plus une fois par activation ; ne repioche pas immédiatement la copie jetée.
- Consommation au paiement effectif dans SpellCaster. Cible invalide : rien
  consommé. Limites par activation/combat, recharges et réserves de soin
  existantes partagées entre copies. L'épuisement du combat n'efface pas la carte.
- Niveau effectif suit les statistiques du héros, sans second multiplicateur.
  Les formes apprises sont sélectionnables par famille entre les combats et
  figées à l'entrée ; une mutation n'est pas imposée comme une amélioration absolue.
- Drops par rencontre, non par ennemi : normale 1 + 25 % de bonus ; élite
  2 dont une Héroïque+ + 25 % de bonus. Rien d'inutilisable après Pâris.
  Reçus persistants et RNG séparé empêchent duplication et reroll au chargement.
- Tout drop rejoint la réserve, sans insertion automatique dans le deck.
  Filtres branches/serment/Urne, raretés vides renormalisées, doublons possibles.
  Une première acquisition enseigne la technique de base, pas ses mutations.
- Revente hors combat par copie : active/liée/favorite protégée. Annulation
  au prix exact tant que la collection reste ouverte ; non restaurée au chargement.
  Les copies gratuites d'arbre ne sont pas convertibles en monnaie ; la correction
  d'une maîtrise ne laisse pas de carte fantôme. Retirer sa carte du deck d'abord.
- Boutiques de 3 cartes aux marchands et refuges VII/XI/XVI, jamais XIX.
  Stock unique, aucun reroll ou réapprovisionnement.
- XP/or de victoire classiques conservés. En mode Cartes seulement, l'ancienne
  offre d'apprentissage disparaît au profit du drop et le choix de soin 5 %
  ne donne plus les 40 oboles. Un choix complémentaire objet/relique/soin reste.

## Réglages de départ

Raretés : Usuelle, Gravée, Héroïque, Mythique, Légendaire.

| Profondeurs | Poids nominaux dans cet ordre |
|---|---|
| I–V | 64 / 27 / 8 / 0,9 / 0,1 |
| VI–XII | 49 / 32 / 16 / 2,5 / 0,5 |
| XIII–XVII | 38 / 34 / 22 / 5 / 1 |

Élite garantie Héroïque/Mythique/Légendaire : VI 95/4,5/0,5 ; X 90/9/1 ;
XV 85/12/3. Un pool vide est exclu avant renormalisation : ces taux nominaux
ne sont pas des fréquences effectives garanties. Pondération thématique de
60 % vers l'axe de récompense lorsqu'il contient des candidats de cette rareté.

Prix achat : 50/75/110/160/230 ; vente : 8/12/20/32/50 oboles.
Le niveau et les mutations ne font pas monter le prix de revente.
Stock : une Usuelle, une Gravée, une Héroïque+ pondérée 90/9/1.

## Architecture et fichiers

`core/expedition/catabase_cards.gd` contient le modèle, transactions et
sérialisation ; propriétaire faible vers ExpeditionSession. Le marqueur
`session.cards_run` est absent des sauvegardes classiques. Le chargement
prépare et valide les objets détachés avant de remplacer la run vivante.

Intégration : ExpeditionSession, ExpeditionSaveService, GameManager,
SpellCaster, Battle et la barre d'actions existante. Présentation : titre,
ExpeditionScreen, CatabaseCardCollection et CatabaseCardHand. Les données de
combat et les fichiers des anciennes runs ne sont pas réécrits.

## Vérifications

Exécuté avec Godot 4.7.1 et GUT 9.7.1, dans des profils APPDATA isolés.
Les rapports stricts comprennent les diagnostics moteur, pas uniquement le
compteur d'assertions. Tous les résultats ci-dessous sont PASS, sans erreur moteur.

| Suite GUT | Tests | Assertions | Dossier sous `artifacts/dev/` |
|---|---:|---:|---|
| `test_catabase_cards.gd` | 13 | 466 | `20260916-140403-test-test_unit_test_catabase_cards.gd-29f6c00a` |
| `test_catabase_first_six.gd` | 12 | 1 137 | `20260916-134914-test-test_unit_test_catabase_first_six.gd-a40e1aba` |
| `test_catabase_death_flow.gd` | 6 | 67 | `20260916-135714-test-test_unit_test_catabase_death_flow.gd-e164e409` |
| `test_reliability_expedition_lifecycle.gd` | 15 | 201 | `20260916-135902-test-test_unit_test_reliability_expedition_lifecycle.gd-d3289763` |
| `test_pending_spell_presentation.gd` | 10 | 66 | `20260916-140144-test-test_unit_test_pending_spell_presentation.gd-53f148e8` |
| **Total ciblé** | **56** | **1 937** | Chaque dossier contient `gut-strict-report.json` et `gut.junit.xml`. |

La suite Cartes couvre départ/reprise des six armes, attribution unique,
vente/annulation, cartes liées, réserve, gate de sort au paiement, réactions
automatiques sans deuxième consommation, quotas de soin, recyclage,
recomposition, filtrage de l'Urne, boutique unique, sauvegarde malformée,
deux checkpoints simultanés, lancement par la même API que la sélection
publique, mort isolée, correction de maîtrise et formes partagées/figées.
Le parcours de récompenses I–XX de cette suite utilise des victoires de
fixture, pas des combats réellement gagnés.

**Probe visuel final :** 90 contrôles, 12 captures 1280×720/1920×1080,
dans `artifacts/catabase_run_balance_validation/cards_ui_verified/`.
Vrai titre, vrai Battle, mains de 4/6 cartes, conservation par le vrai bouton,
réduction sans mutation du deck, butin, réserve et achat réel au refuge VII.
Les captures de combat, butin et boutique ont été inspectées ; l'ancrage au
HUD réel corrige le chevauchement constaté en 1080p. La main peut être réduite
pour dégager les dalles. L'arrivée au refuge et les récompenses sont des
fixtures de progression ; ce probe ne constitue pas une victoire de run.

**Combats automatisés :** `artifacts/catabase_run_balance_validation/cards_smoke_final/`.
Deux parcours, Normal, seed 2401, politique `balanced`, IA et résolveurs réels,
sans HP réinitialisés entre combats. Chaque parcours atteint les 12 combats,
avec deux reprises de checkpoint réussies ; zéro erreur structurelle/moteur.

| Arme | Résultat du bot | Activations héros cumulées | PV finaux |
|---|---|---:|---:|
| Arc | Victoire contre Pâris, profondeur XX | 53 | 185 |
| Marteau | Défaite contre Pâris, profondeur XX | 60 | 0 |

Ce bot garde le deck de départ : pas d'intégration des drops, pas de vente,
pas de choix intelligent de conservation/recomposition. Il utilise les
maîtrises et équipements selon sa politique existante. Ces deux essais
prouvent un parcours fonctionnel, pas un taux de victoire ou un équilibre
entre armes ; aucun ajustement automatique de difficulté n'en est déduit.

Contrôle final : `git diff --check` sans erreur ; branche/HEAD inchangés.
Aucune suite CI globale lancée et aucun commit/push effectué.

## Rejouer les vérifications

Depuis la racine du dépôt, un seul processus Godot de validation à la fois :

```powershell
./dev.ps1 test test/unit/test_catabase_cards.gd
./tools/catabase_run_balance_validation/ui_probe.ps1 -Cards -Label cards_ui_new -TimeoutSeconds 300
./tools/catabase_run_balance_validation/run_validation.ps1 -Cards -Label cards_smoke_new -Seeds 2401 -Difficulties normal -Weapons 'arc,marteau'
```

Choisir un label neuf pour ne pas réutiliser les checkpoints d'un précédent
scénario de test. Sans `-Cards`, les harness restent sur le mode classique.

## Limites à garder explicites

- Il s'agit d'une première variante jouable, pas d'un catalogue inédit complet.
  Pas encore de nouvelles cartes persistantes/consommables à charges distinctes.
- Aucun taux de victoire humain ni durée 30–45 min validé par cette mission.
  Le bot de combat optionnel utilise le deck de départ sans construire un deck
  avec les drops, ni retenir/recomposer intelligemment : smoke test uniquement.
- L'économie partage les oboles avec armes, équipement et Péage. Les choix de
  vente humains et l'apport combiné objets + cartes restent à mesurer.
- Certaines raretés sont absentes sans leurs prérequis ; ce n'est pas une
  raison d'offrir automatiquement une légendaire ou de modifier le classique.
- Le butin et le marchand restent dans les écrans existants avec défilement ;
  la réserve peut devenir longue. La présentation est fonctionnelle, à affiner
  après les premiers retours de jeu, sans confondre butin acquis et choix d'objet.
- Suite globale/CI et plateformes autres que Windows non validées ici.
