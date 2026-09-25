# Fiche de reprise — recherche systémique du 25 septembre 2026

Demande : approfondir chaque composante du concept de cartes consommables, examiner l'évolution de jeux de référence et confronter les principes au code de Catabase. Documentation et calculs ; aucune modification du gameplay.

Base Git inspectée : `6a500c545f04d3e4c53a99d3643d0c4d844e303f`. Les documents de conception du 24 septembre et le laboratoire sont déjà non suivis ; les préserver. Aucun autre changement observé au début de cette recherche.

Direction conservée : environ quinze exemplaires initiaux, usage unique dans la run, sacs sur les mobs, normales abondantes, taux croissants, rangs supérieurs rares, préparation avec plafond envisagé de trente. Le modèle standard précède les modificateurs de drop.

Corrections à intégrer : `early_supply` est une expérience locale non monotone, pas une base conforme à la progression souhaitée. Le paramètre de 70 % ne prouve aucune restriction de classe dans le jeu : les cartes hors classe peuvent utiliser une maîtrise de rang zéro. Distinguer disponibilité, utilité et emploi effectif.

Travail terminé : README de reprise, trois chapitres thématiques, 21 références commentées, résultats mathématiques, instantané CSV, script autonome et cinq nouveaux tests. Le point d'entrée parent renvoie ici ; l'ancien rapport porte les corrections sans effacer son expérience historique. Les résultats mesurent le financement d'un stock, jamais une victoire tactique.

Validation exécutée avec Node v24.19.0 :

```powershell
node --test --test-isolation=none docs/design/card_economy_lab/simulate.test.mjs docs/design/card_economy_lab/research_2026-09-25/systems_math.test.mjs
node docs/design/card_economy_lab/research_2026-09-25/systems_math.mjs --runs 20000 --seed 25092026 --out artifacts/dev/card-economy-systems
```

Résultats : 13 tests réussis, aucun ignoré ; 16 cas × 20 000 parcours, soit 320 000. Vérification complémentaire : 72 liens relatifs des douze fichiers Markdown du laboratoire résolvent ; 21 entrées bibliographiques ; CSV portable identique à la sortie calculée, seize lignes d'expériences. Aucun import Godot, test de combat ou test humain : le gameplay n'a pas changé.

Git revérifié à la fin : même HEAD, mêmes quatre chemins non suivis de documentation qu'au début, dont le laboratoire enrichi. Aucun fichier de jeu modifié, aucun commit ni push. Deux tentatives groupées de mise à jour documentaire ont échoué sur un contexte de texte ; elles n'ont appliqué aucun changement. Les ajouts ont ensuite été appliqués par blocs et les liens contrôlés.

Suite prioritaire : contrat de consommation, disponibilité des normales, amélioration par famille à comparer à l'amélioration d'exemplaire, mesure de consommation réelle et des gestes de secours. Ne pas implémenter la candidate de drop comme équilibrage validé ; ne pas ajouter les modificateurs avant de valider la base. Les sources, leur statut de preuve et les limites sont dans SOURCES.md ; les résultats complets sont régénérables.
