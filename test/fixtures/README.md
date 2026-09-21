# Fixtures de régression

Ces ressources servent aux tests et aux outils de diagnostic, pas au catalogue
jouable. Le produit courant et ses apparences sont décrits dans `README.md`.

- `party_rules/` : trois identités et leurs règles pour vérifier les équipes,
  disciplines, sauvegardes et cycles de vie. Un seul mannequin procédural et
  six clips remplacent les modèles, textures et animations du trio retiré.
  `PartyRulesFixtures.HERO_PATHS` est le point d'entrée des scénarios concernés.
  Les sorts, disciplines et profils partagés sous `data/characters/` et
  `data/runs/profiles/` restent leurs dépendances de règles ; ils ne constituent
  pas des personnages proposés au joueur.
- `party_rules/ui/` : ancien écran de groupe, conservé uniquement pour tester
  les cartes, le remplacement des aperçus et la libération des ressources.
- `terrain/` : sept dispositions logiques historiques utilisées par les tests
  de grille et de transition. Les fonds spécifiques et musiques sont retirés ;
  les coordonnées, couches et UID nécessaires aux contrats sont conservés.

Ne pas réintroduire ces fixtures dans les fallbacks du jeu. Une run exige un
profil explicite ; les aperçus rapides du Studio utilisent Achille. Les tests
de règles ne doivent pas importer un nouveau modèle artistique pour remplacer
le mannequin. Les tests visuels du produit utilisent les ressources courantes.
