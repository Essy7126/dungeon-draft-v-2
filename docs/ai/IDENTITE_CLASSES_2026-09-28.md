# Fiche de travail — identité des classes

28 septembre 2026. Étude, pas implémentation. HEAD examiné : `5b3553c07472180d4af08ce4ebdd5ed42362766f` ; changements concurrents préservés.

- Demande : attaques de base distinctes, caractéristiques favorisant certains sorts, conséquences lisibles en combat et en expédition ; inspiration Dofus.
- Proposition : quatre attaques qui amorcent les passifs ; Force/Finesse/Esprit/Ténacité, trois points innés et six points libres ; accès choisi à une normale native par substitution d'une récompense existante ; options hors combat au palier 4 à développer.
- Différer un multiplicateur natif général ; ne pas amplifier les conversions marque/garde/drain deux fois. Aucun ajout de run ou de mode.
- Constat : 70 % natives + communes donne seulement 23,33 % de normales réellement natives. Premier palier, un ennemi : 3,105 copies attendues, 0,7735 natives ; risque sans native 44,38 %.
- Livrables : `docs/design/identite_classes_2026-09-28/README.md`, `calculs.py`, `CALCULS.json`, `.gdignore`.
- Vérification : 18 assertions arithmétiques passées ; aucune validation moteur revendiquée. Empreintes des sources dans le JSON. Sources Dofus datées/qualifiées dans le rapport.
- Suite si cette direction est retenue : classifier les 48 familles et leurs composantes, arrêter les règles de migration des trois attributs existants, prototyper dans les services actuels, comparer consommations/durées/stock à graines identiques. Les haltes à options restent du contenu à concevoir, pas un contrat prêt à porter.
