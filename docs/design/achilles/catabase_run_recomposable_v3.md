# Catabase — même départ, trajectoires différentes

Référence de conception et d'implémentation du 7 septembre 2026. Cette V3 remplace le cadre expérimental V2 : la construction de build et la carte font partie de Catabase, accessible par la sélection habituelle d'Achille et sa cinématique.

## Le contrat de départ

Chaque run engage le même premier combat avec Frappe du Péléide, Percée fulgurante, Tir du Pélion et Garde d'airain, dans le même ordre. Achille possède ses statistiques, ses PA/PM, son inventaire initial et son déploiement canoniques. Aucun achat, carte ou retrait de sort ne peut modifier ce début. Le premier choix arrive après la première victoire : deux points de maîtrise permettent de renforcer une racine puis d'apprendre une nouvelle action, ou de répartir l'investissement.

La reprise repart de l'entrée enregistrée du combat interrompu ou de la dernière frontière de récompense/carte. Elle conserve les offres, les emplacements, les objets et les découvertes. Le prototype séparé « Les douze seuils » n'est plus une entrée du menu ; ses sauvegardes de format 1 sont incompatibles avec cette nouvelle structure et ne sont pas converties silencieusement.

## Une traversée de vingt étapes

Le chemin ordinaire contient quinze combats et cinq haltes. Deux bifurcations permettent de troquer une halte contre une rencontre, ou l'inverse : l'enveloppe est de quatorze à seize combats et six à quatre haltes. Tous les chemins se terminent à la vingtième étape.

La carte comporte quarante destinations principales et deux passages cachés. Elle expose les connexions, les grandes convergences, les haltes connues et les prochaines familles de récompense. Les contenus lointains sont masqués. Certains « ? » sont tirés à la création de la run et peuvent contenir une halte ou un combat ; consulter la carte ou charger la partie ne relance pas ce tirage. Le lore permet de révéler les passages cachés.

Les haltes ordinaires sont aux étapes IV, VIII, XII, XVI et XIX. Les étapes VII et XV portent des combats difficiles communs. Pâris conclut l'étape XX. Le choix d'un embranchement ferme des options jusqu'à la prochaine convergence.

Le parcours ordinaire utilise les cinq maps historiques et les dix nouvelles arènes. Un détour peut éviter une map ou revisiter une arène sur une rencontre supplémentaire. Le catalogue est un pool, pas une numérotation de difficulté ; l'affectation de chaque étape est explicite dans `ExpeditionRouteCatalog.MAP_BY_DEPTH`.

## L'arbre et le kit

Trois doctrines forment la structure permanente : Colère du Péléide, Leçon de Chiron et Égide d'Éaque. Leurs racines améliorent réellement Frappe, Tir et Garde. Leurs branches enseignent de nouvelles techniques et proposent des mutations, des signatures et des légendes. Affinités élémentaires et Serments du Styx deviennent accessibles par des découvertes au fil du parcours ; deux serments sont exclusifs.

L'arbre contient 55 nœuds. Le budget de 24 points impose de choisir une profondeur de spécialisation ou plusieurs ouvertures hybrides. La collection de sorts connus reste distincte du kit équipé. Un sort rangé reste disponible, une mutation ne donne pas un emplacement gratuit et deux formes d'une même famille ne peuvent pas être équipées ensemble.

Le cinquième emplacement s'ouvre au niveau 5. Au jalon XII, le joueur choisit entre un sixième emplacement et la mutation Tempête du Péléide. Le joueur dispose d'une correction de son dernier achat ; cette correction unique ne rembourse pas ses cartes ni ses découvertes. Les détails, coûts et effets sont dans [Doctrines et équipements](catabase_build_doctrines_equipment.md).

## L'économie des choix

| Ressource ou occasion | Règle actuelle |
| --- | --- |
| Départ | 0 obole, 0 point de maîtrise ; inventaire initial canonique |
| Victoire normale | 35 oboles ; XP de la rencontre ; points selon le jalon |
| Victoire difficile | 65 oboles ; choix de butin renforcé |
| Récompense de combat | Objet ou 40 oboles et 5 % PV max ; cartes de techniques à certains jalons et chez les élites |
| XP | Victoires uniquement ; une halte ne donne pas d'XP de combat |
| Marchand | Trois objets à stock unique ; prix de 70 + 3 × profondeur, puis +15 par rang de proposition |
| Halte hors marchand | Un équipement à acheter, récupération, lore et découverte ou tribut |
| Récupération | 45 oboles pour 30 % PV max ; une fois par halte |
| Lore | Fragment narratif, révélation d'un prochain secret et 20 oboles ; une fois par halte |
| Découverte élémentaire | 70 oboles dès IV ; également choix de récompense sur certains combats élémentaires |
| Découverte de serment | 110 oboles dès VIII, après découverte élémentaire dans les haltes ordinaires |
| Tribut du sang | 15 % PV max contre 80 oboles ; paiement non létal, une fois par halte |

Une halte est une petite scène à zones cliquables. Acheter un objet ne ferme pas les autres interactions : le joueur peut comparer, acheter, lire, équiper, puis choisir de repartir. Les reçus empêchent de réinitialiser les stocks, les soins et les gains en réouvrant l'écran. Le journal conserve les textes de lore lus et les transactions.

Les douze nouveaux équipements utilisent le système d'inventaire/équipement commun. Ils modifient des règles de combat réelles : attraction avant une frappe, mouvement avant un impact, arme à zone morte élargie, conversion plafonnée d'armure en dégâts, pari à bas PV, bouclier préservé jusqu'à l'offensive. Leur retrait supprime leurs effets ; leurs limites évitent les boucles de remboursement ou de soin.

## Trois trajectoires à éprouver

**Le briseur mobile.** Après I : Colère et Crochet, à la place de Garde. Rechercher ensuite le Levier des Myrmidons et un outil de sortie dans Chiron. Attirer la cible pour préparer une frappe devient le moteur du tour ; la fin de position compte davantage puisque le kit a abandonné sa défense immédiate.

**Le rempart qui frappe.** Conserver Garde, investir dans Égide puis Posture et Heurt. Acheter la Masse du rempart ou l'Agrafe du serment. L'armure ou le bouclier deviennent des préparations offensives. Les cartes à fronts multiples doivent faire payer les pertes de mobilité et les protections consommées trop tôt.

**Le tireur devenu élémentaire.** Renforcer Tir, puis payer une découverte au sanctuaire. Choisir entre une Javeline qui augmente la zone morte et un Fer de la fournaise qui pénalise les impacts physiques. Ranger une ancienne technique pour contrôler un pont par le terrain modifie la manière d'aborder les mêmes rencontres. Une branche révélée peut donc faire évoluer le projet commencé trois salles plus tôt.

Ces trajectoires sont des intentions de playtest ; elles ne constituent pas des recommandations de builds équilibrés.

## Créer la suite proprement

La [pipeline des maps](../../maps/catabase_expansion_v1.md) part d'une question tactique, d'un blueprint, de spawns sûrs et du rendu Catabase existant. Chaque arène est vérifiée en données, dans Arena Studio et dans une vraie scène avec le HUD. La passe artistique approfondie vient ensuite, sans modifier les collisions pour les faire correspondre à une peinture.

Pour les futures rencontres, commencer par les décisions du kit : fermer des lignes sans neutraliser tous les tirs ; offrir une cible à déplacer sans rendre Crochet obligatoire ; attaquer sur deux fronts sans rendre l'armure inutile ; punir une position sans imposer un sort de mouvement. Les adversaires, mini-boss et boss dédiés pourront ensuite remplacer les acteurs existants sans changer le contrat de départ et de récompense.

## État de validation

Les [commandes reproductibles](../../../tests/expedition/README.md) distinguent données, victoires simulées, casts réels et captures GPU. Une vraie première victoire confirme le passage du départ canonique à un remplacement de Garde par Crochet, puis au choix de route.

Les dix arènes supplémentaires sont jouables avec géométrie, palettes, props et terrains actifs. Les grandes peintures d'environnement, l'équilibrage des quinze combats enchaînés et la durée réelle d'une run restent à valider. La courbe de statistiques Champion conservée devient très généreuse en fin de parcours : le prochain playtest doit mesurer les ennemis éliminés en un tour, le poids réel des soins et le temps passé à approcher une cible avant toute hausse générale de difficulté.

Résultats de cette livraison : import Godot 4.7.1 en mode recovery terminé (code 0) ; route 12 785 contrôles et 3 456 chemins, build/équipement 1 000 contrôles, session 301 contrôles, données des maps 4 439 contrôles, scènes des dix maps 206 contrôles GPU, interface 140 contrôles GPU. Aucun échec d'assertion ni erreur de script dans ces passes finales. Les six suites de régression du Champion et des sorts totalisent 72 tests et 634 assertions réussis. Les probes de scènes signalent encore des ressources non libérées à la fermeture ; le test de session simule les victoires et ne mesure pas l'équilibrage.
