# Dispositions propres aux destinations

Les destinations de combat des étapes à embranchements résolvent désormais une
arène nommée comme la destination, au lieu de reprendre seulement la map de leur
profondeur. Le catalogue `data/rooms/catabase_routes/catalog.json` relie les
36 noms aux ressources et conserve la référence de chaque arène source.

Chaque variante retire entre 12 et 32 dalles pour ouvrir une saignée longitudinale
ou transversale et imposer un contournement. Les coupes restent dans l'emprise
existante, conservent les cases des obstacles et des départs, et préservent la
connexité à quatre directions. Les variantes sont enregistrées et éditables dans
le Studio ; aucune géométrie n'est tirée au hasard au chargement d'une partie.

L'identité est le nom de destination, indépendant du miroir gauche/droite appliqué
par la graine. Les arènes communes des étapes I, VII, XV et XX, les haltes et les
liaisons du parcours sont conservées. Les peintures et les rencontres restent les
mêmes : cette étape traite uniquement le nom des arènes et leur sol jouable.

L'explorateur et la fabrique de run utilisent le même résolveur. Le bouton
**Décor / dalles** expose le plan, même quand la peinture reste commune. Les
sauvegardes dont les destinations portent ces noms retrouvent les mêmes variantes
lorsque la fabrique reconstruit leurs salles.

Auteur : `tools/catabase_map_authoring/BuildRouteVariants.tscn`. Le générateur
refuse de remplacer un dossier de variantes existant ; modifier les ressources
avec le Studio pour les itérations de contenu.

Vérifications réussies : 9 tests, 16 977 assertions (dispositions, placements,
catalogue), navigateur en 720p/1080p et cinq scènes de branches peintes et
modulaires. Les rapports sont consignés dans
`tools/run_explorer/WORK_NOTES.md`. Aucune victoire complète n'a été jouée.
