# WAKFU : personnages, passifs et décisions de build

Lecture complémentaire du 25 septembre 2026, demandée avant publication finale. Elle approfondit les **18 classes** : ce qu'elles préparent, ce qu'elles dépensent, comment leurs passifs changent les décisions et ce qui pourrait enrichir Catabase. Elle complète les [55 premières fiches](../dofus_wakfu_spell_identity_2026-09-25/WAKFU.md) et les [75 fiches des autres classes](../dofus_wakfu_spell_identity_2026-09-25/extension_classes_bestiaire/CLASSES_WAKFU.md).

**38 fiches relues directement**, dont 37 passifs et un actif, avec lecture des effets et descriptions : 36 ajouts et deux relectures Xélor. Les trois dossiers réunissent ainsi **166 identifiants WAKFU distincts**. Ce n'est ni un inventaire exhaustif de tous les sorts WAKFU, ni une certification de chaque combinaison dans le client 1.93. Les 18 portraits proposent chacun deux directions de construction, avec leurs sacrifices, et non des équipements optimaux prétendument testés.

| Pour reprendre le travail | Document |
|---|---|
| Lire les identités et les directions de build des 18 classes | [PERSONNAGES.md](PERSONNAGES.md) |
| Retrouver les contrats, nombres, sources et limites des 38 fiches | [LECTURES_COMPLEMENTAIRES.md](LECTURES_COMPLEMENTAIRES.md) ; source éditable [lectures.tsv](lectures.tsv) |
| Vérifier les calculs de seuil, de tempo et de ressource | [CALCULS.md](CALCULS.md), [script](calculs.mjs) |
| Comprendre les versions, les contradictions et la portée des preuves | [SOURCES_ET_LIMITES.md](SOURCES_ET_LIMITES.md) |
| Comparer au catalogue local et prioriser les essais | [APPLICATION_CATABASE.md](APPLICATION_CATABASE.md) |
| Reproduire les contrôles | [vérificateur](verifier_dossier.mjs), [résultat](VERIFICATION.json), [journal](WORKLOG.md) |

La conclusion de conception est de **changer les choix offerts par une amélioration** : déclenchement immédiat contre recharge, remboursement contre réserve, maîtrise convertie contre portée, survie contre puissance future. Les cartes normales doivent déjà permettre de jouer le moteur de classe ; les rares peuvent le transformer. Les drops de sacs sur les monstres restent le renouvellement principal des copies consommées.

Cette livraison complète aussi l'[étude intégrale des cartes de Slay the Spire 1](../slay_the_spire_complete_2026-09-25/README.md). Aucune modification du moteur Godot ni des tables de drop jouables n'est effectuée ici.

Reproduction depuis la racine du dépôt, avec Node.js et sans dépendance externe :

```powershell
node docs/design/wakfu_character_builds_2026-09-25/construire_lectures.mjs --check
node docs/design/wakfu_character_builds_2026-09-25/calculs.mjs --check
node docs/design/wakfu_character_builds_2026-09-25/verifier_dossier.mjs
```

Les deux premières commandes contrôlent les livrables sans les réécrire ; omettre `--check` pour les reconstruire après une modification des sources. Le vérificateur écrit son compte rendu. Les documents générés sont intentionnellement versionnés pour être lisibles sur l'autre ordinateur sans lancer d'outil.
