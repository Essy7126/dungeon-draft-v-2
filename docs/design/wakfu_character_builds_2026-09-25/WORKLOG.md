# Reprise — personnages WAKFU

Demande complémentaire : approfondir les personnages WAKFU avant de terminer, puis commit et push de l'ensemble sur `main`. Autorisation explicite de l'utilisateur ; aucune publication séparée ni modification du moteur demandée.

Base contrôlée : `24053adbb4a41f9442f14a6c23ca721b8c413c8b`. Les recherches antérieures et le début du catalogue StS ont été intégrés à main pendant le travail ; ils sont conservés. Le nouveau dossier prolonge les 130 identifiants WAKFU lus dans les dossiers précédents.

Collecte effectuée : 38 fiches avec Effets et Description, 18 classes, 37 passifs et Soif. 36 identifiants supplémentaires ; Maître du cadran et Assimilation sont des relectures. Au total, 166 identifiants WAKFU distincts dans les trois dossiers, sans prétention d'exhaustivité du catalogue du jeu. Contexte 1.93 recoupé avec les communications Ankama sur Steam ; WAKFULI reste une source communautaire dont les champs ne sont pas certifiés par ce recoupement.

Décisions : garder les désaccords Fugitif et Fermentation visibles ; ne pas additionner les états développés dans Démineur ; ne pas promettre une annulation des échéances par Maître du cadran. Présenter deux directions par personnage, avec sacrifice et contre-jeu, plutôt qu'un build optimal non joué. Préserver le ravitaillement de copies consommables par sacs de monstres et les plafonds d'éligibilité des morts.

Fichiers de travail : `lectures.tsv` pour les faits sourcés, `PERSONNAGES.md` pour les architectures, `APPLICATION_CATABASE.md` pour la comparaison. Les scripts reconstruisent les exports Markdown/JSON intentionnellement livrés pour reprise sur un autre ordinateur.

Vérifications exécutées : générateur de lectures, calculs W01–W15. Ils contrôlent 18 classes et 38 fiches ; les 15 assertions mathématiques passent. La vérification finale du dossier est enregistrée dans `VERIFICATION.json`. Les résultats locaux complets de la mission StS/V1 restent référencés dans son [journal](../slay_the_spire_complete_2026-09-25/WORKLOG.md).

Publication : grouper ces changements documentaires avec la clôture StS, vérifier les liens et `git diff --check`, commit Conventional Commits, puis push normal de `main`. Vérifier ensuite l'égalité des commits local/distant et l'absence de changements restants. Les logs et captures temporaires ne font pas partie du commit.

Suite produit : sélectionner une transformation de règle par classe, décider son ordre de résolution, puis tester le moteur et observer des joueurs. Les cas client non résolus sont explicités dans `SOURCES_ET_LIMITES.md` ; ils ne constituent pas des tests déjà réussis.
