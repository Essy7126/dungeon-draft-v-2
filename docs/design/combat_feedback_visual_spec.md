# Spécification visuelle — feedback flottant de combat

## Architecture

`CombatFeedbackController` remplace l'implémentation du spawner tout en gardant le chemin de scène historique. Il installe un `CanvasLayer` non interactif (layer 90), un `Control` plein écran, un pool de `FloatingCombatText` et une file par cible. Les scènes de bataille existantes continuent d'instancier `battle/floating_text_spawner.gd` sans modification de leur ressource.

L'ancre cherche d'abord un `Control`, puis un `CanvasItem`, puis une `UnitView` du groupe, puis la projection grille/caméra. La dernière valeur connue est conservée si la cible disparaît pendant le mouvement. L'ancre est bornée avec une marge de viewport.

## Variants Current

La production utilise le style « Current technique » data-driven. La galerie `legacy_preset` reconstruit l'apparence observée avant migration pour la comparaison. Le style « Proposed V2 » reste un handoff, non appliqué sans validation utilisateur.

Les onze variants de la ressource centrale sont :

- Damage / Physical : épée + signe négatif ;
- Damage / Magical : éclat + signe négatif ;
- Damage / Critical : libellé CRITIQUE, impact et taille renforcés ;
- Damage / Periodic : marque de statut, montant plus discret et nom du statut ;
- Healing / Normal : croix + signe positif ;
- Shield / Absorbed : losange plein + libellé ABSORBÉ ;
- Shield / Granted : losange creux + signe positif ;
- Avoidance / Dodge : marque de mouvement + ESQUIVE ;
- Avoidance / Immune : hexagone + IMMUNISÉ ;
- Status / Added : plus + STATUT APPLIQUÉ ;
- Status / Expired : moins + STATUT EXPIRÉ.

Le signe, l'icône, le libellé, la taille et la hiérarchie complètent la couleur. Les libellés utilisent des clés prêtes pour `TranslationServer`, avec fallback français.

## Typographie et lisibilité

Les valeurs sont rendues dans des `Label` avec contour sombre centralisé. La taille dépend du variant et de `text_scale`. La galerie applique en plus une échelle responsive de 0,70 à 1,15 afin de valider 720p, 1080p et 1440p. Les fonds clairs et sombres alternent dans les cartes de preuve.

Les nombres à un, deux, trois ou quatre chiffres restent sur une ligne. Les critiques ont une échelle d'emphase de 1,28. Une esquive ou une immunité affiche son libellé sans aucun zéro. L'overheal demeure dans le fait, sans ligne visuelle par défaut.

## Mouvement

Valeurs Current dans `combat_feedback_settings.tres` : durée 0,86 s, apparition 0,09 s, montée 64 px à 1080p, fade sur les 34 % finaux. La montée se scale avec la hauteur du viewport. Le texte démarre à 0,84 puis atteint son emphase ; le critique culmine à 1,28.

`set_reduced_motion(true)` limite la montée à 8 px et supprime la transition d'échelle. `set_text_scale()` expose une plage 0,5–2,0 sans créer une nouvelle page d'options.

## Simultanéité

- Pré-chauffage : 24 instances.
- Maximum actif : 48.
- Maximum de lanes visibles par cible : 4.
- Intervalle de séquence : 0,09 s.
- Décalage horizontal contrôlé et empilement vertical par cible.
- Déduplication par `event_id`.
- Les multi-impacts utilisent `sequence_index` et restent séparés.
- Les AOE utilisent l'ancre de chaque cible.
- Les DoT sont discrets et conservent `status_id`.

## Cycle de vie

Les instances terminées retournent au pool. `clear_feedback()` vide la file, les identifiants vus et restitue les actifs. `_exit_tree()` déconnecte les signaux et nettoie. Les cibles sont conservées par `WeakRef`; une cible supprimée ne devient pas une référence invalide. La couche et les textes ignorent la souris.

## Galerie de preuve

`tools/ui_snapshots/CombatFeedbackGallery.tscn` expose 16 cartes déterministes : dégâts 8/42/125, critique 240, soin 32, bouclier absorbé 18, bouclier gagné 12, esquive, immunité, poison 6, brûlure 9, statut ajouté/expiré, multi-impact, AOE trois cibles et file même cible. Elle est absente du parcours normal.

## Proposed V2 à valider

Le pack Figma fallback décrit une proposition qui peut renforcer le vocabulaire d'icônes, harmoniser les fontes avec la direction artistique et adapter les espacements aux écrans. Elle ne doit pas être portée dans les scènes de production avant une validation explicite de la frame/composant proposé.
