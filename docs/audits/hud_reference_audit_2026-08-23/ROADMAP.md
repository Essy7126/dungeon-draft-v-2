# Roadmap

Le verdict formel est **PARTIAL_REBUILD**. La vidéo et le runtime Dungeon Draft convergent : préserver scènes, art, données, autorités et gameplay; reconstruire le contrat de présentation, la modalité et le pont historique. La référence inspire le rythme et la hiérarchie, jamais ses cartes ou son économie.

## Niveau A — polish sans refactor d'autorité

1. Corriger textes/raccourcis visibles (Échap), sans changer le comportement tant que le mapping n'est pas livré ensemble.
2. Replier inspect/journal par défaut à 720p; borner positions et hauteurs.
3. Ajuster bandeau et slots par layout data 720/1080; éliminer clipping/espace mort.
4. Ajouter marqueurs non colorimétriques légal/illégal/cooldown/lock.
5. Renforcer annonce tour ennemi et victoire brève sans dévoiler d'intention.
6. Atténuer contextuellement inspect/journal/timeline pendant le ciblage, sans déplacer le plateau.

Dépendances : snapshots actuels. Risque faible à moyen. Valeur joueur forte pour 720p. Tests : snapshots 1280/1920, texte français, contraste, clavier. Non-objectifs : gameplay, PA/PM, capacités, IA.

## Niveau B — refactor de présentation

1. Introduire un snapshot de présentation dérivé (`PLAYER_IDLE`…`BATTLE_ENDING`) sans déplacer encore les règles gameplay.
2. Uniformiser lock/release des move/melee/spell via un seul adaptateur d'intention.
3. Formaliser `ui_cancel` et la priorité Échap : cible → overlay supérieur → pause.
4. Créer un contrôleur modal pour pause/inventaire/arbre/évolution/tooltip.
5. Déporter visibilité/densité inspect-log-timeline dans layout/run data.
6. Donner une raison exacte à la cible illégale et un focus ciblage cohérent.
7. Orchestrer la chaîne impact final → issue locale → post-combat → retour monde sur le flow existant.

Dépendances : tests de contrat avant migration; SpellCaster/TurnQueue restent autorités. Risque moyen. Valeur maintenance élevée. Tests : matrice état × input × overlay, spam durant async, destruction Battle pendant modal, comparaison First Run/Odyssey. Captures : tous états aux deux résolutions.

## Niveau C — refactor architectural

1. Extraire de `action_bar.gd` une interface de ports/intents et un modèle de disponibilité testable.
2. Faire du Recraft une composition sur ce contrat plutôt qu'une sous-classe dépendante de champs privés.
3. Isoler le fallback historique derrière un adaptateur explicite; supprimer un chemin seulement après preuve d'absence d'usage.
4. Définir un contrat Battle ↔ HUD typé : bind/unbind, snapshot, intents, lifecycle.
5. Unifier le propriétaire des couches auxiliaires et leur destruction par salle.
6. Instrumenter compteurs de nœuds/connexions/RID par transition et corriger seulement les fuites attribuées.

Dépendances : Niveau B stable et baseline tests triée. Risque moyen/élevé. Valeur maintenance très élevée; valeur joueur indirecte. Tests : contract suite ancien/nouveau, transition répétée, zéro croissance, fallback explicite. Non-objectifs : réécriture Battle/SpellCaster, changement de RunData, deck/jauge/intention ennemie.

## Ordre conseillé

1. Stabiliser les 9 échecs sélectionnés et le runner évolution.
2. Livrer HUD-001/002/003 avec tests (cancel, modalité, lock).
3. Livrer responsive/accessibilité/focus (HUD-004/005/008/009/012/023).
4. Introduire le snapshot de présentation et l'arbitre modal.
5. Raccorder l'issue locale au post-combat et au retour monde existants.
6. Extraire `action_bar.gd` par strangler/adaptateur, jamais par big-bang.
7. Profiler les leaks et transitions après architecture stabilisée.

Aucune estimation en jours : le coût dépend de la baseline que l'équipe décide de réparer versus reclasser comme test historique, et du statut réel du fallback hors run.
