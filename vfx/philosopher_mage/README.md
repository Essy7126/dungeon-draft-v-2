# Effets du mage philosophe

Les six animations de `assets/vfx/philosopher_mage/sprites_v1/effects.tres`
contiennent chacune quatre dessins transparents : `bolt`, `impact`, `heal`,
`control`, `shield`, `repel`. `PhilosopherSpellSpriteVFX` affiche ces textures
avec des `Sprite2D`. Il ne produit ni dégâts, ni soin, ni statut.

Le gestionnaire de VFX ne route ce kit que pour le personnage
`philosopher_mage` et ses cinq identifiants de sorts. Les parcours des autres
personnages continuent d'utiliser leurs propres effets.

| Sort | Effet affiché | Source de vérité |
| --- | --- | --- |
| Axiome | Projectile 0,20 s puis impact 0,24 s | Libération du geste puis `damaged_enemies` dans le rapport réel |
| Maïeutique | Soin 0,48 s | `healed_units`, uniquement si des PV ont été rendus |
| Réfutation | Onde 0,34 s et impact 0,24 s | Poussée/collision et dégâts confirmés |
| Aporie | Déploiement 0,30 s puis glyphe stable | `status_changed_units`, puis présence effective du statut |
| Égide du Logos | Déploiement 0,30 s puis protection stable | `shielded_units`, puis valeur de la source `philosopher_aegis` |

Les cinq sorts sont à cible unique. Leur `report.cell` conserve la cellule
ciblée avant une éventuelle poussée : Réfutation ne déplace donc pas son
impact à la cellule d'arrivée. Les protections persistantes suivent ensuite
la position affichée de la vraie vue du bénéficiaire pendant sa marche.

La fin du temps de vol ne crée aucun impact : celui-ci attend la confirmation
de résolution. Un cast manqué annule son projectile ; sans confirmation, un
délai de secours le retire. Une résolution directe n'invente pas de vol après
la perte des PV. Chaque `action_id` résolu est reconnu une seule fois.

Les auras vérifient leur source à chaque image, sans conserver de référence
forte à l'unité ou à sa vue. Elles disparaissent à la consommation ou à
l'expiration de la source, au retrait du statut, à la mort, au retrait de la
vue ou à la fermeture du combat. Un bouclier d'une autre origine ne prolonge
pas l'aura d'Égide.

Le groupe `philosopher_spell_sprite_vfx` et `get_debug_state()` exposent
`phase`, `animation`, `spell_id`, `sprite_count`, positions, confirmation et
source de maintien au banc de capture. Les tests du runtime et de la vraie
fabrique sont dans `test/unit/test_philosopher_sprite_vfx.gd`.

Le maintien utilise la position globale de `UnitView`, y compris apres une
poussee, un vortex ou une projection de carte en hauteur. Le projectile suivant
utilise `get_cast_effect_origin_global()` au moment de sa liberation. Un test
traverse un vrai vortex vers une case d'eau, verifie Mouille, suit l'aura apres
changement de hauteur et controle cette nouvelle origine du projectile.
