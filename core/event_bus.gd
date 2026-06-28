# core/event_bus.gd
# ============================================================
# EVENT BUS — Le système nerveux du combat. Autoload (singleton).
#
# Ne contient QUE des signaux typés et nommés. AUCUNE logique, AUCUN état.
# C'est un tableau d'affichage : la logique ANNONCE des faits ("X a pris des
# dégâts"), et tout ce qui est intéressé (DebugLogger, UI, son, futurs traits)
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
#   Ex : damage_dealt est émis depuis Unit._apply_damage_result (une fois les
#   PV réellement retirés), jamais depuis l'appelant. Zéro doublon garanti.
# ============================================================

extends Node

# ============================================================
# SIGNAUX DE COMBAT
# Émis depuis Unit, une fois le fait acté sur les PV.
# ============================================================

# Des dégâts ont été réellement infligés (après mitigation, PV déjà retirés).
# target   : l'Unit qui a encaissé
# attacker : l'Unit source, ou null (terrain, poison)
# amount   : dégâts réels appliqués
# category : Spell.DamageType (physique / magique)
# element  : Spell.Element (feu, glace... ou NONE)
# is_crit  : true si c'était un critique
signal damage_dealt(target, attacker, amount, category, element, is_crit)

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

# Une unité est morte (PV tombés à 0). Émis UNE fois, depuis _die().
signal unit_died(unit)

# ============================================================
# SIGNAUX DE STATUTS
# ============================================================

# Un statut vient d'être appliqué (nouveau, pas un simple rafraîchissement).
signal status_applied(unit, status_data)

# Un statut a expiré et a été retiré.
signal status_expired(unit, status_name)

# ============================================================
# SIGNAUX DE TOUR
# Émis depuis la TurnQueue / Unit.start_turn.
# ============================================================

# Le tour d'une unité commence (PA/PM rechargés, statuts à traiter).
signal turn_started(unit)

# Le tour d'une unité se termine.
signal turn_ended(unit)

# ============================================================
# SIGNAUX D'ÉNERGIE — l'économie d'action (remplace les PA).
# energy_generated : de l'énergie a été réellement produite (après plafond).
# energy_spent     : de l'énergie a été dépensée par une action.
# Les futurs convertisseurs/terrain/UI s'y abonnent.
# ============================================================
signal energy_generated(unit, energy_id, amount)
signal energy_spent(unit, energy_id, amount)
signal elan_generated(unit, amount)
signal elan_spent(unit, amount)
signal elan_changed(unit, current, max_value)
signal fervor_changed(unit, current, max_value, threshold_active)
signal fervor_threshold_changed(unit, active)
signal charge_changed(unit, current, max_value, threshold_active)
signal charge_threshold_changed(unit, active)
signal fervor_reaction_used(unit, attacker, cost, mitigated_amount)
signal awakening_activated(unit, energy_id, duration)
signal awakening_ended(unit, energy_id)

# ============================================================
# SIGNAUX DE BOUCLIER
# Le bouclier absorbe les dégâts AVANT les PV (couche défensive supplémentaire).
# shield_gained   : un bouclier vient d'être accordé (traits, sorts de soutien).
# shield_absorbed : le bouclier a absorbé une partie ou la totalité d'une frappe.
# shield_broken   : le bouclier vient de tomber à 0 (épuisé par une frappe).
# ============================================================
signal shield_gained(unit, amount)
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

# ============================================================
# SIGNAUX DE SORT
# Émis depuis SpellCaster après un cast réussi (énergie payée, effets appliqués).
# Utilisé par les traits de châssis pour réagir conditionnellement.
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

# La vue de combat est prête (GridView initialisé). Émis depuis battle.gd.
signal battle_view_ready(grid_view)
