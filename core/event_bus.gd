# core/event_bus.gd
# ============================================================
# EVENT BUS — Le système nerveux du combat. Autoload (singleton).
#
# Ne contient QUE des signaux typés et nommés. AUCUNE logique, AUCUN état.
# C'est un tableau d'affichage : la logique ANNONCE des faits ("X a pris des
# dégâts"), et tout ce qui est intéressé (DebugLogger, UI, son)
# ÉCOUTE sans se connaître. La logique n'a plus besoin de connaître ses lecteurs.
#
# ------------------------------------------------------------
# CONFIGURATION GODOT (à faire une fois) :
#   Projet → Paramètres du projet → Autoloads (Variables globales)
#   Ajouter ce script sous le nom EXACT : EventBus
#   Le placer APRÈS DebugLogger dans l'ordre (DebugLogger doit exister en premier
#   car il s'abonnera au bus).
# ------------------------------------------------------------
# LA RÈGLE D'OR (ne jamais l'enfreindre) :
#   - Signaux TYPÉS et NOMMÉS pour les ANNONCES (un fait qui s'est produit).
#   - Appel DIRECT quand on a besoin d'un RÉSULTAT tout de suite (ex : calculer
#     un chemin, lire une valeur). Le bus n'est pas pour ça.
#   - JAMAIS de signal générique fourre-tout (genre "event(type, data)") : ça
#     rend le flux invisible et indébogable. Chaque fait a son signal nommé.
# ------------------------------------------------------------
# POINT D'ÉMISSION UNIQUE :
#   Un fait n'est émis QUE depuis UN seul endroit, après que le fait est acté.
#   Les nouveaux signaux `*_resolved` transportent un CombatEventFact émis
#   après application. Les signaux historiques restent transitoirement présents.
# ============================================================

extends Node

# ============================================================
# SIGNAUX DE COMBAT
# Émis depuis Unit, une fois le fait acté sur les PV.
# ============================================================

# DEPRECATED : coup résolu après mitigation, avant absorption du bouclier.
# Le signal est conservé pour compatibilité ; les nouveaux consommateurs doivent
# écouter hit_resolved, shield_absorption_resolved ou hp_damage_taken.
# target   : l'Unit qui a encaissé
# attacker : l'Unit source, ou null (terrain, poison)
# amount   : dégâts réels appliqués
# category : Spell.DamageType (physique / magique)
# element  : Spell.Element (feu, glace... ou NONE)
# is_crit  : true si c'était un critique
signal damage_dealt(target, attacker, amount, category, element, is_crit)

# Perte reelle de PV apres mitigation et absorption par le bouclier.
signal health_damage_taken(target, attacker, amount, category, element, is_crit)

# Contrat sémantique V2. Chaque signal transporte exactement un fait déjà
# appliqué et identifié. CombatEventFact contient les ids action/cast/impact,
# l'ordre multi-impact et les montants finaux sans demander de recalcul à l'UI.
signal hit_resolved(fact: CombatEventFact)
signal shield_absorption_resolved(fact: CombatEventFact)
signal hp_damage_taken(fact: CombatEventFact)
signal heal_received(fact: CombatEventFact)
signal shield_granted(fact: CombatEventFact)
signal attack_dodge_resolved(fact: CombatEventFact)
signal attack_immune(fact: CombatEventFact)
signal status_tick(fact: CombatEventFact)
signal status_added(fact: CombatEventFact)
signal combat_status_refreshed(fact: CombatEventFact)
signal combat_status_expired(fact: CombatEventFact)

# Une attaque a été totalement esquivée (aucun dégât).
# target   : l'Unit qui a esquivé
# attacker : l'Unit source, ou null
signal attack_dodged(target, attacker)

# Un critique s'est produit (émis EN PLUS de damage_dealt, pour les réactions
# spécifiques au crit : son particulier, trait "les crits appliquent un statut").
signal critical_hit(target, attacker, amount)

# Normal attack landed. Traits use this without treating spell damage as basic.
signal basic_attack_performed(attacker, target)

# Une unité a été soignée (PV réellement rendus).
# unit   : l'Unit soignée
# amount : PV réellement rendus (peut être < au soin théorique si plafond atteint)
signal unit_healed(unit, amount)

# Variantes sourcées pour les statistiques de combat. Les signaux historiques
# restent inchangés pour les vues et journaux existants.
signal healing_applied(unit, source, amount)

# Une unité est morte (PV tombés à 0). Émis UNE fois, depuis _die().
signal unit_died(unit)
signal unit_killed(unit, killer)

# ============================================================
# SIGNAUX DE STATUTS
# ============================================================

# Un statut vient d'être appliqué (nouveau, pas un simple rafraîchissement).
signal status_applied(unit, status_data)

# Un statut deja present vient de voir sa duree ou ses charges rafraichies.
signal status_refreshed(unit, status_data)

# Un statut a expiré et a été retiré.
signal status_expired(unit, status_name)
signal status_removed(unit, status_id, source)

# ============================================================
# SIGNAUX DE TOUR
# Émis depuis la TurnQueue / Unit.start_turn.
# ============================================================

# Le tour d'une unité commence (PA/PM rechargés, statuts à traiter).
signal turn_started(unit)
signal ability_telegraphed(caster, spell, payload)
signal telegraph_cleared(caster)
signal pending_ability_resolved(caster, spell, payload)
signal pending_ability_blocked(caster, spell, reason)
signal pending_ability_cancelled(caster, payload, reason)
signal summon_telegraphed(caster, spell, target_cell)
signal summon_resolved(caster, summoned_unit, target_cell, source_ability_id)
signal summon_blocked(caster, spell, target_cell, reason)
signal summon_cancelled(caster, spell, target_cell, reason)

# Un nouveau round commence (tous les vivants ont joué une fois). Émis par la
# TurnQueue. Sert aux systèmes de salle-situation (menace qui s'aggrave par round :
# spawn, terrain qui s'étend) sans qu'ils connaissent la TurnQueue.
signal round_started(number)

# ============================================================
# SIGNAUX DE CYCLE DE VIE DE LA VUE
# Émis depuis battle.gd une fois la vue de combat construite.
# grid_view : le GridView prêt à l'affichage (caméra, overlays, futurs systèmes
# visuels peuvent s'y abonner sans que battle.gd ait à les connaître).
# ============================================================
signal battle_view_ready(grid_view)

# Les PA d'une unite ont change (depense, refresh de tour, drain/bonus).
signal ap_changed(unit, current, max_value)

# ============================================================
# SIGNAUX DE BOUCLIER
# Le bouclier absorbe les dégâts AVANT les PV (couche défensive supplémentaire).
# shield_gained   : un bouclier vient d'être accordé (sorts de soutien).
# shield_absorbed : le bouclier a absorbé une partie ou la totalité d'une frappe.
# shield_broken   : le bouclier vient de tomber à 0 (épuisé par une frappe).
# ============================================================
signal shield_gained(unit, amount)
signal shield_applied(unit, source, amount)
signal shield_absorbed(unit, amount)
signal shield_broken(unit)

# ============================================================
# SIGNAUX DE DÉPLACEMENT FORCÉ
# Émis par SpellCaster quand un sort pousse une unité.
# battle.gd écoute pour mettre à jour la position visuelle.
# unit     : l'Unit déplacée
# from_pos : position grille de départ
# to_pos   : position grille d'arrivée
# collision: true si la poussée a été stoppée par un obstacle
# ============================================================
signal unit_pushed(unit, from_pos, to_pos, collision)

# Des degats de COLLISION viennent d'etre infliges (poussee contre mur/unite,
# chaine comprise). Emis par SpellCaster._apply_collision_damage, une fois le
# coup applique. C'est LE moment signature de l'ecole du placement : la juice
# (hit-stop, shake) et les futurs retours s'y abonnent.
# attacker : l'Unit qui a pousse | victim : l'Unit qui encaisse | damage : brut
signal collision_impact(attacker, victim, damage)

# Une unite vient d'etre TUEE par un terrain-hasard (lave, reaction...).
# Emis par TerrainEffects juste apres le coup fatal. unit : la victime,
# effect_name : le nom de l'effet de terrain responsable.
signal hazard_kill(unit, effect_name)

# ============================================================
# SIGNAUX DE SORT
# Émis depuis SpellCaster après un cast réussi (PA payés, effets appliqués).
#
# caster : l'Unit qui a lancé le sort
# spell  : le Spell lancé
# report : Dictionary avec les données tactiques du cast :
#   "affected_units"         : Array[Unit] touchées
#   "terrain_changed"        : Array[Vector2i] cases modifiées
#   "crits"                  : Array[Unit] touchées en critique
#   "dodges"                 : Array[Unit] ayant esquivé
#   "ally_adjacent_to_caster": bool — un allié était adjacent au caster
#   "angle_advantage"        : bool — attaque depuis un angle favorable
#   "pushed"                 : bool — une cible a été poussée (futur)
#   "collision"              : bool — une poussée a causé une collision (futur)
#   "pushed_away_from_ally"  : bool — poussée éloignant d'un allié (futur)
# ============================================================
signal spell_cast(caster, spell, report)
