@tool
class_name SkillTreeGuidedTour
extends AcceptDialog

## Tutoriel manuel du Studio des personnages et compétences.
##
## Le composant reste découplé de la session d'édition : il demande au Studio
## principal d'afficher une cible et lui délègue entièrement l'exercice sandbox.

signal target_requested(target: StringName)
signal sandbox_requested

const PAGE_ID := 0
const PAGE_TITLE := 1
const PAGE_TARGET := 2
const PAGE_BODY := 3
const PAGE_ACTION := 4

const CHAPTER_ID := 0
const CHAPTER_TITLE := 1
const CHAPTER_PAGES := 2

const EFFECT_PAGES := [
	[&"effect_damage_all", "Dégâts supplémentaires", "Ajoute [b]Quantité principale[/b] aux dégâts de chaque unité définie par [b]Cible de l’effet[/b]. Exemple : +4 sur « Ennemis affectés » renforce chaque ennemi réellement touché."],
	[&"effect_damage_center", "Dégâts sur la case centrale", "Ajoute la quantité uniquement à l’unité de la cellule centrale. Les autres cellules d’une zone ne reçoivent pas ce bonus."],
	[&"effect_damage_low_hp", "Dégâts sur cible affaiblie", "Ajoute la quantité si la cible ennemie est sous le [b]Seuil de PV[/b]. Un seuil de 0,30 signifie moins de 30 % ; zéro rend la condition impossible."],
	[&"effect_damage_backstab", "Dégâts dans le dos", "Ajoute la quantité lorsque le lanceur est derrière la cible selon son orientation sur la grille au moment du lancement."],
	[&"effect_damage_backstab_or_low_hp", "Dos ou cible affaiblie", "Ajoute la quantité si l’attaque vient du dos [b]ou[/b] si la cible est sous le seuil. Ici les conditions forment un OU."],
	[&"effect_range", "Portée", "Ajoute la quantité à la portée maximale. Une portée 4 avec une quantité 2 devient 6 ; la portée minimale ne change pas."],
	[&"effect_heal", "Soin", "Ajoute la quantité de PV aux alliés définis par la cible de l’effet. La cible doit rester compatible avec les permissions du sort."],
	[&"effect_heal_low_hp", "Soin sur cible affaiblie", "Soigne seulement un allié sous le seuil de PV. Quantité 8 et seuil 0,40 rendent 8 PV sous 40 % de vie."],
	[&"effect_shield_target", "Bouclier sur les cibles", "Accorde la quantité de bouclier aux alliés sélectionnés par [b]Cible de l’effet[/b]."],
	[&"effect_shield_caster_if_ally", "Bouclier au lanceur après un soutien", "Accorde le bouclier au lanceur si la cible principale est un autre allié. Se cibler soi-même ne remplit pas la condition."],
	[&"effect_next_turn_mp_target", "PM à la cible au prochain tour", "Place sur la cible principale un modificateur de PM, positif ou négatif, résolu au début de son prochain tour."],
	[&"effect_next_turn_mp_caster", "PM au lanceur au prochain tour", "Place le modificateur de PM sur le lanceur. Les conditions avancées peuvent limiter son déclenchement."],
	[&"effect_status_dot", "Dégâts sur plusieurs tours", "Crée un statut infligeant la quantité à chaque résolution pendant la durée indiquée. Type, élément et moment choisissent la défense et le timing."],
	[&"effect_status_slow", "Ralentissement", "Crée un statut retirant la quantité de PM pendant la durée indiquée. Le groupe stable contrôle sa combinaison avec d’autres ralentissements."],
	[&"effect_status_regen", "Régénération", "Crée un statut rendant la quantité de PV à chaque résolution, au début ou à la fin du tour, pendant la durée indiquée."],
	[&"effect_status_vulnerability", "Vulnérabilité", "Ajoute la quantité de dégâts aux prochaines attaques reçues. [b]Charges[/b] limite les déclenchements et [b]Quantité secondaire[/b] peut produire des dégâts adjacents."],
	[&"effect_status_outgoing", "Dégâts infligés modifiés", "Crée un statut modifiant les dégâts produits par son porteur pendant la durée : positif pour renforcer, négatif pour affaiblir."],
	[&"effect_area_cardinal", "Agrandissement cardinal", "Ajoute autant de couches que la quantité dans les quatre directions autour de la cible, en conservant seulement les cellules valides."],
	[&"effect_push_bonus", "Poussée supplémentaire", "Ajoute la quantité à la poussée de base. Une poussée 2 avec un bonus 1 déplace de 3 cases."],
	[&"effect_push_exact", "Poussée exacte", "Remplace la distance de poussée par la quantité au lieu de l’ajouter. Utilisez-la pour imposer la distance finale."],
	[&"effect_collision_bonus", "Collision supplémentaire", "Ajoute la quantité aux dégâts lorsqu’un déplacement forcé rencontre réellement un obstacle ou une autre unité."],
	[&"effect_collision_exact", "Collision exacte", "Impose les dégâts de collision. Si plusieurs valeurs exactes existent, le runtime conserve la plus élevée."],
	[&"effect_terrain_duration", "Durée du terrain", "Ajoute la quantité à la durée du terrain créé par le sort. Cet effet ne crée pas de terrain à lui seul."],
	[&"effect_terrain_damage", "Dégâts du terrain", "Ajoute la quantité aux dégâts du terrain créé. Le sort doit déjà produire un effet de terrain."],
	[&"effect_cleanse", "Retrait d’effets négatifs", "Retire jusqu’à la quantité indiquée de statuts négatifs simples sur les alliés concernés. Zéro ne retire rien."],
	[&"effect_adjacent_heal", "Soin partagé", "Partage avec les alliés cardinaux une proportion du soin réellement reçu par la cible. Un ratio 0,50 partage 50 %."],
	[&"effect_shield_area_allies", "Bouclier aux alliés de la zone", "Accorde la quantité de bouclier à tous les alliés présents dans les cellules réellement affectées."],
	[&"effect_mp_area_allies", "PM aux alliés de la zone", "Ajoute la quantité de PM au prochain tour de chaque allié présent dans la zone résolue."],
	[&"effect_attack_buff", "Bonus d’attaque", "Applique à la cible alliée un bonus de dégâts : [b]Quantité[/b] fixe le bonus et [b]Charges[/b] le nombre d’attaques."],
	[&"effect_move_caster", "Déplacement du lanceur", "Déplace le lanceur sur la case ciblée ou près de l’unité. Destination libre et alignement sont obligatoires ; le chemin libre complet n’est pas éditable ici."],
	[&"effect_allow_free_cell", "Ciblage d’une case libre", "Autorise une cellule sans unité. Cet effet est booléen : il n’utilise pas la quantité et ne gagne rien à être ajouté plusieurs fois."],
	[&"effect_adjacent_shield", "Bouclier adjacent", "Accorde la quantité aux alliés sur les quatre cellules adjacentes à la cible, ou autour du lanceur sans cible."],
	[&"effect_shield_caster", "Bouclier au lanceur", "Accorde directement la quantité au lanceur après la résolution des dégâts, quelle que soit la cible principale."],
]

const CHAPTERS := [
	[&"start", "1 · Bien démarrer", [
		[&"welcome", "Bienvenue dans le Studio", &"studio_overview", "Le Studio modifie les données de progression sans ouvrir manuellement les fichiers .tres. Vous travaillez sur une [b]copie isolée[/b] : les vraies Resources ne changent qu’après une sauvegarde confirmée."],
		[&"workspace", "Les quatre zones de travail", &"studio_overview", "[b]En haut[/b] : contexte et commandes. [b]À gauche[/b] : catalogue. [b]Au centre[/b] : rangs, graphe et contrôles. [b]À droite[/b] : propriétés. Le panneau inférieur rassemble validation, statistiques, simulation, prévisualisation, analyse et aide."],
		[&"context_run", "Choisir la run", &"context_run", "Une run peut avoir son propre profil de progression. Changer de run recharge donc les compétences du héros dans cette run, après résolution explicite des modifications en cours."],
		[&"context_hero", "Choisir le héros", &"context_hero", "Le héros détermine le personnage de base et le profil de progression édité. Catalogue et graphe se synchronisent avec lui."],
		[&"context_room_scope", "Salle et portée dans cet écran", &"context_room_scope", "La barre est commune à tous les modules. [b]Salle[/b] n’agit actuellement sur aucune compétence. [b]Portée[/b] affiche le contexte commun, mais la sauvegarde reste attachée au profil run/héros. Le tutoriel ne leur invente donc aucun effet."],
		[&"guided_advanced", "Mode guidé et mode avancé", &"mode_toggles", "Le [b]Mode guidé[/b] montre explications, exemples et champs essentiels, et masque l’onglet Avancé. Désactivez-le pour voir les réglages techniques. Ce choix ne modifie jamais les données."],
		[&"undo_redo", "Annuler et rétablir", &"history", "Chaque modification rejoint l’historique de la copie. [b]Ctrl+Z[/b] annule ; [b]Ctrl+Y[/b] ou [b]Ctrl+Maj+Z[/b] rétablit."],
		[&"shortcuts", "Raccourcis utiles", &"toolbar", "[b]Ctrl+F[/b] recherche ; [b]Ctrl+S[/b] revoit puis sauvegarde ; [b]Ctrl+Z/Y[/b] gère l’historique. Dans le graphe, [b]Ctrl+C/V/D[/b] copie, colle ou duplique, et [b]Échap[/b] annule une liaison en cours."],
	]],
	[&"character", "2 · Personnage", [
		[&"character_catalog", "Trouver un personnage", &"catalog", "Recherchez par nom ou identifiant. Les filtres [b]Ressources invalides[/b] et [b]Document modifié[/b] isolent ce qui demande votre attention. Cliquez un héros pour ouvrir ses propriétés."],
		[&"character_identity", "Identité", &"inspector_character", "[b]Nom affiché[/b] est visible par le joueur. [b]Description[/b] résume le style. [b]Identifiant stable[/b] relie sauvegardes et Resources : ne le changez pas pour renommer."],
		[&"character_resources", "PV, PA, PM et initiative", &"inspector_character", "[b]PV maximum[/b] : dégâts supportés. [b]PA maximum[/b] : budget d’actions. [b]PM maximum[/b] : déplacement. [b]Initiative[/b] : ordre de jeu."],
		[&"character_power", "Attaque et force", &"inspector_character", "[b]Puissance d’attaque[/b] fournit une base aux calculs qui la consultent. [b]Force de déplacement[/b] intervient dans la puissance et la résistance aux poussées et attractions."],
		[&"character_defense", "Défenses", &"inspector_character", "[b]Armure[/b] réduit le physique avec rendement décroissant. [b]Résistance magique[/b] réduit le magique. [b]Esquive[/b] est un ratio : 0,15 signifie 15 %."],
		[&"character_critical", "Coups critiques", &"inspector_character", "[b]Chance critique[/b] du personnage s’ajoute à celle du sort. [b]Multiplicateur critique[/b] 1,5 signifie 150 % de la valeur normale."],
		[&"character_presentation", "Sorts actifs et présentation", &"inspector_character", "[b]Emplacements actifs[/b] limite les sorts équipables. [b]Scène de présentation[/b] choisit la PackedScene utilisée par les aperçus compatibles."],
		[&"character_existing_run", "Parties déjà commencées", &"inspector_character", "Ces réglages servent lors de la prochaine création du personnage. Une partie existante conserve son état sérialisé tant qu’une migration ne le remplace pas."],
	]],
	[&"discipline", "3 · Discipline et XP", [
		[&"discipline_concept", "Comprendre une discipline", &"catalog", "Une discipline est un chemin de progression lié à un sort de base. Ses rangs proposent des améliorations lorsque l’XP cumulée atteint leurs seuils."],
		[&"discipline_lifecycle", "Créer, dupliquer, renommer, retirer", &"catalog_actions", "[b]Nouvelle[/b] crée cinq rangs 0/5/12/21/30. [b]Dupliquer[/b] produit une copie indépendante. [b]Renommer[/b] préserve l’identifiant. [b]Supprimer[/b] détache après annonce des conséquences."],
		[&"discipline_settings", "Paramètres de discipline", &"inspector_discipline", "[b]Nom et description[/b] présentent la promesse de jeu. [b]Identifiant stable[/b] relie sort et sauvegardes. [b]Couleur[/b] et [b]icône[/b] assurent la reconnaissance visuelle."],
		[&"base_spell_link", "Associer le sort racine", &"inspector_discipline", "Le champ [b]Discipline associée[/b] du sort doit contenir l’identifiant de la discipline. Sans correspondance, le Studio propose de choisir un sort existant."],
		[&"rank_threshold", "Seuil total d’XP", &"rank_bar", "Le seuil est [b]cumulé[/b] : passer de 5 XP au rang 2 à 12 XP au rang 3 coûte 7 XP supplémentaires. Le Studio affiche aussi cette différence et le nombre de choix."],
		[&"rank_tools", "Outils de rang", &"rank_bar", "[b]+ Rang[/b] ajoute après le dernier. [b]− Dernier rang[/b] annonce les nœuds retirés. [b]Preset[/b] applique 0/5/12/21/30. [b]Répartir l’XP[/b] espace les seuils jusqu’au dernier."],
		[&"production_contract", "Contrat actuel", &"mode_toggles", "En mode avancé, ce contrôle facultatif attend cinq rangs, 0/2/4/8/4 choix et seize configurations finales. Une autre topologie reste autorisée et produit seulement des avertissements."],
	]],
	[&"graph", "4 · Graphe et choix", [
		[&"graph_reading", "Lire le graphe", &"graph", "Le sort racine est au rang 1. Chaque colonne suivante est un rang. Bleu continu : prérequis. Orange pointillé : exclusion. Le rang 2 dépend implicitement de la racine."],
		[&"node_create", "Créer une amélioration", &"rank_bar", "Utilisez [b]+ Amélioration[/b] ou le menu contextuel. Choisissez nom et rang ; le Studio génère un identifiant stable unique."],
		[&"branch_create", "Créer une branche complète", &"graph", "L’assistant ajoute un nœud dans chaque rang restant et les relie. Toute la branche forme une seule action annulable."],
		[&"prerequisites", "Prérequis", &"graph", "Tirez une liaison d’un rang inférieur vers un rang supérieur. Plusieurs entrées signifient que [b]toutes[/b] sont obligatoires : ET, jamais OU."],
		[&"exclusions", "Exclusions", &"inspector_relations", "Une exclusion interdit deux choix dans le même chemin. Cochez les incompatibilités dans Relations ; le Studio écrit la relation dans les deux sens."],
		[&"node_settings", "Paramètres d’une amélioration", &"inspector_node", "[b]Nom et description[/b] expliquent le choix. [b]Identifiant[/b] sert aux sauvegardes. [b]Rang[/b] déplace sans renommer. [b]Sort ciblé[/b] reçoit les effets. [b]Icône[/b] et [b]carte[/b] règlent la présentation."],
		[&"graph_bulk_tools", "Disposition et sélection", &"graph", "Le menu contextuel duplique, supprime, aligne ou répartit. [b]Organiser[/b] replace sans changer le gameplay. Un déplacement manuel épingle la position."],
		[&"graph_copy_paste", "Copier et dupliquer", &"graph", "[b]Ctrl+C[/b] mémorise la sélection, [b]Ctrl+V[/b] crée des copies et [b]Ctrl+D[/b] duplique directement. Les nouvelles Resources sont indépendantes."],
	]],
	[&"spell", "5 · Sort de base", [
		[&"spell_identity", "Identité du sort", &"inspector_spell", "[b]Nom et description[/b] sont visibles en combat. [b]Identifiant stable[/b] est utilisé par les améliorations. [b]Discipline associée[/b] relie la progression."],
		[&"spell_cost_range", "Coût et portée", &"inspector_spell", "[b]Coût en PA[/b] est consommé après réussite. [b]Portées minimale/maximale[/b] bornent la distance. [b]Ligne de vue[/b] interdit de cibler à travers les obstacles."],
		[&"spell_availability", "Disponibilité", &"inspector_spell", "[b]Recharge[/b] compte les activations. [b]Recharge initiale[/b] retarde la première utilisation. [b]Maximum par combat[/b] vaut illimité à zéro. [b]Une fois par activation[/b] bloque un second lancement dans le tour."],
		[&"spell_targets", "Cibles autorisées", &"inspector_spell", "Activez séparément ennemis, alliés, lanceur et cases libres. Une cible d’effet incompatible avec ces permissions produit un avertissement."],
		[&"spell_area", "Zone d’effet", &"inspector_spell_advanced", "[b]Forme[/b] : unique, croix, carré ou ligne. [b]Taille[/b] règle l’étendue. [b]Ligne depuis le lanceur[/b] oriente la zone depuis sa position."],
		[&"spell_direct_effects", "Effets directs", &"inspector_spell", "[b]Dégâts/soin[/b] sont les bases. [b]Physique/magique[/b] choisit la défense. [b]Élément[/b] choisit la résistance. [b]Critique du sort[/b] s’ajoute au personnage. [b]Poussée, attraction, bouclier[/b] s’appliquent directement."],
		[&"spell_terrain_status", "Terrain et statut", &"inspector_spell_advanced", "[b]Terrain[/b] et [b]statut[/b] référencent leurs Resources. [b]Lié à la source[/b] distingue les lanceurs. [b]Remplacer le même statut[/b] remplace l’instance de cette source."],
		[&"spell_movement", "Déplacement et collision", &"inspector_spell_advanced", "[b]Collision[/b] suit une poussée bloquée. [b]Pousser les adjacents[/b] agit autour de l’impact ; [b]pousser la zone[/b] agit sur toutes ses unités. [b]Téléportation[/b] place derrière la cible."],
		[&"spell_specials", "Mécaniques conditionnelles", &"inspector_spell_advanced", "[b]Regroupement[/b], [b]drain de PA[/b], [b]marque[/b] avec identifiant et source, [b]provocation[/b] avec durée, et [b]bonus de soin[/b] avec nom et multiplicateur configurent les cas spéciaux."],
		[&"spell_presentation", "Présentation et timing", &"inspector_spell_appearance", "[b]Icône, VFX et son[/b] règlent la présentation. [b]Placement[/b] choisit trajet ou cible. [b]Animation[/b] choisit l’action. [b]Délai d’impact[/b] synchronise animation et résolution."],
		[&"spell_delayed", "Résolution différée", &"inspector_spell_advanced", "[b]Mode[/b] : aucun, frappe/poussée, invocation. [b]Consommer à la résolution[/b] reporte la consommation. [b]Texte et couleur[/b] annoncent le déclenchement."],
		[&"spell_summon", "Invocation", &"inspector_spell_advanced", "Réglez [b]unité, type stable, PV de départ, maximum vivant, condition de PV[/b] (−1 désactive), [b]unité devant être absente[/b] et le dictionnaire [b]sort → recharge initiale[/b]."],
		[&"spell_permanent_modifiers", "Modificateurs permanents", &"inspector_spell_advanced", "Toujours actifs sur le sort, indépendamment de la progression. Vous pouvez ouvrir, déplacer, copier, rendre unique, retirer, créer ou partager. Leur ordre peut compter."],
	]],
	[&"effects", "6 · Effets (33)", [
		[&"effect_model", "Un effet transforme un sort", &"inspector_node", "Une amélioration contient une liste ordonnée de SpellModifier. Chaque effet transforme le sort ciblé sans changer son script ; son résumé traduit les réglages en phrase de gameplay."],
		[&"effect_lifecycle", "Créer, partager et rendre unique", &"inspector_node", "[b]Ajouter[/b] crée une Resource. [b]Partager[/b] réutilise une Resource. [b]Copier[/b] duplique. [b]Unique[/b] sépare avant modification. Les flèches ordonnent et [b]Retirer[/b] enlève la référence."],
		[&"effect_common_fields", "Paramètres communs", &"inspector_effect", "[b]Nom[/b] identifie l’effet. [b]Identifiant du sort[/b] est prioritaire ; le filtre par nom est historique. [b]Type[/b] choisit la mécanique. [b]Cible[/b] choisit ennemi principal, allié principal, ennemis/alliés affectés ou lanceur. Quantités, durée, seuil et ratio dépendent du type."],
		[&"effect_status_fields", "Paramètres avancés", &"inspector_effect_advanced", "[b]Charges[/b] limite certains déclenchements. [b]Groupes[/b] contrôlent les cumuls. [b]BASE[/b] crée, [b]DELTA[/b] ajoute, [b]OVERRIDE[/b] remplace. Type, élément et moment règlent le périodique. Dos requis et cible alliée requise ajoutent des conditions."],
		[&"legacy_modifiers", "Modificateurs historiques", &"inspector_effect_advanced", "Treize classes restent reconnues : terrain, portée, PM, soin, poussée exacte, dégâts à portée minimale, collision, dégâts centraux ou de dos, statut, cible alignée, bouclier et poussée. Le contrat affiche unité, cible, condition, durée, fréquence et empilement."],
	]],
	[&"verification", "7 · Tester et analyser", [
		[&"validate", "Valider", &"validation", "Contrôle caractéristiques, stockage, identifiants, rangs, XP, sort racine, cibles, effets, relations, cycles et accessibilité. Une [b]erreur[/b] bloque ; un [b]avertissement[/b] demande une décision sans modifier."],
		[&"validation_navigation", "Naviguer depuis un diagnostic", &"bottom_errors", "L’onglet explique problème et correction. Activez une ligne pour sélectionner directement la discipline, le rang ou l’amélioration concernée."],
		[&"simulate", "Simuler la progression", &"bottom_simulator", "Le curseur XP applique les vraies règles. Cliquez les choix disponibles ; les verrouillages expliquent XP, branche, exclusion ou rang antérieur. Remise à zéro et chemin valide accélèrent l’essai."],
		[&"path_statistics", "Statistiques et chemins", &"bottom_statistics", "Compte rangs, choix et relations, dessine l’XP et dénombre les configurations. [b]Tester tous les chemins[/b] rejoue jusqu’à 1 000 configurations avec les règles runtime."],
		[&"runtime_preview", "Prévisualisation runtime", &"bottom_preview", "Le vrai SpellCaster compare base et résultat dans neuf scénarios : défenses 0/25/50/100, allié, ennemi affaibli, dos, cibles multiples et case libre. La sandbox est déterministe et n’écrit rien."],
		[&"full_analysis", "Analyse complète", &"bottom_analysis", "Énumère les chemins, cherche nœuds inaccessibles et rangs morts, détecte la dominance et examine les choix finaux. Elle aide la conception sans prédire une victoire."],
		[&"compare_runs", "Comparer deux runs", &"compare_runs", "Choisissez la run de référence dans le sélecteur. Le rapport compare le profil du héros actif sans changer le contexte ni sauvegarder."],
		[&"global_search", "Recherche globale", &"search", "[b]Ctrl+F[/b] cherche noms, identifiants, descriptions et résumés d’effets. Activez un résultat pour ouvrir son personnage, sa discipline et son nœud."],
	]],
	[&"safety", "8 · Sauvegarde sûre", [
		[&"working_copy", "Copie de travail", &"document_state", "Toutes les modifications restent dans une copie profonde. Tester, prévisualiser, analyser, annuler et rétablir utilisent cette copie ; le badge MODIFIÉ signale son écart avec la source."],
		[&"drafts", "Brouillons récupérables", &"document_state", "Tant que le document est modifié, un brouillon est écrit toutes les 30 secondes. À l’ouverture : Restaurer, Comparer ou Abandonner. Restaurer ne sauvegarde pas encore la source."],
		[&"context_transition", "Changer de contexte", &"context_bar", "Avant de remplacer une copie modifiée : [b]Sauvegarder, Garder comme brouillon, Abandonner[/b] ou [b]Annuler[/b]. Plusieurs domaines sont traités comme une transaction globale."],
		[&"save_review", "Revoir la sauvegarde", &"save", "Sauvegarder et Ctrl+S ouvrent la même revue : opération, fichier, propriétaire, état et différences. Activez une ligne pour revenir à son propriétaire. Erreurs et conflits bloquent."],
		[&"transaction_recovery", "Transaction et récupération", &"save", "Le Studio prépare le plan, réserve les chemins et crée une récupération avant l’écriture. Les opérations cohérentes sont indivisibles ; un échec restaure les données précédentes."],
		[&"orphans", "Resources orphelines", &"orphans", "[b]Adopter[/b] rattache une discipline. [b]Archiver[/b] retire avec récupération. [b]Supprimer[/b] exige l’identifiant exact et crée aussi une récupération. Une référence entrante bloque les retraits."],
	]],
	[&"readonly", "9 · Non éditable ici", [
		[&"readonly_principle", "Ce que signifie non éditable", &"inspector_advanced", "Ces propriétés existent dans les Resources mais n’ont pas encore de champ sûr dans le Studio. Elles sont listées pour ne pas les confondre avec une fonction cachée. [b]Ouvrir dans l’Inspecteur Godot[/b] permet seulement de consulter ou d’assumer une édition technique."],
		[&"readonly_character", "Personnage : non éditable", &"inspector_character", "Équipe ; résistances élémentaires ; orientation ; SpriteFrames, échelle, animation d’attente et scène runtime ; rôle, résumés et badge ; attaque de base ; liste brute des sorts ; IA et distances ; faction et rôles ; armure de proximité ; réduction spéciale du déplacement forcé."],
		[&"readonly_spell", "Sort : non éditable", &"inspector_spell_advanced", "L’exclusion du lanceur des effets de zone existe dans Spell mais n’a pas de champ ici. Les propriétés complexes d’un modificateur historique restent invisibles sans éditeur spécialisé."],
		[&"readonly_effect", "Effet : non éditable", &"inspector_effect_advanced", "[b]Exiger un chemin libre[/b] pour déplacer le lanceur existe dans les données. Destination libre et alignement sont toujours vérifiés ; seule la vérification des cellules intermédiaires n’est pas éditable."],
		[&"readonly_policy", "Pourquoi cette limite", &"inspector_advanced", "Le Studio n’affiche que les champs possédant un éditeur et une validation adaptés. Cela évite de présenter comme complète une Resource dont un réglage essentiel serait invisible."],
	]],
	[&"sandbox", "10 · Exercice sandbox", [
		[&"sandbox_purpose", "Apprendre sans toucher au jeu", &"sandbox", "L’exercice travaille uniquement sous [b]user://dungeon_draft_studio/tests/skill_tree_tutorial/[/b]. Il ne modifie aucune run officielle, aucun héros de production et aucun fichier res://data."],
		[&"sandbox_steps", "Parcours de l’exercice", &"sandbox", "Choisir un héros d’exercice ; créer discipline et sort ; régler trois rangs ; créer deux branches ; prérequis et exclusion ; dégâts, statut et portée ; simuler ; prévisualiser ; valider ; revoir une sauvegarde sandbox ; restaurer l’état initial."],
		[&"sandbox_launch", "Démarrer l’exercice sécurisé", &"sandbox", "Le Studio créera une fixture dédiée et guidera chaque action. L’exercice pourra être interrompu et ne supprimera que son propre dossier.", &"sandbox"],
	]],
]

var _chapter_index := 0
var _page_index := 0
var _chapter_list: ItemList
var _chapter_label: Label
var _title_label: Label
var _body_label: RichTextLabel
var _counter_label: Label
var _previous_button: Button
var _next_button: Button
var _target_button: Button
var _action_button: Button


func _ready() -> void:
	title = "Tutoriel — personnages et compétences"
	min_size = Vector2i(980, 650)
	max_size = Vector2i(1440, 920)
	exclusive = false
	get_ok_button().hide()
	var root := VBoxContainer.new()
	root.custom_minimum_size = Vector2(930, 570)
	root.add_theme_constant_override("separation", 12)
	add_child(root)
	var intro := Label.new()
	intro.text = "Choisissez un chapitre ou suivez le parcours complet. La visite ne modifie jamais vos données."
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.add_theme_color_override("font_color", Color(0.72, 0.77, 0.84))
	root.add_child(intro)
	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.split_offset = 245
	root.add_child(split)
	_chapter_list = ItemList.new()
	_chapter_list.custom_minimum_size.x = 230
	_chapter_list.select_mode = ItemList.SELECT_SINGLE
	_chapter_list.item_selected.connect(_select_chapter)
	split.add_child(_chapter_list)
	for chapter_value in CHAPTERS:
		var chapter := chapter_value as Array
		var item_index := _chapter_list.add_item(str(chapter[CHAPTER_TITLE]))
		_chapter_list.set_item_metadata(item_index, chapter[CHAPTER_ID])
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 10)
	split.add_child(content)
	_chapter_label = Label.new()
	_chapter_label.add_theme_font_size_override("font_size", 14)
	_chapter_label.add_theme_color_override("font_color", Color(0.65, 0.72, 0.82))
	content.add_child(_chapter_label)
	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", 23)
	_title_label.add_theme_color_override("font_color", Color(0.48, 0.86, 1.0))
	_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_title_label)
	_body_label = RichTextLabel.new()
	_body_label.bbcode_enabled = true
	_body_label.fit_content = false
	_body_label.scroll_active = true
	_body_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body_label.custom_minimum_size = Vector2(620, 350)
	_body_label.add_theme_font_size_override("normal_font_size", 16)
	_body_label.add_theme_font_size_override("bold_font_size", 16)
	content.add_child(_body_label)
	var page_actions := HBoxContainer.new()
	content.add_child(page_actions)
	_target_button = Button.new()
	_target_button.text = "Montrer dans le Studio"
	_target_button.tooltip_text = "Sélectionne et met en évidence la zone expliquée."
	_target_button.pressed.connect(_request_current_target)
	page_actions.add_child(_target_button)
	_action_button = Button.new()
	_action_button.text = "Démarrer l’exercice sécurisé"
	_action_button.tooltip_text = "Crée uniquement une fixture possédée sous user://."
	_action_button.pressed.connect(func(): sandbox_requested.emit())
	page_actions.add_child(_action_button)
	var footer := HBoxContainer.new()
	root.add_child(footer)
	_counter_label = Label.new()
	_counter_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(_counter_label)
	_previous_button = Button.new()
	_previous_button.text = "← Précédent"
	_previous_button.pressed.connect(_previous)
	footer.add_child(_previous_button)
	var restart := Button.new()
	restart.text = "Recommencer"
	restart.tooltip_text = "Revient au début du parcours complet."
	restart.pressed.connect(func():
		_chapter_index = 0
		_page_index = 0
		_refresh()
	)
	footer.add_child(restart)
	_next_button = Button.new()
	_next_button.pressed.connect(_next)
	footer.add_child(_next_button)
	_refresh()


func start(start_target: StringName = &"") -> void:
	_chapter_index = 0
	_page_index = 0
	if start_target != &"":
		_find_target(start_target)
	_refresh()
	popup_centered_ratio(0.86)
	_request_current_target.call_deferred()


func start_chapter(chapter_id: StringName) -> void:
	for index in range(CHAPTERS.size()):
		if StringName((CHAPTERS[index] as Array)[CHAPTER_ID]) == chapter_id:
			_chapter_index = index
			_page_index = 0
			break
	_refresh()
	popup_centered_ratio(0.86)
	_request_current_target.call_deferred()


func current_target() -> StringName:
	return StringName(_current_page()[PAGE_TARGET])


func current_page_id() -> StringName:
	return StringName(_current_page()[PAGE_ID])


func current_chapter_id() -> StringName:
	return StringName(_current_chapter()[CHAPTER_ID])


static func total_page_count() -> int:
	var count := EFFECT_PAGES.size()
	for chapter_value in CHAPTERS:
		count += ((chapter_value as Array)[CHAPTER_PAGES] as Array).size()
	return count


static func all_page_ids() -> PackedStringArray:
	var result := PackedStringArray()
	for chapter_value in CHAPTERS:
		for page_value in ((chapter_value as Array)[CHAPTER_PAGES] as Array):
			result.append(str((page_value as Array)[PAGE_ID]))
	for effect_value in EFFECT_PAGES:
		result.append(str((effect_value as Array)[PAGE_ID]))
	return result


func _select_chapter(index: int) -> void:
	if index < 0 or index >= CHAPTERS.size():
		return
	_chapter_index = index
	_page_index = 0
	_refresh()


func _previous() -> void:
	if _page_index > 0:
		_page_index -= 1
	elif _chapter_index > 0:
		_chapter_index -= 1
		_page_index = _chapter_pages().size() - 1
	_refresh()


func _next() -> void:
	if _page_index < _chapter_pages().size() - 1:
		_page_index += 1
	elif _chapter_index < CHAPTERS.size() - 1:
		_chapter_index += 1
		_page_index = 0
	else:
		hide()
		return
	_refresh()


func _refresh() -> void:
	if _title_label == null:
		return
	_chapter_index = clampi(_chapter_index, 0, CHAPTERS.size() - 1)
	_page_index = clampi(_page_index, 0, _chapter_pages().size() - 1)
	var chapter := _current_chapter()
	var page := _current_page()
	_chapter_list.select(_chapter_index)
	_chapter_list.ensure_current_is_visible()
	_chapter_label.text = str(chapter[CHAPTER_TITLE])
	_title_label.text = str(page[PAGE_TITLE])
	_body_label.text = str(page[PAGE_BODY])
	_counter_label.text = "Chapitre %d/%d · Étape %d/%d · %d étapes au total" % [
		_chapter_index + 1, CHAPTERS.size(), _page_index + 1,
		_chapter_pages().size(), total_page_count(),
	]
	_previous_button.disabled = _chapter_index == 0 and _page_index == 0
	_next_button.text = "Terminer" if _is_last_page() else "Suivant →"
	_target_button.visible = current_target() != &""
	_action_button.visible = page.size() > PAGE_ACTION \
		and StringName(page[PAGE_ACTION]) == &"sandbox"
	if visible and current_target() != &"":
		_request_current_target.call_deferred()


func _request_current_target() -> void:
	var target := current_target()
	if target != &"":
		target_requested.emit(target)


func _find_target(target: StringName) -> bool:
	for chapter_index in range(CHAPTERS.size()):
		var pages := _pages_for_chapter(chapter_index)
		for page_index in range(pages.size()):
			if StringName((pages[page_index] as Array)[PAGE_TARGET]) == target:
				_chapter_index = chapter_index
				_page_index = page_index
				return true
	return false


func _current_chapter() -> Array:
	return CHAPTERS[_chapter_index] as Array


func _chapter_pages() -> Array:
	return _pages_for_chapter(_chapter_index)


func _pages_for_chapter(chapter_index: int) -> Array:
	var chapter := CHAPTERS[chapter_index] as Array
	var pages := (chapter[CHAPTER_PAGES] as Array).duplicate()
	if StringName(chapter[CHAPTER_ID]) != &"effects":
		return pages
	var legacy_page := pages.pop_back()
	for effect_value in EFFECT_PAGES:
		var effect := effect_value as Array
		pages.append([effect[PAGE_ID], effect[PAGE_TITLE], &"inspector_effect", effect[PAGE_TARGET]])
	pages.append(legacy_page)
	return pages


func _current_page() -> Array:
	return _chapter_pages()[_page_index] as Array


func _is_last_page() -> bool:
	return _chapter_index == CHAPTERS.size() - 1 \
		and _page_index == _chapter_pages().size() - 1
