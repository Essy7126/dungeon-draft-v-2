# VFX run Cartes — animation cel retenue

**Décision utilisateur du 22 septembre 2026 : « on prends animation cel ».**
La colonne A de l’atelier de références devient la DA des VFX de la run Cartes.
Cette décision remplace le choix éthéré du 20 septembre.

Références concrètes retenues : `cel.png` pour la lame et la main d’eau,
`standard_cel.png` pour l’étendard, dans
`tools/class_card_vfx/reference_study/art/`. Garder leurs silhouettes dessinées,
aplats francs, ombres découpées et accents clairs. Le choix ne consiste pas à
recolorer les shaders éthérés existants.

L’[atelier](../../../tools/class_card_vfx/reference_study/README.md) indique A
comme retenue dès l’ouverture ; B et C restent accessibles pour comparaison.
Les observations sort par sort et les limites des reconstructions restent dans
l’[étude des références](../vfx_reference_studies_2026-09-22.md).

La DA est choisie ; les trois animations d’étude ne sont pas toutes approuvées
comme animations finales. La main manque encore de dessins de dissolution.
La présentation des états (signaux localisés ou étiquettes) n’a pas encore fait
l’objet d’un choix utilisateur distinct.

## Production autorisée le 22 septembre

La demande suivante étend la réalisation à **toutes les cartes**. La production
utilise désormais 17 séquences de six poses dessinées et 112 compositions
explicites, avec orientation, rémanence et silhouette choisies par carte.
[Sources, prompts et lecteur](../../../vfx/class_cards/cel/README.md).

Les nappes éthérées sont remplacées dans le lecteur, les vols et le sol.
Les états passent dans une rangée compacte, plafonnée à cinq signes et un
compteur en cas de débordement ; les noms et durées complets restent dans le HUD.
C’est une proposition d’implémentation répondant au problème de cumul, et non
un choix artistique supplémentaire déjà approuvé par l’utilisateur.

Les durées de jeu, les coûts, les dégâts et les sons de combat existants sont
conservés. La run Classique conserve son routeur habituel. Les fiches exportées
sont dans `cards_vfx_cel_contracts_2026-09-22.md` ; les preuves finales sont
consignées dans `docs/ai/CARDS_CEL_PRODUCTION_2026-09-22.md`.
