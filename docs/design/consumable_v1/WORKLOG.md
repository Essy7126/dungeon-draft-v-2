# Construction V1 théorique — fiche active

Demande utilisateur : poursuivre la recherche en chaîne jusqu'à une V1 théorique complète, dont les cartes, équipements, statistiques et composants de run sont calculés, testés et comparés.

Base : 6a500c545f04d3e4c53a99d3643d0c4d844e303f. Les documents du laboratoire et les trois concepts du 24 septembre sont déjà non suivis. Aucun code public à modifier pour cette tâche ; prototype théorique autonome dans ce dossier.

Direction ferme : quinze exemplaires initiaux, consommation lors de l'usage, sacs sur les mobs, normales fréquentes, taux croissants, six raretés, deck limité à trente. Pas de bonus de drop par maîtrise, équipement ou performance dans le socle.

Périmètre de conception prévu : catalogue V1 fermé de 48 cartes/sorts, quatre classes et deux spécialisations par classe, équipement et reliques à effets explicites, douze combats sur vingt profondeurs, progression, marchands, troc, soins, fin de run et contrat de sauvegarde. Les comptes finaux feront foi dans le manifeste.

Méthode : spécifier les règles et données ; construire un modèle tactique autonome ; couvrir tous les effets ; calculer les seuils et conversions ; comparer des politiques de jeu et variantes ; corriger les échecs ; livrer les tables et la preuve de couverture. Les parties automatiques ne prouveront pas le plaisir humain ni l'intégration Godot. Les valeurs ne seront pas déclarées équilibrées sur la seule base de tests unitaires.

Décisions de prototype : stocks limités à la run ; déblocages extérieurs horizontaux ; réserve séparée du deck ; investissements de build attachés aux familles ; cartes non jouées conservées. À fermer explicitement dans les règles : pioche, secours, pression temporelle, limites des contrôles et économie complète.

État au 25 septembre 2026 : V1 `1.0.1-theory` rédigée et exécutée. Base Git revérifiée inchangée. Les seuls fichiers de produit touchés sont des documents du laboratoire ; aucun script Godot, aucune scène, aucune ressource publique modifiés. Aucun commit ni push.

Livraison : README de reprise, règles fermées, catalogue des 48 cartes et améliorations / 18 équipements / 8 reliques / 8 spécialisations, manifeste JSON, tables de progression et monstres, 336 répartitions de caractéristiques, 192 probabilités famille/classe, recherche complémentaire, bilan, journal des itérations et guide d’intégration.

Réglages retenus : sac garanti de deux normales par mob et second sac de deux à 50/60/75/90 % ; combats initiaux à budgets PV 1,4/3/4,2 P ; Gardien renvoie 0,25 P sur première attaque partiellement absorbée du tour ; vingt copies préparées par l’automate, plafond trente. Améliorations portées par les familles ; stocks à la run ; pas de modificateur de drop dans le socle.

Preuves exécutées : 2 304 cas de cartes, 672 comparaisons d’objets/spécialisations, 640 runs finales (52 groupes), 640 runs R1 historiques, 60 runs ciblées de renvoi Gardien. 212 tests réussis, dont 199 V1 et 13 du laboratoire précédent ; aucun ignoré. Cas internes : 135 paires d’équipement, 729 ensembles complets, 28 paires de reliques. Aucun import/test/runtime Godot exécuté pour ce livrable documentaire.

Vérification finale terminée : manifeste identique aux données, empreintes concordantes, tailles des tables vérifiées, 55 liens locaux vérifiés. Un contrôle final a trouvé une référence de ligne devenue obsolète après clonage transactionnel : le stock après récompense n’était pas toujours écrit dans l’historique. Correction dans `run.mjs`, test de continuité ajouté. La reprise complète avec `replay_runs.mjs` a confirmé **640/640 résultats identiques** pour les victoires, consommations, or, achats, drops, secours, dépenses et usages de cartes ; toutes les continuités de stock et d’or passent. COMPARAISONS_RUN.md a été régénéré avec les lignes corrigées. Les reprises ne sont pas comptées comme des graines inédites.

Commandes de contrôle : les quatre suites Node sont détaillées dans le bilan de cette tâche ; la commande courte de reprise est dans REPRISE_REPO.md. Les traces complètes sont sous `artifacts/dev/consumable-v1/`, les synthèses portables sont dans ce dossier. Le premier laboratoire et les trois concepts du 24 septembre restent présents et non suivis ; ne pas les effacer.

Limites : modèle tactique autonome 7 × 7, contrôleurs imparfaits, seulement un petit ensemble de graines pour comparer les variantes, validation interne réutilisée après constat du problème du Gardien, aucun joueur humain observé. Lire BILAN.md avant toute affirmation d’équilibrage. Prochaine étape produit : port expérimental versionné, concordance des traces Godot, puis sessions observées selon REPRISE_REPO.md.
