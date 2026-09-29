# Recherche — caractéristiques et synergies propres à Catabase

28 septembre 2026. Travail de conception demandé après rejet du modèle Force/Finesse/Esprit/Ténacité. HEAD examiné : `5b3553c07472180d4af08ce4ebdd5ed42362766f` ; fichiers de travail concurrents préservés.

## Direction actuelle après recadrage

- L'utilisateur rejette une fondation organisée autour de combinaisons précises et fermées. Repartir d'une classification ouverte des statistiques, des classes de cartes, des éléments, des fonctions, des propriétés d'exécution et des raretés.
- Nouvelle proposition : `docs/design/fondations_stats_cartes_2026-09-28.md`. Une maîtrise élémentaire commune à toutes les classes ; les répertoires, attaques permanentes, passifs et équipements différencient leur utilisation. Les transformations ne sont plus une condition nécessaire de l'hybridation.
- Correction méthodologique : les calculs précédents portent sur un sort ou un état isolé, pas sur la richesse ni la balance d'un répertoire entier.
- Audit complémentaire : les origines, raretés, opérations, géométries et bonus contact/distance existent ; le rôle UI unique confond certaines composantes, notamment le drain. Aucun élément de maîtrise n'est encore défini dans les règles.
- HEAD relu pour ce recadrage, inchangé. Aucun code de jeu modifié. Les chiffres d'investissement, la palette finale et l'avantage natif restent des propositions à équilibrer.

## Historique de la recherche précédente

- Objectif : comprendre les contraintes qui créent de vrais builds dans BG3, DOS2, Wakfu, Waven ; comparer à des systèmes de cartes, puis proposer une structure adaptée à la run solo et à ses copies consommables.
- Rejet pris en compte : pas de deuxième effet hors combat imposé à chaque attribut ; pas de caractéristique universelle de dégâts ; pas de simple renommage de statistiques ou recopie des éléments suggérés.
- Pistes examinées : pondérations élémentaires seules ; exigences doubles et transformations de sorts ; éventuelle rémanence limitée d'une copie consommée. Ce dernier mécanisme doit justifier son coût de complexité avant d'être recommandé.
- Sources : BG3 wiki + annonce officielle du multiclassage ; fiches DOS2 et analyse du coût Corpse Explosion ; Wakfu Huppermage et correctif 1.92 lus dans le navigateur ; ancien devblog decks publié par Ankama sur Steam ; correctif Waven 0.20 relu ; articles de Mark Rosewater sur hybridation ET/OU ; FAQ officielle Gloomhaven.
- Point mathématique à vérifier : sous budget fixe et bonus linéaires, un sort 80/20 favorise l'investissement dominant ; un 50/50 peut être indifférent à la répartition. Les lignes multiples ne suffisent pas à garantir un build hybride.
- Audit local : 48 sorts relus ; quatre PA, main de cinq, quinze copies initiales. Vérifier disponibilité conjointe des fonctions, coûts de séquence, dilution du butin et accès aux sorts étrangers dès la création d'un build hybride.
- Dossier livré : `docs/design/systeme_synergies_2026-09-28/README.md`, avec enquête comparative, audit des 48 sorts, protocole d'intégration et calculs exécutables. L'ancienne proposition porte un avertissement de rejet.
- Direction recommandée : maîtrises par composante et transformations conditionnelles avec sacrifice explicite ; pas de nouvelle monnaie de runes. Prototypes Eau/Nuit (transport de marque), Feu/Eau (durée contre zone), Terre/Feu (protection contre explosion différée). Les valeurs 4 % / 8 % sont des paramètres d'expérience.
- Vérifications exécutées : calculs Python ; disponibilités recoupées par énumération des 3 003 mains possibles (1 001 avec ouverture imposée) ; audit de correspondance des 48 IDs ; empreintes de sources enregistrées. Résultats dans `CALCULS.json`, journal dans `artifacts/dev/systeme_synergies_2026-09-28/calculs.log`.
- Résultats : paire 3+3 copies disponible dans 51,45 % des mains initiales, fonctions redondantes 6+6 dans 91,61 %. Feu : un normal ; aucun normal Soleil étayé. L'ajout de seules statistiques ne suffit pas.
- Relecture : distinguer l'expiration du dépôt et l'échéance de la marque reçue pour permettre son exploitation au tour suivant sans prolongation. Coûts de préparation, surdégâts, ratés et déclenchements différés explicités.
- Fraîcheur : HEAD relu après production, inchangé. Aucun code de jeu modifié, aucun test Godot revendiqué. Suite éventuelle : fermeture du contenu normal manquant et prototype dans la vraie Battle ; balance, gestes de classe et progression longue restent à valider.
