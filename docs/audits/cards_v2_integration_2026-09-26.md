# Audit d’intégration Cartes V2 — 26 septembre 2026

Demande : vérifier l’intégration venant d’être réalisée. Base Git :
`c6ab5a72c1789e4cc285300c9bbae9c78524fa05`, arbre local contenant aussi des
travaux de sélection, audio, sprites et VFX. Ces travaux n’ont pas été annulés.
Les preuves ci-dessous concernent cet arbre local, pas une branche isolée.

## Conclusion

Le fonctionnement du profil Cartes V2 est validé par les tests Cartes et les
captures examinées. La livraison reste une version de calibration explicitement
sélectionnée au menu. Elle n’a pas une validation globale du projet : plusieurs
gates restent en échec et l’atelier Objets n’a pas encore une analyse adaptée
aux règles V2. La réception humaine et l’équilibrage restent à faire.

## Défauts corrigés pendant cet audit

| Priorité | Défaut | Correction et preuve |
|---|---|---|
| P1 | Les dégâts périodiques, indirects ou de terrain absorbés par la garde alimentaient le compteur réservé aux attaques ennemies. Cela pouvait accorder un bonus d’Urne/Dette de bronze non mérité. | Filtrer la classification et l’équipe avant l’incrément dans `consumable_card_turns.gd`. Test par trois catégories exclues puis une attaque adverse ; vérification de la riposte Gardien. |
| P1 | Le compteur d’absorption pouvait rester présent entre deux rencontres. | Réinitialiser les deux compteurs au début du combat dans `consumable_cards_state.gd`. Le test termine un combat après absorption et vérifie que Bronze ne donne pas de garde au premier tour du suivant. |
| P2 | Deux créations avec le même seed dans la même seconde pouvaient partager leur identifiant, donc fusionner leur bilan dans la chronique. | Identifiant aléatoire de 128 bits indépendant des flux RNG de gameplay. Deux départs rapides avec le même seed conservent deux bilans distincts. |
| P2 | Le détail de carte et la portée de la main affichaient les valeurs de base malgré les bonus d’équipement ou la réduction Archive. | En combat, coût et portée proviennent des mêmes méthodes `Unit`/`SpellCaster` que l’exécution. Hors combat, la fiche précise qu’elle montre les valeurs de base. Test du texte affiché et de la consommation du bonus Archive. |

Trois échecs antérieurs provenaient aussi des fixtures : cibles hors des portées
minimales lors du test des 96 formes, même famille rejouée dans une activation,
comparaison stricte entre entiers et nombres relus depuis JSON. Les fixtures ont
été corrigées sans assouplir les règles de jeu.

## Vérifications du fonctionnement

- **Données** : le catalogue runtime et le manifeste préparé ont le même SHA-256
  `F7858B253A6AF464563E18B25FC55CC504BDE2B0EF40E37859339639BDFE10DF`.
  Les 48 familles / 96 formes sont construites et réellement jouées dans les
  fixtures avec consommation d’un UID. Cela ne couvre pas toutes les combinaisons
  possibles de cartes, états et reliques.
- **Persistance** : validation de l’état détaché avant écriture/publication,
  rejets sans dépense, reçus non rejoués, erreur d’écriture bloquante puis reprise,
  RNG, Relais en attente, surfaces, phase ennemie et santé après équipement.
- **Profils** : choix explicite et fichier V2 distinct ; les tests couvrent
  l’exigence de confirmation avant remplacement et la conservation des fichiers
  des autres profils. Les anciens tests Cartes et Classique de la suite passent.
- **Parcours** : douze rencontres et vingt profondeurs, récompenses, marchands,
  progression et rechargements. Le scénario de parcours affaiblit les ennemis et
  soigne le héros : preuve des transitions, pas de difficulté. Un autre scénario
  gagne le premier combat avec ses PV ennemis normaux.
- **Studio** : sept ArenaDefinition et 26 objets publiés via les services
  existants. Validation, copie détachée, fingerprint, undo/redo et concordance
  équipement/manifeste testés. La nouvelle publication ne signale plus les
  26 fuites UndoRedo de la première exécution.
- **Visuel** : captures réelles à 1200×896 et 1280×720 du départ, de la
  préparation, du combat, du ciblage, de la prévision, du dossier et du marchand.
  Les quatorze images ont été inspectées. Commandes accessibles ; contenus longs
  dans des zones défilantes.
  Le marchand est une fixture d’interface, pas la preuve d’une victoire.

## Preuves exécutées

Les chemins sont relatifs à la racine du dépôt. Un contrôle rouge reste rouge ;
l’allowlist et les gates CI n’ont pas été modifiées.

| Contrôle | Résultat | Rapport |
|---|---|---|
| Import et suite V2 après les quatre corrections | PASS, 49 tests / 2 624 assertions | `artifacts/dev/20260926-222704-test-consumable-v2-26b70495/summary.json` |
| Import et suite Cartes élargie, avec test supplémentaire d’entrée et parité des objets | PASS, 166 tests / 14 092 assertions ; 50 tests V2 inclus | `artifacts/dev/20260926-223039-test-cards-259adf66/summary.json` |
| Publication Studio V2 | PASS, 7 maps / 26 objets | `artifacts/consumable_cards_v2/content_publication.json`, `publication.stderr.log` |
| Deux séries de captures V2 | PASS, 14 images produites, aucun message d’erreur moteur | `artifacts/consumable_cards_v2/capture*.engine.log`, images `01_*` à `07_*` |
| Références de ressources sérialisées | PASS, 12 210 fichiers, zéro ressource externe manquante | `artifacts/consumable_cards_v2/audit_resources.json` |
| Smoke Rencontre | PASS, sortie 0 | `artifacts/consumable_cards_v2/encounter_smoke.engine.log` |
| Smoke Terrain avec `--headless` | FAIL : le renderer dummy ne produit pas d’image de viewport | `artifacts/consumable_cards_v2/terrain_smoke.stderr.log` |
| Reprise du smoke Terrain avec rendu GL | Cinq captures produites, `failures=0`, sortie 0 ; erreurs de ressources/RID non libérés à la fermeture, donc contrôle non propre | `artifacts/consumable_cards_v2/terrain_graphical.stdout.log`, `terrain_graphical.stderr.log` |
| Smoke Objets historique | FAIL : sélection de sort vide et projection sans héros compatible | `artifacts/consumable_cards_v2/item_smoke.stderr.log` |
| Contrats Studio, liste exacte de la CI | FAIL, 522 tests : 494 réussis, 28 en échec ; 17 552 assertions réussies sur 17 668 ; sortie 1, sans timeout ni crash | `artifacts/dev/20260926-223513-test-studio-758187c7/summary.json` |
| Départ et reprise par GameManager | PASS : sélection, départ, déplacement, sauvegarde en phase ennemie, reprise sur la scène V2, acteur suivant et conservation des deux fichiers historiques | `artifacts/consumable_cards_v2/public_entry.json`, `public_entry.engine.log` |
| Empreintes V2 avant/après Cartes et Studio | PASS : 65 fichiers comparés, aucune mutation | `artifacts/consumable_cards_v2/audit_mutation_check.json` |
| Suite globale exécutée pendant l’intégration, avant les corrections propres à V2 de cet audit | FAIL, 3 144 tests, 166 tests en échec, crash de fermeture `-1073741819` | `artifacts/dev/20260926-155430-test-all-b864d248/`, `artifacts/consumable_cards_v2/global_comparison.json` |

La comparaison du dernier `all` à l’exécution précédente trouve 169 → 166 tests
en échec, aucune nouvelle identité d’échec et trois échecs Studio résolus. Cela
ne rend pas la gate verte : l’allowlist en attend huit et la fermeture plante.
Les changements de cet audit sont propres à V2 ; la suite Cartes a été relancée.
Le `all` antérieur n’est pas présenté comme une nouvelle preuve de ces changements.
Les deux passages globaux provenaient d’un arbre local en cours de modification :
leur comparaison ne remplace pas une baseline propre d’avant la refonte.

Les 28 identités de tests Studio en échec étaient toutes présentes dans le dernier
rapport global : `artifacts/consumable_cards_v2/studio_comparison.json`.
Les cinq captures du smoke Terrain ont aussi été inspectées. La vue Rencontre
présente encore des commandes rognées à droite en 1280×720 ; la réussite de la
production des images n’est donc pas une validation complète de l’interface Studio.
Le seul échec de `test_item_studio_v1.gd` est l’empreinte de caractérisation du
catalogue historique ; ses empreintes obtenue/attendue sont identiques aux deux
rapports globaux antérieurs. Les 51 autres tests de ce script passent.

Le smoke d’entrée utilise `tools/consumable_cards/integration_smoke.tscn` et refuse
de s’exécuter hors de son répertoire APPDATA isolé sous `artifacts/`. Il vérifie les
handlers GameManager et la destination demandée ; les clics du menu ne sont pas
automatisés dans ce smoke. Une première comparaison textuelle de checkpoint a
échoué sur `3` versus `3.0` ; les valeurs JSON étaient identiques. L’assertion
normalise désormais les deux côtés et le smoke complet passe sans erreur moteur.

`git diff --check` réussit. Les empreintes des 65 fichiers ne certifient pas
l’absence de mutation dans tout l’arbre, déjà modifié et utilisé par d’autres
travaux. La gate CI exigeant un arbre entièrement propre n’est pas déclarée verte.

## Intégration restante et limites

1. **P2 — atelier Objets V2 incomplet.** Les services de contenu sont intégrés,
   mais le panneau générique d’analyse n’interprète ni `profile_modifiers` ni
   `profile_relic_rule`. Son catalogue par défaut ne propose pas le catalogue V2.
   Il ne faut donc pas utiliser une projection générique comme preuve d’effet V2.
   Une entrée de catalogue et une analyse adaptées au profil restent à réaliser.
2. **P2 — smoke Objets historique rouge.** `hache_executeur.tres` est limité à
   `warrior`. Le catalogue courant n’offre pas de héros compatible à cette fixture.
   La branche vide de `_rebuild_spell_analysis_choices` laisse le choix de sort
   sans métadonnées Dictionary, puis `_remember_ui_state` tente de le convertir.
   Les erreurs concernent des fichiers non modifiés par cette refonte. Elles sont
   conservées dans le rapport, sans réintroduire un ancien personnage pour cacher
   le défaut.
3. **Validation globale non acquise.** Les erreurs du `all`, des contrats Studio,
   du smoke Objets, les fuites à la fermeture du smoke Terrain et
   les chemins locaux historiques de provenance VFX empêchent une certification
   CI complète. Le garde-fou de formatage a également refusé certaines expressions
   complexes ; aucun formatage intégral n’est déclaré réussi.
4. **Présentation et balance.** L’écran V2 réutilise le rendu de grille et les
   personnages, mais n’intègre pas encore toute la mise en scène du combat
   historique. Les quatre identités, la pression et l’économie doivent être
   évaluées en parties humaines avant toute bascule par défaut.
