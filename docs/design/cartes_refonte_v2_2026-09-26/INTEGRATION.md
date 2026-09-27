# Mise en place : fichiers, lots et preuves attendues

Base inspectée : `c6ab5a72c1789e4cc285300c9bbae9c78524fa05`, avec modifications locales de sélection/sprites/VFX. Les nouveaux noms ci-dessous sont des **cibles proposées** ; ils n'existent pas encore. Les autres sont des points d'entrée réellement présents dans le dépôt.

## 1. Architecture retenue

Ajouter un profil `catabase_cards_consumable_v2`. Sa fabrique fournit un contrôleur de cartes dédié et des adaptateurs de combat/économie. Les services communs de déplacement, dégâts, terrain, contenu Studio et navigation demeurent les points d'exécution.

Ne pas activer V2 en modifiant seulement `HAND_SIZE`, `consume()` ou `rules_revision=3` : ces chemins servent des parties antérieures et `ClassCards` ajoute encore ses maîtrises, drops et passifs. Une nouvelle valeur numérique sans routage complet ferait charger des règles incompatibles.

| Responsabilité | Existant à adapter | Cible proposée |
|---|---|---|
| Choix du profil | `core/expedition/expedition_session.gd`, `core/game_manager.gd` | Fabrique `core/expedition/consumable_cards_profile.gd`, routage par `ruleset_id` |
| Copies et préparation | `core/expedition/catabase_cards.gd`, `class_cards.gd` | `core/expedition/consumable_cards_state.gd`, interface de lecture/actions compatible UI |
| Catalogue et sorts | `class_card_catalog.gd`, `card_ecosystem_catalog.gd` | `core/expedition/consumable_card_catalog.gd` et ressources du profil dans `data/cards/consumable_v2/` |
| Effets et prévision | `core/spell_caster.gd`, `battle/battle.gd`, `class_card_modifier.gd` | `core/expedition/consumable_card_modifier.gd`, fonctions pures partagées preview/résolution |
| Loot et transactions | `core/expedition/expedition_session.gd`, mécanismes de reçus actuels | `core/expedition/consumable_card_economy.gd`, flux RNG séparés |
| Persistance | `core/expedition/expedition_save_service.gd` | `core/expedition/consumable_cards_checkpoint.gd`, sérialisation complète V2 |
| Sélection et HUD | `ui/selection/cards_character_setup.gd`, `cards_choice_page.gd`, `ui/recraft_hud_v1/combat/combat_hud_recraft_v1.gd` | Adapter les composants existants selon les capacités du profil |
| Terrain | `battle/dynamic_terrain/terrain_interaction_resolver.gd`, `terrain_surface_runtime_service.gd` | Métadonnées et politique de durée V2 ; aucune table parallèle |
| Rencontres et salles | catalogues d'expédition, `card_tactical_room_rules.gd`, `card_tactical_resource_rules.gd` | Adaptateurs de paramètres V2, variantes de rencontres identifiées |

Les vues demandent des capacités (`consumes_copies`, `can_prepare_opening`, `can_retain`, `uses_family_upgrades`), pas des comparaisons numériques dispersées de révision. Rechercher les branches `rules_revision == 3` et `>=2`, puis décider explicitement leur destin. Ne pas appeler un `super()` qui applique les anciennes cartes d'initiation ou la défausse.

## 2. Contenu et Studio

Le manifeste livré est une définition de conception complète, **pas un JSON à charger à l'aveugle dans le moteur V1** : de nouveaux champs et effets existent. Générer les ressources runtime avec validation de schéma et des références. Identifiants `cc2_n01`, etc. ; les IDs logiques du manifeste restent stables et sont préfixés au portage.

Réutiliser les services de transactions/validation existants dans `addons/dungeon_draft_arena_studio/`, notamment objets, rencontres et terrain. Ne pas fabriquer une seconde bibliothèque d'objets ni écrire manuellement des chemins d'assets dans plusieurs contrôleurs.

Le catalogue historique reste chargé pour ses propres saves. Les 18 objets et huit reliques V2 ont leur profil de catalogue. L'inventaire V2 doit accepter les acquisitions prévues sans le plafond implicite de 24 emplacements du restore historique : affichage paginé, UID, réserve de doublons, aucun cumul de deux reliques identiques. Pas de revente d'équipement ajoutée pour résoudre artificiellement un manque de place.

Pour les sept maps de référence, importer les cellules logiques via le Studio, vérifier les positions initiales et les commandes de salle. Le décor ne peut pas modifier la ligne de vue sans modifier aussi la fixture de référence.

## 3. Sauvegarde : changement obligatoire

Le service actuel indique une reprise au début du combat. V2 demande une reprise après chaque engagement. Utiliser un nouveau fichier `user://catabase_cards_consumable_v2.json`, enveloppe intègre et schéma 1. Le `ruleset_id` choisit le restaurateur ; aucune inférence à partir de la seule présence d'un tableau de cartes.

Champs minimaux :

```text
schema_version, ruleset_id, content_version, run_id, seed, action_seq
route + phase (préparation/combat/récompense/halte/terminée)
hero (classe, spécialisation, progression, compétences familiales, PV/PA/PM)
copies (UID/famille/origine/reçu), prepared_uids, opening_uid
hand/draw/discard, consumed_uid_tombstones, retained_uid
units (UID, données de référence, position, PV/garde/états, intentions)
round_index, actor_queue, current_actor, trigger_counters, pending_choice
dynamic_surfaces (cellule/groupe/source/durée/coefficients)
room_state, boss_phase, eligible_roster, loot_commitment
rng_states (pioche/loot/rencontres), merchant_stock, transaction_receipts
reward_receipts, pending_progression_choices, visual_variant
```

Le journal complet de toutes les actions est un artefact de diagnostic ; il n'est pas recopié indéfiniment dans chaque snapshot. Les UID consommés/reçus indispensables restent compacts. Garder une limite de taille vérifiée et échouer lisiblement si elle est atteinte.

**Transaction d'action.** Résoudre sur un état détaché ou un delta annulable → valider invariants → écrire atomiquement le checkpoint → exposer l'état engagé et lancer les animations. Échec d'écriture : rollback, pas d'effet visible engagé, entrée bloquée jusqu'à traitement. Un identifiant `run_id/action_seq` déjà reçu n'est jamais exécuté une seconde fois.

**Reprise.** Restaurer hors de la session courante, valider toutes les références, puis basculer. Un acteur adverse interrompu au milieu d'une animation a déjà son résultat engagé ; reprendre l'acteur suivant. Un choix de Relais sauvegardé revient sur ce choix, sans rejouer le kill. Les effets purement visuels peuvent être sautés, jamais leurs résultats logiques.

**Compatibilité.** L'ancien fichier `catabase_cards_v1.json` reste intact. Continuer peut proposer la partie ancienne et la partie V2 si les deux existent. Aucun transfert automatique des cartes, objets, maîtrises ou statistiques. L'abandon d'une ancienne run reste une action du joueur selon le parcours actuel.

## 4. Ordre des lots — dépendances explicites

| Lot | Travail | Livrable qui clôt le lot |
|---|---|---|
| L0 — Profil et données | Schéma, registre de profil, 48 familles, huit spécialisations, objets, route et référence logique | Import valide, IDs uniques, données anciennes inchangées, fabrique V2 non publique |
| L1 — Consommation et checkpoint | UID, main, préparation, ouverture, transactions, reprise d'action, compteurs | Scénarios interruption/annulation/reprise sans copie rendue ni coût doublé |
| L2 — Combat et quatre identités | Arrondis, états, prévision, relais, ancre, sacrifice, surfaces | Traces prévues/réelles concordantes et scénarios ciblés par classe |
| L3 — Run et économie | XP, upgrades, sacs, marchands, reçus, inventaire, bilan, prochaines destinations | Une run automatisée complète et reprises à chaque frontière de décision |
| L4 — Ennemis et cartes réelles | Variantes C3/C4/C7/C10, Pâris, cinq salles, Studio et IA | Intentions annulables réellement annulées, géométrie et terrain vérifiés |
| L5 — Parcours public et calibration | Sélection, HUD, magasin, captures, parties humaines puis ajustements bornés | Critères de réception ci-dessous, puis V2 par défaut pour les nouvelles parties Cartes |

Chaque lot garde le candidat jouable à son stade, avec fonctionnalités non livrées explicitement désactivées. L0–L1 ne doivent pas présenter la sélection définitive tant que les effets des cartes ne fonctionnent pas. La bascule ne dépend pas d'un taux de victoire de l'ancien bot.

## 5. Tests de règles indispensables

Futurs tests proposés : `test_consumable_cards_state.gd`, `test_consumable_cards_checkpoint.gd`, `test_consumable_cards_effects.gd`, `test_consumable_cards_economy.gd`, `test_consumable_cards_profile.gd`. Les inscrire dans les suites du dépôt au moment de leur création ; leur nom dans ce document n'est pas une exécution.

| Domaine | Cas qui doit échouer si le contrat est violé |
|---|---|
| Conservation | Chaque UID actif dans une seule zone ; aucune copie consommée rejouable ; réserve hors combat inaccessible |
| Légalité | Cible invalide, PA insuffisants, famille déjà utilisée : zéro mutation, zéro receipt d'action réussie |
| Ordre | Condition marquée capturée avant consommation ; Convergence avant impact ; prévision garde/sacrifice identique au résultat |
| Arrondis | Impact faible, garde juste suffisante, PV exactement au seuil de mort, dégâts traversant les deux phases |
| Déclencheurs | Carte de zone avec plusieurs morts ; pas de récursion riposte/miroir ; relais non retransmissible ; classe/spec compteurs distincts |
| Pioche | Ouverture retirée du paquet ; rétention limite la place ; main pleine ; petit stock ; double pioche relais/spécialisation |
| Mouvement | Ancre bloquée, hors portée, PM insuffisants ; retour exclu du compteur ; mur vs unité/bord/boss pour Choc |
| Terrain | Eau→glace/vapeur, deux groupes, durée, propriétaire, pas de double tic entrée/début ; vapeur modifie la visée |
| Butin | Mort initiale vs invocation/sacrifice/phase boss ; mêmes reçus après reload ; plusieurs sacs indépendants |
| Marchand | Transactions rejouées, stock fini, trois UID de troc, sélection d'ouverture vendue, changement d'équipement sans soin |
| Reprise | Après coup létal, pendant Relais, entre deux acteurs, avant/après progression, pendant ouverture des sacs, écriture échouée |
| Anciennes runs | Fichiers antérieurs restaurés par leur code ; catalogue, quantités et checkpoints historiques conservés |

## 6. Validation projet et réception

Suivre [la référence actuelle](../../current/validation.md). Pour les premiers lots ciblés : `./dev.ps1 test cards`, puis `catabase`. Ajouter `monsters`, `terrain` et `studio` suivant le lot. Avant bascule, le moteur commun ayant changé : **import, `./dev.ps1 test all`, gates CI conservées et parcours complet réel**.

La CI conserve comparaison exacte aux échecs historiques autorisés, absence de mutations GUT, portabilité et smokes de contenu. Aucun nouvel échec ajouté à la liste pour faire passer V2. Un import interrompu ou zéro test ne clôt aucun lot.

Parcours minimum : sélection personnalisée → trois premiers combats → premier marchand → niveau/spécialisation → combat avec reprise au milieu → terrain → Pâris → bilan → nouvelle run. Exécuter aussi une reprise d'ancienne partie et Classique. Vérifier captures HUD/inventaire et les vrais écrans du parcours, pas seulement la galerie de composants.

Réception avant usage par défaut : aucune divergence légalité/prévision constatée dans les fixtures ; aucun reroll/duplicata aux checkpoints ; réponses ordinaires accessibles dans chaque rencontre ; quatre identités utilisables sans rare obligatoire ; pression et consommation comprises durant observation ; causes d'échec traçables.

Les essais humains exploratoires et la campagne de balance sont un travail à réaliser dans L5, pas une permission supplémentaire à demander pour L0–L4 déjà préparés. Toute nouvelle valeur de balance doit être versionnée avec ses raisons et ses résultats.
